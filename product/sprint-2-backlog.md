# RunForm Sprint 2 Backlog：CoreMotion 实时教练管线 + Android 收尾 + 后端支撑

> **创建日期**：2026-05-16
> **Sprint 周期**：2026-05-26 ~ 2026-06-20（4 周）
> **Sprint 1 完成状态**：跨平台功能对齐 100% P0 完成，Android 13/16 条目完成，WeChat 9/9 完成，后端 compare/feedback API 就绪
> **关联文档**：`product/v1-prd.md`、`product/sprint-1-revised-backlog.md`、`product/sprint1-16-05-2026-completion.md`、`onboarding/ios-developer.md`、`onboarding/android-developer.md`

---

## 一、Sprint 2 目标

**一句话**：恢复新功能开发 — 交付 iOS CoreMotion 实时跑步教练核心管线（Phase 0-4），Android 同步建设 Sensor API 管线，完成 Android P1/P2 收尾条目，后端提供实时跑步数据 API 支撑，QA 执行全平台回归测试。

---

## 二、Sprint 1 结转：Android 剩余条目

以下条目在 Sprint 1 中未完成，转入 Sprint 2：

| 原 ID | 标题 | 优先级 | SP | 状态 |
|-------|------|--------|-----|------|
| RF-205 | Android Strava OAuth 集成 | P1 | 8 | **CEO 指令暂停（见第八节）** |
| RF-209 | Android 实时录制引导（Camera Overlay） | P2 | 5 | 转入 Sprint 2 |
| RF-214 | Android R8 混淆 + Keystore 签名配置 | P1 | 3 | 转入 Sprint 2 |
| RF-215 | Android Firebase Crashlytics + Analytics 接入 | P2 | 3 | 转入 Sprint 2 |

---

## 三、Sprint 2 新条目总览

| ID | 标题 | 指派 | SP | 优先级 | 平台 |
|----|------|------|-----|--------|------|
| **iOS CoreMotion 管线（Phase 0-4）** |
| RF-500 | iOS CoreMotion Phase 0 — 传感器采集管线 + DebugView | iOS 开发 | 5 | P0 | iOS |
| RF-501 | iOS CoreMotion Phase 1 — 步频实时计算（CadenceCalculator） | iOS 开发 | 5 | P0 | iOS |
| RF-502 | iOS CoreMotion Phase 2 — 垂直振幅 + 触地时间（RunningMetricsCalculator） | iOS 开发 | 5 | P0 | iOS |
| RF-503 | iOS CoreMotion Phase 3 — 姿态特征提取（MotionPostureExtractor） | iOS 开发 | 8 | P0 | iOS |
| RF-504 | iOS CoreMotion Phase 4 — 实时语音教练（AudioCoachManager） | iOS 开发 | 5 | P0 | iOS |
| RF-505 | iOS RunSession 管线整合 + 跑步会话 View | iOS 开发 | 8 | P0 | iOS |
| **Android Sensor API 管线（对标 iOS CoreMotion）** |
| RF-600 | Android SensorManager 采集 + SensorFusionProcessor | Android 开发 | 5 | P0 | Android |
| RF-601 | Android CadenceDetector — 步频实时计算 | Android 开发 | 3 | P0 | Android |
| RF-602 | Android RunningMetrics — 垂直振幅 + 触地时间 | Android 开发 | 5 | P1 | Android |
| RF-603 | Android TextToSpeech 实时语音教练引擎 | Android 开发 | 5 | P0 | Android |
| RF-604 | Android RunningForegroundService — 后台跑步服务 | Android 开发 | 5 | P0 | Android |
| RF-605 | Android LiveRunningDashboard — 跑步实时仪表盘 UI | Android 开发 | 3 | P0 | Android |
| **Android Sprint 1 收尾** |
| RF-214 | Android R8 混淆 + Keystore 签名配置 | Android 开发 | 3 | P1 | Android |
| RF-215 | Android Firebase Crashlytics + Analytics 接入 | Android 开发 | 3 | P2 | Android |
| RF-209 | Android 实时录制引导（LiveGuidance Camera Overlay） | Android 开发 | 5 | P2 | Android |
| **后端支撑** |
| RF-700 | 后端实时跑步会话 API（POST/GET /run-sessions） | 后端开发 | 5 | P0 | 后端 |
| RF-701 | 后端跑步指标数据模型 + DB 迁移 | 后端开发 | 3 | P0 | 后端 |
| RF-702 | 后端跑步趋势聚合 API（GET /run-trends） | 后端开发 | 5 | P1 | 后端 |
| RF-703 | 后端跑步会话对比 API（POST /compare-sessions） | 后端开发 | 5 | P1 | 后端 |
| **QA 全平台回归** |
| RF-800 | QA 全平台回归测试计划 + 执行 | QA 工程师 | 8 | P0 | 全平台 |
| RF-801 | CI 测试门禁强化（iOS + Android + 后端） | QA 工程师 | 5 | P1 | CI |
| RF-802 | iOS CoreMotion 管线专项测试（精度/功耗/后台） | QA 工程师 | 5 | P0 | iOS |

**总计**：22 个条目，108 SP（约 4 周，4 人并行）

- iOS 开发：6 个条目，36 SP
- Android 开发：9 个条目，37 SP
- 后端开发：4 个条目，18 SP
- QA 工程师：3 个条目，18 SP

### 优先级说明

| 优先级 | 含义 | Sprint 2 处理策略 |
|--------|------|-------------------|
| **P0** | 核心创新，Sprint 2 必须交付 | 优先保障，Week 1-3 攻坚 |
| **P1** | 增强项，尽力交付 | Week 3-4 视进度推进 |
| **P2** | Nice-to-have，有余力时做 | Week 4 缓冲期处理 |

---

## 四、iOS CoreMotion Phase 0-4 详细分解

### 4.1 管线总览

