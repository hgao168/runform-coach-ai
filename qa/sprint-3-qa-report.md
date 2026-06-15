# RunForm Sprint 3 — 全平台 QA 静态审查报告

> **审查日期**：2026-05-18
> **审查人**：QA & Release Engineer (qa-release-engineer)
> **审查范围**：iOS / Android / WeChat / Web / Backend
> **审查方式**：WSL 环境下代码级静态审查（无编译环境）
> **Sprint 3 目标**：产品上线准备 + 用户功能 + 性能优化 + 营销 + 广告变现

---

## 一、审查覆盖清单

| 工单 | 功能 | iOS | Android | WeChat | Web | Backend |
|------|------|:---:|:-------:|:------:|:---:|:-------:|
| RF-910 | RunSession 回放 | ✅ 审查 | — | — | — | ✅ |
| RF-911 | iOS 周洞察报告 | ✅ 审查 | — | — | — | ⚠️ 无端点 |
| RF-912 | Android 周洞察报告 | — | ✅ 审查 | — | — | ⚠️ 无端点 |
| RF-913 | WeChat 分享卡片 | — | — | ✅ 审查 | — | — |
| RF-920 | iOS 冷启动优化 | ✅ 审查 | — | — | — | — |
| RF-921 | Android ANR + StrictMode | — | ✅ 审查 | — | — | — |
| RF-960 | 网站广告位 | — | — | — | ✅ 审查 | — |
| RF-961 | iOS AdMob 横幅广告 | ✅ 审查 | — | — | — | — |
| RF-962 | Android AdMob 横幅广告 | — | ✅ 审查 | — | — | — |
| RF-963 | WeChat 激励视频广告 | — | — | ✅ 审查 | — | — |
| RF-900-903 | 四端上架准备 | ✅ 审查 | ✅ 审查 | ✅ 审查 | ✅ 审查 | ✅ 审查 |
| RF-930-951 | 营销（Google/微信/小红书） | 部分 | 部分 | ✅ 审查 | ✅ 审查 | — |

---

## 二、Bug 清单

### 2.1 Critical（阻塞发布）

#### C1 — iOS: Info.plist 使用 Google 测试 AdMob App ID
- **文件**：`ios/RunFormCoachAI/Info.plist` 第 31 行
- **根因**：`GADApplicationIdentifier` = `ca-app-pub-3940256099942544~1458002511` 是 Google 公开测试 ID，提交 App Store 后 AdMob 不会填充真实广告
- **修复**：替换为 Firebase Console 中 `runform-coach-ai` 项目的真实 AdMob App ID

#### C2 — iOS: AdBannerView 硬编码测试广告单元 ID 且无生产切换路径
- **文件**：`ios/RunFormCoachAI/AdBannerView.swift` 第 41 行
- **影响位置**：`AnalysisResultView.swift` 第 17 行 `AdBannerView(adUnitID: AdBannerView.testAdUnitID)`
- **根因**：`AdBannerView` 仅暴露 `static let testAdUnitID`，AnalysisResultView 直接引用测试 ID，没有 `#if DEBUG` / 构建配置切换
- **修复**：
  1. 添加 `static let productionAdUnitID`（生产横幅广告单元 ID）
  2. AnalysisResultView 改为 `#if DEBUG` 使用测试 ID，Release 使用生产 ID

#### C3 — Android: AndroidManifest.xml 使用 Google 测试 AdMob App ID
- **文件**：`android/app/src/main/AndroidManifest.xml` 第 51 行
- **根因**：`com.google.android.gms.ads.APPLICATION_ID` = `ca-app-pub-3940256099942544~3347511713` 是 Google 公开测试 App ID
- **修复**：替换为 Firebase Console 中 Android 应用的真实 AdMob App ID

#### C4 — Android: BannerAdView 硬编码测试广告单元 ID
- **文件**：`android/app/src/main/java/com/runformcoach/runformcoachai/AnalysisResultScreen.kt` 第 457 行
- **根因**：`private const val BANNER_AD_UNIT_ID = "ca-app-pub-3940256099942544/6300978111"` 是测试 ID，代码注释写着 "Replace with production ad unit ID before release" 但未执行
- **修复**：使用 `BuildConfig.DEBUG` 分支切换测试/生产广告单元 ID

