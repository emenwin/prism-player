import Foundation

/// 预加载策略配置
///
/// 职责：
/// - 定义音频预加载行为参数
/// - 提供多档位预设（conservative/default/aggressive）
/// - 支持自定义配置
///
/// 核心参数说明：
/// - **预加载时长**：媒体加载后预先抽取的音频时长
/// - **首帧快速窗口**：优先抽取的快速窗口时长（用于极速首帧）
/// - **滚动识别段长**：滚动识别时每段的时长
/// - **内存缓存上限**：音频缓存的最大内存占用
///
/// 三档位对比：
/// ```
/// | 策略         | 预加载 | 首帧窗口 | 内存上限 | 适用场景      |
/// |-------------|--------|----------|---------|---------------|
/// | conservative| 10s    | 5s       | 5 MB    | 低端设备      |
/// | default     | 30s    | 10s      | 10 MB   | 推荐（中端）  |
/// | aggressive  | 60s    | 10s      | 20 MB   | 高端设备      |
/// ```
///
/// 参考：
/// - Task-102 §1.1 目标（可量化）
/// - Task-102 §3.1.2 PreloadStrategy 配置
public struct PreloadStrategy: Sendable, Equatable {
    /// 预加载时长（秒）
    ///
    /// 说明：
    /// - 媒体加载后，预先抽取的音频时长
    /// - 默认 30s，可覆盖大多数短视频场景
    /// - 高端设备可增加至 60s（提升滚动流畅度）
    /// - 低端设备可降至 10s（减少内存压力）
    public let preloadDuration: TimeInterval
    
    /// 首帧快速窗口时长（秒）
    ///
    /// 说明：
    /// - 首次加载时，优先抽取的快速窗口时长
    /// - 默认 10s，实测可满足 P95 < 5s 目标
    /// - 采用双路并行策略：
    ///   - 路径 A：前 5s → 极速首帧（立即送 ASR）
    ///   - 路径 B：5–10s → 补充首屏（ASR 队列）
    public let fastFirstFrameDuration: TimeInterval
    
    /// 滚动识别段长（秒）
    ///
    /// 说明：
    /// - 滚动识别时每段的时长
    /// - 默认 20s，兼顾识别准确度和延迟
    /// - 过短：上下文不足，WER 上升
    /// - 过长：首字延迟增加
    public let segmentDuration: TimeInterval
    
    /// 内存缓存上限（MB）
    ///
    /// 说明：
    /// - 音频缓存的最大内存占用
    /// - 默认 10 MB ≈ 156s 音频（16kHz mono Float32）
    /// - 触发 LRU 淘汰：保留当前播放 ±30s，清理更远的缓存
    /// - 内存压力时：按三级策略清理（±60s/±30s/±15s）
    public let maxCacheSizeMB: Int
    
    // MARK: - 预设策略
    
    /// 默认策略（推荐）
    ///
    /// - 预加载：30s
    /// - 首帧窗口：10s
    /// - 滚动段长：20s
    /// - 内存上限：10 MB
    ///
    /// 适用场景：
    /// - 中端设备（iPhone 13, M1 MacBook Air）
    /// - 短视频（10–60s）
    /// - 日常使用
    public static let `default` = PreloadStrategy(
        preloadDuration: 30,
        fastFirstFrameDuration: 10,
        segmentDuration: 20,
        maxCacheSizeMB: 10
    )
    
    /// 激进策略
    ///
    /// - 预加载：60s
    /// - 首帧窗口：10s
    /// - 滚动段长：30s
    /// - 内存上限：20 MB
    ///
    /// 适用场景：
    /// - 高端设备（iPhone 15 Pro, M3 MacBook Pro）
    /// - 长视频（60min+）
    /// - 流畅度优先
    public static let aggressive = PreloadStrategy(
        preloadDuration: 60,
        fastFirstFrameDuration: 10,
        segmentDuration: 30,
        maxCacheSizeMB: 20
    )
    
    /// 保守策略
    ///
    /// - 预加载：10s
    /// - 首帧窗口：5s
    /// - 滚动段长：15s
    /// - 内存上限：5 MB
    ///
    /// 适用场景：
    /// - 低端设备（iPhone SE 3rd, Intel MacBook Pro 2019）
    /// - 内存受限环境
    /// - 省电模式
    public static let conservative = PreloadStrategy(
        preloadDuration: 10,
        fastFirstFrameDuration: 5,
        segmentDuration: 15,
        maxCacheSizeMB: 5
    )
    
    // MARK: - 初始化
    
    /// 自定义策略
    /// - Parameters:
    ///   - preloadDuration: 预加载时长（秒）
    ///   - fastFirstFrameDuration: 首帧快速窗口时长（秒）
    ///   - segmentDuration: 滚动识别段长（秒）
    ///   - maxCacheSizeMB: 内存缓存上限（MB）
    public init(
        preloadDuration: TimeInterval,
        fastFirstFrameDuration: TimeInterval,
        segmentDuration: TimeInterval,
        maxCacheSizeMB: Int
    ) {
        self.preloadDuration = preloadDuration
        self.fastFirstFrameDuration = fastFirstFrameDuration
        self.segmentDuration = segmentDuration
        self.maxCacheSizeMB = maxCacheSizeMB
    }
    
    // MARK: - 计算属性
    
    /// 最大缓存字节数
    ///
    /// 计算公式：
    /// ```
    /// maxCacheSizeBytes = maxCacheSizeMB × 1024 × 1024
    /// ```
    public var maxCacheSizeBytes: Int {
        maxCacheSizeMB * 1024 * 1024
    }
    
    /// 最大缓存时长（秒）
    ///
    /// 计算公式：
    /// ```
    /// 16kHz × 1ch × 4bytes = 64 KB/s
    /// maxCacheDuration = maxCacheSizeBytes / 64000
    /// ```
    ///
    /// 示例：
    /// - 10 MB → 156s
    /// - 20 MB → 312s
    /// - 5 MB → 78s
    public var maxCacheDuration: TimeInterval {
        Double(maxCacheSizeBytes) / 64000.0
    }
}

// MARK: - CustomStringConvertible

extension PreloadStrategy: CustomStringConvertible {
    public var description: String {
        """
        PreloadStrategy(
            preloadDuration: \(preloadDuration)s,
            fastFirstFrameDuration: \(fastFirstFrameDuration)s,
            segmentDuration: \(segmentDuration)s,
            maxCacheSizeMB: \(maxCacheSizeMB) MB ≈ \(String(format: "%.1f", maxCacheDuration))s
        )
        """
    }
}
