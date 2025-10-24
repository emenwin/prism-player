# PrismKit

UI 组件与扩展库，提供可复用的 SwiftUI 视图、扩展与工具。

## 职责

- SwiftUI 自定义组件（播放器控件、字幕视图等）
- 常用扩展（Color, View, String 等）
- UI 工具函数与样式定义
- 平台适配层（iOS/macOS 差异封装）

## 模块结构

```
PrismKit/
├── Components/      # 自定义 SwiftUI 组件
│   ├── PlayerView/
│   ├── SubtitleView/
│   └── ProgressBar/
└── Extensions/      # Swift 扩展
    ├── View+Extensions.swift
    ├── Color+Theme.swift
    └── String+Localization.swift
```

## 依赖关系

- **依赖**: PrismCore
- **被依赖**: App 层（iOS/macOS）

## 使用示例

```swift
import SwiftUI
import PrismKit

struct ContentView: View {
    var body: some View {
        VStack {
            // 使用 PrismKit 提供的组件
            Text("Hello")
                .primaryTextStyle()
        }
    }
}
```

## 开发规范

- 组件设计遵循 SwiftUI 最佳实践
- 支持暗黑模式与动态字体
- 优先使用 SF Symbols
- 单元测试覆盖率 ≥ 60%
