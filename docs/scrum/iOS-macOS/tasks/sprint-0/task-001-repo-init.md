# Task-001: 仓库初始化与协作规范

## 任务信息

- **Sprint**: Sprint 0
- **PBI**: 仓库初始化与协作规范（3 SP）
- **优先级**: P0
- **状态**: Todo
- **负责人**: TBD
- **相关文档**: 
  - Sprint Plan v0.2: Sprint 0 PBI 1
  - HLD §13: 工程结构

## 目标

建立完整的代码仓库基础设施与团队协作规范，包括 Git 工作流、提交规范、文档模板和 Issue/PR 流程，为项目的顺利开展奠定基础。

## 技术方案

### 1. Git 分支策略

采用 **Git Flow 简化版**：

```
main (生产环境)
 ├─ develop (开发主线)
 │   ├─ feature/sprint-1-player-service
 │   ├─ feature/sprint-1-asr-engine
 │   └─ feature/sprint-2-model-management
 ├─ release/v0.1.0 (发布分支，可选)
 └─ hotfix/critical-bug (紧急修复)
```

#### 分支规则

| 分支类型 | 命名规范 | 生命周期 | 说明 |
|---------|---------|---------|------|
| `main` | 固定 | 永久 | 生产环境代码，受保护 |
| `develop` | 固定 | 永久 | 开发主线，集成分支 |
| `feature/*` | `feature/<sprint>-<描述>` | Sprint 周期 | 功能开发分支 |
| `bugfix/*` | `bugfix/<issue-id>-<描述>` | 临时 | Bug 修复分支 |
| `hotfix/*` | `hotfix/<描述>` | 临时 | 紧急修复分支 |
| `release/*` | `release/v<version>` | 临时 | 发布准备分支（可选） |

#### 分支保护规则

**`main` 分支保护**：
- ✅ 必须通过 PR 合并（禁止直接推送）
- ✅ 需要至少 1 人 Review 批准
- ✅ 必须通过 CI 检查（构建 + 测试 + Lint）
- ✅ 必须是线性历史（Squash or Rebase）

**`develop` 分支保护**：
- ✅ 必须通过 PR 合并
- ✅ 必须通过 CI 检查
- ⚠️ Review 可选（建议有）

### 2. Commit 规范（Conventional Commits）

采用 **Conventional Commits** 规范：

```
<type>(<scope>): <subject>

<body>

<footer>
```

#### Type 类型

| Type | 说明 | 示例 |
|------|------|------|
| `feat` | 新功能 | `feat(asr): add WhisperCppBackend implementation` |
| `fix` | Bug 修复 | `fix(player): resolve audio sync issue` |
| `docs` | 文档变更 | `docs(readme): update installation guide` |
| `style` | 代码格式（不影响逻辑） | `style(core): apply swiftlint fixes` |
| `refactor` | 重构 | `refactor(cache): improve LRU algorithm` |
| `perf` | 性能优化 | `perf(asr): optimize audio preprocessing` |
| `test` | 测试相关 | `test(player): add playback state tests` |
| `build` | 构建系统 | `build(ci): add coverage report` |
| `ci` | CI 配置 | `ci(github): add iOS 17 build matrix` |
| `chore` | 其他杂项 | `chore(deps): update swift package dependencies` |
| `revert` | 回滚 | `revert: feat(asr): remove experimental feature` |

#### Scope 范围

| Scope | 说明 |
|-------|------|
| `core` | PrismCore 核心模块 |
| `asr` | PrismASR 模块 |
| `kit` | PrismKit UI 组件 |
| `player` | 播放器相关 |
| `cache` | 缓存管理 |
| `model` | 模型管理 |
| `export` | 导出功能 |
| `ci` | CI/CD 配置 |
| `docs` | 文档 |

#### Commit 示例

```bash
# 新功能
feat(asr): implement AsrEngine protocol and WhisperCppBackend

- Define AsrEngine protocol with transcribe method
- Implement WhisperCppBackend using whisper.cpp
- Add unit tests and mock implementation

Closes #12

# Bug 修复
fix(player): resolve subtitle sync offset issue

The subtitle timestamps were off by 200ms due to incorrect
audio extraction timing. Now using player callback as the
single source of truth.

Fixes #45

# 文档更新
docs(adr): add ADR-0001 multiplatform architecture

# Breaking Change
feat(asr)!: change AsrEngine API to async/await

BREAKING CHANGE: AsrEngine.transcribe now returns async throws
instead of completion handler. Update all call sites.
```

