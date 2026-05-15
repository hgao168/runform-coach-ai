# Sprint 0 — QA & 发布工程师入职文档

> RunForm 跨平台质量保证与发布管理  
> 审查日期：2026-05-13 · 审查人：Hermes Agent (qa-release-engineer)  
> 代码库路径：`~/workspace/runform/`

---

## 一、本周目标（This-Week Goal）

**建立 RunForm 五端（iOS / Android / 微信小程序 / Web / 后端）质量基础体系**。

当前仓库质量基础设施几乎为零——五端全线零测试覆盖、零 Lint 规则、零自动化测试流水线。本周核心任务不是写测试用例，而是搭好质量管理的「地基」：确定各端测试策略与框架选型、设计跨平台 Bug 管理流程、补齐 CI 流水线中缺失的测试环节、规划真机设备实验室方案。本周结束时应产出一份完整的质量保障蓝图，使 Sprint 1 开始后各端开发能直接按策略编写测试。

---

## 二、交付物（Deliverables）

### 2.1 现状审计：CI / 测试 / 发布基础设施盘点

#### 2.1.1 CI 流水线现状

| 工作流 | 文件 | 触发方式 | 覆盖内容 | 测试环节 |
|--------|------|----------|----------|----------|
| iOS 生产发布 | `.github/workflows/ios-build.yml` | 手动 (`workflow_dispatch`) | master 分支 → Release 构建 → 签名 → IPA 导出 → TestFlight 上传 | ❌ 无 |
| iOS Staging | `.github/workflows/ios-staging.yml` | 手动 (`workflow_dispatch`) | staging 分支 → Debug 构建 → 可选 TestFlight 上传 | ❌ 无 |
| 后端 Staging 部署 | `.github/workflows/backend-staging-deploy.yml` | 手动 (`workflow_dispatch`) | 触发 Railway GraphQL API 部署 | ❌ 无 |
| **Android CI** | — | 不存在 | — | ❌ |
| **微信小程序 CI** | — | 不存在 | — | ❌ |
| **Web CI** | — | 不存在 | — | ❌ |
| **后端生产部署** | — | 不存在（仅 Railway 内手动部署） | — | ❌ |

**关键发现**：
- 仅 3 个 GitHub Actions 工作流，全部为手动触发，零自动触发（无 push/PR 触发）。
- 所有工作流仅做构建/部署，**无任何测试步骤**——没有 `xcodebuild test`、没有 `./gradlew test`、没有 `pytest`。
- iOS 构建使用 XcodeGen (`project.yml`) 生成 `.xcodeproj`，但 `project.yml` 中**未定义任何 test target**。
- Android 无 CI，本地构建用 `gradlew`，但 `build.gradle.kts` 中无测试依赖声明。
- 后端部署在 Railway 上，有 staging 和 production 两套环境，但无生产部署自动化。

#### 2.1.2 测试覆盖现状：五端全为零

| 平台 | 测试框架 | 单元测试 | UI/集成测试 | 测试文件数 | 覆盖率 |
|------|----------|----------|-------------|-----------|--------|
| **iOS** | 无 XCTest target | 0 | 0 | 0 | 0% |
| **Android** | 无 JUnit/Espresso | 0 | 0 | 0 | 0% |
| **后端 (Python)** | 无 pytest | 0 | 0 | 0 | 0% |
| **微信小程序** | 无 | 0 | 0 | 0 | 0% |
| **Web** | 无 | 0 | 0 | 0 | 0% |

**唯一存在的测试脚本**：`scripts/test_analyzer.py`（21 行），仅调用 `analyze_running_video_mock()` 打印输出——属于冒烟验证脚本，非正式测试。

#### 2.1.3 代码质量 / Lint 现状

| 检查项 | iOS | Android | 后端 | 微信小程序 | Web |
|--------|-----|---------|------|-----------|-----|
| SwiftLint | ❌ 无 `.swiftlint.yml` | — | — | — | — |
| ktlint / detekt | — | ❌ | — | — | — |
| ESLint | — | — | — | ❌ | ❌ |
| Ruff / pylint / mypy | — | — | ❌ | — | — |
| Pre-commit hooks | ❌ | ❌ | ❌ | ❌ | ❌ |
| 类型检查 | Swift 5.9 编译时 | Kotlin 2.1 编译时 | 无 mypy | 无 TS | 无 |

#### 2.1.4 发布管道现状

| 平台 | 发布渠道 | 当前版本 | 自动化程度 | 签名/证书管理 |
|------|----------|----------|-----------|--------------|
| **iOS** | TestFlight → App Store | 1.1 (build: 3.x) | 半自动：手动触发 CI → 自动上传 TestFlight | GitHub Secrets (p12 + provisioning profile + App Store Connect API Key) |
| **Android** | 无 Google Play | 1.0 (versionCode=1) | 无 | 无 keystore |
| **微信小程序** | 微信审核 | 未版本化 | 无：微信开发者工具手动上传 | 无 CI 集成 |
| **后端** | Railway | 0.5.0 | 半自动：手动触发 CI → 触发 Railway deploy | Railway Token (GitHub Secret) |
| **Web** | 无独立 Web | — | 无 | — |

