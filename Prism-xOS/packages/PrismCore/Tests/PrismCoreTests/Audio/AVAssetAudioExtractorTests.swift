import AVFoundation
import XCTest

@testable import PrismCore

/// AVAssetAudioExtractor 单元测试
///
/// 测试范围：
/// - 正常流程：音频抽取与格式验证
/// - 边界条件：超出时长、零时长
/// - 异常处理：无音频轨道、不可读资源
/// - 取消操作：Task cancellation
///
/// 测试策略：
/// - 使用程序化生成的音频资源（AVMutableComposition）
/// - 避免依赖外部音频文件
final class AVAssetAudioExtractorTests: XCTestCase {

    var extractor: AVAssetAudioExtractor!

    override func setUp() async throws {
        try await super.setUp()
        extractor = AVAssetAudioExtractor()
    }

    override func tearDown() async throws {
        extractor = nil
        try await super.tearDown()
    }

    // MARK: - 正常流程测试

    func testExtractValidTimeRange() async throws {
        // Given: 创建 10s 测试音频资源
        let asset = try createTestAudioAsset(duration: 10.0)
        let timeRange = CMTimeRange(
            start: .zero,
            duration: CMTime(seconds: 5, preferredTimescale: 600)
        )

        // When: 抽取前 5s
        let buffer = try await extractor.extract(from: asset, timeRange: timeRange)

        // Then: 验证输出格式
        XCTAssertEqual(buffer.sampleRate, 16000, "采样率应为 16kHz")
        XCTAssertEqual(buffer.channels, 1, "应为 Mono 单声道")

        // 验证样本数量（允许 ±5% 误差，因为编解码器可能有帧对齐）
        let expectedSamples = 16000 * 5  // 5s × 16kHz
        let tolerance = Int(Double(expectedSamples) * 0.05)
        XCTAssertEqual(
            buffer.samples.count,
            expectedSamples,
            accuracy: tolerance,
            "样本数量应约等于 80,000（5s × 16kHz）"
        )

        XCTAssertEqual(buffer.timeRange.start.seconds, 0, accuracy: 0.01)
        XCTAssertEqual(buffer.timeRange.duration.seconds, 5, accuracy: 0.01)

        // 验证样本值范围（Float32 应在 [-1.0, 1.0]）
        XCTAssertTrue(buffer.samples.allSatisfy { $0 >= -1.0 && $0 <= 1.0 })
    }

    func testExtractMiddleTimeRange() async throws {
        // Given: 创建 30s 测试音频资源
        let asset = try createTestAudioAsset(duration: 30.0)
        let timeRange = CMTimeRange(
            start: CMTime(seconds: 10, preferredTimescale: 600),
            duration: CMTime(seconds: 5, preferredTimescale: 600)
        )

        // When: 抽取中间 5s（10s–15s）
        let buffer = try await extractor.extract(from: asset, timeRange: timeRange)

        // Then
        XCTAssertEqual(buffer.sampleRate, 16000)
        XCTAssertEqual(buffer.channels, 1)
        XCTAssertEqual(buffer.timeRange.start.seconds, 10, accuracy: 0.01)
        XCTAssertEqual(buffer.timeRange.duration.seconds, 5, accuracy: 0.01)
    }

    // MARK: - 边界条件测试

    func testExtractZeroDuration() async throws {
        // Given
        let asset = try createTestAudioAsset(duration: 10.0)
        let timeRange = CMTimeRange(
            start: .zero,
            duration: .zero
        )

        // When
        let buffer = try await extractor.extract(from: asset, timeRange: timeRange)

        // Then: 应返回空缓冲区
        XCTAssertTrue(buffer.samples.isEmpty || buffer.samples.count < 100)  // 允许少量帧
    }

    func testExtractTimeRangeBeyondDuration() async throws {
        // Given: 10s 音频
        let asset = try createTestAudioAsset(duration: 10.0)
        let invalidRange = CMTimeRange(
            start: CMTime(seconds: 15, preferredTimescale: 600),  // 超出时长
            duration: CMTime(seconds: 5, preferredTimescale: 600)
        )

        // When/Then: 应抛出 timeRangeInvalid 错误
        do {
            _ = try await extractor.extract(from: asset, timeRange: invalidRange)
            XCTFail("应抛出 timeRangeInvalid 错误")
        } catch AudioExtractionError.timeRangeInvalid {
            // Expected
        } catch {
            XCTFail("错误类型不正确: \(error)")
        }
    }

