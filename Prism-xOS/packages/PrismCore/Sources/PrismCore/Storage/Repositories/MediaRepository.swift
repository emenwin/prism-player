import Foundation
import GRDB

/// 媒体文件数据访问层
///
/// 提供媒体文件记录的 CRUD 操作
public actor MediaRepository {
    private let db: DatabaseManager

    /// 初始化 Repository
    public init(db: DatabaseManager = .shared) {
        self.db = db
    }

    // MARK: - 创建

    /// 保存媒体记录
    public func save(_ media: MediaRecord) async throws {
        try await db.writeAsync { db in
            try media.insert(db)
        }
    }

    // MARK: - 查询

    /// 根据 ID 查询媒体记录
    public func find(id: String) async throws -> MediaRecord? {
        try await db.readAsync { db in
            try MediaRecord.fetchOne(db, key: id)
        }
    }

    /// 查询所有媒体记录
    public func findAll() async throws -> [MediaRecord] {
        try await db.readAsync { db in
            try MediaRecord.fetchAll(db)
        }
    }

    /// 查询最近的媒体记录
    public func findRecent(limit: Int = 10) async throws -> [MediaRecord] {
        try await db.readAsync { db in
            try MediaRecord
                .order(MediaRecord.Columns.updatedAt.desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    // MARK: - 更新

    /// 更新媒体记录
    public func update(_ media: MediaRecord) async throws {
        try await db.writeAsync { db in
            try media.update(db)
        }
    }

    /// 更新识别进度
    public func updateProgress(id: String, progress: Double) async throws {
        try await db.writeAsync { db in
            try db.execute(
                sql: """
                    UPDATE media_files
                    SET recognition_progress = ?, updated_at = ?
                    WHERE id = ?
                    """,
                arguments: [progress, Int64(Date().timeIntervalSince1970), id]
            )
        }
    }

    // MARK: - 删除

    /// 删除媒体记录（级联删除关联的字幕）
    public func delete(id: String) async throws {
        try await db.writeAsync { db in
            try MediaRecord.deleteOne(db, key: id)
        }
    }
}
