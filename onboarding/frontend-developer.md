# Sprint 0 启动文档 — 前端开发工程师入职手册

> **版本**：v1.1
> **日期**：2026-05-13
> **角色**：前端开发工程师（Web 端从零搭建）
> **网站代码库**：`https://github.com/hgao168/movenova.ai`（独立仓库，优先在该仓库开发）
> **参考代码库**：`~/workspace/runform/`（仅用于读取 iOS 功能与文案来源）
> **核心目标**：前端先完成官网开发（Website First），并以 iOS 已有功能为内容和模块基准，确保官网价值主张与 App 能力一致

---

## 一、本周目标（This-Week Goal）

**一句话**：在独立仓库 `movenova.ai` 启动并推进官网开发，优先交付可上线的 Website MVP；功能叙事与页面模块以 iOS 已上线能力为准。

**执行优先级（本次更新）**：
1. 网站开发优先，不先做 Web App
2. 开发位置固定在 `https://github.com/hgao168/movenova.ai`
3. 页面内容优先映射 iOS 现有功能（分析、对比、历史、训练计划、实时语音指导）
4. `runform` 主仓库只作参考，不承载网站业务代码

**本周产出物清单**：
1. `movenova.ai` 仓库初始化与部署链路可用（Preview/Production）
2. 官网信息架构（IA）和 Sitemap 定稿
3. Landing Page 首版上线（可访问）
4. iOS 功能映射表（iOS Feature -> Website Section）
5. 风险识别与缓解方案
6. 需 CEO 拍板的关键决策项（仅保留网站相关）

### 1.1 Day 1 入职清单（Owner 明确）

| 任务 | Owner | 说明 |
|------|-------|------|
| 获取仓库权限（`movenova.ai`） | CEO/管理员 | 添加 Frontend Developer 的 GitHub 读写权限 |
| Clone 仓库到本地 | Frontend Developer | 前端开发自行执行，不要求 CEO 手动 clone |
| 安装依赖并本地启动 | Frontend Developer | 产出可运行截图或终端日志 |
| 配置 `.env.local` 与必要变量 | Frontend Developer | 对齐 `README` 与部署环境变量 |
| 提交首个 Setup PR | Frontend Developer | PR 包含运行步骤、构建结果、Preview URL |
| 审核并合并 Setup PR | Tech Lead/CEO 指定 reviewer | 通过后进入模块开发 |

---

## 二、交付物（Deliverables）

### 2.1 现状审计：Web 端起点

| 维度 | 现状 | 评估 |
|------|------|------|
| **Web 代码** | 网站在独立仓库 `movenova.ai` | ✅ 可独立迭代，不受主仓库结构限制 |
| **后端 API** | FastAPI 全栈服务（分析/计划/对比/Strava OAuth） | ✅ 已有完整 REST API，Web 端可直接复用 |
| **域名/部署** | 当前仅 Railway 后端部署，无前端托管 | ⚠️ 需确定部署方案（Vercel/Cloudflare Pages/Railway Static） |
| **设计资产** | iOS/Android 已有 UI 组件（SwiftUI/Compose），无 Figma/设计规范文档 | ⚠️ Website 需优先从 iOS 提取视觉与功能叙事 |
| **视频上传** | iOS/Android 端已有视频录制+上传流程，后端支持 multipart 上传 | ✅ Web 端可直接复用后端 `/upload` + `/analyze` 端点 |
| **微信小程序** | 已有 5 页面结构（分析/结果/计划/历史/个人） | ✅ 可作为 Web 应用信息架构参考 |

### 2.2 React（Next.js）vs Vue（Nuxt）技术选型对比

> 选择框架的本质是匹配**项目需求画像**而不是追热点。下面从 RunForm 的具体场景出发逐项对比。

#### 需求画像

RunForm Web 端需要同时满足两类场景：

| 场景类型 | 特征 | 技术需求 |
|----------|------|----------|
| **官网营销页面**（Home/Features/Pricing/Blog） | 内容为主，SEO 敏感，加载速度要求高 | SSR/SSG，优秀的 Core Web Vitals，Markdown 博客支持 |
| **Web 应用**（视频上传 + 分析结果 + Dashboard） | 交互密集，状态复杂，需要与后端 API 频繁通信 | 丰富的表单/上传组件生态，复杂状态管理，路由嵌套 |

#### 逐维度对比

