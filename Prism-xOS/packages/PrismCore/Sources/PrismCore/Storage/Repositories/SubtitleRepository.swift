import Foundation
import GRDB

/// 字幕片段数据访问层
///
/// 提供字幕片段的 CRUD 操作和时间范围查询
public actor SubtitleRepository {
    private let db: DatabaseManager

    /// 初始化 Repository
    public init(db: DatabaseManager = .shared) {
        self.db = db
    }

    // MARK: - 创建

    /// 保存单个字幕片段
    public func save(_ segment: AsrSegment) async throws {
        try await db.writeAsync { db in
            try segment.insert(db)
        }
    }

    /// 批量保存字幕片段（使用事务）
    public func saveBatch(_ segments: [AsrSegment]) async throws {
        try await db.writeAsync { db in
            for segment in segments {
                try segment.insert(db)
            }
        }
    }

    // MARK: - 查询

    /// 查询指定时间范围的字幕片段
    ///
    /// - Parameters:
    ///   - mediaId: 媒体文件 ID
    ///   - startTime: 起始时间（秒）
    ///   - endTime: 结束时间（秒）
    /// - Returns: 字幕片段数组，按开始时间排序
    public func findInTimeRange(
        mediaId: String,
        startTime: TimeInterval,
        endTime: TimeInterval
    ) async throws -> [AsrSegment] {
        try await db.readAsync { db in
            try AsrSegment
                .filter(AsrSegment.Columns.mediaId == mediaId)
                .filter(AsrSegment.Columns.startTime < endTime)
                .filter(AsrSegment.Columns.endTime > startTime)
                .order(AsrSegment.Columns.startTime.asc)
                .fetchAll(db)
        }
    }

    /// 查询指定媒体的所有字幕
    public func findAll(mediaId: String) async throws -> [AsrSegment] {
        try await db.readAsync { db in
            try AsrSegment
                .filter(AsrSegment.Columns.mediaId == mediaId)
                .order(AsrSegment.Columns.startTime.asc)
                .fetchAll(db)
        }
    }

    /// 获取字幕总数
    public func count(mediaId: String) async throws -> Int {
        try await db.readAsync { db in
            try AsrSegment
                .filter(AsrSegment.Columns.mediaId == mediaId)
                .fetchCount(db)
        }
    }

    // MARK: - 删除

    /// 删除指定媒体的所有字幕
    public func deleteAll(mediaId: String) async throws {
        try await db.writeAsync { db in
            try AsrSegment
                .filter(AsrSegment.Columns.mediaId == mediaId)
                .deleteAll(db)
        }
    }

    /// 删除指定时间范围的字幕
    public func deleteInTimeRange(
        mediaId: String,
        startTime: TimeInterval,
        endTime: TimeInterval
    ) async throws {
        try await db.writeAsync { db in
            try AsrSegment
                .filter(AsrSegment.Columns.mediaId == mediaId)
                .filter(AsrSegment.Columns.startTime >= startTime)
                .filter(AsrSegment.Columns.endTime <= endTime)
                .deleteAll(db)
        }
    }
}
