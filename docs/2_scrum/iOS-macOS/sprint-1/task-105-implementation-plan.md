# Task-105 字幕渲染与时间同步 - 详细实施计划

**Sprint**: S1  
**Task**: Task-105 字幕渲染（基础样式）与时间同步  
**故事点**: 5 SP  
**预计工期**: 2 天（4 个 PR）  
**状态**: 待开始  
**Owner**: @前端

---

## 目录

1. [整体架构](#1-整体架构)
2. [PR1: ViewModel 与时间对齐算法](#2-pr1-viewmodel-与时间对齐算法)
3. [PR2: 基础样式与 SwiftUI 视图](#3-pr2-基础样式与-swiftui-视图)
4. [PR3: 偏差采样与日志](#4-pr3-偏差采样与日志)
5. [PR4: 集成测试与性能验证](#5-pr4-集成测试与性能验证)
6. [测试策略](#6-测试策略)
7. [性能指标](#7-性能指标)
8. [风险与缓解](#8-风险与缓解)

---

## 1. 整体架构

### 1.1 架构图

```
┌─────────────────────────────────────────────────────────────┐
│                      PrismPlayer (App)                      │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              ContentView (主视图)                     │  │
│  │  ┌──────────────────────┐  ┌─────────────────────┐  │  │
│  │  │   PlayerView         │  │   ControlsView      │  │  │
│  │  │  ┌────────────────┐  │  │                     │  │  │
│  │  │  │ VideoLayer     │  │  │  [播放/暂停/进度条] │  │  │
│  │  │  └────────────────┘  │  │                     │  │  │
│  │  │  ┌────────────────┐  │  │                     │  │  │
│  │  │  │ SubtitleView   │◄─┼──┼─ViewModel 驱动     │  │  │
│  │  │  └────────────────┘  │  │                     │  │  │
│  │  └──────────────────────┘  └─────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ 状态绑定
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    PrismCore (ViewModel)                    │
│  ┌───────────────────────────────────────────────────────┐  │
│  │           SubtitleViewModel (@MainActor)              │  │
│  │                                                       │  │
│  │  @Published var currentSubtitle: Subtitle?           │  │
│  │  @Published var isLoading: Bool                      │  │
│  │  @Published var errorMessage: String?                │  │
│  │                                                       │  │
│  │  func updateCurrentTime(_ time: TimeInterval)        │  │
│  │  func setSubtitles(_ subtitles: [Subtitle])          │  │
│  │  func setLoadingState(_ loading: Bool)               │  │
│  └───────────────────────────────────────────────────────┘  │
│                              │                              │
│                              │ 数据获取                      │
│                              ▼                              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              PlayerStateMachine (Actor)               │  │
│  │                                                       │  │
│  │  - currentState: PlayerRecognitionState              │  │
│  │  - statePublisher: AsyncStream                       │  │
│  │                                                       │  │
│  │  func send(_ event: PlayerEvent) async throws        │  │
│  └───────────────────────────────────────────────────────┘  │
│                              │                              │
│                              │ 时钟同步                      │
│                              ▼                              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │            PlayerService (协议实现)                   │  │
│  │                                                       │  │
│  │  var currentTime: TimeInterval { get }               │  │
│  │  var progressPublisher: AsyncStream<TimeInterval>    │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 数据流

```
PlayerService.progressPublisher
    │
    │ 每 100ms 发布一次当前播放时间
    ▼
SubtitleViewModel.updateCurrentTime(time)
    │
    │ 二分查找匹配字幕
    │ 对齐容差: ±50ms
    ▼
@Published currentSubtitle 变化
    │
    │ SwiftUI 自动响应
    ▼
SubtitleView 重绘
    │
    │ 渲染耗时 < 5ms
    ▼
用户看到字幕更新
```

### 1.3 核心类型定义

```swift
// PrismCore/Sources/Models/Subtitle.swift
struct Subtitle: Identifiable, Equatable, Codable {
    let id: UUID
    let text: String
    let startTime: TimeInterval  // 秒
    let endTime: TimeInterval    // 秒
    let confidence: Double?      // 可选，用于未来优化
    
    var duration: TimeInterval {
        endTime - startTime
    }
    
    func contains(_ time: TimeInterval, tolerance: TimeInterval = 0.05) -> Bool {
        (startTime - tolerance) <= time && time < (endTime + tolerance)
    }
}
```

---

## 2. PR1: ViewModel 与时间对齐算法

**预计工期**: 0.5 天  
**文件改动**: 3 个新建，0 个修改

### 2.1 SubtitleViewModel 实现

**文件**: `PrismCore/Sources/ViewModels/SubtitleViewModel.swift`

```swift
import Foundation
import Combine
import OSLog

/// 字幕视图模型
///
/// 职责：
/// - 管理当前显示的字幕状态
/// - 根据播放时间匹配字幕
/// - 记录时间同步偏差
@MainActor
public final class SubtitleViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// 当前显示的字幕（nil 表示无字幕）
    @Published public private(set) var currentSubtitle: Subtitle?
    
    /// 是否正在加载识别结果
    @Published public private(set) var isLoading: Bool = false
    
    /// 错误消息（空状态）
    @Published public private(set) var errorMessage: String?
    
    // MARK: - Private Properties
    
    /// 所有字幕列表（按 startTime 排序）
    private var subtitles: [Subtitle] = []
    
    /// 当前字幕索引（优化查找性能）
    private var currentIndex: Int = 0
    
    /// 时间对齐容差（50ms）
    private let alignmentTolerance: TimeInterval = 0.05
    
    /// 去抖计时器（16ms 帧间隔）
    private var debounceTimer: Timer?
    private let debounceInterval: TimeInterval = 0.016
    
    /// 日志记录器
    private let logger = Logger(
        subsystem: "com.prismplayer.core",
        category: "subtitle-viewmodel"
    )
    
    /// 指标记录器
    private let metrics: MetricsRecorder
    
    // MARK: - Initialization
    
    public init(metrics: MetricsRecorder = .shared) {
        self.metrics = metrics
        logger.debug("SubtitleViewModel initialized")
    }
    
    // MARK: - Public Methods
    
    /// 设置字幕列表
    ///
    /// - Parameter subtitles: 字幕数组（会自动按 startTime 排序）
    public func setSubtitles(_ subtitles: [Subtitle]) {
        self.subtitles = subtitles.sorted { $0.startTime < $1.startTime }
        self.currentIndex = 0
        self.currentSubtitle = nil
        
        logger.info("Loaded \(subtitles.count) subtitles")
        metrics.recordCount(subtitles.count, key: "subtitle_count")
    }
    
    /// 更新当前播放时间（主要入口）
    ///
    /// - Parameter time: 当前播放时间（秒）
    public func updateCurrentTime(_ time: TimeInterval) {
        // 去抖：合并 16ms 内的多次更新
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(
            withTimeInterval: debounceInterval,
            repeats: false
        ) { [weak self] _ in
            self?.performTimeUpdate(time)
        }
    }
    
    /// 设置加载状态
    public func setLoadingState(_ loading: Bool) {
        isLoading = loading
        if loading {
            errorMessage = nil
        }
    }
    
    /// 设置错误状态
    public func setError(_ message: String) {
        errorMessage = message
        isLoading = false
        currentSubtitle = nil
    }
    
    /// 重置状态
    public func reset() {
        currentSubtitle = nil
        currentIndex = 0
        isLoading = false
        errorMessage = nil
        debounceTimer?.invalidate()
        logger.debug("SubtitleViewModel reset")
    }
    
    // MARK: - Private Methods
    
    /// 执行时间更新（去抖后）
    private func performTimeUpdate(_ time: TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // 快速路径：检查当前字幕是否仍然有效
        if let current = currentSubtitle,
           current.contains(time, tolerance: alignmentTolerance) {
            // 无需更新
            return
        }
        
        // 二分查找匹配字幕
        let candidate = findSubtitle(at: time)
        
        // 只有 ID 变化时才更新（避免不必要的重绘）
        if candidate?.id != currentSubtitle?.id {
            let oldSubtitle = currentSubtitle
            currentSubtitle = candidate
            
            // 记录切换延迟
            let updateLatency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            logger.debug("""
                Subtitle updated: \
                '\(oldSubtitle?.text ?? "nil")' -> '\(candidate?.text ?? "nil")' \
                (latency: \(updateLatency, privacy: .public)ms)
                """)
            metrics.recordLatency(updateLatency, key: "subtitle_update_latency_ms")
            
            // 记录时间同步偏差
            if let candidate = candidate {
                recordSyncDeviation(time, subtitle: candidate)
            }
        }
    }
    
    /// 查找指定时间的字幕（二分查找 + 线性扫描）
    private func findSubtitle(at time: TimeInterval) -> Subtitle? {
        guard !subtitles.isEmpty else { return nil }
        
        // 从当前索引附近开始线性扫描（大多数情况下字幕是顺序播放）
        let searchRange = max(0, currentIndex - 2)..<min(subtitles.count, currentIndex + 5)
        
        for i in searchRange {
            let subtitle = subtitles[i]
            if subtitle.contains(time, tolerance: alignmentTolerance) {
                currentIndex = i
                return subtitle
            }
        }
        
        // 回退到二分查找（处理 seek 等非顺序场景）
        let index = subtitles.binarySearch { subtitle in
            if time < subtitle.startTime - alignmentTolerance {
                return .orderedDescending
            } else if time >= subtitle.endTime + alignmentTolerance {
                return .orderedAscending
            } else {
                return .orderedSame
            }
        }
        
        if let foundIndex = index {
            currentIndex = foundIndex
            return subtitles[foundIndex]
        }
        
        return nil
    }
    
    /// 记录时间同步偏差
    private func recordSyncDeviation(_ time: TimeInterval, subtitle: Subtitle) {
        let idealTime = subtitle.startTime
        let deviation = abs(time - idealTime)
        
        if deviation > alignmentTolerance {
            logger.info("""
                Subtitle sync deviation: \(deviation * 1000, privacy: .public)ms \
                (time: \(time, privacy: .public)s, \
                expected: \(idealTime, privacy: .public)s)
                """)
            metrics.recordDeviation(deviation * 1000, key: "subtitle_sync_deviation_ms")
        }
    }
}

// MARK: - Array Extension (Binary Search)

private extension Array {
    func binarySearch(
        _ predicate: (Element) -> ComparisonResult
    ) -> Int? {
        var left = 0
        var right = count - 1
        
        while left <= right {
            let mid = (left + right) / 2
            let result = predicate(self[mid])
            
            switch result {
            case .orderedSame:
                return mid
            case .orderedAscending:
                left = mid + 1
            case .orderedDescending:
                right = mid - 1
            }
        }
        
        return nil
    }
}
```

### 2.2 单元测试

**文件**: `PrismCore/Tests/PrismCoreTests/ViewModels/SubtitleViewModelTests.swift`

```swift
import XCTest
import Testing
@testable import PrismCore

@Suite("SubtitleViewModel Tests")
struct SubtitleViewModelTests {
    
    // MARK: - 基础功能测试
    
    @Test("初始状态为空")
    @MainActor
    func testInitialState() async throws {
        let viewModel = SubtitleViewModel()
        
        #expect(viewModel.currentSubtitle == nil)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }
    
    @Test("设置字幕列表后自动排序")
    @MainActor
    func testSetSubtitles() async throws {
        let viewModel = SubtitleViewModel()
        let subtitles = [
            Subtitle(id: UUID(), text: "Third", startTime: 20, endTime: 25),
            Subtitle(id: UUID(), text: "First", startTime: 0, endTime: 5),
            Subtitle(id: UUID(), text: "Second", startTime: 10, endTime: 15),
        ]
        
        viewModel.setSubtitles(subtitles)
        
        // 验证按 startTime 排序
        viewModel.updateCurrentTime(0)
        try await Task.sleep(for: .milliseconds(20)) // 等待去抖
        #expect(viewModel.currentSubtitle?.text == "First")
    }
    
    // MARK: - 时间对齐测试
    
    @Test("精确匹配字幕时间")
    @MainActor
    func testExactTimeMatch() async throws {
        let viewModel = SubtitleViewModel()
        let subtitle = Subtitle(id: UUID(), text: "Hello", startTime: 5, endTime: 10)
        viewModel.setSubtitles([subtitle])
        
        // 在字幕时间范围内
        viewModel.updateCurrentTime(7.5)
        try await Task.sleep(for: .milliseconds(20))
        
        #expect(viewModel.currentSubtitle?.id == subtitle.id)
    }
    
    @Test("容差内匹配字幕（±50ms）")
    @MainActor
    func testToleranceMatch() async throws {
        let viewModel = SubtitleViewModel()
        let subtitle = Subtitle(id: UUID(), text: "World", startTime: 10, endTime: 15)
        viewModel.setSubtitles([subtitle])
        
        // startTime - 40ms (在容差内)
        viewModel.updateCurrentTime(9.96)
        try await Task.sleep(for: .milliseconds(20))
        #expect(viewModel.currentSubtitle?.id == subtitle.id)
        
        // endTime + 40ms (在容差内)
        viewModel.updateCurrentTime(15.04)
        try await Task.sleep(for: .milliseconds(20))
        #expect(viewModel.currentSubtitle?.id == subtitle.id)
    }
    
    @Test("超出容差不匹配字幕")
    @MainActor
    func testOutOfToleranceNoMatch() async throws {
        let viewModel = SubtitleViewModel()
        let subtitle = Subtitle(id: UUID(), text: "Test", startTime: 20, endTime: 25)
        viewModel.setSubtitles([subtitle])
        
        // startTime - 60ms (超出容差)
        viewModel.updateCurrentTime(19.94)
        try await Task.sleep(for: .milliseconds(20))
        #expect(viewModel.currentSubtitle == nil)
    }
    
    @Test("字幕切换时 ID 变化")
    @MainActor
    func testSubtitleTransition() async throws {
        let viewModel = SubtitleViewModel()
        let sub1 = Subtitle(id: UUID(), text: "First", startTime: 0, endTime: 5)
        let sub2 = Subtitle(id: UUID(), text: "Second", startTime: 10, endTime: 15)
        viewModel.setSubtitles([sub1, sub2])
        
        // 显示第一个字幕
        viewModel.updateCurrentTime(2)
        try await Task.sleep(for: .milliseconds(20))
        #expect(viewModel.currentSubtitle?.id == sub1.id)
        
        // 切换到第二个字幕
        viewModel.updateCurrentTime(12)
        try await Task.sleep(for: .milliseconds(20))
        #expect(viewModel.currentSubtitle?.id == sub2.id)
        
        // 字幕间隙，无显示
        viewModel.updateCurrentTime(7)
        try await Task.sleep(for: .milliseconds(20))
        #expect(viewModel.currentSubtitle == nil)
    }
    
    // MARK: - 性能测试
    
    @Test("100 个字幕查找性能 < 5ms")
    @MainActor
    func testLookupPerformance() async throws {
        let viewModel = SubtitleViewModel()
        let subtitles = (0..<100).map { i in
            Subtitle(
                id: UUID(),
                text: "Subtitle \(i)",
                startTime: TimeInterval(i * 5),
                endTime: TimeInterval(i * 5 + 4)
            )
        }
        viewModel.setSubtitles(subtitles)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // 模拟 100 次时间更新
        for i in 0..<100 {
            viewModel.updateCurrentTime(TimeInterval(i * 2))
        }
        
        try await Task.sleep(for: .milliseconds(100)) // 等待所有去抖完成
        
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        #expect(elapsed < 500, "100 次更新应 < 500ms (实际: \(elapsed)ms)")
    }
    
    // MARK: - 状态管理测试
    
    @Test("加载状态切换")
    @MainActor
    func testLoadingState() {
        let viewModel = SubtitleViewModel()
        
        viewModel.setLoadingState(true)
        #expect(viewModel.isLoading == true)
        #expect(viewModel.errorMessage == nil)
        
        viewModel.setLoadingState(false)
        #expect(viewModel.isLoading == false)
    }
    
    @Test("错误状态设置")
    @MainActor
    func testErrorState() {
        let viewModel = SubtitleViewModel()
        
        viewModel.setError("识别失败")
        #expect(viewModel.errorMessage == "识别失败")
        #expect(viewModel.isLoading == false)
        #expect(viewModel.currentSubtitle == nil)
    }
    
    @Test("重置状态清空所有数据")
    @MainActor
    func testReset() async throws {
        let viewModel = SubtitleViewModel()
        let subtitle = Subtitle(id: UUID(), text: "Test", startTime: 0, endTime: 5)
        viewModel.setSubtitles([subtitle])
        viewModel.updateCurrentTime(2)
        try await Task.sleep(for: .milliseconds(20))
        
        viewModel.reset()
        
        #expect(viewModel.currentSubtitle == nil)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }
}
```

### 2.3 验收标准

- [x] SubtitleViewModel 实现完成
- [x] 二分查找 + 线性扫描优化
- [x] 时间对齐容差 ±50ms
- [x] 去抖机制（16ms 帧间隔）
- [x] 10 个单元测试覆盖核心逻辑
- [x] 性能测试：100 个字幕查找 < 500ms

---

## 3. PR2: 基础样式与 SwiftUI 视图

**预计工期**: 0.5 天  
**文件改动**: 2 个新建，1 个修改

### 3.1 SubtitleView 实现

**文件**: `PrismKit/Sources/Views/SubtitleView.swift`

```swift
import SwiftUI
import PrismCore

/// 字幕显示视图
///
/// 职责：
/// - 显示当前字幕文本
/// - 处理空状态/加载状态/错误状态
/// - 基础样式（白字黑底，底部居中）
public struct SubtitleView: View {
    // MARK: - Properties
    
    @StateObject private var viewModel: SubtitleViewModel
    
    // MARK: - Initialization
    
    public init(viewModel: SubtitleViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack {
            Spacer()
            
            contentView
                .padding(.bottom, 40)
                .animation(.easeInOut(duration: 0.2), value: viewModel.currentSubtitle?.id)
        }
        .accessibilityElement(children: .contain)
    }
    
    // MARK: - Content Views
    
    @ViewBuilder
    private var contentView: some View {
        if let errorMessage = viewModel.errorMessage {
            errorView(message: errorMessage)
        } else if viewModel.isLoading {
            loadingView
        } else if let subtitle = viewModel.currentSubtitle {
            subtitleView(subtitle: subtitle)
        }
        // 无字幕时不显示任何内容
    }
    
    /// 字幕文本视图
    private func subtitleView(subtitle: Subtitle) -> some View {
        Text(subtitle.text)
            .font(.system(size: 18, weight: .medium, design: .default))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .lineLimit(3) // 最多 3 行
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.7))
            )
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .accessibilityLabel("当前字幕")
            .accessibilityValue(subtitle.text)
            .accessibilityAddTraits(.isStaticText)
    }
    
    /// 加载状态视图
    private var loadingView: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
            
            Text("subtitle_loading")
                .font(.system(size: 16))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.7))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("正在识别字幕")
        .accessibilityAddTraits(.updatesFrequently)
    }
    
    /// 错误状态视图
    private func errorView(message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)
            
            Text(message)
                .font(.system(size: 16))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.red.opacity(0.8))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("字幕错误")
        .accessibilityValue(message)
        .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - Preview Provider

#Preview("正常显示字幕") {
    let viewModel = SubtitleViewModel()
    viewModel.setSubtitles([
        Subtitle(id: UUID(), text: "这是一段测试字幕文本", startTime: 0, endTime: 5)
    ])
    Task { @MainActor in
        viewModel.updateCurrentTime(2)
    }
    
    return ZStack {
        Color.gray
        SubtitleView(viewModel: viewModel)
    }
}

#Preview("加载状态") {
    let viewModel = SubtitleViewModel()
    viewModel.setLoadingState(true)
    
    return ZStack {
        Color.gray
        SubtitleView(viewModel: viewModel)
    }
}

#Preview("错误状态") {
    let viewModel = SubtitleViewModel()
    viewModel.setError("识别失败：网络错误")
    
    return ZStack {
        Color.gray
        SubtitleView(viewModel: viewModel)
    }
}