#### C5 — WeChat: 分享卡片小程序码为占位矩形，未生成真实小程序码
- **文件**：`wechat/utils/share-card.js` 第 473–485 行（`drawFooter` 函数）
- **根因**：`drawFooter()` 绘制一个 48×48 的矩形框，内写 "QR" 文字，无任何 `wx.getUnlimitedQRCode()` 或云函数调用生成真实小程序码。用户分享出去的卡片上显示的是一个假的「QR」方块
- **修复**：
  1. 创建云函数 `generateQRCode` 调用 `cloud.openapi.wxacode.getUnlimited`
  2. 在 `generate()` 中先异步获取小程序码临时文件路径，用 `ctx.drawImage()` 绘制到 Canvas
  3. 或预生成小程序码图片放入 `assets/` 目录，Canvas 直接 drawImage

#### C6 — iOS: 隐私清单声称 Crashlytics 但代码零集成（App Store 审核风险）
- **文件**：`ios/fastlane/metadata/en-US/app_privacy_details.json` 第 39 行（声称使用 "Firebase Crashlytics"）
- **确认文件**：`ios/RunFormCoachAI/RunFormCoachAIApp.swift`（无 Firebase import）、`ios/RunFormCoachAI/PerformanceOptimizer.swift`（仅 os_signpost）
- **根因**：隐私标签预声明了 Crashlytics，但项目未集成 Firebase SDK（无 GoogleService-Info.plist，无 SPM/CocoaPods 依赖，无 `Firebase.configure()` 调用）
- **修复（二选一）**：
  - A：按 `qa/monitoring-setup.md` §4.1 方案接入 Firebase Crashlytics（5 SP）
  - B：从 `app_privacy_details.json` 中移除 Crashlytics 声明

#### C7 — WeChat: 激励视频广告单元 ID 为占位符
- **文件**：`wechat/pages/result/result.js` 第 468 行
- **根因**：`const adUnitId = 'adunit-xxxxxxxxxxxxxxxx'` 为占位符，注释写 "TODO: replace with real ad unit ID"
- **修复**：从微信公众平台 → 流量主 → 广告管理获取真实激励视频广告单元 ID 并替换

---

### 2.2 Bug（影响功能完整性）

#### B1 — iOS: RunSessionReplayView 全部 UI 字符串硬编码英文（无 i18n）
- **文件**：`ios/RunFormCoachAI/RunSessionReplayView.swift`（800 行）
- **缺失的 i18n Key**（概览）：`"Run Replay"` (L180), `"Sessions"` (L194), `"No Sessions Yet"` (L211), `"Your live run sessions will appear here once you complete a tracked run."` (L214), `"Session Overview"` (L314), `"Time Series"` (L427), `"Tap & drag to seek"` (L427), `"Avg Cadence"` (L322), `"Avg Oscillation"` (L329), `"Avg GCT"` (L336), `"Duration"` (L346), `"Distance"` (L353), `"Coach Prompts"` (L361), `"Coach prompt at"` (L372)
- **根因**：Sprint 3 新增功能 RF-910，作者直接写入英文字符串，未在 `en.lproj/Localizable.strings`、`zh-Hans.lproj/Localizable.strings`、`nl.lproj/Localizable.strings` 中添加对应 Key
- **修复**：为所有硬编码字符串添加 NSLocalizedString Key，补全三语翻译

#### B2 — Android: WeeklyInsightScreen 全部 UI 字符串硬编码英文（无 i18n）
- **文件**：`android/app/src/main/java/com/runformcoach/runformcoachai/WeeklyInsightScreen.kt`（605 行）
- **缺失的 string resource**：`"Weekly Insights"` (L261), `"Your training trends at a glance"` (L267), `"Week-over-Week Comparison"` (L136), `"Cadence"` (L140), `"Vertical Oscillation"` (L151), `"Ground Contact Time"` (L162), `"Weekly Stats"` (L172), `"Distance"` (L179), `"Sessions"` (L185), `"Duration"` (L189), `"Badges Earned This Week"` (L198), `"AI Coach Says"` (L211), `"4-Week Trends"` (L234), `"Loading your weekly insights..."` (L92), `"Could not load trends"` (L107), `"Tap to retry →"` (L122), `"Higher cadence reduces overstride risk"` (L146), `"Lower oscillation = more efficient stride"` (L157), `"Shorter GCT = faster turnover"` (L168), `"Improving"/"Declining"/"Stable"` (L327-329), `"Last week:"` (L413), `"km"` (L180), `"min"` (L190)
- **根因**：Sprint 3 新增功能 RF-912，所有字符串硬编码英文，未在 `values/strings.xml`、`values-zh/strings.xml`、`values-nl/strings.xml` 中添加
- **修复**：提取所有字符串到 `strings.xml`，补全 zh/nl 翻译

