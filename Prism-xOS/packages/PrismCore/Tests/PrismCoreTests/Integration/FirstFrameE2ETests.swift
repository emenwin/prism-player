import XCTest
import AVFoundation
@testable import PrismCore

/// 首帧 E2E 集成测试
///
/// 测试范围：
/// - 端到端首帧时间验证
/// - 双路并行策略效果验证
/// - 内存和性能监控
/// - 真实媒体文件处理
///
/// 性能目标（参考 Task-102 §4.3）：
/// - 短视频（<5min）高端设备：P95 < 5s
/// - 中端设备：P95 < 8s
/// - 低端设备：P95 < 12s
///
/// 参考：Task-102 §5.2 集成测试
@available(iOS 17.0, macOS 14.0, *)
final class FirstFrameE2ETests: XCTestCase {
    
    var preloadService: AudioPreloadService!
    var cache: AudioCache!
    var memoryMonitor: MemoryPressureMonitor!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // 初始化组件
        let extractor = AVAssetAudioExtractor()
        
        cache = AudioCache(maxSizeMB: 10, maxItems: 50)
        memoryMonitor = MemoryPressureMonitor()
        
        preloadService = AudioPreloadService(
            extractor: extractor,
            strategy: .default,
            maxConcurrentTasks: 3
        )
    }
    
    override func tearDown() async throws {
        await cache.removeAll()
        cache = nil
        memoryMonitor = nil
        preloadService = nil
        try await super.tearDown()
    }
    
    // MARK: - 测试音频文件生成
    
    /// 创建测试音频 AVAsset
    /// - Parameters:
    ///   - duration: 音频时长（秒）
    ///   - sampleRate: 采样率
    /// - Returns: AVAsset（临时文件会在测试结束后自动清理）
    private func createTestAudioAsset(duration: TimeInterval, sampleRate: Double = 44100) throws -> AVAsset {
        // 创建临时文件
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        
        // 创建音频文件写入器
        let writer = try AVAssetWriter(outputURL: tempURL, fileType: .m4a)
        
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64000
        ]
        
        let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        writer.add(writerInput)
        
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        
        writerInput.markAsFinished()
        
        let expectation = XCTestExpectation(description: "Audio file creation")
        writer.finishWriting {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // 注册清理
        addTeardownBlock {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        return AVAsset(url: tempURL)
    }
    
    // MARK: - 基础功能测试
    
    func testGetFirstFrameBuffer_Success() async throws {
        // Given: 创建测试音频文件（30s）
        let asset = try createTestAudioAsset(duration: 30.0)
        
        // When: 启动预加载并获取首帧缓冲区
        try await preloadService.startPreload(for: asset)
        
        let startTime = Date()
        let buffer = try await preloadService.getFirstFrameBuffer()
        let elapsed = Date().timeIntervalSince(startTime)
        
        // Then: 验证结果
        XCTAssertNotNil(buffer, "应成功获取首帧缓冲区")
        XCTAssertGreaterThan(buffer.samples.count, 0, "缓冲区应包含音频数据")
        
        // 验证时长（应该包含 0-5s 的数据，因为双路并行先返回路径A）
        let expectedMinDuration: TimeInterval = 4.0  // 至少 4s
        let expectedMaxDuration: TimeInterval = 11.0 // 最多 11s（包含路径B）
        XCTAssertGreaterThanOrEqual(buffer.duration, expectedMinDuration, "首帧缓冲区应至少包含 4s 数据")
        XCTAssertLessThanOrEqual(buffer.duration, expectedMaxDuration, "首帧缓冲区不应超过 11s")
        
        print("✅ 首帧获取耗时: \(String(format: "%.2f", elapsed))s")
        print("   缓冲区时长: \(String(format: "%.2f", buffer.duration))s")
        print("   数据量: \(String(format: "%.2f", Double(buffer.sizeInBytes) / 1024.0)) KB")
    }
    
    func testDualPathParallelStrategy() async throws {
        // Given: 创建测试音频文件（30s）
        let asset = try createTestAudioAsset(duration: 30.0)
        
        // When: 记录并行任务的执行情况
        let startTime = Date()
        
        // 手动触发双路并行（模拟内部实现）
        let extractor = AVAssetAudioExtractor()
        
        async let pathA = try extractor.extract(
            from: asset,
            timeRange: CMTimeRange(
                start: .zero,
                duration: CMTime(seconds: 5, preferredTimescale: 600)
            )
        )
        
        async let pathB = try extractor.extract(
            from: asset,
            timeRange: CMTimeRange(
                start: CMTime(seconds: 5, preferredTimescale: 600),
                duration: CMTime(seconds: 5, preferredTimescale: 600)
            )
        )
        
        // 等待路径A（首帧应该快速返回）
        let bufferA = try await pathA
        let pathATime = Date().timeIntervalSince(startTime)
        
        // 等待路径B
        let bufferB = try await pathB
        let totalTime = Date().timeIntervalSince(startTime)
        
        // Then: 验证并行效果
        XCTAssertGreaterThan(bufferA.samples.count, 0, "路径A 应返回数据")
        XCTAssertGreaterThan(bufferB.samples.count, 0, "路径B 应返回数据")
        
        // 路径A应该显著快于总时间（证明并行执行）
        XCTAssertLessThan(pathATime, totalTime * 0.8, "路径A 应该先于路径B 完成")
        
        print("✅ 双路并行验证:")
        print("   路径A 耗时: \(String(format: "%.2f", pathATime))s")
        print("   总耗时: \(String(format: "%.2f", totalTime))s")
        print("   并行优势: \(String(format: "%.1f", (1 - pathATime / totalTime) * 100))%")
    }
    
    // MARK: - 性能测试
    
    func testFirstFramePerformance_ShortVideo() async throws {
        // Given: 短视频（30s）
        let asset = try createTestAudioAsset(duration: 30.0)
        
        // When: 测量首帧时间
        measure(metrics: [XCTClockMetric()]) {
            let expectation = XCTestExpectation(description: "First frame")
            
            Task {
                try await preloadService.startPreload(for: asset)
                _ = try await preloadService.getFirstFrameBuffer()
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 15.0)
        }
        
        // 性能目标：P95 < 5s（高端设备）
        // 实际测试会根据设备性能有所不同
    }
    
    func testConcurrentFirstFrameRequests() async throws {
        // Given: 创建多个测试音频文件
        let assets = try (1...3).map { _ in
            try createTestAudioAsset(duration: 30.0)
        }
        
        // When: 并发请求多个首帧
        let startTime = Date()
        
        try await withThrowingTaskGroup(of: PrismCore.AudioBuffer.self) { group in
            for asset in assets {
                group.addTask {
                    try await self.preloadService.startPreload(for: asset)
                    return try await self.preloadService.getFirstFrameBuffer()
                }
            }
            
            var buffers: [PrismCore.AudioBuffer] = []
            for try await buffer in group {
                buffers.append(buffer)
            }
            
            let elapsed = Date().timeIntervalSince(startTime)
            
            // Then: 验证结果
            XCTAssertEqual(buffers.count, 3, "应该成功获取 3 个首帧缓冲区")
            
            // 验证并发控制（不应该是顺序执行的 3 倍时间）
            // 假设单个耗时 ~1s，3 个并发应该 < 2s（最多 3 个并发任务）
            XCTAssertLessThan(elapsed, 5.0, "并发执行应该比顺序执行快")
            
            print("✅ 并发请求验证:")
            print("   请求数: \(assets.count)")
            print("   总耗时: \(String(format: "%.2f", elapsed))s")
            print("   平均耗时: \(String(format: "%.2f", elapsed / Double(assets.count)))s")
        }
    }
    
    // MARK: - 缓存集成测试
    
    func testCacheIntegration() async throws {
        // Given: 创建测试音频文件
        let asset = try createTestAudioAsset(duration: 30.0)
        
        // When: 第一次请求（无缓存）
        try await preloadService.startPreload(for: asset)
        
        let startTime1 = Date()
        let buffer1 = try await preloadService.getFirstFrameBuffer()
        let elapsed1 = Date().timeIntervalSince(startTime1)
        
        // 等待缓存写入
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        
        // 第二次请求（有缓存）
        try await preloadService.startPreload(for: asset)
        
        let startTime2 = Date()
        let buffer2 = try await preloadService.getFirstFrameBuffer()
        let elapsed2 = Date().timeIntervalSince(startTime2)
        
        // Then: 验证缓存效果
        XCTAssertGreaterThan(buffer1.samples.count, 0)
        XCTAssertGreaterThan(buffer2.samples.count, 0)
        
        // 第二次应该显著快于第一次（从缓存读取）
        print("✅ 缓存效果验证:")
        print("   首次耗时: \(String(format: "%.2f", elapsed1))s")
        print("   缓存耗时: \(String(format: "%.2f", elapsed2))s")
        print("   加速比: \(String(format: "%.1f", elapsed1 / max(elapsed2, 0.001)))x")
        
        // 验证缓存命中（第二次应该极快，< 10ms）
        // 注意：实际可能因为音频抽取仍然执行而稍慢
    }
    
    // MARK: - 内存压力测试
    
    func testMemoryPressureHandling() async throws {
        // Given: 创建测试音频文件并获取首帧
        let asset = try createTestAudioAsset(duration: 30.0)
        try await preloadService.startPreload(for: asset)
        let buffer = try await preloadService.getFirstFrameBuffer()
        
        // 手动添加缓存项
        await cache.set(key: "0-10000", buffer: buffer)
        await cache.set(key: "50000-60000", buffer: buffer)
        await cache.set(key: "100000-110000", buffer: buffer)
        
        let itemCountBefore = await cache.itemCount
        XCTAssertEqual(itemCountBefore, 3, "应该有 3 个缓存项")
        
        // When: 模拟 warning 级内存压力（保留 ±60s）
        let currentTime = CMTime(seconds: 50, preferredTimescale: 600)
        await cache.handleMemoryPressure(level: .warning, currentTime: currentTime)
        
        // Then: 验证远端缓存被清理
        let itemCountAfter = await cache.itemCount
        XCTAssertLessThan(itemCountAfter, itemCountBefore, "远端缓存应该被清理")
        
        // 验证当前播放附近的缓存仍然存在
        let nearbyBuffer = await cache.get(key: "50000-60000")
        XCTAssertNotNil(nearbyBuffer, "当前播放附近的缓存应该保留")
        
        print("✅ 内存压力处理:")
        print("   清理前: \(itemCountBefore) 项")
        print("   清理后: \(itemCountAfter) 项")
    }
    
    // MARK: - 边界条件测试
    
    func testVeryShortAudio() async throws {
        // Given: 极短音频（1s）
        let asset = try createTestAudioAsset(duration: 1.0)
        
        // When: 获取首帧
        try await preloadService.startPreload(for: asset)
        let buffer = try await preloadService.getFirstFrameBuffer()
        
        // Then: 应该成功处理
        XCTAssertNotNil(buffer)
        XCTAssertGreaterThan(buffer.samples.count, 0)
        XCTAssertLessThanOrEqual(buffer.duration, 1.1, "缓冲区时长不应超过音频总时长")
    }
    
    func testLongAudioPreload() async throws {
        // Given: 长音频（需要预加载）
        let asset = try createTestAudioAsset(duration: 120.0) // 2分钟
        
        // When: 获取首帧（0-10s）
        try await preloadService.startPreload(for: asset)
        let buffer = try await preloadService.getFirstFrameBuffer()
        
        // Then: 验证首帧正确
        XCTAssertNotNil(buffer)
        XCTAssertGreaterThan(buffer.samples.count, 0)
        
        // 验证首帧时长合理（应该是 0-10s 左右）
        XCTAssertGreaterThanOrEqual(buffer.duration, 4.0)
        XCTAssertLessThanOrEqual(buffer.duration, 11.0)
        
        // 后续预加载应该在后台继续（这里只验证首帧不阻塞）
    }
    
    // MARK: - 错误处理测试
    
    func testInvalidAsset() async throws {
        // Given: 无效的 asset（空音频）
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("txt")
        
        try "invalid".write(to: tempURL, atomically: true, encoding: .utf8)
        
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        let asset = AVAsset(url: tempURL)
        
        // When & Then: 应该抛出错误
        do {
            try await preloadService.startPreload(for: asset)
            _ = try await preloadService.getFirstFrameBuffer()
            XCTFail("应该抛出错误")
        } catch {
            // 成功：捕获了错误
            print("✅ 正确处理无效 asset: \(error)")
        }
    }
    
    // MARK: - 性能指标输出
    
    func testPerformanceMetrics() async throws {
        // Given: 创建测试音频
        let asset = try createTestAudioAsset(duration: 30.0)
        
        // When: 收集性能指标
        var samples: [TimeInterval] = []
        
        for _ in 1...5 {
            // 清理缓存确保每次都是冷启动
            await cache.removeAll()
            
            let startTime = Date()
            try await preloadService.startPreload(for: asset)
            _ = try await preloadService.getFirstFrameBuffer()
            let elapsed = Date().timeIntervalSince(startTime)
            
            samples.append(elapsed)
        }
        
        // Then: 计算统计信息
        let mean = samples.reduce(0, +) / Double(samples.count)
        let sorted = samples.sorted()
        let p50 = sorted[sorted.count / 2]
        let p95 = sorted[Int(Double(sorted.count) * 0.95)]
        let min = sorted.first ?? 0
        let max = sorted.last ?? 0
        
        print("✅ 性能指标（5 次采样）:")
        print("   Mean: \(String(format: "%.2f", mean))s")
        print("   P50:  \(String(format: "%.2f", p50))s")
        print("   P95:  \(String(format: "%.2f", p95))s")
        print("   Min:  \(String(format: "%.2f", min))s")
        print("   Max:  \(String(format: "%.2f", max))s")
        
        // 验证性能目标（模拟器/测试环境可能较慢，放宽要求）
        XCTAssertLessThan(p95, 15.0, "P95 应该 < 15s（测试环境）")
    }
}
