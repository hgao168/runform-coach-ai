# Sprint 0 — Android 开发者入职文档

> RunForm Coach AI Android 端 · 入职 Sprint 0 审查报告
> 审查日期：2026-05-13 · 审查人：Hermes Agent (engineering-android-developer)

---

## 一、本周目标（This-Week Goal）

**完成 Android 端代码审查，梳理技术债清单，产出实时传感器姿态采集管线（SensorManager → 步频/步幅 → TTS 语音提示）的 PoC 方案，并明确 CEO 需决策的三个关键架构问题。**

本周不写新功能代码。目标是让新加入的 Android 工程师在 2 天内获得对现有代码的完整认知，知道问题在哪、方案长什么样、需要哪些决策才能推进。

---

## 二、交付物（Deliverables）

### 2.1 现有代码审查总结

**概览：** 现有 Android 应用是一个基于 Kotlin + Jetpack Compose 的单模块 App，围绕「上传视频 → 后端 AI 分析跑姿 → 展示结果 → 生成训练计划」这条核心链路构建。代码结构简单，功能可用，但缺少生产级基础设施。

| 维度 | 现状 | 评价 |
|------|------|------|
| 语言 | Kotlin 2.1.0 | ✅ 最新 |
| UI | Jetpack Compose + Material 3 | ✅ 组件化较好 |
| 架构 | 单一 ViewModel + Compose Screen，无分层 | ⚠️ 无 Repository/Domain 层 |
| DI | 无（ViewModel 直接 `viewModel()` 实例化） | ❌ 缺少 Hilt/Koin |
| 持久化 | SharedPreferences（明文） | ❌ 无 Room，无加密 |
| 网络 | Retrofit + OkHttp + Gson | ✅ 基础可用 |
| 测试 | **0 测试** | ❌ 无单元测试、无 UI 测试 |
| 混淆 | `isMinifyEnabled = false` | ❌ Release 未开启 R8 |
| 签名 | 无 keystore 配置 | ❌ 无法发布 |
| 传感器 | **无 SensorManager 集成** | ❌ Sprint 0 核心缺失 |
| 语音 | **无 TextToSpeech** | ❌ Sprint 0 核心缺失 |
| 健康数据 | 无 Health Connect / Google Fit | ❌ 待规划 |
| 穿戴设备 | 无 Wear OS 模块 | ❌ 待规划 |
| Strava | 无（上下文提到但代码中不存在） | ❌ 待接入 |

### 2.2 技术债清单（Tech-Debt List）

按严重程度和 Sprint 规划排列：

#### 🔴 P0 — 阻塞 Sprint 1（必须本周确认方案）

| # | 条目 | 现状 | 建议方案 |
|---|------|------|----------|
| 1 | **无传感器管线** | AndroidManifest 中无 BODY_SENSORS / ACTIVITY_RECOGNITION 权限 | Sprint 1 实现 SensorManager → 加速度计 → 步频计算 → Flow 发射 |
| 2 | **无 TTS 音频反馈** | 无任何语音输出 | Sprint 1 实现 TextToSpeech 实时语音提示（步频过高/过低、姿态提醒） |
| 3 | **无前台服务** | 无 Foreground Service，App 切后台传感器即停止 | 用 Foreground Service + 通知栏保持采集 |

#### 🟡 P1 — Sprint 1~2 应解决

| # | 条目 | 现状 | 建议方案 |
|---|------|------|----------|
| 4 | **无 DI 框架** | `AppViewModel` 直接实例化，无法 mock 测试 | 接入 Hilt（推荐）或 Koin |
| 5 | **无 Room 数据库** | SharedPreferences 存 JSON，不支持查询/迁移 | 接入 Room：本地跑步记录、传感器历史 |
| 6 | **明文存储** | SharedPreferences 无加密 | 迁移到 EncryptedSharedPreferences |
| 7 | **无测试** | 0% 覆盖率 | 先补 ViewModel 单元测试（JUnit5 + MockK），再补 Compose UI 测试 |
| 8 | **硬编码 API URL** | `ApiClient.kt` 写死 staging URL | 用 BuildConfig 区分 staging / production |
| 9 | **API 无认证** | Retrofit 请求无 token / header | 接入认证（Firebase Auth 或自建） |

