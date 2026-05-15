# RunForm Sprint 1 Backlog

> Sprint 1：2026-05-19 ~ 2026-05-30（双周）
> Sprint 目标：交付 CoreMotion Phase 0-3 核心管线 + iOS 工程基础设施 + QA/CI 测试框架
> CEO 决策依据：iOS 单点突破（决策1）、Phase 0-3 MVP（决策2）、QA 基础设施全面投入（决策3）
> 关联 PRD：`product/v1-prd.md`

---

## Sprint 1 目标（一句话）

**搭建 iOS 工程基础设施 + CoreMotion 实时姿态采集管线（步频 / 垂直振幅 / 触地时间 / 躯干倾角），建立 CI 自动化测试门禁，产出可 Demo 的传感器数据可视化验证界面。**

---

## Backlog 条目总览

| ID | 标题 | 指派 | SP | Phase | 依赖 |
|----|------|------|-----|-------|------|
| RUNFORM-100 | XcodeGen project.yml + Info.plist 权限声明 |  iOS 开发 | 3 | Foundation | 无 |
| RUNFORM-101 | SwiftLint 配置 + .gitignore 完善 | iOS 开发 | 2 | Foundation | 无 |
| RUNFORM-102 | XCTest 测试框架搭建 + PoseExtractor 首批单元测试 | iOS 开发 | 5 | Foundation | RUNFORM-100 |
| RUNFORM-103 | CoreMotionManager — 传感器数据采集管线 | iOS 开发 | 5 | Phase 0 | RUNFORM-100 |
| RUNFORM-104 | DebugView — 实时传感器加速度波形可视化 | iOS 开发 | 3 | Phase 0 | RUNFORM-103 |
| RUNFORM-105 | CadenceCalculator — 步频实时计算 | iOS 开发 | 8 | Phase 1 | RUNFORM-103 |
| RUNFORM-106 | RunningMetricsCalculator — 垂直振幅 + 触地时间估算 | iOS 开发 | 8 | Phase 2 | RUNFORM-103 |
| RUNFORM-107 | MotionPostureExtractor — 传感器融合 + 躯干倾角提取 | iOS 开发 | 8 | Phase 3 | RUNFORM-103 |
| RUNFORM-108 | iOS CI 测试流水线（XCTest 自动门禁 + Lint） | QA 工程师 | 3 | CI | RUNFORM-102 |
| RUNFORM-109 | 后端 CI 测试流水线（pytest + ruff） | QA / 后端 | 5 | CI | 无 |
| RUNFORM-110 | 后端实时跑步会话 API（session CRUD） | 后端开发 | 5 | Backend | 无 |
| RUNFORM-111 | 跑步会话数据模型定义（PoseMetrics 兼容层） | iOS + 后端 | 3 | Backend | RUNFORM-103 |
| RUNFORM-112 | v1 语音提示文案模板 + 中文本地化初稿 | 产品经理 | 2 | Content | 无 |
| RUNFORM-113 | Sprint 1 Demo 准备（端到端：传感器采集 → 指标计算 → 可视化） | iOS 开发 | 2 | Integration | RUNFORM-103~107 |

**总计**：13 个条目，62 SP
- iOS 开发：10 个条目，47 SP
- QA 工程师：2 个条目，8 SP
- 后端开发：2 个条目，7 SP（与 QA 共享 RUNFORM-109）
- 产品经理：1 个条目，2 SP

---

## 详细条目

### RUNFORM-100 · XcodeGen project.yml + Info.plist 权限声明

**优先级**：P0
**类型**：工程基础设施
**平台**：iOS
**指派**：iOS 开发者（engineering-ios-developer）
**估算**：3 SP（~1.5 天）

**用户故事**：
作为 iOS 开发者，我希望项目有标准的 Xcode 工程文件和完整的权限声明，以便团队能统一编译环境和 CI 能自动构建。

