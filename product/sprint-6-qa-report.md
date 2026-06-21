# Sprint 6 QA 报告 — 全平台挑战赛质量验证

**验证日期**: 2026-06-21  
**审查范围**: Sprint 6 全部 13 个已完成任务  
**代码仓库**:
- `runform-coach-ai` → commit `1ef660a` (staging)
- `movenova.ai` → commit `d80ce1f` (master)

**总结**: 后端挑战赛核心 API 全部通过测试 (16/16)。iOS/Android 客户端实现良好。但 **Web 端存在 2 个阻塞级 Bug**（API 路径和 Challenge ID 错误），实际上线后挑战赛功能将完全不可用。WeChat 端实现正确。

---

## 测试结果总览

| 平台 | 测试方式 | 结果 | 关键发现 |
|------|---------|------|---------|
| **Web Build** | `npm run build` | ✅ PASS | 构建成功，无 lint 错误 |
| **Backend** | `pytest` 66 测试 | ⚠️ 39/66 PASS | Sprint 6 测试 16/16 全过；sessions/coach 预存问题 |
| **iOS** | 静态代码审查 | ⚠️ PASS (1 Bug) | SwiftUI 架构良好，`selectedChallenge` 初始化缺失 |
| **Android** | 静态代码审查 | ✅ PASS | Compose + Hilt 架构良好，API 字段对齐 |
| **WeChat** | `node --check` | ✅ PASS | 语法检查通过，API 路径正确 |
| **跨平台 API** | 字段对齐审计 | ❌ 2 CRITICAL | Web API 路径错误 + Challenge ID 不匹配 |

---

## 🔴 Critical (阻塞级)

### C1: Web check-in API 路径错误 — 永远 404

**文件**: `movenova.ai/src/app/[locale]/app/challenge/page.tsx`  
**行号**: 173  
**严重度**: 🔴 Critical

```typescript
// 当前代码 (错误):
`/api/v1/challenges/${encodeURIComponent(CHALLENGE_ID)}/checkin`

// 后端实际路径 (主代码 main.py:2134):
`/api/v1/challenges/{challenge_id}/check-in`    // 注意: check-in 带连字符
```

**影响**: Web 端打卡功能完全不可用。每次 check-in 请求都会收到 404，不会降级到 demo 模式（因为 `doCheckIn` 没有 fail 状态的 demo 降级）。

**修复建议**:
```typescript
// page.tsx line 173: 将 "checkin" 改为 "check-in"
`/api/v1/challenges/${encodeURIComponent(CHALLENGE_ID)}/check-in`
```

**对比验证**: iOS (`APIClient.swift:432`) 和 Android (`ApiClient.kt:82`) 均正确使用 `check-in`。WeChat (`api.js:255`) 也正确使用 `check-in`。

---

### C2: Web Challenge ID 与后端不匹配 — 永远 404

**文件**: `movenova.ai/src/app/[locale]/app/challenge/page.tsx`  
**行号**: 103  
**严重度**: 🔴 Critical

```typescript
// 当前代码 (错误):
const CHALLENGE_ID = "pain-free-5k";

// 后端唯一挑战赛 ID (db_models.py:181):
_FOURTEEN_DAY_CHALLENGE_ID = "14-day-form-challenge"
```

**影响**: 所有 Web 端挑战赛 API 请求（列表、加入、排行榜、打卡）均返回 404。用户只能看到 demo/fallback 数据。`joinChallenge()` 调用会将 `CHALLENGE_ID` 硬编码为 `"pain-free-5k"`，但后端没有该 ID。

**修复建议**:
1. 短期: 将 `CHALLENGE_ID` 改为 `"14-day-form-challenge"`
2. 长期: 从 `GET /api/v1/challenges` 动态获取第一个活跃挑战的 ID（iOS/Android 均这样实现）

---

## 🟠 Bug (功能缺陷)

### B1: Web join/check-in 接口缺少 X-API-Key 认证头

**文件**: `movenova.ai/src/app/[locale]/app/challenge/page.tsx`  
**行号**: 157 (joinChallenge), 173 (doCheckIn)  
**严重度**: 🟠 Bug

```typescript
// 当前代码: 不传 X-API-Key
return apiRequest<ChallengeStatus>(
    `/api/v1/challenges/.../join`, { method: "POST", token, body }
);
```