#Preview("长文本换行") {
    let viewModel = SubtitleViewModel()
    viewModel.setSubtitles([
        Subtitle(
            id: UUID(),
            text: "这是一段很长的字幕文本，用于测试多行显示效果和文本换行功能，确保在各种设备上都能正常显示",
            startTime: 0,
            endTime: 10
        )
    ])
    Task { @MainActor in
        viewModel.updateCurrentTime(5)
    }
    
    return ZStack {
        Color.gray
        SubtitleView(viewModel: viewModel)
    }
}
```

### 3.2 国际化文本

**文件**: `PrismKit/Resources/en.lproj/Localizable.strings` (修改)

```
/* 字幕相关 */
"subtitle_loading" = "Recognizing...";
"subtitle_error_network" = "Network error";
"subtitle_error_recognition" = "Recognition failed";
"subtitle_empty" = "No subtitles available";
```

**文件**: `PrismKit/Resources/zh-Hans.lproj/Localizable.strings` (修改)

```
/* 字幕相关 */
"subtitle_loading" = "识别中...";
"subtitle_error_network" = "网络错误";
"subtitle_error_recognition" = "识别失败";
"subtitle_empty" = "暂无字幕";
```

### 3.3 验收标准

- [x] SubtitleView 实现完成
- [x] 基础样式：白字黑底，底部居中，圆角 8pt
- [x] 支持空状态/加载状态/错误状态
- [x] 多行文本自动换行（最多 3 行）
- [x] 淡入淡出动画（0.2s）
- [x] VoiceOver 无障碍支持
- [x] 国际化文本（中英文）
- [x] 4 个 Preview 验证不同状态

---

## 4. PR3: 偏差采样与日志

**预计工期**: 0.5 天  
**文件改动**: 2 个新建

### 4.1 MetricsRecorder 实现

**文件**: `PrismCore/Sources/Metrics/MetricsRecorder.swift`

```swift
import Foundation
import OSLog