**验收标准**：
- [ ] `project.yml` 包含主 target `RunFormCoachAI`（sources: `ios/RunFormCoachAI/`）
- [ ] `project.yml` 包含单元测试 target `RunFormCoachAITests`（bundle.unit-test）
- [ ] `project.yml` 包含 UI 测试 target `RunFormCoachAIUITests`（bundle.ui-testing）
- [ ] `Info.plist` 新增 `NSMotionUsageDescription`：描述 RunForm 使用运动传感器分析跑步姿态
- [ ] `Info.plist` 新增 `NSHealthShareUsageDescription` + `NSHealthUpdateUsageDescription`
- [ ] `Info.plist` 新增 `UIBackgroundModes`：`location`、`audio`
- [ ] `xcodebuild -project RunFormCoachAI.xcodeproj -list` 显示三个 target
- [ ] 在 iPhone 16 Simulator 上编译通过（Debug 配置）

**依赖项**：无
**风险**：低。XcodeGen 语法标准，工程已在 iOS Staging CI 中使用

---

### RUNFORM-101 · SwiftLint 配置 + .gitignore 完善

**优先级**：P1
**类型**：工程基础设施
**平台**：iOS
**指派**：iOS 开发者（engineering-ios-developer）
**估算**：2 SP（~1 天）

**用户故事**：
作为团队，我们希望代码风格统一、自动检查基本规则，以便 Code Review 集中在逻辑层面而非格式问题。

**验收标准**：
- [ ] 仓库根目录创建 `.swiftlint.yml`：禁用 `trailing_whitespace`，启用 `empty_count`、`missing_docs`，行宽限制 140，文件长度限制 1000
- [ ] `swiftlint lint --strict` 在现有 35 个 `.swift` 文件上通过（允许少量 warning，不允许 error）
- [ ] `.gitignore` 新增：`*.xcuserdata`、`DerivedData/`、`*.xcworkspace/xcuserdata/`、`.swiftpm/`
- [ ] `.swiftlint.yml` 纳入版本控制

**依赖项**：无
**风险**：低。现有代码可能需要少量 SwiftLint 适配

---

### RUNFORM-102 · XCTest 测试框架搭建 + PoseExtractor 首批单元测试

**优先级**：P0
**类型**：测试基础设施
**平台**：iOS
**指派**：iOS 开发者（engineering-ios-developer）
**估算**：5 SP（~2.5 天）

**用户故事**：
作为 iOS 开发者，我希望有 XCTest 测试框架和首批单元测试，以便后续 CoreMotion 管线开发有安全网，防止回归。

**验收标准**：
- [ ] `ios/RunFormCoachAITests/` 目录创建，包含首个测试文件 `PoseExtractorTests.swift`
- [ ] `ios/RunFormCoachAIUITests/` 目录创建（占位），待 Sprint 2 填充
- [ ] `PoseExtractorTests` 至少覆盖 5 个纯函数：`smooth()`、`countPeaks()`、`pearsonCorrelation()`、`calculateCadence()`、`detectFootStrike()`
- [ ] `PoseExtractorTests` 中每个函数至少 3 个测试用例（正常值、边界值、异常值）
- [ ] `xcodebuild test -scheme RunFormCoachAI -destination 'platform=iOS Simulator,name=iPhone 16'` 全绿通过
- [ ] 测试文件路径符合 `project.yml` 中 `RunFormCoachAITests` target 的 sources 配置

**依赖项**：RUNFORM-100（需要 XCTest target 在 project.yml 中定义）
**风险**：中。PoseExtractor 810 行代码，部分函数与 Vision 框架耦合，需设计 mock/stub

---

### RUNFORM-103 · CoreMotionManager — 传感器数据采集管线

**优先级**：P0
**类型**：新功能（CoreMotion Phase 0）
**平台**：iOS
**指派**：iOS 开发者（engineering-ios-developer）
**估算**：5 SP（~2.5 天）

**用户故事**：
作为跑者，我希望 RunForm 在跑步时实时采集 iPhone 的运动传感器数据，以便后续计算我的步频和姿态。