**关键发现**：
- iOS 发布管道最成熟：XcodeGen 生成工程 + 签名自动化 + TestFlight 上传。但完全无测试门禁，IPA 在未跑任何测试的情况下直接上传 TestFlight。
- Android 无签名配置 (`build.gradle.kts` 中无 `signingConfigs`)，无 `google-services.json`，无法发布到 Google Play。
- 微信小程序发布完全手动：微信开发者工具 → 上传 → mp.weixin.qq.com 提交审核，无 CI 集成。

#### 2.1.5 XcodeGen project.yml 分析

```yaml
# project.yml 仅定义了一个 target，无测试 target
targets:
  RunFormCoachAI:
    type: application
    platform: iOS
    sources:
      - path: ios/RunFormCoachAI
    # ⚠️ 缺失: 无 RunFormCoachAITests (XCTest)
    # ⚠️ 缺失: 无 RunFormCoachAIUITests (XCUITest)
```

---

### 2.2 跨平台测试策略（五端全覆盖）

基于 skill 定义的测试层级和各端技术栈现状，制定以下分阶段测试策略：

#### 2.2.1 iOS 测试策略

**测试金字塔**：

```
         ┌──────────┐
         │ E2E      │  XCUITest: 核心用户旅程 (分析→结果→计划)
         │  5-10条  │  每周手动执行，CI 按需触发
         ├──────────┤
         │ 集成测试  │  APIClient 集成测试 (mock server) + PoseExtractor Vision 管线测试
         │  15-20条 │  CI 每次 push 触发
         ├──────────┤
         │ 单元测试  │  XCTest: ViewModel 状态机 + 数据处理逻辑 + 计算函数
         │  50+条   │  CI 每次 push 触发
         └──────────┘
```

**Sprint 0 行动**：
1. `project.yml` 新增两个 target：
   ```yaml
   RunFormCoachAITests:
     type: bundle.unit-test
     platform: iOS
     sources:
       - path: ios/RunFormCoachAITests
     dependencies:
       - target: RunFormCoachAI

   RunFormCoachAIUITests:
     type: bundle.ui-testing
     platform: iOS
     sources:
       - path: ios/RunFormCoachAIUITests
     dependencies:
       - target: RunFormCoachAI
   ```
2. 在 `ios-build.yml` 和 `ios-staging.yml` 的 archive 步骤之前插入测试步骤：
   ```yaml
   - name: Run unit tests
     run: |
       xcodebuild test \
         -project RunFormCoachAI.xcodeproj \
         -scheme RunFormCoachAI \
         -destination 'platform=iOS Simulator,name=iPhone 16' \
         -configuration Debug
   ```
3. Sprint 1 优先覆盖的单元测试范围（按风险排序）：
   - `AppStore` 状态管理（分析/计划/登录状态机）
   - `PoseExtractor` 信号处理函数（smooth/countPeaks/pearsonCorrelation）
   - `APIClient` URL 构建与错误处理
   - `AnalysisModels` 编解码往返测试

**XCUITest 核心场景**（Sprint 2+）：
- TC-IOS-001: 选择视频 → 上传分析 → 结果页渲染 → 置信度环显示
- TC-IOS-002: 生成训练计划 → 计划展示 → 保存计划
- TC-IOS-003: 历史列表滚动 → 点击展开详情 → 趋势图渲染
- TC-IOS-004: 个人资料填写 → 保存 → 重启 App 验证持久化
- TC-IOS-005: 无网络 → 错误提示可理解（非崩溃）

#### 2.2.2 Android 测试策略

**测试金字塔**：

```
         ┌──────────┐
         │ E2E      │  Compose UI Testing: 核心用户旅程
         │  5-10条  │  真机矩阵执行
         ├──────────┤
         │ 集成测试  │  ApiClient + Retrofit (MockWebServer) + Room DAO
         │  10-15条 │  CI 每次 push 触发
         ├──────────┤
         │ 单元测试  │  JUnit5 + MockK: ViewModel 逻辑 + CadenceDetector + SensorFusion
         │  40+条   │  CI 每次 push 触发
         └──────────┘
```

**Sprint 0 行动**：
1. `app/build.gradle.kts` 新增测试依赖：
   ```kotlin
   testImplementation("org.junit.jupiter:junit-jupiter:5.11.0")
   testImplementation("io.mockk:mockk:1.13.12")
   testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.9.0")
   androidTestImplementation("androidx.compose.ui:ui-test-junit4")
   androidTestImplementation("androidx.test:runner:1.6.2")
   ```
2. 新增 GitHub Actions workflow `.github/workflows/android-test.yml`：
   ```yaml
   name: Android Test
   on: [push, pull_request]
   jobs:
     test:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
         - uses: actions/setup-java@v4
           with:
             java-version: '17'
             distribution: 'temurin'
         - run: ./gradlew test
   ```
