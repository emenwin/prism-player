//
//  VideoPlayerView.swift
//  PrismPlayer
//
//  Created on 2025-10-28.
//  Purpose: macOS video rendering using AVPlayerView (PR4 Commit 2)
//

#if os(macOS)
    import AVFoundation
    import AVKit
    import SwiftUI

    /// macOS 视频播放器视图（基于 AVPlayerView）
    ///
    /// 职责：
    /// - 将 AVPlayer 渲染到 SwiftUI 视图中
    /// - 使用 AVPlayerView 的原生控制器（可选）
    /// - 支持视频重力模式
    ///
    /// Target Membership: macOS only
    struct VideoPlayerView: NSViewRepresentable {
        let player: AVPlayer?
        var showsControls: Bool = false
        var videoGravity: AVLayerVideoGravity = .resizeAspect

        func makeNSView(context: Context) -> AVPlayerView {
            let view = AVPlayerView()
            view.controlsStyle = showsControls ? .default : .none
            view.videoGravity = videoGravity
            return view
        }

        func updateNSView(_ nsView: AVPlayerView, context: Context) {
            nsView.player = player
            nsView.controlsStyle = showsControls ? .default : .none
            nsView.videoGravity = videoGravity
        }
    }

#endif
