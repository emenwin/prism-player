# Task 详细设计：播放控件增强

- **Sprint**: Sprint 1b
- **Task**: Task-1b02 播放控件增强
- **PBI**: Sprint 1b - 播放器基础播放功能
- **Owner**: @开发团队
- **状态**: Todo
- **故事点**: 8 SP
- **创建日期**: 2025-11-13
- **最后更新**: 2025-11-13

---

## 相关 TDD
- [macOS UI 页面结构设计](../../../1_design/hld/iOS-macOS/ui-structure-macos-v0.2.md) — 定义播放页控制条布局与交互框架
- [SwiftUI 组件树草图](../../../1_design/hld/iOS-macOS/swiftui-component-tree-sketch-v0.2.md) — 定义 BottomControlBarView 组件层级与命名约定

## 相关 ADR
- （待添加）播放器架构 ADR — 关于 AVPlayer 封装与状态管理策略

---

## 1. 目标与范围

### 目标（可量化）
- 实现完整的播放控制 UI，包含播放/暂停、进度条、时间显示、速度控制等核心功能
- macOS 优先实现，确保 MVVM 架构下 UI 与业务逻辑清晰分离
- 支持键盘快捷键操作（Space、方向键等），提升用户体验
- 单元测试覆盖率 ≥ 80%，关键业务逻辑全部覆盖
- 性能目标：UI 刷新节流 ≤ 60 FPS，不阻塞播放线程

### 范围
**包含**：
- BottomControlBarView 完整实现（播放/暂停、进度、时间、速度、音量、全屏）
- PlayerViewModel 状态管理与 AVPlayer 集成
- 键盘快捷键支持（macOS）
- 进度拖拽与缓冲进度显示
- 时间格式化工具（HH:MM:SS）
- 播放速度选择（0.5x ~ 2.0x）
- 基础错误处理（播放失败、解码错误）

**不包含**：
- iOS 平台实现（后续 Sprint）
- 高级播放控制（AB 循环、逐帧播放）
- 播放列表面板（Task-1b04）
- 字幕显示（Task-1b03）
- 工具侧栏与面板（后续 Sprint）

---

## 2. 方案要点

### 2.1 架构设计

遵循 MVVM 模式：

```
View 层: BottomControlBarView (SwiftUI)
    ├── ControlBarLeadingGroupView (音量、静音、PiP)
    ├── ControlBarCenterGroupView (播放/暂停、进度条、时间)
    └── ControlBarTrailingGroupView (速度、全屏)
         ↓ @ObservedObject
ViewModel 层: PlayerViewModel
    ├── 播放状态管理 (isPlaying, currentTime, duration, rate)
    ├── 与 AVPlayer 交互
    └── 业务逻辑（play, pause, seek, setRate）
         ↓
Model 层: AVPlayer + MediaItem
```

### 2.2 关键组件设计

#### 2.2.1 PlayerViewModel

```
/// 播放器视图模型，管理播放状态与控制逻辑
class PlayerViewModel: ObservableObject {
    // MARK: - 状态属性
    @Published var isPlaying: Bool
    @Published var currentTime: TimeInterval
    @Published var duration: TimeInterval
    @Published var bufferedTime: TimeInterval
    @Published var rate: Float  // 播放速度
    @Published var volume: Float
    @Published var isMuted: Bool
    @Published var isFullScreen: Bool
    @Published var isPipActive: Bool
    @Published var error: PlayerError?
    
    // MARK: - 内部依赖
    private let player: AVPlayer
    private var timeObserverToken: Any?
    private var statusObserver: NSKeyValueObservation?
    
    // MARK: - 控制方法
    func play()
    func pause()
    func togglePlayPause()
    func seek(to time: TimeInterval)
    func setRate(_ rate: Float)
    func setVolume(_ volume: Float)
    func toggleMute()
    func toggleFullScreen()
}
```

