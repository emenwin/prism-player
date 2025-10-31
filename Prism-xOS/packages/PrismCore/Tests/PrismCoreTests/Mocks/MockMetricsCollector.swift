import Foundation
import PrismCore

/// Mock 指标采集器 - 包内测试版本
public actor MockMetricsCollector: MetricsCollector {
    public private(set) var recordTimingCalled = false
    public private(set) var lastTimingName: String?
    public private(set) var lastTimingDuration: TimeInterval?

    public private(set) var recordCountCalled = false
    public private(set) var lastCountName: String?
    public private(set) var lastCountValue: Int?

    public private(set) var recordDistributionCalled = false
    public private(set) var lastDistributionName: String?
    public private(set) var lastDistributionValue: Double?
    public private(set) var lastDistributionMetadata: [String: String]?

    private var metrics: [Metric] = []

    public init() {}

    public func recordTiming(_ name: String, duration: TimeInterval, metadata: [String: String]?)
        async
    {
        recordTimingCalled = true
        lastTimingName = name
        lastTimingDuration = duration

        let metric = Metric(
            name: name, type: .timing, value: duration, metadata: metadata, timestamp: Date())
        metrics.append(metric)
    }

    public func recordCount(_ name: String, value: Int, metadata: [String: String]?) async {
        recordCountCalled = true
        lastCountName = name
        lastCountValue = value

        let metric = Metric(
            name: name, type: .count, value: Double(value), metadata: metadata, timestamp: Date())
        metrics.append(metric)
    }

    public func recordDistribution(_ name: String, value: Double, metadata: [String: String]?) async
    {
        recordDistributionCalled = true
        lastDistributionName = name
        lastDistributionValue = value
        lastDistributionMetadata = metadata

        let metric = Metric(
            name: name, type: .distribution, value: value, metadata: metadata, timestamp: Date())
        metrics.append(metric)
    }

    public func getMetrics(name: String?, startDate: Date?, endDate: Date?) async -> [Metric] {
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
        let values = filtered.map { $0.value }
        return Metric.Statistics(values: values)
    }

    public func cleanupMetrics(olderThan date: Date) async {
        metrics.removeAll { $0.timestamp < date }
    }

    public func getSummary() async -> MetricsSummary {
        let firstFrameStats = await getStatistics(for: Metric.FirstFrame.total)
        let rtfMetrics = await getMetrics(name: Metric.RTF.overall, startDate: nil, endDate: nil)
        let timeOffsetStats = await getStatistics(for: Metric.TimeSync.absoluteOffset)
        let memoryMetrics = await getMetrics(
            name: Metric.Resource.memoryPeak, startDate: nil, endDate: nil)

        return MetricsSummary(
            firstFrameP95: firstFrameStats?.p95,
            rtfDistribution: rtfMetrics.map { $0.value },
            timeOffsetP95: timeOffsetStats?.p95,
            memoryPeak: memoryMetrics.map { $0.value }.max(),
            totalMetrics: metrics.count
        )
    }

    public func hasMetric(name: String) -> Bool {
        return metrics.contains { $0.name == name }
    }

    public func getAllMetrics() -> [Metric] {
        return metrics
    }

    public func getMetricCount(name: String) -> Int {
        return metrics.filter { $0.name == name }.count
    }

    public func reset() {
        recordTimingCalled = false
        lastTimingName = nil
        lastTimingDuration = nil
        recordCountCalled = false
        lastCountName = nil
        lastCountValue = nil
        recordDistributionCalled = false
        lastDistributionName = nil
        lastDistributionValue = nil
        lastDistributionMetadata = nil
        metrics.removeAll()
    }
}
