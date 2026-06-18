# WeChat 小程序 vs iOS 功能差距审计报告

> 审计日期：2026-05-25  
> 审计人员：engineering-wechat-mini-program-developer  
> WeChat 路径：~/workspace/runform/wechat/  
> iOS 路径：~/workspace/runform/ios/RunFormCoachAI/

---

## 一、逐项对照审计

### 1. 视频分析结果展示 (AnalysisResultView ↔ result/)

**状态：✅ 完成**

| 对比维度 | iOS (AnalysisResultView) | WeChat (result/) | 差距 |
|----------|--------------------------|-------------------|------|
| 评分展示 | Score card with confidence % | 英雄卡片 + 进度条 + 总分 % | 一致 |
| 指标详情 | Metrics section (good/needs-work status) | 指标网格含颜色编码 (绿/橙/红) | 一致 |
| 问题列表 | Issues section with severity + exercises | Insights 含严重度标签 + 纠正练习 | WeChat 多了视频教程搜索链接 |
| 分享 | Share sheet via system | 多层分享：系统分享 + Canvas 生成卡片 + 保存相册 | WeChat 更丰富 |
| 广告 | Google AdMob banner | 激励视频广告（RF-963） | 实现方式不同 |
| 语音教练 | 无 | 语音播报分析结果（RF-305） | **WeChat 独有** |
| 反馈评分 | 嵌入式 FeedbackView | 内置星级评分 + 文字评论 + 离线缓存 | **WeChat 更完整** |
| UGC 投稿 | 无 | UGC 内容提交模态框（RF-604） | **WeChat 独有** |
| 动态分享模板 | archaeology/kipchoge/weekly/analysis 四场景 | 同四场景分享标题（RF-941） | 一致 |

**结论**：WeChat result 页面功能实际上比 iOS 更丰富（多了语音教练、UGC 投稿），核心分析展示完整。

---

### 2. 历史记录 + 趋势图表 (HistoryView + HistoryTrendComponents ↔ history/)

**状态：✅ 完成**

| 对比维度 | iOS | WeChat (history/) | 差距 |
|----------|-----|-------------------|------|
| 历史列表 | HistoryView: 列表 + feedback pills | 评分圆环 + 日期/摘要列表 | 一致 |
| 趋势图表 | HistoryTrendComponents: Sparkline + TrendCard（SwiftUI 原生） | Canvas 2D 手绘多线图：步频/振幅/触地三条线 | WeChat 实现更定制化 |
| 图表交互 | 静态展示 | 点击 Tooltip 显示数据点详情 | **WeChat 更优** |
| 里程碑 | 无 | 里程碑检测 + 庆祝弹窗 + 分享卡片（RF-605） | **WeChat 独有** |
| 分享 | 无 | 分享记录 + 保存到相册 | **WeChat 独有** |

**结论**：WeChat history 页面不仅完整，还比 iOS 多了里程碑检测和图表交互功能。

---

### 3. 精英对比全流程 (CompareView + CompareResultView ↔ compare/)

**状态：⚠️ 部分完成（缺少对比结果详情页）**

| 对比维度 | iOS | WeChat (compare/) | 差距 |
|----------|-----|-------------------|------|
| 运动员列表 | CompareView: 列表选择 | athlete-card 列表 + 运动项目/国籍/成就 | 基本一致 |
| 对比发起 | PoseMetrics → API | 本地 lastAnalysisResult 提取 → API | 基本一致 |
| **相似度评分** | CompareResultView: 圆环匹配度 % | **无** | ❌ 缺失 |
| **教练点评** | coachingNarrative 卡片 | **无** | ❌ 缺失 |
| **最大差距分析** | topGaps 列表 | **无** | ❌ 缺失 |
| 指标对比表 | MetricComparisonRow: 进度条 + elite基准线 | 简单表格（用户值/精英值/差距+颜色） | ⚠️ WeChat 较简单 |
| 运动员简介 | athleteBioCard | 基本信息 + 成就列表 | 基本一致 |
| 分享 | 无 | Canvas 对比分享卡 + 保存相册 | **WeChat 独有** |