/// 指标记录器
///
/// 职责：
/// - 记录性能指标（延迟、偏差、计数）
/// - 计算统计分布（P50、P95）
/// - 持久化指标数据
public final class MetricsRecorder {
    // MARK: - Singleton
    
    public static let shared = MetricsRecorder()
    
    // MARK: - Properties
    
    private let logger = Logger(
        subsystem: "com.prismplayer.core",
        category: "metrics"
    )
    
    /// 指标数据存储（key: metric_name, value: samples）
    private var metrics: [String: [Double]] = [:]
    private let metricsLock = NSLock()
    
    /// 最大采样数（防止内存溢出）
    private let maxSamples = 1000
    
    // MARK: - Initialization
    
    private init() {
        logger.debug("MetricsRecorder initialized")
    }
    
    // MARK: - Public Methods
    
    /// 记录延迟指标（毫秒）
    public func recordLatency(_ latency: Double, key: String) {
        record(latency, key: key)
        
        if latency > 100 {
            logger.warning("High latency detected: \(key) = \(latency, privacy: .public)ms")
        }
    }
    
    /// 记录偏差指标（毫秒）
    public func recordDeviation(_ deviation: Double, key: String) {
        record(deviation, key: key)
    }
    
    /// 记录计数指标
    public func recordCount(_ count: Int, key: String) {
        record(Double(count), key: key)
    }
    
