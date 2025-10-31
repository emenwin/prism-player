import Foundation
import PrismCore

/// ASR 引擎协议
///
/// 定义语音转文字引擎的标准接口，支持多种后端实现（Whisper.cpp, MLX Swift 等）。
/// 该协议设计为 Sendable，确保在并发环境中的线程安全性。
///
/// ## 使用示例
/// ```swift
/// let backend = WhisperCppBackend(modelPath: modelURL)
/// let options = AsrOptions(language: .english)
/// let segments = try await backend.transcribe(audioData: pcmData, options: options)
/// ```
public protocol AsrEngine: Sendable {
    /// 转写音频数据
    ///
    /// 将音频数据转换为带时间戳的文本片段。音频数据必须是 PCM Float32 格式，
    /// 16kHz 采样率，单声道。
    ///
    /// - Parameters:
    ///   - audioData: PCM Float32 音频数据（16kHz mono）
    ///   - options: ASR 配置选项
    /// - Returns: 识别的文本片段数组（带时间戳）
    /// - Throws: 转写失败时抛出 AsrError
    func transcribe(
        audioData: Data,
        options: AsrOptions
    ) async throws -> [AsrSegment]

    /// 取消所有进行中的识别任务
    ///
    /// 调用此方法将取消所有正在执行的 transcribe 任务。
    /// 被取消的任务会抛出 AsrError.cancelled 错误。
    func cancelAll() async
}