```
iPhone 腰包/臂带
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│  CMMotionManager (100Hz)                                │
│  ├─ Accelerometer (x, y, z m/s²)                       │
│  └─ Gyroscope (x, y, z rad/s)                          │
└────────────┬────────────────────────────────────────────┘
             │ AsyncStream<SensorFrame>
             ▼
┌────────────────────────┐   ┌───────────────────────────┐
│  CadenceCalculator     │   │  MotionPostureExtractor    │
│  (Phase 1)             │   │  (Phase 3)                 │
│  ─────────────────     │   │  ─────────────────────     │
│  Butterworth lowpass   │   │  Madgwick sensor fusion    │
│  → peak detection      │   │  → pitch/roll/yaw          │
│  → CadenceUpdate       │   │  → trunk lean angle        │
└────────┬───────────────┘   └────────────┬──────────────┘
         │                                │
         ▼                                ▼
┌────────────────────────┐   ┌───────────────────────────┐
│  RunningMetricsCalc    │   │  AudioCoachManager         │
│  (Phase 2)             │   │  (Phase 4)                 │
│  ─────────────────     │   │  ─────────────────────     │
│  Z double-integration  │   │  subscribes cadence +      │
│  → vertical oscillation│   │  posture streams           │
│  ‖a‖ trough detect     │   │  → AVSpeechSynthesizer     │
│  → ground contact time │   │  → debounce 15s / 5 max    │
└────────────────────────┘   └───────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│  RunSessionManager (Phase 5)                            │
│  ───────────────────────────                            │
│  start → running → paused → stopped → saved             │
│  └→ RunSessionSummary                                   │
│  └→ PoseMetrics 兼容格式 → 现有 AnalysisResultView      │
└─────────────────────────────────────────────────────────┘
```

---

### RF-500 · iOS CoreMotion Phase 0 — 传感器采集管线 + DebugView

**优先级**：P0
**类型**：新功能（原 RUNFORM-103 + 104）
**平台**：iOS
**指派**：iOS 开发者
**估算**：5 SP（~2.5 天）
**原 Sprint 1 ID**：RUNFORM-103（CoreMotionManager）、RUNFORM-104（DebugView）

**用户故事**：
作为 iOS 跑者，我希望 App 能通过手机传感器采集跑步时的加速度和陀螺仪数据，并能在调试界面看到原始波形，验证数据质量。

**验收标准**：
- [ ] 新建 `CoreMotionManager.swift`：封装 `CMMotionManager`
- [ ] `AsyncStream<SensorFrame>` 数据流输出（三轴加速度 + 三轴陀螺仪 + 时间戳）
- [ ] 配置：`updateInterval = 100Hz`（10ms），后台队列处理，主线程仅更新 UI
- [ ] 采样频率自适应：省电模式 50Hz / 精度模式 100Hz
- [ ] FIFO 环形缓冲区 `RingBuffer<SensorFrame>`（capacity=600，~6 秒滑动窗口）
- [ ] 新建 `SensorDebugView.swift`：Swift Charts 显示三轴加速度波形（X=时间，Y=m/s²）
- [ ] 验证：将设备绑在腰间慢跑 30 秒，确认三轴数据连续无丢帧
- [ ] 功耗测试：100Hz 持续采集 5 分钟，电池消耗 < 3%
- [ ] `Info.plist` 已含 `NSMotionUsageDescription`（Sprint 1 RF-403 已添加）

**依赖项**：RF-403（XCTest + SwiftLint，已完成）
**风险**：中。Sprint 1 已添加 `NSMotionUsageDescription` 权限，但 iOS 后台挂起策略需 Phase 5 配合 HealthKit 解决。

---

### RF-501 · iOS CoreMotion Phase 1 — 步频实时计算（CadenceCalculator）

**优先级**：P0
**类型**：新功能（原 RUNFORM-105）
**平台**：iOS
**指派**：iOS 开发者
**估算**：5 SP（~2.5 天）
**原 Sprint 1 ID**：RUNFORM-105

**用户故事**：
作为 iOS 跑者，我希望在跑步时实时看到当前步频（SPM），并且数值准确（误差 ≤ ±2 SPM）。

**验收标准**：
- [ ] 新建 `CadenceCalculator.swift`
- [ ] 算法输入：`AsyncStream<SensorFrame>`（加速度计 Z 轴垂直分量）
- [ ] 低通滤波：Butterworth 2nd-order，cutoff=3Hz（滤除高频噪声）
- [ ] 峰值检测：自适应阈值（最近 2 秒窗口均值的 1.2 倍），最小峰值间隔 200ms
- [ ] 滑动窗口：5 秒窗口，峰值数 × 12 = 步频（SPM）
- [ ] 算法输出：`AsyncStream<CadenceUpdate>`（spm: Double, confidence: Double, timestamp: Date）
- [ ] 手动击掌 180bpm 验证步频准确性（误差 ≤ ±2 SPM）
- [ ] 与视频 PoseExtractor 步频结果对比验证（同一次跑步录视频 + 传感器）
- [ ] XCTest 单元测试：正弦波模拟输入 → CadenceCalculator → 验证输出 SPM
- [ ] 使用 Accelerate 框架进行向量化信号处理（性能优化）

**依赖项**：RF-500（CoreMotionManager）
**风险**：中。腰包固定方式引入的噪声是最大不确定因素，需在真实跑步场景验证。

---

### RF-502 · iOS CoreMotion Phase 2 — 垂直振幅 + 触地时间（RunningMetricsCalculator）

**优先级**：P0
**类型**：新功能（原 RUNFORM-106）
**平台**：iOS
**指派**：iOS 开发者
**估算**：5 SP（~2.5 天）
**原 Sprint 1 ID**：RUNFORM-106

**用户故事**：
作为 iOS 跑者，我希望在跑步时获取垂直振幅（cm）和触地时间（ms）数据，这两个指标是跑步经济性的核心衡量。

**验收标准**：
- [ ] 新建 `RunningMetricsCalculator.swift`
- [ ] 垂直振幅算法：Z 轴加速度双重积分（加速度 → 速度 → 位移），高通滤波去漂移
- [ ] 触地时间算法：合成加速度范数 ‖a‖ = sqrt(x²+y²+z²) 的谷值检测
  - 阈值：‖a‖ < 0.7g → 触地期，> 1.1g → 腾空期
  - GCT（Ground Contact Time）= 触地期持续时间（ms）
- [ ] 步幅估算：from pace（可选 CoreLocation GPS）÷ cadence
- [ ] 算法输出：`AsyncStream<RunningMetrics>`（verticalOscillationCm, groundContactTimeMs, strideLengthM, timestamp）
- [ ] 垂直振幅验证：跑步时数值在 3-13cm 范围（运动生物力学文献参考）
- [ ] 触地时间验证：慢跑时数值在 200-300ms 范围
- [ ] XCTest 单元测试：模拟加速度数据 → 验证输出合理范围

**依赖项**：RF-500（CoreMotionManager）、RF-501（CadenceCalculator，提供步频给步幅估算）
**风险**：中。双重积分漂移是经典难题，高通滤波参数需反复调优。建议先实现，标记为「实验性」指标。

---

