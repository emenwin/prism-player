# Sprint 1b Task 列表

**Sprint 周期**: 2025-11-14 ~ 2025-11-27（预估 2 周）  
**Sprint 目标**: 完成播放器基础播放功能与 UI 框架（优先 macOS），用于后续的集成测试  
**总故事点**: 68 SP

---

## 📊 进度概览

| 状态 | 任务数 | 故事点 | 占比 |
|------|--------|--------|------|
| ✅ 完成 | 2 | 13 SP | 19.1% |
| 🚧 进行中 | 0 | 0 SP | 0% |
| ⏳ 待开始 | 9 | 55 SP | 80.9% |

**最后更新**: 2025-11-14

---


## 📋 任务清单

### 核心功能（P0）

#### Task-1b01: 视频选择功能（macOS 优先）
- **故事点**: 5 SP
- **状态**: ✅ 完成
- **优先级**: P0
- **依赖**: Sprint 0（工程基线）
- **验收标准**:
  - [x] macOS: NSOpenPanel 选择本地视频/音频文件
  - [x] iOS: UIDocumentPickerViewController 选择文件
  - [x] 支持常见格式：mp4, mov, m4v, mp3, m4a, wav
  - [x] 文件路径安全访问与权限处理
  - [x] 错误处理：文件不存在、权限拒绝、格式不支持
- **参考**: PRD §6.1, Sprint 1 Task-101
- **相关文件**: `PrismPlayer/Sources/Features/MediaSelection/`
- **备注**: 已在 Sprint 1 Task-101 完成

---

#### Task-1b02: 播放控件增强
- **故事点**: 8 SP
- **状态**: ✅ 完成
- **优先级**: P0
- **依赖**: Task-1b01
- **验收标准**:
  - [x] macOS: 实现 AVPlayerView 封装与自定义控件层
  - [x] iOS: 实现 VideoPlayer/AVPlayerViewController 自定义控件
  - [x] 播放/暂停按钮，状态同步
  - [x] 进度条（Slider）：
    - 显示当前播放进度
    - 支持拖动跳转
    - 显示缓冲进度（可选）
  - [x] 时间显示：
    - 当前播放时间（HH:MM:SS）
    - 总时长（HH:MM:SS）
    - 格式：00:00 / 05:30
  - [x] 音量控制（可选）
  - [x] 全屏/窗口化切换（macOS）
  - [x] 播放速度选择：0.5x, 0.75x, 1.0x, 1.25x, 1.5x, 2.0x
  - [x] 键盘快捷键（macOS）：
    - Space: 播放/暂停
    - Left/Right: ±5s 跳转
    - Up/Down: 音量调节
    - F: 全屏切换
    - M: 静音切换
  - [x] 错误处理：播放失败、解码错误
  - [x] 自动化测试：控件状态同步、时间格式化
- **参考**: PRD §6.1, HLD §2.2 PlayerService
- **相关文件**: 
  - `PrismKit/Sources/Components/VideoPlayer/PlayerViewModel.swift` ✅
  - `PrismKit/Sources/Components/VideoPlayer/BottomControlBarView.swift` ✅
  - `PrismKit/Sources/Components/VideoPlayer/TimelineSliderView.swift` ✅
  - `PrismKit/Sources/Extensions/TimeInterval+Formatting.swift` ✅
  - `PrismCore/Sources/Models/PlayerError.swift` ✅
  - `PrismPlayer/Sources/Features/Player/PlayerSceneView.swift` ✅
- **完成日期**: 2025-11-14

---