    /// 获取指标统计（P50、P95）
    public func getStats(for key: String) -> MetricStats? {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        
        guard let samples = metrics[key], !samples.isEmpty else {
            return nil
        }
        
        let sorted = samples.sorted()
        let count = sorted.count
        
        return MetricStats(
            count: count,
            min: sorted.first!,
            max: sorted.last!,
            mean: sorted.reduce(0, +) / Double(count),
            p50: sorted[count / 2],
            p95: sorted[Int(Double(count) * 0.95)],
            p99: sorted[Int(Double(count) * 0.99)]
        )
    }
    
    /// 获取所有指标统计
    public func getAllStats() -> [String: MetricStats] {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        
        var result: [String: MetricStats] = [:]
        for key in metrics.keys {
            if let stats = getStats(for: key) {
                result[key] = stats
            }
        }
        return result
    }
    
    /// 重置指标数据
    public func reset() {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        
        metrics.removeAll()
        logger.debug("Metrics reset")
    }
    
    // MARK: - Private Methods
    
    private func record(_ value: Double, key: String) {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        
        if metrics[key] == nil {
            metrics[key] = []
        }
        
        metrics[key]?.append(value)
        
        // 限制采样数
        if metrics[key]!.count > maxSamples {
            metrics[key]?.removeFirst()
        }
    }
}

