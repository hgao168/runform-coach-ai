# RunForm Coach AI — WeChat Mini Program

WeChat mini program companion to the iOS app. Provides running form analysis, personalised training plans, history tracking, and elite athlete profiles — all in Chinese-first UI backed by the same FastAPI backend.

## Project Structure

```
wechat/
├── app.js                  Global state & lifecycle
├── app.json                Page routing & tab bar config
├── app.wxss                Global dark theme styles
├── project.config.json     WeChat DevTools project config
├── utils/
│   ├── config.js           Backend URL (staging/production toggle)
│   ├── api.js              HTTP + file upload helpers
│   ├── storage.js          globalData wrappers (profile, history, plan)
│   └── i18n.js             Chinese/English strings + video URL routing
└── pages/
    ├── analyze/            Video picker → POST /analyze → result
    ├── result/             Score, form metrics, issues, exercise cards
    ├── plan/               Weekly km, goal, day chips → POST /training-plan
    ├── history/            Scrollable analysis history
    ├── profile/            Runner profile form
    ├── compare/            GET /athletes list + detail view
    └── webview/            Generic <web-view> (reserved for future use)
```

## Development Setup

### Prerequisites

- [WeChat DevTools](https://developers.weixin.qq.com/miniprogram/dev/devtools/download.html) ≥ 1.06
- WeChat developer account with a registered Mini Program AppID
- Node.js not required — this is native WXML/WXSS/JS, no build step

### 1. Clone and open

```bash
# From repo root
cd wechat
```

Open **WeChat DevTools** → **Import Project** → select the `wechat/` folder.

### 2. Set your AppID

Edit `project.config.json` and replace `"appid": "wx_YOUR_APPID_HERE"` with your real AppID from the [WeChat MP admin console](https://mp.weixin.qq.com).

### 3. Skip domain validation during development

In WeChat DevTools: **Details → Local Settings → Enable "不校验合法域名…"** (Skip domain validation). This allows requests to the staging backend without adding it to the trusted domain whitelist.

### 4. Switch backend environment

Edit `utils/config.js`:

```js
const ENV = 'staging'   // 'staging' | 'production'
```

## Backend Endpoints Used

| Feature | Endpoint |
|---------|----------|
| Video analysis | `POST /analyze` (multipart, field `video`) |
| Training plan | `POST /training-plan` |
| Elite athletes | `GET /athletes` |
| Compare (future) | `POST /compare` |
| Health check | `GET /health` |

Backend URLs:
- **Staging**: `https://runform-coach-ai-staging.up.railway.app`
- **Production**: `https://runform-coach-ai-production.up.railway.app`

## Publishing to WeChat MP

1. In WeChat DevTools → **Upload** (上传)
2. In [WeChat MP Admin](https://mp.weixin.qq.com) → **版本管理** → Submit for review
3. Before publishing to production, add the production domain to **开发→开发设置→服务器域名→request合法域名**

## Design System

Mirrors the iOS app dark theme:

| Token | Value |
|-------|-------|
| Background | `#0a0a0f` |
| Card | `rgba(255,255,255,0.06)` |
| Mint (primary) | `#00f5a0` |
| Cyan | `#00d4ff` |
| Orange (accent) | `#ff9f30` |
| Danger | `#ff4757` |

## Key Differences vs iOS

| Feature | iOS | WeChat |
|---------|-----|--------|
| On-device pose | Vision framework → `/analyze-metrics` | Not available — only `/analyze` |
| Exercise links | `openURL` to YouTube/Bilibili | `wx.setClipboardData` (copy search URL) |
| Locale detection | `Locale.current.region` | `wx.getSystemInfoSync().language` |
| Storage | Core Data + UserDefaults | `wx.setStorageSync` + `globalData` |

## Notes

- The mini program uses **Chinese as the primary language**; English strings are included for non-Chinese system locales.
- Exercise tutorial links copy a search URL to the clipboard (YouTube outside China, Bilibili inside China) because WeChat mini programs cannot open arbitrary external URLs via `openURL`.
- The `/analyze-metrics` endpoint (iOS-only pose metrics path) is **not used** — WeChat has no on-device Vision equivalent.
