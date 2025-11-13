import Combine
import Foundation
import OSLog

/// 字幕视图模型
///
/// 职责：
/// - 管理当前显示的字幕状态
/// - 根据播放时间匹配字幕
/// - 记录时间同步偏差和性能指标
///
/// # 核心算法
/// - **时间对齐**：使用 ±50ms 容差的区间匹配算法
/// - **查找优化**：优先线性扫描当前索引附近（顺序播放），回退到二分查找（seek 场景）
/// - **去抖机制**：合并 16ms 内的多次时间更新，避免不必要的重绘
/// - **快速路径**：检查当前字幕是否仍然有效，避免重复查找
///
/// # 性能指标
/// - 字幕更新延迟：目标 < 5ms
/// - 时间同步偏差：P95 ≤ 200ms
/// - 100 个字幕查找：< 500ms
///
/// # 示例
/// ```swift
/// @MainActor
/// class PlayerView: View {
///     @StateObject private var subtitleVM = SubtitleViewModel()
///
///     var body: some View {
///         VStack {
///             VideoPlayer(...)
///             if let subtitle = subtitleVM.currentSubtitle {
///                 Text(subtitle.text)
///             }
///         }
///         .onReceive(player.timePublisher) { time in
///             subtitleVM.updateCurrentTime(time)
///         }
///     }
/// }
/// ```
@MainActor
public final class SubtitleViewModel: ObservableObject {
    // MARK: - Published Properties

    /// 当前显示的字幕（nil 表示无字幕）
    @Published public private(set) var currentSubtitle: Subtitle?

    /// 是否正在加载识别结果
    @Published public private(set) var isLoading: Bool = false

    /// 错误消息（空状态）
    @Published public private(set) var errorMessage: String?

    // MARK: - Private Properties

    /// 所有字幕列表（按 startTime 排序）
    private var subtitles: [Subtitle] = []

    /// 当前字幕索引（优化查找性能）
    private var currentIndex: Int = 0

    /// 时间对齐容差（50ms）
    private let alignmentTolerance: TimeInterval = 0.05

    /// 去抖计时器（16ms 帧间隔）
    private var debounceTimer: Timer?
    private let debounceInterval: TimeInterval = 0.016

    /// 日志记录器
    private let logger = Logger(
        subsystem: "com.prismplayer.core",
        category: "subtitle-viewmodel"
    )

    /// 指标记录器
    private let metrics: MetricsRecorder

    // MARK: - Initialization

    /// 创建字幕视图模型
    ///
    /// - Parameter metrics: 指标记录器，默认使用共享实例
    nonisolated public init(metrics: MetricsRecorder? = nil) {
        self.metrics = metrics ?? MetricsRecorder()
        logger.debug("SubtitleViewModel initialized")
    }

    // MARK: - Public Methods

    /// 设置字幕列表
    ///
    /// 会自动按 startTime 排序，并重置当前状态。
    ///
    /// - Parameter subtitles: 字幕数组
    public func setSubtitles(_ subtitles: [Subtitle]) {
        self.subtitles = subtitles.sorted { $0.startTime < $1.startTime }
        self.currentIndex = 0
        self.currentSubtitle = nil

        logger.info("Loaded \(subtitles.count) subtitles")
        metrics.recordCount(subtitles.count, key: "subtitle_count")
    }

