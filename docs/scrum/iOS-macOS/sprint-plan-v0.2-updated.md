# Prism Player Scrum Sprint 计划（v0.2，更新稿 r1）

> 版本：v0.2 更新稿 r1  
> 日期：2025-10-17  
> 适用范围：对应 PRD v0.2 与 HLD iOS+macOS v0.2（离线字幕播放器）  
> 参考：`docs/scrum.md`（流程规范）、`docs/requirements/prd_v0.2.md`、`docs/tdd/hld-ios-macos-v0.2.md`、评审：`docs/scrum/reviews/sprint-plan-v0.2-review-claude4.5.md`

## 变更摘要（基于评审）

- 新增与强化（关键）：
  - 在 Sprint 0 增加“测试架构与 DI 策略定义”，明确单测覆盖率目标（Core/Kit≥70%，VM≥60%，关键路径≥80%），CI 立即启用测试与覆盖率报告。
  - 在 Sprint 1 增加“AsrEngine 协议定义与契约测试”“播放器与识别状态机设计与文档化”，并将“性能基线记录”和“时间同步偏差测量”纳入 DoD。
  - 在 Sprint 2 增加“后台行为与能耗策略（iOS 背景 Audio、macOS App Nap）”“JobScheduler 基础实现（并发与优先级）”“性能监控与降级逻辑基础版”“端到端集成测试与 a11y 测试”。
  - 增加技术 Spike：VAD + 对齐方案评估（S2，时间盒 3–5 天，可与 MLX Swift 后端评估并行）。
   - 新增“字幕翻译”能力规划：采用“ASR 转写 → 本地 NMT 翻译”两段式，首批支持英文→中文（S2 交付基础版，S3 优化与扩展语对）。
- 明确双后端路径：Sprint 1 仅集成 whisper.cpp；Sprint 2 可选 MLX Swift 后端评估（macOS 优先，标注实验特性）。
- KPI 与验收更新：补充时间同步偏差±200ms的测量方法与验收阈值；导出成功率≥99%增加专项测试；每 Sprint Review 展示指标样本与趋势。
   - 增补翻译指标：译文段可见延迟（自 ASR 段产出到译文渲染的耗时 P95）纳入 Review 展示；译文导出正确性专项用例。
- 能力与容量：Sprint 2 建议 3.5–4 周（~75 SP）；Sprint 3 建议 3.5 周（~70 SP）。
- 文档与流程：引入 ADR（`docs/adr/`）与 CHANGELOG 规范；DoD 强化 a11y 与隐私检查；新增 Metrics schema 与接口定义。

---

## 0. 概述

- 迭代节奏：每个 Sprint 2–4 周；以 3 个里程碑（M1/M2/M3）规划 3 个 Sprint。
- 产品目标摘要：本地播放 + 端侧离线 ASR，边播边出字幕；基础样式与 SRT/VTT 导出；模型下载/导入/删除；中英 i18n 与可访问性基线。
- KPI 对齐（PRD §2）：
  - 首帧字幕可见时间（P95）。
  - 时间同步偏差：|字幕时间 − 播放器时间| ≤ 200ms（P95），测量方法见“5. 验收与度量”。
  - RTF 处理率（≥0.3/0.5/1.0 分档）。
  - 导出成功率 ≥ 99%（自动化用例覆盖异常路径）。
- DoR/DoD（增补）：
  - 禁用硬编码字符串，采用 String Catalog（zh-Hans/en-US）。
  - SwiftLint 严格模式通过。
  - 单测覆盖率目标：Core/Kit 层 ≥70%；ViewModel 层 ≥60%；关键业务路径 ≥80%。
  - 性能基线数据记录（首帧/RTF/内存样本，至少 3 个设备档位）。
  - 可访问性检查（Sprint 2+）：VoiceOver 标签、动态字体 3 档、高对比度模式。
  - 隐私与合规：PrivacyInfo.xcprivacy 更新；第三方许可清单。
  - CI：构建 iOS 17+/macOS 14+ 矩阵；启用单元测试与覆盖率报告（可对接 Codecov）。
  - 文档：关键技术决策以 ADR 形式记录；CHANGELOG 持续维护。

---

## 1. 里程碑与 Sprint 划分（与 PRD §10 对齐）

