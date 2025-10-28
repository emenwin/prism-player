# Scrum 文档目录

本目录用于存放敏捷过程文档，包括 Sprint 计划、任务卡（Task）与评审/回顾记录。目标是让计划、执行、评审形成闭环，并与 PRD、TDD、ADR 建立可追溯关系。

## 目录结构建议
```
scrum/
 ├─ sprint-plan-vX.Y.md              # 跨平台或公共 Sprint 计划（可选）
 ├─ Android/                         # 平台子目录
 │   ├─ README.md
 │   ├─ sprint-plan-vX.Y.md
 │   └─ tasks/
 │      ├─ README.md
 │      └─ sprint-N/
 └─ iOS-macOS/
     ├─ sprint-plan-vX.Y.md
     ├─ reviews/                    # 计划评审与复盘
     └─ tasks/
        └─ sprint-N/
```

## 文档边界
- Sprint 计划：目标、容量、范围（PBI 列表）、风险与里程碑。
- Task 详细设计：单卡的实施方案、改动清单、测试与验收、观测与回滚。
- 不重复 TDD/ADR：架构与长期取舍放在 TDD/ADR，任务文档仅引用。

## 模板
- Sprint 计划模板：`./template-sprint-plan.md`
- Task 模板：`./template-task.md`

## 约定与检查清单
- DOR（就绪定义）：目标清晰、范围可控、依赖已识别、验收标准可执行。
- DoD（完成定义）：
  - CI 通过（构建/测试/SwiftLint 严格模式）
  - 无硬编码字符串（使用本地化）
  - 文档与变更日志更新
  - 关键路径有测试覆盖与可观测埋点

## 追踪建议
- 在 Sprint 计划与 Task 中添加“相关 PRD/TDD/ADR/Issue/PR”链接，形成追踪矩阵。