#### 🟢 P2 — Sprint 3+

| # | 条目 | 现状 | 建议方案 |
|---|------|------|----------|
| 10 | **无 R8 混淆** | release build 未开启 | 开启 `isMinifyEnabled = true`，配置 proguard-rules.pro |
| 11 | **无签名配置** | 无 keystore | 生成 upload key，本地开发用 debug，CI 用环境变量注入 |
| 12 | **单模块工程** | 所有代码在同一 app 模块 | 按需拆分为 `:core:sensor`、`:core:network`、`:feature:analysis` 等 |
| 13 | **无错误监控** | 异常只在 UI 显示 toast 级别 | 接入 Firebase Crashlytics |
| 14 | **无埋点** | 无事件追踪 | 接入 Firebase Analytics / Mixpanel |
| 15 | **Coil 未使用** | `libs.versions.toml` 声明了但代码未引用 | 评估是否需要（视频缩略图？） |

### 2.3 文件结构地图（File-Structure Map）

```
android/
├── build.gradle.kts                        # 根构建脚本（插件声明 only）
├── settings.gradle.kts                     # 项目名 RunFormCoachAI，单模块 :app
├── gradle.properties                       # JDK 路径（Windows）、JVM 参数
├── gradle/
│   ├── libs.versions.toml                  # 版本目录（统一依赖管理）
│   └── wrapper/
│       ├── gradle-wrapper.jar
│       └── gradle-wrapper.properties
│
└── app/
    ├── build.gradle.kts                    # 应用构建：compileSdk=36, minSdk=26
    │                                       #   Compose=true, 无签名配置, R8 关闭
    └── src/
        └── main/
            ├── AndroidManifest.xml          # 权限：INTERNET, CAMERA, RECORD_AUDIO
            │                                #       READ_MEDIA_VIDEO
            │                                # ⚠️ 缺失：BODY_SENSORS, FOREGROUND_SERVICE,
            │                                #          ACTIVITY_RECOGNITION, POST_NOTIFICATIONS
            │
            ├── res/
            │   └── xml/
            │       └── file_paths.xml       # FileProvider 路径（cache 目录）
            │
            └── java/com/runformcoach/runformcoachai/
                ├── MainActivity.kt          # 入口 Activity，enableEdgeToEdge
                │                            #   4 个 Tab：Analyze / History / Plan / Profile
                │                            #   数据类 TabItem, 导航用 when(selectedTab)
                │
                ├── AppTheme.kt              # 主题 + 公共组件
                │   ├── AppColors            #   暗色主题色板：Mint(#40F5C2) 为主色
                │   ├── RunFormColorScheme   #   Material 3 darkColorScheme
                │   ├── BgGradient           #   渐变背景（深蓝 → 紫）
                │   ├── GlassCard / DarkCard #   毛玻璃卡片组件
                │   ├── SectionTitle         #   大写标题组件
                │   └── categoryColor()      #   训练类别 → 颜色映射
                │
                ├── AppViewModel.kt          # 核心 ViewModel（~195 行）
                │   ├── 分析状态机           #   Idle → Loading → Success/Error
                │   ├── 训练计划状态机       #   Idle → Loading → Success/Error
                │   ├── 用户资料管理         #   SharedPreferences 序列化
                │   ├── 历史记录管理         #   最多保留 50 条
                │   └── Video URI → TempFile #   ContentResolver → cache
                │
                ├── MainViewModel.kt         # ⚠️ 已废弃（文件内容：Superseded by AppViewModel）
                │
                ├── Models.kt                # 数据模型（~118 行）
                │   ├── AnalysisResponse     #   后端分析结果
                │   ├── Metric / Issue       #   指标 + 问题
                │   ├── Exercise             #   推荐训练
                │   ├── TesterProfile        #   用户资料
                │   ├── TrainingPlanRequest  #   训练计划请求
                │   ├── TrainingPlanResponse #   训练计划响应
                │   ├── PlannedWorkout       #   单日训练
                │   └── AnalysisHistoryItem  #   历史记录条目
                │
                ├── ApiClient.kt             # Retrofit 网络层（~56 行）
                │   ├── RunFormApi           #   接口：analyzeVideo (Multipart), generatePlan (POST)
                │   ├── BASE_URL             #   ⚠️ 硬编码 staging URL
                │   └── OkHttp               #   120s 超时，BASIC 日志拦截器
                │
                ├── AnalyzeScreen.kt         # 分析页（~313 行）
                │   ├── 视频选择             #   ActivityResultContracts.GetContent
                │   ├── 相机录制             #   ActivityResultContracts.CaptureVideo
                │   ├── 角度选择             #   side / rear / front
                │   └── 结果嵌入             #   复用 AnalysisResultScreen
                │
                ├── AnalysisResultScreen.kt  # 分析结果页（~228 行）
                │   ├── ConfidenceRing       #   Canvas 绘制环形进度
                │   ├── MetricRow            #   指标条 + 状态标签
                │   ├── IssueCard            #   问题卡片 + 推荐训练
                │   ├── ExerciseCard         #   训练链接（B站/YouTube）
                │   └── StatusBadge          #   状态徽章（Good/Needs Work/Critical）
                │
                ├── HistoryScreen.kt         # 历史页（~201 行）
                │   ├── 列表展示             #   LazyColumn + GlassCard
                │   ├── 展开/折叠            #   点击展开完整结果
                │   ├── 置信度标签           #   绿/橙/红三色
                │   └── 清空确认             #   AlertDialog
                │
                ├── PlanScreen.kt            # 训练计划页（~406 行）
                │   ├── 表单输入             #   周跑量、目标、可选日期
                │   ├── 伤病标志             #   Switch 开关
                │   ├── 计划展示             #   WorkoutCard（日期徽章 + 类型标签 + 强度标签）
                │   └── 中英文自适应         #   Locale.getDefault().language
                │
                └── ProfileScreen.kt         # 个人资料页（~351 行）
                    ├── 身份信息             #   姓名、昵称
                    ├── 跑步者档案           #   水平、目标（下拉菜单）
                    ├── 跑步统计             #   Slider：周跑量、跑步天数、运动时长
                    ├── 身体数据             #   身高、体重
                    ├── 伤病备注             #   多行文本
                    └── DropdownField / SliderRow  # 可复用子组件
```

