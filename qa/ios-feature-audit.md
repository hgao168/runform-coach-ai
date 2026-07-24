# iOS RunForm 应用功能全面审计

> 审计日期: 2026-07-05  
> 项目版本: 1.3 (Build 3)  
> Swift 版本: 5.9  
> iOS 最低目标: 17.0  
> 后端: Railway (Railway)  
> 审计范围: 53 个 Swift 文件 + 3 个本地化字符串文件  

---

## 一、应用架构概览

| 层级 | 组件 | 文件 |
|------|------|------|
| 入口 | App Entry | `RunFormCoachAIApp.swift` |
| 状态管理 | State Store | `AppStore.swift` |
| 导航 | TabView (5 Tab) | `ContentView.swift` |
| 主题 | Design System | `AppTheme.swift` + `UIComponents.swift` |
| 网络 | API Client | `APIClient.swift` |
| 性能 | Perf Optimizer | `PerformanceOptimizer.swift` |

**5 个主 Tab:** Analyze / History / Challenges / Plan / Profile

---

## 二、用户认证系统 (Authentication)

### 2.1 注册 (Register)

| 功能点 | 文件路径 | 实现状态 |
|--------|----------|----------|
| 邮箱+密码注册 UI | `RunFormCoachAI/LoginView.swift` (L174-189) | ✅ 完整实现 |
| 注册 API 调用 | `RunFormCoachAI/APIClient.swift` (L321-333, `register()`) | ✅ 完整实现 |
| 注册请求模型 | `RunFormCoachAI/ProfileModels.swift` (L216-220, `RegisterRequest`) | ✅ 完整实现 |
| 注册失败提示（重复账号） | `RunFormCoachAI/LoginView.swift` (L184-188) | ✅ 完整实现 |
| 昵称字段（注册时） | `RunFormCoachAI/LoginView.swift` (L94-99) | ✅ 完整实现 |

### 2.2 登录 (Login)

| 功能点 | 文件路径 | 实现状态 |
|--------|----------|----------|
| 邮箱+密码登录 UI | `RunFormCoachAI/LoginView.swift` (L25-48, 153-207) | ✅ 完整实现 |
| 登录 API 调用 | `RunFormCoachAI/APIClient.swift` (L335-343, `login()`) | ✅ 完整实现 |
| 登录请求模型 | `RunFormCoachAI/ProfileModels.swift` (L222-225, `LoginRequest`) | ✅ 完整实现 |
| 登录成功状态持久化 | `RunFormCoachAI/AppStore.swift` (L302-323, `signIn()`) | ✅ 完整实现 |
| Google 登录 | `RunFormCoachAI/APIClient.swift` (L345-353, `googleAuth()`) + `Info.plist` (Google OAuth URL Scheme) + `project.yml` (GoogleSignIn 包依赖) | ⚠️ API 就绪，UI 未集成 |
| Google Sign-In SDK | `project.yml` (L23-25, GoogleSignIn 8.0.0) | ✅ 依赖已配置 |

### 2.3 邮箱验证 (Email Verification)

| 功能点 | 文件路径 | 实现状态 |
|--------|----------|----------|
| 邮箱验证状态字段 | `RunFormCoachAI/ProfileModels.swift` (L178, `emailVerified`) | ⚠️ 仅模型字段，无 UI 展示 |
| 邮箱验证流程 | — | ❌ 未实现 |

### 2.4 密码重置 (Password Reset)

| 功能点 | 文件路径 | 实现状态 |
|--------|----------|----------|
| 忘记密码 UI 按钮 | `RunFormCoachAI/LoginView.swift` (L130-138) | ✅ 完整实现 |
| 密码重置 API 调用 | `RunFormCoachAI/APIClient.swift` (L355-363, `requestPasswordReset()`) | ✅ 完整实现 |
| 密码重置请求模型 | `RunFormCoachAI/ProfileModels.swift` (L227-234, `PasswordResetRequest/Response`) | ✅ 完整实现 |
| 密码重置 Token 验证页面 | — | ❌ 未实现（依赖后端邮件链接） |

### 2.5 登出 (Sign Out)

| 功能点 | 文件路径 | 实现状态 |
|--------|----------|----------|
| 登出按钮 (ProfileView) | `RunFormCoachAI/ProfileView.swift` (L354-360, `signOff()`) | ✅ 完整实现 |
| 登出状态清除 | `RunFormCoachAI/AppStore.swift` (L335-346, `signOut()`) | ✅ 完整实现 |

---

## 三、用户资料系统 (Profile)

### 3.1 个人资料表单

| 功能点 | 文件路径 | 实现状态 |
|--------|----------|----------|
| 资料页面 | `RunFormCoachAI/ProfileView.swift` (L1-712) | ✅ 完整实现 |
| 资料数据模型 | `RunFormCoachAI/ProfileModels.swift` (L5-118, `TesterProfile`) | ✅ 完整实现 |
| 资料保存 API | `RunFormCoachAI/APIClient.swift` (L278-319, `saveProfile()`) | ✅ 完整实现 |
| 资料保存请求模型 | `RunFormCoachAI/ProfileModels.swift` (L120-160, `ProfileSaveRequest`) | ✅ 完整实现 |
| 资料保存响应模型 | `RunFormCoachAI/ProfileModels.swift` (L162-169, `ProfileSaveResponse`) | ✅ 完整实现 |
| 本地 UserDefaults 持久化 | `RunFormCoachAI/AppStore.swift` (L292-295, `saveProfile()`) | ✅ 完整实现 |
| 表单组件（文本框/滑块/选择器） | `RunFormCoachAI/ProfileFormFields.swift` | ✅ 完整实现 |

