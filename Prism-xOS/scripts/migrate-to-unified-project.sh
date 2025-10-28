#!/bin/bash
# migrate-to-unified-project.sh
# 迁移脚本：合并 PrismPlayer-iOS 和 PrismPlayer-macOS 为单工程双 Target
#
# 用途：实现 ADR-0006（统一 App 工程结构）
# 日期：2025-10-28
# 作者：Prism Player Team
#
# 使用方法：
#   cd Prism-xOS
#   ./scripts/migrate-to-unified-project.sh
#
# 注意：
#   1. 执行前请确保 git 工作区干净（git status）
#   2. 建议在新分支执行：git checkout -b feature/unified-project
#   3. 脚本会创建备份：apps/.backup-{timestamp}/

set -e  # 遇到错误立即退出
set -u  # 使用未定义变量时报错

# ============================================================================
# 配置变量
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APPS_DIR="$PROJECT_ROOT/apps"
BACKUP_DIR="$APPS_DIR/.backup-$(date +%Y%m%d_%H%M%S)"

IOS_PROJECT="$APPS_DIR/PrismPlayer-iOS"
MACOS_PROJECT="$APPS_DIR/PrismPlayer-macOS"
UNIFIED_PROJECT="$APPS_DIR/PrismPlayer"

WORKSPACE="$PROJECT_ROOT/PrismPlayer.xcworkspace"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# 辅助函数
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "检查前置条件..."
    
    # 检查是否在正确目录
    if [ ! -d "$APPS_DIR" ]; then
        log_error "未找到 apps/ 目录，请在 Prism-xOS 目录下执行此脚本"
        exit 1
    fi
    
    # 检查原工程是否存在
    if [ ! -d "$IOS_PROJECT" ]; then
        log_error "未找到 $IOS_PROJECT"
        exit 1
    fi
    
    if [ ! -d "$MACOS_PROJECT" ]; then
        log_error "未找到 $MACOS_PROJECT"
        exit 1
    fi
    
    # 检查 git 状态
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        log_warning "Git 工作区不干净，建议先提交或暂存当前更改"
        read -p "是否继续？(y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "迁移已取消"
            exit 0
        fi
    fi
    
    # 检查目标目录是否已存在
    if [ -d "$UNIFIED_PROJECT" ]; then
        log_error "目标目录已存在: $UNIFIED_PROJECT"
        log_error "请先删除或重命名该目录"
        exit 1
    fi
    
    log_success "前置条件检查通过"
}

create_backup() {
    log_info "创建备份到 $BACKUP_DIR ..."
    mkdir -p "$BACKUP_DIR"
    
    cp -R "$IOS_PROJECT" "$BACKUP_DIR/PrismPlayer-iOS"
    cp -R "$MACOS_PROJECT" "$BACKUP_DIR/PrismPlayer-macOS"
    
    log_success "备份完成"
}

create_unified_project_structure() {
    log_info "创建统一工程目录结构..."
    
    mkdir -p "$UNIFIED_PROJECT/Sources/iOS/Platform"
    mkdir -p "$UNIFIED_PROJECT/Sources/macOS/Platform"
    mkdir -p "$UNIFIED_PROJECT/Sources/Shared/Player"
    mkdir -p "$UNIFIED_PROJECT/Sources/Shared/Resources"
    mkdir -p "$UNIFIED_PROJECT/Sources/Tests/Shared"
    mkdir -p "$UNIFIED_PROJECT/Sources/Tests/Platform/iOS"
    mkdir -p "$UNIFIED_PROJECT/Sources/Tests/Platform/macOS"
    
    log_success "目录结构创建完成"
}