**具体差距**：
- iOS CompareResultView 是一个独立的对比结果页，包含相似度环形图、AI 教练叙事点评、最大差距分析
- WeChat 仅在 compare 页面内嵌简单的指标对比表，缺少 CompareResultView 的丰富交互

---

### 4. 训练计划含马拉松 (PlanBuilderView + MarathonPlanDetailView ↔ plan/)

**状态：❌ 严重缺失**

| 对比维度 | iOS | WeChat (plan/) | 差距 |
|----------|-----|-------------------|------|
| 基础周计划 | 周跑量输入 + 目标选择 + 天选择 + 伤病标记 | 周跑量滑块 + 目标芯片 + 天选择 + 伤病开关 | 基本一致 |
| **马拉松模式** | MarathonPlanDetailView: 阶段分组、每周目标里程、长跑里程、关键训练课、周训练活动 | **完全不存在** | ❌❌ 严重缺失 |
| **比赛模式** | racePlanDetailView: 比赛日计划 | **完全不存在** | ❌❌ 严重缺失 |
| 生成类型切换 | weekly/marathon/race 三选一 | 仅 weekly | ❌ 缺失 |
| Strava 集成 | Strava 数据同步 | 无 | ❌ 缺失（WeChat 生态限制） |
| 手动编辑计划 | ManualNextWeekPlanEditor | 无 | ❌ 缺失 |
| 已保存计划 | SavedPlansView | 本地存储（无查看页） | ⚠️ 部分缺失 |
| 计划规模 | 951 行 SwiftUI | 179 行 JS | WeChat 功能量约为 iOS 的 20% |

**具体差距**：
- iOS PlanBuilderView 有 3 种生成模式（周计划/马拉松/比赛），WeChat 仅有周计划
- iOS MarathonPlanDetailView 展示完整的马拉松训练阶段（基础期→强化期→巅峰期→减量期），每阶段含周目标里程、长跑里程、关键训练课描述
- WeChat plan 只有 179 行代码，仅实现了最基础的周计划生成表单

---

### 5. 用户反馈评分 (FeedbackView ↔ ?)

**状态：⚠️ 功能存在但集成方式不同**

| 对比维度 | iOS | WeChat | 差距 |
|----------|-----|--------|------|
| 独立组件 | FeedbackView: rating picker + comment | 内嵌在 result.js 中（RF-302） | ⚠️ 非独立页面 |
| 评分方式 | 预设枚举（partlyAccurate 等） | 1-5 星评分 | 功能等价 |
| 文字评论 | TextField optional | textarea 500 字限制 | 一致 |
| 离线支持 | 无 | 离线缓存 + 自动同步 | **WeChat 更优** |
| 历史关联 | 绑定 historyItemID | 绑定 analysisId | 一致 |

**结论**：反馈功能存在且完整，只是未像 iOS 那样抽成独立组件。WeChat 还多了离线缓存同步能力。

---

### 6. 跑步会话回放 (RunSessionReplayView ↔ ?)

**状态：❌ 完全缺失**

| 对比维度 | iOS (RunSessionReplayView) | WeChat | 差距 |
|----------|----------------------------|--------|------|
| 会话列表 | sessions list with date/duration/cadence/distance | **无** | ❌ |
| 概览面板 | avg cadence/oscillation/GCT/duration/distance | **无** | ❌ |
| 时序图表 | Canvas time-series chart (cadence/oscillation/GCT lines) | **无** | ❌ |
| 播放控制 | play/pause/seek with timer | **无** | ❌ |
| 教练事件 | coach events timeline + detail cards | **无** | ❌ |

**结论**：iOS RunSessionReplayView 约 800 行代码，提供完整的跑步会话回放体验。WeChat 完全没有对应模块。

---

### 7. 周洞察报告 (WeeklyInsight ↔ insight/)

**状态：✅ 完成（且 WeChat 可能优于 iOS）**

