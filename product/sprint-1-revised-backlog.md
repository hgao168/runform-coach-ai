# RunForm Sprint 1 修订版 Backlog

> **修订日期**：2026-05-16
> **修订原因**：CEO 新指令 — 暂停所有新功能开发，转向跨平台功能对齐
> **原 Sprint 1**：2026-05-19 ~ 2026-05-30（双周，iOS CoreMotion Phase 0-3）
> **修订后 Sprint 1**：2026-05-19 ~ 2026-06-13（延长至 4 周，跨平台功能对齐）
> **关联文档**：`product/v1-prd.md`、`onboarding/SUMMARY.md`、各端入职文档

---

## 一、CEO 新指令摘要

### 1.1 背景

MoveNova 旗下拥有 5 条产品线：**RunForm**（跑步）、**SwimForm**（游泳）、**TennisForm**（网球）、**GolfForm**（高尔夫）、**LiftForm**（力量训练，即将推出）。品牌定位为「AI-Powered Movement Intelligence — Move Better. Perform Stronger. Live Healthier.」。多产品战略要求每条产品线都能在 iOS / Android / 微信小程序三端提供一致的用户体验。

### 1.2 新指令

| 原指令（已废弃） | 新指令 |
|------------------|--------|
| iOS 单点突破：交付 CoreMotion Phase 0-3 核心管线 | **暂停所有新功能开发**（含 CoreMotion 全部 Phase） |
| iOS 工程基础设施 + CI 测试框架 | **功能对齐优先**：Android 补齐 iOS 已有功能，微信补齐 iOS 已有功能 |
| Sprint 1 以 iOS 为主，其他平台做技术准备 | **三端功能对齐**为 Sprint 1 唯一目标 |
| Website 作为并行支线 | Website 继续并行推进（前端独立负责），不挤占对齐资源 |

### 1.3 新 Sprint 目标

**一句话**：完成 iOS ↔ Android、iOS ↔ 微信小程序的功能差距分析，将 Android 和微信小程序的功能补齐至与 iOS 持平。对齐达成后，再恢复新功能（CoreMotion 等）开发。

---

## 二、iOS 完整功能清单与跨平台对齐审计

### 2.1 审计说明

- ✅ = 已具备该功能
- ❌ = 完全缺失
- ⚠️ = 部分具备（有骨架但未完整实现）
- 🔒 = 平台限制（技术上无法实现或需等效替代方案）
- 「—」= 不适用

### 2.2 核心功能对齐表

| # | 功能 | 分类 | iOS | Android | WeChat | 差距分析 |
|---|------|------|-----|---------|--------|----------|
| **F1** | 视频录制上传（相册选择 + 相机拍摄） | 核心 | ✅ | ✅ | ✅ | 三端对齐 |
| **F2** | 多角度视频拍摄（侧/后/前） | 核心 | ✅ | ✅（AnalyzeScreen 有 angle 选择） | ⚠️（analyze 页未明确角度选择 UI） | WeChat 需增加角度选择 UI |
| **F3** | 实时相机人体检测引导（LiveGuidanceRecorderView，录制时叠加 Vision 骨骼线） | 增强 | ✅ | ❌ | 🔒（微信无逐帧相机访问） | Android 缺失实时录制引导；WeChat 平台限制，不做 |
| **F4** | 端侧姿态提取（PoseExtractor，Vision/ML Kit，21 项生物力学指标） | 核心 | ✅（Vision，810 行） | ❌（后端 AI 分析，无端侧） | ❌（后端 AI 分析，无端侧） | Android/WeChat 均依赖后端 AI，可考虑后续接入 ML Kit |
| **F5** | AI 分析结果展示（置信度、指标列表、问题卡片、训练建议） | 核心 | ✅（AnalysisResultView） | ✅（AnalysisResultScreen） | ✅（result 页） | 三端对齐 |
| **F6** | 历史记录列表（最近分析记录） | 核心 | ✅（HistoryView） | ✅（HistoryScreen，50 条） | ✅（history 页，50 条） | 三端对齐 |
| **F7** | 历史趋势图表（HistoryTrendComponents，多指标变化趋势） | 增强 | ✅ | ❌ | ❌ | Android/WeChat 均缺失趋势组件 |
| **F8** | 历史详情回看（单条分析完整展示） | 核心 | ✅（HistoryDetailView） | ✅（HistoryScreen 展开/折叠） | ✅（result 页 onLoad） | 三端对齐 |
| **F9** | 精英运动员对比（Kipchoge 等 benchmark 数据浏览） | 核心 | ✅（CompareView） | ❌ | ✅（compare 页，浏览） | Android 完全缺失对比功能 |
| **F10** | 用户 vs 精英数据对比（调用 /compare API） | 增强 | ✅（CompareResultView） | ❌ | ❌（api.js 已封装，页面未使用） | Android/WeChat 缺失对比接入 |
| **F11** | 自定义对比（选择任意两次分析记录对比） | 增强 | ✅（CustomCompareResultView） | ❌ | ❌ | Android/WeChat 缺失 |
| **F12** | 历史对比记录浏览 | 增强 | ✅（CompareHistoryView） | ❌ | ❌ | Android/WeChat 缺失 |
| **F13** | AI 训练计划生成（基于跑者档案生成周计划） | 核心 | ✅（PlanBuilderView，912 行） | ✅（PlanScreen，406 行） | ✅（plan 页） | 三端对齐 |
| **F14** | 马拉松训练计划 | 增强 | ✅（MarathonPlanDetailView） | ❌（PlanScreen 无此模式） | ❌ | Android/WeChat 缺失马拉松计划 |
| **F15** | 比赛计划（RacePlanDetailView） | 增强 | ✅ | ❌ | ❌ | Android/WeChat 缺失 |
| **F16** | 已保存计划管理（SavedPlanViews） | 增强 | ✅ | ❌（无持久化保存） | ❌ | Android/WeChat 缺失计划保存 |
| **F17** | 手动编辑下周计划（ManualNextWeekPlanEditorView） | 增强 | ✅ | ❌ | ❌ | Android/WeChat 缺失 |
| **F18** | 跑者档案管理（姓名/水平/跑量/目标/伤病等） | 核心 | ✅（ProfileView） | ✅（ProfileScreen） | ✅（profile 页） | 三端对齐 |
| **F19** | 跑者档案扩展字段（鞋码/腿长/跑鞋品牌） | 增强 | ✅ | ❌（ProfileScreen 无此字段） | ✅（profile 页已有） | Android 缺失扩展档案字段 |
| **F20** | Strava OAuth 集成（授权/断开/同步训练数据） | 增强 | ✅（StravaModels + ProfileStravaCard + APIClient） | ❌（代码中无任何 Strava 痕迹） | ❌（小程序无法跳转外部 OAuth） | Android 缺失 Strava；WeChat 平台限制 |
| **F21** | 语音教练 UI（AVSpeechSynthesizer 语音合成框架） | 核心 | ✅（AudioCoachManager 框架就绪，等待 CoreMotion Pipeline 触发） | ❌（无 TTS 实现） | 🔒（微信小程序不支持系统 TTS，需用 wx.createInnerAudioContext 播放预录音频或讯飞插件） | Android 缺失 TTS；WeChat 平台限制需等效方案 |
| **F22** | 多语言支持 | 核心 | ✅（en/nl/zh-Hans，3 套 Localizable.strings） | ⚠️（PlanScreen 有 Locale 检测但仅影响训练文案，无完整 i18n） | ✅（i18n.js，中/英/荷兰语完整） | Android 缺失完整 i18n |
| **F23** | 用户反馈评分（FeedbackView，分析质量评价） | 增强 | ✅ | ❌ | ❌ | Android/WeChat 缺失反馈功能 |
| **F24** | 训练卡片展示（WorkoutCardViews） | 核心 | ✅ | ✅（WorkoutCard） | ✅（plan 页卡片） | 三端对齐 |
| **F25** | 视频压缩上传 | 增强 | ✅（系统自动） | ❌（无压缩逻辑） | ❌（10MB 限制易超） | Android/WeChat 缺失视频压缩 |
| **F26** | 分享功能 | 增强 | ✅（系统 ShareSheet） | ❌ | ❌（result 页 toast "分享功能开发中"） | Android/WeChat 缺失分享 |
| **F27** | Strava WebView 上下文展示 | 增强 | ✅ | ❌ | 🔒 | Android 缺失 |