    func testExtractTimeRangeExceedingDuration() async throws {
        // Given: 10s 音频
        let asset = try createTestAudioAsset(duration: 10.0)
        let invalidRange = CMTimeRange(
            start: CMTime(seconds: 8, preferredTimescale: 600),
            duration: CMTime(seconds: 5, preferredTimescale: 600)  // 8 + 5 = 13s > 10s
        )

        // When/Then
        do {
            _ = try await extractor.extract(from: asset, timeRange: invalidRange)
            XCTFail("应抛出 timeRangeInvalid 错误")
        } catch AudioExtractionError.timeRangeInvalid {
            // Expected
        } catch {
            XCTFail("错误类型不正确: \(error)")
        }
    }

    // MARK: - 异常处理测试

    func testExtractFromVideoOnlyAsset() async throws {
        // Given: 创建纯视频资源（无音频轨道）
        let composition = AVMutableComposition()
        _ = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
        let asset = composition as AVAsset

        // When/Then
        do {
            _ = try await extractor.extract(
                from: asset,
                timeRange: CMTimeRange(
                    start: .zero, duration: CMTime(seconds: 1, preferredTimescale: 600))
            )
            XCTFail("应抛出 noAudioTrack 错误")
        } catch AudioExtractionError.noAudioTrack {
            // Expected
        } catch {
            XCTFail("错误类型不正确: \(error)")
        }
    }

    // MARK: - 取消操作测试

    func testExtractCancellation() async throws {
        // Given: 创建较长的音频资源
        let asset = try createTestAudioAsset(duration: 60.0)
        let timeRange = CMTimeRange(
            start: .zero,
            duration: CMTime(seconds: 60, preferredTimescale: 600)
        )

        // When: 启动抽取任务并立即取消
        let task = Task {
            try await extractor.extract(from: asset, timeRange: timeRange)
        }

        // 等待任务启动后取消
        try await Task.sleep(nanoseconds: 50_000_000)  // 50ms
        task.cancel()

        // Then: 应抛出取消相关错误
        do {
            _ = try await task.value
            XCTFail("应抛出取消错误")
        } catch is CancellationError {
            // Expected
        } catch AudioExtractionError.cancelled {
            // Also acceptable
        } catch {
            XCTFail("错误类型不正确: \(error)")
        }
    }

    // MARK: - 并发测试

    func testConcurrentExtraction() async throws {
        // Given: 创建测试音频资源
        let asset = try createTestAudioAsset(duration: 30.0)

        // When: 并发抽取 3 个不同时间段
        let results = try await withThrowingTaskGroup(of: PrismCore.AudioBuffer.self) { group in
            // 段 1: 0-10s
            group.addTask {
                try await self.extractor.extract(
                    from: asset,
                    timeRange: CMTimeRange(
                        start: .zero, duration: CMTime(seconds: 10, preferredTimescale: 600))
                )
            }

            // 段 2: 10-20s
            group.addTask {
                try await self.extractor.extract(
                    from: asset,
                    timeRange: CMTimeRange(
                        start: CMTime(seconds: 10, preferredTimescale: 600),
                        duration: CMTime(seconds: 10, preferredTimescale: 600)
                    )
                )
            }

            // 段 3: 20-30s
            group.addTask {
                try await self.extractor.extract(
                    from: asset,
                    timeRange: CMTimeRange(
                        start: CMTime(seconds: 20, preferredTimescale: 600),
                        duration: CMTime(seconds: 10, preferredTimescale: 600)
                    )
                )
            }

            var buffers: [PrismCore.AudioBuffer] = []
            for try await buffer in group {
                buffers.append(buffer)
            }
            return buffers
        }

        // Then: 所有段都应成功抽取
        XCTAssertEqual(results.count, 3)
        results.forEach { buffer in
            XCTAssertEqual(buffer.sampleRate, 16000)
            XCTAssertEqual(buffer.channels, 1)
        }
    }

    // MARK: - Helper Methods

    /// 创建测试音频资源
    ///
    /// 使用 AVMutableComposition 生成程序化音频
    /// - Parameter duration: 音频时长（秒）
    /// - Returns: AVAsset
    private func createTestAudioAsset(duration: TimeInterval) throws -> AVAsset {
        let composition = AVMutableComposition()

        // 添加音频轨道
        guard
            let audioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
        else {
            throw NSError(
                domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法创建音频轨道"])
        }

        // 设置时长
        let timeRange = CMTimeRange(
            start: .zero,
            duration: CMTime(seconds: duration, preferredTimescale: 600)
        )

        // 插入静音段（AVMutableComposition 会自动填充）
        try audioTrack.insertTimeRange(
            timeRange,
            of: audioTrack,
            at: .zero
        )

        return composition as AVAsset
    }
}
