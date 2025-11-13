# Task-103 PR2 实施指南：Xcode Framework 方案

**版本**: v1.1  
**日期**: 2025-11-13  
**状态**: ✅ 已完成构建  
**方案**: ADR-0007 方案 A - 使用 Xcode Framework Target

> **🎉 重要发现**: whisper.cpp 官方已提供 `build-xcframework.sh` 脚本！  
> 可直接使用官方脚本构建，无需手动创建 Xcode 项目。

---

## 目录

- [0. 快速开始（推荐）](#0-快速开始推荐)
- [1. 概述](#1-概述)
- [2. 前置准备](#2-前置准备)
- [3. 实施步骤](#3-实施步骤)
- [4. 验证测试](#4-验证测试)
- [5. 注意事项](#5-注意事项)
- [6. 故障排查](#6-故障排查)

---

## 0. 快速开始（推荐）

### 方案选择

| 方案 | 优点 | 缺点 | 推荐度 |
|------|------|------|--------|
| **方案 A: 官方脚本** | ✅ 一键构建<br>✅ 官方维护<br>✅ 自动更新 | ❌ 黑盒构建<br>❌ 定制困难 | ⭐⭐⭐⭐⭐ |
| **方案 B: 自建项目** | ✅ 完全可控<br>✅ 易于调试<br>✅ 深度定制 | ❌ 维护成本高<br>❌ 初期复杂 | ⭐⭐⭐ |

### 🚀 方案 A: 使用官方脚本（推荐）

```bash
cd /Users/jiang/Projects/prism-player/Prism-xOS/packages/PrismASR/external/whisper.cpp

# 1. 执行官方构建脚本
./build-xcframework.sh

# 2. 等待构建完成（约 5-10 分钟）
# 构建产物位于: build-apple/whisper.xcframework

# 3. 复制到项目目录
cp -R build-apple/whisper.xcframework ../../CWhisper.xcframework

# 4. 验证产物
ls -lh ../../CWhisper.xcframework
```

**优点**:
- ✅ **零配置** - 无需创建 Xcode 项目
- ✅ **官方维护** - 跟随 whisper.cpp 更新
- ✅ **完整支持** - 包含所有平台和架构
- ✅ **构建优化** - 官方调优的编译选项

**注意事项**:
- ⚠️ 构建时间较长（首次 5-10 分钟）
- ⚠️ 需要 Xcode 命令行工具完整安装
- ⚠️ 产物约 50-100MB

### 📝 方案 B: 自建 Xcode 项目（学习用）

如果你想深入了解 XCFramework 构建过程，或需要定制编译选项，请继续阅读后续章节。

---

## 1. 概述

### 1.1 目标

创建 `CWhisper.xcframework`，封装 whisper.cpp C/C++ 代码，供 Swift Package `PrismASR` 使用。

### 1.2 架构图

```
packages/PrismASR/
├── CWhisper/                           # 🆕 Xcode 项目（Framework）
│   ├── CWhisper.xcodeproj             # Xcode 项目文件
│   ├── CWhisper/                       # Framework 源码
│   │   ├── CWhisper.h                 # Umbrella header
│   │   ├── Info.plist
│   │   └── whisper.cpp -> ../external/whisper.cpp  # 符号链接
│   ├── Build/                          # 构建产物
│   │   └── CWhisper.xcframework       # 最终产物
│   └── Scripts/
│       └── build-xcframework.sh       # 构建脚本
├── Package.swift                       # Swift Package（依赖 xcframework）
├── Sources/PrismASR/                   # Swift 代码
└── external/whisper.cpp/               # whisper.cpp 源码（已存在）
```

### 1.3 关键决策

| 决策点 | 选择 | 理由 |
|--------|------|------|
| **构建方式** | XCFramework | 支持 iOS/macOS/Simulator 统一封装 |
| **依赖管理** | Binary Target | SPM 原生支持，无需额外配置 |
| **符号链接** | 是 | 避免复制源码，便于更新 |
| **构建脚本** | Shell | 自动化多架构编译 |

---

## 2. 前置准备

### 2.1 环境要求

```bash
# 检查 Xcode 版本
xcodebuild -version
# 需要：Xcode 15.0+

# 检查命令行工具
xcode-select -p
# 输出：/Applications/Xcode.app/Contents/Developer

# 检查 Swift 版本
swift --version
# 需要：Swift 5.9+
```

### 2.2 清理旧方案

```bash
cd /Users/jiang/Projects/prism-player/Prism-xOS/packages/PrismASR

# 1. 备份当前实现（可选）
git stash push -m "backup: PR2 SPM attempt"

# 2. 删除 SPM C/C++ target 相关文件
rm -rf Sources/CWhisper/

# 3. 确认 whisper.cpp submodule 存在
ls -la external/whisper.cpp/
# 应该看到源码文件

# 4. 确认 git submodule 状态
cd external/whisper.cpp && git status
cd ../..
```

### 2.3 创建工作目录

```bash
# 在 PrismASR 包下创建 CWhisper 目录
mkdir -p CWhisper/CWhisper
mkdir -p CWhisper/Scripts
mkdir -p CWhisper/Build

# 创建符号链接（指向 whisper.cpp 源码）
cd CWhisper/CWhisper
ln -s ../../external/whisper.cpp whisper.cpp
ls -la  # 验证符号链接
```

---

## 3. 实施步骤

### 步骤 1: 创建 Xcode Framework 项目

#### 1.1 使用 Xcode 创建项目

```bash
# 打开 Xcode
open /Applications/Xcode.app

# 步骤：
# 1. File > New > Project
# 2. 选择 iOS > Framework
# 3. Product Name: CWhisper
# 4. Organization: com.prismplayer
# 5. Language: Objective-C (重要！支持 C/C++ 混编)
# 6. 保存位置: packages/PrismASR/CWhisper/
```

**关键配置**：
- ✅ Framework 类型（不是 Static Library）
- ✅ 语言选择 Objective-C（而非 Swift）
- ✅ 不勾选 "Include Tests"（稍后手动添加）

#### 1.2 配置项目结构

```
CWhisper.xcodeproj
├── CWhisper/
│   ├── CWhisper.h              # Umbrella header（自动生成）
│   ├── Info.plist              # Framework metadata
│   └── whisper.cpp/            # 符号链接（已创建）
└── CWhisper.xcodeproj/
    └── project.pbxproj         # Xcode 项目配置
```

---

### 步骤 2: 添加 whisper.cpp 源文件到项目

#### 2.1 添加源文件

在 Xcode 中：

```
1. 右键点击 CWhisper group
2. Add Files to "CWhisper"...
3. 导航到 whisper.cpp 符号链接
4. 选择以下文件：
   - src/whisper.cpp
   - ggml/src/ggml.c
   - ggml/src/ggml.cpp
   - ggml/src/gguf.cpp
   - ggml/src/ggml-alloc.c
   - ggml/src/ggml-backend.cpp
   - ggml/src/ggml-backend-reg.cpp
   - ggml/src/ggml-quants.c
   - ggml/src/ggml-threading.cpp
   - ggml/src/ggml-metal/ggml-metal.cpp

5. ⚠️ 重要选项：
   - ✅ Copy items if needed: 不勾选（使用符号链接）
   - ✅ Create groups
   - ✅ Add to targets: CWhisper
```

#### 2.2 添加 Metal Shader 资源

```
1. 右键点击 CWhisper group
2. Add Files to "CWhisper"...
3. 选择文件：
   - ggml/src/ggml-metal/ggml-metal.metal

4. 选项：
   - ✅ Copy items if needed: 不勾选
   - ✅ Add to targets: CWhisper (确保在 Bundle Resources 中)
```

**验证**：
- 在 Build Phases > Copy Bundle Resources 中应该看到 `ggml-metal.metal`

---

### 步骤 3: 配置 Build Settings

#### 3.1 打开 Build Settings

```
1. 选择 CWhisper target
2. 点击 Build Settings 标签
3. 切换到 "All" 和 "Combined" 视图
```

#### 3.2 配置搜索路径

**Header Search Paths** (`HEADER_SEARCH_PATHS`):

```
$(PROJECT_DIR)/whisper.cpp/include
$(PROJECT_DIR)/whisper.cpp/src
$(PROJECT_DIR)/whisper.cpp/ggml/include
$(PROJECT_DIR)/whisper.cpp/ggml/src
$(PROJECT_DIR)/whisper.cpp/ggml/src/ggml-metal
```

**设置方式**：
1. 搜索 "Header Search Paths"
2. 双击右侧值区域
3. 点击 `+` 添加每一行
4. 确保设置为 `recursive`（可选）

#### 3.3 配置预处理器宏

**Preprocessor Macros** (`GCC_PREPROCESSOR_DEFINITIONS`):

```
Debug 配置:
  GGML_USE_METAL=1
  GGML_USE_ACCELERATE=1
  GGML_METAL_NDEBUG=1
  GGML_VERSION=\"master\"
  GGML_COMMIT=\"unknown\"
  WHISPER_VERSION=\"master\"
  DEBUG=1

Release 配置:
  GGML_USE_METAL=1
  GGML_USE_ACCELERATE=1
  GGML_METAL_NDEBUG=1
  GGML_VERSION=\"master\"
  GGML_COMMIT=\"unknown\"
  WHISPER_VERSION=\"master\"
```

#### 3.4 配置 C++ 标准

**C++ Language Dialect** (`CLANG_CXX_LANGUAGE_STANDARD`):
```
GNU++17 [-std=gnu++17]
```

**C Language Dialect** (`GCC_C_LANGUAGE_STANDARD`):
```
GNU11 [-std=gnu11]
```

#### 3.5 禁用不必要的警告（可选）

**Other C Flags** (`OTHER_CFLAGS`):
```
-Wno-shorten-64-to-32
-Wno-unused-function
```

**Other C++ Flags** (`OTHER_CPLUSPLUSFLAGS`):
```
-Wno-shorten-64-to-32
-Wno-unused-function
```

#### 3.6 配置架构支持

**Supported Platforms**:
```
iOS
macOS
```

**Architectures** (自动检测):
```
iOS: arm64 (真机), arm64 + x86_64 (模拟器)
macOS: arm64 + x86_64 (Universal)
```

---

### 步骤 4: 链接系统框架

#### 4.1 添加 Frameworks

```
1. 选择 CWhisper target
2. Build Phases 标签
3. Link Binary With Libraries
4. 点击 `+` 添加以下框架：
   - Metal.framework
   - MetalKit.framework
   - Accelerate.framework
   - Foundation.framework
```

#### 4.2 验证链接

在 Build Phases > Link Binary With Libraries 中应该看到：

```
Metal.framework           Required
MetalKit.framework        Required
Accelerate.framework      Required
Foundation.framework      Required
```

---

### 步骤 5: 配置公共头文件

#### 5.1 编辑 CWhisper.h (Umbrella Header)

打开 `CWhisper/CWhisper.h`，替换为：

```objc
//
//  CWhisper.h
//  CWhisper
//
//  Created by Prism Player Team on 2025-11-12.
//

#import <Foundation/Foundation.h>

//! Project version number for CWhisper.
FOUNDATION_EXPORT double CWhisperVersionNumber;

//! Project version string for CWhisper.
FOUNDATION_EXPORT const unsigned char CWhisperVersionString[];

// Public headers
#import "whisper.cpp/include/whisper.h"
#import "whisper.cpp/ggml/include/ggml.h"
```

#### 5.2 设置头文件为 Public

```
1. 选择 CWhisper target
2. Build Phases > Headers
3. 将 CWhisper.h 拖动到 Public 区域
4. 确认 whisper.h 和 ggml.h 不在此列表（通过 umbrella header 引用）
```

---

### 步骤 6: 添加额外的 Target（macOS）

#### 6.1 创建 macOS Target

```
1. File > New > Target
2. 选择 macOS > Framework
3. Product Name: CWhisper-macOS
4. 复制 iOS target 的所有 Build Settings
```

**或者**更简单的方式：

```
1. 选择 CWhisper target
2. Editor > Add Target
3. 选择 macOS
```

#### 6.2 同步配置

确保 macOS target 的 Build Settings 与 iOS 完全一致（搜索路径、宏定义等）。

---

### 步骤 7: 编译单架构验证

#### 7.1 编译 iOS (arm64 真机)

```bash
cd CWhisper

xcodebuild \
  -project CWhisper.xcodeproj \
  -scheme CWhisper \
  -configuration Debug \
  -sdk iphoneos \
  -arch arm64 \
  build
```

**预期输出**：
```
BUILD SUCCEEDED
```

#### 7.2 编译 iOS Simulator (arm64 + x86_64)

```bash
xcodebuild \
  -project CWhisper.xcodeproj \
  -scheme CWhisper \
  -configuration Debug \
  -sdk iphonesimulator \
  -arch "arm64 x86_64" \
  build
```

#### 7.3 编译 macOS (Universal)

```bash
xcodebuild \
  -project CWhisper.xcodeproj \
  -scheme CWhisper-macOS \
  -configuration Debug \
  -sdk macosx \
  -arch "arm64 x86_64" \
  build
```

#### 7.4 检查构建产物

```bash
# iOS 真机
ls -lh ~/Library/Developer/Xcode/DerivedData/CWhisper-*/Build/Products/Debug-iphoneos/CWhisper.framework

# iOS 模拟器
ls -lh ~/Library/Developer/Xcode/DerivedData/CWhisper-*/Build/Products/Debug-iphonesimulator/CWhisper.framework

# macOS
ls -lh ~/Library/Developer/Xcode/DerivedData/CWhisper-*/Build/Products/Debug/CWhisper.framework
```

---

### 步骤 8: 创建 XCFramework 构建脚本

#### 8.1 创建构建脚本

创建文件 `CWhisper/Scripts/build-xcframework.sh`:

```bash
#!/bin/bash
set -e

# 配置
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
XCODEPROJ="$PROJECT_DIR/CWhisper.xcodeproj"
SCHEME="CWhisper"
SCHEME_MACOS="CWhisper-macOS"
BUILD_DIR="$PROJECT_DIR/Build"
XCFRAMEWORK="$BUILD_DIR/CWhisper.xcframework"

# 清理旧的构建产物
echo "🧹 清理旧的构建产物..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# 临时构建目录
DERIVED_DATA="$BUILD_DIR/DerivedData"

# 构建配置
CONFIGURATION="Release"

echo "🔨 开始构建 CWhisper.xcframework..."

# 1. 构建 iOS 真机 (arm64)
echo "📱 构建 iOS 真机 (arm64)..."
xcodebuild archive \
  -project "$XCODEPROJ" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -sdk iphoneos \
  -archivePath "$BUILD_DIR/ios.xcarchive" \
  -derivedDataPath "$DERIVED_DATA" \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES

# 2. 构建 iOS 模拟器 (arm64 + x86_64)
echo "📱 构建 iOS 模拟器 (arm64 + x86_64)..."
xcodebuild archive \
  -project "$XCODEPROJ" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -sdk iphonesimulator \
  -archivePath "$BUILD_DIR/ios-simulator.xcarchive" \
  -derivedDataPath "$DERIVED_DATA" \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES

# 3. 构建 macOS (arm64 + x86_64 Universal)
echo "💻 构建 macOS (Universal)..."
xcodebuild archive \
  -project "$XCODEPROJ" \
  -scheme "$SCHEME_MACOS" \
  -configuration "$CONFIGURATION" \
  -sdk macosx \
  -archivePath "$BUILD_DIR/macos.xcarchive" \
  -derivedDataPath "$DERIVED_DATA" \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES

# 4. 创建 XCFramework
echo "📦 创建 XCFramework..."
xcodebuild -create-xcframework \
  -framework "$BUILD_DIR/ios.xcarchive/Products/Library/Frameworks/CWhisper.framework" \
  -framework "$BUILD_DIR/ios-simulator.xcarchive/Products/Library/Frameworks/CWhisper.framework" \
  -framework "$BUILD_DIR/macos.xcarchive/Products/Library/Frameworks/CWhisper.framework" \
  -output "$XCFRAMEWORK"

# 5. 清理临时文件
echo "🧹 清理临时文件..."
rm -rf "$BUILD_DIR"/*.xcarchive
rm -rf "$DERIVED_DATA"

# 6. 验证产物
echo "✅ 验证构建产物..."
if [ -d "$XCFRAMEWORK" ]; then
    echo "📦 XCFramework 创建成功！"
    echo "📍 位置: $XCFRAMEWORK"
    
    # 显示架构信息
    echo ""
    echo "📊 架构信息："
    find "$XCFRAMEWORK" -name "CWhisper" -type f -exec file {} \;
    
    # 显示大小
    echo ""
    echo "📏 文件大小："
    du -sh "$XCFRAMEWORK"
else
    echo "❌ XCFramework 创建失败！"
    exit 1
fi

echo ""
echo "🎉 构建完成！"
```

#### 8.2 设置执行权限

```bash
chmod +x CWhisper/Scripts/build-xcframework.sh
```

#### 8.3 执行构建

```bash
cd CWhisper
./Scripts/build-xcframework.sh
```

**预期输出**：
```
🧹 清理旧的构建产物...
🔨 开始构建 CWhisper.xcframework...
📱 构建 iOS 真机 (arm64)...
📱 构建 iOS 模拟器 (arm64 + x86_64)...
💻 构建 macOS (Universal)...
📦 创建 XCFramework...
🧹 清理临时文件...
✅ 验证构建产物...
📦 XCFramework 创建成功！
📍 位置: /path/to/Build/CWhisper.xcframework
📊 架构信息：
...
📏 文件大小：
XX.XM Build/CWhisper.xcframework
🎉 构建完成！
```

---

### 步骤 9: 更新 Package.swift

#### 9.1 修改 PrismASR Package.swift

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PrismASR",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PrismASR",
            targets: ["PrismASR"]
        )
    ],
    dependencies: [
        .package(path: "../PrismCore")
    ],
    targets: [
        // 🆕 Binary target for CWhisper.xcframework
        .binaryTarget(
            name: "CWhisper",
            path: "CWhisper/Build/CWhisper.xcframework"
        ),
        
        // Swift target
        .target(
            name: "PrismASR",
            dependencies: [
                "CWhisper",
                .product(name: "PrismCore", package: "PrismCore")
            ],
            path: "Sources/PrismASR"
        ),
        
        // Tests
        .testTarget(
            name: "PrismASRTests",
            dependencies: ["PrismASR"],
            path: "Tests/PrismASRTests"
        )
    ]
)
```

#### 9.2 更新 WhisperContext.swift

```swift
import CWhisper  // 现在从 xcframework 导入
import Foundation
import OSLog

public actor WhisperContext {
    private var context: OpaquePointer?
    // ... 其余代码保持不变
    
    public func loadModel(at modelPath: URL) async throws {
        let cPath = modelPath.path.cString(using: .utf8)!
        
        // 直接使用 whisper.cpp 的 C API
        guard let ctx = whisper_init_from_file(cPath) else {
            throw AsrError.modelLoadFailed(modelPath)
        }
        
        self.context = ctx
        // ...
    }
}
```

---

### 步骤 10: 验证 Swift Package 集成

#### 10.1 清理并构建

```bash
cd /Users/jiang/Projects/prism-player/Prism-xOS/packages/PrismASR

# 清理 SPM 缓存
rm -rf .build
rm Package.resolved

# 构建
swift build -c debug
```

**预期输出**：
```
Building for debugging...
[1/2] Compiling CWhisper ...
[2/2] Emitting module PrismASR
Build complete!
```

#### 10.2 运行测试

```bash
swift test
```

---

## 4. 验证测试

### 4.1 单元测试验证

```bash
# 运行所有测试
swift test

# 运行特定测试
swift test --filter WhisperContextTests
```

### 4.2 架构验证

```bash
# 检查 xcframework 支持的平台和架构
xcodebuild -project CWhisper/CWhisper.xcodeproj \
  -list

# 验证符号导出
nm CWhisper/Build/CWhisper.xcframework/ios-arm64/CWhisper.framework/CWhisper | grep whisper_init
```

### 4.3 真机测试

1. 在 Xcode 中打开主应用项目
2. 选择真机设备（iPhone/Mac）
3. 运行 PrismPlayer App
4. 测试 ASR 功能

---

## 5. 注意事项

### 5.1 ⚠️ 重要约束

| 约束项 | 说明 | 影响 |
|--------|------|------|
| **符号链接** | 不要 "Copy items if needed" | 避免源码重复，便于更新 |
| **Framework 类型** | 必须是 Framework，不是 Static Library | Swift Package 只支持 Framework |
| **架构支持** | 必须构建所有架构 | iOS 真机/模拟器 + macOS Universal |
| **头文件可见性** | Umbrella header 必须为 Public | Swift 才能访问 C API |
| **Metal shader** | 必须在 Bundle Resources 中 | 运行时加载 Metal 代码 |

### 5.2 🎯 最佳实践

#### 5.2.1 版本管理

```bash
# .gitignore 添加
CWhisper/Build/
CWhisper/DerivedData/
*.xcuserdata
*.xcworkspace/xcuserdata/

# 提交 xcframework 到仓库（可选）
# 如果团队成员不想每次都构建，可以提交二进制文件
git add CWhisper/Build/CWhisper.xcframework
```

#### 5.2.2 CI/CD 集成

在 `.github/workflows/build.yml` 中添加：

```yaml
- name: Build CWhisper XCFramework
  run: |
    cd Prism-xOS/packages/PrismASR/CWhisper
    ./Scripts/build-xcframework.sh
    
- name: Build PrismASR Package
  run: |
    cd Prism-xOS/packages/PrismASR
    swift build -c release
```

#### 5.2.3 更新 whisper.cpp

```bash
# 更新 submodule
cd external/whisper.cpp
git pull origin master
cd ../..

# 重新构建 xcframework
cd CWhisper
./Scripts/build-xcframework.sh
```

### 5.3 🔧 调试技巧

#### 5.3.1 查看构建日志

```bash
# 详细构建日志
xcodebuild ... | tee build.log

# 查看错误
grep -i "error:" build.log
```

#### 5.3.2 检查符号导出

```bash
# 列出所有导出的符号
nm -gU CWhisper/Build/CWhisper.xcframework/ios-arm64/CWhisper.framework/CWhisper

# 搜索特定符号
nm -gU ... | grep whisper
```

#### 5.3.3 断点调试 C/C++ 代码

1. 在 Xcode 中打开主应用项目
2. File > Add Files > 添加 `CWhisper.xcodeproj`
3. 在 whisper.cpp 源码中设置断点
4. 运行 App，断点会命中

---

## 6. 故障排查

### 6.1 常见错误

#### 错误 1: "ggml.h file not found"

**原因**：Header Search Paths 配置错误

**解决**：
```
1. 检查 Build Settings > Header Search Paths
2. 确保包含 whisper.cpp/ggml/include
3. 路径使用 $(PROJECT_DIR) 相对路径
```

#### 错误 2: "Undefined symbol: _whisper_init_from_file"

**原因**：源文件未添加到 target

**解决**：
```
1. 检查 Build Phases > Compile Sources
2. 确保 whisper.cpp 和 ggml.c 在列表中
3. 重新添加文件到 target
```

#### 错误 3: "Metal shader not found"

**原因**：ggml-metal.metal 未添加到 Bundle Resources

**解决**：
```
1. 检查 Build Phases > Copy Bundle Resources
2. 添加 ggml-metal.metal 文件
```

#### 错误 4: 编译时间过长

**原因**：编译 whisper.cpp 较慢

**优化**：
```
1. Build Settings > Optimization Level > -O2 (Release)
2. Build Settings > Compilation Mode > Whole Module
3. 使用预编译头文件（可选）
```

#### 错误 5: 符号链接失效

**原因**：移动了项目目录

**解决**：
```bash
cd CWhisper/CWhisper
rm whisper.cpp
ln -s ../../external/whisper.cpp whisper.cpp
```

### 6.2 性能问题

#### 问题 1: 构建时间过长（> 5 分钟）

**排查**：
```bash
# 查看编译时间分布
xcodebuild ... -showBuildTimingSummary
```

**优化**：
- 使用增量构建
- 只构建需要的架构
- 启用并行编译

#### 问题 2: XCFramework 文件过大（> 100MB）

**原因**：包含调试符号

**优化**：
```
Build Settings > Debug Information Format > DWARF
Build Settings > Strip Debug Symbols During Copy > YES (Release)
```

---

## 附录 A: 完整的 Build Settings 清单

### A.1 通用设置

| 设置项 | 值 | 说明 |
|--------|-------|------|
| `PRODUCT_NAME` | CWhisper | Framework 名称 |
| `PRODUCT_BUNDLE_IDENTIFIER` | com.prismplayer.CWhisper | Bundle ID |
| `DYLIB_COMPATIBILITY_VERSION` | 1 | 兼容性版本 |
| `DYLIB_CURRENT_VERSION` | 1 | 当前版本 |
| `DEFINES_MODULE` | YES | 支持模块化 |
| `SKIP_INSTALL` | NO | Archive 时包含 |
| `BUILD_LIBRARY_FOR_DISTRIBUTION` | YES | 支持 XCFramework |

### A.2 搜索路径

```
HEADER_SEARCH_PATHS:
  $(PROJECT_DIR)/whisper.cpp/include
  $(PROJECT_DIR)/whisper.cpp/src
  $(PROJECT_DIR)/whisper.cpp/ggml/include
  $(PROJECT_DIR)/whisper.cpp/ggml/src
  $(PROJECT_DIR)/whisper.cpp/ggml/src/ggml-metal

FRAMEWORK_SEARCH_PATHS:
  $(inherited)
  
LIBRARY_SEARCH_PATHS:
  $(inherited)
```

### A.3 编译选项

```
GCC_PREPROCESSOR_DEFINITIONS:
  GGML_USE_METAL=1
  GGML_USE_ACCELERATE=1
  GGML_METAL_NDEBUG=1
  GGML_VERSION=\"master\"
  GGML_COMMIT=\"unknown\"
  WHISPER_VERSION=\"master\"

CLANG_CXX_LANGUAGE_STANDARD:
  gnu++17

GCC_C_LANGUAGE_STANDARD:
  gnu11

OTHER_CFLAGS:
  -Wno-shorten-64-to-32
  -Wno-unused-function

OTHER_CPLUSPLUSFLAGS:
  $(OTHER_CFLAGS)
```

### A.4 链接选项

```
OTHER_LDFLAGS:
  -framework Metal
  -framework MetalKit
  -framework Accelerate
  -framework Foundation
```

---

## 附录 B: 构建脚本变体

### B.1 仅构建 iOS

```bash
#!/bin/bash
# build-ios-only.sh

xcodebuild archive \
  -project CWhisper.xcodeproj \
  -scheme CWhisper \
  -configuration Release \
  -sdk iphoneos \
  -archivePath Build/ios.xcarchive

xcodebuild -create-xcframework \
  -framework Build/ios.xcarchive/Products/Library/Frameworks/CWhisper.framework \
  -output Build/CWhisper.xcframework
```

### B.2 快速迭代（Debug 模式）

```bash
#!/bin/bash
# quick-build.sh

xcodebuild \
  -project CWhisper.xcodeproj \
  -scheme CWhisper \
  -configuration Debug \
  -sdk iphonesimulator \
  -arch arm64
```

---

## 附录 C: 相关资源

### C.1 官方文档

- [Creating a Swift Package with XCFramework](https://developer.apple.com/documentation/xcode/creating-a-multi-platform-binary-framework-bundle)
- [Distributing Binary Frameworks as Swift Packages](https://developer.apple.com/documentation/xcode/distributing-binary-frameworks-as-swift-packages)
- [whisper.cpp GitHub](https://github.com/ggerganov/whisper.cpp)
- [whisper.cpp build-xcframework.sh](https://github.com/ggerganov/whisper.cpp/blob/master/build-xcframework.sh)

### C.2 项目文档

- [ADR-0007: Whisper.cpp 集成策略](../../1_design/architecture/adr/iOS-macOS/0007-whisper-cpp-integration-strategy.md)
- [Task-103 详细设计](./task-103-asr-engine-protocol-whisper-backend.md)
- [HLD §6 ASR 引擎集成](../../1_design/hld/iOS-macOS/hld-ios-macos-v0.2.md)

---

## 附录 D: 实战经验总结

### D.1 关键发现

#### ✅ 使用官方脚本的优势

**发现**: whisper.cpp 官方提供 `build-xcframework.sh`，位于仓库根目录。

**构建命令**:
```bash
cd external/whisper.cpp
./build-xcframework.sh
# 产物: build-apple/whisper.xcframework
```

**优势**:
1. **零配置** - 无需创建 Xcode 项目
2. **官方维护** - 跟随上游更新
3. **完整支持** - 自动包含所有必要的源文件和配置
4. **平台覆盖** - iOS/macOS/Simulator 全架构支持

**集成步骤**:
```bash
# 1. 构建 xcframework
cd Prism-xOS/packages/PrismASR/external/whisper.cpp
./build-xcframework.sh

# 2. 复制到项目
cp -R build-apple/whisper.xcframework ../../CWhisper.xcframework

# 3. 更新 Package.swift
# 使用 .binaryTarget(path: "CWhisper.xcframework")
```

#### ⚠️ Xcode 16+ 文件添加变化

**问题**: Xcode 16.4 移除了 "Create folder references" 选项。

**解决方案**:
1. **方案 1**: 使用 "Create groups" 并手动管理文件
2. **方案 2**: 使用 Finder 拖拽 + Option 键
3. **方案 3**: 手动创建 groups 后逐个添加文件（最可控）

**推荐**: 直接使用官方脚本，避免手动管理源文件。

#### 🔧 Objective-C ARC 问题

**问题**: `ggml-metal-device.m` 等文件编译报错：
```
Implicit conversion of C pointer type 'void *' to Objective-C pointer type 'id<MTLDevice>' 
requires a bridged cast
```

**原因**: Xcode 默认启用 ARC，但 whisper.cpp 的 Objective-C 代码不兼容 ARC。

**解决**: 对所有 `.m` 文件禁用 ARC
```
Build Phases → Compile Sources → Compiler Flags: -fno-objc-arc

需要添加的文件:
✓ ggml-metal-device.m      → -fno-objc-arc
✓ ggml-metal-context.m     → -fno-objc-arc
```

**原理**: ARC 要求显式的桥接转换 (`__bridge`)，而 C/C++ 混编代码通常直接转换指针。

#### 📋 必需的源文件清单

**C/C++ 源文件** (11 个):
```
whisper.cpp/src/whisper.cpp
whisper.cpp/ggml/src/ggml.c
whisper.cpp/ggml/src/ggml.cpp
whisper.cpp/ggml/src/gguf.cpp
whisper.cpp/ggml/src/ggml-alloc.c
whisper.cpp/ggml/src/ggml-backend.cpp
whisper.cpp/ggml/src/ggml-backend-reg.cpp
whisper.cpp/ggml/src/ggml-quants.c
whisper.cpp/ggml/src/ggml-threading.cpp
whisper.cpp/ggml/src/ggml-metal/ggml-metal.cpp
```

**Objective-C 源文件** (2 个，关键！):
```
whisper.cpp/ggml/src/ggml-metal/ggml-metal-device.m    ← 实现 Metal 设备管理
whisper.cpp/ggml/src/ggml-metal/ggml-metal-context.m   ← 实现 Metal 上下文
```

**资源文件** (1 个):
```
whisper.cpp/ggml/src/ggml-metal/ggml-metal.metal       ← Metal shader
```

**常见错误**: 
- ❌ 忘记添加 `.m` 文件 → 链接错误 "Undefined symbols"
- ❌ 忘记禁用 ARC → 编译错误 "requires a bridged cast"
- ❌ 忘记添加 `.metal` 文件到 Bundle Resources → 运行时错误

### D.2 构建时间优化

| 方案 | 首次构建 | 增量构建 | 产物大小 |
|------|---------|---------|---------|
| 官方脚本 | 5-10 分钟 | N/A | ~60MB |
| Xcode 项目 Debug | 3-5 分钟 | 30-60 秒 | ~80MB (含符号) |
| Xcode 项目 Release | 8-12 分钟 | 1-2 分钟 | ~50MB |

**优化建议**:
- 开发阶段使用 Debug 配置（快速迭代）
- 提交前使用 Release 配置（体积优化）
- CI/CD 使用官方脚本（稳定性）

### D.3 决策建议

| 场景 | 推荐方案 | 理由 |
|------|---------|------|
| **快速验证** | 官方脚本 | 一键构建，快速集成 |
| **生产部署** | 官方脚本 | 官方维护，稳定可靠 |
| **深度定制** | Xcode 项目 | 完全控制编译选项 |
| **学习研究** | Xcode 项目 | 理解构建过程 |
| **CI/CD** | 官方脚本 | 可重复构建 |

**最终建议**: 
- ✅ **首选官方脚本**（方案 A）
- 📚 **保留本文档**作为 XCFramework 构建的学习资料
- 🔧 需要定制时再考虑自建项目（方案 B）

---

## 变更记录

| 版本 | 日期 | 变更内容 | 作者 |
|------|------|---------|------|
| v1.0 | 2025-11-12 | 初始版本，完整实施指南 | Team |
| v1.1 | 2025-11-13 | ✅ 添加官方脚本方案<br>✅ 添加实战经验总结<br>✅ 补充 ARC 问题解决<br>✅ 完善源文件清单 | Team |

---

## 下一步行动

### ✅ 已完成
- [x] whisper.cpp submodule 集成
- [x] XCFramework 构建方案验证
- [x] 编译通过（Xcode 项目方式）
- [x] 实施文档编写

### 🚀 待执行

#### 方案选择
**推荐使用官方脚本**:
```bash
# 切换到官方脚本方案
cd Prism-xOS/packages/PrismASR/external/whisper.cpp
./build-xcframework.sh

# 集成到项目
cp -R build-apple/whisper.xcframework ../../CWhisper.xcframework
```

#### 后续任务
1. **更新 Package.swift** - 配置 binary target
2. **验证 Swift 集成** - `swift build` 测试
3. **实现 transcribe()** - Task-103 PR3
4. **单元测试** - 验证 WhisperContext 功能
5. **性能测试** - 实际音频转录
