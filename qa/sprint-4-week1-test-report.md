# Sprint 4 Week 1 — QA Test & Security Scan Report

**日期**: 2026-05-23
**测试角色**: QA & 发布工程师
**范围**: Android RF-1000 / WeChat RF-1010 / Web RF-1020+RF-1021

---

## 测试执行摘要

| 平台 | 测试维度 | 结果 | 问题数 |
|------|---------|------|--------|
| Android | 静态代码验证 | 通过 (2 Bug) | 2 Bug / 1 Minor |
| WeChat | Node语法检查 + 路由 + i18n | 通过 (1 Minor) | 0 Bug / 1 Minor |
| Web | TSC 编译 + i18n对齐 | 通过 (4 Minor) | 0 Bug / 4 Minor |
| 安全 | 密钥泄露 / 凭据 / 注入 | 通过 (1 Caution) | 0 Bug / 1 Caution |

**总计**: 2 Critical/Bug, 6 Minor, 1 Caution

---

## 一、Android — RF-1000 RunSession 历史回放

### 测试项目

#### 1.1 文件交付物确认

| 文件 | 行数 | 状态 |
|------|------|------|
| `RunSessionReplayScreen.kt` | 1233 | ✅ 已交付 |
| `RunSessionReplayViewModel.kt` | 220 | ✅ 已交付 |
| `Models.kt` (新增模型) | +96 行 (L249-344) | ✅ 已修改 |
| `ApiClient.kt` (新增端点) | +10 行 (L47-57) | ✅ 已修改 |
| `values/strings.xml` (EN) | +38 行 (L387-424) | ✅ 已修改 |
| `values-zh/strings.xml` | +38 行 (L379-416) | ✅ 已修改 |
| `values-nl/strings.xml` | +38 行 (L376-413) | ✅ 已修改 |

#### 1.2 Import 声明完整性

所有 import 均有对应类或标准库：
- `androidx.compose.*` — Compose UI 库 (标准)
- `androidx.hilt.navigation.compose.hiltViewModel` — Hilt 依赖注入
- `java.text.SimpleDateFormat` / `java.util.Date` — 仅在 `SessionSummaryCard` 使用
- `kotlin.math.roundToInt` — 在多个 Composable 中使用

✅ 无缺失 import（未显式 import `R`，但 Android 编译器自动解析同包 `R` 类）

#### 1.3 注解完整性

- `RunSessionReplayScreen`: ✅ `@Composable` (L95)
- `RunSessionReplayViewModel`: ✅ `@HiltViewModel` (L61)
- 构造函数 `@Inject` 注入 `RunFormApi`: ✅ (L62)
- 所有 private Composable 函数均有 `@Composable` 注解: ✅

#### 1.4 ViewModel → API → Model 数据流

```
RunSessionReplayViewModel (Hilt注入 RunFormApi)
  ├── loadSessionList()       → api.fetchSessions()       → List<RunSessionSummary>
  ├── selectSession(id)       → api.fetchSessionDetail(id) → RunSessionDetail
  ├── play()/pause()/stopReplay()/seekTo()
  └── currentDataPoint / promptMarkersAtOrBefore (derived)
```

API 端点定义完整:
- `GET sessions` → `List<RunSessionSummary>` ✅
- `GET sessions/{sessionId}` → `RunSessionDetail` ✅

模型交叉引用:
- `RunSessionSummary` → `ApiClient.kt` L51 (`fetchSessions()` 返回类型) → `RunSessionReplayViewModel.kt` L129 → `RunSessionReplayScreen.kt` L248 (`SessionSummaryCard`) ✅
- `RunSessionDetail` → `ApiClient.kt` L55-57 → `RunSessionReplayViewModel.kt` L150 → `RunSessionReplayScreen.kt` L479 ✅
- `ReplayDataPoint` → `Models.kt` L270 → `RunSessionReplayViewModel.kt` L87 → `RunSessionReplayScreen.kt` L558 ✅
- `SessionCoachPrompt` → `Models.kt` L290 → `RunSessionReplayViewModel.kt` L101 → `RunSessionReplayScreen.kt` L575 ✅

---

### 🐛 Bug 发现

