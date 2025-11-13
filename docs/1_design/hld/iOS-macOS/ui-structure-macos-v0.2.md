# macOS UI 页面结构设计（框架）

类型：HLD（High Level Design）- UI 结构与导航框架（不含代码）
版本：v0.2
最后更新：2025-11-13

本文件仅定义 macOS 版本的页面结构与交互框架，用于指导后续 SwiftUI 开发与细化视觉。严格遵循仓库文档规范：分层、版本与更新日期清晰；遵循 MVVM；不涉及任何硬编码字符串与具体实现代码。

--------

## 1. 范围与目标

- 目标：将两张参考 UI 截图抽象为 macOS 应用的页面结构、布局分区、导航/窗口策略与核心状态契约。
- 非目标：
  - 不做像素级视觉稿与主题细节。
  - 不实现具体业务逻辑与 API；不写任何代码。
  - 不定义完整交互动效，仅记录关键显隐/开合与层级关系。

## 2. 信息架构总览（IA）

- 窗口层级
  - App 主窗口（单窗口优先，可扩展多窗口）
    - 场景 A：欢迎/首页（Welcome）
    - 场景 B：播放页（Player）
  - 浮层/临时界面
    - 偏好设置（Preferences）
    - 打开文件/URL 面板（系统标准面板）
    - 导出/转码对话框（系统/自定义表单）
    - 快捷键帮助/关于（模态/弹出）

切换关系：Welcome -> 打开媒体 -> Player。Player 可返回 Welcome（当播放列表为空或用户主动关闭媒体时）。

## 3. 欢迎页（Welcome）结构

视觉参考：截图 1。

### 3.1 布局分区

容器：Centered 固定宽度内容区，周边留白，整体暗色主题可适配浅色。

1) 左侧功能简介卡（FeatureCard，固定宽度）
   - 列表项（带图标 + 文本）：
     - 截图与录制
     - 制作动态图/GIF
     - 无缝投屏/串流画面
     - 自定义倍速、音轨/字幕同步
     - 转换与压缩媒体
   - 主行动按钮：解锁完整版（Primary）

2) 右侧操作卡（ActionCard，固定宽度，与左卡并排）
   - 分组标题：播放
   - 主按钮列表（纵向）：
     - 播放文件（Open File）
     - 播放碟片（Open Disc）
     - 播放 URL 媒体（Open URL）
     - 转换与压缩（Open Transcoder）

3) 底部历史/最近区域（HistoryBar，跨整行）
   - 左：最近媒体快捷入口（缩略图/文件名）
   - 右：清空记录按钮

4) 顶部工具区（TopBar）
   - 标题：应用名称
   - 右上角：反馈入口

### 3.2 交互与显隐规则

- 欢迎页为默认场景；当播放列表为空或首次启动显示。
- 任何“打开媒体”动作成功后，切换到播放页并初始化播放列表。
- 历史项点击直接进入播放页加载对应媒体；清空记录后该区为空态。

### 3.3 可自适应与可达性

- 横向布局在最小宽度下变为垂直栈：FeatureCard 在上，ActionCard 在下，间距与排版按系统字号自适应。
- 所有交互点提供可聚焦与 VoiceOver 文案（走 I18N 资源）。

## 4. 播放页（Player）结构

视觉参考：截图 2。

### 4.1 视图层级与布局

根容器：分区 + 叠加层（Split + Overlays）。

主区域（中心）：
- 画布区（VideoCanvas，等比缩放，随窗口自适应）。
- 叠加层（Overlays）：
  - 标题/信息层（TopOverlay，左上显示文件名或流标题，可隐藏）
  - 播放控制条（BottomControlBar，居中悬浮）
  - HUD/Toast（右下）

左侧：工具侧栏（ToolSidebar，纵向图标按钮）
- 功能位：
  - 截图/录制
  - GIF 制作
  - 投屏/串流
  - AI 字幕（离线 ASR 与时间轴）
  - 画面/音频调整
  - 预设/滤镜
  - 导出/文档（如 PDF 报告）
- 显示策略：
  - 常驻窄栏；窄宽度仅显示图标，宽时显示图标+标签。
  - 每个工具位打开对应“侧面板”或“弹出卡片”（详见 4.3）。

右侧：播放列表抽屉（PlaylistDrawer，可折叠）
- 结构：
  - 顶部：搜索框
  - 列表：条目（标题、时长、播放状态）
  - 底部工具栏：添加、导入、删除等
- 宽度：可拖拽；支持完全折叠为中部画布宽屏模式。

底部（可选）：全局状态栏（StatusBar，可隐藏）
- 网络/硬解/缓存状态等只读信息。

### 4.2 播放控制条（BottomControlBar）

- 左侧：返回/窗口控制、音量、静音、画中画
- 中部：播放/暂停、上一/下一、时间轴（当前时间/总时长）、缓冲进度
- 右侧：播放倍率、字幕切换、音轨切换、纵横比/填充模式、进入/退出全屏、显示/隐藏播放列表

显隐：
- 鼠标移动或键盘交互时显示，若 3s 无操作则自动淡出；全屏下更明显的自动隐藏策略。

### 4.3 工具侧栏 -> 侧面板/弹出

- 每个工具图标对应一个 Panel：
  - 截图/录制面板：区域选择、帧捕获、录屏控制。
  - GIF 面板：片段范围、尺寸/帧率、导出路径。
  - 投屏面板：目标设备列表、连接状态。
  - AI 字幕面板：
    - 任务状态（离线识别/转写进度）
    - 字幕轨列表与开关
    - 同步/校对工具（简化按钮级别描述）
  - 调整面板：画面（亮度/对比/饱和/旋转）与音频（均衡/增益）。
  - 预设/滤镜面板：预览网格、应用/重置。
  - 导出/报告面板：格式选择与选项。
