# iOS 开发者 Sprint 0 入职文档

> RunForm iOS — Swift/SwiftUI 跑步姿态分析与训练计划应用  
> 编写日期: 2026-05-13 | 作者: Hermes Agent (代码审查)  
> 代码库路径: `~/workspace/runform/ios/RunFormCoachAI/`

---

## 一、本周目标 (This-Week Goal)

**规划 CoreMotion 实时姿态采集管线**：评审现有代码架构，确定传感器数据流的架构方案（Combine vs AsyncSequence）、确定 iOS 最低版本策略、输出可分阶段执行的 CoreMotion PoC（概念验证）计划。不要求本周写代码——输出为架构决策文档 + 可执行的阶段计划。

同时建立 Xcode 工程基础设施：将零散的 Swift 源文件组织为正式的 `.xcodeproj` + `project.yml` 配置，补充缺失的 Info.plist 权限声明。

---

## 二、交付物 (Deliverables)

### 2.1 技术债清单（按优先级排序）

| 优先级 | 问题 | 影响 | 建议方案 |
|--------|------|------|----------|
| **P0** | 无 Xcode 工程文件 — 仅有 35 个 `.swift` 源文件散落，无 `.xcodeproj` 或 `project.yml` | 新开发者无法打开/编译项目，CI 不可用 | 用 XcodeGen 生成 `project.yml`，版本控制纳入仓库 |
| **P0** | Info.plist 缺少 CoreMotion 权限声明 (`NSMotionUsageDescription`) | 无法调用 CMMotionManager，任何传感器功能不可用 | 添加 `NSMotionUsageDescription` 键值 |
| **P0** | 零测试覆盖 — 整个 `ios/` 目录无 `*Test*.swift`、无 XCTest target | 重构/新增传感器管线时无安全网 | Sprint 1 建立 XCTest + XCUITest target，至少覆盖 PoseExtractor 和 CoreMotion pipeline |
| **P1** | 无 CoreMotion 代码 — 传感器数据采集完全缺失，这是 Sprint 0 核心 GAP | 当前仅支持视频后处理分析，无实时跑步姿态反馈 | 见 2.3 CoreMotion PoC 计划 |
| **P1** | 无 HealthKit 集成 — 无步频、心率读写 | 无法与 Apple Health 数据互通 | Info.plist 添加 `NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription`，规划 HealthKitManager |
| **P1** | 无实时音频反馈 (`AVSpeechSynthesizer` / 音频播放) | 跑步中无法获取语音指导 | 规划 AudioFeedbackManager，Swift concurrency 线程模型 |
| **P1** | 无 Apple Watch 扩展 | 无法监测腕上步频/震动反馈 | Sprint 2+ 评估 Watch-only target |
| **P2** | AppStore 使用 UserDefaults 存储全部状态（包含 history JSON blob） | 分析历史增长后启动卡顿、数据丢失风险 | 迁移到 Core Data 或 SwiftData |
| **P2** | APIClient 硬编码 fallback URL + fatalError 崩溃 | 配置错误时崩溃而非优雅降级 | 改为可选 URL + UI 错误提示 |
| **P2** | PoseExtractor 单文件 810 行，包含信号处理函数混杂其中 | 维护困难，难以单独测试 | 拆分: `PoseExtractor.swift` (Vision) + `SignalProcessing.swift` (信号算法) |
| **P2** | URLSession 无缓存/重试策略，timeout 硬编码 | 弱网环境下体验差 | 引入 URLSession 配置 + 重试逻辑 |
| **P3** | 多语言本地化已有 3 套 `.lproj` (en/nl/zh-Hans)，但 LocalizedStringKey 混用 | 部分文本硬编码英文 | 审计全部 UI 文本 → Localizable.strings |
| **P3** | 无 App 图标规范 — AppIcon 资源仅一套尺寸且不完整 | App Store 提审可能被拒 | 补充完整 App Icon 尺寸链 |

---

### 2.2 文件结构地图与依赖关系

