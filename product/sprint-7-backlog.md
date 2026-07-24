# RunForm Sprint 7 Backlog：双端功能对齐 Sprint

> **创建日期**：2026-07-05
> **Sprint 周期**：2026-07-28 ~ 2026-08-10（2 周）
> **Sprint 类型**：功能对齐型（Feature Parity）— 暂停新功能开发，全力追赶双端差异
> **Sprint 6 状态**：进行中（预计 7/27 收尾）
> **关联文档**：`qa/platform-feature-gap.md`（全平台差异对比审计报告）、`product/sprint-6-backlog.md`

---

## 一、Sprint 7 目标

**一句话**：Android 补齐用户认证系统 + iOS 补齐图片分享&周度洞察 + 双端对齐 Strava OAuth，将双端对齐度从 ~85% 推向 95%+。

**战略定位**：

```
Sprint 1-3：产品打磨 + 基础获客
Sprint 4：  全平台功能对齐（Android 95% / WeChat 80% / Web 60%）
Sprint 5：  营销破圈 Sprint — 全渠道饱和攻击 + 增长引擎
Sprint 6：  稳固收尾 — 安全 → 技术债 → 营销 P2 → Web 追赶
Sprint 7：  功能对齐 Sprint — 补齐最后拼图，暂停新功能 ✨ ← 本期
Sprint 8+： 跑姿驱动训练闭环 + 多产品扩展
```

**Sprint 7 核心叙事**：
- Sprint 5-6 打了两场硬仗（营销破圈 + 稳固收尾），留下了双端功能差异
- Sprint 7 是「补课 Sprint」——不追求新功能，把该对齐的对齐
- 优先级铁律：**P0 认证/Strava > P1 分享/洞察 > P2 通用页面**
- CEO 不亲自写代码——所有实现通过 `delegate_task` 分配给 iOS/Android 开发者

---

## 二、平台差异审计回顾

> 完整报告见 `qa/platform-feature-gap.md`（2026-07-05 审计），以下为 Sprint 7 相关差异摘要：

### 2.1 Android 缺失（iOS 已有）

| # | 功能 | 差距严重度 | 当前状态 |
|---|------|:--------:|---------|
| 1 | 邮箱+密码注册 UI | 🔴 阻断 | 零认证 UI，用户用本地 UUID 标识 |
| 2 | 邮箱+密码登录 UI | 🔴 阻断 | 同上 |
| 3 | 忘记密码 UI | 🔴 阻断 | 同上 |
| 4 | 登出功能 | 🟡 高 | TokenManager 基础就绪，无 UI 触发 |
| 5 | Strava OAuth 全链路 | 🟡 高 | 零 Strava 代码（模型/API/OAuth） |

### 2.2 iOS 缺失（Android 已有）

| # | 功能 | 差距严重度 | 当前状态 |
|---|------|:--------:|---------|
| 1 | 图片分享卡片渲染 | 🟡 高 | 仅 UIActivityViewController 文本分享 |
| 2 | 周度训练洞察报告 | 🟡 高 | 未实现（Android 596 行完整实现） |
| 3 | Strava 连接卡片 | 🟢 中 | 代码完整但被注释（显示 "Coming Soon"） |

### 2.3 双方共同缺失

| # | 功能 | 优先级 |
|---|------|:------:|
| 1 | 独立设置页面 | 🟡 中 |
| 2 | 隐私政策/服务条款页面 | 🟡 中 |
| 3 | 订阅/付费系统 | 🟡 中 |

### 2.4 后端前置条件（已就绪 ✅）

| 资源 | 状态 | 说明 |
|------|:----:|------|
| 注册/登录/密码重置 API | ✅ | `/auth/register` `/auth/login` `/auth/reset-password` 端点已部署 |
| Strava OAuth 后端 | ✅ | Strava API 代理 + Token 交换端点已就绪 |
| TokenManager / AuthInterceptor（Android） | ✅ | 基础设施已有，只需上层 UI |
| ShareCardRenderer（Android） | ✅ | 1080×1440 Canvas Bitmap 参考实现就绪 |
| WeeklyInsightScreen（Android） | ✅ | 596 行 Kotlin 参考实现就绪 |

---

## 三、Sprint 7 Backlog 条目