- Sprint 0（工程基线/仓库初始化，建议 1.5 周，~20 SP）
- Sprint 1（M1 原型，建议 2 周，~40 SP）
- Sprint 2（M2 可用版，建议 3.5–4 周，~83 SP）
- Sprint 3（M3 优化版，建议 3.5 周，~70 SP）

注：具体周数在 Sprint Planning 时根据容量微调（±0.5 周）。

---

## 2. Sprint 0（工程基线，建议 1.5 周，~20 SP）

- 目标：建立工程基线，完成仓库与编码规范、构建配置、基础自动化与模板，确保 M1 开发顺畅启动。
- 范围与 PBIs
  1) 仓库初始化与协作规范（3 SP）
     - Git 分支策略（main/dev/feature-*），Conventional Commits；.gitignore、LICENSE、README、CONTRIBUTING；CODEOWNERS、Issue/PR 模板。
  2) 多平台工程脚手架（HLD §13）（3 SP）
     - Xcode 多平台工程与 Swift Package：packages/PrismCore、PrismASR、PrismKit；apps 目标（iOS/macOS）。
  3) 代码规范与质量基线（2 SP）
     - SwiftLint（严格模式）与规则；CI 中启用 Lint；String Catalog 初始化。
  4) 构建与 CI 基线（3 SP）
     - GitHub Actions/GitLab CI：构建 iOS/macOS、运行 Lint、运行单元测试（即使早期仅占位）。
  5) 数据与存储占位（2 SP）
     - SQLite 方案占位与迁移框架；应用沙盒路径约定与文件夹结构（Models/AudioCache/Exports）。
  6) 安全/隐私与合规占位（2 SP）
     - PrivacyInfo.xcprivacy 占位；Info.plist 权限说明本地化；第三方与模型许可清单模板。
  7) 指标与日志占位（2 SP）
     - OSLog 分类与级别；Metrics 接口占位（首帧、RTF）。
  8) 开发体验（可选）（1 SP）
     - pre-commit hook（lint/format）；swift-format 评估。
  9) 测试架构与 DI 策略定义（新增，5 SP，P0）
     - 选择 DI 方案（协议式 DI/轻量容器）；Mock/Stub 约定与目录结构（`Tests/Mocks/`、`Tests/Fixtures/`）。
     - 配置 XCTest 目标与覆盖率收集（slather/xcov）；CI 集成覆盖率报告。
     - 示例用例：Mock AsrEngine、Mock PlayerService。
  10) ADR 目录与模板（新增，1 SP，P3）
      - `docs/adr/` 目录与模板；首批 ADR：DI 方案选择、双后端策略。
- 交付物：可构建多平台工程；CI 工作流（构建+Lint+单测+覆盖率）；本地化与隐私占位；Issue/PR 模板；ADR 模板；测试与 DI 骨架。
- 风险与回退：
  - CI 签名受限 → 仅跑 Debug 构建与单测；发布签名后续配置。
  - 依赖选择未定 → 以原生方案占位，后续可替换（如 GRDB）。

---

## 3. Sprint 1（M1 原型，建议 2 周，~40 SP）

- Sprint Goal：实现“选择本地媒体后，数秒内看到首帧字幕，播放中有基础字幕显示，并可导出 SRT”。
- 范围与 PBIs（含来源与验收）
  1) 媒体选择与播放（5 SP，PRD §6.1；US §5-1/2）
     - AC：支持本地视频/音频选择；播放/暂停；进度回调作为字幕渲染时钟（HLD §2.2 PlayerService）。
  2) 音频预加载与极速首帧（8 SP，PRD §6.2；KPI §2）
     - AC：默认预加载 30s；首帧快速窗 5–10s 并行抽取（HLD §5 预加载）。
  3) AsrEngine 协议定义与 WhisperCppBackend（新增，5 SP，HLD §6.1/§6.2）
     - AC：定义 `AsrEngine` 协议、`AsrOptions`/`AsrLanguage`；实现 `WhisperCppBackend`（gguf 模型加载 → 返回 `[Segment]`）。
     - 测试：协议契约测试（Mock）与最小金样本回归（3 段 × 10–30s）。
  4) 播放器与识别状态机设计与文档化（新增，5 SP，讨论清单）
     - AC：状态枚举与转移规则；快速 seek 冲突处理（取消过期任务，记录最新 seekId）；Mermaid 状态图；Swift 骨架与单测。
  5) 字幕渲染（基础样式）与同步（5 SP，PRD §6.4/§6.5）
     - AC：以播放器时间为唯一时钟；底部居中；字号 1 档、默认主题；记录时间偏差样本，目标±200ms（P95）。
  6) SRT 导出（基础）（3 SP，PRD §6.6；US §5-5）
     - AC：UTF-8；<源文件名>.<locale>.srt；时间戳格式正确；避免覆盖；空间检查基础提示；专项导出用例（空/特殊字符）。
  7) 指标与诊断（最小化）（2 SP，HLD §6.7/§2.1）
     - AC：记录首帧时间、段耗时样本（本地）；日志可用于问题反馈包。
