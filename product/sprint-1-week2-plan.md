# RunForm Sprint 1 — Week 2 详细计划

> **日期**：2026-05-16（制定）
> **Week 2 周期**：2026-05-26（周一）~ 2026-05-30（周五）
> **Sprint 1 全局**：2026-05-19 ~ 2026-06-13（4 周）
> **PM**：Morgan（MoveNova）
> **关联文档**：`product/sprint-1-revised-backlog.md`、`product/sprint-1-kickoff.md`

---

## 零、Week 1 完成状态确认（5/16）

Week 1（5/19-5/23）原计划基础设施先行，实际完成如下：

| 平台 | 任务 ID | 内容 | SP | 状态 |
|------|---------|------|----|------|
| iOS | RF-402 | 代码清理 + PoseExtractor 拆分 | 5 | ✅ Done |
| iOS | RF-403 | SwiftLint + XCTest 测试框架 | 5 | ✅ Done |
| Android | RF-210 | Hilt DI（ApiModule + AuthModule + TokenManager + AuthInterceptor） | 5 | ✅ Done |
| Android | RF-213 | API 认证（OkHttp Interceptor）+ 多环境配置 | 3 | ✅ Done |
| WeChat | RF-300 | 精英对比 compare.js | 3 | ✅ Done |
| WeChat | RF-301 | 历史趋势图表 history.js Canvas | 5 | ✅ Done |
| Backend | RF-400 | compare API 完善 | 5 | ✅ Done |
| Backend | RF-401 | POST /feedback API | 3 | ✅ Done |
| QA | RF-404 | CI 测试流水线（pytest + ruff + 6 个 workflow） | 5 | ✅ Done |
| Frontend | — | movenova.ai Cloudflare Pages 部署（9 卡片 + 平台状态） | — | ✅ Done |

**Week 1 遗留**：Android RF-211（Room DB）和 RF-212（单元测试）原计划 Week 1 Day 3-5 完成但因 Hilt 改造量吸收全部容量，顺延至 Week 2。

### Week 1 依赖关系变化（关键）

```
RF-210 (Hilt) ✅ → RF-211 (Room DB) ──→ RF-201 (计划保存), RF-202 (趋势图表)
RF-400 (compare API) ✅ → RF-200 (Compare), RF-300 (WeChat Compare) ✅
RF-401 (feedback API) ✅ → RF-203 (反馈), RF-302 (WeChat 反馈)
```

- 阻塞已解除：RF-210 完成，RF-211 可立即启动
- 阻塞已解除：RF-400 完成，RF-200 可立即启动
- 阻塞已解除：RF-401 完成，RF-203 / RF-302 可立即启动

---

## 一、Week 2 目标

**一句话**：完成 Android 基础设施收尾（Room DB + 单元测试），打通 RF-200（Compare）首屏并完成 WeChat 全部 P1 快速条目。

具体：
- Android：完成 RF-211（Room DB）和 RF-212（单元测试框架），启动 RF-200（Compare）和 RF-204（i18n）
- WeChat：完成全部 P1 快速条目（RF-302 反馈、RF-303 视频压缩、RF-304 分享），启动 RF-305（语音方案）
- iOS：开发者完成 Week 1 后进入「支援模式」，预分配协助 Android Compare UI 对齐 iOS 设计规范
- Backend：已无 Sprint 1 剩余任务，转为支援 Android/WeChat 联调 + 准备 Sprint 2 CoreMotion API

---

## 二、Android 开发者 Week 2 精确排期

> **开发者**：1 人
> **总 SP 容量**：~10 SP（5 个工作日 × 2 SP/日）
> **优先级策略**：基础设施收尾（RF-211 + RF-212）优先，功能对齐（RF-200 + RF-204）并行启动

### Day-by-Day

