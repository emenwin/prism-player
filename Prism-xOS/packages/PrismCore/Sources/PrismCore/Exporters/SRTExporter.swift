import Foundation

/// SRT 导出错误类型
///
/// 定义 SRT 字幕导出过程中可能发生的各种错误。
/// 每个错误都提供了本地化的错误描述，方便用户理解。
public enum ExportError: LocalizedError, Equatable {
    /// 字幕数组为空
    case emptySubtitles
    
    /// 磁盘空间不足
    /// - Parameters:
    ///   - required: 需要的字节数
    ///   - available: 可用的字节数
    case insufficientSpace(required: Int64, available: Int64)
    
    /// 权限拒绝
    /// - Parameter path: 被拒绝访问的路径
    case permissionDenied(path: String)
    
    /// 写入失败
    /// - Parameter underlying: 底层错误
    case writeFailure(underlying: Error)
    
    /// 时间戳异常
    /// - Parameter index: 异常字幕的索引
    case invalidTimestamps(index: Int)
    
    public var errorDescription: String? {
        switch self {
        case .emptySubtitles:
            return NSLocalizedString(
                "export.error.emptySubtitles",
                value: "暂无字幕可导出",
                comment: "空字幕数组错误"
            )
        case .insufficientSpace(let required, let available):
            let requiredMB = Double(required) / 1_048_576.0
            let availableMB = Double(available) / 1_048_576.0
            return String(
                format: NSLocalizedString(
                    "export.error.insufficientSpace",
                    value: "磁盘空间不足。需要 %.2f MB，可用 %.2f MB",
                    comment: "磁盘空间不足错误"
                ),
                requiredMB, availableMB
            )
        case .permissionDenied(let path):
            return String(
                format: NSLocalizedString(
                    "export.error.permissionDenied",
                    value: "无法写入文件：%@\n请检查文件权限设置",
                    comment: "权限拒绝错误"
                ),
                path
            )
        case .writeFailure(let underlying):
            return String(
                format: NSLocalizedString(
                    "export.error.writeFailure",
                    value: "文件写入失败：%@",
                    comment: "写入失败错误"
                ),
                underlying.localizedDescription
            )
        case .invalidTimestamps(let index):
            return String(
                format: NSLocalizedString(
                    "export.error.invalidTimestamps",
                    value: "第 %d 条字幕的时间戳异常",
                    comment: "时间戳异常错误"
                ),
                index + 1
            )
        }
    }
    
    public static func == (lhs: ExportError, rhs: ExportError) -> Bool {
        switch (lhs, rhs) {
        case (.emptySubtitles, .emptySubtitles):
            return true
        case (.insufficientSpace(let lr, let la), .insufficientSpace(let rr, let ra)):
            return lr == rr && la == ra
        case (.permissionDenied(let lp), .permissionDenied(let rp)):
            return lp == rp
        case (.invalidTimestamps(let li), .invalidTimestamps(let ri)):
            return li == ri
        case (.writeFailure, .writeFailure):
            return true
        default:
            return false
        }
    }
}

/// SRT 导出服务协议
///
/// 提供字幕导出为 SRT 格式的能力。
/// SRT（SubRip）格式是最常见的字幕格式，支持大多数视频播放器。
public protocol SRTExporter: Sendable {
    /// 导出字幕为 SRT 文件
    ///
    /// - Parameters:
    ///   - subtitles: 字幕数组，应按时间顺序排列
    ///   - destinationURL: 目标文件 URL
    ///   - locale: 语言标识符（如 "zh-Hans", "en-US"）
    /// - Throws: ExportError（空间不足、权限拒绝、写入失败等）
    func export(
        subtitles: [Subtitle],
        to destinationURL: URL,
        locale: String
    ) async throws
}

/// 默认的 SRT 导出实现
///
/// # 核心算法
/// 1. 验证字幕数据（非空、时间戳有效）
/// 2. 生成 SRT 格式内容（序号、时间戳、文本）
/// 3. 检查磁盘空间
/// 4. 处理文件名冲突（自动追加后缀）
/// 5. 写入文件（UTF-8 编码，无 BOM）
///
/// # SRT 格式示例
/// ```
/// 1
/// 00:00:00,000 --> 00:00:02,500
/// 你好，世界
///
/// 2
/// 00:00:02,500 --> 00:00:05,000
/// 这是第二句字幕
/// ```
public struct DefaultSRTExporter: SRTExporter {
    /// 创建 SRT 导出器
    public init() {
    }
    
    public func export(
        subtitles: [Subtitle],
        to destinationURL: URL,
        locale: String
    ) async throws {
        // 验证字幕数组非空
        guard !subtitles.isEmpty else {
            throw ExportError.emptySubtitles
        }
        
        // 验证时间戳
        for (index, subtitle) in subtitles.enumerated() {
            guard subtitle.startTime >= 0,
                  subtitle.endTime > subtitle.startTime else {
                throw ExportError.invalidTimestamps(index: index)
            }
        }
        
        // 生成 SRT 内容
        let srtContent = generateSRTContent(from: subtitles)
        
        // 估算文件大小（UTF-8 编码）
        guard let data = srtContent.data(using: .utf8) else {
            throw ExportError.writeFailure(
                underlying: NSError(
                    domain: "SRTExporter",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "无法编码字幕内容"]
                )
            )
        }
        
        // 检查磁盘空间
        try checkDiskSpace(at: destinationURL, requiredBytes: Int64(data.count))
        
