import Foundation
import GRDB

/// ASR 识别结果片段
///
/// 表示语音转文字识别的单个时间片段，包含时间戳、文本内容及可选的置信度。
/// 支持数据库持久化。
public struct AsrSegment: Identifiable, Codable, Sendable {
    /// 唯一标识符
    public let id: UUID

    /// 所属媒体文件 ID
    public var mediaId: String

    /// 开始时间（秒）
    public let startTime: TimeInterval

    /// 结束时间（秒）
    public let endTime: TimeInterval

    /// 识别文本内容
    public let text: String

    /// 置信度（0.0-1.0），可选
    public let confidence: Double?

    /// 创建时间（Unix timestamp）
    public var createdAt: Int64

    /// 初始化 ASR 片段
    /// - Parameters:
    ///   - id: 唯一标识符，默认生成新 UUID
    ///   - mediaId: 所属媒体文件 ID
    ///   - startTime: 开始时间（秒）
    ///   - endTime: 结束时间（秒）
    ///   - text: 识别文本
    ///   - confidence: 置信度，范围 0.0-1.0
    ///   - createdAt: 创建时间，默认当前时间
    public init(
        id: UUID = UUID(),
        mediaId: String,
        startTime: TimeInterval,
        endTime: TimeInterval,
        text: String,
        confidence: Double? = nil,
        createdAt: Int64 = Int64(Date().timeIntervalSince1970)
    ) {
        self.id = id
        self.mediaId = mediaId
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.confidence = confidence
        self.createdAt = createdAt
    }
}

// MARK: - GRDB 集成

extension AsrSegment: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "subtitle_segments"

    /// 定义数据库列
    public enum Columns: String, ColumnExpression {
        case id
        case mediaId = "media_id"
        case startTime = "start_time"
        case endTime = "end_time"
        case text
        case confidence
        case createdAt = "created_at"
    }

    /// 自定义编码（UUID → String）
    public func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id.uuidString
        container[Columns.mediaId] = mediaId
        container[Columns.startTime] = startTime
        container[Columns.endTime] = endTime
        container[Columns.text] = text
        container[Columns.confidence] = confidence
        container[Columns.createdAt] = createdAt
    }
}

// MARK: - Computed Properties
extension AsrSegment {
    /// 片段时长（秒）
    public var duration: TimeInterval {
        endTime - startTime
    }

    /// 是否为高置信度（>= 0.8）
    public var isHighConfidence: Bool {
        confidence ?? 0.0 >= 0.8
    }
}
