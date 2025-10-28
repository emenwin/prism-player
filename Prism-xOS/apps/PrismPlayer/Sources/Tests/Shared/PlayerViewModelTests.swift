//
//  PlayerViewModelTests.swift
//  PrismPlayer Tests
//
//  Created on 2025-10-28.
//

import AVFoundation
import Combine
import XCTest

@testable import PrismCore
@testable import PrismPlayer

/// PlayerViewModel 单元测试
///
/// 覆盖范围：
/// - 状态转换测试（idle → loading → ready → playing → paused）
/// - 播放/暂停/跳转功能
/// - 时间同步与抖动验证
/// - 错误处理（所有 PlayerError 场景）
/// - 用户取消选择
///
/// 目标覆盖率：≥70%，关键路径 ≥80%
@MainActor
final class PlayerViewModelTests: XCTestCase {
    private var mockPlayerService: MockPlayerService!
    private var mockMediaPicker: MockMediaPicker!
    private var viewModel: PlayerViewModel!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        try await super.setUp()
        mockPlayerService = MockPlayerService()
        mockMediaPicker = MockMediaPicker()
        viewModel = PlayerViewModel(
            playerService: mockPlayerService,
            mediaPicker: mockMediaPicker
        )
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() async throws {
        cancellables = nil
        viewModel = nil
        mockMediaPicker = nil
        mockPlayerService = nil
        try await super.tearDown()
    }

    // MARK: - 状态转换测试（关键路径 ≥80%）

    /// 测试加载媒体成功路径：idle → loading → ready
    func testLoadMediaSuccess() async throws {
        // Given
        let testURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test.mp4")

        // 创建临时测试文件
        FileManager.default.createFile(atPath: testURL.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: testURL) }

        mockMediaPicker.mockURL = testURL
        mockPlayerService.setDuration(120.0)

        // When
        await viewModel.selectAndLoadMedia()

