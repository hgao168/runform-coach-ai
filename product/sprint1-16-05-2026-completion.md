# Sprint 1 完整总结

> **周期**: 2026-05-16 ~ 2026-05-23（1 周）
> **仓库**: `runform` | `movenova.ai`
> **总规模**: **116 文件** · **+15,821 / -843 行** · **8 个 commits**

---

## 目标回顾

> 暂停所有新功能开发，将 Android 和微信小程序的功能补齐至与 iOS 持平。

---

## 各平台交付

### iOS（2 条目完成）

| 条目 | 内容 | 规模 |
|------|------|------|
| RF-402 | 代码清理 + PoseExtractor 拆分 + SignalProcessing.swift（15 纯函数） | — |
| RF-403 | SwiftLint 配置 + XCTest 框架 + PoseExtractorTests（60 用例） | — |

### Android（13 条目完成 / 16 总计）

| 条目 | 内容 | 规模 |
|------|------|------|
| RF-210 | Hilt DI（ApiModule / AuthModule / DatabaseModule） | 5 文件 |
| RF-213 | API 认证（TokenManager / AuthInterceptor / EncryptedSharedPreferences） | 2 文件 |
| RF-211 | Room DB（3 Entity + 3 DAO + RunFormDatabase + MigrationHelper） | 8 文件 |
| RF-204 | 完整 i18n（zh 159 keys / nl / en，覆盖全部 Screen） | 3 文件 |
| RF-200 | 精英对比（CompareScreen / CompareResultScreen / CompareHistoryScreen / CompareViewModel / CompareModels） | 1,775 行 |
| RF-201 | 训练计划增强（MarathonPlanScreen 825L + MarathonPlanVM 186L + SavedPlansScreen 357L + EditPlanScreen 916L） | 2,284 行 |
| RF-202 | 历史趋势 Canvas 折线图（3 指标 + Tooltip） | +470 行 |
| RF-212 | JUnit5 + MockK 测试框架（4 test 文件：AppVM / CompareVM / Dao / ApiClient） | 1,041 行 |
| RF-203 | 用户反馈评分（FeedbackViewModel + FeedbackEntity/DAO） | 249 行 |
| RF-206 | 视频压缩（VideoCompressor.kt 308L，MediaCodec 720p/30fps） | 308 行 |
| RF-207 | 分享功能（Intent.ACTION_SEND，分析结果页 + 对比页） | — |
| RF-208 | 跑者档案扩展（鞋码/腿长/跑鞋品牌） | — |

**延至 Sprint 2**: RF-205 Strava（P1）、RF-209 实时引导（P2）、RF-214 R8/Keystore（P1）、RF-215 Crashlytics（P2）

### 微信小程序（9 条目全部完成）

| 条目 | 内容 | 规模 |
|------|------|------|
| RF-300 | 精英对比接入（/compare API） | compare.js |
| RF-301 | 历史趋势图表（Canvas 折线图） | history.js 461L |
| RF-302 | 用户反馈评分（5 星 + 离线同步） | result 页 |
| RF-303 | 视频压缩上传（wx.compressVideo 智能跳过） | video-compress.js 93L |
| RF-304 | 分享功能（onShareAppMessage + Canvas 截图） | result + compare |
| RF-305 | 语音教练（voice-coach.js 419L + prompts.json 20条 + TTS 脚本） | 696 行 |
| RF-306 | CloudBase 接入准备（cloudbase.js 309L + 云函数模板） | 329 行 |
| RF-307 | 跑者档案完善（nickname 字段补齐） | profile 页 |
| RF-308 | 多角度拍摄选择 UI（chip selector + i18n） | analyze 页 |

### 后端（2 条目完成）

| 条目 | 内容 |
|------|------|
| RF-400 | /compare API 完善（用户 vs 精英 + 自定义对比） |
| RF-401 | POST /feedback API |

### QA / CI（1 条目完成）

| 条目 | 内容 |
|------|------|
| RF-404 | GitHub Actions CI（pytest + ruff，6 个 workflow） |

### Website（movenova.ai）

| 交付 | 内容 |
|------|------|
| 跨平台一致性 | CrossPlatformSection（F1-F27 功能对齐审计表） |
| Changelog | Sprint 1 里程碑时间线 |
| 产品展示 | ProductShowcaseSection（5 产品矩阵 + 全家福 + 各产品图） |
| 使命区块 | MissionSection（MoveNovaMission.png + 愿景引语） |
| Products 页 | `/products` 专属页面（RunForm 详情 + 平台支持 + 技术亮点） |
| 品牌图片 | 7 张产品/品牌图片嵌入 Home + Products 页 |
| 产品状态 | 仅 RunForm "Available Now"，其余 "Coming Soon" |
| 部署 | 3 次 Cloudflare Pages 部署，零构建错误 |

---

## 对齐审计结果

基于 `sprint-1-revised-backlog.md` 中的 F1-F27 审计表：

| 指标 | 目标 | 实际 |
|------|------|------|
| Android P0 完成率 | 100% | 100%（7/7） |
| WeChat P0 完成率 | 100% | 100%（2/2） |
| Android 功能覆盖率 | ≥80% iOS | ~85%（22/26） |
| WeChat 功能覆盖率 | ≥80% iOS | ~88%（排除平台限制项） |
| CI 流水线 | 通过 | pytest + ruff + 6 workflows |
| iOS Lint/Test | SwiftLint + 5 测试 | ✅ |

---

## 关键数字

| 维度 | 数据 |
|------|------|
| 总文件变更 | 116 |
| 新增代码 | +15,821 行 |
| 删除代码 | -843 行 |
| Commits | 8（runform）+ 3（movenova.ai） |
| P0 条目 | 14/14 完成 |
| P1 条目 | 7/8 完成 |
| P2 条目 | 3/6 完成 |
| 唯一延至 Sprint 2 | RF-205 Strava、RF-209 实时引导、RF-214/215 |

---

## Commits 记录

### runform 仓库

1. Sprint 1 Week 2: Android Room DB + i18n, WeChat RF-302/303/304, CompareScreen stub — 57 files, +5,531/-514
2. Sprint 1 Week 2: RF-200 Android Compare + RF-305 WeChat Voice — 13 files, +2,668/-106
3. Sprint 1 Week 2: RF-212 Unit tests (1,041L) + RF-203 Feedback (249L) — 18 files, +1,895/-8
4. Sprint 1 Week 2: RF-202 History trend charts (+470L Canvas) — 5 files, +673/-2
5. Sprint 1 Week 2: RF-201 Marathon training plan (1,011L) — 3 files, +1,137/-4
6. Sprint 1 Week 3: Android RF-201 收尾 + P1 batch + WeChat 收尾 — 23 files, +2,370/-6

### movenova.ai 仓库

7. Sprint 1 Week 2: Cross-platform parity + Changelog + Product showcase — 15 files, +1,135/-322
8. Website: Embed brand images into homepage — 13 files, +212/-11
9. Website: Fix product status, add Products nav+page, fix mission image crop — 7 files, +348/-18
