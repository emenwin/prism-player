import Foundation

/// 音频格式转换工具
///
/// 提供音频数据格式转换的静态方法，主要用于 ASR 引擎的音频输入准备。
enum AudioConverter {
    /// 将 Data 转换为 Float32 数组
    ///
    /// - Parameter data: PCM Float32 音频数据（原始字节）
    /// - Returns: Float32 样本数组
    ///
    /// ## 使用场景
    /// 从音频文件或流中读取的 Data 需要转换为 Float32 数组才能传递给 whisper.cpp。
    ///
    /// ## 注意事项
    /// - 输入 Data 必须是有效的 Float32 字节序列
    /// - 数据长度必须是 4 的倍数（Float32 = 4 bytes）
    /// - 字节序取决于平台（通常为 little-endian）
    static func dataToFloatArray(_ data: Data) -> [Float] {
        data.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: Float.self))
        }
    }

    /// 将 Float32 数组转换为 Data
    ///
    /// - Parameter samples: Float32 音频样本数组
    /// - Returns: PCM Float32 Data（原始字节）
    ///
    /// ## 使用场景
    /// 将音频样本数组转换为 Data 格式，用于持久化存储或网络传输。
    ///
    /// ## 注意事项
    /// - 输出 Data 的长度为 samples.count * 4 字节
    /// - 字节序取决于平台（通常为 little-endian）
    static func floatArrayToData(_ samples: [Float]) -> Data {
        samples.withUnsafeBytes { buffer in
            Data(buffer)
        }
    }
}
