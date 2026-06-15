# movenova.ai 网站上线周 — 营销文案与发布策略

> **版本**：v1.0
> **日期**：2026-05-13
> **营销经理**：Jordan
> **用途**：Website Launch Week 所有文案素材集中管理，供前端开发 + 产品经理直接取用
> **品牌**：RunForm（网站域名 movenova.ai）
> **设计调性**：Dark theme / mint green accent / 专业但不冰冷

---

## 一、Hero CTA 文案变体（A/B 测试池）

> 设计说明：主 CTA 按钮放置在 Landing Page 首屏 Hero 区域。以下提供 6 组变体（中英各 3 组），上线后通过 Google Optimize / 自建 A/B 框架轮换测试，以首周 CTA 点击率（CTR）为 KPI。

### 1.1 中文 Hero CTA 变体

#### 变体 A：痛点切入型（主力上线版）

```
Headline：跑得对，比跑得快更重要
Subhead：拍一段跑步视频，AI 在 30 秒内分析你的 15+ 项生物力学指标。
          看看你的跑姿和基普乔格差在哪。
CTA Button：免费分析我的跑姿
```

**设计逻辑**：切入跑者最深层的「怕受伤」焦虑，同时用 Kipchoge 对比制造好奇心缺口。CTA 用「免费」+「我」削弱心理阻力。

---

#### 变体 B：好奇心驱动型

```
Headline：你的跑姿，真有你以为的那么好吗？
Subhead：90% 的跑者都有至少一项跑姿问题——你中招了吗？
          上传视频，AI 告诉你答案。
CTA Button：上传视频 · 免费分析
```

**设计逻辑**：先用否定句制造认知失调，再用「90%」社会证据加深焦虑，最后用 AI 提供一个出口。适合对跑步已有自信但隐隐怀疑的中级跑者（RunForm 核心 TA）。

---

#### 变体 C：数据控 + 精英对比型

```
Headline：你和基普乔格，跑姿差在哪？
Subhead：15+ 生物力学指标对比报告，步频、触地时间、躯干倾角一目了然。
          拍视频 → AI 分析 → 对比报告。
CTA Button：立即对比我的跑姿
```

**设计逻辑**：「基普乔格」中国跑圈认知度极高（马拉松之神），制造身份投射。CTA 用「对比」而非「分析」，强调社交传播属性。适合知乎/Reddit 跑者群体。

---

### 1.2 English Hero CTA Variants

#### Variant A: Pain Point (Primary)

```
Headline: AI That Understands HOW Your Body Runs
Subhead: Upload a video. Get biomechanical analysis of 15+ metrics in 30 seconds.
          Compare your form against Kipchoge's.
CTA Button: Analyze My Run — Free
```

**Rationale**: Anchors on the core value proposition ("HOW" not "HOW FAR"). Borrows Kipchoge's global recognition for instant curiosity.

---

#### Variant B: Curiosity Gap

```
Headline: Your Running Form Is Probably Wrong.
Subhead: 90% of runners have at least one form issue causing unnecessary pain.
          AI scans your video in 30 seconds. No wearables needed.
CTA Button: Check My Form Free →
```

**Rationale**: Bold claim with a specific stat. "No wearables needed" removes the #1 friction for running app onboarding.

---

#### Variant C: Data + Elite Comparison

```
Headline: Run Like Kipchoge. Or At Least Know the Difference.
Subhead: 15+ biomechanical metrics. Side-by-side elite comparison.
          Your form, decoded by AI.
CTA Button: Compare My Form →
```

**Rationale**: Self-deprecating humor ("Or At Least") lowers defense while keeping aspiration high. "Side-by-side elite comparison" is the most unique feature hook in the market.

---

### 1.3 CTA A/B 测试计划

