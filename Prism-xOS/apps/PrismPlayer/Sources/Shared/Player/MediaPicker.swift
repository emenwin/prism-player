//
//  MediaPicker.swift
//  PrismPlayer
//
//  Created on 2025-10-28.
//

import Foundation
import UniformTypeIdentifiers

/// 媒体选择器协议
///
/// 平台实现：
/// - iOS: MediaPickeriOS（基于 UIDocumentPickerViewController）
/// - macOS: MediaPickerMac（基于 NSOpenPanel）
///
/// 职责：跨平台媒体文件选择抽象
protocol MediaPicker {
    /// 选择媒体文件
    /// - Parameter allowedTypes: 允许的文件类型（UTType）
    /// - Returns: 选中的文件 URL，用户取消返回 nil
    /// - Throws: 文件访问权限错误或系统错误
    func selectMedia(allowedTypes: [UTType]) async throws -> URL?
}

/// 预定义的媒体类型集合
extension MediaPicker {
    /// 支持的媒体类型
    static var supportedMediaTypes: [UTType] {
        [
            .movie,           // 通用视频
            .mpeg4Movie,      // mp4
            .quickTimeMovie,  // mov
            .audio,           // 通用音频
            .mp3,             // mp3
            .mpeg4Audio,      // m4a/aac
            .wav              // wav
        ]
    }
}
