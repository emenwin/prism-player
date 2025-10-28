//
//  PlayerView.swift
//  PrismPlayer
//
//  Created on 2025-10-28.
//  Purpose: Shared player view with platform-specific MediaPicker injection (PR3 Commit 3)
//

import AVFoundation
import PrismCore
import SwiftUI

/// 播放器视图（跨平台共享）
///
/// 职责：
/// - 提供统一的播放器 UI 界面
/// - 通过条件编译注入平台特定的 MediaPicker
/// - 绑定 PlayerViewModel 的状态与 UI
///
/// 平台差异：
/// - iOS: 使用 MediaPickeriOS (UIDocumentPicker)
/// - macOS: 使用 MediaPickerMac (NSOpenPanel 占位)
///
/// Target Membership: Both (iOS + macOS)
struct PlayerView: View {
    @StateObject private var viewModel: PlayerViewModel

    // MARK: - Initialization

    /// 默认初始化器（自动注入平台 MediaPicker）
    init() {
        // 创建真实的 AVPlayerService
        let playerService = AVPlayerService()

        // 条件编译：注入平台特定的 MediaPicker
        #if os(iOS)
            let mediaPicker = MediaPickeriOS()
        #elseif os(macOS)
            let mediaPicker = MediaPickerMac()
        #endif

        _viewModel = StateObject(
            wrappedValue: PlayerViewModel(
                playerService: playerService,
                mediaPicker: mediaPicker
            )
        )
    }

    /// 测试初始化器（支持依赖注入）
    init(playerService: PlayerService, mediaPicker: MediaPicker) {
        _viewModel = StateObject(
            wrappedValue: PlayerViewModel(
                playerService: playerService,
                mediaPicker: mediaPicker
            )
        )
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            // 播放器状态指示器
            statusIndicator

            // 视频渲染区域（占位，PR4 实现）
            videoPlaceholder

            // 时间进度显示
            timeDisplay

            // 控制按钮组
            controlButtons

            // 错误提示 Alert
        }
        .padding()
        .alert(
            String(localized: "player.error.title"),
            isPresented: .constant(viewModel.errorMessage != nil),
            presenting: viewModel.errorMessage
        ) { _ in
            Button(String(localized: "player.error.dismiss")) {
                viewModel.errorMessage = nil
            }
        } message: { errorMessage in
            Text(errorMessage)
        }
    }

    // MARK: - Subviews

    /// 状态指示器
    private var statusIndicator: some View {
        VStack(spacing: 8) {
            Image(systemName: statusIcon)
                .font(.system(size: 60))
                .foregroundColor(statusColor)
                .accessibilityLabel(statusText)

            Text(statusText)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    /// 视频渲染区域
    @ViewBuilder
    private var videoPlaceholder: some View {
        ZStack {
            // 背景色
            Color.black

            // 视频渲染（如果有 AVPlayer）
            if let player = viewModel.avPlayer {
                VideoPlayerView(player: player, videoGravity: .resizeAspect)
            } else {
                // 占位内容
                VStack(spacing: 12) {
                    if viewModel.state == .idle {
                        Image(systemName: "film")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text(String(localized: "player.no_media"))
                            .foregroundColor(.secondary)
                    } else if viewModel.state == .loading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(1.5)
                        Text(String(localized: "player.status.loading"))
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    } else if let url = viewModel.currentMediaURL {
                        Image(systemName: "music.note")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text(url.lastPathComponent)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
            }
        }
        .frame(height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// 时间进度显示
    private var timeDisplay: some View {
        HStack {
            Text(formatTime(viewModel.currentTime))
            Spacer()
            Text(formatTime(viewModel.duration))
        }
        .font(.system(.body, design: .monospaced))
        .foregroundColor(.secondary)
        .padding(.horizontal)
    }

    /// 控制按钮组
    private var controlButtons: some View {
        HStack(spacing: 20) {
            // 选择媒体按钮
            Button {
                Task { await viewModel.selectAndLoadMedia() }
            } label: {
                Label(
                    String(localized: "player.select_media"),
                    systemImage: "folder.badge.plus"
                )
            }
            .buttonStyle(.bordered)

            // 播放/暂停按钮
            Button {
                Task {
                    if viewModel.isPlaying {
                        await viewModel.pause()
                    } else {
                        await viewModel.play()
                    }
                }
            } label: {
                Label(
                    viewModel.isPlaying
                        ? String(localized: "player.pause")
                        : String(localized: "player.play"),
                    systemImage: viewModel.isPlaying ? "pause.fill" : "play.fill"
                )
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.state == .idle || viewModel.state == .loading)
        }
    }

    // MARK: - Helper Properties

    private var statusIcon: String {
        switch viewModel.state {
        case .idle: return "music.note"
        case .loading: return "arrow.clockwise"
        case .ready: return "checkmark.circle"
        case .playing: return "play.circle.fill"
        case .paused: return "pause.circle.fill"
        case .seeking: return "arrow.forward.circle"
        case .stopped: return "stop.circle"
        case .error: return "exclamationmark.triangle"
        }
    }

    private var statusColor: Color {
        switch viewModel.state {
        case .idle: return .secondary
        case .loading: return .blue
        case .ready: return .green
        case .playing: return .blue
        case .paused: return .orange
        case .seeking: return .purple
        case .stopped: return .secondary
        case .error: return .red
        }
    }

    private var statusText: String {
        switch viewModel.state {
        case .idle: return String(localized: "player.status.idle")
        case .loading: return String(localized: "player.status.loading")
        case .ready: return String(localized: "player.status.ready")
        case .playing: return String(localized: "player.status.playing")
        case .paused: return String(localized: "player.status.paused")
        case .seeking: return String(localized: "player.status.seeking")
        case .stopped: return String(localized: "player.status.stopped")
        case .error: return String(localized: "player.status.error")
        }
    }

    // MARK: - Helper Methods

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Preview

#Preview("PlayerView - Default") {
    PlayerView()
}

#Preview("PlayerView - Landscape", traits: .landscapeLeft) {
    PlayerView()
}