| 维度 | 设置 |
|------|------|
| **测试平台** | movenova.ai Landing Page Hero |
| **测试周期** | Week 1-2（上线首月） |
| **核心指标** | CTA 点击率 (CTR)，次指标：跳出率、页面停留时长 |
| **流量分配** | 中文访客：三组轮换，每组 33.3% 曝光。英文访客同上。 |
| **决策门限** | 某变体 CTR 显著高于其他两组（p < 0.05）后，全量切至胜出变体 |
| **工具** | Google Optimize 或 Vercel Analytics A/B 分流 |

---

## 二、Social Proof（社会证明数据）

> 说明：以下数据为 **合理占位数字**，带 `[placeholder]` 标记。请在上线前根据实际数据替换。所有数字选取原则：(1) 可感知的社会证明，(2) 与产品功能直接关联，(3) 在跑步赛道有对比锚点。

### 2.1 中文版 Social Proof 区块

```html
<!-- Landing Page Hero 下方 social proof strip -->
<div class="social-proof-strip">
  <div class="stat">
    <span class="stat-number">15+</span>
    <span class="stat-label">生物力学分析指标</span>
  </div>
  <div class="stat">
    <span class="stat-number">30s</span>
    <span class="stat-label">完成一次跑姿分析</span>
  </div>
  <div class="stat">
    <span class="stat-number">[1,200+]</span>
    <span class="stat-label">跑者已获得跑姿报告</span>
    <span class="placeholder-tag">[placeholder]</span>
  </div>
  <div class="stat">
    <span class="stat-number">4.9 / 5</span>
    <span class="stat-label">跑者评分 [placeholder]</span>
  </div>
</div>
```

**数字选取说明**：
- **15+**：真实功能数字（已有 PoseExtractor 21 项指标，保守报 15+）
- **30s**：产品真实体验目标（Time-to-Value < 3min 上位目标，分析本身 30s 内）
- **[1,200+]**：placeholder，上线后替换为真实分析次数。冷启动期启动数字建议：如果内测期间有 20 人 × 3 次分析 = 60，可用「数百名跑者」。如果有 10 个种子用户 + 3 周内容引流带来 10 个/天 = 200+ 时改为此数字。
- **4.9 / 5**：placeholder 评分，建议在 TestFlight / 内测阶段收集 5-10 条真实评分后再上线。如果上线时无评分，此条删除或替换为「由跑步教练与运动科学家联合研发」。

---

### 2.2 English Social Proof Strip

```html
<div class="social-proof-strip">
  <div class="stat">
    <span class="stat-number">15+</span>
    <span class="stat-label">Biomechanical Metrics</span>
  </div>
  <div class="stat">
    <span class="stat-number">30s</span>
    <span class="stat-label">Per Analysis</span>
  </div>
  <div class="stat">
    <span class="stat-number">[1,200+]</span>
    <span class="stat-label">Reports Generated</span>
    <span class="placeholder-tag">[placeholder]</span>
  </div>
  <div class="stat">
    <span class="stat-number">[4.9/5]</span>
    <span class="stat-label">Runner Rating</span>
    <span class="placeholder-tag">[placeholder]</span>
  </div>
</div>
```

### 2.3 Placeholder 替换指南

| Placeholder | 当前建议值 | 替换触发条件 | 替换为 |
|------------|-----------|-------------|--------|
| `[1,200+] 跑者已获得跑姿报告` | 用户基数不足时不显示此行 | 真实分析次数 > 50 | 真实数字向上取整（如 58 → 60+） |
| `[1,200+] Reports Generated` | 同上 | 同上 | 同上 |
| `[4.9/5]` 跑者评分 | 无评分时不显示 | App Store / TestFlight 评分 ≥ 3 条 | 真实平均分，取一位小数 |
| `[4.9/5]` Runner Rating | 同上 | 同上 | 同上 |

**冷启动备选方案**（如果上线时无任何社会证明数据）：
替换为信任背书型：
```
中文：「由跑步教练 × 运动科学家联合研发」
      「基于生物力学研究文献验证」
英文："Built with running coaches & sports scientists"
      "Backed by biomechanics research"
```