### 2.3 技术基础设施对齐表

| # | 能力 | iOS | Android | WeChat | 备注 |
|---|------|-----|---------|--------|------|
| **I1** | 单元测试 | ❌（0 测试，Sprint 1 原计划建 XCTest） | ❌（0 测试） | ❌（无测试框架） | 三端均无测试 |
| **I2** | UI 测试 | ❌（原计划 Sprint 2 XCUITest） | ❌ | ❌ | 三端均无 |
| **I3** | CI 自动测试门禁 | ❌（原计划 RUNFORM-108） | ❌ | ❌ | 三端均无 |
| **I4** | Lint / 代码风格检查 | ❌（原计划 SwiftLint） | ❌ | ❌ | 三端均无 |
| **I5** | DI 框架 | ❌（无，SwiftUI @EnvironmentObject 部分替代） | ❌（无 Hilt/Koin） | — | Android 需接入 Hilt |
| **I6** | 本地持久化 | ⚠️（UserDefaults 存 JSON，原计划迁移 Core Data） | ❌（SharedPreferences 明文存 JSON，无 Room） | ⚠️（wx.setStorageSync 本地存 JSON，无云同步） | Android 最差 |
| **I7** | 加密存储 | ❌ | ❌（SharedPreferences 明文） | ❌ | Android/WeChat 均需 |
| **I8** | API 认证 | ✅（token header） | ❌（Retrofit 无 auth） | ❌（无登录体系） | Android/WeChat 缺失 |
| **I9** | 多环境切换（staging/production） | ✅ | ❌（硬编码 staging URL） | ✅（config.js） | Android 缺失 |
| **I10** | 代码混淆/加固 | ✅（App Store 自动） | ❌（isMinifyEnabled=false，无 R8） | ✅（微信自动） | Android 缺失 |
| **I11** | 签名/发布配置 | ✅（Xcode 自动管理） | ❌（无 keystore） | ✅（微信开发者工具） | Android 无法发布 |
| **I12** | 错误监控 | ❌（无 Crashlytics/Sentry） | ❌ | ❌ | 三端均无 |
| **I13** | 用户行为埋点 | ❌（无 Analytics） | ❌ | ❌ | 三端均无 |

---

## 三、修订后 Sprint 1 Backlog

### 3.1 总览

| ID | 标题 | 指派 | SP | 优先级 | 平台 | 对齐功能 |
|----|------|------|-----|--------|------|----------|
| **Android 功能对齐** |
| RF-200 | Android 精英运动员对比功能（Compare） | Android 开发 | 8 | P0 | Android | F9-F12 |
| RF-201 | Android 训练计划增强（马拉松/比赛/计划保存） | Android 开发 | 8 | P0 | Android | F14-F17 |
| RF-202 | Android 历史趋势图表（HistoryTrendComponents） | Android 开发 | 5 | P0 | Android | F7 |
| RF-203 | Android 用户反馈评分（FeedbackView） | Android 开发 | 3 | P1 | Android | F23 |
| RF-204 | Android 完整多语言 i18n（en/zh-Hans/nl） | Android 开发 | 5 | P0 | Android | F22 |
| RF-205 | Android Strava OAuth 集成 | Android 开发 | 8 | P1 | Android | F20 |
| RF-206 | Android 视频压缩 + 多角度选择增强 | Android 开发 | 3 | P1 | Android | F25, F2 |
| RF-207 | Android 分享功能（ShareSheet） | Android 开发 | 2 | P2 | Android | F26 |
| RF-208 | Android 跑者档案扩展字段（鞋码/腿长/跑鞋） | Android 开发 | 2 | P2 | Android | F19 |
| RF-209 | Android 实时录制引导（LiveGuidance-like Camera Overlay） | Android 开发 | 5 | P2 | Android | F3 |
| **Android 基础设施** |
| RF-210 | Android DI 框架接入（Hilt/Koin） | Android 开发 | 5 | P0 | Android | I5 |
| RF-211 | Android Room 数据库迁移（替换 SharedPreferences） | Android 开发 | 5 | P0 | Android | I6 |
| RF-212 | Android 单元测试框架 + ViewModel 首批测试 | Android 开发 | 5 | P0 | Android | I1 |
| RF-213 | Android API 认证 + 多环境配置 | Android 开发 | 3 | P0 | Android | I8, I9 |
| RF-214 | Android R8 混淆 + Keystore 签名配置 | Android 开发 | 3 | P1 | Android | I10, I11 |
| RF-215 | Android Firebase Crashlytics + Analytics 接入 | Android 开发 | 3 | P2 | Android | I12, I13 |
| **WeChat 功能对齐** |
| RF-300 | WeChat 精英对比功能接入（接通 /compare API） | WeChat 开发 | 3 | P0 | WeChat | F10 |
| RF-301 | WeChat 历史趋势图表（Canvas 绘制趋势线） | WeChat 开发 | 5 | P0 | WeChat | F7 |
| RF-302 | WeChat 用户反馈评分（Feedback） | WeChat 开发 | 2 | P1 | WeChat | F23 |
| RF-303 | WeChat 视频压缩上传 | WeChat 开发 | 2 | P1 | WeChat | F25 |
| RF-304 | WeChat 分享功能（wx.shareAppMessage） | WeChat 开发 | 2 | P1 | WeChat | F26 |
| RF-305 | WeChat 语音反馈等效方案（预录音频 + innerAudioContext） | WeChat 开发 | 5 | P1 | WeChat | F21 |
| RF-306 | WeChat 云存储接入（CloudBase，替代本地 Storage） | WeChat 开发 | 5 | P1 | WeChat | I6 |
| RF-307 | WeChat 跑者档案完善（与 iOS 字段对齐确认） | WeChat 开发 | 1 | P2 | WeChat | F18 |
| RF-308 | WeChat 多角度视频拍摄选择 UI | WeChat 开发 | 1 | P2 | WeChat | F2 |
| **跨平台基础** |
| RF-400 | 后端 compare API 完善（支持用户数据对比 + 历史对比） | 后端开发 | 5 | P0 | 后端 | F10, F11 |
| RF-401 | 后端反馈 API（POST /feedback） | 后端开发 | 3 | P1 | 后端 | F23 |
| RF-402 | iOS 端代码清理 + 技术债处理（PoseExtractor 拆分等） | iOS 开发 | 5 | P1 | iOS | I1, I4 |
| RF-403 | iOS SwiftLint 配置 + XCTest 测试框架搭建 | iOS 开发 | 5 | P0 | iOS | I1, I4 |
| RF-404 | 后端 CI 测试流水线（pytest + ruff） | QA / 后端 | 5 | P0 | CI | I3 |

