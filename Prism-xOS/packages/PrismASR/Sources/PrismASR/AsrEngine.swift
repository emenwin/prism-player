import Foundation
import PrismCore

/// ASR 引擎协议
///
/// 定义语音转文字引擎的标准接口，支持多种后端实现（Whisper.cpp, MLX Swift 等）。
public protocol AsrEngine: Sendable {
    /// 转写音频数据
    /// - Parameters:
    ///   - audioData: 音频原始数据
    ///   - options: ASR 配置选项
    /// - Returns: 识别的文本片段数组
    /// - Throws: 转写失败时抛出错误
    func transcribe(
        audioData: Data,
        options: AsrOptions
    ) async throws -> [AsrSegment]
}

/// ASR 配置选项
public struct AsrOptions: Sendable {
    /// 识别语言（ISO 639-1 代码，如 "en", "zh"），nil 表示自动检测
    public let language: String?

    /// 是否启用时间戳
    public let enableTimestamps: Bool

    /// 初始化 ASR 选项
    /// - Parameters:
    ///   - language: 目标语言，nil 表示自动检测
    ///   - enableTimestamps: 是否生成时间戳，默认 true
    public init(language: String? = nil, enableTimestamps: Bool = true) {
        self.language = language
        self.enableTimestamps = enableTimestamps
    }
}

/// ASR 语言枚举
public enum AsrLanguage: String, Sendable, CaseIterable {
    case auto = "auto"
    case english = "en"
    case chinese = "zh"
    case japanese = "ja"
    case korean = "ko"
    case french = "fr"
    case german = "de"
    case spanish = "es"

    /// 本地化显示名称
    public var displayName: String {
        switch self {
        case .auto: return "asr.language.auto"
        case .english: return "asr.language.english"
        case .chinese: return "asr.language.chinese"
        case .japanese: return "asr.language.japanese"
        case .korean: return "asr.language.korean"
        case .french: return "asr.language.french"
        case .german: return "asr.language.german"
        case .spanish: return "asr.language.spanish"
        }
    }
}