> **编号规则**：RUNFORM-7XX，XX 为流水号。
> **指派规则**：所有开发任务通过 `delegate_task` 分配给对应平台开发者（CEO 不写代码）。
> **故事点估算基准**：1 SP ≈ 半天专注开发（4h），以此类推。

---

### 3.1 P0：阻断性对齐 —— 必须交付

P0 完成后 Android 用户将首次能够创建账号并登录，iOS 用户将首次看到 Strava 连接选项。

| ID | 标题 | 优先级 | 平台 | 指派 | SP | 验收标准 | 依赖 |
|----|------|:------:|------|------|:--:|---------|------|
| **RUNFORM-700** | **Android 邮箱+密码注册 UI** — 实现注册页面，包含邮箱输入、密码输入（含强度指示）、确认密码、注册按钮。对齐 iOS `LoginView.swift` L174-189 的注册流程。使用现有 TokenManager 存储注册成功返回的 JWT Token，AuthInterceptor 自动携带 Token。后端 API `/auth/register` 已就绪。 | P0 | Android | Android 开发者 (delegate) | 5 | ① 用户可通过邮箱+密码创建账号 ② 密码强度实时反馈（弱/中/强）③ 两次密码一致性校验 ④ 注册成功后自动登录并跳转主页 ⑤ 网络错误/邮箱已存在等异常有 Toast 提示 ⑥ 输入校验（空邮箱/无效格式/密码<6位） | 后端 API ✅ |
| **RUNFORM-701** | **Android 邮箱+密码登录 UI** — 实现登录页面，包含邮箱输入、密码输入、登录按钮、"忘记密码"链接、"去注册"链接。对齐 iOS `LoginView.swift` L25-48。支持 Token 持久化（SharedPreferences），下次启动自动登录。 | P0 | Android | Android 开发者 (delegate) | 5 | ① 已注册用户可通过邮箱+密码登录 ② 登录成功 Token 持久化，下次启动免登录 ③ 登录失败有明确错误提示（密码错误/用户不存在）④ 提供"忘记密码"和"去注册"文本链接入口 ⑤ 登录中显示 Loading 状态 | RUNFORM-700（可并行） |
| **RUNFORM-702** | **Android 忘记密码/密码重置 UI** — 实现密码重置流程：输入注册邮箱 → 发送重置邮件 → 引导用户查收邮件。对齐 iOS `LoginView.swift` L130-138。后端 API `/auth/reset-password` 已就绪。 | P0 | Android | Android 开发者 (delegate) | 3 | ① 登录页"忘记密码"点击进入重置页 ② 输入邮箱后发送重置请求 ③ 发送成功后显示"重置邮件已发送，请查收"引导文案 ④ 邮箱格式校验 ⑤ 网络异常/邮箱未注册等错误提示 | RUNFORM-700（可并行） |
| **RUNFORM-703** | **Android 登出功能** — Profile 页面增加登出按钮，清除本地 Token（TokenManager.clear()），返回登录页。对齐 iOS `ProfileView` L354-360。 | P0 | Android | Android 开发者 (delegate) | 2 | ① Profile 页底部有"登出"按钮 ② 点击后弹出确认对话框 ③ 确认后清除 Token 并导航到登录页 ④ 登出后下次启动不自动登录 | RUNFORM-700, RUNFORM-701 |
| ~~RUNFORM-704~~ | ~~**iOS 取消注释 Strava 连接卡片**~~ — **❌ CEO 决策：iOS Strava 暂不实现，保持 "Coming Soon"。** Strava 代码保持注释状态。恢复条件：CEO 明确指令解冻。 | — | iOS | — | 0 | 已取消 | — |

**P0 小计**：4 条目，15 SP（RUNFORM-704 已取消）

---

### 3.2 P1：重要对齐 —— 优先交付

P1 完成后 iOS 分享能力对齐 Android，Android Strava 能力对齐 iOS，双端用户体验大幅拉平。

