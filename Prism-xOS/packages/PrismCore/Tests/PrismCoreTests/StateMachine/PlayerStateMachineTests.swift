// PlayerStateMachineTests.swift
// PrismCoreTests
//
// 播放器状态机单元测试
// 测试所有状态转移路径，确保状态机行为正确
//
// Created: 2025-11-07
// Sprint: S1, Task-104, PR2

import Foundation
import Testing

@testable import PrismCore

/// 播放器状态机测试套件
@Suite("PlayerStateMachine Tests")
struct PlayerStateMachineTests {

    // MARK: - 辅助方法

    /// 创建测试用状态机
    private func makeStateMachine() -> PlayerStateMachine {
        return PlayerStateMachine()
    }

    /// 等待状态变化
    /// - Parameters:
    ///   - stateMachine: 状态机
    ///   - expectedState: 期望的状态（用于断言）
    ///   - timeout: 超时时间（秒）
    private func waitForState(
        _ stateMachine: PlayerStateMachine,
        _ expectedState: PlayerRecognitionState,
        timeout: TimeInterval = 1.0
    ) async throws {
        let start = Date()
        while await stateMachine.currentState != expectedState {
            if Date().timeIntervalSince(start) > timeout {
                throw TestError.timeout("Timeout waiting for state: \(expectedState)")
            }
            try await Task.sleep(nanoseconds: 10_000_000)  // 10ms
        }
    }

    // MARK: - 初始化测试

    @Test("状态机初始化为 idle 状态")
    func testInitialState() async {
        let stateMachine = makeStateMachine()
        let state = await stateMachine.currentState

        #expect(state == .idle)
    }

    // MARK: - 正常路径测试（8个用例）

    @Test("用例1: idle → loading → playing（媒体加载并播放）")
    func testNormalFlow_IdleToLoadingToPlaying() async throws {
        let stateMachine = makeStateMachine()
        let testURL = TestMediaURL.validVideo

        // idle → loading
        try await stateMachine.send(.loadMedia(testURL))
        var state = await stateMachine.currentState
        #expect(state == .loading(mediaURL: testURL))

        // loading → playing
        try await stateMachine.send(.play)
        state = await stateMachine.currentState
        if case .playing(let progress) = state {
            #expect(progress == 0)
        } else {
            throw TestError.unexpectedState("Expected playing state, got \(state)")
        }
    }

    @Test("用例2: playing → paused → playing（暂停与恢复）")
    func testNormalFlow_PlayingToPausedToPlaying() async throws {
        let stateMachine = makeStateMachine()

        // 先进入 playing 状态
        try await stateMachine.send(.loadMedia(TestMediaURL.validVideo))
        try await stateMachine.send(.play)
        try await stateMachine.send(.progressUpdate(10.5))

        // playing → paused
        try await stateMachine.send(.pause)
        var state = await stateMachine.currentState
        if case .paused(let at) = state {
            #expect(at == 10.5)
        } else {
            throw TestError.unexpectedState("Expected paused state, got \(state)")
        }

        // paused → playing
        try await stateMachine.send(.play)
        state = await stateMachine.currentState
        if case .playing(let progress) = state {
            #expect(progress == 10.5)  // 从暂停位置恢复
        } else {
            throw TestError.unexpectedState("Expected playing state, got \(state)")
        }
    }

    @Test("用例3: playing → recognizing → playing（识别完成）")
    func testNormalFlow_PlayingToRecognizingToPlaying() async throws {
        let stateMachine = makeStateMachine()

        // 先进入 playing 状态
        try await stateMachine.send(.loadMedia(TestMediaURL.validVideo))
        try await stateMachine.send(.play)
        try await stateMachine.send(.progressUpdate(20.0))

        // playing → recognizing
        let window = TimeRange(start: 20.0, end: 35.0)
        try await stateMachine.send(.startRecognition(window))
        var state = await stateMachine.currentState
        if case .recognizing(let w, let seekId) = state {
            #expect(w == window)
            #expect(seekId == nil)
        } else {
            throw TestError.unexpectedState("Expected recognizing state, got \(state)")
        }

        // recognizing → playing
        try await stateMachine.send(.recognitionCompleted)
        state = await stateMachine.currentState
        if case .playing(let progress) = state {
            #expect(progress == 35.0)  // 应该在窗口结束位置
        } else {
            throw TestError.unexpectedState("Expected playing state, got \(state)")
        }
    }

