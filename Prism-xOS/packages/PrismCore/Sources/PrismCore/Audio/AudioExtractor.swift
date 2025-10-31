import AVFoundation
import Foundation

/// 音频抽取服务协议
///
/// 职责：
/// - 从媒体资源滚动提取音频段
/// - 转换为 16kHz/mono/PCM Float32 格式
/// - 支持异步操作和取消
///
/// 音频格式说明：
/// - 采样率：16 kHz（Whisper 模型训练标准，覆盖人声 80Hz–8kHz）
/// - 声道：Mono（单声道，减少 50% 数据量，ASR 不需要空间信息）
/// - 位深度：Float32（32-bit 浮点，避免削波失真，AVFoundation 原生格式）
/// - 编码：PCM（未压缩，处理简单，CPU 开销小）
/// - 数据量：64 KB/s（16,000 samples × 1 channel × 4 bytes）
///
/// 实现策略：
/// - AVAssetAudioExtractor: 基于 AVAssetReader 的生产实现
/// - MockAudioExtractor: 测试用 Mock 实现
///
/// 性能要求：
/// - 10s 音频抽取耗时 P95 < 200ms（M1 Mac）
/// - 支持并发抽取（多段音频并行处理）
/// - 支持取消操作（通过 Task.checkCancellation()）
///
/// 参考：
/// - HLD v0.2 §2.1 AudioExtractService
/// - HLD v0.2 §5 播放-抽取-识别-渲染流水线
/// - Task-102 §2 音频格式技术说明
public protocol AudioExtractor: Sendable {
    /// 抽取指定时间范围的音频数据
    ///
    /// 核心算法：
    /// 1. 创建 AVAssetReader 并配置音频输出设置（16kHz mono Float32）
    /// 2. 设置时间范围（timeRange）
    /// 3. 循环读取 CMSampleBuffer
    /// 4. 转换为 PCM Float32 数组
    /// 5. 检查取消信号（Task.checkCancellation()）
    ///
    /// - Parameters:
    ///   - asset: 媒体资源（AVAsset）
    ///   - timeRange: 时间范围（CMTimeRange）
    /// - Returns: PCM Float32 音频数据（16kHz mono）
    /// - Throws: AudioExtractionError
    ///
    /// - Note: 此方法是异步的，支持通过 Task.cancel() 取消
    /// - Warning: 如果时间范围超出媒体时长，会抛出 `.timeRangeInvalid` 错误
    func extract(
        from asset: AVAsset,
        timeRange: CMTimeRange
    ) async throws -> AudioBuffer
}

/// 音频抽取错误
///
/// 职责：
/// - 定义音频抽取过程中可能出现的错误类型
/// - 提供本地化错误描述（支持国际化）
///
/// 错误分类：
/// - 资源错误：assetNotReadable, noAudioTrack
/// - 格式错误：unsupportedFormat
/// - 初始化错误：readerInitFailed
/// - 读取错误：readFailed, timeRangeInvalid
/// - 操作错误：cancelled
public enum AudioExtractionError: Error, LocalizedError {
    /// 媒体资源无法读取
    case assetNotReadable

    /// 未找到音频轨道
    case noAudioTrack

    /// 不支持的音频格式
    case unsupportedFormat

    /// 音频读取器初始化失败
    case readerInitFailed(String)

    /// 音频读取失败
    case readFailed(String)

    /// 时间范围无效（超出媒体时长或格式错误）
    case timeRangeInvalid

    /// 操作已取消
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .assetNotReadable:
            return NSLocalizedString(
                "audio.error.asset_not_readable",
                comment: "媒体资源无法读取"
            )
        case .noAudioTrack:
            return NSLocalizedString(
                "audio.error.no_audio_track",
                comment: "未找到音频轨道"
            )
        case .unsupportedFormat:
            return NSLocalizedString(
                "audio.error.unsupported_format",
                comment: "不支持的音频格式"
            )
        case .readerInitFailed(let message):
            return String(
                format: NSLocalizedString(
                    "audio.error.reader_init_failed",
                    comment: "音频读取器初始化失败: %@"
                ),
                message
            )
        case .readFailed(let message):
            return String(
                format: NSLocalizedString(
                    "audio.error.read_failed",
                    comment: "音频读取失败: %@"
                ),
                message
            )
        case .timeRangeInvalid:
            return NSLocalizedString(
                "audio.error.time_range_invalid",
                comment: "时间范围无效"
            )
        case .cancelled:
            return NSLocalizedString(
                "audio.error.cancelled",
                comment: "操作已取消"
            )
        }
    }
}
