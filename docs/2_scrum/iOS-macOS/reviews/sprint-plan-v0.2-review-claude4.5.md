# Prism Player Sprint Plan v0.2 评审报告

> 评审版本：v1.0  
> 评审日期：2025-10-17  
> 评审人：Claude 4.5（AI 架构评审）  
> 评审对象：`docs/scrum/sprint-plan-v0.2.md`  
> 参考文档：
> - `docs/requirements/prd_v0.2.md`（产品需求）
> - `docs/tdd/hld-ios-macos-v0.2.md`（高级架构设计）
> - `docs/tdd/hld-ios-macos-v0.2-discussion-list.md`（待讨论项）

---

## 执行摘要

**整体评价：良好（B+ / 85分）**

Sprint Plan v0.2 整体结构清晰，与 PRD v0.2 和 HLD v0.2 保持了良好的对齐。三个里程碑的划分合理，逐步递进。但在以下关键领域需要加强：

**优势（Strengths）：**
1. ✅ 里程碑划分与 PRD §10 完全一致，渐进式交付策略明确
2. ✅ 每个 PBI 都标注了来源（PRD/HLD 章节），可追溯性强
3. ✅ 明确了 DoR/DoD 并强化了代码规范（SwiftLint、String Catalog）
4. ✅ 新增 Sprint 0 用于工程基线建设，务实且必要
5. ✅ 风险识别与回退策略在各 Sprint 中都有体现

**待改进（Needs Improvement）：**
1. ⚠️ **缺少明确的测试策略与覆盖率目标**（与 HLD 讨论清单高优先级不符）
2. ⚠️ **后台行为与能耗策略在 Sprint 1/2 中未充分体现**（PRD §7 NFR 要求）
3. ⚠️ **双后端 ASR 方案（whisper.cpp + MLX Swift）的集成路径不明确**（HLD §6 核心设计）
4. ⚠️ **性能基准测试与回归框架推迟到 Sprint 3，风险较高**（HLD 讨论清单建议 M1 前明确）
5. ⚠️ **状态机与并发冲突处理（如快速 seek）未体现在 PBI 中**（HLD 讨论清单高优先级）

---

## 1. 与 PRD v0.2 的对齐分析

### 1.1 范围对齐（Scope Alignment）

| PRD 章节 | Sprint Plan 覆盖情况 | 评分 | 备注 |
|---------|---------------------|------|------|
| §3 In Scope - 本地媒体播放 | ✅ Sprint 1 PBI-1 | A | 完整覆盖 |
| §3 In Scope - 音频预加载 | ✅ Sprint 1 PBI-2 | A | 含极速首帧优化 |
| §3 In Scope - 端侧 ASR | ✅ Sprint 1 PBI-3 | B+ | 仅 whisper.cpp，MLX 路径不明 |
| §3 In Scope - 字幕展示与样式 | ✅ Sprint 1/2 | A | 基础+增强分阶段 |
| §3 In Scope - SRT/VTT 导出 | ✅ Sprint 1/2 | A | SRT 必选+VTT 可选 |
| §3 In Scope - 模型管理 | ✅ Sprint 2 PBI-4 | A | 下载/导入/删除完整 |
| §3 In Scope - 国际化与 a11y | ⚠️ Sprint 0/3 分散 | B | 基线在 S0，完善在 S3，中间缺验证 |
| §3 Out of Scope | ✅ 未提及云端/账户/翻译等 | A | 正确排除 |

**改进建议：**
- 在 Sprint 1 的 PBI-3 中明确说明"仅集成 whisper.cpp 后端，MLX Swift 后端作为 Sprint 2/3 的可选实验特性"。
- 在 Sprint 2 中增加"国际化与 a11y 中期验证"PBI，避免到 Sprint 3 才发现基础问题。

### 1.2 成功指标对齐（KPI Alignment）

| PRD §2 指标 | Sprint Plan 体现 | 评分 | 备注 |
|------------|------------------|------|------|
| 首帧字幕可见时间（分档）| ✅ Sprint 1 验收 + Sprint 3 优化 | A | 有记录与达标要求 |
| 时间同步偏差 ±200ms | ⚠️ Sprint 1 提及"记录实测"| B | 缺乏验收阈值与测试方法 |
| 处理率 RTF（分档）| ✅ Sprint 1 记录 + Sprint 3 优化 | B+ | 缺少中间 Sprint 的监测 |
| 导出成功率 ≥99% | ⚠️ 仅 Sprint 2 PBI-9 提及 | C | 无专项测试计划 |
| 稳定性（连续可见/缺字占位）| ✅ Sprint 2 PBI-1/2 验收 | A | 有明确行为要求 |

