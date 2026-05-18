# RunForm 全平台上线后监控基建方案

> **文档 ID**：MON-001  
> **关联 Backlog**：RF-1040（全平台 Crash/ANR/异常监控）  
> **创建日期**：2026-05-18  
> **负责角色**：QA & 发布工程师 (qa-release-engineer)  
> **状态**：审计完成，方案已输出，待 RF-1040 正式执行  
> **代码库路径**：`~/workspace/runform/` + `~/workspace/movenova.ai/`

---

## 一、执行摘要

本文件是 RF-1040 的前置工作产物——在 Sprint 4 正式启动前完成全平台监控状态审计，对缺失平台提供接入方案，并整合为统一监控清单。Sprint 4 Week 1（6/16-6/20）将由 QA/后端团队执行本方案中的接入步骤。

**关键发现**：四端监控覆盖不均。Android 已完成 Firebase Crashlytics + Analytics 全量接入（RF-215），iOS 仅在隐私文档声明 Crashlytics 但代码零集成，微信小程序和 Web 无任何错误监控。后端仅有基础 logging，缺少结构化日志和 APM。

---

## 二、各平台监控状态审计

### 2.1 iOS — Firebase Crashlytics

| 维度 | 状态 | 详情 |
|------|:----:|------|
| **GoogleService-Info.plist** | ❌ 不存在 | 未在 `ios/` 目录下找到此文件 |
| **Firebase SDK 依赖** | ❌ 未集成 | 无 SPM/CocoaPods Firebase 声明；`project.yml` 中无 Firebase 包引用 |
| **Crashlytics 初始化代码** | ❌ 未集成 | `RunFormCoachAIApp.swift` 和 `PerformanceOptimizer.swift` 均无 Firebase.configure / Crashlytics 调用 |
| **隐私文档声明** | ⚠️ 预声明 | `fastlane/metadata/en-US/app_privacy_details.json` 第39行声称使用 Firebase Crashlytics，但实际未接入 |
| **性能监控** | ⚠️ 仅本地 | `PerformanceOptimizer.swift` 使用 `os_signpost` 记录启动性能，仅本地 Instruments 可见，无远程上报 |

**结论**：❌ **完全未接入。App Store 隐私标签与实际代码不一致，有审核风险。**

**代码审计证据**：
- `ios/RunFormCoachAI/RunFormCoachAIApp.swift`（34行）— 无 Firebase import / configure  
- `ios/RunFormCoachAI/PerformanceOptimizer.swift`（293行）— 仅有 os_signpost 本地性能日志  
- `ios/RunFormCoachAI/Info.plist` — 无 Firebase 相关配置项  
- `ios/project.yml` — 无 Firebase 包依赖声明

---

### 2.2 Android — Firebase Crashlytics + Analytics

| 维度 | 状态 | 详情 |
|------|:----:|------|
| **Crashlytics SDK** | ✅ 已集成 | `app/build.gradle.kts` L9: `id("com.google.firebase.crashlytics")` + L114-115: 依赖声明 |
| **Analytics SDK** | ✅ 已集成 | L116: `implementation(libs.firebase.analytics)` |
| **Firebase BOM** | ✅ v33.12.0 | `gradle/libs.versions.toml` L25 |
| **google-services.json** | ⚠️ 未确认 | 未在仓库中找到（可能被 .gitignore 排除或使用 Firebase 运行时配置） |
| **Crashlytics 初始化** | ✅ 懒加载 | `StartupOptimizer.kt` L139-179: 通过 IdleHandler 延迟初始化，避免阻塞首帧 |
| **全局异常捕获** | ✅ 已配置 | `StartupOptimizer.kt` L157-165: `Thread.setDefaultUncaughtExceptionHandler` → Crashlytics.recordException |
| **非致命错误上报** | ✅ 已封装 | `AnalyticsHelper.kt` L70-76: `logNonFatal(throwable)` 和 `logNonFatal(message)` |
| **Screen View 追踪** | ✅ 已封装 | `AnalyticsHelper.kt` L20-26: `logScreenView(screenName, screenClass)` |
| **自定义事件追踪** | ✅ 已封装 | 分析开始/完成、实时引导录音、训练计划生成等事件 |
| **ProGuard 规则** | ✅ 已配置 | `proguard-rules.pro` L63-65: Firebase keep 规则 |
| **数据安全表单** | ✅ 已更新 | `fastlane/metadata/android/en-US/data_safety.txt` 声明 Crashlytics + Analytics |

