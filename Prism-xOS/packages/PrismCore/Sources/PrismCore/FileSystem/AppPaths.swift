import Foundation

/// 应用文件系统路径管理
///
/// 管理 Prism Player 的所有文件存储路径，遵循 Apple 平台最佳实践。
public enum AppPaths {
    /// 应用 Application Support 根目录
    ///
    /// - iOS: `~/Library/Application Support/com.prismplayer.ios/`
    /// - macOS: `~/Library/Application Support/com.prismplayer.macos/`
    public static var applicationSupport: URL {
        let fileManager = FileManager.default
        guard
            let baseURL = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first
        else {
            fatalError("Unable to access Application Support directory")
        }

        let bundleID = Bundle.main.bundleIdentifier ?? "com.prismplayer.fallback"
        return baseURL.appendingPathComponent(bundleID, isDirectory: true)
    }

    /// 数据库目录
    ///
    /// 存储 SQLite 数据库文件
    public static var database: URL {
        applicationSupport.appendingPathComponent("Database", isDirectory: true)
    }

    /// 主数据库文件路径
    public static var mainDatabase: URL {
        database.appendingPathComponent("prism.db", isDirectory: false)
    }

    /// ASR 模型目录
    ///
    /// 存储下载或导入的 ASR 模型文件（.gguf, .mlmodel 等）
    public static var models: URL {
        applicationSupport.appendingPathComponent("Models", isDirectory: true)
    }

    /// 音频缓存目录
    ///
    /// 存储从媒体文件提取的音频片段缓存
    public static var audioCache: URL {
        applicationSupport.appendingPathComponent("AudioCache", isDirectory: true)
    }

    /// 导出文件目录
    ///
    /// 存储导出的字幕文件（.srt, .vtt 等）
    public static var exports: URL {
        applicationSupport.appendingPathComponent("Exports", isDirectory: true)
    }

    /// 确保所有必要的目录存在
    ///
    /// 应在应用启动时调用，创建所有标准目录结构
    public static func ensureDirectoriesExist() throws {
        let directories = [
            applicationSupport,
            database,
            models,
            audioCache,
            exports
        ]

        let fileManager = FileManager.default
        for directory in directories {
            if !fileManager.fileExists(atPath: directory.path) {
                try fileManager.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }
        }
    }

    /// 获取缓存目录的当前大小（字节）
    public static func cacheSize() throws -> Int64 {
        try directorySize(audioCache)
    }

    /// 清理音频缓存
    public static func clearAudioCache() throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: audioCache.path) {
            try fileManager.removeItem(at: audioCache)
            try fileManager.createDirectory(
                at: audioCache,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }

    /// 计算目录大小
    private static func directorySize(_ url: URL) throws -> Int64 {
        let fileManager = FileManager.default
        guard
            let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
            )
        else {
            return 0
        }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
            totalSize += Int64(resourceValues.fileSize ?? 0)
        }
        return totalSize
    }
}