**改进建议：**
- 在 Sprint 1 DoD 中增加"时间同步偏差测量方法与基线数据"要求。
- 在 Sprint 2 增加"导出成功率自动化测试"PBI（如覆盖异常路径：空间不足、权限拒绝、格式异常等）。
- 在每个 Sprint Review 的 Demo Checklist 中增加"关键指标仪表盘展示"要求。

### 1.3 用户故事验收对齐（User Stories AC）

| PRD §5 用户故事 | Sprint Plan PBI | 评分 | 备注 |
|----------------|-----------------|------|------|
| US-1: 快速看到首条字幕 | ✅ Sprint 1 PBI-2/3/4 | A | 对应预加载+ASR+渲染 |
| US-2: 播放中持续滚动字幕 | ✅ Sprint 2 PBI-1 | A | 增量识别明确 |
| US-3: 拖动后尽快获得字幕 | ⚠️ Sprint 2 PBI-2（基础版）<br>✅ Sprint 3 PBI-1（完善版）| B+ | 分阶段合理，但 S2 "简化版"定义模糊 |
| US-4: 调整字幕样式与开关 | ✅ Sprint 1 PBI-4 + Sprint 2 增强 | A | 基础+高级分阶段 |
| US-5: 导出字幕文件 | ✅ Sprint 1/2 PBI-5/6 | A | SRT+VTT 分阶段 |
| US-6: 离线使用 | ✅ Sprint 1 PBI-3（内置模型）<br>✅ Sprint 2 PBI-4（下载/导入）| A | 覆盖完整 |
| US-7: 后台继续识别 | ❌ **缺失** | **D** | **重要遗漏** |
| US-8: 了解字幕质量与改进 | ✅ Sprint 3 PBI-3 | B+ | 推迟到 S3 合理，但无中间指标 |

**改进建议（关键）：**
- **立即在 Sprint 2 增加 PBI：后台行为与能耗策略**
  - 描述：实现 iOS Audio 背景模式下的持续识别；macOS NSProcessInfo.beginActivity 抑制 App Nap；电量与热管理降速策略。
  - 验收：播放中切换到后台，识别不中断；回到前台进度衔接；低电量自动降速并提示；非播放态的后台任务规划（可推迟到 S3 BGProcessingTask）。
  - 来源：PRD §5-US7、§7-NFR 后台行为、HLD §10。
- 在 Sprint 2 PBI-2 中明确"基础版"指：优先级提升 + 取消过期任务，"完善版"（S3）指：背压与公平性。

---

## 2. 与 HLD v0.2 的对齐分析

### 2.1 架构组件覆盖

| HLD §2.1 组件 | Sprint Plan 集成点 | 评分 | 备注 |
|--------------|-------------------|------|------|
| PlayerService (AVFoundation) | ✅ Sprint 1 PBI-1 | A | 明确 |
| AudioExtractService | ✅ Sprint 1 PBI-2 | A | 预加载+滚动 |
| AsrEngine（双后端协议）| ⚠️ Sprint 1 仅 whisper.cpp | B | **MLX Swift 路径不明** |
| SubtitleStore (SQLite) | ✅ Sprint 0（schema）+ Sprint 1/2（使用）| A | 增量落盘明确 |
| ModelManager | ✅ Sprint 2 PBI-4 | A | 完整覆盖 |
| CacheManager (LRU) | ✅ Sprint 2 PBI-3 | A | 明确 |
| ExportService (SRT/VTT) | ✅ Sprint 1/2 PBI-5/6 | A | 分阶段 |
| MetricsService | ⚠️ Sprint 1/2/3 分散 | B | 缺少统一接口与测试 |
| JobScheduler（并发调度）| ⚠️ Sprint 2 PBI-2 + Sprint 3 PBI-1 | **C** | **并发策略模糊** |

**改进建议（关键）：**
1. **在 Sprint 1 中增加 PBI：AsrEngine 协议定义与 WhisperCppBackend 实现**
   - 描述：定义 `AsrEngine` Swift 协议（HLD §6.1）与 `AsrOptions`/`AsrLanguage` 类型；实现 `WhisperCppBackend`（whisper.cpp 桥接）。
   - 验收：协议可编译；WhisperCppBackend 可加载 gguf 模型并返回 `[Segment]`；单元测试覆盖协议合约（Mock）。
   - 来源：HLD §6.1/§6.2。