**验收标准**：
- [ ] 新建 `CoreMotionManager.swift`，封装 `CMMotionManager`
- [ ] 实现 `AsyncStream<SensorFrame>` 数据流（100Hz 采样：加速度计 x/y/z + 陀螺仪 x/y/z + 时间戳）
- [ ] `SensorFrame` 结构体定义：`accelX/Y/Z: Double`、`gyroX/Y/Z: Double`、`timestamp: TimeInterval`
- [ ] 支持采样频率配置：默认 100Hz，省电模式 50Hz
- [ ] 实现 `RingBuffer<SensorFrame>`（capacity=600，~6 秒滑动窗口）
- [ ] `start()` / `stop()` 接口：启动/停止传感器采集
- [ ] 错误处理：设备不支持传感器时返回明确错误，不崩溃
- [ ] 单元测试：模拟 `CMMotionManager` 回调，验证 AsyncStream 输出帧率和数据完整性

**依赖项**：RUNFORM-100（需要 `NSMotionUsageDescription` 权限声明）
**风险**：中。需要真机验证，模拟器不支持 CoreMotion

---

### RUNFORM-104 · DebugView — 实时传感器加速度波形可视化

**优先级**：P1
**类型**：开发工具
**平台**：iOS
**指派**：iOS 开发者（engineering-ios-developer）
**估算**：3 SP（~1.5 天）

**用户故事**：
作为开发者和 QA，我希望有一个实时波形可视化界面来验证传感器数据质量，以便在算法开发前确认数据采集的完整性和噪声水平。

**验收标准**：
- [ ] 新建 `SensorDebugView.swift`，使用 Swift Charts 绘制三轴加速度波形
- [ ] X 轴为时间（最近 3 秒窗口），Y 轴为加速度（m/s²），三个颜色区分 x/y/z
- [ ] 实时刷新率 ≥ 30fps，无卡顿
- [ ] 显示当前帧率（Hz）和丢帧计数
- [ ] 支持「开始/停止采集」按钮
- [ ] 真机验证：手机绑在腰间慢跑 30 秒，波形连续无断点
- [ ] 功耗验证：100Hz 采集 5 分钟，电池消耗 < 3%

**依赖项**：RUNFORM-103（需要 `CoreMotionManager` 的 `AsyncStream<SensorFrame>` 输出）
**风险**：低。Swift Charts 在 iOS 16+ 上成熟稳定

---

### RUNFORM-105 · CadenceCalculator — 步频实时计算

**优先级**：P0
**类型**：新功能（CoreMotion Phase 1）
**平台**：iOS
**指派**：iOS 开发者（engineering-ios-developer）
**估算**：8 SP（~4 天）

**用户故事**：
作为跑者，我希望跑步时实时看到我的步频（SPM），以便知道是否达到理想步频（170-180 SPM）。

**验收标准**：
- [ ] 新建 `CadenceCalculator.swift`
- [ ] 输入：订阅 `AsyncStream<SensorFrame>`，提取 Z 轴加速度（垂直分量）
- [ ] 信号处理管线：Butterworth 二阶低通滤波（cutoff=3Hz）→ 自适应阈值峰值检测（最近 2 秒窗口均值 × 1.2）→ 最小峰值间隔 200ms
- [ ] 5 秒滑动窗口计数：峰值数 × 12 = 步频（SPM）
- [ ] 输出：`AsyncStream<CadenceUpdate>`，包含 `spm: Double`、`confidence: Double`、`timestamp: TimeInterval`
- [ ] 误差要求：手动击掌 180bpm → 显示 178-182 SPM（±2 SPM）
- [ ] 单元测试：正弦波（1.5Hz/2.5Hz/3.0Hz）模拟输入 → 验证输出步频 = 90/150/180 SPM ± 2
- [ ] 边界测试：零输入（无运动）→ 步频 = 0，置信度 = 0
- [ ] 性能测试：100Hz 输入流持续处理 5 分钟，CPU 占用 < 10%

**依赖项**：RUNFORM-103（需要 `CoreMotionManager` 的 `AsyncStream<SensorFrame>`）
**风险**：高。自适应阈值在真实跑步场景可能失效（步频变化、路面不平），需要真机验证迭代

---

### RUNFORM-106 · RunningMetricsCalculator — 垂直振幅 + 触地时间估算

**优先级**：P0
**类型**：新功能（CoreMotion Phase 2）
**平台**：iOS
**指派**：iOS 开发者（engineering-ios-developer）
**估算**：8 SP（~4 天）

