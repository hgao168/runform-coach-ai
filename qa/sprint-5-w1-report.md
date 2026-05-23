# Sprint 5 QA 验证报告

**日期**: 2026-05-23  
**角色**: QA Release Engineer  
**覆盖范围**: 后端 API / WeChat 前端 / Web 前端  
**Sprint**: Sprint 5 — 邀请码系统 + 挑战赛平台 + 教练面板

---

## 执行摘要

Sprint 5 的核心后端逻辑基本完成，数据模型设计合理，测试覆盖了教练面板的主要场景。但**三线代码之间存在严重的 API 路由不匹配问题**，Web 前端和 WeChat 前端均无法与后端实际 API 正确对接。WeChat 前端整体停留在 mock/demo 阶段，缺少真实 API 集成。**建议阻塞上线，直至修复 Critical 问题**。

### 风险等级: 🔴 HIGH — 阻塞上线

---

## 一、发现的问题

### 🔴 Critical (阻塞上线)

#### C1. Web 前端 API 路由与后端不匹配

- **位置**: `src/app/[locale]/app/challenge/page.tsx` (lines 81, 92)
- **严重程度**: Critical
- **描述**:
  - Web 前端调用 `GET /api/v1/challenge/leaderboard?limit=50`（单数 `challenge`）
  - Web 前端调用 `POST /api/v1/challenge/join`（单数 `challenge`，无 path param）
  - 后端实际路由是 `GET /api/v1/challenges/{challenge_id}/leaderboard` 和 `POST /api/v1/challenges/{challenge_id}/join`（复数 `challenges`，需要 `challenge_id` path parameter）
  - 调用时也未传递 `challenge_id`（后端硬编码为 `14-day-form-challenge`）
- **影响**: Web 前端所有 API 调用将返回 404，挑战赛页面完全无法工作
- **建议修复**:
  - Web 端改为 `GET /api/v1/challenges/14-day-form-challenge/leaderboard?limit=50`
  - Web 端改为 `POST /api/v1/challenges/14-day-form-challenge/join` 并附带 `{ ios_user_id: ... }` body
  - 同时 web 端 `joinChallenge()` 函数未发送 body，需增加 `JSON.stringify({ ios_user_id })` 或从认证上下文获取

#### C2. WeChat 挑战赛页面无真实 API 集成

- **位置**: `wechat/pages/challenge/challenge.js` (lines 58-78, 85-94, 103-128, 131-178)
- **严重程度**: Critical
- **描述**:
  - `_loadChallengeData()` 仅从 `app.globalData.challenge` 读取本地 mock 数据，从未调用后端 API
  - `_getDemoLeaderboard()` 硬编码 10 个假用户名，无真实网络请求
  - `joinChallenge()` 只设置 `app.globalData.challenge = { joined: true, ... }`，不调用 `POST /api/v1/challenges/{challenge_id}/join`
  - `checkInToday()` 仅更新 `app.globalData.challenge.completedDays`，不调用后端 check-in 端点（该端点甚至在代码中也未标注 "POST /check-in"，后端实际未实现打卡 API）
- **影响**: 整个 WeChat 挑战赛功能是纯客户端的 mock，用户数据不持久化、不与其他用户同步
- **建议修复**:
  - 在 `utils/api.js` 中新增 `joinChallenge()`, `getLeaderboard()`, `checkIn()` API 函数
  - `challenge.js` 通过这些 API 函数与后端交互
  - 后端需补充 `POST /api/v1/challenges/{challenge_id}/check-in` 端点（当前缺失）

#### C3. WeChat 邀请码系统无后端集成

- **位置**: `wechat/pages/invite/invite.js` (lines 62-90)
- **严重程度**: Critical
- **描述**:
  - `_loadInviteData()` 从 `app.globalData.inviteData` 读取，若无则调用 `_generateInviteData()` 客户端随机生成 8 位邀请码
  - `_generateInviteData()` 用 `Math.random()` 生成代码，完全不调用 `POST /api/v1/invite/generate`
  - 已邀请列表、邀请计数等均来自本地 mock，不调用 `GET /api/v1/invite/{code}`
  - `copyInviteCode()` 仅复制到剪贴板，不涉及后端
- **影响**: 邀请码完全无服务端验证，用户无法真正邀请或被邀请
- **建议修复**: 在 `api.js` 中新增 `generateInvite()`, `verifyInvite()`, `redeemInvite()` 函数，`invite.js` 改用这些函数

#### C4. WeChat 跑团排行榜 API 端点不存在