    /// 更新当前播放时间（主要入口）
    ///
    /// 使用去抖机制合并高频更新，避免不必要的计算和重绘。
    ///
    /// - Parameter time: 当前播放时间（秒）
    public func updateCurrentTime(_ time: TimeInterval) {
        // 去抖：合并 16ms 内的多次更新
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(
            withTimeInterval: debounceInterval,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.performTimeUpdate(time)
            }
        }
    }

    /// 设置加载状态
    ///
    /// - Parameter loading: 是否正在加载
    public func setLoadingState(_ loading: Bool) {
        isLoading = loading
        if loading {
            errorMessage = nil
        }
    }

    /// 设置错误状态
    ///
    /// - Parameter message: 错误消息
    public func setError(_ message: String) {
        errorMessage = message
        isLoading = false
        currentSubtitle = nil
    }

    /// 重置状态
    ///
    /// 清空当前字幕、加载状态和错误消息。
    public func reset() {
        currentSubtitle = nil
        currentIndex = 0
        isLoading = false
        errorMessage = nil
        debounceTimer?.invalidate()
        logger.debug("SubtitleViewModel reset")
    }

    // MARK: - Private Methods

    /// 执行时间更新（去抖后）
    ///
    /// # 算法流程
    /// 1. 快速路径：检查当前字幕是否仍然有效
    /// 2. 查找匹配字幕（线性扫描 + 二分查找）
    /// 3. 只有 ID 变化时才更新 @Published 属性
    /// 4. 记录性能指标
    ///
    /// - Parameter time: 当前播放时间（秒）
    private func performTimeUpdate(_ time: TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()

        // 快速路径：检查当前字幕是否仍然有效
        if let current = currentSubtitle,
            current.contains(time, tolerance: alignmentTolerance)
        {
            // 无需更新
            return
        }

        // 二分查找匹配字幕
        let candidate = findSubtitle(at: time)

        // 只有 ID 变化时才更新（避免不必要的重绘）
        if candidate?.id != currentSubtitle?.id {
            let oldSubtitle = currentSubtitle
            currentSubtitle = candidate

            // 记录切换延迟
            let updateLatency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            logger.debug(
                """
                Subtitle updated: \
                '\(oldSubtitle?.text ?? "nil")' -> '\(candidate?.text ?? "nil")' \
                (latency: \(updateLatency, privacy: .public)ms)
                """)
            metrics.recordLatency(updateLatency, key: "subtitle_update_latency_ms")

            // 记录时间同步偏差
            if let candidate = candidate {
                recordSyncDeviation(time, subtitle: candidate)
            }
        }
    }

    /// 查找指定时间的字幕
    ///
    /// # 算法说明
    /// - **顺序播放优化**：优先在当前索引附近线性扫描（-2 到 +5 范围）
    /// - **随机访问回退**：如果线性扫描未找到，使用二分查找处理 seek 等场景
    ///
    /// - Parameter time: 当前播放时间（秒）
    /// - Returns: 匹配的字幕，如果无匹配则返回 nil
    private func findSubtitle(at time: TimeInterval) -> Subtitle? {
        guard !subtitles.isEmpty else { return nil }

        // 从当前索引附近开始线性扫描（大多数情况下字幕是顺序播放）
        let searchRange = max(0, currentIndex - 2)..<min(subtitles.count, currentIndex + 5)

        for i in searchRange {
            let subtitle = subtitles[i]
            if subtitle.contains(time, tolerance: alignmentTolerance) {
                currentIndex = i
                return subtitle
            }
        }

        // 回退到二分查找（处理 seek 等非顺序场景）
        let index = subtitles.binarySearch { subtitle in
            if time < subtitle.startTime - alignmentTolerance {
                return .orderedDescending
            } else if time >= subtitle.endTime + alignmentTolerance {
                return .orderedAscending
            } else {
                return .orderedSame
            }
        }

        if let foundIndex = index {
            currentIndex = foundIndex
            return subtitles[foundIndex]
        }

        return nil
    }

    /// 记录时间同步偏差
    ///
    /// 当偏差超过容差时记录警告日志和指标。
    ///
    /// - Parameters:
    ///   - time: 当前播放时间
    ///   - subtitle: 匹配的字幕
    private func recordSyncDeviation(_ time: TimeInterval, subtitle: Subtitle) {
        let idealTime = subtitle.startTime
        let deviation = abs(time - idealTime)

        if deviation > alignmentTolerance {
            logger.info(
                """
                Subtitle sync deviation: \(deviation * 1000, privacy: .public)ms \
                (time: \(time, privacy: .public)s, \
                expected: \(idealTime, privacy: .public)s)
                """)
            metrics.recordDeviation(deviation * 1000, key: "subtitle_sync_deviation_ms")
        }
    }
}

// MARK: - Array Extension (Binary Search)

extension Array {
    /// 二分查找
    ///
    /// 使用自定义比较器在有序数组中查找元素。
    ///
    /// - Parameter predicate: 比较器，返回 .orderedSame 表示找到
    /// - Returns: 找到的索引，如果未找到则返回 nil
    fileprivate func binarySearch(
        _ predicate: (Element) -> ComparisonResult
    ) -> Int? {
        var left = 0
        var right = count - 1

        while left <= right {
            let mid = (left + right) / 2
            let result = predicate(self[mid])

            switch result {
            case .orderedSame:
                return mid
            case .orderedAscending:
                left = mid + 1
            case .orderedDescending:
                right = mid - 1
            }
        }

        return nil
    }
}
