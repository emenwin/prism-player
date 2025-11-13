import Foundation
import OSLog
import PrismCore

/// Whisper.cpp 后端实现
///
/// 基于 whisper.cpp 的 ASR 引擎后端，提供高质量的语音转文字能力。
/// 使用 Actor 封装的 WhisperContext 确保线程安全。
///
/// ## 功能特性
/// - 支持 GGUF 模型（tiny/base/small/medium/large）
/// - Metal/Accelerate 硬件加速
/// - 多语言支持（英文/中文/日语等）
/// - 自动模型加载（首次调用时）
/// - 任务取消机制
///
/// ## 使用示例
/// ```swift
/// let backend = WhisperCppBackend(modelPath: modelURL)
/// let options = AsrOptions(language: .english, temperature: 0.0)
/// let segments = try await backend.transcribe(audioData: pcmData, options: options)
/// ```
public final class WhisperCppBackend: AsrEngine, @unchecked Sendable {
    // MARK: - Private Properties

    /// Whisper.cpp 上下文（Actor 线程安全）
    private let context: WhisperContext

    /// 默认模型路径（可选）
    private let defaultModelPath: URL?

    /// 模型是否已加载（通过 context 管理，此标志仅用于优化重复加载检查）
    private var isModelLoaded = false

    /// 日志器
    private let logger = Logger(
        subsystem: "com.prismplayer.asr",
        category: "WhisperCppBackend"
    )

    // MARK: - Initialization

    /// 初始化 Whisper.cpp 后端
    ///
    /// - Parameter modelPath: 默认模型路径（可选）。如果提供，首次调用 transcribe() 时自动加载。
    public init(modelPath: URL? = nil) {
        self.context = WhisperContext()
        self.defaultModelPath = modelPath

        logger.debug(
            "[WhisperCppBackend] Initialized with defaultModelPath: \(modelPath?.lastPathComponent ?? "none")"
        )
    }

    // MARK: - AsrEngine Protocol

    /// 转写音频数据
    ///
    /// - Parameters:
    ///   - audioData: PCM Float32 音频数据（16kHz mono）
    ///   - options: ASR 配置选项
    /// - Returns: 识别的文本片段数组（带时间戳）
    /// - Throws: 转写失败时抛出 AsrError
    ///
    /// ## 注意事项
    /// - 首次调用时会自动加载模型（如果提供了 modelPath）
    /// - 音频格式必须为 16kHz mono PCM Float32
    /// - 可以通过 Task 取消机制中断转写
    public func transcribe(
        audioData: Data,
        options: AsrOptions
    ) async throws -> [AsrSegment] {
        logger.info("[WhisperCppBackend] Transcribe requested: \(audioData.count) bytes")

        // 自动加载模型（首次调用）
        let modelPath = options.modelPath ?? defaultModelPath
        if !isModelLoaded, let path = modelPath {
            logger.info("[WhisperCppBackend] Auto-loading model: \(path.lastPathComponent)")
            try await context.loadModel(at: path)
            isModelLoaded = true
        }

        // 验证音频数据
        guard !audioData.isEmpty else {
            logger.error("[WhisperCppBackend] Empty audio data")
            throw AsrError.invalidAudioFormat
        }

        // 验证音频长度（至少 0.1秒，即 1600 samples * 4 bytes）
        let minAudioSize = 1600 * 4  // 0.1s @ 16kHz Float32
        guard audioData.count >= minAudioSize else {
            logger.error(
                "[WhisperCppBackend] Audio too short: \(audioData.count) bytes < \(minAudioSize) bytes"
            )
            throw AsrError.invalidAudioFormat
        }

        // 委托给 WhisperContext
        do {
            let segments = try await context.transcribe(audioData: audioData, options: options)

            logger.info(
                "[WhisperCppBackend] Transcription successful: \(segments.count) segments"
            )

            return segments
        } catch {
            logger.error("[WhisperCppBackend] Transcription failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// 取消所有进行中的识别任务
    ///
    /// 调用此方法将取消当前正在执行的 transcribe 任务。
    /// 被取消的任务会抛出 AsrError.cancelled 错误。
    public func cancelAll() async {
        logger.warning("[WhisperCppBackend] Cancel all requested")
        await context.cancel()
    }
}