- **位置**: `wechat/pages/club-leaderboard/club-leaderboard.js` (line 78)
- **严重程度**: Critical
- **描述**:
  - `_tryFetchFromAPI()` 请求 `GET /api/v1/clubs/${clubCode}/leaderboard`
  - 后端**不存在此端点**，无任何 clubs 相关路由
  - 页面始终降级到 `_getMockLeaderboard()` mock 数据并显示 "跑团功能即将开放"
- **影响**: 跑团排行榜功能完全不可用，始终显示 coming-soon 横幅
- **建议修复**: 后端实现 `GET /api/v1/clubs/{club_code}/leaderboard` 端点，或修改评估为 "此功能尚未实现"

#### C5. 后端缺少挑战赛打卡 (check-in) 端点

- **位置**: `backend/app/main.py` — 搜索 "check-in" 无匹配
- **严重程度**: Critical
- **描述**:
  - Sprint 5 交付清单中包含 `POST /check-in`
  - 实际后端代码中不存在 `/api/v1/challenges/{challenge_id}/check-in` 或任何 check-in 端点
  - WeChat 的 `checkInToday()` 只更新本地状态；Web 前端甚至没有打卡功能入口
- **影响**: 挑战赛的核心功能（每日打卡）无法使用
- **建议修复**: 实现 `POST /api/v1/challenges/{challenge_id}/check-in` 端点，将打卡记录持久化

---

### 🟠 Bug (影响功能正确性)

#### B1. 后端 leaderboard N+1 查询问题

- **位置**: `backend/app/main.py` lines 1152-1196
- **严重程度**: Bug (性能)
- **描述**:
  - `challenge_leaderboard()` 对每个 participant 循环执行:
    1. 查询 `RunSession` (line 1154-1162)
    2. 查询 `User` 获取 `ios_user_id` (line 1194)
  - 若有 100 个参与者，产生 200+ 次数据库查询
- **建议修复**: 使用 JOIN 或批量查询预加载所有 User 和 RunSession 数据

```python
# 一次性加载所有需要的 user 数据
user_ids = [p.user_id for p in participants]
users_map = {u.id: u.ios_user_id for u in session.execute(
    select(User).where(User.id.in_(user_ids))
).scalars().all()}

# 一次性加载所有参与者的 recent sessions
all_sessions = session.execute(
    select(RunSession).where(
        RunSession.user_id.in_(user_ids),
        RunSession.start_time >= min(p.joined_at for p in participants),
    ).order_by(RunSession.start_time.desc())
).scalars().all()
# 按 user_id 分组
```

#### B2. Web 前端 joinChallenge 缺少请求体

- **位置**: `src/app/[locale]/app/challenge/page.tsx` lines 90-100
- **严重程度**: Bug
- **描述**:
  ```typescript
  async function joinChallenge(token?: string | null): Promise<ChallengeStatus> {
    const headers = authHeaders(token);
    const res = await fetch(`${API_BASE}/api/v1/challenge/join`, {
      method: "POST",
      headers,        // ← 无 body!
    });
  ```
  - POST 请求无 body，后端 `ChallengeJoinRequest` 要求 `ios_user_id` (必填)
  - 即使修复路由，后端也会返回 422 Validation Error
- **建议修复**: 添加 body 或从后端认证 token 解析 `ios_user_id`

#### B3. coach_join 对同一教练重复加入的幂等性返回有歧义

- **位置**: `backend/app/main.py` lines 1356-1362
- **严重程度**: Bug (轻微)
- **描述**:
  - 已加入的学生再次使用同一 coach code 加入时，返回 `CoachJoinResponse(joined=True, ...)`
  - 但若学生已通过其他 coach code 与此教练关联（虽然业务上 student 只能与一个 coach_id 关联），返回的 message 是 "already connected"
  - 这是正确的，但若学生尝试用**不同** coach code 加入**同一**教练（绕过 code 限制），后端检查的是 `(coach_id, student_id)` 唯一约束而非 code 本身
- **影响**: 边界条件，影响不大
- **建议修复**: 可接受当前行为，但建议在文档中注明

#### B4. WeChat FONT 常量声明位置

- **位置**: `wechat/pages/challenge/challenge.js` line 281 (declared after Page())
- **严重程度**: Bug (代码异味)
- **描述**:
  - `const FONT` 在文件末尾 (line 281) 声明，但在 `_drawProgressRing()` (line 181+) 中使用
  - JS 中 `const` 不会被提升，但模块级代码是同步执行的：`Page({...})` 注册时不运行方法，当 `_drawProgressRing()` 被调用时模块已加载完毕
  - 当前运行正常，但代码组织混乱，容易在未来重构时出错
- **建议修复**: 将 `const FONT` 移到文件顶部（Page() 之前）

#### B5. invite.js Math.random() 导致海报非确定性