#### Task-1b03: SRT 字幕加载
- **故事点**: 5 SP
- **状态**: ⏳ 待开始
- **优先级**: P0
- **依赖**: Task-1b01
- **验收标准**:
  - [ ] SRTParser 实现：
    - 解析 SRT 格式文件
    - 支持多种编码（UTF-8, UTF-8-BOM, GBK 等）
    - 容错处理：格式错误、时间戳错误
  - [ ] SubtitleSegment 模型：
    - id: Int
    - startTime: TimeInterval
    - endTime: TimeInterval
    - text: String
  - [ ] 字幕文件选择：
    - macOS: NSOpenPanel
    - iOS: UIDocumentPickerViewController
  - [ ] 自动加载同名字幕：
    - 查找同目录下同名 .srt 文件
    - 如：video.mp4 → video.srt
  - [ ] 字幕文件状态管理：
    - 未加载、加载中、已加载、加载失败
  - [ ] 错误处理：
    - 文件不存在、解析失败、编码错误
    - 用户友好的错误提示
  - [ ] 单元测试：
    - 标准 SRT 格式解析
    - 时间戳解析（HH:MM:SS,mmm）
    - 多行文本处理
    - 特殊字符与 HTML 标签
    - 格式容错
- **参考**: PRD §6.1, §6.4
- **相关文件**: 
  - `PrismCore/Sources/Subtitles/SRTParser.swift`
  - `PrismCore/Sources/Models/SubtitleSegment.swift`
  - `Tests/PrismCoreTests/SRTParserTests.swift`

---

#### Task-1b04: SRT 字幕显示
- **故事点**: 8 SP
- **状态**: ⏳ 待开始
- **优先级**: P0
- **依赖**: Task-1b02, Task-1b03
- **验收标准**:
  - [ ] SubtitleRenderer 组件：
    - 根据当前播放时间显示对应字幕片段
    - 时间同步精度 ±50ms（SRT 回放无需 ASR 级别）
    - 流畅的进入/退出动画（可选）
  - [ ] 字幕样式：
    - 位置：底部居中，安全区内
    - 字体：系统字体，支持动态字号
    - 背景：半透明黑色背景（可配置透明度）
    - 颜色：白色文字（可配置）
  - [ ] 字幕开关：
    - UI 控件切换显示/隐藏
    - 状态持久化
  - [ ] 多行字幕支持：
    - 正确渲染换行
    - 最大行数限制（3-5 行）
  - [ ] 性能优化：
    - 二分查找当前时间对应片段
    - 避免不必要的重渲染
  - [ ] macOS/iOS 适配：
    - macOS: NSView/Text 实现
    - iOS: UIView/Text 实现
  - [ ] a11y 支持：
    - VoiceOver 字幕内容朗读
    - 动态字体支持
  - [ ] 测试：
    - 时间同步测试（模拟播放进度）
    - 字幕切换测试
    - 边界条件测试（空字幕、超长字幕）
- **参考**: PRD §6.5, HLD §2.3 SubtitleRenderer
- **相关文件**: 
  - `PrismKit/Sources/Components/SubtitleView.swift`
  - `PrismPlayer/Sources/Features/Player/SubtitleRenderer.swift`
  - `Tests/PrismKitTests/SubtitleViewTests.swift`

---

#### Task-1b05: 视频拖动处理（Seek）
- **故事点**: 8 SP
- **状态**: ⏳ 待开始
- **优先级**: P0
- **依赖**: Task-1b02, Task-1b04
- **验收标准**:
  - [ ] 进度条拖动实现：
    - 平滑的拖动体验
    - 实时预览时间（Tooltip/Overlay）
    - 释放后跳转到目标时间
  - [ ] 播放器 Seek 处理：
    - AVPlayer.seek(to:) 精确跳转
    - 跳转完成回调与状态更新
    - Seek 期间显示加载状态
  - [ ] 字幕同步更新：
    - Seek 后立即显示目标时间字幕
    - 字幕片段快速定位（二分查找）
    - 无字幕时显示空白或占位
  - [ ] 性能优化：
    - 防抖处理：拖动过程中避免频繁 Seek
    - 最终 Seek 一次到目标位置
  - [ ] 边界处理：
    - 文件开始/结束位置
    - 无效时间戳
    - Seek 失败错误处理
  - [ ] 用户体验：
    - Seek 后继续播放（如果之前在播放）
    - Seek 后暂停（如果之前暂停）
    - 播放状态保持一致
  - [ ] 测试：
    - Seek 精度测试（±100ms）
    - 字幕同步测试
    - 边界条件测试
    - 防抖逻辑测试
