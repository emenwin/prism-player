# ADR-0002: 播放页 UI 技术栈选择（SwiftUI vs UIKit/AppKit）

## 状态
- 已接受
- 日期：2025-10-24
- 决策者：[@owner]（待补充）
- 相关文档：[PRD v0.2](../requirements/prd_v0.2.md)，[HLD iOS+macOS v0.2](../tdd/hld-ios-macos-v0.2.md)，[Sprint Plan v0.2（更新稿）](../scrum/sprint-plan-v0.2-updated.md)

## 背景与问题陈述
整个应用以 SwiftUI 为主（iOS/macOS 多平台），但“播放页”需要高性能与低延迟：
- 视频渲染稳定（AVFoundation/AVPlayer* 管线）。
- 字幕渲染与播放器时钟同步偏差 P95 ≤ 200ms（见 Sprint DoD）。
- 需要扩展 PiP/手势/倍速/后台行为（iOS）与 App Nap 抑制（macOS）。

问题：播放页是否应改用 UIKit/AppKit 实现以获得更高性能，还是维持 SwiftUI？

## 决策驱动因素
- 性能与同步：视频面板渲染、字幕叠加的刷新与时序精度。
- 可维护性：团队以 SwiftUI + MVVM 为主；减少两套 UI 维护成本。
- 跨平台一致性：iOS 与 macOS 共享 ViewModel 与大部分 UI 结构。
- 可测试性：依赖注入与可替换渲染面板，便于契约测试与基准测试。
- a11y/i18n：SwiftUI 控件层的可访问性与国际化更便捷。

## 考虑的方案

### 方案 A：全 SwiftUI（含 SwiftUI 的 VideoPlayer/Representable 包装）
- 优点：
  - ✅ 统一技术栈，开发效率高。
  - ✅ SwiftUI a11y、动态字体、样式一致性强。
- 缺点：
  - ⚠️ 高频状态驱动（@State/@Published）可能带来额外无谓重绘。
  - ⚠️ 精细时序（30–60Hz）下字幕层使用 SwiftUI 重绘可能产生抖动/抖帧。

### 方案 B：混合方案（推荐）
SwiftUI 作为“外壳 UI 与控制层”，视频渲染面板使用 UIKit/AppKit 原生视图（AVPlayerLayer/AVPlayerView），通过 `UIViewRepresentable`/`NSViewRepresentable` 嵌入到 SwiftUI。
- 优点：
  - ✅ 视频渲染完全由 CoreAnimation/AVFoundation 管线负责，性能稳定。
  - ✅ SwiftUI 仅负责布局与控件，减小重绘频率；逻辑仍保持 MVVM。
  - ✅ 字幕可使用 CALayer（如 CATextLayer/CoreText）或低频 SwiftUI overlay，降低抖动。
  - ✅ iOS/macOS 分别用 AVPlayerLayer/AVPlayerView，平台能力（PiP、App Nap）易集成。
- 缺点：
  - ⚠️ 存在 Representable 桥接与少量平台差异代码。

### 方案 C：播放页完全使用 UIKit/AppKit
- 优点：
  - ✅ 最大化原生控制（含复杂手势/转场）。
- 缺点：
  - ❌ 破坏整体 SwiftUI 一致性，维护两套 UI 心智成本高。
  - ❌ 与其他页面衔接需 Hosting/容器，导航/状态管理复杂度上升。

### 方案 D：自研 Metal 渲染管线
- 优点：
  - ✅ 极致可控。
- 缺点：
  - ❌ 研发成本与风险不匹配当前阶段（超出 Sprint 1/2 范围）。

## 决策结果
选择方案 B：SwiftUI 外壳 + 平台原生渲染面板（UIKit/AppKit）

### 理由
1. AVPlayerLayer/AVPlayerView 由系统优化，避免 SwiftUI 高频重绘带来的额外开销。
2. 保持 SwiftUI 为主（导航、控制、设置、列表等），减少学习与维护成本。
3. 满足时序指标：字幕与时钟同步可通过定时观察器 + 轻量层级（CALayer）实现。
4. 平滑支持 PiP/后台（iOS）与 App Nap 抑制（macOS）。

## 实施细节
- 结构：
  - `PlayerView`（SwiftUI）包含 `PlayerSurfaceRepresentable`（iOS: `UIViewRepresentable` | macOS: `NSViewRepresentable`）。
  - 渲染面板：iOS 使用 `AVPlayerLayer` 的自定义 `UIView`；macOS 使用 `AVPlayerView`。
  - 字幕层：优先使用 `CALayer`（`CATextLayer`/CoreText）绘制；备选 SwiftUI overlay（仅段落边界更新）。