| ID | 标题 | 优先级 | 平台 | 指派 | SP | 验收标准 | 依赖 |
|----|------|:------:|------|------|:--:|---------|------|
| **RUNFORM-705** | **iOS 图片分享卡片渲染** — 实现与 Android `ShareCardRenderer.kt` 对齐的图片分享能力。使用 UIKit 渲染 1080×1440 分享卡片（包含跑姿数据摘要、骨架线截图、RunForm 品牌标识），支持保存到相册。覆盖场景：分析结果分享、历史记录分享、训练计划分享。Android 参考实现：Canvas Bitmap 渲染 → MediaStore 保存。 | P1 | iOS | iOS 开发者 (delegate) | 8 | ① 分析结果页"分享"按钮弹出分享选项（文本/图片）② 选择"图片分享"渲染 1080×1440 分享卡 ③ 分享卡包含：骨架线单帧截图、关键指标（步频/振幅/GCT/评分）、RunForm Logo + "扫码分析你的跑姿"文案 ④ 支持保存到相册（PHPhotoLibrary）⑤ 历史记录列表每项可触发图片分享 ⑥ 训练计划完成页可触发图片分享 ⑦ 渲染性能：卡片生成 < 500ms | Android ShareCardRenderer（参考代码已就绪） |
| **RUNFORM-706** | **iOS 周度训练洞察报告** — 实现与 Android `WeeklyInsightScreen.kt`（596 行）对齐的周度洞察页面。包含：本周 vs 上周步频/振幅/GCT 指标对比 + 趋势箭头、训练量统计（次数/里程）、成就徽章展示、AI 教练建议文案。数据源：调用后端 `/sessions/trends` API（已就绪）。 | P1 | iOS | iOS 开发者 (delegate) | 8 | ① Profile 或 History Tab 有"周度洞察"入口 ② 展示本周总跑量/训练次数/平均步频/平均 GCT ③ 步频/振幅/GCT 三个核心指标本周 vs 上周对比，含 ↑ ↓ → 趋势箭头 ④ 成就徽章区（达成目标自动点亮）⑤ AI 教练本周总结 + 下周建议（后端返回文案）⑥ 空态：无数据时显示引导文案"完成本周训练后查看洞察" ⑦ 加载态 + 错误态处理 | 后端 `/sessions/trends` API ✅、Android WeeklyInsightScreen（参考代码已就绪） |
| ~~RUNFORM-707~~ | ~~**Android Strava OAuth 全链路集成**~~ — **❌ CEO 决策：Android Strava 暂不实现。** 全平台 Strava 冻结，恢复条件：CEO 明确指令解冻。 | — | Android | — | 0 | 已取消 | — |

**P1 小计**：2 条目，16 SP（RUNFORM-707 已取消）

---

### 3.3 P2：双方共同补齐 —— 资源允许时交付

P2 完成后双端基础体验完整，为后续商业化铺路。

| ID | 标题 | 优先级 | 平台 | 指派 | SP | 验收标准 | 依赖 |
|----|------|:------:|------|------|:--:|---------|------|
| **RUNFORM-708** | **双端独立设置页面** — iOS + Android 各新增独立 Settings 页面，集中管理：账号信息、通知偏好、Strava 连接状态、语言（跟随系统/手动切换占位）、关于（版本号/开源许可）、清除缓存、登出。当前设置散落在 Profile/Plan 页，需统一收归。 | P2 | iOS + Android | iOS 开发者 + Android 开发者 (delegate) | 3+3 | ① Profile 页有"设置"入口（齿轮图标）② Settings 页包含：账号信息区、Strava 连接状态区、通知开关、关于区（版本号 1.3/开源许可链接）、清除缓存按钮、登出按钮 ③ iOS 使用 Settings.bundle 或 SwiftUI Form ④ Android 使用 PreferenceFragmentCompat 或 Compose ⑤ 清除缓存有确认弹窗 + 清除后反馈 | RUNFORM-704（Strava 状态依赖） |
| **RUNFORM-709** | **双端隐私政策 + 服务条款页面** — iOS + Android 各新增应用内法律页面：隐私政策（Privacy Policy）和服务条款（Terms of Service），内容通过 WebView 加载后端托管页面或本地静态 HTML。Profile/Settings 页增加入口链接。 | P2 | iOS + Android | iOS 开发者 + Android 开发者 (delegate) | 2+2 | ① Settings 页面有"隐私政策"和"服务条款"入口 ② 点击后在应用内 WebView 打开对应页面 ③ 页面内容由后端/Web 托管（movenova.ai/legal/privacy, /legal/terms）④ WebView 支持基础导航（返回/在浏览器中打开）⑤ 加载中/加载失败有对应状态处理 | 隐私政策+条款 Web 页面（可复用 movenova.ai 已有页面） |
| **RUNFORM-710** | **双端订阅/付费系统** — iOS 接入 StoreKit 2（内购 + 订阅），Android 接入 Google Play Billing Library 6。本期仅搭建基础框架：App Store Connect / Google Play Console 配置订阅产品、客户端 IAP 初始化 + 商品查询 + 购买流程 + 收据验证（后端验证），暂不接入具体付费功能。 | P2 | iOS + Android | iOS 开发者 + Android 开发者 (delegate) | 8+8 | ① App Store Connect 配置 1 个订阅产品（Sandbox）② Google Play Console 配置对应订阅产品 ③ 客户端可查询订阅产品列表（SKProduct / ProductDetails）④ 发起购买 → 系统支付弹窗 → 收据获取 ⑤ 收据发送后端验证（后端新增 `/iap/verify` 端点）⑥ 购买成功/失败/取消/恢复购买四种状态处理 ⑦ Profile/Settings 页显示订阅状态（未订阅/已订阅/已过期）⑧ 沙盒环境完整走通购买→验证→订阅状态更新闭环 | 后端 `/iap/verify` 端点需新建（2 SP 后端工作量，纳入本期）、App Store Connect / Google Play Console 配置 |