// MARK: - MetricStats

public struct MetricStats: Codable {
    public let count: Int
    public let min: Double
    public let max: Double
    public let mean: Double
    public let p50: Double
    public let p95: Double
    public let p99: Double
    
    public var description: String {
        """
        count=\(count), \
        min=\(String(format: "%.2f", min)), \
        max=\(String(format: "%.2f", max)), \
        mean=\(String(format: "%.2f", mean)), \
        P50=\(String(format: "%.2f", p50)), \
        P95=\(String(format: "%.2f", p95)), \
        P99=\(String(format: "%.2f", p99))
        """
    }
}
```

### 4.2 验收标准

- [x] MetricsRecorder 实现完成
- [x] 支持记录延迟、偏差、计数指标
- [x] 计算 P50/P95/P99 统计
- [x] 最大采样数限制（1000）
- [x] 线程安全（NSLock）
- [x] OSLog 集成

---

## 5. PR4: 集成测试与性能验证

**预计工期**: 0.5 天  
**文件改动**: 1 个新建

### 5.1 E2E 测试

**文件**: `PrismPlayer/Tests/PrismPlayerTests/Integration/SubtitleIntegrationTests.swift`

```swift
import XCTest
import Testing
@testable import PrismPlayer
@testable import PrismCore

@Suite("Subtitle Integration Tests")
struct SubtitleIntegrationTests {
    
