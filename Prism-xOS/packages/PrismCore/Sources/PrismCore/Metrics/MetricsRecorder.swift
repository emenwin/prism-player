import Foundation
import OSLog

/// 字幕性能指标记录器
///
/// 提供 @MainActor 兼容的 API，用于在 ViewModel 中记录性能指标。
/// 内部使用 MetricsCollector actor 进行异步指标采集。
///
/// # 核心算法
/// - 使用 Task.detached 异步发送指标，避免阻塞主线程
/// - 维护内存中的百分位数计算（用于 P95/P99）
/// - 提供共享实例 `.shared` 用于全局指标收集
///
/// # 示例
/// ```swift
/// @MainActor
/// class SubtitleViewModel {
///     let metrics = MetricsRecorder.shared
///
///     func updateSubtitle() {
///         let start = CFAbsoluteTimeGetCurrent()
///         // ... 执行操作
///         let latency = (CFAbsoluteTimeGetCurrent() - start) * 1000
///         metrics.recordLatency(latency, key: "subtitle_update_ms")
///     }
/// }
/// ```
@MainActor
public final class MetricsRecorder {
    // MARK: - Shared Instance
    
    /// 共享实例
    public static let shared = MetricsRecorder()
    
    // MARK: - Properties
    
    /// 底层指标采集器
    private let collector: MetricsCollector
    
    /// 日志记录器
    private let logger = Logger(
        subsystem: "com.prismplayer.core",
        category: "metrics-recorder"
    )
    
    /// 内存中的延迟样本（用于计算百分位数）
    private var latencySamples: [String: [Double]] = [:]
    
    /// 最大样本数量（避免内存无限增长）
    private let maxSamplesPerKey = 1000
    
    // MARK: - Initialization
    
    /// 创建指标记录器
    ///
    /// - Parameter collector: 底层指标采集器，默认使用 LocalMetricsCollector
    nonisolated public init(collector: MetricsCollector? = nil) {
        self.collector = collector ?? LocalMetricsCollector()
    }
    
    // MARK: - Recording Methods
    
    /// 记录延迟指标（毫秒）
    ///
    /// 用于记录操作耗时，如字幕更新延迟、查找延迟等。
    ///
    /// - Parameters:
    ///   - latency: 延迟时间（毫秒）
    ///   - key: 指标键名
    ///   - metadata: 可选元数据
    public func recordLatency(
        _ latency: Double,
        key: String,
        metadata: [String: String]? = nil
    ) {
        // 更新本地样本
        if latencySamples[key] == nil {
            latencySamples[key] = []
        }
        
        latencySamples[key]?.append(latency)
        
        // 限制样本数量
        if let count = latencySamples[key]?.count, count > maxSamplesPerKey {
            latencySamples[key]?.removeFirst(count - maxSamplesPerKey)
        }
        
        // 异步记录到采集器
        Task.detached { [collector, logger] in
            await collector.recordTiming(key, duration: latency / 1000.0, metadata: metadata)
            logger.debug("Recorded latency: \(key) = \(latency)ms")
        }
    }
    
    /// 记录偏差指标（毫秒）
    ///
    /// 用于记录时间同步偏差，如字幕与播放器时钟的偏差。
    ///
    /// - Parameters:
    ///   - deviation: 偏差时间（毫秒）
    ///   - key: 指标键名
    ///   - metadata: 可选元数据
    public func recordDeviation(
        _ deviation: Double,
        key: String,
        metadata: [String: String]? = nil
    ) {
        // 更新本地样本
        if latencySamples[key] == nil {
            latencySamples[key] = []
        }
        
        latencySamples[key]?.append(deviation)
        
        // 限制样本数量
        if let count = latencySamples[key]?.count, count > maxSamplesPerKey {
            latencySamples[key]?.removeFirst(count - maxSamplesPerKey)
        }
        
        // 异步记录到采集器
        Task.detached { [collector, logger] in
            await collector.recordDistribution(key, value: deviation, metadata: metadata)
            logger.debug("Recorded deviation: \(key) = \(deviation)ms")
        }
    }
    
    /// 记录计数指标
    ///
    /// 用于记录次数或数量，如字幕总数、更新次数等。
    ///
    /// - Parameters:
    ///   - count: 计数值
    ///   - key: 指标键名
    ///   - metadata: 可选元数据
    public func recordCount(
        _ count: Int,
        key: String,
        metadata: [String: String]? = nil
    ) {
        Task.detached { [collector, logger] in
            await collector.recordCount(key, value: count, metadata: metadata)
            logger.debug("Recorded count: \(key) = \(count)")
        }
    }
    
    // MARK: - Query Methods
    
    /// 获取指定键的百分位数
    ///
    /// - Parameters:
    ///   - key: 指标键名
    ///   - percentile: 百分位数（0.0 - 1.0），如 0.95 表示 P95
    /// - Returns: 百分位数值，如果无数据则返回 nil
    public func getPercentile(key: String, percentile: Double) -> Double? {
        guard let samples = latencySamples[key], !samples.isEmpty else {
            return nil
        }
        
        let sorted = samples.sorted()
        let index = Int(Double(sorted.count) * percentile)
        let clampedIndex = min(index, sorted.count - 1)
        
        return sorted[clampedIndex]
    }
    
    /// 获取指定键的平均值
    ///
    /// - Parameter key: 指标键名
    /// - Returns: 平均值，如果无数据则返回 nil
    public func getAverage(key: String) -> Double? {
        guard let samples = latencySamples[key], !samples.isEmpty else {
            return nil
        }
        
        return samples.reduce(0.0, +) / Double(samples.count)
    }
    
    /// 获取指定键的最大值
    ///
    /// - Parameter key: 指标键名
    /// - Returns: 最大值，如果无数据则返回 nil
    public func getMax(key: String) -> Double? {
        latencySamples[key]?.max()
    }
    
    /// 获取指定键的最小值
    ///
    /// - Parameter key: 指标键名
    /// - Returns: 最小值，如果无数据则返回 nil
    public func getMin(key: String) -> Double? {
        latencySamples[key]?.min()
    }
    
    /// 获取指标摘要
    ///
    /// - Parameter key: 指标键名
    /// - Returns: 包含统计信息的字符串
    public func getSummary(key: String) -> String? {
        guard let samples = latencySamples[key], !samples.isEmpty else {
            return nil
        }
        
        let avg = getAverage(key: key) ?? 0
        let p50 = getPercentile(key: key, percentile: 0.5) ?? 0
        let p95 = getPercentile(key: key, percentile: 0.95) ?? 0
        let p99 = getPercentile(key: key, percentile: 0.99) ?? 0
        let max = getMax(key: key) ?? 0
        
        return """
        \(key) (n=\(samples.count)):
          Avg: \(String(format: "%.2f", avg))ms
          P50: \(String(format: "%.2f", p50))ms
          P95: \(String(format: "%.2f", p95))ms
          P99: \(String(format: "%.2f", p99))ms
          Max: \(String(format: "%.2f", max))ms
        """
    }
    
    // MARK: - Management Methods
    
    /// 重置所有样本
    public func reset() {
        latencySamples.removeAll()
        logger.info("MetricsRecorder reset")
    }
    
    /// 重置指定键的样本
    ///
    /// - Parameter key: 指标键名
    public func reset(key: String) {
        latencySamples.removeValue(forKey: key)
        logger.debug("Reset metrics for key: \(key)")
    }
}