#### B3 — Android: AnalysisResultScreen 部分关键标签使用硬编码英文而非 string resource
- **文件**：`android/app/src/main/java/com/runformcoach/runformcoachai/AnalysisResultScreen.kt`
- **问题项**：
  - L106: `"Overall Score"` — `strings.xml` 有 `R.string.overall_score` 但未使用
  - L123: `"Video Quality"` — `strings.xml` 有 `R.string.video_quality` 但未使用
  - L136: `"Movement Metrics"` — `strings.xml` 有 `R.string.movement_metrics_title` 但未使用
  - L146: `"Strength Focus"` — `strings.xml` 有 `R.string.strength_focus_title` 但未使用
  - L169: `"Analyze New Video"` — `strings.xml` 有 `R.string.analyze_new_video` 但未使用
  - L410: `"Exercises"` — `strings.xml` 有 `R.string.exercises` 但未使用
  - L188: `"Tester Feedback"` — `strings.xml` 有 `R.string.tester_feedback` 但未使用
  - L198: `"Help improve coaching quality"` — `strings.xml` 有 `R.string.feedback_subtitle` 但未使用
  - L227: `"Optional comment: what was wrong or useful?"` — `strings.xml` 有 `R.string.feedback_comment_hint` 但未使用
  - L299: `"Save Feedback"` — `strings.xml` 有 `R.string.feedback_save` 但未使用
- **根因**：string resource 已定义但代码中直接写死了英文字符串，未通过 `stringResource()` 引用
- **修复**：将上述硬编码字符串替换为 `stringResource(R.string.xxx)` 引用

#### B4 — WeChat: result.wxml 存在混用硬编码与 i18n 的不一致
- **文件**：`wechat/pages/result/result.wxml`
- **问题项**：
  - L30: `⚠️ 姿态分析` — 硬编码中文，应使用 `{{i.insightsTitle}}` 等 i18n key
  - L187: `{{isZh ? '保存到相册' : 'Save to Album'}}` — 内联双语，绕过 i18n 系统
  - L197-204: 激励视频广告区块全部内联双语
- **修复**：统一使用 i18n 系统的 `t()` 函数或在 Page data 中通过 `{{i.xxx}}` 引用

#### B5 — Web: AdSense 占位符 ID
- **文件**：`src/messages/en.json` L365-366, `src/messages/zh.json` L365-366
- **根因**：`adsenseClient: "ca-pub-XXXXXXXXXXXXXXXX"` 和 `adsenseSlot: "1234567890"` 均为占位符
- **修复**：替换为 Google AdSense 真实发布商 ID 和广告位 ID

#### B6 — Backend: 缺少周洞察报告专用 API 端点
- **文件**：`backend/app/main.py`
- **根因**：iOS RF-911 和 Android RF-912 的 WeeklyInsight UI 需要「本周 vs 上周对比」「AI 教练建议」「成就徽章」数据，但后端仅有 `GET /sessions/trends` 返回原始趋势数组。WeeklyInsightScreen 需要的聚合对比、AI 建议生成、徽章判定在后端无对应端点
- **影响**：Android `WeeklyInsightViewModel.kt` 和 iOS 对应 ViewModel 需自行完成所有计算逻辑，或依赖客户端 mock 数据
- **修复**：新增 `GET /api/v1/weekly-insight` 端点，返回聚合后的周对比数据 + AI 建议