    @Test("用例4: playing → seek → playing（seek 后恢复）")
    func testNormalFlow_PlayingToSeekToPlaying() async throws {
        let stateMachine = makeStateMachine()

        // 先进入 playing 状态
        try await stateMachine.send(.loadMedia(TestMediaURL.validVideo))
        try await stateMachine.send(.play)
        try await stateMachine.send(.progressUpdate(10.0))

        // seek 到新位置
        let seekId = UUID()
        try await stateMachine.send(.seek(to: 60.0, seekId: seekId))
        let state = await stateMachine.currentState

        if case .playing(let progress) = state {
            #expect(progress == 60.0)
        } else {
            throw TestError.unexpectedState("Expected playing state, got \(state)")
        }
    }

    @Test("用例5: idle → loading → error（加载失败）")
    func testNormalFlow_IdleToLoadingToError() async throws {
        let stateMachine = makeStateMachine()

        // idle → loading
        try await stateMachine.send(.loadMedia(TestMediaURL.validVideo))

        // 模拟加载失败
        let error = PlayerError.loadFailed("File not found")
        try await stateMachine.send(.recognitionFailed(error))

        let state = await stateMachine.currentState
        if case .error(_, let recoverable) = state {
            #expect(recoverable == true)  // loadFailed 是可恢复的
        } else {
            throw TestError.unexpectedState("Expected error state, got \(state)")
        }
    }

    @Test("用例6: recognizing → cancel → playing（识别被取消）")
    func testNormalFlow_RecognizingToCancelToPlaying() async throws {
        let stateMachine = makeStateMachine()

        // 先进入 recognizing 状态
        try await stateMachine.send(.loadMedia(TestMediaURL.validVideo))
        try await stateMachine.send(.play)
        try await stateMachine.send(.progressUpdate(30.0))
        let window = TimeRange(start: 30.0, end: 45.0)
        try await stateMachine.send(.startRecognition(window))

        // 取消识别
        try await stateMachine.send(.cancel(seekId: nil))
        let state = await stateMachine.currentState

        if case .playing(let progress) = state {
            #expect(progress == 30.0)  // 应该返回到窗口开始位置
        } else {
            throw TestError.unexpectedState("Expected playing state, got \(state)")
        }
    }

    @Test("用例7: paused → seek → paused（暂停态 seek）")
    func testNormalFlow_PausedToSeekToPaused() async throws {
        let stateMachine = makeStateMachine()

        // 先进入 paused 状态
        try await stateMachine.send(.loadMedia(TestMediaURL.validVideo))
        try await stateMachine.send(.play)
        try await stateMachine.send(.progressUpdate(15.0))
        try await stateMachine.send(.pause)

        // 在暂停状态下 seek
        let seekId = UUID()
        try await stateMachine.send(.seek(to: 45.0, seekId: seekId))
        let state = await stateMachine.currentState

        if case .paused(let at) = state {
            #expect(at == 45.0)
        } else {
            throw TestError.unexpectedState("Expected paused state, got \(state)")
        }
    }

    @Test("用例8: error → retry → idle（错误恢复）")
    func testNormalFlow_ErrorToRetryToIdle() async throws {
        let stateMachine = makeStateMachine()

        // 先进入 error 状态（可恢复）
        try await stateMachine.send(.loadMedia(TestMediaURL.validVideo))
        let error = PlayerError.loadFailed("Network error")
        try await stateMachine.send(.recognitionFailed(error))

        // 重试恢复
        try await stateMachine.send(.retry)
        let state = await stateMachine.currentState

        #expect(state == .idle)
    }

    // MARK: - 边界测试

    @Test("边界测试: progressUpdate 更新播放进度")
    func testEdgeCase_ProgressUpdate() async throws {
        let stateMachine = makeStateMachine()

        // 进入 playing 状态
        try await stateMachine.send(.loadMedia(TestMediaURL.validVideo))
        try await stateMachine.send(.play)

        // 连续更新进度
        for progress in [1.0, 2.5, 5.0, 10.0, 15.5] {
            try await stateMachine.send(.progressUpdate(progress))
            let state = await stateMachine.currentState

            if case .playing(let currentProgress) = state {
                #expect(currentProgress == progress)
            } else {
                throw TestError.unexpectedState("Expected playing state with progress \(progress)")
            }
        }
    }

