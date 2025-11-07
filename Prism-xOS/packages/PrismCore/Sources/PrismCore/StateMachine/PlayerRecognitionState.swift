// PlayerRecognitionState.swift
// PrismCore
//
// 播放器与识别状态机 - 状态定义
// 用于管理播放器的核心状态转移，包括播放、识别、拖动等场景
//
// Created: 2025-11-07

import Foundation

/// 播放器与识别系统的统一状态枚举
///
/// 状态转移规则：
/// - idle → loading（加载媒体）
/// - loading → playing（播放开始）
/// - loading → error（加载失败）
/// - playing → paused（暂停）
/// - playing → recognizing（开始识别）
/// - playing → loading（seek 跳转）
/// - paused → playing（恢复播放）
/// - paused → loading（seek 跳转）
/// - recognizing → playing（识别完成或取消）
/// - recognizing → error（识别失败）
/// - error → idle（错误恢复）
public enum PlayerRecognitionState: Equatable, Sendable {
    /// 空闲状态：未加载任何媒体
    case idle

    /// 加载状态：正在加载媒体文件
    /// - Parameter mediaURL: 正在加载的媒体文件 URL
    case loading(mediaURL: URL)

    /// 播放状态：正在播放媒体
    /// - Parameter progress: 当前播放进度（秒）
    case playing(progress: TimeInterval)

    /// 暂停状态：媒体已暂停
    /// - Parameter at: 暂停时的播放位置（秒）
    case paused(at: TimeInterval)

    /// 识别状态：正在进行语音识别
    /// - Parameters:
    ///   - window: 正在识别的时间窗口
    ///   - seekId: 关联的 seek 操作 ID（用于取消标识）
    case recognizing(window: TimeRange, seekId: UUID?)

    /// 错误状态：系统发生错误
    /// - Parameters:
    ///   - error: 错误详情
    ///   - recoverable: 是否可恢复（true = 可重试，false = 不可恢复）
    case error(PlayerError, recoverable: Bool)
}

// MARK: - Computed Properties

extension PlayerRecognitionState {
    /// 当前状态的简短描述（用于日志）
    public var description: String {
        switch self {
        case .idle:
            return "idle"
        case .loading(let url):
            return "loading(\(url.lastPathComponent))"
        case .playing(let progress):
            return "playing(\(String(format: "%.1f", progress))s)"
        case .paused(let at):
            return "paused(\(String(format: "%.1f", at))s)"
        case .recognizing(let window, let seekId):
            let seekIdStr = seekId.map { $0.uuidString.prefix(8) } ?? "nil"
            return "recognizing(\(window.description), seekId:\(seekIdStr))"
        case .error(let error, let recoverable):
            return "error(\(error.localizedDescription), recoverable:\(recoverable))"
        }
    }

    /// 是否为终态（需要外部干预才能转移）
    public var isTerminal: Bool {
        switch self {
        case .error(_, let recoverable):
            return !recoverable
        default:
            return false
        }
    }

    /// 是否正在执行异步操作
    public var isProcessing: Bool {
        switch self {
        case .loading, .recognizing:
            return true
        default:
            return false
        }
    }

    /// 当前播放位置（如果可用）
    public var currentPosition: TimeInterval? {
        switch self {
        case .playing(let progress):
            return progress
        case .paused(let at):
            return at
        case .recognizing(let window, _):
            return window.start
        default:
            return nil
        }
    }
}

// MARK: - State Transition Validation

extension PlayerRecognitionState {
    /// 检查是否可以转移到目标状态
    /// - Parameter target: 目标状态
    /// - Returns: 是否允许转移
    public func canTransition(to target: PlayerRecognitionState) -> Bool {
        // 终态无法转移（除非显式恢复到 idle）
        guard !isTerminal || (isTerminal && isIdleState(target)) else {
            return false
        }

        switch (self, target) {
        // idle 可以转移到 loading 或保持 idle
        case (.idle, .loading), (.idle, .idle):
            return true

        // loading 可以转移到 playing、error 或重新 loading
        case (.loading, .playing), (.loading, .error), (.loading, .loading):
            return true

        // playing 可以转移到 paused、recognizing、loading，或保持 playing（progressUpdate）
        case (.playing, .paused), (.playing, .recognizing), (.playing, .loading),
            (.playing, .playing):
            return true

        // paused 可以转移到 playing、loading，或保持 paused（seek）
        case (.paused, .playing), (.paused, .loading), (.paused, .paused):
            return true

        // recognizing 可以转移到 playing 或 error
        case (.recognizing, .playing), (.recognizing, .error):
            return true

        // error 可以恢复到 idle
        case (.error, .idle):
            return true

        // 任何状态都可以 reset 到 idle
        case (_, .idle):
            return true

        default:
            return false
        }
    }

    /// 判断是否为 idle 状态
    private func isIdleState(_ state: PlayerRecognitionState) -> Bool {
        if case .idle = state {
            return true
        }
        return false
    }
}