migrate_ios_files() {
    log_info "迁移 iOS 文件..."
    
    # 迁移 App 入口
    if [ -f "$IOS_PROJECT/Sources/PrismPlayerApp.swift" ]; then
        cp "$IOS_PROJECT/Sources/PrismPlayerApp.swift" "$UNIFIED_PROJECT/Sources/iOS/"
    fi
    
    # 迁移 Info.plist
    if [ -f "$IOS_PROJECT/Resources/Info.plist" ]; then
        mkdir -p "$UNIFIED_PROJECT/Sources/iOS"
        cp "$IOS_PROJECT/Resources/Info.plist" "$UNIFIED_PROJECT/Sources/iOS/"
    fi
    
    # 迁移其他 iOS 专用文件
    if [ -d "$IOS_PROJECT/Sources" ]; then
        # 排除可能共享的 ViewModel 等文件（后续手动处理）
        find "$IOS_PROJECT/Sources" -name "*.swift" -not -name "*ViewModel.swift" -not -name "ContentView.swift" | while read -r file; do
            filename=$(basename "$file")
            if [[ ! -f "$UNIFIED_PROJECT/Sources/iOS/$filename" ]]; then
                cp "$file" "$UNIFIED_PROJECT/Sources/iOS/"
            fi
        done
    fi
    
    log_success "iOS 文件迁移完成"
}

migrate_macos_files() {
    log_info "迁移 macOS 文件..."
    
    # 迁移 App 入口
    if [ -f "$MACOS_PROJECT/Sources/PrismPlayerApp.swift" ]; then
        cp "$MACOS_PROJECT/Sources/PrismPlayerApp.swift" "$UNIFIED_PROJECT/Sources/macOS/"
    fi
    
    # 迁移 Info.plist
    if [ -f "$MACOS_PROJECT/Resources/Info.plist" ]; then
        mkdir -p "$UNIFIED_PROJECT/Sources/macOS"
        cp "$MACOS_PROJECT/Resources/Info.plist" "$UNIFIED_PROJECT/Sources/macOS/"
    fi
    
    # 迁移 Entitlements
    if [ -f "$MACOS_PROJECT/PrismPlayer_macOS.entitlements" ]; then
        cp "$MACOS_PROJECT/PrismPlayer_macOS.entitlements" "$UNIFIED_PROJECT/Sources/macOS/"
    fi
    
    # 迁移其他 macOS 专用文件
    if [ -d "$MACOS_PROJECT/Sources" ]; then
        find "$MACOS_PROJECT/Sources" -name "*.swift" -not -name "*ViewModel.swift" -not -name "ContentView.swift" | while read -r file; do
            filename=$(basename "$file")
            if [[ ! -f "$UNIFIED_PROJECT/Sources/macOS/$filename" ]]; then
                cp "$file" "$UNIFIED_PROJECT/Sources/macOS/"
            fi
        done
    fi
    
    log_success "macOS 文件迁移完成"
}

create_xcode_project() {
    log_info "创建 Xcode 工程文件..."
    
    cat > "$UNIFIED_PROJECT/create-project.sh" << 'EOF'
#!/bin/bash
# 临时脚本：使用 Xcode 命令行工具创建工程
# 注意：实际需要在 Xcode 中手动创建 Multi-platform App 模板

echo "================================================"
echo "请在 Xcode 中手动完成以下步骤："
echo "================================================"
echo ""
echo "1. 打开 Xcode"
echo "2. File > New > Project"
echo "3. 选择 Multiplatform > App"
echo "4. Product Name: PrismPlayer"
echo "5. Organization Identifier: com.prismplayer"
echo "6. Interface: SwiftUI"
echo "7. Language: Swift"
echo "8. 保存到: $(pwd)"
echo ""
echo "9. 删除自动生成的示例文件："
echo "   - ContentView.swift"
echo "   - Assets.xcassets (保留 iOS/macOS 各自的)"
echo ""
echo "10. 配置 Target Membership："
echo "    - iOS/* → PrismPlayer-iOS target only"
echo "    - macOS/* → PrismPlayer-macOS target only"
echo "    - Shared/* → Both targets"
echo ""
echo "11. 添加 Swift Package 依赖："
echo "    - PrismCore"
echo "    - PrismASR"
echo "    - PrismKit"
echo ""
echo "================================================"
echo "完成后，删除此脚本文件"
echo "================================================"
EOF
    
    chmod +x "$UNIFIED_PROJECT/create-project.sh"
    
    log_warning "Xcode 工程需要手动创建（Multiplatform App 模板）"
    log_info "请执行: $UNIFIED_PROJECT/create-project.sh 查看详细步骤"
}

