//
//  TimeIntervalFormattingTests.swift
//  PrismKitTests
//
//  Created by Prism Player on 2025-11-13.
//

import XCTest
@testable import PrismKit

/// TimeInterval 格式化扩展测试
final class TimeIntervalFormattingTests: XCTestCase {
    
    // MARK: - 正常情况测试
    
    /// 测试短时长格式化（小于 1 分钟）
    func testFormatShortDuration() {
        XCTAssertEqual(0.0.formattedTime, "00:00", "0 秒应格式化为 00:00")
        XCTAssertEqual(30.0.formattedTime, "00:30", "30 秒应格式化为 00:30")
        XCTAssertEqual(59.0.formattedTime, "00:59", "59 秒应格式化为 00:59")
    }
    
    /// 测试分钟级时长格式化（1 分钟 ~ 1 小时）
    func testFormatMinutes() {
        XCTAssertEqual(60.0.formattedTime, "01:00", "1 分钟应格式化为 01:00")
        XCTAssertEqual(90.0.formattedTime, "01:30", "1 分 30 秒应格式化为 01:30")
        XCTAssertEqual(600.0.formattedTime, "10:00", "10 分钟应格式化为 10:00")
        XCTAssertEqual(3599.0.formattedTime, "59:59", "59 分 59 秒应格式化为 59:59")
    }
    
    /// 测试小时级时长格式化（≥ 1 小时）
    func testFormatHours() {
        XCTAssertEqual(3600.0.formattedTime, "1:00:00", "1 小时应格式化为 1:00:00")
        XCTAssertEqual(3661.0.formattedTime, "1:01:01", "1 小时 1 分 1 秒应格式化为 1:01:01")
        XCTAssertEqual(7200.0.formattedTime, "2:00:00", "2 小时应格式化为 2:00:00")
        XCTAssertEqual(36000.0.formattedTime, "10:00:00", "10 小时应格式化为 10:00:00")
    }
    
    // MARK: - 边界条件测试
    
    /// 测试零值
    func testFormatZero() {
        XCTAssertEqual(0.0.formattedTime, "00:00", "0 秒应格式化为 00:00")
    }
    
    /// 测试小数秒（应向下取整）
    func testFormatFractionalSeconds() {
        XCTAssertEqual(59.9.formattedTime, "00:59", "59.9 秒应格式化为 00:59（向下取整）")
        XCTAssertEqual(60.5.formattedTime, "01:00", "60.5 秒应格式化为 01:00（向下取整）")
    }
    
    /// 测试大数值
    func testFormatLargeDuration() {
        XCTAssertEqual(86400.0.formattedTime, "24:00:00", "24 小时应格式化为 24:00:00")
        XCTAssertEqual(359999.0.formattedTime, "99:59:59", "99 小时 59 分 59 秒应格式化为 99:59:59")
    }
    
    // MARK: - 异常情况测试
    
    /// 测试负数（应返回默认值）
    func testFormatNegativeValue() {
        XCTAssertEqual((-10.0).formattedTime, "00:00", "负数应返回 00:00")
    }
    
    /// 测试无穷大（应返回默认值）
    func testFormatInfinity() {
        XCTAssertEqual(TimeInterval.infinity.formattedTime, "00:00", "无穷大应返回 00:00")
        XCTAssertEqual((-TimeInterval.infinity).formattedTime, "00:00", "负无穷大应返回 00:00")
    }
    
    /// 测试 NaN（应返回默认值）
    func testFormatNaN() {
        XCTAssertEqual(TimeInterval.nan.formattedTime, "00:00", "NaN 应返回 00:00")
    }
    
    // MARK: - 性能测试
    
    /// 测试格式化性能（1000 次调用应在 0.01 秒内完成）
    func testFormattingPerformance() {
        measure {
            for i in 0..<1000 {
                _ = TimeInterval(i).formattedTime
            }
        }
    }
}
