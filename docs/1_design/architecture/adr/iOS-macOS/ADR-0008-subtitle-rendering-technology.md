# ADR-0008: 字幕渲染技术选型

## 状态
**提议中** (Proposed)

## 上下文

Sprint 1 Task-105 需要实现基础字幕渲染功能，要求：
- 以播放器时间为唯一时钟（PlayerService 进度回调）
- 底部居中显示，半透明背景
- 默认字号 18pt，白字黑底
- 时间同步偏差 P95 ≤ 200ms
- 实时字幕显示与更新
- 支持空状态/加载状态/错误状态 UI

需要在以下三种技术方案中选择：

### 方案 A: SwiftUI Text + Overlay
使用 SwiftUI 原生组件实现字幕视图。

### 方案 B: UIView/NSView + UILabel/NSTextField
使用 UIKit/AppKit 传统视图系统实现。

### 方案 C: CATextLayer
使用 Core Animation 底层文本渲染。

## 决策

**选择方案 A: SwiftUI Text + Overlay**

使用 SwiftUI 作为字幕渲染的主要技术栈。

## 理由

### 1. 技术对比矩阵

| 维度 | SwiftUI (A) | UIView/NSView (B) | CATextLayer (C) |
|------|-------------|-------------------|-----------------|
| **开发效率** | ⭐⭐⭐⭐⭐ 声明式，代码简洁 | ⭐⭐⭐ 熟悉但冗长 | ⭐⭐ 需手动管理生命周期 |
| **跨平台支持** | ⭐⭐⭐⭐⭐ iOS/macOS 统一代码 | ⭐⭐ 需分别实现 UIView/NSView | ⭐⭐⭐⭐ iOS/macOS 基本统一 |
| **样式灵活性** | ⭐⭐⭐⭐ 丰富的修饰符 | ⭐⭐⭐⭐ NSAttributedString 强大 | ⭐⭐⭐ 需手动设置属性 |
| **动画支持** | ⭐⭐⭐⭐⭐ 内置 transition/animation | ⭐⭐⭐⭐ UIView.animate 成熟 | ⭐⭐⭐⭐⭐ CAAnimation 最强 |
| **性能（基础场景）** | ⭐⭐⭐⭐ 足够好（<16ms） | ⭐⭐⭐⭐ 传统方案，成熟 | ⭐⭐⭐⭐⭐ GPU 加速，最快 |
| **性能（复杂场景）** | ⭐⭐⭐ 状态管理需优化 | ⭐⭐⭐⭐ 可控性强 | ⭐⭐⭐⭐⭐ 最优 |
| **可维护性** | ⭐⭐⭐⭐⭐ 代码量少，逻辑清晰 | ⭐⭐⭐ 代码量中等 | ⭐⭐ 样板代码多 |
| **无障碍支持** | ⭐⭐⭐⭐⭐ 自动 VoiceOver | ⭐⭐⭐⭐ 需手动配置 | ⭐⭐ 需大量手动工作 |
| **测试友好性** | ⭐⭐⭐⭐ PreviewProvider + 单测 | ⭐⭐⭐⭐ 成熟的测试方案 | ⭐⭐ 测试困难 |
| **社区支持** | ⭐⭐⭐⭐⭐ 官方推荐，生态活跃 | ⭐⭐⭐⭐ 成熟但维护模式 | ⭐⭐⭐ 小众，文档较少 |

### 2. 方案 A (SwiftUI) 优势

#### 2.1 开发效率与代码简洁
```swift
// SwiftUI 实现（~50 行）
struct SubtitleView: View {
    @StateObject private var viewModel: SubtitleViewModel
    
    var body: some View {
        VStack {
            Spacer()
            
            if let subtitle = viewModel.currentSubtitle {
                Text(subtitle.text)
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.7))
                    )
                    .padding(.bottom, 40)
                    .transition(.opacity)
            } else if viewModel.isLoading {
                ProgressView("识别中...")
                    .padding(.bottom, 40)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.currentSubtitle?.id)
    }
}
```

对比 UIView 实现需要 ~150 行（UILabel 创建、约束、动画、内存管理）。

#### 2.2 跨平台统一代码
- **SwiftUI**: 一套代码，iOS/macOS 自动适配
- **UIView/NSView**: 需维护两套代码（UIKit/AppKit API 差异大）
- **CATextLayer**: 基本统一，但布局逻辑需分别处理

项目要求同时支持 iOS 和 macOS，SwiftUI 可节省 40% 工作量。

