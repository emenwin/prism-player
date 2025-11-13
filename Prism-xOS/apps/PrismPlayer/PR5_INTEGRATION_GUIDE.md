# PR5 集成指南

## 已创建的文件

本次 PR 创建了以下新文件：

1. **AppViewModel.swift** - 应用级路由管理
   - 路径: `/Users/jingjiang/Projects/iOS/prism-player/Prism-xOS/apps/PrismPlayer/Sources/Shared/App/AppViewModel.swift`
   
2. **WelcomeView.swift** - 欢迎页面视图
   - 路径: `/Users/jingjiang/Projects/iOS/prism-player/Prism-xOS/apps/PrismPlayer/Sources/Shared/Welcome/WelcomeView.swift`

3. **已更新文件**:
   - `PrismPlayerApp.swift` - 集成了场景切换逻辑
   - `Localizable.xcstrings` - 添加了欢迎页面的国际化字符串

## 需要在 Xcode 中手动添加文件

由于新文件需要添加到 Xcode 项目中，请按以下步骤操作：

### 步骤 1: 添加 AppViewModel.swift

1. 打开 Xcode 工作空间: `Prism-xOS/PrismPlayer.xcworkspace`
2. 在项目导航器中，找到 `PrismPlayer-macOS` -> `Sources` -> `Shared`
3. 右键点击 `Shared` 文件夹，选择 "New Group"，命名为 `App`
4. 右键点击新建的 `App` 文件夹，选择 "Add Files to PrismPlayer..."
5. 导航到 `Sources/Shared/App/AppViewModel.swift`
6. 确保勾选 "Copy items if needed" 和目标 `PrismPlayer-macOS`
7. 点击 "Add"

### 步骤 2: 添加 WelcomeView.swift

1. 在 `Shared` 文件夹下创建新组 `Welcome`
2. 右键点击 `Welcome` 文件夹，选择 "Add Files to PrismPlayer..."
3. 导航到 `Sources/Shared/Welcome/WelcomeView.swift`
4. 确保勾选目标 `PrismPlayer-macOS`
5. 点击 "Add"

### 步骤 3: 验证 PlayerSceneView 已添加

检查 `Sources/Shared/Player/PlayerSceneView.swift` 是否已在项目中：
- 如果没有，按照上述步骤添加该文件

### 步骤 4: 构建测试

1. 选择 scheme: `PrismPlayer-macOS`
2. 按 `Cmd+B` 构建项目
3. 构建成功后，按 `Cmd+R` 运行

## 预期行为

1. **启动应用**: 应该看到欢迎页面，包含：
   - 左侧功能介绍卡片
   - 右侧操作按钮（打开文件、URL、光盘、转码器）
   - 底部最近历史区域（初次运行为空）

2. **打开文件**: 
   - 点击 "播放文件" 按钮
   - 选择视频文件
   - 自动切换到播放器页面，显示完整的控制栏（来自 PR1-4）

3. **播放控制**:
   - 底部控制栏包含播放/暂停、进度条、时间、音量、速度、全屏等控件
   - 支持键盘快捷键（Space、方向键等）

4. **菜单快捷键**:
   - `Cmd+O`: 打开文件
   - `Cmd+U`: 打开 URL

## 故障排除

### 如果看到编译错误

1. **"Cannot find 'AppViewModel' in scope"**
   - 确认 `AppViewModel.swift` 已添加到项目
   - 检查文件的 Target Membership 包含 `PrismPlayer-macOS`

2. **"Cannot find 'WelcomeView' in scope"**
   - 确认 `WelcomeView.swift` 已添加到项目
   - 检查文件的 Target Membership

3. **"Cannot find 'PlayerSceneView' in scope"**
   - 确认 `PlayerSceneView.swift` 已在项目中
   - 该文件应该在 PR4 中已创建

### 清理构建

如果遇到缓存问题：
```bash
# 清理 DerivedData
rm -rf ~/Library/Developer/Xcode/DerivedData/PrismPlayer-*

# 在 Xcode 中
# Product -> Clean Build Folder (Shift+Cmd+K)
```

## 验收标准

- [ ] 应用启动显示欢迎页面
- [ ] 点击"播放文件"可以选择并播放视频
- [ ] 播放页面显示完整的底部控制栏
- [ ] 所有控制栏按钮正常工作（播放/暂停、进度条拖拽、音量、速度等）
- [ ] 键盘快捷键正常响应
- [ ] 无编译错误和警告（除代码签名警告外）

## 相关 PR

- PR1: PlayerViewModel 核心实现
- PR2: 播放控制 UI - 中心区域
- PR3: 播放控制 UI - 左右区域  
- PR4: 键盘快捷键与错误处理
- PR5: **当前** - 集成到 macOS App

## 后续工作

- 实现 URL 输入对话框
- 实现光盘播放功能
- 实现转码器功能
- 添加缩略图生成（最近历史）
- 完善错误处理
