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
public enum PlayerError: Error, LocalizedError {
    case fileNotFound
    case unsupportedFormat
    case loadFailed(String)
    case seekFailed
    case unknown(Error)

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
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}