**文件统计：**

| 文件 | 行数 | 职责 |
|------|------|------|
| AppTheme.kt | 163 | 主题、颜色、公共组件 |
| AppViewModel.kt | 194 | 状态管理、持久化、网络调度 |
| Models.kt | 118 | 全部数据模型 |
| ApiClient.kt | 56 | Retrofit 配置 |
| MainActivity.kt | 116 | 导航 + Tab 结构 |
| AnalyzeScreen.kt | 313 | 视频分析页面 |
| AnalysisResultScreen.kt | 228 | 分析结果展示 |
| HistoryScreen.kt | 201 | 历史记录 |
| PlanScreen.kt | 406 | 训练计划 |
| ProfileScreen.kt | 351 | 个人资料 |
| **总计** | **~2,186** | **10 个 Kotlin 源文件** |

### 2.4 传感器 API 实时姿态采集 PoC 方案

#### 2.4.1 目标

在跑步过程中，通过 Android 传感器实时采集加速度计数据，计算步频（Cadence）和步幅特征，通过 TTS 语音实时提示跑者调整姿态。

#### 2.4.2 数据流

```
手机 IMU 传感器
    │
    ├─ TYPE_ACCELEROMETER     (加速度计, 100Hz)
    ├─ TYPE_GYROSCOPE         (陀螺仪, 100Hz) [可选]
    └─ TYPE_GRAVITY           (重力, 分离重力分量) [可选]
         │
         ▼
    SensorManager.registerListener()
    onSensorChanged(event: SensorEvent)
         │
         ▼
    SensorFusionProcessor
    ├─ 低通滤波 (α=0.8)         → 消除高频噪声
    ├─ 峰值检测                  → 识别步态周期
    ├─ 步频计算 (spm)            → 实时步频
    ├─ 步幅推算 (步频+身高估算)  → 近似步幅
    └─ 姿态角计算 (陀螺仪融合)   → 躯干倾斜
         │
         ▼
    StateFlow<RunningMetrics>     → 发射给 UI / TTS
         │
         ├─→ UI Layer: 实时仪表盘 (步频、步幅、躯干角度)
         └─→ TTS Engine: 语音提示 ("步频偏低，加快节奏" / "躯干过度前倾")
```

