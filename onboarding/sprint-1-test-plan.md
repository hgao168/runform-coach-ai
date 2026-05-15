# Sprint 1 测试计划

> 版本: 1.0  
> Sprint 周期: 2周  
> 测试负责人: QA & 发布工程师  
> 最后更新: 2025-05-14

---

## 1. 测试范围概览

Sprint 1 聚焦于 **CoreMotion PoC 验证**、**网站 QA** 和 **API 冒烟测试**，为后续全面自动化测试打基础。

| 测试类别 | 平台 | 优先级 | 描述 |
|----------|------|:---:|------|
| CoreMotion PoC | iOS | P0 | 步频、姿态数据的采集精度与稳定性验证 |
| 网站功能测试 | Web | P1 | 营销网站 + Web 端核心页面 QA |
| API 冒烟测试 | Backend | P1 | 关键接口可用性、响应格式、错误处理 |
| 基础 UI 测试 | iOS | P2 | 核心页面渲染与导航流程 |
| 基础 UI 测试 | Android | P2 | 核心页面渲染与导航流程 |

---

## 2. CoreMotion PoC 验证（iOS）

### 2.1 测试目标
验证 iOS CoreMotion 传感器数据采集的准确性，确保步频计算误差 < 2 步/分钟。

### 2.2 测试用例

| ID | 用例名称 | 步骤 | 验收标准 |
|:---|------|------|------|
| CM-001 | 站立静止采集 | 手持手机静止 30 秒 | 步频 = 0，加速度值在 ±0.05g 范围内波动 |
| CM-002 | 步行步频采集 | 以 ~120 步/分钟步行 60 秒 | 实测步频 118–122 步/分钟（误差 < 2%） |
| CM-003 | 慢跑步频采集 | 以 ~160 步/分钟慢跑 60 秒 | 实测步频 158–162 步/分钟 |
| CM-004 | 快跑步频采集 | 以 ~180 步/分钟快跑 60 秒 | 实测步频 178–182 步/分钟 |
| CM-005 | 走跑切换 | 步行 30s → 慢跑 30s → 步行 30s | 步频曲线能清晰区分三个阶段 |
| CM-006 | 设备朝向变化 | 跑步时旋转手机（竖屏→横屏） | 步频数据不中断、不跳变 |
| CM-007 | 后台运行 | 录制 → 切后台 10s → 切回前台 | 后台时段数据连续无断裂 |

### 2.3 测试工具
- 秒表 / 节拍器 App（用于设定目标步频）
- 参考设备：Apple Watch / Garmin 手表对比
- 测试脚本: `scripts/test_analyzer.py`（已有）

---

## 3. 网站 QA

### 3.1 测试目标
确保 RunForm 营销网站（Web 端）在主流浏览器与设备上功能正常、渲染正确、性能合格。

### 3.2 浏览器兼容性矩阵

| 浏览器 | 平台 | 优先级 |
|--------|------|:---:|
| Chrome (最新稳定版) | macOS / Windows / Android | P0 |
| Safari (最新稳定版) | macOS / iOS | P0 |
| Firefox (最新稳定版) | macOS / Windows | P1 |
| Edge (最新稳定版) | Windows | P2 |
| 微信内置浏览器 | iOS / Android | P1 |

### 3.3 测试用例

| ID | 用例名称 | 步骤 | 验收标准 |
|:---|------|------|------|
| WEB-001 | 首页加载 | 打开 RunForm 官网 | 3 秒内首屏渲染完成（LCP < 2.5s） |
| WEB-002 | 移动端响应式 | 在 iPhone SE 尺寸 (375px) 下浏览 | 布局不错位、无水平滚动 |
| WEB-003 | 平板响应式 | 在 iPad 尺寸 (768px) 下浏览 | 布局适配 tablet 断点 |
| WEB-004 | 导航链接 | 点击所有顶部/底部导航链接 | 无 404、无死链 |
| WEB-005 | 行动号召按钮 | 点击"下载 App"按钮 | 正确跳转 App Store / Google Play |
| WEB-006 | 多语言切换 | 切换 en → zh → nl | 所有文案正确翻译，无 key 泄露 |
| WEB-007 | 图片加载 | 使用慢速网络 (3G throttling) 加载 | 图片有占位/loading 状态，不破坏布局 |
| WEB-008 | 表单提交 | 填写联系表单并提交 | 成功提示，数据到达后端 |

### 3.4 Lighthouse 性能目标
| 指标 | 目标 |
|------|:---:|
| Performance | ≥ 90 |
| Accessibility | ≥ 90 |
| Best Practices | ≥ 90 |
| SEO | ≥ 90 |

---

## 4. API 冒烟测试（Backend）

### 4.1 测试目标
验证关键 API 接口在 staging 环境中可用且响应格式符合规范。

### 4.2 测试环境
- **Base URL**: `https://runform-coach-ai-staging.up.railway.app`
- **数据库**: PostgreSQL (staging)

### 4.3 测试用例