**总计**：27 个条目，116 SP（约 4 周，3 人并行）

- Android 开发：16 个条目，68 SP
- WeChat 开发：9 个条目，26 SP
- iOS 开发：2 个条目，10 SP
- 后端开发：2 个条目，8 SP
- QA 工程师：1 个条目（与后端共享 RF-404），5 SP

### 3.2 优先级说明

| 优先级 | 含义 | Sprint 1 处理策略 |
|--------|------|-------------------|
| **P0** | 功能对齐核心项，Sprint 1 必须交付 | 优先保障 |
| **P1** | 功能对齐增强项，Sprint 1 尽力交付 | 如时间不足可降级到 Sprint 2 |
| **P2** | Nice-to-have，Sprint 1 有余力时做 | 可延后 |

---

## 四、详细条目

### 4.1 Android 功能对齐

---

#### RF-200 · Android 精英运动员对比功能（Compare）

**优先级**：P0
**类型**：功能对齐
**平台**：Android
**指派**：Android 开发者
**估算**：8 SP（~4 天）
**对齐 iOS 功能**：F9（精英运动员浏览）、F10（用户 vs 精英对比）、F11（自定义对比）、F12（历史对比）

**用户故事**：
作为 Android 跑者，我希望能浏览精英运动员（如 Kipchoge）的 benchmark 数据，并将自己的分析结果与之对比，了解差距和改进方向。

**验收标准**：
- [ ] 新建 `CompareScreen.kt`：精英运动员列表（LazyColumn + GlassCard），复用后端 `/athletes` 接口
- [ ] 运动员详情展示：关键指标（步频/步幅/垂直振幅/触地时间/躯干倾角等）
- [ ] 新建 `CompareResultScreen.kt`：用户 vs 精英雷达图或并排指标对比（调用 `/compare` API）
- [ ] 支持从历史记录/分析结果页跳转到对比页（传递当前分析数据）
- [ ] 新建 `CustomCompareScreen.kt`：选择任意两次历史分析记录进行对比
- [ ] 对比结果数据模型与 iOS `CompareModels.swift` 保持一致
- [ ] 动画过渡：对比结果加载骨架屏 → 数据渲染
- [ ] 新增 `CompareViewModel`（@HiltViewModel，依赖 RF-210）
- [ ] 单元测试：CompareViewModel 状态转换（Loading → Success/Error）（依赖 RF-212）

**依赖项**：RF-210（Hilt DI）、RF-400（后端 compare API 完善）
**风险**：中。后端的 `/compare` API 当前仅封装但未全量使用，需确认 API 是否已就绪或需后端配合。

---

#### RF-201 · Android 训练计划增强（马拉松/比赛/计划保存）

**优先级**：P0
**类型**：功能对齐
**平台**：Android
**指派**：Android 开发者
**估算**：8 SP（~4 天）
**对齐 iOS 功能**：F14（马拉松计划）、F15（比赛计划）、F16（计划保存）、F17（手动编辑）

**用户故事**：
作为 Android 跑者，我希望除了基础周计划外，还能生成马拉松训练计划和比赛计划，并保存计划以便后续查看和手动调整。

**验收标准**：
- [ ] 在 `PlanScreen.kt` 中新增「马拉松计划」模式：选择赛事（六大满贯 + 自定义）→ 输入目标时间 → 生成 12-16 周训练计划
- [ ] 新增 `MarathonPlanDetailScreen.kt`：展示马拉松训练计划详情（周视图 / 阶段视图）
- [ ] 新增「比赛计划」模式：选择比赛距离（5K/10K/Half/Full）→ 目标配速 → 生成针对性训练
- [ ] 新增计划保存功能：将生成的计划持久化到 Room 数据库（依赖 RF-211）
- [ ] 新增 `SavedPlansScreen.kt`：已保存计划列表，支持点击查看详情
- [ ] 新增 `EditPlanScreen.kt`：手动编辑下周训练内容（添加/删除/修改训练日）
- [ ] 数据模型扩展：`PlannedWorkout` 增加 `planType`（weekly/marathon/race）、`weekNumber`、`phase` 字段
- [ ] 单元测试：PlanViewModel 各模式状态转换 + 保存/加载逻辑

**依赖项**：RF-211（Room 数据库）、RF-210（Hilt DI）
**风险**：中。马拉松计划生成逻辑复杂，后端需确认是否已有马拉松计划 API。

---

#### RF-202 · Android 历史趋势图表（HistoryTrendComponents）

**优先级**：P0
**类型**：功能对齐
**平台**：Android
**指派**：Android 开发者
**估算**：5 SP（~2.5 天）
**对齐 iOS 功能**：F7（历史趋势图表）

**用户故事**：
作为 Android 跑者，我希望在历史记录页看到关键指标的变化趋势图，以便直观地了解自己的进步。

**验收标准**：
- [ ] 在 `HistoryScreen.kt` 顶部新增趋势图表区域（可折叠）
- [ ] 使用 Compose Canvas 或第三方图表库（如 Vico/MPAndroidChart）绘制折线图
- [ ] 支持 3 项核心指标趋势：步频（cadence）、垂直振幅（vertical oscillation）、触地时间（GCT）
- [ ] X 轴为时间（最近 20 条记录），Y 轴为指标值，不同颜色区分指标
- [ ] 支持点击数据点查看具体数值（Tooltip）
- [ ] 无数据时展示空状态引导（「完成第一次分析后查看趋势」）
- [ ] 从 Room DB 读取历史数据（依赖 RF-211）

**依赖项**：RF-211（Room DB）
**风险**：低。Canvas 绘图或成熟图表库均可实现，核心逻辑在数据聚合。

---

#### RF-203 · Android 用户反馈评分（FeedbackView）

**优先级**：P1
**类型**：功能对齐
**平台**：Android
**指派**：Android 开发者
**估算**：3 SP（~1.5 天）
**对齐 iOS 功能**：F23（用户反馈评分）

**用户故事**：
作为 Android 跑者，我希望在查看分析结果后能对分析质量进行评分和反馈，帮助 AI 持续改进。

**验收标准**：
- [ ] 在 `AnalysisResultScreen.kt` 底部新增反馈区域
- [ ] 5 星评分选择 + 可选文字反馈（多行输入框）
- [ ] 提交按钮 → 调用 `POST /feedback` API（依赖 RF-401）
- [ ] 提交成功后显示确认提示，隐藏反馈区域
- [ ] 无网络时本地暂存反馈（Room DB），联网后自动同步
- [ ] 单元测试：FeedbackViewModel 提交/暂存/重试逻辑

**依赖项**：RF-401（后端反馈 API）、RF-211（Room 暂存）
**风险**：低。

---

#### RF-204 · Android 完整多语言 i18n（en/zh-Hans/nl）

**优先级**：P0
**类型**：功能对齐
**平台**：Android
**指派**：Android 开发者
**估算**：5 SP（~2.5 天）
**对齐 iOS 功能**：F22（多语言）

**用户故事**：
作为国际用户，我希望能用我的母语（中文/英文/荷兰语）使用 RunForm，而非仅有部分页面支持多语言。