### 3. 仓库文件结构

#### 3.1 根目录文件

```
prism-player/
├── .gitignore                  # Git 忽略规则
├── .gitattributes              # Git 属性配置
├── LICENSE                     # 开源许可证
├── README.md                   # 项目说明
├── CONTRIBUTING.md             # 贡献指南
├── CODE_OF_CONDUCT.md          # 行为准则
├── CHANGELOG.md                # 变更日志
├── .github/                    # GitHub 配置
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.md
│   │   ├── feature_request.md
│   │   └── task.md
│   ├── PULL_REQUEST_TEMPLATE.md
│   ├── workflows/
│   │   ├── ci.yml
│   │   └── release.yml
│   └── CODEOWNERS
├── scripts/                    # 自动化脚本
│   ├── setup-workspace.sh
│   └── run-tests.sh
└── docs/                       # 文档目录
```

### 4. .gitignore 配置

```gitignore
# filepath: .gitignore

### macOS ###
.DS_Store
.AppleDouble
.LSOverride
Icon
._*

### Xcode ###
## Build generated
build/
DerivedData/
*.xcuserstate
*.pbxuser
!default.pbxuser
*.mode1v3
!default.mode1v3
*.mode2v3
!default.mode2v3
*.perspectivev3
!default.perspectivev3
xcuserdata/
*.xccheckout
*.moved-aside
*.hmap
*.ipa
*.dSYM.zip
*.dSYM

## Xcode Patch
*.xcodeproj/*
!*.xcodeproj/project.pbxproj
!*.xcodeproj/xcshareddata/
!*.xcworkspace/contents.xcworkspacedata
/*.gcno

### Swift Package Manager ###
.build/
.swiftpm/
Packages/
Package.resolved
*.swiftpm

### CocoaPods (如果使用) ###
Pods/
*.xcworkspace
!default.xcworkspace
Podfile.lock

### Fastlane ###
fastlane/report.xml
fastlane/Preview.html
fastlane/screenshots/**/*.png
fastlane/test_output

### Testing ###
*.gcov
*.gcda
*.profraw
*.profdata
coverage/
.coverage

### IDE ###
.vscode/
.idea/
*.swp
*.swo
*~

### App Data (开发环境) ###
*.sqlite
*.sqlite-shm
*.sqlite-wal
AudioCache/
Models/
Exports/

### Logs ###
*.log
logs/

### Temporary ###
tmp/
temp/
*.tmp
```
 
## 💡 使用

### 快速开始

1. **选择媒体文件**：点击"打开"按钮选择本地视频或音频
2. **下载模型**：首次使用时下载语音识别模型（约 150MB）
3. **开始播放**：播放后自动生成字幕
4. **导出字幕**：点击"导出"保存为 SRT 文件

### 模型管理

- **下载模型**：设置 → 模型管理 → 选择语言 → 下载
- **导入模型**：支持从本地导入 `.gguf` 模型文件
- **删除模型**：长按模型卡片 → 删除

## 🛠️ 开发

### 工程结构

```
prism-player/
├── apps/                    # 应用层
│   ├── PrismPlayer-iOS/     # iOS App
│   └── PrismPlayer-macOS/   # macOS App
├── packages/                # Swift Packages
│   ├── PrismCore/           # 核心协议与模型
│   ├── PrismASR/            # ASR 引擎
│   └── PrismKit/            # UI 组件
└── docs/                    # 文档
```

### 技术栈

- **语言**: Swift 5.9+
- **UI**: SwiftUI
- **架构**: MVVM + 协议式 DI
- **ASR**: whisper.cpp / MLX Swift
- **存储**: SQLite
- **测试**: XCTest + Quick/Nimble（可选）

### 本地开发

```bash
# 安装依赖（如需要）
# Swift Package 会自动解析

# 运行测试
swift test --package-path packages/PrismCore
swift test --package-path packages/PrismASR

# 代码检查
swiftlint lint --strict
```

### CI/CD

本项目使用 GitHub Actions 进行持续集成：

