# SwiftLint Xcode 集成指南

本文档说明如何在 Xcode 项目中集成 SwiftLint。

## 前置条件

确保已安装 SwiftLint：

```bash
brew install swiftlint
```

## 集成步骤

### 方法 1: 使用提供的脚本（推荐）

1. 在 Xcode 中打开项目
2. 选择 Target（`PrismPlayer-iOS` 或 `PrismPlayer-macOS`）
3. 切换到 **Build Phases** 标签页
4. 点击左上角 `+` → **New Run Script Phase**
5. 将新建的 Run Script 拖到 **Compile Sources** 之前
6. 在脚本框中输入：

```bash
"${PROJECT_DIR}/scripts/swiftlint.sh"
```

7. 勾选 **Based on dependency analysis**（可选，加速构建）

### 方法 2: 直接内嵌脚本

在 Run Script Phase 中直接输入：

```bash
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"

if which swiftlint >/dev/null; then
  swiftlint
else
  echo "warning: SwiftLint not installed"
fi
```

## 验证集成

1. 在代码中故意引入违规（如硬编码字符串）：
   ```swift
   let text = "硬编码文本"  // 违反 nslocalizedstring_key 规则
   ```

2. 构建项目（⌘B）

3. 应在 Issue Navigator 中看到 SwiftLint 警告/错误

4. 修复违规后，警告/错误应消失

## 配置说明

- SwiftLint 配置文件：`.swiftlint.yml`
- 规则详情见配置文件注释
- 可通过修改配置调整规则严格程度

## 常见问题

### Q: 构建时提示 "SwiftLint not installed"

A: 
1. 确认已通过 Homebrew 安装 SwiftLint
2. 检查 PATH 环境变量
3. 重启 Xcode

### Q: 规则太严格，影响开发

A:
1. 在 `.swiftlint.yml` 中调整规则
2. 将部分规则从 `error` 改为 `warning`
3. 或临时禁用某些规则

### Q: 如何在特定代码处禁用规则？

A: 使用注释标记：

```swift
// swiftlint:disable:next force_unwrapping
let value = optionalValue!

// 禁用整个文件
// swiftlint:disable all
```

## 命令行使用

```bash
# 检查所有文件
swiftlint lint

# 严格模式（CI）
swiftlint lint --strict

# 自动修复
swiftlint --fix

# 查看规则列表
swiftlint rules
```

---

**文档版本**: v1.0  
**最后更新**: 2025-10-24