#### B7 — Android: strings.xml 缺少 WeeklyInsight 全部字符串资源
- **文件**：`android/app/src/main/res/values/strings.xml`、`values-zh/strings.xml`、`values-nl/strings.xml`
- **根因**：Sprint 3 新增 Android WeeklyInsight 功能（RF-912），但三个语言的 `strings.xml` 均未添加对应 Key
- **修复**：在三个 strings.xml 中添加 B2 所列的全部缺失 Key 及翻译

---

### 2.3 Minor（低优先级或不阻塞发布）

#### M1 — iOS: PerformanceOptimizer 使用 HKHealthStore 占位存根而非真实 HealthKit
- **文件**：`ios/RunFormCoachAI/PerformanceOptimizer.swift` 第 254-256 行
- **根因**：`private struct HKHealthStore { static func isHealthDataAvailable() -> Bool { true } }` 是编译占位存根，总是返回 `true`。DeferredWork.checkHealthKitAvailability 不会检测真实的 HealthKit 可用性
- **修复**：将 `import HealthKit` 加入文件，删除占位存根，使用真实 `HKHealthStore.isHealthDataAvailable()`

#### M2 — Web: AdSense `<ins>` 块默认 `hidden`
- **文件**：`src/components/sections/AdBannerSection.tsx` 第 121 行
- **根因**：包围 AdSense `<ins>` 的 `<div>` 使用 `className="mt-6 hidden"`，即使填入真实 AdSense ID，广告也不会显示
- **修复**：移除 `hidden` class，或通过 AdSense 加载状态动态控制可见性

#### M3 — WeChat: share-card.js Canvas 字体栈可能不被小程序 2D Canvas 支持
- **文件**：`wechat/utils/share-card.js` 第 33 行
- **根因**：`FONT = '-apple-system, "PingFang SC", sans-serif'` — 微信小程序 Canvas 2D API 仅支持有限的系统字体（`sans-serif`、`serif`、`monospace`），CSS 字体栈的降级行为不可预测
- **修复**：使用 `sans-serif` 作为主要字体，或在小程序中加载自定义字体文件

#### M4 — iOS: AdBannerView 不处理广告加载失败/无填充场景
- **文件**：`ios/RunFormCoachAI/AdBannerView.swift`
- **根因**：`GADBannerView` 不使用 `GADBannerViewDelegate`，广告加载失败或无可填充广告时，用户看到一个空白区域
- **修复**：实现 `GADBannerViewDelegate`，在 `bannerView:didFailToReceiveAdWithError:` 中隐藏 banner 或显示 fallback

#### M5 — Android: BannerAdView 同样不处理广告加载失败
- **文件**：`android/app/src/main/java/com/runformcoach/runformcoachai/AnalysisResultScreen.kt` 第 463-483 行
- **根因**：`BannerAdView` composable 未实现 `AdListener`，加载失败时用户看到空白区域
- **修复**：添加 `adView.adListener` 实现 `onAdFailedToLoad` 时隐藏或缩小广告区域

#### M6 — WeChat: app.json 缺少广告相关权限声明
- **文件**：`wechat/app.json`
- **根因**：RF-963 激励视频广告需要在 `app.json` 中声明插件或权限，当前 `app.json` 无广告相关配置
- **修复**：若使用微信广告组件，需在 `app.json` 中添加 `"plugins": { "ad": { "version": "...", "provider": "wx..." } }`

---

## 三、维度专项审计

### 3.1 数据流完整性

| 链路 | 状态 | 备注 |
|------|:----:|------|
| iOS RunSession 回放 (RF-910) | ✅ 完整 | RunSessionManager → APIClient.fetchSessions → RunSessionReplayViewModel → RunSessionReplayView |
| iOS 周洞察 (RF-911) | ⚠️ 不完整 | 前端 View 存在（需确认文件名），但后端无专用 API（见 B6） |
| Android 周洞察 (RF-912) | ⚠️ 不完整 | WeeklyInsightScreen + ViewModel 存在，后端无专用 API |
| WeChat 分享卡片 (RF-913) | ❌ 断裂 | Canvas 渲染管线完整，但 QR 码生成缺失（见 C5） |
| 全平台广告 (RF-960-963) | ⚠️ 部分 | 代码集成完整，但全部使用测试/占位 ID（见 C1-C4, C7, B5） |

### 3.2 依赖注入链