**结论**：✅ **已全面接入。Android 是四端中监控最完善的平台。RF-215 工单已完成交付。**

**代码审计证据**：
- `android/app/src/main/java/com/runformcoach/runformcoachai/StartupOptimizer.kt`  
- `android/app/src/main/java/com/runformcoach/runformcoachai/analytics/AnalyticsHelper.kt`  
- `android/app/src/main/java/com/runformcoach/runformcoachai/di/AnalyticsModule.kt`  
- `android/app/build.gradle.kts`  
- `android/gradle/libs.versions.toml`

---

### 2.3 微信小程序 — 错误日志收集

| 维度 | 状态 | 详情 |
|------|:----:|------|
| **wx.onError 全局错误监听** | ❌ 未配置 | `app.js` 中无全局错误捕获 |
| **wx.onUnhandledRejection** | ❌ 未配置 | Promise 未处理拒绝无监听 |
| **云函数错误日志** | ❌ 无 | `cloudfunctions/login/index.js` 仅登录逻辑，无日志存储 |
| **WeChat alog SDK** | ❌ 未接入 | 微信官方实时日志 SDK 未使用 |
| **第三方监控 (Sentry/Fundebug)** | ❌ 未接入 | 无任何 JS 错误监控 SDK |
| **console.error 分散使用** | ⚠️ 仅本地 | `app.js`、`utils/cloudbase.js`、`utils/cadence.js` 等有 console.error，仅开发者工具可见 |
| **wx.cloud.traceUser** | ✅ 已开启 | `cloudbase.js` L31: `traceUser: true`，但仅限云开发调用链追踪 |
| **用户可见错误** | ⚠️ 基础 | 网络错误通过 `wx.showToast({ icon: 'error' })` 提示用户 |

**结论**：❌ **无任何结构化错误监控。线上用户白屏/崩溃对开发者完全不可见。**

**代码审计证据**：
- `wechat/app.js`（67行）— 无 App.onError / onUnhandledRejection  
- `wechat/utils/cloudbase.js`（309行）— 仅有 console.warn/error，无远程上报  
- `wechat/pages/` 各页面 JS — 错误仅 showToast + console.error，无远程收集

---

### 2.4 Web (movenova.ai) — Sentry 或类似工具

| 维度 | 状态 | 详情 |
|------|:----:|------|
| **Sentry SDK** | ❌ 未安装 | `package.json` 中无 `@sentry/nextjs` 或其他 Sentry 依赖 |
| **ErrorBoundary** | ❌ 未配置 | Next.js error.tsx / React Error Boundary 无 Sentry 集成 |
| **其他监控 (Datadog/LogRocket)** | ❌ 无 | 无任何 APM / RUM 工具 |
| **Vercel Analytics** | ❌ 未使用 | 服务器端错误仅 Vercel 默认日志（如有） |
| **Lighthouse CI** | ❌ 无 | 无性能回归检测流水线 |
| **Website CI** | ⚠️ 仅构建验证 | `.github/workflows/website-test.yml` 仅执行 `npm run build`，无测试/监控 |

**结论**：❌ **零错误监控。线上 JS 异常、API 错误、页面崩溃对开发者完全不可见。**

**代码审计证据**：
- `movenova.ai/package.json`（36行）— 仅 Next.js + UI 库，无监控依赖

---

### 2.5 后端 (Python/FastAPI) — 补充审计

| 维度 | 状态 | 详情 |
|------|:----:|------|
| **结构化日志** | ❌ 无 | 仅有标准 `logging` 模块 INFO 日志（feedback 端点） |
| **Sentry/DataDog** | ❌ 未接入 | 无任何 APM 或错误追踪 SDK |
| **Health Check** | ✅ | `GET /health` 返回服务状态 + DB 连通性 |
| **异常处理** | ✅ 完善 | 每个端点 try/except → HTTPException，Strava 端点有统一异常映射装饰器 |
| **CI 测试** | ✅ | `.github/workflows/backend-test.yml` 执行 ruff lint + pytest |

**结论**：⚠️ **基础可用但缺远程监控。RF-1040 聚焦前端 Crash/ANR，后端监控可在 RF-1041 压力测试中同步补齐。**

---

## 三、监控状态总览表