- 面板呈现方式：从左侧栏向右滑出固定宽度面板；同时压缩主画布；支持 Esc/侧栏重复点击关闭。

### 4.4 播放列表抽屉（PlaylistDrawer）行为

- 折叠/展开：点击抽屉把手或快捷键；拖拽改变宽度。
- 列表项交互：双击播放、Enter 播放、Delete 删除、拖拽重排。
- 空态：展示“添加媒体”入口与快捷提示。

### 4.5 键鼠/快捷键（页面级）

- 空格：播放/暂停
- 左/右方向键：快退/快进（5s）
- 上/下方向键：音量 ±
- Cmd+O：打开文件；Cmd+U：打开 URL
- Cmd+L：显示/隐藏播放列表
- Cmd+1..7：打开相应工具侧面板标签
- F：全屏开/关

## 5. 导航与窗口策略

- 单窗口优先：Welcome 与 Player 共享一个主窗口，通过路由状态切换。
- 多窗口可选：允许“在新窗口中播放”，每个窗口维护独立播放上下文与列表。
- 场景切换：以渐隐/无动画切换，保持一致性与性能。
- 打开媒体：
  - 文件/文件夹、碟片、URL 三种入口统一走系统面板或输入弹窗。
  - 成功后确保焦点位于控制条或画布，便于立即播放。

## 6. MVVM 视图模型最小契约（仅命名与字段说明）

说明：以下为“页面结构所需”的状态与动作清单，便于实现时保持职责边界。名称仅供约定，可根据最终命名规范微调。

### 6.1 AppViewModel
- 路由状态：route ∈ {welcome, player}
- 窗口策略：isSingleWindow、openNewWindow()
- 全局偏好：theme、language、shortcutsEnabled

### 6.2 WelcomeViewModel
- 最近历史：recentItems: [MediaItem]
- 操作：openFile()、openDisc()、openURL()、openTranscoder()、clearHistory()

### 6.3 PlayerViewModel
- 当前媒体：current: MediaItem?，playlist: [MediaItem]
- 播放状态：isPlaying、currentTime、duration、bufferedTime、rate
- 音量与输出：volume、isMuted、audioTrack: [AudioTrack]、selectedAudioTrack
- 字幕：subtitleTracks: [SubtitleTrack]、selectedSubtitleTrack、isSubtitleVisible
- 画面：aspectMode、isFullScreen、isPipActive
- UI 可见性：
  - showControls、showTitleOverlay
  - showPlaylistDrawer、playlistWidth
  - activeToolPanel ∈ {none, capture, gif, cast, aiSub, adjust, presets, export}
- 动作：play()、pause()、seek(to:)、next()、previous()、toggleFullScreen()、togglePlaylist()

### 6.4 ToolPanelsViewModel（或拆分各自的 VM）
- CaptureVM：region、isRecording、snapshot(), start/stopRecording()
- GifVM：range、size、fps、export()
- CastVM：targets、connect(target)
- AISubVM：jobs、progress、enableTrack(track)、syncTools
- AdjustVM：brightness/contrast/saturation/rotation、reset()
- PresetVM：presets、apply(preset)
- ExportVM：format、options、export()

数据模型（摘要）：
- MediaItem{id, title, url, duration, type(file/url/disc)}
- SubtitleTrack{id, lang, name, isExternal}
- AudioTrack{id, lang, channels, name}

## 7. 国际化、无障碍与适配规则（页面层）

- 不使用硬编码字符串；所有标签与提示从本地化资源加载（支持中/英，默认随系统）。
- 支持 VoiceOver：为侧栏工具、控制条按钮、抽屉把手等提供 accessibilityLabel 与 hint（文案走 I18N）。
- 键盘导航可达：Tab/Shift+Tab 遍历关键控件，Focus 环清晰。
- 自适应：
  - 最小窗口尺寸定义，低于阈值时：
    - 播放列表自动折叠；侧栏仅显示图标；控制条压缩布局。
  - 全屏模式下隐藏冗余装饰，仅保留必要控件与浮层。

## 8. 性能与状态同步（结构级约束）

- 画布渲染与 UI 状态解耦；UI 刷新节流，避免与解码/渲染抢占主线程。
- 大型面板采用懒加载（首次打开再构建）。
- 播放列表与最近历史保持去重与持久化接口（不在本文细化实现）。

## 9. 验收标准（仅页面结构）

- 欢迎页：
  - 左右两张卡片并排展示，底部有历史区域与清空操作；窄宽度下自动改为上下布局。
  - 四类“打开媒体”入口可见可操作，触发后能够切换至播放页（以占位回调模拟）。
- 播放页：
  - 可见画布、左侧工具侧栏、右侧播放列表抽屉、底部控制条与顶部标题层。
  - 播放列表抽屉可折叠/展开，支持拖拽调整宽度。
  - 侧栏每个工具可打开对应面板，并能与画布并存（压缩画布有效）。
  - 控制条可显隐（空闲超时隐藏），全屏下工作正常。
- 导航：欢迎页与播放页之间的切换明确，空播放列表时返回欢迎页。
- I18N/无障碍：所有关键控件有可本地化的命名与可达性标签位。

## 10. 后续工作（不在本次交付范围）

- 视觉细化稿（暗/亮主题、图标样式与密度）。
- 具体组件树与 SwiftUI 代码框架（WindowGroup / NavigationSplitView / overlay 布局）。
- 工具面板的领域逻辑与持久化、转码/识别任务编排与进度模型。

—— 以上为 macOS 版本页面结构的高层设计，可直接用于任务拆分与组件开发排期。
