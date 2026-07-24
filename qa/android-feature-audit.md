# RunForm Android 功能模块全面审计

> 审计日期: 2026-07-05  
> 项目路径: `~/workspace/runform/android/`  
> 包名: `com.runformcoach.runformcoachai`  
> Kotlin 文件总数: 63  
> 架构: Jetpack Compose + Hilt DI + Room DB + Retrofit + ML Kit + Firebase

---

## 目录

1. [应用入口与架构](#1-应用入口与架构)
2. [用户认证系统](#2-用户认证系统)
3. [跑步功能](#3-跑步功能)
4. [分享功能](#4-分享功能)
5. [Strava 集成](#5-strava-集成)
6. [设置页面](#6-设置页面)
7. [个人资料](#7-个人资料)
8. [订阅/付费](#8-订阅付费)
9. [隐私政策](#9-隐私政策)
10. [数据层](#10-数据层)
11. [测试](#11-测试)
12. [总结](#12-总结)

---

## 1. 应用入口与架构

### 1.1 主入口

| 功能 | 文件路径 | 状态 |
|------|----------|------|
| MainActivity (单 Activity 架构) | `app/src/main/java/.../MainActivity.kt` | ✅ 完整 |
| AppRoot Composable (5-Tab 底部导航) | `app/src/main/java/.../MainActivity.kt` | ✅ 完整 |
| RunFormApplication (Hilt 入口) | `app/src/main/java/.../RunFormApplication.kt` | ✅ 完整 |
| AndroidManifest.xml | `app/src/main/AndroidManifest.xml` | ✅ 完整 |

### 1.2 主题与通用组件

| 功能 | 文件路径 | 状态 |
|------|----------|------|
| AppColors 调色板 + 暗色主题 | `app/src/main/java/.../AppTheme.kt` | ✅ 完整 |
| GlassCard / DarkCard / SectionTitle 组件 | `app/src/main/java/.../AppTheme.kt` | ✅ 完整 |
| AppBackground 渐变背景 | `app/src/main/java/.../AppTheme.kt` | ✅ 完整 |

### 1.3 依赖注入 (Hilt)

| 模块 | 文件路径 | 状态 |
|------|----------|------|
| ApiModule (Retrofit + OkHttp) | `app/src/main/java/.../di/ApiModule.kt` | ✅ 完整 |
| DatabaseModule (Room) | `app/src/main/java/.../di/DatabaseModule.kt` | ✅ 完整 |
| AnalyticsModule (Firebase) | `app/src/main/java/.../di/AnalyticsModule.kt` | ✅ 完整 |
| AuthModule (TokenManager) | `app/src/main/java/.../auth/TokenManager.kt` | ✅ 完整 |

### 1.4 启动优化

| 功能 | 文件路径 | 状态 |
|------|----------|------|
| StartupOptimizer (冷启动优化/ANR看门狗) | `app/src/main/java/.../StartupOptimizer.kt` | ✅ 完整 |
| StrictMode (Debug) | `app/src/main/java/.../StartupOptimizer.kt` | ✅ 完整 |
| Firebase 延迟初始化 (IdleHandler) | `app/src/main/java/.../StartupOptimizer.kt` | ✅ 完整 |

### 1.5 分析追踪

| 功能 | 文件路径 | 状态 |
|------|----------|------|
| AnalyticsHelper (Firebase Analytics + Crashlytics) | `app/src/main/java/.../analytics/AnalyticsHelper.kt` | ✅ 完整 |
| 屏幕浏览追踪 (logScreenView) | `analytics/AnalyticsHelper.kt` | ✅ 完整 |
| 分析事件追踪 (analysis_started/completed) | `analytics/AnalyticsHelper.kt` | ✅ 完整 |
| 训练计划事件 (plan_generated) | `analytics/AnalyticsHelper.kt` | ✅ 完整 |
| 实时指导录音事件 | `analytics/AnalyticsHelper.kt` | ✅ 完整 |
| Crashlytics 非致命错误记录 | `analytics/AnalyticsHelper.kt` | ✅ 完整 |

---

## 2. 用户认证系统

### 2.1 认证基础设施

| 功能 | 文件路径 | 状态 |
|------|----------|------|
| TokenManager (EncryptedSharedPreferences) | `app/src/main/java/.../auth/TokenManager.kt` | ✅ 完整 |
| AuthInterceptor (Bearer Token + 401 自动刷新) | `app/src/main/java/.../auth/AuthInterceptor.kt` | ✅ 完整 |
| isAuthenticated 状态 | `auth/TokenManager.kt` | ✅ 完整 |
| Token 刷新逻辑 | `auth/AuthInterceptor.kt` | ✅ 完整 |

### 2.2 用户注册/登录/邮箱验证/密码重置

| 功能 | 文件路径 | 状态 |
|------|----------|------|
| 注册屏幕 | — | ❌ 未实现 |
| 登录屏幕 | — | ❌ 未实现 |
| 邮箱验证 | — | ❌ 未实现 |
| 密码重置 | — | ❌ 未实现 |
| 第三方登录 (Google/Apple) | — | ❌ 未实现 |

> **说明**: 认证基础设施已就绪（TokenManager + AuthInterceptor），但目前没有用户注册/登录的 UI 界面。应用使用本地 UUID（UserIdentity）作为用户标识（见 `ChallengeViewModel.kt`）。

### 2.3 用户身份

| 功能 | 文件路径 | 状态 |
|------|----------|------|
| UserIdentity (本地 UUID 生成) | `app/src/main/java/.../ChallengeViewModel.kt` | ✅ 完整 |
| SharedPreferences 持久化 | `ChallengeViewModel.kt` | ✅ 完整 |

---

## 3. 跑步功能

### 3.1 视频分析（核心功能）

| 功能 | 文件路径 | 状态 |
|------|----------|------|
| AnalyzeScreen (视频分析主界面) | `app/src/main/java/.../AnalyzeScreen.kt` | ✅ 完整 |
| 视频选择 (Gallery Picker) | `AnalyzeScreen.kt` | ✅ 完整 |
| 视频录制 (Camera Capture) | `AnalyzeScreen.kt` | ✅ 完整 |
| 三种拍摄角度 (Side/Rear/Front) | `AnalyzeScreen.kt` | ✅ 完整 |
| 视频压缩 (720p@30fps MediaCodec) | `app/src/main/java/.../utils/VideoCompressor.kt` | ✅ 完整 |
| 压缩进度条 + 开关 | `AnalyzeScreen.kt` | ✅ 完整 |
| 分析结果展示 (AnalysisResultScreen) | `app/src/main/java/.../AnalysisResultScreen.kt` | ✅ 完整 |
| 综合评分环形图 (ConfidenceRing) | `AnalysisResultScreen.kt` | ✅ 完整 |
| 视频质量评分 | `AnalysisResultScreen.kt` | ✅ 完整 |
| 运动指标列表 (MetricRow) | `AnalysisResultScreen.kt` | ✅ 完整 |
| 问题分析卡片 (IssueCard) | `AnalysisResultScreen.kt` | ✅ 完整 |
| 推荐训练动作 (ExerciseCard) | `AnalysisResultScreen.kt` | ✅ 完整 |
| 受伤风险提示 | `AnalysisResultScreen.kt` | ✅ 完整 |
| 用户反馈评分 (5星 + 评论) | `AnalysisResultScreen.kt` + `FeedbackViewModel.kt` | ✅ 完整 |
| 反馈离线缓存 | `FeedbackViewModel.kt` + `FeedbackDao.kt` | ✅ 完整 |
| 反馈同步 (联网后自动同步) | `FeedbackViewModel.kt` | ✅ 完整 |
| AdMob 横幅广告 | `AnalysisResultScreen.kt` | ✅ 完整 |
| 录制提示卡片 | `AnalyzeScreen.kt` | ✅ 完整 |

### 3.2 实时传感器跑步管线

| 功能 | 文件路径 | 状态 |
|------|----------|------|
| SensorCaptureManager (加速度计+陀螺仪 ~50Hz) | `app/src/main/java/.../sensor/SensorManager.kt` | ✅ 完整 |
| SensorService (前台服务，后台运行) | `app/src/main/java/.../sensor/SensorService.kt` | ✅ 完整 |
| 通知渠道 "RunForm Running" | `sensor/SensorService.kt` | ✅ 完整 |
| RingBuffer (环形缓冲区 300帧) | `app/src/main/java/.../sensor/RingBuffer.kt` | ✅ 完整 |
| CadenceDetector (步频检测/零交叉) | `app/src/main/java/.../sensor/CadenceDetector.kt` | ✅ 完整 |
| GaitAnalyzer (步态分析: 振幅/GCT/躯干倾角) | `app/src/main/java/.../sensor/GaitAnalyzer.kt` | ✅ 完整 |
| AudioCoachEngine (TTS 实时语音教练) | `app/src/main/java/.../sensor/AudioCoachEngine.kt` | ✅ 完整 |
| 多语言支持 (en/zh/nl) | `sensor/AudioCoachEngine.kt` | ✅ 完整 |
| LiveRunningDashboard (实时跑步仪表盘 UI) | `app/src/main/java/.../sensor/LiveRunningDashboard.kt` | ✅ 完整 |
| RunSessionManager (管线编排器: 状态机) | `app/src/main/java/.../sensor/RunSessionManager.kt` | ✅ 完整 |
| 会话状态机 (idle→ready→running→paused→stopped) | `sensor/RunSessionManager.kt` | ✅ 完整 |
| 会话配置 (目标步频/语言/采样率) | `sensor/RunSessionManager.kt` | ✅ 完整 |
| 聚合指标回调 (SessionMetrics) | `sensor/RunSessionManager.kt` | ✅ 完整 |

### 3.3 实时指导录制

| 功能 | 文件路径 | 状态 |
|------|----------|------|
| LiveGuidanceRecorderScreen (CameraX + ML Kit) | `app/src/main/java/.../LiveGuidanceRecorderScreen.kt` | ✅ 完整 |
| LiveGuidanceViewModel (姿态检测+录制) | `app/src/main/java/.../LiveGuidanceViewModel.kt` | ✅ 完整 |
| ML Kit Pose Detection (实时骨骼线) | `LiveGuidanceViewModel.kt` | ✅ 完整 |
| 身体位置指引 (TOO_CLOSE/TOO_FAR/NO_PERSON) | `LiveGuidanceViewModel.kt` | ✅ 完整 |
| 录制计时器 | `LiveGuidanceViewModel.kt` | ✅ 完整 |
| 录制完成回调 → 分析流程 | `LiveGuidanceViewModel.kt` | ⚠️ TODO 标记 (RF-801) |

### 3.4 跑步会话回放 (RF-1000)

| 功能 | 文件路径 | 状态 |
|------|----------|------|
| RunSessionReplayScreen (1233行，全功能回放) | `app/src/main/java/.../RunSessionReplayScreen.kt` | ✅ 完整 |
| RunSessionReplayViewModel (会话列表+详情+回放) | `app/src/main/java/.../RunSessionReplayViewModel.kt` | ✅ 完整 |
| 会话列表 (GET /api/v1/sessions) | `RunSessionReplayViewModel.kt` | ✅ 完整 |
| 会话详情 (GET /api/v1/sessions/{id}) | `RunSessionReplayViewModel.kt` | ✅ 完整 |
| 时间序列数据回放 (4Hz) | `RunSessionReplayViewModel.kt` | ✅ 完整 |
| 播放/暂停/停止/拖拽控制 | `RunSessionReplayScreen.kt` | ✅ 完整 |
| GPS 路径地图追踪 | `RunSessionReplayScreen.kt` (包含路径坐标渲染) | ✅ 完整 |
| 教练提示时间轴叠加 | `RunSessionReplayViewModel.kt` | ✅ 完整 |
| 多指标并行图表 (步频/振幅/GCT/躯干倾角) | `RunSessionReplayScreen.kt` | ✅ 完整 |

### 3.5 历史记录

| 功能 | 文件路径 | 状态 |
|------|----------|------|
| HistoryScreen (分析历史列表) | `app/src/main/java/.../HistoryScreen.kt` | ✅ 完整 |
| 历史趋势图 (Canvas 折线图) | `HistoryScreen.kt` | ✅ 完整 |
| 趋势图交互提示 (Tooltip) | `HistoryScreen.kt` | ✅ 完整 |
| 历史卡片展开/折叠 | `HistoryScreen.kt` | ✅ 完整 |
| 清空所有历史 (AlertDialog) | `HistoryScreen.kt` | ✅ 完整 |
| 空状态占位图 | `HistoryScreen.kt` | ✅ 完整 |
| Room 持久化 (最多50条) | `AppViewModel.kt` + `AnalysisDao.kt` | ✅ 完整 |

### 3.6 训练计划

| 功能 | 文件路径 | 状态 |
|------|----------|------|
| PlanScreen (训练计划主界面) | `app/src/main/java/.../PlanScreen.kt` | ✅ 完整 |
| 周计划生成 (Weekly Plan) | `PlanScreen.kt` + `AppViewModel.kt` | ✅ 完整 |
| 马拉松训练计划 | `app/src/main/java/.../MarathonPlanScreen.kt` | ✅ 完整 |
| MarathonPlanViewModel | `app/src/main/java/.../MarathonPlanViewModel.kt` | ✅ 完整 |
| 六大马拉松 Major 选择 | `MarathonPlanScreen.kt` + `Models.kt` | ✅ 完整 |
| 计划生成参数 (周里程/目标/可用日/受伤标记) | `PlanScreen.kt` | ✅ 完整 |
| 阶段视图 (Phase View) | `MarathonPlanScreen.kt` | ✅ 完整 |
| 周视图 (Week View) | `MarathonPlanScreen.kt` | ✅ 完整 |
| 比赛计划 (Race Plan) | `PlanScreen.kt` | ⚠️ 仅占位 (RacePlanPlaceholder) |
| 计划保存到 Room | `AppViewModel.kt` + `PlanDao.kt` | ✅ 完整 |
| 已保存计划列表 (SavedPlansScreen) | `app/src/main/java/.../SavedPlansScreen.kt` | ✅ 完整 |
| 滑动删除计划 | `SavedPlansScreen.kt` | ✅ 完整 |
| 计划编辑 (EditPlanScreen) | `app/src/main/java/.../EditPlanScreen.kt` | ✅ 完整 |
| 添加/修改/删除训练条目 | `EditPlanScreen.kt` + `AppViewModel.kt` | ✅ 完整 |
| 计划类型 Tab (Weekly/Marathon/Race) | `PlanScreen.kt` | ✅ 完整 |
| 每周步态复查卡片 | `PlanScreen.kt` | ⚠️ TODO (hardcoded) |
| 多语言训练计划 (en/zh) | `PlanScreen.kt` | ✅ 完整 |

### 3.7 精英对比

| 功能 | 文件路径 | 状态 |
|------|----------|------|
| CompareScreen (精英运动员对比 + 自定义对比) | `app/src/main/java/.../CompareScreen.kt` | ✅ 完整 |
| CompareViewModel | `app/src/main/java/.../CompareViewModel.kt` | ✅ 完整 |
| CompareResultScreen (对比结果展示) | `app/src/main/java/.../CompareResultScreen.kt` | ✅ 完整 |
| CompareHistoryScreen (历史对比浏览) | `app/src/main/java/.../CompareHistoryScreen.kt` | ✅ 完整 |
| 精英运动员列表 (GET /athletes) | `CompareScreen.kt` | ✅ 完整 |
| 与精英运动员对比 (POST /compare) | `CompareViewModel.kt` | ✅ 完整 |
| 自定义两两对比 (本地计算) | `CompareViewModel.kt` | ✅ 完整 |
| 相似度评分 / 差距分析 | `CompareResultScreen.kt` | ✅ 完整 |
| 22 项 PoseMetrics 指标映射 | `CompareViewModel.kt` | ✅ 完整 |

### 3.8 周度洞察 (RF-912)

| 功能 | 文件路径 | 状态 |
|------|----------|------|
| WeeklyInsightScreen (周度训练洞察报告) | `app/src/main/java/.../WeeklyInsightScreen.kt` | ✅ 完整 |
| WeeklyInsightViewModel | `app/src/main/java/.../WeeklyInsightViewModel.kt` | ✅ 完整 |
| 本周 vs 上周指标对比 (步频/振幅/GCT) | `WeeklyInsightScreen.kt` | ✅ 完整 |
| 趋势箭头 (↗/↘/→) | `WeeklyInsightScreen.kt` | ✅ 完整 |
| 成就徽章展示 | `WeeklyInsightScreen.kt` | ✅ 完整 |
| AI 教练建议 | `WeeklyInsightScreen.kt` | ✅ 完整 |
| 分享卡片生成 (Canvas Bitmap) | `WeeklyInsightViewModel.kt` | ✅ 完整 |

### 3.9 挑战功能 (RF-601)

| 功能 | 文件路径 | 状态 |
|------|----------|------|
| ChallengeScreen (挑战主界面) | `app/src/main/java/.../ChallengeScreen.kt` | ✅ 完整 |
| ChallengeViewModel | `app/src/main/java/.../ChallengeViewModel.kt` | ✅ 完整 |
| 挑战列表 (GET /api/v1/challenges) | `ChallengeViewModel.kt` | ✅ 完整 |
| 加入挑战 (POST join) | `ChallengeViewModel.kt` | ✅ 完整 |
| 每日签到 (POST check-in) | `ChallengeViewModel.kt` | ✅ 完整 |
| 排行榜 (GET leaderboard) | `ChallengeScreen.kt` | ✅ 完整 |
| 进度环形图 | `ChallengeScreen.kt` | ✅ 完整 |
| 挑战任务清单 | `ChallengeScreen.kt` | ✅ 完整 |

---

## 4. 分享功能

### 4.1 文本分享

| 功能 | 文件路径 | 状态 |
|------|----------|------|
| 分析结果文本分享 (Intent.ACTION_SEND) | `AnalysisResultScreen.kt` | ✅ 完整 |
| "考古学"模板分享 (Marketing) | `AnalysisResultScreen.kt` | ✅ 完整 |

### 4.2 图片卡片分享 (RF-1001)

| 功能 | 文件路径 | 状态 |
|------|----------|------|
| ShareCardRenderer (Canvas Bitmap 渲染) | `app/src/main/java/.../ShareCardRenderer.kt` | ✅ 完整 |
| 分析结果分享卡 (1080×1440) | `ShareCardRenderer.kt` | ✅ 完整 |
| 历史记录分享卡 | `ShareCardRenderer.kt` | ✅ 完整 |
| 训练计划分享卡 | `ShareCardRenderer.kt` | ✅ 完整 |
| 保存到相册 (MediaStore Android 10+/Legacy) | `ShareCardRenderer.kt` | ✅ 完整 |
| Intent 分享图片 | `AnalysisResultScreen.kt` / `HistoryScreen.kt` / `PlanScreen.kt` | ✅ 完整 |
| 周度洞察分享卡 | `WeeklyInsightViewModel.kt` | ✅ 完整 |

### 4.3 链接分享

| 功能 | 文件路径 | 状态 |
|------|----------|------|
| 链接分享 | — | ❌ 未实现 |

---

## 5. Strava 集成

| 功能 | 文件路径 | 状态 |
|------|----------|------|
| Strava OAuth 认证 | — | ❌ 未实现 |
| Strava 数据同步 | — | ❌ 未实现 |
| Strava 跑步导入 | — | ❌ 未实现 |

> **说明**: 代码中无任何 Strava 相关引用。搜索 `Strava`、`strava` 返回零结果。

---

## 6. 设置页面

| 功能 | 文件路径 | 状态 |
|------|----------|------|
| 独立设置页面 | — | ❌ 未实现 |
| 语言切换 | — | ❌ 未实现（仅依据系统 Locale 自动选择） |
| 通知设置 | — | ❌ 未实现 |
| 数据管理 | — | ❌ 未实现 |
| 关于页面 | — | ❌ 未实现 |

---

## 7. 个人资料

### 7.1 个人资料页面

| 功能 | 文件路径 | 状态 |
|------|----------|------|
| ProfileScreen (个人资料 Tab) | `app/src/main/java/.../ProfileScreen.kt` | ✅ 完整 |
| 身份信息 (名/姓/昵称) | `ProfileScreen.kt` | ✅ 完整 |
| 跑步经验等级 (Beginner/Intermediate/Advanced) | `ProfileScreen.kt` | ✅ 完整 |
| 训练目标 (5K/10K/Half Marathon/Marathon/General Fitness) | `ProfileScreen.kt` | ✅ 完整 |
| 跑步统计 (周里程/跑步天数/运动小时) | `ProfileScreen.kt` | ✅ 完整 |
| 身体数据 (身高/体重) | `ProfileScreen.kt` | ✅ 完整 |
| 受伤/医疗备注 | `ProfileScreen.kt` | ✅ 完整 |
| 装备数据 (鞋码EU/US/UK/腿长/品牌/型号) (RF-208) | `ProfileScreen.kt` | ✅ 完整 |
| 保存到 Room (ProfileDao) | `ProfileScreen.kt` + `AppViewModel.kt` | ✅ 完整 |
| 鞋码单位转换 (EU↔US↔UK) | `Models.kt` (TesterProfile) | ✅ 完整 |

### 7.2 个人资料数据模型

| 功能 | 文件路径 | 状态 |
|------|----------|------|
| TesterProfile (12 字段) | `app/src/main/java/.../Models.kt` | ✅ 完整 |
| RunnerProfileEntity (Room) | `app/src/main/java/.../data/RunnerProfileEntity.kt` | ✅ 完整 |
| ProfileDao | `app/src/main/java/.../data/ProfileDao.kt` | ✅ 完整 |
| MigrationHelper (SharedPreferences → Room) | `app/src/main/java/.../data/MigrationHelper.kt` | ✅ 完整 |

---

## 8. 订阅/付费

| 功能 | 文件路径 | 状态 |
|------|----------|------|
| 付费墙 (Paywall) | — | ❌ 未实现 |
| 订阅管理 | — | ❌ 未实现 |
| Google Play Billing | — | ❌ 未实现 |
| 免费/付费功能区分 | — | ❌ 未实现 |

---

## 9. 隐私政策

| 功能 | 文件路径 | 状态 |
|------|----------|------|
| 隐私政策页面 | — | ❌ 未实现 |
| 服务条款页面 | — | ❌ 未实现 |
| GDPR/数据保护弹窗 | — | ❌ 未实现 |

---

## 10. 数据层

### 10.1 Room 数据库

| 功能 | 文件路径 | 状态 |
|------|----------|------|
| RunFormDatabase (v2, WAL 模式) | `app/src/main/java/.../data/RunFormDatabase.kt` | ✅ 完整 |
| AnalysisHistoryEntity (分析记录) | `data/AnalysisHistoryEntity.kt` | ✅ 完整 |
| AnalysisDao (CRUD + Flow 观察) | `data/AnalysisDao.kt` | ✅ 完整 |
| SavedPlanEntity (训练计划) | `data/SavedPlanEntity.kt` | ✅ 完整 |
| PlanDao | `data/PlanDao.kt` | ✅ 完整 |
| RunnerProfileEntity (用户资料) | `data/RunnerProfileEntity.kt` | ✅ 完整 |
| ProfileDao | `data/ProfileDao.kt` | ✅ 完整 |
| FeedbackEntity (离线反馈) | `data/FeedbackEntity.kt` | ✅ 完整 |
| FeedbackDao (含未同步/标记同步/清理) | `data/FeedbackDao.kt` | ✅ 完整 |

### 10.2 API 客户端

| 功能 | 文件路径 | 状态 |
|------|----------|------|
| RunFormApi (Retrofit Interface) | `app/src/main/java/.../ApiClient.kt` | ✅ 完整 |
| POST /analyze (视频分析) | `ApiClient.kt` | ✅ 完整 |
| POST /training-plan (训练计划) | `ApiClient.kt` | ✅ 完整 |
| GET /athletes (精英运动员) | `ApiClient.kt` | ✅ 完整 |
| POST /api/v1/compare (对比) | `ApiClient.kt` | ✅ 完整 |
| POST /api/v1/feedback (反馈) | `ApiClient.kt` | ✅ 完整 |
| GET /api/v1/sessions/trends (周趋势) | `ApiClient.kt` | ✅ 完整 |
| GET /api/v1/sessions (跑步会话列表) | `ApiClient.kt` | ✅ 完整 |
| GET /api/v1/sessions/{id} (会话详情) | `ApiClient.kt` | ✅ 完整 |
| GET /api/v1/challenges (挑战列表) | `ApiClient.kt` | ✅ 完整 |
| POST /api/v1/challenges/{id}/join | `ApiClient.kt` | ✅ 完整 |
| GET /api/v1/challenges/{id}/leaderboard | `ApiClient.kt` | ✅ 完整 |
| POST /api/v1/challenges/{id}/check-in | `ApiClient.kt` | ✅ 完整 |

### 10.3 数据模型

| 功能 | 文件路径 | 状态 |
|------|----------|------|
| Models.kt (主数据模型 344行) | `app/src/main/java/.../Models.kt` | ✅ 完整 |
| ChallengeModels.kt | `app/src/main/java/.../ChallengeModels.kt` | ✅ 完整 |
| CompareModels.kt (PoseMetrics 22字段) | `app/src/main/java/.../CompareModels.kt` | ✅ 完整 |
| WeeklyInsightModels.kt | `app/src/main/java/.../WeeklyInsightModels.kt` | ✅ 完整 |

---

## 11. ViewModel 汇总

| ViewModel | 文件路径 | 行数 | 状态 |
|-----------|----------|------|------|
| AppViewModel (核心 VM) | `AppViewModel.kt` | 484 | ✅ 完整 |
| CompareViewModel | `CompareViewModel.kt` | 320 | ✅ 完整 |
| FeedbackViewModel | `FeedbackViewModel.kt` | 181 | ✅ 完整 |
| ChallengeViewModel | `ChallengeViewModel.kt` | 176 | ✅ 完整 |
| MarathonPlanViewModel | `MarathonPlanViewModel.kt` | 187 | ✅ 完整 |
| WeeklyInsightViewModel | `WeeklyInsightViewModel.kt` | 248 | ✅ 完整 |
| RunSessionReplayViewModel | `RunSessionReplayViewModel.kt` | 220 | ✅ 完整 |
| LiveGuidanceViewModel | `LiveGuidanceViewModel.kt` | 295 | ✅ 完整 |
| EditPlanViewModel (内嵌在 EditPlanScreen.kt) | `EditPlanScreen.kt` | ~910 | ✅ 完整 |
| MainViewModel (已废弃) | `MainViewModel.kt` | 3 | ⚠️ 已标记废弃 |

---

## 12. Screen / Composable 汇总

| Screen/Composable | 文件路径 | 行数 | 状态 |
|-------------------|----------|------|------|
| AppRoot (5-Tab 导航) | `MainActivity.kt` | ~60 | ✅ 完整 |
| AnalyzeScreen | `AnalyzeScreen.kt` | 413 | ✅ 完整 |
| AnalysisResultScreen | `AnalysisResultScreen.kt` | 572 | ✅ 完整 |
| HistoryScreen | `HistoryScreen.kt` | 717 | ✅ 完整 |
| PlanScreen | `PlanScreen.kt` | 679 | ✅ 完整 |
| ProfileScreen | `ProfileScreen.kt` | 358 | ✅ 完整 |
| ChallengeScreen | `ChallengeScreen.kt` | 804 | ✅ 完整 |
| CompareScreen | `CompareScreen.kt` | 550 | ✅ 完整 |
| CompareResultScreen | `CompareResultScreen.kt` | 512 | ✅ 完整 |
| CompareHistoryScreen | `CompareHistoryScreen.kt` | 264 | ✅ 完整 |
| MarathonPlanScreen | `MarathonPlanScreen.kt` | 821 | ✅ 完整 |
| SavedPlansScreen | `SavedPlansScreen.kt` | 357 | ✅ 完整 |
| EditPlanScreen | `EditPlanScreen.kt` | 910 | ✅ 完整 |
| LiveGuidanceRecorderScreen | `LiveGuidanceRecorderScreen.kt` | 255 | ✅ 完整 |
| LiveRunningDashboard | `sensor/LiveRunningDashboard.kt` | 587 | ✅ 完整 |
| RunSessionReplayScreen | `RunSessionReplayScreen.kt` | 1233 | ✅ 完整 |
| WeeklyInsightScreen | `WeeklyInsightScreen.kt` | 596 | ✅ 完整 |

---

## 12. 总结

### ✅ 已完整实现 (46 项)

| 模块 | 完成度 |
|------|--------|
| 视频分析管线 (上传/压缩/结果/反馈) | 100% |
| 实时传感器跑步教练管线 (Sensor→Cadence→Gait→TTS) | 100% |
| 跑步会话回放 (列表/详情/时间序列/GPS/提示) | 100% |
| 历史记录 + 趋势图 | 100% |
| 训练计划 (周计划/马拉松/编辑/保存) | 90% |
| 精英对比 (运动员对比/自定义两两对比) | 100% |
| 挑战系统 (加入/签到/排行榜) | 100% |
| 周度洞察报告 | 100% |
| 个人资料 (含装备数据) | 100% |
| 分享卡片渲染 (分析/历史/计划/洞察) | 100% |
| 认证基础设施 (Token/Interceptor) | 100% |
| 启动优化 (冷启动/ANR看门狗/StrictMode) | 100% |
| Firebase 分析 + Crashlytics | 100% |
| Room 数据库 (4表/4DAO) | 100% |
| 实时指导录制 (CameraX + ML Kit Pose) | 90% |
| AdMob 广告集成 | 100% |

### ❌ 未实现 (12 项)

| 功能 | 优先级 |
|------|--------|
| 用户注册/登录/邮箱验证/密码重置 UI | 🔴 高 |
| 设置页面 | 🟡 中 |
| 隐私政策/服务条款页面 | 🟡 中 |
| Strava OAuth 集成 | 🟡 中 |
| 订阅/付费系统 | 🟡 中 |
| Race Plan 具体实现 (仅有占位) | 🟢 低 |
| 每周步态复查 (TODO 标记) | 🟢 低 |
| 链接分享 | 🟢 低 |
| 语言切换设置 | 🟢 低 |

### ⚠️ 部分实现 / TODO 标记

| 功能 | 说明 |
|------|------|
| LiveGuidanceRecorderScreen 录制完成回调 | RF-801 标记 TODO |
| Race Plan | RacePlanPlaceholder 仅显示提示文字 |
| 每周步态复查卡片 | `PlanScreen.kt` 硬编码提示无数据 |
| MainViewModel | 已废弃，被 AppViewModel 取代 |
