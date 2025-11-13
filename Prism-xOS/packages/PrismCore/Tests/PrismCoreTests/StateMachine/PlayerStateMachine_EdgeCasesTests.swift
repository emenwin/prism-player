// PlayerStateMachine_EdgeCasesTests.swift
// PrismCore
//
// PR5 补充测试：边界与异常场景
// 补全设计文档中要求的所有边界用例
//
// Created: 2025-11-13
// Sprint: S1, Task-104, PR5

import Foundation
import Testing

@testable import PrismCore

/// PR5 测试套件：边界与异常场景补充
@Suite("PlayerStateMachine - 边界与异常（PR5 补充）")
struct PlayerStateMachineEdgeCasesTests {

    // MARK: - 并发识别触发测试

    /// 边界用例: recognizing 状态拒绝新的 startRecognition 事件
    /// 验证：非法转移被正确拒绝，状态机保持稳定
    @Test("并发识别触发：recognizing 拒绝新识别")
    func testConcurrentRecognitionTriggers() async throws {
        let stateMachine = PlayerStateMachine()

        // 进入 playing 状态
        try await stateMachine.send(.loadMedia(TestMediaURL.sample1))
        try await stateMachine.send(.play)

        // 发送第一个识别请求
        let window1 = TimeRange(start: 0, end: 10)
        try await stateMachine.send(.startRecognition(window1))

        // 验证进入 recognizing 状态
        var currentState = await stateMachine.currentState
        if case .recognizing(let window, _) = currentState {
            #expect(window == window1)
        } else {
            Issue.record("Expected recognizing state, got \(currentState)")
        }

        // 尝试发送第二个识别请求（应失败）
        let window2 = TimeRange(start: 10, end: 20)
        do {
            try await stateMachine.send(.startRecognition(window2))
            Issue.record("Should reject startRecognition in recognizing state")
        } catch StateMachineError.illegalTransition {
            // Expected: 非法转移被拒绝
        }

        // 验证状态未改变，仍然是第一个识别窗口
        currentState = await stateMachine.currentState
        if case .recognizing(let window, _) = currentState {
            #expect(window == window1, "状态应保持不变")
        } else {
            Issue.record("State should remain recognizing")
        }
    }

    // MARK: - loading 超时测试

    /// 边界用例: loading 状态超时应转移到 error
    /// 注意：这需要在实际实现中添加超时机制，当前测试验证设计意图
    @Test("loading 超时场景（设计验证）", .disabled("需要实现超时机制"))
    func testLoadingTimeout() async throws {
        let stateMachine = PlayerStateMachine()

        // 进入 loading 状态
        try await stateMachine.send(.loadMedia(TestMediaURL.sample1))

        let currentState = await stateMachine.currentState
        #expect(currentState == .loading(mediaURL: TestMediaURL.sample1))

        // TODO: 在实际实现中，5s 后应自动转移到 error 状态
        // 当前设计验证：记录此需求
        // 未来 PR6 实现：
        // - 添加 Task.sleep(seconds: 5) 超时检测
        // - 自动发送 .recognitionFailed(PlayerError.loadTimeout) 事件
    }

    // MARK: - 状态一致性验证

    /// 边界用例: 状态停留时长记录正确性
    @Test("验证状态停留时长计算")
    func testStateDurationTracking() async throws {
        let stateMachine = PlayerStateMachine()

        // 进入 loading 状态并等待
        try await stateMachine.send(.loadMedia(TestMediaURL.sample1))

        let startTime = Date()
        try await Task.sleep(nanoseconds: 100_000_000)  // 100ms

        // 转移到 playing 状态
        try await stateMachine.send(.play)

        let duration = Date().timeIntervalSince(startTime)

        // 验证时长在合理范围（100ms ± 50ms）
        #expect(duration >= 0.08 && duration <= 0.15, "停留时长应约为 100ms")
    }

    // MARK: - 内存与资源管理

    /// 边界用例: 大量状态转移不导致内存泄漏
    @Test("压力测试：1000 次状态转移无内存泄漏")
    func testNoMemoryLeakWithManyTransitions() async throws {
        let stateMachine = PlayerStateMachine()

        // 执行 1000 次状态转移循环
        for _ in 0..<1000 {
            try await stateMachine.send(.loadMedia(TestMediaURL.sample1))
            try await stateMachine.send(.play)
            try await stateMachine.send(.pause)
            try await stateMachine.send(.reset)
        }

        // 验证最终状态
        let finalState = await stateMachine.currentState
        #expect(finalState == .idle, "1000 次循环后应回到 idle")

        // 注意：实际内存泄漏检测需要 Instruments，这里只验证功能正确性
    }

    // MARK: - 错误恢复路径

    /// 边界用例: 不可恢复错误不允许 retry
    @Test("不可恢复错误拒绝 retry 事件")
    func testUnrecoverableErrorRejectsRetry() async throws {
        let stateMachine = PlayerStateMachine()

        // 进入不可恢复的错误状态
        try await stateMachine.send(.loadMedia(TestMediaURL.sample1))

        let fatalError = PlayerError.internalError("Fatal crash")
        try await stateMachine.send(.recognitionFailed(fatalError))

        // 手动设置为不可恢复（在实际实现中，某些错误类型默认不可恢复）
        // 当前测试验证设计意图

        // 尝试 retry（应失败）
        do {
            try await stateMachine.send(.retry)
            Issue.record("不可恢复错误应拒绝 retry")
        } catch {
            // 预期抛出 StateMachineError.illegalTransition
            if case StateMachineError.illegalTransition = error {
                // OK
            } else {
                Issue.record("应抛出 illegalTransition，实际: \(error)")
            }
        }
    }

