import Foundation

/// ASR 配置选项
///
/// 定义语音识别的各项参数配置，包括语言、模型路径、温度等。
/// 所有属性均为不可变，确保并发安全。
public struct AsrOptions: Sendable {
    /// 识别语言（nil 表示自动检测）
    public let language: AsrLanguage?

    /// 模型路径（URL）
    ///
    /// 如果为 nil，将使用引擎的默认模型。
    public let modelPath: URL?

    /// 采样温度（0.0-1.0）
    ///
    /// 温度值控制输出的随机性：
    /// - 0.0: 完全确定性输出（推荐用于准确转写）
    /// - 1.0: 最大随机性（可能用于创意生成）
    public let temperature: Float

    /// 是否启用时间戳
    ///
    /// 启用后，每个 AsrSegment 将包含准确的开始/结束时间。
    /// 禁用可能略微提升性能，但无法用于字幕同步。
    public let enableTimestamps: Bool

    /// 初始提示词（可选）
    ///
    /// 提供上下文或引导识别的文本。例如：
    /// - 专业术语词汇表
    /// - 说话人姓名
    /// - 特定领域的关键词
    public let prompt: String?

    /// 初始化 ASR 选项
    ///
    /// - Parameters:
    ///   - language: 识别语言，nil 表示自动检测
    ///   - modelPath: 模型文件路径，nil 表示使用默认模型
    ///   - temperature: 采样温度，范围 0.0-1.0，默认 0.0
    ///   - enableTimestamps: 是否生成时间戳，默认 true
    ///   - prompt: 初始提示词，默认 nil
    public init(
        language: AsrLanguage? = nil,
        modelPath: URL? = nil,
        temperature: Float = 0.0,
        enableTimestamps: Bool = true,
        prompt: String? = nil
    ) {
        self.language = language
        self.modelPath = modelPath
        self.temperature = max(0.0, min(1.0, temperature))  // 限制在 [0.0, 1.0]
        self.enableTimestamps = enableTimestamps
        self.prompt = prompt
    }
}