---

## 三、平台下载徽章文案

### 3.1 中文版下载区块

```
下载 RunForm，开始改善你的跑姿

[App Store 徽章]  [Google Play 徽章]  [微信小程序]
   即将上线          即将上线            扫码体验
```

**中文徽章按钮文案**：
| 平台 | 按钮文案 | 状态 |
|------|---------|------|
| iOS App Store | 在 App Store 下载 | Coming Soon / 即将上线 |
| Google Play | 在 Google Play 获取 | Coming Soon / 即将上线 |
| 微信小程序 | 微信扫码体验 | 可用（小程序先行上线） |

**App Store 预约页面文案**（如果做 Pre-order）：
```
RunForm: AI 跑步姿态教练
预订现已开启 · 上线后自动下载
```

### 3.2 English Download Section

```
Download RunForm & Transform Your Running Form

[Download on the App Store]  [Get it on Google Play]  [WeChat Mini Program]
       Coming Soon                Coming Soon            Scan to Try
```

**English Badge Copy**:
| Platform | Button Text | Status |
|----------|------------|--------|
| App Store | Download on the App Store | Coming Soon |
| Google Play | Get it on Google Play | Coming Soon |
| WeChat Mini Program | Scan QR Code to Try | Available Now |

### 3.3 微信小程序引流文案（独立小程序卡片区域）

> 小程序是前 3 个月中国市场的核心转化入口。在 Landing Page 中单独给小程序一个醒目 Section。

**中文**：
```
已有微信？立刻体验
无需下载，微信扫码即刻分析你的跑步姿态
[小程序码图片]

「比我预期的更精准」—— 内测跑者
[placeholder：替换为真实评价]
```

**English**（面向海外华人 / 中国跑者）：
```
Already on WeChat? Try Now
Scan the QR code. Analyze your running form in WeChat.
No app download required.
[QR Code Image]
```

---

## 四、Email Signup 区域文案（邮件注册）

> 设计说明：Email 注册区放在 Landing Page 中下部（Hero → Features → Social Proof → Email Signup → Footer）。设计风格：深色背景 + mint green CTA 按钮。

### 4.1 中文版 Email 注册区

```
📬 想第一时间知道你的跑姿分析结果意味着什么？

注册获取 RunForm 跑步科学周报——
步频研究、伤病预防贴士、精英跑姿拆解，每周一发送。

[输入邮箱地址]  [订阅周报 →]

✅ 不收垃圾邮件  ·  随时退订  ·  每周一封
```

**设计要素**：
- Headline 用「你的跑姿分析结果意味着什么」——暗示用户已上传视频但可能看不懂报告，制造 FOMO
- 明确价值：「跑步科学周报」而非泛泛的「Newsletter」
- Trust signals：三连承诺（无垃圾/可退订/低频）消除隐私顾虑
- Button 用「订阅周报」而非「Submit」——动词化、价值化

---

### 4.2 English Email Signup Section

```
📬 Understand What Your Running Form Is Telling You

Join the RunForm weekly newsletter — cadence science,
injury prevention tips, and elite form breakdowns.
One email. Every Monday. Zero spam.

[Enter your email]  [Join the Run Club →]

✅ No spam  ·  Unsubscribe anytime  ·  One email per week
```

### 4.3 中文备选版（功能预告 + 邮件注册混合）

```
🔮 RunForm v1 即将推出
跑步中实时语音教练 — 步频、姿态、触地时间，跑步时 AI 直接告诉你。

留下邮箱，上线第一时间通知 + 解锁首月试用优惠。

[输入邮箱地址]  [抢先体验 →]

✅ 只发产品更新，不发广告
```

**使用场景**：如果 v1 尚未上线，将邮件注册与 v1 预热结合，注册转化率通常比纯「Newsletter」高 2-3 倍（因为有明确 hook）。

---