**用户故事**：
作为跑者，我希望知道自己的垂直振幅和触地时间，以便减少不必要的上下弹跳和刹车效应，提高跑步经济性。

**验收标准**：
- [ ] 新建 `RunningMetricsCalculator.swift`
- [ ] 垂直振幅算法：Z 轴加速度双重积分（加速度 → 速度 → 位移），高通滤波（cutoff=0.5Hz）去除漂移
- [ ] 触地时间算法：合成加速度范数 ‖a‖ = √(x²+y²+z²)，谷值检测。阈值：‖a‖ < 0.7g → 触地期，> 1.1g → 腾空期。GCT = 触地期持续时间（ms）
- [ ] 输出：`AsyncStream<RunningMetrics>`，包含 `verticalOscillationCm: Double`、`groundContactTimeMs: Double`、`flightTimeMs: Double`、`strideLengthM: Double?`（基于步频+配速估算）
- [ ] 合理范围验证：垂直振幅慢跑 3-13cm，触地时间慢跑 200-300ms
- [ ] 与视频 PoseExtractor 对比：同步录制跑步视频 + 传感器采集，步频误差 ≤ ±3 SPM
- [ ] 单元测试：模拟正弦加速度信号（模拟弹跳）→ 验证积分结果
- [ ] 30 分钟连续采集无内存泄漏（Instruments Leaks 验证）

**依赖项**：RUNFORM-103（需要 `CoreMotionManager`）、RUNFORM-105（复用步频结果辅助触地时间验证）
**风险**：高。加速度双重积分的漂移问题是经典难点——高通滤波和零速更新（ZUPT）需要仔细调参

---

### RUNFORM-107 · MotionPostureExtractor — 传感器融合 + 躯干倾角提取

**优先级**：P0
**类型**：新功能（CoreMotion Phase 3）
**平台**：iOS
**指派**：iOS 开发者（engineering-ios-developer）
**估算**：8 SP（~4 天）

**用户故事**：
作为跑者，我希望跑步中感知躯干前倾角度，以便纠正前倾过度导致的腰背压力。

**验收标准**：
- [ ] 新建 `MotionPostureExtractor.swift`
- [ ] 传感器融合：加速度计（tilt）+ 陀螺仪（angular velocity）→ 互补滤波器 / Madgwick AHRS 算法 → 四元数 → Pitch/Roll/Yaw
- [ ] 躯干倾角提取：低频 Pitch 分量（cutoff=0.5Hz）→ `torsoAngleDeg: Double`
- [ ] 骨盆旋转幅度：Yaw 震荡标准差 → `pelvicRotationDeg: Double`
- [ ] 跑步阶段识别：触地瞬间（Z 加速度峰值 + Pitch 极小值）、腾空期（‖a‖ ≈ 0g）
- [ ] 输出：`AsyncStream<MotionPosture>`，包含 `pitchMean`、`pitchRange`、`rollAsymmetry`、`yawOscillation`、`phaseLabel: StancePhase`（stance/swing/flight）、`confidence`
- [ ] 精度验证：站直姿势 Pitch=0° ± 3°；跑步机上跑步 Pitch=5-15°
- [ ] 异常检测：躯干前倾 > 20° 或后仰 > 5° 持续 ≥ 3 秒 → 输出 `postureAlert: PostureAlertType`
- [ ] 单元测试：模拟静止/倾斜/跑步三种加速度+陀螺仪数据 → 验证 Pitch 输出

**依赖项**：RUNFORM-103（需要 `CoreMotionManager`）
**风险**：高。手机放腰包中的坐标系与人体坐标系存在偏移，传感器融合滤波器参数需要真机实测迭代调优

---

### RUNFORM-108 · iOS CI 测试流水线（XCTest 自动门禁 + Lint）

**优先级**：P0
**类型**：CI/CD
**平台**：iOS
**指派**：QA 工程师（qa-release-engineer）
**估算**：3 SP（~1.5 天）

**用户故事**：
作为团队，我希望每次 Push/PR 自动运行 XCTest 单元测试和 SwiftLint，以便在合并前发现回归和质量问题。

