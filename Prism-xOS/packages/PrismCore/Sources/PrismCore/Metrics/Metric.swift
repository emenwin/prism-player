import Foundation

/// 指标类型枚举
/// Metric type enumeration
public enum MetricType: String, Codable {
    /// 计时指标（耗时）
    case timing

    /// 计数指标（次数）
    case count

    /// 分布指标（数值分布）
    case distribution
}

/// 指标数据结构
/// Metric data structure
public struct Metric: Codable, Identifiable {
    /// 唯一标识
    public let id: UUID

    /// 指标名称
    public let name: String

    /// 指标类型
    public let type: MetricType

    /// 指标值
    public let value: Double

    /// 元数据（可选）
    public let metadata: [String: String]?

    /// 记录时间
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        name: String,
        type: MetricType,
        value: Double,
        metadata: [String: String]? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.value = value
        self.metadata = metadata
        self.timestamp = timestamp
    }
}

// MARK: - Metric Statistics

extension Metric {
    /// 指标统计信息
    /// Metric statistics
    public struct Statistics {
        public let count: Int
        public let min: Double
        public let max: Double
        public let mean: Double
        public let p50: Double  // Median
        public let p95: Double
        public let p99: Double

        public init(values: [Double]) {
            self.count = values.count

            guard !values.isEmpty else {
                self.min = 0
                self.max = 0
                self.mean = 0
                self.p50 = 0
                self.p95 = 0
                self.p99 = 0
                return
            }

            let sorted = values.sorted()
            self.min = sorted.first!
            self.max = sorted.last!
            self.mean = values.reduce(0, +) / Double(values.count)

            // 计算分位数
            func percentile(_ p: Double) -> Double {
                let index = Int(Double(sorted.count) * p)
                let clampedIndex = Swift.min(index, sorted.count - 1)
                return sorted[clampedIndex]
            }

            self.p50 = percentile(0.50)
            self.p95 = percentile(0.95)
            self.p99 = percentile(0.99)
        }
    }
}

// MARK: - Metric Category Extensions

extension Metric {
    /// 首帧指标名称常量
    /// First frame metric name constants
    public enum FirstFrame {
        public static let total = "subtitle.first_frame.total"
        public static let audioExtraction = "subtitle.first_frame.audio_extraction"
        public static let asrInference = "subtitle.first_frame.asr_inference"
        public static let rendering = "subtitle.first_frame.rendering"
    }

    /// RTF 指标名称常量
    /// RTF metric name constants
    public enum RTF {
        public static let overall = "asr.rtf"
        public static let perSegment = "asr.rtf.segment"
    }

    /// 时间同步指标名称常量
    /// Time synchronization metric name constants
    public enum TimeSync {
        public static let offset = "subtitle.time_offset"
        public static let absoluteOffset = "subtitle.time_offset.absolute"
    }

    /// 资源指标名称常量
    /// Resource metric name constants
    public enum Resource {
        public static let memoryPeak = "resource.memory.peak"
        public static let memoryAverage = "resource.memory.average"
        public static let cacheSize = "resource.cache.size"
        public static let diskSpace = "resource.disk.available"
    }

    /// 质量指标名称常量
    /// Quality metric name constants
    public enum Quality {
        public static let confidence = "asr.confidence"
        public static let segmentSuccess = "asr.segment.success"
        public static let segmentFailure = "asr.segment.failure"
        public static let exportSuccess = "export.success"
        public static let exportFailure = "export.failure"
    }
}

// MARK: - Convenience Initializers

extension Metric {
    /// 创建计时指标
    /// Create timing metric
    public static func timing(
        _ name: String,
        duration: TimeInterval,
        metadata: [String: String]? = nil
    ) -> Metric {
        Metric(
            name: name,
            type: .timing,
            value: duration * 1_000,  // 转换为毫秒
            metadata: metadata
        )
    }

    /// 创建计数指标
    /// Create count metric
    public static func count(
        _ name: String,
        value: Int,
        metadata: [String: String]? = nil
    ) -> Metric {
        Metric(
            name: name,
            type: .count,
            value: Double(value),
            metadata: metadata
        )
    }

    /// 创建分布指标
    /// Create distribution metric
    public static func distribution(
        _ name: String,
        value: Double,
        metadata: [String: String]? = nil
    ) -> Metric {
        Metric(
            name: name,
            type: .distribution,
            value: value,
            metadata: metadata
        )
    }
}
