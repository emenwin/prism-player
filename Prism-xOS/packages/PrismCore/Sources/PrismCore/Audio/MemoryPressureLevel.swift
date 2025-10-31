import Foundation

/// 内存压力等级
///
/// 职责：
/// - 定义内存压力的分级
/// - 用于三级清理策略
///
/// 三级清理策略：
/// - **normal**：正常状态，无需清理
/// - **warning**：内存警告，清理 ±60s 外的缓存
/// - **urgent**：内存紧张，清理 ±30s 外的缓存
/// - **critical**：内存严重不足，仅保留 ±15s，暂停预加载
///
/// 参考：
/// - Task-102 §3.2 差异 2: 内存压力响应策略
/// - Task-102 §4 实施计划 PR3
public enum MemoryPressureLevel: Int, Sendable, Comparable {
    /// 正常状态
    case normal = 0

    /// 内存警告（清理 ±60s 外）
    case warning = 1

    /// 内存紧张（清理 ±30s 外）
    case urgent = 2

    /// 内存严重不足（仅保留 ±15s）
    case critical = 3

    public static func < (lhs: MemoryPressureLevel, rhs: MemoryPressureLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// 保留范围（秒）
    ///
    /// 说明：
    /// - warning: 保留 ±60s
    /// - urgent: 保留 ±30s
    /// - critical: 保留 ±15s
    public var retentionRange: TimeInterval {
        switch self {
        case .normal:
            return .infinity
        case .warning:
            return 60
        case .urgent:
            return 30
        case .critical:
            return 15
        }
    }
}
