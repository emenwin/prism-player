import XCTest

@testable import PrismASR
import PrismCore

/// WhisperCppBackend 单元测试
///
/// 测试 WhisperCppBackend 的核心功能，包括转写、取消、错误处理等。
///
/// ## 测试覆盖
/// - 音频格式验证
/// - 错误处理（空数据、音频过短、模型未加载）
/// - 取消机制
/// - 自动模型加载（需要真实模型，PR4）
///
/// ## 注意事项
/// - PR3 使用 Mock 音频进行基础验证
/// - PR4 添加真实模型文件后进行完整测试
final class WhisperCppBackendTests: XCTestCase {
    var backend: WhisperCppBackend!

    override func setUp() async throws {
        backend = WhisperCppBackend()
    }

    override func tearDown() async throws {
        backend = nil
    }

    // MARK: - Error Handling Tests

    /// 测试：空音频数据应抛出 invalidAudioFormat 错误
    func testTranscribeWithEmptyAudioShouldThrow() async {
        let emptyData = Data()
        let options = AsrOptions(language: .english)

        do {
            _ = try await backend.transcribe(audioData: emptyData, options: options)
            XCTFail("应该抛出 invalidAudioFormat 错误")
        } catch AsrError.invalidAudioFormat {
            // 预期行为
        } catch {
            XCTFail("错误类型不匹配: \(error)")
        }
    }

    /// 测试：音频过短应抛出 invalidAudioFormat 错误
    func testTranscribeWithTooShortAudioShouldThrow() async {
        // 创建 50ms 音频（< 100ms 最小长度）
        let shortAudio = generateMockAudio(duration: 0.05)  // 50ms
        let options = AsrOptions(language: .english)

        do {
            _ = try await backend.transcribe(audioData: shortAudio, options: options)
            XCTFail("应该抛出 invalidAudioFormat 错误")
        } catch AsrError.invalidAudioFormat {
            // 预期行为
        } catch {
            XCTFail("错误类型不匹配: \(error)")
        }
    }

    /// 测试：未加载模型应抛出 modelNotLoaded 错误
    func testTranscribeWithoutModelShouldThrow() async {
        let audioData = generateMockAudio(duration: 1.0)
        let options = AsrOptions(language: .english)

        do {
            _ = try await backend.transcribe(audioData: audioData, options: options)
            XCTFail("应该抛出 modelNotLoaded 错误")
        } catch AsrError.modelNotLoaded {
            // 预期行为
        } catch {
            XCTFail("错误类型不匹配: \(error)")
        }
    }

    // MARK: - Real Model Tests (PR4)

    /// 测试：完整转写流程（PR4 启用）
    ///
    /// 需要真实模型文件和音频样本。
    func testTranscribeSuccess() async throws {
        // PR4: 添加真实模型文件后启用
        throw XCTSkip("PR4: 需要真实模型文件")
    }

    /// 测试：语言选项（PR4 启用）
    func testTranscribeWithLanguageOption() async throws {
        // PR4: 添加真实模型文件后启用
        throw XCTSkip("PR4: 需要真实模型文件")
    }

    /// 测试：温度参数（PR4 启用）
    func testTranscribeWithTemperature() async throws {
        // PR4: 添加真实模型文件后启用
        throw XCTSkip("PR4: 需要真实模型文件")
    }

    /// 测试：取消机制（PR4 启用）
    func testCancelAll() async throws {
        // PR4: 添加真实模型文件后启用
        throw XCTSkip("PR4: 需要真实模型文件")
    }

    /// 测试：自动模型加载（PR4 启用）
    func testAutoModelLoading() async throws {
        // PR4: 添加真实模型文件后启用
        throw XCTSkip("PR4: 需要真实模型文件")
    }
}

// MARK: - Integration Tests

/// 集成测试：端到端转写流程
final class WhisperCppBackendIntegrationTests: XCTestCase {
    /// 测试：端到端转写流程（PR4 启用）
    ///
    /// 验证完整的转写流程，从音频输入到最终输出。
    func testEndToEndTranscription() async throws {
        // PR4: 添加真实模型文件后启用
        throw XCTSkip("PR4: 需要真实模型文件和音频样本")
    }

    /// 测试：取消机制验证（PR4 启用）
    ///
    /// 验证在转写过程中取消任务的行为。
    func testCancellationDuringTranscription() async throws {
        // PR4: 添加真实模型文件后启用
        throw XCTSkip("PR4: 需要真实模型文件和长音频样本")
    }
}