- 交付物：可运行原型（iOS）；短视频 Demo；SRT 样例；性能基线记录（首帧/RTF）。
- DoD 强化：
  - 时间同步偏差测量方法：以播放器进度回调为真值，采样已显示字幕起止与当前时间，计算绝对偏差分布（P95≤200ms）。
  - CI：多 OS 构建矩阵；单测与覆盖率报告；协议契约测试通过。
- 风险与回退：
  - 设备性能不足 → 降级更小模型/缩短窗长；UI 提示（PRD §12）。
  - 时间戳偏差 → 先满足“看得上”，记录差值，后续在 S3 优化。

---

## 4. Sprint 2（M2 可用版，建议 3.5–4 周，~83 SP）

- Sprint Goal：完成滚动增量识别与模型管理，改善使用体验与可用性，支持 macOS 基线，并落实后台与并发策略。
- 范围与 PBIs
  1) 增量识别与滚动字幕（13 SP，PRD §6.4；US §5-2）
     - AC：按 15–30s 段滚动抽取与识别，增量落盘并驱动 UI（HLD §5）。
  2) 进度拖动后的优先识别（基础版）（8 SP，PRD §5-3；§6.4）
     - AC：seek 后展示已识别片段，未识别片段显示占位；队列对“seek 点起后窗口”提高优先级（简化版）。
  3) 缓存与内存策略（基础）（8 SP，PRD §6.2；HLD §7）
     - AC：音频缓存 ≤10MB，LRU 淘汰；内存警告仅保留“当前 ±15s”。
  4) 模型管理（下载/导入/删除）与语言选择（13 SP，PRD §6.3/§6.7）
     - AC：展示大小/进度/校验（SHA256）；空间检查；至少保留一个可用模型；语言自动/手动选择与持久化。
     - 数据：`ModelMetadata` 增加 `backend: AsrBackend` 与 `supportsTimestamps: Bool` 字段。
  5) 倍速播放适配（0.5–2.0x）（5 SP，PRD §6.1/§6.4）
     - AC：字幕显示时长与播放速度等比；识别明显落后时弱提示。
  6) VTT 导出（可选增强）（3 SP，PRD §6.6）
  7) macOS 目标最小可用（6 SP，HLD §3）
     - AC：NSOpenPanel 打开文件；播放、基础识别与渲染、导出。
  8) 设置页与一键清理（5 SP，PRD §6.7）
     - AC：预加载时长 10/30/60s；缓存清理；最近语言与模型记忆。
  9) 指标与离线统计（基础）（3 SP）
     - AC：首帧、RTF、段失败率本地记录；问题反馈包开关雏形（不含原媒体）。
  10) 后台行为与能耗策略（新增，13 SP，P0，PRD §7；HLD §10）
      - iOS：Audio 背景模式下持续识别；非播放态规划 BGProcessingTask（可推迟实现）；低电量/温度降速策略。
      - macOS：`NSProcessInfo.beginActivity` 抑制 App Nap；屏幕关闭策略；回到前台进度衔接。
      - AC：播放中切后台识别不中断；回前台进度衔接；低电量提示与降速；基础能耗记录。
  11) JobScheduler 基础实现（新增，8 SP，P1，HLD §2.2）
      - 优先级：抢占（seek）> 滚动 > 预加载；取消机制；Actor 封装；无死锁单测。
  12) 性能监控与降级逻辑（基础）（新增，5 SP，P2）
      - PerformanceMonitor 采集 RTF/内存/电量；阈值：RTF<0.3 → 提示换模型；内存警告 → LRU 清理。
  13) 端到端集成测试与 a11y 测试（新增，8 SP，P2）
      - 场景：选择媒体→首帧→滚动→seek→导出→验证文件（iOS+macOS）；
      - a11y：VoiceOver 朗读关键控件；动态字体 3 档；高对比度。
  14) MLX Swift 后端评估 Spike（可选，5 SP，P1，时间盒 3 天）
      - macOS Apple Silicon 优先；实现 `AsrEngine` 协议最小推理；与 whisper.cpp 对比样本。
  15) VAD + 对齐方案评估 Spike（新增，可选，5 SP，P1，时间盒 3–5 天）
      - 评估 WebRTC/Silero VAD；短窗推理 + 切段 + 简易对齐（DTW/能量峰值）；精度报告与回退策略。
   16) 字幕翻译基础版（新增，8 SP，P0，PRD §6.10；HLD §2/§5/§12）
         - AC：
            - TranslationEngine 协议与最小本地 NMT 后端（英→中）实现；
            - 流水线：ASR 片段产出后进入翻译队列，优先“当前窗口”，未完成显示“翻译中…”；
            - 设置：字幕语言选择（原文/翻译 zh-Hans/（可选）双语），持久化；
            - 导出：支持选择译文轨导出，命名包含目标语言；
            - 测试：协议契约测试 + 金样本（英→中 30s ×3 段）译文正确性与时间对齐（±200ms）。