### RF-503 · iOS CoreMotion Phase 3 — 姿态特征提取（MotionPostureExtractor）

**优先级**：P0
**类型**：新功能（原 RUNFORM-107）
**平台**：iOS
**指派**：iOS 开发者
**估算**：8 SP（~4 天）
**原 Sprint 1 ID**：RUNFORM-107

**用户故事**：
作为 iOS 跑者，我希望跑步时 App 能感知我的躯干前倾角度，并在姿态异常（前倾 > 20°）时收到提醒。

**验收标准**：
- [ ] 新建 `MotionPostureExtractor.swift`
- [ ] 传感器融合：加速度计（tilt）+ 陀螺仪（angular velocity）→ Madgwick 滤波器 → 四元数 → Pitch/Roll/Yaw
- [ ] 跑步阶段识别：
  - 触地瞬间：Z 轴加速度峰值 + Pitch 极小值
  - 蹬伸期：Pitch 增大 + Yaw 旋转
  - 腾空期：‖a‖ ≈ 0g
- [ ] 躯干前倾：低频 Pitch 分量（cutoff 0.5Hz），输出 `trunkLeanDegrees`
- [ ] 骨盆旋转：Yaw 震荡幅度
- [ ] 左右对称性：Roll 标准差对比
- [ ] 算法输出：`AsyncStream<MotionPosture>`（pitchMean, pitchRange, rollAsymmetry, yawOscillation, gaitPhase, confidence）
- [ ] 验证：站立时 Pitch ≈ 0° ± 3°
- [ ] 跑步机验证：躯干前倾在 5-15° 范围
- [ ] XCTest 单元测试：已知姿态的模拟传感器数据 → 验证四元数解算精度

**依赖项**：RF-500（CoreMotionManager）
**风险**：高。传感器融合算法（Madgwick）实现复杂，且手机在腰包中的坐标系与躯干坐标系存在偏差。建议 Phase 3 先输出 Pitch 原始值，躯干倾角标记为「实验性」。

---

### RF-504 · iOS CoreMotion Phase 4 — 实时语音教练（AudioCoachManager）

**优先级**：P0
**类型**：新功能（原 RUNFORM-112 + 语音集成）
**平台**：iOS
**指派**：iOS 开发者
**估算**：5 SP（~2.5 天）

**用户故事**：
作为 iOS 跑者，我希望在跑步中通过耳机听到实时语音指导（如「步频偏低，试着加快到 170」），而不需要看手机屏幕。

**验收标准**：
- [ ] 新建 `AudioCoachManager.swift`（Sprint 1 已有框架骨架，本次完整实现）
- [ ] 订阅 `CadenceUpdate` stream：步频 < 160 SPM 持续 10 秒 → 「步频偏低，试着加快节奏到每分钟 170 步」
- [ ] 订阅 `MotionPosture` stream：躯干前倾 > 20° 持续 3 秒 → 「注意挺直躯干，你有点前倾了」
- [ ] 使用 AVSpeechSynthesizer + Ting-Ting 中文语音包（`com.apple.ttsbundle.Tingting-compact`）
- [ ] 多语言支持：中文（zh-Hans）、英文（en）、荷兰语（nl）三套提示文案
- [ ] 防抖逻辑：同类型提示间隔 ≥ 15 秒，单次跑步最多 5 条语音提示
- [ ] 打断策略：新的高优先级提示可打断低优先级播放（`AVSpeechSynthesizerDelegate`）
- [ ] 节拍器模式（可选）：根据目标步频播放节拍音（`AVAudioPlayer` + 音频文件）
- [ ] 后台音频播放：启用 `UIBackgroundModes: audio`
- [ ] 中文 TTS 语音清晰可辨识，人工验收 ≥ 4/5

**依赖项**：RF-501（CadenceCalculator）、RF-503（MotionPostureExtractor）
**风险**：中。AVSpeechSynthesizer 在后台播放的行为需验证；中文 TTS 自然度是用户体验关键，Ting-Ting 语音包为保底方案。

---

### RF-505 · iOS RunSession 管线整合 + 跑步会话 View

**优先级**：P0
**类型**：新功能（原 RUNFORM-110 + 111 + 113）
**平台**：iOS
**指派**：iOS 开发者
**估算**：8 SP（~4 天）

**用户故事**：
作为 iOS 跑者，我希望打开 App 点击「开始跑步」后，进入一个简洁的跑步界面，看到实时步频、跑步时长，跑完后自动生成姿态总结报告。

**验收标准**：
- [ ] 新建 `RunSessionManager.swift`：统一会话生命周期 `start → running → paused → stopped → saved`
- [ ] 管线编排：
  ```
  CoreMotionManager
    ├── CadenceCalculator → CadenceUpdate
    ├── RunningMetricsCalculator → RunningMetrics
    ├── MotionPostureExtractor → MotionPosture
    └── AudioCoachManager ← 订阅上述流
  ```
- [ ] 新建 `RunSessionView.swift`：实时步频大字显示 + 迷你波形图（Swift Charts）+ 语音提示气泡
- [ ] 后台跑步支持：启用 `HKWorkoutSession` + `HKLiveWorkoutBuilder` 保持后台活跃（iOS 16+）
- [ ] 数据持久化：`RunSession` → Core Data（需先迁移 UserDefaults → Core Data，或复用现有 JSON 存储）
- [ ] 跑步结束后自动跳转总结页面：总时长、平均步频、平均垂直振幅、平均触地时间、躯干倾角趋势图
- [ ] 总结页面显示「步频评级」（优秀 170-180 / 良好 160-170 / 需改进 < 160）
- [ ] 总结页面可保存到历史记录，复用现有 `HistoryView` + `HistoryTrendComponents`
- [ ] 跑步历史支持「实时跑步」会话类型标识
- [ ] 端到端测试：打开 App → 开始跑步 → 10 分钟跑步 → 停止 → 查看摘要 → 历史列表可见
- [ ] 压力测试：30 分钟连续采集 + 计算 + 语音，无内存泄漏（Instruments Leaks）
- [ ] 后台测试：锁屏后持续采集 10 分钟不中断

**依赖项**：RF-500 ~ RF-504（全部 Phase 0-4）
**风险**：高。`HKWorkoutSession` 后台保活是关键路径，需真机验证；Core Data 迁移如时间不足可先用 UserDefaults JSON 过渡。

---

## 五、Android Sensor API 管线（对标 iOS CoreMotion）

### 5.1 管线对比