| 维度 | Next.js (React) | Nuxt (Vue) | 对 RunForm 的影响 |
|------|-----------------|------------|-------------------|
| **SSR/SSG 成熟度** | ⭐⭐⭐⭐⭐ App Router + Server Components 领先一代 | ⭐⭐⭐⭐ 稳定好用，但 React RSC 生态更新 | 官网 SEO 是关键，Next.js 的 Server Components 可做到零 JS 的纯内容页面 |
| **富交互应用生态** | ⭐⭐⭐⭐⭐ 拖拽上传、视频播放器、图表库选择极丰富 | ⭐⭐⭐⭐ 生态足够但部分高级库 React-only | Web 应用的视频上传/结果可视化是核心技术环节 |
| **渐进式 Web App（PWA）** | ⭐⭐⭐⭐⭐ next-pwa 成熟，Vercel 原生支持 | ⭐⭐⭐⭐ @vite-pwa/nuxt 可用 | v1 可能不需要 PWA，但后续「离线查看分析报告」是刚需 |
| **TypeScript 支持** | ⭐⭐⭐⭐⭐ 一等公民，生态库几乎全部带类型 | ⭐⭐⭐⭐ 良好，但部分 Vue 生态库类型覆盖不如 React | 项目规模会增长，强类型 = 重构安全 |
| **状态管理复杂度** | Redux/Zustand/Jotai — 多层选择 | Pinia — 统一方案 | Web App 的状态（上传进度/分析结果轮询/历史筛选）需要强状态管理 |
| **服务端渲染性能** | ⭐⭐⭐⭐⭐ React Server Components 减少客户端 JS 体积 | ⭐⭐⭐⭐ 稳定但客户端 hydration 较重 | 官网首屏加载速度直接影响转化率 |
| **学习曲线** | 中等（JSX + Hooks 心智模型） | 中等偏低（模板语法直观） | 团队如果已有 React 经验，切换 Vue 是额外成本 |
| **AI/数据分析可视化** | D3/ECharts/Recharts/visx 生态最丰富 | ECharts/Vue-chartjs 够用但深度不如 React | 分析结果需要图表展示（步频趋势/姿态评分雷达图/历史对比） |
| **中文社区 & 招聘** | 国内市场 React 开发者供给 > Vue（2025） | 国内 Vue 社区庞大，但高级 Nuxt 人才少于 Next.js | 后续团队扩张时有影响 |
| **部署 & 托管** | Vercel 原生支持，边缘函数免费额度大方 | Nuxt Hub / Vercel / Cloudflare 均可 | Vercel + Next.js 是「推上即用」级别体验 |
| **视频处理前端** | video.js / remotion / mux-player 完整方案 | 需自行封装，Vue 视频组件生态偏少 | Web 端核心差异化：视频逐帧跑姿标注回放 |
| **国际化（i18n）** | next-intl / next-i18n-router 开箱即用 | @nuxtjs/i18n 成熟 | RunForm 已有中/英/荷兰语三语，Web 端需同步 |

#### 核心推理

**RunForm Web 端的独特挑战不是「做一个官网」**——如果只是官网，Nuxt 和 Next.js 都能做且差距不大。真正的挑战在于：

1. **视频分析结果的 Web 展示**：用户在浏览器中查看跑姿分析时，需要视频逐帧标注回放（类似 Hudl Technique 的 Web 版）。这需要复杂的视频时间轴控制 + Canvas/SVG 骨骼叠加。React 生态在视频处理组件（remotion、mux-player、自定义 video.js wrapper）上领先 Vue 一个身位。

2. **分析结果的交互式图表**：步频趋势、姿态评分雷达图、历史对比——React + D3/visx/Recharts 的组合是事实上的行业标准。

3. **官网 → Web App 的平滑过渡**：Next.js App Router 可以在同一个项目中无缝混合 SSG（官网页面）和 CSR（Web App 页面），用户从首页点击「Upload Video」时不离开站点——这是 Nuxt 也能做到但 Next.js 做得更优雅的地方。

**建议：React（Next.js 14+ App Router）**

| 判断理由 | 权重 |
|----------|------|
| 视频播放与逐帧标注交互的 React 组件生态碾压优势 | 🔴 决定性 |
| 分析结果可视化（D3/visx/Recharts）在 React 生态更成熟 | 🔴 决定性 |
| Next.js Server Components 对 SEO 页面性能的极致优化 | 🟡 重要 |
| 一条代码库覆盖「纯内容官网 + 重交互 Web App」 | 🟡 重要 |
| 国际化（next-intl）和部署（Vercel）开箱即用 | 🟢 加分 |