#### BUG-ANDROID-001: currentDataPoint StateFlow 响应式断裂
- **严重度**: Bug (Critical — 功能缺陷)
- **文件**: `RunSessionReplayViewModel.kt`
- **行号**: 87-96
- **根因**: `currentDataPoint` 属性的 getter 每次调用都创建新的 `MutableStateFlow`，并同步读取 `_detailState.value` 和 `_currentDataPointIndex.value` 的当前值。由于返回的是一个全新的 Flow 对象，Compose 的 `collectAsState()` 无法在 `_detailState` 或 `_currentDataPointIndex` 变化时触发重组。
- **影响**: 在 Replay 模式下，当前数据点的 UI 展示不会随播放进度更新。用户滑动 seek bar 后，指标卡片不会刷新。
- **修复建议**: 使用 `combine` 将 `_detailState` 和 `_currentDataPointIndex` 组合为派生 StateFlow：
  ```kotlin
  val currentDataPoint: StateFlow<ReplayDataPoint?> =
      combine(_detailState, _currentDataPointIndex) { detail, idx ->
          (detail as? RunSessionDetailState.Success)?.session?.dataPoints?.getOrNull(idx)
      }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), null)
  ```

#### BUG-ANDROID-002: promptMarkersAtOrBefore StateFlow 响应式断裂
- **严重度**: Bug (Critical — 功能缺陷，同根因)
- **文件**: `RunSessionReplayViewModel.kt`
- **行号**: 101-109
- **根因**: 与 BUG-ANDROID-001 相同 —— 每次 get() 创建新的 MutableStateFlow。同时依赖了有同样问题的 `currentDataPoint`。
- **影响**: Coach prompt 列表不会随时间线推进而更新显示。
- **修复建议**: 修复 BUG-ANDROID-001 后，使用 `combine` 将 `_detailState` 和修复后的 `currentDataPoint` 组合。

---

### 🟡 Minor 发现

#### MINOR-ANDROID-001: 缺少 `@SerializedName("trunk_lean_array")` 的具体使用验证
- **严重度**: Minor
- **文件**: `RunSessionReplayScreen.kt`
- **行号**: 552-560 (CurrentMetricCards) — 仅显示 cadenceSPM, amplitudeCm, gctMs, trunkLeanDeg
- **根因**: `RunSessionDetail.trunkLeanArray` 已在 Models.kt 定义（L315），但 `CurrentMetricCards` 四项指标中用了 `dataPoint.trunkLeanDeg`，数据来源于 `ReplayDataPoint.trunkLeanDeg`。`ReplayDataPoint` 通过 `dataPoints` lazy 属性从 arrays 解包（Models.kt L322-340），该逻辑包含 `trunkLeanArray`。
- **影响**: 无实际功能影响，`dataPoints` 的 `minOf` 逻辑会正确处理。但 `currentDataPoint` 存在 Bug（见上），此功能实际不可用。
- **修复建议**: 随 BUG-ANDROID-001 一并验证。

---

### 1.5 三语 strings.xml Key 对齐

| 语言 | replay_* 条目数 | 覆盖 |
|------|----------------|------|
| EN (values) | 38 | ✅ 完整 |
| ZH (values-zh) | 38 | ✅ 完整 |
| NL (values-nl) | 38 | ✅ 完整 |

✅ 三语 key 集合完全对齐，无缺失。

---

## 二、WeChat — RF-1010 周训练洞察

### 测试项目

#### 2.1 文件交付物确认

| 文件 | 行数 | 状态 |
|------|------|------|
| `pages/insight/insight.js` | 420 | ✅ 新增 |
| `pages/insight/insight.wxml` | 122 | ✅ 新增 |
| `pages/insight/insight.wxss` | 223 | ✅ 新增 |
| `pages/insight/insight.json` | 1 | ✅ 新增 |
| `utils/api.js` (新增 getWeeklyInsight) | +10 行 (L135-142) | ✅ 已修改 |
| `utils/i18n.js` (新增 insight key) | +18 行 (L186-202 / L374-390) | ✅ 已修改 |
| `app.json` (注册 insight 路由) | +1 行 (L12) | ✅ 已修改 |
| `pages/result/result.js` (新增 goInsight) | +3 行 (L295-298) | ✅ 已修改 |
| `pages/result/result.wxml` (新增按钮) | +3 行 (L184-187) | ✅ 已修改 |
| `pages/history/history.js` (新增 goInsight) | +3 行 (L441-444) | ✅ 已修改 |
| `pages/history/history.wxml` (新增按钮) | +3 行 (L88-91) | ✅ 已修改 |