| 对比维度 | iOS | WeChat (insight/) | 差距 |
|----------|-----|-------------------|------|
| 独立页面 | **无**（iOS 未找到 WeeklyInsight 视图） | insight.js 534 行完整页面 | **WeChat 独有** |
| 周对比指标 | - | 5 项指标变化 %（步频/振幅/触地/距离/次数） | WeChat 实现 |
| 4 周趋势图 | - | Canvas 2D 多线趋势图 | WeChat 实现 |
| AI 教练建议 | - | AI 建议文本卡片 | WeChat 实现 |
| 成就徽章 | - | 徽章网格展示 | WeChat 实现 |
| 分享卡片 | - | Canvas 洞察分享卡（insight 场景） | WeChat 实现 |

**结论**：iOS 端未找到 WeeklyInsight 独立视图（可能在计划中但未实现）。WeChat insight 页面是完整实现，含趋势图、AI 建议、徽章和分享。

---

### 8. 分享卡片图片生成 (utils/share-card.js)

**状态：✅ 完成**

| 对比维度 | iOS | WeChat (share-card.js) | 差距 |
|----------|-----|------------------------|------|
| 卡片生成 | Share sheet text 分享 | Canvas 2D 渲染 3 种场景卡片 | WeChat 更丰富 |
| 场景差异化 | 无 | analysis/compare/insight 三场景不同配色和布局 | **WeChat 更优** |
| 评分圆环 | 无 | 环形进度指示器 | WeChat 独有 |
| 对比表格 | 无 | 用户 vs 精英对比表 | WeChat 独有 |
| 趋势迷你图 | 无 | Sparkline 绘制 | WeChat 独有 |
| QR 码 | 无 | 小程序码动态获取 + placeholder | WeChat 独有 |
| 保存相册 | 无 | saveToAlbum with auth | WeChat 独有 |
| 代码规模 | - | 939 行 | 完善 |

**结论**：WeChat share-card.js 功能远超 iOS 的分享能力，939 行代码覆盖 3 种场景。

---

### 9. 步频实时模式 (CadenceDetector ↔ cadence/)

**状态：⚠️ 功能存在但算法和限制不同**

| 对比维度 | iOS (CadenceDetector.swift) | WeChat (cadence.js + cadence page) | 差距 |
|----------|----------------------------|-------------------------------------|------|
| 检测算法 | 低通滤波 + 过零检测 + 步间隔计算 | 低通滤波 + 峰值检测 + 滑动窗口 | 算法不同，核心等效 |
| 置信度 | 间隔一致性 + 样本量评分 | 峰数量因子 + 均匀性 | 等效 |
| 采样率 | 60Hz (CoreMotion) | ~60Hz iOS / ~30Hz Android | WeChat Android 采样率低 |
| 后台运行 | 支持 | **不支持**（微信限制：仅前台） | ❌ 平台限制 |
| 批处理 | processBatch 支持 | 无 | ⚠️ |
| 可配置参数 | alpha/minSPM/maxSPM/window | 硬编码常量 | ⚠️ 灵活性差 |
| UI 页面 | 无独立页面（集成到跑步会话） | 独立 cadence 页面 + 实时数据显示 | **WeChat 独有** |

**结论**：核心步频检测功能两端均可用。WeChat 受限于只能在屏幕亮起时工作。iOS 算法更精细（过零检测 + 步间隔 CV 分析），WeChat 用峰值检测。

---

## 二、追赶优先级排序

### P0 — 必须追赶（核心功能缺失，影响产品完整度）

| 序号 | 功能 | 当前状态 | 预估工作量 | 说明 |
|------|------|----------|------------|------|
| P0-1 | **马拉松训练计划模式** | ❌ 完全缺失 | 5-8 人日 | plan 页面仅 179 行，iOS 有完整的 MarathonPlanDetailView + PlanBuilderView 马拉松模式。需增加：马拉松/比赛目标类型、阶段分组展示（基础期→强化期→巅峰期→减量期）、每周目标里程/长跑里程、关键训练课、生成/查看马拉松计划的完整流程 |

### P1 — 尽快追赶（影响用户体验和竞争力）