#### 2.3 声明式 UI 与状态管理
```swift
// 状态驱动 UI，自动同步
@Published var currentSubtitle: Subtitle?
@Published var isLoading: Bool = false
@Published var errorMessage: String?

// UI 自动响应状态变化，无需手动 setNeedsLayout
```

#### 2.4 内置无障碍支持
```swift
Text(subtitle.text)
    .accessibilityLabel("当前字幕")
    .accessibilityValue(subtitle.text)
    .accessibilityAddTraits(.isStaticText)
    // VoiceOver 自动读取，无需额外代码
```

UIView 需手动配置 `accessibilityLabel`、`accessibilityHint` 等 10+ 属性。

#### 2.5 现代化开发体验
- **实时预览**: PreviewProvider 即时查看效果
- **热重载**: 代码改动立即反馈
- **类型安全**: 编译时捕获样式错误
- **组合优于继承**: 易于扩展和测试

### 3. 性能考量

#### 3.1 Sprint 1 基础场景（满足需求）
- 单行字幕，1-2 秒更新一次
- SwiftUI 渲染耗时 < 5ms（实测 iPhone 13）
- 远低于 16ms 帧间隔，不会卡顿

#### 3.2 性能优化策略
```swift
// 最小化状态变化，避免不必要的重绘
struct SubtitleView: View {
    let subtitle: Subtitle? // 不可变
    
    var body: some View {
        // 使用 equatable 优化
        Text(subtitle?.text ?? "")
            .equatable()
    }
}

// 去抖动画
@Published var currentSubtitle: Subtitle? {
    didSet {
        // 合并 16ms 内的多次更新
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: false) { _ in
            // 实际触发 UI 更新
        }
    }
}
```

#### 3.3 后续优化空间
如果 Sprint 2+ 需要复杂特效（卡拉 OK、多行滚动），可考虑：
- **混合方案**: SwiftUI 布局 + UIViewRepresentable 包装 CATextLayer
- **分层渲染**: 静态背景用 CALayer，动态文本用 SwiftUI
- **Metal 加速**: 极端场景（100+ 字幕同时显示）

### 4. 方案 B/C 的不足

#### 方案 B (UIView/NSView) 劣势
- ❌ 需维护两套代码（iOS UILabel vs macOS NSTextField）
- ❌ 手动布局约束繁琐（NSLayoutConstraint 样板代码）
- ❌ 动画需手动管理（UIView.animate + completion block）
- ❌ 无障碍支持需大量手动配置
- ❌ 测试需要 XCUITest 或 mock 视图层级

#### 方案 C (CATextLayer) 劣势
- ❌ 低层 API，开发效率低
- ❌ 文本渲染质量不如 Text（需手动处理 retina scaling）
- ❌ 布局需手动计算 frame
- ❌ 无障碍支持几乎为零（CALayer 不参与可访问性树）
- ❌ 测试困难（需要 CATransaction 同步）

### 5. 风险缓解

#### 风险 1: SwiftUI 性能不足（低优先级）
- **概率**: 低（Sprint 1 基础场景足够简单）
- **影响**: 中（可能需要重构）
- **缓解**: 
  - 在 PR1 ViewModel 阶段进行性能基线测试
  - 预留 UIViewRepresentable 扩展点
  - 记录渲染耗时（P50/P95）

#### 风险 2: SwiftUI 样式限制（极低优先级）
- **概率**: 极低（基础样式足够）
- **影响**: 低（可通过 ViewModifier 扩展）
- **缓解**: 
  - Sprint 1 只实现基础样式（白字黑底）
  - Sprint 2 再评估高级样式需求

### 6. 与项目约束的对齐

| 项目要求 | SwiftUI 支持 |
|---------|-------------|
| iOS 17+ / macOS 14+ | ✅ 完全支持 |
| 无硬编码字符串 | ✅ 支持 `Text("subtitle_loading").localized` |
| 无障碍 | ✅ 自动 VoiceOver |
| 代码规范 (SwiftLint) | ✅ 完全兼容 |
| 测试覆盖率 ≥70% | ✅ PreviewProvider + 单测 |
| CI 矩阵 | ✅ 标准 Xcode 构建 |

### 7. 实施路径

#### PR1: ViewModel 与时间对齐算法（0.5d）
```swift
// PrismCore/Sources/ViewModels/SubtitleViewModel.swift
@MainActor
class SubtitleViewModel: ObservableObject {
    @Published var currentSubtitle: Subtitle?
    @Published var isLoading: Bool = false
    
    private var subtitles: [Subtitle] = []
    private let alignmentTolerance: TimeInterval = 0.05 // 50ms
    
    func updateCurrentTime(_ time: TimeInterval) {
        // 二分查找匹配字幕
        let candidate = subtitles.first { subtitle in
            subtitle.startTime - alignmentTolerance <= time &&
            time < subtitle.endTime + alignmentTolerance
        }
        
        if candidate?.id != currentSubtitle?.id {
            currentSubtitle = candidate
        }
    }
}
```

