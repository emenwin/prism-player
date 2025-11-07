// TestMediaURL.swift
// PrismCoreTests
//
// 测试用媒体 URL 常量
// 提供各种测试场景的媒体文件引用
//
// Created: 2025-11-07
// Sprint: S1, Task-104, PR2

import Foundation

/// 测试媒体 URL 常量
///
/// 提供各种测试场景所需的媒体文件 URL
public enum TestMediaURL {
    /// 有效的本地视频文件（用于正常流程测试）
    public static let validVideo = URL(fileURLWithPath: "/tmp/test-video.mp4")

    /// 有效的本地音频文件
    public static let validAudio = URL(fileURLWithPath: "/tmp/test-audio.mp3")

    /// 不存在的文件（用于错误测试）
    public static let nonExistent = URL(fileURLWithPath: "/tmp/non-existent.mp4")

    /// 不支持的格式（用于格式错误测试）
    public static let unsupportedFormat = URL(fileURLWithPath: "/tmp/test.unsupported")

    /// 远程 URL（用于网络场景测试）
    public static let remote = URL(string: "https://example.com/test-video.mp4")!

    /// 生成指定文件名的临时 URL
    /// - Parameter filename: 文件名
    /// - Returns: 临时目录中的文件 URL
    public static func temporary(filename: String) -> URL {
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(filename)
    }
}
