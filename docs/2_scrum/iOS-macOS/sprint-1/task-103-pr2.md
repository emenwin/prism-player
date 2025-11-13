# 使用官方脚本构建 XCFramework

### 立即执行

1. **使用官方脚本构建 XCFramework**
   ```bash
   cd Prism-xOS/packages/PrismASR/external/whisper.cpp
   ./build-xcframework.sh
   
   # 复制到项目
   cp -R build-apple/whisper.xcframework ../../CWhisper.xcframework
   ```

2. **更新 Package.swift**
   ```swift
   .binaryTarget(
       name: "whisper",
       path: "CWhisper.xcframework"
   )
   ```

3. **验证 Swift 集成**
   ```bash
   cd Prism-xOS/packages/PrismASR
   swift build -c debug
   swift test
   ```
