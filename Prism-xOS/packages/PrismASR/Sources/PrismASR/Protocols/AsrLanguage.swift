import Foundation

/// ASR 语言枚举
///
/// 定义支持的语音识别语言。使用 ISO 639-1 语言代码。
public enum AsrLanguage: String, Sendable, CaseIterable, Codable {
    /// 自动检测语言
    case auto = "auto"

    /// 英文
    case english = "en"

    /// 中文
    case chinese = "zh"

    /// 日语
    case japanese = "ja"

    /// 韩语
    case korean = "ko"

    /// 法语
    case french = "fr"

    /// 德语
    case german = "de"

    /// 西班牙语
    case spanish = "es"

    /// 本地化显示名称（国际化 key）
    ///
    /// 返回用于 NSLocalizedString 的键名，实际显示文本由本地化文件提供。
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

    /// ISO 639-1 语言代码
    ///
    /// 返回标准的两字母语言代码。
    /// 注意：`auto` 返回 "auto"（非标准代码）
    public var code: String {
        rawValue
    }
}

// MARK: - Convenience Initializers

extension AsrLanguage {
    /// 从 ISO 639-1 代码或 "auto" 创建语言枚举
    ///
    /// - Parameter code: 语言代码字符串
    /// - Returns: 对应的 AsrLanguage，如果无法识别则返回 nil
    public init?(code: String) {
        self.init(rawValue: code.lowercased())
    }
}
