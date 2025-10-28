# Task-101: 媒体选择与播放（iOS 基线）

- Sprint：Sprint 1（M1 原型）
- Task：Task-101 媒体选择与播放（Media Selection & Playback）
- PBI：Sprint 1-1（PRD §6.1；US §5-1/§5-2）
- Owner：@to-assign
- 状态：Todo

## 相关 TDD
- [x] `tdd/iOS-macOS/hld-ios-macos-v0.2.md` — 采用 PlayerService 作为唯一播放抽象；以播放器进度为字幕渲染时钟（见 §2.2 PlayerService、§5 预加载）

## 相关 ADR
- [x] `docs/adr/iOS-macOS/0002-player-view-ui-stack.md` — SwiftUI + MVVM，PlayerService 以协议注入；
- [x] `docs/adr/iOS-macOS/0005-testing-di-strategy.md` — 协议式 DI 与可替换后端，使用 Mock 进行契约测试

## 1. 目标与范围
- 目标（可量化）
  - 选择本地视频/音频文件后，能够开始播放；支持播放/暂停；提供稳定的进度回调（≥10Hz，抖动≤50ms）供字幕渲染作为“真值时钟”。
  - 首帧可见时间将在后续 PBI“极速首帧（预加载）”中优化，本 Task 不做性能保证，仅确保功能链路通。
- 范围
  - iOS 基线（SwiftUI + AVFoundation）；支持 mp4/mov/m4a/aac/wav（系统可解码）；本地文件选取使用 UIDocumentPicker。
  - 提供 PlayerView + ViewModel 骨架，与 PrismCore.PlayerService 对接。
  - 设计层面覆盖 macOS：共享 ViewModel 与 PlayerService 契约，平台差异集中在“媒体选择器封装”和极少量 UI 修饰，保证本 Task 交付后 macOS 目标可编译通过（以占位/桩件实现），功能实现排期在 Sprint 2。
- 非目标
  - macOS 端的文件选择与完整 UI 行为在本 Sprint 不做功能交付（但提供技术设计与编译通过的桩件）。
  - 倍速、后台播放、音频预加载（对应后续 PBI）。

## 2. 方案要点（引用为主）
- 采用的接口/约束/契约
  - PlayerService（`PrismCore`）：协议作为唯一播放控制入口：load(url:), play(), pause(), seek(to:), timePublisher, statePublisher。（HLD §2.2）
  - 进度时钟：以 `timePublisher` 作为字幕渲染参考时钟（UI 层只读），更新频率目标 10Hz（每 0.1s）。
  - DI：通过协议注入 PlayerService，便于测试替换为 `MockPlayerService`（ADR-0005）。
- 与 TDD 差异的本地实现细节
  1) iOS 端文件选择采用 `UIDocumentPickerViewController`（支持多类型 UTI）；选择后将 `URL` 交给 ViewModel → PlayerService.load。
  2) UI 状态：idle/loading/ready/playing/paused/error；按钮状态与可用性随 `statePublisher` 绑定。
  3) 国际化：所有 UI 文本使用 String Catalog（`player.play`/`player.pause`/`player.select_media`/错误文案 key）。

### 2.1 macOS 技术设计（与 iOS 共享方案）

- 共享层：
  - 复用 `PrismCore.PlayerService` 协议与实现；`PlayerViewModel` 与业务状态机与 iOS 共享。
  - 以 `Combine`/`AnyPublisher<TimeInterval,Never>` 为唯一渲染时钟来源，macOS 同样订阅 `timePublisher`。
- 平台差异封装：
  - 媒体选择器：定义轻量协议 `MediaPicker`（UI 层协议，不进入 `PrismCore`），在 iOS 用 `UIDocumentPickerViewController` 封装、在 macOS 用 `NSOpenPanel` 封装；通过依赖注入在 View 中提供。
  - SwiftUI 适配：采用 `#if os(macOS)`/`#if os(iOS)` 条件编译分别提供 `MediaPickerRepresentable`；其余 UI 采用共享 View，尽量以 `ViewModifier` 做小差异。
