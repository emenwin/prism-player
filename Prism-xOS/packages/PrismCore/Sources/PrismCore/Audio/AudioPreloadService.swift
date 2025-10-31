import AVFoundation
import Foundation
import OSLog

/// 音频预加载服务
///
/// 职责：
/// - 管理音频预加载流程（首帧快速窗口 + 后台预加载）
/// - 协调 AudioExtractor 和 PreloadQueue
/// - 实现双路并行首帧策略
///
/// 核心算法：
/// 1. **双路并行首帧**：
///    - 路径 A：抽取前 5s → 立即送 ASR（极速首帧）
///    - 路径 B：抽取 5–10s → ASR 队列（补充首屏）
///    - 路径 C：抽取 10–30s → 预加载队列（低优先级）
/// 2. **优先级调度**：
///    - fastFirstFrame > scroll > preload
///    - 首帧任务优先，预加载任务后台执行
/// 3. **缓存管理**：
///    - 抽取的音频数据缓存（LRU）
///    - 避免重复抽取
///
/// 使用示例：
/// ```swift
/// let service = AudioPreloadService(
///     extractor: AVAssetAudioExtractor(),
///     strategy: .default
/// )
///
/// // 开始预加载
/// try await service.startPreload(for: asset)
///
/// // 获取首帧音频
/// let firstFrameBuffer = try await service.getFirstFrameBuffer()
/// ```
///
/// 参考：
/// - Task-102 §3.2 差异 1: 首帧快速窗口优化策略
/// - Task-102 §4 实施计划 PR2
public actor AudioPreloadService {
    private let logger = Logger(subsystem: "com.prismplayer.core", category: "audio.preload")

    /// 音频抽取器
    private let extractor: AudioExtractor

    /// 预加载策略
    private let strategy: PreloadStrategy

    /// 预加载队列
    private let queue: PreloadQueue

    /// 缓存的音频数据（key: "startMs-endMs"）
    private var cache: [String: AudioBuffer] = [:]

    /// 当前资源
    private var currentAsset: AVAsset?

    /// 首帧完成回调
    private var firstFrameCompletion: ((Result<AudioBuffer, Error>) -> Void)?

    /// 初始化
    /// - Parameters:
    ///   - extractor: 音频抽取器
    ///   - strategy: 预加载策略
    ///   - maxConcurrentTasks: 最大并发任务数
    public init(
        extractor: AudioExtractor,
        strategy: PreloadStrategy = .default,
        maxConcurrentTasks: Int = 3
    ) {
        self.extractor = extractor
        self.strategy = strategy
        self.queue = PreloadQueue(maxConcurrentTasks: maxConcurrentTasks)
    }

    /// 开始预加载
    ///
    /// 核心流程：
    /// 1. 清除旧缓存和队列
    /// 2. 启动双路并行首帧抽取
    /// 3. 启动后台预加载（10–30s）
    ///
    /// - Parameter asset: 媒体资源
    public func startPreload(for asset: AVAsset) async throws {
        logger.info("开始预加载: strategy=\(self.strategy.description, privacy: .public)")

        // 清除旧状态
        await queue.cancelAll()
        cache.removeAll()
        currentAsset = asset

        let duration = try await asset.load(.duration)
        let totalSeconds = duration.seconds

        // 双路并行首帧策略
        let fastWindowDuration = min(strategy.fastFirstFrameDuration, totalSeconds)

        // 路径 A: 前 5s（极速首帧）
        let path_A_Duration = min(5.0, fastWindowDuration)
        logger.debug("路径 A: 前 \(path_A_Duration, privacy: .public)s（极速首帧）")

        await queue.enqueue(priority: .fastFirstFrame) {
            await self.extractAndCache(
                from: asset,
                start: 0,
                duration: path_A_Duration,
                label: "首帧路径A"
            )
        }

        // 路径 B: 5–10s（补充首屏）
        if fastWindowDuration > 5.0 {
            let path_B_Start = 5.0
            let path_B_Duration = min(fastWindowDuration - 5.0, totalSeconds - 5.0)
            logger.debug(
                "路径 B: \(path_B_Start, privacy: .public)s–\(path_B_Start + path_B_Duration, privacy: .public)s（补充首屏）"
            )

            await queue.enqueue(priority: .fastFirstFrame) {
                await self.extractAndCache(
                    from: asset,
                    start: path_B_Start,
                    duration: path_B_Duration,
                    label: "首帧路径B"
                )
            }
        }

        // 路径 C: 10–30s（后台预加载）
        let preloadStart = fastWindowDuration
        let preloadDuration = min(
            strategy.preloadDuration - fastWindowDuration,
            totalSeconds - fastWindowDuration
        )

        if preloadDuration > 0 {
            logger.debug(
                "路径 C: \(preloadStart, privacy: .public)s–\(preloadStart + preloadDuration, privacy: .public)s（后台预加载）"
            )

            await queue.enqueue(priority: .preload) {
                await self.extractAndCache(
                    from: asset,
                    start: preloadStart,
                    duration: preloadDuration,
                    label: "后台预加载"
                )
            }
        }
    }

    /// 获取音频缓冲区
    /// - Parameter timeRange: 时间范围
    /// - Returns: 音频缓冲区（如果已缓存）
    public func getBuffer(for timeRange: CMTimeRange) -> AudioBuffer? {
        let key = cacheKey(for: timeRange)
        return cache[key]
    }

    /// 获取首帧音频（等待路径 A 完成）
    /// - Returns: 首帧音频缓冲区
    public func getFirstFrameBuffer() async throws -> AudioBuffer {
        let firstFrameRange = CMTimeRange(
            start: .zero,
            duration: CMTime(
                seconds: min(5.0, strategy.fastFirstFrameDuration), preferredTimescale: 600)
        )

        // 如果已缓存，直接返回
        if let buffer = getBuffer(for: firstFrameRange) {
            logger.debug("首帧音频已缓存")
            return buffer
        }

        // 等待抽取完成
        logger.debug("等待首帧音频抽取...")
        return try await withCheckedThrowingContinuation { continuation in
            // 每 100ms 检查一次缓存
            Task {
                while true {
                    if let buffer = self.getBuffer(for: firstFrameRange) {
                        continuation.resume(returning: buffer)
                        return
                    }

                    try? await Task.sleep(nanoseconds: 100_000_000)

                    // 超时检查（10s）
                    // TODO: 实现超时机制
                }
            }
        }
    }

    /// 等待所有任务完成
    public func waitForAll() async {
        await queue.waitForAll()
    }

    /// 停止预加载
    public func stop() async {
        logger.info("停止预加载")
        await queue.cancelAll()
    }

    /// 获取队列深度
    public func getQueueDepth() async -> Int {
        await queue.depth
    }

    // MARK: - Private Methods

    /// 抽取并缓存音频
    private func extractAndCache(
        from asset: AVAsset,
        start: TimeInterval,
        duration: TimeInterval,
        label: String
    ) async {
        let timeRange = CMTimeRange(
            start: CMTime(seconds: start, preferredTimescale: 600),
            duration: CMTime(seconds: duration, preferredTimescale: 600)
        )

        do {
            let startTime = Date()
            logger.debug(
                "[\(label, privacy: .public)] 开始抽取: \(start, privacy: .public)s–\(start + duration, privacy: .public)s"
            )

            let buffer = try await extractor.extract(from: asset, timeRange: timeRange)

            let elapsed = Date().timeIntervalSince(startTime)
            logger.info(
                "[\(label, privacy: .public)] 抽取完成: 耗时=\(elapsed * 1000, privacy: .public)ms, 样本数=\(buffer.samples.count, privacy: .public)"
            )

            // 缓存
            let key = cacheKey(for: timeRange)
            cache[key] = buffer

        } catch {
            logger.error(
                "[\(label, privacy: .public)] 抽取失败: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    /// 生成缓存 key
    private func cacheKey(for timeRange: CMTimeRange) -> String {
        let startMs = Int(timeRange.start.seconds * 1000)
        let endMs = Int(timeRange.end.seconds * 1000)
        return "\(startMs)-\(endMs)"
    }
}
