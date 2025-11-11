# Task-103 PR2 实施记录

**日期**: 2025-11-11  
**任务**: whisper.cpp 集成与 C++ 桥接层  
**状态**: 进行中 - 遇到技术障碍

---

## 已完成的工作

### 1. whisper.cpp 源码集成 ✅
- 位置：`Prism-xOS/packages/PrismASR/external/whisper.cpp/`
- 方式：Git submodule
- 版本：master (latest)

### 2. Package.swift 配置 ✅

```swift
.target(
    name: "CWhisper",
    path: ".",
    sources: [
        "external/whisper.cpp/src/whisper.cpp",
        "external/whisper.cpp/ggml/src/ggml.c",
        "external/whisper.cpp/ggml/src/ggml.cpp",
        // ... 其他源文件
    ],
    cSettings: [
        .define("GGML_USE_METAL"),
        .define("GGML_USE_ACCELERATE"),
        .headerSearchPath("external/whisper.cpp/include"),
        .headerSearchPath("external/whisper.cpp/ggml/include"),
        // ...
    ]
)
```

### 3. 桥接层代码 ✅

#### WhisperContext.swift
- Actor 模式确保线程安全
- 模型加载/卸载接口
- 日志记录（OSLog）
- 错误处理（AsrError）

#### AudioConverter.swift
- Data ↔ Float32 数组转换
- 性能测试覆盖

#### WhisperContextTests.swift
- 模型加载失败测试
- 资源管理测试
- 转写接口占位测试（PR3 实现）

---

## 遇到的技术问题

### 问题描述：头文件依赖无法解析

**错误信息**：
```
/external/whisper.cpp/include/whisper.h:4:10: error: 'ggml.h' file not found
#include "ggml.h"
         ^
```

**根本原因**：
1. `whisper.h` 使用相对路径 `#include "ggml.h"`
2. `ggml.h` 实际位于 `external/whisper.cpp/ggml/include/ggml.h`
3. SPM 的 C/C++ target 头文件搜索机制与 CMake 不同

**尝试过的方案**：

1. ❌ **module.modulemap 相对路径**
   ```
   header "../../external/whisper.cpp/include/whisper.h"
   ```
   结果：路径计算错误

2. ❌ **umbrella header 绝对路径**
   ```c
   #include "../../../external/whisper.cpp/ggml/include/ggml.h"
   #include "../../../external/whisper.cpp/include/whisper.h"
   ```
   结果：whisper.h 内部的 `#include "ggml.h"` 仍然找不到

3. ❌ **umbrella header 系统路径**
   ```c
   #include <ggml.h>
   #include <whisper.h>
   ```
   结果：headerSearchPath 对 module.modulemap 不生效

---

## 解决方案建议

### 方案 A：使用 Xcode Framework Target（推荐）

**优点**：
- 完全控制头文件搜索路径
- 支持复杂的第三方库集成
- 可以使用 Build Phases 定制编译流程

**缺点**：
- 需要维护 Xcode 项目文件
- SPM 与 Xcode 项目混合管理

**实施步骤**：
1. 在 `Prism-xOS/packages/PrismASR/` 下创建 `.xcodeproj`
2. 添加 Framework target for CWhisper
3. 配置 Header Search Paths：
   ```
   $(PROJECT_DIR)/external/whisper.cpp/include
   $(PROJECT_DIR)/external/whisper.cpp/ggml/include
   ```
4. 将 CWhisper.framework 作为 PrismASR 的依赖

---

### 方案 B：使用 whisper.spm（最简单）

**描述**：使用社区维护的 Swift Package

**优点**：
- 开箱即用，无需手动配置
- 社区维护，及时更新

**缺点**：
- 依赖第三方维护
- 可能不是最新版本

**参考**：
- [whisper.spm](https://github.com/ggerganov/whisper.spm)

---

### 方案 C：自定义 C 桥接层（中等复杂度）

**描述**：创建简化的 C wrapper，只暴露需要的函数

**优点**：
- 完全控制接口
- 避免复杂的头文件依赖

**缺点**：
- 需要手动维护 C wrapper
- 每次 whisper.cpp 更新需要同步

**实施示例**：
```c
// CWhisperBridge.h
typedef void* WhisperContextRef;

WhisperContextRef whisper_bridge_init(const char* model_path);
void whisper_bridge_free(WhisperContextRef ctx);
// ...
```

---

### 方案 D：修改 whisper.cpp 头文件（不推荐）

**描述**：Fork whisper.cpp，修改头文件为绝对路径

**优点**：
- 可以在 SPM 中直接使用

**缺点**：
- 需要维护 fork
- 每次上游更新需要手动合并

---

## 下一步行动

### 短期（本周）
1. **评估方案**：与团队讨论选择最合适的方案
2. **验证可行性**：为选定方案创建 POC
3. **更新文档**：更新 Task-103 设计文档

### 中期（下周）
1. **实施方案**：完成 CWhisper 集成
2. **编译验证**：确保所有平台编译通过（iOS/macOS）
3. **单元测试**：验证模型加载功能

---

## 参考资料

- [Swift Package Manager - C/C++ Target](https://github.com/apple/swift-package-manager/blob/main/Documentation/Usage.md#c-language-targets)
- [whisper.cpp Official Repo](https://github.com/ggerganov/whisper.cpp)
- [whisper.cpp iOS Example](https://github.com/ggerganov/whisper.cpp/tree/master/examples/whisper.objc)
- [Swift/C++ Interoperability](https://www.swift.org/documentation/cxx-interop/)

---

##变更记录

- **2025-11-11**: 初始版本，记录 PR2 实施进展和遇到的问题
