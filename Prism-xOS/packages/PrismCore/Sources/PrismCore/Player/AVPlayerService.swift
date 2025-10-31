import AVFoundation
import Combine
import Foundation
import OSLog

/// AVPlayer 播放器服务实现
///
/// 基于 AVFoundation 实现 PlayerService 协议
/// 特性：
/// - 10Hz 时间更新（精确到 0.1s）
/// - 状态自动同步（KVO）
/// - 错误处理与映射
///
/// - Created: Sprint 1, Task-101, PR2
@MainActor
public final class AVPlayerService: PlayerService {
    // MARK: - Published Properties

    public var currentTime: TimeInterval {
        guard player.currentItem != nil else { return 0 }
        return CMTimeGetSeconds(player.currentTime())
    }

    public var duration: TimeInterval {
        guard let item = player.currentItem,
            item.status == .readyToPlay
        else {
            return 0
        }
        let duration = item.duration
        guard duration.isValid, !duration.isIndefinite else {
            return 0
        }
        return CMTimeGetSeconds(duration)
    }

    public var playbackRate: Float {
        get { player.rate }
        set { player.rate = newValue }
    }

    public var isPlaying: Bool {
        player.rate > 0 && player.error == nil
    }

    public var timePublisher: AnyPublisher<TimeInterval, Never> {
        timeSubject.eraseToAnyPublisher()
    }

    public var statePublisher: AnyPublisher<PlayerState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    // MARK: - Private Properties

    private let player: AVPlayer

    /// 暴露 AVPlayer 实例供视频渲染使用
    /// - Note: 仅用于视频图层绑定，不应直接调用 AVPlayer 方法
    public var avPlayer: AVPlayer {
        player
    }

    private let logger = Logger(subsystem: "com.prismplayer.core", category: "AVPlayerService")

    private let timeSubject = PassthroughSubject<TimeInterval, Never>()
    private let stateSubject = CurrentValueSubject<PlayerState, Never>(.idle)

    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private var rateObserver: NSKeyValueObservation?
    private var currentItem: AVPlayerItem?

    private let timeUpdateInterval = CMTime(
        value: 1,
        timescale: 10  // 10Hz = 0.1s
    )

    // MARK: - Initialization

    public init() {
        self.player = AVPlayer()
        setupTimeObserver()
    }

