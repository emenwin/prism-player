/// 诊断信息采集器
/// 用于收集应用状态、日志和指标，生成诊断报告
///
/// Diagnostics collector
/// Collects app state, logs, and metrics to generate diagnostic reports
///
/// 特性:
/// - 自动收集设备和系统信息
/// - 集成指标摘要
/// - 可选包含最近日志
/// - 支持自定义附加信息
/// - JSON 格式导出
///
/// - Created: Sprint 0, Task-007
/// - Last Updated: 2025-01-24

import Foundation
import OSLog

/// 诊断采集器
public actor DiagnosticsCollector {
    /// 关联的指标采集器
    private let metricsCollector: MetricsCollector

    /// 最大日志条数（用于诊断报告）
    private let maxLogEntries: Int

    /// 初始化诊断采集器
    /// - Parameters:
    ///   - metricsCollector: 指标采集器
    ///   - maxLogEntries: 诊断报告中包含的最大日志条数（默认 100）
    public init(
        metricsCollector: MetricsCollector = SharedMetricsCollector.shared,
        maxLogEntries: Int = 100
    ) {
        self.metricsCollector = metricsCollector
        self.maxLogEntries = maxLogEntries
    }

    /// 生成完整的诊断报告
    /// - Parameters:
    ///   - includeLogs: 是否包含最近日志（默认 false，因为 OSLog 读取需要额外权限）
    ///   - additionalInfo: 自定义附加信息
    /// - Returns: 诊断报告
    public func generateReport(
        includeLogs: Bool = false,
        additionalInfo: [String: String]? = nil
    ) async -> DiagnosticReport {
        // 收集指标摘要
        let metrics = await metricsCollector.getSummary()

        // 收集最近日志（可选）
        let logs: [LogEntry]? = includeLogs ? collectRecentLogs() : nil

        return DiagnosticReport(
            timestamp: Date(),
            appVersion: .current,
            deviceInfo: .current,
            systemInfo: .current,
            metrics: metrics,
            recentLogs: logs,
            additionalInfo: additionalInfo
        )
    }

    /// 生成并导出 JSON
    /// - Parameters:
    ///   - includeLogs: 是否包含日志
    ///   - additionalInfo: 附加信息
    /// - Returns: JSON 数据
    public func exportReportJSON(
        includeLogs: Bool = false,
        additionalInfo: [String: String]? = nil
    ) async throws -> Data {
        let report = await generateReport(
            includeLogs: includeLogs,
            additionalInfo: additionalInfo
        )
        return try report.exportJSON()
    }

    /// 生成并保存报告到文件
    /// - Parameters:
    ///   - url: 目标文件 URL
    ///   - includeLogs: 是否包含日志
    ///   - additionalInfo: 附加信息
    public func saveReport(
        to url: URL,
        includeLogs: Bool = false,
        additionalInfo: [String: String]? = nil
    ) async throws {
        let data = try await exportReportJSON(
            includeLogs: includeLogs,
            additionalInfo: additionalInfo
        )
        try data.write(to: url, options: .atomic)

        Logger.lifecycle.info("Diagnostic report saved to: \(url.path)")
    }

    /// 收集最近的日志（占位实现）
    /// 注意：从 OSLog 读取需要额外权限，且 API 复杂，这里先返回空数组
    /// 未来可选使用 OSLogStore API 或自定义日志缓存
    private func collectRecentLogs() -> [LogEntry] {
        // TODO: Sprint 1 - 实现日志读取
        // 可选方案:
        // 1. 使用 OSLogStore (需要 iOS 15+/macOS 12+)
        // 2. 自定义日志缓冲区（内存缓存最近 N 条）
        // 3. 仅在调试模式下启用

        Logger.lifecycle.debug("Log collection not implemented yet, returning empty array")
        return []
    }
}

// MARK: - Shared Instance

extension DiagnosticsCollector {
    /// 共享诊断采集器
    public static let shared = DiagnosticsCollector()
}

// MARK: - Convenience Methods

extension DiagnosticsCollector {
    /// 快速导出诊断报告到临时目录
    /// - Returns: 导出文件的 URL
    public func quickExport() async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "prism-diagnostic-\(Date().timeIntervalSince1970).json"
        let url = tempDir.appendingPathComponent(filename)

        try await saveReport(to: url, includeLogs: false)
        return url
    }

    /// 收集崩溃上下文信息（用于崩溃处理器）
    /// - Returns: 诊断报告的 JSON 字符串
    public func collectCrashContext() async -> String {
        let report = await generateReport(
            includeLogs: false,
            additionalInfo: ["context": "crash"]
        )

        do {
            return try report.exportJSONString()
        } catch {
            Logger.error.error("Failed to export crash context: \(error.localizedDescription)")
            return "{\"error\": \"Failed to collect crash context\"}"
        }
    }
}