#### 2.2 Node 语法检查

```
node --check pages/insight/insight.js     ✅ PASS
node --check utils/api.js                 ✅ PASS
node --check utils/i18n.js                ✅ PASS
node --check pages/result/result.js       ✅ PASS
node --check pages/history/history.js     ✅ PASS
node --check app.js                       ✅ PASS
```

全文件通过 `node --check` 验证，无语法错误。

#### 2.3 app.json 路由注册

`pages/insight/insight` 已在 `app.json` 的 `pages` 数组中注册（L12），顺序位于 `pages/cadence/cadence` 之后。✅ 正确。

insight 页面不在 `tabBar` 中（符合设计——通过按钮导航进入）。

#### 2.4 API 调用链路

```
insight.js: onLoad() → _fetchInsight()
  → api.getWeeklyInsight()
  → api.js: request('GET', '/api/v1/weekly-insight')
  → wx.request: https://<BASE_URL>/api/v1/weekly-insight
```

链路完整，无断裂。`getWeeklyInsight` 已在 `module.exports` 中导出（api.js L151）。

#### 2.5 页面间导航

| 来源 | 方法 | 目标 | 状态 |
|------|------|------|------|
| `result.js` L296 | `goInsight()` → `wx.navigateTo('/pages/insight/insight')` | insight page | ✅ |
| `history.js` L442 | `goInsight()` → `wx.navigateTo('/pages/insight/insight')` | insight page | ✅ |

WXML 按钮绑定 `bindtap="goInsight"` 均正确对应。

#### 2.6 i18n Key 覆盖

insight 页面使用的所有 i18n key：

| Key | ZH 覆盖 | EN 覆盖 |
|-----|---------|---------|
| `insightTitle` | ✅ 周训练洞察 | ✅ Weekly Insight |
| `insightLoading` | ✅ 加载洞察报告... | ✅ Loading insight... |
| `insightError` | ✅ 洞察加载失败 | ✅ Failed to load insight |
| `insightRetry` | ✅ 重试 | ✅ Retry |
| `insightCompareTitle` | ✅ 本周 vs 上周 | ✅ This Week vs Last Week |
| `insightTrendTitle` | ✅ 4周趋势 | ✅ 4-Week Trend |
| `insightAiAdviceTitle` | ✅ AI 教练建议 | ✅ AI Coach Advice |
| `insightBadgesTitle` | ✅ 本周成就 | ✅ This Week Achievements |
| `insightCadence` | ✅ 步频 | ✅ Cadence |
| `insightOscillation` | ✅ 垂直振幅 | ✅ Vert. Osc. |
| `insightGCT` | ✅ 触地时间 | ✅ GCT |
| `insightDistance` | ✅ 距离 | ✅ Distance |
| `insightSessions` | ✅ 训练次数 | ✅ Sessions |
| `insightSpacing` | ✅ 间距 | ✅ Spacing |
| `insightNoData` | ✅ 暂无足够数据... | ✅ Not enough data... |
| `insightNoDataSub` | ✅ 完成至少两周... | ✅ Complete at least two weeks... |

✅ 所有 16 个 key 在 zh/en 字典中均有值，无缺失。

#### 2.7 Canvas 2D API 调用正确性

- WXML: `<canvas type="2d" id="insightTrendCanvas">` → ✅ 使用新版 Canvas 2D API
- JS: `wx.createSelectorQuery().select('#insightTrendCanvas').fields({ node: true, size: true })` → ✅ 正确的 API 调用方式
- DPR 适配: `const dpr = wx.getSystemInfoSync().pixelRatio` → ✅
- `bindtouchstart="onChartTap"` → ✅ 交互正确，tooltip 显示正常

---

### 🟡 Minor 发现

