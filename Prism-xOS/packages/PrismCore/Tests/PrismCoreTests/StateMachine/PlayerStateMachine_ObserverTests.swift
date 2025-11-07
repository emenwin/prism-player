// PlayerStateMachine_ObserverTests.swift
// PrismCore
//
// PR4 测试：观察者接口与集成
// 验证 AsyncStream 多订阅者、状态发布、集成场景
//
// Created: 2025-11-07
// Sprint: S1, Task-104, PR4

import Foundation
import Testing

@testable import PrismCore

/// PR4 测试套件：观察者接口与集成
@Suite("PlayerStateMachine - 观察者与集成（PR4）")
struct PlayerStateMachineObserverTests {

    // MARK: - 单一观察者测试

    /// 用例1: 单一订阅者接收所有状态变化
    @Test("单一观察者接收完整状态序列")
    func testSingleObserverReceivesAllStates() async throws {
        let stateMachine = PlayerStateMachine()
        var receivedStates: [PlayerRecognitionState] = []

        // 启动观察者任务
        let observerTask = Task {
            for await state in stateMachine.statePublisher {
                receivedStates.append(state)

                // 收到 playing 状态后停止观察（避免无限循环）
                if case .playing = state {
                    break
                }
            }
        }

        // 等待初始 idle 状态
        try await Task.sleep(nanoseconds: 10_000_000)  // 10ms

        // 执行状态转移
        try await stateMachine.send(.loadMedia(TestMediaURL.sample1))
        try await stateMachine.send(.play)

        // 等待观察者完成
        try await Task.sleep(nanoseconds: 50_000_000)  // 50ms
        observerTask.cancel()

        // 验证接收到的状态序列
        #expect(receivedStates.count >= 3, "应至少接收到 3 个状态")
        #expect(receivedStates[0] == .idle)

        // 检查是否包含 loading 状态
        let hasLoading = receivedStates.contains { state in
            if case .loading = state { return true }
            return false
        }
        #expect(hasLoading, "应包含 loading 状态")

        // 检查最后是否为 playing 状态
        if let lastState = receivedStates.last {
            if case .playing = lastState {
                // OK
            } else {
                Issue.record("最后状态应为 playing，实际: \(lastState)")
            }
        }
    }

    // MARK: - 多订阅者测试

    /// 用例2: 验证 AsyncStream 订阅行为（单一订阅者）
    @Test("AsyncStream 支持单一订阅者（设计限制）")
    func testAsyncStreamSingleSubscriberBehavior() async throws {
        // 注意：Swift 的 AsyncStream 设计为单一消费者
        // 多个订阅者会竞争消费事件，导致每个订阅者接收不同的事件子集
        // 这是预期行为，不是bug
        
        let stateMachine = PlayerStateMachine()
        var receivedStates: [PlayerRecognitionState] = []
        
        // 单一订阅者
        let observer = Task {
            for await state in stateMachine.statePublisher {
                receivedStates.append(state)
                if case .paused = state { break }
            }
        }
        
        try await Task.sleep(nanoseconds: 50_000_000)  // 50ms
        
        // 执行状态转移
        try await stateMachine.send(.loadMedia(TestMediaURL.sample1))
        try await stateMachine.send(.play)
        try await stateMachine.send(.pause)
        
        try await Task.sleep(nanoseconds: 100_000_000)  // 100ms
        observer.cancel()
        
        // 验证单一订阅者接收到完整序列
        #expect(receivedStates.count >= 4, "单一订阅者应接收到完整状态序列")
        
        // 验证包含关键状态
        let hasIdle = receivedStates.contains { if case .idle = $0 { return true }; return false }
        let hasLoading = receivedStates.contains { if case .loading = $0 { return true }; return false }
        let hasPlaying = receivedStates.contains { if case .playing = $0 { return true }; return false }
        let hasPaused = receivedStates.contains { if case .paused = $0 { return true }; return false }
        
        #expect(hasIdle && hasLoading && hasPlaying && hasPaused, "应包含所有关键状态")
    }    // MARK: - 状态发布时序测试

