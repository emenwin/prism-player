// PlayerEvent.swift
// PrismCore
//
// 播放器与识别状态机 - 事件定义
// 定义所有可能触发状态转移的事件类型
//
// Created: 2025-11-07

import Foundation

/// 播放器事件枚举
///
/// 事件驱动状态机转移，每个事件对应一个或多个可能的状态转移
public enum PlayerEvent: Equatable, Sendable {
    // MARK: - 媒体控制事件

    /// 加载媒体文件
    /// - Parameter url: 媒体文件 URL
    case loadMedia(URL)

    /// 开始播放
    case play

    /// 暂停播放
    case pause

    /// 跳转到指定时间
    /// - Parameters:
    ///   - to: 目标时间（秒）
    ///   - seekId: 跳转操作的唯一标识（用于取消管理）
    case seek(to: TimeInterval, seekId: UUID)

    /// 播放进度更新（定时触发）
    /// - Parameter progress: 当前播放进度（秒）
    case progressUpdate(TimeInterval)

    // MARK: - 识别控制事件

    /// 开始语音识别
    /// - Parameter window: 要识别的时间窗口
    case startRecognition(TimeRange)

    /// 识别完成
    case recognitionCompleted

    /// 识别失败
    /// - Parameter error: 失败原因
    case recognitionFailed(Error)

    // MARK: - 取消事件

    /// 取消操作
    /// - Parameter seekId: 要取消的操作 ID（nil 表示取消所有）
    case cancel(seekId: UUID?)

    // MARK: - 错误恢复事件

    /// 从错误状态恢复
    case retry

    /// 重置到空闲状态
    case reset
}

// MARK: - Computed Properties

extension PlayerEvent {
    /// 事件的简短描述（用于日志）
    public var description: String {
        switch self {
        case .loadMedia(let url):
            return "loadMedia(\(url.lastPathComponent))"
        case .play:
            return "play"
        case .pause:
            return "pause"
        case .seek(let time, let seekId):
            return "seek(to:\(String(format: "%.1f", time))s, id:\(seekId.uuidString.prefix(8)))"
        case .progressUpdate(let progress):
            return "progressUpdate(\(String(format: "%.1f", progress))s)"
        case .startRecognition(let window):
            return "startRecognition(\(window.description))"
        case .recognitionCompleted:
            return "recognitionCompleted"
        case .recognitionFailed(let error):
            return "recognitionFailed(\(error.localizedDescription))"
        case .cancel(let seekId):
            if let seekId = seekId {
                return "cancel(\(seekId.uuidString.prefix(8)))"
            } else {
                return "cancel(all)"
            }
        case .retry:
            return "retry"
        case .reset:
            return "reset"
        }
    }

    /// 事件优先级（用于调度）
    /// 值越大优先级越高
    public var priority: Int {
        switch self {
        case .cancel:
            return 100  // 最高优先级
        case .loadMedia, .play, .pause, .seek:
            return 50  // 用户交互事件
        case .startRecognition, .recognitionCompleted, .recognitionFailed:
            return 30  // 后台任务事件
        case .progressUpdate:
            return 10  // 定时事件
        case .retry, .reset:
            return 20  // 恢复事件
        }
    }

    /// 是否为用户主动触发的事件
    public var isUserInitiated: Bool {
        switch self {
        case .loadMedia, .play, .pause, .seek, .retry, .reset:
            return true
        case .progressUpdate, .startRecognition, .recognitionCompleted, .recognitionFailed, .cancel:
            return false
        }
    }
}

// MARK: - Equatable (Custom Implementation)

extension PlayerEvent {
    public static func == (lhs: PlayerEvent, rhs: PlayerEvent) -> Bool {
        switch (lhs, rhs) {
        case (.loadMedia(let lUrl), .loadMedia(let rUrl)):
            return lUrl == rUrl
        case (.play, .play), (.pause, .pause):
            return true
        case (.seek(let lTime, let lId), .seek(let rTime, let rId)):
            return lTime == rTime && lId == rId
        case (.progressUpdate(let lProgress), .progressUpdate(let rProgress)):
            return lProgress == rProgress
        case (.startRecognition(let lWindow), .startRecognition(let rWindow)):
            return lWindow == rWindow
        case (.recognitionCompleted, .recognitionCompleted):
            return true
        case (.recognitionFailed(let lError), .recognitionFailed(let rError)):
            return lError.localizedDescription == rError.localizedDescription
        case (.cancel(let lId), .cancel(let rId)):
            return lId == rId
        case (.retry, .retry), (.reset, .reset):
            return true
        default:
            return false
        }
    }
}