**验收标准**：
- [ ] 新建 `res/values-zh/strings.xml`（中文）、`res/values-nl/strings.xml`（荷兰语）
- [ ] 所有用户可见文本从硬编码字符串迁移到 `@string` 资源引用
- [ ] 覆盖范围：AnalyzeScreen、AnalysisResultScreen、HistoryScreen、PlanScreen、ProfileScreen、新增的 CompareScreen
- [ ] 训练计划内容（PlanScreen 的训练文案）支持中文/英文切换（已有 Locale 检测逻辑，扩展即可）
- [ ] 语言切换方式：跟随系统语言（默认），后续在 Profile 页增加手动切换
- [ ] 对照 iOS `zh-Hans.lproj/Localizable.strings` + `en.lproj/Localizable.strings` 保证翻译一致性

**依赖项**：无
**风险**：低。体力活为主，需 PM 审核翻译一致性。

---

#### RF-205 · Android Strava OAuth 集成

**优先级**：P1
**类型**：功能对齐
**平台**：Android
**指派**：Android 开发者
**估算**：8 SP（~4 天）
**对齐 iOS 功能**：F20（Strava OAuth）

**用户故事**：
作为 Android 跑者且 Strava 用户，我希望能将 RunForm 与我的 Strava 账号连接，同步训练数据并在个人资料页查看 Strava 统计。

**验收标准**：
- [ ] 新建 `StravaAuthActivity`（或 Compose Screen）：Strava OAuth WebView 授权流程
- [ ] 新建 `StravaRepository`：token 管理（加密存储，依赖 EncryptedSharedPreferences / DataStore）
- [ ] `ProfileScreen.kt` 新增 Strava 连接卡片（对标 iOS `ProfileStravaCard`）
- [ ] 展示 Strava 同步状态（已连接/未连接/同步中）
- [ ] 支持断开 Strava 连接 + 重新授权
- [ ] 调用 `/strava/status` 获取同步状态、`/strava/disconnect` 断开
- [ ] Strava 数据模型与 iOS `StravaModels.swift` 保持一致
- [ ] 单元测试：StravaViewModel OAuth 流程 + token 刷新逻辑

**依赖项**：RF-210（Hilt DI）
**风险**：中。OAuth 流程调试复杂，Android WebView 需要处理 Strava 回调 URL（自定义 scheme 或 App Links）

---

#### RF-206 · Android 视频压缩 + 多角度选择增强

**优先级**：P1
**类型**：功能对齐
**平台**：Android
**指派**：Android 开发者
**估算**：3 SP（~1.5 天）
**对齐 iOS 功能**：F25（视频压缩）、F2（多角度选择）

**用户故事**：
作为 Android 跑者，我希望上传前自动压缩视频以加快上传速度，并能明确选择拍摄角度。

**验收标准**：
- [ ] 在视频选择后、上传前，自动调用 `MediaCodec` 或 `VideoCompressor` 降分辨率至 720p（保持 30fps）
- [ ] 压缩进度提示（ProgressBar + 百分比）
- [ ] 压缩后文件大小 < 10MB（对标微信小程序的限制，统一标准）
- [ ] `AnalyzeScreen.kt` 角度选择 UI 优化：更明确的按钮/卡片视觉（侧/后/前），带人体示意图标
- [ ] 单元测试：视频压缩尺寸/码率验证

**依赖项**：无
**风险**：低。Android 视频压缩库（如 Silicompressor、Compressor）成熟。

---

#### RF-207 · Android 分享功能（ShareSheet）

**优先级**：P2
**类型**：功能对齐
**平台**：Android
**指派**：Android 开发者
**估算**：2 SP（~1 天）
**对齐 iOS 功能**：F26（分享）

**验收标准**：
- [ ] 在分析结果页和对比结果页顶部增加「分享」按钮
- [ ] 调用 Android ShareSheet（Intent.ACTION_SEND），分享内容为分析摘要文本 + App 下载链接
- [ ] 可分享截图（结果页 Canvas 截图）

**依赖项**：无
**风险**：低。

---

#### RF-208 · Android 跑者档案扩展字段（鞋码/腿长/跑鞋）

**优先级**：P2
**类型**：功能对齐
**平台**：Android
**指派**：Android 开发者
**估算**：2 SP（~1 天）
**对齐 iOS 功能**：F19（档案扩展字段）

**验收标准**：
- [ ] `ProfileScreen.kt` 新增字段：鞋码（EU/US/UK 切换）、腿长（cm）、主要跑鞋品牌/型号
- [ ] `TesterProfile` 数据模型扩展对应字段
- [ ] 持久化到 Room（依赖 RF-211）

**依赖项**：RF-211
**风险**：低。

---

#### RF-209 · Android 实时录制引导（LiveGuidance-like Camera Overlay）

**优先级**：P2
**类型**：功能对齐
**平台**：Android
**指派**：Android 开发者
**估算**：5 SP（~2.5 天）
**对齐 iOS 功能**：F3（实时相机人体检测引导）

**用户故事**：
作为 Android 跑者，我希望能像 iOS 用户一样，在录制跑步视频时看到实时的人体骨骼线叠加，确保我站在正确的位置、全身可见。

**验收标准**：
- [ ] 新建 `LiveGuidanceRecorderScreen.kt`：CameraX + ML Kit Pose Detection 实时骨骼线叠加
- [ ] 录制前检测：全身是否在画面内 → 提示「请后退/靠近」
- [ ] 骨骼线绘制覆盖在 CameraX PreviewView 上（Canvas overlay）
- [ ] 录制按钮 + 计时器叠加
- [ ] 录制完成后自动进入分析流程

**依赖项**：ML Kit Pose Detection（需添加依赖 `com.google.mlkit:pose-detection`）
**风险**：中。ML Kit 实时推理性能需验证（低端设备可能掉帧），可降级为仅检测不渲染骨骼线。

---

### 4.2 Android 基础设施

---

#### RF-210 · Android DI 框架接入（Hilt/Koin）

**优先级**：P0（阻塞项 — 所有 P0 ViewModel 都依赖 DI）
**类型**：基础设施
**平台**：Android
**指派**：Android 开发者
**估算**：5 SP（~2.5 天）
**对齐基础设施**：I5（DI 框架）

**用户故事**：
作为 Android 开发者，我需要 DI 框架来解耦依赖、支持 ViewModel 单元测试，并为新增的 CompareViewModel、StravaViewModel 等提供注入能力。

**验收标准**：
- [ ] 接入 Hilt（推荐，Google 官方）：添加 `hilt-android-gradle-plugin` + `hilt-compiler`
- [ ] 创建 `@HiltAndroidApp Application` 类
- [ ] 改造现有 `AppViewModel` → `@HiltViewModel` + `@Inject constructor`
- [ ] `ApiClient` 改造为 `@Module @InstallIn(SingletonComponent::class)` 提供 `@Provides`
- [ ] `StorageManager`（Room DAO 封装）作为 `@Singleton` 注入
- [ ] 项目编译通过，无 DI 循环依赖错误
- [ ] 验证：注入的 ViewModel 在所有 Screen 中正常工作

**依赖项**：无
**风险**：中。现有 `AppViewModel` 直接在 Compose 中 `viewModel()` 实例化，改 Hilt 需调整所有 ViewModel 实例化点，工作量主要在适配现有代码。

---

#### RF-211 · Android Room 数据库迁移（替换 SharedPreferences）