### 2.3 官网信息架构（IA）与 Sitemap

> 说明：Website 信息架构优先体现 iOS 已上线功能，不提前承诺未落地能力。

```
runform.co / runform.ai
│
├── /                         Home（首页）
│   ├── Hero：核心价值主张 — "AI that understands HOW your body runs"
│   ├── 跑姿分析流程展示（3 步：上传 → 分析 → 改善）
│   ├── 真实案例/效果对比（Before/After 跑姿动图）
│   ├── 支持的平台（iOS / Android / 微信小程序 / Web）
│   ├── 信任背书（用户数/分析次数/教练推荐）
│   └── CTA：免费试用 / 下载 App
│
├── /features                 Features（功能详情）
│   ├── AI 视频跑姿分析
│   ├── 实时跑步语音教练（v1 核心卖点）
│   ├── 生物力学指标面板（15+ 指标详解）
│   ├── 精英运动员对比模式（me vs Kipchoge）
│   ├── AI 个性化训练计划
│   └── Strava 同步集成
│
├── /pricing                  Pricing（定价页）
│   ├── Free Tier：基础分析（限次数）
│   ├── Pro Tier：无限分析 + 实时教练 + 训练计划
│   └── Team/Coach Tier：教练管理多位跑者
│
├── /blog                     Blog（博客）
│   ├── 跑步生物力学科普
│   ├── 伤病预防指南
│   ├── 产品更新日志
│   └── 跑者故事/用户案例
│
├── /app                      Web App（Web 应用入口）
│   ├── /app/upload           视频上传页（支持拖拽 / 粘贴 / 本地选择）
│   ├── /app/analyze/[id]     分析结果页（逐帧回放 + 指标面板）
│   ├── /app/history          历史分析记录
│   ├── /app/compare          对比模式（me vs elite / me vs last）
│   ├── /app/plan             训练计划查看
│   └── /app/settings         设置（语言/单位制/Strava 连接）
│
├── /dashboard                Dashboard（管理后台 / 教练面板）
│   ├── /dashboard/overview   概览（用户数/分析量/活跃度）
│   ├── /dashboard/athletes   跑者管理（教练视角）
│   └── /dashboard/analytics  数据分析（聚合匿名统计）
│
├── /about                    About（关于我们）
├── /contact                  Contact（联系我们）
├── /privacy                  Privacy Policy（隐私政策）
├── /terms                    Terms of Service（服务条款）
└── /support                  Support（帮助中心）

动态路由预留：
  /blog/[slug]                单篇文章
  /app/analyze/[id]           单次分析结果（SSR 分享链接）
```

#### IA 设计原则

| 原则 | 说明 |
|------|------|
| **官网与 Web App 同一域名** | 不做 `app.runform.ai` 子域拆分（v1 阶段），用 `/app/*` 路由前缀在 Next.js 内轻松区分 SSR 和 CSR 页面 |
| **分析结果可分享** | `/app/analyze/[id]` 使用 SSR（ISR），用户分享链接到社交媒体时能看到 Open Graph 预览（跑姿评分 + 关键指标） |
| **博客作为 SEO 获客引擎** | 跑步伤病相关的长尾关键词搜索量极大（"running knee pain" 月搜索 10K+），Blog 是低成本流量入口 |
| **Dashboard 先走轻量** | Sprint 1-2 用简单的表格 + 图表展示，不做复杂 RBAC；跑者量不足以支撑后台前先搁置 |

### 2.4 Landing Page 原型方案（Sprint 1 计划）

#### iOS 功能映射（必须先完成）

| iOS 功能 | 网站对应模块 | 页面位置 |
|----------|--------------|----------|
| 跑姿分析（AnalysisResultView） | AI 跑姿分析能力模块 | `/` Hero 下方 + `/features` |
| 历史趋势（HistoryView） | Progress Tracking 模块 | `/features` |
| 对比能力（CompareView） | Compare 模块（Me vs Elite/History） | `/features` |
| 训练计划（PlanBuilderView/MarathonPlanDetailView） | Personalized Plan 模块 | `/features` + `/app teaser` |
| 实时语音指导（LiveGuidanceRecorderView） | Live Coaching 模块 | `/` 与 `/features` |
| Strava 集成（ProfileStravaCard） | Integrations 模块 | `/features` |