| 维度 | iOS | Android |
|------|-----|---------|
| 传感器框架 | CMMotionManager | SensorManager |
| 数据流抽象 | AsyncStream<SensorFrame> | Flow<SensorFrame> (Kotlin) |
| 采样率 | 100Hz | SENSOR_DELAY_GAME (~50Hz, 20ms) |
| 后台保活 | HKWorkoutSession | ForegroundService + 通知栏 |
| 语音合成 | AVSpeechSynthesizer | TextToSpeech (系统默认 / 讯飞) |
| UI 框架 | SwiftUI + Swift Charts | Jetpack Compose + Canvas/Vico |

---

### RF-600 · Android SensorManager 采集 + SensorFusionProcessor

**优先级**：P0
**类型**：新功能
**平台**：Android
**指派**：Android 开发者
**估算**：5 SP（~2.5 天）

**用户故事**：
作为 Android 跑者，我希望能通过手机传感器实时采集跑步数据，为步频计算和姿态分析提供数据基础。

**验收标准**：
- [ ] 新建 `sensor/RunningSensorManager.kt`：封装 `SensorManager` 生命周期
- [ ] 注册 `TYPE_ACCELEROMETER`（SENSOR_DELAY_GAME，~50Hz）+ `TYPE_GYROSCOPE`（可选）
- [ ] `Flow<SensorFrame>` 数据流发射（三轴加速度 + 三轴陀螺仪 + 时间戳）
- [ ] 新建 `sensor/SensorFusionProcessor.kt`：低通滤波（α=0.8，cutoff ~3.5Hz）
- [ ] `AndroidManifest.xml` 新增权限：`BODY_SENSORS`、`FOREGROUND_SERVICE`、`POST_NOTIFICATIONS`
- [ ] 验证：加速度计数据正确回调，`onSensorChanged` 在 SENSOR_DELAY_GAME 下稳定输出
- [ ] 单元测试：SensorFusionProcessor 滤波正确性（JUnit5 + 模拟 SensorEvent）

**依赖项**：RF-210（Hilt DI，已完成），需注入 `@Singleton SensorManager`
**风险**：中。Android 13+ `BODY_SENSORS_BACKGROUND` 需运行时权限请求；国产 ROM（华为/小米/OPPO）后台限制严格。

---

### RF-601 · Android CadenceDetector — 步频实时计算

**优先级**：P0
**类型**：新功能
**平台**：Android
**指派**：Android 开发者
**估算**：3 SP（~1.5 天）

**用户故事**：
作为 Android 跑者，我希望跑步时实时看到当前步频，与 iOS 版体验一致。

**验收标准**：
- [ ] 新建 `sensor/CadenceDetector.kt`
- [ ] 算法：滑动窗口峰值检测（窗口 500ms，加速度幅值 `sqrt(x²+y²+z²)`）
- [ ] 峰值阈值：1.2× 当前窗口均值，最小峰值间距 250ms（最大步频 240 SPM）
- [ ] 实时步频 = 60 /（最近两次峰值间隔_秒）
- [ ] 输出：`Flow<CadenceUpdate>`（spm: Float, confidence: Float, timestamp: Long）
- [ ] 验证：跑步机上 160/170/180 SPM 三种步频，检测误差 < ±5 SPM
- [ ] 单元测试：模拟加速度波形 → 验证 CadenceDetector 输出

**依赖项**：RF-600（RunningSensorManager）
**风险**：低。算法与 iOS CadenceCalculator 同构，差异仅在传感器采样率（50Hz vs 100Hz）。

---

### RF-602 · Android RunningMetrics — 垂直振幅 + 触地时间

**优先级**：P1
**类型**：新功能
**平台**：Android
**指派**：Android 开发者
**估算**：5 SP（~2.5 天）

**用户故事**：
作为 Android 跑者，我希望获取垂直振幅和触地时间数据，对标 iOS 体验。

**验收标准**：
- [ ] 新建 `sensor/RunningMetricsCalculator.kt`
- [ ] 垂直振幅：Z 轴双重积分 + 高通滤波去漂移
- [ ] 触地时间：合成加速度范数谷值检测（‖a‖ < 0.7g → 触地期）
- [ ] 步幅估算：步频 + 身高推算
- [ ] 输出：`Flow<RunningMetrics>`
- [ ] 验证：慢跑时垂直振幅 3-13cm，触地时间 200-300ms
- [ ] 单元测试：模拟加速度数据 → 输出验证

**依赖项**：RF-600（RunningSensorManager）、RF-601（CadenceDetector）
**风险**：中。双重积分漂移在 50Hz 采样率下更显著，可能需要更激进的高通滤波参数。

---

### RF-603 · Android TextToSpeech 实时语音教练引擎

**优先级**：P0
**类型**：新功能
**平台**：Android
**指派**：Android 开发者
**估算**：5 SP（~2.5 天）

**用户故事**：
作为 Android 跑者，我希望跑步时通过耳机听到语音提示，不用看屏幕就能获得步频和姿态反馈。

**验收标准**：
- [ ] 新建 `tts/CoachingTtsEngine.kt`：封装 `android.speech.tts.TextToSpeech`
- [ ] 新建 `tts/CoachingCueGenerator.kt`：指标 → 提示文案（中英文，参考 iOS 文案）
- [ ] TTS 触发策略（对标 iOS AudioCoachManager）：
  - 步频 < 160 SPM 持续 10s → 「步频偏低，试着加快节奏」
  - 步频 > 200 SPM 持续 10s → 「步频过快，试着放慢节奏」
  - 躯干前倾 > 15° 持续 3s → 「注意保持躯干直立」
- [ ] 防抖：同类型提示 ≥ 30 秒冷却，单次跑步最多 5 条
- [ ] TTS 引擎降级策略：系统默认 TTS → 检查中文语音包可用性 → 无语音包时提示用户安装
- [ ] i18n 覆盖：中文（zh）/ 英文（en）/ 荷兰语（nl）（复用 Sprint 1 RF-204 strings.xml）
- [ ] 单元测试：CoachingCueGenerator 输入输出验证

**依赖项**：RF-601（CadenceDetector）、RF-204（i18n，已完成）
**风险**：中。国产设备系统默认 TTS 引擎不一致（部分无中文语音包），后续需评估讯飞 SDK。

---

### RF-604 · Android RunningForegroundService — 后台跑步服务

**优先级**：P0
**类型**：新功能
**平台**：Android
**指派**：Android 开发者
**估算**：5 SP（~2.5 天）

**用户故事**：
作为 Android 跑者，我希望锁屏后传感器和语音教练继续工作，不会因为 App 进入后台而中断。

