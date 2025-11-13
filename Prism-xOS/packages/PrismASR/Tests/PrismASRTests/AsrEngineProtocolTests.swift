import PrismCore
import XCTest

@testable import PrismASR

/// AsrEngine 协议契约测试
///
/// 使用 Mock 实现验证 AsrEngine 协议的契约要求。
/// 确保所有后端实现都遵循统一的行为规范。
final class AsrEngineProtocolTests: XCTestCase {
    // MARK: - Protocol Contract Tests    /// 测试：transcribe 方法应返回 AsrSegment 数组
    func testTranscribeShouldReturnSegments() async throws {
        // Given
        let mockEngine = MockAsrEngine()
        let audioData = Data(count: 16_000 * 4)  // 1s of Float32 audio
        let options = AsrOptions(language: .english)

        // When
        let segments = try await mockEngine.transcribe(audioData: audioData, options: options)

        // Then
        XCTAssertFalse(segments.isEmpty, "Should return at least one segment")
        XCTAssertEqual(segments.count, 1, "Mock should return 1 segment")
        XCTAssertEqual(segments.first?.text, "Mock transcription", "Should return mock text")
    }

    /// 测试：空音频应抛出 invalidAudioFormat 错误
    func testTranscribeWithEmptyAudioShouldThrowError() async throws {
        // Given
        let mockEngine = MockAsrEngine()
        let emptyData = Data()
        let options = AsrOptions(language: .english)

        // When/Then
        do {
            _ = try await mockEngine.transcribe(audioData: emptyData, options: options)
            XCTFail("Should throw invalidAudioFormat error")
        } catch AsrError.invalidAudioFormat {
            // Expected
        } catch {
            XCTFail("Should throw AsrError.invalidAudioFormat, got \(error)")
        }
    }

    /// 测试：取消机制应正常工作
    func testCancelAllShouldCancelInFlightTasks() async throws {
        // Given
        let mockEngine = MockAsrEngine()
        let audioData = Data(count: 16_000 * 4 * 30)  // 30s audio
        let options = AsrOptions(language: .english)

        // When: 启动转写任务
        let transcribeTask = Task {
            try await mockEngine.transcribe(audioData: audioData, options: options)
        }

        // 等待一小段时间确保任务开始
        try await Task.sleep(nanoseconds: 100_000_000)  // 100ms

        // 取消所有任务
        await mockEngine.cancelAll()

        // Then: 任务应被取消
        do {
            _ = try await transcribeTask.value
            XCTFail("Task should be cancelled")
        } catch AsrError.cancelled {
            // Expected
        } catch {
            XCTFail("Should throw AsrError.cancelled, got \(error)")
        }
    }

    /// 测试：支持的语言应被正确处理
    func testTranscribeWithDifferentLanguages() async throws {
        // Given
        let mockEngine = MockAsrEngine()
        let audioData = Data(count: 16_000 * 4)

        let languages: [AsrLanguage] = [.english, .chinese, .auto]

        // When/Then
        for language in languages {
            let options = AsrOptions(language: language)
            let segments = try await mockEngine.transcribe(audioData: audioData, options: options)

            XCTAssertFalse(segments.isEmpty, "Should support \(language.displayName)")
        }
    }

    /// 测试：AsrOptions 默认值应正确
    func testAsrOptionsDefaults() {
        // When: 使用默认值初始化
        let options = AsrOptions()

        // Then
        XCTAssertNil(options.language, "Language should default to nil (auto-detect)")
        XCTAssertNil(options.modelPath, "ModelPath should default to nil")
        XCTAssertEqual(options.temperature, 0.0, "Temperature should default to 0.0")
        XCTAssertTrue(options.enableTimestamps, "Timestamps should be enabled by default")
        XCTAssertNil(options.prompt, "Prompt should default to nil")
    }

    /// 测试：AsrOptions 温度值应被限制在 [0.0, 1.0]
    func testAsrOptionsTemperatureClamping() {
        // When: 使用超出范围的温度值
        let tooLow = AsrOptions(temperature: -0.5)
        let tooHigh = AsrOptions(temperature: 1.5)
        let valid = AsrOptions(temperature: 0.5)

        // Then
        XCTAssertEqual(tooLow.temperature, 0.0, "Temperature should be clamped to 0.0")
        XCTAssertEqual(tooHigh.temperature, 1.0, "Temperature should be clamped to 1.0")
        XCTAssertEqual(valid.temperature, 0.5, "Valid temperature should be unchanged")
    }
}

// MARK: - Mock Implementation

/// Mock AsrEngine 实现
///
/// 用于测试 AsrEngine 协议契约。模拟真实引擎的行为。
private actor MockAsrEngine: AsrEngine {
    private var isCancelled = false

    func transcribe(audioData: Data, options: AsrOptions) async throws -> [PrismASR.AsrSegment] {
        // 验证音频格式
        guard !audioData.isEmpty else {
            throw AsrError.invalidAudioFormat
        }

        // 模拟处理时间
        try await Task.sleep(nanoseconds: 200_000_000)  // 200ms

        // 检查是否被取消
        if isCancelled {
            throw AsrError.cancelled
        }

        // 返回 mock 数据（使用 PrismASR.AsrSegment）
        return [
            PrismASR.AsrSegment(
                startTime: 0.0,
                endTime: 1.0,
                text: "Mock transcription"
            )
        ]
    }

    func cancelAll() async {
        isCancelled = true
    }
}
