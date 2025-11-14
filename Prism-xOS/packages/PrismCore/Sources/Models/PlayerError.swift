//
//  PlayerError.swift
//  PrismCore
//
//  Created on 2025-11-14.
//  Purpose: 播放器错误类型定义
//

import AVFoundation
import Foundation

/// 播放器错误类型
///
/// 职责：
/// - 定义播放器可能遇到的各类错误
/// - 提供本地化的错误描述
/// - 便于错误追踪和日志记录
///
/// 使用场景：
/// 1. 文件加载失败（文件不存在、权限错误、格式不支持）
/// 2. 解码错误（编解码器不支持、文件损坏）
/// 3. 网络错误（网络中断、超时、服务器错误）
/// 4. 未知错误（其他 AVFoundation 错误）
public enum PlayerError: LocalizedError {

    /// 文件加载失败
    /// - Parameter reason: 失败原因描述
    case loadFailed(String)

    /// 解码错误
    /// - Parameter reason: 错误原因描述
    case decodingError(String)

    /// 网络错误
    /// - Parameter reason: 错误原因描述
    case networkError(String)

    /// 未知错误
    /// - Parameter reason: 错误原因描述
    case unknownError(String)

    // MARK: - LocalizedError

    /// 错误的本地化描述
    public var errorDescription: String? {
        switch self {
        case .loadFailed(let reason):
            return NSLocalizedString(
                "player.error.load_failed",
                comment: "文件加载失败"
            ) + ": \(reason)"

        case .decodingError(let reason):
            return NSLocalizedString(
                "player.error.decoding",
                comment: "解码错误"
            ) + ": \(reason)"

        case .networkError(let reason):
            return NSLocalizedString(
                "player.error.network",
                comment: "网络错误"
            ) + ": \(reason)"

        case .unknownError(let reason):
            return NSLocalizedString(
                "player.error.unknown",
                comment: "未知错误"
            ) + ": \(reason)"
        }
    }
    /// 错误的失败原因描述
    public var failureReason: String? {
        switch self {
        case .loadFailed:
            return NSLocalizedString(
                "player.error.load_failed.reason",
                comment: "无法加载媒体文件"
            )

        case .decodingError:
            return NSLocalizedString(
                "player.error.decoding.reason",
                comment: "视频解码失败"
            )

        case .networkError:
            return NSLocalizedString(
                "player.error.network.reason",
                comment: "网络连接问题"
            )

        case .unknownError:
            return NSLocalizedString(
                "player.error.unknown.reason",
                comment: "发生未知错误"
            )
        }
    }

    /// 错误的恢复建议
    public var recoverySuggestion: String? {
        switch self {
        case .loadFailed:
            return NSLocalizedString(
                "player.error.load_failed.recovery",
                comment: "请检查文件是否存在且格式正确"
            )

        case .decodingError:
            return NSLocalizedString(
                "player.error.decoding.recovery",
                comment: "请尝试使用其他播放器或转换格式"
            )

        case .networkError:
            return NSLocalizedString(
                "player.error.network.recovery",
                comment: "请检查网络连接后重试"
            )

        case .unknownError:
            return NSLocalizedString(
                "player.error.unknown.recovery",
                comment: "请重试或联系技术支持"
            )
        }
    }
}

// MARK: - AVError 转换

extension PlayerError {
    /// 从 AVFoundation 错误转换为 PlayerError
    /// - Parameter error: AVFoundation 错误
    /// - Returns: 转换后的 PlayerError
    public static func from(_ error: Error) -> PlayerError {
        let nsError = error as NSError

        // 根据错误域和代码分类
        switch nsError.domain {
        case AVFoundationErrorDomain:
            switch nsError.code {
            case AVError.fileFormatNotRecognized.rawValue,
                AVError.fileFailedToParse.rawValue:
                return .loadFailed(nsError.localizedDescription)

            case AVError.decoderNotFound.rawValue,
                AVError.decoderTemporarilyUnavailable.rawValue:
                return .decodingError(nsError.localizedDescription)

            default:
                return .unknownError(nsError.localizedDescription)
            }

        case NSURLErrorDomain:
            return .networkError(nsError.localizedDescription)

        default:
            return .unknownError(nsError.localizedDescription)
        }
    }
}
