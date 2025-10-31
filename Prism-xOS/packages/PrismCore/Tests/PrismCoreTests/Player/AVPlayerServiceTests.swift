import AVFoundation
import Combine
import XCTest

@testable import PrismCore

/// AVPlayerService 集成测试
///
/// 测试策略：
/// - 使用真实的 AVPlayer 进行集成测试
/// - 使用苹果提供的测试流和本地样本文件
/// - 验证时间发布频率、状态转换、错误处理
///
/// - Created: Sprint 1, Task-101, PR2, commit 2
@MainActor
final class AVPlayerServiceTests: XCTestCase {
    var sut: AVPlayerService!
    var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        try await super.setUp()
        sut = AVPlayerService()
        cancellables = []
    }

    override func tearDown() async throws {
        cancellables = nil
        await sut.stop()
        sut = nil
        try await super.tearDown()
    }

    // MARK: - 加载测试

    /// 测试加载远程 HLS 流
    func testLoadRemoteHLSStream() async throws {
        // Given: Apple 提供的测试 HLS 流
        let url = URL(
            string:
                "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8"
        )!

        // When: 加载媒体
        try await sut.load(url: url)

        // Then: 验证状态和时长
        XCTAssertGreaterThan(sut.duration, 0, "时长应大于 0")
        XCTAssertEqual(sut.currentTime, 0, accuracy: 0.1, "初始时间应为 0")
    }

    /// 测试加载本地文件（如果存在）
    func testLoadLocalMediaFile() async throws {
        // Given: 尝试查找本地测试文件
        guard let url = findLocalTestMedia() else {
            throw XCTSkip("未找到本地测试媒体文件，跳过此测试")
        }

        // When: 加载媒体
        try await sut.load(url: url)

        // Then: 验证加载成功
        XCTAssertGreaterThan(sut.duration, 0, "时长应大于 0")
        XCTAssertEqual(sut.currentTime, 0, accuracy: 0.1, "初始时间应为 0")
    }

    /// 测试加载不存在的本地文件
    func testLoadNonexistentLocalFile() async throws {
        // Given: 不存在的文件路径
        let url = URL(fileURLWithPath: "/path/to/nonexistent/file.mp4")

        // When & Then: 应抛出 fileNotFound 错误
        do {
            try await sut.load(url: url)
            XCTFail("应该抛出 fileNotFound 错误")
        } catch let error as PlayerError {
            if case .fileNotFound = error {
                // 成功：抛出了预期的错误
            } else {
                XCTFail("应该是 fileNotFound 错误，实际是: \(error)")
            }
        }
    }

    /// 测试加载不支持的格式
    func testLoadUnsupportedFormat() async throws {
        // Given: 创建一个空的文本文件假装是媒体文件
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test.txt")

        try "dummy content".write(to: tempURL, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        // When & Then: 应抛出 unsupportedFormat 错误
        do {
            try await sut.load(url: tempURL)
            XCTFail("应该抛出 unsupportedFormat 错误")
        } catch let error as PlayerError {
            if case .unsupportedFormat = error {
                // 成功：抛出了预期的错误
            } else {
                XCTFail("应该是 unsupportedFormat 错误，实际是: \(error)")
            }
        }
    }

    // MARK: - 播放控制测试

    /// 测试播放和暂停
    func testPlayAndPause() async throws {
        // Given: 加载远程媒体
        let url = URL(
            string:
                "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8"
        )!
        try await sut.load(url: url)

        // When: 播放
        await sut.play()

        // Then: 验证播放状态
        try await Task.sleep(nanoseconds: 500_000_000)  // 等待 0.5s
        XCTAssertTrue(sut.isPlaying, "应该在播放中")

        // When: 暂停
        await sut.pause()

        // Then: 验证暂停状态
        try await Task.sleep(nanoseconds: 100_000_000)  // 等待 0.1s
        XCTAssertFalse(sut.isPlaying, "应该已暂停")
    }

    /// 测试 seek 操作
    func testSeek() async throws {
        // Given: 加载远程媒体
        let url = URL(
            string:
                "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8"
        )!
        try await sut.load(url: url)

        // When: 跳转到 5 秒
        let targetTime: TimeInterval = 5.0
        await sut.seek(to: targetTime)

        // Then: 验证当前时间接近目标时间
        try await Task.sleep(nanoseconds: 500_000_000)  // 等待 seek 完成
        XCTAssertEqual(sut.currentTime, targetTime, accuracy: 0.5, "当前时间应接近目标时间")
    }

    // MARK: - 时间发布测试

    /// 测试时间发布频率（目标：≥9Hz，允许系统波动）
    func testTimePublisherFrequency() async throws {
        // Given: 加载远程媒体
        let url = URL(
            string:
                "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8"
        )!
        try await sut.load(url: url)

        var timestamps: [CFAbsoluteTime] = []
        let expectation = XCTestExpectation(description: "收集时间戳")
        expectation.expectedFulfillmentCount = 30

        // When: 订阅时间更新
        sut.timePublisher
            .prefix(30)
            .sink { _ in
                timestamps.append(CFAbsoluteTimeGetCurrent())
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // 开始播放
        await sut.play()

        // 等待收集 30 次更新
        await fulfillment(of: [expectation], timeout: 5.0)

        // Then: 验证发布频率
        var intervals: [TimeInterval] = []
        for i in 1..<timestamps.count {
            intervals.append(timestamps[i] - timestamps[i - 1])
        }

        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
        let expectedInterval: TimeInterval = 0.1  // 10Hz

        // 验证平均间隔接近 0.1s（允许 ±20% 波动）
        XCTAssertEqual(
            avgInterval, expectedInterval, accuracy: 0.02,
            "平均时间间隔应约为 \(expectedInterval)s，实际为 \(avgInterval)s")

        // 验证频率 ≥9Hz（即间隔 ≤0.111s）
        XCTAssertLessThanOrEqual(
            avgInterval, 0.111,
            "平均间隔应 ≤0.111s (9Hz)，实际为 \(avgInterval)s")

        print("📊 时间发布统计:")
        print("   平均间隔: \(String(format: "%.3f", avgInterval))s")
        print("   实际频率: \(String(format: "%.1f", 1.0 / avgInterval))Hz")
        print("   样本数: \(intervals.count)")
    }

    /// 测试时间发布的抖动（标准差应 < 50ms）
    func testTimePublisherJitter() async throws {
        // Given: 加载远程媒体
        let url = URL(
            string:
                "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8"
        )!
        try await sut.load(url: url)

        var timestamps: [CFAbsoluteTime] = []
        let expectation = XCTestExpectation(description: "收集时间戳")
        expectation.expectedFulfillmentCount = 50

        // When: 订阅时间更新
        sut.timePublisher
            .prefix(50)
            .sink { _ in
                timestamps.append(CFAbsoluteTimeGetCurrent())
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // 开始播放
        await sut.play()

        // 等待收集 50 次更新
        await fulfillment(of: [expectation], timeout: 6.0)

        // Then: 计算抖动
        var intervals: [TimeInterval] = []
        for i in 1..<timestamps.count {
            intervals.append(timestamps[i] - timestamps[i - 1])
        }

        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
        let variance =
            intervals.map { pow($0 - avgInterval, 2) }.reduce(0, +) / Double(intervals.count)
        let stdDev = sqrt(variance)

        // 验证标准差 < 50ms
        XCTAssertLessThan(stdDev, 0.05, "标准差应 < 50ms，实际为 \(String(format: "%.3f", stdDev))s")

        print("📊 抖动统计:")
        print("   平均间隔: \(String(format: "%.3f", avgInterval))s")
        print("   标准差: \(String(format: "%.3f", stdDev * 1_000))ms")
        print("   最小间隔: \(String(format: "%.3f", intervals.min() ?? 0))s")
        print("   最大间隔: \(String(format: "%.3f", intervals.max() ?? 0))s")
    }

    // MARK: - 状态发布测试

    /// 测试状态转换发布
    func testStatePublisher() async throws {
        // Given
        var states: [PlayerState] = []
        let expectation = XCTestExpectation(description: "状态转换")
        expectation.expectedFulfillmentCount = 3  // idle → loading → ready

        sut.statePublisher
            .dropFirst()  // 跳过初始 idle
            .prefix(2)  // loading, ready
            .sink { state in
                states.append(state)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // When: 加载媒体
        let url = URL(
            string:
                "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8"
        )!
        try await sut.load(url: url)

        // Then: 验证状态序列
        await fulfillment(of: [expectation], timeout: 5.0)

        XCTAssertEqual(states.count, 2, "应该有 2 次状态转换")
        XCTAssertEqual(states[0], .loading, "第一个状态应该是 loading")
        XCTAssertEqual(states[1], .ready, "第二个状态应该是 ready")
    }

    /// 测试播放状态转换
    func testPlayingStateTransitions() async throws {
        // Given: 加载媒体
        let url = URL(
            string:
                "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8"
        )!
        try await sut.load(url: url)

        var states: [PlayerState] = []
        let expectation = XCTestExpectation(description: "播放状态转换")

        sut.statePublisher
            .sink { state in
                states.append(state)
                if states.count == 4 {  // ready → playing → paused
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When: 播放
        await sut.play()
        try await Task.sleep(nanoseconds: 500_000_000)

        // Then: 暂停
        await sut.pause()
        try await Task.sleep(nanoseconds: 500_000_000)

        await fulfillment(of: [expectation], timeout: 3.0)

        // 验证状态序列包含 playing 和 paused
        XCTAssertTrue(states.contains(.playing), "应该包含 playing 状态")
        XCTAssertTrue(states.contains(.paused), "应该包含 paused 状态")
    }

    // MARK: - Helper Methods

    /// 查找本地测试媒体文件
    private func findLocalTestMedia() -> URL? {
        // 尝试在常见位置查找测试文件
        let possiblePaths = [
            "Tests/Fixtures/audio/sample.m4a",
            "Tests/Fixtures/audio/sample.mp4",
            "../../../Tests/Fixtures/audio/sample.m4a"
        ]

        for path in possiblePaths {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        return nil
    }
}