2. **在 Sprint 2 增加可选 PBI（实验特性）：MLXSwiftBackend 原型（macOS 优先）**
   - 描述：基于 mlx-swift 实现 `AsrEngine` 协议；仅 macOS Apple Silicon；标注实验特性。
   - 验收：可加载兼容 ASR 模型；基础推理可用；性能与 WhisperCpp 对比数据。
   - 来源：HLD §6.3；讨论清单§MLX Swift 成熟度。
   - DoD 补充：如 MLX Swift 在 iOS 不可用或体积超标，明确降级为"macOS only + 实验标签"。

3. **在 Sprint 2 增加 PBI：JobScheduler 基础实现（并发与优先级）**
   - 描述：实现任务队列（预加载/滚动/抢占三类）；优先级排序；取消机制；Actor 封装（HLD §2.2）。
   - 验收：seek 后可取消过期任务；优先级队列测试；无死锁（单元测试）。
   - 来源：HLD §2.2、讨论清单§并发/调度。

### 2.2 跨平台策略（iOS vs macOS）

| HLD §3 要求 | Sprint Plan 体现 | 评分 | 备注 |
|-------------|------------------|------|------|
| UI（SwiftUI 统一） | ✅ Sprint 0（工程结构）+ Sprint 2 PBI-7 | A | macOS 目标明确 |
| 文件访问（Picker 差异）| ✅ Sprint 1 PBI-1 + Sprint 2 PBI-7 | A | iOS/macOS 分别处理 |
| 后台行为（Audio 模式 vs App Nap）| ❌ **缺失** | **D** | **与 2.1 重复，关键遗漏** |
| 下载（URLSession 背景配置）| ✅ Sprint 2 PBI-4 | B+ | iOS 明确，macOS 待细化 |
| 加速（Metal vs Accelerate）| ✅ Sprint 1 PBI-3（whisper.cpp）| B+ | MLX 路径不明 |

**改进建议：**
- 在 Sprint 2 新增的"后台行为与能耗策略"PBI 中，明确 iOS 与 macOS 的实现差异（参考 HLD §10）。

### 2.3 数据模型与存储

| HLD §4 模型 | Sprint Plan 体现 | 评分 | 备注 |
|------------|------------------|------|------|
| Segment | ✅ Sprint 1 PBI-3/4 | A | ASR 输出+渲染 |
| WindowIndex | ⚠️ Sprint 2 PBI-1（增量识别）| B | 未显式提及索引表 |
| ModelMetadata（含 backend 字段）| ✅ Sprint 2 PBI-4 | B+ | 需扩展支持双后端 |
| Settings | ✅ Sprint 2 PBI-8 | A | 明确 |
| Metrics | ⚠️ Sprint 1/2/3 分散 | B | 缺少统一 schema |

**改进建议：**
- 在 Sprint 1 DoD 中增加："SQLite schema 定义 Segment/Settings 表，包含迁移版本号"。
- 在 Sprint 2 PBI-4（模型管理）中明确："ModelMetadata 增加 `backend: AsrBackend` 与 `supportsTimestamps: Bool` 字段（HLD §6.4）"。
- 在 Sprint 2 增加 PBI："Metrics schema 与 MetricsService 接口定义"（为 Sprint 3 优化做准备）。

---

## 3. 与讨论清单的对齐分析

### 3.1 高优先级项（M1 前需明确/完成）

| 讨论清单项 | Sprint Plan 覆盖 | 评分 | 备注 |
|-----------|------------------|------|------|
| VAD + 对齐方案（非时间戳模型）| ❌ **完全缺失** | **F** | **关键风险未规划** |
| 状态机与状态转移图补全 | ❌ **缺失** | **D** | 并发冲突未体现 |
| 性能基准测试与回归框架 | ⚠️ Sprint 3 PBI-7 | **C** | **推迟到 M3，风险高** |
| 依赖注入（DI）策略与测试架构 | ⚠️ Sprint 0（占位）| **C** | **测试架构不明确** |

**改进建议（关键）：**

1. **在 Sprint 1 或 Sprint 2 增加技术 Spike PBI：VAD + 对齐方案评估**
   - 描述：评估 VAD 库（如 WebRTC VAD、Silero VAD）；设计短窗推理 + VAD 切段 + 简易对齐（DTW/能量峰值）方案；验证 ±200ms 精度可行性。
   - 交付物：技术方案文档、POC 代码、精度测试报告、回退策略（若精度不达标，回退 whisper.cpp 时间戳模型）。
   - 来源：讨论清单§高优先级-VAD；HLD §6.3/§6.8。
   - **时间盒：3–5 天**（不应阻塞主线）。

