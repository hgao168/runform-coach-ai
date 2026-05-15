# RunForm Sprint 1 启动摘要

> **日期**：2026-05-16
> **Sprint 周期**：2026-05-19 ~ 2026-06-13（4 周）
> **PM**：Morgan（MoveNova）
> **关联文档**：`product/sprint-1-revised-backlog.md`

---

## 一、Sprint 1 目标（一句话）

**暂停所有新功能开发，将 Android 和微信小程序的功能补齐至与 iOS 持平。**

具体：
- Android 端补齐精英对比（F9-F12）、训练增强（F14-F17）、趋势图表（F7）、多语言（F22）等 iOS 已具备的核心/增强功能
- WeChat 端补齐精英对比接入（F10）、趋势图表（F7）、反馈（F23）、视频压缩（F25）、分享（F26）等功能
- 后端完善 compare API（F10/F11）和反馈 API（F23）
- iOS 端偿还技术债 + 搭建 Lint/测试框架，为 CoreMotion 恢复做好准备
- Website 继续并行推进（前端独立负责，不挤占对齐资源）

**不做**：CoreMotion 全部 Phase、新传感器功能、跑步会话管线（均延后至 Sprint 2）

---

## 二、Week 1 任务分配（5/19 - 5/23）—— 基础设施先行

| 开发者 | 任务 ID | 任务内容 | SP | 优先级 |
|--------|---------|----------|-----|--------|
| **iOS 开发** | RF-402 | 代码清理 + 技术债（PoseExtractor 拆分、APIClient 改造等） | 5 | P1 |
| | RF-403 | SwiftLint 配置 + XCTest 测试框架搭建 | 5 | P0 |
| **Android 开发** | **RF-210** | **Hilt DI 框架接入（最高优先，阻塞项）** | 5 | P0 |
| | RF-213 | API 认证（OkHttp Interceptor）+ 多环境配置 | 3 | P0 |
| **WeChat 开发** | RF-300 | 精英对比功能接入（接通 /compare API） | 3 | P0 |
| | RF-301 | 历史趋势图表（Canvas 绘制折线图） | 5 | P0 |
| **前端开发** | — | Website iOS 功能对照映射（独立并行） | — | — |
| **QA 工程师** | RF-404 | 后端 CI 测试流水线（pytest + ruff + GitHub Actions） | 5 | P0 |
| **后端开发** | RF-400 | compare API 完善（支持用户 vs 精英 + 自定义对比） | 5 | P0 |
| | RF-401 | 反馈 API（POST /feedback） | 3 | P1 |

---

## 三、关键依赖与阻塞项

**关键路径**：RF-210（Hilt DI）是 Android 端的**单点最大阻塞项**。

```
RF-210 (Hilt DI) ──→ RF-211 (Room DB) ──→ RF-200/201/202/203（所有功能对齐条目）
                  ──→ RF-212 (单元测试框架)
```

- 几乎所有 Android P0 条目的 ViewModel 都需要 @HiltViewModel 注入（CompareViewModel、StravaViewModel、PlanViewModel 等）
- RF-210 如延误，将连锁推迟整个 Android 对齐进度
- 缓解：Week 1 Day 1-3 优先攻克 RF-210，仅做最小改造（AppViewModel + ApiClient），后续条目逐步迁移其余 Screen

**其他关键依赖**：
- RF-400（compare API）→ RF-200（Android Compare）、RF-300（WeChat Compare）
- RF-211（Room DB）→ RF-202（趋势图表，需 Room 查询历史数据）
- RF-401（反馈 API）→ RF-203（Android 反馈）、RF-302（WeChat 反馈）

---

## 四、成功度量

| 指标 | 目标 | 衡量方式 |
|------|------|----------|
| Android 功能覆盖 | ≥ 80% iOS 核心功能 | Sprint Review 审计表逐项对照 |
| WeChat 功能覆盖 | ≥ 80% iOS 核心功能（排除平台限制项） | Sprint Review 审计表逐项对照 |
| P0 完成率 | 100% | Backlog P0 条目全部 Done |
| CI 流水线 | 后端 CI（pytest + ruff）在 GitHub Actions 通过 | Actions 绿勾 |
| 代码质量 | iOS SwiftLint 通过 + XCTest ≥ 5 测试用例 | CI 输出 |

---

## 五、风险观察清单

| 风险 | 等级 | 应对 |
|------|------|------|
| RF-210 Hilt 改造量超预期 | 🔴 高 | 最小化改造范围，仅 AppViewModel + ApiClient；如受阻 3 天内升级 PM |
| Room 数据迁移失败致用户数据丢失 | 🟡 中 | 迁移前自动备份 SharedPreferences → cache 目录 JSON |
| Strava OAuth Android 兼容性 | 🟡 中 | 优先 Chrome Custom Tabs 方案，预留 2 天缓冲 |
| 微信云开发环境审批周期长 | 🟡 中 | Week 1 即提交申请，若未通过则降级为 P2、保持本地 Storage |
| 微信语音方案受限（无系统 TTS） | 🟡 中 | 预录音频保底方案；讯飞插件作为增强 |
| Sprint 延长至 4 周，团队节奏/士气 | 🟢 低 | 每周五进度同步会，第 4 周预留缓冲 |
| iOS 开发者无 CoreMotion 工作 | 🟢 低 | 专注技术债清理 + XCTest，提前完成可支援 Android/WeChat |

---

> **下一步**：待 CEO 审批 → Sprint Planning 确认指派人 → 创建 GitHub Issues → Week 1 正式启动。