| 平台 | Crash 监控 | 性能监控 | 自定义事件 | 远程日志 | 告警 | 状态 |
|------|:----------:|:--------:|:----------:|:--------:|:----:|:----:|
| **iOS** | ❌ | ❌ | ❌ | ❌ | ❌ | 🔴 零覆盖 |
| **Android** | ✅ | ✅ | ✅ | ✅ | ⚠️ 需配置 | 🟢 完善 |
| **微信小程序** | ❌ | ❌ | ❌ | ❌ | ❌ | 🔴 零覆盖 |
| **Web** | ❌ | ❌ | ❌ | ❌ | ❌ | 🔴 零覆盖 |
| **后端** | N/A | ⚠️ 本地 | ⚠️ 本地 | ⚠️ 本地 | ❌ | 🟡 基础 |

**图例**：🟢 已接入 · 🟡 基础可用 · 🔴 未接入

---

## 四、缺失平台接入方案

### 4.1 iOS — Firebase Crashlytics 接入方案

#### 前置条件
- Apple Developer Program 有效会员资格
- Firebase 项目已创建（与 Android 共用同一项目 `runform-coach-ai`）
- 从 Firebase Console 下载 `GoogleService-Info.plist`

#### 接入步骤

**Step 1：添加 Firebase 依赖**

在 `ios/project.yml` 中添加 SPM 依赖：

```yaml
packages:
  Firebase:
    url: https://github.com/firebase/firebase-ios-sdk
    majorVersion: 11.0.0

targets:
  RunFormCoachAI:
    type: application
    platform: iOS
    sources:
      - path: ios/RunFormCoachAI
    dependencies:
      - package: Firebase
        product: FirebaseCrashlytics
      - package: Firebase
        product: FirebaseAnalytics
```

**Step 2：添加 GoogleService-Info.plist**

将下载的 `GoogleService-Info.plist` 放入 `ios/RunFormCoachAI/` 目录，并在 `project.yml` 中声明资源：

```yaml
    settings:
      INFOPLIST_FILE: ios/RunFormCoachAI/Info.plist
    sources:
      - path: ios/RunFormCoachAI
        excludes:
          - "**/.swiftlint.yml"
    preBuildScripts:
      - name: "Firebase Crashlytics dSYM Upload"
        script: |
          "${BUILD_DIR%Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"
        inputFiles:
          - "$(DWARF_DSYM_FOLDER_PATH)/$(DWARF_DSYM_FILE_NAME)/Contents/Resources/DWARF/$(TARGET_NAME)"
          - "$(SRCROOT)/$(BUILT_PRODUCTS_DIR)/$(INFOPLIST_PATH)"
```

**Step 3：初始化 Firebase（懒加载，对齐 Android 模式）**

在 `RunFormCoachAIApp.swift` 中添加延迟初始化：

```swift
import SwiftUI
import FirebaseCore
import FirebaseCrashlytics

@main
struct RunFormCoachAIApp: App {
    init() {
        PerformanceOptimizer.markMainEntry()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    if !launchCompleted {
                        launchCompleted = true
                        PerformanceOptimizer.markFirstFrameRender()
                        Task {
                            await PerformanceOptimizer.performDeferredInitialization()
                            // Deferred Firebase init (like Android's IdleHandler)
                            await PerformanceOptimizer.initializeFirebase()
                            PerformanceOptimizer.logLaunchReport()
                        }
                    }
                }
        }
    }
}
```

在 `PerformanceOptimizer.swift` 中添加：

```swift
public static func initializeFirebase() async {
    guard FirebaseApp.app() == nil else { return }
    FirebaseApp.configure()
    Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
    // Log launch duration as a custom key
    let totalMs = Int((fullInteractiveTime - processStartTime) * 1000)
    Crashlytics.crashlytics().setCustomValue(totalMs, forKey: "cold_start_ms")
}
```

**Step 4：配置 dSYM 自动上传**

在 `.github/workflows/ios-build.yml` archive 步骤后添加：

```yaml
- name: Upload dSYMs to Crashlytics
  run: |
    "${BUILD_DIR%Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/upload-symbols" \
      -gsp ios/RunFormCoachAI/GoogleService-Info.plist \
      -p ios build/RunFormCoachAI.xcarchive/dSYMs
```

**Step 5：更新 App Store 隐私标签**

`ios/fastlane/metadata/en-US/app_privacy_details.json` 中 Crashlytics 声明已存在（L39），确认与实际接入一致。

#### 验证方法

