# RunForm Sprint 3 Backlog：产品上线 + 全渠道营销增长

> **创建日期**：2026-05-16
> **Sprint 周期**：2026-05-26 ~ 2026-06-16（3 周）
> **Sprint 2 完成状态**：CoreMotion 管线双端对标完成，Run Sessions API 就绪，全平台 QA 通过
> **关联文档**：`product/sprint-2-backlog.md`、`marketing/sprint-3-marketing-plan.md`、`marketing/google-play-aso-v2.md`、`marketing/xiaohongshu-strategy.md`、`marketing/wechat-growth-plan.md`、`marketing/ads-placement-design.md`

---

## 一、Sprint 3 目标

**一句话**：将 RunForm 推向市场 — 完成 App Store / Google Play 上架准备，执行 Google + 微信 + 小红书三线营销，在网站和 App 内搭建广告变现基建，同时交付用户最需要的跑后分享和训练洞察功能。

---

## 二、Sprint 3 新条目总览

| ID | 标题 | 指派 | SP | 优先级 | 平台 |
|----|------|------|-----|--------|------|
| **产品 — 上线准备** |
| RF-900 | App Store Connect 上架准备（隐私标签/截图/描述） | iOS 开发 | 5 | P0 | iOS |
| RF-901 | Google Play Console 上架准备（Data safety/截图/分级） | Android 开发 | 5 | P0 | Android |
| RF-902 | 微信小程序提审准备（类目/隐私协议/功能完整性） | WeChat 开发 | 3 | P0 | WeChat |
| RF-903 | 全平台隐私政策 + 服务条款完善 | 后端开发 | 3 | P0 | 全平台 |
| **产品 — 用户功能** |
| RF-910 | RunSession 历史回放（跑步轨迹+指标时间轴动画） | iOS 开发 | 8 | P1 | iOS |
| RF-911 | 周训练洞察报告（自动生成分享卡片） | iOS 开发 | 5 | P1 | iOS |
| RF-912 | Android 周训练洞察报告 | Android 开发 | 5 | P1 | Android |
| RF-913 | 分享卡片图片生成（Canvas 渲染+小程序码） | WeChat 开发 | 3 | P1 | WeChat |
| **产品 — 性能优化** |
| RF-920 | iOS 冷启动优化（<2秒）+ 内存优化（<150MB） | iOS 开发 | 5 | P1 | iOS |
| RF-921 | Android 冷启动优化 + ANR 修复 | Android 开发 | 5 | P1 | Android |
| **营销 — Google** |
| RF-930 | Google Play ASO 优化（关键词/描述/截图文案） | 营销经理 | 3 | P0 | Android |
| RF-931 | 网站 Google SEO 优化（meta/sitemap/structured data） | 前端开发 | 3 | P0 | Web |
| RF-932 | Google Ads 搜索广告搭建（5组关键词广告组） | 营销经理 | 3 | P1 | Web |
| **营销 — 微信** |
| RF-940 | 微信公众号内容发布（8篇推文/3周） | 营销经理 | 5 | P0 | 微信 |
| RF-941 | 小程序分享卡片优化（3种场景差异化设计） | WeChat 开发 | 2 | P0 | WeChat |
| RF-942 | 微信朋友圈广告投放（素材+定向+预算） | 营销经理 | 3 | P1 | 微信 |
| **营销 — 小红书** |
| RF-950 | 小红书内容矩阵搭建（12篇笔记/3周） | 营销经理 | 5 | P0 | 小红书 |
| RF-951 | KOC 合作启动（筛选5位跑步博主+寄测） | 营销经理 | 3 | P1 | 小红书 |
| **广告变现基建** |
| RF-960 | 网站广告位搭建（Hero banner + 产品页侧边栏） | 前端开发 | 3 | P1 | Web |
| RF-961 | iOS AdMob 集成（分析结果页 banner） | iOS 开发 | 3 | P2 | iOS |
| RF-962 | Android AdMob 集成（分析结果页 banner） | Android 开发 | 3 | P2 | Android |
| RF-963 | 微信小程序激励视频广告 | WeChat 开发 | 2 | P2 | WeChat |

