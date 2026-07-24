# RunForm iOS vs Android 功能差异对比报告

> 审计日期: 2026-07-05
> iOS 版本: 1.3 (Build 3), 53 个 Swift 文件
> Android 版本: 1.3 (code 3), 63 个 Kotlin 文件
> 后端: Railway, 9 个 API 端点

---

## 一、差异总览

| 类别 | iOS 独有 | Android 独有 | 双方缺失 |
|------|---------|-------------|---------|
| 用户认证 | 3 | 0 | — |
| 分享功能 | 0 | 4 | 1 |
| Strava | 5 | 0 | — |
| 跑步功能 | 1 | 4 | — |
| 基础设施 | 0 | 3 | — |
| 通用缺失 | — | — | 5 |
| **合计差异** | **9** | **11** | **5** |

---

## 二、Android 缺失（iOS 已有，需补齐）🔴

### 2.1 用户认证系统 — 最高优先级

| # | 功能 | iOS 状态 | Android 状态 |
|---|------|---------|-------------|
| 1 | 邮箱+密码注册 UI | ✅ LoginView.swift L174-189 | ❌ 无任何注册/登录界面 |
| 2 | 邮箱+密码登录 UI | ✅ LoginView.swift L25-48 | ❌ |
| 3 | 忘记密码 UI | ✅ LoginView.swift L130-138 | ❌ |
| 4 | Google 登录 | ⚠️ API 就绪，UI 未集成 | ❌ |
| 5 | 登出功能 | ✅ ProfileView L354-360 | ❌ |

> **现状**: Android 有 TokenManager + AuthInterceptor 基础设施，但没有任何认证 UI。用户用本地 UUID 标识。iOS 注册/登录/密码重置三件套完整。

### 2.2 Strava OAuth 集成

| # | 功能 | iOS 状态 | Android 状态 |
|---|------|---------|-------------|
| 1 | Strava 连接/断开/同步 API | ✅ 5 个 API 调用 (APIClient) | ❌ 零代码 |
| 2 | Strava 数据模型 | ✅ StravaModels.swift (158行) | ❌ |
| 3 | ASWebAuthenticationSession OAuth | ✅ StravaPresentationContext.swift | ❌ |
| 4 | ProfileView Strava 卡片 | ⚠️ 代码完整但被注释 | ❌ |
| 5 | Strava 资料预填充 | ✅ StravaProfilePrefill | ❌ |

> **现状**: iOS Strava 全链路代码已写完，但 ProfileView 中注释掉了（显示 "Coming Soon"）。Android 完全没有一行 Strava 相关代码。

### 2.3 其他缺失

| # | 功能 | iOS 状态 | Android 状态 |
|---|------|---------|-------------|
| 1 | PerformanceOptimizer | ✅ PerformanceOptimizer.swift | ❌ |
| 2 | HistoryDetailView（单条历史详情页） | ✅ HistoryDetailView.swift | ❌ 仅有列表，无详情页 |
| 3 | FeedbackView（独立反馈表单） | ✅ FeedbackView.swift | ✅ 但嵌入在 AnalysisResultScreen |

---

## 三、iOS 缺失（Android 已有，需补齐）🟡

### 3.1 分享功能 — 重要差异

| # | 功能 | iOS 状态 | Android 状态 |
|---|------|---------|-------------|
| 1 | 图片分享卡片渲染 | ❌ 仅文本分享 | ✅ ShareCardRenderer.kt (1080×1440 Canvas Bitmap) |
| 2 | 分析结果图片分享 | ❌ | ✅ 全功能渲染 |
| 3 | 历史记录图片分享 | ❌ | ✅ |
| 4 | 训练计划图片分享 | ❌ | ✅ |
| 5 | 周度洞察图片分享 | ❌ | ✅ |
| 6 | 保存到相册 | ❌ | ✅ MediaStore (Android 10+/Legacy) |

> **关键差距**: iOS 分享只有纯文本 (UIActivityViewController + buildShareItems)，没有图像分享。Android 有 ShareCardRenderer 统一渲染 1080×1440 分享卡并保存到相册。

### 3.2 周度洞察 (Weekly Insights)

| # | 功能 | iOS 状态 | Android 状态 |
|---|------|---------|-------------|
| 1 | 周度训练洞察报告 | ❌ 未实现 | ✅ WeeklyInsightScreen.kt (596行) |
| 2 | 本周 vs 上周指标对比 | ❌ | ✅ 步频/振幅/GCT + 趋势箭头 |
| 3 | 成就徽章展示 | ❌ | ✅ |
| 4 | AI 教练建议 | ❌ | ✅ |