#### 技术栈

| 层 | 选型 | 理由 |
|----|------|------|
| **框架** | Next.js 14+ (App Router) | 统一官网 + Web App 代码库 |
| **语言** | TypeScript (strict mode) | 按 skill 要求 + 项目长期可维护性 |
| **样式** | Tailwind CSS 4 | 按 skill 要求移动优先 + 快速原型迭代 |
| **组件库** | shadcn/ui + Radix UI | 无 runtime 开销、可定制、无障碍内置 |
| **动效** | Framer Motion | Landing Page 动效（Hero 滚动视差 / 流程图解逐步展示） |
| **内容管理** | MDX (本地) 或 Contentlayer | Blog 使用 Markdown，不需要数据库 |
| **国际化** | next-intl | 中/英/荷兰语三语路由（`/zh/`, `/en/`, `/nl/`） |
| **动画** | Lottie / Rive（可选） | 跑姿动画展示（骨胳动效），非必需 |
| **图标** | Lucide Icons | 与 shadcn/ui 配套 |
| **部署** | Vercel（Hobby 计划免费） | 零配置部署 + 自动预览域名 |
| **分析** | Plausible / Umami（自建或云） | 隐私友好的访问统计 |
| **视频** | 原生 `<video>` + Canvas 叠加层 | Web 应用逐帧标注不依赖第三方播放器 |

#### Landing Page （`/`）UI 模块拆解

```
┌─────────────────────────────────────────────────────┐
│ Navbar（Logo + Features/Pricing/Blog + CTA按钮）      │
├─────────────────────────────────────────────────────┤
│                                                      │
│  Hero Section                                        │
│  ┌─────────────┐   ┌──────────────────┐             │
│  │             │   │ AI Running Form  │             │
│  │  跑姿骨骼    │   │ & Injury Coach   │             │
│  │  动效展示    │   │                  │             │
│  │  (Lottie/   │   │  Understand HOW  │             │
│  │   CSS 动效)  │   │  your body runs  │             │
│  │             │   │                  │             │
│  │             │   │  [开始免费分析]   │             │
│  └─────────────┘   └──────────────────┘             │
│                                                      │
├─────────────────────────────────────────────────────┤
│  How It Works（3 步卡片流）                           │
│  ┌──────┐  →  ┌──────┐  →  ┌──────┐                │
│  │ 录视频 │     │ AI分析│     │ 获得   │                │
│  │ 3视角 │     │ 15+指标│    │ 改善方案│                │
│  └──────┘     └──────┘     └──────┘                │
│                                                      │
├─────────────────────────────────────────────────────┤
│  Key Metrics Preview（指标雷达图 + 对比模式预告）      │
│                                                      │
├─────────────────────────────────────────────────────┤
│  Testimonials / Social Proof（用户反馈/教练推荐）      │
│                                                      │
├─────────────────────────────────────────────────────┤
│  Platform Support（iOS/Android/微信/Web 四端图标）     │
│                                                      │
├─────────────────────────────────────────────────────┤
│  CTA Footer（重复入口：开始免费分析 / 下载 App）       │
├─────────────────────────────────────────────────────┤
│  Footer（Links + Copyright + Language Switcher）      │
└─────────────────────────────────────────────────────┘
```

#### Sprint 1 Landing Page 交付范围

| 模块 | 交付物 | Sprint 1 范围 |
|------|--------|---------------|
| Navbar | 响应式导航 + 语言切换器 | ✅ 完整实现 |
| Hero | 主标题 + 副标题 + CTA 按钮 + 背景动效 | ✅ 完整实现 |
| Problem/Agitation | 「大多数跑者不知道自己的跑姿问题」+ 伤病数据 | ✅ 完整实现 |
| How It Works | 3 步静态卡片（暂不做 Lottie 动效） | ✅ 完整实现 |
| Key Metrics | 4-6 个核心指标卡片（步频、跨步、躯干角度、着地方式） | ✅ 完整实现 |
| Compare Teaser | 「你和 Kipchoge 的跑姿差在哪」钩子模块 | ✅ 完整实现 |
| Platform | 四端图标 + 下载链接 | ✅ 完整实现 |
| Testimonials | 占位（Sprint 2 填充真实数据） | ⚪ 占位结构 + 假数据 |
| Pricing Preview | 定价预览（Free / Pro） | ⚪ 结构 + TBD 定价 |
| Blog | 零文章状态 + 标题占位 | ⚪ 路由骨架 |
| Footer | 链接 + copyright + 语言切换 | ✅ 完整实现 |
| SEO | 中/英/荷兰语 meta + OG image + sitemap.xml | ✅ 完整实现 |
| Analytics | Plausible 埋点 | ✅ 完整实现 |