- **位置**: `wechat/pages/invite/invite.js` lines 169-176
- **严重程度**: Bug (轻微)
- **描述**: `_renderPosterOnCanvas()` 中用 `Math.random()` 绘制装饰点，每次生成的海报背景图案不同
- **影响**: 同一用户重复生成海报得到不同视觉效果，可能引起困惑
- **建议修复**: 使用确定性种子或移除随机装饰

---

### 🟡 Minor (可后续迭代修复)

#### M1. 后端 `/api/v1/invite/verify` vs 任务文档描述不一致

- **位置**: `backend/app/main.py` line 955
- **严重程度**: Minor
- **描述**: 任务描述为 `POST /api/v1/invite/verify`，实际实现为 `GET /api/v1/invite/{code}`。GET 语义上更合理（验证不产生副作用），但文档与实现不一致
- **建议**: 统一文档或添加 POST 别名

#### M2. coach_dashboard 中 overall_score 的双重 or 防护

- **位置**: `backend/app/main.py` line 1439
- **严重程度**: Minor
- **描述**:
  ```python
  ((latest_session.avg_cadence or 0) / 180.0 * 0.5)
  + ((0.12 / max((latest_session.avg_vertical_oscillation or 0.001), 0.001)) * 0.5)
  ```
  - 外部已有 `if latest_session.avg_cadence is not None and latest_session.avg_vertical_oscillation is not None` 保护
  - 内层的 `or 0` / `or 0.001` 是死代码，但无害
- **建议**: 移除冗余防护保持代码整洁

#### M3. OG 图片返回 SVG 格式兼容性问题

- **位置**: `src/app/api/og/challenge/route.tsx` line 117, `src/app/api/og/analyze/route.tsx` line 108
- **严重程度**: Minor
- **描述**:
  - OG 图片端点返回 `Content-Type: image/svg+xml`
  - Twitter/Facebook/LinkedIn 等平台的爬虫对 SVG OG 图片支持不统一
  - Twitter 明确要求 PNG/JPEG；部分平台会忽略 SVG
- **建议**: 使用 `@vercel/og` 或 Satori 生成 PNG，或标注当前为 V1 可接受 SVG

#### M4. 后端硬编码挑战赛日期

- **位置**: `backend/app/main.py` lines 1029-1030
- **严重程度**: Minor
- **描述**:
  ```python
  "start_date": "2026-05-18",
  "end_date": "2026-06-01",
  ```
  - 日期硬编码，过期后挑战赛自动变为 "ended"
  - 无 CRON 或管理接口刷新挑战赛
- **建议**: 将挑战赛配置移至数据库或环境变量

#### M5. WeChat api.js 缺少 Sprint 5 新 API 封装

- **位置**: `wechat/utils/api.js` (lines 144-152)
- **严重程度**: Minor
- **描述**: `api.js` 仅封装了 `analyzeVideo`, `generatePlan`, `fetchAthletes`, `compareWithAthlete`, `submitFeedback`, `health`, `getWeeklyInsight`
  - 缺少: `generateInviteCode`, `verifyInviteCode`, `redeemInviteCode`
  - 缺少: `joinChallenge`, `getChallengeLeaderboard`, `checkInChallenge`
  - 缺少: `generateCoachCode`, `joinCoach`, `getCoachStudents`, `getCoachDashboard`
- **建议**: 补齐所有 Sprint 5 API 封装函数

#### M6. Web 前端 useEffect 刷新逻辑限制

- **位置**: `src/app/[locale]/app/challenge/page.tsx` lines 399-405
- **严重程度**: Minor (UX)
- **描述**: `initialLoadDone` ref 阻止了 StrictMode 下的双重请求，但也阻止了认证状态变化后的数据刷新
- **建议**: 监听 `token` 变化并重新加载

#### M7. 后端 `_calculate_overall_score` 重复实现

- **位置**: `backend/app/main.py`:
  - `join_challenge` line 1111-1113
  - `challenge_leaderboard` line 1185-1187
  - `coach_dashboard` line 1437-1441
- **严重程度**: Minor (代码质量)
- **描述**: 跑姿综合评分公式在三个地方重复实现，未来修改容易遗漏
- **建议**: 抽提为模块级函数 `_calculate_overall_score(cadence, oscillation) -> float`

#### M8. Web share-card.ts 使用已弃用 API

- **位置**: `src/lib/share-card.ts` line 82
- **严重程度**: Minor
- **描述**: `document.execCommand("copy")` 已在现代浏览器中被标记为弃用
- **建议**: 保留 fallback 但添加 `@deprecated` 注释，在主路径 `navigator.clipboard.writeText()` 已覆盖绝大部分浏览器

---

## 二、测试覆盖分析

### 后端测试 (`tests/test_coach.py`)