- **参考**: PRD §6.1, §6.4, US §5-3
- **相关文件**: 
  - `PrismCore/Sources/Services/PlayerService.swift`
  - `PrismPlayer/Sources/Features/Player/PlayerViewModel.swift`
  - `PrismPlayer/Sources/Features/Player/SeekHandler.swift`

---

### UI 框架（P0）

#### Task-1b06: 欢迎页（Welcome）实现
- **故事点**: 8 SP
- **状态**: ⏳ 待开始
- **优先级**: P0
- **依赖**: Task-1b01
- **验收标准**:
  - [ ] 页面布局实现：
    - 左侧功能简介卡（FeatureCard）：列表式功能介绍
    - 右侧操作卡（ActionCard）：4 个主按钮（播放文件、碟片、URL、转换）
    - 底部历史区域（HistoryBar）：最近媒体列表与清空按钮
    - 顶部工具区（TopBar）：应用名称与反馈入口
  - [ ] 响应式布局：
    - 并排布局（默认）：左右卡片横向排列
    - 垂直布局（窄窗口）：卡片纵向堆叠
    - 最小宽度适配：确保可用性
  - [ ] 交互功能：
    - 4 个打开媒体按钮触发对应动作
    - 历史项点击直接进入播放页
    - 清空历史功能
    - 解锁完整版按钮（占位）
  - [ ] 状态管理：
    - 与 AppViewModel 集成
    - 最近历史加载与显示
    - 空态处理
  - [ ] 国际化：
    - 所有文本走 I18N 资源
    - 支持中/英双语
  - [ ] 无障碍：
    - VoiceOver 支持
    - 键盘导航可达
    - 焦点管理
- **参考**: UI 结构设计 §3, AppViewModel
- **相关文件**: 
  - `PrismPlayer/Sources/Features/Welcome/WelcomeView.swift`
  - `PrismPlayer/Sources/Features/Welcome/Components/FeatureCard.swift`
  - `PrismPlayer/Sources/Features/Welcome/Components/ActionCard.swift`
  - `PrismPlayer/Sources/Features/Welcome/Components/HistoryBar.swift`

---

#### Task-1b07: 播放页（Player）框架实现
- **故事点**: 10 SP
- **状态**: ⏳ 待开始
- **优先级**: P0
- **依赖**: Task-1b02, Task-1b06
- **验收标准**:
  - [ ] 主区域布局：
    - 中心画布区（VideoCanvas）：等比缩放，自适应窗口
    - 叠加层（Overlays）：标题层（TopOverlay）、控制条（BottomControlBar）、HUD/Toast
  - [ ] 三栏布局结构：
    - 左侧：工具侧栏（ToolSidebar，图标按钮）
    - 中部：视频画布 + 叠加层
    - 右侧：播放列表抽屉（PlaylistDrawer，可折叠）
  - [ ] 控制条功能：
    - 左侧：返回、音量、静音、画中画
    - 中部：播放/暂停、上一/下一、时间轴、缓冲进度
    - 右侧：倍率、字幕、音轨、纵横比、全屏、播放列表开关
  - [ ] 显隐逻辑：
    - 鼠标移动显示控制条
    - 3s 无操作自动隐藏
    - 全屏模式强化自动隐藏
  - [ ] 窗口管理：
    - 与 AppViewModel 场景路由集成
    - 支持返回欢迎页
  - [ ] 响应式：
    - 最小窗口尺寸处理
    - 窄宽度下自动折叠播放列表
  - [ ] 国际化 & 无障碍：
    - 所有控件文本 I18N
    - VoiceOver 支持
    - 键盘快捷键（Space、方向键、F）
- **参考**: UI 结构设计 §4, PlayerViewModel 契约
- **相关文件**: 
  - `PrismPlayer/Sources/Features/Player/PlayerView.swift`
  - `PrismPlayer/Sources/Features/Player/VideoCanvasView.swift`
  - `PrismPlayer/Sources/Features/Player/BottomControlBar.swift`
  - `PrismPlayer/Sources/Features/Player/Overlays/`