| 序号 | 功能 | 当前状态 | 预估工作量 | 说明 |
|------|------|----------|------------|------|
| P1-1 | **跑步会话回放** | ❌ 完全缺失 | 8-12 人日 | iOS RunSessionReplayView 800 行，需从零构建：会话列表 API 对接、概览面板、Canvas 时序图表（多指标折线）、播放控制、教练事件时间线。可能需要新增后端 API |
| P1-2 | **精英对比结果详情页** | ⚠️ 缺少结果页 | 3-5 人日 | 当前 compare 页只有简单对比表，缺少 iOS CompareResultView 的相似度环形图、AI 教练叙事点评、最大差距分析卡片。建议新建 compare-result 页面 |
| P1-3 | **步频检测算法增强** | ⚠️ 算法偏简 | 2-3 人日 | 现有峰值检测算法可行但精度不如 iOS 的过零检测。建议引入 iOS 的步间隔一致性分析提升置信度准确性；增加可配置参数（窗口大小、采样频率适配） |

### P2 — 优化完善（锦上添花，非阻塞）

| 序号 | 功能 | 当前状态 | 预估工作量 | 说明 |
|------|------|----------|------------|------|
| P2-1 | **反馈组件独立化** | ⚠️ 内嵌在 result | 1 人日 | 将反馈从 result.js 抽成独立组件可复用，与 iOS FeedbackView 对齐 |
| P2-2 | **历史记录详情页** | ⚠️ 点击跳转 result | 2 人日 | iOS 有 HistoryDetailView 展示历史分析详情 + FeedbackView。WeChat 目前点击历史项跳转 result 页，体验不一致 |
| P2-3 | **计划手动编辑** | ❌ 缺失 | 3 人日 | iOS 有 ManualNextWeekPlanEditorView，允许用户手动调整生成的周计划 |
| P2-4 | **已保存计划查看** | ⚠️ 仅存储无查看 | 1-2 人日 | iOS 有 SavedPlansView，WeChat 仅用 storage 保存但缺少查看页面 |

---

## 三、完成度总览

| # | 功能项 | 状态 | WeChat 代码量 | iOS 代码量 | 差距等级 |
|---|--------|------|--------------|-----------|----------|
| 1 | 视频分析结果展示 | ✅ | 801 行 JS | 378 行 Swift | 无差距（WeChat 更丰富） |
| 2 | 历史记录+趋势图 | ✅ | 967 行 JS | ~200 行 Swift | 无差距（WeChat 更丰富） |
| 3 | 精英对比全流程 | ⚠️ | 310 行 JS | ~500 行 Swift | 缺结果详情页 |
| 4 | 训练计划含马拉松 | ❌ | 179 行 JS | ~1200 行 Swift | **严重缺失** |
| 5 | 用户反馈评分 | ⚠️ | 内嵌 ~90 行 | 56 行 Swift | 功能存在，非独立 |
| 6 | 跑步会话回放 | ❌ | 0 行 | 800 行 Swift | **完全缺失** |
| 7 | 周洞察报告 | ✅ | 534 行 JS | 0 行 Swift | WeChat 独有（iOS 未实现） |
| 8 | 分享卡片生成 | ✅ | 939 行 JS | - | WeChat 独有且完善 |
| 9 | 步频实时模式 | ⚠️ | 301+103 行 JS | 210 行 Swift | 算法差异+平台限制 |

---

## 四、追赶计划建议

### 第一阶段（第 1-2 周）：P0 冲刺
- **马拉松计划模式**：扩展 plan 页面，增加马拉松/比赛目标类型，对接后端马拉松 API，新建 marathon-plan 子页面展示阶段分组和每周详情

### 第二阶段（第 3-4 周）：P1 补充
- **跑步会话回放**：从零构建 run-replay 页面，包含会话列表 → 详情回放流程，Canvas 时序图表，播放控制
- **精英对比结果页**：新建 compare-result 页面，实现相似度环形图 + 教练点评 + 最大差距分析
- **步频检测增强**：引入 iOS 过零检测算法，优化置信度计算

### 第三阶段（第 5 周+）：P2 打磨
- 反馈组件独立化、历史详情页、计划手动编辑、已保存计划查看

---

*报告结束*
