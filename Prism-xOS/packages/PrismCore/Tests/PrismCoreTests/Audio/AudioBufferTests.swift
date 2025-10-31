import AVFoundation
import XCTest

@testable import PrismCore

/// AudioBuffer 单元测试
///
/// 测试范围：
/// - 基础属性验证
/// - 内存占用计算
/// - 时长计算
/// - CustomStringConvertible
final class AudioBufferTests: XCTestCase {

    // MARK: - 基础属性测试

    func testInitialization() {
        // Given: 10s 音频数据（16kHz mono）
        let samples = Array(repeating: Float(0.5), count: 160000)  // 16000 samples/s × 10s
        let timeRange = CMTimeRange(
            start: .zero,
            duration: CMTime(seconds: 10, preferredTimescale: 600)
        )

        // When
        let buffer = AudioBuffer(
            samples: samples,
            sampleRate: 16000,
            channels: 1,
            timeRange: timeRange
        )

        // Then
        XCTAssertEqual(buffer.samples.count, 160000)
        XCTAssertEqual(buffer.sampleRate, 16000)
        XCTAssertEqual(buffer.channels, 1)
        XCTAssertEqual(buffer.timeRange.start, .zero)
        XCTAssertEqual(buffer.timeRange.duration.seconds, 10, accuracy: 0.01)
    }

    // MARK: - 内存计算测试

    func testSizeInBytes() {
        // Given: 1s 音频数据（16kHz mono Float32）
        let samples = Array(repeating: Float(0.0), count: 16000)
        let timeRange = CMTimeRange(
            start: .zero,
            duration: CMTime(seconds: 1, preferredTimescale: 600)
        )
        let buffer = AudioBuffer(samples: samples, timeRange: timeRange)

        // When
        let size = buffer.sizeInBytes

        // Then: 16000 samples × 4 bytes = 64 KB
        XCTAssertEqual(size, 64000)
    }

    func testSizeInBytesFor30Seconds() {
        // Given: 30s 音频数据
        let samples = Array(repeating: Float(0.0), count: 480000)  // 16000 × 30
        let timeRange = CMTimeRange(
            start: .zero,
            duration: CMTime(seconds: 30, preferredTimescale: 600)
        )
        let buffer = AudioBuffer(samples: samples, timeRange: timeRange)

        // When
        let size = buffer.sizeInBytes

        // Then: 480000 samples × 4 bytes = 1.92 MB
        XCTAssertEqual(size, 1_920_000)

        // 验证约等于 1.92 MB
        let sizeInMB = Double(size) / 1_000_000.0
        XCTAssertEqual(sizeInMB, 1.92, accuracy: 0.01)
    }

    // MARK: - 时长计算测试

    func testDuration() {
        // Given: 10s 音频数据
        let samples = Array(repeating: Float(0.0), count: 160000)
        let timeRange = CMTimeRange(
            start: .zero,
            duration: CMTime(seconds: 10, preferredTimescale: 600)
        )
        let buffer = AudioBuffer(samples: samples, timeRange: timeRange)

        // When
        let duration = buffer.duration

        // Then
        XCTAssertEqual(duration, 10.0, accuracy: 0.01)
    }

    func testDurationForStereo() {
        // Given: 5s 立体声音频数据（2 声道）
        let samples = Array(repeating: Float(0.0), count: 160000)  // 16000 × 2ch × 5s
        let timeRange = CMTimeRange(
            start: .zero,
            duration: CMTime(seconds: 5, preferredTimescale: 600)
        )
        let buffer = AudioBuffer(
            samples: samples,
            sampleRate: 16000,
            channels: 2,  // Stereo
            timeRange: timeRange
        )

        // When
        let duration = buffer.duration

        // Then: 160000 / 16000 / 2 = 5s
        XCTAssertEqual(duration, 5.0, accuracy: 0.01)
    }

    // MARK: - CustomStringConvertible 测试

    func testDescription() {
        // Given
        let samples = Array(repeating: Float(0.0), count: 160000)
        let timeRange = CMTimeRange(
            start: CMTime(seconds: 5, preferredTimescale: 600),
            duration: CMTime(seconds: 10, preferredTimescale: 600)
        )
        let buffer = AudioBuffer(samples: samples, timeRange: timeRange)

        // When
        let description = buffer.description

        // Then: 验证关键信息存在
        XCTAssertTrue(description.contains("160000"))  // samples count
        XCTAssertTrue(description.contains("16000 Hz"))  // sample rate
        XCTAssertTrue(description.contains("10.00"))  // duration
        XCTAssertTrue(description.contains("5.0"))  // start time
        XCTAssertTrue(description.contains("15.0"))  // end time (5 + 10)
    }

    // MARK: - 边界条件测试

    func testEmptyBuffer() {
        // Given: 空缓冲区
        let samples: [Float] = []
        let timeRange = CMTimeRange(
            start: .zero,
            duration: .zero
        )
        let buffer = AudioBuffer(samples: samples, timeRange: timeRange)

        // Then
        XCTAssertEqual(buffer.samples.count, 0)
        XCTAssertEqual(buffer.sizeInBytes, 0)
        XCTAssertEqual(buffer.duration, 0.0)
    }

    func testCustomSampleRate() {
        // Given: 自定义采样率（44.1kHz）
        let samples = Array(repeating: Float(0.0), count: 44100)  // 1s at 44.1kHz
        let timeRange = CMTimeRange(
            start: .zero,
            duration: CMTime(seconds: 1, preferredTimescale: 600)
        )
        let buffer = AudioBuffer(
            samples: samples,
            sampleRate: 44100,
            channels: 1,
            timeRange: timeRange
        )

        // Then
        XCTAssertEqual(buffer.sampleRate, 44100)
        XCTAssertEqual(buffer.duration, 1.0, accuracy: 0.01)
        XCTAssertEqual(buffer.sizeInBytes, 176400)  // 44100 × 4 bytes
    }
}
