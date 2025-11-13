import Foundation
import OSLog
import whisper  // Module from CWhisper.xcframework (official whisper.framework)

/// Whisper.cpp 上下文封装（线程安全）
///
/// 负责管理 whisper.cpp 的生命周期与状态，提供 Swift 友好的 API。
/// 使用 Actor 确保所有操作的线程安全性。
///
/// ## 功能概述
/// - 模型加载与卸载（支持 GGUF 格式）
/// - 音频转写（PCM Float32，16kHz mono）
/// - 任务取消机制
/// - 自动资源管理（RAII 模式）
///
/// ## 使用示例
/// ```swift
/// let context = WhisperContext()
/// try await context.loadModel(at: modelURL)
/// let segments = try await context.transcribe(audioData: data, options: options)
/// await context.unloadModel()
/// ```
public actor WhisperContext {
    // MARK: - Private Properties

    /// C API 上下文指针
    private var context: OpaquePointer?

    /// 当前加载的模型路径
    private var modelPath: URL?

    /// 日志器
    private let logger = Logger(
        subsystem: "com.prismplayer.asr",
        category: "WhisperContext"
    )

    // MARK: - Computed Properties

    /// 是否已初始化（模型已加载）
    private var isInitialized: Bool {
        context != nil
    }

    // MARK: - Initialization

    /// 创建 Whisper 上下文（不加载模型）
    public init() {
        self.context = nil
        logger.debug("[WhisperContext] Initialized (no model loaded)")
    }

    // MARK: - Model Management

    /// 加载 GGUF 模型
    ///
    /// - Parameter modelPath: 模型文件路径（.bin 或 .gguf 格式）
    /// - Throws: 模型加载失败时抛出 `AsrError.modelLoadFailed`
    ///
    /// ## 注意事项
    /// - 如果已有模型加载，会先自动卸载
    /// - 支持 whisper.cpp 的所有 GGUF 模型（tiny/base/small/medium/large）
    /// - 加载过程可能耗时较长（取决于模型大小）
    public func loadModel(at modelPath: URL) async throws {
        let startTime = Date()

        // 如果已有模型，先释放
        if isInitialized {
            logger.info("[WhisperContext] Unloading existing model before loading new one")
            await unloadModel()
        }

        // 检查文件是否存在
        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            logger.error("[WhisperContext] Model file not found: \(modelPath.path)")
            throw AsrError.modelLoadFailed(modelPath)
        }

        // 调用 C API 加载模型
        logger.info("[WhisperContext] Loading model from: \(modelPath.lastPathComponent)")
        let cPath = modelPath.path.cString(using: .utf8)!

        // whisper_init_from_file 可能返回 nil
        guard let ctx = whisper_init_from_file(cPath) else {
            logger.error("[WhisperContext] whisper_init_from_file returned nil")
            throw AsrError.modelLoadFailed(modelPath)
        }

        // 保存状态
        self.context = ctx
        self.modelPath = modelPath

        let elapsed = Date().timeIntervalSince(startTime)
        logger.info(
            """
            [WhisperContext] Model loaded successfully: \
            file=\(modelPath.lastPathComponent), \
            loadTime=\(String(format: "%.2f", elapsed))s
            """)
    }

    /// 卸载模型并释放资源
    ///
    /// 该方法是幂等的，可以安全地多次调用。
    public func unloadModel() async {
        guard let ctx = context else {
            logger.debug("[WhisperContext] No model to unload")
            return
        }

        logger.info(
            "[WhisperContext] Unloading model: \(self.modelPath?.lastPathComponent ?? "unknown")")
        whisper_free(ctx)

        self.context = nil
        self.modelPath = nil

        logger.debug("[WhisperContext] Model unloaded successfully")
    }

    // MARK: - Audio Transcription

    /// 转写音频数据
    ///
    /// - Parameters:
    ///   - audioData: PCM Float32 音频数据（16kHz mono）
    ///   - options: ASR 配置选项
    /// - Returns: 识别的文本片段数组（带时间戳）
    /// - Throws: 转写失败时抛出 `AsrError`
    ///
    /// ## 注意事项
    /// - 必须先调用 `loadModel(at:)` 加载模型
    /// - 音频格式必须为 16kHz mono PCM Float32
    /// - 转写过程可能耗时较长（取决于音频长度和模型大小）
    public func transcribe(
        audioData: Data,
        options: AsrOptions
    ) async throws -> [AsrSegment] {
        guard isInitialized else {
            logger.error("[WhisperContext] Transcribe called but model not loaded")
            throw AsrError.modelNotLoaded
        }

        // PR3: 实现音频转写逻辑
        // 1. 转换 Data → Float32 buffer
        // 2. 配置 whisper_full_params
        // 3. 调用 whisper_full()
        // 4. 解析结果并转换为 AsrSegment

        logger.warning("[WhisperContext] transcribe() not implemented yet (PR3)")
        throw AsrError.internalError("Transcription not implemented in PR2")
    }

    /// 取消当前转写任务
    ///
    /// PR3 将实现此功能。
    public func cancel() async {
        // PR3: 实现取消机制
        logger.warning("[WhisperContext] cancel() not implemented yet (PR3)")
    }

    // MARK: - Cleanup

    /// 析构函数，确保资源正确释放
    ///
    /// 注意：Actor 的 deinit 在同步上下文中执行，无法调用 async 方法。
    deinit {
        if let ctx = context {
            logger.info("[WhisperContext] deinit: Releasing whisper context")
            whisper_free(ctx)
        }
    }
}

// MARK: - AsrSegment (临时定义，PR3 将移至 Models/)

/// ASR 识别的文本片段（带时间戳）
///
/// 这是临时定义，PR3 将移至 PrismCore 的共享模型中。
public struct AsrSegment: Sendable {
    /// 开始时间（秒）
    public let startTime: Double

    /// 结束时间（秒）
    public let endTime: Double

    /// 识别的文本内容
    public let text: String

    public init(startTime: Double, endTime: Double, text: String) {
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
    }
}