**验收标准**：
- [ ] 新建 `service/RunningForegroundService.kt`：继承 `Service`（或 `LifecycleService`）
- [ ] 通知栏常驻：显示跑步时长 + 当前步频 + 「停止跑步」操作
- [ ] 通知渠道：`RUNNING_SESSION`（importance=low，不打扰用户）
- [ ] 服务中启动 `RunningSensorManager` + `CoachingTtsEngine`
- [ ] 前台服务类型：`FOREGROUND_SERVICE_TYPE_DATA_SYNC`（Android 14+）
- [ ] `RunningForegroundService` 通过 Hilt 注入（`@AndroidEntryPoint`）
- [ ] 生命周期绑定：`RunSessionManager` 启动/绑定服务，跑步结束 → `stopSelf()`
- [ ] 验证：华为/小米/OPPO 设备上锁屏后采集不中断（引导用户加白名单）
- [ ] 通知栏操作测试：点击「停止跑步」→ 结束服务 + 跳转总结页

**依赖项**：RF-600（RunningSensorManager）、RF-603（CoachingTtsEngine）、RF-210（Hilt DI，已完成）
**风险**：高。国产 ROM 后台限制是 Android 生态最大痛点，需真机验证至少 3 台主流设备（小米/华为/OPPO）。

---

### RF-605 · Android LiveRunningDashboard — 跑步实时仪表盘 UI

**优先级**：P0
**类型**：新功能
**平台**：Android
**指派**：Android 开发者
**估算**：3 SP（~1.5 天）

**用户故事**：
作为 Android 跑者，我希望在跑步时看到一个简洁美观的实时仪表盘，展示步频、跑步时长和配速。

**验收标准**：
- [ ] 新建 `ui/LiveRunningDashboard.kt`（Jetpack Compose）
- [ ] 实时步频大字显示（数字 + 单位 SPM，动态颜色：绿 170-180 / 黄 160-170 / 红 <160）
- [ ] 跑步时长计时器（MM:SS 格式）
- [ ] 迷你折线图：最近 30 秒步频趋势（Canvas 绘制，复用 Sprint 1 RF-202 风格）
- [ ] 语音提示气泡：最新一条语音提示简短显示 2 秒后消失
- [ ] 「暂停」/「停止」按钮
- [ ] 采集 `Flow<CadenceUpdate>` + `Flow<Timestamp>` → Compose State
- [ ] UI 测试：模拟 Flow 数据 → 验证 UI 渲染

**依赖项**：RF-601（CadenceDetector）
**风险**：低。纯 Compose UI 工作，Sprint 1 已积累丰富的 Compose 经验。

---

## 六、Android Sprint 1 收尾条目

### RF-214 · Android R8 混淆 + Keystore 签名配置

**优先级**：P1
**类型**：基础设施（Sprint 1 结转）
**平台**：Android
**指派**：Android 开发者
**估算**：3 SP（~1.5 天）

**验收标准**（与 Sprint 1 一致）：
- [ ] `app/build.gradle.kts`：`isMinifyEnabled = true`（release）、`proguardFiles`
- [ ] `proguard-rules.pro`：保留 Retrofit/Gson 数据类、Compose 类、Hilt 类
- [ ] 生成 upload keystore（`.jks`），CI 用环境变量注入
- [ ] 签名配置：`signingConfigs` 区分 debug/release
- [ ] 验证：release APK 可安装、运行、API 调用正常

---

### RF-215 · Android Firebase Crashlytics + Analytics 接入

**优先级**：P2
**类型**：基础设施（Sprint 1 结转）
**平台**：Android
**指派**：Android 开发者
**估算**：3 SP（~1.5 天）

**验收标准**（与 Sprint 1 一致）：
- [ ] 接入 Firebase Crashlytics + Analytics SDK
- [ ] `google-services.json` 配置（需 PM/后端 提供）
- [ ] 基础埋点：`screen_view`, `analyze_video`, `run_session_started`, `run_session_completed`
- [ ] 非致命异常手动上报
- [ ] 验证：Firebase Console 可看到测试设备的崩溃报告和事件

---

### RF-209 · Android 实时录制引导（LiveGuidance Camera Overlay）

**优先级**：P2
**类型**：功能对齐（Sprint 1 结转）
**平台**：Android
**指派**：Android 开发者
**估算**：5 SP（~2.5 天）

**验收标准**（与 Sprint 1 一致）：
- [ ] 新建 `LiveGuidanceRecorderScreen.kt`：CameraX + ML Kit Pose Detection 实时骨骼线叠加
- [ ] 录制前检测：全身是否在画面内 → 提示「请后退/靠近」
- [ ] 骨骼线绘制覆盖在 CameraX PreviewView 上（Canvas overlay）
- [ ] 录制按钮 + 计时器叠加
- [ ] 录制完成后自动进入分析流程

**风险**：ML Kit 实时推理性能需验证（低端设备可能掉帧）。

---

## 七、后端支撑

### RF-700 · 后端实时跑步会话 API（POST/GET /run-sessions）

**优先级**：P0
**类型**：新功能
**平台**：后端
**指派**：后端开发
**估算**：5 SP（~2.5 天）

**用户故事**：
作为 iOS/Android 客户端，我需要后端提供跑步会话持久化 API，以便在跑步结束后将传感器数据上传存储，并跨设备查看历史跑步记录。

**验收标准**：
- [ ] 新建 `POST /api/v1/run-sessions` 接口
- [ ] 请求体：`RunSessionSubmitRequest`（user_id, session_id, start_time, end_time, duration_seconds, metrics_summary, location_data, device_info）
- [ ] `metrics_summary` 结构体：
  ```
  {
    avg_cadence_spm: float,
    max_cadence_spm: float,
    avg_vertical_oscillation_cm: float,
    avg_ground_contact_time_ms: float,
    avg_trunk_lean_degrees: float,
    cadence_rating: str,       // "excellent" | "good" | "needs_work"
    posture_rating: str,
    total_steps: int,
  }
  ```
- [ ] 新建 `GET /api/v1/run-sessions?user_id=X&limit=50&offset=0` 接口
- [ ] 新建 `GET /api/v1/run-sessions/{session_id}` 接口：返回单次跑步详情
- [ ] 数据库新增 `run_sessions` 表：`id`, `user_id`, `session_id`, `start_time`, `end_time`, `duration_seconds`, `metrics_summary`（JSONB）, `location_data`（JSONB）, `device_info`（JSONB）, `created_at`
- [ ] Alembic 迁移脚本
- [ ] pytest 测试：CRUD 全套 + 无效参数 + 缺失字段
- [ ] 性能要求：写入 < 200ms，查询（50条）< 300ms