| 日 | 日期 | 上午（09:00-12:30） | 下午（13:30-18:00） | 当日 SP |
|----|------|---------------------|---------------------|---------|
| **Day 1** | 5/26 周一 | **RF-211 Room DB**：添加 Room 依赖（room-runtime/ktx/compiler），定义 Entity（AnalysisHistoryEntity、SavedPlanEntity、RunnerProfileEntity），定义 DAO 接口（AnalysisDao、PlanDao、ProfileDao） | **RF-211 Room DB**：定义 RunFormDatabase 类（@Database version=1），AppViewModel 适配 DAO 注入（@HiltViewModel 已就绪） | 2 SP |
| **Day 2** | 5/27 周二 | **RF-211 Room DB**：编写 Migration(0,1) 脚本，SharedPreferences → Room 数据迁移工具（SP 备份 → cache JSON → Room 批量插入） | **RF-211 Room DB**：DAO CRUD 集成测试（Instrumentation Test），AppViewModel 读写切换验证，历史记录列表确认 Room 数据源正常 | 2 SP |
| **Day 3** | 5/28 周三 | **RF-211 Room DB**：Room 收尾 → Migration 降级策略（失败回退 SP），代码 Review → **RF-211 COMPLETE ✅**；**RF-212 单元测试**：添加 JUnit5 + MockK + Turbine 依赖，test 目录结构搭建 | **RF-212 单元测试**：AppViewModelTest.kt（分析状态机 Idle→Loading→Success/Error，5+ 用例） | 2 SP |
| **Day 4** | 5/29 周四 | **RF-212 单元测试**：AnalysisDaoTest.kt（Room 集成测试：insert/queryAll/queryById/delete，4+ 用例）；**RF-200 Compare**：启动背景调研 — iOS CompareModels.swift 字段对照，CompareResponse 数据模型定义 | **RF-212 单元测试**：ApiClientTest.kt（MockWebServer 模拟 /compare API 响应，3+ 用例）；**RF-204 i18n**：res/values-zh/strings.xml 骨架（对照 iOS zh-Hans Localizable.strings） | 2 SP |
| **Day 5** | 5/30 周五 | **RF-212 单元测试**：收尾 → `./gradlew testDebugUnitTest` 全绿验证 → **RF-212 COMPLETE ✅**；**RF-200 Compare**：CompareScreen.kt 骨架（LazyColumn + GlassCard 运动员列表），CompareViewModel 骨架（@HiltViewModel + StateFlow） | **RF-200 Compare**：AthleteDetailScreen 运动员详情（关键指标展示），API 调用链路验证（Repository → ApiClient → /athletes 端点）；**RF-204 i18n**：res/values-nl/strings.xml 骨架 | 2 SP |

### Week 2 产出小结

| 任务 ID | 内容 | SP | Week 2 状态 | 说明 |
|---------|------|----|-------------|------|
| **RF-211** | Room DB 迁移 | 5 | ✅ **COMPLETE** | Entity/DAO/Database/Migration/SP迁移工具 全部完成 |
| **RF-212** | 单元测试框架 | 5 | ✅ **COMPLETE** | JUnit5+MockK+Turbine，AppViewModelTest+DaoTest+ApiClientTest 全绿 |
| **RF-200** | Compare 功能 | 8 | 🔄 2SP done / 6SP 剩余 | CompareScreen + ViewModel 骨架 + 运动员列表；Week 3 完成 |
| **RF-204** | 多语言 i18n | 5 | 🔄 2SP done / 3SP 剩余 | zh/nl strings.xml 骨架建立；Week 3 完成 |

---

## 三、WeChat 开发者 Week 2 精确排期

> **开发者**：1 人
> **P0 已完成**：RF-300（compare.js）、RF-301（history.js Canvas）
> **Week 2 目标**：清空 P1 快速条目（RF-302/303/304），启动 RF-305（语音）

| 日 | 日期 | 上午 | 下午 | 当日 SP |
|----|------|------|------|---------|
| **Day 1** | 5/26 周一 | **RF-302 反馈**：result 页底部新增反馈区域 UI（5星评分组件 + 多行输入框），对接 POST /feedback API | **RF-302 反馈**：提交成功提示 + 无网络本地暂存（wx.setStorageSync），错误重试逻辑 → **RF-302 COMPLETE ✅** | 2 SP |
| **Day 2** | 5/27 周二 | **RF-303 视频压缩**：analyze 页视频上传前调用 wx.compressVideo（降分辨率 720p），压缩进度 loading 动画 | **RF-303 视频压缩**：压缩后边界检查（>10MB 提示用户）、60 秒自动停止录制 → **RF-303 COMPLETE ✅** | 2 SP |
| **Day 3** | 5/28 周三 | **RF-304 分享**：result 页新增「分享」按钮，wx.shareAppMessage 集成（标题=分析摘要，图片=Canvas 截图），onShareAppMessage 生命周期 | **RF-304 分享**：分享路径含分析记录 ID（好友点开看结果），测试微信会话/群聊分享链路 → **RF-304 COMPLETE ✅** | 2 SP |
| **Day 4** | 5/29 周四 | **RF-305 语音方案**：策划语音素材（3 类场景 × 2 条变体：步频偏低/偏高/合格），联系 PM 确认文案 | **RF-305 语音方案**：录制中文语音素材（预录音频文件），wx.createInnerAudioContext 播放测试 | 2 SP |
| **Day 5** | 5/30 周五 | **RF-305 语音方案**：result 页「语音播报」按钮 + 播放状态动画（波形图标），断点续播/暂停控制 | **RF-305 语音方案** + **RF-306 调研**：讯飞插件可行性评估文档；CloudBase 云开发环境申请状态检查 | 2 SP |