**验收标准**：
- [ ] 新建 `.github/workflows/ios-test.yml`
- [ ] 触发方式：`push` 和 `pull_request` 到任意分支
- [ ] 步骤 1：`swiftlint lint --strict`（warning 不阻止通过，error 阻止）
- [ ] 步骤 2：`xcodebuild test -scheme RunFormCoachAI -destination 'platform=iOS Simulator,name=iPhone 16' -configuration Debug`
- [ ] 测试失败时 PR 显示 ❌，阻止合并
- [ ] 在 `ios-build.yml` 和 `ios-staging.yml` 的 Archive 步骤前插入测试步骤，测试失败阻止上传 TestFlight

**依赖项**：RUNFORM-102（需要 XCTest target 和至少首个测试文件）
**风险**：低。Xcode 16 simulator 在 GitHub Actions macOS runner 上可用

---

### RUNFORM-109 · 后端 CI 测试流水线（pytest + ruff）

**优先级**：P0
**类型**：CI/CD
**平台**：后端
**指派**：QA 工程师 / 后端开发（共享）
**估算**：5 SP（~2.5 天）

**用户故事**：
作为团队，我希望后端 API 有自动化测试流水线，以便在每次部署前验证 API 可用性和正确性。

**验收标准**：
- [ ] 新建 `.github/workflows/backend-test.yml`
- [ ] 触发方式：`push` 和 `pull_request` 到任意分支
- [ ] 步骤 1：`pip install -r backend/requirements.txt`（含 pytest、httpx、ruff）
- [ ] 步骤 2：`ruff check backend/`（代码风格检查）
- [ ] 步骤 3：`cd backend && python -m pytest tests/ -v`
- [ ] 新建 `backend/tests/` 目录，含 `conftest.py`（async client fixture）
- [ ] 至少覆盖 5 个 API 端点：`GET /health`、`POST /analyze-metrics`、`POST /training-plan`、`PUT /profile`、`POST /compare`
- [ ] 每个端点覆盖：正常请求 200 + 错误请求 4xx + 边界输入

**依赖项**：无（后端代码库独立）
**风险**：低。pytest + FastAPI TestClient 成熟稳定

---

### RUNFORM-110 · 后端实时跑步会话 API（session CRUD）

**优先级**：P1
**类型**：新功能
**平台**：后端
**指派**：后端开发
**估算**：5 SP（~2.5 天）

**用户故事**：
作为 iOS 客户端，我需要后端提供跑步会话的持久化和查询 API，以便跑步结束后保存数据并在历史记录中查看。

**验收标准**：
- [ ] 数据库新增 `run_sessions` 表（字段：`id`、`user_id`、`start_time`、`end_time`、`duration_seconds`、`avg_cadence`、`avg_vertical_oscillation`、`avg_ground_contact_time`、`avg_torso_angle`、`sensor_data_json`、`created_at`）
- [ ] Alembic 迁移脚本：`add_run_sessions_table`
- [ ] `POST /api/v1/run-sessions`：创建跑步会话
- [ ] `PATCH /api/v1/run-sessions/{session_id}`：更新会话（跑步结束后写入聚合指标）
- [ ] `GET /api/v1/run-sessions?user_id={id}&limit=20&offset=0`：查询历史会话列表
- [ ] `GET /api/v1/run-sessions/{session_id}`：查询单次会话详情
- [ ] `DELETE /api/v1/run-sessions/{session_id}`：删除会话
- [ ] 单元测试（pytest）：覆盖全部 CRUD 操作（正常 + 错误路径）
- [ ] 响应格式与现有 API 保持一致（`{ "status": "ok", "data": {...} }`）

**依赖项**：RUNFORM-109（需要 pytest 测试框架就位）
**风险**：低。标准 CRUD API，FastAPI + SQLAlchemy 成熟

---

### RUNFORM-111 · 跑步会话数据模型定义（PoseMetrics 兼容层）

**优先级**：P1
**类型**：数据模型
**平台**：iOS + 后端
**指派**：iOS 开发者 + 后端开发（协作）
**估算**：3 SP（~1.5 天）