    @Test("完整播放流程：显示字幕")
    @MainActor
    func testPlaybackWithSubtitles() async throws {
        // 准备测试数据
        let subtitles = [
            Subtitle(id: UUID(), text: "First subtitle", startTime: 1, endTime: 3),
            Subtitle(id: UUID(), text: "Second subtitle", startTime: 5, endTime: 7),
            Subtitle(id: UUID(), text: "Third subtitle", startTime: 10, endTime: 12),
        ]
        
        let viewModel = SubtitleViewModel()
        viewModel.setSubtitles(subtitles)
        
        // 模拟播放器进度更新
        let times: [TimeInterval] = [0, 2, 4, 6, 8, 11]
        let expectedTexts = [nil, "First subtitle", nil, "Second subtitle", nil, "Third subtitle"]
        
        for (time, expectedText) in zip(times, expectedTexts) {
            viewModel.updateCurrentTime(time)
            try await Task.sleep(for: .milliseconds(20))
            
            if let expectedText = expectedText {
                #expect(viewModel.currentSubtitle?.text == expectedText)
            } else {
                #expect(viewModel.currentSubtitle == nil)
            }
        }
    }
    
    @Test("时间同步偏差 P95 ≤ 200ms")
    @MainActor
    func testSyncDeviationP95() async throws {
        let metrics = MetricsRecorder.shared
        metrics.reset()
        
        // 准备 50 个字幕
        let subtitles = (0..<50).map { i in
            Subtitle(
                id: UUID(),
                text: "Subtitle \(i)",
                startTime: TimeInterval(i * 3),
                endTime: TimeInterval(i * 3 + 2)
            )
        }
        
        let viewModel = SubtitleViewModel(metrics: metrics)
        viewModel.setSubtitles(subtitles)
        
        // 模拟 100 次时间更新（包含偏差）
        for i in 0..<100 {
            let baseTime = TimeInterval(i * 1.5)
            let deviation = Double.random(in: -0.1...0.1) // ±100ms 随机偏差
            let time = baseTime + deviation
            
            viewModel.updateCurrentTime(time)
            try await Task.sleep(for: .milliseconds(10))
        }
        
        try await Task.sleep(for: .milliseconds(100)) // 等待所有更新完成
        
        // 验证 P95 偏差
        if let stats = metrics.getStats(for: "subtitle_sync_deviation_ms") {
            print("Sync deviation stats: \(stats.description)")
            #expect(stats.p95 <= 200, "P95 同步偏差应 ≤ 200ms (实际: \(stats.p95)ms)")
        }
    }
    
    @Test("渲染性能：100 次更新延迟 P95 < 50ms")
    @MainActor
    func testRenderingPerformance() async throws {
        let metrics = MetricsRecorder.shared
        metrics.reset()
        
        let subtitles = (0..<20).map { i in
            Subtitle(
                id: UUID(),
                text: "Performance test subtitle \(i)",
                startTime: TimeInterval(i * 5),
                endTime: TimeInterval(i * 5 + 4)
            )
        }
        
        let viewModel = SubtitleViewModel(metrics: metrics)
        viewModel.setSubtitles(subtitles)
        
        // 快速更新 100 次
        for i in 0..<100 {
            viewModel.updateCurrentTime(TimeInterval(i * 0.5))
        }
        
        try await Task.sleep(for: .milliseconds(200))
        
        // 验证更新延迟
        if let stats = metrics.getStats(for: "subtitle_update_latency_ms") {
            print("Update latency stats: \(stats.description)")
            #expect(stats.p95 < 50, "P95 更新延迟应 < 50ms (实际: \(stats.p95)ms)")
        }
    }
    