**优先级**：P0（阻塞项 — 历史趋势/计划保存等功能依赖本地查询）
**类型**：基础设施
**平台**：Android
**指派**：Android 开发者
**估算**：5 SP（~2.5 天）
**对齐基础设施**：I6（本地持久化）

**用户故事**：
作为 Android 开发者，我需要用 Room 数据库替换 SharedPreferences 明文 JSON 存储，以支持高效查询（历史趋势）、数据迁移和加密存储。

**验收标准**：
- [ ] 接入 Room：添加 Room 依赖（`room-runtime`、`room-ktx`、`room-compiler`）
- [ ] 定义 Entity：`AnalysisHistoryEntity`（id, userId, videoUri, analysisJson, metricsJson, confidence, createdAt）
- [ ] 定义 Entity：`SavedPlanEntity`（id, userId, planJson, planType, createdAt）
- [ ] 定义 Entity：`RunnerProfileEntity`（id, userId, profileJson, updatedAt）
- [ ] 定义 DAO：`AnalysisDao`（insert/queryAll/queryById/delete）、`PlanDao`、`ProfileDao`
- [ ] 定义 RoomDatabase：`RunFormDatabase`（version=1, exportSchema=true）
- [ ] 数据迁移脚本：`Migration(0, 1)` — 首次安装不需要迁移；如 SharedPreferences 已有历史数据，提供从 SharedPreferences → Room 的迁移工具
- [ ] 改造 `AppViewModel` 历史数据读写 → 通过 `AnalysisDao` 操作 Room
- [ ] 单元测试：DAO CRUD 操作 + Migration 验证

**依赖项**：RF-210（Hilt DI，用于注入 DAO）
**风险**：中。SharedPreferences → Room 迁移涉及现有数据兼容，需处理迁移失败时的降级策略。

---

#### RF-212 · Android 单元测试框架 + ViewModel 首批测试

**优先级**：P0
**类型**：基础设施
**平台**：Android
**指派**：Android 开发者
**估算**：5 SP（~2.5 天）
**对齐基础设施**：I1（单元测试）

**用户故事**：
作为 Android 开发者，我需要建立单元测试框架并为核心 ViewModel 编写测试，以便后续功能对齐开发有安全网。

**验收标准**：
- [ ] 添加测试依赖：JUnit5、MockK、Turbine（Flow 测试）、Compose UI Test
- [ ] 新建 `app/src/test/java/.../viewmodel/AppViewModelTest.kt`：至少覆盖分析状态机（Idle→Loading→Success/Error）、历史记录 CRUD、Profile 读写
- [ ] 新建 `app/src/test/java/.../repository/AnalysisDaoTest.kt`（Room 集成测试）：DAO CRUD
- [ ] 新建 `app/src/test/java/.../api/ApiClientTest.kt`：MockWebServer 模拟 API 响应
- [ ] 测试覆盖率目标：核心 ViewModel > 60%
- [ ] `./gradlew testDebugUnitTest` 全绿通过

**依赖项**：RF-210（Hilt DI，测试中可注入 Mock）、RF-211（Room，DAO 集成测试）
**风险**：低。

---

#### RF-213 · Android API 认证 + 多环境配置

**优先级**：P0
**类型**：基础设施
**平台**：Android
**指派**：Android 开发者
**估算**：3 SP（~1.5 天）
**对齐基础设施**：I8（API 认证）、I9（多环境）

**用户故事**：
作为 Android 开发者，我需要 Retrofit 请求携带认证 token 并支持 staging/production 环境切换，以便安全调用后端 API 和安全地调试。

**验收标准**：
- [ ] 在 `ApiClient.kt` 中添加 OkHttp Interceptor：自动附加 `Authorization: Bearer <token>` header
- [ ] Token 存储：使用 EncryptedSharedPreferences（AndroidX Security）
- [ ] Token 刷新逻辑（如后端支持 refresh token）：401 响应自动尝试刷新
- [ ] `build.gradle.kts` 定义 `buildConfigField`：`STAGING_URL` / `PRODUCTION_URL`
- [ ] 新增 `debug` / `release` build variant，自动切换 API Base URL
- [ ] 单元测试：Interceptor 附加 token 逻辑 + token 刷新流程

**依赖项**：无
**风险**：低。

---

#### RF-214 · Android R8 混淆 + Keystore 签名配置

**优先级**：P1
**类型**：基础设施
**平台**：Android
**指派**：Android 开发者
**估算**：3 SP（~1.5 天）
**对齐基础设施**：I10（混淆）、I11（签名）

**用户故事**：
作为团队，我需要 Android Release 构建开启代码混淆并配置签名密钥，以便能将 RunForm 发布到 Google Play。

**验收标准**：
- [ ] `app/build.gradle.kts`：`isMinifyEnabled = true`（release）、`proguardFiles` 指向 `proguard-rules.pro`
- [ ] `proguard-rules.pro`：保留 Retrofit/Gson 数据类（`@Keep` 或 proguard rule）、保留 Compose 相关类
- [ ] 生成 upload keystore（`.jks`），本地开发用 debug 签名，CI 用环境变量注入
- [ ] `app/build.gradle.kts` 签名配置：`signingConfigs` 区分 debug/release
- [ ] 验证：release APK 可安装、运行、API 调用正常

**依赖项**：无
**风险**：低。标准 Android 发布流程。

---

#### RF-215 · Android Firebase Crashlytics + Analytics 接入

**优先级**：P2
**类型**：基础设施
**平台**：Android
**指派**：Android 开发者
**估算**：3 SP（~1.5 天）
**对齐基础设施**：I12（错误监控）、I13（埋点）

**用户故事**：
作为团队，我需要在 Android 端接入崩溃上报和用户行为分析，以便监控线上质量并理解用户行为。

**验收标准**：
- [ ] 接入 Firebase Crashlytics：添加依赖 + `google-services.json` + 初始化
- [ ] 接入 Firebase Analytics：添加依赖 + 基础事件（screen_view, analyze_video, view_result 等）
- [ ] 非致命异常手动上报（try-catch 中 `Firebase.crashlytics.recordException`）
- [ ] 验证：Firebase Console 可看到测试设备的崩溃报告和分析事件

**依赖项**：Firebase 项目创建（需 PM/后端 提供 google-services.json）
**风险**：低。

---

### 4.3 WeChat 功能对齐

---

#### RF-300 · WeChat 精英对比功能接入（接通 /compare API）

**优先级**：P0
**类型**：功能对齐
**平台**：WeChat
**指派**：WeChat 开发者
**估算**：3 SP（~1.5 天）
**对齐 iOS 功能**：F10（用户 vs 精英对比）

**用户故事**：
作为微信小程序跑者，我希望在 compare 页不仅能浏览精英运动员，还能将自己的分析数据与精英进行对比。

**验收标准**：
- [ ] `compare` 页改造：在选择运动员后，从最近一次分析结果中读取用户指标（`wx.getStorageSync('lastAnalysisResult')`）
- [ ] 调用 `api.compareWithAthlete(userMetrics, athleteId)`（api.js 已封装，页面接通即可）
- [ ] 对比结果展示：用户 vs 精英指标并排展示（表格或卡片形式）
- [ ] 指标差异高亮：标注用户与精英的差距（如「步频：168 vs 180，差距 -12」）
- [ ] 无分析记录时提示「请先完成一次视频分析」