3. Sprint 1 优先覆盖的单元测试：
   - `AppViewModel` 分析状态机（Idle → Loading → Success → Error）
   - `AppViewModel` 历史记录 CRUD（最多 50 条限制）
   - `CadenceDetector` 峰值检测算法（正弦波输入验证）
   - `CoachingTtsEngine` 提示冷却逻辑

**Compose UI 测试核心场景**（Sprint 2+）：
- TC-AND-001: AnalyzeScreen 选择视频 → 显示视频缩略图 → 触发分析
- TC-AND-002: AnalysisResultScreen 置信度环颜色（绿/橙/红）正确
- TC-AND-003: PlanScreen 表单输入 → 生成计划 → 周训练卡片展示
- TC-AND-004: ProfileScreen DropdownField/SliderRow 交互正确
- TC-AND-005: HistoryScreen 清空确认对话框

#### 2.2.3 后端 (Python/FastAPI) 测试策略

**测试金字塔**：

```
         ┌──────────┐
         │ E2E      │  pytest + httpx.AsyncClient: 完整 API 调用链
         │  15-20条 │  CI 每次 push/PR 触发
         ├──────────┤
         │ 集成测试  │  pytest + 测试数据库 (SQLite in-memory): DB 操作 + Strava mock
         │  10-15条 │  CI 每次 push/PR 触发
         ├──────────┤
         │ 单元测试  │  pytest: analyzer / planner / schemas 纯函数
         │  30+条   │  CI 每次 push/PR 触发
         └──────────┘
```

**Sprint 0 行动**：
1. `backend/requirements.txt` 新增测试依赖：
   ```
   pytest==8.3.4
   pytest-asyncio==0.24.0
   httpx==0.28.1
   ```
2. 新建目录结构：
   ```
   backend/tests/
   ├── __init__.py
   ├── conftest.py          # fixtures: async client, test DB
   ├── test_health.py       # GET /health
   ├── test_analyze.py      # POST /analyze-metrics, POST /analyze
   ├── test_training_plan.py# POST /training-plan
   ├── test_profile.py      # PUT /profile
   ├── test_compare.py      # POST /compare, GET /athletes
   └── test_strava.py       # Strava OAuth/sync/summary/disconnect
   ```
3. 新增 GitHub Actions workflow `.github/workflows/backend-test.yml`：
   ```yaml
   name: Backend Test
   on: [push, pull_request]
   jobs:
     test:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
         - uses: actions/setup-python@v5
           with:
             python-version: '3.12'
         - run: pip install -r backend/requirements.txt
         - run: cd backend && python -m pytest tests/ -v
   ```
4. Sprint 1 优先测试的 API 端点：
   - `GET /health` → 200 + 正确 JSON schema
   - `POST /training-plan` → 有效输入 → 200 + 计划结构完整
   - `POST /training-plan` → 无效输入 → 422 或 400
   - `POST /analyze-metrics` → 有效 PoseMetrics → 200 + AnalysisResponse
   - `PUT /profile` → 完整 profile → 200 + saved=true
   - Strava OAuth 错误路径覆盖率：配置错误 → 503 / token 无效 → 400

#### 2.2.4 微信小程序测试策略

由于微信小程序的测试生态特殊（无标准测试框架），采用分层策略：

| 层级 | 工具 | 范围 |
|------|------|------|
| **手动回归测试** | 微信开发者工具真机预览 + 体验版 | 每次发版前执行完整 checklist |
| **API 层单元测试** | `jest` + `miniprogram-simulate`（可选） | utils/api.js, utils/storage.js 核心函数 |
| **审核自查** | 微信官方审核规范 checklist | 每次提审前执行 |

**Sprint 0 行动**：
1. 编写微信小程序手动回归测试 Checklist（见 2.4 Bug 工作流中的 Checklist 模板）
2. 评估 `miniprogram-simulate` 可行性（微信官方测试工具，但维护滞后，建议 Sprint 2 再评估）
3. 短期方案：手动回归测试 + 微信开发者工具「自动化测试」录制回放功能

**核心手动测试场景**：
- TC-WX-001: 选择视频 → 上传分析 → 结果页完整渲染
- TC-WX-002: 生成训练计划 → 周卡片展示正确
- TC-WX-003: 历史列表滚动加载 → 点击查看详情
- TC-WX-004: 个人资料填写保存 → 重启小程序验证
- TC-WX-005: 精英运动员列表加载 → 对比入口
- TC-WX-006: 中英文切换（系统语言切换后 UI 文本正确）
- TC-WX-007: 弱网/断网 → 错误提示可理解

#### 2.2.5 Web 测试策略

当前仓库无独立 Web 端代码（微信小程序内的 webview 页面仅为占位）。Web 测试策略暂定：
- **如果有 Web 管理后台或 Landing Page**：Cypress / Playwright E2E + Lighthouse 性能审计
- **如果 Web 仅为 API 文档页**：只需手动验证
- **建议**：Sprint 2 之后再根据 Web 产品形态确定

---

### 2.3 Bug 管理工作流与模板

#### 2.3.1 GitHub Issues Bug 模板

