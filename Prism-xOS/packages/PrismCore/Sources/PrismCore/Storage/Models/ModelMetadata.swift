import Foundation
import GRDB

/// ASR 模型元数据
///
/// 管理已下载或导入的 ASR 模型信息
public struct ModelMetadata: Codable, Sendable {
    /// 唯一标识符
    public var id: String

    /// 模型名称（用户可见）
    public var name: String

    /// 文件大小（字节）
    public var size: Int64

    /// 后端类型
    public var backend: AsrBackend

    /// 模型版本
    public var version: String?

    /// 模型文件路径（相对于 Models 目录）
    public var filePath: String?

    /// 下载状态
    public var downloadStatus: DownloadStatus

    /// SHA256 校验和
    public var sha256: String?

    /// 是否支持时间戳
    public var supportsTimestamps: Bool

    /// 创建时间（Unix timestamp）
    public var createdAt: Int64

    /// 定义数据库列映射（snake_case）
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case size
        case backend
        case version
        case filePath = "file_path"
        case downloadStatus = "download_status"
        case sha256
        case supportsTimestamps = "supports_timestamps"
        case createdAt = "created_at"
    }

    /// 初始化模型元数据
    public init(
        id: String = UUID().uuidString,
        name: String,
        size: Int64,
        backend: AsrBackend,
        version: String? = nil,
        filePath: String? = nil,
        downloadStatus: DownloadStatus = .pending,
        sha256: String? = nil,
        supportsTimestamps: Bool = true,
        createdAt: Int64 = Int64(Date().timeIntervalSince1970)
    ) {
        self.id = id
        self.name = name
        self.size = size
        self.backend = backend
        self.version = version
        self.filePath = filePath
        self.downloadStatus = downloadStatus
        self.sha256 = sha256
        self.supportsTimestamps = supportsTimestamps
        self.createdAt = createdAt
    }
}

// MARK: - 嵌套类型

extension ModelMetadata {
    /// ASR 后端类型
    public enum AsrBackend: String, Codable, Sendable {
        /// whisper.cpp 后端
        case whisperCpp = "whisper-cpp"

        /// MLX Swift 后端（macOS Apple Silicon）
        case mlxSwift = "mlx-swift"
    }

    /// 下载状态
    public enum DownloadStatus: String, Codable, Sendable {
        /// 等待下载
        case pending

        /// 下载中
        case downloading

        /// 已完成
        case completed

        /// 失败
        case failed
    }
}

// MARK: - GRDB 集成

extension ModelMetadata: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "model_metadata"

    /// 定义数据库列
    public enum Columns: String, ColumnExpression {
        case id
        case name
        case size
        case backend
        case version
        case filePath = "file_path"
        case downloadStatus = "download_status"
        case sha256
        case supportsTimestamps = "supports_timestamps"
        case createdAt = "created_at"
    }
}

// MARK: - 辅助方法

extension ModelMetadata {
    /// 是否可用（已下载且有文件路径）
    public var isAvailable: Bool {
        downloadStatus == .completed && filePath != nil
    }

    /// 格式化文件大小
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    /// 完整文件路径
    public var fullFilePath: URL? {
        guard let filePath = filePath else { return nil }
        return AppPaths.models.appendingPathComponent(filePath)
    }
}