| 测试场景 | 状态 | 备注 |
|---------|------|------|
| 生成教练码 | ✅ Pass | 验证 code 长度=8, student_limit=20, is_active=True |
| 生成超过5个码限流 | ✅ Pass | 第6次返回 429 |
| 学生加入教练成功 | ✅ Pass | 端到端: 生成码→加入→验证响应 |
| 无效码加入 | ✅ Pass | 返回 404 |
| 自我加入 | ✅ Pass | 返回 400 |
| 重复加入 | ✅ Pass | 返回 "already" message |
| 学生列表 | ✅ Pass | 返回 1 个学生 |
| 空学生列表 | ✅ Pass | 返回 [] |
| Dashboard | ✅ Pass | student_count=1, session_count=0 |
| Dashboard with sessions | ✅ Pass | 验证 cadence/osc/gct/overall_score |
| Case-insensitive code | ✅ Pass | 小写码可加入 |

**缺失的测试**:
- ❌ 无邀请码 (invite) 测试
- ❌ 无挑战赛 (challenge) 测试
- ❌ 无教练码学生上限测试

---

## 三、Alembic 迁移审查

| 迁移 | 表 | 状态 |
|------|---|------|
| `20260523_0004` | `invite_codes` | ✅ 索引正确 (code UNIQUE, creator_user_id, redeemed_by) |
| `20260523_0004` | `challenge_participants` | ✅ 唯一约束 `uq_challenge_user` |
| `20260523_0005` | `coach_codes` | ✅ 索引正确, server_default 正确 |
| `20260523_0005` | `coach_students` | ✅ 唯一约束 `uq_coach_student` |

无迁移问题发现。

---

## 四、整体风险评估

| 维度 | 评级 | 说明 |
|------|------|------|
| **后端逻辑正确性** | 🟢 Good | CRUD 逻辑完整，错误处理到位，测试覆盖教练面板 |
| **前后端协议一致性** | 🔴 Critical | Web/WeChat 前端 API 调用与后端路由多处不匹配 |
| **WeChat 集成完成度** | 🔴 Incomplete | 三个新页面均为 mock 数据，无真实 API 调用 |
| **Web 集成完成度** | 🔴 Incomplete | 路由不匹配 + 请求体缺失导致功能不可用 |
| **测试覆盖** | 🟡 Partial | 仅教练面板有测试，邀请码和挑战赛无测试 |
| **数据安全** | 🟢 Good | Pydantic 验证 + FK 约束 + 唯一约束到位 |

---

## 五、上线建议

### 🔴 阻塞上线 — 必须在合并前修复

1. **C1**: 对齐 Web 前端 API 路由至实际后端路由 (challenge → challenges, 添加 challenge_id)
2. **C2**: WeChat 挑战赛页接入真实 API
3. **C3**: WeChat 邀请码页接入真实 API
4. **C4**: 跑团排行榜 — 明确此功能是否属于当前交付范围（若是，实现后端端点；若否，在 WeChat 端移除 API 调用）
5. **C5**: 实现挑战赛打卡 API 端点

### 🟡 强烈建议修复（不影响核心流程但影响体验）

6. **B1**: 修复 leaderboard N+1 查询
7. **B2**: Web joinChallenge 添加请求体
8. **B5**: 移除海报随机装饰或使用种子

### 🟢 可后续迭代

9. M1–M8 各项优化

---

## 六、代码审查统计

| 文件 | 行数 | 问题数 | 严重问题 |
|------|------|--------|----------|
| backend/app/main.py | 1466 | 5 | 1 (C5) |
| backend/app/schemas.py | 570 | 0 | 0 |
| backend/app/db_models.py | 221 | 0 | 0 |
| backend/tests/test_coach.py | 256 | 0 | 0 |
| wechat/pages/invite/invite.js | 461 | 1 | 1 (C3) |
| wechat/pages/challenge/challenge.js | 281 | 2 | 1 (C2) |
| wechat/pages/club-leaderboard/club-leaderboard.js | 146 | 1 | 1 (C4) |
| wechat/utils/i18n.js | 554 | 0 | 0 |
| wechat/utils/api.js | 152 | 1 | 0 (M5) |
| web/app/challenge/page.tsx | 1142 | 4 | 1 (C1), 1 (B2) |
| web/app/challenge/layout.tsx | 56 | 0 | 0 |
| web/api/og/challenge/route.tsx | 121 | 1 | 0 (M3) |
| web/api/og/analyze/route.tsx | 112 | 0 | 0 |
| web/history/[id]/layout.tsx | 56 | 0 | 0 |
| web/lib/share-card.ts | 104 | 1 | 0 (M8) |

---

*报告生成时间: 2026-05-23 | 审查人: QA Release Engineer (AI Agent)*
