import AVFoundation
import XCTest

@testable import PrismCore

/// AudioCache 单元测试
///
/// 测试范围：
/// - LRU 淘汰逻辑
/// - 内存压力清理（三级策略）
/// - 容量限制（大小 + 项数）
/// - 缓存操作（set/get/remove）
///
/// 参考：Task-102 §5.1 单元测试
final class AudioCacheTests: XCTestCase {
    var cache: AudioCache!

    override func setUp() async throws {
        try await super.setUp()
        cache = AudioCache(maxSizeMB: 1, maxItems: 10)
    }

    override func tearDown() async throws {
        await cache.removeAll()
        cache = nil
        try await super.tearDown()
    }

    // MARK: - Helper Methods

    /// 创建测试音频缓冲区
    private func makeTestBuffer(duration: TimeInterval, id: String) -> PrismCore.AudioBuffer {
        let sampleCount = Int(duration * 16_000)  // 16kHz
        let samples = Array(repeating: Float(0.5), count: sampleCount)
        return PrismCore.AudioBuffer(
            samples: samples,
            sampleRate: 16_000,
            channels: 1,
            timeRange: CMTimeRange(
                start: .zero,
                duration: CMTime(seconds: duration, preferredTimescale: 600)
            )
        )
    }

    // MARK: - 基础操作测试