建议在仓库中创建 `.github/ISSUE_TEMPLATE/bug_report.md`：

```markdown
---
name: Bug 报告
about: 提交缺陷报告帮助改进 RunForm
title: "[平台] 简短描述"
labels: bug
assignees: ''
---

## Bug 信息

**Bug ID**：（由 QA 分配编号）
**平台**：[ ] iOS  [ ] Android  [ ] 微信小程序  [ ] 后端  [ ] Web
**严重级别**：
  [ ] P0 — 崩溃 / 数据丢失 / 用户无法使用核心功能
  [ ] P1 — 主流程阻断 / 功能完全不可用
  [ ] P2 — 功能异常但不影响主流程
  [ ] P3 — 体验问题 / 文案错误 / 视觉瑕疵

**标题**：[简洁概括问题，如「iOS：分析结果页步频指标始终显示 0」]

## 复现信息

**设备/环境**：
- 设备型号：（如 iPhone 15 Pro / 小米 14 / 微信开发者工具）
- OS 版本：（如 iOS 18.2 / Android 14 / HarmonyOS 4）
- App 版本：（如 1.1 build 3.42）
- 网络环境：（WiFi / 4G / 5G）

**复现步骤**：
1. 打开 App → 进入「分析」Tab
2. 选择一段跑步视频
3. 点击「开始分析」
4. 等待分析完成

**期望结果**：
分析结果页显示步频指标数值（如 172 spm）

**实际结果**：
步频指标始终显示 0，其他指标正常

**复现率**：[ ] 必现  [ ] 偶现（约 ___%）  [ ] 仅一次

## 证据

**截图/录屏**：（拖拽附件到这里）

**日志**（如有）：
```
（粘贴相关日志）
```

## 其他信息

**是否 Regression**：[ ] 是（之前版本正常）  [ ] 否  [ ] 不确定
**关联 PR / Issue**：（如有）
```

#### 2.3.2 Bug 生命周期与工作流

```
发现 Bug → 提交 Issue → 标签分类 → 指派开发者
                                    │
                     ┌──────────────┴──────────────┐
                     ▼                              ▼
              P0 / P1                          P2 / P3
         立即修复 + Hotfix                排入当前或下个 Sprint
               │                                │
               ▼                                ▼
         开发者修复 → 提交 PR ← 关联 Issue (#fixes #123)
               │
               ▼
         QA 验证修复 → 关闭 Issue 或 Reopen
```

**SLA 建议**：
| 级别 | 响应时间 | 修复时间 | 示例 |
|------|----------|----------|------|
| P0 | 1 小时内 | 24 小时内（hotfix） | App 启动崩溃、数据丢失、支付失败 |
| P1 | 4 小时内 | 当前 Sprint 内 | 核心功能不可用、分析结果错误、登录失败 |
| P2 | 24 小时内 | 下个 Sprint 内 | UI 异常、非核心功能异常 |
| P3 | 72 小时内 | 排入 Backlog | 文案错误、视觉瑕疵、优化建议 |

#### 2.3.3 发布前回归测试 Checklist

```markdown
## RunForm 发布前回归测试 Checklist

### 通用（所有平台）
- [ ] App/小程序启动无崩溃
- [ ] 网络异常时错误提示可理解（非白屏/非原生错误栈）
- [ ] 后台切换后状态保持正确

### iOS 专项
- [ ] TestFlight 构建安装成功
- [ ] 选择视频 → 上传分析 → 结果页渲染完整
- [ ] 训练计划生成 → 保存 → 马拉松/比赛计划
- [ ] 精英运动员对比功能
- [ ] Strava OAuth 连接/同步/断开
- [ ] 历史趋势图表渲染
- [ ] 视频实时录制引导 (LiveGuidanceRecorderView)
- [ ] 多语言切换（en / nl / zh-Hans）
- [ ] App Store 审核材料完备（隐私声明、权限说明）

### Android 专项
- [ ] APK 在 Pixel / 三星 / 小米 / 华为 / OPPO 上安装成功
- [ ] 视频选择/相机录制正常
- [ ] 分析流程端到端
- [ ] 训练计划生成与展示
- [ ] 后台限制后前台服务恢复（厂商适配）
- [ ] Google Play 数据安全表单已更新

### 微信小程序专项
- [ ] 体验版扫码安装成功
- [ ] 视频选择上传 → 分析流程
- [ ] 训练计划生成
- [ ] 历史记录滚动加载
- [ ] 精英运动员列表
- [ ] 中英文切换
- [ ] 审核自查清单全部通过

### 后端专项
- [ ] `/health` 返回 200
- [ ] 数据库迁移无错误 (Alembic)
- [ ] 生产环境 CORS 配置正确
- [ ] API 错误响应格式统一
- [ ] Railway 部署成功且健康检查通过
```

---

### 2.4 CI / 发布管道提案

#### 2.4.1 目标架构