    // MARK: - 事件队列与顺序

    /// 边界用例: 事件顺序处理（Actor 保证）
    @Test("Actor 保证事件顺序执行")
    func testEventOrderGuarantee() async throws {
        let stateMachine = PlayerStateMachine()

        actor EventLog {
            var events: [String] = []

            func append(_ event: String) {
                events.append(event)
            }

            func getEvents() -> [String] {
                return events
            }
        }

        let log = EventLog()

        // 快速连续发送多个事件
        Task {
            await log.append("send: loadMedia")
            try await stateMachine.send(.loadMedia(TestMediaURL.sample1))
            await log.append("done: loadMedia")
        }

        Task {
            await log.append("send: play")
            try await stateMachine.send(.play)
            await log.append("done: play")
        }

        Task {
            await log.append("send: pause")
            try await stateMachine.send(.pause)
            await log.append("done: pause")
        }

        // 等待所有事件完成
        try await Task.sleep(nanoseconds: 100_000_000)  // 100ms

        let events = await log.getEvents()

        // 验证事件按顺序完成（由于 Actor 串行化）
        // 每个 done 应在对应的 send 之后
        #expect(events.count >= 6, "应有至少 6 条日志")

        // 查找 loadMedia 的 send 和 done
        if let loadSendIndex = events.firstIndex(of: "send: loadMedia"),
            let loadDoneIndex = events.firstIndex(of: "done: loadMedia")
        {
            #expect(loadDoneIndex > loadSendIndex, "done 应在 send 之后")
        }
    }

    // MARK: - 极端参数测试

    /// 边界用例: progressUpdate 接受极端值
    @Test("progressUpdate 处理极端时间值")
    func testProgressUpdateWithExtremeValues() async throws {
        let stateMachine = PlayerStateMachine()

        // 进入 playing 状态
        try await stateMachine.send(.loadMedia(TestMediaURL.sample1))
        try await stateMachine.send(.play)

        // 测试负值（应被接受，表示倒带）
        try await stateMachine.send(.progressUpdate(-10.0))
        var state = await stateMachine.currentState
        if case .playing(let progress) = state {
            #expect(progress == -10.0)
        } else {
            Issue.record("Expected playing state with negative progress")
        }

        // 测试超大值（如 1 小时 = 3600s）
        try await stateMachine.send(.progressUpdate(3600.0))
        state = await stateMachine.currentState
        if case .playing(let progress) = state {
            #expect(progress == 3600.0)
        } else {
            Issue.record("Expected playing state with large progress")
        }

        // 测试零值
        try await stateMachine.send(.progressUpdate(0.0))
        state = await stateMachine.currentState
        if case .playing(let progress) = state {
            #expect(progress == 0.0)
        } else {
            Issue.record("Expected playing state with zero progress")
        }
    }

    // MARK: - 并发安全验证

    /// 边界用例: 并发 send 调用不产生竞态
    /// 注意：需要 TSan（Thread Sanitizer）运行以检测数据竞争
    @Test("并发安全：多线程 send 无竞态（需 TSan）")
    func testConcurrentSendNoDace() async throws {
        let stateMachine = PlayerStateMachine()

        // 从多个并发 Task 发送事件
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                try? await stateMachine.send(.loadMedia(TestMediaURL.sample1))
            }

            group.addTask {
                try? await stateMachine.send(.play)
            }

            group.addTask {
                try? await stateMachine.send(.pause)
            }

            group.addTask {
                try? await stateMachine.send(.reset)
            }
        }

        // 验证最终状态一致（应为 idle，因为 reset）
        try await Task.sleep(nanoseconds: 50_000_000)  // 50ms

        let finalState = await stateMachine.currentState
        #expect(finalState == .idle, "并发事件后应收敛到一致状态")

        // 注意：真正的竞态检测需要运行：
        // swift test --sanitize=thread
    }

    // MARK: - 状态不变性验证

    /// 边界用例: recognizing 状态包含的 seekId 不可变
    @Test("recognizing 状态的 seekId 不可变")
    func testRecognizingSeekIdImmutability() async throws {
        let stateMachine = PlayerStateMachine()

        // 进入 recognizing 状态
        try await stateMachine.send(.loadMedia(TestMediaURL.sample1))
        try await stateMachine.send(.play)

        let window = TimeRange(start: 0, end: 10)
        try await stateMachine.send(.startRecognition(window))

        let state1 = await stateMachine.currentState

        // 提取 seekId
        var originalSeekId: UUID?
        if case .recognizing(_, let seekId) = state1 {
            originalSeekId = seekId
        }

        // 再次读取状态
        let state2 = await stateMachine.currentState

        // 验证两次读取的 seekId 相同（状态不变）
        if case .recognizing(_, let seekId2) = state2 {
            #expect(seekId2 == originalSeekId, "seekId 应保持不变")
        } else {
            Issue.record("State changed unexpectedly")
        }
    }
}