**依赖项**：RF-400（后端 compare API 完善）
**风险**：低。API 已封装，主要是页面接入工作。

---

#### RF-301 · WeChat 历史趋势图表（Canvas 绘制趋势线）

**优先级**：P0
**类型**：功能对齐
**平台**：WeChat
**指派**：WeChat 开发者
**估算**：5 SP（~2.5 天）
**对齐 iOS 功能**：F7（历史趋势图表）

**用户故事**：
作为微信小程序跑者，我希望能看到关键指标的变化趋势，直观了解自己的进步。

**验收标准**：
- [ ] `history` 页顶部新增趋势图区域（可折叠）
- [ ] 使用微信 Canvas 2D API 绘制折线图
- [ ] 支持 3 项核心指标趋势：步频、垂直振幅、触地时间
- [ ] X 轴为时间（最近 20 条记录）、Y 轴为指标值
- [ ] 颜色区分指标（与 iOS HistoryTrendComponents 配色一致：#00f5a0 步频、#00d4ff 振幅、#ff9f30 GCT）
- [ ] 支持点击数据点查看具体数值（WXS 响应事件）
- [ ] 无数据时展示空状态引导

**依赖项**：无
**风险**：中。微信 Canvas 2D API 与 Web Canvas 类似但有细微差异，折线图绘制逻辑需自行实现。

---

#### RF-302 · WeChat 用户反馈评分（Feedback）

**优先级**：P1
**类型**：功能对齐
**平台**：WeChat
**指派**：WeChat 开发者
**估算**：2 SP（~1 天）
**对齐 iOS 功能**：F23（用户反馈评分）

**用户故事**：
作为微信小程序跑者，我希望在查看分析结果后能打分和反馈，帮助 AI 持续改进。

**验收标准**：
- [ ] `result` 页底部新增反馈区域
- [ ] 5 星评分（使用 WeChat 图标或自定义星星组件）+ 可选文字反馈
- [ ] 提交按钮 → 调用 `POST /feedback` API（依赖 RF-401）
- [ ] 提交成功提示 + 隐藏反馈区域
- [ ] 无网络时本地暂存（wx.setStorageSync），下次分析时自动提交

**依赖项**：RF-401（后端反馈 API）
**风险**：低。

---

#### RF-303 · WeChat 视频压缩上传

**优先级**：P1
**类型**：功能对齐
**平台**：WeChat
**指派**：WeChat 开发者
**估算**：2 SP（~1 天）
**对齐 iOS 功能**：F25（视频压缩）

**用户故事**：
作为微信小程序跑者，我希望上传跑步视频时不会因文件过大而失败。

**验收标准**：
- [ ] `analyze` 页视频上传前，调用 `wx.compressVideo` 压缩：码率降低、分辨率 ≤ 720p
- [ ] 压缩进度提示（loading 动画）
- [ ] 压缩后边界检查：文件 > 10MB 则提示用户录制更短的视频（≤ 30 秒）
- [ ] 视频时长限制：录制时自动限制 60 秒，超时自动停止

**依赖项**：无
**风险**：低。`wx.compressVideo` 为微信原生 API。

---

#### RF-304 · WeChat 分享功能（wx.shareAppMessage）

**优先级**：P1
**类型**：功能对齐
**平台**：WeChat
**指派**：WeChat 开发者
**估算**：2 SP（~1 天）
**对齐 iOS 功能**：F26（分享）

**用户故事**：
作为微信小程序跑者，我希望能把分析结果分享给跑步群里的朋友。

**验收标准**：
- [ ] `result` 页顶部新增「分享」按钮
- [ ] 调用 `wx.shareAppMessage` 分享：标题为分析摘要（如「步频 172 SPM，跑姿评分 82/100」），图片为结果页截图（Canvas 绘制）
- [ ] 分享路径包含分析记录 ID，好友点击可查看该分析结果
- [ ] `result` 页 `onShareAppMessage` 生命周期方法实现

**依赖项**：无
**风险**：低。

---

#### RF-305 · WeChat 语音反馈等效方案（预录音频 + innerAudioContext）

**优先级**：P1
**类型**：功能对齐
**平台**：WeChat
**指派**：WeChat 开发者
**估算**：5 SP（~2.5 天）
**对齐 iOS 功能**：F21（语音教练等效方案，平台限制不可用系统 TTS）

**用户故事**：
作为微信小程序跑者，我希望能像 iOS 用户一样，在跑步后收到语音形式的姿态反馈摘要。

**验收标准**：
- [ ] 策划 + 录制中文语音素材：覆盖 3 类场景提示 × 2 条变体（步频偏低/偏高/合格 + 姿态警告）
- [ ] 使用 `wx.createInnerAudioContext` 播放预录音频
- [ ] 在分析结果页增加「语音播报」按钮：点击后播放分析结果语音摘要
- [ ] 评估讯飞插件（`wx-plugin://xunfei-tts`）可行性：如审批通过，支持动态文字合成语音；否则使用预录音频
- [ ] 语音播报时显示播放状态动画（波形图标）

**依赖项**：PM 提供语音文案（参考 RUNFORM-112）
**风险**：中。微信小程序无系统 TTS，预录音频方案固定化，讯飞插件审批周期不确定。

---

#### RF-306 · WeChat 云存储接入（CloudBase，替代本地 Storage）

**优先级**：P1
**类型**：基础设施
**平台**：WeChat
**指派**：WeChat 开发者
**估算**：5 SP（~2.5 天）
**对齐基础设施**：I6（云同步替代本地存储）

**用户故事**：
作为微信小程序跑者，我希望我的分析记录能安全存储在云端，换设备也能查看历史数据。

**验收标准**：
- [ ] 微信云开发初始化：`wx.cloud.init()` + 环境 ID 配置
- [ ] 云数据库集合：`analysis_history`（userId/openid, analysisData, createdAt）
- [ ] `history` 页数据源切换：从 `wx.getStorageSync` → 云数据库查询（`db.collection('analysis_history').orderBy('createdAt', 'desc').limit(50)`）
- [ ] 数据迁移工具：`migrateLocalToCloud()` — 首次启动时将本地 Storage 历史数据批量同步到云数据库
- [ ] 降级策略：云数据库不可用时回退到本地 Storage
- [ ] 用户无需登录：使用 `wx.cloud.getWXContext().OPENID` 匿名标识用户

**依赖项**：微信云开发环境开通（需 PM 协助申请）
**风险**：中。云开发环境开通需微信审核，且有月度调用量限制。

---

#### RF-307 · WeChat 跑者档案完善（与 iOS 字段对齐确认）

**优先级**：P2
**类型**：功能对齐
**平台**：WeChat
**指派**：WeChat 开发者
**估算**：1 SP（~0.5 天）
**对齐 iOS 功能**：F18（档案字段对齐）

**用户故事**：
作为微信小程序跑者，我希望我的跑者档案与 iOS 版一致，内容完整。

**验收标准**：
- [ ] 审计 iOS `ProfileModels.swift` 中的 `TesterProfile` 字段，与 WeChat `profile` 页字段一一对比
- [ ] 补充 WeChat 缺失的字段（如有）
- [ ] 确认字段名与后端 API 一致（level key 大小写等）

**依赖项**：无
**风险**：低。

---

#### RF-308 · WeChat 多角度视频拍摄选择 UI

**优先级**：P2
**类型**：功能对齐
**平台**：WeChat
**指派**：WeChat 开发者
**估算**：1 SP（~0.5 天）
**对齐 iOS 功能**：F2（多角度选择 UI）

