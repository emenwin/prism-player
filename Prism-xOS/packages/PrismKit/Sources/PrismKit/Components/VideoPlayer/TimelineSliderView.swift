//
//  TimelineSliderView.swift
//  PrismKit
//
//  Created by Prism Player on 2025-11-13.
//

import SwiftUI
import AVFoundation

/// 播放进度条，支持拖拽跳转与缓冲进度显示
///
/// 功能：
/// - 显示当前播放进度
/// - 显示缓冲进度（可选）
/// - 支持拖拽跳转到指定位置
/// - 支持点击跳转
/// - 拖拽时暂停时间观察器更新，避免抖动
///
/// 算法说明：
/// 1. 使用 GeometryReader 获取进度条宽度
/// 2. 将时间转换为进度条位置（百分比 × 宽度）
/// 3. 拖拽时实时更新 UI，结束时调用 seek
/// 4. 拖拽期间通知 ViewModel 暂停时间更新
struct TimelineSliderView: View {
    
    // MARK: - Properties
    
    /// 播放器视图模型
    @ObservedObject var viewModel: PlayerViewModel
    
    /// 是否正在拖拽
    @State private var isDragging: Bool = false
    
    /// 拖拽时的临时值（0.0 ~ 1.0）
    @State private var dragProgress: Double = 0
    
    /// 轨道高度
    private let trackHeight: CGFloat = 4
    
    /// 交互热区高度
    private let hitAreaHeight: CGFloat = 20
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景轨道
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: trackHeight)
                
                // 缓冲进度（可选，当前简化实现）
                if viewModel.bufferedTime > 0 {
                    RoundedRectangle(cornerRadius: trackHeight / 2)
                        .fill(Color.gray.opacity(0.5))
                        .frame(
                            width: bufferedWidth(in: geometry),
                            height: trackHeight
                        )
                }
                
                // 播放进度
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(Color.accentColor)
                    .frame(
                        width: playedWidth(in: geometry),
                        height: trackHeight
                    )
                
                // 进度指示器（拖拽时显示）
                if isDragging {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 12, height: 12)
                        .offset(x: playedWidth(in: geometry) - 6)
                }
            }
            .frame(height: hitAreaHeight)
            .contentShape(Rectangle()) // 扩大交互热区
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleDragChanged(value, in: geometry)
                    }
                    .onEnded { value in
                        handleDragEnded(value, in: geometry)
                    }
            )
        }
        .frame(height: hitAreaHeight)
    }
    
    // MARK: - Helper Methods
    
    /// 计算已播放进度宽度
    private func playedWidth(in geometry: GeometryProxy) -> CGFloat {
        let progress = isDragging ? dragProgress : currentProgress
        return geometry.size.width * progress
    }
    
    /// 计算已缓冲进度宽度
    private func bufferedWidth(in geometry: GeometryProxy) -> CGFloat {
        guard viewModel.duration > 0 else { return 0 }
        let bufferedProgress = viewModel.bufferedTime / viewModel.duration
        return geometry.size.width * bufferedProgress
    }
    
    /// 当前播放进度（0.0 ~ 1.0）
    private var currentProgress: Double {
        guard viewModel.duration > 0 else { return 0 }
        return viewModel.currentTime / viewModel.duration
    }
    
    /// 处理拖拽变化
    private func handleDragChanged(_ value: DragGesture.Value, in geometry: GeometryProxy) {
        if !isDragging {
            // 开始拖拽，通知 ViewModel 暂停时间观察器
            isDragging = true
            viewModel.beginDraggingTimeline()
        }
        
        // 计算拖拽进度
        let progress = value.location.x / geometry.size.width
        dragProgress = max(0, min(1, progress))
    }
    
    /// 处理拖拽结束
    private func handleDragEnded(_ value: DragGesture.Value, in geometry: GeometryProxy) {
        // 计算目标时间
        let progress = value.location.x / geometry.size.width
        let clampedProgress = max(0, min(1, progress))
        let targetTime = clampedProgress * viewModel.duration
        
        // 跳转到目标时间
        viewModel.seek(to: targetTime)
        
        // 恢复状态
        isDragging = false
        viewModel.endDraggingTimeline()
    }
}

// MARK: - Preview

#Preview("进度条") {
    TimelineSliderView(viewModel: {
        let player = AVPlayer()
        let viewModel = PlayerViewModel(player: player)
        return viewModel
    }())
    .padding()
}
