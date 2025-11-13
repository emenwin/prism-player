//
//  PlayerViewModel.swift
//  PrismKit
//
//  Created by Prism Player on 2025-11-13.
//

import Foundation
import AVFoundation
import Combine
import OSLog

/// 播放器视图模型，管理播放状态与控制逻辑
///
/// 职责：
/// 1. 封装 AVPlayer，提供简化的播放控制接口
/// 2. 管理播放状态（播放/暂停、时间、速度、音量等）
/// 3. 处理播放错误并转换为用户友好的错误信息
/// 4. 通过 Combine 发布状态变化，驱动 UI 更新
///
/// 架构说明：
/// - 使用 MVVM 模式，作为 View 和 AVPlayer 之间的桥梁
/// - 通过 @Published 属性自动通知 SwiftUI 视图更新
/// - 使用 KVO 观察 AVPlayer 内部状态变化
/// - 时间观察器以 30 FPS 频率更新，平衡性能与流畅度
@MainActor
public final class PlayerViewModel: ObservableObject {
    
    // MARK: - Published Properties (状态属性)
    
    /// 是否正在播放
    @Published public private(set) var isPlaying: Bool = false
    
    /// 当前播放时间（秒）
    @Published public private(set) var currentTime: TimeInterval = 0
    
    /// 视频总时长（秒）
    @Published public private(set) var duration: TimeInterval = 0
    
    /// 已缓冲的时间（秒）
    @Published public private(set) var bufferedTime: TimeInterval = 0
    
    /// 播放速度（0.5x ~ 2.0x）
    @Published public private(set) var rate: Float = 1.0
    
    /// 音量（0.0 ~ 1.0）
    @Published public private(set) var volume: Float = 1.0
    
    /// 是否静音
    @Published public private(set) var isMuted: Bool = false
    
    /// 是否全屏模式
    @Published public var isFullScreen: Bool = false
    
    /// 是否画中画模式
    @Published public var isPipActive: Bool = false
    
    /// 播放错误（nil 表示无错误）
    @Published public private(set) var error: PlayerError?
    
    // MARK: - Private Properties (内部依赖)
    
    /// AVPlayer 实例（公开以供视频层使用）
    public let player: AVPlayer
    
    /// 时间观察器令牌（需要在 deinit 中访问）
    private nonisolated(unsafe) var timeObserverToken: Any?
    
    /// 播放状态观察器（需要在 deinit 中访问）
    private nonisolated(unsafe) var statusObserver: NSKeyValueObservation?
    
    /// 播放器项状态观察器（需要在 deinit 中访问）
    private nonisolated(unsafe) var itemStatusObserver: NSKeyValueObservation?
    
    /// 播放结束通知观察器（需要在 deinit 中访问）
    private nonisolated(unsafe) var playbackEndObserver: NSObjectProtocol?
    
    /// 日志记录器
    private let logger = Logger(subsystem: "com.prismplayer.prismkit", category: "PlayerViewModel")
    
    /// 是否正在拖拽进度条（拖拽时暂停时间观察器更新）
    private var isDraggingTimeline: Bool = false
    
    // MARK: - Initialization (初始化)
    
    /// 初始化播放器视图模型
    /// - Parameter player: AVPlayer 实例
    public init(player: AVPlayer) {
        self.player = player
        setupObservers()
        setupInitialState()
    }
    
    deinit {
        // 移除观察器是线程安全的，可以在任何线程调用
        cleanupObservers()
    }
    
    // MARK: - Public Methods (公开接口)
    
    /// 开始播放
    public func play() {
        logger.info("▶️ 播放开始")
        player.play()
        isPlaying = true
    }
    
    /// 暂停播放
    public func pause() {
        logger.info("⏸ 播放暂停")
        player.pause()
        isPlaying = false
    }
    