#### 2.4.3 核心组件设计

```
app/src/main/java/com/runformcoach/runformcoachai/
├── sensor/
│   ├── RunningSensorManager.kt        # 封装 SensorManager 生命周期
│   ├── SensorFusionProcessor.kt       # 滤波 + 步频检测 + 姿态计算
│   ├── CadenceDetector.kt             # 加速度计峰值检测 → 步频
│   ├── StrideEstimator.kt             # 步频+身高 → 步幅估算
│   └── RunningMetrics.kt              # data class: cadence, stride, trunkAngle, ...
│
├── tts/
│   ├── CoachingTtsEngine.kt           # TextToSpeech 封装 + 教练提示队列
│   └── CoachingCueGenerator.kt        # 指标 → 提示文案 (中英文)
│
├── service/
│   └── RunningForegroundService.kt    # 前台服务：保持传感器 + TTS 后台运行
│
└── ui/
    └── LiveRunningDashboard.kt        # Compose 实时仪表盘页面
```

#### 2.4.4 关键技术细节

**加速度计配置：**

```kotlin
val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
val accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)

sensorManager.registerListener(
    listener,
    accelerometer,
    SensorManager.SENSOR_DELAY_GAME  // ~20ms = 50Hz, 步频检测足够了
)
```

**滤波参数：** 低通滤波器 α=0.8（可配置），截止频率约 3.5Hz，保留步频信号（1.5~3.5Hz），过滤传感器硬件噪声。

```
filtered[n] = α * filtered[n-1] + (1-α) * raw[n]
```

**步频峰值检测：**
- 滑窗大小：500ms
- 加速度幅值 `sqrt(x² + y² + z²)`
- 在幅值超过阈值（1.2×当前窗口均值）且间距 > 250ms（最大步频 240spm）时计为一步
- 实时步频 = 60 / (最近两次峰值间隔_秒)

**TTS 触发策略：**

| 条件 | 提示文案（中文） | 冷却 |
|------|------------------|------|
| 步频 < 160 spm 持续 10s | "步频偏低，试着加快节奏到每分钟 170 步" | 30s |
| 步频 > 200 spm 持续 10s | "步频过快，试着放慢节奏" | 30s |
| 躯干前倾 > 15° | "注意保持躯干直立" | 60s |
| 每公里 | "当前步频 xxx，配速 x:xx" | — |

#### 2.4.5 需要的权限变更

在 `AndroidManifest.xml` 中新增：

```xml
<!-- Android 12-: 身体传感器 -->
<uses-permission android:name="android.permission.BODY_SENSORS" />

<!-- Android 13+: 身体传感器（运行时请求） -->
<uses-permission android:name="android.permission.BODY_SENSORS_BACKGROUND" />

<!-- 前台服务 -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />

<!-- Android 13+: 通知权限 -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

<!-- 物理活动识别（可选，用于自动检测跑步开始） -->
<uses-permission android:name="android.permission.ACTIVITY_RECOGNITION" />
```

