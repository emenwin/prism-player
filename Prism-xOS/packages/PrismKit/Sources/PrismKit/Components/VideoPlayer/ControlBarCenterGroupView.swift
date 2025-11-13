//
//  ControlBarCenterGroupView.swift
//  PrismKit
//
//  Created by Prism Player on 2025-11-13.
//

import SwiftUI
import AVFoundation

/// 控制条中心区域视图
///
/// 功能：
/// - 播放/暂停按钮
/// - 播放进度条
/// - 时间显示（当前时间 / 总时长）
///
/// 布局：
/// - 水平排列：[播放按钮] [进度条] [时间显示]
/// - 进度条占据弹性空间（Spacer 效果）
struct ControlBarCenterGroupView: View {
    
    // MARK: - Properties
    
    /// 播放器视图模型
    @ObservedObject var viewModel: PlayerViewModel
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 12) {
            // 播放/暂停按钮
            playPauseButton
            
            // 播放进度条
            TimelineSliderView(viewModel: viewModel)
            
            // 时间显示
            TimeIndicatorView(viewModel: viewModel)
        }
    }
    
    // MARK: - Subviews
    
    /// 播放/暂停按钮
    private var playPauseButton: some View {
        Button {
            viewModel.togglePlayPause()
        } label: {
            Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 16, weight: .medium))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(viewModel.isPlaying ? "暂停 (Space)" : "播放 (Space)")
    }
}

// MARK: - Preview

#Preview("中心控制区") {
    ControlBarCenterGroupView(viewModel: {
        let player = AVPlayer()
        let viewModel = PlayerViewModel(player: player)
        return viewModel
    }())
    .padding()
    .frame(width: 600)
    .background(Color.black.opacity(0.8))
}
