# Sprint Tasks 设计文档

## 目录说明

本目录存放各 Sprint 的详细任务设计文档。每个 Task 文档包含具体的实施方案、验收标准和技术细节。

## 目录结构

```
tasks/
├── README.md              # 本文件
├── sprint-0/              # Sprint 0 任务
│   ├── task-001-repo-init.md
│   ├── task-002-multiplatform-scaffold.md
│   └── ...
├── sprint-1/              # Sprint 1 任务
│   ├── task-101-player-service.md
│   ├── task-102-asr-engine-protocol.md
│   └── ...
├── sprint-2/              # Sprint 2 任务
└── sprint-3/              # Sprint 3 任务
```

## 文档分层

| 文档类型 | 目录位置 | 粒度 | 生命周期 | 目的 |
|---------|---------|------|---------|------|
| **PRD** | `docs/requirements/` | 产品功能级 | 长期维护（版本化） | **是什么**（产品需求） |
| **HLD/TDD** | `docs/tdd/` | 架构/模块级 | 长期维护（版本化） | **怎么设计**（技术架构） |
| **ADR** | `docs/adr/` | 关键技术决策 | 永久保留（不可变） | **为什么**（决策理由） |
| **Task Design** | `docs/scrum/tasks/` | 实现任务级 | Sprint 周期内有效 | **怎么做**（实施细节） |

## 命名规范

### 文件命名
- 格式：`task-<编号>-<简短描述>.md`
- 编号：3 位数字，建议采用 `<sprint编号><任务序号>` 格式
- 示例：
  - `task-002-multiplatform-scaffold.md`（Sprint 0 的第 2 个任务）
  - `task-101-player-service.md`（Sprint 1 的第 1 个任务）
  - `task-102-asr-engine-protocol.md`（Sprint 1 的第 2 个任务）

### 编号规则
- Sprint 0: 001-009
- Sprint 1: 101-199
- Sprint 2: 201-299
- Sprint 3: 301-399

## Task 文档模板

每个 Task 设计文档应包含以下核心部分：

### 1. 任务信息
- Sprint 归属
- PBI（Product Backlog Item）关联
- 优先级（P0/P1/P2/P3）
- 估算（Story Points）
- 负责人
- 状态（Todo/In Progress/Review/Done）

### 2. 目标
清晰描述任务要达成的目标

### 3. 技术方案
详细的实施方案，包括：
- 架构设计
- 接口定义
- 关键代码示例
- 配置说明
- 集成方式

### 4. 验收标准 (AC)
可验证的验收条件清单

### 5. 依赖
- 技术依赖
- 任务依赖
- 外部依赖

### 6. 风险与缓解
识别风险及应对措施

### 7. 测试策略
- 单元测试
- 集成测试
- 手动测试

### 8. 实施步骤
分步骤的执行计划

### 9. 交付物
明确的交付清单

## 文档关联

### 引用层次
```
PRD (产品需求)
 ├─> HLD (高层设计)
 │    ├─> ADR (架构决策)
 │    └─> Task Design (任务实施)
 └─> Sprint Plan (迭代计划)
      └─> Task Design (任务实施)
```

### 可追溯性要求
每个 Task 设计文档必须：
1. 关联到 Sprint Plan 中的 PBI
2. 引用相关的 HLD 章节
3. 引用相关的 ADR（如有架构决策）
4. 引用相关的 PRD 章节（如果直接关联用户故事）

示例：
```markdown
## 任务信息
- **Sprint**: Sprint 1
- **PBI**: AsrEngine 协议定义与 WhisperCppBackend（5 SP）
- **相关文档**: 
  - ADR-0001: 多平台工程架构
  - ADR-0003: 双后端策略
  - HLD §6.1: AsrEngine 协议
  - HLD §6.2: Whisper.cpp 集成
  - PRD §6.3: 语音识别功能
```

## 生命周期管理

### 创建时机
在 Sprint Planning 会议后，针对复杂任务（≥3 SP）创建详细设计文档。

### 更新时机
- 任务开始前：完善技术方案
- 实施过程中：记录关键决策与变更
- 任务完成后：更新状态与实际交付物

### 归档策略
- Sprint 结束后：保留在对应 sprint 目录
- 关键技术决策：提取为 ADR（永久保留）
- 通用设计方案：合并回 HLD（长期维护）

## 质量标准

### 完整性
- [ ] 包含所有必需章节
- [ ] 验收标准清晰可验证
- [ ] 技术方案足够详细（可直接实施）
- [ ] 关联文档完整

### 清晰性
- [ ] 代码示例可运行
- [ ] 文件路径使用绝对路径或明确约定
- [ ] 技术术语有定义或链接
- [ ] 流程图/架构图清晰（如需要）

### 可维护性
- [ ] 遵循 Markdown 格式规范
- [ ] 使用一致的命名约定
- [ ] 包含变更历史

## Sprint 0 任务清单

| 任务 | 文档 | 状态 | 优先级 |
|------|------|------|--------|
| 仓库初始化与协作规范 | task-001-repo-init.md | 待创建 | P0 |
| 多平台工程脚手架 | [task-002-multiplatform-scaffold.md](sprint-0/task-002-multiplatform-scaffold.md) | ✅ 已完成 | P0 |
| 代码规范与质量基线 | task-003-code-quality.md | 待创建 | P0 |
| 构建与 CI 基线 | task-004-ci-baseline.md | 待创建 | P0 |
| 数据与存储占位 | task-005-storage-placeholder.md | 待创建 | P1 |
| 安全/隐私与合规占位 | task-006-privacy-compliance.md | 待创建 | P1 |
| 指标与日志占位 | task-007-metrics-logging.md | 待创建 | P1 |
| 开发体验配置 | task-008-dev-experience.md | 待创建 | P2 |
| 测试架构与 DI 策略 | task-009-test-di-strategy.md | 待创建 | P0 |
| ADR 目录与模板 | ~~task-010-adr-setup.md~~ | ✅ 已完成（直接创建） | P3 |

## 最佳实践

### 1. 任务分解
- 每个 Task ≤5 SP，超过则拆分
- 保持任务原子性（单一职责）
- 明确任务间依赖关系

### 2. 技术方案
- 优先引用 ADR，避免重复
- 包含足够代码示例（可直接使用）
- 说明平台差异（iOS vs macOS）

### 3. 验收标准
- 使用 Checklist 格式
- 包含功能、性能、质量三个维度
- 可自动化验证的优先

### 4. 风险管理
- 提前识别技术风险
- 提供 Plan B（回退方案）
- 标注风险等级（高/中/低）

### 5. 测试覆盖
- 单元测试覆盖率目标
- 集成测试场景
- 手动测试步骤

## 工具与脚本

### 创建新 Task（计划）
```bash
# 未来可提供脚本自动生成 Task 模板
./scripts/new-task.sh <sprint> <task-number> <title>
```

### 验证 Task 完整性（计划）
```bash
# 检查 Task 文档是否包含所有必需章节
./scripts/validate-task.sh <task-file>
```

## 参考资料

- [Sprint Plan v0.2](../sprint-plan-v0.2-updated.md)
- [ADR 目录](../../adr/README.md)
- [HLD iOS+macOS v0.2](../../tdd/hld-ios-macos-v0.2.md)
- [Scrum 流程规范](../scrum.md)

## 联系方式

如有关于 Task 设计文档的问题，请在 Sprint Planning 或 Daily Standup 中讨论。