    @Test("边界测试: reset 事件从任意状态返回 idle")
    func testEdgeCase_ResetFromAnyState() async throws {
        let stateMachine = makeStateMachine()

        // 从 playing 状态 reset
        try await stateMachine.send(.loadMedia(TestMediaURL.validVideo))
        try await stateMachine.send(.play)
        try await stateMachine.send(.reset)
        #expect(await stateMachine.currentState == .idle)

        // 从 paused 状态 reset
        try await stateMachine.send(.loadMedia(TestMediaURL.validVideo))
        try await stateMachine.send(.play)
        try await stateMachine.send(.pause)
        try await stateMachine.send(.reset)
        #expect(await stateMachine.currentState == .idle)
    }

    // MARK: - 非法转移测试

    @Test("非法转移: idle 状态发送 pause 事件")
    func testIllegalTransition_IdleToPause() async {
        let stateMachine = makeStateMachine()

        // 尝试在 idle 状态暂停
        do {
            try await stateMachine.send(.pause)
            Issue.record("Should throw StateMachineError")
        } catch let error as StateMachineError {
            if case .illegalTransition = error {
                // 预期的错误
            } else {
                Issue.record("Unexpected error type: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("非法转移: loading 状态直接发送 pause 事件")
    func testIllegalTransition_LoadingToPause() async {
        let stateMachine = makeStateMachine()

        try? await stateMachine.send(.loadMedia(TestMediaURL.validVideo))

        // 尝试在 loading 状态暂停
        do {
            try await stateMachine.send(.pause)
            Issue.record("Should throw StateMachineError")
        } catch let error as StateMachineError {
            if case .illegalTransition = error {
                // 预期的错误
            } else {
                Issue.record("Unexpected error type: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    // MARK: - 性能测试

    @Test("性能测试: 状态转移耗时 < 50ms")
    func testPerformance_StateTransitionLatency() async throws {
        let stateMachine = makeStateMachine()

        // 预热
        try await stateMachine.send(.loadMedia(TestMediaURL.validVideo))
        try await stateMachine.send(.play)

        // 测试多次 progressUpdate 的平均耗时
        let iterations = 100
        let start = Date()

        for i in 0..<iterations {
            try await stateMachine.send(.progressUpdate(Double(i)))
        }

        let duration = Date().timeIntervalSince(start)
        let avgLatency = (duration / Double(iterations)) * 1000  // 转换为毫秒

        // 平均耗时应 < 50ms
        #expect(avgLatency < 50.0, "Average latency: \(avgLatency)ms")
    }

    // MARK: - 辅助工具测试

    @Test("测试转移历史记录")
    func testTransitionHistory() async throws {
        let stateMachine = makeStateMachine()

        // 执行一些转移
        try await stateMachine.send(.loadMedia(TestMediaURL.validVideo))
        try await stateMachine.send(.play)
        try await stateMachine.send(.pause)

        // 获取历史
        let history = await stateMachine.getTransitionHistory()

        #expect(history.count >= 3)

        // 验证最后几次转移
        let lastTransition = history.last!
        #expect(lastTransition.from == "playing(0.0s)")
        #expect(lastTransition.to.contains("paused"))
    }

    @Test("测试当前状态停留时长")
    func testTimeInCurrentState() async throws {
        let stateMachine = makeStateMachine()

        // 进入 playing 状态
        try await stateMachine.send(.loadMedia(TestMediaURL.validVideo))
        try await stateMachine.send(.play)

        // 等待一小段时间
        try await Task.sleep(nanoseconds: 100_000_000)  // 100ms

        // 检查停留时长
        let timeInState = await stateMachine.getTimeInCurrentState()
        #expect(timeInState >= 0.1, "Time in state should be at least 100ms")
        #expect(timeInState < 0.5, "Time in state should be less than 500ms")
    }
}

// MARK: - 测试错误类型

enum TestError: Error {
    case timeout(String)
    case unexpectedState(String)
}