### 3.3 跑步功能增强

| # | 功能 | iOS 状态 | Android 状态 |
|---|------|---------|-------------|
| 1 | 视频压缩 (MediaCodec 720p@30fps) | ❌ | ✅ VideoCompressor.kt |
| 2 | 离线反馈缓存 (Room FeedbackDao) | ❌ 仅内存 | ✅ FeedbackEntity + 自动同步 |
| 3 | GPS 地图追踪（会话回放） | ❌ | ✅ RunSessionReplayScreen 含路径坐标 |

### 3.4 基础设施

| # | 功能 | iOS 状态 | Android 状态 |
|---|------|---------|-------------|
| 1 | Firebase Analytics + Crashlytics | ❌ | ✅ AnalyticsHelper.kt |
| 2 | 冷启动优化 (ANR看门狗) | ❌ | ✅ StartupOptimizer.kt |
| 3 | 数据迁移 (SharedPreferences→Room) | ❌ | ✅ MigrationHelper.kt |

---

## 四、双方共同缺失 ❌

| # | 功能 | 优先级 | 说明 |
|---|------|--------|------|
| 1 | 设置页面（独立 Settings） | 🟡 中 | 两边设置都散落在 Profile/Plan 页 |
| 2 | 隐私政策/服务条款页面 | 🟡 中 | 应用内无任何法律页面 |
| 3 | 订阅/付费系统 | 🟡 中 | 无 StoreKit / Google Play Billing |
| 4 | 链接分享（Deep Link） | 🟢 低 | 两边都是纯文本/图片分享，无可分享链接 |
| 5 | 语言切换设置 | 🟢 低 | 自动跟随系统语言，无手动切换 |

---

## 五、功能一致（已对齐）✅

| 模块 | 对齐度 |
|------|--------|
| 视频分析（选择/录制/结果/指标/Narrative） | ✅ 100% |
| 13 项生物力学指标 | ✅ 完全一致 |
| 实时跑步传感器管线 (Sensor→Cadence→Gait→TTS Coach) | ✅ 100% |
| 三语语音教练 (en/zh/nl) | ✅ 100% |
| 训练计划（周/马拉松/编辑/保存） | ✅ 95% (Race Plan 两边都是占位) |
| 精英对比（运动员+自定义） | ✅ 100% |
| 挑战（加入/签到/排行榜） | ✅ 100% |
| 跑步会话回放 | ✅ 100% |
| 历史记录列表 + 趋势图 | ✅ 100% |
| 个人资料 + 装备数据 | ✅ 100% |
| AdMob 广告 | ✅ 100% |
| 5-Tab 底部导航 (Analyze/History/Challenges/Plan/Profile) | ✅ 100% |

---

## 六、行动建议

### Sprint 立即安排 (P0 - 用户认证)

```
RF-AUTH-1: Android 注册/登录 UI（对齐 iOS LoginView）
RF-AUTH-2: Android 密码重置 UI
RF-AUTH-3: Android 登出功能
RF-AUTH-4: iOS 启用 Strava 连接卡片（取消注释）
```

### Sprint 下一批 (P1 - 分享 + Strava)

```
RF-SHARE-1: iOS 图片分享卡片（对齐 Android ShareCardRenderer）
RF-SHARE-2: iOS 周度洞察页面（对齐 Android WeeklyInsightScreen）
RF-STRAVA-1: Android Strava OAuth 全链路（对齐 iOS 代码）
```

### Backlog (P2 - 通用缺失)

```
RF-SETTINGS: 两边独立设置页面
RF-LEGAL: 两边隐私政策/条款页面
RF-DEEPLINK: 两边链接分享
```

---

## 七、代码规模对比

| 指标 | iOS | Android |
|------|-----|---------|
| 文件数 | 53 | 63 |
| Screen/Composable | 25 | 17 |
| ViewModel | 2 (AppStore + ViewModels) | 10 |
| Room 表 | 无 (UserDefaults) | 4 表 + 4 DAO |
| DI 框架 | 手动单例 | Hilt |
| 单元测试文件 | 2 | 4 |
| 总代码行数 | ~8000+ | ~13000+ |

> **结论**: Android 代码量更大（多 60%），但核心功能高度对齐。Android 在分享/基础设施/离线能力上领先，iOS 在用户认证/Strava 集成上领先。双端最大的不对齐是**用户认证系统**——iOS 有完整登录注册，Android 用户却无法创建账号。