**依赖项**：无
**风险**：低。

---

### RF-701 · 后端跑步指标数据模型 + DB 迁移

**优先级**：P0
**类型**：基础设施
**平台**：后端
**指派**：后端开发
**估算**：3 SP（~1.5 天）

**用户故事**：
作为后端开发者，我需要定义跑步会话的数据模型和数据库表结构，确保与 iOS/Android 客户端模型对齐。

**验收标准**：
- [ ] 在 `schemas.py` 中新增 Pydantic 模型：
  - `RunSessionSubmitRequest`
  - `RunSessionSummaryResponse`
  - `RunSessionDetailResponse`
  - `RunSessionListItem`
  - `RunMetricsSummary`（嵌套模型）
- [ ] 在 `db_models.py` 中新增 SQLAlchemy 模型：`RunSession`
- [ ] Alembic 迁移脚本：`20260516_add_run_sessions_table.py`
- [ ] 字段与 iOS `RunSessionSummary` 对齐确认
- [ ] pytest 模型验证测试

**依赖项**：无
**风险**：低。需与 iOS 开发者确认 `RunSessionSummary` 数据结构。

---

### RF-702 · 后端跑步趋势聚合 API（GET /run-trends）

**优先级**：P1
**类型**：新功能
**平台**：后端
**指派**：后端开发
**估算**：5 SP（~2.5 天）

**用户故事**：
作为 iOS/Android 客户端，我需要后端提供跑步历史趋势聚合数据，以便绘制多指标趋势图（比客户端本地聚合更可靠，支持跨设备）。

**验收标准**：
- [ ] 新建 `GET /api/v1/run-trends?user_id=X&metrics=cadence,vertical_oscillation,gct&limit=30`
- [ ] 返回最近 N 次跑步的指定指标趋势数据
- [ ] 响应格式：`{ trends: [{ session_id, date, cadence_spm, vertical_oscillation_cm, gct_ms, ... }] }`
- [ ] 聚合逻辑在 SQL 层完成（GROUP BY + JSONB 字段提取）
- [ ] pytest 测试：正常查询 + 无数据 + 无效指标名
- [ ] 性能要求：30 条聚合 < 200ms

**依赖项**：RF-700（Run Sessions API）、RF-701（数据模型）
**风险**：低。

---

### RF-703 · 后端跑步会话对比 API（POST /compare-sessions）

**优先级**：P1
**类型**：新功能
**平台**：后端
**指派**：后端开发
**估算**：5 SP（~2.5 天）

**用户故事**：
作为跑者，我希望比较任意两次跑步会话的指标，了解进步或退步。

**验收标准**：
- [ ] 新建 `POST /api/v1/compare-sessions` 接口
- [ ] 请求体：`{ user_id, session_id_1, session_id_2 }`
- [ ] 响应：两次会话的所有指标并排对比 + 差异值 + 变化趋势（↑/↓/→）
- [ ] 响应增加 coaching_narrative：针对变化给出训练建议（如「步频提升 5 SPM，继续保持」）
- [ ] pytest 测试：正常对比 + 无效 session_id + 跨用户对比（应拒绝）
- [ ] 性能要求：对比计算 < 300ms

**依赖项**：RF-700（Run Sessions API）
**风险**：低。与现有 `/compare` 接口架构类似，可复用。

---

## 八、QA 全平台回归

### RF-800 · QA 全平台回归测试计划 + 执行

**优先级**：P0
**类型**：质量保障
**平台**：全平台
**指派**：QA 工程师
**估算**：8 SP（~4 天）

**用户故事**：
作为 QA 工程师，我需要在 Sprint 2 新功能上线前执行全平台回归测试，确保 Sprint 1 功能对齐成果不被破坏，Sprint 2 新功能符合验收标准。

**验收标准**：
- [ ] 制定回归测试计划：覆盖 iOS / Android / WeChat / 后端 四个平台
- [ ] iOS 回归测试：
  - 视频录制 → PoseExtractor 分析 → AnalysisResultView（确保未回归）
  - 训练计划生成 → 马拉松/比赛计划
  - 精英对比 → 历史对比 → 自定义对比
  - 用户反馈评分
  - 历史记录 + 趋势图表
  - **[新增]** CoreMotion Phase 0-4 验收标准逐条验证（M1-AC1~AC6, M2-AC1~AC4, M3-AC1~AC4）
  - **[新增]** RunSession 端到端测试
- [ ] Android 回归测试：
  - Sprint 1 全部 13 项功能回归（Compare / 训练增强 / 趋势图表 / i18n / 反馈 / 视频压缩 / 分享）
  - **[新增]** Sensor API 管线验收（RF-600~605）
  - **[新增]** R8 混淆后 Release APK 冒烟测试
  - **[新增]** Crashlytics 上报验证
- [ ] WeChat 回归测试：
  - Sprint 1 全部 9 项功能回归
- [ ] 后端回归测试：
  - 全部现有 API 端点冒烟（/analyze, /analyze-metrics, /training-plan, /compare, /athletes, /feedback, Strava 系列）
  - **[新增]** /run-sessions CRUD + /run-trends + /compare-sessions
- [ ] Bug 汇总 + 优先级分类 → GitHub Issues

**依赖项**：全部 P0 条目完成后执行
**风险**：中。全平台回归工作量大，需排定优先级，核心路径优先保障。

---

### RF-801 · CI 测试门禁强化（iOS + Android + 后端）

**优先级**：P1
**类型**：CI/CD
**平台**：CI
**指派**：QA 工程师
**估算**：5 SP（~2.5 天）

**用户故事**：
作为团队，我希望每次 PR 自动触发测试，确保新代码不引入回归。

**验收标准**：
- [ ] iOS CI 测试门禁：`.github/workflows/ios-test.yml`
  - PR 触发 `xcodebuild test`（XCTest + 所有 Phase 0-4 测试）
  - SwiftLint 检查
- [ ] Android CI 测试门禁：`.github/workflows/android-test.yml`
  - PR 触发 `./gradlew testDebugUnitTest`
  - ktlint 或 detekt 检查（可选）
- [ ] 后端 CI 强化：现有 `backend-test.yml` 增加 `/run-sessions` 端点测试
- [ ] 测试失败时 PR 不允许合并（branch protection rule）
- [ ] 验证：提交一个故意失败的测试 → CI 红灯