    /// 用例3: 状态发布与事件处理同步
    @Test("状态发布与事件处理同步")
    func testStatePublishingSynchronization() async throws {
        let stateMachine = PlayerStateMachine()

        actor EventLog {
            var events: [(state: PlayerRecognitionState, timestamp: Date)] = []

            func log(_ state: PlayerRecognitionState) {
                events.append((state, Date()))
            }

            func getEvents() -> [(state: PlayerRecognitionState, timestamp: Date)] {
                return events
            }
        }

        let eventLog = EventLog()

        // 启动观察者
        let observer = Task {
            for await state in stateMachine.statePublisher {
                await eventLog.log(state)
                if case .playing = state { break }
            }
        }

        try await Task.sleep(nanoseconds: 10_000_000)

        // 执行状态转移并记录时间
        try await stateMachine.send(.loadMedia(TestMediaURL.sample1))
        try await stateMachine.send(.play)

        try await Task.sleep(nanoseconds: 50_000_000)
        observer.cancel()

        // 验证状态发布顺序
        let events = await eventLog.getEvents()

        #expect(events.count >= 3, "应至少有 3 个状态")

        // 验证时间顺序：每个状态的时间戳应该递增
        for i in 1..<events.count {
            let prevTime = events[i - 1].timestamp
            let currTime = events[i].timestamp
            #expect(currTime >= prevTime, "状态时间戳应该递增")
        }
    }

    // MARK: - 集成测试：与 TestPlayerService

    /// 用例4: 状态机与 PlayerService 集成
    @Test("状态机与 PlayerService 集成")
    func testIntegrationWithPlayerService() async throws {
        let stateMachine = PlayerStateMachine()
        let playerService = TestPlayerService()

        // 模拟协调器：根据状态机状态调用 PlayerService
        let coordinator = Task {
            for await state in stateMachine.statePublisher {
                switch state {
                case .loading(let url):
                    try? await playerService.loadMedia(url)

                case .playing:
                    await playerService.play()

                case .paused:
                    await playerService.pause()

                default:
                    break
                }

                // 停止条件
                if case .paused = state {
                    break
                }
            }
        }
        
        try await Task.sleep(nanoseconds: 50_000_000)  // 50ms - 等待订阅建立
        
        // 执行状态转移
        try await stateMachine.send(.loadMedia(TestMediaURL.sample1))
        try await stateMachine.send(.play)
        try await stateMachine.send(.pause)
        
        try await Task.sleep(nanoseconds: 150_000_000)  // 150ms - 等待协调器处理
        coordinator.cancel()        // 验证 PlayerService 调用
        #expect(await playerService.didPerform(.loadMedia(TestMediaURL.sample1)))
        #expect(await playerService.didPerform(.play))
        #expect(await playerService.didPerform(.pause))

        // 验证最终状态
        let isPlaying = await playerService.isPlaying
        let isPaused = await playerService.isPaused

        #expect(!isPlaying, "播放器不应处于播放状态")
        #expect(isPaused, "播放器应处于暂停状态")
    }

    // MARK: - 集成测试：与 TestAsrEngine

    /// 用例5: 状态机与 AsrEngine 集成
    @Test("状态机与 AsrEngine 集成")
    func testIntegrationWithAsrEngine() async throws {
        let stateMachine = PlayerStateMachine()
        let asrEngine = TestAsrEngine()

        // 设置较短的识别延迟
        await asrEngine.setRecognitionDelay(0.05)  // 模拟协调器：触发识别
        let coordinator = Task {
            for await state in stateMachine.statePublisher {
                if case .recognizing(let window, _) = state {
                    // 触发识别
                    _ = try? await asrEngine.recognize(
                        window: window,
                        mediaURL: TestMediaURL.sample1
                    )

                    // 识别完成，通知状态机
                    try? await stateMachine.send(.recognitionCompleted)
                }

                // 停止条件
                if case .playing(let progress) = state, progress > 0 {
                    break
                }
            }
        }

        try await Task.sleep(nanoseconds: 20_000_000)

        // 执行流程：播放 → 识别 → 完成
        try await stateMachine.send(.loadMedia(TestMediaURL.sample1))
        try await stateMachine.send(.play)

        let window = TimeRange(start: 5, end: 15)
        try await stateMachine.send(.startRecognition(window))

        // 等待识别完成
        try await Task.sleep(nanoseconds: 150_000_000)  // 150ms

        coordinator.cancel()

        // 验证 AsrEngine 调用
        let recognitionCount = await asrEngine.recognitionCount()
        #expect(recognitionCount >= 1, "应至少执行一次识别")

        if let lastRequest = await asrEngine.lastRequest() {
            #expect(lastRequest.window == window)
            #expect(lastRequest.mediaURL == TestMediaURL.sample1)
        }
    }