1. **强制崩溃测试**：在开发构建中临时添加 `fatalError("Test crash for Crashlytics")` 按钮，触发后检查 Firebase Console > Crashlytics 是否收到报告
2. **非致命错误测试**：`Crashlytics.crashlytics().record(error)` 后检查 Console
3. **启动性能上报**：检查 Crashlytics 自定义 key `cold_start_ms` 是否有值
4. **dSYM 符号化**：确认 Firebase Console 中崩溃堆栈已符号化（非十六进制地址）

#### 预计工时
- **SP 估算**：5 SP（含依赖配置、初始化、dSYM 自动化、隐私标签审核）
- **执行时机**：Sprint 4 Week 1（RF-1040）

---

### 4.2 微信小程序 — 错误日志收集方案

#### 平台限制
微信小程序无法使用 Sentry 等传统 JS SDK（无 DOM、无 `window.onerror`）。可选方案有三：

| 方案 | 成本 | 覆盖度 | 推荐度 |
|------|------|:------:|:------:|
| **A: 微信 we分析 + 实时日志** | 低（微信生态免费） | Web 端查看 | ⭐⭐⭐⭐⭐ |
| **B: 自建错误收集 → 后端 `/api/v1/log`** | 中（需后端新增端点） | 实时查看 | ⭐⭐⭐⭐ |
| **C: Fundebug / FrontJS 小程序 SDK** | 中（第三方付费） | 详细堆栈 | ⭐⭐⭐ |

#### 推荐方案：A + B 组合
- 方案 A 用于日常监控和聚合统计
- 方案 B 用于实时错误告警（对接 Push 通知）

#### 接入步骤（方案 A：微信 we分析）

**Step 1：开通微信 we分析**

在 mp.weixin.qq.com → 开发 → 开发管理 → 运维中心 → 实时日志 / we分析 开通。

**Step 2：接入 we分析 SDK**

在 `app.js` 中接入：

```javascript
// app.js
App({
  onLaunch() {
    // 接入 we分析
    if (wx.reportEvent) {
      wx.reportEvent('app_launch', {})
    }
  },

  onError(error) {
    // 全局错误捕获 → we分析实时日志
    console.error('[App.onError]', error)
    if (wx.getRealtimeLogManager) {
      const log = wx.getRealtimeLogManager()
      log.error('App.onError', error)
    }
  },

  onUnhandledRejection(res) {
    console.error('[App.onUnhandledRejection]', res.reason)
    if (wx.getRealtimeLogManager) {
      const log = wx.getRealtimeLogManager()
      log.error('UnhandledRejection', res.reason)
    }
  },
})
```

**Step 3：创建统一错误上报工具**

新建 `wechat/utils/error-reporter.js`：

```javascript
// utils/error-reporter.js
const { t } = require('./i18n')

const reporter = {
  init() {
    // 基础库 >= 2.12.0 支持 RealtimeLogManager
    if (!wx.getRealtimeLogManager) {
      console.warn('[error-reporter] RealtimeLogManager not available (base lib < 2.12.0)')
      return false
    }
    this._rtm = wx.getRealtimeLogManager()
    return true
  },

  // 上报 JS 错误
  error(error, context = {}) {
    const payload = {
      type: 'js_error',
      message: error instanceof Error ? error.message : String(error),
      stack: error instanceof Error ? error.stack : '',
      context: JSON.stringify(context),
      time: new Date().toISOString(),
    }
    console.error('[error-reporter]', payload)
    if (this._rtm) {
      this._rtm.error(JSON.stringify(payload))
    }
  },

  // 上报 API 请求失败
  apiError(url, status, response, duration) {
    const payload = {
      type: 'api_error',
      url,
      status,
      response: typeof response === 'string' ? response.slice(0, 500) : JSON.stringify(response).slice(0, 500),
      duration_ms: duration,
      time: new Date().toISOString(),
    }
    if (this._rtm) {
      this._rtm.warn(JSON.stringify(payload))
    }
  },

  // 上报自定义事件（用于漏斗分析）
  trackEvent(name, params = {}) {
    const payload = { name, ...params, time: new Date().toISOString() }
    if (this._rtm) {
      this._rtm.info(JSON.stringify(payload))
    }
  },
}

module.exports = reporter
```

**Step 4：在关键位置接入**

- `utils/api.js` 的通用请求函数中，catch 块调用 `reporter.apiError()`
- 各页面 onLoad / 关键操作 catch 块调用 `reporter.error()`

#### 验证方法

