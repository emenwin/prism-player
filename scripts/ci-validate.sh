#!/bin/bash

# CI 本地验证脚本
# 用于在提交前本地验证 CI 工作流

set -e  # 遇到错误立即退出

echo "🚀 Starting CI validation..."
echo ""

# 切换到项目目录
cd "$(dirname "$0")/.."

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. SwiftLint 检查
echo "📋 Step 1: Running SwiftLint..."
cd Prism-xOS
if swiftlint lint --strict; then
    echo -e "${GREEN}✅ SwiftLint passed${NC}"
else
    echo -e "${RED}❌ SwiftLint failed${NC}"
    exit 1
fi
echo ""

# 2. 构建 iOS
echo "📱 Step 2: Building iOS..."
if xcodebuild build \
    -workspace PrismPlayer.xcworkspace \
    -scheme PrismPlayer-iOS \
    -destination 'platform=iOS Simulator,name=iPhone 15' \
    -configuration Debug \
    CODE_SIGNING_ALLOWED=NO \
    -quiet; then
    echo -e "${GREEN}✅ iOS build passed${NC}"
else
    echo -e "${RED}❌ iOS build failed${NC}"
    exit 1
fi
echo ""

# 3. 测试 iOS
echo "🧪 Step 3: Testing iOS..."
if xcodebuild test \
    -workspace PrismPlayer.xcworkspace \
    -scheme PrismPlayer-iOS \
    -destination 'platform=iOS Simulator,name=iPhone 15' \
    -enableCodeCoverage YES \
    -resultBundlePath TestResults-iOS.xcresult \
    CODE_SIGNING_ALLOWED=NO \
    -quiet; then
    echo -e "${GREEN}✅ iOS tests passed${NC}"
else
    echo -e "${RED}❌ iOS tests failed${NC}"
    exit 1
fi
echo ""

# 4. 构建 macOS
echo "💻 Step 4: Building macOS..."
if xcodebuild build \
    -workspace PrismPlayer.xcworkspace \
    -scheme PrismPlayer-macOS \
    -destination 'platform=macOS' \
    -configuration Debug \
    CODE_SIGNING_ALLOWED=NO \
    -quiet; then
    echo -e "${GREEN}✅ macOS build passed${NC}"
else
    echo -e "${RED}❌ macOS build failed${NC}"
    exit 1
fi
echo ""

# 5. 测试 macOS
echo "🧪 Step 5: Testing macOS..."
if xcodebuild test \
    -workspace PrismPlayer.xcworkspace \
    -scheme PrismPlayer-macOS \
    -destination 'platform=macOS' \
    -enableCodeCoverage YES \
    -resultBundlePath TestResults-macOS.xcresult \
    CODE_SIGNING_ALLOWED=NO \
    -quiet; then
    echo -e "${GREEN}✅ macOS tests passed${NC}"
else
    echo -e "${RED}❌ macOS tests failed${NC}"
    exit 1
fi
echo ""

# 6. 测试 Swift Packages
echo "📦 Step 6: Testing Swift Packages..."

for package in PrismCore PrismASR PrismKit; do
    echo "  Testing $package..."
    cd packages/$package
    if swift test --enable-code-coverage 2>&1 | grep -q "Test Suite.*passed"; then
        echo -e "  ${GREEN}✅ $package tests passed${NC}"
    else
        echo -e "  ${RED}❌ $package tests failed${NC}"
        cd ../..
        exit 1
    fi
    cd ../..
done
echo ""

# 7. 生成覆盖率报告摘要
echo "📊 Step 7: Generating coverage summary..."
echo -e "${YELLOW}iOS Coverage:${NC}"
xcrun xccov view --report TestResults-iOS.xcresult 2>/dev/null | head -n 20 || echo "  No coverage data"
echo ""
echo -e "${YELLOW}macOS Coverage:${NC}"
xcrun xccov view --report TestResults-macOS.xcresult 2>/dev/null | head -n 20 || echo "  No coverage data"
echo ""

# 完成
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ All CI checks passed!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "You can now safely commit and push your changes."
