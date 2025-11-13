# SwiftUI 组件树草图（macOS）

类型：HLD - 组件结构草图（不含逻辑/状态）
版本：v0.2
最后更新：2025-11-13

说明：仅列 View 结构与命名，配合《ui-structure-macos-v0.2.md》。命名统一以 XxxView / XxxPanelView / XxxBar / XxxOverlay 命名；容器与布局仅描述层级，不含实现代码。

---

## 0. App 根视图

- AppRootView
  - WindowGroup
    - AppContentView
      - switch route
        - WelcomeSceneView
        - PlayerSceneView
  - GlobalModalsHostView（Preferences / About / ShortcutsHelp 等）

备注：多窗口方案可在 WindowGroup 层复用 AppContentView。

## 1. 欢迎页（WelcomeSceneView）

- WelcomeSceneView
  - TopBarView
    - AppTitleView
    - FeedbackButtonView
  - WelcomeBodySplitView（水平栈，窄宽度时垂直）
    - FeatureCardView（左卡）
      - FeatureItemRowView × N
      - UnlockProButtonView
    - ActionCardView（右卡）
      - ActionGroupHeaderView
      - OpenFileButtonView
      - OpenDiscButtonView
      - OpenURLButtonView
      - OpenTranscoderButtonView
  - HistoryBarView（底部）
    - RecentItemThumbnailView × N
    - ClearHistoryButtonView

空态：RecentItemEmptyView（HistoryBarView 内部切换）。

## 2. 播放页（PlayerSceneView）

- PlayerSceneView
  - PlayerLayoutContainerView（主布局容器）
    - ToolSidebarView（左侧纵向栏）
      - ToolSidebarItemView: Capture
      - ToolSidebarItemView: GIF
      - ToolSidebarItemView: Cast
      - ToolSidebarItemView: AISubtitle
      - ToolSidebarItemView: Adjust
      - ToolSidebarItemView: Presets
      - ToolSidebarItemView: Export
    - VideoCanvasStackView（中心）
      - VideoCanvasView
      - TitleOverlayView（顶部信息层）
      - BottomControlBarView（悬浮控制条）
      - ToastHUDContainerView
    - PlaylistDrawerView（右侧抽屉，可折叠）
      - PlaylistHeaderView
        - PlaylistSearchFieldView
      - PlaylistListView
        - PlaylistRowView × N
      - PlaylistFooterToolbarView
        - AddItemButtonView
        - ImportButtonView
        - DeleteButtonView
        - ItemCountIndicatorView
  - StatusBarView（底部可选）

### 2.1 控制条（BottomControlBarView）

- BottomControlBarView
  - ControlBarLeadingGroupView
    - BackButtonView / WindowControlProxyView
    - VolumeControlView
    - MuteToggleView
    - PiPToggleView
  - ControlBarCenterGroupView
    - PreviousButtonView
    - PlayPauseButtonView
    - NextButtonView
    - TimelineSliderView
    - TimeIndicatorView（current / duration）
  - ControlBarTrailingGroupView
    - PlaybackRatePickerView
    - SubtitlePickerView
    - AudioTrackPickerView
    - AspectModePickerView
    - FullscreenToggleView
    - TogglePlaylistButtonView

### 2.2 工具面板集合（与侧栏联动）

- ToolPanelsHostView（位于 ToolSidebar 右侧，以 overlay 或分栏实现）
  - CapturePanelView
    - CaptureRegionPickerView
    - SnapshotButtonView
    - StartStopRecordingButtonView
  - GIFPanelView
    - GifRangePickerView
    - GifSizeFpsControlsView
    - GifExportButtonView
  - CastPanelView
    - CastTargetListView
    - ConnectButtonView
  - AISubtitlePanelView
    - ASRJobProgressView
    - SubtitleTrackListView
    - SubtitleSyncToolsView
  - AdjustPanelView
    - PictureTuningControlsView（亮度/对比/饱和/旋转）
    - AudioTuningControlsView（EQ/增益）
    - ResetAdjustButtonView
  - PresetsPanelView
    - PresetGridView
    - ApplyPresetButtonView
  - ExportPanelView
    - ExportFormatPickerView
    - ExportOptionsFormView
    - ExportActionButtonsView

## 3. 全局复用组件

- EmptyStateView
- LoadingStateView
- ErrorBannerView
- DraggableDividerHandleView（抽屉/分栏把手）
- ResizablePanelContainerView
- ShortcutHintPopoverView
- IconLabelButtonView（图标+文案统一按钮）

## 4. 模态与弹出

- PreferencesView（系统偏好窗口内容）
- AboutView
- ShortcutsHelpView
- OpenURLPromptView
- SystemOpenPanelBridgeView（与系统面板交互的桥接视图壳，命名为占位）

## 5. 命名约定与结构说明

- 页面/场景：XxxSceneView
- 复合容器：XxxContainerView / XxxStackView / XxxHostView
- 叠加：XxxOverlayView / XxxHUDView
- 工具侧栏项：ToolSidebarItemView（通过样式区分具体条目）
- 面板：XxxPanelView（由 ToolPanelsHostView 承载）
- Bar/Toolbar 均用于横向条状区域（TopBarView、BottomControlBarView、StatusBarView）

## 6. 关系示意（Mermaid）

```mermaid
flowchart LR
  AppRoot --> AppContent
  AppContent -->|welcome| WelcomeScene
  AppContent -->|player| PlayerScene

  subgraph WelcomeScene
    TopBar --> BodySplit
    BodySplit --> FeatureCard
    BodySplit --> ActionCard
    WelcomeScene --> HistoryBar
  end

  subgraph PlayerScene
    Sidebar --> PanelsHost
    PlayerLayout -.-> StatusBar
    PlayerLayout --> CanvasStack
    PlayerLayout --> Sidebar
    PlayerLayout --> PlaylistDrawer
    CanvasStack --> TitleOverlay
    CanvasStack --> ControlBar
    CanvasStack --> ToastHUD
  end
```

—— 以上为组件树草图，可直接用于后续任务拆分与 Story/Issue 建立。