    /// 切换播放/暂停状态
    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    /// 跳转到指定时间
    /// - Parameter time: 目标时间（秒），会自动限制在有效范围内
    public func seek(to time: TimeInterval) {
        // 限制在有效范围 [0, duration]
        let clampedTime = max(0, min(time, duration))
        
        logger.debug("⏩ 跳转到: \(clampedTime, format: .fixed(precision: 2))s")
        
        let cmTime = CMTime(seconds: clampedTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        
        // 立即更新 UI 显示
        currentTime = clampedTime
    }
    
    /// 设置播放速度
    /// - Parameter rate: 播放速度（0.5x ~ 2.0x），会自动限制在有效范围内
    public func setRate(_ rate: Float) {
        // 限制在有效范围 [0.5, 2.0]
        let clampedRate = max(0.5, min(rate, 2.0))
        
        logger.info("⚡️ 播放速度调整为: \(clampedRate, format: .fixed(precision: 1))x")
        
        self.rate = clampedRate
        player.rate = clampedRate
        
        // 如果在播放状态，应用新速度
        if isPlaying {
            player.play()
        }
    }
    
    /// 设置音量
    /// - Parameter volume: 音量大小（0.0 ~ 1.0），会自动限制在有效范围内
    public func setVolume(_ volume: Float) {
        // 限制在有效范围 [0.0, 1.0]
        let clampedVolume = max(0.0, min(volume, 1.0))
        
        logger.debug("🔊 音量调整为: \(clampedVolume, format: .fixed(precision: 2))")
        
        self.volume = clampedVolume
        player.volume = clampedVolume
        
        // 如果音量大于 0，自动取消静音
        if clampedVolume > 0 && isMuted {
            isMuted = false
            player.isMuted = false
        }
    }
    
    /// 切换静音状态
    public func toggleMute() {
        isMuted.toggle()
        player.isMuted = isMuted
        
        logger.debug("🔇 静音状态: \(self.isMuted ? "开启" : "关闭")")
    }
    
    /// 开始拖拽进度条（暂停时间观察器更新，避免抖动）
    public func beginDraggingTimeline() {
        isDraggingTimeline = true
    }
    
    /// 结束拖拽进度条（恢复时间观察器更新）
    public func endDraggingTimeline() {
        isDraggingTimeline = false
    }
    
    /// 切换全屏模式（由外部视图层控制实际全屏逻辑）
    public func toggleFullScreen() {
        isFullScreen.toggle()
        logger.debug("🖥 全屏模式: \(self.isFullScreen ? "开启" : "关闭")")
    }
    
    // MARK: - Private Methods (内部实现)
    
    /// 设置观察器
    private func setupObservers() {
        // 1. 时间观察器（30 FPS = 0.033s 间隔）
        let interval = CMTime(seconds: 0.033, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, !self.isDraggingTimeline else { return }
            self.currentTime = time.seconds
        }
        
        // 2. 播放器状态观察器
        statusObserver = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.isPlaying = player.timeControlStatus == .playing
            }
        }
        
        // 3. 播放器项状态观察器
        itemStatusObserver = player.observe(\.currentItem?.status, options: [.new]) { [weak self] player, _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.handlePlayerItemStatusChange()
            }
        }
        
        // 4. 播放结束通知
        playbackEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.isPlaying = false
                self.logger.info("✅ 播放完成")
            }
        }
    }
    
    /// 清理观察器（可以在任何线程调用）
    private nonisolated func cleanupObservers() {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
        
        statusObserver?.invalidate()
        itemStatusObserver?.invalidate()
        
        if let observer = playbackEndObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    /// 设置初始状态
    private func setupInitialState() {
        volume = player.volume
        isMuted = player.isMuted
        
        // 获取时长
        if let currentItem = player.currentItem {
            duration = currentItem.duration.seconds
            
            // 如果时长无效（实时流），设为 0
            if duration.isNaN || duration.isInfinite {
                duration = 0
            }
        }
    }
    
    /// 处理播放器项状态变化
    private func handlePlayerItemStatusChange() {
        guard let currentItem = player.currentItem else { return }
        
        switch currentItem.status {
        case .readyToPlay:
            duration = currentItem.duration.seconds
            if duration.isNaN || duration.isInfinite {
                duration = 0
            }
            error = nil
            logger.info("✅ 播放器就绪，时长: \(self.duration, format: .fixed(precision: 2))s")
            
        case .failed:
            if let itemError = currentItem.error {
                error = PlayerError.from(itemError)
                logger.error("❌ 播放失败: \(itemError.localizedDescription)")
            }
            
        case .unknown:
            logger.debug("⏳ 播放器状态未知")
            
        @unknown default:
            break
        }
    }
}

// MARK: - PlayerError (播放错误模型)

/// 播放器错误类型
public enum PlayerError: LocalizedError {
    /// 加载失败
    case loadFailed(String)
    
    /// 解码错误
    case decodingError(String)
    
    /// 网络错误
    case networkError(String)
    
    /// 未知错误
    case unknownError(String)
    
    public var errorDescription: String? {
        switch self {
        case .loadFailed(let reason):
            return NSLocalizedString("player.error.load_failed", comment: "加载失败") + ": \(reason)"
        case .decodingError(let reason):
            return NSLocalizedString("player.error.decoding", comment: "解码错误") + ": \(reason)"
        case .networkError(let reason):
            return NSLocalizedString("player.error.network", comment: "网络错误") + ": \(reason)"
        case .unknownError(let reason):
            return NSLocalizedString("player.error.unknown", comment: "未知错误") + ": \(reason)"
        }
    }
    
    /// 从 NSError 转换为 PlayerError
    static func from(_ error: Error) -> PlayerError {
        let nsError = error as NSError
        
        // AVFoundation 错误域
        if nsError.domain == AVFoundationErrorDomain {
            switch nsError.code {
            case AVError.fileFormatNotRecognized.rawValue,
                 AVError.decoderNotFound.rawValue:
                return .decodingError(nsError.localizedDescription)
                
            case AVError.contentIsNotAuthorized.rawValue,
                 AVError.applicationIsNotAuthorized.rawValue:
                return .loadFailed(nsError.localizedDescription)
                
            default:
                return .unknownError(nsError.localizedDescription)
            }
        }
        
        // NSURLError 网络错误域
        if nsError.domain == NSURLErrorDomain {
            return .networkError(nsError.localizedDescription)
        }
        
        return .unknownError(nsError.localizedDescription)
    }
}
