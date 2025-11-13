//
//  TimeInterval+Formatting.swift
//  PrismKit
//
//  Created by Prism Player on 2025-11-13.
//

import Foundation

/// TimeInterval 扩展，提供时间格式化功能
/// 用于将时间间隔转换为人类可读的时间字符串格式
extension TimeInterval {
    /// 将时间间隔格式化为 HH:MM:SS 或 MM:SS 格式
    ///
    /// 算法说明：
    /// 1. 提取小时、分钟、秒数
    /// 2. 如果时长超过 1 小时，使用 HH:MM:SS 格式
    /// 3. 否则使用 MM:SS 格式
    ///
    /// - Returns: 格式化后的时间字符串
    ///
    /// 示例：
    /// ```swift
    /// 59.formattedTime      // "00:59"
    /// 90.formattedTime      // "01:30"
    /// 3661.formattedTime    // "1:01:01"
    /// ```
    var formattedTime: String {
        // 处理无效值
        guard self.isFinite && self >= 0 else {
            return "00:00"
        }
        
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        let seconds = Int(self) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}