**关键约束**：
- 时间更新频率：30 FPS (0.033s 间隔)，使用 `addPeriodicTimeObserver`
- 状态同步：通过 KVO 观察 `player.timeControlStatus`、`player.status`
- 错误处理：观察 `playerItem.error` 并转换为 `PlayerError` 枚举
- 线程安全：所有 UI 更新在主线程，AVPlayer 操作使用其内部队列

#### 2.2.2 BottomControlBarView 布局

```
HStack(spacing: 12) {
    // Leading Group (80pt)
    ControlBarLeadingGroupView(viewModel: viewModel)
    
    // Center Group (flex, 占据剩余空间)
    ControlBarCenterGroupView(viewModel: viewModel)
    
    // Trailing Group (180pt)
    ControlBarTrailingGroupView(viewModel: viewModel)
}
.padding(.horizontal, 16)
.padding(.vertical, 8)
.background(Material.ultraThin)  // 毛玻璃效果
.cornerRadius(8)
```

**尺寸约束**：
- 总高度：48pt（固定）
- Leading Group 宽度：~80pt
- Trailing Group 宽度：~180pt
- Center Group：flex fill
- 最小窗口宽度支持：640pt

#### 2.2.3 进度条组件

```
/// 播放进度条，支持拖拽跳转与缓冲进度显示
struct TimelineSliderView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @State private var isDragging = false
    @State private var dragValue: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景轨道
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 4)
                
                // 缓冲进度
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: bufferedWidth(in: geometry), height: 4)
                
                // 播放进度
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: playedWidth(in: geometry), height: 4)
            }
            .gesture(dragGesture(in: geometry))
        }
        .frame(height: 20)  // 交互热区
    }
}
```

**交互逻辑**：
- 拖拽时暂停时间观察器更新，避免抖动
- 拖拽结束时调用 `viewModel.seek(to:)`
- 支持点击跳转（TapGesture）

#### 2.2.4 时间格式化工具

```
extension TimeInterval {
    /// 格式化为 HH:MM:SS 或 MM:SS
    var formattedTime: String {
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
```

### 2.3 键盘快捷键实现

使用 SwiftUI `.keyboardShortcut` 修饰符：

```swift
.onKeyPress(.space) { _ in
    viewModel.togglePlayPause()
    return .handled
}
.onKeyPress(.leftArrow) { _ in
    viewModel.seek(to: max(0, viewModel.currentTime - 5))
    return .handled
}
.onKeyPress(.rightArrow) { _ in
    viewModel.seek(to: min(viewModel.duration, viewModel.currentTime + 5))
    return .handled
}
.onKeyPress(.upArrow) { _ in
    viewModel.setVolume(min(1.0, viewModel.volume + 0.1))
    return .handled
}
.onKeyPress(.downArrow) { _ in
    viewModel.setVolume(max(0.0, viewModel.volume - 0.1))
    return .handled
}
```

### 2.4 错误处理策略

定义 `PlayerError` 枚举：

```swift
enum PlayerError: LocalizedError {
    case loadFailed(String)
    case decodingError(String)
    case networkError(String)
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .loadFailed(let reason):
            return NSLocalizedString("player.error.load_failed", comment: "") + ": \(reason)"
        case .decodingError(let reason):
            return NSLocalizedString("player.error.decoding", comment: "") + ": \(reason)"
        case .networkError(let reason):
            return NSLocalizedString("player.error.network", comment: "") + ": \(reason)"
        case .unknownError(let reason):
            return NSLocalizedString("player.error.unknown", comment: "") + ": \(reason)"
        }
    }
}
```

**错误展示**：
- 使用 Toast/HUD 显示错误消息（3 秒自动消失）
- 严重错误（无法播放）显示在画布中心，提供"重试"按钮

### 2.5 与 TDD 差异的本地实现细节

**偏差 1：进度条拖拽防抖策略**
- **差异**：TDD 未明确拖拽时的时间观察器处理策略
- **实现**：拖拽开始时暂停 `timeObserver`，拖拽结束后恢复，避免 UI 抖动
- **原因**：实际测试发现同时更新会导致进度条跳动
- **影响**：仅内部实现细节，不影响接口
- **后续**：❌ 无需更新 HLD