**P2 小计**：3 条目（双端），26 SP

---

## 四、条目汇总

### 4.1 优先级分布

| 优先级 | 条目数 | SP 总计 | 说明 |
|--------|:------:|:-------:|------|
| **P0** | 4 | 15 | 阻断性对齐：Android 认证四件套 |
| **P1** | 2 | 16 | 重要对齐：iOS 分享/洞察 |
| **P2** | 3（双端） | 26 | 通用补齐：设置/法律/订阅 |
| **总计** | **9** | **57** | — |

### 4.2 平台分布

| 平台 | 条目 | SP | 说明 |
|------|:----:|:--:|------|
| **Android** | RUNFORM-700/701/702/703 + 708/709/710 Android 端 | 28 | 认证系统（15 SP）+ 通用页面（13 SP） |
| **iOS** | RUNFORM-705/706 + 708/709/710 iOS 端 | 27 | 分享/洞察（16 SP）+ 通用页面（11 SP） |
| **Backend** | RUNFORM-710 关联 | 2 | IAP 收据验证端点 |
| **全平台** | RUNFORM-708/709/710 | — | 双端共同实现 |

### 4.3 与历史 Sprint 规模对比

| Sprint | 产品条目 | 产品 SP | 特点 |
|--------|:------:|:------:|------|
| Sprint 4 | 20 | 87 | 全平台功能对齐 |
| Sprint 5 | 10 | 45 | 营销破圈（营销 34 条目独立） |
| Sprint 6 | 12 | 34 | 稳固收尾 |
| **Sprint 7** | **11** | **66** | **功能对齐（P0+P1 共 40 SP，P2 共 26 SP）** |

**规模评估**：66 SP 在 2 周（10 工作日）× 双端并行开发下压力较大，建议严格执行 P0 → P1 → P2 优先级顺序，P2 条目至少完成 1 个（RUNFORM-708 设置页面）。

---

## 五、每周排期

### Week 1（7/28 - 8/3）：P0 全部交付 + P1 启动

| 团队 | 任务 | SP | 时间 |
|------|------|:--:|------|
| **Android 开发** | RUNFORM-700 注册 UI | 5 | Mon-Wed |
| | RUNFORM-701 登录 UI | 5 | Wed-Fri |
| | RUNFORM-702 密码重置 UI | 3 | Fri |
| **iOS 开发** | RUNFORM-704 取消注释 Strava | 1 | Mon |
| | RUNFORM-705 图片分享卡片（启动） | — | Tue-Fri |
| | RUNFORM-706 周度洞察（启动） | — | Wed-Fri |
| **关键里程碑** | ⏰ **Week 1 Mon**：iOS Strava 卡片恢复上线 | — |
| | ⏰ **Week 1 Wed**：Android 注册 UI 完成 | — |
| | ⏰ **Week 1 Fri**：**Android 认证系统全面可用**（注册+登录+密码重置+登出）| — |

### Week 2（8/4 - 8/10）：P1 收尾 + P2 推进 + QA

