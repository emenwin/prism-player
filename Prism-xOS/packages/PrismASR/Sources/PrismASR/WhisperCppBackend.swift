import Foundation
import PrismCore

/// Whisper.cpp 后端实现（占位）
///
/// 在 Sprint 1 中实现完整的 Whisper.cpp 集成。
public final class WhisperCppBackend: AsrEngine {
    /// 初始化 Whisper.cpp 后端
    public init() {
        // TODO: Sprint 1 - 加载模型与初始化
    }

    /// 转写音频数据（占位实现）
    public func transcribe(
        audioData: Data,
        options: AsrOptions
    ) async throws -> [AsrSegment] {
        // TODO: Sprint 1 - 实现 whisper.cpp 调用
        // 1. 音频预处理（重采样到 16kHz）
        // 2. 调用 whisper.cpp 推理
        // 3. 解析结果并转换为 AsrSegment

        []
    }
}