2. **在 Sprint 1 增加 PBI：播放器与识别状态机设计与文档化**
   - 描述：定义状态枚举（waiting/loading/playing/paused/seeking/failed）与转移规则；设计并发冲突处理（快速 seek → 取消前次 seek 任务并记录最新 seekId）；绘制状态转移图。
   - 交付物：状态机文档（Mermaid 图）+ Swift 实现骨架 + 单元测试（状态转移正确性）。
   - 来源：讨论清单§高优先级-状态机；评审一§1.2。

3. **在 Sprint 1 DoD 中强制要求：性能基准数据记录**
   - 要求：每个关键路径（预加载、首帧识别、滚动识别、导出）记录耗时/内存/RTF 基线数据（至少 3 个设备档位样本）。
   - 交付物：`performance-baseline-v0.1.md` 文档，包含测试设备、OS 版本、模型、测量方法与数据。
   - 目的：为 Sprint 3 优化提供对比基准；提前发现性能热点。

4. **在 Sprint 0 增加 PBI：测试架构与 DI 策略定义**
   - 描述：选择 DI 方案（协议式 DI vs Swinject 等容器）；定义 Mock/Stub 约定与目录结构（`Tests/Mocks/`、`Tests/Fixtures/`）；配置单元测试目标与覆盖率工具（XCTest + slather/xcov）。
   - 交付物：测试架构文档 + 示例测试用例（如 Mock AsrEngine、Mock PlayerService）+ CI 集成（覆盖率报告）。
   - 来源：讨论清单§高优先级-DI；评审一§1.1/§6.1。

### 3.2 中优先级项（M2 前应落地）

| 讨论清单项 | Sprint Plan 覆盖 | 评分 | 备注 |
|-----------|------------------|------|------|
| 性能监控与降级逻辑 | ⚠️ Sprint 3 PBI-2 | B | 应在 Sprint 2 实现基础版 |
| 诊断包格式与隐私脱敏 | ✅ Sprint 3 PBI-4 | A | 合理 |
| CI/CD 流程矩阵 | ⚠️ Sprint 0（占位）+ Sprint 3 | B | 应在 Sprint 1 完善 |

**改进建议：**
- 在 Sprint 2 PBI-9（指标）中分拆出："性能监控与降级逻辑基础版"
  - 描述：实现 PerformanceMonitor Actor，实时采集 RTF/内存/电量；定义降级阈值（如 RTF < 0.3 → 提示换模型；内存警告 → LRU 清理）。
  - 验收：低性能设备触发降级提示；单元测试覆盖阈值逻辑。
- 在 Sprint 1 DoD 中补充："CI 流程包含多 OS 版本构建矩阵（iOS 17.0/17.4/18.0；macOS 14.0/15.0）"。

---

## 4. 测试策略评审（关键缺失）

### 4.1 当前测试覆盖情况

| 测试类型 | Sprint Plan 体现 | 评分 | 备注 |
|---------|------------------|------|------|
| 单元测试 | ⚠️ Sprint 0 DoD 提及"最小覆盖"| **C** | **无具体目标与范围** |
| 集成测试 | ❌ **缺失** | **F** | 端到端链路未规划 |
| 性能测试 | ⚠️ Sprint 1/3 记录样本 | **D** | **非自动化，无回归** |
| UI 测试 | ❌ **缺失** | **F** | 屏幕阅读器/a11y 未规划 |
| 金样本回归 | ⚠️ Sprint 3 PBI-7 | **D** | **推迟到 M3，风险高** |

**改进建议（高优先级）：**

1. **在 Sprint 0 增加 PBI：测试基础设施与覆盖率目标**
   - 单元测试覆盖率目标：Core/Kit 层 ≥70%；ViewModel 层 ≥60%（关键路径 80%）。
   - 金样本音频准备：3 个短音频文件（英文/中文/噪声环境，各 10–30s），期望输出文本（Ground Truth）。
   - 集成测试框架：XCUITest 配置 + 端到端场景列表（见 4.2）。
   - CI 集成：每次 PR 运行单元测试 + 覆盖率报告；每日构建运行集成测试 + 金样本回归。

2. **在 Sprint 1 DoD 中强制要求：**
   - AsrEngine 协议的契约测试（Contract Test）：Mock 实现必须通过协议定义的所有测试用例。
   - PlayerViewModel 的状态转移测试：覆盖 load/play/pause/seek 的所有路径。
   - SRT 导出格式测试：时间戳格式、UTF-8 编码、边界条件（空字幕/单字符/特殊字符）。

