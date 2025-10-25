# CI/CD 文档

本文档说明 Prism Player 项目的持续集成/持续部署（CI/CD）流程。

## 概述

项目使用 GitHub Actions 实现自动化构建、测试和代码质量检查。每次 Push 或 Pull Request 都会自动触发相应的工作流。

## 工作流

### 1. Build & Test (`.github/workflows/build.yml`)

主构建和测试工作流，包含三个并行任务：

#### iOS 构建
- **运行环境**: macOS 14, Xcode 15.4
- **目标**: iOS 17.5+ Simulator (iPhone 15)
- **步骤**:
  1. 构建 `PrismPlayer-iOS` target
  2. 运行单元测试
  3. 生成代码覆盖率报告
  4. 上传测试结果

#### macOS 构建
- **运行环境**: macOS 14, Xcode 15.4
- **目标**: macOS 14.0+
- **步骤**:
  1. 构建 `PrismPlayer-macOS` target
  2. 运行单元测试
  3. 生成代码覆盖率报告
  4. 上传测试结果

#### Swift Packages 测试
- **包**: PrismCore, PrismASR, PrismKit
- **步骤**:
  1. 使用 `swift test` 运行包测试
  2. 生成覆盖率报告
  3. （可选）上传到 Codecov

### 2. SwiftLint (`.github/workflows/swiftlint.yml`)

代码规范检查工作流：

- **运行环境**: macOS 14
- **检查**: SwiftLint 严格模式
- **失败处理**: 生成详细报告到 GitHub Summary

### 3. 触发条件

所有工作流在以下情况下触发：

```yaml
on:
  push:
    branches: [ main, dev ]
    paths:
      - 'Prism-xOS/**'
      - '.github/workflows/*.yml'
  pull_request:
    branches: [ main, dev ]
```

## 缓存策略

为加速构建，CI 使用以下缓存：

- **Swift Package Manager**:
  - `~/Library/Developer/Xcode/DerivedData`
  - `Prism-xOS/.build`
- **缓存键**: 基于 `Package.resolved` 的哈希值

## 本地复现 CI 构建

### iOS

```bash
cd Prism-xOS

# 构建
xcodebuild build \
  -workspace PrismPlayer.xcworkspace \
  -scheme PrismPlayer-iOS \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.5' \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO

# 测试
xcodebuild test \
  -workspace PrismPlayer.xcworkspace \
  -scheme PrismPlayer-iOS \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.5' \
  -enableCodeCoverage YES \
  -resultBundlePath TestResults.xcresult \
  CODE_SIGNING_ALLOWED=NO
```

### macOS

```bash
cd Prism-xOS

# 构建
xcodebuild build \
  -workspace PrismPlayer.xcworkspace \
  -scheme PrismPlayer-macOS \
  -destination 'platform=macOS' \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO

# 测试
xcodebuild test \
  -workspace PrismPlayer.xcworkspace \
  -scheme PrismPlayer-macOS \
  -destination 'platform=macOS' \
  -enableCodeCoverage YES \
  -resultBundlePath TestResults.xcresult \
  CODE_SIGNING_ALLOWED=NO
```

### Swift Packages

```bash
cd Prism-xOS/packages/PrismCore

# 测试
swift test --enable-code-coverage

# 查看覆盖率
swift test --enable-code-coverage && \
xcrun llvm-cov show \
  .build/debug/PrismCorePackageTests.xctest/Contents/MacOS/PrismCorePackageTests \
  -instr-profile .build/debug/codecov/default.profdata
```

### SwiftLint

```bash
cd Prism-xOS

# 检查
swiftlint lint --strict

# 自动修复
swiftlint --fix
```

## 测试覆盖率

### 查看覆盖率报告

#### Xcode

1. 运行测试（⌘U）
2. 打开 Report Navigator（⌘9）
3. 选择最新的测试报告
4. 切换到 Coverage 标签页

#### 命令行

```bash
# 生成覆盖率报告
xcrun xccov view --report TestResults.xcresult

# 导出为 JSON
xcrun xccov view --report --json TestResults.xcresult > coverage.json
```

### 覆盖率目标

根据 Sprint 计划：

- **Core/Kit 层**: ≥ 70%
- **ViewModel 层**: ≥ 60%
- **关键业务路径**: ≥ 80%

## 故障排查

### 构建失败

1. **签名问题**:
   - CI 使用 `CODE_SIGNING_ALLOWED=NO`
   - 确保本地也使用相同设置

2. **依赖解析失败**:
   ```bash
   # 清理缓存
   rm -rf ~/Library/Developer/Xcode/DerivedData
   rm -rf Prism-xOS/.build
   
   # 重新解析
   xcodebuild -resolvePackageDependencies
   ```

3. **Simulator 不可用**:
   ```bash
   # 列出可用 Simulator
   xcrun simctl list devices available
   
   # 创建新 Simulator
   xcrun simctl create "iPhone 15" "iPhone 15" "iOS17.5"
   ```

### 测试失败

1. **环境差异**:
   - 检查 Xcode 版本是否一致
   - 检查 macOS 版本是否一致

2. **时间相关测试**:
   - 使用依赖注入的时钟
   - 避免依赖真实时间

3. **文件路径问题**:
   - 使用相对路径
   - 使用 `Bundle.module`（Swift Package）

### SwiftLint 失败

1. **规则冲突**:
   - 检查 `.swiftlint.yml` 配置
   - 本地运行 `swiftlint lint --strict`

2. **版本不一致**:
   - CI 使用 `brew install swiftlint`
   - 确保本地版本一致

## 性能优化

### 减少构建时间

1. **使用缓存**: 已启用 SPM 和 DerivedData 缓存
2. **并行构建**: 多个 Job 并行运行
3. **条件触发**: 仅在相关文件变更时运行
4. **取消重复运行**: 使用 `concurrency` 配置

### 当前构建时间（估算）

- iOS 构建: ~5-8 分钟
- macOS 构建: ~4-6 分钟
- Swift Packages 测试: ~2-3 分钟（每个包）
- SwiftLint: ~1-2 分钟

总计: ~15-25 分钟（并行）

## 状态徽章

在 README.md 中添加：

```markdown
[![Build Status](https://github.com/<org>/prism-player/workflows/Build%20%26%20Test/badge.svg)](https://github.com/<org>/prism-player/actions)
[![SwiftLint](https://github.com/<org>/prism-player/workflows/SwiftLint/badge.svg)](https://github.com/<org>/prism-player/actions)
[![codecov](https://codecov.io/gh/<org>/prism-player/branch/main/graph/badge.svg)](https://codecov.io/gh/<org>/prism-player)
```

## 未来改进

- [ ] 集成 Codecov 自动上传覆盖率
- [ ] 添加性能基准测试
- [ ] 集成静态分析工具（SwiftFormat, Periphery）
- [ ] 添加发布自动化（TestFlight）
- [ ] 添加依赖安全扫描

## 参考资料

- [GitHub Actions 官方文档](https://docs.github.com/en/actions)
- [Xcodebuild 参考](https://developer.apple.com/library/archive/technotes/tn2339/)
- [Swift Package Manager](https://swift.org/package-manager/)
- [Codecov Swift 集成](https://docs.codecov.com/docs/swift)

---

**文档版本**: v1.0  
**最后更新**: 2025-10-24