```
GitHub Push / PR
      │
      ├──→ [iOS CI] ──→ SwiftLint → XCTest → XCUITest(sim) → (手动触发) Archive → TestFlight
      │
      ├──→ [Android CI] ──→ ktlint → JUnit → Compose UI Test(emu) → (手动触发) Build → Google Play
      │
      ├──→ [Backend CI] ──→ ruff/mypy → pytest → (手动触发) Deploy → Railway
      │
      └──→ [WeChat CI] ──→ (暂无自动化测试) → 微信开发者工具 CLI 上传体验版
```

#### 2.4.2 新增 GitHub Actions Workflow 清单

| # | Workflow 文件 | 触发方式 | 任务 | 优先级 |
|---|-------------|----------|------|--------|
| 1 | `ios-test.yml` | push/PR 到任意分支 | SwiftLint + XCTest (单元) | **Sprint 0** |
| 2 | `android-test.yml` | push/PR 到任意分支 | ktlint + JUnit 单元测试 | **Sprint 0** |
| 3 | `backend-test.yml` | push/PR 到任意分支 | ruff + mypy + pytest | **Sprint 0** |
| 4 | `ios-e2e.yml` | 手动 / 定时 (nightly) | XCUITest 在 Simulator 上运行 | Sprint 2 |
| 5 | `android-e2e.yml` | 手动 / 定时 (nightly) | Compose UI Test 在模拟器上 | Sprint 2 |
| 6 | `android-release.yml` | 手动触发 | 签名 + 构建 AAB → Google Play Internal Track | Sprint 1 |
| 7 | `backend-prod-deploy.yml` | 手动触发 | 部署到 Railway 生产环境 | Sprint 0 |
| 8 | `wechat-upload.yml` | 手动触发 | 微信开发者工具 CLI 上传体验版 | Sprint 2 |

#### 2.4.3 现有 Workflow 改进清单

| 现有 Workflow | 改进项 | 优先级 |
|--------------|--------|--------|
| `ios-build.yml` | Archive 前插入 `xcodebuild test` 步骤 → 测试失败阻止上传 | **Sprint 0** |
| `ios-build.yml` | 增加 `swiftlint lint --strict` 步骤 | Sprint 1 |
| `ios-staging.yml` | Archive 前插入 `xcodebuild test` 步骤 | **Sprint 0** |
| `backend-staging-deploy.yml` | 部署前触发 `backend-test.yml` 或内联 pytest | **Sprint 0** |

#### 2.4.4 Lint / 代码质量基础设施

**Sprint 0 立即添加**：

1. **iOS — SwiftLint**：仓库根目录创建 `.swiftlint.yml`
   ```yaml
   disabled_rules:
     - trailing_whitespace
   opt_in_rules:
     - empty_count
     - missing_docs
   line_length: 140
   type_body_length: 400
   file_length: 1000
   excluded:
     - .build
   ```

2. **Android — ktlint**：`android/` 目录下集成 ktlint Gradle plugin
   ```kotlin
   // build.gradle.kts (app)
   plugins {
       id("org.jlleitschuh.gradle.ktlint") version "12.1.2"
   }
   ```

3. **后端 — ruff + mypy**：`backend/` 目录下创建 `pyproject.toml`
   ```toml
   [tool.ruff]
   line-length = 120
   target-version = "py312"

   [tool.ruff.lint]
   select = ["E", "F", "I", "N", "W", "UP", "B"]

   [tool.mypy]
   python_version = "3.12"
   strict = true
   ```

4. **Pre-commit hooks**：仓库根目录创建 `.pre-commit-config.yaml`，在提交前自动执行 lint

#### 2.4.5 发布管道详细设计

**iOS 发布流程**（当前已有基础，需增强）：

```
master 分支 → 手动触发 ios-build.yml
  ├── xcodegen generate
  ├── SwiftLint (新增)
  ├── xcodebuild test (新增) → 失败则阻止
  ├── xcodebuild archive (Release)
  ├── export IPA
  └── altool upload to TestFlight

发布节奏建议：
  - 开发期：每 Sprint 至少 1 次 TestFlight 内测构建
  - 提审前：完整回归测试 → TestFlight 外测 2-3 天 → App Store 提交
```

**Android 发布流程**（需从零搭建）：

```
master 分支 → 手动触发 android-release.yml
  ├── ktlint (新增)
  ├── ./gradlew test (新增)
  ├── ./gradlew bundleRelease (签名)
  └── 上传 AAB 到 Google Play Console Internal Track

前置条件：
  - 生成 upload keystore → 存入 GitHub Secrets
  - Google Play Console 创建应用 + 启用 Internal Track
  - 配置 google-services.json（如需 Firebase）
```

**微信小程序发布流程**：

```
 手动 → 微信开发者工具 → 上传代码 → mp.weixin.qq.com 提交审核

前置条件：
  - 注册微信小程序 AppID
  - 配置服务器域名白名单（request 合法域名）
  - 准备审核材料：隐私保护说明、内容分类
```

**后端发布流程**：

```
staging: 手动触发 backend-staging-deploy.yml → Railway staging deploy
production: 手动触发 backend-prod-deploy.yml (新建) → Railway production deploy

改进：
  - 部署前自动运行 backend-test.yml
  - 部署后自动执行冒烟测试 (curl /health → 验证 200)
  - 添加 deploy status 通知 (Slack/钉钉 webhook)
```