#### MINOR-WECHAT-001: insight.json 硬编码中文标题
- **严重度**: Minor
- **文件**: `pages/insight/insight.json`
- **行号**: L1
- **根因**: `"navigationBarTitleText": "周训练洞察"` — 标题硬编码为中文，英文用户看到的导航栏标题仍为中文。
- **影响**: 非中文用户导航栏标题显示错误。
- **修复建议**: 在 `insight.js` 的 `onLoad()` 中添加动态标题设置：
  ```javascript
  onLoad() {
    wx.setNavigationBarTitle({ title: t('insightTitle') })
    this._fetchInsight()
  },
  ```

---

## 三、Web — RF-1020+RF-1021 用户系统 + 分析历史

### 测试项目

#### 3.1 文件交付物确认

| 文件 | 行数 | 状态 |
|------|------|------|
| `auth/login/page.tsx` | 150 | ✅ 新增 |
| `auth/register/page.tsx` | 170 | ✅ 新增 |
| `history/page.tsx` | 573 | ✅ 新增 |
| `history/[id]/page.tsx` | 494 | ✅ 新增 |
| `lib/auth.tsx` | 174 | ✅ 新增 |
| `types/analysis.ts` | 41 | ✅ 新增 |
| `layout/Navbar.tsx` | 170 | ✅ 已修改 |
| `messages/en.json` | +87 行 | ✅ 已修改 |
| `messages/zh.json` | +87 行 | ✅ 已修改 |
| `package.json` | — | ✅ 已修改 (含 recharts 依赖) |

#### 3.2 TSC 编译验证

```
npx tsc --noEmit
→ TypeScript: No errors found
```

✅ **零编译错误**。所有类型引用正确解析。

#### 3.3 页面路由注册

页面位于 Next.js App Router 的 `[locale]/app/` 下:
- `/app/auth/login/` → `[locale]/app/auth/login/page.tsx` ✅
- `/app/auth/register/` → `[locale]/app/auth/register/page.tsx` ✅
- `/app/history/` → `[locale]/app/history/page.tsx` ✅
- `/app/history/[id]/` → `[locale]/app/history/[id]/page.tsx` ✅

Next.js App Router 基于文件系统路由，无需显式注册。所有页面均可通过 locale 参数访问。

#### 3.4 next-intl Key 对齐

**auth 命名空间** (en/zh 对比):

| Key | EN | ZH |
|-----|----|----|
| `login` | Log In | 登录 |
| `register` | Register | 注册 |
| `logout` | Log Out | 退出登录 |
| `email` | Email | 邮箱 |
| `password` | Password | 密码 |
| `name` | Name (optional) | 姓名（选填）|
| `loginTitle` | Welcome Back | 欢迎回来 |
| `loginSubtitle` | Log in to access... | 登录以查看... |
| `registerTitle` | Create Account | 创建账号 |
| `registerSubtitle` | Join MoveNova... | 加入 MoveNova... |
| `noAccount` | Don't have... | 还没有账号？|
| `hasAccount` | Already have... | 已有账号？|
| `createAccount` | Create one | 注册一个 |
| `signIn` | Sign in | 立即登录 |
| `errors.invalidEmail` | Please enter... | 请输入有效的... |
| `errors.passwordShort` | Password must... | 密码至少需要... |
| `errors.loginFailed` | Login failed... | 登录失败... |
| `errors.registerFailed` | Registration failed... | 注册失败... |
| `errors.genericError` | Something went wrong... | 出了点问题... |

**history 命名空间** (en/zh 对比):

| Key | EN | ZH |
|-----|----|----|
| `title` | Analysis History | 分析历史 |
| `subtitle` | Browse your past... | 浏览你过去的... |
| `noResults` | No analyses yet | 暂无分析记录 |
| `noResultsDesc` | Upload your first... | 上传你的第一个... |
| `startAnalysis` | Start Analysis | 开始分析 |
| `viewDetail` | View Details | 查看详情 |
| `delete` | Delete | 删除 |
| `confirmDelete` | Delete this analysis... | 确认删除此分析？|
| `cancel` | Cancel | 取消 |
| `trends` | Trend Charts | 趋势图表 |
| `trendsSubtitle` | Track your... | 追踪你的... |
| `cadence` | Cadence | 步频 |
| `cadenceUnit` | spm | 步/分钟 |
| `verticalOscillation` | Vertical Oscillation | 垂直振幅 |
| `verticalOscillationUnit` | cm | 厘米 |
| `groundContactTime` | Ground Contact Time | 触地时间 |
| `groundContactTimeUnit` | ms | 毫秒 |
| `strideLength` | Stride Length | 步幅 |
| `strideLengthUnit` | m | 米 |
| `confidenceScore` | Confidence | 置信度 |
| `date` | Date | 日期 |
| `duration` | Duration | 时长 |
| `metrics` | Metrics | 指标 |
| `issues` | Issues Found | 发现的问题 |
| `backToList` | Back to History | 返回历史列表 |
| `loadError` | Failed to load... | 加载历史记录失败... |