- 可编译占位策略（本 Sprint）：
  - 在 `apps/PrismPlayer-macOS` 下新增 `MediaPickerMac.swift`（实现 `MediaPicker`，最小功能：返回所选 `URL`；若本 Sprint 不实现交互，则提供占位实现与 TODO 标记，但保证编译通过）。
  - `PlayerView` 共享 View 文件中使用条件编译加载对应的 `MediaPicker`。
- 文件类型与校验：
  - 统一采用 UTType：`movie`, `mpeg4Movie`, `audio`, `wav`, `m4a` 等；选择后通过 `AVURLAsset.isPlayable` 快速校验，错误映射到 `PlayerError.unsupportedFormat`。

### 2.2 目录与文件结构（iOS + macOS）

- apps/PrismPlayer-iOS/Sources/Features/Player/
  - PlayerView.swift（共享主体 UI，条件编译包裹平台差异）
  - PlayerViewModel.swift（共享）
  - MediaPickeriOS.swift（`UIDocumentPickerViewController` 封装）
- apps/PrismPlayer-macOS/Sources/Features/Player/
  - PlayerView.swift（共享，如需微差异可用扩展/Modifier）
  - PlayerViewModel.swift（共享引用）
  - MediaPickerMac.swift（`NSOpenPanel` 封装，占位亦可）
- apps/共通
  - Resources/Localizable.xcstrings：保持 key 一致，按 target 维护多语言文案