**用户故事**：
作为全栈开发者，我希望 CoreMotion 传感器管线产出的指标能复用现有的 PoseMetrics 模型和 AnalysisResultView 展示组件，以便跑步结束后直接利用已有的分析结果 UI。

**验收标准**：
- [ ] iOS 端定义 `RunSessionSummary` 结构体：聚合一次跑步的所有指标
- [ ] `RunSessionSummary` 包含 `toPoseMetrics()` 转换方法：将步频/垂直振幅/触地时间/躯干倾角映射到 `PoseMetrics` 的对应字段
- [ ] 映射规则文档化：传感器指标 → `PoseMetrics` 字段对照表
  - `avgCadence` → `PoseMetrics.cadence`
  - `verticalOscillationCm` → `PoseMetrics.verticalOscillation`
  - `groundContactTimeMs` → `PoseMetrics.groundContactTime`
  - `avgTorsoAngleDeg` → `PoseMetrics.trunkLean`
- [ ] 后端 `RunSession` Pydantic schema 与 iOS 端 `RunSessionSummary` 字段对应
- [ ] 端到端验证：iOS 模拟传感器数据 → 生成 RunSessionSummary → toPoseMetrics() → 传给 AnalysisResultView → 正确渲染

**依赖项**：RUNFORM-103（SensorFrame）、RUNFORM-110（后端 RunSession schema）
**风险**：低。主要是字段映射，需要 PM 确认映射规则

---

### RUNFORM-112 · v1 语音提示文案模板 + 中文本地化初稿

**优先级**：P1
**类型**：内容
**平台**：iOS
**指派**：产品经理（product-runform-manager）
**估算**：2 SP（~1 天）

**用户故事**：
作为产品经理，我希望 v1 语音提示文案提前准备好，以便 iOS 开发在 Sprint 2 实现 AudioCoachManager 时可以直接集成，无需等待文案。

**验收标准**：
- [ ] 文案模板覆盖 5 类提示场景，每类 3 条文案变体（避免重复感）：
  1. 步频偏低（< 160 SPM）：如「步频 155，偏低，试着加快小步快跑」
  2. 步频合格（160-180 SPM）：如「步频 172，不错，保持这个节奏」
  3. 躯干前倾（> 20°）：如「注意挺直躯干，你有点前倾了」
  4. 过大的垂直振幅（> 13cm）：如「试着跑得更轻一些，减少弹跳」
  5. 跑步结束鼓励：如「跑步完成！平均步频 168，有进步空间」
- [ ] 全部文案翻译为中文（简体，zh-Hans）和英文（en）
- [ ] 文案风格要求：温和鼓励（非命令式）、简短（≤ 15 字中文 / ≤ 12 词英文）、可操作（给出具体行动建议）
- [ ] 输出文件：`product/content/voice-coach-texts-v1.csv`（场景、中文、英文、优先级、冷却时间）
- [ ] 冷却时间定义：步频提示 ≥ 15 秒间隔，姿态提示 ≥ 30 秒间隔，单次跑步上限 5 条

**依赖项**：无
**风险**：低。内容产出，不涉及开发

---

### RUNFORM-113 · Sprint 1 Demo 准备（端到端集成验证）

**优先级**：P1
**类型**：集成
**平台**：iOS
**指派**：iOS 开发者（engineering-ios-developer）
**估算**：2 SP（~1 天）

**用户故事**：
作为团队，我希望 Sprint 1 结束时能 Demo CoreMotion Phase 0-3 的端到端管线，以便向 CEO 展示 CoreMotion MVP 的可行性和数据质量。

**验收标准**：
- [ ] 端到端流程可执行：启动 App → 开始跑步会话 → CoreMotionManager 采集数据 → CadenceCalculator 输出步频 → RunningMetricsCalculator 输出垂直振幅/触地时间 → MotionPostureExtractor 输出躯干倾角 → DebugView 实时展示所有指标
- [ ] DebugView 展示：步频大字显示 + 垂直振幅数值 + 触地时间数值 + 躯干倾角数值
- [ ] 准备 Demo 脚本：手机绑在腰间跑步 5 分钟，展示实时数据变化
- [ ] 验收会议时间：Sprint 1 最后一天（Day 10），参与人：CEO、产品经理、iOS 开发、QA
- [ ] Demo 检查清单：传感器不掉帧、步频随速度变化、振幅/触地时间在合理范围、躯干倾角有响应

