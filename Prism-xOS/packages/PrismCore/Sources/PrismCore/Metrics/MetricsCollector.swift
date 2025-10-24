import Foundation

/// 性能指标采集器协议
/// Performance metrics collector protocol
public protocol MetricsCollector: Actor {
    /// 记录计时指标
    /// Record timing metric
    /// - Parameters:
    ///   - name: 指标名称
    ///   - duration: 耗时（秒）
    ///   - metadata: 元数据（可选）
    func recordTiming(
        _ name: String,
        duration: TimeInterval,
        metadata: [String: String]?
    ) async

    /// 记录计数指标
    /// Record count metric
    /// - Parameters:
    ///   - name: 指标名称
    ///   - value: 计数值
    ///   - metadata: 元数据（可选）
    func recordCount(
        _ name: String,
        value: Int,
        metadata: [String: String]?
    ) async

    /// 记录分布指标
    /// Record distribution metric
    /// - Parameters:
    ///   - name: 指标名称
    ///   - value: 数值
    ///   - metadata: 元数据（可选）
    func recordDistribution(
        _ name: String,
        value: Double,
        metadata: [String: String]?
    ) async

    /// 查询指标
    /// Query metrics
    /// - Parameters:
    ///   - name: 指标名称（可选，nil 表示所有）
    ///   - startDate: 开始时间（可选）
    ///   - endDate: 结束时间（可选）
    /// - Returns: 指标列表
    func getMetrics(
        name: String?,
        startDate: Date?,
        endDate: Date?
    ) async -> [Metric]

    /// 获取指标统计信息
    /// Get metric statistics
    /// - Parameter name: 指标名称
    /// - Returns: 统计信息（如果有数据）
    func getStatistics(for name: String) async -> Metric.Statistics?

    /// 清理旧指标
    /// Clean up old metrics
    /// - Parameter olderThan: 保留此日期之后的数据
    func cleanupMetrics(olderThan date: Date) async

    /// 获取指标摘要（用于诊断报告）
    /// Get metrics summary (for diagnostic reports)
    /// - Returns: 指标摘要
    func getSummary() async -> MetricsSummary
}

// MARK: - Default Implementations

extension MetricsCollector {
    /// 记录计时指标（无元数据）
    public func recordTiming(_ name: String, duration: TimeInterval) async {
        await recordTiming(name, duration: duration, metadata: nil)
    }

    /// 记录计数指标（无元数据）
    public func recordCount(_ name: String, value: Int) async {
        await recordCount(name, value: value, metadata: nil)
    }

    /// 记录分布指标（无元数据）
    public func recordDistribution(_ name: String, value: Double) async {
        await recordDistribution(name, value: value, metadata: nil)
    }

    /// 查询所有指标
    public func getAllMetrics() async -> [Metric] {
        await getMetrics(name: nil, startDate: nil, endDate: nil)
    }

    /// 查询指定名称的指标
    public func getMetrics(name: String) async -> [Metric] {
        await getMetrics(name: name, startDate: nil, endDate: nil)
    }
}

// MARK: - Shared Instance

/// 共享指标采集器
/// Shared metrics collector
public actor SharedMetricsCollector {
    public static let shared: MetricsCollector = LocalMetricsCollector()
}