#### 2.4.6 依赖新增（gradle/libs.versions.toml）

```toml
[versions]
coroutines = "1.9.0"

[libraries]
kotlinx-coroutines-android = { group = "org.jetbrains.kotlinx", name = "kotlinx-coroutines-android", version.ref = "coroutines" }
```

#### 2.4.7 PoC 验证标准

- [ ] 加速度计数据正确回调，onSensorChanged 在 SENSOR_DELAY_GAME 下稳定输出
- [ ] 跑步机上以 160/170/180 spm 三种步频跑步，步频检测误差 < ±5 spm
- [ ] 低通滤波后波形平滑，无明显毛刺
- [ ] TTS 在步频偏差时正确触发语音提示
- [ ] 前台服务通知正确显示，息屏后传感器不中断
- [ ] 小米/华为/OPPO 设备上后台采集不中断（需验证厂商后台限制）

---

## 三、风险（Risks）

| # | 风险 | 影响 | 概率 | 缓解措施 |
|---|------|------|------|----------|
| R1 | **厂商后台限制** | 华为/小米/OPPO 等国产 ROM 在息屏后会杀死后台进程，传感器采集中断 | 高 | 前台服务 + 通知栏常驻 + 引导用户加白名单 |
| R2 | **传感器精度差异** | 低端设备加速度计噪声大，步频检测不准 | 中 | 滤波参数可配置；设备分级降级策略 |
| R3 | **TTS 引擎兼容性** | 国产设备可能无 Google TTS，需用系统自带或讯飞 | 中 | 先走系统默认 TTS，后续评估讯飞 SDK |
| R4 | **加速度计功耗** | 持续 50Hz 采样增加耗电 | 低 | SENSOR_DELAY_GAME 功耗可控；可选降频至 25Hz |
| R5 | **测试设备不足** | 缺乏国产主流厂商真机 | 高 | 申请至少 3 台设备：小米（MIUI）、华为（HarmonyOS）、OPPO（ColorOS） |
| R6 | **现有架构脆弱** | 无 DI / 无测试，重构成本高 | 中 | Sprint 1 先接入 Hilt + 补核心测试，再扩展传感器模块 |
| R7 | **Strava 接入路径不清** | 上下文提到 Strava 但代码中无任何迹象 | 低 | CEO 需确认 Android 端是否需要 Strava |

---

## 四、需要 CEO 决策的三个问题（Decisions Needed From CEO）

### 决策 1：minSdk —— 最低支持到哪个版本？

**现状：** 当前 `minSdk = 26`（Android 8.0，2017 年）。覆盖市场约 95%+ 设备。

**选项：**

| 选项 | minSdk | 覆盖 | 代价 | 收益 |
|------|--------|------|------|------|
| A (保守) | 26 (Android 8) | ~95% | 无额外 | 现状不变 |
| B (积极) | 29 (Android 10) | ~85% | 丢 10% 用户 | Health Connect 原生支持（无需 Google Fit 桥接）、更少权限适配 |
| C (激进) | 31 (Android 12) | ~70% | 丢 25% 用户 | Dynamic Color 原生、Material You 全功能、最简后台限制适配 |

**推荐：** **A（保守 minSdk=26）**，因为跑步 App 用户群偏大众，且 Sprint 0 阶段无需最新 API。

**请 CEO 确认：** ☐ minSdk=26 保持 / ☐ 升级至 minSdk= ____

---

### 决策 2：UI 架构 —— Jetpack Compose 纯写 vs XML Fragment 混合？

**现状：** 当前 100% Jetpack Compose，无一行 XML layout。

**选项：**

| 选项 | 描述 | 优点 | 缺点 |
|------|------|------|------|
| A (维持现状) | 全部 Compose，不引入 Fragment | 开发效率高、代码少、声明式 UI | 团队需 Compose 经验；未来如需嵌第三方 Fragment（地图、支付 SDK）需处理 |
| B (混合模式) | 主流程 Compose + 复杂 View 用 Fragment 承载 | 兼容性好，第三方 SDK 接入方便 | 架构复杂度高，需 ComposeView ↔ Fragment 互操作 |