> **Sprint 1 目标**：一个**可以上线**的单页 Landing Page，收集邮箱等并展示核心价值主张。Web App（`/app/*`）不在 Sprint 1 范围内。

> **仓库约束**：Sprint 1 所有网站代码提交到 `movenova.ai`；`runform` 仓库不新增 `web/` 业务代码。

---

## 三、风险（Risks）

### 风险 1：Web 端视频上传体验不如原生 App 🔴 高

**描述**：浏览器对视频编码格式（H.264/HEVC/VP9）的支持不一致，大文件上传断点续传是挑战。iOS Safari 对 `<input type="file" accept="video/*">` 的行为与 Android Chrome 不同。如果 Web 端视频上传体验很差（等待久 / 失败 / 不支持某些格式），用户会流失到原生 App——而 Web 端的核心价值「不需要下载 App 即可试用」将被削弱。

**缓解方案**：
- 前端做客户端视频格式检测（`HTMLVideoElement.canPlayType`）+ 不支持的格式提示转码
- 使用 `tus` 协议做断点续传上传（`tus-js-client`），避免大文件上传失败重传
- 上传前压缩/抽取关键帧预分析（Web Worker 线程，避免阻塞 UI）
- 后端已有 `/upload` 端点，但需确认是否支持 chunked upload
- Sprint 1 不碰 Web App，优先交付官网——视频上传的坑留给 Sprint 2 解决

### 风险 2：设计资产缺失导致视觉一致性差 🟡 中

**描述**：项目目前没有 Figma 设计规范、没有 Design Token、没有组件库。iOS 和 Android 的 UI 各自独立开发，视觉语言不完全统一。Web 端从零开始如果缺乏设计指导，容易产出与 App 风格不一致的页面，损害品牌认知。

**缓解方案**：
- Sprint 0 从 iOS App 截图中提取关键视觉元素：配色（主色/辅色）、字体栈、间距比例
- 在 Tailwind 配置中建立 Design Token（`colors.runform.primary` 等），确保可复用
- shadcn/ui 的 `--primary` / `--radius` 等 CSS 变量可以从 App 提取值后直接映射
- Sprint 1 产出的 Landing Page 作为后续所有 Web 页面的视觉基准

### 风险 3：Next.js 引入对后端部署架构的变更 🟡 中

**描述**：当前后端部署在 Railway，前端是纯静态文件（iOS/Android 不涉及前端部署）。引入 Next.js 后需要前端部署环境（Vercel / Railway Static / Cloudflare Pages）。Next.js 的 API Routes 可能与 FastAPI 端点产生概念混淆。

**缓解方案**：
- v1 阶段 **不使用** Next.js API Routes——所有 API 调用直连 FastAPI 后端
- Next.js 仅承担「SSR/SSG 渲染 + 客户端 CSR」角色，是纯前端
- 部署选 Vercel（免费额度 100GB 带宽/月，对于初期官网绰绰有余）
- 通过环境变量 `NEXT_PUBLIC_API_BASE_URL` 指向 Railway 后端地址
- 如果未来需要 BFF（Backend for Frontend），在 Sprint 3+ 评估是否需要中间层

### 风险 4：内容生产滞后导致 SEO 效果不足 🟢 低（短期）

**描述**：Blog 是 SEO 获客引擎，但如果 Blog 上线后长期没有文章（典型的「幽灵博客」），对 SEO 不仅无益，反而可能被搜索引擎视为低质量站点。

**缓解方案**：
- Sprint 1 Blog 路由骨架上线但不做 SEO 索引（robots.txt 暂时屏蔽 `/blog/*`）
- 产品经理 + 领域专家 Sprint 2 起每两周一篇博客的生产节奏
- 初始内容方向：跑步伤病科普（复用 Backlog1.md 的分析框架）、AI 跑姿分析原理

---