        // 处理文件名冲突
        let finalURL = resolveFileNameConflict(destinationURL)
        
        // 写入文件
        do {
            try data.write(to: finalURL, options: [.atomic])
        } catch let error as NSError where error.code == NSFileWriteNoPermissionError {
            throw ExportError.permissionDenied(path: finalURL.path)
        } catch {
            throw ExportError.writeFailure(underlying: error)
        }
    }
    
    /// 生成 SRT 格式内容
    ///
    /// # 算法说明
    /// 遍历字幕数组，为每条字幕生成：
    /// 1. 序号（从 1 开始）
    /// 2. 时间范围（HH:MM:SS,mmm --> HH:MM:SS,mmm）
    /// 3. 字幕文本
    /// 4. 空行（段落分隔）
    ///
    /// - Parameter subtitles: 字幕数组
    /// - Returns: SRT 格式的字符串
    func generateSRTContent(from subtitles: [Subtitle]) -> String {
        var result = ""
        
        for (index, subtitle) in subtitles.enumerated() {
            let sequenceNumber = index + 1
            let startTime = formatTimestamp(subtitle.startTime)
            let endTime = formatTimestamp(subtitle.endTime)
            
            result += "\(sequenceNumber)\n"
            result += "\(startTime) --> \(endTime)\n"
            result += "\(subtitle.text)\n"
            result += "\n"
        }
        
        return result
    }
    
    /// 将时间（秒）转换为 SRT 时间戳格式
    ///
    /// # 算法说明
    /// SRT 时间戳格式：HH:MM:SS,mmm
    /// - HH: 小时（00-99）
    /// - MM: 分钟（00-59）
    /// - SS: 秒（00-59）
    /// - mmm: 毫秒（000-999）
    ///
    /// # 示例
    /// ```
    /// formatTimestamp(0.0)      // "00:00:00,000"
    /// formatTimestamp(65.5)     // "00:01:05,500"
    /// formatTimestamp(3665.123) // "01:01:05,123"
    /// ```
    ///
    /// - Parameter time: 时间（秒）
    /// - Returns: "HH:MM:SS,mmm" 格式字符串
    func formatTimestamp(_ time: TimeInterval) -> String {
        let totalMilliseconds = Int(time * 1000)
        let hours = totalMilliseconds / 3_600_000
        let minutes = (totalMilliseconds % 3_600_000) / 60_000
        let seconds = (totalMilliseconds % 60_000) / 1_000
        let milliseconds = totalMilliseconds % 1_000
        
        return String(
            format: "%02d:%02d:%02d,%03d",
            hours, minutes, seconds, milliseconds
        )
    }
    
    /// 生成导出文件名
    ///
    /// # 命名规则
    /// `<basename>.<locale>.srt`
    ///
    /// # 示例
    /// ```
    /// generateFileName("video.mp4", locale: "zh-Hans")  // "video.zh-Hans.srt"
    /// generateFileName("audio", locale: "en-US")        // "audio.en-US.srt"
    /// ```
    ///
    /// - Parameters:
    ///   - sourceFileName: 原文件名
    ///   - locale: 语言代码
    /// - Returns: 导出文件名
    public static func generateFileName(
        sourceFileName: String,
        locale: String
    ) -> String {
        let baseName = (sourceFileName as NSString).deletingPathExtension
        return "\(baseName).\(locale).srt"
    }
    
    /// 处理文件名冲突
    ///
    /// # 算法说明
    /// 如果文件已存在，自动追加 `-1`, `-2`, ... 后缀，直到找到唯一文件名。
    ///
    /// # 示例
    /// ```
    /// video.zh-Hans.srt (已存在)
    ///   → video.zh-Hans-1.srt (已存在)
    ///   → video.zh-Hans-2.srt (可用)
    /// ```
    ///
    /// - Parameter url: 原始 URL
    /// - Returns: 唯一 URL
    func resolveFileNameConflict(_ url: URL) -> URL {
        let fileManager = FileManager.default
        var counter = 1
        var uniqueURL = url
        
        while fileManager.fileExists(atPath: uniqueURL.path) {
            let directory = url.deletingLastPathComponent()
            let baseName = url.deletingPathExtension().lastPathComponent
            let ext = url.pathExtension
            let newName = "\(baseName)-\(counter).\(ext)"
            uniqueURL = directory.appendingPathComponent(newName)
            counter += 1
        }
        
        return uniqueURL
    }
    
    /// 检查磁盘可用空间
    ///
    /// - Parameters:
    ///   - url: 目标路径
    ///   - requiredBytes: 需要的字节数
    /// - Throws: ExportError.insufficientSpace 如果空间不足
    func checkDiskSpace(at url: URL, requiredBytes: Int64) throws {
        let directory = url.deletingLastPathComponent()
        
        do {
            let values = try directory.resourceValues(
                forKeys: [.volumeAvailableCapacityForImportantUsageKey]
            )
            
            guard let available = values.volumeAvailableCapacityForImportantUsage,
                  available >= requiredBytes else {
                throw ExportError.insufficientSpace(
                    required: requiredBytes,
                    available: values.volumeAvailableCapacityForImportantUsage ?? 0
                )
            }
        } catch let error as ExportError {
            throw error
        } catch {
            // 如果无法获取空间信息，继续执行（某些文件系统不支持）
            // 实际写入时如果空间不足会抛出错误
        }
    }
}
