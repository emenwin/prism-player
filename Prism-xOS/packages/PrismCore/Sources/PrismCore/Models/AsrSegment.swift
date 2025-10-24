import Foundation

/// ASR 识别结果片段
///
/// 表示语音转文字识别的单个时间片段，包含时间戳、文本内容及可选的置信度。
public struct AsrSegment: Identifiable, Codable, Sendable {
    /// 唯一标识符
    public let id: UUID

    /// 开始时间（秒）
    public let startTime: TimeInterval

    /// 结束时间（秒）
    public let endTime: TimeInterval

    /// 识别文本内容
    public let text: String

    /// 置信度（0.0-1.0），可选
    public let confidence: Double?

    /// 初始化 ASR 片段
    /// - Parameters:
    ///   - id: 唯一标识符，默认生成新 UUID
    ///   - startTime: 开始时间（秒）
    ///   - endTime: 结束时间（秒）
    ///   - text: 识别文本
    ///   - confidence: 置信度，范围 0.0-1.0
    public init(
        id: UUID = UUID(),
        startTime: TimeInterval,
        endTime: TimeInterval,
        text: String,
        confidence: Double? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.confidence = confidence
    }
}

// MARK: - Computed Properties
public extension AsrSegment {
    /// 片段时长（秒）
    var duration: TimeInterval {
        endTime - startTime
    }

    /// 是否为高置信度（>= 0.8）
    var isHighConfidence: Bool {
        confidence ?? 0.0 >= 0.8
    }
}