## 四、需要 CEO 拍板的决策（Decisions Needed From CEO）

| # | 决策项 | 选项 A | 选项 B | 建议 |
|---|--------|--------|--------|------|
| **D1** | **React（Next.js）vs Vue（Nuxt）最终选型** | React / Next.js 14+ App Router | Vue / Nuxt 3 | **强烈建议 A**。见 2.2 节详细推理：视频逐帧标注 + 数据可视化 + 官网 SEO 的三重需求下，Next.js 是最优解。唯一选择 B 的理由是如果团队只有 Vue 开发经验且无人愿学 React，但目前 Web 端团队为零，不存在这个约束 |
| **D2** | **域名策略：独立域名 vs 子域名** | `runform.ai` 统一域名，`/app/*` 路由区分官网和 Web App | `runform.ai` 官网 + `app.runform.ai` Web App 子域 | **建议 A（v1）→ 视情况切换到 B（v2+）**。v1 阶段子域增加 DNS/部署/Cookie 隔离复杂度，ROI 低。当 Web App 流量大到需要独立扩容时再拆分 |
| **D3** | **官网 v1 是否需要 Blog** | 仅博客路由骨架（占位），不写文章 | Sprint 1 发布至少 3 篇博客 | **建议 A**。Sprint 1 目标是把 Landing Page 上线，Blog 内容非本周可交付。但路由要建，方便后续直接写 Markdown 即可发布 |
| **D4** | **Web App（视频上传分析）是否 Sprint 1 交付** | Sprint 1 仅交付 Landing Page，Web App 延后到 Sprint 2 | Sprint 1 同时交付 Landing Page + 视频上传 MVP | **强烈建议 A**。视频上传的跨浏览器兼容性、断点续传、逐帧标注 UI 都是独立的技术深坑。Sprint 1 专注把 Landing Page 做到像素级完美上线，Sprint 2 开始攻克 Web App |
| **D5** | **是否需要在 Landing Page 上做定价页** | Sprint 1 包含 Pricing 页（Free/Pro 定价可见） | Sprint 1 不显示具体价格，仅「即将推出」占位 | **建议 A**（如果定价已确定）或 **B**（如果定价未定）。Pricing 是官网转化漏斗的重要一环，但如果 CEO 还没确定定价策略，强行写数字会有法律风险 |
| **D6** | **Web 端国际化范围** | 全部三语（中/英/荷兰语）同步上线 | Sprint 1 仅英文，后续补中文和荷兰语 | **建议 B**。Landing Page 单页的 i18n 工作量不大（next-intl 的翻译文件），但如果 Sprint 1 时间紧张，先英文上线验证市场反应，再补多语也不迟 |

---

## 五、Sprint 0 待办清单（Web 前端）

| # | 任务 | 类型 | 预估 | 交付物 |
|---|------|------|------|--------|
| **S0-W1** | React vs Vue 技术选型文档终稿 | 技术决策 | 0.5 天 | `onboarding/frontend-developer.md` 本文档 2.2 节 |
| **S0-W2** | 官网 IA + Sitemap 审阅与确认 | 信息架构 | 0.5 天 | Sitemap 确认稿（本文档 2.3 节） |
| **S0-W3** | Landing Page 视觉参考收集（竞品官网截图） | 设计参考 | 0.5 天 | Runna/Strava/Hudl 等竞品官网截图 + 结构分析 |
| **S0-W4** | 从 iOS App 截图提取 Design Token（色板/字体/间距） | 设计工程 | 0.5 天 | Tailwind 配置文件草案 |
| **S0-W5** | 在 `movenova.ai` 初始化 Next.js 脚手架 + 验证 Tailwind/shadcn/i18n 三件套可工作 | 技术验证 | 0.5 天 | 可运行的网站骨架项目 + `README.md` |
| **S0-W6** | Vercel 部署 PoC（推送即部署验证） | DevOps | 0.5 天 | Vercel 项目创建 + 自动预览域名可用 |
| **S0-W7** | CEO 决策会：拍板 D1-D6 | 决策 | 0.5 天 | 决策记录（本文档第四节更新为终稿） |
| **S0-W8** | Sprint 1 任务拆解：Landing Page 模块分配到开发日 | 规划 | 0.5 天 | Sprint 1 看板（GitHub Issues / Linear） |

---

## 六、技术架构速览

