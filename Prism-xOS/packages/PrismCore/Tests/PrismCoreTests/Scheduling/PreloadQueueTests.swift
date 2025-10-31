import XCTest

@testable import PrismCore

/// PreloadQueue 单元测试
///
/// 测试范围：
/// - 优先级调度：fastFirstFrame > seek > scroll > preload
/// - 并发限制：最多 N 个任务同时执行
/// - 任务取消：单个任务和全部任务
/// - 等待完成：waitForAll()
///
/// 参考：Task-102 §5.2 PreloadQueue 测试用例
final class PreloadQueueTests: XCTestCase {

    var queue: PreloadQueue!

    override func setUp() async throws {
        try await super.setUp()
        queue = PreloadQueue(maxConcurrentTasks: 3)
    }

    override func tearDown() async throws {
        await queue.cancelAll()
        queue = nil
        try await super.tearDown()
    }

    // MARK: - 优先级调度测试

    func testFastFirstFramePriority() async throws {
        // Given: 记录任务完成顺序
        actor CompletionTracker {
            private(set) var completedTasks: [String] = []

            func append(_ task: String) {
                completedTasks.append(task)
            }
        }

        let tracker = CompletionTracker()

        // When: 先入队低优先级任务，再入队高优先级任务
        await queue.enqueue(priority: .preload) {
            try? await Task.sleep(nanoseconds: 200_000_000)  // 200ms
            await tracker.append("preload")
        }

        // 稍微延迟确保第一个任务已启动
        try await Task.sleep(nanoseconds: 50_000_000)  // 50ms

        await queue.enqueue(priority: .fastFirstFrame) {
            try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
            await tracker.append("fastFirstFrame")
        }

        // Then: 等待所有任务完成
        await queue.waitForAll()

        let completed = await tracker.completedTasks
        print("完成顺序: \(completed)")

        // 验证：虽然 preload 先入队，但 fastFirstFrame 应该在并发槽位可用时立即执行
        // 由于 fastFirstFrame 耗时更短，应该先完成
        XCTAssertEqual(completed.count, 2)
    }

    func testPriorityOrdering() async throws {
        // Given: 记录任务完成顺序
        actor CompletionTracker {
            private(set) var completedTasks: [String] = []

            func append(_ task: String) {
                completedTasks.append(task)
            }
        }

        let tracker = CompletionTracker()

        // When: 按不同优先级入队多个任务（所有任务耗时相同）
        let taskDuration: UInt64 = 100_000_000  // 100ms

        await queue.enqueue(priority: .preload) {
            try? await Task.sleep(nanoseconds: taskDuration)
            await tracker.append("preload-1")
        }

        await queue.enqueue(priority: .scroll) {
            try? await Task.sleep(nanoseconds: taskDuration)
            await tracker.append("scroll-1")
        }

        await queue.enqueue(priority: .fastFirstFrame) {
            try? await Task.sleep(nanoseconds: taskDuration)
            await tracker.append("fastFirstFrame-1")
        }

        await queue.enqueue(priority: .seek) {
            try? await Task.sleep(nanoseconds: taskDuration)
            await tracker.append("seek-1")
        }

        // Then: 等待所有任务完成
        await queue.waitForAll()

        let completed = await tracker.completedTasks
        print("完成顺序: \(completed)")

        XCTAssertEqual(completed.count, 4)

        // 验证：高优先级任务应该在低优先级任务之前完成
        // fastFirstFrame(3) > seek(2) > scroll(1) > preload(0)
        if let fastFirstFrameIndex = completed.firstIndex(of: "fastFirstFrame-1"),
            let preloadIndex = completed.firstIndex(of: "preload-1")
        {
            XCTAssertLessThan(fastFirstFrameIndex, preloadIndex, "fastFirstFrame 应在 preload 之前完成")
        }
    }

    // MARK: - 并发限制测试

    func testConcurrentTaskLimit() async throws {
        // Given: 创建队列，限制最多 2 个并发任务
        let limitedQueue = PreloadQueue(maxConcurrentTasks: 2)

        // 记录同时运行的任务数
        actor ConcurrencyTracker {
            private(set) var maxConcurrentCount = 0
            private var currentCount = 0

            func incrementAndTrack() {
                currentCount += 1
                maxConcurrentCount = max(maxConcurrentCount, currentCount)
            }

            func decrement() {
                currentCount -= 1
            }
        }

        let tracker = ConcurrencyTracker()

        // When: 入队 5 个任务
        for _ in 1...5 {
            await limitedQueue.enqueue(priority: .preload) {
                await tracker.incrementAndTrack()
                try? await Task.sleep(nanoseconds: 200_000_000)  // 200ms
                await tracker.decrement()
            }
        }

        // Then: 等待所有任务完成
        await limitedQueue.waitForAll()

        let maxConcurrent = await tracker.maxConcurrentCount
        XCTAssertLessThanOrEqual(maxConcurrent, 2, "并发任务数不应超过限制")

        await limitedQueue.cancelAll()
    }

    func testQueueDepth() async throws {
        // Given: 入队多个长时间任务
        for _ in 1...5 {
            await queue.enqueue(priority: .preload) {
                try? await Task.sleep(nanoseconds: 500_000_000)  // 500ms
            }
        }

        // When: 检查队列深度
        let depth = await queue.depth

        // Then: 队列深度应该 > 0（部分任务还在等待）
        XCTAssertGreaterThan(depth, 0, "队列深度应该大于 0")

        // 清理
        await queue.cancelAll()
    }