### Week 2 产出小结

| 任务 ID | 内容 | SP | Week 2 状态 | 说明 |
|---------|------|----|-------------|------|
| **RF-302** | 反馈评分 | 2 | ✅ **COMPLETE** | result 页反馈 UI + API 对接 + 离线暂存 |
| **RF-303** | 视频压缩 | 2 | ✅ **COMPLETE** | wx.compressVideo + 边界检查 + 时长限制 |
| **RF-304** | 分享功能 | 2 | ✅ **COMPLETE** | wx.shareAppMessage + Canvas 截图 + 深度链接 |
| **RF-305** | 语音方案 | 5 | 🔄 4SP done / 1SP 剩余 | 预录音频录制完成 + 播放集成；Week 3 Day1 收尾 |
| **RF-306** | CloudBase 云存储 | 5 | ⏸️ 调研阶段 | 等待云开发环境审批；如 Week 3 初仍未通过则降级 P2 |

---

## 四、其他开发者 Week 2 安排

### iOS 开发者
- Week 1 RF-402 + RF-403 已完成
- Week 2 转入「支援模式」：
  - 协助 Android Compare UI 对齐 iOS 设计规范（对比卡片样式、配色、动画时长等）
  - 输出 iOS → Android 设计对照文档（CompareView/CompareResultView 截图标注 + 间距/颜色/字体规范）
  - 如 RF-403 XCTest 测试覆盖不足，可补充 PoseExtractor 纯函数测试用例
  - **目标**：Week 2 为 Android Compare UI 提供清晰的设计参考，减少 Android 开发返工

### 后端开发者
- Week 1 RF-400 + RF-401 已完成
- Week 2 Sprint 1 无剩余后端任务
- 转入：
  - 支援 Android/WeChat Compare API 联调（验证 RF-200/300 API 调用正确性）
  - 准备 Sprint 2 CoreMotion 后端需求：实时跑步会话 API（原 RUNFORM-110）+ PoseMetrics 兼容层（原 RUNFORM-111）
  - 维护 CI 流水线（RF-404），确保 backend-test.yml 稳定通过

### QA 工程师
- Week 1 RF-404 已完成
- Week 2：
  - 维护 CI 流水线（6 个 workflow 稳绿）
  - 协助 Android Room DB 数据迁移测试（验证 SP → Room 迁移数据完整性）
  - 准备 Week 3 Android/WeChat 功能对齐测试用例清单

---

## 五、Backlog 状态更新（截至 Week 2 启动前）

### 5.1 Android 条目

| ID | 标题 | SP | 优先级 | 状态 | 备注 |
|----|------|-----|--------|------|------|
| RF-210 | Hilt DI 框架 | 5 | P0 | ✅ Done | Week 1 |
| RF-213 | API 认证 + 多环境 | 3 | P0 | ✅ Done | Week 1 |
| **RF-211** | Room DB 迁移 | 5 | P0 | 🔄 **Week 2 进行中** | D1-D3，计划 5/28 完成 |
| **RF-212** | 单元测试框架 | 5 | P0 | 🔄 **Week 2 进行中** | D3-D5，计划 5/30 完成 |
| **RF-200** | Compare | 8 | P0 | 🔄 **Week 2 启动** | D4 启动，Week 3 完成 |
| **RF-204** | i18n 多语言 | 5 | P0 | 🔄 **Week 2 启动** | D4 启动，Week 3 完成 |
| RF-201 | 训练计划增强 | 8 | P0 | ⏳ Week 3 | 依赖 RF-211（计划保存） |
| RF-202 | 趋势图表 | 5 | P0 | ⏳ Week 3 | 依赖 RF-211（历史查询） |
| RF-203 | 反馈评分 | 3 | P1 | ⏳ Week 3 | 依赖 RF-401 ✅ |
| RF-205 | Strava OAuth | 8 | P1 | ⏳ Week 3-4 | 复杂，预留缓冲 |
| RF-206 | 视频压缩 | 3 | P1 | ⏳ Week 3 | |
| RF-207 | 分享功能 | 2 | P2 | ⏳ Week 4 | |
| RF-208 | 档案扩展字段 | 2 | P2 | ⏳ Week 4 | 依赖 RF-211 |
| RF-209 | 实时录制引导 | 5 | P2 | ⏳ Week 4 | |
| RF-214 | R8 混淆 + 签名 | 3 | P1 | ⏳ Week 3-4 | |
| RF-215 | Crashlytics | 3 | P2 | ⏳ Week 4 | |