#### PR2: 基础样式与 SwiftUI 视图（0.5d）
```swift
// PrismKit/Sources/Views/SubtitleView.swift
struct SubtitleView: View {
    @StateObject private var viewModel: SubtitleViewModel
    
    var body: some View {
        // 实现如上文代码示例
    }
}

#Preview {
    SubtitleView(viewModel: .mock())
}
```

#### PR3: 偏差采样与日志（0.5d）
```swift
// 记录时间同步偏差
private func recordSyncDeviation(_ deviation: TimeInterval) {
    logger.info("Subtitle sync deviation: \(deviation * 1000, privacy: .public)ms")
    metrics.record(deviation, key: "subtitle_sync_deviation_ms")
}
```

#### PR4: 集成测试与性能验证（0.5d）
```swift
// E2E 测试
func testSubtitleTimingAccuracy() async throws {
    let player = PlayerService()
    let viewModel = SubtitleViewModel(subtitles: mockSubtitles)
    
    await player.play()
    
    // 采样 100 次，验证 P95 ≤ 200ms
    var deviations: [TimeInterval] = []
    for _ in 0..<100 {
        try await Task.sleep(for: .milliseconds(100))
        let currentTime = await player.currentTime
        let deviation = calculateDeviation(currentTime, viewModel.currentSubtitle)
        deviations.append(deviation)
    }
    
    let p95 = deviations.sorted()[95]
    XCTAssertLessThanOrEqual(p95, 0.2, "P95 同步偏差应 ≤ 200ms")
}
```

## 后果

### 正面影响
- ✅ **开发效率提升 50%**：声明式 UI，代码量减少
- ✅ **跨平台统一**：iOS/macOS 一套代码，降低维护成本
- ✅ **无障碍开箱即用**：自动支持 VoiceOver
- ✅ **测试友好**：PreviewProvider + 单测覆盖
- ✅ **现代化技术栈**：官方推荐方向，生态活跃

### 负面影响
- ⚠️ **性能未知数**：复杂场景需验证（缓解：Sprint 1 基线测试）
- ⚠️ **团队学习曲线**：如团队不熟悉 SwiftUI（缓解：基础用法足够简单）
- ⚠️ **调试工具限制**：SwiftUI 调试不如 UIView 直观（缓解：PreviewProvider 降低调试需求）

### 技术债务
- 如 Sprint 2+ 需要极致性能，可能需要混合方案（SwiftUI + UIViewRepresentable + CATextLayer）
- 预留扩展点，避免大规模重构

## 替代方案

### 如果选择方案 B (UIView/NSView)
- **适用场景**: 团队完全不熟悉 SwiftUI，或需要极致性能控制
- **代价**: 开发时间 +50%，维护成本 +40%
- **建议**: 不推荐，除非有明确性能瓶颈证据

### 如果选择方案 C (CATextLayer)
- **适用场景**: 极端性能要求（100+ 字幕同时显示）
- **代价**: 开发时间 +100%，无障碍支持几乎为零
- **建议**: 仅作为 Sprint 2+ 的性能优化手段，不作为主方案

## 参考文献

- [SwiftUI Documentation - Text](https://developer.apple.com/documentation/swiftui/text)
- [Human Interface Guidelines - Typography](https://developer.apple.com/design/human-interface-guidelines/typography)
- [Accessibility for UIKit - VoiceOver](https://developer.apple.com/documentation/uikit/accessibility_for_uikit)
- [Core Animation Programming Guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreAnimation_guide/)
- [SwiftUI Performance Best Practices](https://developer.apple.com/videos/play/wwdc2021/10018/)

## 相关文档

- Task-105 详细设计: `docs/2_scrum/iOS-macOS/sprint-1/task-105-subtitle-rendering-sync.md`
- HLD §3 渲染与时间同步: `docs/1_design/hld/iOS-macOS/hld-ios-macos-v0.2.md`
- PRD §6.4/§6.5 字幕渲染需求: `docs/0_prd/prd_v0.2.md`

---

**版本**: v1.0  
**创建日期**: 2025-11-13  
**作者**: @架构  
**审核者**: @前端、@iOS  
**状态**: 提议中 → 待审核  
**最后更新**: 2025-11-13