1. 在微信开发者工具中触发一个 JS 错误，检查「运维中心 → 实时日志」是否显示
2. 在体验版中触发错误，在 mp.weixin.qq.com → 运维中心查看
3. 过滤日志类型 `js_error` / `api_error` 确认分类正确

#### 预计工时
- **SP 估算**：2 SP（纯接入 we分析 RealtimeLogManager + error-reporter.js）
- **执行时机**：Sprint 4 Week 1（RF-1040）

---

### 4.3 Web (movenova.ai) — Sentry 接入方案

#### 推荐方案
`@sentry/nextjs` — Next.js 原生集成，支持 Server-side / Client-side / Edge 三层错误捕获。

#### 接入步骤

**Step 1：安装 Sentry**

```bash
cd ~/workspace/movenova.ai
npm install @sentry/nextjs
```

**Step 2：运行 Sentry 向导**

```bash
npx @sentry/wizard@latest -i nextjs
```

向导会自动：
- 创建 `sentry.client.config.ts` 和 `sentry.server.config.ts`
- 更新 `next.config.ts` 添加 `withSentryConfig`
- 生成 `sentry.edge.config.ts`

**Step 3：手动配置（如不使用向导）**

创建 `sentry.client.config.ts`：

```typescript
import * as Sentry from '@sentry/nextjs'

Sentry.init({
  dsn: process.env.NEXT_PUBLIC_SENTRY_DSN,
  tracesSampleRate: 0.1,  // 10% 性能追踪采样
  replaysSessionSampleRate: 0.1,
  replaysOnErrorSampleRate: 1.0,
  environment: process.env.NEXT_PUBLIC_ENV || 'production',
  beforeSend(event) {
    // 过滤敏感信息
    if (event.request?.cookies) {
      delete event.request.cookies
    }
    return event
  },
})
```

创建 `sentry.server.config.ts`：

```typescript
import * as Sentry from '@sentry/nextjs'

Sentry.init({
  dsn: process.env.SENTRY_DSN || process.env.NEXT_PUBLIC_SENTRY_DSN,
  tracesSampleRate: 0.1,
  environment: process.env.VERCEL_ENV || 'production',
})
```

**Step 4：添加全局 Error Boundary**

创建 `app/global-error.tsx`：

```tsx
'use client'

import * as Sentry from '@sentry/nextjs'
import { useEffect } from 'react'

export default function GlobalError({ error, reset }: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  useEffect(() => {
    Sentry.captureException(error)
  }, [error])

  return (
    <html>
      <body>
        <div style={{ padding: '2rem', textAlign: 'center' }}>
          <h2>Something went wrong</h2>
          <button onClick={() => reset()}>Try again</button>
        </div>
      </body>
    </html>
  )
}
```

**Step 5：设置 GitHub Actions 环境变量**

在仓库 Settings → Secrets 添加：
- `SENTRY_DSN` — Sentry DSN（服务端）
- `NEXT_PUBLIC_SENTRY_DSN` — Sentry DSN（客户端）
- `SENTRY_AUTH_TOKEN` — 用于 CI 中上传 source maps

**Step 6：更新 CI 构建**

在 `.github/workflows/website-test.yml` 中添加 Sentry source map 上传：

```yaml
- name: Build website
  run: npm run build
  env:
    SENTRY_AUTH_TOKEN: ${{ secrets.SENTRY_AUTH_TOKEN }}
    NEXT_PUBLIC_SENTRY_DSN: ${{ secrets.NEXT_PUBLIC_SENTRY_DSN }}
```

#### 验证方法

1. 在本地开发环境触发 `throw new Error('Sentry test')`，检查 Sentry Dashboard → Issues
2. 部署到 Vercel staging 后触发错误，确认 source map 正确映射
3. 检查 Performance 页面是否有 Web Vitals 数据（LCP / FID / CLS）

#### 预计工时
- **SP 估算**：3 SP（含 Sentry 项目创建、SDK 接入、Error Boundary、CI 集成）
- **执行时机**：Sprint 4 Week 1（RF-1040）

---

### 4.4 后端 — 结构化日志 + Sentry（补充建议）

虽然 RF-1040 聚焦前端 Crash/ANR，但后端监控缺失会影响排查效率。建议在 RF-1041（后端压力测试）中同步接入：

