//
//  PlaybackRatePickerView.swift
//  PrismKit
//
//  Created by Prism Player on 2025-11-13.
//

import SwiftUI
import AVFoundation

/// 播放速度选择器
///
/// 功能：
/// - 显示当前播放速度
/// - 点击弹出速度选择菜单
/// - 支持 0.5x、0.75x、1.0x、1.25x、1.5x、2.0x
struct PlaybackRatePickerView: View {
    
    // MARK: - Properties
    
    /// 播放器视图模型
    @ObservedObject var viewModel: PlayerViewModel
    
    /// 可选播放速度列表
    private let availableRates: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    
    // MARK: - Body
    
    var body: some View {
        Menu {
            ForEach(availableRates, id: \.self) { rate in
                Button {
                    viewModel.setRate(rate)
                } label: {
                    HStack {
                        Text(rateLabel(for: rate))
                        if abs(viewModel.rate - rate) < 0.01 {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(rateLabel(for: viewModel.rate))
                    .font(.caption)
                    .monospacedDigit()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8))
            }
            .foregroundColor(.primary)
            .frame(width: 60, height: 32)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .help("播放速度")
    }
    
    // MARK: - Helper Methods
    
    /// 获取速度标签
    private func rateLabel(for rate: Float) -> String {
        if rate == 1.0 {
            return "正常"
        } else {
            return String(format: "%.2fx", rate)
        }
    }
}

// MARK: - Preview

#Preview("速度选择器") {
    PlaybackRatePickerView(viewModel: {
        let player = AVPlayer()
        let viewModel = PlayerViewModel(player: player)
        return viewModel
    }())
    .padding()
}
