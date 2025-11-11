# Task 详细设计：Task-108 CI 矩阵与测试覆盖率

- Sprint：S1
- Task：Task-108 CI 矩阵与测试覆盖率
- PBI：HLD §13 CI/CD
- Owner：@架构
- 状态：Todo

## 相关 TDD
- [x] docs/tdd/iOS-macOS/hld-ios-macos-v0.2.md — §13 CI/CD 约束

## 相关 ADR
- [ ] （如有）CI 工具与覆盖率策略 ADR

## 1. 目标与范围
- 目标：iOS 17+/macOS 14+ 矩阵；所有 Package + App 单测自动运行；覆盖率收集与阈值检查；契约测试/金样本测试纳入。
- 非目标：发布与签名流水线。

## 2. 方案要点（引用为主）
- GitHub Actions 工作流：构建、测试、覆盖率（slather/xcov）。
- 缓存与并行化；报告注入 PR 注释。

## 3. 改动清单
- .github/workflows/ci.yml（或分解多个）
- scripts/ci-validate.sh

## 4. 实施计划
- PR1：矩阵与构建（0.5d）
- PR2：测试与覆盖率采集（0.5d）
- PR3：阈值检查与报告（0.5d）

## 5. 测试与验收
- 触发条件：push/PR；报告包含覆盖率与契约测试结果。
- 验收：任务清单 7 项验收标准全部通过。

## 6. 观测与验证
- 失败快速反馈；缓存命中率监控。

## 7. 风险与未决
- Xcode 模拟器稳定性；重试与超时策略。

## 定义完成（DoD）
- [ ] CI 通过
- [ ] 文档更新
- [ ] Code Review 通过

---

模板版本：v1.1  
文档版本：v1.0  
最后更新：2025-11-06  
变更记录：
- v1.0 (2025-11-06): 初始详细设计
