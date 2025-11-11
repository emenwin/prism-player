# 文档组织说明

本目录采用**三层文档体系**，清晰分离产品需求、技术设计和敏捷过程，支持高效的文档管理和可追溯性。

---

## 📁 目录结构总览

```
docs/
├── 0_prd/                          # 产品需求层
│   ├── README.md                   # 目录说明
│   └── prd_v0.1.md                 # 产品需求文档
│
├── 1_design/                       # 技术设计层（长期维护）
│   ├── README.md
│   ├── architecture/
│   │   ├── architecture.md         # 架构概览
│   │   └── adr/
│   │       └── 0001-xxx.md         # 架构决策记录
│   ├── hld/
│   │   └── hld-ios-macos-v1.0.md   # 高层设计文档
│   └── tdd/
│       ├── module-asr-engine.md    # 模块设计：语音识别引擎
│       └── module-media-player.md  # 模块设计：媒体播放器
│
├── 2_scrum/                        # 敏捷过程层（周期归档）
│   ├── README.md
│   ├── scrum.md                    # Scrum 实践指南
│   └── sprint-x/
│       ├── planning.md             # Sprint 计划
│       ├── task-list.md            # 任务清单
│       └── tasks/
│           └── task-001-implementation.md  # 任务实现设计
│
├── template/                       # 文档模板库
│   ├── README.md                   # 模板使用说明
│   ├── 0.prd.template.md           # PRD 产品需求文档模板
│   ├── 1.technical-feasibility.template.md  # 技术可行性分析模板
│   ├── 2.adr.template.md           # ADR 架构决策记录模板
│   ├── 3.add-architecture-design-document.template.md  # ADD 架构设计模板（可选）
│   ├── 4.hld.template.md           # HLD 高层设计模板
│   ├── 5.tdd.template.md           # TDD 详细技术设计模板（精简版）
│   ├── 6.sprint-plan.template.md   # Sprint 计划模板
│   ├── 7.sprint-task-list.template.md  # Sprint 任务清单模板
│   ├── 8.task-detailed.template.md # Task 详细设计模板
│   ├── 9.sprint-review-retrospective.template.md  # Sprint 回顾模板
│   └── archived/                   # 已归档的旧版模板
│
├── README.md                       # 本文件
└── 文档目录详细说明.md             # 详细的文档体系说明
```

---

## 🎯 三层文档体系

### 层次 0：产品需求层 (`0_prd/`)

**职责**：定义产品需求和验收标准

| 文档类型 | 核心问题 | 主要内容 | 负责人 | 生命周期 |
|---------|---------|---------|--------|---------|
| **PRD** | 做什么？为何做？<br>(What & Why) | 用户故事、功能清单、<br>验收标准、成功指标 | PM/产品经理 | 长期维护（版本化） |
| **Feasibility** | 能不能做？<br>(Can We?) | 技术风险评估、<br>资源需求分析 | 技术负责人 | 一次性（决策后归档） |

**使用指南**：
- 新功能需求 → 创建或更新 PRD
- 技术验证需求 → 创建 Feasibility 分析
- PRD 版本号与项目版本对应（v0.1, v0.2...）
- 参考模板：
  - `template/0.prd.template.md`
  - `template/1.technical-feasibility.template.md`

---

### 层次 1：技术设计层 (`1_design/`)

**职责**：定义技术方案和架构设计（长期维护的设计文档）

#### 1.1 `architecture/` - 架构与决策

| 子目录 | 用途 | 粒度 | 生命周期 | 示例 |
|-------|------|------|---------|------|
| `architecture.md` | 架构概览 | 系统级 | 长期维护 | 整体架构图、分层说明 |
| `adr/` | 架构决策记录 | 决策级 | 永久保留（不可变） | 为什么选择 Workspace + SPM？ |

**ADR 特点**：
- ✅ 记录**为什么**这样设计（Why）
- ✅ 包含 2-3 个备选方案对比
- ✅ 永久保留，废弃时标记 `Superseded by ADR-XXXX`
- ❌ 不包含详细实现代码

**参考模板**：`template/2.adr.template.md`

#### 1.2 `hld/` - 高层设计文档

**用途**：系统级架构设计（High-Level Design）