### 3.2 个人资料字段

| 字段 | 实现状态 |
|------|----------|
| 名 (First Name) | ✅ |
| 姓 (Last Name) | ✅ |
| 昵称 (Nickname) | ✅ |
| 邮箱 (Email) | ✅ |
| 出生日期 (Date of Birth) | ✅ |
| 跑步水平 (Beginner/Intermediate/Advanced) | ✅ |
| 周跑量 (Weekly Mileage) | ✅ |
| 每周跑步天数 | ✅ |
| 每周运动总时长 | ✅ |
| 身高 (cm) | ✅ |
| 体重 (kg) | ✅ |
| 训练目标 (5K/10K/Half/Marathon/General Fitness) | ✅ |
| 性别 (Male/Female/Other/Unspecified) | ✅ |
| 鞋码 (Shoe Size) | ✅ |
| 腿长 (cm) | ✅ |
| 鞋品牌/型号 | ✅ |
| 伤病史备注 | ✅ |

---

## 四、跑步分析 - 视频姿态分析 (Core Video Pose Analysis)

### 4.1 视频采集

| 功能点 | 文件路径 | 实现状态 |
|--------|----------|----------|
| 相册视频选择器 (PHPicker) | `RunFormCoachAI/VideoPicker.swift` | ✅ 完整实现 |
| 实时摄像头录制 (AVCaptureSession) | `RunFormCoachAI/LiveGuidanceRecorderView.swift` (L137-444) | ✅ 完整实现 |
| 实时姿态引导叠加层 | `RunFormCoachAI/LiveGuidanceRecorderView.swift` (L70-108, 271-367) | ✅ 完整实现 |
| 视频角度模式选择 (Side/Rear/Front) | `RunFormCoachAI/ContentView.swift` (L132-170) + `AnalysisModels.swift` (L201-257, `VideoMode`) | ✅ 完整实现 |
| 录制时长限制 (20秒) | `RunFormCoachAI/LiveGuidanceRecorderView.swift` (L260-264) | ✅ 完整实现 |
| 实时画面质量评分 | `RunFormCoachAI/LiveGuidanceRecorderView.swift` (L139, `liveQualityScore`) | ✅ 完整实现 |
| 相机权限请求 | `LiveGuidanceRecorderView.swift` (L162-180) + `Info.plist` (NSCameraUsageDescription) | ✅ 完整实现 |

### 4.2 姿态提取 (On-Device Vision Pipeline)

| 功能点 | 文件路径 | 实现状态 |
|--------|----------|----------|
| Vision Body Pose 提取 | `RunFormCoachAI/PoseExtractor.swift` (L1-746) | ✅ 完整实现 |
| 信号处理工具集 | `RunFormCoachAI/SignalProcessing.swift` (L1-180) | ✅ 完整实现 |
| 视频质量评分 (detectionRate/confidence/completeness) | `RunFormCoachAI/PoseExtractor.swift` (L125-126) | ✅ 完整实现 |
| 低质量视频拒绝 (< 0.40) | `RunFormCoachAI/ContentView.swift` (L342-348) | ✅ 完整实现 |
| 质量提示引导 (0.40–0.55) | `RunFormCoachAI/ContentView.swift` (L350-355) | ✅ 完整实现 |

### 4.3 姿态指标提取 (Biomechanical Metrics)

| 指标 | 文件位置 | 实现状态 |
|------|----------|----------|
| 步频 (Cadence SPM) - 多信号融合+自适应峰值检测 | `PoseExtractor.swift` L128-168 | ✅ 完整实现 |
| 跨步过大 (Overstride) - 置信度加权踝-髋距离 | `PoseExtractor.swift` L180-200 | ✅ 完整实现 |
| 躯干前倾 (Trunk Lean) - 修剪均值 | `PoseExtractor.swift` L202-231 | ✅ 完整实现 |
| 膝内翻/外翻 (Knee Valgus) | `PoseExtractor.swift` L233-253 | ✅ 完整实现 |
| 垂直振幅 (Vertical Oscillation) | `PoseExtractor.swift` L262-272 | ✅ 完整实现 |
| 肩部高度 (Shoulder Elevation) | `PoseExtractor.swift` L274-290 | ✅ 完整实现 |
| 摆臂幅度 (Arm Swing) | `PoseExtractor.swift` L292-322 | ✅ 完整实现 |
| 交叉摆臂 (Arm Crossing/"Knitting") | `PoseExtractor.swift` L324-363 | ✅ 完整实现 |
| 后摆肘角度 (Backward Elbow Drive) | `PoseExtractor.swift` L365-400 | ✅ 完整实现 |
| 肘关节角度 (Elbow Angle) | `PoseExtractor.swift` L402-430 | ✅ 完整实现 |
| 肩臂独立性 (Shoulder-Arm Independence) | `PoseExtractor.swift` L432-459 | ✅ 完整实现 |
| 骨盆下沉 (Pelvic Drop) | `PoseExtractor.swift` L461-489 | ✅ 完整实现 |
| 左右步幅对称 (Step Symmetry) | `PoseExtractor.swift` L491-527 | ✅ 完整实现 |
| 头部前倾 (Head Forward) | 引用自 AnalysisModels.swift (headForwardScore/Status) | ✅ 模型字段已定义 |
| 综合评分 (Posture/Efficiency/Stability/Propulsion/Arm/Symmetry/Injury) | `AnalysisModels.swift` (L91-97, PoseMetrics 复合评分) | ✅ 完整实现 |