**用户故事**：
作为微信小程序跑者，我希望在录制/选择视频前明确选择拍摄角度。

**验收标准**：
- [ ] `analyze` 页在录制/选择视频前增加角度选择：侧（side）/ 后（rear）/ 前（front）
- [ ] 三个选项以按钮/卡片形式展示，人体角度示意图标
- [ ] 选择的角度以参数形式传给后端 `/analyze` API

**依赖项**：无
**风险**：低。

---

### 4.4 后端 & 跨平台基础

---

#### RF-400 · 后端 compare API 完善（支持用户数据对比 + 历史对比）

**优先级**：P0
**类型**：后端增强
**平台**：后端
**指派**：后端开发
**估算**：5 SP（~2.5 天）
**对齐功能**：F10、F11

**用户故事**：
作为 Android/WeChat 客户端，我需要后端 `/compare` API 完整可用，支持用户数据与精英对比及自定义历史对比。

**验收标准**：
- [ ] 确认 `/compare` 接口当前实现状态：参数、返回值、是否已有测试
- [ ] 完善 `/compare` 接口：接收用户指标 JSON + 运动员 ID，返回对比结果（差异值 + 百分比 + 评价等级）
- [ ] 新增或完善 `/custom-compare` 接口：接收两组分析结果 ID，返回逐项对比
- [ ] 响应字段与 iOS `CompareModels.swift` 保持一致（`MetricComparison`, `CompareResponse`）
- [ ] 接口文档更新：OpenAPI / Swagger 自动生成
- [ ] pytest 单元测试覆盖：正常对比 + 缺失数据 + 无效运动员 ID
- [ ] 性能要求：对比计算 < 500ms

**依赖项**：无
**风险**：低。

---

#### RF-401 · 后端反馈 API（POST /feedback）

**优先级**：P1
**类型**：后端增强
**平台**：后端
**指派**：后端开发
**估算**：3 SP（~1.5 天）
**对齐功能**：F23

**用户故事**：
作为 Android/WeChat 客户端，我需要后端提供反馈 API，以便收集用户对分析质量的评分和文字反馈。

**验收标准**：
- [ ] 新建 `POST /api/v1/feedback` 接口
- [ ] 请求体：`analysis_id`（关联分析记录）、`rating`（1-5 int）、`comment`（可选 string）
- [ ] 数据库新增 `feedback` 表：`id`, `analysis_id`, `user_id`, `rating`, `comment`, `created_at`
- [ ] Alembic 迁移脚本
- [ ] 响应：`{ "status": "ok", "message": "Feedback submitted" }`
- [ ] pytest 测试：正常提交 + 无效 rating + 缺失 analysis_id

**依赖项**：无
**风险**：低。

---

#### RF-402 · iOS 端代码清理 + 技术债处理

**优先级**：P1
**类型**：技术债
**平台**：iOS
**指派**：iOS 开发者
**估算**：5 SP（~2.5 天）

**用户故事**：
作为 iOS 开发者，在 CoreMotion 暂停期间，我希望偿还已积累的技术债，为后续恢复 CoreMotion 开发打好基础。

**验收标准**：
- [ ] PoseExtractor（810 行）拆分：`PoseExtractor.swift`（Vision 管线）+ `SignalProcessing.swift`（纯函数：smooth/countPeaks/pearsonCorrelation/等）
- [ ] `APIClient.swift` 硬编码 fallback URL → 改为可选 URL + UI 错误提示（移除 `fatalError`）
- [ ] `URLSession` 添加重试策略（失败自动重试 2 次，指数退避）
- [ ] 审计全部 UI 文本 → 确保所有用户可见文本已纳入 `Localizable.strings`
- [ ] Assets.xcassets AppIcon 尺寸链补充完整（1024x1024 + 所有衍生尺寸）

**依赖项**：无
**风险**：低。

---

#### RF-403 · iOS SwiftLint 配置 + XCTest 测试框架搭建

**优先级**：P0
**类型**：基础设施
**平台**：iOS
**指派**：iOS 开发者
**估算**：5 SP（~2.5 天）
**对齐基础设施**：I1、I4

**用户故事**：
作为团队，我需要 iOS 端也有 Lint 规范和测试框架，以便代码质量和后续 CoreMotion 恢复开发时有安全网。

**验收标准**：
与 RUNFORM-100/101/102 相同，但减少 CoreMotion 相关的 Info.plist 权限声明部分：

- [ ] XcodeGen `project.yml`：主 target + XCTest target + XCUITest target
- [ ] `Info.plist` 补充：`NSMotionUsageDescription`、`NSHealthShareUsageDescription`、`NSHealthUpdateUsageDescription`、`UIBackgroundModes`
- [ ] SwiftLint 配置：`.swiftlint.yml` + `.gitignore` 完善
- [ ] `ios/RunFormCoachAITests/` 创建 + `PoseExtractorTests.swift`：5 个纯函数测试（smooth/countPeaks/pearsonCorrelation/calculateCadence/detectFootStrike），每个函数 ≥ 3 用例
- [ ] `xcodebuild test` 全绿通过

**依赖项**：RF-402（PoseExtractor 拆分后，纯函数测试更容易编写）
**风险**：低。

---

#### RF-404 · 后端 CI 测试流水线（pytest + ruff）

**优先级**：P0
**类型**：CI/CD
**平台**：后端
**指派**：QA 工程师 / 后端开发（共享）
**估算**：5 SP（~2.5 天）

**验收标准**：与 RUNFORM-109 一致
- [ ] `.github/workflows/backend-test.yml`：push/PR 触发
- [ ] ruff check + pytest 集成
- [ ] `backend/tests/` 目录建立 + conftest.py + ≥ 5 个 API 端点测试
- [ ] GitHub Actions 上通过

**依赖项**：无
**风险**：低。

---

## 五、明确暂停项（原 Sprint 1 CoreMotion 工作）

以下原 Sprint 1 条目**全部暂停**，待功能对齐完成后恢复：

| 原 ID | 标题 | 暂停原因 |
|-------|------|----------|
| **RUNFORM-103** | CoreMotionManager — 传感器数据采集管线 | 新功能开发，非功能对齐 |
| **RUNFORM-104** | DebugView — 实时传感器波形可视化 | 依赖 RUNFORM-103 |
| **RUNFORM-105** | CadenceCalculator — 步频实时计算 | 新功能开发，非功能对齐 |
| **RUNFORM-106** | RunningMetricsCalculator — 垂直振幅 + 触地时间 | 新功能开发，非功能对齐 |
| **RUNFORM-107** | MotionPostureExtractor — 传感器融合 + 躯干倾角 | 新功能开发，非功能对齐 |
| **RUNFORM-110** | 后端实时跑步会话 API（session CRUD） | 依赖 CoreMotion 管线产出数据模型 |
| **RUNFORM-111** | 跑步会话数据模型定义（PoseMetrics 兼容层） | 依赖 CoreMotion 管线 |
| **RUNFORM-112** | v1 语音提示文案模板 + 中文本地化初稿 | PM 可继续产出文案，但音频集成暂停 |
| **RUNFORM-113** | Sprint 1 Demo 准备（端到端集成验证） | 无 CoreMotion 管线，无法 Demo |

**保留/调整的原 Sprint 1 工作**：