| 团队 | 任务 | SP | 时间 |
|------|------|:--:|------|
| **Android 开发** | RUNFORM-707 Strava OAuth 全链路 | 8 | Mon-Fri |
| | RUNFORM-708 设置页面（Android 端）| 3 | 视资源 |
| **iOS 开发** | RUNFORM-705 图片分享卡片（收尾） | 8 | Mon-Wed |
| | RUNFORM-706 周度洞察（收尾） | 8 | Wed-Fri |
| | RUNFORM-708 设置页面（iOS 端）| 3 | 视资源 |
| **Backend 开发** | RUNFORM-710 `/iap/verify` 端点 | 2 | Mon-Tue |
| **QA** | 全平台 Sprint 7 回归测试 | 3 | Thu-Fri |
| **关键里程碑** | ⏰ **Week 2 Mon**：iOS 图片分享卡片功能可用 | — |
| | ⏰ **Week 2 Wed**：iOS 周度洞察 + 后端 IAP 端点完成 | — |
| | ⏰ **Week 2 Fri**：**Android Strava OAuth 完成 + QA 回归通过** | — |

---

## 六、验收标准总览

### 6.1 P0 验收门（Week 1 结束）

- [ ] **Android 用户可完成完整认证闭环**：注册 → 登录 → 查看 Profile → 登出 → 重新登录
- [ ] **iOS Strava 连接卡片可见且可用**：连接 → 授权 → 同步数据 → 断开
- [ ] 两个平台各自的 Apk/IPA 构建成功，无编译错误

### 6.2 P1 验收门（Week 2 结束）

- [ ] **iOS 图片分享**：分析结果/历史记录/训练计划三场景均可生成 1080×1440 分享卡并保存相册
- [ ] **iOS 周度洞察**：步频/振幅/GCT 三指标本周 vs 上周对比正确，成就徽章/教练建议显示
- [ ] **Android Strava**：OAuth 全链路走通（连接→授权→数据同步→预填充→断开）

### 6.3 P2 验收门（选做）

- [ ] 至少一端设置页面可用（RUNFORM-708）
- [ ] 至少一端法律页面可用（RUNFORM-709）

---

## 七、风险

| # | 风险 | 等级 | 概率 | 影响 | 缓解方案 |
|---|------|:----:|:----:|:----:|---------|
| R1 | **Android 认证 UI 开发周期超预期** — 注册/登录/密码重置三页 + 状态管理 + 异常处理，实际可能超过 13 SP | 🟡 中 | 中 | P0 阻塞后续，必须完成。密码重置可降级为"邮件客服"，暂不去 UI；注册/登录必须交付 | 
| R2 | **iOS 图片分享卡渲染性能不达标** — 1080×1440 卡片渲染 > 500ms 或内存占用过高 | 🟡 中 | 低 | 降级方案：降低卡片分辨率至 720×960；使用后台队列异步渲染；复用单一 Renderer 实例 |
| R3 | **Android Strava OAuth Custom Tabs 兼容性** — 部分国产 ROM（MIUI/ColorOS）Chrome Custom Tabs 行为异常 | 🟢 低 | 中 | 降级方案：回退到 WebView OAuth（牺牲 UX，但功能可用）；优先测试主流机型 |
| R4 | **后端 IAP 验证端点开发延迟** — `/iap/verify` 需要在 Sprint 6 结束后由后端开发实现，可能挤占 Sprint 7 时间窗 | 🟡 中 | 中 | P2 条目，可在 Sprint 7 后补。降级：客户端仅做前端购买 UI，收据验证后续迭代 |
| R5 | **Sprint 7 66 SP 超出双端开发者带宽** — 双端并行开发 2 周内 66 SP 压力较大 | 🟡 中 | 中 | P2 全部标记"资源允许时交付"；P1 中 iOS 分享卡和洞察可只选一个先行完成；严格按 P0 → P1 → P2 推进 |
| R6 | **iOS Xcode 26 构建环境兼容性** — Sprint 6 已知 Xcode 26 环境适配进行中，可能影响 Sprint 7 iOS 开发 | 🟢 低 | 低 | 延续 Sprint 6 兼容方案；关键功能优先在真机验证 |

---

## 八、不做的事（以及为什么）