### 4.4 分析结果显示

| 功能点 | 文件路径 | 实现状态 |
|--------|----------|----------|
| 分析结果视图 | `RunFormCoachAI/AnalysisResultView.swift` (L1-378) | ✅ 完整实现 |
| 综合评分圆环 (Form Report) | `AnalysisResultView.swift` L192-219 | ✅ 完整实现 |
| 视频质量卡片 | `AnalysisResultView.swift` L221-252 | ✅ 完整实现 |
| 运动指标列表（各指标得分/状态/解释） | `AnalysisResultView.swift` L254-285 | ✅ 完整实现 |
| 受伤风险叙事（伤防提示） | `AnalysisResultView.swift` L110-142 | ✅ 完整实现 |
| 改善练习推荐（Strength Focus） | `AnalysisResultView.swift` L287-317 | ✅ 完整实现 |
| 练习视频搜索链接（B站/YouTube） | `AnalysisResultView.swift` L320-365 (`ExerciseCard`) | ✅ 完整实现 |
| Google AdMob 广告 | `AnalysisResultView.swift` L22-30 + `AdBannerView.swift` | ⚠️ 条件编译，生产广告单元 ID 为占位符 |
| 与精英运动员对比入口 | `AnalysisResultView.swift` L168-190 | ✅ 完整实现 |

---

## 五、历史记录 (History)

### 5.1 记录列表

| 功能点 | 文件路径 | 实现状态 |
|--------|----------|----------|
| 历史记录列表 | `RunFormCoachAI/HistoryView.swift` (L1-175) | ✅ 完整实现 |
| 空状态提示 | `HistoryView.swift` L103-118 (`EmptyHistoryView`) | ✅ 完整实现 |
| 趋势分析（Form Score / Cadence / Hip Stability） | `HistoryView.swift` L72-86 | ✅ 完整实现 |
| 趋势迷你图表 (Sparkline) | `RunFormCoachAI/HistoryTrendComponents.swift` (L1-136) | ✅ 完整实现 |
| 一致性卡片 (ConsistencyCard) | `HistoryTrendComponents.swift` L62+ | ✅ 完整实现 |
| 清空历史确认对话框 | `HistoryView.swift` L66-68 | ✅ 完整实现 |
| 历史行项目（日期/文件名/置信度/指标/反馈） | `HistoryView.swift` L121-155 (`HistoryRow`) | ✅ 完整实现 |
| 历史数据模型 | `RunFormCoachAI/AnalysisModels.swift` (L184-190, `AnalysisHistoryItem`) | ✅ 完整实现 |
| 本地持久化 (UserDefaults) | `AppStore.swift` L357-369 | ✅ 完整实现 |

### 5.2 记录详情

| 功能点 | 文件路径 | 实现状态 |
|--------|----------|----------|
| 单条历史记录详情 | `RunFormCoachAI/HistoryDetailView.swift` (L1-69) | ✅ 完整实现 |
| 从历史对比精英运动员 | `HistoryDetailView.swift` L28-44 → `CompareHistoryView.swift` | ✅ 完整实现 |
| 历史反馈展示 | `HistoryDetailView.swift` L46-60 | ✅ 完整实现 |

### 5.3 用户反馈

| 功能点 | 文件路径 | 实现状态 |
|--------|----------|----------|
| 反馈表单（评分+评论） | `RunFormCoachAI/FeedbackView.swift` (L1-56) | ✅ 完整实现 |
| 反馈评分枚举 | `AnalysisModels.swift` L169-175 (`FeedbackRating`) | ✅ 完整实现 |
| 反馈保存 | `AppStore.swift` L158-162 (`updateFeedback()`) | ✅ 完整实现 |

---

## 六、分享功能 (Share)

| 功能点 | 文件路径 | 实现状态 |
|--------|----------|----------|
| 分享按钮（分析结果页） | `RunFormCoachAI/AnalysisResultView.swift` (L144-166) | ✅ 完整实现 |
| 分享内容生成（文本报告） | `AnalysisResultView.swift` L54-107 (`buildShareItems()`) | ✅ 完整实现 |
| 分享报告模板（含 App Store 链接） | `AnalysisResultView.swift` L62-106 | ✅ 完整实现 |
| UIActivityViewController 桥接 | `AnalysisResultView.swift` L370-378 (`ShareSheet`) | ✅ 完整实现 |
| 截图分享 | — | ❌ 未实现（仅文本分享） |
| 链接分享 | — | ❌ 未实现 |
| 社交媒体深度分享 | — | ❌ 未实现 |

---

## 七、Strava 集成

### 7.1 OAuth 授权