3. **在 Sprint 2 增加 PBI：端到端集成测试与 a11y 测试**
   - 场景：选择媒体 → 首帧字幕 → 播放滚动 → seek → 导出 → 验证文件。
   - a11y 测试：VoiceOver 朗读所有关键控件（播放/暂停/字幕开关/导出按钮）；动态字体 3 档渲染正确；高对比度模式达标。
   - 来源：评审一§6.2/§7.2；PRD §7-a11y。

### 4.2 建议的测试清单（跨 Sprint）

**单元测试（Sprint 1–3 持续）：**
- PlayerService：播放/暂停/seek/倍速/进度回调
- AudioExtractService：抽取 PCM/采样率转换/滑窗边界
- AsrEngine：协议契约测试（Mock）+ WhisperCppBackend 金样本回归
- SubtitleStore：增量写入/查询时间窗口/迁移兼容性
- ExportService：SRT/VTT 格式化/特殊字符/边界条件
- CacheManager：LRU 淘汰/内存警告响应/空间检查

**集成测试（Sprint 2–3）：**
- 端到端：媒体选择 → 识别 → 渲染 → 导出（iOS + macOS）
- 后台：切换到后台 → 识别继续 → 回到前台进度衔接
- 长视频：>1 小时视频播放 → 内存不增长 → 字幕完整导出
- 模型切换：下载新模型 → 切换 → 重新识别 → 结果变化

**性能测试（Sprint 1 基线 + Sprint 3 回归）：**
- 首帧时间：3 设备档位 × 3 模型 × 3 视频（短/中/长）
- RTF：长视频识别全程 RTF 监测
- 内存：长视频播放 1 小时内存增长曲线
- 能耗：1 小时识别电量消耗（低/高性能模式对比）

**UI/a11y 测试（Sprint 2–3）：**
- VoiceOver 流程测试（实机）
- 动态字体 3 档渲染验证
- 高对比度/Reduce Motion 适配
- 横屏/分屏（iPad/macOS）布局正确性

---

## 5. 工程实践与质量评审

### 5.1 DoR/DoD 充分性

**现有 DoD（Sprint Plan §0）：**
- ✅ 禁用硬编码字符串，String Catalog
- ✅ SwiftLint 严格模式
- ⚠️ "关键模块最小单测覆盖" —— **定义模糊**
- ✅ Demo 可运行、可复现
- ✅ PRD/HLD 引用与状态更新
- ✅ 风险与回退策略

**改进建议：**
- 将 DoD 中的"最小单测覆盖"明确为：
  > 核心业务逻辑（ViewModel/UseCase/Service 接口）单元测试覆盖率 ≥70%；所有公开 API 至少有 1 个正向测试用例；关键错误路径（如网络失败/空间不足）有测试覆盖。

- 在 DoD 中增加：
  - 性能基线数据记录（Sprint 1+）：关键路径耗时/内存样本。
  - 可访问性检查（Sprint 2+）：VoiceOver 标签完整；动态字体适配；对比度达标。
  - 安全/隐私检查（Sprint 1+）：无硬编码敏感信息；PrivacyInfo.xcprivacy 更新；第三方许可清单。

### 5.2 CI/CD 流程评审

**现有规划（Sprint 0 PBI-4）：**
- ✅ GitHub Actions/GitLab CI 占位
- ✅ 构建 iOS/macOS + Lint
- ⚠️ "（后续）单元测试" —— **不应推迟**
- ⚠️ 缓存依赖与签名占位 —— **发布流程未定义**

**改进建议：**
- 在 Sprint 0 PBI-4 中立即启用单元测试运行（即使初期仅有占位测试）。
- 在 Sprint 1 DoD 中增加：CI 运行覆盖率报告并展示趋势（如 Codecov）。
- 在 Sprint 2 增加 PBI："发布流程与签名策略"
  - 描述：配置 TestFlight 自动上传（iOS）；公证与分发配置（macOS）；版本号与 CHANGELOG 自动化。
  - 来源：评审一§9.2/§9.3。

### 5.3 文档与沟通

**优势：**
- ✅ PBI 标注来源（PRD/HLD 章节），可追溯性强
- ✅ 每个 Sprint 都有风险与回退策略
- ✅ Demo Checklist 清晰（Sprint Plan §8）

**待改进：**
- ⚠️ 缺少"技术决策记录"（ADR, Architecture Decision Records）规范
  - 建议：在 Sprint 0 增加 `docs/adr/` 目录与模板；重要决策（如 DI 方案选择、VAD 方案、双后端策略）需记录 ADR。
- ⚠️ 缺少"变更日志"（CHANGELOG）维护要求
  - 建议：在 DoD 中增加："每个 PBI 完成后更新 CHANGELOG.md，记录新增功能/修复问题/破坏性变更"。

