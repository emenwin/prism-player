import XCTest

@testable import PrismCore

/// 示例测试用例：演示如何使用 Mock 进行单元测试
/// Example Test Case: Demonstrates how to use Mocks for unit testing
///
/// 本测试用例展示了测试的最佳实践：
/// This test case demonstrates testing best practices:
///
/// 1. Given-When-Then 模式 / Given-When-Then pattern
/// 2. setUp/tearDown 生命周期 / setUp/tearDown lifecycle
/// 3. Mock 对象的使用 / Using Mock objects
/// 4. 异步测试 / Async testing
/// 5. 断言验证 / Assertions
///
/// - Created: Sprint 0, Task-009
/// - Last Updated: 2025-10-24
final class ExampleMockTests: XCTestCase {
    // MARK: - Properties

    var mockEngine: MockAsrEngine!
    var mockCollector: MockMetricsCollector!

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        mockEngine = MockAsrEngine()
        mockCollector = MockMetricsCollector()
    }

    override func tearDown() {
        mockEngine = nil
        mockCollector = nil
        super.tearDown()
    }

    // MARK: - Mock AsrEngine Tests

    func testMockAsrEngine_Success() async throws {
        // Given: 配置 Mock 返回预设结果
        let expectedSegments = [
            AsrSegment.fixture(startTime: 0, endTime: 1, text: "Hello"),
            AsrSegment.fixture(startTime: 1, endTime: 2, text: "World"),
        ]
        await mockEngine.setSegments(expectedSegments)

        // When: 调用 transcribe 方法
        let testAudio = Data([0x00, 0x01, 0x02, 0x03])
        let result = try await mockEngine.transcribe(audioData: testAudio, options: .default)

        // Then: 验证结果和调用记录
        XCTAssertEqual(result.count, 2, "应返回 2 个字幕段")
        XCTAssertEqual(result[0].text, "Hello")
        XCTAssertEqual(result[1].text, "World")

        let called = await mockEngine.transcribeCalled
        XCTAssertTrue(called, "transcribe 方法应该被调用")

        let callCount = await mockEngine.transcribeCallCount
        XCTAssertEqual(callCount, 1, "transcribe 方法应该被调用 1 次")

        let lastAudio = await mockEngine.lastAudioData
        XCTAssertEqual(lastAudio, testAudio, "应记录最后一次的音频数据")
    }

    func testMockAsrEngine_Failure() async {
        // Given: 配置 Mock 抛出错误
        await mockEngine.setError(.modelLoadFailed)

        // When/Then: 验证抛出预期错误
        do {
            let testAudio = Data([0x00])
            _ = try await mockEngine.transcribe(audioData: testAudio, options: .default)
            XCTFail("应该抛出错误")
        } catch let error as AsrError {
            if case .modelLoadFailed = error {
                // 成功：抛出了预期的错误
            } else {
                XCTFail("错误类型不匹配: \(error)")
            }
        } catch {
            XCTFail("未知错误: \(error)")
        }
    }

    func testMockAsrEngine_Cancel() async throws {
        // Given: 配置延迟和取消行为
        await mockEngine.setTranscribeDelay(0.1)
        await mockEngine.setSegments([])

        // When: 启动识别并立即取消
        let task = Task {
            let testAudio = Data([0x00])
            return try await mockEngine.transcribe(audioData: testAudio, options: .default)
        }

        try await Task.sleep(nanoseconds: 10_000_000)  // 等待 10ms
        await mockEngine.cancel()

        // Then: 验证取消行为
        do {
            _ = try await task.value
            XCTFail("应该因取消而失败")
        } catch let error as AsrError {
            if case .cancelled = error {
                // 成功：抛出了取消错误
            } else {
                XCTFail("错误类型不匹配: \(error)")
            }
        }

        let cancelCalled = await mockEngine.cancelCalled
        XCTAssertTrue(cancelCalled, "cancel 方法应该被调用")
    }

    func testMockAsrEngine_MultipleCallsRecording() async throws {
        // Given: 配置不同的返回结果
        await mockEngine.setSegments([AsrSegment.fixture(text: "First")])

        // When: 多次调用
        _ = try await mockEngine.transcribe(audioData: Data([0x01]), options: .default)

        await mockEngine.setSegments([AsrSegment.fixture(text: "Second")])
        _ = try await mockEngine.transcribe(audioData: Data([0x02]), options: .default)

        // Then: 验证调用历史
        let callCount = await mockEngine.transcribeCallCount
        XCTAssertEqual(callCount, 2, "应记录 2 次调用")

        let firstCall = await mockEngine.getCall(at: 0)
        XCTAssertEqual(firstCall?.audioData, Data([0x01]))

        let secondCall = await mockEngine.getCall(at: 1)
        XCTAssertEqual(secondCall?.audioData, Data([0x02]))
    }

    // MARK: - Mock MetricsCollector Tests

    func testMockMetricsCollector_RecordTiming() async {
        // Given
        let metricName = "test.timing"
        let duration: TimeInterval = 1.5

        // When
        await mockCollector.recordTiming(metricName, duration: duration, metadata: nil)

        // Then
        let called = await mockCollector.recordTimingCalled
        XCTAssertTrue(called, "recordTiming 应该被调用")

        let lastName = await mockCollector.lastTimingName
        XCTAssertEqual(lastName, metricName)

        let lastDuration = await mockCollector.lastTimingDuration
        XCTAssertEqual(lastDuration, duration)

        let hasMetric = await mockCollector.hasMetric(name: metricName)
        XCTAssertTrue(hasMetric, "应记录指标")
    }

    func testMockMetricsCollector_RecordCount() async {
        // Given
        let metricName = "test.count"
        let value = 42

        // When
        await mockCollector.recordCount(metricName, value: value, metadata: nil)

        // Then
        let called = await mockCollector.recordCountCalled
        XCTAssertTrue(called)

        let lastName = await mockCollector.lastCountName
        XCTAssertEqual(lastName, metricName)

        let lastValue = await mockCollector.lastCountValue
        XCTAssertEqual(lastValue, value)
    }

    func testMockMetricsCollector_RecordDistribution() async {
        // Given
        let metricName = "test.distribution"
        let value: Double = 0.95
        let metadata = ["key": "value"]

        // When
        await mockCollector.recordDistribution(metricName, value: value, metadata: metadata)

        // Then
        let called = await mockCollector.recordDistributionCalled
        XCTAssertTrue(called)

        let lastName = await mockCollector.lastDistributionName
        XCTAssertEqual(lastName, metricName)

        let lastValue = await mockCollector.lastDistributionValue
        XCTAssertEqual(lastValue, value)

        let lastMetadata = await mockCollector.lastDistributionMetadata
        XCTAssertEqual(lastMetadata, metadata)
    }

    func testMockMetricsCollector_QueryMetrics() async {
        // Given: 记录多个指标
        await mockCollector.recordTiming("metric.a", duration: 1.0, metadata: nil)
        await mockCollector.recordTiming("metric.b", duration: 2.0, metadata: nil)
        await mockCollector.recordCount("metric.a", value: 1, metadata: nil)

        // When: 查询指定名称的指标
        let metricsA = await mockCollector.getMetrics(
            name: "metric.a", startDate: nil, endDate: nil)

        // Then: 验证查询结果
        XCTAssertEqual(metricsA.count, 2, "metric.a 应有 2 条记录")

        let allMetrics = await mockCollector.getAllMetrics()
        XCTAssertEqual(allMetrics.count, 3, "总共应有 3 条指标")

        let metricCount = await mockCollector.getMetricCount(name: "metric.a")
        XCTAssertEqual(metricCount, 2)
    }

    func testMockMetricsCollector_GetStatistics() async {
        // Given: 记录多个相同名称的指标
        let metricName = "test.metric"
        await mockCollector.recordDistribution(metricName, value: 1.0, metadata: nil)
        await mockCollector.recordDistribution(metricName, value: 2.0, metadata: nil)
        await mockCollector.recordDistribution(metricName, value: 3.0, metadata: nil)

        // When: 获取统计信息
        let stats = await mockCollector.getStatistics(for: metricName)

        // Then: 验证统计结果
        XCTAssertNotNil(stats, "应返回统计信息")
        XCTAssertEqual(stats?.count, 3)
        XCTAssertEqual(stats?.min, 1.0)
        XCTAssertEqual(stats?.max, 3.0)
        XCTAssertEqual(stats?.mean, 2.0, accuracy: 0.01)
    }

    // MARK: - Integration Example

    func testIntegration_AsrWithMetrics() async throws {
        // Given: 配置 ASR 引擎和指标采集器
        let segment = AsrSegment.fixture(text: "Integration test")
        await mockEngine.setSegments([segment])

        // When: 执行识别并记录指标
        let startTime = Date()
        let audioData = Data([0x00, 0x01])
        let result = try await mockEngine.transcribe(audioData: audioData, options: .default)
        let duration = Date().timeIntervalSince(startTime)

        await mockCollector.recordTiming("asr.transcribe", duration: duration, metadata: nil)

        // Then: 验证结果和指标
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.text, "Integration test")

        let timingCalled = await mockCollector.recordTimingCalled
        XCTAssertTrue(timingCalled, "应记录识别耗时")

        let metricName = await mockCollector.lastTimingName
        XCTAssertEqual(metricName, "asr.transcribe")
    }
}

// MARK: - Test Helpers

extension AsrSegment {
    /// 创建测试用的 AsrSegment
    static func fixture(
        id: UUID = UUID(),
        mediaId: String = "test-media",
        startTime: TimeInterval = 0,
        endTime: TimeInterval = 1,
        text: String = "Test",
        confidence: Double? = 0.95
    ) -> AsrSegment {
        AsrSegment(
            id: id,
            mediaId: mediaId,
            startTime: startTime,
            endTime: endTime,
            text: text,
            confidence: confidence,
            createdAt: Int64(Date().timeIntervalSince1970)
        )
    }
}