### 5.2 WeChat 条目

| ID | 标题 | SP | 优先级 | 状态 | 备注 |
|----|------|-----|--------|------|------|
| RF-300 | 精英对比接入 | 3 | P0 | ✅ Done | Week 1 |
| RF-301 | 趋势图表 Canvas | 5 | P0 | ✅ Done | Week 1 |
| **RF-302** | 反馈评分 | 2 | P1 | 🔄 **Week 2** | 计划 5/26 完成 |
| **RF-303** | 视频压缩 | 2 | P1 | 🔄 **Week 2** | 计划 5/27 完成 |
| **RF-304** | 分享功能 | 2 | P1 | 🔄 **Week 2** | 计划 5/28 完成 |
| **RF-305** | 语音方案 | 5 | P1 | 🔄 **Week 2-3** | Week 2 启动，5/30 接近完成 |
| RF-306 | CloudBase | 5 | P1 | ⏸️ 阻塞（审批） | 等待云环境开通 |
| RF-307 | 档案完善 | 1 | P2 | ⏳ Week 4 | |
| RF-308 | 多角度 UI | 1 | P2 | ⏳ Week 4 | |

### 5.3 后端 / iOS / 跨平台

| ID | 标题 | SP | 优先级 | 状态 | 备注 |
|----|------|-----|--------|------|------|
| RF-400 | compare API | 5 | P0 | ✅ Done | Week 1 |
| RF-401 | 反馈 API | 3 | P1 | ✅ Done | Week 1 |
| RF-402 | iOS 代码清理 | 5 | P1 | ✅ Done | Week 1 |
| RF-403 | iOS SwiftLint+XCTest | 5 | P0 | ✅ Done | Week 1 |
| RF-404 | CI 流水线 | 5 | P0 | ✅ Done | Week 1 |

### 5.4 暂停项（原 CoreMotion）

| 原 ID | 标题 | 状态 | 恢复条件 |
|-------|------|------|----------|
| RUNFORM-103~107 | CoreMotion Phase 0-3 | ⏸️ 暂停 | Sprint 1 功能对齐达成后 |
| RUNFORM-110~111 | Session API + 数据模型 | ⏸️ 暂停 | Sprint 1 功能对齐达成后 |
| RUNFORM-113 | Sprint 1 Demo | ⏸️ 暂停 | 替换为 Sprint Review 三端对齐 Demo |

---

## 六、依赖关系与阻塞项（Week 2 视角）

### 6.1 阻塞已解除 ✅

| 阻塞 | 原阻塞方 | 解除方式 |
|------|----------|----------|
| RF-211 Room DB 等 RF-210 Hilt | RF-210 | Week 1 已完成 Hilt DI 接入 |
| RF-200 Compare 等 RF-400 | RF-400 | Week 1 已完成 compare API |
| RF-203/RF-302 反馈等 RF-401 | RF-401 | Week 1 已完成 feedback API |
| RF-200 Compare 等 RF-210 | RF-210 | Week 1 已完成 Hilt（@HiltViewModel 可用） |

### 6.2 当前活跃阻塞 🔴

| 阻塞项 | 影响条目 | 严重度 | 缓解措施 |
|--------|----------|--------|----------|
| **RF-211 Room DB 未完成** | RF-201（计划保存需要 Room）、RF-202（趋势图表需要 Room 查询）、RF-208（档案扩展需要 Room） | 🟡 中 | RF-211 计划 Week 2 D1-D3 完成，不影响 RF-201/202 在 Week 3 启动；RF-200/204 无 Room 依赖，可并行推进 |
| **RF-306 CloudBase 审批** | WeChat 云存储 | 🟡 中 | 审批已提交；如 Week 3 初未完成，保持本地 Storage + 降级 P2 |
| **讯飞插件审批** | RF-305 语音增强 | 🟢 低 | 预录音频方案已作为保底实现，不依赖插件审批 |