| 平台 | 状态 | 备注 |
|------|:----:|------|
| iOS | ✅ 正常 | AdBannerView 为纯 SwiftUI View，通过参数注入 adUnitID；PerformanceOptimizer 通过 static enum 模式供 App struct 调用 |
| Android | ✅ 正常 | Hilt DI 已全面接入（RunFormApplication @HiltAndroidApp），StartupOptimizer 为 object 单例直接调用 |
| WeChat | ✅ 正常 | share-card.js 通过 CommonJS require 注入，i18n 通过 `require('./i18n')` 获取 |
| Web | ✅ 正常 | next-intl useTranslations hook 注入，无 DI 问题 |

### 3.3 权限声明

| 平台 | 文件 | 状态 | 问题 |
|------|------|:----:|------|
| iOS | `Info.plist` | ⚠️ | NSCameraUsageDescription ✅, NSMotionUsageDescription ✅, NSHealthShareUsageDescription ✅, GADApplicationIdentifier ⚠️ 测试 ID（C1） |
| Android | `AndroidManifest.xml` | ⚠️ | INTERNET ✅, CAMERA ✅, BODY_SENSORS ✅, FOREGROUND_SERVICE ✅, 但 AdMob App ID 为测试 ID（C3） |
| WeChat | `app.json` | ⚠️ | scope.camera ✅, scope.album ✅, scope.record ✅, requiredPrivateInfos ✅, 缺少广告插件声明（M6） |

### 3.4 广告 SDK 集成 — 全平台测试 ID 审计

| 平台 | 组件 | 当前值 | 类型 |
|------|------|--------|:----:|
| iOS | `Info.plist` GADApplicationIdentifier | `ca-app-pub-3940256099942544~1458002511` | ❌ 测试 |
| iOS | AdBannerView adUnitID | `ca-app-pub-3940256099942544/2934735716` | ❌ 测试 |
| Android | AndroidManifest APPLICATION_ID | `ca-app-pub-3940256099942544~3347511713` | ❌ 测试 |
| Android | AnalysisResultScreen BANNER_AD_UNIT_ID | `ca-app-pub-3940256099942544/6300978111` | ❌ 测试 |
| WeChat | result.js rewarded adUnitId | `adunit-xxxxxxxxxxxxxxxx` | ❌ 占位符 |
| Web | en.json / zh.json adsenseClient | `ca-pub-XXXXXXXXXXXXXXXX` | ❌ 占位符 |

**结论：全平台广告位无一使用生产 ID。这是 Sprint 3 收尾阶段最集中的技术债务。**

### 3.5 分享功能 — WeChat share-card.js Canvas 渲染链路

| 检查项 | 状态 | 详情 |
|--------|:----:|------|
| Canvas 2D API 初始化 | ✅ | `wx.createSelectorQuery().select('#shareCanvas').fields({ node: true })` |
| DPR 缩放 | ✅ | `canvas.width = W * dpr; ctx.scale(dpr, dpr)` |
| analysis 场景渲染 | ✅ | score card + 关键指标圆圈 + key finding |
| compare 场景渲染 | ✅ | 表格布局 + 用户/精英对比行 |
| history 场景渲染 | ✅ | 简化 score card + 日期 + 指标圆圈 |
| 小程序码绘制 | ❌ | 仅绘制占位矩形 + "QR" 文字（C5） |
| 保存到相册 | ✅ | `wx.saveImageToPhotosAlbum` + 权限被拒处理 |
| i18n 整合 | ✅ | drawHeader/drawFooter 使用 `isZh` 分支 |
| pageInstance 传递 | ✅ | result.js L421/L442 传递 `this` |

### 3.6 性能优化

| 平台 | 组件 | 状态 | 备注 |
|------|------|:----:|------|
| iOS | PerformanceOptimizer | ✅ 已接入 | RunFormCoachAIApp.init() 调用 markMainEntry()，onAppear 调用 markFirstFrameRender() + performDeferredInitialization()。signpost 完整，有 ImagePreloader 和 DeferredWork |
| Android | StartupOptimizer | ✅ 已接入 | RunFormApplication.onCreate() 调用 installStrictMode() + installTraceSections() + onApplicationCreate()。IdleHandler 延迟 Firebase 初始化，ANR watchdog 已启动 |