后端 `join_challenge` 和 `challenge_check_in` 均要求 `X-API-Key`:
```python
def join_challenge(..., _api_key: str = Depends(verify_api_key))
def challenge_check_in(..., _api_key: str = Depends(verify_api_key))
```

**影响**: 即使修复 C1/C2，join 和 check-in 仍会因缺少 API Key 被拒绝（403）。iOS/Android 正确传递 `X-API-Key: runform-coach-ai-2025-secure-key`。

**修复建议**: 在 `apiRequest` 调用中添加 `X-API-Key` 头，或通过 `insights/route.ts` 模式统一注入。

---

### B2: Web CheckInResponse 类型与后端 schema 不匹配

**文件**: `movenova.ai/src/app/[locale]/app/challenge/page.tsx`  
**行号**: 162-167  
**严重度**: 🟠 Bug

```typescript
// Web 期望的类型:
interface CheckInResponse {
    checked_in: boolean;      // ❌ 后端返回: status: "ok"
    days_completed: number;   // ❌ 后端返回: check_in_count
    today_task?: string;      // ❌ 后端不返回此字段
    message?: string;         // ❌ 后端不返回此字段
}

// 后端实际 schema (schemas.py:559-563):
class ChallengeCheckInResponse(BaseModel):
    status: str              // "ok"
    check_in_count: int
    streak_days: int
    today_metrics: dict      // { cadence, vertical_oscillation, gct, score }
```

**影响**: `handleCheckIn` 中 `result.checked_in` 始终为 `undefined`（falsy），check-in 成功状态永不会正确显示。

**修复建议**: 对齐接口类型:
```typescript
interface CheckInResponse {
    status: string;
    check_in_count: number;
    streak_days: number;
    today_metrics?: {
        cadence?: number;
        vertical_oscillation?: number;
        gct?: number;
        score?: number;
    };
}
```

---

### B3: iOS AppStore 未在 fetchChallenges 时设置 selectedChallenge

**文件**: `ios/RunFormCoachAI/AppStore.swift`  
**行号**: 239-248  
**严重度**: 🟠 Bug

```swift
func fetchChallenges() async {
    isFetchingChallenges = true
    challengeError = nil
    do {
        challenges = try await APIClient.shared.fetchChallenges(iosUserID: appUserID)
        // ❌ 缺少: 自动选中第一个 active 挑战赛
    } catch { ... }
    isFetchingChallenges = false
}
```

对比 Android (`ChallengeViewModel.kt:88`):
```kotlin
activeChallenge = challenges.firstOrNull { it.status == "active" }
if (activeChallenge != null) { loadLeaderboard(activeChallenge!!.id) }
```

**影响**: `ChallengeDetailView` 中的 `challenge.joined == true` 判断后 `selectedChallenge` 可能为 nil，导致 join 后 `onChange` 回调不会触发 UI 更新。

**修复建议**: 在 `fetchChallenges()` 末尾添加:
```swift
if let firstActive = challenges.first(where: { $0.isActive }) {
    selectedChallenge = firstActive
}
```

---

### B4: Android AlreadyCheckedIn UI 状态从未展示

**文件**: `android/.../ChallengeScreen.kt`  
**行号**: 171-178  
**严重度**: 🟠 Bug

```kotlin
// 第 171-178 行:
LaunchedEffect(checkInState) {
    when (val state = checkInState) {
        is ChallengeCheckInState.CheckedIn -> {
            viewModel.resetCheckInState()  // 立即重置
        }
        is ChallengeCheckInState.AlreadyCheckedIn -> {
            viewModel.resetCheckInState()  // 立即重置！用户看不到提示
        }
        else -> {}
    }
}
```

**影响**: 当用户同一天再次尝试打卡时，ViewModel 正确返回 `AlreadyCheckedIn` 状态，但 `LaunchedEffect` 立即将其重置为 `Idle`。用户看不到"已打卡"提示。

**修复建议**: 使用 `SnackbarHostState` 显示 Toast，或延迟 2-3 秒再重置状态。

---

## 🟡 Minor (建议修复)

### M1: iOS withRetry 对 4xx 错误进行不必要的重试

**文件**: `ios/RunFormCoachAI/APIClient.swift`  
**行号**: 51-68  
**严重度**: 🟡 Minor

