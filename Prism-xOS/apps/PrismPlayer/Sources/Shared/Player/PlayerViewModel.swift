//
//  PlayerViewModel.swift
//  PrismPlayer
//
//  Created on 2025-10-28.
//

import AVFoundation
import Combine
import Foundation
import OSLog
import PrismCore

/// 播放器 ViewModel
///
/// 职责：
/// - 管理播放器状态与 UI 绑定
/// - 协调媒体选择与播放控制
/// - 时间同步与错误处理
///
/// 依赖注入：
/// - PlayerService（播放控制）
/// - MediaPicker（文件选择）
@MainActor
final class PlayerViewModel: ObservableObject {
    // MARK: - Published State

    /// 当前播放时间（秒）
    @Published private(set) var currentTime: TimeInterval = 0

    /// 媒体总时长（秒）
    @Published private(set) var duration: TimeInterval = 0

    /// 播放器状态
    @Published private(set) var state: PlayerState = .idle

    /// 是否正在播放
    @Published private(set) var isPlaying: Bool = false

    /// 错误信息（用于 UI 展示）
    @Published var errorMessage: String?

    /// 当前加载的媒体 URL
    @Published private(set) var currentMediaURL: URL?

    /// AVPlayer 实例（用于视频渲染）
    /// - Note: 仅在 PlayerService 为 AVPlayerService 时可用
    var avPlayer: AVPlayer? {
        (playerService as? AVPlayerService)?.avPlayer
    }

    // MARK: - Dependencies

    private let playerService: PlayerService
    private let mediaPicker: MediaPicker

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        playerService: PlayerService,
        mediaPicker: MediaPicker
    ) {
        self.playerService = playerService
        self.mediaPicker = mediaPicker
        setupBindings()
    }

    // MARK: - Public Methods

    /// 选择并加载媒体
    func selectAndLoadMedia() async {
        do {
            // 1. 选择文件
            guard
                let url = try await mediaPicker.selectMedia(
                    allowedTypes: supportedMediaTypes
                )
            else {
                // 用户取消，不做任何操作
                Logger.player.debug("用户取消选择媒体")
                return
            }

            // 2. 验证文件可播放性
            try await validateMediaPlayability(url: url)

            // 3. 记录日志
            Logger.player.info("开始加载媒体: \(url.lastPathComponent)")

            // 4. 加载媒体
            try await playerService.load(url: url)

            // 5. 更新状态
            currentMediaURL = url
            errorMessage = nil

            Logger.player.info("媒体加载成功，时长: \(self.playerService.duration)s")
        } catch {
            handleError(error)
        }
    }

    /// 播放
    func play() async {
        Logger.player.debug("开始播放")
        await playerService.play()
    }

    /// 暂停
    func pause() async {
        Logger.player.debug("暂停播放")
        await playerService.pause()
    }

    /// 跳转
    func seek(to time: TimeInterval) async {
        Logger.player.debug("跳转到: \(time)s")
        await playerService.seek(to: time)
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // 绑定时间更新（10Hz）
        playerService.timePublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentTime)

        // 绑定状态变化
        playerService.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.state = state
                self?.isPlaying = (state == .playing)

                // 更新时长（仅在 ready/playing 状态）
                if state == .ready || state == .playing {
                    self?.duration = self?.playerService.duration ?? 0
                }
            }
            .store(in: &cancellables)
    }

    private func validateMediaPlayability(url: URL) async throws {
        let asset = AVURLAsset(url: url)

        // 检查文件是否存在
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PlayerError.fileNotFound
        }

        // 检查是否可播放（使用新的异步 API）
        let isPlayable = try await asset.load(.isPlayable)
        guard isPlayable else {
            throw PlayerError.unsupportedFormat
        }
    }

    private func handleError(_ error: Error) {
        if let playerError = error as? PlayerError {
            errorMessage = playerError.errorDescription
        } else {
            errorMessage = error.localizedDescription
        }

        // 记录错误日志
        Logger.player.error("播放器错误: \(error.localizedDescription)")
    }
}