---

#### Task-1b08: 工具侧栏（ToolSidebar）实现
- **故事点**: 5 SP
- **状态**: ⏳ 待开始
- **优先级**: P1
- **依赖**: Task-1b07
- **验收标准**:
  - [ ] 侧栏结构：
    - 纵向图标按钮列表
    - 7 个工具位：截图/录制、GIF、投屏、AI 字幕、调整、预设、导出
  - [ ] 显示策略：
    - 常驻窄栏：仅图标
    - 宽栏模式：图标 + 文本标签（可选）
  - [ ] 交互逻辑：
    - 点击打开对应侧面板
    - 高亮当前激活工具
    - 重复点击关闭面板
  - [ ] 侧面板占位：
    - 从左向右滑出面板
    - 压缩画布宽度
    - Esc 或侧栏点击关闭
  - [ ] 状态管理：
    - activeToolPanel 状态同步
    - 单一面板激活（互斥）
  - [ ] 样式：
    - 暗色主题适配
    - 图标资源准备（SF Symbols 或自定义）
  - [ ] 国际化 & 无障碍：
    - 工具名称 I18N
    - VoiceOver 标签
    - 键盘快捷键（Cmd+1~7）
- **参考**: UI 结构设计 §4.1, §4.3
- **相关文件**: 
  - `PrismPlayer/Sources/Features/Player/ToolSidebar/ToolSidebarView.swift`
  - `PrismPlayer/Sources/Features/Player/ToolSidebar/ToolButton.swift`
  - `PrismPlayer/Sources/Features/Player/ToolSidebar/ToolPanelHost.swift`

---

#### Task-1b09: 播放列表抽屉（PlaylistDrawer）实现
- **故事点**: 8 SP
- **状态**: ⏳ 待开始
- **优先级**: P0
- **依赖**: Task-1b07
- **验收标准**:
  - [ ] 抽屉结构：
    - 顶部：搜索框（占位）
    - 中部：列表区域（条目：标题、时长、播放状态）
    - 底部：工具栏（添加、导入、删除）
  - [ ] 折叠/展开：
    - 抽屉把手或快捷键（Cmd+L）
    - 拖拽调整宽度
    - 状态持久化
  - [ ] 列表交互：
    - 双击播放媒体
    - Enter 键播放选中项
    - Delete 键删除选中项
    - 拖拽重排（可选）
  - [ ] 空态处理：
    - 显示"添加媒体"提示
    - 快捷入口
  - [ ] 播放列表模型：
    - MediaItem 数组
    - 当前播放项标记
    - 上一/下一导航逻辑
  - [ ] 与 PlayerViewModel 集成：
    - 播放列表状态同步
    - 选中项播放
    - 列表更新触发重渲染
  - [ ] 样式：
    - 列表项设计（缩略图占位、标题、时长）
    - 当前播放高亮
    - 分隔线与间距
  - [ ] 国际化 & 无障碍：
    - 所有文本 I18N
    - VoiceOver 支持
    - 键盘导航
- **参考**: UI 结构设计 §4.1, §4.4, MediaItem 模型
- **相关文件**: 
  - `PrismPlayer/Sources/Features/Player/PlaylistDrawer/PlaylistDrawerView.swift`
  - `PrismPlayer/Sources/Features/Player/PlaylistDrawer/PlaylistItemView.swift`
  - `PrismPlayer/Sources/Features/Player/PlaylistDrawer/PlaylistViewModel.swift`

---