## 五、Privacy 页面引导文案

> 设计说明：Privacy 页面不是法律免责声明墙——它是建立信任的工具。用跑者能懂的语言解释数据流向，消除「AI 分析我的视频 = 隐私泄露」的恐惧。

### 5.1 中文版 Privacy 简介（`/privacy` 页首屏）

```
你的跑姿数据，属于你

在 RunForm，我们相信这个简单原则：你上传的跑步视频和分析报告是你的数据，
不是我们的资产。

🔒 视频处理完成后自动删除
   你的跑步视频仅用于生成姿态分析报告。报告生成后，原始视频
   在 24 小时内从服务器彻底删除。我们不存储、不转发、不用于
   模型训练。

🧠 AI 分析在加密环境中进行
   所有数据传输使用 TLS 1.3 加密。分析过程隔离处理，任何
   RunForm 员工无法查看你的个人跑步视频。

📊 你的分析报告由你控制
   你可以随时删除任何分析报告。报告数据存储在加密云数据库中，
   仅你本人可访问。我们永远不会将你的跑步数据出售给第三方。

🤝 我们只有一个业务模式：订阅
   RunForm 没有广告，不卖数据，不把跑者当作商品。你的订阅费
   是我们唯一的收入来源。这意味着我们的利益和你的隐私完全一致。

阅读完整隐私政策 →
```

**关键设计原则**：
- 4 个 emoji 分区（🔒🧠📊🤝），视觉化降低阅读阻力
- 每个承诺用「我们的行动 + 对你意味着什么」结构
- 最后一段「只有一个业务模式」——直接对标 Strava/Keep 的免费+广告+卖数据疑虑，把 RunForm 的商业模型变成隐私优势

---

### 5.2 English Privacy Intro (`/privacy` page hero)

```
Your Form Data Is Yours

At RunForm, we live by one principle: the running videos you upload
and the analysis we generate are YOUR data — not our asset.

🔒 Videos auto-deleted after analysis
    Your running video is used solely to generate your form report.
    Once analysis completes, the raw video is permanently deleted
    within 24 hours. We never store it, share it, or use it to train models.

🧠 AI analysis in encrypted environments
    All data transfers use TLS 1.3 encryption. Analysis runs in isolated
    environments — no RunForm employee can access your personal
    running footage.

📊 You control your reports
    Delete any analysis at any time. Your report data is stored in encrypted
    cloud databases, accessible only to you. We will never sell your
    running data to third parties.

🤝 We have exactly one business model: subscriptions
    RunForm has zero ads, zero data brokers, zero runners-as-product.
    Your subscription is our only revenue source. That means our
    incentives are 100% aligned with your privacy.

Read the full Privacy Policy →
```

### 5.3 Privacy 页面设计建议

| 要素 | 建议 |
|------|------|
| **位置** | Footer 有 `/privacy` 链接。Email 注册区下方有简短隐私承诺 |
| **语言** | 中文版 + 英文版独立页面（按 Accept-Language 自动切换） |
| **格式** | 短段落 + emoji 分区 + FAQ 折叠。避免法律文书墙式排版 |
| **合规** | 中国大陆：个人信息保护法 (PIPL) 合规声明。全球：GDPR + CCPA 基础覆盖 |

---

## 六、上线日社交媒体发布稿

> 上线日内容发布顺序：小红书（上午 10:00 黄金时段）→ 知乎（12:00）→ Reddit（对应美西时间上午 / 北京时间深夜）。三篇内容互有关联但不重复，覆盖不同受众。

---

### 6.1 小红书：上线日首发图文

**发布日期**：上线日当天，上午 10:00 CST
**发布形式**：图文笔记（9 张图 + 正文）
**目标**：种草 + 驱动微信小程序扫码体验（小红书外链受限，引导「搜索 RunForm 小程序」）

---

**标题**：
```
你的跑姿可能一直在伤你的膝盖——我用了 AI 分析后才发现
```