**依赖项**：RF-404（后端 CI，已完成）、RF-403（iOS XCTest，已完成）、RF-212（Android 测试框架，已完成）
**风险**：低。

---

### RF-802 · iOS CoreMotion 管线专项测试（精度/功耗/后台）

**优先级**：P0
**类型**：质量保障
**平台**：iOS
**指派**：QA 工程师
**估算**：5 SP（~2.5 天）

**用户故事**：
作为 QA 工程师，我需要专项验证 CoreMotion 管线的精度、功耗和后台稳定性，这些是用户满意度的关键。

**验收标准**：
- [ ] 步频精度测试：3 人 × 跑步机 160/170/180 SPM × 各 3 分钟，验证误差 ≤ ±3 SPM
- [ ] 垂直振幅合理性：3 人慢跑，采集振幅值在 3-13cm 范围
- [ ] 触地时间合理性：3 人慢跑，GCT 在 200-300ms 范围
- [ ] 躯干角度验证：站立时 Pitch ≈ 0° ± 3°，跑步时 5-15°
- [ ] 功耗测试：30 分钟连续跑步，电池消耗 < 15%（iPhone 14 基准）
- [ ] 后台稳定性：锁屏跑步 10 分钟，数据连续无断流
- [ ] 内存泄漏检测：30 分钟持续运行，Instruments Leaks 零报告
- [ ] 语音提示时机验证：步频 < 160 持续 10s → 提示触发时间偏差 < 2s
- [ ] 汇总测试报告 → 产品文档

**依赖项**：RF-500 ~ RF-505（全部 Phase）
**风险**：中。真机测试需至少 2 台 iPhone（14/15），跑步机接入取决于设备可用性。

---

## 九、依赖关系图

```
┌─────────────────────────────────────────────────────────────────┐
│                        Sprint 2 依赖关系图                       │
└─────────────────────────────────────────────────────────────────┘

iOS 管线：
  RF-500 (CoreMotionManager)
    ├── RF-501 (CadenceCalculator)
    │     ├── RF-504 (AudioCoachManager)
    │     └── RF-502 (RunningMetricsCalculator) ──┐
    ├── RF-503 (MotionPostureExtractor)            │
    │     └── RF-504 (AudioCoachManager)           │
    └── RF-505 (RunSession 整合) ◄── RF-501+502+503+504

Android 管线：
  RF-600 (RunningSensorManager)
    ├── RF-601 (CadenceDetector)
    │     ├── RF-603 (CoachingTtsEngine)
    │     ├── RF-602 (RunningMetricsCalculator)
    │     └── RF-604 (RunningForegroundService) ◄── RF-600+603
    └── RF-605 (LiveRunningDashboard) ◄── RF-601

Android 收尾：
  RF-214 (R8/Keystore)    ← 无依赖，可并行
  RF-215 (Crashlytics)    ← 无依赖，可并行
  RF-209 (LiveGuidance)   ← 无依赖，可并行

后端：
  RF-701 (数据模型)       ← 无依赖
    └── RF-700 (Run Sessions API)
          ├── RF-702 (Run Trends API)
          └── RF-703 (Compare Sessions API)

QA：
  RF-802 (CoreMotion 专项测试) ◄── RF-500~505
  RF-800 (全平台回归)          ◄── 全部 P0 完成
  RF-801 (CI 门禁强化)         ◄── RF-500~505 (iOS tests) + RF-600~605 (Android tests)

跨团队依赖：
  RF-505 (iOS RunSession)     → RF-700 (后端 Sessions API)  [数据模型对齐]
  RF-604 (Android Foreground) → RF-700 (后端 Sessions API)  [数据模型对齐]
  RF-505 (iOS RunSession)     → RF-800 (QA 回归)            [端到端验证]
```

---

## 十、估算（SP）+ 排期

### 10.1 团队配置

| 角色 | 人数 | Sprint 2 总 SP | 备注 |
|------|------|----------------|------|
| iOS 开发者 | 1 | 36 SP | CoreMotion Phase 0-4 + RunSession |
| Android 开发者 | 1 | 37 SP | Sensor API + 收尾条目 |
| 后端开发 | 1 | 18 SP | Sessions API + Trends + Compare |
| QA 工程师 | 1 | 18 SP | 回归 + CI + 专项测试 |

### 10.2 四周排期

```
Week 1 (5/26-5/30):  基础设施 + Phase 0-1 启动

  iOS:
    Day 1-3:  RF-500 (CoreMotionManager + DebugView)    ← Phase 0
    Day 3-5:  RF-501 (CadenceCalculator)                ← Phase 1 启动

  Android:
    Day 1-3:  RF-600 (RunningSensorManager + Fusion)    ← Sensor 采集
    Day 3-5:  RF-601 (CadenceDetector)                  ← 步频检测
    Day 3-5:  RF-214 (R8/Keystore) 并行                  ← 收尾

  后端:
    Day 1-3:  RF-701 (数据模型 + DB 迁移)               ← 模型先行
    Day 3-5:  RF-700 (Run Sessions API)                 ← API 启动

  QA:
    Day 1-5:  RF-800 回归测试计划编写                    ← 计划先行

Week 2 (6/2-6/6):  核心算法攻坚

  iOS:
    Day 6-8:  RF-501 (CadenceCalculator 收尾)           ← Phase 1 完成
    Day 6-10: RF-502 (RunningMetricsCalculator)         ← Phase 2

  Android:
    Day 6-8:  RF-603 (CoachingTtsEngine)                ← TTS 引擎
    Day 6-10: RF-602 (RunningMetricsCalculator)          ← 对标 iOS Phase 2
    Day 8-10: RF-604 (RunningForegroundService)          ← 后台服务

  后端:
    Day 6-8:  RF-700 (Run Sessions API 收尾)            ← API 完成
    Day 8-10: RF-702 (Run Trends API)                   ← 趋势 API

  QA:
    Day 6-10: RF-800 回归测试执行（Sprint 1 功能）      ← 启动回归

Week 3 (6/9-6/13):  姿态 + 语音 + 整合

  iOS:
    Day 11-14: RF-503 (MotionPostureExtractor)          ← Phase 3
    Day 13-15: RF-504 (AudioCoachManager)               ← Phase 4 启动

  Android:
    Day 11-13: RF-604 (ForegroundService 收尾)          ← 后台完成
    Day 13-15: RF-605 (LiveRunningDashboard)            ← UI 仪表盘
    Day 13-15: RF-215 (Crashlytics) 并行                  ← 收尾

  后端:
    Day 11-13: RF-703 (Compare Sessions API)            ← 对比 API
    Day 13-15: 后端集成测试 + 文档                        ← 收尾

  QA:
    Day 11-15: RF-800 回归测试执行（Sprint 2 新功能）   ← 新功能测试
    Day 13-15: RF-802 (CoreMotion 专项测试) 启动        ← 专项测试

Week 4 (6/16-6/20):  收尾 + 缓冲

  iOS:
    Day 16-19: RF-505 (RunSession 管线整合)             ← Phase 5
    Day 19-20: Bug 修复 + 缓冲                            ← 收尾

  Android:
    Day 16-18: RF-209 (LiveGuidance) 如有余力             ← P2
    Day 18-20: Bug 修复 + 缓冲                            ← 收尾

  后端:
    Day 16-20: Bug 修复 + API 文档完善                     ← 收尾

  QA:
    Day 16-18: RF-802 (CoreMotion 专项测试) 收尾        ← 专项完成
    Day 18-20: RF-801 (CI 门禁强化)                      ← CI 收尾
    Day 20:    Sprint 2 Review Demo                     ← 全平台演示
```