`withRetry` 只排除 `CancellationError` 和 `ConfigurationError`，但对 join 返回的 400/409、check-in 返回的 400/409 等业务错误也会重试 3 次。

**修复建议**: 当 HTTP 状态码为 4xx 时不重试，或添加一个 `shouldRetry` 参数。

---

### M2: Android todayMetrics 使用无类型 Map

**文件**: `android/.../ChallengeModels.kt`  
**行号**: 74  
**严重度**: 🟡 Minor

```kotlin
@SerializedName("today_metrics") val todayMetrics: Map<String, Any> = emptyMap()
```

iOS 正确定义了 `ChallengeTodayMetrics` 结构体：
```swift
struct ChallengeTodayMetrics: Codable {
    let cadence: Double?
    let verticalOscillation: Double?
    let gct: Double?
    let score: Double?
}
```

**修复建议**: 定义 `data class ChallengeTodayMetrics` 并使用具体类型。

---

### M3: WeChat leaderboard 使用 index 作为 wx:key

**文件**: `wechat/pages/challenge/challenge.wxml`  
**行号**: 103  
**严重度**: 🟡 Minor

```xml
<view wx:for="{{leaderboard}}" wx:key="index">
```

当列表重新排序时（如打卡后更新排名），使用 index 会导致渲染错误。

**修复建议**: 使用唯一标识符:
```xml
wx:key="name"  <!-- 或 ios_user_id -->
```

---

### M4: WeChat challenge.js 存在冗余的 today_completed 判断

**文件**: `wechat/pages/challenge/challenge.js`  
**行号**: 92-93  
**严重度**: 🟡 Minor

```javascript
joined = first.joined || false
completedDays = first.completed_days || first.completedDays || 0
todayCompleted = first.today_completed || first.todayCompleted || false
```

后端返回的字段是 `completed_days` 和 `today_completed`（snake_case），JS 中 `first.completedDays` 和 `first.todayCompleted` 永远为 `undefined`。虽然后面的 `||` 会回退到正确的 snake_case 字段，但代码可读性差。

**修复建议**: 统一使用 snake_case 字段名：
```javascript
completedDays = first.completed_days || 0
todayCompleted = first.today_completed || false
```

---

## ✅ 验证通过项

### Web Build
- `npm run build` 成功完成（exit 0），输出产物在 `.vercel/output/`
- 所有路由正确生成: challenge, insights, compare, plan 页面均已构建
- CSP headers 安全脚本成功合并到 `_headers`
- 无 TypeScript 类型错误

### Backend pytest
- Sprint 6 挑战赛相关测试 **16/16 全部通过**:
  - `test_challenge_club.py`: 10/10 (check-in + club leaderboard)
  - `test_challenge_list_leaderboard.py`: 6/6 (list + leaderboard)
- 预存失败（非 Sprint 6 变更引入）:
  - `test_sessions.py`: 16 失败（sessions API 重构未完成）
  - `test_coach.py`: 11 ERROR（conftest fixture 问题）

### iOS 静态审查
- ✅ `ChallengeModels.swift` (146行): Codable 字段与后端 schema 完全对齐
- ✅ `ChallengeListView.swift`: 正确使用 `@EnvironmentObject AppStore`, NavigationStack
- ✅ `ChallengeDetailView.swift`: join/check-in 流程完整，状态管理合理
- ✅ `ChallengeLeaderboardView.swift`: displayName 优先级正确 (displayName → name → nickname)
- ✅ `APIClient.swift` (657行): 挑战赛 API 方法全部正确（路径、认证、参数）
- ✅ `ContentView.swift`: TabView 正确集成 `ChallengeListView()`

### Android 静态审查
- ✅ `ChallengeModels.kt` (107行): Gson SerializedName 与后端 snake_case 对齐
- ✅ `ChallengeViewModel.kt`: StateFlow 管理良好，Hilt DI 集成正确
- ✅ `ChallengeScreen.kt` (803行): Compose UI 完整实现 progress tab + leaderboard tab
- ✅ `ApiClient.kt`: Retrofit 接口定义与后端 API 路径完全对齐
- ✅ `MainActivity.kt`: Tab 栏正确集成 `ChallengeScreen()`