**偏差 2：全屏模式实现方式**
- **差异**：TDD 未指定全屏 API 选择（NSWindow.toggleFullScreen vs native fullscreen）
- **实现**：使用 `NSWindow.toggleFullScreen(_:)` 系统 API
- **原因**：与 macOS 系统行为一致，支持多桌面
- **影响**：无，符合用户预期
- **后续**：❌ 无需更新 HLD

---

## 3. 改动清单

### 3.1 新增文件

```
packages/PrismKit/Sources/Components/
├── VideoPlayer/
│   ├── PlayerViewModel.swift          (核心 ViewModel)
│   ├── BottomControlBarView.swift     (控制条容器)
│   ├── ControlBarLeadingGroupView.swift
│   ├── ControlBarCenterGroupView.swift
│   ├── ControlBarTrailingGroupView.swift
│   ├── TimelineSliderView.swift       (进度条)
│   ├── TimeIndicatorView.swift        (时间显示)
│   └── PlaybackRatePickerView.swift   (速度选择)
└── Extensions/
    └── TimeInterval+Formatting.swift   (时间格式化)

packages/PrismKit/Tests/Components/
└── VideoPlayer/
    ├── PlayerViewModelTests.swift
    ├── TimelineSliderTests.swift
    └── TimeIntervalFormattingTests.swift

packages/PrismCore/Sources/Models/
└── PlayerError.swift                   (错误模型)
```

### 3.2 修改文件

```
apps/PrismPlayer/Sources/Features/Player/
└── PlayerSceneView.swift               (集成 BottomControlBarView)

packages/PrismKit/Sources/Localization/
├── en.lproj/Localizable.strings        (英文文案)
└── zh-Hans.lproj/Localizable.strings   (中文文案)
```

### 3.3 接口变更

**新增公开接口**：

```swift
// PlayerViewModel.swift
public class PlayerViewModel: ObservableObject {
    public init(player: AVPlayer)
    public func play()
    public func pause()
    public func seek(to time: TimeInterval)
    public func setRate(_ rate: Float)
    // ... 其他方法
}

// BottomControlBarView.swift
public struct BottomControlBarView: View {
    public init(viewModel: PlayerViewModel)
}
```

**无破坏性变更**，所有新增接口。

---

## 4. 实施计划

### 4.1 PR 拆分

**PR1: 核心 ViewModel 与时间格式化**（2 天）
- `PlayerViewModel.swift` 基础实现
- `TimeInterval+Formatting.swift` 扩展
- 单元测试覆盖
- DoD: CI 通过，覆盖率 ≥ 80%

**PR2: 播放控制 UI - 中心区域**（2 天）
- `BottomControlBarView.swift` 容器
- `ControlBarCenterGroupView.swift` (播放/暂停、进度、时间)
- `TimelineSliderView.swift` 进度条组件
- `TimeIndicatorView.swift` 时间显示
- 预览与集成测试

**PR3: 播放控制 UI - 左右区域**（1.5 天）
- `ControlBarLeadingGroupView.swift` (音量、静音)
- `ControlBarTrailingGroupView.swift` (速度、全屏)
- `PlaybackRatePickerView.swift` 速度选择器
- 完整布局测试

**PR4: 键盘快捷键与错误处理**（1.5 天）
- 键盘事件处理
- `PlayerError.swift` 错误模型
- 错误 UI 显示（Toast/HUD）
- 国际化文案
- 集成到 PlayerSceneView

**PR5: 集成测试与文档**（1 天）
- 端到端测试场景
- README 更新
- CHANGELOG 更新
- 性能验证（FPS、内存）

**总计**: 约 8 天（符合 8 SP 预估）

### 4.2 特性开关

无需特性开关，直接发布。

---

## 5. 测试与验收

### 5.1 单元测试

**PlayerViewModelTests.swift**：

