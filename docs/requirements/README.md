# 需求文档（Requirements）目录

本目录用于存放产品/需求相关文档，包括正式的 PRD、评审记录与精简版本。目标是把“要做什么、为什么做、做到什么程度算完成”清晰落地，并为技术设计（TDD/ADR）提供可追溯来源。

## 文档类型
- PRD（Product Requirements Document）：完整需求说明，建议按版本/里程碑输出。
- 评审稿与评审意见：`prd_review-*.md`，保留评审过程与结论。
- 精简稿：`short.md`，用于快速对齐范围与目标。

## 命名建议
- `prd_vX.Y.md`：面向某一版本/里程碑的正式 PRD。
- `prd_review-<reviewer>.md`：评审记录。

## 与 TDD/ADR 的关系
- PRD 定义目标、范围与验收标准；TDD/ADR 则给出“如何实现、为何如此取舍”。
- 在 PRD 的“参考与追踪”章节中，链接相关 TDD/ADR/Issue/PR 以形成闭环。

## 模板
- PRD 模板参见：`./template-prd.md`

> 建议：创建新 PRD 前，复制模板并在顶部填写元信息与状态（Draft/Review/Approved）。