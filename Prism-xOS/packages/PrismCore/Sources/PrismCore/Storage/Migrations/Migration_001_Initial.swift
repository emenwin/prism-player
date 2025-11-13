import Foundation
import GRDB

/// 数据库初始 Schema（v1）
///
/// 创建核心表结构：媒体文件、字幕片段、模型元数据
struct Migration_001_Initial {
    static func migrate(_ db: Database) throws {
        // 1. 创建媒体文件表
        try db.create(table: "media_files") { table in
            table.column("id", .text).primaryKey()
            table.column("file_path", .text).notNull()
            table.column("duration", .double).notNull()
            table.column("recognition_progress", .double).notNull().defaults(to: 0.0)
            table.column("model_id", .text)
            table.column("language", .text)
            table.column("created_at", .integer).notNull()
            table.column("updated_at", .integer).notNull()
        }

        // 为 file_path 创建索引（单独创建，避免重复列定义）
        try db.create(
            index: "media_files_on_file_path",
            on: "media_files",
            columns: ["file_path"]
        )

        // 2. 创建字幕片段表
        try db.create(table: "subtitle_segments") { table in
            table.column("id", .text).primaryKey()
            table.column("media_id", .text).notNull()
                .references("media_files", onDelete: .cascade)
            table.column("start_time", .double).notNull()
            table.column("end_time", .double).notNull()
            table.column("text", .text).notNull()
            table.column("confidence", .double)
            table.column("created_at", .integer).notNull()
        }

        // 为时间范围查询创建复合索引
        try db.create(
            index: "idx_segments_time_range",
            on: "subtitle_segments",
            columns: ["media_id", "start_time", "end_time"]
        )

        // 3. 创建模型元数据表
        try db.create(table: "model_metadata") { table in
            table.column("id", .text).primaryKey()
            table.column("name", .text).notNull()
            table.column("size", .integer).notNull()
            table.column("backend", .text).notNull()
            table.column("version", .text)
            table.column("file_path", .text)
            table.column("download_status", .text).notNull().defaults(to: "pending")
            table.column("sha256", .text)
            table.column("supports_timestamps", .boolean).notNull().defaults(to: true)
            table.column("created_at", .integer).notNull()
        }

        // 为 backend 和 download_status 创建索引
        try db.create(
            index: "model_metadata_on_backend",
            on: "model_metadata",
            columns: ["backend"]
        )
        try db.create(
            index: "model_metadata_on_download_status",
            on: "model_metadata",
            columns: ["download_status"]
        )

        // 插入示例模型（占位）
        try insertSampleModels(db)
    }

    /// 插入示例模型元数据（用于开发测试）
    private static func insertSampleModels(_ db: Database) throws {
        let now = Int64(Date().timeIntervalSince1970)

        // Whisper Base 模型
        try db.execute(
            sql: """
                INSERT INTO model_metadata
                (id, name, size, backend, version, download_status, supports_timestamps, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
            arguments: [
                "whisper-base",
                "Whisper Base",
                145_000_000,  // ~145MB
                "whisper-cpp",
                "v1",
                "pending",
                true,
                now,
            ]
        )

        // Whisper Small 模型
        try db.execute(
            sql: """
                INSERT INTO model_metadata
                (id, name, size, backend, version, download_status, supports_timestamps, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
            arguments: [
                "whisper-small",
                "Whisper Small",
                466_000_000,  // ~466MB
                "whisper-cpp",
                "v1",
                "pending",
                true,
                now,
            ]
        )
    }
}