| 请求 | 来源 | 延后原因 | 重新考虑条件 |
|------|------|---------|-------------|
| **新功能开发**（任何不在差异报告中的新需求） | 产品 Roadmap | 本期为功能对齐 Sprint，禁令明确：暂停新功能 | Sprint 8 |
| **Web 平台对齐**（周洞察/分享等） | Sprint 6 结转 | Sprint 6 已安排 Web 洞察（RF-612），本期聚焦移动端双端对齐 | Sprint 8 |
| **微信小程序功能补齐** | 平台差异 | 微信小程序对齐度 ~85%，剩余 GAP 多为系统限制（CoreMotion）或低优先级 | 有明确运营需求时 |
| **Google 登录集成** | 差异报告 2.1-#4 | Android 认证 P0 优先邮箱+密码（后端 API 已就绪），Google 登录需额外后端工作 | Sprint 8 |
| **Android PerformanceOptimizer** | 差异报告 2.3-#1 | iOS 独有优化器，Android 已有 StartupOptimizer + 其他优化机制，非关键差距 | 性能问题暴露时 |
| **Android HistoryDetailView** | 差异报告 2.3-#2 | 单条历史详情页，P2 优化项，不阻塞用户体验 | Sprint 8 |
| **iOS 视频压缩**（MediaCodec 对齐） | 差异报告 3.3-#1 | Android 独有，iOS 本身视频处理管线不同，非关键差距 | 有视频上传体验投诉时 |
| **iOS 离线反馈缓存**（Room FeedbackDao 对齐） | 差异报告 3.3-#2 | Android 独有 Room 离线缓存，iOS 使用 UserDefaults + 内存管理，架构不同 | 离线场景用户反馈数据丢失时 |
| **iOS GPS 地图追踪**（RunSessionReplay 对齐） | 差异报告 3.3-#3 | Android 独有 GPS 路径回放，iOS 已有 RunSession 回放（无地图），可后续补 | Sprint 8 |
| **iOS Firebase Analytics + Crashlytics** | 差异报告 3.4-#1 | Android 独有，iOS 可补但非关键对齐项 | 需要统一的跨平台数据分析时 |
| **双端语言切换设置** | 差异报告 4-#5 | 低优先级，当前自动跟随系统语言已满足需求 | 用户明确反馈需手动切换时 |
| **双端链接分享（Deep Link）** | 差异报告 4-#4 | 低优先级，需配合后端 Deep Link 路由 + App Link/Universal Link 配置 | 有显著的 Web→App 引流需求时 |

---

## 九、Sprint 7 成功指标

| 指标 | 目标 | 说明 |
|------|------|------|
| P0 条目完成率 | 100%（5/5） | Android 认证系统 + iOS Strava 解冻 |
| P1 条目完成率 | ≥ 67%（2/3） | 至少交付 iOS 分享卡片 + 周度洞察，或 Android Strava + 一项 iOS |
| P2 条目完成率 | ≥ 33%（1/3） | 至少一端设置页面可用 |
| Android 认证闭环 | ✅ | 注册→登录→Profile→登出→重新登录全链路 |
| iOS Strava 连接 | ✅ | 连接→授权→同步→断开全链路 |
| 双端对齐度 | 85% → 95%+ | P0+P1 完成后核心功能对齐率 |
| QA 回归 | 0 个 P0 回归 Bug | Sprint 6 已完成功能 + Sprint 7 新增功能 |

---

## 十、与其他 Sprint 的关系

```
Sprint 6（进行中）              Sprint 7（本期）             Sprint 8（展望）
┌─────────────────┐          ┌─────────────────┐          ┌─────────────────┐
│ 安全部署 + 修复   │          │ Android 认证系统  │          │ 跑姿驱动训练闭环  │
│ Web 平台对齐收尾  │    →     │ iOS 分享+洞察     │    →     │ Phase 2          │
│ 营销 P2 支撑      │          │ 双端 Strava 对齐  │          │ 视频资产生产      │
│ 体验优化          │          │ 通用页面补齐       │          │ 用户反馈驱动迭代  │
└─────────────────┘          └─────────────────┘          └─────────────────┘
       稳固收尾                   功能追齐                     重回增长
```

---

> **RunForm Sprint 7 Backlog — 暂停新功能，把该对齐的对齐。Android 用户终于能注册了，iOS 用户终于能分享了，双端一起接上 Strava。**
> *文档版本 v1.0 | 2026-07-05*