---

## 6. 风险与依赖评审

### 6.1 技术风险评估

| 风险项 | Sprint Plan 识别 | 严重性 | 缓解措施充分性 | 评分 |
|-------|------------------|--------|---------------|------|
| 低端设备性能不足 | ✅ Sprint 1/3 | 高 | ✅ 降级小模型/提示 | A |
| 存储空间压力 | ✅ Sprint 2 | 中 | ✅ 体积提示/清理工具 | A |
| 语言检测误差 | ✅ Sprint 2 | 中 | ✅ 手动选择 | A |
| 系统后台限制 | ⚠️ **识别不足** | **高** | ❌ **缺少缓解措施** | **D** |
| VAD/对齐精度（MLX 非时间戳模型）| ❌ **完全未识别** | **高** | ❌ **无规划** | **F** |
| MLX Swift iOS 成熟度 | ⚠️ Sprint 3 风险 | 中 | ⚠️ "macOS 优先"不够具体 | C |
| 长视频稳定性（>3h）| ⚠️ Sprint 3 | 中 | ⚠️ 需专项压测 | C |
| App Store 审核（模型下载）| ⚠️ Sprint 1 风险 | 中 | ⚠️ 需首启引导设计 | C |

**改进建议：**
1. **在 Sprint 2 增加风险缓解 PBI：iOS 后台限制应对策略**
   - 描述：实现后台任务降级策略（Audio 模式优先；非播放时采用 BGProcessingTask 批量识别；状态提示与恢复）。
   - 验收：后台限制场景测试通过；用户可理解状态与恢复入口。
   - 来源：PRD §7-后台行为；HLD §10；讨论清单（见 §1.3）。

2. **在 Sprint 1 或 Sprint 2 增加技术 Spike：VAD + 对齐方案评估（见 §3.1）。**

3. **在 Sprint 2 PBI-4（模型管理）中增加验收标准：**
   - 首启引导清晰说明"需下载模型才能使用识别功能"；
   - 内置超轻量演示模型（如 tiny.en）或明确"仅播放功能可用"。

### 6.2 依赖风险

| 依赖项 | Sprint Plan 识别 | 风险 | 缓解措施 | 评分 |
|-------|------------------|------|---------|------|
| whisper.cpp | ✅ Sprint 1 PBI-3 | 低 | 成熟度高，许可宽松 | A |
| mlx-swift | ⚠️ 未明确集成点 | 中-高 | ⚠️ 需评估成熟度与体积 | C |
| SQLite/GRDB | ✅ Sprint 0 | 低 | 原生方案稳妥 | A |
| AVFoundation | ✅ Sprint 1 | 低 | 系统框架稳定 | A |
| String Catalog | ✅ Sprint 0 | 低 | Xcode 15+ 原生支持 | A |

**改进建议：**
- 在 Sprint 2 增加可选 PBI："MLX Swift 后端评估 Spike"（见 §2.1），明确集成成本与回退策略。

---

## 7. 估算与容量评审

### 7.1 Story Points 合理性分析

| Sprint | 总 SP | 建议周数 | SP/周 | 评估 | 备注 |
|--------|------|---------|-------|------|------|
| Sprint 0 | 未标注 | 1 周 | N/A | ⚠️ | 建议 15–20 SP（工程基线） |
| Sprint 1 | 36 SP | 2 周 | 18 | ✅ | 合理（2 人团队约 20 SP/周） |
| Sprint 2 | 56 SP | 3 周 | 18.7 | ⚠️ | **偏高**（需增加后台+并发 PBI，建议 70 SP / 3.5 周） |
| Sprint 3 | 58 SP | 3 周 | 19.3 | ⚠️ | **偏高**（优化与测试工作量大，建议 65–70 SP / 3.5 周） |

**假设：2 人全职开发团队，每人每周约 10 SP（行业中位数）。**

**改进建议：**
1. Sprint 0 标注估算 SP（建议 15–20 SP），便于跟踪。
2. Sprint 2 增加 PBI 后（后台+并发+MLX Spike+测试），总 SP 可能达到 70+，建议：
   - 延长到 3.5–4 周；或
   - 将 VTT 导出（3 SP）推迟到 Sprint 3；或
   - 将 MLX Spike 标记为可选（若资源不足则跳过）。
3. Sprint 3 的"性能优化"（13 SP）可能低估，建议拆分为多个子任务并重新评估。

### 7.2 关键路径与依赖分析