#### Task-1b10: PlayerViewModel 完整实现
- **故事点**: 8 SP
- **状态**: ⏳ 待开始
- **优先级**: P0
- **依赖**: Task-1b02, Task-1b07
- **验收标准**:
  - [ ] 核心状态属性（Published）：
    - 当前媒体：current, playlist
    - 播放状态：isPlaying, currentTime, duration, bufferedTime, rate
    - 音量：volume, isMuted
    - 音轨：audioTracks, selectedAudioTrack
    - 字幕：subtitleTracks, selectedSubtitleTrack, isSubtitleVisible
    - 画面：aspectMode, isFullScreen, isPipActive
    - UI 可见性：showControls, showTitleOverlay, showPlaylistDrawer, playlistWidth
    - 工具面板：activeToolPanel
  - [ ] 核心动作方法：
    - play(), pause(), togglePlayState()
    - seek(to:), next(), previous()
    - setVolume(_:), toggleMute()
    - selectAudioTrack(_:), selectSubtitleTrack(_:)
    - toggleSubtitleVisibility()
    - toggleFullScreen(), togglePip()
    - togglePlaylist(), setActiveToolPanel(_:)
  - [ ] AVPlayer 集成：
    - AVPlayer 生命周期管理
    - 时间观察器（currentTime 更新）
    - 播放状态监听（rate, status）
    - 错误处理
  - [ ] 播放列表管理：
    - 添加/删除媒体项
    - 上一曲/下一曲逻辑
    - 播放完成自动下一曲
  - [ ] 状态同步：
    - UI 控件 ↔ ViewModel 双向绑定
    - 播放器状态 → ViewModel 单向流
  - [ ] 性能优化：
    - 时间更新节流（避免过度刷新）
    - 懒加载与按需计算
  - [ ] 测试：
    - 单元测试：状态更新、动作方法
    - 模拟播放器测试
- **参考**: UI 结构设计 §6.3, HLD PlayerService
- **相关文件**: 
  - `PrismPlayer/Sources/Features/Player/PlayerViewModel.swift`
  - `Tests/PrismPlayerTests/PlayerViewModelTests.swift`

---

#### Task-1b11: 场景路由与导航实现
- **故事点**: 5 SP
- **状态**: ⏳ 待开始
- **优先级**: P0
- **依赖**: Task-1b06, Task-1b07
- **验收标准**:
  - [ ] AppViewModel 场景管理：
    - AppScene 枚举：welcome, player(url:)
    - currentScene 状态管理
    - navigateToWelcome(), navigateToPlayer(url:)
  - [ ] 场景切换逻辑：
    - 欢迎页 → 播放页：打开媒体成功
    - 播放页 → 欢迎页：播放列表为空或用户主动关闭
  - [ ] 主窗口内容切换：
    - WindowGroup 或 NavigationStack
    - 场景渐隐/无动画切换
  - [ ] 焦点管理：
    - 切换到播放页后焦点在控制条或画布
    - 切换到欢迎页后焦点在主按钮
  - [ ] 窗口策略（单窗口优先）：
    - 共享主窗口
    - 多窗口支持预留（可选）
  - [ ] 状态清理：
    - 返回欢迎页时清理播放器资源
    - AVPlayer 停止与释放
  - [ ] 测试：
    - 场景切换状态测试
    - 路由动作测试
- **参考**: UI 结构设计 §5, AppViewModel 已有代码
- **相关文件**: 
  - `PrismPlayer/Sources/Shared/App/AppViewModel.swift` (已有)
  - `PrismPlayer/Sources/Shared/App/PrismPlayerApp.swift`
  - `Tests/PrismPlayerTests/AppViewModelTests.swift`

---


## 📅 里程碑检查点

### Week 1（2025-11-14 ~ 2025-11-20）
- [ ] Task-1b06: 欢迎页实现 完成（8 SP）
- [ ] Task-1b02: 播放控件增强 完成（8 SP）
- [ ] Task-1b03: SRT 字幕加载 完成（5 SP）
- [ ] Task-1b11: 场景路由与导航 完成（5 SP）

### Week 2（2025-11-21 ~ 2025-11-27）
- [ ] Task-1b07: 播放页框架实现 完成（10 SP）
- [ ] Task-1b10: PlayerViewModel 完整实现 完成（8 SP）
- [ ] Task-1b09: 播放列表抽屉 完成（8 SP）
- [ ] Task-1b04: SRT 字幕显示 完成（8 SP）
- [ ] Task-1b05: 视频拖动处理 完成（8 SP）
- [ ] Task-1b08: 工具侧栏 完成（5 SP）
- [ ] 集成测试：完整播放流程 + UI 导航 + 字幕同步