- 交付物：iOS + macOS 可用版；模型管理 UI；后台与并发基础；翻译字幕（英→中）基础版；VTT（如启用）。
- 风险与回退：
  - 后台/能耗限制：播放中优先保障；非播放批处理推迟；状态清晰提示。
  - 下载失败/空间不足：进度、重试、清理工具、可恢复提示。

---

## 5. Sprint 3（M3 优化版，建议 3.5 周，~70 SP）

- Sprint Goal：达成性能与稳定性目标，完善质量感知与错误/诊断体系，完成 a11y 与长视频策略。
- 范围与 PBIs
  1) 抢占式调度完善（13 SP，PRD §5-3；HLD §2.2/§5）
     - AC：抢占优先级 > 滚动 > 预加载；取消过期任务；公平性与背压策略；并发无饥饿单测。
  2) 性能与能耗优化（13 SP，PRD §7；KPI §2）
     - AC：多档位设备 RTF/首帧达标或降级提示；段间节流；后台降速；热管理；能耗曲线可视化。
  3) 质量感知与按段重识别（8 SP，PRD §6.9）
     - AC：低置信度弱提示样式；按段以更高精度模型重识别入口与耗时提示；策略可配置。
  4) 错误处理与诊断包（8 SP，PRD §6.8；HLD §8）
     - AC：统一错误码；问题反馈包（配置/设备/时序日志，脱敏）。
  5) 长视频策略与持久化（8 SP，PRD §6.2；HLD §4/§7）
     - AC：按需提取与增量落盘；冷启动恢复进度；内存不随时长线性增长；>1h 稳定性通过。
  6) a11y 与 i18n 完善（4 SP，PRD §7）
     - AC：动态字体/对比度达标；屏幕阅读器标签完整；无硬编码；复数/RTL 预留。
  7) 测试与 CI 增强（4 SP，HLD §13；讨论清单）
     - AC：金样本回归（英文/中文/噪声 3 套）、基础 WER 指标、内存泄漏检查、构建矩阵维持；发布前检查清单。
  8) ADR 与 CHANGELOG 规范（新增，2 SP，P3）
     - AC：关键决策以 ADR 固化；CHANGELOG.md 每 PBI 更新。
- 交付物：优化版应用；性能/稳定性报告；问题反馈包原型；测试与 CI 报告；ADR/CHANGELOG 规范落地。
- 风险与回退：
  - VAD/对齐精度不足：回退 whisper.cpp 时间戳模型；UI 明示精度提示。
  - MLX 在 iOS 成熟度：继续 macOS 优先，iOS 标注实验特性。

---

## 6. 验收与度量（跨 Sprint）

- 验收口径：
  - 用户故事（PRD §5）逐项通过；Out of Scope（PRD §11）不提前引入。
  - 导出：SRT/VTT 正确、UTF-8、时间戳准确；失败可重试（含异常路径）。
  - 隐私：默认离线，不上传媒体/字幕；隐私清单与权限文案符合规范。