**推荐：** **A（纯 Compose）**。理由：
- 现有代码已是 100% Compose，无需倒退
- 传感器仪表盘 / 实时数据展示天然适合 Compose
- 如需嵌套第三方 View，用 `AndroidView` 可解决，无需 Fragment

**请 CEO 确认：** ☐ 纯 Compose / ☐ 混合 Fragment + Compose

---

### 决策 3：TTS 引擎 —— 用系统默认还是第三方 SDK？

**现状：** 无任何 TTS 实现。Android 自带 `android.speech.tts.TextToSpeech`，但国产设备默认引擎不一致。

**选项：**

| 选项 | 引擎 | 优点 | 缺点 |
|------|------|------|------|
| A (系统默认) | `Android TTS` | 零成本、零 SDK、包体积无增长 | 国产设备语音质量参差不齐（有的无中文/英文语音包） |
| B (讯飞) | 讯飞语音 SDK | 中文语音质量最佳，国内设备普遍预装 | 需集成 SDK，增加包体积 ~5MB，需申请 API Key |
| C (自建) | 预录音频文件 | 离线可用，延迟最低（纯音频播放） | 文案固化，无法动态生成提示；后期维护成本高 |

**推荐：** **先 A 后 B**。Sprint 1 用系统默认 TTS 跑通链路，验证可行性后，Sprint 2 评估讯飞 SDK 集成（如用户反馈语音质量差）。

**请 CEO 确认：** ☐ 系统默认 TTS / ☐ 讯飞 SDK / ☐ 预录音频

---

## 五、Sprint 1 展望（Preview）

Sprint 0 结束后，Sprint 1 的计划产出：

1. **接入 Hilt DI** → `@HiltViewModel` + `@Inject` 替换手动实例化
2. **实现 RunningSensorManager + CadenceDetector** → 加速度计数据采集 + 步频计算
3. **实现 CoachingTtsEngine** → 系统 TTS 语音提示
4. **实现 RunningForegroundService** → 前台服务保持后台采集
5. **实现 LiveRunningDashboard** → Compose 实时仪表盘页面
6. **补 AppViewModel 单元测试** → JUnit5 + MockK，覆盖率 > 50%
7. **配置 BuildConfig 多环境** → staging / production API URL

---

## 附录 A：现有依赖清单

| 类别 | 依赖 | 版本 |
|------|------|------|
| 构建 | AGP | 8.13.2 |
| 语言 | Kotlin | 2.1.0 |
| 核心 | AndroidX Core KTX | 1.15.0 |
| 生命周期 | Lifecycle Runtime KTX | 2.8.7 |
| 生命周期 | Lifecycle ViewModel Compose | 2.8.7 |
| 活动 | Activity Compose | 1.9.3 |
| UI | Compose BOM | 2024.11.00 |
| UI | Material 3 | BOM 管理 |
| UI | Material (MDC) | 1.12.0 |
| UI | Material Icons Extended | BOM 管理 |
| 网络 | Retrofit | 2.11.0 |
| 网络 | OkHttp | 4.12.0 |
| 序列化 | Gson | 2.11.0 |
| 图片 | Coil Compose | 2.7.0 |

## 附录 B：操作项总览

| # | 项 | 负责人 | 状态 |
|---|-----|--------|------|
| 1 | CEO 确认 minSdk 决策 | CEO | ⬜ 待确认 |
| 2 | CEO 确认 Compose vs Fragment 决策 | CEO | ⬜ 待确认 |
| 3 | CEO 确认 TTS 引擎决策 | CEO | ⬜ 待确认 |
| 4 | 申请国产测试设备 | PM | ⬜ 待办 |
| 5 | Sprint 1 规划评审 | Android 工程师 | ⬜ 待办 |
| 6 | 传感器 PoC 方案评审 | 全团队 | ⬜ 待办 |