```
RunFormCoachAI/
│
├── RunFormCoachAIApp.swift          # @main 入口, WindowGroup → ContentView
├── AppStore.swift                   # @MainActor ObservableObject, 全局状态 (profile/history/plans/Strava)
├── AppTheme.swift                   # 深色主题色彩/渐变/共用背景组件
├── ContentView.swift                # 主 TabView (Analyze/History/Plan/Profile), 视频选择→分析流程
│
├── ── 分析管线 ──
│   ├── PoseExtractor.swift          # Vision 姿态提取 (810行): 21项生物力学指标计算
│   │   └── 内部: FramePose, JointPoint, 信号处理 (smooth/countPeaks/pearsonCorrelation/...) 
│   ├── AnalysisModels.swift         # AnalysisResponse, PoseMetrics (68字段), Metric, Issue, Exercise
│   ├── AnalysisResultView.swift     # 分析结果展示: 分数卡/指标列表/问题+训练建议
│   ├── CompareModels.swift          # AthleteListItem, MetricComparison, CompareRequest/Response
│   ├── AthleteRowView.swift         # 精英运动员选择行
│   ├── CompareView.swift            # 对比入口视图
│   ├── CompareResultView.swift      # 对比结果视图
│   ├── CompareHistoryView.swift     # 历史对比视图
│   └── CustomCompareResultView.swift# 自定义对比结果
│
├── ── 视频采集 ──
│   ├── VideoPicker.swift            # PHPickerViewController 封装 (相册选视频)
│   └── LiveGuidanceRecorderView.swift # AVCaptureSession 实时录制 + Vision 实时人体检测引导 (444行)
│       └── 内置: LiveGuidanceRecorderController, CameraPreview, PreviewView
│
├── ── 训练计划 ──
│   ├── PlanModels.swift             # TrainingTarget/Level/MarathonMajor 枚举, FormIssueContext, 计划结构体
│   ├── PlanBuilderView.swift        # 训练计划生成 UI (912行: 周计划/马拉松/比赛计划)
│   ├── TrainingPlanResultView.swift # 计划结果展示
│   ├── SavedPlanViews.swift         # 已保存计划列表
│   ├── WorkoutCardViews.swift       # 训练卡片视图组件
│   ├── ManualNextWeekPlanEditorView.swift # 手动编辑下周计划
│   ├── MarathonPlanDetailView.swift # 马拉松计划详情
│   └── RacePlanDetailView.swift     # 比赛计划详情
│
├── ── 历史 & 反馈 ──
│   ├── HistoryView.swift            # 分析历史列表
│   ├── HistoryDetailView.swift      # 单条历史详情
│   ├── HistoryTrendComponents.swift # 趋势图组件
│   └── FeedbackView.swift           # 用户反馈评分 (Tester Feedback)
│
├── ── 用户 & Strava ──
│   ├── ProfileModels.swift          # TesterProfile, RunnerLevel, ProfileGender
│   ├── ProfileView.swift            # 个人资料页
│   ├── ProfileFormFields.swift      # 表单字段组件
│   ├── ProfileStravaCard.swift      # Strava 连接状态卡片
│   ├── StravaModels.swift           # Strava OAuth/Status/Disconnect/Sync/Activity 模型
│   └── StravaPresentationContext.swift # Strava WebView 上下文
│
├── ── 网络 & 基础 ──
│   ├── APIClient.swift              # 后端API: analyzeMetrics, training-plan, Strava CRUD, profile, athletes, compare
│   └── UIComponents.swift           # GlassCard/DarkCard/IconBubble/StatusBadge/SectionTitle/GradientButtonStyle...
│
├── ── 本地化 ──
│   ├── en.lproj/Localizable.strings
│   ├── nl.lproj/Localizable.strings
│   └── zh-Hans.lproj/Localizable.strings
│
├── Info.plist                       # 当前仅有 NSCameraUsageDescription + NSPhotoLibraryUsageDescription + Strava URL scheme
└── Assets.xcassets/                 # AppIcon (部分尺寸), AccentColor
```

**依赖关系图（简化）**:

