/// 诊断报告数据结构
/// 用于收集应用状态、日志和指标信息，便于问题诊断
///
/// Diagnostic report data structure
/// Used to collect app state, logs, and metrics for troubleshooting
///
/// 用途:
/// - 开发调试时快速定位问题
/// - 生产环境收集崩溃上下文
/// - 性能分析和优化
///
/// - Created: Sprint 0, Task-007
/// - Last Updated: 2025-01-24

import Foundation

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// 诊断报告
public struct DiagnosticReport: Codable {
    /// 报告生成时间
    public let timestamp: Date

    /// 应用版本信息
    public let appVersion: AppVersion

    /// 设备信息
    public let deviceInfo: DeviceInfo

    /// 系统信息
    public let systemInfo: SystemInfo

    /// 性能指标摘要
    public let metrics: MetricsSummary?

    /// 最近日志摘要（可选）
    public let recentLogs: [LogEntry]?

    /// 自定义附加信息
    public let additionalInfo: [String: String]?

    public init(
        timestamp: Date = Date(),
        appVersion: AppVersion,
        deviceInfo: DeviceInfo,
        systemInfo: SystemInfo,
        metrics: MetricsSummary? = nil,
        recentLogs: [LogEntry]? = nil,
        additionalInfo: [String: String]? = nil
    ) {
        self.timestamp = timestamp
        self.appVersion = appVersion
        self.deviceInfo = deviceInfo
        self.systemInfo = systemInfo
        self.metrics = metrics
        self.recentLogs = recentLogs
        self.additionalInfo = additionalInfo
    }
}

// MARK: - App Version

/// 应用版本信息
public struct AppVersion: Codable {
    public let version: String
    public let build: String
    public let bundleIdentifier: String

    public init(version: String, build: String, bundleIdentifier: String) {
        self.version = version
        self.build = build
        self.bundleIdentifier = bundleIdentifier
    }

    /// 从 Bundle 自动获取
    public static var current: AppVersion {
        let bundle = Bundle.main
        return AppVersion(
            version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                ?? "unknown",
            build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            bundleIdentifier: bundle.bundleIdentifier ?? "unknown"
        )
    }
}

// MARK: - Device Info

/// 设备信息
public struct DeviceInfo: Codable {
    public let model: String
    public let name: String
    public let systemName: String
    public let systemVersion: String

    public init(model: String, name: String, systemName: String, systemVersion: String) {
        self.model = model
        self.name = name
        self.systemName = systemName
        self.systemVersion = systemVersion
    }

    /// 从系统自动获取
    public static var current: DeviceInfo {
        #if os(iOS)
            let device = UIDevice.current
            return DeviceInfo(
                model: device.model,
                name: device.name,
                systemName: device.systemName,
                systemVersion: device.systemVersion
            )
        #elseif os(macOS)
            let version = ProcessInfo.processInfo.operatingSystemVersion
            let versionString =
                "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"

            return DeviceInfo(
                model: "Mac",
                name: Host.current().localizedName ?? "Unknown",
                systemName: "macOS",
                systemVersion: versionString
            )
        #else
            return DeviceInfo(
                model: "Unknown",
                name: "Unknown",
                systemName: "Unknown",
                systemVersion: "Unknown"
            )
        #endif
    }
}

// MARK: - System Info

/// 系统信息
public struct SystemInfo: Codable {
    /// 活动处理器核心数
    public let activeProcessorCount: Int

    /// 物理内存大小（字节）
    public let physicalMemory: UInt64

    /// 可用磁盘空间（字节）
    public let diskSpaceAvailable: UInt64?

    /// 系统启动时间
    public let systemUptime: TimeInterval

    public init(
        activeProcessorCount: Int,
        physicalMemory: UInt64,
        diskSpaceAvailable: UInt64?,
        systemUptime: TimeInterval
    ) {
        self.activeProcessorCount = activeProcessorCount
        self.physicalMemory = physicalMemory
        self.diskSpaceAvailable = diskSpaceAvailable
        self.systemUptime = systemUptime
    }

    /// 从系统自动获取
    public static var current: SystemInfo {
        let processInfo = ProcessInfo.processInfo

        // 获取可用磁盘空间
        let diskSpace: UInt64?
        if let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
            .first
        {
            diskSpace =
                try? FileManager.default.attributesOfFileSystem(
                    forPath: path
                )[.systemFreeSize] as? UInt64
        } else {
            diskSpace = nil
        }

        return SystemInfo(
            activeProcessorCount: processInfo.activeProcessorCount,
            physicalMemory: processInfo.physicalMemory,
            diskSpaceAvailable: diskSpace,
            systemUptime: processInfo.systemUptime
        )
    }
}

// MARK: - Log Entry

/// 日志条目（简化版，用于诊断报告）
public struct LogEntry: Codable {
    public let timestamp: Date
    public let category: String
    public let level: String
    public let message: String

    public init(timestamp: Date, category: String, level: String, message: String) {
        self.timestamp = timestamp
        self.category = category
        self.level = level
        self.message = message
    }
}

// MARK: - Export

extension DiagnosticReport {
    /// 导出为 JSON
    public func exportJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// 导出为 JSON 字符串
    public func exportJSONString() throws -> String {
        let data = try exportJSON()
        guard let string = String(data: data, encoding: .utf8) else {
            throw DiagnosticError.encodingFailed
        }
        return string
    }

    /// 从 JSON 导入
    public static func importJSON(_ data: Data) throws -> DiagnosticReport {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(DiagnosticReport.self, from: data)
    }
}

// MARK: - Error

public enum DiagnosticError: Error {
    case encodingFailed
    case decodingFailed
    case invalidData
}
