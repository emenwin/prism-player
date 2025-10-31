import AVFoundation
import Foundation
import OSLog

/// 基于 AVAssetReader 的音频抽取实现
///
/// 职责：
/// - 从 AVAsset 中抽取音频数据
/// - 自动处理格式转换（任意格式 → 16kHz mono Float32 PCM）
/// - 支持异步操作和取消
///
/// 核心算法：
/// 1. **验证资源**：检查 asset.isReadable 和音频轨道存在性
/// 2. **创建 Reader**：使用 AVAssetReader 和 AVAssetReaderAudioMixOutput
/// 3. **配置输出格式**：
///    - kAudioFormatLinearPCM（PCM 格式）
///    - 16 kHz 采样率（Whisper 标准）
///    - Mono 单声道（自动混合 Stereo → Mono）
///    - Float32 位深度（避免削波失真）
/// 4. **读取数据**：循环读取 CMSampleBuffer，转换为 Float 数组
/// 5. **取消检查**：每次循环检查 Task.isCancelled
///
/// 性能特性：
/// - 10s 音频抽取耗时：P95 < 200ms（M1 Mac）
/// - 内存占用：64 KB/s（16kHz × 1ch × 4bytes）
/// - 并发安全：每次调用创建新的 Reader，无共享状态
///
/// AVFoundation 自动处理：
/// - 解码压缩格式（AAC/MP3/FLAC → PCM）
/// - 重采样（48kHz/44.1kHz → 16kHz）
/// - 声道混合（Stereo → Mono，取平均值）
/// - 位深度转换（16-bit Int → 32-bit Float）
///
/// 参考：
/// - Task-102 §2.2 本项目音频处理流程
/// - Task-102 §3.1.1 AudioExtractor 协议定义
public final class AVAssetAudioExtractor: AudioExtractor {
    private let logger = Logger(subsystem: "com.prismplayer.core", category: "audio.extractor")

    /// 目标音频格式配置（16kHz mono Float32 PCM）
    ///
    /// 注意：使用 nonisolated(unsafe) 标记，因为此字典是不可变的常量
    /// 在多线程环境中安全使用（只读，无写操作）
    private nonisolated(unsafe) let outputSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatLinearPCM,  // PCM 格式
        AVSampleRateKey: 16_000,  // 16 kHz 采样率
        AVNumberOfChannelsKey: 1,  // Mono（单声道）
        AVLinearPCMBitDepthKey: 32,  // 32-bit
        AVLinearPCMIsFloatKey: true,  // Float（非整数）
        AVLinearPCMIsBigEndianKey: false,  // 小端序（iOS/macOS 标准）
        AVLinearPCMIsNonInterleaved: false  // 交错格式（LRLRLR...）
    ]

    public init() {}

    public func extract(
        from asset: AVAsset,
        timeRange: CMTimeRange
    ) async throws -> AudioBuffer {
        logger.info(
            "开始抽取音频: range=\(timeRange.start.seconds, privacy: .public)s - \(timeRange.end.seconds, privacy: .public)s"
        )

        let startTime = Date()

        // 1. 验证资源可读性
        let isReadable = try await asset.load(.isReadable)
        guard isReadable else {
            logger.error("媒体资源无法读取")
            throw AudioExtractionError.assetNotReadable
        }

        // 2. 获取音频轨道
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard let audioTrack = audioTracks.first else {
            logger.error("未找到音频轨道")
            throw AudioExtractionError.noAudioTrack
        }

        // 3. 验证时间范围
        let duration = try await asset.load(.duration)
        guard timeRange.start >= .zero && timeRange.end <= duration else {
            logger.error(
                "时间范围无效: 请求范围=\(timeRange.start.seconds, privacy: .public)s - \(timeRange.end.seconds, privacy: .public)s, 媒体时长=\(duration.seconds, privacy: .public)s"
            )
            throw AudioExtractionError.timeRangeInvalid
        }

        // 4. 创建 AVAssetReader
        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: asset)
        } catch {
            logger.error("音频读取器初始化失败: \(error.localizedDescription, privacy: .public)")
            throw AudioExtractionError.readerInitFailed(error.localizedDescription)
        }

        // 5. 配置音频输出
        let output = AVAssetReaderAudioMixOutput(
            audioTracks: [audioTrack], audioSettings: outputSettings)
        reader.add(output)

        // 6. 设置时间范围
        reader.timeRange = timeRange

        // 7. 开始读取
        guard reader.startReading() else {
            let error = reader.error?.localizedDescription ?? "Unknown error"
            logger.error("音频读取启动失败: \(error, privacy: .public)")
            throw AudioExtractionError.readFailed(error)
        }

        // 8. 读取样本数据
        var samples: [Float] = []
        let expectedSampleCount = Int(timeRange.duration.seconds * 16_000)  // 16kHz
        samples.reserveCapacity(expectedSampleCount)

        while reader.status == .reading {
            // 检查取消信号
            try Task.checkCancellation()

            guard let sampleBuffer = output.copyNextSampleBuffer() else {
                break
            }

            // 转换 CMSampleBuffer → Float 数组
            if let audioBuffer = try extractFloatSamples(from: sampleBuffer) {
                samples.append(contentsOf: audioBuffer)
            }
        }

        // 9. 检查读取状态
        if reader.status == .failed {
            let error = reader.error?.localizedDescription ?? "Unknown error"
            logger.error("音频读取失败: \(error, privacy: .public)")
            throw AudioExtractionError.readFailed(error)
        }

        if reader.status == .cancelled {
            logger.notice("音频读取已取消")
            throw AudioExtractionError.cancelled
        }

        let elapsed = Date().timeIntervalSince(startTime)
        logger.info(
            "音频抽取完成: 样本数=\(samples.count, privacy: .public), 耗时=\(elapsed * 1_000, privacy: .public)ms"
        )

        return AudioBuffer(
            samples: samples,
            sampleRate: 16_000,
            channels: 1,
            timeRange: timeRange
        )
    }

    /// 从 CMSampleBuffer 中提取 Float 样本数据
    ///
    /// 核心算法：
    /// 1. 获取 AudioBufferList
    /// 2. 遍历所有音频缓冲区
    /// 3. 将 UnsafePointer<Float> 转换为 [Float]
    ///
    /// - Parameter sampleBuffer: CMSampleBuffer
    /// - Returns: Float 数组（PCM Float32）
    /// - Throws: AudioExtractionError.readFailed
    private func extractFloatSamples(from sampleBuffer: CMSampleBuffer) throws -> [Float]? {
        var audioBufferList = AudioBufferList()
        var blockBuffer: CMBlockBuffer?

        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: &audioBufferList,
            bufferListSize: MemoryLayout<AudioBufferList>.size,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
            blockBufferOut: &blockBuffer
        )

        guard status == noErr else {
            logger.error("获取 AudioBufferList 失败: status=\(status, privacy: .public)")
            throw AudioExtractionError.readFailed("Failed to get AudioBufferList: \(status)")
        }

        var samples: [Float] = []

        // 遍历所有缓冲区（Mono 通常只有 1 个）
        let buffers = UnsafeMutableAudioBufferListPointer(&audioBufferList)

        for buffer in buffers {
            guard let data = buffer.mData else { continue }

            let frameCount = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
            let floatPointer = data.assumingMemoryBound(to: Float.self)
            let floatBuffer = UnsafeBufferPointer(start: floatPointer, count: frameCount)

            samples.append(contentsOf: floatBuffer)
        }

        return samples
    }
}
