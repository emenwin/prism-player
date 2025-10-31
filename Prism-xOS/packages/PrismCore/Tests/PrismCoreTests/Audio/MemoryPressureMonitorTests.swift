import XCTest
@testable import PrismCore

/// MemoryPressureMonitor 单元测试
///
/// 测试范围：
/// - 分级压力检测（滑动窗口）
/// - AsyncStream 事件发布
/// - 手动触发压力
/// - 边界条件
///
/// 参考：Task-102 §5.1 单元测试
final class MemoryPressureMonitorTests: XCTestCase {
    
    var monitor: MemoryPressureMonitor!
    
    override func setUp() async throws {
        try await super.setUp()
        monitor = MemoryPressureMonitor()
    }
    
    override func tearDown() async throws {
        monitor = nil
        try await super.tearDown()
    }
    
    // MARK: - 手动触发测试
    
    func testManualTriggerWarning() async {
        // Given: 创建监听器
        actor EventCollector {
            var events: [MemoryPressureMonitor.PressureEvent] = []
            
            func append(_ event: MemoryPressureMonitor.PressureEvent) {
                events.append(event)
            }
            
            func getEvents() -> [MemoryPressureMonitor.PressureEvent] {
                return events
            }
        }
        
        let collector = EventCollector()
        
        // When: 在后台收集事件
        let task = Task {
            for await event in await monitor.pressureStream {
                await collector.append(event)
                let count = await collector.getEvents().count
                if count >= 1 {
                    break
                }
            }
        }
        
        // 触发 warning
        try? await Task.sleep(nanoseconds: 100_000_000)
        await monitor.triggerPressure(level: .warning)
        
        // 等待收集完成
        _ = await task.result
        
        // Then: 应该收到 warning 事件
        let events = await collector.getEvents()
        XCTAssertEqual(events.count, 1, "应该收到 1 个事件")
        XCTAssertEqual(events.first?.level, .warning, "应该为 warning 级别")
    }
    
    func testManualTriggerUrgent() async {
        // Given: 创建监听器
        actor EventCollector {
            var events: [MemoryPressureMonitor.PressureEvent] = []
            
            func append(_ event: MemoryPressureMonitor.PressureEvent) {
                events.append(event)
            }
            
            func getEvents() -> [MemoryPressureMonitor.PressureEvent] {
                return events
            }
        }
        
        let collector = EventCollector()
        
        // When: 在后台收集事件
        let task = Task {
            for await event in await monitor.pressureStream {
                await collector.append(event)
                let count = await collector.getEvents().count
                if count >= 1 {
                    break
                }
            }
        }
        
        // 触发 urgent
        try? await Task.sleep(nanoseconds: 100_000_000)
        await monitor.triggerPressure(level: .urgent)
        
        // 等待收集完成
        _ = await task.result
        
        // Then: 应该收到 urgent 事件
        let events = await collector.getEvents()
        XCTAssertEqual(events.count, 1, "应该收到 1 个事件")
        XCTAssertEqual(events.first?.level, .urgent, "应该为 urgent 级别")
    }
    
    func testManualTriggerCritical() async {
        // Given: 创建监听器
        actor EventCollector {
            var events: [MemoryPressureMonitor.PressureEvent] = []
            
            func append(_ event: MemoryPressureMonitor.PressureEvent) {
                events.append(event)
            }
            
            func getEvents() -> [MemoryPressureMonitor.PressureEvent] {
                return events
            }
        }
        
        let collector = EventCollector()
        
        // When: 在后台收集事件
        let task = Task {
            for await event in await monitor.pressureStream {
                await collector.append(event)
                let count = await collector.getEvents().count
                if count >= 1 {
                    break
                }
            }
        }
        
        // 触发 critical
        try? await Task.sleep(nanoseconds: 100_000_000)
        await monitor.triggerPressure(level: .critical)
        
        // 等待收集完成
        _ = await task.result
        
        // Then: 应该收到 critical 事件
        let events = await collector.getEvents()
        XCTAssertEqual(events.count, 1, "应该收到 1 个事件")
        XCTAssertEqual(events.first?.level, .critical, "应该为 critical 级别")
    }
    
    // MARK: - AsyncStream 事件发布测试
    
    func testPressureEventStream() async {
        // Given: 创建监听器并订阅事件流
        actor EventCollector {
            var events: [MemoryPressureMonitor.PressureEvent] = []
            
            func append(_ event: MemoryPressureMonitor.PressureEvent) {
                events.append(event)
            }
            
            func getEvents() -> [MemoryPressureMonitor.PressureEvent] {
                return events
            }
        }
        
        let collector = EventCollector()
        
        // When: 在后台收集事件
        let task = Task {
            for await event in await monitor.pressureStream {
                await collector.append(event)
                // 收集到 3 个事件后退出
                let count = await collector.getEvents().count
                if count >= 3 {
                    break
                }
            }
        }
        
        // 触发 3 次不同级别的警告
        try? await Task.sleep(nanoseconds: 100_000_000)
        await monitor.triggerPressure(level: .warning)
        try? await Task.sleep(nanoseconds: 100_000_000)
        await monitor.triggerPressure(level: .urgent)
        try? await Task.sleep(nanoseconds: 100_000_000)
        await monitor.triggerPressure(level: .critical)
        
        // 等待收集完成
        _ = await task.result
        
        // Then: 应该收到 3 个事件
        let events = await collector.getEvents()
        XCTAssertEqual(events.count, 3, "应该收到 3 个压力事件")
        XCTAssertEqual(events[0].level, .warning, "第 1 个应为 warning")
        XCTAssertEqual(events[1].level, .urgent, "第 2 个应为 urgent")
        XCTAssertEqual(events[2].level, .critical, "第 3 个应为 critical")
    }
    