```python
# 方案 A：Sentry SDK（轻量）
# pip install sentry-sdk
import sentry_sdk
sentry_sdk.init(
    dsn=os.getenv("SENTRY_DSN"),
    traces_sample_rate=0.1,
    environment=os.getenv("ENVIRONMENT", "production"),
)

# 在 FastAPI app 中添加 Sentry middleware
from sentry_sdk.integrations.fastapi import FastApiIntegration
sentry_sdk.init(integrations=[FastApiIntegration()])
```

---

## 五、告警阈值配置建议

Sprint 4 Week 1 接入完成后，在 Firebase Console / Sentry Dashboard 中配置以下告警：

### 5.1 Firebase Crashlytics（iOS + Android）

| 告警名称 | 条件 | 通道 | 优先级 |
|----------|------|------|:----:|
| Crash-free rate 下降 | < 99.0%（1h 窗口） | Slack / 邮件 | 🔴 P0 |
| Crash-free rate 预警 | < 99.5%（24h 窗口） | Slack | 🟡 P1 |
| 新版本 Crash 激增 | v2.x 发布 2h 内 crash-free < 97% | Slack + 短信 | 🔴 P0 |
| 特定 Crash 频率 | 同一 Issue 1h 内 ≥ 10 次 | Slack | 🟡 P1 |
| ANR 率 | ≥ 0.5%（Android，24h 窗口） | Slack | 🟡 P1 |

### 5.2 Sentry（Web）

| 告警名称 | 条件 | 通道 | 优先级 |
|----------|------|------|:----:|
| 新 Error Issue | 首次出现的新错误类型 | Sentry 默认邮件 | 🟡 P2 |
| Error 频率激增 | 1h 内同一 Issue ≥ 50 次 | Slack | 🔴 P0 |
| Web Vitals 劣化 | LCP > 4s（P75，24h 窗口） | Slack | 🟡 P1 |
| API 错误率 | 5xx 错误率 > 5%（5min 窗口） | Slack | 🔴 P0 |

### 5.3 微信 we分析（WeChat）

| 告警名称 | 条件 | 通道 | 优先级 |
|----------|------|------|:----:|
| JS 错误频率 | 1h 内 js_error ≥ 20 次 | mp 后台站内信 | 🟡 P1 |
| API 错误率 | api_error / 总请求 > 5%（1h 窗口） | mp 后台站内信 | 🔴 P0 |
| 页面加载失败 | webview onError ≥ 10%（1h 窗口） | mp 后台站内信 | 🟡 P1 |

### 5.4 告警通道设置

| 通道 | 工具 | 用途 |
|------|------|------|
| **Slack** | `#runform-alerts` 频道 | 日常监控告警 |
| **邮件** | Firebase / Sentry 默认 | 非紧急告警 |
| **短信/电话** | PagerDuty（可选） | P0 崩溃告警 |

---

## 六、Sprint 4 全平台监控交付清单

| ID | 条目 | 平台 | SP | 优先级 | 依赖 |
|----|------|------|:--:|:------:|------|
| RF-1040-1 | iOS: Firebase Crashlytics 接入（SDK + 初始化 + dSYM） | iOS | 5 | P0 | Firebase 项目 admin 权限 |
| RF-1040-2 | 微信小程序: we分析 RealtimeLogManager + error-reporter.js | WeChat | 2 | P0 | 可自执行 |
| RF-1040-3 | Web: Sentry 接入（SDK + Error Boundary + CI） | Web | 3 | P0 | Sentry 项目创建 |
| RF-1040-4 | Firebase Console: Crashlytics 告警规则配置 | iOS+Android | 1 | P1 | RF-1040-1 完成后 |
| RF-1040-5 | Sentry Dashboard: 告警规则配置 | Web | 1 | P1 | RF-1040-3 完成后 |
| RF-1040-6 | 微信 mp 后台: 实时日志告警配置 | WeChat | 0.5 | P2 | RF-1040-2 完成后 |
| RF-1040-7 | 全平台监控验证：触发测试错误 → 确认各通道收到 | 全平台 | 1 | P0 | 全部接入完成后 |
| **合计** | | | **13.5** | | |

> 原 RF-1040 估算为 3 SP，经审计发现 iOS 需要 5 SP（含 dSYM 配置），建议调整为 13.5 SP 或拆分为多个子工单跨 Week 1-2 交付。

---

## 七、Sprint 3 QA 完成状态审计

### 7.1 Sprint 3 条目完成状态

基于 `product/sprint-4-backlog.md` 中的 Sprint 3 状态声明和代码审计，Sprint 3 各条目完成情况如下：

