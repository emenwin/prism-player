# ADR (Architecture Decision Records) 目录内容规范

本目录记录 Prism Player 项目的关键架构与技术决策。

提出新决策时，复制 `template.md` 并填

 
## 目录结构

```text
docs/adr/
├── README.md                           # ADR 索引与使用指南
├── template.md                         # ADR 模板
├── 0001-adr-process.md                # 元决策：ADR 流程本身
├── 0002-di-strategy.md                # DI 方案选择
├── 0003-dual-backend-strategy.md      # 双后端策略（whisper.cpp + MLX）
├── 0004-state-machine-design.md       # 播放器与识别状态机设计
├── 0005-cache-strategy.md             # 音频缓存与 LRU 策略
├── 0006-background-processing.md      # 后台处理策略（iOS/macOS）
├── 0007-translation-pipeline.md       # 字幕翻译流水线架构
└── superseded/                         # 已废弃的决策（保留历史）
    └── 0002-old-di-strategy.md
```

## ADR 模板

参考[template](./template.md)

 

## ADR 内容要点

### 1. 必须包含的核心元素
- **状态与元数据**：状态、日期、决策者、相关文档
- **背景**：为什么需要这个决策
- **驱动因素**：关键约束与目标
- **方案对比**：至少 2-3 个候选方案的优缺点
- **决策结果**：选择的方案与理由
- **后果**：正面/负面影响与缓解措施

### 2. 技术决策类型（适用于 Prism Player）

#### Sprint 0
- **ADR-0001**: ADR 流程本身
- **ADR-0002**: DI 策略（协议式 vs 容器）
- **ADR-0003**: 双后端策略（whisper.cpp + MLX Swift）

#### Sprint 1
- **ADR-0004**: 播放器与识别状态机设计
- **ADR-0005**: 音频预加载窗口策略（5-10s 极速首帧）
- **ADR-0006**: 日志与指标收集框架（OSLog vs 自定义）

#### Sprint 2
- **ADR-0007**: 后台处理策略（iOS Audio Session + macOS App Nap）
- **ADR-0008**: JobScheduler 并发模型（Actor vs OperationQueue）
- **ADR-0009**: 音频缓存与 LRU 淘汰算法
- **ADR-0010**: 翻译流水线架构（ASR → NMT 两段式）

#### Sprint 3
- **ADR-0011**: VAD + 对齐方案（若 Spike 通过）
- **ADR-0012**: 长视频内存管理策略
- **ADR-0013**: 错误处理与诊断包设计

### 3. 编号规范
- 格式：`NNNN-kebab-case-title.md`（如 `0002-di-strategy.md`）
- 顺序递增，已废弃的保留编号并移至 `superseded/`

### 4. 状态转移
```
提议中 → 已接受 → [已废弃 / 已替代]
         ↓
      已拒绝
```

### 5. 维护原则5. 维护原则
- **不可变性**：已接受的 ADR 不修改，用新 ADR 替代
- **可追溯性**：必须关联 PRD/HLD/Sprint Plan 章节
- **团队审阅**：关键 ADR 需至少 2 人 Review
- **索引维护**：README.md 列出所有 ADR 与状态

###   关键原则
- 轻量但完整：模板简洁，但必须包含方案对比与理由
- 可执行：决策结果必须可转化为代码或配置
- 团队共识：关键 ADR 需 Review 通过
- 持续维护：索引与状态及时更新

 