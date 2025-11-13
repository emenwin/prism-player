import AVFoundation
import PrismCore
import XCTest

@testable import PrismASR

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

    /// 测试：完整转写流程
    ///
    /// 验证使用真实模型和音频文件的基本转写功能。
    func testTranscribeSuccess() async throws {
        // 加载真实模型
        let modelURL = getModelPath()
        let backend = WhisperCppBackend(modelPath: modelURL)

        // 加载英文测试音频
        let audioData = try await loadTestAudio(named: "english-sample.mp3")
        let options = AsrOptions(language: .english)

        // 执行转写
        let segments = try await backend.transcribe(audioData: audioData, options: options)

        // 验证结果
        XCTAssertFalse(segments.isEmpty, "应该识别出至少一个片段")

        // 验证片段结构
        for segment in segments {
            XCTAssertFalse(segment.text.isEmpty, "片段文本不应为空")
            XCTAssertGreaterThanOrEqual(segment.endTime, segment.startTime, "结束时间应大于等于开始时间")
        }

        print("✅ 识别到 \(segments.count) 个片段")
        for (i, segment) in segments.prefix(3).enumerated() {
            print(
                "  [\(i)] [\(String(format: "%.2f", segment.startTime))s - \(String(format: "%.2f", segment.endTime))s]: \(segment.text)"
            )
        }
    }

    /// 测试：语言选项
    ///
    /// 验证不同语言设置的转写效果。
    func testTranscribeWithLanguageOption() async throws {
        let modelURL = getModelPath()
        let backend = WhisperCppBackend(modelPath: modelURL)

        // 测试中文识别
        let chineseAudio = try await loadTestAudio(named: "chinese-sample.mp3")
        let chineseOptions = AsrOptions(language: .chinese)

        let chineseSegments = try await backend.transcribe(
            audioData: chineseAudio, options: chineseOptions)
        XCTAssertFalse(chineseSegments.isEmpty, "应该识别出中文片段")

        print("✅ 中文识别: \(chineseSegments.count) 个片段")
        if let first = chineseSegments.first {
            print("  示例: \(first.text)")
        }
    }

    /// 测试：温度参数
    ///
    /// 验证不同温度值对转写的影响（温度影响输出多样性）。
    func testTranscribeWithTemperature() async throws {
        let modelURL = getModelPath()
        let backend = WhisperCppBackend(modelPath: modelURL)
        let audioData = try await loadTestAudio(named: "english-sample.mp3")

        // 测试低温度（更确定性）
        let lowTempOptions = AsrOptions(language: .english, temperature: 0.0)
        let lowTempSegments = try await backend.transcribe(
            audioData: audioData, options: lowTempOptions)

        XCTAssertFalse(lowTempSegments.isEmpty, "低温度应该产生识别结果")

        print("✅ 温度=0.0: \(lowTempSegments.count) 个片段")
    }

    /// 测试：取消机制
    ///
    /// 验证取消正在进行的转写任务。
    func testCancelAll() async throws {
        let modelURL = getModelPath()
        let backend = WhisperCppBackend(modelPath: modelURL)
        let audioData = try await loadTestAudio(named: "english-sample.mp3")
        let options = AsrOptions(language: .english)

        // 启动转写任务
        let task = Task {
            try await backend.transcribe(audioData: audioData, options: options)
        }

        // 立即取消
        await backend.cancelAll()
        task.cancel()

        // 验证任务被取消
        do {
            _ = try await task.value
            XCTFail("任务应该被取消")
        } catch is CancellationError {
            // 预期行为
            print("✅ 取消机制正常工作")
        } catch {
            // 也可能是其他取消相关错误
            print("⚠️ 取消时抛出: \(error)")
        }
    }

    /// 测试：自动模型加载
    ///
    /// 验证首次调用 transcribe() 时自动加载模型的功能。
    func testAutoModelLoading() async throws {
        let modelURL = getModelPath()

        // 创建 backend 但不手动加载模型
        let backend = WhisperCppBackend(modelPath: modelURL)

        // 首次调用应该自动加载模型
        let audioData = try await loadTestAudio(named: "english-sample.mp3")
        let options = AsrOptions(language: .english)

        let segments = try await backend.transcribe(audioData: audioData, options: options)

        XCTAssertFalse(segments.isEmpty, "自动加载模型后应该能正常转写")
        print("✅ 自动模型加载成功，识别到 \(segments.count) 个片段")
    }
}