### WeChat 审查
- ✅ `node --check`: challenge.js, plan.js, i18n.js 均通过语法检查
- ✅ API 路径正确: `checkInChallenge` → `/api/v1/challenges/{id}/check-in` (正确带连字符)
- ✅ i18n 覆盖完整: challenge 全部 18 个 key 在 zh/en 中均有定义

---

## 跨平台 API 字段对齐审计

### ChallengeInfo 字段对比

| 字段 | 后端 | iOS | Android | WeChat | Web |
|------|------|-----|---------|--------|-----|
| `id` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `name` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `description` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `start_date` | ✅ | ✅ | ✅ | - | - |
| `end_date` | ✅ | ✅ | ✅ | - | - |
| `days` | ✅ | ✅ | ✅ | ✅ | - |
| `participant_count` | ✅ | ✅ | ✅ | - | - |
| `status` | ✅ | ✅ | ✅ | - | - |
| `joined` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `completed_days` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `today_completed` | ✅ | ✅ | ✅ | ✅ | - |

### ChallengeLeaderboardEntry 字段对比

| 字段 | 后端 | iOS | Android | WeChat | Web |
|------|------|-----|---------|--------|-----|
| `ios_user_id` | ✅ | ✅ | ✅ | - | ✅ |
| `cadence_improvement_pct` | ✅ | ✅ | ✅ | - | ✅ |
| `oscillation_improvement_pct` | ✅ | ✅ | ✅ | - | - |
| `overall_score_change` | ✅ | ✅ | ✅ | - | ✅ |
| `rank` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `display_name` | ✅ | ✅ | ✅ | ✅ | - |
| `name` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `nickname` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `days` | ✅ | ❌ 缺失 | ✅ | ✅ | - |
| `completed_days` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `is_me` | ✅ | ✅ | ✅ | ✅ | ✅ |

> **注意**: iOS `ChallengeLeaderboardEntry` 的 `days` 字段虽在 CodingKeys 中定义，但自定义 `init(from decoder:)` 中 fallback 为 0。与后端完全对齐。

### ChallengeCheckIn 字段对比

| 字段 | 后端 | iOS | Android | WeChat | Web |
|------|------|-----|---------|--------|-----|
| `status` | ✅ | ✅ | ✅ | - | ❌ |
| `check_in_count` | ✅ | ✅ | ✅ | - | ❌ |
| `streak_days` | ✅ | ✅ | ✅ | - | ❌ |
| `today_metrics` | ✅ | ✅ | ✅ | - | ❌ |
| `checked_in` | ❌ 不存在 | - | - | - | ❌ 不存在 |
| `days_completed` | ❌ 不存在 | - | - | - | ❌ 不存在 |

> **关键**: Web 端 CheckInResponse 类型与后端完全不同，详见 **B2**。

---

## 修复优先级

| 优先级 | ID | 问题 | 平台 | 预计工时 |
|--------|----|------|------|---------|
| 🔴 P0 | C1 | Web check-in API 路径 `checkin`→`check-in` | Web | 10 min |
| 🔴 P0 | C2 | Web Challenge ID `pain-free-5k`→`14-day-form-challenge` | Web | 30 min |
| 🟠 P1 | B1 | Web 缺少 X-API-Key 头 | Web | 20 min |
| 🟠 P1 | B2 | Web CheckInResponse 类型不匹配 | Web | 30 min |
| 🟠 P2 | B3 | iOS selectedChallenge 初始化缺失 | iOS | 20 min |
| 🟠 P2 | B4 | Android AlreadyCheckedIn UI 状态丢失 | Android | 15 min |
| 🟡 P3 | M1 | iOS withRetry 4xx 重试 | iOS | 15 min |
| 🟡 P3 | M2 | Android todayMetrics 无类型 | Android | 15 min |
| 🟡 P3 | M3 | WeChat wx:key="index" | WeChat | 5 min |
| 🟡 P3 | M4 | WeChat 冗余字段判断 | WeChat | 5 min |

**总预计修复工时**: ~2.5 小时

---

## 测试环境

- **OS**: WSL (Windows Subsystem for Linux)
- **Node.js**: 可用（Web build 成功）
- **Python**: 3.12.3 (venv at `backend/.venv/`)
- **Playwright**: 未执行（无 dev server / 无法访问生产 API）
- **Xcode/Android SDK**: 不可用（静态审查替代）

---

*报告由 Hermes Agent 自动生成 · 2026-06-21*