**内容**：
- 系统架构图与分层
- 模块划分与依赖关系
- 核心接口定义
- 技术栈选型
- 部署策略

**粒度**：系统级、架构级（What + How 概要）  
**生命周期**：长期维护，版本化  
**参考模板**：`template/4.hld.template.md`

#### 1.3 `tdd/` - 模块设计文档

**用途**：模块级技术设计（Technical Design Document / Module Design）

**内容**：
- 模块职责与边界
- 详细接口设计（协议定义、类签名）
- 数据模型定义
- 核心算法说明
- 模块级测试策略

**粒度**：模块级、组件级（How 详细）  
**生命周期**：长期维护，版本化  
**参考模板**：`template/5.tdd.template.md`（精简版，1-2 小时完成）

**示例文件**：
- `module-asr-engine.md` - 语音识别引擎模块设计
- `module-media-player.md` - 媒体播放器模块设计

---

### 层次 2：敏捷过程层 (`2_scrum/`)

**职责**：记录 Scrum 敏捷开发过程中的所有产物（周期性归档）

#### 2.1 Sprint 组织结构

```
2_scrum/
├── README.md              # Scrum 过程文档说明
├── scrum.md               # Scrum 实践指南
└── sprint-N/              # 按 Sprint 编号组织
    ├── planning.md        # Sprint 计划会议记录
    ├── task-list.md       # Sprint Backlog / 任务清单
    ├── retrospective.md   # Sprint 回顾与复盘（可选）
    └── tasks/             # 任务实现设计（可选）
        └── task-XXX-implementation.md
```

#### 2.2 何时需要创建 Task Implementation Design？

| 任务类型 | 是否需要 | 理由 |
|---------|---------|------|
| 简单任务（1-2 SP） | ❌ | 直接在 `task-list.md` 描述即可 |
| 中等任务（3-5 SP） | ⚠️ 可选 | 如涉及多模块协作，建议创建 |
| 复杂任务（5+ SP） | ✅ 必须 | 需要详细实现步骤和测试策略 |
| 核心模块实现 | ✅ 必须 | 便于 Code Review 和知识传递 |

**参考模板**：
- Sprint Planning: `template/6.sprint-plan.template.md`
- Task List: `template/7.sprint-task-list.template.md`
- Task Design: `template/8.task-detailed.template.md`
- Retrospective: `template/9.sprint-review-retrospective.template.md`

---

## 📊 文档流程图

```
┌─────────────────────────────────────────────────────────────┐
│                    文档体系工作流                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  PRD ──→ Feasibility ──→ ADR ──→ HLD ──→ TDD ──→ Task
│  (需求)   (可行性)    (决策)   (架构)   (模块)   (实现)
│  (0_prd/) (0_prd/)  (1_design/) (1_design/) (1_design/) (2_scrum/)
│     ↓        ↓          ↓         ↓         ↓          ↓
│  做什么？  能做吗？   为什么？   是什么？   怎么设计？  怎么做？
│  Why      Can       Why       What+How    How        How
│  (产品)   (技术)    (技术)    概要        详细       实现
│     │        │         │         │         │          │
│  产品视角  风险评估  技术选型  系统架构   模块设计   代码实现
│  永久维护  一次性    永久保留  长期维护   长期维护   Sprint周期
│   版本化   归档      不可变    版本化     版本化     完成归档
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**典型工作流**：

1. **需求阶段** → 编写/更新 `0_prd/prd_vX.X.md`
2. **可行性验证** → 创建 `0_prd/technical-feasibility-vX.X.md`（必需）
3. **架构决策** → 遇到关键技术选择时创建 `1_design/architecture/adr/XXXX-xxx.md`
4. **架构设计** → 编写 `1_design/hld/hld-platform-vX.X.md`
5. **模块设计** → 编写 `1_design/tdd/module-xxx.md`（复杂模块）
6. **Sprint 计划** → 在 `2_scrum/sprint-N/` 创建 planning 和 task-list
7. **任务实现** → 复杂任务创建 `2_scrum/sprint-N/tasks/task-XXX-implementation.md`
8. **Sprint 回顾** → 更新 retrospective，归档 Sprint 产物

---

## 🔗 文档引用关系

### 向上追溯（Why？）

```
Task Implementation → TDD (Module Design) → HLD → ADR → Feasibility → PRD
     ↑                       ↑                ↑      ↑         ↑          ↑
  具体怎么做？           怎么设计的？       是什么？ 为什么？  能做吗？   做什么？
  (How 实现)            (How 详细)        (What)   (Why)    (Can)      (What)
