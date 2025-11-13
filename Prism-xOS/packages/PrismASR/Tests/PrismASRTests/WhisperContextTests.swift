import AVFoundation
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

    /// 测试：加载真实模型成功
    ///
    /// 需要模型文件：Tests/Fixtures/models/ggml-tiny.bin
    func testLoadModelSuccess() async throws {
        let modelURL = getModelPath()

        // 加载模型
        try await context.loadModel(at: modelURL)

        // 验证：不应抛出异常
        print("✅ 模型加载成功: \(modelURL.lastPathComponent)")
    }

    /// 测试：多次加载模型应自动释放旧模型
    func testLoadMultipleModelsShouldReleaseOldOne() async throws {
        let modelURL = getModelPath()

        // 加载第一个模型
        try await context.loadModel(at: modelURL)
        print("✅ 第一次加载成功")

        // 加载第二个模型（应自动释放第一个）
        try await context.loadModel(at: modelURL)
        print("✅ 第二次加载成功（旧模型已自动释放）")

        // 验证：不应有内存泄漏（需 Instruments 验证）
    }

    // MARK: - Transcription Tests

    /// 测试：基础转写流程
    ///
    /// 使用真实模型和音频进行完整转写测试。
    func testBasicTranscription() async throws {
        let modelURL = getModelPath()
        try await context.loadModel(at: modelURL)

        // 加载测试音频
        let audioData = try await loadTestAudio(named: "english-sample.mp3")
        let options = AsrOptions(language: .english)

        // 执行转写
        let segments = try await context.transcribe(audioData: audioData, options: options)

        // 验证结果
        XCTAssertFalse(segments.isEmpty, "应该识别出片段")

        print("✅ 基础转写测试通过: \(segments.count) 个片段")
        for (i, segment) in segments.prefix(2).enumerated() {
            print("  [\(i)] \(segment.text)")
        }
    }
}

// MARK: - Test Helpers

/// 生成 Mock 音频数据（正弦波）
///
/// - Parameters:
///   - duration: 音频时长（秒）
///   - frequency: 正弦波频率（Hz），默认 440Hz（A4 音符）
///   - sampleRate: 采样率，默认 16000Hz
/// - Returns: PCM Float32 Data（16kHz mono）
func generateMockAudio(
    duration: TimeInterval,
    frequency: Double = 440.0,
    sampleRate: Int = 16000
) -> Data {
    let sampleCount = Int(duration * Double(sampleRate))
    var samples: [Float] = []

    for i in 0..<sampleCount {
        let t = Double(i) / Double(sampleRate)
        let sample = sin(2.0 * .pi * frequency * t)
        samples.append(Float(sample * 0.5))  // 振幅 0.5
    }

    return AudioConverter.floatArrayToData(samples)
}

/// 获取测试模型文件路径
private func getModelPath() -> URL {
    // 使用测试类获取 Bundle
    let bundle = Bundle(for: WhisperContextTests.self)

    // 尝试多个可能的资源路径
    if let modelURL = bundle.url(
        forResource: "ggml-tiny", withExtension: "bin", subdirectory: "Fixtures/models")
    {
        return modelURL
    }

    // Fallback: 直接使用文件路径（SPM 测试环境）
    let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // WhisperContextTests.swift
        .deletingLastPathComponent()  // PrismASRTests/
        .deletingLastPathComponent()  // Tests/

    let modelURL =
        packageRoot
        .appendingPathComponent("Tests")
        .appendingPathComponent("Fixtures")
        .appendingPathComponent("models")
        .appendingPathComponent("ggml-tiny.bin")

    guard FileManager.default.fileExists(atPath: modelURL.path) else {
        fatalError("找不到测试模型文件: \(modelURL.path)")
    }

    return modelURL
}

/// 加载测试音频文件
/// - Parameter named: 音频文件名（含扩展名）
/// - Returns: PCM Float32 音频数据（16kHz mono）
private func loadTestAudio(named filename: String) async throws -> Data {
    // 使用测试类获取 Bundle
    let bundle = Bundle(for: WhisperContextTests.self)

    // 获取文件名和扩展名
    let components = filename.split(separator: ".")
    guard components.count == 2 else {
        throw NSError(
            domain: "TestError", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "无效的文件名格式: \(filename)"])
    }

    let name = String(components[0])
    let ext = String(components[1])

    // 尝试从 Bundle 加载
    if let audioURL = bundle.url(forResource: name, withExtension: ext, subdirectory: "Fixtures/audio") {
        return try await loadAudioUsingAVFoundation(from: audioURL)
    }

    // Fallback: 使用文件路径
    let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    let audioURL =
        packageRoot
        .appendingPathComponent("Tests")
        .appendingPathComponent("Fixtures")
        .appendingPathComponent("audio")
        .appendingPathComponent(filename)

    guard FileManager.default.fileExists(atPath: audioURL.path) else {
        throw NSError(
            domain: "TestError", code: 2,
            userInfo: [NSLocalizedDescriptionKey: "找不到测试音频文件: \(audioURL.path)"])
    }

    return try await loadAudioUsingAVFoundation(from: audioURL)
}
/// 使用 AVFoundation 加载音频文件并转换为 PCM Float32
private func loadAudioUsingAVFoundation(from url: URL) async throws -> Data {
    let asset = AVAsset(url: url)
    let reader = try AVAssetReader(asset: asset)

    let audioTracks = try await asset.loadTracks(withMediaType: .audio)
    guard let audioTrack = audioTracks.first else {
        throw NSError(
            domain: "TestError", code: 3, userInfo: [NSLocalizedDescriptionKey: "音频文件无音轨"])
    }

    // 配置输出格式：16kHz mono Float32 PCM
    let outputSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: 16_000,
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 32,
        AVLinearPCMIsFloatKey: true,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsNonInterleaved: false,
    ]

    let output = AVAssetReaderAudioMixOutput(
        audioTracks: [audioTrack], audioSettings: outputSettings)
    reader.add(output)

    guard reader.startReading() else {
        throw NSError(domain: "TestError", code: 4, userInfo: [NSLocalizedDescriptionKey: "音频读取失败"])
    }

    var audioData = Data()

    while reader.status == .reading {
        guard let sampleBuffer = output.copyNextSampleBuffer() else {
            break
        }

        if let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
            let length = CMBlockBufferGetDataLength(blockBuffer)
            var data = Data(count: length)

            _ = data.withUnsafeMutableBytes { buffer in
                CMBlockBufferCopyDataBytes(
                    blockBuffer, atOffset: 0, dataLength: length, destination: buffer.baseAddress!)
            }

            audioData.append(data)
        }
    }

    if reader.status == .failed {
        throw reader.error
            ?? NSError(
                domain: "TestError", code: 5, userInfo: [NSLocalizedDescriptionKey: "音频读取失败"])
    }

    return audioData
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
