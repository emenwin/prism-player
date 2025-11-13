//
//  PlayerSceneView.swift
//  PrismPlayer
//
//  Created by Prism Player on 2025-11-13.
//

import SwiftUI
import AVFoundation
import PrismKit

/// 播放器场景视图（带完整控制栏）
///
/// 功能：
/// - 视频播放画布
/// - 底部控制条（BottomControlBarView）
/// - 键盘快捷键支持
/// - 全屏模式管理
///
/// 架构：
/// - 使用 PrismKit.PlayerViewModel 管理播放状态
/// - 使用 PrismKit.BottomControlBarView 显示控制条
/// - 响应键盘事件（Space、方向键等）
struct PlayerSceneView: View {
    
    // MARK: - Properties
    
    /// 播放器视图模型（使用 PrismKit 的 ViewModel）
    @StateObject private var viewModel: PrismKit.PlayerViewModel
    
    /// 是否显示控制条（悬停或交互时显示）
    @State private var showControls: Bool = true
    
    /// 控制条自动隐藏计时器
    @State private var hideControlsTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    /// 初始化播放器场景视图
    /// - Parameter url: 媒体文件 URL
    init(url: URL) {
        let player = AVPlayer(url: url)
        _viewModel = StateObject(wrappedValue: PrismKit.PlayerViewModel(player: player))
    }
    
    /// 初始化播放器场景视图（用于测试）
    /// - Parameter player: AVPlayer 实例
    init(player: AVPlayer) {
        _viewModel = StateObject(wrappedValue: PrismKit.PlayerViewModel(player: player))
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // 视频画布
            VideoPlayerLayer(player: viewModel)
                .background(Color.black)
            
            // 错误提示（如果有）
            if let error = viewModel.error {
                errorOverlay(error)
            }
            
            // 底部控制条
            VStack {
                Spacer()
                
                if showControls {
                    BottomControlBarView(viewModel: viewModel)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onHover { isHovering in
            handleHover(isHovering)
        }
        .onTapGesture {
            handleTap()
        }
        .addKeyboardShortcuts(viewModel: viewModel)
        .onChange(of: viewModel.isFullScreen) { _, isFullScreen in
            handleFullScreenChange(isFullScreen)
        }
        .animation(.easeInOut(duration: 0.3), value: showControls)
    }
    
    // MARK: - Subviews
    
    /// 错误覆盖层
    private func errorOverlay(_ error: PlayerError) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.yellow)
            
            Text(error.errorDescription ?? "未知错误")
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("重试") {
                // TODO: 实现重试逻辑
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color.black.opacity(0.7))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Methods
    
    /// 处理悬停事件
    private func handleHover(_ isHovering: Bool) {
        if isHovering {
            showControls = true
            scheduleHideControls()
        }
    }
    
    /// 处理点击事件
    private func handleTap() {
        showControls.toggle()
        if showControls {
            scheduleHideControls()
        }
    }
    
    /// 安排自动隐藏控制条
    private func scheduleHideControls() {
        // 取消之前的计时器
        hideControlsTask?.cancel()
        
        // 如果在播放状态，3 秒后隐藏控制条
        if viewModel.isPlaying {
            hideControlsTask = Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 秒
                if !Task.isCancelled {
                    showControls = false
                }
            }
        }
    }
    
    /// 处理全屏模式变化
    private func handleFullScreenChange(_ isFullScreen: Bool) {
        #if os(macOS)
        // 获取当前窗口并切换全屏
        if let window = NSApplication.shared.keyWindow {
            if isFullScreen != window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
            }
        }
        #endif
    }
}

// MARK: - VideoPlayerLayer

/// 视频播放层（使用 AVPlayerLayer）
private struct VideoPlayerLayer: View {
    @ObservedObject var player: PrismKit.PlayerViewModel
    
    var body: some View {
        #if os(macOS)
        VideoPlayerLayerMac(player: player)
        #else
        VideoPlayerLayeriOS(player: player)
        #endif
    }
}

#if os(macOS)
/// macOS 视频播放层
private struct VideoPlayerLayerMac: NSViewRepresentable {
    @ObservedObject var player: PrismKit.PlayerViewModel
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        
        let playerLayer = AVPlayerLayer(player: player.player)
        playerLayer.videoGravity = .resizeAspect
        playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        view.layer = playerLayer
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let playerLayer = nsView.layer as? AVPlayerLayer {
            playerLayer.player = player.player
        }
    }
}
#else
/// iOS 视频播放层（占位）
private struct VideoPlayerLayeriOS: UIViewRepresentable {
    @ObservedObject var player: PrismKit.PlayerViewModel
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let playerLayer = AVPlayerLayer(player: player.player)
        playerLayer.videoGravity = .resizeAspect
        playerLayer.frame = view.bounds
        view.layer.addSublayer(playerLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let playerLayer = uiView.layer.sublayers?.first as? AVPlayerLayer {
            playerLayer.player = player.player
            playerLayer.frame = uiView.bounds
        }
    }
}
#endif

// MARK: - Keyboard Shortcuts Extension

extension View {
    /// 添加键盘快捷键支持
    func addKeyboardShortcuts(viewModel: PrismKit.PlayerViewModel) -> some View {
        self
            .onKeyPress(.space) { 
                viewModel.togglePlayPause()
                return .handled
            }
            .onKeyPress(.leftArrow) { 
                viewModel.seek(to: max(0, viewModel.currentTime - 5))
                return .handled
            }
            .onKeyPress(.rightArrow) { 
                viewModel.seek(to: min(viewModel.duration, viewModel.currentTime + 5))
                return .handled
            }
            .onKeyPress(.upArrow) { 
                viewModel.setVolume(min(1.0, viewModel.volume + 0.1))
                return .handled
            }
            .onKeyPress(.downArrow) { 
                viewModel.setVolume(max(0.0, viewModel.volume - 0.1))
                return .handled
            }
            .onKeyPress("f") { 
                viewModel.toggleFullScreen()
                return .handled
            }
            .onKeyPress("m") { 
                viewModel.toggleMute()
                return .handled
            }
    }
}

// MARK: - Preview

#Preview("播放器场景") {
    // 创建示例 URL（使用本地测试视频）
    if let url = Bundle.main.url(forResource: "sample-10s", withExtension: "mp4") {
        PlayerSceneView(url: url)
    } else {
        Text("未找到测试视频")
    }
}
