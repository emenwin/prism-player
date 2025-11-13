import Foundation

/// 字幕数据模型
///
/// 表示单个字幕段落，包含文本内容、时间范围和置信度等信息。
/// 用于在播放器中显示实时字幕或离线识别的字幕内容。
///
/// # 核心算法
/// - `contains(_:tolerance:)` 方法使用时间范围匹配，支持容差以适应播放器时钟的微小偏差
/// - 通过 `Equatable` 基于 `id` 进行比较，避免不必要的 UI 重绘
///
/// # 示例
/// ```swift
/// let subtitle = Subtitle(
///     id: UUID(),
///     text: "你好，世界",
///     startTime: 5.0,
///     endTime: 8.0,
///     confidence: 0.95
/// )
///
/// // 检查时间点是否在字幕范围内
/// subtitle.contains(6.0)  // true
/// subtitle.contains(5.0 - 0.03, tolerance: 0.05)  // true (在容差内)
/// subtitle.contains(4.0)  // false
/// ```
public struct Subtitle: Identifiable, Equatable, Codable, Sendable {
    // MARK: - Properties

    /// 唯一标识符
    public let id: UUID

    /// 字幕文本内容
    public let text: String

    /// 字幕开始时间（秒）
    public let startTime: TimeInterval

    /// 字幕结束时间（秒）
    public let endTime: TimeInterval

    /// 识别置信度（0.0 - 1.0），可选
    ///
    /// 用于评估字幕质量，未来可用于：
    /// - 过滤低置信度字幕
    /// - UI 样式调整（低置信度显示为半透明）
    /// - 优先重新识别低置信度片段
    public let confidence: Double?

    // MARK: - Computed Properties

    /// 字幕持续时间（秒）
    public var duration: TimeInterval {
        endTime - startTime
    }

    // MARK: - Initialization

    /// 创建字幕实例
    ///
    /// - Parameters:
    ///   - id: 唯一标识符，默认生成新 UUID
    ///   - text: 字幕文本内容
    ///   - startTime: 开始时间（秒）
    ///   - endTime: 结束时间（秒）
    ///   - confidence: 识别置信度（0.0 - 1.0），可选
    public init(
        id: UUID = UUID(),
        text: String,
        startTime: TimeInterval,
        endTime: TimeInterval,
        confidence: Double? = nil
    ) {
        self.id = id
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.confidence = confidence
    }

    // MARK: - Methods

    /// 检查指定时间是否在字幕范围内
    ///
    /// # 算法说明
    /// 使用半开区间 `[startTime - tolerance, endTime + tolerance)` 进行匹配：
    /// - 容差用于适应播放器时钟的微小偏差（如 ±50ms）
    /// - 使用 `<` 而非 `<=` 避免两个连续字幕在边界重叠
    ///
    /// - Parameters:
    ///   - time: 待检查的时间点（秒）
    ///   - tolerance: 时间容差（秒），默认 50ms
    /// - Returns: `true` 如果时间在字幕范围内（含容差）
    public func contains(_ time: TimeInterval, tolerance: TimeInterval = 0.05) -> Bool {
        (startTime - tolerance) <= time && time < (endTime + tolerance)
    }

    // MARK: - Equatable

    /// 基于 ID 判断两个字幕是否相同
    ///
    /// 仅比较 `id`，避免比较文本内容导致的性能开销。
    /// 用于 SwiftUI 视图更新时判断字幕是否发生变化。
    public static func == (lhs: Subtitle, rhs: Subtitle) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Extensions

extension Subtitle: CustomStringConvertible {
    public var description: String {
        let confidenceStr = confidence.map { String(format: " (%.0f%%)", $0 * 100) } ?? ""
        return
            "Subtitle[\(String(id.uuidString.prefix(8)))]: \"\(text)\" [\(startTime)s - \(endTime)s]\(confidenceStr)"
    }
}

extension Subtitle {
    /// 创建用于测试的字幕实例
    ///
    /// - Parameters:
    ///   - text: 字幕文本
    ///   - start: 开始时间（秒）
    ///   - end: 结束时间（秒）
    /// - Returns: 测试用字幕实例
    public static func mock(text: String, start: TimeInterval, end: TimeInterval) -> Subtitle {
        Subtitle(id: UUID(), text: text, startTime: start, endTime: end, confidence: 0.95)
    }
}
