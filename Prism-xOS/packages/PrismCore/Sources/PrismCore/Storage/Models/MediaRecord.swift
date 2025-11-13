import Foundation
import GRDB

/// 媒体文件记录
///
/// 存储已导入媒体文件的元数据和识别进度
public struct MediaRecord: Codable, Sendable {
    /// 唯一标识符
    public var id: String

    /// 文件路径（绝对路径）
    public var filePath: String

    /// 媒体时长（秒）
    public var duration: TimeInterval

    /// 识别进度（0.0-1.0）
    public var recognitionProgress: Double

    /// 使用的模型 ID
    public var modelId: String?

    /// 识别语言
    public var language: String?

    /// 创建时间（Unix timestamp）
    public var createdAt: Int64

    /// 最后更新时间（Unix timestamp）
    public var updatedAt: Int64

    /// 定义数据库列映射（snake_case）
    private enum CodingKeys: String, CodingKey {
        case id
        case filePath = "file_path"
        case duration
        case recognitionProgress = "recognition_progress"
        case modelId = "model_id"
        case language
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// 初始化媒体记录
    public init(
        id: String = UUID().uuidString,
        filePath: String,
        duration: TimeInterval,
        recognitionProgress: Double = 0.0,
        modelId: String? = nil,
        language: String? = nil,
        createdAt: Int64 = Int64(Date().timeIntervalSince1970),
        updatedAt: Int64 = Int64(Date().timeIntervalSince1970)
    ) {
        self.id = id
        self.filePath = filePath
        self.duration = duration
        self.recognitionProgress = recognitionProgress
        self.modelId = modelId
        self.language = language
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - GRDB 集成

extension MediaRecord: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "media_files"

    /// 定义数据库列
    public enum Columns: String, ColumnExpression {
        case id
        case filePath = "file_path"
        case duration
        case recognitionProgress = "recognition_progress"
        case modelId = "model_id"
        case language
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - 辅助方法

extension MediaRecord {
    /// 是否已完成识别
    public var isRecognitionComplete: Bool {
        recognitionProgress >= 1.0
    }

    /// 文件名（不含路径）
    public var fileName: String {
        URL(fileURLWithPath: filePath).lastPathComponent
    }

    /// 更新识别进度
    public mutating func updateProgress(_ progress: Double) {
        recognitionProgress = min(max(progress, 0.0), 1.0)
        updatedAt = Int64(Date().timeIntervalSince1970)
    }
}
