# Prism Player Android 技术可行性评估（v0.2）

> 日期：2025-10-25  
> 关联文档：`docs/requirements/prd_v0.2.md`、`docs/requirements/prd_v0.1.md`、`docs/adr/0001-0005`

## 1. 结论速览（Verdict）
- 播放器与字幕同步：绿色（采用 ExoPlayer + Compose Overlay，可满足 ±200ms P95 同步指标）。
- 端侧离线 ASR：绿色/黄色（Whisper.cpp NDK 集成在中高端机达标；入门机需模型降级与节流，Vosk 作为备选）。
- 字幕翻译（离线优先，首批 en→zh-Hans）：黄色（可行但模型体积与耗时较大，建议小模型+可选下载；M2 目标）。
- 模型管理与完整性校验：绿色（DownloadManager/WorkManager+SHA256 校验）。
- 存储（字幕片段/设置/模型清单）：绿色（Room/SQLite 索引优化时间范围查询）。
- 隐私与离线：绿色（全程本地处理；模型下载/导入除外）。
- 性能与能耗：黄色（低端设备 RTF 风险；需分段处理/线程数自适应/后台节流）。

## 2. 范围与目标对齐
依据 PRD v0.2（首期范围）在 Android 侧交付：
- 本地媒体播放、音频预加载与滚动提取；
- 端侧离线 ASR（时间戳片段）、实时/准实时字幕叠加；
- 样式（字号三档、浅/深主题、半透明背景）、开关；
- SRT 导出（VTT 作为增强）；
- 模型管理（下载/导入/删除/校验）、语言指定/自动；
- 字幕翻译（en→zh-Hans 优先，离线优先）；
- 缓存管理与 i18n/a11y 基线；
- KPI：首帧字幕时间、时间同步偏差（≤±200ms）、RTF 分档指标。

## 3. 平台与技术栈建议
- 最低系统版本（建议）：minSdk 24（Android 7.0）；targetSdk 35。  
  - 说明：ExoPlayer/WorkManager/Room 在该范围可良好工作；若提到 26 可简化后台限制处理，但 24 覆盖度更高。
- 架构：MVVM + Jetpack Compose（UI）+ Kotlin Coroutines/Flow。
- 播放：ExoPlayer（Media3），自定义 AudioProcessor 抽头抽取 PCM 并重采样至 16kHz/mono 提供给 ASR。
- 依赖注入：Hilt（推荐）或 Koin；同时保持“协议式/接口式”抽象，便于测试替换（对应 ADR-0005 思路）。
- 存储：Room（SQLite），WAL 模式；时间窗口索引（`media_id,start_time,end_time`）。
- 日志/指标：Timber + 本地轻量指标采集（与 ADR-0004 对齐：本地统计 P95 首帧/RTF/时间偏差）；可选 BatteryStats 采样。
- 测试：JUnit5 + Robolectric（单元）+ Instrumentation/Compose UI Test（集成）。

## 4. 关键能力可行性

### 4.1 媒体播放与音频提取
- 方案：ExoPlayer 作为统一播放栈；
  - 预加载：选中媒体后，按 PRD 默认 30s 窗口解复用并解码音频缓存；
  - 滚动提取：播放过程中以 15–30s 段迭代抽取；
  - 进度拖动抢占：跳转后优先抽取“当前位置起 60s”音频段。
- 风险与对策：
  - 容器/编解码兼容性：优先系统解码器；Exo 解码失败时提示“媒体不支持”。
  - 内存压力：缓存 ≤10MB（PRD），收到 onTrimMemory 时仅保留“当前 ±15s”。

### 4.2 端侧离线 ASR
- 首选：Whisper.cpp（MIT）通过 NDK 集成，支持 int8/FP16 量化，输出时间戳；
  - ABI：arm64-v8a（首选）；x86_64（模拟器，可选）；
  - 并行：基于 CPU 多线程；线程数自适应（big.LITTLE，温控反馈可调低）。
