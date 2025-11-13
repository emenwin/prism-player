import Foundation
import OSLog
import PrismCore
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

        // 使用新版 API：whisper_init_from_file_with_params
        let params = whisper_context_default_params()
        guard let ctx = whisper_init_from_file_with_params(cPath, params) else {
            logger.error("[WhisperContext] whisper_init_from_file_with_params returned nil")
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
        
        guard let ctx = context else {
            throw AsrError.modelNotLoaded
        }

        let startTime = Date()
        
        // 日志：转写开始
        logger.info(
            """
            [WhisperContext] Transcription started: \
            audioSize=\(audioData.count) bytes, \
            language=\(options.language?.code ?? "auto"), \
            temperature=\(options.temperature)
            """
        )

        // 1. 音频数据转换（Data → [Float]）
        let samples = AudioConverter.dataToFloatArray(audioData)
        let sampleCount = samples.count
        
        logger.debug(
            "[WhisperContext] Audio converted: \(sampleCount) samples (\(String(format: "%.2f", Double(sampleCount) / 16000.0))s)"
        )

        // 2. 配置 whisper_full_params
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        
        // 语言设置
        if let language = options.language {
            let languageCode = language.code
            params.language = languageCode.withCString { ptr in
                // 复制字符串到 C 风格内存
                UnsafePointer(strdup(ptr))
            }
        }
        
        // 温度参数
        params.temperature = options.temperature
        
        // 线程数配置（使用系统核心数）
        params.n_threads = Int32(ProcessInfo.processInfo.activeProcessorCount)
        
        // 时间戳启用
        params.no_timestamps = !options.enableTimestamps
        
        // 禁用实时打印（避免干扰日志）
        params.print_realtime = false
        params.print_progress = false
        params.print_timestamps = false
        params.print_special = false
        
        // 初始提示词（如有）
        if let prompt = options.prompt {
            params.initial_prompt = prompt.withCString { ptr in
                UnsafePointer(strdup(ptr))
            }
        }

        logger.debug(
            """
            [WhisperContext] Params configured: \
            threads=\(params.n_threads), \
            no_timestamps=\(params.no_timestamps)
            """
        )

        // 3. 调用 whisper_full() C API
        let result = samples.withUnsafeBufferPointer { buffer in
            whisper_full(ctx, params, buffer.baseAddress, Int32(buffer.count))
        }
        
        // 释放字符串内存（如果分配了）
        if let languagePtr = params.language {
            free(UnsafeMutableRawPointer(mutating: languagePtr))
        }
        if let promptPtr = params.initial_prompt {
            free(UnsafeMutableRawPointer(mutating: promptPtr))
        }
        
        // 检查返回值
        guard result == 0 else {
            logger.error("[WhisperContext] whisper_full() returned error code: \(result)")
            throw AsrError.transcriptionFailed("whisper_full returned \(result)")
        }

        // 4. 解析结果并转换为 AsrSegment
        let nSegments = whisper_full_n_segments(ctx)
        var segments: [AsrSegment] = []
        
        logger.debug("[WhisperContext] Parsing \(nSegments) segments")
        
        for i in 0..<nSegments {
            // 取消检查（每 10 个片段检查一次，减少开销）
            if i % 10 == 0 {
                try Task.checkCancellation()
            }
            
            // 获取片段文本
            guard let textPtr = whisper_full_get_segment_text(ctx, i) else {
                logger.warning("[WhisperContext] Segment \(i) has nil text, skipping")
                continue
            }
            let text = String(cString: textPtr)
            
            // 跳过空文本
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }
            
            // 获取时间戳（单位：百分之一秒）
            let t0 = whisper_full_get_segment_t0(ctx, i)
            let t1 = whisper_full_get_segment_t1(ctx, i)
            
            // 转换为秒
            let startTime = Double(t0) / 100.0
            let endTime = Double(t1) / 100.0
            
            // 创建 AsrSegment（mediaId 由调用方设置）
            let segment = AsrSegment(
                mediaId: "unknown",  // 占位符，由上层设置
                startTime: startTime,
                endTime: endTime,
                text: text
            )
            segments.append(segment)
            
            logger.debug(
                """
                [WhisperContext] Segment \(i): \
                [\(String(format: "%.2f", startTime)) → \(String(format: "%.2f", endTime))s] \
                "\(text.prefix(50))\(text.count > 50 ? "..." : "")"
                """
            )
        }

        let elapsed = Date().timeIntervalSince(startTime)
        let audioDuration = Double(sampleCount) / 16000.0
        let rtf = audioDuration > 0 ? elapsed / audioDuration : 0
        
        // 日志：转写成功
        logger.info(
            """
            [WhisperContext] Transcription completed: \
            segmentCount=\(segments.count), \
            duration=\(String(format: "%.2f", elapsed))s, \
            audioDuration=\(String(format: "%.2f", audioDuration))s, \
            RTF=\(String(format: "%.2f", rtf))
            """
        )

        return segments
    }

    /// 取消当前转写任务
    ///
    /// 通过 Swift Concurrency 的取消机制实现。
    /// 调用方应取消包含 transcribe() 的 Task。
    public func cancel() async {
        logger.warning("[WhisperContext] Cancel requested (handled via Task.checkCancellation())")
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