---

### 2.5 真机设备实验室需求

#### 2.5.1 iOS 设备矩阵

| 优先级 | 设备 | 屏幕尺寸 | iOS 版本 | 用途 | 获取方式 |
|--------|------|----------|----------|------|----------|
| **P0** | iPhone 16 / 16 Pro | 6.3" / 6.1" | iOS 18.x | 最新机型适配 + 主力测试 | 购买/租用 |
| **P0** | iPhone SE (3rd gen) | 4.7" | iOS 17/18 | 小屏适配（跑步用户常用轻便机型） | 购买/租用 |
| P1 | iPhone 15 / 14 | 6.1" | iOS 17/18 | 覆盖主流用户 | 可复用模拟器 |
| P1 | iPhone 13 mini | 5.4" | iOS 17 | 极小屏边界测试 | 二手 |
| P2 | iPad (10th gen) | 10.9" | iPadOS 18 | iPad 适配验证（非核心） | 暂不需要 |
| P2 | iPhone XR (2018) | 6.1" | iOS 16 | 最低支持版本验证 (iOS 16) | 二手 |

**最低需求**：至少 2 台真机 —— 一台最新 Pro 机型 + 一台小屏/旧机型

#### 2.5.2 Android 设备矩阵

| 优先级 | 品牌 | 代表机型 | Android 版本 | ROM | 关键测试项 |
|--------|------|----------|-------------|-----|-----------|
| **P0** | Google | Pixel 8/9 | 14/15 | 原生 Android | 基线测试，标准行为 |
| **P0** | 三星 | Galaxy S24 | 14 (One UI 6) | One UI | 国际市场主流 |
| **P0** | 小米 | 小米 14 / Redmi Note | 14 (HyperOS) | HyperOS | 中国市场最大份额，后台限制严格 |
| **P1** | 华为 | Mate 60 / Pura 70 | HarmonyOS 4 | 鸿蒙 | 中国市场重要，无 GMS，TTS 引擎不同 |
| **P1** | OPPO | Find X7 / Reno | 14 (ColorOS) | ColorOS | 中国市场主流，后台策略激进 |
| P2 | vivo | X100 | 14 (OriginOS) | OriginOS | 补充覆盖 |

**最低需求**：至少 3 台 —— Pixel (原生) + 小米 (HyperOS) + 三星 (One UI)。预算允许再加 1 台华为 (鸿蒙)。

#### 2.5.3 微信小程序测试设备

微信小程序的测试关键是 **不同厂商的微信客户端行为差异**（WebView 内核、API 支持程度）。设备需求可以与 Android/iOS 矩阵复用，但需要额外注意：

- **iOS 微信**：需要在 iOS 设备上安装微信，测试小程序在微信内置浏览器中的表现
- **Android 微信**：不同厂商的微信版本内置 Chromium 版本不同，需在华为/小米设备上测试
- **微信开发者工具**：作为主要开发测试工具，但**不能替代真机测试**（preview 模式有差异）

#### 2.5.4 设备管理流程

```
设备清单（Google Sheet / Notion）
├── 设备名称、型号、OS 版本
├── 当前借用人
├── 上次系统更新时间
└── 已知问题备注

测试前：
- 确保系统更新到目标测试版本
- 清除旧版 App 数据
- 确认网络环境（WiFi / 蜂窝）

测试后：
- 记录测试结果到设备清单
- 标记发现的设备特有问题
```

#### 2.5.5 跑步场景专项测试设备

除了手机本身，跑步姿态 App 的测试还需要：

| 设备 | 用途 | 优先级 |
|------|------|--------|
| **腰包 / 跑步腰带** | 测试手机在腰间固定时的传感器精度和稳定性 | **P0** |
| **臂带** | 测试手机在手臂固定时的传感器数据质量 | P1 |
| **蓝牙耳机** | 测试 TTS 语音提示在跑步中的可听性（风噪/环境噪音下） | **P0** |
| **跑步机** | 可控环境下的步频/姿态基线测试 | P1 |
| **Apple Watch**（可选） | 如未来集成 Watch 端，验证腕部传感器数据 | P2 |

---

## 三、风险（Risks）