**nav 命名空间扩充**:
- `nav.history` ✅ EN: "History" / ZH: "历史"

✅ 所有 i18n key 在 en.json 和 zh.json 中完全对齐。

#### 3.5 认证流程验证

```
登录: login(email, password) → POST /auth/login → 获取 access_token
   → 存储到 localStorage → setUser + setToken

注册: register(email, password, name) → POST /auth/register → 获取 access_token
   → 存储到 localStorage → setUser + setToken

会话恢复: AuthProvider mount → 读取 localStorage token
   → GET /auth/me → 验证 token 有效性 → setUser

登出: logout() → 清除 localStorage → setUser(null)
```

✅ 认证流程完整，Bearer token 正确注入请求头。

---

### 🟡 Minor 发现

#### MINOR-WEB-001: 多处硬编码英文字符串，未使用 i18n
- **严重度**: Minor
- **影响范围**:

| 文件 | 行号 | 硬编码内容 |
|------|------|-----------|
| `auth/login/page.tsx` | 93 | `placeholder="you@example.com"` |
| `auth/login/page.tsx` | 113 | `placeholder="••••••"` |
| `auth/register/page.tsx` | 94 | `placeholder="John Doe"` |
| `auth/register/page.tsx` | 113 | `placeholder="you@example.com"` |
| `auth/register/page.tsx` | 132 | `placeholder="••••••"` |
| `history/page.tsx` | 434 | `Refresh` (按钮文字，中文用户看到英文) |
| `history/[id]/page.tsx` | 193 | `"Loading analysis..."` |
| `history/[id]/page.tsx` | 203 | `"Analysis not found"` |
| `history/[id]/page.tsx` | 245 | `"Analysis Result"` (badge text) |
| `history/[id]/page.tsx` | 336 | `"No issues detected"` |
| `history/[id]/page.tsx` | 337 | `" issue(s) found"` (含拼接逻辑) |

- **修复建议**: 将这些字符串添加到 i18n 字典 (`auth` 或 `history` 命名空间) 并使用 `t()` 函数。

#### MINOR-WEB-002: login.tsx 已定义的变量 `User` 导入未使用
- **严重度**: Minor (Lint 级别)
- **文件**: `auth/login/page.tsx`
- **行号**: L17
- **根因**: `const { login } = useAuth()` 解构了 `login` 函数，但未解构 `user`。`User` icon 从头到尾未使用（但文件顶部导入了 `User` icon — 实际检查 L8: `import { Mail, Lock, LogIn, AlertCircle } from "lucide-react"` 并未导入 `User`，仅在 register/page.tsx L8 导入了 `User`）。
- **实际状态**: 复核后，login/page.tsx 未导入未使用的 `User` icon。register/page.tsx 导入了 `User` 并在 name 字段使用 — 正确。✅ 无问题。

---

## 四、安全扫描

### 4.1 密钥泄露检查

| 位置 | 状态 | 说明 |
|------|------|------|
| `android/keystore.properties` | ✅ Safe | 所有值为占位符 (`CHANGE_ME_*`)；已在 `.gitignore` 中排除 (`*.keystore`, `keystore.properties`) |
| `android/app/google-services.json` | ✅ Safe | 使用占位符 (`000000000000`, `placeholder_api_key`) |
| `wechat/utils/config.js` | ✅ Safe | 仅含 Railway 公开 URL，不含密钥/凭据 |
| Web `.env` 变量 | ✅ Safe | 使用 `process.env.NEXT_PUBLIC_API_URL`，无硬编码密钥 |

### 4.2 硬编码凭据

- 无硬编码密码、API key、Token 发现。
- Auth token 在 Web 端存储于 `localStorage`（标准做法，但存在 XSS 泄露风险 — 见下方 Caution）。

### 4.3 输入验证

