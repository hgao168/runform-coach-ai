# RunForm v1 发布就绪检查清单

> 文档版本：v1.0
> 作者：Jordan（营销经理）
> 日期：2026-05-14
> 状态：Sprint 0 交付 — 在 Sprint 1 结束 / v1 发布前逐项核验
> 用途：确保 v1 发布时所有必选项已完成，无遗漏

---

## 检查清单符号说明

| 符号 | 含义 |
|:----:|------|
| ⬜ | 未开始 / 待完成 |
| 🔄 | 进行中 |
| ✅ | 已完成并验证 |
| ⚠️ | 有阻塞 / 需要决策 |
| ❌ | 已决定不做 (需注明原因) |

---

## 一、ASO & 商店上架 (App Store + Google Play)

### 1.1 App Store (iOS)

| # | 检查项 | 状态 | 负责人 | 截止日期 | 备注 |
|---|--------|:----:|--------|---------|------|
| 1 | App Store 标题终稿确认 (30字符限制) | ⬜ | Jordan + PM | Sprint 1 End | 当前：`RunForm-AI跑步姿态教练` |
| 2 | App Store 副标题终稿确认 (30字符限制) | ⬜ | Jordan + PM | Sprint 1 End | 当前：`跑步伤病预防与跑姿分析` |
| 3 | 关键字域填充 (100字符) | ⬜ | Jordan | Sprint 1 End | 见 `aso-keywords-v1.md` 第二节 |
| 4 | 应用描述 (Description) 前三行含核心关键词 | ⬜ | Jordan | Sprint 1 End | 英文 + 中文双版本 |
| 5 | 应用截图 (至少 3 套：iPhone 6.7" + 6.5" + 5.5") | ⬜ | 设计师 | Sprint 1 End | Screenshot A/B 测试预留 2 套素材 |
| 6 | 预览视频 (App Preview, 15-30s) | ⬜ | 设计师 | Sprint 1 End | 前 5 秒必须钩住用户 |
| 7 | App Store 评分 & 评论策略文档 | ⬜ | Jordan | Sprint 1 Mid | 「啊哈时刻」后触发评价弹窗的设计说明 |
| 8 | 隐私政策 (Privacy Policy) URL 可访问 | ⬜ | 前端 + 法务 | Sprint 1 End | movenova.ai/privacy |
| 9 | 服务条款 (Terms of Service) URL 可访问 | ⬜ | 前端 + 法务 | Sprint 1 End | movenova.ai/terms |
| 10 | App Store Connect 产品页优化 (Product Page Optimization) 设置 | ⬜ | Jordan | Sprint 1 End | 如有条件做 CVR 测试 |
| 11 | 应用内购买 (IAP) 项目创建并审核通过 | ⬜ | iOS Dev | Sprint 1 End | 订阅等级确认 |
| 12 | App Store 分类选择确认 | ⬜ | Jordan + PM | Sprint 1 End | 推荐：Health & Fitness / Sports |
| 13 | 年龄分级 (Age Rating) 设置 | ⬜ | iOS Dev | Sprint 1 End | 预计 4+ |
| 14 | 版权信息填写 | ⬜ | Legal | Sprint 1 End | © 2026 RunForm |
| 15 | App 审核提交 | ⬜ | iOS Dev | Sprint 1 + 3d | 为审核预留 3 天缓冲 |

### 1.2 Google Play (Android)

| # | 检查项 | 状态 | 负责人 | 截止日期 | 备注 |
|---|--------|:----:|--------|---------|------|
| 1 | Google Play 标题终稿 (50字符) | ⬜ | Jordan | Android v1.1 | `RunForm: AI Running Form Coach & Injury Prevention` |
| 2 | 短描述终稿 (80字符) | ⬜ | Jordan | Android v1.1 | 见 `aso-keywords-v1.md` 第四节 |
| 3 | 长描述终稿 (含关键词密度 2-3%) | ⬜ | Jordan | Android v1.1 | 4000 字符英文版 + 中文版 |
| 4 | 功能图片 (Feature Graphic) | ⬜ | 设计师 | Android v1.1 | 1024x500px |
| 5 | 应用截图 (手机 + 平板) | ⬜ | 设计师 | Android v1.1 | 至少 4 张 |
| 6 | 隐私政策链接 | ⬜ | 前端 | Android v1.1 | 同 iOS |
| 7 | 内容分级问卷 | ⬜ | Android Dev | Android v1.1 | |
| 8 | Google Play Console 应用创建 | ⬜ | Android Dev | Android v1.1 | |

---

## 二、网站 (movenova.ai)

| # | 检查项 | 状态 | 负责人 | 截止日期 | 备注 |
|---|--------|:----:|--------|---------|------|
| 1 | Landing Page 完整上线 (Dark theme + mint green accent) | ✅ 已上线 | 前端 | 已完成 | 当前可访问 |
| 2 | Hero CTA A/B 测试配置就绪 | ⬜ | 前端 | Sprint 1 End | 6 组变体 (中英各 3)，Google Optimize 或 Vercel Analytics |
| 3 | Social Proof 数字更新 (非 Placeholder) | ⬜ | Jordan + PM | 上线前 | 移除所有 `[placeholder]` 标记 |
| 4 | 下载徽章区域就绪 (App Store + Google Play + 小程序) | ⬜ | 前端 | Sprint 1 End | "Coming Soon" → 上线后替换为真实链接 |
| 5 | Email 注册功能可用 + 自动回复流程 | ⬜ | 前端 + 后端 | Sprint 1 End | 订阅后自动发送欢迎邮件 |
| 6 | Privacy 页面可访问 (movenova.ai/privacy) | ⬜ | 前端 + 法务 | Sprint 1 End | 中文 + 英文独立页面 |
| 7 | Terms 页面可访问 (movenova.ai/terms) | ⬜ | 前端 + 法务 | Sprint 1 End | |
| 8 | SEO Meta Tags (title, description, og:image) | ⬜ | 前端 | Sprint 1 End | 中英文双语 |
| 9 | Google Analytics / Vercel Analytics 部署 | ⬜ | 前端 | Sprint 1 Mid | UTM 参数追踪配置 |
| 10 | 网站性能优化 (Lighthouse Score ≥ 90) | ⬜ | 前端 | Sprint 1 End | |
| 11 | 网站移动端适配验证 | ⬜ | QA | Sprint 1 End | |

---

## 三、社交媒体 & 内容渠道

### 3.1 账号矩阵

| # | 平台 | 检查项 | 状态 | 负责人 | 备注 |
|---|------|--------|:----:|--------|------|
| 1 | 知乎 | RunForm 官方账号注册并完善主页 | ⬜ | Jordan | Bio 含小程序引流信息 |
| 2 | 小红书 | RunForm 官方账号注册 | ⬜ | Jordan | |
| 3 | 微信公众号 | RunForm 公众号注册并认证 | ⬜ | Jordan | 需企业认证 (300元/年) |
| 4 | Reddit | u/RunForm 账号注册 | ⬜ | Jordan | 先积累 Karma 再发帖 |
| 5 | B站 | RunForm 官方账号注册 | ⬜ | Jordan | |
| 6 | 微博 | RunForm 官方账号注册 | ⬜ | Jordan | |
| 7 | Instagram | @runform.ai 账号注册 | ⬜ | Jordan | |
| 8 | TikTok | @runform.ai 账号注册 | ⬜ | Jordan | |
| 9 | YouTube | RunForm 频道创建 | ⬜ | Jordan | |
| 10 | Product Hunt | 创作者账号注册 + 产品页面草稿 | ⬜ | Jordan | v1 发布日做 PH Launch |

### 3.2 上线日内容就绪

| # | 检查项 | 状态 | 负责人 | 备注 |
|---|--------|:----:|--------|------|
| 1 | 知乎深度回答终稿确认 | ⬜ | Jordan | 「膝盖痛怎么跑步」— 已提供草稿 |
| 2 | 小红书图 9 张设计完成 | ⬜ | 设计师 | 上线日前 2 天完成 |
| 3 | 小红书文案终稿确认 | ⬜ | Jordan | 已提供草稿 |
| 4 | Reddit r/running 帖子终稿确认 | ⬜ | Jordan | 已提供草稿 |
| 5 | 微信公众号首发推文终稿 | ⬜ | Jordan | |
| 6 | 公众号推文排版完成 (含小程序卡片) | ⬜ | Jordan | 上线日前 1 天 |
| 7 | 微博话题蹭热点内容预备 | ⬜ | Jordan | 上线日当天确认热点 |
| 8 | 抖音测试视频拍摄/剪辑完成 | ⬜ | Jordan + 设计师 | |

---

## 四、KOL & 媒体关系

| # | 检查项 | 状态 | 负责人 | 截止日期 | 备注 |
|---|--------|:----:|--------|---------|------|
| 1 | KOL 联系名单终稿 (中国 10 人 + 海外 10 人) | ⬜ | Jordan | Sprint 1 Mid | 含粉丝数、内容风格、合作方式 |
| 2 | KOL 合作方案模板 (免费评测 + 专属链接) | ⬜ | Jordan | Sprint 1 Mid | |
| 3 | 首批 3-5 位 KOL 评测邀请发出 | ⬜ | Jordan | Sprint 1 End | 确保 v1 上线时有评测内容 |
| 4 | v1 PR 媒体通稿草案 (中文 + 英文) | ⬜ | Jordan | Sprint 1 End | 「跑步中实时语音教练」为核心 Hook |
| 5 | 媒体联系人名单 (跑步/科技/健身媒体) | ⬜ | Jordan | Sprint 1 Mid | |
| 6 | Product Hunt Launch 素材包准备 | ⬜ | Jordan | Sprint 1 End | GIF/截图/文案/Tagline |

---

## 五、数据分析 & 追踪

| # | 检查项 | 状态 | 负责人 | 截止日期 | 备注 |
|---|--------|:----:|--------|---------|------|
| 1 | Firebase Analytics / App 事件埋点上线 | ⬜ | iOS Dev | Sprint 1 End | 所有 PRD 中的 Success Metrics 指标可追踪 |
| 2 | Firebase Crashlytics 上线 | ⬜ | iOS Dev | Sprint 1 End | |
| 3 | UTM 参数体系建立并文档化 | ⬜ | Jordan | Sprint 1 Mid | 所有外链统一 UTM 命名规范 |
| 4 | App Store Connect Analytics 开通 | ⬜ | iOS Dev | Sprint 1 End | |
| 5 | Google Play Console 数据面板配置 | ⬜ | Android Dev | Android v1.1 | |
| 6 | 营销数据看板 (Dashboard) 搭建 | ⬜ | Jordan | Sprint 2 | 第一版可用 Google Sheets |
| 7 | 微信小程序数据统计接入 | ⬜ | 微信 Dev | Sprint 1 End | |
| 8 | Email 注册转化漏斗追踪 | ⬜ | 前端 + 后端 | Sprint 1 End | |

---

## 六、小程序 (微信生态)

| # | 检查项 | 状态 | 负责人 | 截止日期 | 备注 |
|---|--------|:----:|--------|---------|------|
| 1 | 小程序名称及描述 ASO 优化 | ⬜ | Jordan + 微信 Dev | Sprint 1 Mid | 「跑步姿态」「AI跑步」等关键词融入 |
| 2 | 小程序码设计 (用于所有营销物料) | ⬜ | 设计师 | Sprint 1 End | |
| 3 | 朋友圈分享卡片文案 + 图片 | ⬜ | Jordan + 设计师 | Sprint 1 End | 跑后自动生成的分享图 |
| 4 | 微信搜一搜关键词覆盖验证 | ⬜ | Jordan | Sprint 1 End | 搜索「跑步姿态」「AI跑步」能否找到 |
| 5 | 小程序首次体验免费流程验证 | ⬜ | QA | Sprint 1 End | |

---

## 七、法律 & 合规

| # | 检查项 | 状态 | 负责人 | 截止日期 | 备注 |
|---|--------|:----:|--------|---------|------|
| 1 | 隐私政策中英文版终稿 + 法律审核 | ⬜ | 法务 | Sprint 1 End | GDPA/PIPL 合规声明 |
| 2 | 服务条款终稿 | ⬜ | 法务 | Sprint 1 End | |
| 3 | App 数据收集与使用声明 (App Store 隐私标签) | ⬜ | PM + 法务 | Sprint 1 End | 视频处理/传感器数据的隐私说明 |
| 4 | 图像/视频数据处理合规审查 | ⬜ | 法务 + 后端 | Sprint 1 End | 确认「24h内删除」可在技术端实现 |
| 5 | 商标申请 (RunForm) | ⬜ | Legal | Sprint 2 | 可延期但不应忘记 |

---

## 八、v1 产品功能就绪

> 以下检查项来自 PRD Must Have (M1-M5)，仅列出营销需要确认的点。

| # | 检查项 | 状态 | 负责人 | 备注 |
|---|--------|:----:|--------|------|
| 1 | v1 实时步频检测 & 语音播报 (M1) 功能完成 | ⬜ | iOS Dev | Sprint 1 核心交付 |
| 2 | 跑步结束后姿态总结报告 (M4) 可生成且可分享 | ⬜ | iOS Dev | 分享图 = 关键裂变资产 |
| 3 | 跑步历史记录 & 趋势 (M5) 可用 | ⬜ | iOS Dev | |
| 4 | Me vs Kipchoge 跑姿对比功能正常运行 | ⬜ | 后端 + iOS Dev | 核心传播钩子 |
| 5 | App 启动时间 < 2s (护栏指标) | ⬜ | iOS Dev | |
| 6 | Crash-free rate ≥ 99.5% | ⬜ | QA | |
| 7 | 首次跑步分析免费 (定价策略支持) | ⬜ | PM + iOS Dev | Sprint 1 需技术确认 |

---

## 九、团队 & 流程就绪

| # | 检查项 | 状态 | 负责人 | 备注 |
|---|--------|:----:|--------|------|
| 1 | 上线日值班表确认 (技术+客服+营销) | ⬜ | PM | 至少 3 人覆盖 24h |
| 2 | 上线日应急预案 (回滚方案 + 紧急联系人) | ⬜ | PM + Tech Lead | |
| 3 | 用户反馈收集渠道就绪 (App 内 + 邮件 + 社群) | ⬜ | PM | |
| 4 | 客服 FAQ 文档编写 | ⬜ | Jordan + PM | |
| 5 | 首次营销周报模板就绪 | ⬜ | Jordan | |

---

## 十、CEO 决策项 (Sprint 0 产出)

| # | 决策项 | 当前建议 | 状态 | 备注 |
|---|--------|---------|:----:|------|
| D1 | 市场优先级：中国 vs 全球 | 前 3 月聚焦中国，全球被动获取 | ⚠️ 待 CEO 拍板 | |
| D2 | 内容驱动 vs 内容+投放 | 首月纯内容 → 2-3 月加投放 | ⚠️ 待 CEO 拍板 | |
| D3 | 中文品牌名：RunForm vs 跑范 | 现阶段统一 RunForm | ⚠️ 待 CEO 拍板 | |
| D4 | v1 PR 策略：正式发布 vs 低调上线 | 建议正式 PR 发布 | ⚠️ 待 CEO 拍板 | |
| D5 | 定价传播策略：公开 vs 隐藏定价 | 建议先体验后定价 | ⚠️ 待 CEO 拍板 | |

---

## 十一、上线前 7 天冲刺清单

```
T-7:  所有商店素材终稿确认 (截图/视频/文案)
T-6:  KOL 评测邀请全部发出，确认至少 3 位接受
T-5:  上线上线日所有内容终稿锁定 (不再修改文案)
T-4:  小程序码 + App Store 链接最终确认
T-3:  App Store 提交审核 (预留 3 天审核期)
T-2:  所有社交平台账号注册完毕、主页完善
T-1:  上线日值班表确认 + 应急预案演练
T-0:  LAUNCH 🚀
```

---

> **下一步**：Sprint 1 启动后，逐项推进清单。每周五 PM Review 检查清单进度。上线前 7 天进入冲刺模式，T-3 前所有必选项必须 `✅`。