**依赖项**：RUNFORM-103、RUNFORM-104、RUNFORM-105、RUNFORM-106、RUNFORM-107
**风险**：中。如果任一 Phase 延迟，Demo 范围需缩减

---

## Sprint 1 时间线（甘特建议）

```
Day 1-2:  RUNFORM-100 (project.yml + Info.plist)  ← 阻塞项，优先
          RUNFORM-101 (SwiftLint + .gitignore)     ← 并行
          RUNFORM-112 (PM: 文案模板)

Day 2-4:  RUNFORM-102 (XCTest 框架)               ← 依赖 RUNFORM-100
          RUNFORM-103 (CoreMotionManager)          ← 依赖 RUNFORM-100
          RUNFORM-109 (后端 CI)                    ← 并行
          RUNFORM-110 (后端 Session API)           ← 并行

Day 4-6:  RUNFORM-104 (DebugView)                 ← 依赖 RUNFORM-103
          RUNFORM-105 (CadenceCalculator)          ← 依赖 RUNFORM-103
          RUNFORM-108 (iOS CI)                     ← 依赖 RUNFORM-102

Day 6-8:  RUNFORM-106 (RunningMetricsCalculator)   ← 依赖 RUNFORM-103
          RUNFORM-107 (MotionPostureExtractor)     ← 依赖 RUNFORM-103
          RUNFORM-111 (PoseMetrics 兼容层)         ← 依赖 RUNFORM-103 + RUNFORM-110

Day 9-10: RUNFORM-113 (端到端集成 + Demo)          ← 依赖 RUNFORM-103~107
          Bugfix 缓冲区
```

---

## Definition of Done（Sprint 1 完成定义）

- [ ] 所有 P0 条目（RUNFORM-100, 102, 103, 105, 106, 107, 108, 109）代码 Review 通过
- [ ] 所有条目单元测试通过（`xcodebuild test` 全绿）
- [ ] CoreMotion Phase 0-3 在真机上跑通（iPhone 14 或更新机型）
- [ ] CI 流水线（ios-test.yml + backend-test.yml）在 GitHub Actions 上通过
- [ ] Sprint 1 Demo 完成，数据质量满足 Phase 0-3 验收标准
- [ ] Backlog 更新：Sprint 1 关闭的条目标记为 Done，未完成的重新排入 Sprint 2

---

## 风险与缓解

| 风险 | 影响条目 | 缓解措施 |
|------|---------|----------|
| CoreMotion 真机精度不足（腰包携带方式噪声太大） | RUNFORM-105/106/107 | Sprint 1 第一周完成 CoreMotionManager 后立即进行真机精度验证；如果 Phase 1 步频精度不达标，Sprint 1 降级为仅完成 Phase 0+1，Phase 2-3 延后到 Sprint 2 |
| Swift Charts 性能问题（100Hz 实时绘图） | RUNFORM-104 | 降低 DebugView 刷新率到 30fps；备选方案用 Core Graphics 手动绘制 |
| GitHub Actions iOS Simulator 不稳定 | RUNFORM-108 | 设置 3 次重试机制；如果 Simulator 持续不稳定，降级为仅 SwiftLint 门禁 |
| 后端开发资源争抢（Sprint 0 同期有 Website 任务） | RUNFORM-110/111 | 后端 API 可降级为最小可用版本（仅创建 + 查询 session，不包含 PATCH/DELETE） |

---

## Sprint 2 预告（初步）

- **Phase 4**：AudioCoachManager — 实时语音合成与触发逻辑
- **Phase 5**：RunSessionManager — 管线整合 + RunSessionView UI
- **Must Have M4/M5**：跑步总结报告 + 历史记录集成
- **XCUITest**：跑步会话核心用户旅程 E2E 测试
- **Android SensorManager PoC**：为 v1.1 Android 移植做准备

---

> **文档版本**：v1.0
> **下一步**：Sprint Planning 会议 → 确认各条目指派人 → 创建 GitHub Issues → 开始执行
