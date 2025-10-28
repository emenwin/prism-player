//
//  VideoPlayerView.swift
//  PrismPlayer
//
//  Created on 2025-10-28.
//  Purpose: iOS video rendering using AVPlayerLayer (PR4 Commit 2)
//

#if os(iOS)
    import AVFoundation
    import SwiftUI
    import UIKit

    /// iOS 视频播放器视图（基于 AVPlayerLayer）
    ///
    /// 职责：
    /// - 将 AVPlayer 渲染到 SwiftUI 视图中
    /// - 处理视频图层的布局与生命周期
    /// - 支持视频重力模式（aspect fill/fit）
    ///
    /// Target Membership: iOS only
    struct VideoPlayerView: UIViewRepresentable {
        let player: AVPlayer?
        var videoGravity: AVLayerVideoGravity = .resizeAspect

        func makeUIView(context: Context) -> VideoPlayerUIView {
            let view = VideoPlayerUIView()
            view.playerLayer.videoGravity = videoGravity
            return view
        }

        func updateUIView(_ uiView: VideoPlayerUIView, context: Context) {
            uiView.playerLayer.player = player
            uiView.playerLayer.videoGravity = videoGravity
        }
    }

    /// UIView 包装器，包含 AVPlayerLayer
    final class VideoPlayerUIView: UIView {
        override class var layerClass: AnyClass {
            AVPlayerLayer.self
        }

        var playerLayer: AVPlayerLayer {
            layer as! AVPlayerLayer
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .black
            playerLayer.videoGravity = .resizeAspect
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }

#endif
