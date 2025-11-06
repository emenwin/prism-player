# Task 详细设计：Task-106 SRT 导出（基础版）

- Sprint：S1
- Task：Task-106 SRT 导出（基础版）
- PBI：PRD §6.6, US §5-5
- Owner：@后端
- 状态：Todo

## 相关 TDD
- [x] docs/tdd/iOS-macOS/hld-ios-macos-v0.2.md — 参见 §7 导出

## 相关 ADR
- [ ] （无）

## 1. 目标与范围
- 目标：UTF-8 编码；文件命名；时间戳格式正确；成功率 ≥ 99%；专项用例覆盖。
- 非目标：字幕合并/拆分策略与后处理优化。

## 2. 方案要点（引用为主）
- Segment→SRT Line 转换；时间格式 HH:MM:SS,mmm；文件存在处理：自动重命名。

## 3. 改动清单
- PrismCore/Sources/Exporters/SRTExporter.swift
- PrismCore/Tests/Exporters/SRTExporterTests.swift

## 4. 实施计划
- PR1：SRT 格式化与验证（0.5d）
- PR2：文件系统错误处理与命名规则（0.5d）
- PR3：专项导出用例与CI（0.5d）

## 5. 测试与验收
- 单测：空字幕/特殊字符/长文本/溢出边界。
- E2E：导出并校验文件内容与命名。
- 验收：任务清单 7 项验收标准全部通过。

## 6. 观测与验证
- 导出成功/失败计数与错误码；磁盘不足告警路径。

## 7. 风险与未决
- 文件权限与沙箱路径差异；通过统一导出目录与用户提示缓解。

## 定义完成（DoD）
- [ ] CI 通过 / 覆盖率达标
- [ ] 国际化文本
- [ ] 文档更新
- [ ] Code Review 通过

---

模板版本：v1.1  
文档版本：v1.0  
最后更新：2025-11-06  
变更记录：
- v1.0 (2025-11-06): 初始详细设计