**正文**：
```
跑了 3 年马拉松，配速从没进过 430。
我一直以为是自己不够努力。

直到朋友推荐了一个 AI 跑姿分析工具，我随手拍了段跑步视频上传——
30 秒后出来的报告让我愣住了：

❌ 我的触地时间有 280ms（精英跑者都在 200ms 以下）
❌ 身体过度前倾 8°，每一步都给腰椎额外压力
❌ 步频只有 162——离黄金 180 还差很远

最震撼的是，它把我的跑姿和基普乔格的做了一个并排对比。
差距一目了然。

但现在我更关心的是：
如果不是这次分析，我可能永远不知道自己的跑姿问题，
继续带着错误的姿势跑下去——直到膝盖彻底罢工。

🏃 【RunForm】
・拍视频 → AI 分析 15+ 项跑步生物力学指标
・跑姿 vs 基普乔格对比（截图我放在图 3 了）
・即将推出跑步中实时语音教练——边跑边纠正

📱 微信搜「RunForm」小程序，第一次分析免费。

#跑步打卡 #跑步受伤预防 #马拉松训练 #跑步姿势 #跑步教练 #AI跑步
```

**配图计划**（9 张）：
1. 封面图：跑步受伤/膝盖痛的视觉 + 大标题「你的跑姿有问题吗？」
2. 跑姿分析报告截图（关键指标标注）
3. 我 vs 基普乔格对比图（最吸睛的一张）
4. 步频数据可视化截图
5. 躯干倾角分析截图
6. 触地时间分析截图
7. 个性化改善建议截图
8. 小程序码（可直接扫码体验）
9. 品牌 Slogan：「跑得对，比跑得快更重要」

---

### 6.2 知乎：上线日科普回答

**发布日期**：上线日当天，中午 12:00 CST
**发布形式**：回答已有热门问题（或自问自答建立话题）
**目标**：建立专业权威 + 引流小程序

---

**推荐回答的问题**（已有自然流量的长尾问题，选其一）：

首选：「跑步到底伤不伤膝盖？如果伤的话，正确的跑步姿势是怎样的？」
备选：「有哪些提升跑步技术的方法？」

---

**回答草稿（首选题「跑步伤不伤膝盖」）**：

```
先说结论：跑步本身不伤膝盖。**错误的跑步姿态，才会伤害你的膝盖。**

---

## 一、为什么你的膝盖会痛？

在 RunForm 分析了大量跑步视频后，我们发现膝盖疼痛的跑者中，
最常见的 3 个跑姿问题：

### 1. 步频过低（< 165 步/分钟）
步频越低，每一步的触地时间就越长——意味着你的膝盖承受冲击的时间也更长。
研究发现，步频从 162 提升到 180 可以减少约 20% 的膝关节负荷。
**黄金步频**：180 步/分钟（基普乔格马拉松配速下的步频正是 185-190）。

### 2. 过度跨步（Overstriding）
着地时脚在身体重心前方过远，每一步都在对膝盖施加「刹车力」。
判断方法：拍一段慢动作视频，看脚着地瞬间——如果膝盖完全伸直、
脚跟在身体前方，你的跨步幅度可能过大了。

### 3. 骨盆不稳定（髋部下坠）
跑步时骨盆在每一步都会自然下降约 2-3°。但如果下降超过 5°，
你的 IT 带和膝关节就会被反复拉扯。这是「跑步膝」最常见的生物力学原因之一。

---

## 二、怎么知道自己的跑姿有没有问题？

以前跑者只能找跑步教练（500-1000元/小时），或者自己拍视频慢放肉眼判断。
现在有更高效的方式：AI 跑姿分析。

工具会把你的跑步视频逐帧分析，提取：
- 📊 步频 (Cadence)
- 📊 触地时间 (Ground Contact Time)
- 📊 躯干倾角 (Trunk Lean Angle)
- 📊 垂直振幅 (Vertical Oscillation)
- 📊 骨盆倾斜角 (Pelvic Drop)
- ……共 15+ 项生物力学指标

然后和精英跑者的理想姿态做对比（比如基普乔格的马拉松数据），
告诉你哪项偏离了，以及怎么针对性改善。

---

## 三、说一个你可能不知道的数据

在 RunForm 分析的跑姿报告中，超过 90% 的业余跑者至少有 1 项指标偏离了
生物力学推荐范围。最常见的是步频偏低和躯干过度前倾。

但好消息是——这些全都可以纠正。一旦你**知道**自己的问题在哪，
改善的速度比想象中快很多。

---

最后说一句我心里的话：
跑步不是「意志力运动」——它是技术运动。
正确的技术让你跑得更快、更远，而且永远不会膝盖痛。

如果想知道你自己的跑姿数据——
微信搜「RunForm」小程序，拍一段视频就出报告。第一次免费。
```

