# Scripts

项目自动化脚本集合。

## 可用脚本

### `ci-validate.sh`

**用途**: 本地验证 CI 工作流

在提交代码前运行此脚本，确保所有 CI 检查都会通过：

```bash
./scripts/ci-validate.sh
```

**检查项**:
1. ✅ SwiftLint 严格模式
2. ✅ iOS 构建
3. ✅ iOS 测试
4. ✅ macOS 构建
5. ✅ macOS 测试
6. ✅ Swift Packages 测试
7. ✅ 代码覆盖率摘要

**运行时间**: 约 10-15 分钟（取决于机器性能）

**前置条件**:
- Xcode 15.4+
- SwiftLint 已安装
- iOS 17+ Simulator 可用

## 使用建议

### 提交前检查

```bash
# 1. 运行 CI 验证
./scripts/ci-validate.sh

# 2. 如果全部通过，提交代码
git add .
git commit -m "feat: your changes"
git push
```

### 快速检查

如果只想快速验证部分内容：

```bash
# 仅 SwiftLint
cd Prism-xOS && swiftlint lint --strict

# 仅 iOS 构建
cd Prism-xOS && xcodebuild build \
  -workspace PrismPlayer.xcworkspace \
  -scheme PrismPlayer-iOS \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  CODE_SIGNING_ALLOWED=NO

# 仅测试单个 Package
cd Prism-xOS/packages/PrismCore && swift test
```

---

**最后更新**: 2025-10-24