| ID | 条目 | 状态 | 证据 |
|----|------|:----:|------|
| **上线准备** | | | |
| RF-900 | App Store Connect 上架准备 | ✅ 已完成 | `ios/fastlane/metadata/` 完整，App 已在 App Store 上架 |
| RF-901 | Google Play Console 上架准备 | ✅ 已完成 | `android/fastlane/metadata/` 完整，App 已在 Google Play 上架 |
| RF-902 | 微信小程序提审准备 | ✅ 已完成 | `wechat/审核材料/` 3 份文件齐全，小程序审核中 |
| RF-903 | 全平台隐私政策 + 服务条款 | ✅ 已完成 | iOS/Android 隐私文档已更新，Web 有 TOU |
| **用户功能** | | | |
| RF-910 | iOS RunSession 历史回放 | ✅ 已完成 | `RunSessionReplayView.swift` 存在，Sprint 4 Backlog 确认 |
| RF-911 | iOS 周训练洞察报告 | ✅ 已完成 | Sprint 4 Backlog 确认 |
| RF-912 | Android 周训练洞察报告 | ✅ 已完成 | `WeeklyInsightScreen.kt` + `WeeklyInsightViewModel.kt` 存在 |
| RF-913 | 微信分享卡片图片生成 | ⚠️ 部分完成 | `result.js` 有 Canvas 分享逻辑（L608），但仅基础实现，Sprint 4 续做 |
| **性能优化** | | | |
| RF-920 | iOS 冷启动优化 | ✅ 已完成 | `PerformanceOptimizer.swift` 完整实现，`RunFormCoachAIApp.swift` 延迟初始化 |
| RF-921 | Android 冷启动优化 | ✅ 已完成 | `StartupOptimizer.kt` 完整实现，`RunFormApplication.kt` 延迟初始化 |
| **营销** | | | |
| RF-930 | Google Play ASO 优化 | ⚠️ 需复查 | Sprint 4 有续做（RF-1030） |
| RF-931 | 网站 SEO | ⚠️ 需复查 | `sitemap.xml` + `robots.txt` 存在于 `.vercel/output/static/` |
| RF-932 | Google Ads 搜索广告 | ⚠️ 需复查 | |
| RF-940 | 微信公众号内容发布 | ⚠️ 需复查 | `marketing/wechat-ads/` 文案已准备 |
| RF-941 | 小程序分享卡片优化 | ⚠️ 部分完成 | Sprint 4 有续做（RF-1011） |
| RF-942 | 微信朋友圈广告 | ⚠️ 需复查 | `marketing/wechat-ads/moments-ad-copy.md` 已准备 |
| RF-950 | 小红书内容矩阵 | ⚠️ 需复查 | |
| RF-951 | KOC 合作启动 | ⚠️ 需复查 | |
| **广告变现** | | | |
| RF-960 | 网站广告位搭建 | ⚠️ 需复查 | |
| RF-961 | iOS AdMob 集成 | ⚠️ P2 待确认 | Sprint 4 Backlog 列为可能未完成，可降级 |
| RF-962 | Android AdMob 集成 | ⚠️ P2 待确认 | 同上 |
| RF-963 | 微信小程序激励视频广告 | ⚠️ P2 待确认 | 同上 |

### 7.2 QA 基础设施完成情况（Sprint 0-1 建设成果）

| 基础设施 | 状态 | 文件 |
|----------|:----:|------|
| iOS XCTest CI | ✅ 已上线 | `.github/workflows/ios-test.yml` |
| Android JUnit CI | ✅ 已上线 | `.github/workflows/android-test.yml` |
| Backend pytest CI | ✅ 已上线 | `.github/workflows/backend-test.yml` |
| Website Build CI | ✅ 已上线 | `.github/workflows/website-test.yml` |
| Bug Report 模板 | ✅ 已创建 | `.github/ISSUE_TEMPLATE/bug_report.md` |
| Bug 工作流 + SLA | ✅ 文档定义 | `onboarding/qa-release-engineer.md` §2.3 |
| 发布前回归 Checklist | ✅ 文档定义 | `onboarding/qa-release-engineer.md` §2.3.3 |
| 微信小程序测试计划 | ✅ 已定义 | `onboarding/sprint-1-test-plan.md` |
| SwiftLint 配置 | ✅ 已配置 | `ios/.swiftlint.yml` + CI 集成 |
| Android Lint | ✅ CI 集成 | `lintDebug` 在 android-test.yml |

