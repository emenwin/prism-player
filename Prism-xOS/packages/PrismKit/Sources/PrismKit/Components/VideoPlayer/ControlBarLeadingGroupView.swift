//
//  ControlBarLeadingGroupView.swift
//  PrismKit
//
//  Created by Prism Player on 2025-11-13.
//

import SwiftUI
import AVFoundation

/// 控制条左侧区域视图
///
/// 功能：
/// - 音量控制（滑块）
/// - 静音切换按钮
/// - 画中画按钮（预留）
struct ControlBarLeadingGroupView: View {
    
    // MARK: - Properties
    
    /// 播放器视图模型
    @ObservedObject var viewModel: PlayerViewModel
    
    /// 是否显示音量滑块
    @State private var showVolumeSlider: Bool = false
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 8) {
            // 音量/静音按钮
            volumeButton
            
            // 音量滑块（悬停时显示）
            if showVolumeSlider {
                volumeSlider
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showVolumeSlider)
    }
    
    // MARK: - Subviews
    
    /// 音量/静音按钮
    private var volumeButton: some View {
        Button {
            viewModel.toggleMute()
        } label: {
            Image(systemName: volumeIcon)
                .font(.system(size: 14))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(viewModel.isMuted ? "取消静音" : "静音")
        .onHover { isHovering in
            showVolumeSlider = isHovering
        }
    }
    
    /// 音量图标
    private var volumeIcon: String {
        if viewModel.isMuted || viewModel.volume == 0 {
            return "speaker.slash.fill"
        } else if viewModel.volume < 0.33 {
            return "speaker.wave.1.fill"
        } else if viewModel.volume < 0.66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }
    
    /// 音量滑块
    private var volumeSlider: some View {
        Slider(
            value: Binding(
                get: { Double(viewModel.volume) },
                set: { viewModel.setVolume(Float($0)) }
            ),
            in: 0...1
        )
        .frame(width: 80)
        .help("音量: \(Int(viewModel.volume * 100))%")
    }
}

// MARK: - Preview

#Preview("左侧控制区") {
    ControlBarLeadingGroupView(viewModel: {
        let player = AVPlayer()
        let viewModel = PlayerViewModel(player: player)
        return viewModel
    }())
    .padding()
    .frame(width: 200)
    .background(Color.black.opacity(0.8))
}