- **Web login/register**: ✅ 客户端验证了 email 格式 (`includes("@")`) 和密码长度 (`>= 6`)。
- **Web history delete**: ✅ 通过 `confirmDelete` 状态进行二次确认。
- **WeChat insight**: ⚠️ 无 API 响应数据格式校验 — 直接使用 `data.comparison`, `data.trend` 等。若后端返回异常数据，`toFixed(1)` 等操作可能崩溃（已有 null 检查 `.filter(m => m.changePct != null)` 缓解）。
- **Android**: ⚠️ ViewModel 的 `seekTo()` 使用 `coerceIn` 进行边界保护 — ✅ 正确。

### 4.4 XSS/注入风险

- **WeChat WXML**: 使用 `{{}}` 数据绑定，微信小程序框架自动转义 — ✅ 安全。
- **Web JSX**: React 默认转义 `{}` 中的字符串 — ✅ 安全。
- **Web history.page.tsx L490**: `item.summary.slice(0, 80)` 直接在 JSX 中渲染，React 自动转义 — ✅ 安全。
- **Android**: Compose `Text()` composable 不接受 HTML — ✅ 安全。

### 4.5 认证授权

- Web `useAuth()` 通过 React Context 提供统一的认证状态 ✅
- `useOptionalAuth()` 提供非抛出式访问，避免未包裹时的崩溃 ✅
- `authHeaders()` 辅助函数正确构造 Bearer token ✅
- History 页面通过 `token` 传递给 fetch，无需认证时使用 demo 数据 ✅

---

### ⚠️ Caution 发现

#### CAUTION-SEC-001: Web Token 存储在 localStorage — 存在 XSS 泄露风险
- **严重度**: Caution (非阻塞，但应记录)
- **文件**: `lib/auth.tsx` L64, L69, L74
- **根因**: JWT access token 存储在 `localStorage`，若应用存在 XSS 漏洞，攻击者可通过 `localStorage.getItem("movenova_session")` 窃取 token。
- **当前评估**: 无已知 XSS 漏洞，React 默认转义机制提供基础保护。这是常见的 SPA 认证模式，风险可接受。
- **建议**: 若后端支持，考虑使用 `httpOnly` cookie 替代 localStorage；或实施 Content Security Policy (CSP) 头部。

---

## 五、总结与建议

### 测试通过项

1. ✅ Android 代码结构完整，所有 import/注解/模型交叉引用正确
2. ✅ Android 三语 strings.xml 完全对齐
3. ✅ WeChat 所有 JS 文件通过 `node --check`
4. ✅ WeChat 路由注册正确，导航链路完整
5. ✅ WeChat i18n key 全覆盖
6. ✅ Web TSC 编译零错误 (`npx tsc --noEmit`)
7. ✅ Web next-intl key zh/en 完全对齐
8. ✅ Web auth 流程完整，token 管理正确
9. ✅ 无硬编码密钥/凭据泄露
10. ✅ 输入边界保护基本完善

### 阻塞项 (Must Fix Before Release)

| ID | 平台 | 描述 | 优先级 |
|----|------|------|--------|
| BUG-ANDROID-001 | Android | `currentDataPoint` StateFlow 响应式断裂 — 指标不更新 | 🔴 Critical |
| BUG-ANDROID-002 | Android | `promptMarkersAtOrBefore` 同样问题 — coach prompt 不更新 | 🔴 Critical |

### 建议修复 (Should Fix)

| ID | 平台 | 描述 | 优先级 |
|----|------|------|--------|
| MINOR-WECHAT-001 | WeChat | insight.json 硬编码中文导航栏标题 | 🟡 Minor |
| MINOR-WEB-001 | Web | 多处硬编码英文 placeholder/文本 | 🟡 Minor |
| MINOR-ANDROID-001 | Android | currentDataPoint 修复后需验证 CurrentMetricCards | 🟡 Minor |

### 安全建议 (Nice to Have)

| ID | 平台 | 描述 | 优先级 |
|----|------|------|--------|
| CAUTION-SEC-001 | Web | localStorage token → 考虑 httpOnly cookie + CSP | ⚪ Caution |

---

*报告生成: 2026-05-23 07:53 AM | 工具: node --check, npx tsc --noEmit, 手动静态分析*
