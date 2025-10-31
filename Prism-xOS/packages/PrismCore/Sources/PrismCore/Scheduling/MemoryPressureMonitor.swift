import AVFoundation
import Foundation
import OSLog

#if canImport(UIKit)
    import UIKit
#endif

/// 内存压力监控器
///
/// 职责：
/// - 监听系统内存警告通知
/// - 将系统通知转换为三级内存压力等级
/// - 通知订阅者（如 AudioCache）
///
/// 核心算法：
/// 1. **监听系统通知**：
///    - iOS: UIApplication.didReceiveMemoryWarningNotification
///    - macOS: NSApplication.didReceiveMemoryWarningNotification
/// 2. **分级策略**：
///    - 首次警告 → warning
///    - 连续 3 次警告（30s 内）→ urgent
///    - 连续 5 次警告（60s 内）→ critical
/// 3. **避免抖动**：
///    - 记录最近 N 次警告时间
///    - 使用滑动窗口判断压力等级
///
/// 使用示例：
/// ```swift
/// let monitor = MemoryPressureMonitor()
///
/// // 订阅内存压力事件
/// for await (level, time) in monitor.pressureStream {
///     print("Memory pressure: \\(level)")
///     await cache.handleMemoryPressure(level: level, currentTime: time)
/// }
/// ```
///
/// 参考：
/// - Task-102 §3.2 差异 2: 内存压力响应策略
/// - Task-102 §7 风险与未决 - 风险 B
public actor MemoryPressureMonitor {
    private let logger = Logger(subsystem: "com.prismplayer.core", category: "audio.memory")

    /// 内存压力事件
    public struct PressureEvent: Sendable {
        public let level: MemoryPressureLevel
        public let timestamp: Date
    }

    /// 最近警告时间戳（用于分级判断）
    private var recentWarnings: [Date] = []

    /// 压力事件流（使用 AsyncStream）
    public let pressureStream: AsyncStream<PressureEvent>
    private let pressureContinuation: AsyncStream<PressureEvent>.Continuation

    /// 当前播放时间提供者（可选）
    private var currentTimeProvider: (@Sendable () -> CMTime)?

    /// 初始化
    public init() {
        var continuation: AsyncStream<PressureEvent>.Continuation!
        self.pressureStream = AsyncStream { cont in
            continuation = cont
        }
        self.pressureContinuation = continuation

        // 启动监听（需要在主线程）
        Task { @MainActor in
            await self.setupNotifications()
        }
    }

    /// 设置当前播放时间提供者
    /// - Parameter provider: 返回当前播放时间的闭包
    public func setCurrentTimeProvider(_ provider: @escaping @Sendable () -> CMTime) {
        self.currentTimeProvider = provider
    }
    /// 手动触发内存压力（用于测试）
    /// - Parameter level: 内存压力等级
    public func triggerPressure(level: MemoryPressureLevel = .warning) {
        let event = PressureEvent(level: level, timestamp: Date())
        pressureContinuation.yield(event)
        logger.notice("手动触发内存压力: level=\(level.rawValue, privacy: .public)")
    }

    // MARK: - Private Methods

    /// 设置通知监听
    private func setupNotifications() {
        #if canImport(UIKit)
            // iOS/tvOS
            NotificationCenter.default.addObserver(
                forName: UIApplication.didReceiveMemoryWarningNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { [weak self] in
                    await self?.handleMemoryWarning()
                }
            }
        #else
            // macOS
            // Note: macOS 没有标准的内存警告通知，需要自行实现
            // 可以通过监听 mach_task_self() 或使用 DispatchSource.makeMemoryPressureSource
            logger.info("macOS 平台暂不支持自动内存压力监控，请使用 triggerPressure() 手动触发")
        #endif
    }

    /// 处理内存警告
    private func handleMemoryWarning() {
        let now = Date()
        recentWarnings.append(now)

        // 清理超过 60s 的旧警告
        recentWarnings.removeAll { now.timeIntervalSince($0) > 60 }

        // 分级判断
        let level = determineLevel()

        logger.warning(
            "收到内存警告: level=\(level.rawValue, privacy: .public), 最近警告次数=\(self.recentWarnings.count, privacy: .public)"
        )

        let event = PressureEvent(level: level, timestamp: now)
        pressureContinuation.yield(event)
    }

    /// 根据最近警告次数判断压力等级
    ///
    /// 分级规则：
    /// - 1 次警告 → warning
    /// - 3 次警告（30s 内）→ urgent
    /// - 5 次警告（60s 内）→ critical
    private func determineLevel() -> MemoryPressureLevel {
        let now = Date()

        // 统计 60s 内的警告次数
        let warningsIn60s = recentWarnings.filter { now.timeIntervalSince($0) <= 60 }.count

        // 统计 30s 内的警告次数
        let warningsIn30s = recentWarnings.filter { now.timeIntervalSince($0) <= 30 }.count

        if warningsIn60s >= 5 {
            return .critical
        } else if warningsIn30s >= 3 {
            return .urgent
        } else {
            return .warning
        }
    }

    deinit {
        pressureContinuation.finish()
    }
}
