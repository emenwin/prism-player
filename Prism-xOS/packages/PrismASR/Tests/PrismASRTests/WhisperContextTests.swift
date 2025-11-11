import XCTest

@testable import PrismASR

/// WhisperContext 单元测试
///
/// 测试 whisper.cpp 桥接层的模型加载、资源管理等核心功能。
///
/// ## 测试覆盖
/// - 模型加载成功场景
/// - 模型加载失败场景（文件不存在）
/// - 重复卸载模型（幂等性）
/// - 多次加载模型（自动释放旧模型）
///
/// ## 注意事项
/// - PR2 暂无实际模型文件，使用模拟测试
/// - PR4 将添加真实模型文件并进行金样本测试
final class WhisperContextTests: XCTestCase {
    var context: WhisperContext!

    override func setUp() async throws {
        context = WhisperContext()
    }

    override func tearDown() async throws {
        await context.unloadModel()
        context = nil
    }

    // MARK: - Model Loading Tests

    /// 测试：加载不存在的模型应该抛出错误
    func testLoadNonExistentModelShouldThrow() async {
        let invalidURL = URL(fileURLWithPath: "/tmp/nonexistent-model.bin")

        do {
            try await context.loadModel(at: invalidURL)
            XCTFail("应该抛出 modelLoadFailed 错误")
        } catch AsrError.modelLoadFailed(let url) {
            XCTAssertEqual(url.path, invalidURL.path)
        } catch {
            XCTFail("错误类型不匹配: \(error)")
        }
    }

    /// 测试：重复卸载模型不应崩溃（幂等性）
    func testUnloadModelShouldBeIdempotent() async {
        // 重复卸载不应崩溃
        await context.unloadModel()
        await context.unloadModel()
        await context.unloadModel()

        // 验证：无异常抛出，测试通过
    }

    /// 测试：未加载模型时转写应该抛出错误
    func testTranscribeWithoutModelShouldThrow() async {
        let audioData = Data(repeating: 0, count: 1600)  // 0.1s 音频
        let options = AsrOptions()

        do {
            _ = try await context.transcribe(audioData: audioData, options: options)
            XCTFail("应该抛出 modelNotLoaded 错误")
        } catch AsrError.modelNotLoaded {
            // 预期行为
        } catch {
            XCTFail("错误类型不匹配: \(error)")
        }
    }

    // MARK: - Real Model Tests (PR4)

    // 注意：以下测试需要真实模型文件，PR2 暂不执行

    /// 测试：加载真实模型成功（PR4 启用）
    ///
    /// 需要模型文件：Tests/Fixtures/models/ggml-tiny.bin
    func testLoadModelSuccess() async throws {
        // PR4: 添加真实模型文件后启用
        // let modelURL = Bundle.module.url(
        //     forResource: "ggml-tiny",
        //     withExtension: "bin",
        //     subdirectory: "Fixtures/models"
        // )!
        //
        // try await context.loadModel(at: modelURL)
        // // 验证：不应抛出异常

        throw XCTSkip("PR4: 需要真实模型文件")
    }

    /// 测试：多次加载模型应自动释放旧模型（PR4 启用）
    func testLoadMultipleModelsShouldReleaseOldOne() async throws {
        // PR4: 添加真实模型文件后启用
        // let modelURL = Bundle.module.url(
        //     forResource: "ggml-tiny",
        //     withExtension: "bin",
        //     subdirectory: "Fixtures/models"
        // )!
        //
        // // 加载第一个模型
        // try await context.loadModel(at: modelURL)
        //
        // // 加载第二个模型（应自动释放第一个）
        // try await context.loadModel(at: modelURL)
        //
        // // 验证：不应有内存泄漏（需 Instruments 验证）

        throw XCTSkip("PR4: 需要真实模型文件")
    }

    // MARK: - Transcription Tests (PR3)

    /// 测试：基础转写流程（PR3 实现）
    func testBasicTranscription() async throws {
        // PR3: 实现转写功能后启用
        throw XCTSkip("PR3: 转写功能尚未实现")
    }
}

// MARK: - AudioConverter Tests

/// AudioConverter 工具类测试
final class AudioConverterTests: XCTestCase {
    /// 测试：Data → Float 数组转换
    func testDataToFloatArray() {
        let samples: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5]
        let data = AudioConverter.floatArrayToData(samples)

        let convertedSamples = AudioConverter.dataToFloatArray(data)

        XCTAssertEqual(convertedSamples.count, samples.count)
        for (original, converted) in zip(samples, convertedSamples) {
            XCTAssertEqual(original, converted, accuracy: 0.0001)
        }
    }

    /// 测试：Float 数组 → Data 转换
    func testFloatArrayToData() {
        let samples: [Float] = [1.0, -1.0, 0.0, 0.5, -0.5]
        let data = AudioConverter.floatArrayToData(samples)

        // 验证数据长度（Float = 4 bytes）
        XCTAssertEqual(data.count, samples.count * 4)

        // 验证往返转换
        let convertedSamples = AudioConverter.dataToFloatArray(data)
        XCTAssertEqual(convertedSamples, samples)
    }

    /// 测试：空数组转换
    func testEmptyArrayConversion() {
        let samples: [Float] = []
        let data = AudioConverter.floatArrayToData(samples)

        XCTAssertEqual(data.count, 0)

        let convertedSamples = AudioConverter.dataToFloatArray(data)
        XCTAssertEqual(convertedSamples.count, 0)
    }

    /// 测试：大数组转换性能
    func testLargeArrayConversionPerformance() {
        let samples = [Float](repeating: 0.5, count: 160_000)  // 10s @ 16kHz

        measure {
            let data = AudioConverter.floatArrayToData(samples)
            _ = AudioConverter.dataToFloatArray(data)
        }
    }
}