- 备选：Vosk（Apache-2.0），小模型、速度快、准确率较低；适合入门设备降级或英文优先场景。
- 模型体积：
  - Whisper `tiny/base`（int8）约 30–150MB；`small` ≥ 450MB（不建议首期）；
  - Vosk 英文小模型 ~ 50–70MB。
- 预计性能（经验基线，实际以实测为准）：
  - 高端（8 Gen 2/3）：`base-int8` RTF 0.8–1.5；
  - 中端（7+ Gen 1/778G）：`tiny-int8` RTF 0.5–1.0，`base-int8` 0.3–0.7；
  - 入门（6 系/老机）：`tiny-int8` 0.2–0.5（需边播边出字+占位提示）。
- 同步策略：以 ExoPlayer position 为唯一时钟源；段结果结构：`startMs,endMs,text,confidence?`；渲染层消费窗口化流。

### 4.3 字幕翻译（离线优先）
- PRD 要求 en→zh-Hans（首批）；
- 可行路径：ASR 转写 → 本地 NMT 翻译（两段式）。
  - 首选：Marian/Bergamot 小型双语模型（en↔zh），经 ONNX Runtime Mobile 或 NDK 部署，int8 量化；单模型 70–150MB；
  - 备选：当目标语对不支持时，提示联网翻译（需用户显式同意，仅上传转写文本）。
- Whisper “translate”模式仅支持“译为英文”，不满足 en→zh，故不可直接替代。
- 风险与对策：
  - 体积与耗时：提供可选下载与清理；按窗口优先级排程，未完成片段“翻译中…”占位；
  - 质量：提供回退到原文；支持按段重试（更高精度模型）。

### 4.4 UI 与同步渲染（Compose）
- Compose 视频层：ExoPlayer SurfaceView/PlayerView；字幕以 Compose Overlay 或自绘 Canvas（低频刷新，段变更时）。
- 样式：字号三档、浅/深主题与半透明背景；状态不可见时不触发重绘。
- a11y：TalkBack 描述、动态字体、对比度达标。

### 4.5 存储与导出
- Room 实体：`media_files`、`subtitle_segments`、`model_metadata`、`settings`；
- 时间索引：`(media_id,start_time,end_time)`；
- SRT/VTT 生成器：纯 Kotlin；导出前空间检查与命名 `<name>.<locale>.srt`。
- 可选加密：SQLCipher for Android（或对敏感字段用 Tink Encrypt-then-MAC）。

### 4.6 模型管理与校验
- 下载：`DownloadManager` + 前台通知/暂停/重试；或 WorkManager 后台断点续传；
- 校验：下载完成后计算 SHA-256；记录版本、语言覆盖；
- 导入：SAF 选择本地文件（外部存储/USB/云盘本地副本）；
- 存储位置：App 私有目录（`filesDir/models/<id>/…`），按语言与尺寸分组。

### 4.7 权限、文件访问与后台
- 文件访问：SAF（`ACTION_OPEN_DOCUMENT`）选取媒体，兼容分区存储；Android 13+ 使用 `READ_MEDIA_*` 权限（如需）；
- 后台：长任务用 Foreground Service + 通知；合规节流（Doze/Standby）；回前台后自然衔接；
- 无需麦克风权限（不采集实时麦克风输入）。

## 5. 风险清单与缓解
- 低端设备 RTF 偏低（Yellow）：
  - 缓解：默认 `tiny-int8`；线程数自适应；播放倍速提示；允许离线“全片批处理”在空闲时完成。
- 应用包体与模型体积（Yellow）：
  - 缓解：不预置大模型；内置极小 Demo 模型（英文）仅演示；其余按需下载/导入；支持清理。
- 翻译模型可用性与质量（Yellow）：
  - 缓解：首期限定 en→zh 小模型；其他语对延后；必要时提示联网翻译（需同意）。