| 原 ID | 标题 | 调整 |
|-------|------|------|
| **RUNFORM-100** | XcodeGen project.yml + Info.plist 权限声明 | 合并入 **RF-403**，仍执行 |
| **RUNFORM-101** | SwiftLint 配置 + .gitignore 完善 | 合并入 **RF-403**，仍执行 |
| **RUNFORM-102** | XCTest 测试框架 + PoseExtractor 单元测试 | 合并入 **RF-403**，仍执行 |
| **RUNFORM-108** | iOS CI 测试流水线 | 延后（等 XCTest 测试覆盖充足后再建 CI 门禁） |
| **RUNFORM-109** | 后端 CI 测试流水线 | 作为 **RF-404** 继续执行 |

---

## 六、修订后时间线

```
Week 1 (5/19-5/23):  基础设施先行
  Day 1-3:  RF-210 (Hilt DI)     ← 阻塞项，Android 最先做
            RF-213 (API 认证+环境) ← Android 并行
            RF-402 (iOS 代码清理)   ← iOS 开发者启动
            RF-400 (后端 compare API) ← 后端启动

  Day 3-5:  RF-211 (Room DB)      ← Android 依赖 RF-210
            RF-212 (测试框架)      ← Android 并行
            RF-403 (iOS SwiftLint+XCTest) ← iOS 开发者
            RF-404 (后端 CI)        ← QA/后端

Week 2 (5/26-5/30): 功能对齐攻坚
  Day 6-8:  RF-200 (Android Compare)    ← 最高优先功能对齐
            RF-204 (Android i18n)       ← 并行
            RF-300 (WeChat Compare)     ← WeChat 开发者启动
            RF-301 (WeChat 趋势图表)    ← WeChat 并行

  Day 8-10: RF-201 (Android 训练增强)  ← 启动
            RF-202 (Android 趋势图表)   ← 并行
            RF-303 (WeChat 视频压缩)    ← WeChat
            RF-304 (WeChat 分享)        ← WeChat
            RF-401 (后端反馈 API)       ← 后端

Week 3 (6/2-6/6):  对齐扫尾
  Day 11-13: RF-203 (Android 反馈)     ← Android
             RF-205 (Android Strava)    ← Android（如果复杂可延后）
             RF-206 (Android 视频压缩)  ← Android
             RF-305 (WeChat 语音方案)   ← WeChat
             RF-306 (WeChat 云存储)     ← WeChat

  Day 13-15: RF-214 (Android R8+签名)  ← 基础设施收尾
             RF-215 (Android Crashlytics) ← 如果时间允许
             RF-302 (WeChat 反馈)       ← WeChat

Week 4 (6/9-6/13):  P2 项目 + 缓冲
  Day 16-18: RF-207 (Android 分享)     ← P2
             RF-208 (Android 档案扩展)  ← P2
             RF-209 (Android 录制引导)  ← P2（可延后）
             RF-307 (WeChat 档案对齐)   ← P2
             RF-308 (WeChat 角度UI)     ← P2

  Day 19-20: 集成测试 + Bug 修复 + 缓冲
             Sprint 1 Review：功能对齐 Demo（三端对比演示）
```

**关键里程碑**：
- **Week 2 末**：Android 核心功能对齐（Compare + i18n）完成，WeChat Compare + 趋势完成
- **Week 3 末**：Android 训练增强 + Strava 完成，WeChat 语音 + 云存储完成
- **Week 4 末**：全部 P0/P1 完成，Sprint Review

---

## 七、Definition of Done（Sprint 1 完成定义，修订版）

- [ ] Android 端对比、趋势、训练增强、多语言四项 P0 功能对齐完成
- [ ] WeChat 端对比、趋势两项 P0 功能对齐完成
- [ ] Android 基础设施：Hilt DI + Room DB + 测试框架 + API 认证就绪
- [ ] iOS 端 SwiftLint + XCTest 基础测试框架就绪
- [ ] 后端 compare API + 反馈 API 就绪
- [ ] 后端 CI 流水线在 GitHub Actions 通过
- [ ] 全部 P0 条目代码 Review 通过
- [ ] **功能对齐审计通过**：Android 端 ≥ 80% iOS 核心功能覆盖，WeChat 端 ≥ 80% iOS 核心功能覆盖（排除平台限制项）
- [ ] Sprint Review Demo：三端功能对齐对比演示
- [ ] **CoreMotion 恢复评估**：对齐完成后，由 CEO 决策何时恢复 CoreMotion 新功能开发

---

## 八、风险与缓解

| 风险 | 影响条目 | 缓解措施 |
|------|---------|----------|
| Android Hilt 接入现有代码改造量超预期 | RF-200/201/202 等全部依赖 Hilt 的条目 | 先做最小改造（仅 AppViewModel + ApiClient），其他 Screen 在后续条目中逐步迁移 |
| Android Room 数据迁移失败导致用户数据丢失 | RF-211 | 迁移脚本先备份 SharedPreferences → JSON 文件到 cache 目录；迁移失败回退读取 SharedPreferences |
| Strava OAuth Android 平台兼容性问题 | RF-205 | 先用 Chrome Custom Tabs 实现 OAuth flow（而非 WebView），兼容性更好；预留 2 天缓冲 |
| 微信云开发环境审批周期长 | RF-306 | 先提交申请（Week 1），如审批未完成，保持本地 Storage 方案，降级为 P2 |
| 微信语音方案（讯飞插件审批） | RF-305 | 优先实现预录音频方案（保底），讯飞插件作为增强 |
| 人员资源不足（iOS 开发者无 CoreMotion 工作） | RF-402/403 | iOS 开发者专注于技术债清理 + XCTest 搭建，为恢复 CoreMotion 打好基础；如果提前完成可支援 Android/WeChat |
| Sprint 1 延长至 4 周，团队士气/节奏 | 全局 | 每周末进行 Sprint 进度同步会，明确里程碑；第 4 周预留缓冲 |

---

## 九、Sprint 2 预告（初步）

**前提**：Sprint 1 功能对齐达成后，Sprint 2 将：

1. **恢复 CoreMotion 新功能开发**（原 RUNFORM-103 ~ 107 + 110 ~ 113）
2. **Android 传感器管线筹建**（SensorManager → 步频 → TTS）
3. **WeChat 步频模式**（wx.onAccelerometerChange）
4. **iOS AudioCoachManager**（Phase 4 实时语音合成）
5. **三端 CI 测试门禁全面上线**

---

## 十、MoveNova 多产品策略对齐备注

本次功能对齐 Sprint 不仅服务于 RunForm，也为后续 SwimForm / TennisForm / GolfForm / LiftForm 的跨平台对齐建立**可复用的流程模板**：

- **iOS 功能清单 → 跨平台审计表**：后续产品可直接复用此模板
- **Android 基础设施（Hilt + Room + 测试）**：后续产品可直接复用相同架构
- **WeChat 云存储方案**：后续产品可共享云开发环境
- **后端 API 对齐模式**：每个产品先确认 iOS 的 API 表面 → 验证 Android/WeChat 是否匹配

本次 Sprint 产出的流程和经验，将沉淀为 MoveNova 跨平台对齐规范文档。

---

> **文档版本**：v2.0（修订版）
> **原文档**：`product/sprint-1-backlog.md`（v1.0，已废弃）
> **下一步**：CEO 审批修订版 → Sprint Planning 确认指派人 → 创建 GitHub Issues → Week 1 启动