**串行依赖（阻塞风险）：**
- Sprint 0 → Sprint 1：工程基线必须就绪（String Catalog、SQLite schema、CI）
- Sprint 1 PBI-3（ASR）→ Sprint 1 PBI-4（渲染）：识别结果是渲染输入
- Sprint 2 PBI-1（滚动识别）→ Sprint 2 PBI-2（seek 优先）：滚动识别是 seek 优先的基础
- Sprint 2 PBI-4（模型管理）→ Sprint 3 PBI-3（按段重识别）：模型切换是重识别前提

**并行机会（加速建议）：**
- Sprint 1 PBI-1（播放器）+ PBI-2（音频抽取）可并行（不同子系统）
- Sprint 2 PBI-3（缓存）+ PBI-4（模型管理）可并行
- Sprint 3 PBI-4（诊断包）+ PBI-6（a11y）可并行

**改进建议：**
- 在 Sprint Planning 时明确 PBI 的并行/串行依赖关系（如 JIRA 的"Blocks"/"Blocked by"）。
- 在 Daily Standup 中重点关注串行依赖的进展，提前预警阻塞。

---

## 8. 分阶段交付评审

### 8.1 里程碑价值递增分析

| 里程碑 | 用户可见价值 | MVP 完整性 | 评分 | 备注 |
|-------|-------------|-----------|------|------|
| M1 原型 | 首帧字幕+基础播放+SRT 导出 | 60% | A | 核心链路打通，价值清晰 |
| M2 可用版 | 滚动字幕+模型管理+macOS | 85% | A | 接近完整产品 |
| M3 优化版 | 性能达标+质量感知+a11y | 100% | A | 生产就绪 |

**评价：** ✅ 里程碑划分合理，价值递增清晰，符合 PRD §10。

### 8.2 发布策略建议

| 阶段 | 发布形式 | 目标用户 | 目的 |
|------|---------|---------|------|
| M1 后 | 内部 Alpha（TestFlight）| 团队+早期测试者（5–10 人）| 验证核心流程与首帧体验 |
| M2 后 | 封闭 Beta（TestFlight）| 邀请测试者（50–100 人）| 收集长视频/多设备反馈；验证模型管理 |
| M3 后 | 公开 Beta（可选）或正式发布 | 全体用户 | 生产发布；App Store 审核 |

**改进建议：**
- 在 Sprint 1 DoD 中增加："准备 TestFlight 内部发布说明与反馈收集模板"。
- 在 Sprint 2 DoD 中增加："准备封闭 Beta 测试计划与问卷调查"。

---

## 9. 总结与行动项

### 9.1 必须立即改进（Sprint 0/1 前）

| 优先级 | 行动项 | 负责人 | 截止日期 | 来源章节 |
|-------|--------|--------|---------|---------|
| **P0** | **在 Sprint 2 增加 PBI：后台行为与能耗策略** | PO | Sprint 0 Planning | §1.3, §2.2 |
| **P0** | **在 Sprint 0 增加 PBI：测试架构与 DI 策略定义** | 架构师 | Sprint 0 | §3.1, §4.1 |
| **P0** | **在 Sprint 1 增加 PBI：播放器与识别状态机设计** | 架构师 | Sprint 1 | §3.1 |
| **P0** | **在 Sprint 1 DoD 中强制要求：性能基准数据记录** | Tech Lead | Sprint 0 Planning | §3.1 |
| P1 | 在 Sprint 1 增加 PBI：AsrEngine 协议定义与契约测试 | 开发 | Sprint 1 | §2.1 |
| P1 | 在 Sprint 1 或 Sprint 2 增加 Spike PBI：VAD + 对齐方案评估 | 架构师 | Sprint 2 | §3.1 |
| P1 | 明确 DoD 中的"最小单测覆盖"为具体覆盖率目标（≥70%） | PO | Sprint 0 Planning | §5.1 |

### 9.2 建议改进（Sprint 1–2 期间）

| 优先级 | 行动项 | 负责人 | 目标 Sprint | 来源章节 |
|-------|--------|--------|------------|---------|
| P1 | 在 Sprint 2 增加 PBI：JobScheduler 基础实现（并发与优先级） | 开发 | Sprint 2 | §2.1 |
| P1 | 在 Sprint 2 增加可选 PBI：MLX Swift 后端评估 Spike | 架构师 | Sprint 2 | §2.1 |
| P2 | 在 Sprint 2 分拆 PBI：性能监控与降级逻辑基础版 | 开发 | Sprint 2 | §3.2 |
| P2 | 在 Sprint 2 增加 PBI：端到端集成测试与 a11y 测试 | QA | Sprint 2 | §4.1 |
| P2 | 在 Sprint 2 PBI-4 中扩展 ModelMetadata 支持双后端字段 | 开发 | Sprint 2 | §2.3 |
| P2 | 在 Sprint 1 DoD 中补充 CI 多 OS 版本构建矩阵 | DevOps | Sprint 1 | §3.2 |