- 后台限制（Green/Yellow）：
  - 缓解：前台服务+用户可见通知；WorkManager 约束网络/充电状态；失败重试与断点续传。
- 许可与合规（Green）：
  - Whisper.cpp（MIT）、Vosk（Apache-2.0）、ONNX Runtime（MIT）；第三方许可在“关于”页披露；仅离线处理用户数据。

## 6. 性能与能耗策略（与 PRD KPI 对齐）
- 首帧字幕：
  - 流程优化：选中媒体→解析→立即预加载 30s→先出 `tiny` 结果（可选“事后替换”为更准模型）。
- 渲染同步：
  - 以 ExoPlayer position 为时钟；段变更才触发 UI；阈值节流（10–15Hz 刷新上限）。
- 分段识别：
  - 10–30s 段；窗口优先级：抢占（进度跳转后 60s）> 当前窗口滚动 > 预加载。
- 能耗：
  - 段间休眠/背压；后台降线程；温控反馈降低优先级；
  - 大模型仅在充电+Wi-Fi 时提示使用（可选）。

## 7. 数据模型（Kotlin 概要）
- SubtitleSegment: `id, mediaId, startMs, endMs, text, confidence?`
- MediaFile: `id, uri, durationMs, recognitionProgress, modelId, language`
- ModelMetadata: `id, name, size, backend(whisper|vosk|marian), version, path, status, sha256`
- Settings: `subtitleStyle, preloadSeconds, languageHint, targetLanguage`

## 8. 工程与 CI/CD
- 模块划分：player, extractor, asr, translate, subtitles, storage, settings, model-manager, ui, metrics。
- 代码规范：
  - 禁用硬编码字符串（strings.xml + 翻译）；
  - Kotlin lint/ktlint 与 Detekt；
  - 单元/集成测试覆盖关键路径（段合并、SRT 导出、时间同步）。
- CI：GitHub Actions（Gradle 构建+测试+lint）；ABI 分包与 ProGuard/R8。

## 9. 可访问性与国际化
- TalkBack 可读关键控件与状态；动态字体；对比度达标；
- i18n：中英至少两种；所有文案走资源文件；日期/数字/区域设置遵循系统。

## 10. POC 计划与工期（建议）
- M1（2 周）：
  - ExoPlayer 播放与 Compose 叠加；
  - Whisper.cpp NDK 集成（arm64），`tiny-int8` 模型跑通分段转写；
  - 首帧流程（30s 预加载）与基本 SRT 导出；
  - 时间同步度量（偏差 P95 采集）。
- M2（2–3 周）：
  - 模型管理（下载/导入/删除/校验/UI）；
  - 进度拖动抢占与窗口调度；缓存与内存压力策略；
  - 翻译（en→zh）本地小模型原型；双语/导出增强；
  - Room 持久化与时间索引优化。
- M3（2–3 周）：
  - 性能与能耗优化（线程/节流/后台）；
  - a11y 与 i18n 完善；失败重试与错误码；
  - 指标面板（本地）与诊断包导出；VTT 可选。

## 11. 开放问题（需在实现前确认）
- 最低支持 ABI 是否仅 arm64-v8a（缩小 APK/AAB 体积）？
- 翻译模型的具体选择与目标体积（≤150MB）是否可接受？
- 是否提供“离线批处理整片”入口（性能较弱设备的权衡）？
- 目标设备分档与 KPI 校准样机型号清单？

## 12. 结论
Android 版本在现有生态（ExoPlayer、NDK、Room、Compose）下可实现“离线端侧 ASR + 实时字幕 + 可选离线翻译”的产品目标。核心风险集中在“模型体积/性能分档/能耗”，通过“模型分级、按需下载、窗口化调度、后台节流与可视化指标”可控落地。建议立即推进 M1 原型验证 Whisper.cpp 集成与端到端首帧指标，再迭代模型管理与翻译能力。