```
RunFormCoachAIApp
  └── ContentView (TabView)
        ├── [Analyze] → VideoPicker / LiveGuidanceRecorderView
        │     → PoseExtractor (本地Vision)
        │     → APIClient.analyzeMetrics()
        │     → AnalysisResultView → CompareView
        │     → FeedbackView
        ├── [History] → HistoryView → HistoryDetailView
        ├── [Plan] → PlanBuilderView → APIClient.generateTrainingPlan()
        └── [Profile] → ProfileView → APIClient.saveProfile()
                    → ProfileStravaCard → APIClient (Strava连接状态)

共享层: AppStore (ObservableObject, @MainActor), AppTheme, APIClient (URLSession)
分析管线: PoseExtractor → PoseMetrics → APIClient → AnalysisResponse
```

---

### 2.3 CoreMotion 实时姿态采集 PoC 计划

#### 目标

将现有「视频拍摄 → 后处理分析」的单次模式扩展为「跑步过程中实时传感器采集 → 实时步频/姿态指标计算」的持续模式。最终实现：用户跑步时，iPhone 放在腰包/臂带中，通过加速度计+陀螺仪实时计算步频、垂直振幅、触地时间等跑步指标。

#### 架构选型（待 CEO 决策，见第四节）

以下方案假设选择 **AsyncSequence (Swift Concurrency)** 作为传感器数据流抽象。

#### Phase 0: 基础传感器采集 + 原始数据验证 (1-2天)

**文件**: `CoreMotionManager.swift` (新建)

```
内容:
- CMMotionManager 封装: startAccelerometerUpdates / startGyroUpdates
- AsyncStream<SensorFrame> 数据流 (三轴加速度 + 三轴陀螺仪 + 时间戳)
- 配置: updateInterval = 100Hz (10ms), 后台队列处理, 主线程仅更新UI
- 采样频率自适应 (省电模式 50Hz, 精度模式 200Hz)
- FIFO 环形缓冲区 (RingBuffer<SensorFrame>, capacity=600, ~6秒窗口)

验证:
- 写一个 DebugView 显示原始加速度波形 (Swift Charts x:时间 y:m/s²)
- 将设备绑在腰间慢跑 30 秒，确认三轴数据连续无丢帧
- 功耗测试: 100Hz 持续采集 5 分钟，电池消耗 < 3%
```

#### Phase 1: 步频实时计算 (2-3天)

**依赖**: Phase 0

**文件**: `CadenceCalculator.swift` (新建)

```
算法:
- 输入: AsyncStream<SensorFrame> (加速度计 Z 轴垂直分量)
- 低通滤波: Butterworth 2nd-order, cutoff=3Hz (滤除高频噪声)
- 峰值检测: 自适应阈值 (最近2秒窗口均值的1.2倍), 最小峰值间隔 200ms
- 滑动窗口: 5秒窗口, 峰值数 × 12 = 步频 (SPM)
- 输出: AsyncStream<CadenceUpdate> (spm: Double, confidence: Double, timestamp)

验证:
- 手动击掌 180bpm 验证步频准确性 (误差 < ±2 SPM)
- 与视频 PoseExtractor 步频结果对比 (同一次跑步录视频+传感器)
- 单元测试: 正弦波模拟输入 → CadenceCalculator → 验证输出
```

#### Phase 2: 垂直振幅 + 触地时间估算 (2-3天)

**依赖**: Phase 0, Phase 1

**文件**: `RunningMetricsCalculator.swift` (新建)

```
算法:
- 垂直振幅: Z轴加速度双重积分 (加速度→速度→位移), 高通滤波去漂移
- 触地时间: 合成加速度范数 ‖a‖ = sqrt(x²+y²+z²) 的谷值检测
  - 阈值: ‖a‖ < 0.7g → 触地期, > 1.1g → 腾空期
  - GCT (Ground Contact Time) = 触地期持续时间
- 步幅估算: from pace (可选 GPS/CoreLocation) ÷ cadence
- 输出: AsyncStream<RunningMetrics>

验证:
- 与 Garmin/Apple Watch 跑步数据对比 (垂直振幅、触地时间)
- 与运动生物力学文献参考值对比
```