| ID | 端点 | 方法 | 验证项 |
|:---|------|:---:|------|
| API-001 | `/health` | GET | 返回 200，body 含 `{"status": "ok"}` |
| API-002 | `/api/v1/analyze` | POST | 上传有效视频 → 返回 AnalysisResponse 结构 |
| API-003 | `/api/v1/analyze` | POST | 空文件 → 返回 400 错误 |
| API-004 | `/api/v1/athletes` | GET | 返回运动员列表，结构符合 AthleteListItem |
| API-005 | `/api/v1/compare` | POST | 发送 CompareRequest → 返回 CompareResponse |
| API-006 | `/api/v1/profile` | POST | 创建/更新用户资料 → 返回 ProfileResponse |
| API-007 | `/api/v1/strava/connect` | GET | 返回 Strava OAuth 重定向 URL |
| API-008 | CORS 头 | OPTIONS | 返回 `access-control-allow-origin: *` 或指定 origin |

### 4.4 使用脚本
- `scripts/test_analyzer.py` — 已有分析端点测试脚本，Sprint 1 中扩展覆盖

---

## 5. 基础 UI 回归（iOS & Android）

### 5.1 测试范围
仅覆盖 App 核心页面可访问性和基本导航，不做深度功能验证。

### 5.2 iOS 用例

| ID | 页面 | 验证点 |
|:---|------|------|
| UI-iOS-01 | 首页 | TabBar 可见，4 个 tab 图标正确渲染 |
| UI-iOS-02 | 分析页 | 录制按钮可点击，相机权限弹窗正常 |
| UI-iOS-03 | 历史页 | 空状态文案正确，无崩溃 |
| UI-iOS-04 | 计划页 | 页面加载无 crash |
| UI-iOS-05 | 个人资料页 | 表单字段可编辑，保存按钮响应 |

### 5.3 Android 用例

| ID | 页面 | 验证点 |
|:---|------|------|
| UI-AND-01 | 首页 | BottomNavigationBar 可见，图标正确渲染 |
| UI-AND-02 | 分析页 | 相机权限请求弹窗，录制按钮状态切换 |
| UI-AND-03 | 历史页 | RecyclerView/LazyList 滚动流畅 |
| UI-AND-04 | 计划页 | 页面加载无 crash |
| UI-AND-05 | 个人资料页 | 表单交互正常，软键盘弹出不遮挡 |

---

## 6. 微信小程序冒烟测试

| ID | 用例名称 | 步骤 | 验收标准 |
|:---|------|------|------|
| WX-001 | 小程序启动 | 微信扫码或搜索进入 | 3 秒内首屏渲染完成 |
| WX-002 | Tab 导航 | 切换 4 个 tab（分析/对比/历史/我的） | 页面切换流畅，无白屏 |
| WX-003 | 微信授权 | 点击需要授权的功能 | 授权弹窗正常弹出，拒绝后有友好提示 |
| WX-004 | 云开发连通 | 任意触发一次数据请求 | 数据正确返回，无网络错误 |
| WX-005 | WebView 页面 | 打开内嵌 WebView 页面 | 页面正常加载，返回按钮可用 |

---

## 7. 测试排期

| 时间 | 活动 | 负责人 |
|------|------|:---:|
| Sprint-1 Day 1-2 | 测试环境准备（设备、账号、数据） | QA |
| Sprint-1 Day 3-5 | CoreMotion PoC 验证 | QA + iOS 开发 |
| Sprint-1 Day 6-8 | 网站 QA + API 冒烟测试 | QA + 前端 |
| Sprint-1 Day 9-10 | 基础 UI 回归（iOS/Android/小程序） | QA |
| Sprint-1 Day 11-12 | Bug 整理、测试报告撰写 | QA |
| Sprint-1 Day 13-14 | 回归验证 + Sprint 总结 | QA |

---

## 8. 风险与依赖

| 风险 | 影响 | 缓解措施 |
|------|:---:|------|
| 测试设备未到位 | 无法执行真机 CoreMotion 测试 | 先用模拟器 + Android 云真机服务替代 |
| Staging 数据库不稳定 | API 测试数据污染 | 使用独立测试账号和数据隔离 |
| iOS TestFlight 审核延迟 | 内测包无法及时分发 | 优先使用 Xcode 直连安装 |
| Sprint 0 代码未就绪 | 测试无法开始 | 从 Sprint 0 最后一天开始执行部分测试 |

---

## 9. 测试报告模板

Sprint 1 结束后需交付：

```markdown
# Sprint 1 测试报告

## 执行概览
- 测试用例总数: XX
- 通过: XX
- 失败: XX
- 阻塞: XX
- 通过率: XX%

## Bug 汇总
| ID | 标题 | 平台 | 严重级别 | 状态 |
|----|------|------|:---:|:---:|
| #001 | ... | iOS | P1 | Open |

## 质量评估
- 上线风险评估: 低 / 中 / 高
- 建议: ...

## 后续行动
- 需要开发跟进的事项
- Sprint 2 测试重点建议
```