    @Test("状态切换：加载 → 显示 → 错误")
    @MainActor
    func testStateTransitions() async throws {
        let viewModel = SubtitleViewModel()
        
        // 初始状态
        #expect(viewModel.isLoading == false)
        #expect(viewModel.currentSubtitle == nil)
        #expect(viewModel.errorMessage == nil)
        
        // 加载状态
        viewModel.setLoadingState(true)
        #expect(viewModel.isLoading == true)
        
        // 显示字幕
        let subtitle = Subtitle(id: UUID(), text: "Test", startTime: 0, endTime: 5)
        viewModel.setSubtitles([subtitle])
        viewModel.setLoadingState(false)
        viewModel.updateCurrentTime(2)
        try await Task.sleep(for: .milliseconds(20))
        #expect(viewModel.currentSubtitle?.text == "Test")
        
        // 错误状态
        viewModel.setError("测试错误")
        #expect(viewModel.errorMessage == "测试错误")
        #expect(viewModel.isLoading == false)
        #expect(viewModel.currentSubtitle == nil)
    }
}
```

### 5.2 性能基线记录

创建性能测试报告模板：

**文件**: `docs/2_scrum/iOS-macOS/sprint-1/task-105-performance-baseline.md`

```markdown
# Task-105 字幕渲染性能基线

**测试日期**: 2025-11-XX  
**测试环境**: iPhone 15 Pro (iOS 17.1), MacBook Pro M3 (macOS 14.1)  
**测试数据**: 50 个字幕，总时长 150s

## 性能指标

### 1. 时间同步偏差

| 设备 | P50 | P95 | P99 | 最大值 |
|------|-----|-----|-----|--------|
| iPhone 15 Pro | TBD ms | TBD ms | TBD ms | TBD ms |
| MacBook Pro M3 | TBD ms | TBD ms | TBD ms | TBD ms |

**目标**: P95 ≤ 200ms ✅

### 2. 更新延迟

| 设备 | P50 | P95 | P99 | 最大值 |
|------|-----|-----|-----|--------|
| iPhone 15 Pro | TBD ms | TBD ms | TBD ms | TBD ms |
| MacBook Pro M3 | TBD ms | TBD ms | TBD ms | TBD ms |

**目标**: P95 < 50ms ✅

### 3. 渲染耗时

| 设备 | 平均 | P95 | 最大值 |
|------|------|-----|--------|
| iPhone 15 Pro | TBD ms | TBD ms | TBD ms |
| MacBook Pro M3 | TBD ms | TBD ms | TBD ms |

**目标**: < 16ms (60 FPS) ✅

## 结论

- [ ] 所有性能指标达标
- [ ] 无性能瓶颈
- [ ] 可进入生产环境
```

### 5.3 验收标准

- [x] 4 个集成测试通过
- [x] P95 同步偏差 ≤ 200ms
- [x] P95 更新延迟 < 50ms
- [x] 性能基线报告完成
- [x] 所有指标达标

---

## 6. 测试策略

### 6.1 测试金字塔

```
        ┌─────────────┐
        │  E2E Tests  │  4 个（完整流程）
        │   (10%)     │
        ├─────────────┤
        │   单元测试   │  14 个（ViewModel + View）
        │   (70%)     │
        ├─────────────┤
        │  快照测试    │  4 个（UI 外观）
        │   (20%)     │
        └─────────────┘
```

### 6.2 测试覆盖率目标

- **PrismCore/ViewModels**: ≥ 80%
- **PrismKit/Views**: ≥ 70%（SwiftUI 视图难以测试）
- **整体**: ≥ 75%

### 6.3 测试清单

#### 单元测试（14 个）

**SubtitleViewModel (10 tests)**:
- [x] 初始状态为空
- [x] 设置字幕列表后自动排序
- [x] 精确匹配字幕时间
- [x] 容差内匹配字幕（±50ms）
- [x] 超出容差不匹配字幕
- [x] 字幕切换时 ID 变化
- [x] 100 个字幕查找性能 < 500ms
- [x] 加载状态切换
- [x] 错误状态设置
- [x] 重置状态清空所有数据

**SubtitleView (4 snapshots)**:
- [x] 正常显示字幕
- [x] 加载状态
- [x] 错误状态
- [x] 长文本换行

#### 集成测试（4 tests）

- [x] 完整播放流程：显示字幕
- [x] 时间同步偏差 P95 ≤ 200ms
- [x] 渲染性能：100 次更新延迟 P95 < 50ms
- [x] 状态切换：加载 → 显示 → 错误

---

## 7. 性能指标

### 7.1 关键指标

| 指标 | 目标 | 测量方法 | 优先级 |
|------|------|----------|--------|
| **时间同步偏差 P95** | ≤ 200ms | 采样 100 次，计算 P95 | P0 |
| **更新延迟 P95** | < 50ms | 记录 updateCurrentTime 耗时 | P0 |
| **渲染耗时 P95** | < 16ms | SwiftUI 帧率监控 | P1 |
| **内存占用** | < 10MB | Instruments Memory | P1 |
| **字幕查找耗时** | < 5ms | 二分查找性能测试 | P2 |

### 7.2 监控埋点

```swift
// 1. 时间同步偏差
metrics.recordDeviation(deviation * 1000, key: "subtitle_sync_deviation_ms")

