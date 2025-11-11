# Task-004: 构建与 CI 基线

## 任务信息

## 相关 TDD
- [tdd/iOS-macOS/hld-ios-macos-v0.2.md](../../../../tdd/iOS-macOS/hld-ios-macos-v0.2.md) — 约束：SwiftUI + MVVM，SwiftLint 严格模式，国际化无硬编码

## 相关 ADR
- [docs/adr/iOS-macOS/0001-multiplatform-architecture.md](../../../../adr/iOS-macOS/0001-multiplatform-architecture.md) — Accepted
- [docs/adr/iOS-macOS/0002-player-view-ui-stack.md](../../../../adr/iOS-macOS/0002-player-view-ui-stack.md) — Accepted
- [docs/adr/iOS-macOS/0003-sqlite-storage-solution.md](../../../../adr/iOS-macOS/0003-sqlite-storage-solution.md) — Accepted
- [docs/adr/iOS-macOS/0004-logging-metrics-strategy.md](../../../../adr/iOS-macOS/0004-logging-metrics-strategy.md) — Accepted
- [docs/adr/iOS-macOS/0005-testing-di-strategy.md](../../../../adr/iOS-macOS/0005-testing-di-strategy.md) — Accepted

## 定义完成（DoD）
- [ ] CI 通过（构建/测试/SwiftLint 严格模式）
- [ ] 无硬编码字符串（使用国际化）
- [ ] 文档/变更日志更新（PRD/TDD/ADR/Scrum）
- [ ] 关键路径测试覆盖与可观测埋点到位

- **Sprint**: Sprint 0
- **估算**: 3 SP
- **优先级**: P0
- **依赖**: Task-002（多平台工程脚手架）, Task-003（代码规范）
- **负责人**: 待分配
- **状态**: 进行中

## 任务目标

建立 CI/CD 基线，配置 GitHub Actions 工作流，实现自动化构建、测试和代码质量检查，确保每次代码提交都经过验证。

## 验收标准（AC）

1. ✅ GitHub Actions 工作流已配置
2. ✅ 支持 iOS 17+ 和 macOS 14+ 构建矩阵
3. ✅ 自动运行 SwiftLint 检查（已在 Task-003 完成）
4. ✅ 自动运行单元测试
5. ✅ 生成测试覆盖率报告
6. ✅ PR 和 Push 时自动触发
7. ✅ 构建状态徽章添加到 README

**验证结果**：
- Build workflow 已创建：iOS + macOS + Swift Packages
- 支持并行构建和测试
- 启用代码覆盖率收集
- 配置缓存策略加速构建
- 文档已完善

## 实施步骤

### Step 1: 创建主构建工作流

创建 `.github/workflows/build.yml`，包含：
- iOS 和 macOS 构建
- 多版本 Xcode 矩阵
- 单元测试执行
- 测试覆盖率收集

### Step 2: 配置测试覆盖率

- 使用 `xcodebuild` 收集覆盖率数据
- 可选：集成 Codecov 或 Coveralls
- 设置覆盖率阈值警告

### Step 3: 优化 CI 性能

- 启用缓存（Swift Package Manager、DerivedData）
- 并行运行多个 Job
- 仅在相关文件变更时触发

### Step 4: 添加状态徽章

在 README.md 中添加：
- Build Status
- SwiftLint Status
- Coverage Status（可选）

### Step 5: 文档化 CI 流程

创建 `docs/ci-cd.md` 说明：
- CI 工作流结构
- 如何本地复现 CI 构建
- 故障排查指南

## 技术要点

### GitHub Actions 配置

```yaml
name: Build & Test

on:
  push:
    branches: [ main, dev ]
  pull_request:
    branches: [ main, dev ]

jobs:
  build-ios:
    runs-on: macos-14
    strategy:
      matrix:
        scheme: [PrismPlayer-iOS]
        destination: ['platform=iOS Simulator,name=iPhone 15,OS=17.0']
    
  build-macos:
    runs-on: macos-14
    strategy:
      matrix:
        scheme: [PrismPlayer-macOS]
```

### 测试覆盖率收集

```bash
xcodebuild test \
  -workspace PrismPlayer.xcworkspace \
  -scheme PrismPlayer-iOS \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -enableCodeCoverage YES \
  -resultBundlePath TestResults.xcresult
```

### 缓存策略

```yaml
- name: Cache Swift Package Manager
  uses: actions/cache@v4
  with:
    path: |
      ~/Library/Developer/Xcode/DerivedData
      ~/.swiftpm
    key: ${{ runner.os }}-spm-${{ hashFiles('**/Package.resolved') }}
```

## 交付物

- [x] `.github/workflows/build.yml` - 主构建工作流
- [x] `.github/workflows/test.yml` - 测试工作流（可选，或合并到 build.yml）
- [x] SwiftLint 工作流已存在（Task-003）
- [x] `docs/ci-cd.md` - CI/CD 文档
- [x] README.md 状态徽章

## 风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| CI 构建时间过长 | 中 | 启用缓存；并行运行；仅在必要时触发 |
| Xcode 版本兼容性 | 中 | 使用稳定的 macos-14 runner；固定 Xcode 版本 |
| 测试在 CI 中失败但本地通过 | 高 | 确保环境一致；提供本地复现脚本 |
| 覆盖率收集失败 | 低 | 初期可选；逐步完善 |

## 测试要点

1. 验证 iOS 构建成功（多个 Simulator）
2. 验证 macOS 构建成功
3. 验证单元测试全部通过
4. 验证 SwiftLint 检查通过
5. 验证覆盖率报告生成
6. 验证 PR 触发 CI
7. 验证状态徽章显示正确

## 参考资料

- [GitHub Actions for iOS](https://docs.github.com/en/actions/use-cases-and-examples/building-and-testing/building-and-testing-swift)
- [xcodebuild man page](https://developer.apple.com/library/archive/technotes/tn2339/_index.html)
- [Codecov for Swift](https://docs.codecov.com/docs/swift)

## 完成标准

- ✅ GitHub Actions 工作流已创建并配置
- ✅ iOS + macOS 构建矩阵工作正常
- ✅ Swift Packages 测试独立运行
- ✅ 单元测试自动运行
- ✅ 代码覆盖率报告生成（可上传 Codecov）
- ✅ 缓存策略已优化构建速度
- ✅ 文档已更新（README + CI/CD 文档）
- ✅ 状态徽章已添加

## 交付物清单

1. **GitHub Actions 工作流**
   - `.github/workflows/build.yml` - 主构建与测试工作流
   - `.github/workflows/swiftlint.yml` - SwiftLint 检查（Task-003）

2. **文档**
   - `docs/ci-cd.md` - CI/CD 完整文档
   - `README.md` - 添加状态徽章和文档链接

3. **CI 特性**
   - iOS 17.5+ 构建和测试
   - macOS 14.0+ 构建和测试
   - Swift Packages 独立测试
   - 代码覆盖率收集
   - SPM 和 DerivedData 缓存
   - 并行执行加速
   - 测试结果工件上传

---

**任务状态**: ✅ 已完成  
**创建日期**: 2025-10-24  
**完成日期**: 2025-10-24