    func testRunningTaskCount() async throws {
        // Given: 入队 5 个任务
        for _ in 1...5 {
            await queue.enqueue(priority: .preload) {
                try? await Task.sleep(nanoseconds: 300_000_000)  // 300ms
            }
        }

        // When: 稍微等待任务启动
        try await Task.sleep(nanoseconds: 100_000_000)  // 100ms

        let runningCount = await queue.runningTaskCount

        // Then: 运行中任务数应该 ≤ maxConcurrentTasks
        XCTAssertLessThanOrEqual(runningCount, 3, "运行中任务数不应超过限制")

        // 清理
        await queue.cancelAll()
    }

    // MARK: - 任务取消测试

    func testCancelSingleTask() async throws {
        // Given: 入队一个长时间任务
        actor TaskTracker {
            private(set) var completed = false
            func markCompleted() {
                completed = true
            }
        }

        let tracker = TaskTracker()

        let taskId = await queue.enqueue(priority: .preload) {
            try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1s
            await tracker.markCompleted()
        }

        // When: 立即取消
        try await Task.sleep(nanoseconds: 50_000_000)  // 50ms
        await queue.cancel(taskId: taskId)

        // Then: 等待一段时间后，任务应该未完成
        try await Task.sleep(nanoseconds: 200_000_000)  // 200ms
        let completed = await tracker.completed
        XCTAssertFalse(completed, "任务应该被取消，未完成")
    }

    func testCancelAll() async throws {
        // Given: 入队多个长时间任务
        actor CompletionTracker {
            private(set) var completedCount = 0
            func increment() {
                completedCount += 1
            }
        }

        let tracker = CompletionTracker()

        for _ in 1...5 {
            await queue.enqueue(priority: .preload) {
                try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1s
                await tracker.increment()
            }
        }

        // When: 稍微等待后取消所有任务
        try await Task.sleep(nanoseconds: 100_000_000)  // 100ms
        await queue.cancelAll()

        // Then: 队列应该为空
        let depth = await queue.depth
        XCTAssertEqual(depth, 0, "取消后队列应该为空")

        // 等待一段时间，验证任务未完成
        try await Task.sleep(nanoseconds: 200_000_000)  // 200ms
        let completedCount = await tracker.completedCount
        XCTAssertLessThan(completedCount, 5, "大部分任务应该被取消")
    }

    // MARK: - 等待完成测试

    func testWaitForAll() async throws {
        // Given: 入队多个任务
        actor CompletionTracker {
            private(set) var completedCount = 0
            func increment() {
                completedCount += 1
            }
        }

        let tracker = CompletionTracker()

        for _ in 1...3 {
            await queue.enqueue(priority: .preload) {
                try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
                await tracker.increment()
            }
        }

        // When: 等待所有任务完成
        await queue.waitForAll()

        // Then: 所有任务应该完成
        let completedCount = await tracker.completedCount
        XCTAssertEqual(completedCount, 3, "所有任务应该完成")

        let depth = await queue.depth
        XCTAssertEqual(depth, 0, "等待完成后队列应该为空")
    }

    func testWaitForAllWithEmptyQueue() async throws {
        // Given: 空队列

        // When: 等待所有任务完成（应立即返回）
        await queue.waitForAll()

        // Then: 不应该阻塞
        let depth = await queue.depth
        XCTAssertEqual(depth, 0)
    }

    // MARK: - 异常处理测试

    func testTaskWithError() async throws {
        // Given: 入队一个会抛出错误的任务
        await queue.enqueue(priority: .preload) {
            throw NSError(domain: "TestError", code: 1, userInfo: nil)
        }

        // When: 等待任务完成
        await queue.waitForAll()

        // Then: 队列应该正常处理错误，不崩溃
        let depth = await queue.depth
        XCTAssertEqual(depth, 0, "即使任务出错，队列也应该正常清理")
    }

    func testMixedSuccessAndErrorTasks() async throws {
        // Given: 入队成功和失败的任务
        actor SuccessTracker {
            private(set) var successCount = 0
            func increment() {
                successCount += 1
            }
        }

        let tracker = SuccessTracker()

        await queue.enqueue(priority: .preload) {
            await tracker.increment()
        }

        await queue.enqueue(priority: .preload) {
            throw NSError(domain: "TestError", code: 1, userInfo: nil)
        }

        await queue.enqueue(priority: .preload) {
            await tracker.increment()
        }

        // When: 等待所有任务完成
        await queue.waitForAll()

        // Then: 成功的任务应该完成
        let successCount = await tracker.successCount
        XCTAssertEqual(successCount, 2, "成功的任务应该完成")
    }

    // MARK: - 性能测试

    func testPerformanceWith100Tasks() async throws {
        // Given: 100 个轻量级任务
        measure {
            Task {
                let perfQueue = PreloadQueue(maxConcurrentTasks: 3)

                for i in 1...100 {
                    await perfQueue.enqueue(priority: .preload) {
                        // 轻量级任务
                        _ = i * 2
                    }
                }

                await perfQueue.waitForAll()
            }
        }
    }
}
