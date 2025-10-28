//
//  PlayerIntegrationDemoView.swift
//  PrismPlayer
//
//  Created on 2025-10-28.
//  Purpose: Demonstrate AVPlayerService integration (PR2 Commit 3)
//

import AVFoundation
import PrismCore
import SwiftUI

/// 播放器集成演示视图
///
/// 用途：
/// - 验证 AVPlayerService 与 PlayerViewModel 的集成
/// - 展示依赖注入的正确配置
/// - 提供基础的播放控制 UI（临时，PR4 将完善）
///
/// 注意：这是临时演示代码，PR4 将创建完整的 PlayerView
struct PlayerIntegrationDemoView: View {
    @StateObject private var viewModel: PlayerViewModel

    init() {
        // 注入真实的 AVPlayerService
        let playerService = AVPlayerService()

        // 注入平台特定的 MediaPicker
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

    var body: some View {
        VStack(spacing: 20) {
            // 播放器状态显示
            statusView

            // 时间显示
            timeView

            // 控制按钮
            controlButtons

            // 错误提示
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
            }
        }
        .padding()
    }

    // MARK: - Subviews

    private var statusView: some View {
        VStack(spacing: 8) {
            Image(systemName: statusIcon)
                .font(.system(size: 60))
                .foregroundColor(statusColor)

            Text(statusText)
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }

    private var timeView: some View {
        HStack {
            Text(formatTime(viewModel.currentTime))
            Text("/")
            Text(formatTime(viewModel.duration))
        }
        .font(.system(.body, design: .monospaced))
        .foregroundColor(.secondary)
    }

    private var controlButtons: some View {
        HStack(spacing: 20) {
            // 选择媒体按钮
            Button(action: { Task { await viewModel.selectAndLoadMedia() } }) {
                Label("选择媒体", systemImage: "folder")
            }
            .buttonStyle(.bordered)

            // 播放/暂停按钮
            Button(action: {
                Task {
                    if viewModel.isPlaying {
                        await viewModel.pause()
                    } else {
                        await viewModel.play()
                    }
                }
            }) {
                Label(
                    viewModel.isPlaying ? "暂停" : "播放",
                    systemImage: viewModel.isPlaying ? "pause.fill" : "play.fill"
                )
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.state == .idle || viewModel.state == .loading)
        }
    }

    // MARK: - Helper Methods

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
        case .idle: return "就绪"
        case .loading: return "加载中..."
        case .ready: return "准备播放"
        case .playing: return "播放中"
        case .paused: return "已暂停"
        case .seeking: return "跳转中"
        case .stopped: return "已停止"
        case .error: return "错误"
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview("iOS") {
    PlayerIntegrationDemoView()
}

#Preview("macOS") {
    PlayerIntegrationDemoView()
        .frame(width: 400, height: 500)
}
