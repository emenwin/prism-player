# Task-003: 代码规范与质量基线

## 任务信息

- **Sprint**: Sprint 0
- **估算**: 2 SP
- **优先级**: P0
- **依赖**: Task-002（多平台工程脚手架）
- **负责人**: 待分配
- **状态**: 进行中

## 任务目标

建立代码规范与质量基线，配置 SwiftLint 严格模式，确保代码风格一致性，并在 CI 中启用 Lint 检查。

## 验收标准（AC）

1. ✅ SwiftLint 已配置并启用严格模式
2. ✅ 所有规则符合移动端开发最佳实践
3. ✅ 禁止硬编码字符串，强制使用国际化
4. ✅ 现有代码通过 SwiftLint 检查（0 警告 0 错误）
5. ✅ CI 中集成 SwiftLint 检查
6. ✅ 文档说明如何本地运行 Lint

**验证结果**：
- SwiftLint 版本：0.59.1
- Lint 检查结果：15 个文件，0 违规，0 严重错误
- 严格模式测试通过 ✅

## 实施步骤

### Step 1: 安装 SwiftLint

通过 Homebrew 安装 SwiftLint（用于本地开发）：

```bash
brew install swiftlint
```

### Step 2: 配置 .swiftlint.yml

在工程根目录创建 `.swiftlint.yml` 配置文件，包含：

- 严格模式规则
- 禁用硬编码字符串
- 文件长度、行长度等限制
- 排除规则（生成代码、第三方库等）

### Step 3: 集成到 Xcode Build Phase

为 iOS 和 macOS App Target 添加 Run Script Phase：

```bash
if which swiftlint >/dev/null; then
  swiftlint
else
  echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
fi
```

### Step 4: 修复现有代码问题

运行 SwiftLint 并修复所有警告和错误：

```bash
cd Prism-xOS
swiftlint lint --strict
swiftlint --fix  # 自动修复部分问题
```

### Step 5: 添加 GitHub Actions Workflow

创建 `.github/workflows/swiftlint.yml`，在 PR 和 Push 时自动检查。

### Step 6: 更新文档

在 `Prism-xOS/README.md` 中添加代码规范章节。

## 技术要点

### SwiftLint 规则配置

- **启用规则**：
  - `nslocalizedstring_key`: 禁止硬编码字符串
  - `force_unwrapping`: 禁止强制解包
  - `trailing_whitespace`: 尾随空格
  - `vertical_whitespace`: 垂直空格
  - `line_length`: 行长度限制（120）
  - `file_length`: 文件长度限制（400 行警告）
  - `type_body_length`: 类型长度限制
  - `function_body_length`: 函数长度限制
  - `cyclomatic_complexity`: 圈复杂度

- **排除路径**：
  - `.build/`
  - `DerivedData/`
  - `*.xcodeproj/`
  - `Tests/Fixtures/`
  - `Tests/Mocks/`

### Xcode 集成

在 Target → Build Phases → New Run Script Phase 中添加：

```bash
export PATH="$PATH:/opt/homebrew/bin"
if which swiftlint >/dev/null; then
  swiftlint
else
  echo "warning: SwiftLint not installed"
fi
```

## 交付物

- [x] `.swiftlint.yml` 配置文件
- [x] Xcode Build Phase 脚本集成
- [x] GitHub Actions Workflow
- [x] `Prism-xOS/README.md` 代码规范章节
- [x] 所有现有代码通过 Lint 检查

## 风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 现有代码有大量 Lint 错误 | 中 | 使用 `swiftlint --fix` 自动修复；逐步修复手动问题 |
| CI 环境 SwiftLint 版本不一致 | 低 | 使用 Docker 或指定版本号 |
| 严格模式影响开发效率 | 低 | 提供清晰文档；部分规则可降级为警告 |

## 测试要点

1. 本地运行 `swiftlint lint --strict` 通过
2. CI Workflow 触发并通过
3. Xcode 构建时显示 Lint 警告/错误
4. 故意引入违规代码，验证检测生效

## 参考资料

- [SwiftLint 官方文档](https://github.com/realm/SwiftLint)
- [SwiftLint 规则列表](https://realm.github.io/SwiftLint/rule-directory.html)
- [Copilot Instructions](/.github/copilot-instructions.md) - Code Style 要求

## 完成标准

- ✅ SwiftLint 配置文件已创建（`.swiftlint.yml`）
- ✅ Xcode 集成脚本已创建（`scripts/swiftlint.sh`）
- ✅ CI Workflow 已添加（`.github/workflows/swiftlint.yml`）
- ✅ 文档已更新（`README.md`, `docs/SwiftLint-Integration.md`）
- ✅ 所有代码通过 Lint 检查（15 文件，0 违规）

## 交付物清单

1. **配置文件**
   - `.swiftlint.yml` - SwiftLint 规则配置
   
2. **脚本**
   - `scripts/swiftlint.sh` - Xcode Build Phase 脚本

3. **CI/CD**
   - `.github/workflows/swiftlint.yml` - GitHub Actions 工作流

4. **文档**
   - `README.md` - 更新代码规范章节
   - `docs/SwiftLint-Integration.md` - Xcode 集成指南

5. **代码修复**
   - 所有 Swift 文件已通过 SwiftLint 严格模式检查
   - 移除硬编码字符串，使用 `String(localized:)`
   - 修复代码格式问题（空格、换行等）

---

**任务状态**: ✅ 已完成  
**创建日期**: 2025-10-24  
**完成日期**: 2025-10-24