#### Phase 3: 姿态特征提取 (3-5天)

**依赖**: Phase 0

**文件**: `MotionPostureExtractor.swift` (新建)

```
算法:
- 传感器融合: 加速度计 (tilt) + 陀螺仪 (angular velocity) → 
  互补滤波器/Madgwick 滤波器 → 四元数 → Pitch/Roll/Yaw
- 跑步阶段识别: 
  - 触地瞬间: Z轴加速度峰值 + Pitch极小值
  - 蹬伸期: Pitch增大 + Yaw旋转
  - 腾空期: ‖a‖ ≈ 0g
- 躯干前倾: 低频Pitch分量 (cutoff 0.5Hz)
- 骨盆旋转: Yaw震荡幅度
- 左右对称性: Roll标准差对比

输出: AsyncStream<MotionPosture>
  - pitchMean, pitchRange, rollAsymmetry, yawOscillation
  - 步相标签 (stance/swing/flight)
  - 置信度

验证:
- 在跑步机上拍摄同步视频，Vision分析 vs 传感器分析对比
- 人工标注 100 步的步相标签，与算法输出计算准确率 (>85%)
```

#### Phase 4: 实时语音反馈 (2-3天)

**依赖**: Phase 1, Phase 2

**文件**: `AudioCoachManager.swift` (新建)

```
功能:
- 监控 CadenceUpdate stream: 步频 < 160 → "Pick up your cadence"
- 监控垂直振荡 > 阈值 → "Try to run lighter, less bounce"
- AVSpeechSynthesizer 中文/英文语音合成
- 节拍器 (Metronome): 根据目标步频播放节拍音 (AVAudioPlayer)
- 防抖逻辑: 同类型提示间隔 ≥ 15秒, 本次跑步最多 5 条语音提示
- 打断策略: 新的高优先级提示可打断低优先级播放 (AVSpeechSynthesizerDelegate)

验证:
- 模拟跑步场景播放验证语音时机正确
- 后台播放测试 (App 进入后台时继续音频)
```

#### Phase 5: 管线整合 + 跑步会话管理 (3-4天)

**依赖**: Phase 0-4

**文件**: `RunSessionManager.swift` (新建), `RunSessionView.swift` (新建)

```
功能:
- 统一会话生命周期: start → running → paused → stopped → saved
- 管线编排:
  CoreMotionManager
    ├── CadenceCalculator → CadenceUpdate
    ├── RunningMetricsCalculator → RunningMetrics
    ├── MotionPostureExtractor → MotionPosture
    └── AudioCoachManager ← 订阅上述流
- 数据持久化: RunSession → JSON/CoreData, 包含原始 SensorFrame 采样
- 会话摘要: 结束时生成 RunSessionSummary (平均步频/振幅/GCT/姿态评分)
- UI: RunSessionView (实时步频大字显示 + 迷你波形图 + 语音提示气泡)

验证:
- 端到端: 打开 App → 开始跑步会话 → 10分钟跑步 → 查看摘要
- 压力测试: 30分钟连续采集 + 计算 + 语音, 无内存泄漏
- 后台测试: 锁屏后持续采集 (需 Background Modes: location/gymkit)
```

---

## 三、风险 (Risks)

### 风险 1: 传感器精度不足 — 腰包/臂带固定方式导致数据噪声

- **严重程度**: 高
- **描述**: iPhone 放在腰包中跑步时，设备晃动、布料缓冲、旋转偏移会引入大量噪声。Z轴加速度与真正的垂直方向存在偏差（设备坐标系 ≠ 世界坐标系）。100Hz 采样下原始数据信噪比可能 < 10dB。
- **缓解措施**: 
  - Phase 3 的传感器融合算法（互补滤波/Madgwick）可部分解决
  - 要求用户尽量用紧身腰包，减少晃动
  - 实施信号质量自检：连续 5 秒方差过大 → 提示"请确保手机固定在腰间"
  - 备选方案：支持 Apple Watch 传感器（Watch 绑在手腕上更稳定）

### 风险 2: 后台运行限制 — iOS 挂起应用导致数据断流