    func testSetAndGet() async {
        // Given: 创建测试缓冲区
        let buffer = makeTestBuffer(duration: 1.0, id: "test")

        // When: 存储缓冲区
        await cache.set(key: "test-key", buffer: buffer)

        // Then: 可以获取到
        let retrieved = await cache.get(key: "test-key")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.samples.count, buffer.samples.count)
    }

    func testGetNonexistentKey() async {
        // When: 获取不存在的 key
        let retrieved = await cache.get(key: "nonexistent")

        // Then: 应返回 nil
        XCTAssertNil(retrieved)
    }

    func testRemove() async {
        // Given: 存储缓冲区
        let buffer = makeTestBuffer(duration: 1.0, id: "test")
        await cache.set(key: "test-key", buffer: buffer)

        // When: 删除
        await cache.remove(key: "test-key")

        // Then: 无法再获取
        let retrieved = await cache.get(key: "test-key")
        XCTAssertNil(retrieved)
    }

    func testRemoveAll() async {
        // Given: 存储多个缓冲区
        for i in 1...5 {
            let buffer = makeTestBuffer(duration: 1.0, id: "\(i)")
            await cache.set(key: "key-\(i)", buffer: buffer)
        }

        // When: 清空所有
        await cache.removeAll()

        // Then: 所有缓存都被清除
        let count = await cache.itemCount
        XCTAssertEqual(count, 0)
    }

    func testUpdateExistingKey() async {
        // Given: 存储缓冲区
        let buffer1 = makeTestBuffer(duration: 1.0, id: "test1")
        await cache.set(key: "test-key", buffer: buffer1)

        // When: 用新缓冲区更新同一 key
        let buffer2 = makeTestBuffer(duration: 2.0, id: "test2")
        await cache.set(key: "test-key", buffer: buffer2)

        // Then: 获取到新缓冲区
        let retrieved = await cache.get(key: "test-key")
        XCTAssertEqual(retrieved?.samples.count, buffer2.samples.count)
    }

    // MARK: - LRU 淘汰测试

    func testLRUEvictionByItemCount() async {
        // Given: 容量限制为 3 个项
        let limitedCache = AudioCache(maxSizeMB: 100, maxItems: 3)

        let buffer1 = makeTestBuffer(duration: 1.0, id: "1")
        let buffer2 = makeTestBuffer(duration: 1.0, id: "2")
        let buffer3 = makeTestBuffer(duration: 1.0, id: "3")
        let buffer4 = makeTestBuffer(duration: 1.0, id: "4")

        // When: 依次插入 4 个
        await limitedCache.set(key: "key1", buffer: buffer1)
        await limitedCache.set(key: "key2", buffer: buffer2)
        await limitedCache.set(key: "key3", buffer: buffer3)
        await limitedCache.set(key: "key4", buffer: buffer4)  // 触发 LRU，应淘汰 key1

        // Then: key1 应该被淘汰
        let retrieved1 = await limitedCache.get(key: "key1")
        XCTAssertNil(retrieved1, "最久未使用的 key1 应该被淘汰")

        let retrieved2 = await limitedCache.get(key: "key2")
        XCTAssertNotNil(retrieved2, "key2 应该仍在缓存中")

        let count = await limitedCache.itemCount
        XCTAssertEqual(count, 3, "缓存项数应该不超过限制")

        await limitedCache.removeAll()
    }

    func testLRUEvictionBySize() async {
        // Given: 容量限制为 0.1 MB（约 1.5s 音频）
        let limitedCache = AudioCache(maxSizeMB: 1, maxItems: 100)

        // When: 插入多个 1s 缓冲区（每个约 64KB）
        for i in 1...20 {
            let buffer = makeTestBuffer(duration: 1.0, id: "\(i)")
            await limitedCache.set(key: "key\(i)", buffer: buffer)
        }

        // Then: 早期插入的应该被淘汰
        let retrieved1 = await limitedCache.get(key: "key1")
        XCTAssertNil(retrieved1, "最早插入的应该被淘汰")

        let retrieved20 = await limitedCache.get(key: "key20")
        XCTAssertNotNil(retrieved20, "最近插入的应该仍在缓存中")

        let sizeMB = await limitedCache.currentSizeMB
        XCTAssertLessThanOrEqual(sizeMB, 1.0, "缓存大小应该不超过限制")

        await limitedCache.removeAll()
    }

    func testLRUAccessTimeUpdate() async {
        // Given: 容量限制为 3 个项
        let limitedCache = AudioCache(maxSizeMB: 100, maxItems: 3)

        await limitedCache.set(key: "key1", buffer: makeTestBuffer(duration: 1.0, id: "1"))
        await limitedCache.set(key: "key2", buffer: makeTestBuffer(duration: 1.0, id: "2"))
        await limitedCache.set(key: "key3", buffer: makeTestBuffer(duration: 1.0, id: "3"))

        // When: 访问 key1（更新访问时间）
        _ = await limitedCache.get(key: "key1")

        // Then: 插入 key4 时，应该淘汰 key2（最久未访问）
        await limitedCache.set(key: "key4", buffer: makeTestBuffer(duration: 1.0, id: "4"))

        let retrieved1 = await limitedCache.get(key: "key1")
        XCTAssertNotNil(retrieved1, "被访问过的 key1 不应该被淘汰")

        let retrieved2 = await limitedCache.get(key: "key2")
        XCTAssertNil(retrieved2, "未被访问的 key2 应该被淘汰")

        await limitedCache.removeAll()
    }

    // MARK: - 内存压力清理测试

    func testMemoryPressureWarning() async {
        // Given: 缓存多个缓冲区（分布在不同时间范围）
        await cache.set(key: "0-1000", buffer: makeTestBuffer(duration: 1.0, id: "1"))  // 0-1s
        await cache.set(key: "30000-31000", buffer: makeTestBuffer(duration: 1.0, id: "2"))  // 30-31s
        await cache.set(key: "70000-71000", buffer: makeTestBuffer(duration: 1.0, id: "3"))  // 70-71s
        await cache.set(key: "120000-121000", buffer: makeTestBuffer(duration: 1.0, id: "4"))  // 120-121s

        // When: 模拟 Warning 级内存压力（当前播放 50s，保留 ±60s）
        let currentTime = CMTime(seconds: 50, preferredTimescale: 600)
        await cache.handleMemoryPressure(level: .warning, currentTime: currentTime)

        // Then: 超出 ±60s 范围的应该被清理
        let retrieved1 = await cache.get(key: "0-1000")
        XCTAssertNotNil(retrieved1, "0-1s 在 ±60s 范围内，不应被清理")

        let retrieved4 = await cache.get(key: "120000-121000")
        XCTAssertNil(retrieved4, "120-121s 超出 ±60s 范围，应该被清理")
    }

    func testMemoryPressureUrgent() async {
        // Given: 缓存多个缓冲区
        await cache.set(key: "10000-11000", buffer: makeTestBuffer(duration: 1.0, id: "1"))  // 10-11s
        await cache.set(key: "25000-26000", buffer: makeTestBuffer(duration: 1.0, id: "2"))  // 25-26s
        await cache.set(key: "50000-51000", buffer: makeTestBuffer(duration: 1.0, id: "3"))  // 50-51s
        await cache.set(key: "85000-86000", buffer: makeTestBuffer(duration: 1.0, id: "4"))  // 85-86s

        // When: 模拟 Urgent 级内存压力（当前播放 50s，保留 ±30s）
        let currentTime = CMTime(seconds: 50, preferredTimescale: 600)
        await cache.handleMemoryPressure(level: .urgent, currentTime: currentTime)

        // Then: 超出 ±30s 范围的应该被清理
        let retrieved1 = await cache.get(key: "10000-11000")
        XCTAssertNil(retrieved1, "10-11s 超出 ±30s 范围，应该被清理")

        let retrieved2 = await cache.get(key: "25000-26000")
        XCTAssertNotNil(retrieved2, "25-26s 在 ±30s 范围内，不应被清理")

        let retrieved4 = await cache.get(key: "85000-86000")
        XCTAssertNil(retrieved4, "85-86s 超出 ±30s 范围，应该被清理")
    }

    func testMemoryPressureCritical() async {
        // Given: 缓存多个缓冲区
        await cache.set(key: "30000-31000", buffer: makeTestBuffer(duration: 1.0, id: "1"))  // 30-31s
        await cache.set(key: "45000-46000", buffer: makeTestBuffer(duration: 1.0, id: "2"))  // 45-46s
        await cache.set(key: "50000-51000", buffer: makeTestBuffer(duration: 1.0, id: "3"))  // 50-51s
        await cache.set(key: "70000-71000", buffer: makeTestBuffer(duration: 1.0, id: "4"))  // 70-71s

        // When: 模拟 Critical 级内存压力（当前播放 50s，仅保留 ±15s）
        let currentTime = CMTime(seconds: 50, preferredTimescale: 600)
        await cache.handleMemoryPressure(level: .critical, currentTime: currentTime)

        // Then: 仅保留 35-65s 范围
        let retrieved1 = await cache.get(key: "30000-31000")
        XCTAssertNil(retrieved1, "30-31s 超出 ±15s 范围，应该被清理")

        let retrieved2 = await cache.get(key: "45000-46000")
        XCTAssertNotNil(retrieved2, "45-46s 在 ±15s 范围内，不应被清理")

        let retrieved3 = await cache.get(key: "50000-51000")
        XCTAssertNotNil(retrieved3, "50-51s 在 ±15s 范围内，不应被清理")

        let retrieved4 = await cache.get(key: "70000-71000")
        XCTAssertNil(retrieved4, "70-71s 超出 ±15s 范围，应该被清理")
    }

    func testMemoryPressureNormal() async {
        // Given: 缓存多个缓冲区
        await cache.set(key: "key1", buffer: makeTestBuffer(duration: 1.0, id: "1"))
        await cache.set(key: "key2", buffer: makeTestBuffer(duration: 1.0, id: "2"))
        await cache.set(key: "key3", buffer: makeTestBuffer(duration: 1.0, id: "3"))

        let countBefore = await cache.itemCount

        // When: 模拟 Normal 级内存压力（无需清理）
        let currentTime = CMTime(seconds: 50, preferredTimescale: 600)
        await cache.handleMemoryPressure(level: .normal, currentTime: currentTime)

        // Then: 所有缓存都应该保留
        let countAfter = await cache.itemCount
        XCTAssertEqual(countBefore, countAfter, "Normal 级压力不应该清理缓存")
    }

    // MARK: - 容量统计测试

    func testItemCount() async {
        // Given: 空缓存
        var count = await cache.itemCount
        XCTAssertEqual(count, 0, "初始应该为空")

        // When: 添加 3 个项
        for i in 1...3 {
            await cache.set(key: "key\(i)", buffer: makeTestBuffer(duration: 1.0, id: "\(i)"))
        }

        // Then: 计数应该为 3
        count = await cache.itemCount
        XCTAssertEqual(count, 3)

        // When: 删除 1 个
        await cache.remove(key: "key1")

        // Then: 计数应该为 2
        count = await cache.itemCount
        XCTAssertEqual(count, 2)
    }

    func testCurrentSizeMB() async {
        // Given: 添加 1s 音频（约 64KB）
        let buffer = makeTestBuffer(duration: 1.0, id: "test")
        await cache.set(key: "test-key", buffer: buffer)

        // When: 获取当前大小
        let sizeMB = await cache.currentSizeMB

        // Then: 应该约等于 0.06 MB（64KB）
        XCTAssertGreaterThan(sizeMB, 0)
        XCTAssertLessThan(sizeMB, 0.1)  // 允许一定误差
    }

    func testCurrentSizeWithMultipleBuffers() async {
        // Given: 添加 10 个 1s 音频（约 640KB）
        for i in 1...10 {
            let buffer = makeTestBuffer(duration: 1.0, id: "\(i)")
            await cache.set(key: "key\(i)", buffer: buffer)
        }

        // When: 获取当前大小
        let sizeMB = await cache.currentSizeMB

        // Then: 应该约等于 0.6 MB
        XCTAssertGreaterThan(sizeMB, 0.5)
        XCTAssertLessThan(sizeMB, 0.7)
    }

    // MARK: - 边界条件测试

    func testEmptyCache() async {
        // When: 获取空缓存的统计
        let count = await cache.itemCount
        let size = await cache.currentSizeMB

        // Then
        XCTAssertEqual(count, 0)
        XCTAssertEqual(size, 0.0)
    }

    func testLargeBuffer() async {
        // Given: 创建一个很大的缓冲区（60s ≈ 3.84MB）
        let largeBuffer = makeTestBuffer(duration: 60.0, id: "large")

        // When: 存储
        await cache.set(key: "large-key", buffer: largeBuffer)

        // Then: 可以存储和获取
        let retrieved = await cache.get(key: "large-key")
        XCTAssertNotNil(retrieved)

        let sizeMB = await cache.currentSizeMB
        XCTAssertGreaterThan(sizeMB, 3.0)
    }

    func testZeroDurationBuffer() async {
        // Given: 创建零时长缓冲区
        let emptyBuffer = AudioBuffer(
            samples: [],
            sampleRate: 16_000,
            channels: 1,
            timeRange: CMTimeRange(start: .zero, duration: .zero)
        )

        // When: 存储
        await cache.set(key: "empty-key", buffer: emptyBuffer)

        // Then: 可以存储和获取
        let retrieved = await cache.get(key: "empty-key")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.samples.count, 0)
    }
}