```swift
// 正常流程
func testPlayPauseToggle()
func testSeekToValidTime()
func testSetPlaybackRate()
func testVolumeControl()

// 边界条件
func testSeekToNegativeTime()  // 应限制到 0
func testSeekBeyondDuration()  // 应限制到 duration
func testSetRateOutOfRange()   // 应限制到 0.5 ~ 2.0

// 异常处理
func testHandlePlayerItemError()
func testHandleNetworkError()

// 状态同步
func testTimeObserverUpdatesCurrentTime()
func testBufferedTimeUpdatesCorrectly()
```

**TimeIntervalFormattingTests.swift**：

```swift
func testFormatShortDuration()    // 59s → "00:59"
func testFormatMinutes()          // 90s → "01:30"
func testFormatHours()            // 3661s → "1:01:01"
func testFormatZero()             // 0s → "00:00"
```

**夹具**：
- ✅ 已有：`packages/PrismKit/Tests/Fixtures/video/sample-10s.mp4`（来自 Sprint 1）
- ⏳ 需创建：`sample-corrupt.mp4`（损坏文件测试）

**覆盖率目标**: ≥ 80%（ViewModel 核心逻辑 100%）

### 5.2 集成测试

**场景 1：完整播放流程**
```swift
func testCompletePlaybackFlow() {
    // Given: 加载有效视频文件
    let viewModel = PlayerViewModel(player: AVPlayer(url: sampleURL))
    
    // When: 播放 -> 暂停 -> 跳转 -> 改变速度
    viewModel.play()
    XCTAssertTrue(viewModel.isPlaying)
    
    viewModel.pause()
    XCTAssertFalse(viewModel.isPlaying)
    
    viewModel.seek(to: 5.0)
    XCTAssertEqual(viewModel.currentTime, 5.0, accuracy: 0.1)
    
    viewModel.setRate(1.5)
    XCTAssertEqual(viewModel.rate, 1.5)
}
```

**场景 2：进度条拖拽**
```swift
func testTimelineSliderDragSeek() {
    // 模拟用户拖拽进度条到 50% 位置
    // 验证 seek 被调用且时间正确
}
```

**场景 3：键盘快捷键**
```swift
func testKeyboardShortcuts() {
    // 模拟按键事件（Space、Left/Right、Up/Down）
    // 验证对应方法被调用
}
```

**场景 4：错误恢复**
```swift
func testErrorRecovery() {
    // Given: 加载损坏文件
    // Then: 显示错误消息，提供重试按钮
    // When: 重试加载有效文件
    // Then: 成功播放
}
```

### 5.3 验收标准

- [x] **功能完整性**：
  - [ ] 播放/暂停按钮工作正常，状态同步
  - [ ] 进度条显示当前播放位置
  - [ ] 进度条支持拖拽跳转
  - [ ] 时间显示格式正确（MM:SS / HH:MM:SS）
  - [ ] 缓冲进度显示（可选，优先级低）
  - [ ] 播放速度选择器（0.5x ~ 2.0x）
  - [ ] 音量控制与静音切换
  - [ ] 全屏切换（macOS）
  - [ ] 键盘快捷键全部响应

- [x] **质量指标**：
  - [ ] 所有单元测试通过（覆盖率 ≥ 80%）
  - [ ] 集成测试通过（4 个场景）
  - [ ] SwiftLint 严格模式通过
  - [ ] 无硬编码字符串，所有文案国际化
  - [ ] 性能测试：UI 刷新 ≤ 60 FPS，内存稳定

- [x] **文档更新**：
  - [ ] README 添加播放控件使用说明
  - [ ] CHANGELOG 记录新增功能
  - [ ] 代码注释完整（中文）

- [x] **Code Review**：
  - [ ] 至少 1 位 Reviewer 批准
  - [ ] 无未解决的评论

---

## 6. 观测与验证

### 6.1 日志埋点

```swift
// PlayerViewModel.swift
func play() {
    logger.info("▶️ 播放开始", metadata: [
        "mediaURL": "\(player.currentItem?.asset)",
        "currentTime": "\(currentTime)"
    ])
}

func seek(to time: TimeInterval) {
    logger.debug("⏩ 跳转到: \(time.formattedTime)")
}

func handleError(_ error: Error) {
    logger.error("❌ 播放错误", metadata: [
        "error": "\(error.localizedDescription)",
        "mediaURL": "\(player.currentItem?.asset)"
    ])
}
```