- **严重程度**: 高
- **描述**: iOS 在屏幕锁定后约 30 秒会挂起前台应用。跑步场景中用户通常锁屏 → CoreMotion 停止回调。即使启用 Background Modes，系统也可能在内存压力下终止进程。
- **缓解措施**:
  - 必须启用 Background Mode: `location` (GPS后台) 或 `workout-processing` (HealthKit 运动会话)
  - HKWorkoutSession + HKLiveWorkoutBuilder 可保持后台活跃
  - 实现断点续跑：挂起前的传感器数据全部保存，恢复后平滑衔接
  - App 被 kill 后的恢复策略（从已持久化的 RunSession 恢复）
  - 注：纯 CoreMotion 后台不依赖 HealthKit 的方案不可行（Apple 明确限制）

### 风险 3: PoseExtractor 算法复用度低 — 视频姿态分析算法无法直接用于传感器

- **严重程度**: 中
- **描述**: 现有 PoseExtractor (810行) 的全部算法基于 Vision 2D 关键点坐标（x,y 归一化图像坐标），计算的是关节角度、距离、对称性。而 CoreMotion 输出的是三轴加速度/角速度（物理量: m/s², rad/s），完全不同的数据维度。所有指标需从零实现传感器版本。
- **缓解措施**:
  - 保留视频分析作为"精准模式"（较高精度、需要录像），传感器模式作为"便捷模式"（实时、粗略但持续）
  - 将两个管线的 Metrics 模型统一为同一个 `PoseMetrics` 输出接口
  - 先实现 3-4 个核心指标（步频、垂直振幅、触地时间、躯干倾角），逐步扩展

### 风险 4: 实时语音反馈用户体验 — 过度打扰 vs 反馈不足的平衡

- **严重程度**: 中
- **描述**: 语音提示频率过高（"步频偏低"每 5 秒一次）会让用户反感，频率过低则失去 coaching 价值。中文 TTS 在节拍器节奏下可能刺耳。
- **缓解措施**:
  - 防抖逻辑（15秒最小间隔）+ 每次跑步上限 5 条
  - 可配置提示频率（"安静模式"仅节拍器 / "教练模式"语音+节拍器）
  - 使用高质量 TTS 语音 (AVSpeechSynthesisVoice(identifier: "com.apple.ttsbundle.Tingting-compact"))

### 风险 5: 功耗与发热 — 100Hz 持续采样 + Vision 处理的高能耗

- **严重程度**: 中
- **描述**: 100Hz 加速度计+陀螺仪 + 实时信号处理 + 可能的 Vision on-device 分析 → 持续高 CPU 占用 → 设备发热、电池快速消耗。
- **缓解措施**:
  - Phase 0 验证功耗基线
  - 动态采样率（检测到跑步状态 → 100Hz；静止/走路 → 25Hz 或暂停）
  - 使用 Accelerate 框架进行向量化信号处理（比 Swift for-loop 快 10-50x）
  - 5 分钟跑步功耗目标 < 5% 电池

---

## 四、需要 CEO 决策的事项

以下决策直接影响架构方向，请在 Sprint 0 第一周内给出明确答复：