**发布技巧**：
- 文末不加粗推广，自然融入产品名（「在 RunForm 分析的数据中……」），知乎社区对硬广容忍度极低，软植入效果更好
- 在知乎主页 Bio 中添加「RunForm 跑步姿态分析 | 👉 微信搜 RunForm 小程序」
- 回答发布后 24 小时内积极回复评论（知乎算法重视互动率）

---

### 6.3 Reddit: Launch Day Post on r/running

**Post Time**: 5:00 AM PST / 8:00 AM EST (aligns with US morning commute scroll)
**Subreddit**: r/running (3M+ members)
**Goal**: Build credibility, drive passive traffic, establish r/running presence

---

**Post Draft**:

**Title**:
```
I built an AI tool that analyzes your running form from a video.
It told me I've been overstriding for 2 years. Here's what I learned.
```

**Body**:
```
I've been running for 5 years, training for marathons. Like most of us,
I thought my form was fine — until I built something to check.

The tool takes a side-view video of you running (phone camera is enough)
and analyzes 15+ biomechanical metrics:
- Cadence
- Ground contact time
- Trunk lean angle
- Vertical oscillation
- Pelvic drop
- Knee drive angle
- ... and compares your form against elite benchmarks (yes, Kipchoge's data)

**What it found about MY running:**
- My cadence was 164 (elite marathoners are 180+)
- Ground contact time: 285ms (should be under 220ms for my pace)
- I was overstriding by ~8cm — every single step

I've been running with a braking force applied to my knees
for TWO YEARS and had no idea.

**Why I'm sharing this:**
I'm not here to promote (the app is free to try and the first analysis
doesn't cost anything). I'm here because I genuinely believe most of us
are running with form issues we can't feel — and the injury eventually
shows up uninvited.

**How it works:**
1. Film a 10-second side-view video of yourself running
2. Upload — the AI extracts pose landmarks frame-by-frame
3. Get your report in ~30 seconds with metrics + improvement suggestions

**The Kipchoge comparison is wild.**
Seeing your running form side-by-side with his is humbling and
incredibly useful at the same time. You can literally see where
your body is out of alignment.

**What's next:**
We're building a real-time voice coach — it watches your form WHILE
you run and gives you live cues ("increase cadence", "straighten your trunk").

—

**TL;DR:** Most of us don't know what our running form actually looks like.
I built an AI tool that shows you — and it told me I'd been making the same
mistake for 2 years without knowing.

If you want to try it: [link in comments — don't want to self-promo in post body]
```

**Comment (immediately after posting)**:
```
For those asking — the tool is called RunForm.
You can try it at movenova.ai or search "RunForm" on the App Store (iOS coming soon,
web + WeChat available now). First analysis is free.

Happy to answer any questions about how the biomechanical analysis works
or the computer vision side of it.
```

---