## 3. 改动清单
- 影响模块/文件（新建，拟定路径）
  - apps/PrismPlayer-iOS/Sources/Features/Player/
    - PlayerView.swift（共享主体 UI：选择/播放/暂停/时间显示；订阅 timePublisher）
    - PlayerViewModel.swift（共享，持有 `PlayerService`；处理选择媒体与控制；公开只读 `currentTime`/`isPlaying`）
    - MediaPickeriOS.swift（UIDocumentPicker 封装为 SwiftUI `UIViewControllerRepresentable`）
  - apps/PrismPlayer-macOS/Sources/Features/Player/
    - MediaPickerMac.swift（NSOpenPanel 封装为 SwiftUI `NSViewControllerRepresentable`，本 Sprint 可为占位实现）
  - apps/*/Resources/
    - Localizable.xcstrings（新增/更新 player.* 文本条目 zh-Hans/en-US，两个 target 保持 key 一致）
- 接口/协议变更
  - 无需修改 `PrismCore.PlayerService` 协议。若后续需要更细的错误枚举映射，另起 Task 与 ADR。
- 数据/迁移
  - 无持久化变更。

## 4. 实施计划（细化至提交）

- 提交规范：Conventional Commits；每个步骤确保 iOS 与 macOS 目标均可编译（macOS 允许占位实现）。

- PR1：ViewModel 与 DI 骨架（共享）
  - commit 1: `feat(player): add PlayerViewModel with PlayerService DI and state bindings`
  - commit 2: `test(player): add ViewModel unit tests using MockPlayerService`
  - commit 3: `chore(i18n): add player.* keys to String Catalog (zh-Hans/en-US)`

- PR2：媒体选择器封装（iOS 实现 + macOS 占位）
  - commit 1: `feat(player-ios): add UIDocumentPicker-based MediaPickeriOS`
  - commit 2: `feat(player-macos): add NSOpenPanel-based MediaPickerMac (stub for Sprint 1)`
  - commit 3: `refactor(player): inject platform MediaPicker into shared PlayerView`

- PR3：PlayerView 基础 UI 与状态绑定
  - commit 1: `feat(player): add PlayerView with play/pause and time binding`
  - commit 2: `feat(player): wire timePublisher as render clock (10Hz target)`
  - commit 3: `style(i18n): replace hardcoded strings with catalog keys`

- PR4：错误处理与验证
  - commit 1: `feat(player): validate selected URL playability and map to PlayerError`
  - commit 2: `test(player): add error/unsupported format/selection cancel tests`
  - commit 3: `docs(task): update Task-101 DoD checklist and known risks`

- 验收前检查（每 PR CI gate）
  - 构建：iOS 17+/macOS 14+ Debug 构建通过。
  - Lint：SwiftLint 严格模式零警告。
  - 测试：ViewModel 单测通过，覆盖率达标（VM ≥60%）。
  - i18n：无硬编码字符串。

## 5. 测试与验收
- 单测（XCTest，目标覆盖 VM ≥60%）
  - 加载成功路径：调用 load → state 变更为 ready；play → playing；pause → paused。
  - 进度转发：Mock 模拟 `timeSubject` 推送，VM 透传至 UI 观察属性；断言抖动不放大（时间戳单调非递减）。
  - 错误路径：load 失败（`PlayerError.loadFailed`）→ UI 显示错误并回到 idle；seek 失败 → 保持上一状态并提示。
  - 选择器取消：不触发 load 调用。
- 集成/E2E（可选，后续增强）
  - iOS：使用 `Tests/Fixtures/audio/` 中 10–30s 样本，真机/模拟器播放验证按钮状态与时间递增。
  - macOS：本 Sprint 要求能编译运行应用并显示基础 UI（可无选择器交互），Sprint 2 接入 NSOpenPanel 行为与用例。
- 验收标准（与 Sprint 计划一致）
  - [ ] 支持本地视频/音频选择（iOS，UIDocumentPicker）。
  - [ ] 支持播放/暂停。
  - [ ] 提供稳定的进度回调作为字幕渲染时钟（≥10Hz），UI 可读当前时间。

## 6. 观测与验证
- 日志/指标
  - OSLog 分类：category=Player，事件：load_start/load_ready/play/pause/seek/error；错误包含 `PlayerError` code 与 message。
  - 指标（最小）：首帧样本时间戳（供后续 PBI 使用，不做阈值考核）。
- 验证方法
  - 本地：
    - iOS：模拟器 + 真机各 1 台验证常见格式（mp4/m4a/wav）。
    - macOS：编译运行应用，验证基础 UI 与日志不报错；如实现选择器，则使用样本媒体验证 URL 回传与可播放校验。
  - CI：单测与覆盖率报告通过；SwiftLint 严格模式零警告；两个 target 构建矩阵通过。

## 7. 风险与未决
- 风险 A：部分容器/编码 iOS 不支持 → 在选择后快速校验 `AVURLAsset.isPlayable`，给出友好错误与引导（参考 PRD §12）。
- 风险 B：进度频率受系统节流影响 → AVPlayer 回调频率可能 <10Hz；UI 层允许插值但以字幕渲染为主用例，后续可在 AV 层自定义 `addPeriodicTimeObserver` 间隔（100ms）。
- 未决：macOS 文件选择与共享 VM 方案（计划在 Sprint 2 完成）。

— macOS 相关补充：
- 风险 C：沙盒权限/文件访问（macOS）→ 使用安全作用域书签（如后续需要持久访问），本 Task 先以临时访问为主。
- 风险 D：NSOpenPanel 交互在沙盒应用的行为差异 → 保持默认配置（`canChooseFiles=true`、`allowsMultipleSelection=false`、`canChooseDirectories=false`）。

## 定义完成（DoD）
- [ ] CI 通过（构建/测试/SwiftLint 严格模式）
- [ ] 无硬编码字符串（国际化）
- [ ] 文档/变更日志更新（CHANGELOG 同步）
- [ ] 关键路径测试覆盖与可观测埋点到位

— 跨平台补充：
- [ ] macOS 目标可编译通过（含占位的 `MediaPickerMac` 与共享 `PlayerViewModel`）。
