import Combine
import Foundation

/// 播放器服务协议
/// 定义媒体播放控制的标准接口
///
/// 实现类：
/// - AVPlayerService: 基于 AVPlayer 的实现
/// - MockPlayerService: 测试用 Mock（Tests/Mocks）
///
/// - Created: Sprint 0, Task-009
/// - Last Updated: 2025-10-28
@MainActor
public protocol PlayerService: AnyObject {
    /// 当前播放时间（秒）
    var currentTime: TimeInterval { get }

    /// 媒体总时长（秒）
    var duration: TimeInterval { get }

    /// 播放速率（0.5-2.0）
    var playbackRate: Float { get set }

    /// 播放状态
    var isPlaying: Bool { get }

    /// 时间更新发布者（每 0.1 秒发布一次）
    var timePublisher: AnyPublisher<TimeInterval, Never> { get }

    /// 播放状态变化发布者
    var statePublisher: AnyPublisher<PlayerState, Never> { get }

    /// 加载媒体
    /// - Parameter url: 媒体文件 URL
    func load(url: URL) async throws

    /// 开始播放
    func play() async

    /// 暂停播放
    func pause() async

    /// 跳转到指定时间
    /// - Parameter time: 目标时间（秒）
    func seek(to time: TimeInterval) async

    /// 停止播放并释放资源
    func stop() async
}

// MARK: - Player State

/// 播放器状态
public enum PlayerState: Equatable, Sendable {
    case idle
    case loading
    case ready
    case playing
    case paused
    case seeking
    case stopped
    case error(String)
}

// MARK: - Player Error

/// 播放器错误
public enum PlayerError: Error, LocalizedError, Equatable, Sendable {
    // MARK: - 基础错误（原有）
    case fileNotFound
    case unsupportedFormat
    case loadFailed(String)
    case seekFailed
    case unknown(String)

    // MARK: - 扩展错误（状态机支持）
    /// 媒体加载失败（带 URL 上下文）
    case mediaLoadFailed(URL, underlying: String)

    /// 识别失败
    case recognitionFailed(TimeRange, underlying: String)

    /// 内部错误
    case internalError(String)

    /// 操作被取消
    case cancelled(operation: String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return NSLocalizedString("player.error.file_not_found", comment: "文件未找到")
        case .unsupportedFormat:
            return NSLocalizedString("player.error.unsupported_format", comment: "不支持的媒体格式")
        case .loadFailed(let message):
            return String(
                format: NSLocalizedString("player.error.load_failed", comment: "加载失败: %@"), message)
        case .seekFailed:
            return NSLocalizedString("player.error.seek_failed", comment: "跳转失败")
        case .unknown(let message):
            return message
        case .mediaLoadFailed(let url, let underlying):
            return "Failed to load media '\(url.lastPathComponent)': \(underlying)"
        case .recognitionFailed(let window, let underlying):
            return "Recognition failed for \(window.description): \(underlying)"
        case .internalError(let description):
            return "Internal error: \(description)"
        case .cancelled(let operation):
            return "Operation '\(operation)' was cancelled"
        }
    }

    /// 是否为可恢复的错误
    public var isRecoverable: Bool {
        switch self {
        case .fileNotFound, .unsupportedFormat:
            return false
        case .loadFailed, .seekFailed, .unknown,
            .mediaLoadFailed, .recognitionFailed, .cancelled:
            return true
        case .internalError:
            return false
        }
    }

    // MARK: - Equatable

    public static func == (lhs: PlayerError, rhs: PlayerError) -> Bool {
        switch (lhs, rhs) {
        case (.fileNotFound, .fileNotFound),
            (.unsupportedFormat, .unsupportedFormat),
            (.seekFailed, .seekFailed):
            return true
        case (.loadFailed(let lMsg), .loadFailed(let rMsg)),
            (.unknown(let lMsg), .unknown(let rMsg)),
            (.internalError(let lMsg), .internalError(let rMsg)):
            return lMsg == rMsg
        case (.mediaLoadFailed(let lUrl, let lUnd), .mediaLoadFailed(let rUrl, let rUnd)):
            return lUrl == rUrl && lUnd == rUnd
        case (.recognitionFailed(let lWin, let lUnd), .recognitionFailed(let rWin, let rUnd)):
            return lWin == rWin && lUnd == rUnd
        case (.cancelled(let lOp), .cancelled(let rOp)):
            return lOp == rOp
        default:
            return false
        }
    }

    // MARK: - Error Helpers

    /// 从底层错误创建 PlayerError
    /// - Parameters:
    ///   - error: 底层错误
    ///   - context: 错误上下文（操作描述）
    /// - Returns: PlayerError 实例
    public static func from(_ error: Error, context: String) -> PlayerError {
        if let playerError = error as? PlayerError {
            return playerError
        }

        // 检查是否为取消错误
        let nsError = error as NSError
        if nsError.code == NSURLErrorCancelled
            || (nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError)
        {
            return .cancelled(operation: context)
        }

        return .internalError("\(context): \(error.localizedDescription)")
    }
}
