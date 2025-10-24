#!/bin/bash

# SwiftLint Run Script for Xcode Build Phase
# 在 Xcode Build Phase 中运行此脚本以自动检查代码规范

# 添加 Homebrew 路径（Apple Silicon）
export PATH="$PATH:/opt/homebrew/bin"

# 添加 Homebrew 路径（Intel）
export PATH="$PATH:/usr/local/bin"

# 检查 SwiftLint 是否安装
if which swiftlint >/dev/null; then
  # 运行 SwiftLint，从项目根目录检查源代码
  # 直接传递路径参数，不使用 --path
  swiftlint lint "${SRCROOT}/Sources" --config "${SRCROOT}/../../.swiftlint.yml"
else
  echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
fi