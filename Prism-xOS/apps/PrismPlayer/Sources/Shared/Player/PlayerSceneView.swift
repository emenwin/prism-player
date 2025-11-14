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
    
    /// 应用视图模型（用于场景切换）
    @ObservedObject var appViewModel: AppViewModel
    
    /// 播放器视图模型（使用 PrismKit 的 ViewModel）
    @StateObject private var viewModel: PrismKit.PlayerViewModel
    
    /// 是否显示控制条（悬停或交互时显示）
    @State private var showControls: Bool = true
    
    /// 控制条自动隐藏计时器
    @State private var hideControlsTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    /// 初始化播放器场景视图
    /// - Parameters:
    ///   - appViewModel: 应用视图模型
    ///   - url: 媒体文件 URL
    init(appViewModel: AppViewModel, url: URL) {
        self.appViewModel = appViewModel
        let player = AVPlayer(url: url)
        _viewModel = StateObject(wrappedValue: PrismKit.PlayerViewModel(player: player))
    }
    
    /// 初始化播放器场景视图（用于测试）
    /// - Parameters:
    ///   - appViewModel: 应用视图模型
    ///   - player: AVPlayer 实例
    init(appViewModel: AppViewModel, player: AVPlayer) {
        self.appViewModel = appViewModel
        _viewModel = StateObject(wrappedValue: PrismKit.PlayerViewModel(player: player))
    }
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 0) {
            // 主播放区域
            ZStack {
                // 视频画布
                VideoPlayerLayer(player: viewModel)
                    .background(Color.black)
                
                // 顶部工具栏（显示关闭按钮等）
                VStack {
                    topBar
                        .opacity(showControls ? 1 : 0)
                    Spacer()
                }
                
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
            
            // 播放列表抽屉（右侧）
            if appViewModel.showPlaylistDrawer {
                PlaylistDrawerView(viewModel: appViewModel)
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showControls)
        .animation(.easeInOut(duration: 0.3), value: appViewModel.showPlaylistDrawer)
    }
    
    // MARK: - Subviews
    
    /// 顶部工具栏
    private var topBar: some View {
        HStack {
            // 关闭按钮（返回到欢迎页）
            Button {
                appViewModel.closePlayer(player: viewModel.player)
            } label: {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help(String(localized: "player.close"))
            
            Spacer()
            
            // 播放列表按钮
            Button {
                appViewModel.togglePlaylistDrawer()
            } label: {
                Image(systemName: appViewModel.showPlaylistDrawer ? "sidebar.right" : "sidebar.left")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help(String(localized: appViewModel.showPlaylistDrawer ? "playlist.hide" : "playlist.show"))
        }
        .padding(20)
    }
    
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
    let appViewModel = AppViewModel()
    if let url = Bundle.main.url(forResource: "sample-10s", withExtension: "mp4") {
        PlayerSceneView(appViewModel: appViewModel, url: url)
    } else {
        Text("未找到测试视频")
    }
}