| 功能点 | 文件路径 | 实现状态 |
|--------|----------|----------|
| Strava 连接 API (获取授权 URL) | `RunFormCoachAI/APIClient.swift` (L97-107, `fetchStravaConnectResponse()`) | ✅ 完整实现 |
| OAuth 模型 (authorizeURL + state) | `RunFormCoachAI/StravaModels.swift` (L5-13, `StravaConnectResponse`) | ✅ 完整实现 |
| ASWebAuthenticationSession 上下文 | `RunFormCoachAI/StravaPresentationContext.swift` (L1-38) | ✅ 完整实现 |
| Strava 回调 URL Scheme | `Info.plist` (L19-26, `runformcoachai://strava/callback`) | ✅ 已注册 |
| ProfileView 中的 Strava 卡片 | `RunFormCoachAI/ProfileView.swift` (L292-319) | ❌ **当前显示 "Coming Soon"，原功能被注释** |
| Strava 连接 UI 组件 | `RunFormCoachAI/ProfileStravaCard.swift` (L1-134) | ✅ 组件完整实现，但 ProfileView 中已注释 |
| Strava 连接/断开/同步回调 | `ProfileView.swift` L320-331 (已注释) | ⚠️ 代码全量存在但被禁用 |

### 7.2 Strava 状态 & 数据

| 功能点 | 文件路径 | 实现状态 |
|--------|----------|----------|
| Strava 连接状态查询 API | `APIClient.swift` (L109-117, `fetchStravaStatus()`) | ✅ 完整实现 |
| Strava 断开 API | `APIClient.swift` (L119-128, `disconnectStrava()`) | ✅ 完整实现 |
| Strava 活动同步 API | `APIClient.swift` (L130-140, `syncStravaActivities()`) | ✅ 完整实现 |
| Strava 周摘要 API | `APIClient.swift` (L142-165, `fetchStravaSummary()`) | ✅ 完整实现 |
| Strava 数据模型 | `RunFormCoachAI/StravaModels.swift` (L1-158) | ✅ 完整实现 |
| Strava 状态本地持久化 | `AppStore.swift` L297-300, 348-355 | ✅ 完整实现 |
| Strava 资料预填充 | `StravaModels.swift` L98-126 (`StravaProfilePrefill`) | ✅ 完整实现 |

---

## 八、训练计划 (Training Plan)

### 8.1 计划生成

| 功能点 | 文件路径 | 实现状态 |
|--------|----------|----------|
| 训练计划页面 | `RunFormCoachAI/PlanBuilderView.swift` (L1-951) | ✅ 完整实现 |
| 每周训练计划生成 | `PlanBuilderView.swift` (Weekly Plan) | ✅ 完整实现 |
| 马拉松训练计划生成 | `PlanBuilderView.swift` (Marathon Plan Block) | ✅ 完整实现 |
| 特定赛事训练计划 (5K/10K/Half) | `PlanBuilderView.swift` (Race Plan Block) | ✅ 完整实现 |
| 训练目标枚举 | `RunFormCoachAI/PlanModels.swift` (L6-14, `TrainingTarget`) | ✅ 完整实现 |
| 训练水平枚举 | `PlanModels.swift` (L16-22, `TrainingLevel`) | ✅ 完整实现 |
| 六大满贯马拉松选择 | `PlanModels.swift` (L24-34, `MarathonMajor`) | ✅ 完整实现 |
| 训练计划 API | `APIClient.swift` (L200-218, `generateTrainingPlan()`) | ✅ 完整实现 |
| 计划输入模型 | `PlanModels.swift` (L53-141, `TrainingPlanInput`) | ✅ 完整实现 |
| 计划响应模型 | `PlanModels.swift` (L165-255, `TrainingPlanResponse`) | ✅ 完整实现 |
| Strava 基准数据（自动拉取周跑量） | `PlanBuilderView.swift` L100-103, `refreshWeeklyKmBaseline()` | ✅ 完整实现 |
| 周跑量来源标签（Profile/Strava/Manual） | `PlanBuilderView.swift` L441-457 | ✅ 完整实现 |
| 基于最新分析结果优化计划 | `PlanModels.swift` (L59-62, `formIssues`/`recentAnalysisSummary`) | ✅ 完整实现 |

### 8.2 计划展示与管理

| 功能点 | 文件路径 | 实现状态 |
|--------|----------|----------|
| 训练计划结果展示 | `RunFormCoachAI/TrainingPlanResultView.swift` (L1-180) | ✅ 完整实现 |
| 训练课卡片 | `RunFormCoachAI/WorkoutCardViews.swift` (L1-107) | ✅ 完整实现 |
| 训练课状态追踪 (Done/Skipped/Too Hard/Pain) | `WorkoutCardViews.swift` L72-107 (`WorkoutStatusRow`) | ✅ 完整实现 |
| 训练状态模型 | `PlanModels.swift` L259-284 (`WorkoutStatus`) | ✅ 完整实现 |
| 马拉松计划详情 | `RunFormCoachAI/MarathonPlanDetailView.swift` | ✅ 完整实现 |
| 赛事计划详情 | `RunFormCoachAI/RacePlanDetailView.swift` | ✅ 完整实现 |
| 手动周计划编辑器 | `RunFormCoachAI/ManualNextWeekPlanEditorView.swift` | ✅ 完整实现 |
| 已保存计划列表 | `RunFormCoachAI/SavedPlanViews.swift` (L1-82) | ✅ 完整实现 |
| 已保存计划详情 | `SavedPlanViews.swift` L64-82 (`SavedPlanDetailView`) | ✅ 完整实现 |
| 计划保存/删除 | `AppStore.swift` L169-204 | ✅ 完整实现 |
| 下周日历计划 | `AppStore.swift` L100-144 (`ManualNextWeekPlan`) | ✅ 完整实现 |
| 周一形态复查提示卡片 | `PlanBuilderView.swift` L346-380 (`weeklyRecheckCard`) | ✅ 完整实现 |