```
                        ┌──────────────────────┐
                        │   Vercel (前端托管)    │
                        │                       │
                        │  Next.js 14+          │
                        │  ├─ /           SSG   │ ← 官网页面（预渲染）
                        │  ├─ /features   SSG   │
                        │  ├─ /pricing    SSG   │
                        │  ├─ /blog/*     ISR   │ ← 博客（增量静态再生）
                        │  ├─ /app/*      CSR   │ ← Web App（客户端渲染）
                        │  └─ /api/*      不启用 │ ← 直接调用后端
                        │                       │
                        └──────────┬────────────┘
                                   │ HTTPS (CORS)
                                   ▼
                        ┌──────────────────────┐
                        │  Railway (后端托管)    │
                        │                       │
                        │  FastAPI (Python)     │
                        │  ├─ POST /upload      │
                        │  ├─ POST /analyze     │
                        │  ├─ GET  /analysis/:id│
                        │  ├─ POST /training-   │
                        │  │       plan         │
                        │  ├─ POST /compare     │
                        │  └─ /strava/*         │
                        └──────────────────────┘
```

| 边界 | 约定 |
|------|------|
| 前端域名 | `runform.ai`（TBD by CEO D2） |
| 后端 API Base URL | `https://runform-coach-ai-production.up.railway.app` |
| 跨域 | FastAPI 需添加 CORS 中间件允许前端域名 |
| 认证 | v1 Web App 使用 JWT（Token 存储在 httpOnly cookie，Next.js middleware 转发），后续 OAuth（Google/Apple） |
| 视频存储 | 后端已有文件存储方案，前端不做额外处理 |

---

## 七、与现有代码库的交互边界

| 现有模块 | Web 端是否需要接入 | 接入方式 |
|----------|-------------------|---------|
| iOS 端侧 PoseExtractor | ❌ 不接入 | iOS 独有的 Vision 框架能力，Web 端走视频上传 → 后端分析 |
| 后端 `/analyze` 端点 | ✅ 核心接入 | Web 端上传视频 → 后端调用分析 → 返回结果 JSON → 前端渲染 |
| 后端 `/training-plan` | ✅ 展示接入 | Web App Dashboard 中展示训练计划（只读） |
| 后端 `/compare` | ✅ 展示接入 | Web 端对比模式展示（me vs Kipchoge / me vs history） |
| Strava OAuth | ✅ 可选接入 | Web 端连接 Strava 查看训练量（与 iOS/Android 共享同一后端） |
| 微信小程序 | ❌ 不接入 | 独立平台，不与 Web 端直接互通（共用后端 API） |
| Android 端 | ❌ 不接入 | 独立平台 |

> **关键事实**：Web 端是「纯消费者」角色——它调用现有后端 API 并渲染结果，不做任何原生传感器数据处理。这意味着 Web 端开发不阻塞也不被任何其他端阻塞。

---

## 八、附录：关键文件路径索引

| 文件/目录 | 说明 |
|-----------|------|
| `~/workspace/runform/` | 项目根目录（monorepo 结构） |
| `~/workspace/runform/backend/` | FastAPI 后端源码（Web 端的主要 API 来源） |
| `~/workspace/runform/ios/RunFormCoachAI/` | iOS 原生 App（UI 参考来源） |
| `~/workspace/runform/wechat/pages/` | 微信小程序页面（信息架构参考） |
| `https://github.com/hgao168/movenova.ai` | 网站开发主仓库（前端优先执行） |
| `~/workspace/runform/onboarding/product-manager.md` | PM 入职文档（产品定位 & v1 范围参考） |
| `~/workspace/runform/Backlog1.md` | 跑步生物力学分析框架（Blog 内容素材） |
| `~/workspace/runform/backlog3.md` | 战略定位文档：AI Running Form & Injury Coach |
| `~/workspace/runform/PRIVACY_POLICY.md` | 隐私政策（Web 端 `/privacy` 页内容来源） |
| `~/workspace/runform/SUPPORT.md` | 支持内容（Web 端 `/support` 页内容来源） |
| `web/` | 主仓库内暂不作为 Sprint 1 网站开发目录（仅保留历史说明） |

---

> **下一步**：CEO 审批本文档 → 确认 D1-D6 决策 → 前端在 `movenova.ai` 启动 S0-W5 脚手架 → Sprint 0 结束时产出可编译运行的网站骨架项目 → Sprint 1 开始 Landing Page 模块开发。
