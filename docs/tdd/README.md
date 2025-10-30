# 技术设计文档（TDD）目录

本目录用于存放技术设计文档，包括高层设计（HLD）与低层设计（LLD）。TDD 解决“怎么做”和“为何这样做”的实现方案问题，并与 ADR（长期决策）和 PRD（做什么）保持一致。



## 文档边界
- ADR：长期架构取舍与标准，跨版本复用；TDD 仅引用 ADR，不嵌入。
- TDD：本功能/模块在本期的完整技术方案、接口契约、数据与性能目标。TDD 是系统级/模块级的长期设计文档。
- Task：单卡的执行方案与测试，引用 TDD/ADR。

## 命名与组织建议
- 命名示例：`hld-ios-macos-vX.Y.md`、`hld-android-vX.Y.md`、`lld-<topic>-vX.Y.md`
- 平台子目录：`iOS-macOS/`、`Android/`、`feasibility/`（可行性研究）

## 推荐章节
- 背景与目标、范围与非目标、约束与前提
- 架构总览与时序/状态图、模块与数据设计
- 接口与集成、质量与保障（可观测性/性能/安全/国际化）
- 测试与验证（金字塔）、发布与回滚、风险与未决
- 里程碑与估算、参考与追踪（含 ADR/TDD/Issue/PR 链接）

## 质量约定（本仓库）
- SwiftLint 严格模式（iOS/macOS）；Jetpack Compose/SwiftUI + MVVM
- 禁止硬编码字符串，统一使用国际化资源

## 模板
- TDD 模板参见：`./template-tdd.md`
