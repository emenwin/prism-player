//
//  ControlBarTrailingGroupView.swift
//  PrismKit
//
//  Created by Prism Player on 2025-11-13.
//

import SwiftUI
import AVFoundation

/// 控制条右侧区域视图
///
/// 功能：
/// - 播放速度选择器
/// - 全屏切换按钮
/// - 设置按钮（预留）
struct ControlBarTrailingGroupView: View {
    
    // MARK: - Properties
    
    /// 播放器视图模型
    @ObservedObject var viewModel: PlayerViewModel
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 8) {
            // 播放速度选择器
            PlaybackRatePickerView(viewModel: viewModel)
            
            // 分隔线
            Divider()
                .frame(height: 24)
            
            // 全屏按钮
            fullScreenButton
        }
    }
    
    // MARK: - Subviews
    
    /// 全屏按钮
    private var fullScreenButton: some View {
        Button {
            viewModel.toggleFullScreen()
        } label: {
            Image(systemName: fullScreenIcon)
                .font(.system(size: 14))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(viewModel.isFullScreen ? "退出全屏 (F)" : "全屏 (F)")
    }
    
    /// 全屏图标
    private var fullScreenIcon: String {
        viewModel.isFullScreen
            ? "arrow.down.right.and.arrow.up.left"
            : "arrow.up.left.and.arrow.down.right"
    }
}

// MARK: - Preview

#Preview("右侧控制区") {
    ControlBarTrailingGroupView(viewModel: {
        let player = AVPlayer()
        let viewModel = PlayerViewModel(player: player)
        return viewModel
    }())
    .padding()
    .frame(width: 200)
    .background(Color.black.opacity(0.8))
}