两个平台的性能优化组件均已正确接入 App 入口点，代码链完整。

### 3.7 i18n 对齐 — 新增 UI 文本三语覆盖

| 平台 | 新增功能 | 英文 (en) | 中文 (zh) | 荷兰语 (nl) | 状态 |
|------|---------|:---:|:---:|:---:|:----:|
| iOS | RunSessionReplayView (RF-910) | ❌ 硬编码 | ❌ 缺失 | ❌ 缺失 | 🔴 零覆盖 |
| Android | WeeklyInsightScreen (RF-912) | ❌ 硬编码 | ❌ 缺失 | ❌ 缺失 | 🔴 零覆盖 |
| Android | AnalysisResultScreen 部分标签 | ✅ 部分 | ✅ 资源已定义但未引用 | ✅ 资源已定义但未引用 | 🟡 |
| WeChat | result.wxml 广告区块 | ❌ 内联双语 | ❌ 硬编码中文 | ❌ 缺失 | 🔴 |
| Web | AdBannerSection (RF-960) | ✅ | ✅ | — | 🟢 |

**结论：Sprint 3 新增功能的 i18n 是未完成任务。iOS RunSessionReplayView 和 Android WeeklyInsightScreen 两大新功能均零 i18n 覆盖。**

### 3.8 隐私合规

| 检查项 | 状态 | 详情 |
|--------|:----:|------|
| iOS app_privacy_details.json vs 实际代码 | ❌ 不一致 | 声明 Crashlytics（L39）但代码未集成 Firebase。声明 Location（L22）但 Info.plist 无 NSLocationWhenInUseUsageDescription |
| Info.plist 隐私描述 | ✅ 完整 | Camera / PhotoLibrary / Motion / HealthShare / HealthUpdate 均有描述字符串 |
| Android data_safety.txt | ✅ | `fastlane/metadata/android/en-US/data_safety.txt` 声明 Crashlytics + Analytics（与代码一致） |
| WeChat 隐私保护说明 | ✅ | `审核材料/隐私保护说明.txt` 存在 |
| WeChat requiredPrivateInfos | ✅ | app.json 声明 chooseMedia |

**特别关注**：iOS `app_privacy_details.json` 声称收集 Location 数据，但 `Info.plist` 中缺少 `NSLocationWhenInUseUsageDescription` 和 `NSLocationAlwaysAndWhenInUseUsageDescription` 键。这会导致：
1. 若未来启用定位功能，App Store 审核会被拒
2. 隐私标签与实际权限不匹配

### 3.9 后端 API — Route 注册与 Schema 验证

| 端点 | 方法 | 状态 | Schema |
|------|------|:----:|--------|
| `/health` | GET | ✅ | dict |
| `/profile` | PUT | ✅ | ProfileSaveRequest → ProfileSaveResponse |
| `/training-plan` | POST | ✅ | TrainingPlanInput → TrainingPlanResponse |
| `/analyze-metrics` | POST | ✅ | PoseMetricsInput → AnalysisResponse |
| `/analyze` | POST | ✅ | UploadFile → AnalysisResponse |
| `/athletes` | GET | ✅ | list[AthleteListItem] |
| `/compare` | POST | ✅ | CompareRequest → CompareResponse |
| `/api/v1/feedback` | POST | ✅ | FeedbackSubmitRequest → FeedbackSubmitResponse |
| `/sessions` | POST / GET | ✅ | RunSessionCreate → RunSessionResponse |
| `/sessions/trends` | GET | ✅ | SessionTrendsResponse |
| `/sessions/compare` | POST | ✅ | SessionCompareRequest → SessionCompareResponse |
| `/sessions/{id}` | GET / DELETE | ✅ | RunSessionResponse |
| `/integrations/strava/*` | 多个 | ✅ | 所有 Schema 完整 |
| `/api/v1/weekly-insight` | — | ❌ 缺失 | 见 B6 |

所有已注册端点均使用了 Pydantic response_model，异常处理完备（Strava 端点有统一 `_strava_endpoint` 装饰器）。

---

## 四、风险评估

### 整体风险等级：🔴 **高**