| # | 风险 | 严重程度 | 影响范围 | 概率 | 缓解措施 |
|---|------|----------|----------|------|----------|
| **R1** | **五端零测试 → 重构/新增功能无安全网** | 🔴 高 | 全平台 | 已发生 | Sprint 0 优先搭建 CI 测试流水线 + Lint 门禁；至少保证每次 push 触发单元测试 |
| **R2** | **Android 厂商后台限制导致传感器采集中断** | 🔴 高 | Android | 高 | 真机矩阵必须覆盖小米/华为/OPPO；前台服务 + 通知栏常驻 + 引导用户加白名单 |
| **R3** | **iOS TestFlight 上传时未运行测试，有缺陷直接到达内测用户** | 🟡 中 | iOS | 已存在 | 在 `ios-build.yml` 和 `ios-staging.yml` 的 archive 前插入 `xcodebuild test` 步骤 |
| **R4** | **微信小程序无自动化测试能力 → 回归测试全靠人工** | 🟡 中 | 微信小程序 | 已存在 | Sprint 2 评估 miniprogram-simulate + 制定详尽的手动回归测试 Checklist |
| **R5** | **Android 无签名/无 Google Play → 无法正式发布** | 🔴 高 | Android | 已发生 | Sprint 1 前生成 upload keystore + 创建 Google Play Console 应用 |
| **R6** | **后端无生产部署自动化 → 人为误操作风险** | 🟡 中 | 后端 | 中 | Sprint 0 新建 `backend-prod-deploy.yml`，部署前自动跑 pytest |
| **R7** | **测试设备不足 → 厂商特有问题无法发现** | 🟡 中 | Android / iOS | 高 | 申请最低设备矩阵（见 2.5）；无法购买时使用云真机平台 (AWS Device Farm / 阿里云移动测试) 作为补充 |
| **R8** | **开发者无测试习惯 → 测试用例无人维护** | 🟡 中 | 全平台 | 中 | CI 中强制测试通过才允许合并 PR；Sprint Review 时展示覆盖率趋势；在 onboarding 文档中强调 TDD 文化 |
| **R9** | **微信小程序审核被拒** | 🟢 低 | 微信小程序 | 低 | 建立提审前自查 Checklist；每次审核前完整自测；关注微信审核政策变化 |
| **R10** | **App Store 审核被拒（隐私/权限声明不足）** | 🟢 低 | iOS | 低 | 已在 Info.plist 中有基本权限声明，新增传感器权限后需同步更新隐私说明 |

---

## 四、需要 CEO 决策的事项（Decisions Needed From CEO）

以下决策直接影响 QA 基础设施投入、工具选型和发布节奏，请在 Sprint 0 第一周内给出明确答复：

| # | 决策事项 | 选项 A | 选项 B | 选项 C | 推荐 | 理由 |
|---|---------|--------|--------|--------|------|------|
| **D1** | **Android 端发布优先级** | **Sprint 1 同步发布 Google Play Internal Track** | 暂缓 Android 发布，先用 iOS 验证市场 | Android 仅内部测试不对外发布 | ✅ **A** | Android 端已有可用代码（10 个 Kotlin 文件，~2,186 行），Sprint 1 接入传感器管线后可达到可测状态。提前建立发布管道避免后期阻塞 |
| **D2** | **真机设备预算** | **购买 5-7 台测试机**（iOS 2台 + Android 3台(Pixel/小米/三星) + 华为1台）约 ¥15,000-30,000 | 仅购买 3 台（iOS 1 + Android 2）约 ¥8,000 | 不购买，使用云真机平台 (AWS Device Farm / 阿里云) 按需付费 | ✅ **A** | 跑步 App 的传感器测试必须在真机上验证（云真机无法模拟跑步场景的加速度计输入）。跑步姿态是 RunForm 核心差异化，传感器精度验证不可跳过 |
| **D3** | **测试覆盖率目标** | **Sprint 3 前达到 60% 单元测试覆盖率**（iOS + Android + 后端） | 30% 覆盖率即可，允许逐步提升 | 不设硬性指标 | ✅ **A** | 当前 0% 覆盖。60% 是业内合理初期目标，不要求 UI 测试覆盖。后端 API 测试覆盖率优先提高到 80%+ |
| **D4** | **微信小程序自动化测试投入** | Sprint 2 评估并引入 miniprogram-simulate | 微信小程序**仅做手动测试**，不投入自动化 | 用第三方平台（如 微信云测） | ✅ **B（短期）+ A（长期）** | 微信小程序测试生态不成熟，miniprogram-simulate 维护停滞。Sprint 0-2 用手动回归 Checklist 保证质量，Sprint 3+ 根据小程序业务重要性决定是否投入自动化 |
| **D5** | **PR 合并门禁：是否强制测试通过** | **强制：所有 PR 必须通过 lint + 测试才允许合并** | 宽松：测试失败时人工判断是否放行 | 仅 master 分支强制，feature 分支不强制 | ✅ **A** | 从零测试到有测试的初期，没有强制门禁会导致测试快速腐化。允许在极端情况（如 CI 基础设施故障）下由 QA 手动 override |
| **D6** | **Bug 跟踪工具** | **GitHub Issues**（已有 GitHub 仓库，零额外成本） | Linear（更好的项目管理体验） | Jira（最重量级） | ✅ **A** | 团队已在 GitHub 上协作，Issues 与 PR/Commit 天然关联（`fixes #123`）。Linear/Jira 引入额外工具切换成本，Sprint 0-3 不需要 |
| **D7** | **发布节奏** | **双周迭代**：每两周一版 TestFlight/内部构建 | 四周迭代：更充裕的测试时间 | 按需发布：不固定节奏 | ✅ **A** | 双周迭代适合早期快速验证阶段。iOS TestFlight 审核约 1-2 天，双周节奏给 QA 留出 3-4 天完整测试窗口。后续稳定后可延长至四周 |
| **D8** | **Crash 监控 / 错误追踪工具** | **Firebase Crashlytics**（iOS + Android 免费） | Sentry（更强大的错误分组） | 暂不接入 | ✅ **A** | Crashlytics 免费、接入简单（iOS 1 个 pod / Android 1 个依赖）、与 Firebase Analytics 统一。Sentry 功能更强但初期不需要 |
| **D9** | **CI 运行器** | **GitHub Actions macOS runner**（iOS 构建 ¥0.08/min）+ **Ubuntu runner**（Android/Backend 免费额度内） | 自建 Mac Mini 作为 CI runner | 使用第三方 CI（Bitrise / CircleCI） | ✅ **A** | 已有 3 个 GitHub Actions workflow 在运行，扩展即可。iOS 构建约 15-20 min/次，按月约 10 次构建，成本可控。自建 Mac Mini 维护成本高 |
| **D10** | **QA 工程师是否需要编码能力** | **需要：能写 XCTest / JUnit / pytest 测试代码** | 不需要：纯手动测试 + 管理测试用例文档 | — | ✅ **A** | 五端自动化测试都需要写代码。没有自动化测试的 QA 在此阶段无法独立建立质量基础设施 |