- ✅ 构建 iOS/macOS Target
- ✅ 运行单元测试
- ✅ SwiftLint 代码检查
- ✅ 测试覆盖率报告

 
### 开发流程

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'feat(asr): add amazing feature'`)
4. 推送分支 (`git push origin feature/amazing-feature`)
5. 创建 Pull Request

### Commit 规范

遵循 [Conventional Commits](https://www.conventionalcommits.org/)：

```
feat(scope): add new feature
fix(scope): fix bug
docs(scope): update documentation
```

## 📄 文档

- [产品需求文档 (PRD)](docs/requirements/prd_v0.2.md)
- [技术设计文档 (HLD)](docs/tdd/hld-ios-macos-v0.2.md)
- [架构决策记录 (ADR)](docs/adr/README.md)
- [Sprint 计划](docs/scrum/sprint-plan-v0.2-updated.md)

## 📊 项目状态

当前版本: **0.1.0-alpha** (Sprint 0)

- ✅ Sprint 0: 工程基线（进行中）
- ⏳ Sprint 1: M1 原型
- ⏳ Sprint 2: M2 可用版
- ⏳ Sprint 3: M3 优化版

## 🙏 致谢

本项目使用了以下开源项目：

- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) - 高性能 Whisper 推理引擎
- [MLX Swift](https://github.com/ml-explore/mlx-swift) - Apple Silicon 机器学习框架


---



 

## Pull Request 规范

### PR Title

遵循 Conventional Commits：

```
feat(asr): add Whisper model support
fix(player): resolve audio sync issue
docs(readme): update installation guide
```

### PR Description

使用模板填写：

- **What**: 改动了什么
- **Why**: 为什么需要这个改动
- **How**: 如何实现的
- **Testing**: 如何测试
- **Checklist**: 完成情况

### Code Review

- 至少 1 人 Review 批准
- 所有 CI 检查通过
- 无未解决的 Review 评论

 
 
## ✅ Checklist

### 代码质量
- [ ] SwiftLint 检查通过
- [ ] 无硬编码字符串（使用 String Catalog）
- [ ] 遵循项目编码规范
- [ ] 代码有适当注释

### 测试
- [ ] 所有测试通过
- [ ] 新增代码有测试覆盖
- [ ] 测试覆盖率达标（Core/Kit ≥70%）

### 文档
- [ ] 更新了相关文档
- [ ] 添加了 CHANGELOG 条目
- [ ] 更新了 README（如需要）

### 兼容性
- [ ] iOS 17+ 兼容性验证
- [ ] macOS 14+ 兼容性验证
- [ ] 无 Breaking Changes（或已标注）

### 其他
- [ ] PR 标题符合 Conventional Commits
- [ ] 分支基于最新的 `develop`
- [ ] CI 检查全部通过

## 📋 Review Notes

需要 Reviewer 特别关注的点：

- ...

 
 
## 交付物

### 配置文件
- [x] `.gitignore`
- [x] `.gitattributes`
- [x] `LICENSE`

### 文档
- [x] `README.md`
- [x] `CONTRIBUTING.md`
- [x] `CODE_OF_CONDUCT.md`
- [x] `CHANGELOG.md`

### GitHub 配置
- [x] Issue 模板（Bug/Feature/Task）
- [x] PR 模板
- [x] `CODEOWNERS`
- [x] 分支保护规则

### 流程文档
- [x] Git 工作流说明
- [x] Commit 规范说明
- [x] Code Review 流程

## 时间估算

- **仓库初始化**: 0.5 天
- **文档创建**: 0.5 天
- **模板配置**: 0.5 天
- **分支策略**: 0.5 天
- **验证测试**: 0.5 天
- **优化调整**: 0.5 天

**总计**: 3 Story Points (~3 天，1 人)

## 后续任务

- **Task-002**: 多平台工程脚手架
- **Task-003**: 代码规范与质量基线
- **Task-004**: 构建与 CI 基线

## 参考资料

- [Git Flow](https://nvie.com/posts/a-successful-git-branching-model/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Keep a Changelog](https://keepachangelog.com/)
- [Semantic Versioning](https://semver.org/)
- [GitHub Flow](https://guides.github.com/introduction/flow/)

## 变更记录

| 日期 | 版本 | 变更内容 | 作者 |
|------|------|---------|------|
| 2025-10-23 | v1.0 | 初始版本 | AI Agent |