**总计**：26 个条目，96 SP（约 3 周，5 人并行）

- iOS 开发：4 个条目，21 SP
- Android 开发：4 个条目，18 SP
- WeChat 开发：4 个条目，10 SP
- 前端开发：2 个条目，6 SP
- 后端开发：1 个条目，3 SP
- 营销经理：6 个条目，22 SP

---

## 三、优先级说明

| 优先级 | 含义 | Sprint 3 处理策略 |
|--------|------|-------------------|
| **P0** | 上线阻塞 + 核心获客渠道 | Week 1-2 必须完成 |
| **P1** | 用户留存 + 辅助获客 | Week 2-3 尽力交付 |
| **P2** | 变现基建 | Week 3 有余力时做 |

---

## 四、Week-by-Week 排期

### Week 1（5/26 - 5/30）：上线准备 + 营销基建

| 开发者 | 任务 |
|--------|------|
| iOS 开发 | RF-900 App Store 上架准备 |
| Android 开发 | RF-901 Google Play 上架准备 |
| WeChat 开发 | RF-902 小程序提审准备 |
| 后端开发 | RF-903 隐私政策/TOS |
| 前端开发 | RF-931 网站 SEO |
| 营销经理 | RF-930 ASO 优化, RF-940 公众号首3篇, RF-950 小红书首4篇 |

### Week 2（6/2 - 6/6）：用户功能 + 广告投放

| 开发者 | 任务 |
|--------|------|
| iOS 开发 | RF-910 RunSession 回放, RF-920 性能优化 |
| Android 开发 | RF-912 周洞察, RF-921 性能优化 |
| WeChat 开发 | RF-913 分享卡片, RF-941 小程序分享优化 |
| 前端开发 | RF-960 网站广告位 |
| 营销经理 | RF-932 Google Ads, RF-942 微信广告, RF-951 KOC 合作 |

### Week 3（6/9 - 6/13）：变现 + 收尾

| 开发者 | 任务 |
|--------|------|
| iOS 开发 | RF-961 AdMob 集成, RF-911 周洞察 |
| Android 开发 | RF-962 AdMob 集成 |
| WeChat 开发 | RF-963 激励视频广告 |
| 营销经理 | 数据复盘 + 下阶段计划 |

---

## 五、成功指标

| 指标 | 当前基线 | Sprint 3 目标 |
|------|---------|---------------|
| 网站月 UV | ~200 | ≥ 3,000 |
| Google 自然搜索点击 | ~0 | ≥ 500/月 |
| 微信小程序 DAU | ~30 | ≥ 200 |
| 小红书品牌搜索量 | ~0 | ≥ 1,000/月 |
| 邮件订阅列表 | ~50 | ≥ 500 |
| App 广告展示收入 | $0 | ≥ $50/月 |
| 全渠道获客成本 (CAC) | N/A | < ¥5 |

---

## 六、暂停项

| 条目 | 原因 |
|------|------|
| RF-205 Strava OAuth | CEO 指令暂停 |
| Apple Watch / Wear OS | 延至 Sprint 4 |
| SwimForm MVP | 延至 Sprint 4 |
| CoreML 模型量化 | 需真机数据后再优化 |

---

## 七、风险

| 风险 | 等级 | 应对 |
|------|------|------|
| App Store 审核被拒 | 🟡 中 | 预留 1 周缓冲，提前自查审核指南 |
| 微信审核隐私要求升级 | 🟡 中 | 隐私政策先于提审完成 |
| 小红书内容冷启动慢 | 🟡 中 | 前 4 篇用高互动选题测试 |
| Google Ads ROI 低 | 🟢 低 | 先用 $50 小预算测试，3 天优化 |
| AdMob 审核延迟 | 🟢 低 | P2 优先级，不阻塞主线 |