---

## 🎯 Sprint 1b 关键目标

1. **完整 UI 框架**: 欢迎页 + 播放页三栏布局（macOS 优先）
2. **完整播放器**: 包含所有基础播放控件与状态管理
3. **SRT 字幕支持**: 加载、解析、显示外部字幕文件
4. **播放体验**: 流畅的拖动、精确的时间同步、播放列表管理
5. **测试基础**: 为 Sprint 2 ASR 集成测试提供稳定播放器与 UI

---

## 📊 风险与依赖

### 高风险项
- **Task-1b07 (播放页框架)**: 三栏布局与叠加层复杂度高
- **Task-1b10 (PlayerViewModel)**: 状态管理与 AVPlayer 集成复杂
- **Task-1b02 (播放控件)**: 跨平台 UI 适配复杂度
- **Task-1b04 (字幕显示)**: 时间同步与性能平衡

### 技术依赖
```
Task-1b01 (视频选择) [已完成]
  ├── Task-1b06 (欢迎页)
  │     └── Task-1b11 (场景路由)
  ├── Task-1b02 (播放控件)
  │     ├── Task-1b07 (播放页框架)
  │     │     ├── Task-1b08 (工具侧栏)
  │     │     ├── Task-1b09 (播放列表抽屉)
  │     │     └── Task-1b10 (PlayerViewModel)
  │     ├── Task-1b04 (字幕显示)
  │     └── Task-1b05 (拖动处理)
  └── Task-1b03 (SRT 加载)
        └── Task-1b04 (字幕显示)
```

### UI 任务依赖关系
```
欢迎页（Task-1b06）→ 场景路由（Task-1b11）→ 播放页框架（Task-1b07）
                                                    ├── 工具侧栏（Task-1b08）
                                                    ├── 播放列表（Task-1b09）
                                                    └── PlayerViewModel（Task-1b10）
```

### Sprint 间依赖
- Sprint 1b 完成后，Sprint 2 的 ASR 集成测试可以基于稳定的播放器与完整 UI 进行
- Task-1b04 的字幕显示组件可以复用到 Sprint 2 的 ASR 字幕显示
- Task-1b08 的工具侧栏为 Sprint 2 的 AI 字幕面板提供框架基础

---

## 📝 更新日志

### 2025-11-14
- **新增 UI 框架任务**（6 个，34 SP）：
  - Task-1b06: 欢迎页实现（8 SP）
  - Task-1b07: 播放页框架实现（10 SP）
  - Task-1b08: 工具侧栏实现（5 SP）
  - Task-1b09: 播放列表抽屉实现（8 SP）
  - Task-1b10: PlayerViewModel 完整实现（8 SP）
  - Task-1b11: 场景路由与导航实现（5 SP）
- **总故事点更新**: 34 SP → 68 SP
- **依据**: macOS UI 页面结构设计 v0.2
- **调整里程碑**: 扩展为完整 UI 框架 + 播放功能

### 2025-11-13
- 创建 Sprint 1b Task 列表
- 定义 5 个核心任务（34 SP）
- Task-1b01 标记为已完成（Sprint 1 遗留）
- 制定 2 周里程碑检查点

---

## 📖 参考文档

- **UI 结构设计**: `docs/1_design/hld/iOS-macOS/ui-structure-macos-v0.2.md` ✨ NEW
- **Sprint 计划**: `docs/2_scrum/iOS-macOS/sprint-plan-v0.2-updated.md`
- **PRD**: `docs/0_prd/prd_v0.2.md`
- **HLD**: `docs/1_design/hld/iOS-macOS/hld-ios-macos-v0.2.md`
- **Sprint 1 总结**: `docs/2_scrum/iOS-macOS/sprint-1/sprint-1-task-list.md`
- **Sprint 2 计划**: `docs/2_scrum/iOS-macOS/sprint-2/sprint-2-task-list.md`
- **AppViewModel**: `Prism-xOS/apps/PrismPlayer/Sources/Shared/App/AppViewModel.swift`
