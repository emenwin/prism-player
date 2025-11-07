// StateMachine.swift
// PrismCore
//
// 状态机协议定义
// 提供通用的状态机接口，支持事件驱动的状态转移与观察
//
// Created: 2025-11-07

import Foundation

/// 状态机协议
///
/// 定义状态机的核心行为：
/// - 事件驱动的状态转移
/// - 状态观察（AsyncStream）
/// - 线程安全（Actor）
///
/// ## 使用示例
/// ```swift
/// actor MyStateMachine: StateMachine {
///     typealias State = MyState
///     typealias Event = MyEvent
///
///     private(set) var currentState: MyState = .idle
///     private let stateContinuation: AsyncStream<MyState>.Continuation
///
///     init() {
///         let (stream, continuation) = AsyncStream<MyState>.makeStream()
///         self.statePublisher = stream
///         self.stateContinuation = continuation
///     }
///
///     func send(_ event: MyEvent) async throws {
///         // 处理事件并转移状态
///     }
/// }
/// ```
public protocol StateMachine: Actor {
    /// 状态类型
    associatedtype State

    /// 事件类型
    associatedtype Event

    /// 当前状态流（用于观察状态变化）
    ///
    /// 订阅者可以通过 `for await` 循环监听状态变化：
    /// ```swift
    /// for await state in stateMachine.statePublisher {
    ///     print("New state: \(state)")
    /// }
    /// ```
    var statePublisher: AsyncStream<State> { get }

    /// 发送事件以触发状态转移
    ///
    /// - Parameter event: 要发送的事件
    /// - Throws: `StateMachineError` 如果转移非法或内部错误
    ///
    /// ## 线程安全
    /// 此方法在 Actor 上下文中执行，保证顺序处理事件
    func send(_ event: Event) async throws

    /// 当前状态快照（只读）
    ///
    /// - Note: 仅用于调试和测试，生产代码应使用 `statePublisher` 观察状态
    var currentState: State { get async }
}

// MARK: - State Machine Error

/// 状态机错误
public enum StateMachineError: Error, LocalizedError, Equatable, Sendable {
    /// 非法状态转移
    /// - Parameters:
    ///   - from: 当前状态描述
    ///   - event: 触发转移的事件描述
    case illegalTransition(from: String, event: String)

    /// 内部错误
    /// - Parameter description: 错误描述
    case internalError(String)

    /// 状态机已被销毁
    case disposed

    /// 超时
    /// - Parameters:
    ///   - operation: 操作描述
    ///   - timeout: 超时时长（秒）
    case timeout(operation: String, timeout: TimeInterval)

    public var errorDescription: String? {
        switch self {
        case .illegalTransition(let from, let event):
            return "Illegal state transition: cannot handle event '\(event)' in state '\(from)'"
        case .internalError(let description):
            return "State machine internal error: \(description)"
        case .disposed:
            return "State machine has been disposed"
        case .timeout(let operation, let timeout):
            return
                "State machine operation '\(operation)' timed out after \(String(format: "%.1f", timeout))s"
        }
    }
}

// MARK: - State Observer

/// 状态观察者辅助类型
///
/// 提供类型安全的状态订阅
public struct StateObserver<State: Sendable>: Sendable {
    /// 状态流
    public let stream: AsyncStream<State>

    /// 创建观察者
    /// - Parameter stream: 状态流
    public init(stream: AsyncStream<State>) {
        self.stream = stream
    }

    /// 订阅状态变化
    /// - Parameter handler: 状态处理闭包
    public func observe(_ handler: @escaping @Sendable (State) async -> Void) async {
        for await state in stream {
            await handler(state)
        }
    }

    /// 过滤特定状态
    /// - Parameter predicate: 过滤条件
    /// - Returns: 过滤后的流
    public func filter(_ predicate: @escaping @Sendable (State) -> Bool) -> AsyncStream<State> {
        AsyncStream { continuation in
            Task {
                for await state in stream {
                    if predicate(state) {
                        continuation.yield(state)
                    }
                }
                continuation.finish()
            }
        }
    }
}