---

## 九、挑战功能 (Challenges)

### 9.1 挑战列表与详情

| 功能点 | 文件路径 | 实现状态 |
|--------|----------|----------|
| 挑战列表 | `RunFormCoachAI/ChallengeListView.swift` (L1-131) | ✅ 完整实现 |
| 挑战详情 | `RunFormCoachAI/ChallengeDetailView.swift` (L1-260) | ✅ 完整实现 |
| 加入挑战 | `ChallengeDetailView.swift` L197-209 | ✅ 完整实现 |
| 每日签到 (Check-in) | `ChallengeDetailView.swift` L174-195 | ✅ 完整实现 |
| 进度条展示 | `ChallengeDetailView.swift` L94-132 | ✅ 完整实现 |
| 今日签到状态 | `ChallengeDetailView.swift` L122-131 | ✅ 完整实现 |
| 挑战数据模型 | `RunFormCoachAI/ChallengeModels.swift` (L1-146) | ✅ 完整实现 |
| 挑战 API | `APIClient.swift` L367-453 | ✅ 完整实现 |
| 签到 API (含 X-API-Key 认证) | `APIClient.swift` (L435-453, `checkIn()`) | ✅ 完整实现 |
| 加入 API | `APIClient.swift` (L391-409, `joinChallenge()`) | ✅ 完整实现 |

### 9.2 排行榜

| 功能点 | 文件路径 | 实现状态 |
|--------|----------|----------|
| 排行榜视图 | `RunFormCoachAI/ChallengeLeaderboardView.swift` (L1-184) | ✅ 完整实现 |
| 排行榜 API | `APIClient.swift` (L411-433, `fetchLeaderboard()`) | ✅ 完整实现 |
| 排行榜数据模型 | `ChallengeModels.swift` L103-146 (`ChallengeLeaderboardEntry`) | ✅ 完整实现 |
| 当前用户高亮 | `ChallengeLeaderboardView.swift` L148-150 | ✅ 完整实现 |
| 奖牌表情展示 (🥇🥈🥉) | `ChallengeLeaderboardView.swift` L121-128 | ✅ 完整实现 |
| 进步指标展示 (Cadence/Oscillation/Score) | `ChallengeLeaderboardView.swift` L153-166 | ✅ 完整实现 |

---

## 十、精英运动员对比 (Elite Comparison)

| 功能点 | 文件路径 | 实现状态 |
|--------|----------|----------|
| 对比入口页 (精英+自定义) | `RunFormCoachAI/CompareView.swift` (L1-296) | ✅ 完整实现 |
| 精英运动员列表 | `CompareView.swift` L184-221 | ✅ 完整实现 |
| 自定义运动员视频上传对比 | `CompareView.swift` L96-181 | ✅ 完整实现 |
| 对比结果页 | `RunFormCoachAI/CompareResultView.swift` (L1-282) | ✅ 完整实现 |
| 历史记录对比 | `RunFormCoachAI/CompareHistoryView.swift` (L1-380) | ✅ 完整实现 |
| 自定义运动员对比结果 | `RunFormCoachAI/CustomCompareResultView.swift` | ✅ 完整实现 |
| 运动员行组件 | `RunFormCoachAI/AthleteRowView.swift` (L1-48) | ✅ 完整实现 |
| 对比数据模型 | `RunFormCoachAI/CompareModels.swift` (L1-88) | ✅ 完整实现 |
| 对比 API | `APIClient.swift` (L237-257, `compareWithAthlete()`) | ✅ 完整实现 |
| 运动员列表 API | `APIClient.swift` (L220-235, `fetchAthletes()`) | ✅ 完整实现 |
| 指标对比条 | `CompareResultView.swift` L202-282 (`MetricComparisonRow`) | ✅ 完整实现 |
| 教练评语 | `CompareResultView.swift` L121-133 (`narrativeCard`) | ✅ 完整实现 |
| 最大差距分析 | `CompareResultView.swift` L135-155 (`topGapsCard`) | ✅ 完整实现 |
| 运动员传记卡片 | `CompareResultView.swift` L168-183 | ✅ 完整实现 |

---

## 十一、实时跑步管线 (CoreMotion Real-time Pipeline)

### 11.1 传感器采集

| 功能点 | 文件路径 | 实现状态 |
|--------|----------|----------|
| CoreMotion 管理器 (加速度计+陀螺仪) | `RunFormCoachAI/CoreMotion/CoreMotionManager.swift` (L1-223) | ✅ 完整实现 |
| 环形缓冲区 | `RunFormCoachAI/CoreMotion/RingBuffer.swift` | ✅ 完整实现 |
| 传感器帧融合 (Accel+Gyro 时间对齐) | `CoreMotionManager.swift` L113-177 | ✅ 完整实现 |
| 后台采集支持 | `CoreMotionManager.swift` L10-12, 105 | ⚠️ 设计支持但需额外 entitlement |
| 传感器数据模型 | `RunFormCoachAI/SensorData.swift` L7-40 (`SensorFrame`) | ✅ 完整实现 |
| Motion 权限声明 | `Info.plist` L40-41 (NSMotionUsageDescription) | ✅ 已注册 |

