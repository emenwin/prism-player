import AVFoundation
import Foundation

/// 音频缓冲区
///
/// 职责：
/// - 封装 PCM Float32 音频数据
/// - 记录音频元数据（采样率、声道数、时间范围）
/// - 提供内存占用计算
///
/// 数据格式：
/// - 采样率：16 kHz（Whisper 模型训练标准）
/// - 声道：Mono（单声道，减少 50% 数据量）
/// - 位深度：Float32（32-bit 浮点，避免削波失真）
/// - 编码：PCM（未压缩，处理简单）
///
/// 内存计算：
/// - 1 秒音频 = 16,000 samples × 1 channel × 4 bytes = 64 KB
/// - 10 秒音频 = 640 KB
/// - 30 秒音频 = 1.92 MB
///
/// 参考：Task-102 §2 音频格式技术说明
public struct AudioBuffer: Sendable {
    /// PCM Float32 样本数据
    /// 每个样本的取值范围：[-1.0, 1.0]（归一化振幅）
    public let samples: [Float]

    /// 采样率（Hz）
    /// 默认：16,000 Hz（16 kHz）
    public let sampleRate: Int

    /// 声道数
    /// 默认：1（Mono 单声道）
    public let channels: Int

    /// 时间范围（原始媒体时间）
    /// 用于缓存索引和时间对齐
    public let timeRange: CMTimeRange

    /// 缓冲区大小（字节）
    ///
    /// 计算公式：
    /// ```
    /// sizeInBytes = samples.count × MemoryLayout<Float>.size
    ///             = samples.count × 4 bytes
    /// ```
    public var sizeInBytes: Int {
        samples.count * MemoryLayout<Float>.size
    }

    /// 音频时长（秒）
    ///
    /// 计算公式：
    /// ```
    /// duration = samples.count / sampleRate / channels
    /// ```
    public var duration: TimeInterval {
        Double(samples.count) / Double(sampleRate) / Double(channels)
    }

    /// 初始化音频缓冲区
    /// - Parameters:
    ///   - samples: PCM Float32 样本数据
    ///   - sampleRate: 采样率（Hz），默认 16,000
    ///   - channels: 声道数，默认 1（Mono）
    ///   - timeRange: 时间范围（原始媒体时间）
    public init(
        samples: [Float],
        sampleRate: Int = 16_000,
        channels: Int = 1,
        timeRange: CMTimeRange
    ) {
        self.samples = samples
        self.sampleRate = sampleRate
        self.channels = channels
        self.timeRange = timeRange
    }
}

// MARK: - CustomStringConvertible

extension AudioBuffer: CustomStringConvertible {
    public var description: String {
        """
        AudioBuffer(
            samples: \(samples.count),
            sampleRate: \(sampleRate) Hz,
            channels: \(channels),
            duration: \(String(format: "%.2f", duration))s,
            size: \(ByteCountFormatter.string(fromByteCount: Int64(sizeInBytes), countStyle: .memory)),
            timeRange: \(timeRange.start.seconds)s - \(timeRange.end.seconds)s
        )
        """
    }
}