---

## 五、Sprint 0 执行清单

> Sprint 0 时间框：**本周（5 天）**。目标：搭好质量地基，不要求深度覆盖。

| # | 任务 | 预估 | 产出 |
|---|------|------|------|
| **S0-1** | 在 `project.yml` 新增 XCTest + XCUITest target | 0.5 天 | 可运行的 `xcodebuild test` 工程结构 |
| **S0-2** | 创建 `ios-test.yml`、`android-test.yml`、`backend-test.yml` | 1 天 | 3 个新的 CI workflow，初始仅 1-2 条示例测试 |
| **S0-3** | 创建十个端各 2-3 条示例测试（验证 CI 可用性） | 1 天 | iOS 2条 XCTest + Android 2条 JUnit + 后端 3条 pytest |
| **S0-4** | 创建 `.swiftlint.yml`、ktlint 集成、`ruff/mypy` 配置 | 0.5 天 | Lint 配置文件，CI workflow 中集成 |
| **S0-5** | 创建 `.github/ISSUE_TEMPLATE/bug_report.md` | 0.5 天 | Bug 模板就绪 |
| **S0-6** | 改进现有 `ios-build.yml`，插入 test 步骤 | 0.5 天 | 生产构建前强制测试通过 |
| **S0-7** | 设备采购清单提交 CEO 审批 | 0.5 天 | 设备清单文档 |
| **S0-8** | 编写 Sprint 1 测试计划（基于各端 Sprint 1 开发任务） | 0.5 天 | Sprint 1 测试范围文档 |

---

## 附录 A：仓库技术摘要

| 维度 | 详情 |
|------|------|
| **仓库** | `~/workspace/runform/` |
| **分支策略** | `master` (生产) + `staging` (预发布) |
| **iOS** | Swift 5.9, SwiftUI, XcodeGen (`project.yml`), 35 个源文件, 零测试 |
| **Android** | Kotlin 2.1, Jetpack Compose, Gradle 8.13, 10 个源文件 (~2,186 行), 零测试 |
| **后端** | Python 3.12, FastAPI, PostgreSQL, SQLAlchemy, Alembic, Railway 部署, 零测试 |
| **微信小程序** | 原生 WXML/WXSS/JS, 7 个页面, 4 个 utils, 零测试 |
| **Web** | 无独立 Web 端 |
| **CI** | GitHub Actions × 3 (全部手动触发, 全部无测试步骤) |
| **CD** | iOS → TestFlight (手动), 后端 → Railway (手动), Android/微信小程序 → 无 |

---

## 附录 B：关键文件索引

| 文件 | 说明 |
|------|------|
| `project.yml` | XcodeGen 工程定义（需新增 test targets） |
| `.github/workflows/ios-build.yml` | iOS 生产构建 + TestFlight |
| `.github/workflows/ios-staging.yml` | iOS Staging 构建 |
| `.github/workflows/backend-staging-deploy.yml` | 后端 Staging 部署 |
| `backend/requirements.txt` | Python 依赖（需新增 pytest） |
| `backend/Dockerfile` | 后端容器构建 |
| `backend/railway.toml` | Railway 部署配置 |
| `android/app/build.gradle.kts` | Android 构建配置（需新增测试依赖） |
| `wechat/README.md` | 微信小程序开发与发布说明 |
| `scripts/test_analyzer.py` | 唯一测试脚本（冒烟验证） |
| `.gitignore` | 已有 `.pytest_cache/` 忽略 |

---

*本文档为 Sprint 0 QA & 发布工程师入职启动文档。所有策略和方案为建议路径，具体排期和资源分配待 Sprint Planning 确认。关键决策项 (D1-D10) 需 CEO 在 Sprint 0 周内反馈。*