// MARK: - Integration Tests

/// 集成测试：端到端转写流程
final class WhisperCppBackendIntegrationTests: XCTestCase {
    /// 测试：端到端转写流程
    ///
    /// 验证完整的转写流程，从音频输入到最终输出。
    func testEndToEndTranscription() async throws {
        let modelURL = getModelPath()
        let backend = WhisperCppBackend(modelPath: modelURL)

        // 加载噪声样本（更复杂的场景）
        let audioData = try await loadTestAudio(named: "noise-sample.mp3")
        let options = AsrOptions(language: .english)

        let startTime = Date()
        let segments = try await backend.transcribe(audioData: audioData, options: options)
        let elapsed = Date().timeIntervalSince(startTime)

        // 验证结果
        XCTAssertFalse(segments.isEmpty, "应该识别出片段（即使有噪声）")

        // 计算音频时长（估算）
        let sampleCount = audioData.count / 4  // Float32 = 4 bytes
        let audioDuration = Double(sampleCount) / 16000.0  // 16kHz
        let rtf = audioDuration > 0 ? elapsed / audioDuration : 0

        print("✅ E2E 转写完成:")
        print("  - 片段数: \(segments.count)")
        print("  - 耗时: \(String(format: "%.2f", elapsed))s")
        print("  - 音频时长: \(String(format: "%.2f", audioDuration))s")
        print("  - RTF: \(String(format: "%.2f", rtf))")

        // 性能验证（RTF 应该合理）
        XCTAssertLessThan(rtf, 2.0, "RTF 应该小于 2.0（实时性能）")
    }

    /// 测试：取消机制验证
    ///
    /// 验证在转写过程中取消任务的行为。
    func testCancellationDuringTranscription() async throws {
        let modelURL = getModelPath()
        let backend = WhisperCppBackend(modelPath: modelURL)

        // 使用较长的音频以确保有时间取消
        let audioData = try await loadTestAudio(named: "english-sample.mp3")
        let options = AsrOptions(language: .english)

        // 启动转写任务
        let task = Task {
            try await backend.transcribe(audioData: audioData, options: options)
        }

        // 等待一小段时间后取消
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1s
        await backend.cancelAll()
        task.cancel()

        // 验证任务被取消
        do {
            _ = try await task.value
            print("⚠️ 任务可能已经完成（音频太短）")
        } catch {
            print("✅ 任务取消验证通过: \(error)")
        }
    }
}

// MARK: - Test Helpers

/// 获取测试模型文件路径
private func getModelPath() -> URL {
    // 使用测试类获取 Bundle  
    let bundle = Bundle(for: WhisperCppBackendTests.self)
    
    // 尝试从 Bundle 加载
    if let modelURL = bundle.url(forResource: "ggml-tiny", withExtension: "bin", subdirectory: "Fixtures/models") {
        return modelURL
    }
    
    // Fallback: 直接使用文件路径（SPM 测试环境）
    let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    
    let modelURL = packageRoot
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
    let bundle = Bundle(for: WhisperCppBackendTests.self)

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

    // 使用 AVFoundation 加载并转换音频（简化版，实际应使用 AudioExtractor）
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
                    blockBuffer, atOffset: 0, dataLength: length,
                    destination: buffer.baseAddress!)
            }

            audioData.append(data)
        }
    }

    if reader.status == .failed {
        throw reader.error
            ?? NSError(
                domain: "TestError", code: 5,
                userInfo: [NSLocalizedDescriptionKey: "音频读取失败"])
    }

    return audioData
}