### 6.3 潜在风险 🔶

| 风险 | 影响 | 等级 | 应对 |
|------|------|------|------|
| Room 数据迁移导致用户数据丢失 | RF-211 | 🟡 中 | 迁移前自动备份 SP JSON → cache；迁移失败回退 SP；Week 2 D2 QA 协助验证 |
| RF-200 Compare 与 iOS 设计不一致导致返工 | RF-200 | 🟡 中 | Week 2 安排 iOS 开发输出设计对照文档；Android Day 4 先研究 iOS CompareModels 对齐 |
| WeChat 预录音频质量不达标（机械感） | RF-305 | 🟢 低 | 评估备选方案：降低预期 → 仅提供文字摘要朗读；或联系 PM 预算专业录音 |
| Week 2 Android 10 SP 容量紧张 | 全局 | 🟡 中 | 严格优先级：RF-211 > RF-212 > RF-200 启动 > RF-204 启动；绝不超载 |
| iOS 开发支援效率低（跨端沟通成本） | RF-200 | 🟢 低 | 明确交付物：设计对照文档（非代码），减少同步等待 |

---

## 七、关键里程碑（Week 2）

| 日期 | 里程碑 | 验收标准 |
|------|--------|----------|
| **5/26 周一 18:00** | RF-302 反馈 + RF-211 Entity/DAO 完成 | WeChat 反馈可提交 + Android Room Entity 编译通过 |
| **5/27 周二 18:00** | RF-303 视频压缩 + RF-211 迁移工具完成 | WeChat 视频压缩可用 + SP→Room 迁移脚本就绪 |
| **5/28 周三 18:00** | 🎯 **RF-211 Room DB COMPLETE** + RF-304 分享完成 | Room 全链路集成测试通过 + WeChat 分享可正常唤起 |
| **5/29 周四 18:00** | RF-212 单元测试过半 + RF-200 Compare 启动 | AppViewModelTest + DaoTest 编写完成 |
| **5/30 周五 18:00** | 🎯 **RF-212 单元测试 COMPLETE** + Week 2 收尾 | `gradlew test` 全绿 + WeChat 语音播报可用 |

---

## 八、Week 3 预览

| 平台 | 任务 | SP | 说明 |
|------|------|----|------|
| Android | RF-200 Compare（完成） | 6 剩余 | CompareResultScreen + CustomCompare + 动画 |
| Android | RF-204 i18n（完成） | 3 剩余 | 全部 Screen 字符串迁移 |
| Android | RF-201 训练计划增强（启动） | 8 | 依赖 RF-211 ✅ |
| Android | RF-202 趋势图表（启动） | 5 | 依赖 RF-211 ✅ |
| Android | RF-203 反馈（完成） | 3 | 依赖 RF-401 ✅ |
| WeChat | RF-305 语音收尾 | 1 | 播放状态动画 + 测试 |
| WeChat | RF-306 CloudBase（如审批通过） | 5 | 或降级 P2 |
| iOS | 继续支援 Android | — | 输出 Profile 档案对照 |

---

## 九、风险观察清单（Week 2 更新）

| 风险 | 原等级 | Week 2 等级 | 变化说明 |
|------|--------|-------------|----------|
| RF-210 Hilt 改造量超预期 | 🔴 高 | 🟢 已解除 | Week 1 已完成 |
| Room 数据迁移失败致数据丢失 | 🟡 中 | 🟡 中 | 迁移本周执行，需密切关注 |
| Strava OAuth Android 兼容性 | 🟡 中 | 🟡 中 | 未变，Week 3 处理 |
| 微信云开发审批周期长 | 🟡 中 | 🟡 中 | 审批进行中，无更新 |
| 微信语音方案受限 | 🟡 中 | 🟡 中 | 预录音频方案本周实施 |
| Sprint 延长至 4 周团队士气 | 🟢 低 | 🟢 低 | 未变 |
| iOS 开发者无 CoreMotion 工作 | 🟢 低 | 🟢 已转化 | 转入支援 Android 设计对齐 |
| **新增：Android Week 2 10 SP 容量 vs 13 SP 需求** | — | 🟡 中 | RF-200 和 RF-204 仅在 Week 2 启动 2SP 各，核心完成（COMPLETE）聚焦 RF-211+RF-212 |

---

> **文档版本**：v1.0
> **下一步**：Week 2 每日站会（09:30）→ 进度同步 → PM 周三中检 RF-211 是否按时完成 → 周五 Week 2 回顾