```

**示例**：
- Task-102 → 引用 `1_design/tdd/module-asr-engine.md` §2 接口设计
- `module-asr-engine.md` → 引用 `1_design/hld/hld-ios-macos-v1.0.md` §6 ASR 模块
- `hld-ios-macos-v1.0.md` → 引用 `1_design/architecture/adr/0001-xxx.md`
- `adr/0001-xxx.md` → 引用 `0_prd/technical-feasibility-ios-v0.2.md` 可行性分析
- `technical-feasibility-ios-v0.2.md` → 引用 `0_prd/prd_v0.1.md` §3 功能需求

### 向下细化（How？）

```
PRD → Feasibility → ADR → ADD → HLD → TDD (Module Design) → Task Implementation
 ↓        ↓          ↓      ↓      ↓          ↓                      ↓
需求    可行性      决策   架构   系统设计   模块设计              具体实现
(做啥)  (能做吗)   (为啥)  (概览) (是啥)    (咋设计)              (咋实现)
```

**流程说明**：
- **PRD** 定义产品需求和业务目标
- **Feasibility** 评估技术可行性和风险
- **ADR** 记录关键技术决策（基于可行性分析）
- **ADD** 系统整体架构设计（可选，复杂系统使用）
- **HLD** 高层设计，模块划分和接口定义
- **TDD** 模块详细设计，算法和数据结构
- **Task** 具体实现步骤和代码

---

## 📌 文档维护原则

### 1. 分层递进原则

每层文档专注于特定抽象级别，通过引用避免重复：
- **PRD** 不涉及技术实现（只描述需求和目标）
- **Feasibility** 不包含详细设计（只评估可行性和风险）
- **ADR** 不包含详细架构（只记录决策过程和备选方案）
- **ADD** 不包含实现细节（只描述架构概览和原则，可选）
- **HLD** 不包含具体代码（接口级示例除外）
- **TDD (Module Design)** 不重复架构说明（引用 HLD）
- **Task Design** 不重复模块设计（引用 TDD）

### 2. 生命周期管理

| 文档类型 | 维护策略 | 修改方式 | 存档规则 |
|---------|---------|---------|---------|
| **PRD** | 长期维护 | 版本化（v0.1 → v0.2） | 旧版本保留 |
| **Feasibility** | 一次性 | 决策后不再修改 | Go/No-Go 后归档 |
| **ADR** | 永久保留 | 不可修改 | 废弃时标记 `Superseded by ADR-XXX` |
| **ADD** | 长期维护 | 版本化更新 | 旧版本归档（可选文档） |
| **HLD** | 长期维护 | 版本化更新，记录变更历史 | 旧版本归档 |
| **TDD** | 长期维护 | 版本化更新，记录变更历史 | 旧版本归档 |
| **Task Design** | Sprint 内 | Sprint 内可修改 | Sprint 结束后归档到 `sprint-N/` |

### 3. 可追溯性原则

- **Task Design** 必须关联 Sprint 和 PBI 编号，引用相关 TDD
- **TDD** 需引用 HLD 的模块定义章节
- **HLD** 需引用关键决策的 ADR 编号
- **ADR** 需引用 Feasibility 分析和 PRD 需求
- **Feasibility** 需引用 PRD 的功能需求章节
- 使用双向链接：`📎 详细设计见 HLD v1.0 §6.1` ↔ `📎 决策依据见 ADR-0001`

---

## 🚀 快速开始

### 场景 1：开始新功能开发

**完整流程**（按顺序执行）：

1. **需求定义** → 编写/更新 `0_prd/prd_vX.X.md`（使用 `template/0.prd.template.md`）
2. **可行性验证** → 创建 `0_prd/technical-feasibility-platform-vX.X.md`（使用 `template/1.technical-feasibility.template.md`）
   - ⚠️ **Go/No-Go 决策点**：评审通过才继续
3. **关键决策** → 如有关键技术选型，创建 `1_design/architecture/adr/XXXX-xxx.md`（使用 `template/2.adr.template.md`）
4. **架构概览** → （可选）复杂系统创建 `1_design/architecture/architecture.md` 或使用 ADD 模板
5. **高层设计** → 编写 `1_design/hld/hld-platform-vX.X.md`（使用 `template/4.hld.template.md`）
6. **模块设计** → 如需新模块，创建 `1_design/tdd/module-xxx.md`（使用 `template/5.tdd.template.md`）
7. **Sprint 计划** → 创建 `2_scrum/sprint-N/planning.md` 和 `task-list.md`（使用 `template/6、7`）
8. **任务实现** → 复杂任务（5+ SP）创建 `2_scrum/sprint-N/tasks/task-XXX.md`（使用 `template/8.task-detailed.template.md`）

**快速参考**：
```
PRD → Feasibility (必需) → ADR (按需) → ADD (可选) → HLD (必需) → TDD (按需) → Sprint → Task
```

### 场景 2：查找设计文档

| 你想知道 | 查看文档 | 关键信息 |
|---------|---------|---------|
| 技术方案可行吗？ | `0_prd/technical-feasibility-*.md` | 风险评估、Go/No-Go 决策 |
| 为什么选这个技术方案？ | `1_design/architecture/adr/` | 备选方案对比、决策理由 |
| 系统整体架构是什么？ | `1_design/hld/` 或 `architecture.md` | 架构图、模块划分、接口定义 |
| 某个模块怎么设计的？ | `1_design/tdd/module-xxx.md` | 接口设计、算法、数据结构 |
| 这个 Task 怎么实现？ | `2_scrum/sprint-N/tasks/task-XXX.md` | 实现步骤、代码示例 |

### 场景 3：发现设计问题

**处理流程**：

```
发现问题 → 评估影响范围
              │
              ├─ 只影响当前 Task → 在 Task 文档中记录偏差
              │                    Sprint Review 时更新对应的 TDD/HLD
              │
              ├─ 影响模块设计 → 更新 TDD → 同步更新相关 Task
              │
              ├─ 影响系统架构 → 更新 HLD → 同步更新相关 TDD → 同步更新 Task
              │
              └─ 需要改变技术方案 → 立即暂停 → 组织技术评审
                                      │
                                      ├─ 重大决策变更？
                                      │   ├─ 是 → 创建新 ADR（记录变更原因）
                                      │   │      → 更新 HLD → 更新 TDD → 更新 Task
                                      │   │
                                      │   └─ 否 → 直接更新 HLD/TDD
                                      │          → 在变更记录中说明原因
                                      │          → 同步更新 Task