### 10.3 关键里程碑

| 里程碑 | 时间 | 内容 |
|--------|------|------|
| **M1** | Week 1 末 (5/30) | iOS Phase 0-1 完成（传感器采集 + 步频），Android Sensor + Cadence 完成，后端 Sessions API 完成 |
| **M2** | Week 2 末 (6/6) | iOS Phase 2 完成（振幅 + GCT），Android TTS + Foreground 完成，后端 Trends API 完成 |
| **M3** | Week 3 末 (6/13) | iOS Phase 3-4 完成（姿态 + 语音），Android Dashboard 完成，QA 回归测试主体完成 |
| **M4** | Week 4 末 (6/20) | iOS Phase 5 完成（端到端跑步会话），QA 专项测试 + CI 门禁完成，Sprint Review |

---

## 十一、暂停项清单

以下条目在 Sprint 2 中明确暂停：

| ID | 标题 | 暂停原因 | 恢复条件 |
|----|------|----------|----------|
| **RF-205** | Android Strava OAuth 集成 | CEO 指令暂停 — 聚焦 CoreMotion 核心创新，Strava 非差异化功能 | Sprint 3 CEO 重新评估 |
| — | iOS Strava 增强（同步训练数据到跑步会话） | 同上，Strava 全平台冻结 | Sprint 3 |
| — | WeChat 步频模式（wx.onAccelerometerChange） | WeChat 平台限制（无后台采集），且微信用户群与跑步实时教练场景匹配度低 | Sprint 3 评估可行性 |
| — | Apple Watch 独立 App | v1 PRD 明确列为 Could Have（v2），且 iPhone-first 策略优先 | v2 规划 |
| — | 跑步视频 + IMU 数据融合分析 | v1 PRD Could Have（C3），双管线独立跑通后再融合 | v2 规划 |
| **RF-209** | Android 实时录制引导（Camera Overlay） | P2 优先级，Sprint 2 仅在 Week 4 有余力时处理 | 如 Week 4 无时间则转入 Sprint 3 |

---

## 十二、Definition of Done（Sprint 2 完成定义）

- [ ] iOS CoreMotion Phase 0-4 全部交付，步频误差 ≤ ±3 SPM，语音提示验收 ≥ 4/5
- [ ] iOS RunSession 端到端跑步会话可正常完成（开始 → 跑步 → 停止 → 总结 → 保存历史）
- [ ] Android Sensor API 管线交付：步频检测 + TTS 语音提示 + 前台服务
- [ ] Android LiveRunningDashboard 可用
- [ ] Android R8 混淆 + Keystore 签名就绪，Release APK 可安装运行
- [ ] 后端 Run Sessions CRUD API + Run Trends API 就绪
- [ ] QA 全平台回归测试通过（Sprint 1 功能零回归，Sprint 2 新功能验收通过）
- [ ] iOS CoreMotion 专项测试（精度/功耗/后台）报告出炉
- [ ] CI 测试门禁覆盖 iOS + Android + 后端
- [ ] 全部 P0 条目代码 Review 通过
- [ ] **Sprint Review Demo**：iOS 跑者实时跑步 5 分钟 → 语音教练提示 → 结束总结报告；Android 跑步仪表盘展示

---

## 十三、风险与缓解

| # | 风险 | 影响条目 | 概率 | 缓解措施 |
|---|------|---------|------|----------|
| R1 | **iOS 后台挂起导致数据断流** | RF-505 | 高 | 必须启用 HKWorkoutSession；锁屏测试 Week 1 就开始；如不可行降级为「屏幕常亮」模式 |
| R2 | **Android 国产 ROM 后台限制** | RF-604 | 高 | 前台服务 + 通知栏常驻；引导用户加白名单（小米自启动/华为受保护应用）；至少 3 台真机验证 |
| R3 | **传感器精度不达标（腰包噪声）** | RF-501/502/503 | 中 | 腰包固定方式在 Week 1 验证；如精度不足降低指标要求或提示用户使用紧身腰包 |
| R4 | **双重积分漂移导致垂直振幅不准** | RF-502/602 | 中 | 先实现并标记为「实验性」功能；与视频 PoseExtractor 交叉验证后校准 |
| R5 | **Android TTS 中文语音包缺失** | RF-603 | 中 | 先走系统默认 TTS；检测语音包可用性；引导用户安装 Google TTS；后续评估讯飞 SDK |
| R6 | **CoreMotion 开发阻塞 Android 并行进度** | 全局 | 低 | iOS/Android 管线独立并行，仅在后端 API 对齐点需要协调；Android 可先做 UI + 服务框架 |
| R7 | **iOS 开发者被 RunSession 整合复杂度卡住** | RF-505 | 中 | Phase 5 预留 4 天 + Week 4 缓冲；优先交付 Phase 0-4 核心，Phase 5 可降级为最小可用版本 |
| R8 | **全平台回归测试工作量超预期** | RF-800 | 中 | 优先核心路径（视频分析 + 跑步会话）；非核心功能（分享/反馈）降低回归深度 |

---

> **文档版本**：v1.0
> **创建者**：Hermes Agent（基于 v1-prd.md / sprint-1-revised-backlog.md / ios-developer.md / android-developer.md 综合制定）
> **下一步**：CEO 审批 Sprint 2 Backlog → Sprint Planning 确认指派人 → 创建 GitHub Issues → Week 1 启动