### 6.2 性能指标

**监控项**：
- UI 刷新帧率：使用 Instruments 的 "Core Animation" 模板
- 内存占用：播放 10 分钟视频，内存增长 < 50 MB
- CPU 占用：UI 线程 CPU < 10%（播放时）

**验证方法**：
- **本地**：Xcode Instruments 性能分析
- **CI**：XCTest Performance Tests
- **真机**：在 MacBook Air M1 测试（最低配置）

### 6.3 错误追踪

**监控**：
- `PlayerError` 发生频率与类型分布
- Seek 失败率
- AVPlayer 状态转换异常

**验证**：
- 单元测试覆盖所有错误分支
- 手动测试异常文件（损坏、网络中断）

---

## 7. 风险与未决

### 风险列表

| 风险 | 影响 | 概率 | 缓解措施 | 负责人 | 状态 |
|------|------|------|---------|--------|------|
| AVPlayer 时间观察器性能问题 | 中 | 低 | 使用 30 FPS 节流，拖拽时暂停观察器 | @开发 | ✅ 已缓解 |
| 全屏模式与多窗口冲突 | 高 | 中 | 使用系统标准 API，优先支持单窗口 | @开发 | ⏳ 待验证 |
| 键盘快捷键与系统冲突 | 低 | 低 | 使用 `.keyboardShortcut` 遵循系统优先级 | @开发 | ✅ 已缓解 |
| 进度条拖拽抖动 | 中 | 中 | 拖拽时暂停时间观察器 | @开发 | ✅ 已缓解 |

### 未决问题

1. **PiP（画中画）实现方式**
   - 选项 A：使用 `AVPictureInPictureController`（需要 macOS 10.15+）
   - 选项 B：延后到后续 Sprint
   - **决策**: 选择 B，当前仅预留 UI 占位
   - **截止日期**: Sprint 1b Review 前确认

2. **缓冲进度显示优先级**
   - 当前实现复杂度较高（需要观察 `loadedTimeRanges`）
   - **决策**: 作为可选功能，时间充裕再实现
   - **截止日期**: PR2 完成时评估

---

## 定义完成（DoD）

### 开发完成

- [ ] 所有 PR 已合并到 `main` 分支
- [ ] CI 通过（构建、测试、SwiftLint 严格模式）
- [ ] 代码覆盖率 ≥ 80%（ViewModel 核心逻辑 100%）
- [ ] 所有单元测试通过
- [ ] 集成测试场景全部通过（4 个）

### 质量保证

- [ ] 无硬编码字符串（所有文案国际化）
- [ ] 所有类和核心方法有中文注释
- [ ] SwiftLint 严格模式无警告
- [ ] 性能测试通过：UI ≤ 60 FPS，内存增长 < 50 MB
- [ ] 错误处理覆盖所有已知异常路径

### 文档完整

- [ ] `README.md` 更新（新增模块说明）
- [ ] `CHANGELOG.md` 记录变更（版本号、日期、功能）
- [ ] HLD 无需更新（设计偏差已记录在本文档）
- [ ] 所有 TODO 注释已清理

### Code Review

- [ ] 至少 1 位 Reviewer 批准
- [ ] 所有评审意见已解决
- [ ] 关键路径代码已 pair review

### 验收演示

- [ ] 可演示完整播放流程（播放、暂停、跳转、速度调整）
- [ ] 可演示键盘快捷键（Space、方向键）
- [ ] 可演示错误处理（加载损坏文件）
- [ ] PO/Stakeholder 确认功能符合预期

---

**文档版本**: v1.0  
**创建日期**: 2025-11-13  
**最后更新**: 2025-11-13  
**变更记录**:
- v1.0 (2025-11-13): 初始版本，基于 Sprint 1b Task-1b02 需求创建
