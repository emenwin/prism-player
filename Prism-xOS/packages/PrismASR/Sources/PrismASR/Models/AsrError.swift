import Foundation

/// ASR 引擎错误类型
///
/// 定义语音识别过程中可能发生的所有错误。
/// 所有错误类型均符合 LocalizedError 协议，提供用户友好的错误描述。
public enum AsrError: Error, LocalizedError, Sendable {
    /// 模型未加载
    case modelNotLoaded

    /// 模型加载失败
    ///
    /// - Parameter url: 尝试加载的模型文件 URL
    case modelLoadFailed(URL)

    /// 无效的音频格式
    ///
    /// 音频数据不符合要求（必须是 16kHz mono PCM Float32）
    case invalidAudioFormat

    /// 转写失败
    ///
    /// - Parameter message: 详细错误信息
    case transcriptionFailed(String)

    /// 任务已取消
    case cancelled

    /// 内部错误
    ///
    /// - Parameter message: 错误详情
    case internalError(String)

    // MARK: - LocalizedError

    /// 错误描述（用户可见）
    public var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return NSLocalizedString(
                "asr.error.model_not_loaded",
                value: "ASR model is not loaded. Please initialize the engine with a valid model.",
                comment: "模型未加载错误"
            )

        case .modelLoadFailed(let url):
            return String(
                format: NSLocalizedString(
                    "asr.error.model_load_failed",
                    value: "Failed to load ASR model from: %@",
                    comment: "模型加载失败"
                ),
                url.lastPathComponent
            )

        case .invalidAudioFormat:
            return NSLocalizedString(
                "asr.error.invalid_audio_format",
                value: "Invalid audio format. Expected 16kHz mono PCM Float32.",
                comment: "无效音频格式"
            )

        case .transcriptionFailed(let message):
            return String(
                format: NSLocalizedString(
                    "asr.error.transcription_failed",
                    value: "Transcription failed: %@",
                    comment: "转写失败"
                ),
                message
            )

        case .cancelled:
            return NSLocalizedString(
                "asr.error.cancelled",
                value: "Transcription was cancelled.",
                comment: "任务已取消"
            )

        case .internalError(let message):
            return String(
                format: NSLocalizedString(
                    "asr.error.internal",
                    value: "Internal error: %@",
                    comment: "内部错误"
                ),
                message
            )
        }
    }

    /// 错误恢复建议
    public var recoverySuggestion: String? {
        switch self {
        case .modelNotLoaded:
            return NSLocalizedString(
                "asr.error.model_not_loaded.recovery",
                value:
                    "Initialize the ASR engine with a valid model file before attempting transcription.",
                comment: "模型未加载恢复建议"
            )

        case .modelLoadFailed:
            return NSLocalizedString(
                "asr.error.model_load_failed.recovery",
                value: "Verify that the model file exists and is a valid GGUF format.",
                comment: "模型加载失败恢复建议"
            )

        case .invalidAudioFormat:
            return NSLocalizedString(
                "asr.error.invalid_audio_format.recovery",
                value: "Convert audio to 16kHz mono PCM Float32 format using AudioExtractor.",
                comment: "无效音频格式恢复建议"
            )

        case .transcriptionFailed:
            return NSLocalizedString(
                "asr.error.transcription_failed.recovery",
                value: "Try with a shorter audio segment or check the audio quality.",
                comment: "转写失败恢复建议"
            )

        case .cancelled:
            return nil

        case .internalError:
            return NSLocalizedString(
                "asr.error.internal.recovery",
                value: "Please report this issue with the error details.",
                comment: "内部错误恢复建议"
            )
        }
    }
}

// MARK: - CustomStringConvertible

extension AsrError: CustomStringConvertible {
    /// 调试友好的字符串描述
    public var description: String {
        switch self {
        case .modelNotLoaded:
            return "AsrError.modelNotLoaded"
        case .modelLoadFailed(let url):
            return "AsrError.modelLoadFailed(\(url.path))"
        case .invalidAudioFormat:
            return "AsrError.invalidAudioFormat"
        case .transcriptionFailed(let message):
            return "AsrError.transcriptionFailed(\(message))"
        case .cancelled:
            return "AsrError.cancelled"
        case .internalError(let message):
            return "AsrError.internalError(\(message))"
        }
    }
}