```

**关键原则**：
- 📌 **向上影响向下更新**：如果修改了 HLD，需要检查并更新所有相关的 TDD 和 Task
- 📌 **重大变更需要 ADR**：改变技术选型、架构模式等必须创建 ADR 记录
- 📌 **保持文档一致性**：修改后的文档版本号递增，并在变更记录中说明

### 场景 4：新成员快速上手

**推荐阅读顺序**：

1. **了解项目** → `0_prd/prd_vX.X.md`（10-20 分钟）
2. **技术背景** → `0_prd/technical-feasibility-*.md` + `1_design/architecture/adr/`（20-30 分钟）
3. **系统架构** → `1_design/hld/hld-platform-vX.X.md`（30-60 分钟）
4. **模块细节** → `1_design/tdd/module-*.md`（按需阅读）
5. **当前进度** → `2_scrum/sprint-N/planning.md` + `task-list.md`（10 分钟）

---

## 📚 参考资源

- **详细说明**：`文档目录详细说明.md` - 包含完整的设计原则、FAQ 和审查清单
- **模板库**：`template/README.md` - 所有文档模板的使用指南
- **Scrum 指南**：`2_scrum/scrum.md` - 团队的 Scrum 实践规范
- **子目录说明**：
  - `0_prd/README.md` - 产品需求文档组织说明
  - `1_design/README.md` - 技术设计文档组织说明
  - `2_scrum/README.md` - 敏捷过程文档组织说明

---

**最后更新**：2025-11-11  
**文档版本**：v1.2  
**主要变更**：
- 添加技术可行性分析文档流程
- 添加 ADD 架构设计模板（可选）
- 更新 TDD 模板为精简版（1-2 小时）
- 完善文档创建顺序说明