| 风险项 | 严重度 | 概率 | 影响 |
|--------|:------:|:----:|------|
| 全平台广告使用测试/占位 ID 上线 | Critical | 100% | 零广告收益，可能触发 AdMob 无效流量警告 |
| iOS 隐私标签与代码不一致 | Critical | 中 | App Store 审核拒绝（如触发人工审查） |
| WeChat 分享卡片无真实小程序码 | Critical | 100% | 分享功能核心价值缺失，用户分享的卡片是残次品 |
| Sprint 3 新功能零 i18n（iOS RunSessionReplay + Android WeeklyInsight） | High | 100% | 非英语用户看到全英文界面，体验断裂 |
| Android 硬编码英文标签（AnalysisResultScreen） | Medium | 100% | 虽有资源定义但未引用，浪费已有翻译 |
| iOS 缺 NSLocationWhenInUseUsageDescription | Low | 低 | 当前未启用定位功能，暂无影响；未来启用时需补 |

---

## 五、发布建议

### 5.1 发布前必须修复（P0 — 阻塞 App Store / Google Play 提交）

- [ ] **C1/C3**: 替换 iOS 和 Android 的 AdMob App ID 为生产 ID
- [ ] **C2/C4**: 替换 iOS 和 Android 的广告单元 ID 为生产 ID，并添加 `#if DEBUG` / `BuildConfig.DEBUG` 分支
- [ ] **C6**: 二选一 — 接入 Firebase Crashlytics 或从隐私清单中移除该声明
- [ ] **C7**: 替换 WeChat 激励视频广告单元 ID
- [ ] **C5**: 实现小程序码真实生成（可降级为预生成静态图）

### 5.2 强烈建议修复（P1 — 影响功能完整性）

- [ ] **B1-B3**: Sprint 3 新增功能 i18n（iOS RunSessionReplayView + Android WeeklyInsightScreen + Android AnalysisResultScreen 标签）
- [ ] **B5**: Web AdSense 发布商 ID 替换
- [ ] **B6**: 后端新增 `/api/v1/weekly-insight` 端点或确认客户端可独立完成计算
- [ ] **M2**: Web AdSense 块移除 `hidden` class
- [ ] **App Store 隐私**: 从 `app_privacy_details.json` 中移除 Location 声明或添加 Info.plist 定位权限描述

### 5.3 发布后跟进（P2 — Sprint 4）

- [ ] **M1**: iOS 替换 HKHealthStore 存根为真实 HealthKit import
- [ ] **M3**: WeChat share-card.js 字体栈兼容性验证
- [ ] **M4/M5**: iOS/Android 广告加载失败 UI fallback
- [ ] **M6**: WeChat app.json 广告插件声明（如需要）
- [ ] **B4**: WeChat result.wxml 硬编码字符串迁移到 i18n 系统
- [ ] **C6 (方案A)**: iOS Firebase Crashlytics 接入（按 monitoring-setup.md §4.1）

### 5.4 建议不阻塞发布的已知风险

以下为已知且已记录的风险，团队已确认在 Sprint 3 不做处理：

1. **RF-205 Strava 暂停**：不在本次测试范围内
2. **iOS Crashlytics 未接入**：已记录在 `qa/monitoring-setup.md`，规划 Sprint 4 执行
3. **Web/WeChat 错误监控未接入**：同上，规划 Sprint 4 RF-1040 解决

---

## 六、测试数据统计

| 维度 | 总数 | 通过 | 失败 | 覆盖率 |
|------|:----:|:----:|:----:|:------:|
| Critical | 7 | 0 | 7 | 0% |
| Bug | 7 | 0 | 7 | 0% |
| Minor | 6 | 0 | 6 | 0% |
| **合计** | **20** | **0** | **20** | **0%** |

| 平台 | Critical | Bug | Minor | 合计 |
|------|:--------:|:---:|:-----:|:----:|
| iOS | 2 | 1 | 2 | 5 |
| Android | 2 | 3 | 1 | 6 |
| WeChat | 2 | 1 | 2 | 5 |
| Web | 0 | 1 | 1 | 2 |
| Backend | 0 | 1 | 0 | 1 |
| 跨平台 | 1 | 0 | 0 | 1 |

---

*报告由 qa-release-engineer 生成于 2026-05-18 21:15 UTC+8。WSL 静态审查，未经编译/运行时验证。*
