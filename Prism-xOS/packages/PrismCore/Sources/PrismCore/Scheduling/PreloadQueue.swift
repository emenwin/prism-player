import Foundation
import OSLog

/// 预加载队列优先级
///
/// 职责：
/// - 定义音频抽取任务的优先级等级
/// - 用于调度器决定任务执行顺序
///
/// 优先级排序（从高到低）：
/// 1. **fastFirstFrame**：首帧快速窗口（极速首帧，用户体验关键）
/// 2. **seek**：拖动抢占（Task-104，立即响应用户操作）
/// 3. **scroll**：滚动识别（Task-104，当前播放位置）
/// 4. **preload**：预加载（低优先级，后台任务）
///
/// 参考：
/// - HLD v0.2 §2.2 并发与调度
/// - Task-102 §3.1.1 AudioExtractor 协议定义
public enum PreloadPriority: Int, Sendable, Comparable {
    /// 预加载（低优先级）
    case preload = 0

    /// 滚动识别（中优先级）
    case scroll = 1

    /// 拖动抢占（高优先级）
    case seek = 2

    /// 首帧快速窗口（最高优先级）
    case fastFirstFrame = 3

    public static func < (lhs: PreloadPriority, rhs: PreloadPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// 预加载队列
///
/// 职责：
/// - 管理音频抽取任务的优先级队列
/// - 支持任务入队、取消、优先级调度
/// - 限制并发数量（避免 CPU 过载）
///
/// 核心算法：
/// 1. **优先级队列**：使用 SortedArray<Task> 按优先级排序
/// 2. **并发控制**：最多 3 个并发任务（可配置）
/// 3. **任务取消**：支持按 ID 或全部取消
/// 4. **等待完成**：支持等待所有任务完成
///
/// 使用示例：
/// ```swift
/// let queue = PreloadQueue(maxConcurrentTasks: 3)
///
/// // 入队首帧任务（最高优先级）
/// let taskId = await queue.enqueue(priority: .fastFirstFrame) {
///     try await extractor.extract(from: asset, timeRange: firstFrameRange)
/// }
///
/// // 入队预加载任务（低优先级）
/// await queue.enqueue(priority: .preload) {
///     try await extractor.extract(from: asset, timeRange: preloadRange)
/// }
///
/// // 等待所有任务完成
/// await queue.waitForAll()
/// ```
///
/// 参考：
/// - Task-102 §3.2 差异 1: 首帧快速窗口优化策略
/// - Task-102 §4 实施计划 PR2
public actor PreloadQueue {
    private let logger = Logger(subsystem: "com.prismplayer.core", category: "audio.preload")

    /// 任务项
    private struct TaskItem {
        let id: UUID
        let priority: PreloadPriority
        let task: Task<Void, Never>
        let createdAt: Date
    }

    /// 任务队列（按优先级排序）
    private var tasks: [TaskItem] = []

    /// 最大并发任务数
    private let maxConcurrentTasks: Int

    /// 当前运行中的任务数
    private var runningCount: Int = 0

    /// 初始化预加载队列
    /// - Parameter maxConcurrentTasks: 最大并发任务数，默认 3
    public init(maxConcurrentTasks: Int = 3) {
        self.maxConcurrentTasks = maxConcurrentTasks
    }

    /// 入队任务
    ///
    /// - Parameters:
    ///   - priority: 任务优先级
    ///   - operation: 任务操作（async throws）
    /// - Returns: 任务 ID（用于取消）
    @discardableResult
    public func enqueue<T>(
        priority: PreloadPriority,
        operation: @escaping @Sendable () async throws -> T
    ) -> UUID {
        let taskId = UUID()

        // 创建任务（包装为 Task<Void, Never>）
        let task = Task {
            // 等待调度
            await waitForSlot()

            // 执行任务
            do {
                logger.debug(
                    "开始执行任务: id=\(taskId.uuidString, privacy: .public), priority=\(priority.rawValue, privacy: .public)"
                )
                _ = try await operation()
                logger.debug("任务完成: id=\(taskId.uuidString, privacy: .public)")
            } catch is CancellationError {
                logger.notice("任务已取消: id=\(taskId.uuidString, privacy: .public)")
            } catch {
                logger.error(
                    "任务失败: id=\(taskId.uuidString, privacy: .public), error=\(error.localizedDescription, privacy: .public)"
                )
            }

            // 标记完成
            markCompleted(taskId: taskId)
        }

        // 加入队列（按优先级排序）
        let item = TaskItem(id: taskId, priority: priority, task: task, createdAt: Date())
        tasks.append(item)
        tasks.sort { $0.priority > $1.priority }  // 高优先级在前

        logger.info(
            "任务入队: id=\(taskId.uuidString, privacy: .public), priority=\(priority.rawValue, privacy: .public), 队列深度=\(self.tasks.count, privacy: .public)"
        )

        return taskId
    }

    /// 取消指定任务
    /// - Parameter taskId: 任务 ID
    public func cancel(taskId: UUID) {
        if let index = tasks.firstIndex(where: { $0.id == taskId }) {
            let item = tasks.remove(at: index)
            item.task.cancel()
            logger.notice("任务已取消: id=\(taskId.uuidString, privacy: .public)")
        }
    }

    /// 取消所有任务
    public func cancelAll() {
        logger.notice("取消所有任务: 总数=\(self.tasks.count, privacy: .public)")
        tasks.forEach { $0.task.cancel() }
        tasks.removeAll()
        runningCount = 0
    }

    /// 等待所有任务完成
    public func waitForAll() async {
        logger.debug("等待所有任务完成: 当前队列深度=\(self.tasks.count, privacy: .public)")

        // 等待所有任务
        for item in tasks {
            await item.task.value
        }

        logger.debug("所有任务已完成")
    }

    /// 获取队列深度
    public var depth: Int {
        tasks.count
    }

    /// 获取运行中任务数
    public var runningTaskCount: Int {
        runningCount
    }

    // MARK: - Private Methods

    /// 等待可用槽位
    private func waitForSlot() async {
        while runningCount >= maxConcurrentTasks {
            // 等待 100ms 后重试
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        runningCount += 1
    }

    /// 标记任务完成
    private func markCompleted(taskId: UUID) {
        runningCount -= 1
        if let index = tasks.firstIndex(where: { $0.id == taskId }) {
            tasks.remove(at: index)
        }
    }
}