**Posting Rules Compliance Notes**:
- r/running self-promo rules: Generally allowed if you're active in the community and the post provides value. The word "I built" transparency is critical — no pretending to be a neutral user.
- Do NOT put link in post body — post it as a comment reply. This is the unwritten r/running etiquette, and mods are more lenient when the link is in comments.
- Timing: Tuesday/Wednesday/Thursday perform best on r/running (Monday is "weekly Q&A" sticky, weekends are race report heavy).
- Engage genuinely: Reply to every comment in the first 2 hours. Reddit's algorithm heavily weights early engagement.

---

## 七、上线周内容发布节奏总览

```
      Mon          Tue          Wed          Thu          Fri          Sat-Sun
   网站上线日    Day 2        Day 3        Day 4        Day 5        周末维护
      │           │            │            │            │             │
10:00 ├─ 小红书首帖  │            │            │            │             │
      │  (图9)     │            │            │            │             │
      │           │            │            │            │             │
12:00 ├─ 知乎回答   ├─ 知乎评论  │            ├─ 知乎回答   │             │
      │  (长文)    │  互动维护    │            │  #2 (备选题)  │             │
      │           │            │            │            │             │
14:00 ├─ 公众号推文  │            ├─ 公众号推文  │            ├─ 公众号推文  │
      │  (首发通稿) │            │  (功能深度)  │            │  (首周数据)  │
      │           │            │            │            │             │
深夜   ├─ Reddit    ├─ Reddit     ├─ Reddit     │            │             │
(PST) │  发帖       │  评论互动    │  评论互动    │            │             │
      │           │            │            │            │             │
其它   │           ├─ 小红书互动  ├─ 微博话题   ├─ 抖音测试   ├─ 竞品监测    ├─ 数据回收
      │           │  回复私信    │  蹭热点      │  短视频      │  调整内容    │  周报产出
```

**首周内容 KPI 目标**：

| 平台 | 核心指标 | 首周目标 |
|------|---------|---------|
| 小红书 | 笔记互动量（点赞+收藏+评论） | 500+ |
| 知乎 | 回答阅读量 | 5000+ |
| 公众号 | 推文阅读 + 小程序访问 | 阅读 1000+ / 小程序访问 200+ |
| Reddit | Post Karma + Comments | 50+ Karma / 30+ Comments |
| movenova.ai | 官网 UV | 500+ |
| 微信小程序 | 新用户注册 | 50+ |

---

## 八、附录：关键内容片段（可直接用于网页）

### A. Features 页面痛点 + 解决方案块（中文）

```
痛点：
「我跑了三年前的马拉松，膝盖越来越痛，但不知道是姿势问题还是训练过度。」

RunForm 的答案：
拍一段你跑步的侧面视频。AI 逐帧分析 15+ 项生物力学指标。
30 秒后，你会看到一份完整的跑姿报告：
—— 你的步频、触地时间、躯干倾角、骨盆稳定性……
—— 每个指标与精英跑者的对比（对，包括基普乔格）
—— 针对你个人跑姿问题的改善训练建议
```

### B. 基普乔格对比功能独立 Section 文案

```
Headline：
看到差距，是变好的第一步。

Body：
把你的跑步视频和基普乔格的马拉松跑姿做并排对比。
步频差了多少？触地时间长了多少？身体前倾是过还是不足？
不是崇拜偶像，而是用最好的模板看清自己的问题。

CTA：免费对比我的跑姿 →
```

### C. 网站 Footer 品牌语

```
中文：
RunForm — 跑得对，比跑得快更重要。
© 2026 RunForm. movenova.ai

英文：
RunForm — AI that understands HOW your body runs.
© 2026 RunForm. movenova.ai
```

---

> **NEXT STEP**：
> 1. 前端开发取用本文案 → Landing Page 文案填充
> 2. PM 审核所有 Feature Claim 与产品实际能力对齐
> 3. 上线日前 1 天：小红书 9 张图设计完成 + 知乎回答终稿确认 + Reddit 帖子预备
> 4. 上线日：按节奏表执行发布，实时监控数据回收