create_readme() {
    log_info "创建迁移说明文档..."
    
    cat > "$UNIFIED_PROJECT/MIGRATION.md" << 'EOF'
# 工程迁移说明

## 迁移概述

已将 `PrismPlayer-iOS` 和 `PrismPlayer-macOS` 两个独立工程合并为单工程双 Target 结构。

**参考文档**：ADR-0006: 统一 App 工程结构

## 目录结构

```
PrismPlayer/
├── PrismPlayer.xcodeproj         # 单工程（手动创建）
└── Sources/
    ├── iOS/                      # iOS 专用（Target: iOS only）
    │   ├── PrismPlayerApp.swift
    │   ├── Info.plist
    │   └── Platform/
    ├── macOS/                    # macOS 专用（Target: macOS only)
    │   ├── PrismPlayerApp.swift
    │   ├── Info.plist
    │   ├── PrismPlayer_macOS.entitlements
    │   └── Platform/
    ├── Shared/                   # 共享代码（Target: Both）
    │   ├── Player/
    │   └── Resources/
    └── Tests/
        ├── Shared/
        └── Platform/
```

## 手动步骤（必须完成）

### 1. 创建 Xcode 工程

在 Xcode 中创建 Multiplatform App：
- File > New > Project > Multiplatform > App
- Product Name: PrismPlayer
- Organization ID: com.prismplayer
- Interface: SwiftUI
- Language: Swift
- 保存到当前目录

### 2. 配置 Target Membership

选中文件/文件夹，在右侧 Inspector 中设置 Target Membership：
- `iOS/*` → ✅ PrismPlayer-iOS
- `macOS/*` → ✅ PrismPlayer-macOS  
- `Shared/*` → ✅ PrismPlayer-iOS + ✅ PrismPlayer-macOS

### 3. 添加 Swift Package 依赖

Project Settings > PrismPlayer > Package Dependencies > +
- 添加本地 Package：
  - `../../packages/PrismCore`
  - `../../packages/PrismASR`
  - `../../packages/PrismKit`

### 4. 配置 Build Settings

#### iOS Target
- Deployment Target: iOS 17.0
- Bundle ID: com.prismplayer.ios
- Info.plist: Sources/iOS/Info.plist

#### macOS Target
- Deployment Target: macOS 14.0
- Bundle ID: com.prismplayer.macos
- Info.plist: Sources/macOS/Info.plist
- Entitlements: Sources/macOS/PrismPlayer_macOS.entitlements

### 5. 更新 Workspace

编辑 `PrismPlayer.xcworkspace/contents.xcworkspacedata`:
- 移除旧工程引用（PrismPlayer-iOS.xcodeproj, PrismPlayer-macOS.xcodeproj）
- 添加新工程引用（PrismPlayer/PrismPlayer.xcodeproj）

### 6. 验证编译

```bash
# iOS
xcodebuild -workspace PrismPlayer.xcworkspace \
  -scheme PrismPlayer-iOS \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  clean build

# macOS
xcodebuild -workspace PrismPlayer.xcworkspace \
  -scheme PrismPlayer-macOS \
  -destination 'platform=macOS' \
  clean build
```

### 7. 删除旧工程

确认新工程编译通过后：
```bash
cd apps/
rm -rf PrismPlayer-iOS PrismPlayer-macOS
```

## 回滚步骤

如果迁移失败，可从备份恢复：
```bash
cd apps/
rm -rf PrismPlayer
cp -R .backup-{timestamp}/PrismPlayer-iOS .
cp -R .backup-{timestamp}/PrismPlayer-macOS .
```

## 后续任务

- [ ] 完成 Xcode 工程创建
- [ ] 配置 Target Membership
- [ ] 添加 Package 依赖
- [ ] 验证 iOS/macOS 编译
- [ ] 更新 CI/CD 脚本
- [ ] 删除旧工程
- [ ] 提交 Git 变更

## 参考资料

- ADR-0006: 统一 App 工程结构
- Task-101 v1.1: 媒体选择与播放
- Apple 文档: [Supporting Multiple Platforms](https://developer.apple.com/documentation/xcode/supporting-multiple-platforms-in-your-app)
EOF
    
    log_success "迁移说明文档创建完成: $UNIFIED_PROJECT/MIGRATION.md"
}

update_workspace() {
    log_info "准备 Workspace 更新说明..."
    
    cat > "$PROJECT_ROOT/UPDATE_WORKSPACE.md" << EOF
# Workspace 更新步骤

## 手动更新 Workspace 引用

编辑文件: \`PrismPlayer.xcworkspace/contents.xcworkspacedata\`

### 移除旧工程引用
删除以下行：
\`\`\`xml
<FileRef
   location = "group:apps/PrismPlayer-iOS/PrismPlayer-iOS.xcodeproj">
</FileRef>
<FileRef
   location = "group:apps/PrismPlayer-macOS/PrismPlayer-macOS.xcodeproj">
</FileRef>
\`\`\`

### 添加新工程引用
添加以下行：
\`\`\`xml
<FileRef
   location = "group:apps/PrismPlayer/PrismPlayer.xcodeproj">
</FileRef>
\`\`\`

## 验证

在 Xcode 中打开 Workspace，应该看到：
- ✅ PrismPlayer.xcodeproj（含 iOS/macOS 两个 Scheme）
- ✅ packages/PrismCore
- ✅ packages/PrismASR
- ✅ packages/PrismKit

## 删除此文件

完成后删除: \`rm UPDATE_WORKSPACE.md\`
EOF
    
    log_success "Workspace 更新说明创建完成: $PROJECT_ROOT/UPDATE_WORKSPACE.md"
}

print_summary() {
    echo ""
    echo "========================================================================"
    echo -e "${GREEN}迁移脚本执行完成！${NC}"
    echo "========================================================================"
    echo ""
    echo "📁 已创建目录结构: $UNIFIED_PROJECT"
    echo "📦 已备份原工程: $BACKUP_DIR"
    echo ""
    echo "⚠️  ${YELLOW}后续手动步骤（必须完成）：${NC}"
    echo ""
    echo "1️⃣  在 Xcode 中创建 Multiplatform App 工程"
    echo "    cd $UNIFIED_PROJECT"
    echo "    ./create-project.sh  # 查看详细步骤"
    echo ""
    echo "2️⃣  配置 Target Membership（iOS/macOS/Shared）"
    echo ""
    echo "3️⃣  添加 Swift Package 依赖（PrismCore/ASR/Kit）"
    echo ""
    echo "4️⃣  更新 Workspace 引用"
    echo "    cat $PROJECT_ROOT/UPDATE_WORKSPACE.md  # 查看步骤"
    echo ""
    echo "5️⃣  验证编译（iOS + macOS）"
    echo ""
    echo "6️⃣  删除旧工程"
    echo "    rm -rf apps/PrismPlayer-iOS apps/PrismPlayer-macOS"
    echo ""
    echo "📖 详细说明: $UNIFIED_PROJECT/MIGRATION.md"
    echo ""
    echo "========================================================================"
}

# ============================================================================
# 主流程
# ============================================================================

main() {
    log_info "开始迁移到统一工程结构（ADR-0006）..."
    echo ""
    
    check_prerequisites
    create_backup
    create_unified_project_structure
    migrate_ios_files
    migrate_macos_files
    create_xcode_project
    create_readme
    update_workspace
    
    print_summary
}

# 执行主流程
main
