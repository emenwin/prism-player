import Foundation

/// 语音识别片段模型（AsrSegment）
///
/// 表示一次识别产生的一段带时间戳的文本结果。
/// - 线程安全：不可变值类型（Sendable）
/// - 编码：支持 Codable，便于持久化与传输
public struct AsrSegment: Sendable, Codable, Equatable {
    /// 媒体唯一标识（用于跨组件追踪）
    public let mediaId: String

    /// 片段开始时间（秒）
    public let startTime: Double

    /// 片段结束时间（秒）
    public let endTime: Double

    /// 识别文本内容（已本地化的原文，UI 层负责国际化展示）
    public let text: String

    /// 置信度（0.0~1.0），仅供参考
    public let confidence: Double

    /// 初始化识别片段
    /// - Parameters:
    ///   - mediaId: 媒体唯一标识
    ///   - startTime: 开始时间（秒）
    ///   - endTime: 结束时间（秒）
    ///   - text: 文本内容
    ///   - confidence: 置信度（0.0~1.0）
    public init(
        mediaId: String,
        startTime: Double,
        endTime: Double,
        text: String,
        confidence: Double
    ) {
        self.mediaId = mediaId
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.confidence = confidence
    }
}