    func testMultipleStreamSubscribers() async {
        // Given: 创建监听器
        actor EventCounter {
            var count = 0
            
            func increment() {
                count += 1
            }
            
            func getCount() -> Int {
                return count
            }
        }
        
        let counter1 = EventCounter()
        let counter2 = EventCounter()
        
        // When: 创建 2 个订阅者
        let task1 = Task {
            for await _ in await monitor.pressureStream {
                await counter1.increment()
                let count = await counter1.getCount()
                if count >= 2 {
                    break
                }
            }
        }
        
        let task2 = Task {
            for await _ in await monitor.pressureStream {
                await counter2.increment()
                let count = await counter2.getCount()
                if count >= 2 {
                    break
                }
            }
        }
        
        // 触发 2 次警告
        try? await Task.sleep(nanoseconds: 100_000_000)
        await monitor.triggerPressure(level: .warning)
        try? await Task.sleep(nanoseconds: 100_000_000)
        await monitor.triggerPressure(level: .urgent)
        
        // 等待收集完成
        _ = await task1.result
        _ = await task2.result
        
        // Then: 两个订阅者都应该收到事件
        let count1 = await counter1.getCount()
        let count2 = await counter2.getCount()
        XCTAssertGreaterThanOrEqual(count1, 2, "订阅者 1 应该收到事件")
        XCTAssertGreaterThanOrEqual(count2, 2, "订阅者 2 应该收到事件")
    }
    
    // MARK: - 边界条件测试
    
    func testRapidTriggers() async {
        // Given: 创建监听器
        actor EventCounter {
            var count = 0
            
            func increment() {
                count += 1
            }
            
            func getCount() -> Int {
                return count
            }
        }
        
        let counter = EventCounter()
        
        // When: 快速触发多次警告
        let task = Task {
            for await _ in await monitor.pressureStream {
                await counter.increment()
                let count = await counter.getCount()
                if count >= 10 {
                    break
                }
            }
        }
        
        for _ in 1...10 {
            await monitor.triggerPressure(level: .warning)
        }
        
        // 等待收集完成
        _ = await task.result
        
        // Then: 应该收到所有事件
        let count = await counter.getCount()
        XCTAssertEqual(count, 10, "应该收到所有 10 个事件")
    }
    
    func testEventTimestamps() async {
        // Given: 创建监听器
        actor EventCollector {
            var events: [MemoryPressureMonitor.PressureEvent] = []
            
            func append(_ event: MemoryPressureMonitor.PressureEvent) {
                events.append(event)
            }
            
            func getEvents() -> [MemoryPressureMonitor.PressureEvent] {
                return events
            }
        }
        
        let collector = EventCollector()
        
        // When: 收集带时间戳的事件
        let task = Task {
            for await event in await monitor.pressureStream {
                await collector.append(event)
                let count = await collector.getEvents().count
                if count >= 3 {
                    break
                }
            }
        }
        
        let startTime = Date()
        await monitor.triggerPressure(level: .warning)
        try? await Task.sleep(nanoseconds: 100_000_000)
        await monitor.triggerPressure(level: .urgent)
        try? await Task.sleep(nanoseconds: 100_000_000)
        await monitor.triggerPressure(level: .critical)
        
        // 等待收集完成
        _ = await task.result
        
        // Then: 时间戳应该递增
        let events = await collector.getEvents()
        XCTAssertEqual(events.count, 3)
        
        for event in events {
            XCTAssertGreaterThanOrEqual(event.timestamp, startTime, "时间戳应该在测试开始之后")
        }
        
        // 验证时间戳递增
        if events.count >= 2 {
            XCTAssertLessThanOrEqual(events[0].timestamp, events[1].timestamp, "时间戳应该递增")
        }
        if events.count >= 3 {
            XCTAssertLessThanOrEqual(events[1].timestamp, events[2].timestamp, "时间戳应该递增")
        }
    }
    
    func testMixedPressureLevels() async {
        // Given: 创建监听器
        actor EventCollector {
            var events: [MemoryPressureMonitor.PressureEvent] = []
            
            func append(_ event: MemoryPressureMonitor.PressureEvent) {
                events.append(event)
            }
            
            func getEvents() -> [MemoryPressureMonitor.PressureEvent] {
                return events
            }
        }
        
        let collector = EventCollector()
        
        // When: 混合触发不同级别
        let task = Task {
            for await event in await monitor.pressureStream {
                await collector.append(event)
                let count = await collector.getEvents().count
                if count >= 5 {
                    break
                }
            }
        }
        
        await monitor.triggerPressure(level: .warning)
        await monitor.triggerPressure(level: .critical)
        await monitor.triggerPressure(level: .urgent)
        await monitor.triggerPressure(level: .warning)
        await monitor.triggerPressure(level: .critical)
        
        // 等待收集完成
        _ = await task.result
        
        // Then: 应该按顺序收到所有事件
        let events = await collector.getEvents()
        XCTAssertEqual(events.count, 5)
        XCTAssertEqual(events[0].level, .warning)
        XCTAssertEqual(events[1].level, .critical)
        XCTAssertEqual(events[2].level, .urgent)
        XCTAssertEqual(events[3].level, .warning)
        XCTAssertEqual(events[4].level, .critical)
    }
}