| # | 决策事项 | 选项 A | 选项 B | 推荐 | 理由 |
|---|---------|--------|--------|------|------|
| 1 | **iOS 最低支持版本** | **iOS 16.0** | iOS 17.0 | ✅ **A: iOS 16** | 覆盖 95%+ 活跃设备。iOS 17 的 SwiftData/Observation 框架更优但会排除 iPhone X/8 用户。跑步用户多为中端设备，覆盖面优先 |
| 2 | **Swift 版本 / Swift 6 并发检查** | **Swift 5.9+ (保守)** | Swift 6.0 (严格并发) | ✅ **A: Swift 5.9** | 现有代码使用 Swift Concurrency (async/await) 但未启用严格并发检查。Swift 6 需要标注所有 Sendable 类型，迁移成本高且目前无并发 bug。Sprint 3+ 再评估 |
| 3 | **传感器管线: Combine vs AsyncSequence** | **AsyncSequence (AsyncStream)** | Combine (PassthroughSubject) | ✅ **A: AsyncSequence** | 现有代码已全部使用 async/await 模式，没有 Combine 依赖。AsyncStream 原生、轻量、取消管理清晰。Combine 引入额外依赖且随着 SwiftUI 演进官方重心向 Observation/AsyncSequence 倾斜 |
| 4 | **后台跑步方案: HealthKit vs CoreLocation** | **HealthKit (HKWorkoutSession)** | CoreLocation (GPS后台) | ✅ **A: HealthKit** | 跑步自然需要 HealthKit 记录运动数据，且 HKWorkoutSession 专门为此设计。GPS 后台会增加功耗且用户可能不授权位置 |
| 5 | **数据持久化: Core Data vs SwiftData vs 文件** | **Core Data** | SwiftData (需 iOS 17) | ✅ **A: Core Data** | iOS 16 兼容。SwiftData 仍在快速迭代中（每年 WWDC 大改），稳定生产环境选 Core Data。后续可渐进迁移 |
| 6 | **手表扩展优先级: 同步 vs 异步** | **iPhone-first**（手表作为远程传感器） | Watch-first（手表独立采集） | ✅ **A: iPhone-first** | Sprint 0-2 先完善 iPhone 传感器管线。手表扩展为 Sprint 4+ 任务。手表独立采集需要独立 processing 管线，开发量翻倍 |
| 7 | **中文语音教练的语音偏好** | **系统 TTS (AVSpeechSynthesizer)** | 预录音频 + 节拍器音效 | 取决于品牌调性 | 系统 TTS 灵活（任意文字合成）、零制作成本，但音色机械。预录音频更自然但内容固定，无法动态生成。建议 Phase 4 先用 TTS，后续录制品牌语音包 |
| 8 | **CoreMotion 指标范围: MVP vs 完整** | **MVP: 步频 + 垂直振幅 + 触地时间** (3指标) | 完整: 15+指标 (对标 PoseExtractor) | ✅ **A: MVP** | Sprint 0-1 聚焦核心价值。PoseExtractor 的 21 项指标从视频获得，传感器版本需要独立算法研发每个指标，先做可交付的最小集合 |

---

## 五、工程基础搭建 (Sprint 0 同步进行)

以下任务可在等待 CEO 决策的同时并行启动：

1. **创建 XcodeGen project.yml** — 定义 targets: RunFormCoachAI (iOS), RunFormCoachAITests (Unit), RunFormCoachAIUITests (UI)
2. **Info.plist 补充权限声明**:
   - `NSMotionUsageDescription` — "RunForm uses motion sensors to analyze your running form in real time."
   - `NSHealthShareUsageDescription` — "RunForm syncs running metrics with Apple Health."
   - `NSHealthUpdateUsageDescription` — "RunForm saves cadence and running metrics to Apple Health."
   - `UIBackgroundModes` — `location`, `audio` (预留), `processing` (预留)
3. **SwiftLint 配置** — `.swiftlint.yml` 基础规则集
4. **.gitignore** — 添加 Xcode 生成文件 (`*.xcuserdata`, `DerivedData/`, `*.xcworkspace/xcuserdata/`)

---

## 六、关键联系人 & 参考

- **后端 API 文档**: 代码中 APIClient.swift 自我注解完整（endpoint + request/response 结构体）
- **姿态分析算法论文**: PoseExtractor 的算法注释详细（步频多信号融合、过步幅、膝外翻、头部前倾等）
- **Apple 参考**:
  - [CMMotionManager Documentation](https://developer.apple.com/documentation/coremotion/cmmotionmanager)
  - [HKWorkoutSession Documentation](https://developer.apple.com/documentation/healthkit/hkworkoutsession)
  - [Creating an AsyncSequence from CMMotionManager updates](https://developer.apple.com/documentation/swift/asyncstream)
  - [Accelerate framework for signal processing](https://developer.apple.com/documentation/accelerate)

---

*本文档为 Sprint 0 启动文档。所有 Phase 计划为建议路径，具体排期和资源分配待 Sprint Planning 确认。*