### 9.3 可推迟但建议跟踪（Sprint 3 或后续）

| 优先级 | 行动项 | 目标 | 来源章节 |
|-------|--------|------|---------|
| P3 | 建立 ADR（技术决策记录）规范与目录 | Sprint 3 | §5.3 |
| P3 | 在 DoD 中增加 CHANGELOG 维护要求 | Sprint 3 | §5.3 |
| P3 | 配置发布流程与签名策略（TestFlight/公证） | Sprint 2 | §5.2 |
| P3 | 长视频（>3h）稳定性专项压测 | Sprint 3 | §6.1 |

### 9.4 评分汇总

| 评审维度 | 评分 | 主要问题 |
|---------|------|---------|
| PRD 对齐 | B+ (85) | 后台行为缺失；部分 KPI 验收不明确 |
| HLD 对齐 | B (82) | 双后端路径不明；并发调度模糊 |
| 讨论清单对齐 | C+ (78) | 高优先级项（VAD、状态机、测试）未充分规划 |
| 测试策略 | D+ (68) | **最弱环节**：缺少单元/集成/性能测试清单 |
| 工程实践 | B (83) | DoD 需强化；CI 需立即启用测试 |
| 风险管理 | B- (80) | 后台限制与 VAD 方案风险未充分缓解 |
| **综合评分** | **B+ (85)** | **整体良好，但测试与后台策略需立即加强** |

---

## 10. 附录：建议的更新后 Sprint 范围（摘要）

### Sprint 0（工程基线，1 周 → 建议 1.5 周，~20 SP）
- 现有 8 个 PBI
- **新增：** 测试架构与 DI 策略定义（5 SP）

### Sprint 1（M1 原型，2 周，~40 SP）
- 现有 7 个 PBI
- **新增：**
  - AsrEngine 协议定义与契约测试（5 SP）
  - 播放器与识别状态机设计与文档化（5 SP）
- **强化 DoD：** 性能基准数据记录、时间同步偏差测量、状态机测试

### Sprint 2（M2 可用版，3 周 → 建议 3.5–4 周，~75 SP）
- 现有 9 个 PBI
- **新增：**
  - 后台行为与能耗策略（iOS Audio 模式 + macOS App Nap）（13 SP）
  - JobScheduler 基础实现（并发与优先级）（8 SP）
  - 性能监控与降级逻辑基础版（5 SP）
  - 端到端集成测试与 a11y 测试（8 SP）
  - MLX Swift 后端评估 Spike（可选，5 SP，时间盒 3 天）
  - VAD + 对齐方案评估 Spike（可选推迟到 S3，5 SP，时间盒 3 天）
- **调整：** 将 VTT 导出（3 SP）标记为可选（资源不足可推迟到 S3）

### Sprint 3（M3 优化版，3 周 → 建议 3.5 周，~70 SP）
- 现有 7 个 PBI
- **强化：**
  - 性能与能耗优化拆分为多个子任务（RTF 优化、内存优化、热管理）
  - 测试与 CI 增强包含：金样本回归、WER 指标、长视频压测、内存泄漏检测
- **可选新增：**
  - VAD + 对齐方案落地（如 S2 Spike 通过）（8 SP）
  - ADR 与 CHANGELOG 规范建立（2 SP）

---

## 结语

Sprint Plan v0.2 在整体结构、里程碑划分与范围对齐方面表现良好，体现了对 PRD 和 HLD 的深入理解。但在以下关键领域需要立即加强：

1. **测试策略**：必须在 Sprint 0 建立测试架构与覆盖率目标，在 Sprint 1 强制执行。
2. **后台行为**：PRD §5-US7 与 HLD §10 的核心需求，必须在 Sprint 2 落地。
3. **并发与状态管理**：状态机与 JobScheduler 是架构基石，应在 Sprint 1–2 明确设计与测试。
4. **性能基准**：必须在 Sprint 1 建立基线数据，为 Sprint 3 优化提供对比依据。

完成上述改进后，该 Sprint Plan 可作为高质量的开发指南，支撑团队交付符合 PRD/HLD 要求的生产级产品。

---

**评审人签名：** Claude 4.5 AI Architect  
**评审日期：** 2025-10-17  
**下一步：** PO 组织 Sprint 0 Planning，结合本评审报告更新 Backlog 并确认优先级与容量。