        // Then
        XCTAssertEqual(mockPlayerService.loadCallCount, 1, "应该调用 load 一次")
        XCTAssertEqual(mockPlayerService.lastLoadURL, testURL, "应该加载正确的 URL")
        XCTAssertEqual(viewModel.state, .ready, "状态应为 ready")
        XCTAssertEqual(viewModel.currentMediaURL, testURL, "应该记录当前 URL")
        XCTAssertNil(viewModel.errorMessage, "不应有错误信息")
    }

    /// 测试用户取消选择：不触发 load
    func testUserCancelSelection() async throws {
        // Given
        mockMediaPicker.mockURL = nil  // 模拟用户取消

        // When
        await viewModel.selectAndLoadMedia()

        // Then
        XCTAssertEqual(viewModel.state, .idle, "状态应保持 idle")
        XCTAssertNil(viewModel.currentMediaURL, "不应记录 URL")
        XCTAssertEqual(mockPlayerService.loadCallCount, 0, "不应调用 load")
    }

    /// 测试播放状态转换：ready → playing
    func testPlayStateTransition() async throws {
        // Given
        mockPlayerService.setState(.ready)

        // When
        await viewModel.play()

        // Then
        XCTAssertEqual(mockPlayerService.playCallCount, 1, "应该调用 play 一次")
        XCTAssertEqual(viewModel.state, .playing, "状态应为 playing")
        XCTAssertTrue(viewModel.isPlaying, "isPlaying 应为 true")
    }

    /// 测试暂停状态转换：playing → paused
    func testPauseStateTransition() async throws {
        // Given
        mockPlayerService.setState(.playing)
        await viewModel.play()

        // When
        await viewModel.pause()

        // Then
        XCTAssertEqual(mockPlayerService.pauseCallCount, 1, "应该调用 pause 一次")
        XCTAssertEqual(viewModel.state, .paused, "状态应为 paused")
        XCTAssertFalse(viewModel.isPlaying, "isPlaying 应为 false")
    }

    /// 测试跳转功能
    func testSeekToTime() async throws {
        // Given
        let targetTime: TimeInterval = 60.0
        mockPlayerService.setDuration(120.0)
        mockPlayerService.setState(.playing)

        // When
        await viewModel.seek(to: targetTime)

        // Then
        XCTAssertEqual(mockPlayerService.seekCallCount, 1, "应该调用 seek 一次")
        XCTAssertEqual(mockPlayerService.lastSeekTime, targetTime, "应该跳转到正确时间")
    }

    // MARK: - 时间同步测试

    /// 测试时间发布者转发到 currentTime
    func testTimePublisherForwarding() async throws {
        // Given
        let expectedTimes: [TimeInterval] = [0.0, 0.1, 0.2, 0.3]
        var receivedTimes: [TimeInterval] = []

        let expectation = XCTestExpectation(description: "接收时间更新")
        expectation.expectedFulfillmentCount = expectedTimes.count

        viewModel.$currentTime
            .dropFirst() // 跳过初始值 0
            .sink { time in
                receivedTimes.append(time)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // When
        for time in expectedTimes {
            mockPlayerService.setCurrentTime(time)
        }

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedTimes, expectedTimes, "应该接收到所有时间更新")
    }

    /// 测试时间发布抖动验证（<50ms）
    func testTimePublisherJitter() async throws {
        // Given
        var timestamps: [TimeInterval] = []
        var intervals: [TimeInterval] = []

        let expectation = XCTestExpectation(description: "收集时间戳")
        expectation.expectedFulfillmentCount = 20

        viewModel.$currentTime
            .dropFirst() // 跳过初始值
            .prefix(20)
            .sink { _ in
                timestamps.append(CACurrentMediaTime())
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // When: 模拟 10Hz 发布 (每 0.1s)
        for i in 0..<20 {
            mockPlayerService.setCurrentTime(Double(i) * 0.1)
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        }

        await fulfillment(of: [expectation], timeout: 3.0)

        // 计算时间间隔
        for i in 1..<timestamps.count {
            intervals.append(timestamps[i] - timestamps[i - 1])
        }

        // Then: 验证平均间隔接近 0.1s，标准差 < 0.05s
        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
        let variance = intervals.map { pow($0 - avgInterval, 2) }.reduce(0, +) / Double(intervals.count)
        let stdDev = sqrt(variance)

        XCTAssertEqual(avgInterval, 0.1, accuracy: 0.01, "平均间隔应为 0.1s")
        XCTAssertLessThan(stdDev, 0.05, "标准差应 < 50ms")
    }

    /// 测试时长更新（仅在 ready/playing 状态）
    func testDurationUpdateInReadyAndPlayingStates() async throws {
        // Given
        let expectedDuration: TimeInterval = 180.0
        mockPlayerService.setDuration(expectedDuration)

        // When: 状态变为 ready
        mockPlayerService.setState(.ready)

        // Then
        try await Task.sleep(nanoseconds: 100_000_000) // 等待状态更新
        XCTAssertEqual(viewModel.duration, expectedDuration, "ready 状态应更新时长")

        // When: 状态变为 playing
        mockPlayerService.setState(.playing)

        // Then
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(viewModel.duration, expectedDuration, "playing 状态应保持时长")

        // When: 状态变为 paused
        mockPlayerService.setState(.paused)

        // Then
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(viewModel.duration, expectedDuration, "paused 状态不应改变时长")
    }

    // MARK: - 错误处理测试（覆盖所有 PlayerError 场景）

    /// 测试文件不存在错误
    func testFileNotFoundError() async throws {
        // Given
        let nonexistentURL = URL(fileURLWithPath: "/nonexistent/path/test.mp4")
        mockMediaPicker.mockURL = nonexistentURL

        // When
        await viewModel.selectAndLoadMedia()

        // Then
        XCTAssertEqual(viewModel.state, .idle, "状态应保持 idle")
        XCTAssertNotNil(viewModel.errorMessage, "应该有错误信息")
        XCTAssertTrue(
            viewModel.errorMessage?.contains("未找到") ?? false,
            "错误信息应包含'未找到'"
        )
        XCTAssertEqual(mockPlayerService.loadCallCount, 0, "不应调用 load")
    }

    /// 测试不支持格式错误
    func testUnsupportedFormatError() async throws {
        // Given: 创建一个无效的媒体文件
        let invalidURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("invalid.xyz")

        // 创建文件但内容为空（不可播放）
        FileManager.default.createFile(atPath: invalidURL.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: invalidURL) }

        mockMediaPicker.mockURL = invalidURL

        // When
        await viewModel.selectAndLoadMedia()

        // Then
        XCTAssertEqual(viewModel.state, .idle, "状态应保持 idle")
        XCTAssertNotNil(viewModel.errorMessage, "应该有错误信息")
        // 注意：空文件可能通过 isPlayable 检查，所以可能触发 loadFailed
        XCTAssertEqual(mockPlayerService.loadCallCount, 0, "验证失败不应调用 load")
    }

    /// 测试加载失败错误
    func testLoadFailedError() async throws {
        // Given
        let testURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test.mp4")

        FileManager.default.createFile(atPath: testURL.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: testURL) }

        mockMediaPicker.mockURL = testURL
        mockPlayerService.shouldFailOnLoad = true
        mockPlayerService.loadError = .loadFailed("模拟加载错误")

        // When
        await viewModel.selectAndLoadMedia()

        // Then
        XCTAssertNotNil(viewModel.errorMessage, "应该有错误信息")
        XCTAssertTrue(
            viewModel.errorMessage?.contains("加载") ?? false,
            "错误信息应包含'加载'"
        )
        XCTAssertEqual(mockPlayerService.loadCallCount, 1, "应该尝试调用 load")
    }

    /// 测试 MediaPicker 抛出错误
    func testMediaPickerThrowsError() async throws {
        // Given
        mockMediaPicker.shouldThrow = true
        mockMediaPicker.mockError = NSError(
            domain: "TestError",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "选择文件失败"]
        )

        // When
        await viewModel.selectAndLoadMedia()

        // Then
        XCTAssertEqual(viewModel.state, .idle, "状态应保持 idle")
        XCTAssertNotNil(viewModel.errorMessage, "应该有错误信息")
        XCTAssertEqual(mockPlayerService.loadCallCount, 0, "不应调用 load")
    }

    // MARK: - 状态绑定测试

    /// 测试 isPlaying 绑定
    func testIsPlayingBinding() async throws {
        // Given
        XCTAssertFalse(viewModel.isPlaying, "初始状态不应播放")

        // When: 状态变为 playing
        mockPlayerService.setState(.playing)

        // Then
        try await Task.sleep(nanoseconds: 100_000_000) // 等待状态更新
        XCTAssertTrue(viewModel.isPlaying, "playing 状态 isPlaying 应为 true")

        // When: 状态变为 paused
        mockPlayerService.setState(.paused)

        // Then
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertFalse(viewModel.isPlaying, "paused 状态 isPlaying 应为 false")

        // When: 状态变为 ready
        mockPlayerService.setState(.ready)

        // Then
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertFalse(viewModel.isPlaying, "ready 状态 isPlaying 应为 false")
    }

    /// 测试状态变化传播
    func testStateChangesPropagation() async throws {
        // Given
        let expectedStates: [PlayerState] = [.idle, .loading, .ready, .playing, .paused]
        var receivedStates: [PlayerState] = []

        let expectation = XCTestExpectation(description: "接收状态变化")
        expectation.expectedFulfillmentCount = expectedStates.count

        viewModel.$state
            .sink { state in
                receivedStates.append(state)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // When
        for state in expectedStates {
            mockPlayerService.setState(state)
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }

        // Then
        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertEqual(receivedStates, expectedStates, "应该按顺序接收所有状态")
    }

    // MARK: - 边界情况测试

    /// 测试重复播放调用
    func testMultiplePlayCalls() async throws {
        // Given
        mockPlayerService.setState(.ready)

        // When
        await viewModel.play()
        await viewModel.play()
        await viewModel.play()

        // Then
        XCTAssertEqual(mockPlayerService.playCallCount, 3, "应该记录所有 play 调用")
    }

    /// 测试空 URL 路径处理
    func testEmptyURLPath() async throws {
        // Given
        let emptyURL = URL(fileURLWithPath: "")
        mockMediaPicker.mockURL = emptyURL

        // When
        await viewModel.selectAndLoadMedia()

        // Then
        XCTAssertNotNil(viewModel.errorMessage, "应该有错误信息")
        XCTAssertEqual(mockPlayerService.loadCallCount, 0, "不应调用 load")
    }

    /// 测试错误消息清除
    func testErrorMessageClear() async throws {
        // Given: 先产生一个错误
        let invalidURL = URL(fileURLWithPath: "/nonexistent.mp4")
        mockMediaPicker.mockURL = invalidURL
        await viewModel.selectAndLoadMedia()
        XCTAssertNotNil(viewModel.errorMessage, "应该有错误信息")

        // When: 成功加载新文件
        let validURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("valid.mp4")
        FileManager.default.createFile(atPath: validURL.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: validURL) }

        mockMediaPicker.mockURL = validURL

        await viewModel.selectAndLoadMedia()

        // Then
        XCTAssertNil(viewModel.errorMessage, "错误信息应该被清除")
    }
}