### 11.2 步频检测

| 功能点 | 文件路径 | 实现状态 |
|--------|----------|----------|
| 实时步频检测器 | `RunFormCoachAI/CadenceDetector.swift` (L1-210) | ✅ 完整实现 |
| 低通滤波 + 零交叉检测算法 | `CadenceDetector.swift` | ✅ 完整实现 |
| 步频数据模型 | `SensorData.swift` L45-66 (`CadenceSample`) | ✅ 完整实现 |

### 11.3 步态分析

| 功能点 | 文件路径 | 实现状态 |
|--------|----------|----------|
| 实时步态分析器 | `RunFormCoachAI/GaitAnalyzer.swift` (L1-287) | ✅ 完整实现 |
| 垂直振幅（双重积分） | `GaitAnalyzer.swift` L134-163, 222-233 | ✅ 完整实现 |
| 触地时间（角速度峰值分析） | `GaitAnalyzer.swift` L239-257 | ✅ 完整实现 |
| 躯干前倾角（加速度计姿态） | `GaitAnalyzer.swift` L167-173 | ✅ 完整实现 |
| 步态快照模型 | `SensorData.swift` L71-96 (`GaitSnapshot`) | ✅ 完整实现 |

### 11.4 语音教练

| 功能点 | 文件路径 | 实现状态 |
|--------|----------|----------|
| 实时语音教练引擎 (AVSpeechSynthesizer) | `RunFormCoachAI/AudioCoachEngine.swift` (L1-287) | ✅ 完整实现 |
| 英语教练提示 | `AudioCoachEngine.swift` L227-232, 260-271 | ✅ 完整实现 |
| 中文教练提示 | `AudioCoachEngine.swift` L215-226, 244-251 | ✅ 完整实现 |
| 荷兰语教练提示 | `AudioCoachEngine.swift` L221-226, 252-259 | ✅ 完整实现 |
| 教练提示数据模型 | `SensorData.swift` L101-130 (`CoachPrompt`) | ✅ 完整实现 |
| 提示间隔限制 (15秒) | `AudioCoachEngine.swift` L50 | ✅ 完整实现 |
| 静音模式 | `AudioCoachEngine.swift` L32 | ✅ 完整实现 |

### 11.5 会话管理

| 功能点 | 文件路径 | 实现状态 |
|--------|----------|----------|
| 跑步会话管理器 (状态机) | `RunFormCoachAI/RunSessionManager.swift` (L1-280) | ✅ 完整实现 |
| 状态机 (idle→ready→running→paused→stopped) | `RunSessionManager.swift` L134-193 | ✅ 完整实现 |
| 管线连接 (Motion→Cadence→Gait→Coach) | `RunSessionManager.swift` L197-238 | ✅ 完整实现 |
| 指标更新回调 (1Hz) | `RunSessionManager.swift` L244-263 | ✅ 完整实现 |
| 会话配置模型 | `SensorData.swift` L146-171 (`RunSessionConfig`) | ✅ 完整实现 |
| 会话状态枚举 | `SensorData.swift` L135-141 (`RunSessionState`) | ✅ 完整实现 |

---

## 十二、跑步会话回放 (Run Session Replay)

| 功能点 | 文件路径 | 实现状态 |
|--------|----------|----------|
| 会话回放列表 | `RunFormCoachAI/RunSessionReplayView.swift` (L1-800) | ✅ 完整实现 |
| 会话回放 ViewModel | `RunSessionReplayView.swift` L67-158 (`RunSessionReplayViewModel`) | ✅ 完整实现 |
| 时间序列图表 (Canvas 绘制) | `RunSessionReplayView.swift` L425-540+ | ✅ 完整实现 |
| 播放控制 (播放/暂停/拖动) | `RunSessionReplayView.swift` L297-307 | ✅ 完整实现 |
| 教练事件叠加 | `RunSessionReplayView.swift` L299-301, 367-377 | ✅ 完整实现 |
| 会话数据模型 | `RunSessionReplayView.swift` L6-62 (`RunSessionResponse`) | ✅ 完整实现 |
| 会话列表 API | `APIClient.swift` L259-276 (`fetchSessions()`) | ✅ 完整实现 |

---

## 十三、Google 广告 (AdMob)