- 时钟与同步：
  - 使用 `addPeriodicTimeObserver`（30–60Hz）驱动内部层更新；对 SwiftUI 层做节流（如 10–15Hz 或“段变更时”）。
  - 记录 `|subtitleTime - playerTime|`，统计 P95 ≤ 200ms。
- 手势与控制：
  - 播放/暂停/进度/倍速等使用 SwiftUI 控件；与 ViewModel 绑定。
- 平台特性：
  - iOS：可选接入 `AVPictureInPictureController`；后台 Audio 模式维持。
  - macOS：`NSProcessInfo.beginActivity` 抑制 App Nap，前后台衔接。
- 架构与 DI：
  - 继续采用协议式 DI（见 ADR-0001），`PlayerService` 与 `AsrEngine` 注入到 ViewModel。

## 示例代码（骨架）

```swift
// iOS: AVPlayerLayer 容器
import SwiftUI
import AVFoundation

final class PlayerSurfaceView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

struct PlayerSurfaceRepresentable: UIViewRepresentable {
    let player: AVPlayer
    let videoGravity: AVLayerVideoGravity

    func makeUIView(context: Context) -> PlayerSurfaceView {
        let v = PlayerSurfaceView()
        v.playerLayer.player = player
        v.playerLayer.videoGravity = videoGravity
        v.isOpaque = true
        return v
    }

    func updateUIView(_ uiView: PlayerSurfaceView, context: Context) {
        uiView.playerLayer.player = player
        uiView.playerLayer.videoGravity = videoGravity
    }
}
```

```swift
// macOS: AVPlayerView 容器
import SwiftUI
import AVKit

struct PlayerSurfaceRepresentable: NSViewRepresentable {
    let player: AVPlayer
    let videoGravity: AVLayerVideoGravity

    func makeNSView(context: Context) -> AVPlayerView {
        let v = AVPlayerView()
        v.player = player
        v.controlsStyle = .none
        v.videoGravity = videoGravity
        return v
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
        nsView.videoGravity = videoGravity
    }
}
```

```swift
// SwiftUI 外壳（简化）
struct PlayerView: View {
    @ObservedObject var viewModel: PlayerViewModel

    var body: some View {
        VStack(spacing: 0) {
            PlayerSurfaceRepresentable(
                player: viewModel.player,
                videoGravity: .resizeAspect
            )
            .overlay(alignment: .bottom) {
                // 可替换为 CALayer 方案；若用 SwiftUI，确保仅在字幕段变更时刷新
                SubtitleOverlayView(segment: viewModel.currentSegment)
                    .allowsHitTesting(false)
                    .padding(.bottom, 16)
            }

            PlayerControlsView(viewModel: viewModel)
        }
        .background(Color.black)
    }
}
```

> 说明：字幕优先用 CALayer 绘制以减少 SwiftUI 重绘；若用 SwiftUI overlay，需对 `currentSegment` 做节流/去抖。

## 验收与度量
- 时间同步偏差：P95 ≤ 200ms（以播放器进度回调为真值）。
- 首帧字幕可见时间：满足 Sprint KPI 基线。
- 性能样本：RTF、内存峰值在 3 档设备采样；SwiftUI 重绘频率不随播放帧率线性增长。
- PiP/后台（iOS）与 App Nap 抑制（macOS）按 HLD 行为通过。

## 后果
- 正面：
  - 视频渲染由系统层优化，减少 UI 层负担；保持 SwiftUI 统一开发体验。
  - 字幕层可独立优化（CALayer/文本栈），便于后续样式与对齐改进。
- 负面：
  - Representable 与平台差异代码需要少量维护。
- 缓解：
  - 统一 `PlayerSurfaceRepresentable` 接口；将平台差异封装于内部；提供最小可测试接口。

## 遵从性
- 保持 SwiftUI 为主；仅渲染“面板”使用 UIKit/AppKit。
- 所有服务通过协议注入；无硬编码字符串（使用 String Catalog）。
- SwiftLint 严格规则通过；新增代码附带最小单测与基准采样。

## 相关决策
- 延续：ADR-0001 多平台架构与协议式 DI（依赖注入）。

## 备注
- Sprint 1 交付骨架与最小可测；Sprint 2 引入 PiP/后台/能耗策略与 a11y 基线。

## 参考资料
- Apple: AVFoundation/AVKit 文档
- WWDC Session: Optimizing SwiftUI performance
- Testing and Tuning for Performance (Apple Developer)