- 关键指标与测量：
  - 首帧时间：从媒体选择到第一条字幕出现的耗时（P95）。
  - 时间同步偏差：以播放器回调时间为真值，记录字幕显示时间与参考时间差，统计 P95 ≤ 200ms。
  - RTF：段识别耗时 / 段音频时长，记录区间与 P50/P95。
   - 译文延迟：自 ASR 段产生到译文段渲染的耗时；目标 P95 ≤ 2s（基础版）。
  - 导出成功率：自动化测试覆盖正常与异常；≥99%。
  - 每次 Sprint Review 展示指标仪表盘与趋势；未达标则制定优化/降级计划。

---

## 7. 角色与会议节奏

- 角色：PO、开发、QA（可轮值）、架构/性能（跨职能）。
- 会议：遵循 `docs/scrum.md`（Planning、Daily、Review、Retro）。
- 工件：Product Backlog、Sprint Backlog、Increment；燃尽图与指标面板（轻量）。

---

## 8. 依赖与风险清单（更新）

- 依赖：
  - whisper.cpp（稳定，Metal/Accelerate）；URLSession 背景下载（iOS）。
   - SQLite/GRDB；String Catalog；mlx-swift（实验，macOS 优先）。
   - 本地 NMT 翻译模型（Marian/NLLB/量化 LLM，取决于许可与体积，英→中为首批）。
- 风险与对策：
  - 系统后台限制（高）：iOS Audio 模式；非播放批处理（BGProcessingTask 规划）；macOS App Nap 抑制；用户提示与恢复入口。
  - VAD/对齐精度（高）：S2 Spike 评估；不达标则回退时间戳模型。
  - 低端设备性能（中-高）：模型降级/窗长缩短/节流与提示；阈值化降级策略。
  - 长视频稳定性（中）：S3 专项压测与内存监测。
  - App Store 审核（模型下载）（中）：首启引导与离线说明；体积提示与清理。
   - 翻译质量与体积（中-高）：首批限定语对与小模型；提供回退到原文；必要时提供联网翻译开关与明示文案（仅上传转写文本）。

---

## 9. 追踪与交付物模板

- 每个 PBI 必含：描述、来源（PRD/HLD 章节）、验收标准（AC）、估算（SP）、依赖、测试要点、降级/回退策略。
- Demo Checklist（每次 Review）：首帧出字、滚动识别、seek 抢占、样式切换、导出、模型管理、倍速适配、缓存清理、后台切换、a11y。
- 文档：ADR 记录关键决策；CHANGELOG 记录新增/修复/破坏性变更。

---

## 10. 建议的初始 Backlog（更新与估算）

- Sprint 0（合计 ~20 SP）
  - 脚手架/规范/CI/存储/隐私/日志（14）
  - 测试架构与 DI（5）
  - ADR 模板（1）
- Sprint 1（合计 ~40 SP）
  - 播放器与时钟（5）/ 预加载与极速窗（8）/ AsrEngine 协议+Whisper 后端（5）/ 状态机设计与骨架（5）/ 渲染与样式基础（5）/ SRT 导出（3）/ 指标最小化（2）/ CI 矩阵与覆盖率（2 已含在 DoD）
- Sprint 2（合计 ~75 SP）
   - 滚动识别（13）/ seek 优先基础（8）/ 缓存与 LRU（8）/ 模型管理与语言（13）/ 倍速（5）/ VTT 可选（3）/ macOS 基线（6）/ 设置与清理（5）/ 指标基础（3）/ 后台与能耗（13）/ JobScheduler（8）/ 监控与降级（5）/ E2E + a11y 测试（8）/ 翻译基础版（8）/ MLX Spike（5 可选）/ VAD Spike（5 可选）
- Sprint 3（合计 ~70 SP）
   - 抢占式调度完善（13）/ 性能与能耗优化（13）/ 质量感知与重识别（8）/ 错误与诊断包（8）/ 长视频策略（8）/ 翻译优化与语对扩展（8）/ a11y 与 i18n 完善（4）/ 测试与 CI 增强（4）/ ADR & CHANGELOG 规范（2）

---

附注：VTT 与 MLX/VAD Spike 为可选项，资源不足时可推迟至 Sprint 3；Sprint 2 周期可按容量延长至 4 周以降低风险。