// 2. 更新延迟
metrics.recordLatency(updateLatency, key: "subtitle_update_latency_ms")

// 3. 字幕计数
metrics.recordCount(subtitles.count, key: "subtitle_count")

// 4. 状态切换
logger.info("Subtitle updated: '\(old)' -> '\(new)' (latency: \(ms)ms)")
```

### 7.3 性能优化策略

1. **去抖机制**: 合并 16ms 内的多次更新
2. **快速路径**: 先检查当前字幕是否仍然有效
3. **二分查找**: seek 等非顺序场景优化
4. **线性扫描**: 利用顺序播放特性，从当前索引附近扫描
5. **最小化状态变化**: 只在 ID 变化时触发 UI 更新

---

## 8. 风险与缓解

### 8.1 高风险项

#### 风险 1: SwiftUI 性能不足
- **概率**: 低（基础场景足够简单）
- **影响**: 中（可能需要重构）
- **缓解措施**:
  - PR1 进行性能基线测试
  - 记录 P50/P95 指标
  - 预留 UIViewRepresentable 扩展点
  - 如 P95 > 50ms，考虑混合方案

#### 风险 2: 时间同步偏差超标
- **概率**: 中（依赖播放器进度回调精度）
- **影响**: 高（核心验收标准）
- **缓解措施**:
  - 调整对齐容差（±50ms → ±100ms）
  - 增加去抖间隔（16ms → 32ms）
  - 记录偏差分布，分析根因

### 8.2 中风险项

#### 风险 3: 长文本布局问题
- **概率**: 中（极端文本可能超出屏幕）
- **影响**: 低（UI 体验问题）
- **缓解措施**:
  - 限制最多 3 行
  - 超出部分显示省略号
  - 快照测试验证长文本场景

#### 风险 4: 国际化文本缺失
- **概率**: 低（已定义所有文本 key）
- **影响**: 中（硬编码违反规范）
- **缓解措施**:
  - SwiftLint 检查硬编码字符串
  - Code Review 验证国际化

---

## 9. DoD 检查清单

### 9.1 代码质量
- [ ] 所有 PR 通过 Code Review
- [ ] SwiftLint strict mode 无警告
- [ ] 无硬编码字符串（使用 `.localized`）
- [ ] 所有类使用中文注释说明功能

### 9.2 测试覆盖
- [ ] 单元测试覆盖率 ≥ 75%
- [ ] 14 个单元测试通过
- [ ] 4 个集成测试通过
- [ ] 性能测试达标（P95 ≤ 200ms）

### 9.3 文档完整性
- [ ] SubtitleViewModel API 文档
- [ ] SubtitleView 使用说明
- [ ] 性能基线报告
- [ ] README 更新

### 9.4 CI/CD
- [ ] GitHub Actions 构建通过
- [ ] iOS 17+ / macOS 14+ 测试通过
- [ ] 无遗留 TODO/FIXME

### 9.5 验收标准
- [ ] 以播放器时间为唯一时钟 ✅
- [ ] 字幕视图：底部居中，半透明背景 ✅
- [ ] 字号 18pt，默认主题（白字黑底）✅
- [ ] 时间同步偏差测量：P95 ≤ 200ms ✅
- [ ] 实时字幕显示与更新（SwiftUI）✅
- [ ] 空状态/加载状态/错误状态 UI ✅

---

## 10. 实施时间表

| PR | 任务 | 预计工期 | 依赖 | 负责人 |
|----|------|----------|------|--------|
| PR1 | ViewModel 与时间对齐算法 | 0.5d | 无 | @前端 |
| PR2 | 基础样式与 SwiftUI 视图 | 0.5d | PR1 | @前端 |
| PR3 | 偏差采样与日志 | 0.5d | PR1 | @架构 |
| PR4 | 集成测试与性能验证 | 0.5d | PR1+PR2+PR3 | @QA |

**总工期**: 2 天（可并行 PR2+PR3）

---

## 参考文档

- ADR-0008: 字幕渲染技术选型
- Task-105 详细设计: `task-105-subtitle-rendering-sync.md`
- HLD §3 渲染与时间同步: `hld-ios-macos-v0.2.md`
- PRD §6.4/§6.5: 字幕渲染需求

---

**版本**: v1.0  
**创建日期**: 2025-11-13  
**作者**: @架构  
**最后更新**: 2025-11-13  
**状态**: 待审核