### 7.3 Sprint 3 待确认项（需人工复查）

以下 P2 条目在 Sprint 4 Backlog 中列为「如未完成 → 降级或迁移」，需在 Sprint 4 启动前与开发确认：

- **RF-961/962/963**（AdMob 集成）：若未完成，Sprint 4 仅简化为 SDK 集成，广告位后续
- **RF-930-932**（营销条目）：需营销经理更新实际完成状态
- **RF-913**（分享卡片）：基础版已完成，增强版迁移为 RF-1011

### 7.4 Sprint 3 QA 综合评估

**已完成关键项**：
- ✅ 三端上架准备全部完成（iOS 已上架、Android 已上架、小程序审核中）
- ✅ 用户核心功能交付（RunSession 回放、周洞察、冷启动优化）
- ✅ CI 测试流水线四端全部上线（iOS XCTest / Android JUnit / Backend pytest / Web Build）
- ✅ Bug 管理基础设施完整（模板 + 流程 + SLA）

**待改进**：
- ⚠️ 监控基建缺失（本文件的主题）
- ⚠️ P2 变现条目完成状态不明
- ⚠️ 无全平台端到端自动化测试（Sprint 4 RF-1042 将补齐）

**整体评分**：🟢 **上线准备就绪，Sprint 3 核心 P0/P1 条目已交付。**

---

## 八、执行计划

### Sprint 4 Week 1（6/16-6/20）：监控基建接入

| 日期 | 任务 | 负责人 | 产出 |
|------|------|:----:|------|
| 6/16 | 在 Sentry 创建项目 + 获取 DSN | QA | Sentry DSN |
| 6/16-17 | iOS Firebase Crashlytics 接入（SDK + plist + 初始化） | iOS 开发 | PR → staging 验证 |
| 6/16-17 | Web Sentry 接入（SDK + Error Boundary） | 前端开发 | PR → staging 验证 |
| 6/17-18 | 微信 we分析 RealtimeLogManager + error-reporter.js | WeChat 开发 | PR → 体验版验证 |
| 6/18 | iOS dSYM 自动上传配置 + CI 验证 | iOS 开发 + QA | CI 通过 |
| 6/19 | Firebase Console + Sentry 告警规则配置 | QA | 告警就绪 |
| 6/20 | 全平台监控验证（触发测试错误 → 确认各通道收到） | QA | 验证报告 |

### Sprint 4 Week 2-3：完善 + 后端

| 周 | 任务 |
|----|------|
| Week 2 | RF-1041 后端压力测试 + 后端 Sentry 接入 |
| Week 3 | RF-1042 全平台端到端回归测试 |

---

## 九、附录

### A. 相关文件清单

| 文件 | 用途 |
|------|------|
| `ios/fastlane/metadata/en-US/app_privacy_details.json` | iOS 隐私声明（含 Crashlytics 预声明） |
| `android/fastlane/metadata/android/en-US/data_safety.txt` | Android 数据安全声明 |
| `android/app/src/main/java/com/runformcoach/runformcoachai/analytics/AnalyticsHelper.kt` | Android 监控封装 |
| `android/app/src/main/java/com/runformcoach/runformcoachai/StartupOptimizer.kt` | Android 启动优化 + Firebase 初始化 |
| `wechat/utils/cloudbase.js` | 微信云开发 + traceUser |
| `.github/workflows/ios-test.yml` | iOS CI |
| `.github/workflows/android-test.yml` | Android CI |
| `.github/workflows/backend-test.yml` | Backend CI |
| `.github/workflows/website-test.yml` | Web CI |
| `onboarding/qa-release-engineer.md` | QA 入职文档 + Bug 工作流 |
| `onboarding/sprint-1-test-plan.md` | Sprint 1 测试计划 |

### B. Firebase 项目配置参考

```
Project Name: runform-coach-ai
Platforms: iOS + Android
Services:
  - Crashlytics (iOS + Android)
  - Analytics (iOS + Android)
```

### C. Sentry 项目配置参考

```
Organization: runform
Projects:
  - movenova-ai-web (Next.js)
  - runform-backend (Python/FastAPI — Sprint 4 Week 2)
```

---

> **下一步**：将本文件提交 PR → CEO 审阅 → 拆解为 RF-1040 子工单 → 分配给各端开发在 Sprint 4 Week 1 执行。