| 功能点 | 文件路径 | 实现状态 |
|--------|----------|----------|
| AdMob 横幅广告 (SwiftUI 桥接) | `RunFormCoachAI/AdBannerView.swift` (L1-43) | ✅ 完整实现 |
| 条件编译 (#if canImport(GoogleMobileAds)) | `AdBannerView.swift` L2 + `AnalysisResultView.swift` L22-30 | ✅ 条件编译 |
| 测试广告单元 ID | `AdBannerView.swift` L40 | ✅ |
| 生产广告单元 ID | `AdBannerView.swift` L41 | ⚠️ **占位符** `ca-app-pub-XXXXXXXX/XXXXXXXX` |
| GoogleMobileAds 包依赖 | — | ❌ 未在 project.yml 中声明 |

---

## 十四、设置页面 (Settings)

| 功能点 | 文件路径 | 实现状态 |
|--------|----------|----------|
| 独立设置页面 | — | ❌ **未实现** |
| 设置项分散在 ProfileView | `ProfileView.swift` (资料表单即设置) | ⚠️ 隐式实现 |
| 训练偏好分散在 PlanBuilderView | `PlanBuilderView.swift` | ⚠️ 隐式实现 |

---

## 十五、隐私政策与法律 (Privacy & Legal)

| 功能点 | 文件路径 | 实现状态 |
|--------|----------|----------|
| 隐私政策页面 | — | ❌ **未实现** |
| 服务条款页面 | — | ❌ **未实现** |
| 隐私政策 URL | `fastlane/metadata/en-US/privacy_url.txt` | ⚠️ App Store 元数据中存在，应用内无链接 |
| 支持 URL | `fastlane/metadata/en-US/support_url.txt` | ⚠️ 同上 |
| Camera 使用说明 | `Info.plist` L5-6 | ✅ |
| 相册使用说明 | `Info.plist` L7-8 | ✅ |
| Motion 使用说明 | `Info.plist` L40-41 | ✅ |
| HealthKit 使用说明 | `Info.plist` L42-45 | ✅ |
| App 隐私详情 | `fastlane/metadata/en-US/app_privacy_details.json` | ✅ |
| 应用内隐私说明（Strava Card 中） | `ProfileStravaCard.swift` L31-33 | ✅ |

---

## 十六、国际化 (Localization)

| 语言 | 文件路径 | 覆盖范围 |
|------|----------|----------|
| 英语 (en) | `en.lproj/Localizable.strings` | ✅ 主语言 |
| 简体中文 (zh-Hans) | `zh-Hans.lproj/Localizable.strings` | ✅ 本地化 |
| 荷兰语 (nl) | `nl.lproj/Localizable.strings` | ✅ 本地化 |

---

## 十七、测试 (Tests)

| 测试文件 | 文件路径 | 覆盖范围 |
|----------|----------|----------|
| 姿态提取器测试 | `RunFormCoachAITests/PoseExtractorTests.swift` | ⚠️ 仅 1 个测试文件 |
| CoreMotion 管线测试 | `RunFormCoachAITests/CoreMotionPipelineTests.swift` | ⚠️ 仅 1 个测试文件 |
| UI 测试 | `project.yml` L99-117 (UITests target) | ❌ 未找到测试实现文件 |

---

## 十八、订阅/付费 (Subscription)

| 功能点 | 文件路径 | 实现状态 |
|--------|----------|----------|
| 内购 (In-App Purchase) | — | ❌ **未实现** |
| 订阅管理 | — | ❌ **未实现** |
| 付费墙 | — | ❌ **未实现** |
| StoreKit 集成 | — | ❌ **未实现** |

---

## 十九、完整文件清单 (53 个 Swift 文件)

### 视图层 (Views) — 25 个文件

| 文件 | 类型 | 功能 |
|------|------|------|
| `ContentView.swift` | View | 主 TabView (5 Tab)，视频分析触发 |
| `LoginView.swift` | View | 登录/注册/密码重置 |
| `ProfileView.swift` | View | 个人资料/Strava/账号管理 |
| `HistoryView.swift` | View | 分析历史列表+趋势 |
| `HistoryDetailView.swift` | View | 单条历史详情 |
| `HistoryTrendComponents.swift` | View | Sparkline/TrendCard/ConsistencyCard |
| `AnalysisResultView.swift` | View | 分析结果展示+分享+对比入口 |
| `FeedbackView.swift` | View | 用户反馈表单 |
| `PlanBuilderView.swift` | View | 训练计划生成表单 |
| `TrainingPlanResultView.swift` | View | 训练计划结果展示 |
| `MarathonPlanDetailView.swift` | View | 马拉松计划详情 |
| `RacePlanDetailView.swift` | View | 赛事计划详情 |
| `ManualNextWeekPlanEditorView.swift` | View | 手动周计划编辑器 |
| `SavedPlanViews.swift` | View | 已保存计划列表/详情 |
| `WorkoutCardViews.swift` | View | 训练课卡片+状态按钮 |
| `ChallengeListView.swift` | View | 挑战列表 |
| `ChallengeDetailView.swift` | View | 挑战详情+加入+签到 |
| `ChallengeLeaderboardView.swift` | View | 排行榜 |
| `CompareView.swift` | View | 精英对比入口 |
| `CompareResultView.swift` | View | 对比结果 |
| `CompareHistoryView.swift` | View | 历史记录对比 |
| `CustomCompareResultView.swift` | View | 自定义运动员对比结果 |
| `AthleteRowView.swift` | View | 运动员列表行 |
| `LiveGuidanceRecorderView.swift` | View | 实时录制+Vision姿态引导 |
| `RunSessionReplayView.swift` | View | 跑步会话回放 |

### ViewModel / State — 2 个文件

| 文件 | 类型 | 功能 |
|------|------|------|
| `AppStore.swift` | ObservableObject | 中央状态管理 |
| `RunSessionReplayView.swift` (内含) | ViewModel | 会话回放 ViewModel |

### Manager / Service / Engine — 6 个文件

| 文件 | 类型 | 功能 |
|------|------|------|
| `APIClient.swift` | Service | HTTP 网络层 (分析/认证/Strava/计划/挑战/对比) |
| `CoreMotion/CoreMotionManager.swift` | Service | 加速度计+陀螺仪数据采集 |
| `RunSessionManager.swift` | Manager | 实时跑步会话状态机 |
| `CadenceDetector.swift` | Service | 实时步频检测 |
| `GaitAnalyzer.swift` | Service | 实时步态分析 |
| `AudioCoachEngine.swift` | Service | 实时语音教练 |

### 数据处理 / 算法 — 3 个文件

| 文件 | 类型 | 功能 |
|------|------|------|
| `PoseExtractor.swift` | Algorithm | Vision 姿态提取+13 项生物力学指标 |
| `SignalProcessing.swift` | Utility | 信号处理纯函数 |
| `PerformanceOptimizer.swift` | Utility | 启动性能追踪+延迟初始化 |

### 模型层 (Models) — 8 个文件

| 文件 | 类型 | 功能 |
|------|------|------|
| `AnalysisModels.swift` | Model | 分析响应/指标/问题/练习/反馈/历史/视频模式 |
| `PlanModels.swift` | Model | 训练目标/等级/马拉松/计划请求/响应/WorkoutStatus |
| `ChallengeModels.swift` | Model | 挑战/加入/签到/排行榜/指标 |
| `StravaModels.swift` | Model | Strava OAuth/连接/同步/摘要/资料预填充 |
| `CompareModels.swift` | Model | 运动员/对比请求/响应 |
| `ProfileModels.swift` | Model | TesterProfile/Auth/User/密码重置 |
| `SensorData.swift` | Model | SensorFrame/CadenceSample/GaitSnapshot/CoachPrompt/Config |
| `RunSessionReplayView.swift` (内含) | Model | RunSessionResponse/TimePoint/CoachEvent |

### 数据存储 — 1 个文件

| 文件 | 类型 | 功能 |
|------|------|------|
| `CoreMotion/RingBuffer.swift` | Data Structure | 环形缓冲区 |

### UI 组件 / 基础设施 — 5 个文件

| 文件 | 类型 | 功能 |
|------|------|------|
| `UIComponents.swift` | UI | GlassCard/DarkCard/IconBubble/SectionTitle/GradientButton 等 |
| `AppTheme.swift` | Theme | 颜色/渐变/背景 |
| `ProfileFormFields.swift` | UI | ProfileLabeledTextField/SliderRow/MenuPicker |
| `ProfileStravaCard.swift` | UI | Strava 卡片组件 (当前被 ProfileView 注释) |
| `AdBannerView.swift` | UI | Google AdMob 桥接 |

### 其他 — 3 个文件

| 文件 | 类型 | 功能 |
|------|------|------|
| `RunFormCoachAIApp.swift` | App Entry | @main 入口 |
| `StravaPresentationContext.swift` | UIKit Bridge | ASWebAuthenticationSession 上下文 |
| `VideoPicker.swift` | UIKit Bridge | PHPicker 桥接 |

### 测试 — 2 个文件

| 文件 | 类型 |
|------|------|
| `RunFormCoachAITests/PoseExtractorTests.swift` | Unit Test |
| `RunFormCoachAITests/CoreMotionPipelineTests.swift` | Unit Test |

---

## 二十、问题总结与风险项

### 🚨 严重问题 (Critical)

| # | 问题 | 影响 |
|---|------|------|
| 1 | **Strava 集成被禁用** — ProfileView 中 StravaCard 显示 "Coming Soon"，原始代码被大量注释 | 用户无法使用 Strava 连接功能 |
| 2 | **AdMob 生产广告单元 ID 为占位符** (`ca-app-pub-XXXXXXXX/XXXXXXXX`) | 生产环境无广告收入 |
| 3 | **GoogleMobileAds 包未在 project.yml 声明** | AdMob 编译可能失败 |

### ⚠️ 警告问题 (Warning)

| # | 问题 | 影响 |
|---|------|------|
| 4 | **无独立设置页面** — 设置分散在 ProfileView/PlanBuilderView | 用户体验碎片化 |
| 5 | **无隐私政策/服务条款页面** — 仅在 App Store 元数据中存在 | 合规风险 |
| 6 | **Google 登录 UI 未实现** — API 和 SDK 就绪，但 LoginView 中无 Google 按钮 | 功能缺失 |
| 7 | **邮箱验证仅模型字段** — 有 `emailVerified` 但无验证流程 UI | 用户体验不完整 |
| 8 | **无订阅/付费模块** — 无 StoreKit/IAP | 无变现方式 |
| 9 | **测试覆盖率极低** — 仅 2 个单元测试，无 UI 测试 | 质量风险 |
| 10 | **HealthKit 仅为存根 (stub)** — `PerformanceOptimizer.swift` 中 `HKHealthStore` 是假的 | 无法使用 Apple Health |
| 11 | **分享仅文本** — 无截图分享、链接分享 | 社交传播受限 |

### ℹ️ 优化建议 (Info)

| # | 建议 |
|---|------|
| 12 | 潜在的重构：将 `PlanBuilderView.swift` (951 行) 拆分为更小的子视图 |
| 13 | 潜在的重构：将 `PoseExtractor.swift` (746 行) 中的指标提取逻辑模块化 |
| 14 | 考虑添加 Widget Extension (iOS 锁屏小组件) 展示周跑量 |
| 15 | 考虑添加 Siri Intents / Shortcuts 集成 |
