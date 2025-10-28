import Foundation

@testable import PrismCore

/// Mock 指标采集器用于单元测试
/// Mock Metrics Collector for unit testing
///
/// 特性 / Features:
/// - 记录所有指标调用 / Records all metrics calls
/// - 可验证指标名称和值 / Verify metric names and values
/// - 提供查询接口 / Provides query interface
///
/// 使用示例 / Usage Example:
/// ```swift
/// let mockCollector = MockMetricsCollector()
/// await mockCollector.recordTiming("test.metric", duration: 1.5)
///
/// let called = await mockCollector.recordTimingCalled
/// XCTAssertTrue(called)
///
/// let lastName = await mockCollector.lastTimingName
/// XCTAssertEqual(lastName, "test.metric")
/// ```
///
/// - Created: Sprint 0, Task-009
/// - Last Updated: 2025-10-24
public actor MockMetricsCollector: MetricsCollector {
    // MARK: - Call Recording

    public private(set) var recordTimingCalled = false
    public private(set) var recordTimingCallCount = 0
    public private(set) var recordCountCalled = false
    public private(set) var recordCountCallCount = 0
    public private(set) var recordDistributionCalled = false
    public private(set) var recordDistributionCallCount = 0

    public private(set) var lastTimingName: String?
    public private(set) var lastTimingDuration: TimeInterval?
    public private(set) var lastTimingMetadata: [String: String]?

    public private(set) var lastCountName: String?
    public private(set) var lastCountValue: Int?
    public private(set) var lastCountMetadata: [String: String]?

    public private(set) var lastDistributionName: String?
    public private(set) var lastDistributionValue: Double?
    public private(set) var lastDistributionMetadata: [String: String]?

    // MARK: - Stored Metrics

    private var metrics: [Metric] = []

    // MARK: - Initialization

    public init() {}

    // MARK: - MetricsCollector Protocol

    public func recordTiming(
        _ name: String,
        duration: TimeInterval,
        metadata: [String: String]?
    ) async {
        recordTimingCalled = true
        recordTimingCallCount += 1
        lastTimingName = name
        lastTimingDuration = duration
        lastTimingMetadata = metadata

        let metric = Metric(
            type: .timing,
            name: name,
            value: duration,
            metadata: metadata,
            timestamp: Date()
        )
        metrics.append(metric)
    }

    public func recordCount(
        _ name: String,
        value: Int,
        metadata: [String: String]?
    ) async {
        recordCountCalled = true
        recordCountCallCount += 1
        lastCountName = name
        lastCountValue = value
        lastCountMetadata = metadata

        let metric = Metric(
            type: .count,
            name: name,
            value: Double(value),
            metadata: metadata,
            timestamp: Date()
        )
        metrics.append(metric)
    }

    public func recordDistribution(
        _ name: String,
        value: Double,
        metadata: [String: String]?
    ) async {
        recordDistributionCalled = true
        recordDistributionCallCount += 1
        lastDistributionName = name
        lastDistributionValue = value
        lastDistributionMetadata = metadata

        let metric = Metric(
            type: .distribution,
            name: name,
            value: value,
            metadata: metadata,
            timestamp: Date()
        )
        metrics.append(metric)
    }

    public func getMetrics(
        name: String?,
        startDate: Date?,
        endDate: Date?
    ) async -> [Metric] {
        var result = metrics

        if let name = name {
            result = result.filter { $0.name == name }
        }

        if let startDate = startDate {
            result = result.filter { $0.timestamp >= startDate }
        }

        if let endDate = endDate {
            result = result.filter { $0.timestamp <= endDate }
        }

        return result
    }

    public func getStatistics(for name: String) async -> Metric.Statistics? {
        let filtered = metrics.filter { $0.name == name }
        guard !filtered.isEmpty else { return nil }

        return Metric.Statistics.calculate(from: filtered)
    }

    public func cleanupMetrics(olderThan date: Date) async {
        metrics.removeAll { $0.timestamp < date }
    }

    public func getSummary() async -> MetricsSummary {
        return MetricsSummary(
            metrics: metrics,
            startDate: metrics.first?.timestamp ?? Date(),
            endDate: metrics.last?.timestamp ?? Date()
        )
    }

    // MARK: - Reset

    /// 重置所有状态和记录
    public func reset() {
        recordTimingCalled = false
        recordTimingCallCount = 0
        recordCountCalled = false
        recordCountCallCount = 0
        recordDistributionCalled = false
        recordDistributionCallCount = 0

        lastTimingName = nil
        lastTimingDuration = nil
        lastTimingMetadata = nil

        lastCountName = nil
        lastCountValue = nil
        lastCountMetadata = nil

        lastDistributionName = nil
        lastDistributionValue = nil
        lastDistributionMetadata = nil

        metrics.removeAll()
    }

    // MARK: - Verification Helpers

    /// 获取所有记录的指标
    public func getAllMetrics() -> [Metric] {
        return metrics
    }

    /// 获取指定名称的指标数量
    public func getMetricCount(name: String) -> Int {
        return metrics.filter { $0.name == name }.count
    }

    /// 验证是否记录过指定名称的指标
    public func hasMetric(name: String) -> Bool {
        return metrics.contains { $0.name == name }
    }

    /// 获取指定类型的指标
    public func getMetrics(ofType type: Metric.MetricType) -> [Metric] {
        return metrics.filter { $0.type == type }
    }
}