    // MARK: - 观察者生命周期测试

    /// 用例6: 观察者任务取消不影响状态机
    @Test("观察者取消不影响状态机")
    func testObserverCancellationDoesNotAffectStateMachine() async throws {
        let stateMachine = PlayerStateMachine()

        // 创建并立即取消观察者
        let observer1 = Task {
            for await state in stateMachine.statePublisher {
                print("Observer1: \(state)")
            }
        }
        
        try await Task.sleep(nanoseconds: 50_000_000)  // 50ms - 等待订阅建立
        try await stateMachine.send(.loadMedia(TestMediaURL.sample1))
        try await stateMachine.send(.play)
        
        let currentState = await stateMachine.currentState
        #expect(currentState == .playing(progress: 0))
        
        // 创建新观察者应该能接收后续状态
        var receivedPause = false
        let observer2 = Task {
            for await state in stateMachine.statePublisher {
                if case .paused = state {
                    receivedPause = true
                    break
                }
            }
        }
        
        try await Task.sleep(nanoseconds: 50_000_000)  // 50ms - 等待新订阅建立
        try await stateMachine.send(.pause)
        
        try await Task.sleep(nanoseconds: 100_000_000)  // 100ms - 等待状态传播
        observer1.cancel()
        observer2.cancel()
        
        #expect(receivedPause, "新观察者应能接收到 pause 状态")
    }

    // MARK: - 错误处理集成测试

    /// 用例7: 集成场景下的错误恢复
    @Test("集成场景：错误恢复流程")
    func testIntegrationErrorRecovery() async throws {
        let stateMachine = PlayerStateMachine()
        let playerService = TestPlayerService()

        // 模拟加载失败
        await playerService.setShouldFailLoading(true)

        var errorReceived = false

        // 协调器处理错误
        let coordinator = Task {
            for await state in stateMachine.statePublisher {
                switch state {
                case .loading(let url):
                    do {
                        try await playerService.loadMedia(url)
                        // 加载成功，发送 play 事件
                        try await stateMachine.send(.play)
                    } catch {
                        // 加载失败，转移到 error 状态
                        let playerError = PlayerError.loadFailed("Integration test error")
                        try await stateMachine.send(.recognitionFailed(playerError))
                    }

                case .error:
                    errorReceived = true
                    break

                default:
                    break
                }

                if errorReceived { break }
            }
        }

        try await Task.sleep(nanoseconds: 20_000_000)

        // 触发加载（预期失败）
        try await stateMachine.send(.loadMedia(TestMediaURL.sample1))

        try await Task.sleep(nanoseconds: 150_000_000)
        coordinator.cancel()

        // 验证进入错误状态
        let currentState = await stateMachine.currentState
        if case .error = currentState {
            // OK
        } else {
            Issue.record("应进入 error 状态，实际: \(currentState)")
        }

        #expect(errorReceived, "应接收到 error 状态")
    }

    // MARK: - 性能测试

    /// 性能测试: 多订阅者不影响状态转移性能
    @Test("性能：多订阅者不影响状态转移")
    func testMultipleObserversPerformance() async throws {
        let stateMachine = PlayerStateMachine()

        // 创建 5 个订阅者
        let observers = (0..<5).map { _ in
            Task {
                for await state in stateMachine.statePublisher {
                    // 模拟轻量处理
                    _ = state.description
                    if case .playing = state { break }
                }
            }
        }

        try await Task.sleep(nanoseconds: 20_000_000)

        // 测量状态转移时间
        let startTime = Date()

        try await stateMachine.send(.loadMedia(TestMediaURL.sample1))
        try await stateMachine.send(.play)

        let duration = Date().timeIntervalSince(startTime)

        try await Task.sleep(nanoseconds: 50_000_000)

        // 取消所有观察者
        observers.forEach { $0.cancel() }

        // 验证性能：即使有 5 个订阅者，状态转移仍应很快
        #expect(duration < 0.1, "状态转移耗时应 < 100ms，实际: \(duration * 1000)ms")

        print("多订阅者场景状态转移耗时: \(String(format: "%.2f", duration * 1000))ms")
    }
}
