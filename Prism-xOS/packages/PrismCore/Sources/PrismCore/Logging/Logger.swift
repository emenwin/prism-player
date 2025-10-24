import OSLog

/// 日志分类枚举
/// Log category enumeration for different subsystems
public enum LogCategory: String, CaseIterable {
    // MARK: - 核心业务分类 / Core Business Categories

    /// 播放器相关日志（播放/暂停/seek/状态变化）
    case player = "Player"

    /// 语音识别相关日志（模型加载/推理/结果）
    case asr = "ASR"

    /// 字幕相关日志（渲染/同步/样式）
    case subtitle = "Subtitle"

    /// 数据存储相关日志（数据库操作/缓存）
    case storage = "Storage"

    /// 网络相关日志（模型下载/检查更新）
    case network = "Network"

    /// UI 交互相关日志（用户操作/页面导航）
    case ui = "UI"

    // MARK: - 系统级分类 / System Categories

    /// 性能指标日志（首帧时间/RTF/内存）
    case performance = "Performance"

    /// 应用生命周期日志（启动/后台/前台）
    case lifecycle = "Lifecycle"

    /// 错误和异常日志（崩溃前兆/降级触发）
    case error = "Error"
}

/// 日志级别说明
/// Log level guidelines for proper usage
public enum LogLevel {
    /// 调试信息（仅 Debug 构建）- 详细的技术细节
    /// Debug info (Debug builds only) - Detailed technical information
    case debug

    /// 一般信息 - 关键流程节点
    /// General info - Key process milestones
    case info

    /// 重要通知 - 状态变化
    /// Important notice - State changes
    case notice

    /// 错误但可恢复 - 需要关注但不影响核心功能
    /// Recoverable error - Needs attention but doesn't break core functionality
    case error

    /// 严重错误 - 不应发生的情况
    /// Critical fault - Should never happen
    case fault
}

// MARK: - Logger Extension

extension Logger {
    /// 应用子系统标识符
    /// Application subsystem identifier
    private static let subsystem = "com.prismplayer.app"

    // MARK: - 核心业务日志器 / Core Business Loggers

    /// 播放器日志
    public static let player = Logger(subsystem: subsystem, category: LogCategory.player.rawValue)

    /// ASR 引擎日志
    public static let asr = Logger(subsystem: subsystem, category: LogCategory.asr.rawValue)

    /// 字幕日志
    public static let subtitle = Logger(
        subsystem: subsystem, category: LogCategory.subtitle.rawValue)

    /// 存储日志
    public static let storage = Logger(subsystem: subsystem, category: LogCategory.storage.rawValue)

    /// 网络日志
    public static let network = Logger(subsystem: subsystem, category: LogCategory.network.rawValue)

    /// UI 日志
    public static let ui = Logger(subsystem: subsystem, category: LogCategory.ui.rawValue)

    // MARK: - 系统级日志器 / System Loggers

    /// 性能指标日志
    public static let performance = Logger(
        subsystem: subsystem, category: LogCategory.performance.rawValue)

    /// 生命周期日志
    public static let lifecycle = Logger(
        subsystem: subsystem, category: LogCategory.lifecycle.rawValue)

    /// 错误日志
    public static let error = Logger(subsystem: subsystem, category: LogCategory.error.rawValue)

    // MARK: - 便捷方法 / Convenience Methods

    /// 根据分类获取日志器
    /// Get logger by category
    public static func logger(for category: LogCategory) -> Logger {
        switch category {
        case .player: return player
        case .asr: return asr
        case .subtitle: return subtitle
        case .storage: return storage
        case .network: return network
        case .ui: return ui
        case .performance: return performance
        case .lifecycle: return lifecycle
        case .error: return error
        }
    }
}

// MARK: - Usage Examples

/*
 使用示例 / Usage Examples:

 // 基础使用 / Basic usage
 Logger.player.info("▶️ Playback started: \(mediaURL.lastPathComponent)")
 Logger.asr.debug("Loading model: \(modelName)")
 Logger.subtitle.notice("First subtitle rendered in \(duration)ms")

 // 带隐私保护 / With privacy protection
 Logger.storage.info("Saved record: \(recordID, privacy: .private)")
 Logger.network.error("Download failed: \(url, privacy: .public)")

 // 性能指标 / Performance metrics
 Logger.performance.notice("First frame time: \(firstFrameTime)ms")
 Logger.performance.info("RTF: \(rtf, format: .fixed(precision: 2))")

 // 错误处理 / Error handling
 Logger.error.error("Failed to decode audio: \(error.localizedDescription)")
 Logger.error.fault("Database corruption detected!")

 // 生命周期 / Lifecycle
 Logger.lifecycle.info("App launched in \(launchTime)ms")
 Logger.lifecycle.notice("Entering background")
 */
