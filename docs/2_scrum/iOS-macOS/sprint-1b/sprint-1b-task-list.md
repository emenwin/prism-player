# Sprint 1b Task 列表

**Sprint 周期**: 2025-11-14 ~ 2025-11-27（预估 2 周）  
**Sprint 目标**: 完成播放器基础播放功能（优先 macOS），用于后续的集成测试  
**总故事点**: 34 SP

---

## 📊 进度概览

| 状态 | 任务数 | 故事点 | 占比 |
|------|--------|--------|------|
| ✅ 完成 | 1 | 5 SP | 14.7% |
| 🚧 进行中 | 0 | 0 SP | 0% |
| ⏳ 待开始 | 4 | 29 SP | 85.3% |

**最后更新**: 2025-11-13

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
- **状态**: ⏳ 待开始
- **优先级**: P0
- **依赖**: Task-1b01
- **验收标准**:
  - [ ] macOS: 实现 AVPlayerView 封装与自定义控件层
  - [ ] iOS: 实现 VideoPlayer/AVPlayerViewController 自定义控件
  - [ ] 播放/暂停按钮，状态同步
  - [ ] 进度条（Slider）：
    - 显示当前播放进度
    - 支持拖动跳转
    - 显示缓冲进度（可选）
  - [ ] 时间显示：
    - 当前播放时间（HH:MM:SS）
    - 总时长（HH:MM:SS）
    - 格式：00:00 / 05:30
  - [ ] 音量控制（可选）
  - [ ] 全屏/窗口化切换（macOS）
  - [ ] 播放速度选择：0.5x, 0.75x, 1.0x, 1.25x, 1.5x, 2.0x
  - [ ] 键盘快捷键（macOS）：
    - Space: 播放/暂停
    - Left/Right: ±5s 跳转
    - Up/Down: 音量调节
  - [ ] 错误处理：播放失败、解码错误
  - [ ] 自动化测试：控件状态同步、时间格式化
- **参考**: PRD §6.1, HLD §2.2 PlayerService
- **相关文件**: 
  - `PrismPlayer/Sources/Features/Player/PlayerControlsView.swift`
  - `PrismPlayer/Sources/Features/Player/PlayerViewModel.swift`
  - `PrismKit/Sources/Components/VideoPlayer.swift`

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

## 📅 里程碑检查点

### Week 1（2025-11-14 ~ 2025-11-20）
- [ ] Task-1b02: 播放控件增强 完成（8 SP）
- [ ] Task-1b03: SRT 字幕加载 完成（5 SP）

### Week 2（2025-11-21 ~ 2025-11-27）
- [ ] Task-1b04: SRT 字幕显示 完成（8 SP）
- [ ] Task-1b05: 视频拖动处理 完成（8 SP）
- [ ] 集成测试：播放 → 加载字幕 → 拖动 → 验证同步

---

## 🎯 Sprint 1b 关键目标

1. **完整播放器**: macOS 优先实现，包含所有基础播放控件
2. **SRT 字幕支持**: 加载、解析、显示外部字幕文件
3. **播放体验**: 流畅的拖动、精确的时间同步
4. **测试基础**: 为 Sprint 2 ASR 集成测试提供稳定播放器

---

## 📊 风险与依赖

### 高风险项
- **Task-1b02 (播放控件)**: 跨平台 UI 适配复杂度
- **Task-1b04 (字幕显示)**: 时间同步与性能平衡

### 技术依赖
```
Task-1b01 (视频选择) [已完成]
  ├── Task-1b02 (播放控件)
  │     ├── Task-1b04 (字幕显示)
  │     └── Task-1b05 (拖动处理)
  └── Task-1b03 (SRT 加载)
        └── Task-1b04 (字幕显示)
```

### Sprint 间依赖
- Sprint 1b 完成后，Sprint 2 的 ASR 集成测试可以基于稳定的播放器进行
- Task-1b04 的字幕显示组件可以复用到 Sprint 2 的 ASR 字幕显示

---

## 📝 更新日志

### 2025-11-13
- 创建 Sprint 1b Task 列表
- 定义 5 个核心任务（34 SP）
- Task-1b01 标记为已完成（Sprint 1 遗留）
- 制定 2 周里程碑检查点

---

## 📖 参考文档

- **Sprint 计划**: `docs/2_scrum/iOS-macOS/sprint-plan-v0.2-updated.md`
- **PRD**: `docs/0_prd/prd_v0.2.md`
- **HLD**: `docs/1_design/hld/iOS-macOS/hld-ios-macos-v0.2.md`
- **Sprint 1 总结**: `docs/2_scrum/iOS-macOS/sprint-1/sprint-1-task-list.md`
- **Sprint 2 计划**: `docs/2_scrum/iOS-macOS/sprint-2/sprint-2-task-list.md`