    deinit {
        // Cleanup must be synchronous in deinit
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
        }
        statusObserver?.invalidate()
        rateObserver?.invalidate()
    }

    // MARK: - Public Methods

    public func load(url: URL) async throws {
        logger.info("开始加载媒体: \(url.absoluteString)")
        stateSubject.send(.loading)

        // 区分本地/远程 URL
        let isLocalFile = url.isFileURL

        // 本地文件验证
        if isLocalFile {
            guard FileManager.default.fileExists(atPath: url.path) else {
                logger.error("本地文件不存在: \(url.path)")
                stateSubject.send(.error("文件未找到"))
                throw PlayerError.fileNotFound
            }
            logger.debug("加载本地媒体: \(url.lastPathComponent)")
        } else {
            logger.debug("加载远程媒体: \(url.absoluteString)")
        }

        // 创建资源
        let asset = AVURLAsset(url: url)

        // 异步加载资源属性
        do {
            let (isPlayable, duration) = try await asset.load(.isPlayable, .duration)

            guard isPlayable else {
                logger.error("资源验证失败: isPlayable = false")
                stateSubject.send(.error("不支持的格式"))
                throw PlayerError.unsupportedFormat
            }

            // 创建播放项
            let playerItem = AVPlayerItem(asset: asset)
            self.currentItem = playerItem

            // 设置观察者
            setupItemObservers(for: playerItem)

            // 替换当前项
            player.replaceCurrentItem(with: playerItem)

            // 等待就绪
            try await waitForPlayerItemReady(playerItem)

            let durationSeconds = CMTimeGetSeconds(duration)
            logger.info("媒体加载成功，时长: \(durationSeconds)s")
            stateSubject.send(.ready)
        } catch let error as PlayerError {
            throw error
        } catch {
            logger.error("加载失败: \(error.localizedDescription)")
            stateSubject.send(.error(error.localizedDescription))
            throw PlayerError.loadFailed(error.localizedDescription)
        }
    }

    public func play() async {
        logger.debug("开始播放")
        player.play()
        stateSubject.send(.playing)
    }

    public func pause() async {
        logger.debug("暂停播放")
        player.pause()
        stateSubject.send(.paused)
    }

    public func seek(to time: TimeInterval) async {
        logger.debug("跳转到: \(time)s")

        let targetTime = CMTime(seconds: time, preferredTimescale: 600)
        let previousState = stateSubject.value

        stateSubject.send(.seeking)

        await player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)

        // 恢复之前的状态
        switch previousState {
        case .playing:
            stateSubject.send(.playing)
        case .paused, .ready:
            stateSubject.send(.paused)
        default:
            stateSubject.send(.ready)
        }

        logger.debug("跳转成功: \(time)s")
    }

    public func stop() async {
        logger.debug("停止播放")
        player.pause()
        player.replaceCurrentItem(with: nil)
        cleanup()
        stateSubject.send(.stopped)
    }

    // MARK: - Private Methods

    private func setupTimeObserver() {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: timeUpdateInterval,
            queue: .main
        ) { [weak self] time in
            guard let self = self else { return }
            MainActor.assumeIsolated {
                let seconds = CMTimeGetSeconds(time)
                self.timeSubject.send(seconds)
            }
        }
    }

    private func setupItemObservers(for item: AVPlayerItem) {
        // 观察播放状态
        statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.handleStatusChange(item.status)
            }
        }

        // 观察播放速率
        rateObserver = player.observe(\.rate, options: [.new]) { [weak self] player, _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.handleRateChange(player.rate)
            }
        }
    }

    private func handleStatusChange(_ status: AVPlayerItem.Status) {
        switch status {
        case .readyToPlay:
            logger.debug("播放器状态: readyToPlay")
            if stateSubject.value == .loading {
                stateSubject.send(.ready)
            }

        case .failed:
            logger.error("播放器状态: failed")
            let errorMessage = player.currentItem?.error?.localizedDescription ?? "未知错误"
            stateSubject.send(.error(errorMessage))

        case .unknown:
            logger.debug("播放器状态: unknown")

        @unknown default:
            logger.warning("播放器状态: 未知值")
        }
    }

    private func handleRateChange(_ rate: Float) {
        // 只在非 seeking 状态下更新
        guard stateSubject.value != .seeking else { return }

        if rate > 0 {
            if stateSubject.value != .playing {
                logger.debug("播放速率变化: \(rate) -> playing")
                stateSubject.send(.playing)
            }
        } else {
            if stateSubject.value == .playing {
                logger.debug("播放速率变化: 0 -> paused")
                stateSubject.send(.paused)
            }
        }
    }

    private func waitForPlayerItemReady(_ item: AVPlayerItem) async throws {
        // 如果已经就绪，直接返回
        if item.status == .readyToPlay {
            return
        }

        // 等待状态变化（最多 5 秒）
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                for await status in item.publisher(for: \.status).values {
                    if status == .readyToPlay {
                        return
                    } else if status == .failed {
                        throw PlayerError.loadFailed(
                            item.error?.localizedDescription ?? "未知错误"
                        )
                    }
                }
            }

            // 超时任务
            group.addTask {
                try await Task.sleep(nanoseconds: 5_000_000_000)  // 5s
                throw PlayerError.loadFailed("加载超时")
            }

            // 等待第一个完成的任务
            try await group.next()

            // 取消其他任务
            group.cancelAll()
        }
    }

    private func cleanup() {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }

        statusObserver?.invalidate()
        statusObserver = nil

        rateObserver?.invalidate()
        rateObserver = nil

        currentItem = nil
    }
}
