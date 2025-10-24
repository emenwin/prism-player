import Foundation
import GRDB

/// 数据库管理器
///
/// 负责数据库连接、迁移管理和生命周期控制
public final class DatabaseManager: Sendable {
    /// 数据库队列
    private let dbQueue: DatabaseQueue

    /// 单例实例
    public static let shared: DatabaseManager = {
        do {
            // 确保目录存在
            try AppPaths.ensureDirectoriesExist()

            // 创建数据库管理器
            return try DatabaseManager()
        } catch {
            fatalError("Failed to initialize database: \(error)")
        }
    }()

    /// 初始化数据库管理器
    /// - Parameter path: 数据库文件路径，默认使用标准路径
    private init(path: String? = nil) throws {
        let dbPath = path ?? AppPaths.mainDatabase.path

        // 创建数据库队列
        dbQueue = try DatabaseQueue(path: dbPath)

        // 配置数据库
        try configureDatabase()

        // 运行迁移
        try runMigrations()
    }

    /// 配置数据库选项
    private func configureDatabase() throws {
        var config = Configuration()

        // 启用 WAL 模式（Write-Ahead Logging）
        // 允许并发读写，提高性能
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode = WAL")
            try db.execute(sql: "PRAGMA synchronous = NORMAL")
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }

        // 在调试模式下启用详细日志
        #if DEBUG
            config.prepareDatabase { db in
                db.trace { print("[SQL] \($0)") }
            }
        #endif
    }

    /// 运行数据库迁移
    private func runMigrations() throws {
        var migrator = DatabaseMigrator()

        // 注册迁移
        migrator.registerMigration("v1_initial") { db in
            try Migration_001_Initial.migrate(db)
        }

        // 执行迁移
        try migrator.migrate(dbQueue)
    }

    /// 获取数据库队列（供内部使用）
    internal func queue() -> DatabaseQueue {
        dbQueue
    }
}

// MARK: - 便捷方法

extension DatabaseManager {
    /// 执行写入操作
    public func write<T>(_ updates: (Database) throws -> T) throws -> T {
        try dbQueue.write(updates)
    }

    /// 执行读取操作
    public func read<T>(_ value: (Database) throws -> T) throws -> T {
        try dbQueue.read(value)
    }

    /// 执行异步写入操作
    public func writeAsync<T>(_ updates: @escaping (Database) throws -> T) async throws -> T {
        try await dbQueue.write(updates)
    }

    /// 执行异步读取操作
    public func readAsync<T>(_ value: @escaping (Database) throws -> T) async throws -> T {
        try await dbQueue.read(value)
    }
}

// MARK: - 测试支持

#if DEBUG
    extension DatabaseManager {
        /// 创建内存数据库（用于测试）
        public static func inMemory() throws -> DatabaseManager {
            try DatabaseManager(path: ":memory:")
        }

        /// 删除数据库文件（用于测试清理）
        public static func deleteDatabase() throws {
            let fileManager = FileManager.default
            let dbPath = AppPaths.mainDatabase.path
            if fileManager.fileExists(atPath: dbPath) {
                try fileManager.removeItem(atPath: dbPath)
            }

            // 删除 WAL 相关文件
            try? fileManager.removeItem(atPath: dbPath + "-shm")
            try? fileManager.removeItem(atPath: dbPath + "-wal")
        }
    }
#endif
