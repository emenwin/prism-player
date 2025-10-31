import Foundation
import OSLog

/// 本地指标采集器实现
/// Local metrics collector implementation
///
/// 使用 UserDefaults 进行轻量级持久化存储
/// Uses UserDefaults for lightweight persistent storage
public actor LocalMetricsCollector: MetricsCollector {
    // MARK: - Properties

    /// 内存中的指标存储
    private var metrics: [Metric] = []

    /// UserDefaults 键
    private let userDefaultsKey = "com.prismplayer.metrics"

    /// 最大保留天数
    private let maxRetentionDays: Int

    /// 日志器
    private let logger = Logger.performance

    // MARK: - Initialization

    public init(maxRetentionDays: Int = 7) {
        self.maxRetentionDays = maxRetentionDays

        // 从持久化存储加载
        Task {
            await loadMetrics()
        }
    }

    // MARK: - MetricsCollector Protocol

    public func recordTiming(
        _ name: String,
        duration: TimeInterval,
        metadata: [String: String]?
    ) async {
        let metric = Metric.timing(name, duration: duration, metadata: metadata)
        await addMetric(metric)

        logger.debug(
            "Recorded timing: \(name) = \(duration * 1_000, format: .fixed(precision: 1))ms")
    }

    public func recordCount(
        _ name: String,
        value: Int,
        metadata: [String: String]?
    ) async {
        let metric = Metric.count(name, value: value, metadata: metadata)
        await addMetric(metric)

        logger.debug("Recorded count: \(name) = \(value)")
    }

    public func recordDistribution(
        _ name: String,
        value: Double,
        metadata: [String: String]?
    ) async {
        let metric = Metric.distribution(name, value: value, metadata: metadata)
        await addMetric(metric)

        logger.debug("Recorded distribution: \(name) = \(value, format: .fixed(precision: 2))")
    }

    public func getMetrics(
        name: String?,
        startDate: Date?,
        endDate: Date?
    ) async -> [Metric] {
        var filtered = metrics

        // 按名称过滤
        if let name = name {
            filtered = filtered.filter { $0.name == name }
        }

        // 按时间范围过滤
        if let startDate = startDate {
            filtered = filtered.filter { $0.timestamp >= startDate }
        }

        if let endDate = endDate {
            filtered = filtered.filter { $0.timestamp <= endDate }
        }

        return filtered
    }

    public func getStatistics(for name: String) async -> Metric.Statistics? {
        let namedMetrics = await getMetrics(name: name)

        guard !namedMetrics.isEmpty else {
            return nil
        }

        let values = namedMetrics.map { $0.value }
        return Metric.Statistics(values: values)
    }

    public func cleanupMetrics(olderThan date: Date) async {
        let oldCount = metrics.count
        metrics.removeAll { $0.timestamp < date }
        let removedCount = oldCount - metrics.count

        if removedCount > 0 {
            logger.info("Cleaned up \(removedCount) old metrics")
            await saveMetrics()
        }
    }

    // MARK: - Private Methods

    /// 添加指标并持久化
    private func addMetric(_ metric: Metric) async {
        metrics.append(metric)

        // 定期清理（每 100 个指标检查一次）
        if metrics.count % 100 == 0 {
            let cutoffDate = Date().addingTimeInterval(
                -TimeInterval(maxRetentionDays * 24 * 60 * 60))
            await cleanupMetrics(olderThan: cutoffDate)
        }

        // 异步保存（避免阻塞）
        Task {
            await saveMetrics()
        }
    }

    /// 从持久化存储加载指标
    private func loadMetrics() async {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            logger.debug("No persisted metrics found")
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            self.metrics = try decoder.decode([Metric].self, from: data)
            logger.info("Loaded \(self.metrics.count) metrics from storage")

            // 加载后立即清理过期数据
            let cutoffDate = Date().addingTimeInterval(
                -TimeInterval(maxRetentionDays * 24 * 60 * 60))
            await cleanupMetrics(olderThan: cutoffDate)
        } catch {
            logger.error("Failed to load metrics: \(error.localizedDescription)")
            self.metrics = []
        }
    }

    /// 保存指标到持久化存储
    private func saveMetrics() async {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(self.metrics)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            logger.debug("Saved \(self.metrics.count) metrics to storage")
        } catch {
            logger.error("Failed to save metrics: \(error.localizedDescription)")
        }
    }
}

// MARK: - Convenience Methods

extension LocalMetricsCollector {
    /// 获取指标摘要
    /// Get metrics summary
    public func getSummary() async -> MetricsSummary {
        let firstFrameStats = await getStatistics(for: Metric.FirstFrame.total)
        let rtfMetrics = await getMetrics(name: Metric.RTF.overall)
        let timeOffsetStats = await getStatistics(for: Metric.TimeSync.absoluteOffset)
        let memoryMetrics = await getMetrics(name: Metric.Resource.memoryPeak)

        return MetricsSummary(
            firstFrameP95: firstFrameStats?.p95,
            rtfDistribution: rtfMetrics.map { $0.value },
            timeOffsetP95: timeOffsetStats?.p95,
            memoryPeak: memoryMetrics.map { $0.value }.max(),
            totalMetrics: metrics.count
        )
    }

    /// 导出指标为 JSON
    /// Export metrics as JSON
    public func exportJSON(startDate: Date? = nil, endDate: Date? = nil) async throws -> Data {
        let filtered = await getMetrics(name: nil, startDate: startDate, endDate: endDate)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        return try encoder.encode(filtered)
    }
}

// MARK: - Metrics Summary

/// 指标摘要
/// Metrics summary for diagnostic reports
public struct MetricsSummary: Codable {
    public let firstFrameP95: Double?
    public let rtfDistribution: [Double]
    public let timeOffsetP95: Double?
    public let memoryPeak: Double?
    public let totalMetrics: Int

    public init(
        firstFrameP95: Double?,
        rtfDistribution: [Double],
        timeOffsetP95: Double?,
        memoryPeak: Double?,
        totalMetrics: Int
    ) {
        self.firstFrameP95 = firstFrameP95
        self.rtfDistribution = rtfDistribution
        self.timeOffsetP95 = timeOffsetP95
        self.memoryPeak = memoryPeak
        self.totalMetrics = totalMetrics
    }
}
