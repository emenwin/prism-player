//
//  BottomControlBarView.swift
//  PrismKit
//
//  Created by Prism Player on 2025-11-13.
//

import SwiftUI
import AVFoundation

/// 底部控制条视图容器
///
/// 功能：
/// - 整合左、中、右三个控制区域
/// - 提供毛玻璃背景和圆角样式
/// - 支持自动隐藏（未来扩展）
///
/// 布局结构：
/// ```
/// [Leading Group (80pt)] [Center Group (flex)] [Trailing Group (180pt)]
/// ```
///
/// 尺寸约束：
/// - 总高度：48pt
/// - 最小宽度：640pt
public struct BottomControlBarView: View {
    
    // MARK: - Properties
    
    /// 播放器视图模型
    @ObservedObject var viewModel: PlayerViewModel
    
    // MARK: - Initialization
    
    /// 初始化底部控制条
    /// - Parameter viewModel: 播放器视图模型
    public init(viewModel: PlayerViewModel) {
        self.viewModel = viewModel
    }
    
    // MARK: - Body
    
    public var body: some View {
        HStack(spacing: 12) {
            // Leading Group (音量、静音、PiP)
            ControlBarLeadingGroupView(viewModel: viewModel)
                .frame(width: 80)
            
            // Center Group (播放/暂停、进度条、时间)
            ControlBarCenterGroupView(viewModel: viewModel)
            
            // Trailing Group (速度、全屏)
            ControlBarTrailingGroupView(viewModel: viewModel)
                .frame(width: 180)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(height: 48)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview("底部控制条") {
    BottomControlBarView(viewModel: {
        let player = AVPlayer()
        let viewModel = PlayerViewModel(player: player)
        return viewModel
    }())
    .padding()
    .frame(width: 800)
    .background(Color.black)
}

#Preview("紧凑宽度") {
    BottomControlBarView(viewModel: {
        let player = AVPlayer()
        let viewModel = PlayerViewModel(player: player)
        return viewModel
    }())
    .padding()
    .frame(width: 640)
    .background(Color.black)
}
