import Foundation

/// ASR 引擎协议
/// 定义语音识别引擎的标准接口
///
/// 实现类：
/// - WhisperCppEngine: whisper.cpp 后端
/// - MLXEngine: MLX Swift 后端（macOS，实验性）
/// - MockAsrEngine: 测试用 Mock（Tests/Mocks）
///
/// - Created: Sprint 0, Task-009
/// - Last Updated: 2025-10-24
public protocol AsrEngine: Actor {
    /// 转写音频数据
    /// - Parameters:
    ///   - audioData: 音频数据（16kHz, Mono, 16-bit PCM）
    ///   - options: 识别选项（语言、模型等）
    /// - Returns: 识别结果段列表
    /// - Throws: AsrError
    func transcribe(audioData: Data, options: AsrOptions) async throws -> [AsrSegment]

    /// 取消当前识别任务
    func cancel() async
}

// MARK: - ASR Options

/// ASR 识别选项
public struct AsrOptions: Sendable {
    /// 识别语言（nil 表示自动检测）
    public let language: AsrLanguage?

    /// 是否返回时间戳
    public let timestamps: Bool

    /// 是否返回置信度
    public let confidence: Bool

    /// 最大段长度（秒）
    public let maxSegmentLength: TimeInterval

    public init(
        language: AsrLanguage? = nil,
        timestamps: Bool = true,
        confidence: Bool = true,
        maxSegmentLength: TimeInterval = 30.0
    ) {
        self.language = language
        self.timestamps = timestamps
        self.confidence = confidence
        self.maxSegmentLength = maxSegmentLength
    }

    /// 默认选项
    public static let `default` = AsrOptions()
}

// MARK: - ASR Language

/// ASR 支持的语言
public enum AsrLanguage: String, Codable, CaseIterable, Sendable {
    case auto = "auto"
    case english = "en"
    case chinese = "zh"
    case japanese = "ja"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case russian = "ru"

    /// 本地化显示名称
    public var displayName: String {
        switch self {
        case .auto: return NSLocalizedString("language.auto", comment: "自动检测")
        case .english: return NSLocalizedString("language.english", comment: "英语")
        case .chinese: return NSLocalizedString("language.chinese", comment: "中文")
        case .japanese: return NSLocalizedString("language.japanese", comment: "日语")
        case .spanish: return NSLocalizedString("language.spanish", comment: "西班牙语")
        case .french: return NSLocalizedString("language.french", comment: "法语")
        case .german: return NSLocalizedString("language.german", comment: "德语")
        case .russian: return NSLocalizedString("language.russian", comment: "俄语")
        }
    }
}

// MARK: - ASR Error

/// ASR 错误类型
public enum AsrError: Error, LocalizedError {
    case modelNotFound
    case modelLoadFailed
    case invalidAudioFormat
    case transcriptionFailed(String)
    case cancelled
    case unknown(Error)

    public var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return NSLocalizedString("asr.error.model_not_found", comment: "模型文件未找到")
        case .modelLoadFailed:
            return NSLocalizedString("asr.error.model_load_failed", comment: "模型加载失败")
        case .invalidAudioFormat:
            return NSLocalizedString("asr.error.invalid_audio", comment: "音频格式无效")
        case .transcriptionFailed(let message):
            return String(
                format: NSLocalizedString("asr.error.transcription_failed", comment: "识别失败: %@"),
                message)
        case .cancelled:
            return NSLocalizedString("asr.error.cancelled", comment: "识别已取消")
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - Factory Methods

extension AsrEngine {
    /// 创建生产环境引擎
    /// - Parameter modelPath: 模型文件路径
    /// - Returns: ASR 引擎实例
    public static func production(modelPath: String) -> AsrEngine {
        // Sprint 1 实现 WhisperCppEngine
        fatalError("WhisperCppEngine not implemented yet")
    }
}
