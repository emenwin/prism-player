//
//  TimeIndicatorView.swift
//  PrismKit
//
//  Created by Prism Player on 2025-11-13.
//

import SwiftUI
import AVFoundation

/// 时间指示器视图，显示当前播放时间和总时长
///
/// 功能：
/// - 显示格式化的时间（MM:SS 或 HH:MM:SS）
/// - 自动响应 PlayerViewModel 的时间更新
/// - 支持自定义字体和颜色
struct TimeIndicatorView: View {
    
    // MARK: - Properties
    
    /// 播放器视图模型
    @ObservedObject var viewModel: PlayerViewModel
    
    /// 字体
    private let font: Font
    
    /// 文字颜色
    private let color: Color
    
    // MARK: - Initialization
    
    /// 初始化时间指示器
    /// - Parameters:
    ///   - viewModel: 播放器视图模型
    ///   - font: 字体，默认为 .caption.monospacedDigit()
    ///   - color: 文字颜色，默认为 .secondary
    init(
        viewModel: PlayerViewModel,
        font: Font = .caption.monospacedDigit(),
        color: Color = .secondary
    ) {
        self.viewModel = viewModel
        self.font = font
        self.color = color
    }
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 4) {
            // 当前播放时间
            Text(viewModel.currentTime.formattedTime)
                .font(font)
                .foregroundColor(color)
                .monospacedDigit()
            
            // 分隔符
            Text("/")
                .font(font)
                .foregroundColor(color.opacity(0.6))
            
            // 总时长
            Text(viewModel.duration.formattedTime)
                .font(font)
                .foregroundColor(color.opacity(0.8))
                .monospacedDigit()
        }
        .fixedSize()
    }
}

// MARK: - Preview

#Preview("正常播放") {
    TimeIndicatorView(viewModel: {
        let player = AVPlayer()
        let viewModel = PlayerViewModel(player: player)
        // 模拟播放状态
        return viewModel
    }())
    .padding()
}
