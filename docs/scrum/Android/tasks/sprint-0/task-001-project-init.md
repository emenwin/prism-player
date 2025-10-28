# Task 001: Android 项目初始化

> Sprint: Sprint 0  
> 优先级: P0  
> 估算: 3 Story Points  
> 负责人: [待分配]  
> 状态: To Do

---

## 背景

作为项目的第一个任务，需要创建 Android 项目基础结构，配置核心依赖，建立包组织规范，为后续开发打下基础。

关联 PRD：无  
关联 HLD：第 4 节（模块与包组织）

---

## 目标

创建可编译运行的 Android 项目骨架，配置 Hilt 依赖注入与 Jetpack Compose UI 框架。

---

## 任务清单

- [ ] 创建 Android 项目（Gradle 8.x + Kotlin 1.9+）
  - [ ] 配置 `build.gradle.kts`（项目级）
  - [ ] 配置 `build.gradle.kts`（app 级）
  - [ ] 设置 `compileSdk = 34`，`minSdk = 28`，`targetSdk = 34`
- [ ] 配置 Hilt 依赖注入
  - [ ] 添加 Hilt Gradle 插件
  - [ ] 添加 Hilt 依赖（`hilt-android`, `hilt-compiler`）
  - [ ] 创建 `@HiltAndroidApp` Application 类
- [ ] 配置 Jetpack Compose
  - [ ] 添加 Compose BOM（Bill of Materials）
  - [ ] 启用 `buildFeatures.compose = true`
  - [ ] 配置 `composeOptions.kotlinCompilerExtensionVersion`
- [ ] 创建包结构（`com.prism.player.*`）
  - [ ] `ui.*`：`player`, `settings`, `models`
  - [ ] `feature.*`：`playback`, `asr`, `subtitles`
  - [ ] `core.*`：`audio`, `storage`, `di`, `util`
  - [ ] `data.*`：`dao`, `entities`, `repository`
  - [ ] `domain.*`：`usecase`, `models`
- [ ] 创建基础文件
  - [ ] `.gitignore`（Android 模板）
  - [ ] `README.md`
  - [ ] `LICENSE`（MIT，待确认）
- [ ] 验证构建
  - [ ] 本地编译成功
  - [ ] 模拟器运行成功（显示"Hello World"）

---

## 验收标准（AC）

- [ ] 项目可在 Android Studio Hedgehog+ 中打开并同步成功
- [ ] `./gradlew assembleDebug` 构建成功
- [ ] Hilt 注入正常工作（创建 `MainViewModel` 并注入验证）
- [ ] Compose UI 可正常渲染（显示简单 Text）
- [ ] 包结构符合 HLD 第 4 节约定
- [ ] `.gitignore` 正确排除 `build/`, `.idea/`, `local.properties` 等
- [ ] 模拟器或真机运行应用无崩溃

---

## 技术要点

### 依赖版本
```kotlin
// build.gradle.kts (project)
plugins {
    id("com.android.application") version "8.2.0" apply false
    id("org.jetbrains.kotlin.android") version "1.9.20" apply false
    id("com.google.dagger.hilt.android") version "2.48" apply false
}

// build.gradle.kts (app)
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.dagger.hilt.android")
    kotlin("kapt")
}

dependencies {
    // Hilt
    implementation("com.google.dagger:hilt-android:2.48")
    kapt("com.google.dagger:hilt-compiler:2.48")

    // Compose
    val composeBom = platform("androidx.compose:compose-bom:2023.10.01")
    implementation(composeBom)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui-tooling-preview")
    debugImplementation("androidx.compose.ui:ui-tooling")

    // Activity
    implementation("androidx.activity:activity-compose:1.8.1")
}
```

## 相关 TDD
- [tdd/Android/hld-android-v0.2.md](../../../../tdd/Android/hld-android-v0.2.md) — 约束：Jetpack Compose + MVVM，禁止硬编码字符串

## 相关 ADR
- （待补充）Android 平台 ADR 列表（如 Logging/DI/存储 等），若共用跨端决策请在 Android 侧建立对应 ADR 或引用通用 ADR

## 定义完成（DoD）
- [ ] CI 通过（构建/测试/Lint）
- [ ] 无硬编码字符串（国际化）
- [ ] 文档/变更日志更新（PRD/TDD/ADR/Scrum）
- [ ] 关键路径测试覆盖与可观测埋点到位

### 包结构示例
```
com.prism.player/
├── PrismApplication.kt          // @HiltAndroidApp
├── MainActivity.kt
├── ui/
│   ├── player/
│   │   └── PlayerScreen.kt
│   ├── settings/
│   │   └── SettingsScreen.kt
│   └── theme/
│       └── Theme.kt
├── feature/
│   ├── playback/
│   └── asr/
├── core/
│   ├── di/
│   │   └── AppModule.kt        // Hilt Module
│   └── util/
└── data/
    └── entities/
```

### Hilt 验证示例
```kotlin
// MainActivity.kt
@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    @Inject lateinit var testDependency: SomeClass
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            PrismTheme {
                Text("Hello Prism Player!")
            }
        }
    }
}
```

---

## 依赖

- **前置任务**：无
- **外部依赖**：
  - Android Studio Hedgehog+ (2023.1.1+)
  - Gradle 8.x
  - JDK 17

---

## 风险

| 风险 | 影响 | 缓解策略 |
|------|------|---------|
| Gradle 版本兼容性问题 | 构建失败 | 使用稳定版本（8.2.0），查阅官方文档 |
| Hilt 配置错误 | 运行时崩溃 | 参考官方示例，单元测试验证 |
| 包结构与团队习惯不一致 | 代码混乱 | Sprint Planning 时与团队对齐 |

---

## 参考文档

- [HLD Android v0.2 - 第 4 节](../../../tdd/Android/hld-android-v0.2.md#4-模块与包组织)
- [Hilt 官方文档](https://developer.android.com/training/dependency-injection/hilt-android)
- [Jetpack Compose 官方文档](https://developer.android.com/jetpack/compose)
- [Android Gradle Plugin 版本说明](https://developer.android.com/studio/releases/gradle-plugin)

---

## 更新日志

| 日期 | 更新内容 | 更新人 |
|------|---------|--------|
| 2025-10-25 | 任务创建 | Copilot Agent |
| - | - | - |

---

## 备注

- 确保团队所有成员使用相同版本的 Android Studio 和 Gradle
- 建议在 `gradle.properties` 中配置 `org.gradle.jvmargs=-Xmx2048m` 避免内存不足
- 可选：配置 `.editorconfig` 统一代码风格
