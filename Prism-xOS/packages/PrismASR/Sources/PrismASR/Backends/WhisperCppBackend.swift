import Foundation
import PrismCore

/// Whisper.cpp 后端实现（占位）
///
/// 在 Sprint 1 PR2/PR3 中实现完整的 Whisper.cpp 集成。
public final class WhisperCppBackend: AsrEngine {
    /// 初始化 Whisper.cpp 后端
    public init() {
        // Sprint 1 PR2: 实现模型加载与初始化
    }

    /// 转写音频数据（占位实现）
    public func transcribe(
        audioData: Data,
        options: AsrOptions
    ) async throws -> [AsrSegment] {
        // Sprint 1 PR3: 实现 whisper.cpp 调用
        // 1. 音频预处理（重采样到 16kHz）
        // 2. 调用 whisper.cpp 推理
        // 3. 解析结果并转换为 AsrSegment
        []
    }

    /// 取消所有进行中的识别任务（占位实现）
    public func cancelAll() async {
        // Sprint 1 PR3: 实现取消机制
    }
}
