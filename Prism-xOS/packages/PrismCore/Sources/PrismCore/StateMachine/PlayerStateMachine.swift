// PlayerStateMachine.swift
// PrismCore
//
// 播放器与识别状态机 - Actor 实现
// 管理播放器的所有状态转移，提供线程安全的事件处理
//
// Created: 2025-11-07
// Sprint: S1, Task-104, PR2

import Foundation
import OSLog

/// 播放器状态机 Actor 实现
///
/// 核心职责：
/// - 管理 6 种播放器状态的转移
/// - 处理 8 种事件类型
/// - 提供状态观察（AsyncStream）
/// - 保证线程安全与顺序处理
///
/// ## 使用示例
/// ```swift
/// let stateMachine = PlayerStateMachine()
///
/// // 订阅状态变化
/// Task {
///     for await state in stateMachine.statePublisher {
///         print("State changed: \(state)")
///     }
/// }
///
/// // 发送事件
/// try await stateMachine.send(.loadMedia(url))
/// try await stateMachine.send(.play)
/// ```
public actor PlayerStateMachine: StateMachine {
    // MARK: - Types

    public typealias State = PlayerRecognitionState
    public typealias Event = PlayerEvent

    // MARK: - Properties

    /// 当前状态（只读）
    public private(set) var currentState: PlayerRecognitionState = .idle

    /// 状态发布流
    public let statePublisher: AsyncStream<PlayerRecognitionState>

    /// 状态流的 Continuation（用于发布新状态）
    private let stateContinuation: AsyncStream<PlayerRecognitionState>.Continuation

    /// 日志记录器
    private let logger: Logger

    /// 状态进入时间戳（用于计算停留时长）
    private var stateEnteredAt: Date = Date()

    /// 性能指标：状态转移历史（用于调试，最多保留最近 20 个）
    private var transitionHistory:
        [(from: State, to: State, event: Event, duration: TimeInterval)] = []
    private let maxHistorySize = 20

    // MARK: - seekId 管理（PR3）

    /// 当前活跃的 seekId（用于取消管理）
    private var activeSeekId: UUID?

    /// 已取消的 seekId 集合（用于幂等取消）
    private var cancelledSeekIds: Set<UUID> = []

    /// 最大缓存的已取消 seekId 数量（防止内存泄漏）
    private let maxCancelledSeekIds = 100

    // MARK: - Initialization

    /// 创建播放器状态机
    public init() {
        // 创建状态发布流
        let (stream, continuation) = AsyncStream<PlayerRecognitionState>.makeStream()
        self.statePublisher = stream
        self.stateContinuation = continuation

        // 创建日志记录器
        self.logger = Logger(subsystem: "com.prism.core", category: "StateMachine")

        // 发布初始状态
        continuation.yield(.idle)

        logger.info("PlayerStateMachine initialized with state: idle")
    }

    deinit {
        stateContinuation.finish()
        logger.info("PlayerStateMachine deinitialized")
    }

    // MARK: - StateMachine Protocol

    /// 发送事件以触发状态转移
    ///
    /// - Parameter event: 要处理的事件
    /// - Throws: StateMachineError 如果转移非法
    public func send(_ event: PlayerEvent) async throws {
        let startTime = Date()
        let oldState = currentState

        logger.debug("Received event: \(event.description) in state: \(oldState.description)")

        // 处理事件并转移状态
        let newState = try await handleEvent(event, currentState: oldState)

        // 如果状态发生变化，执行转移
        if newState != oldState {
            try performTransition(from: oldState, to: newState, event: event)

            let duration = Date().timeIntervalSince(startTime)
            logger.info(
                """
                State transition: \(oldState.description) -> \(newState.description), \
                event: \(event.description), duration: \(String(format: "%.2f", duration * 1000))ms
                """
            )

            // 记录转移历史
            recordTransition(from: oldState, to: newState, event: event, duration: duration)
        } else {
            logger.debug(
                "Event \(event.description) did not change state (still \(oldState.description))")
        }
    }

    // MARK: - seekId 管理（PR3）

    /// 检查指定的 seekId 是否已被取消
    ///
    /// 外部任务（如识别引擎）可以调用此方法检查是否应该中止
    ///
    /// - Parameter seekId: 要检查的 seekId
    /// - Returns: true 表示已取消，false 表示仍然有效
    public func isSeekCancelled(_ seekId: UUID) -> Bool {
        return cancelledSeekIds.contains(seekId)
    }

    /// 获取当前活跃的 seekId
    ///
    /// - Returns: 当前 seekId，如果没有则返回 nil
    public func currentSeekId() -> UUID? {
        return activeSeekId
    }

    // MARK: - Event Handling

    /// 处理事件并返回新状态
    ///
    /// - Parameters:
    ///   - event: 事件
    ///   - currentState: 当前状态
    /// - Returns: 新状态
    /// - Throws: StateMachineError 如果转移非法
    private func handleEvent(_ event: PlayerEvent, currentState: State) async throws -> State {
        switch (currentState, event) {
        // MARK: - idle 状态处理

        case (.idle, .loadMedia(let url)):
            return .loading(mediaURL: url)

        case (.idle, .reset):
            return .idle  // 保持 idle

        // MARK: - loading 状态处理

        case (.loading, .play):
            // 加载完成后开始播放
            return .playing(progress: 0)

        case let (.loading(url), .loadMedia):
            // 允许在加载时切换媒体（取消当前加载）
            logger.warning("Loading interrupted by new loadMedia event")
            return .loading(mediaURL: url)

        case (.loading, .recognitionFailed(let error)):
            // 加载过程中的错误（例如音频提取失败）
            let playerError = PlayerError.from(error, context: "media loading")
            return .error(playerError, recoverable: playerError.isRecoverable)

        // MARK: - playing 状态处理

        case (.playing, .pause):
            if case .playing(let progress) = currentState {
                return .paused(at: progress)
            }
            throw StateMachineError.internalError("playing state should have progress")

        case (.playing, .progressUpdate(let newProgress)):
            return .playing(progress: newProgress)

        case (.playing, .seek(let time, let seekId)):
            // PR3: seekId 并发控制
            // 1. 记录旧 seekId（用于日志）
            let oldSeekId = activeSeekId

            // 2. 更新活跃 seekId
            activeSeekId = seekId

            // 3. 如果有旧 seekId，标记为已取消
            if let old = oldSeekId {
                cancelledSeekIds.insert(old)
                logger.debug(
                    """
                    Seek replaced previous seek: \
                    old=\(old.uuidString.prefix(8)), new=\(seekId.uuidString.prefix(8))
                    """
                )
            }

            logger.debug(
                "Seek initiated: to \(String(format: "%.1f", time))s, seekId: \(seekId.uuidString.prefix(8))"
            )

            // 4. 清理过多的已取消 seekId（防止内存泄漏）
            if cancelledSeekIds.count > maxCancelledSeekIds {
                // 移除最旧的一半
                let toRemove = cancelledSeekIds.prefix(maxCancelledSeekIds / 2)
                cancelledSeekIds.subtract(toRemove)
                logger.debug("Cleaned up \(toRemove.count) old cancelled seekIds")
            }

            // 5. 转移到 playing 状态（简化实现，实际可能需要 loading）
            return .playing(progress: time)

        case (.playing, .startRecognition(let window)):
            // PR3: 将当前 seekId 传递给 recognizing 状态
            // 这样 seek 事件可以中断识别
            let currentSeekId = activeSeekId
            logger.debug(
                """
                Starting recognition for window \(window), \
                seekId: \(currentSeekId?.uuidString.prefix(8) ?? "nil")
                """
            )
            return .recognizing(window: window, seekId: currentSeekId)

        case (.playing, .reset):
            return .idle

        // MARK: - paused 状态处理

        case (.paused, .play):
            if case .paused(let at) = currentState {
                return .playing(progress: at)
            }
            throw StateMachineError.internalError("paused state should have position")

        case (.paused, .seek(let time, let seekId)):
            // PR3: 更新 seekId（paused 状态也需要取消管理）
            let oldSeekId = activeSeekId
            activeSeekId = seekId

            if let old = oldSeekId {
                cancelledSeekIds.insert(old)
            }

            logger.debug(
                """
                Seek from paused state: to \(String(format: "%.1f", time))s, \
                seekId: \(seekId.uuidString.prefix(8))
                """
            )
            return .paused(at: time)

        case (.paused, .reset):
            return .idle

        // MARK: - recognizing 状态处理

        case (.recognizing, .recognitionCompleted):
            // 识别完成，返回播放状态
            if case .recognizing(let window, _) = currentState {
                // 返回到窗口结束位置
                return .playing(progress: window.end)
            }
            throw StateMachineError.internalError("recognizing state should have window")

        case (.recognizing, .cancel(let seekId)):
            // PR3: 幂等取消 - 根据 seekId 判断是否需要取消
            if case .recognizing(let window, let recognizingSeekId) = currentState {
                // 如果指定了 seekId，检查是否匹配
                if let targetSeekId = seekId {
                    // 检查是否已经取消过
                    if cancelledSeekIds.contains(targetSeekId) {
                        logger.debug(
                            """
                            Cancel ignored: seekId \(targetSeekId.uuidString.prefix(8)) \
                            already cancelled (idempotent)
                            """
                        )
                        return currentState  // 幂等：保持当前状态
                    }

                    // 检查 seekId 是否匹配
                    if recognizingSeekId == targetSeekId {
                        cancelledSeekIds.insert(targetSeekId)
                        logger.info(
                            """
                            Recognition cancelled: seekId=\(targetSeekId.uuidString.prefix(8)), \
                            returning to \(String(format: "%.1f", window.start))s
                            """
                        )
                        return .playing(progress: window.start)
                    } else {
                        // seekId 不匹配，忽略取消请求
                        logger.debug(
                            """
                            Cancel ignored: seekId mismatch \
                            (requested=\(targetSeekId.uuidString.prefix(8)), \
                            current=\(recognizingSeekId?.uuidString.prefix(8) ?? "nil"))
                            """
                        )
                        return currentState
                    }
                } else {
                    // 未指定 seekId，取消当前识别
                    logger.info(
                        "Recognition cancelled (no seekId specified), returning to \(String(format: "%.1f", window.start))s"
                    )
                    return .playing(progress: window.start)
                }
            }
            throw StateMachineError.internalError("recognizing state should have window")

        case (.recognizing, .seek(let time, let seekId)):
            // PR3: seek 中断识别，更新 seekId
            let oldSeekId = activeSeekId
            activeSeekId = seekId

            if let old = oldSeekId {
                cancelledSeekIds.insert(old)
            }

            logger.warning(
                """
                Recognition interrupted by seek to \(String(format: "%.1f", time))s, \
                seekId: \(seekId.uuidString.prefix(8))
                """
            )
            return .playing(progress: time)

        case (.recognizing, .recognitionFailed(let error)):
            let playerError = PlayerError.from(error, context: "recognition")
            return .error(playerError, recoverable: playerError.isRecoverable)

        // MARK: - error 状态处理

        case (.error(_, let recoverable), .retry):
            if recoverable {
                return .idle
            } else {
                throw StateMachineError.illegalTransition(
                    from: currentState.description,
                    event: "retry on unrecoverable error"
                )
            }

        case (.error, .reset):
            return .idle

        // MARK: - 全局处理

        case (_, .reset):
            // 任何状态都可以 reset 到 idle
            logger.info("Reset to idle from state: \(currentState.description)")
            return .idle

        // MARK: - 非法转移

        default:
            throw StateMachineError.illegalTransition(
                from: currentState.description,
                event: event.description
            )
        }
    }

    /// 执行状态转移
    ///
    /// - Parameters:
    ///   - oldState: 旧状态
    ///   - newState: 新状态
    ///   - event: 触发转移的事件
    /// - Throws: StateMachineError 如果转移验证失败
    private func performTransition(from oldState: State, to newState: State, event: Event) throws {
        // 验证转移合法性
        guard oldState.canTransition(to: newState) else {
            logger.error(
                "Invalid transition attempted: \(oldState.description) -> \(newState.description)"
            )
            throw StateMachineError.illegalTransition(
                from: oldState.description,
                event: event.description
            )
        }

        // 记录退出旧状态
        let timeInOldState = Date().timeIntervalSince(stateEnteredAt)
        logger.debug(
            "state_exit: \(oldState.description), duration_in_state: \(String(format: "%.2f", timeInOldState * 1000))ms"
        )

        // 更新状态
        currentState = newState
        stateEnteredAt = Date()

        // 记录进入新状态
        logger.debug("state_enter: \(newState.description), from: \(oldState.description)")

        // 发布新状态
        stateContinuation.yield(newState)
    }

    /// 记录状态转移历史（用于调试和性能分析）
    ///
    /// - Parameters:
    ///   - from: 源状态
    ///   - to: 目标状态
    ///   - event: 触发事件
    ///   - duration: 转移耗时（秒）
    private func recordTransition(from: State, to: State, event: Event, duration: TimeInterval) {
        transitionHistory.append((from: from, to: to, event: event, duration: duration))

        // 保持历史记录在限制内
        if transitionHistory.count > maxHistorySize {
            transitionHistory.removeFirst()
        }
    }

    // MARK: - Public Inspection Methods

    /// 获取状态转移历史（用于调试）
    ///
    /// - Returns: 最近的状态转移记录
    public func getTransitionHistory() -> [(
        from: String, to: String, event: String, durationMs: Double
    )] {
        return transitionHistory.map { record in
            (
                from: record.from.description,
                to: record.to.description,
                event: record.event.description,
                durationMs: record.duration * 1000
            )
        }
    }

    /// 获取当前状态在该状态的停留时长（秒）
    ///
    /// - Returns: 停留时长
    public func getTimeInCurrentState() -> TimeInterval {
        return Date().timeIntervalSince(stateEnteredAt)
    }
}
