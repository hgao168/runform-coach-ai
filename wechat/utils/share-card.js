// utils/share-card.js
// RF-913: Canvas 渲染分享卡片工具
// RF-1011: 3种场景差异化设计（分析/对比/洞察）
// 分析结果分享卡：评分圆环 + 关键指标 + 小程序码
// 对比结果分享卡：用户 vs 精英对比表 + 小程序码
// 洞察报告分享卡：周趋势迷你图 + AI建议摘要 + 小程序码

const { t, isZh } = require('./i18n')

// ─── QR Code helper ──────────────────────────────────────────────────────
// WeChat cloud.openapi.wxacode.getUnlimited generates a real mini-program
// QR code.  This module provides optional dynamic fetching.
// For static fallback see _drawQRPlaceholder() below.
async function _tryFetchQRCode() {
  try {
    if (typeof wx === 'undefined' || !wx.cloud) return null
    await wx.cloud.init()
    const result = await wx.cloud.callFunction({
      name: 'generateQRCode',
      data: { page: 'pages/index/index', width: 280 },
    })
    if (result && result.result && result.result.buffer) {
      return `data:image/png;base64,${result.result.buffer}`
    }
    // alternative: direct openapi call (requires cloud SDK)
    const qrRes = await wx.cloud.openapi.wxacode.getUnlimited({
      page: 'pages/index/index', width: 280,
    })
    if (qrRes && qrRes.buffer) {
      return `data:image/png;base64,${qrRes.buffer.toString('base64')}`
    }
    return null
  } catch (_) {
    console.warn('[ShareCard] QR code fetch failed — using placeholder', _)
    return null
  }
}

/** Draw a minimal QR-code-style pattern when no real image is available. */
function _drawQRPlaceholder(ctx, x, y, size) {
  const cols = 7, rows = cols, cell = Math.floor(size / (cols + 1))
  const ox = x + Math.floor((size - cell * cols) / 2)
  const oy = y + Math.floor((size - cell * rows) / 2)
  ctx.fillStyle = 'rgba(0,245,160,0.45)'
  // deterministic pattern so the placeholder is consistent
  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      // skip centre and corners — typical WeChat QR centre eye
      if ((c < 2 && r < 2) || (c < 2 && r >= rows - 2) || (c >= cols - 2 && r < 2)) continue
      if ((r * 7 + c * 3 + c * r) % 3 !== 0) {
        ctx.fillRect(ox + c * cell, oy + r * cell, cell, cell)
      }
    }
  }
  // center dot
  ctx.fillStyle = 'rgba(0,245,160,0.7)'
  ctx.beginPath()
  ctx.arc(x + size / 2, y + size / 2, cell * 1.2, 0, Math.PI * 2)
  ctx.fill()
}

/**
 * ShareCard — generates a Canvas-based share image and provides save-to-album.
 *
 * Usage:
 *   const ShareCard = require('../../utils/share-card')
 *
 *   ShareCard.generate({
 *     canvasId: 'shareCanvas',
 *     scenario: 'analysis',   // 'analysis' | 'compare' | 'insight'
 *     data: { ... },
 *     onSuccess: (tempFilePath) => { ... },
 *     onFail: (err) => { ... },
 *   })
 *
 *   ShareCard.saveToAlbum(tempFilePath)
 */

// ─── Layout constants ───

const W = 375                   // card width
const H = 580                   // card height
const PAD = 24                  // horizontal padding
const FONT = '-apple-system, "PingFang SC", sans-serif'

// ─── Scenario color schemes (RF-1011) ───
// Each scenario gets a distinct accent color and background gradient

const SCENARIO_COLORS = {
  analysis: {
    accent: '#00f5a0',           // mint green
    accentDim: 'rgba(0,245,160,0.4)',
    accentBg: 'rgba(0,245,160,0.08)',
    bgGradStart: '#0a0a0f',
    bgGradMid: '#12121a',
    secondary: '#00d4ff',
  },
  compare: {
    accent: '#ff9f30',           // orange
    accentDim: 'rgba(255,159,48,0.4)',
    accentBg: 'rgba(255,159,48,0.08)',
    bgGradStart: '#0f0a08',
    bgGradMid: '#1a1412',
    secondary: '#ff6b9d',
  },
  insight: {
    accent: '#00d4ff',           // cyan
    accentDim: 'rgba(0,212,255,0.4)',
    accentBg: 'rgba(0,212,255,0.08)',
    bgGradStart: '#0a0f14',
    bgGradMid: '#121a1f',
    secondary: '#a78bfa',        // purple
  },
}

/** Get color scheme, defaulting to analysis */
function _colors(scenario) {
  return SCENARIO_COLORS[scenario] || SCENARIO_COLORS.analysis
}

// ─── Helpers ───

function roundRect(ctx, x, y, w, h, r) {
  ctx.beginPath()
  ctx.moveTo(x + r, y)
  ctx.lineTo(x + w - r, y)
  ctx.arcTo(x + w, y, x + w, y + r, r)
  ctx.lineTo(x + w, y + h - r)
  ctx.arcTo(x + w, y + h, x + w - r, y + h, r)
  ctx.lineTo(x + r, y + h)
  ctx.arcTo(x, y + h, x, y + h - r, r)
  ctx.lineTo(x, y + r)
  ctx.arcTo(x, y, x + r, y, r)
  ctx.closePath()
}

// ─── Common background & header ───

function drawBackground(ctx, scenario) {
  const c = _colors(scenario)
  const bgGrad = ctx.createLinearGradient(0, 0, 0, H)
  bgGrad.addColorStop(0, c.bgGradStart)
  bgGrad.addColorStop(0.5, c.bgGradMid)
  bgGrad.addColorStop(1, c.bgGradStart)
  ctx.fillStyle = bgGrad
  ctx.fillRect(0, 0, W, H)

  // Accent band — uses scenario accent color
  ctx.fillStyle = c.accent
  ctx.fillRect(0, 0, W, 4)
}

function drawHeader(ctx, y, scenario) {
  const c = _colors(scenario)

  // RunForm logo circle
  ctx.fillStyle = c.accent
  ctx.beginPath()
  ctx.arc(PAD + 16, y + 18, 16, 0, Math.PI * 2)
  ctx.fill()

  ctx.fillStyle = c.bgGradStart
  ctx.font = 'bold 10px ' + FONT
  ctx.textAlign = 'center'
  ctx.fillText('🏃', PAD + 16, y + 22)

  // App name + subtitle
  ctx.textAlign = 'left'
  ctx.fillStyle = '#ffffff'
  ctx.font = 'bold 16px ' + FONT
  ctx.fillText(isZh ? 'RunForm 跑步教练' : 'RunForm Coach AI', PAD + 40, y + 14)

  ctx.fillStyle = 'rgba(255,255,255,0.4)'
  ctx.font = '11px ' + FONT

  // Different subtitle per scenario
  let subtitle
  switch (scenario) {
    case 'compare':
      subtitle = isZh ? '精英运动员对比' : 'Elite Athlete Comparison'
      break
    case 'insight':
      subtitle = isZh ? '周训练洞察报告' : 'Weekly Training Insight'
      break
    case 'analysis':
    default:
      subtitle = isZh ? 'AI 跑姿分析' : 'AI Run Analysis'
      break
  }
  ctx.fillText(subtitle, PAD + 40, y + 32)

  return y + 58
}

function drawDivider(ctx, y) {
  ctx.strokeStyle = 'rgba(255,255,255,0.08)'
  ctx.lineWidth = 1
  ctx.beginPath()
  ctx.moveTo(PAD, y)
  ctx.lineTo(W - PAD, y)
  ctx.stroke()
  return y + 20
}

// ─── Mini sparkline helper (RF-1011: insight trend) ───

/**
 * Draw a mini sparkline chart (no axes, just the curve).
 * @param {CanvasRenderingContext2D} ctx
 * @param {number[]} values  - Data points
 * @param {number} x         - Left edge
 * @param {number} y         - Top edge
 * @param {number} w         - Width
 * @param {number} h         - Height
 * @param {string} color     - Line color
 */
function _drawSparkline(ctx, values, x, y, w, h, color) {
  if (!values || values.length < 2) return

  const valid = values.filter((v) => v != null)
  if (valid.length < 2) return

  let vMin = Infinity, vMax = -Infinity
  for (const v of valid) {
    if (v < vMin) vMin = v
    if (v > vMax) vMax = v
  }
  if (vMin === vMax) {
    vMin -= 1
    vMax += 1
  }

  const step = w / (valid.length - 1)

  // Fill area under curve (subtle gradient)
  const fillGrad = ctx.createLinearGradient(0, y, 0, y + h)
  fillGrad.addColorStop(0, color.replace(')', ',0.15)').replace('rgb', 'rgba'))
  fillGrad.addColorStop(1, 'rgba(255,255,255,0)')
  ctx.fillStyle = fillGrad
  ctx.beginPath()
  valid.forEach((v, i) => {
    const px = x + i * step
    const py = y + h - ((v - vMin) / (vMax - vMin)) * h
    if (i === 0) ctx.moveTo(px, py)
    else ctx.lineTo(px, py)
  })
  ctx.lineTo(x + (valid.length - 1) * step, y + h)
  ctx.lineTo(x, y + h)
  ctx.closePath()
  ctx.fill()

  // Line
  ctx.strokeStyle = color
  ctx.lineWidth = 2
  ctx.lineJoin = 'round'
  ctx.lineCap = 'round'
  ctx.beginPath()
  valid.forEach((v, i) => {
    const px = x + i * step
    const py = y + h - ((v - vMin) / (vMax - vMin)) * h
    if (i === 0) ctx.moveTo(px, py)
    else ctx.lineTo(px, py)
  })
  ctx.stroke()

  // Start/end dots
  ctx.fillStyle = color
  valid.forEach((v, i) => {
    if (i === 0 || i === valid.length - 1) {
      const px = x + i * step
      const py = y + h - ((v - vMin) / (vMax - vMin)) * h
      ctx.beginPath()
      ctx.arc(px, py, 3, 0, Math.PI * 2)
      ctx.fill()
    }
  })
}

// ─── Scenario: analysis (分析结果分享) ───
// RF-1011: 评分圆环 + 关键指标 + 小程序码

function drawAnalysisScenario(ctx, data) {
  let y = 30
  const c = _colors('analysis')
  const { confidencePct, metrics, insights, overallAssessment } = data

  // Header
  y = drawHeader(ctx, y, 'analysis')

  // Divider
  y = drawDivider(ctx, y)

  // ── Score ring (RF-1011: circular gauge instead of plain text) ──
  const ringCx = W / 2
  const ringCy = y + 56
  const ringR = 44
  const ringW = 6

  // Score card background
  ctx.fillStyle = c.accentBg
  roundRect(ctx, PAD, y, W - PAD * 2, 116, 12)
  ctx.fill()

  // Background ring
  ctx.beginPath()
  ctx.arc(ringCx, ringCy, ringR, 0, Math.PI * 2)
  ctx.strokeStyle = 'rgba(255,255,255,0.1)'
  ctx.lineWidth = ringW
  ctx.stroke()

  // Progress arc
  const pct = Math.min(Math.max(confidencePct || 0, 0), 100)
  const startAngle = -Math.PI / 2
  const endAngle = startAngle + (Math.PI * 2 * pct) / 100
  ctx.beginPath()
  ctx.arc(ringCx, ringCy, ringR, startAngle, endAngle)
  ctx.strokeStyle = c.accent
  ctx.lineWidth = ringW
  ctx.lineCap = 'round'
  ctx.stroke()

  // Score text inside ring
  ctx.fillStyle = c.accent
  ctx.font = 'bold 36px ' + FONT
  ctx.textAlign = 'center'
  const scoreText = confidencePct != null ? `${confidencePct}` : '–'
  ctx.fillText(scoreText, ringCx, ringCy - 2)

  // Label below ring
  ctx.fillStyle = 'rgba(255,255,255,0.5)'
  ctx.font = '11px ' + FONT
  ctx.fillText(isZh ? '跑姿评分' : 'FORM SCORE', ringCx, ringCy + 34)

  y += 136

  // ── Key metrics circle row ──
  const keyMetricKeys = [
    { match: ['cadence', '步频'], labelZh: '步频', labelEn: 'Cadence' },
    { match: ['oscillation', '振幅', 'vertical'], labelZh: '振幅', labelEn: 'Osc.' },
    { match: ['ground', 'contact', '触地', 'gct'], labelZh: '触地', labelEn: 'GCT' },
  ]

  const keyMetrics = []
  if (metrics && metrics.length > 0) {
    for (const mk of keyMetricKeys) {
      const found = metrics.find((m) => {
        const label = (m.label || '').toLowerCase()
        return mk.match.some((kw) => label.includes(kw.toLowerCase()))
      })
      if (found) {
        keyMetrics.push({ ...found, displayLabel: isZh ? mk.labelZh : mk.labelEn })
      }
    }
  }

  // Fallback: use first 3 metrics
  if (keyMetrics.length === 0 && metrics && metrics.length > 0) {
    const fallback = metrics.slice(0, 3)
    for (const m of fallback) {
      keyMetrics.push({ ...m, displayLabel: m.label.length > 6 ? m.label.slice(0, 5) + '…' : m.label })
    }
  }

  if (keyMetrics.length > 0) {
    ctx.textAlign = 'left'
    const colW = (W - PAD * 2) / Math.min(keyMetrics.length, 4)
    keyMetrics.forEach((m, i) => {
      const cx = PAD + i * colW + colW / 2

      // Background circle
      ctx.beginPath()
      ctx.arc(cx, y + 20, 16, 0, Math.PI * 2)
      ctx.strokeStyle = 'rgba(255,255,255,0.1)'
      ctx.lineWidth = 3
      ctx.stroke()

      // Progress arc (use scenario accent)
      const mpct = m.pct || 0
      ctx.beginPath()
      const sa = -Math.PI / 2
      const ea = sa + (Math.PI * 2 * mpct) / 100
      ctx.arc(cx, y + 20, 16, sa, ea)
      ctx.strokeStyle = m.color || c.accent
      ctx.lineWidth = 3
      ctx.stroke()

      // Label
      ctx.fillStyle = 'rgba(255,255,255,0.7)'
      ctx.font = '10px ' + FONT
      ctx.textAlign = 'center'
      ctx.fillText(m.displayLabel || m.label, cx, y + 52)

      // Value
      ctx.fillStyle = '#ffffff'
      ctx.font = 'bold 12px ' + FONT
      ctx.fillText(m.valueText || `${mpct}%`, cx, y + 68)
    })
    y += 82
  }

  // ── Key finding ──
  if (insights && insights.length > 0) {
    ctx.textAlign = 'left'
    ctx.fillStyle = c.accentDim
    ctx.font = '11px ' + FONT
    ctx.fillText(isZh ? '关键发现' : 'KEY FINDING', PAD, y + 14)

    ctx.fillStyle = '#ffffff'
    ctx.font = '13px ' + FONT
    const insightText = insights[0].title.length > 36
      ? insights[0].title.slice(0, 36) + '...'
      : insights[0].title
    ctx.fillText(insightText, PAD, y + 34)
    y += 50
  } else if (overallAssessment) {
    ctx.textAlign = 'left'
    ctx.fillStyle = c.accentDim
    ctx.font = '11px ' + FONT
    ctx.fillText(isZh ? '综合评估' : 'ASSESSMENT', PAD, y + 14)

    ctx.fillStyle = '#ffffff'
    ctx.font = '13px ' + FONT
    const short = overallAssessment.length > 40
      ? overallAssessment.slice(0, 40) + '...'
      : overallAssessment
    ctx.fillText(short, PAD, y + 34)
    y += 50
  }

  return y
}

// ─── Scenario: compare (对比结果分享) ───
// RF-1011: 用户 vs 精英对比表 + 小程序码

function drawCompareScenario(ctx, data) {
  let y = 30
  const c = _colors('compare')
  const { userMetrics, athleteName, athleteStats, comparisonRows } = data

  // Header
  y = drawHeader(ctx, y, 'compare')

  // Divider
  y = drawDivider(ctx, y)

  // Title
  ctx.textAlign = 'center'
  ctx.fillStyle = '#ffffff'
  ctx.font = 'bold 18px ' + FONT
  const vsTitle = isZh
    ? `你 vs ${athleteName || '精英'}`
    : `You vs ${athleteName || 'Elite'}`
  ctx.fillText(vsTitle, W / 2, y + 20)

  y += 52

  // ── Comparison table (RF-1011: enhanced with gap colors and card background) ──
  let rows = comparisonRows || []

  if (rows.length === 0 && athleteStats && userMetrics) {
    const metricMeta = [
      { key: 'cadence', labelZh: '步频', labelEn: 'Cadence', unit: 'spm', format: (v) => Math.round(v).toString() },
      { key: 'vertical_oscillation', labelZh: '振幅', labelEn: 'Osc.', unit: 'cm', format: (v) => v.toFixed(1) },
      { key: 'ground_contact_time', labelZh: '触地时间', labelEn: 'GCT', unit: 'ms', format: (v) => Math.round(v).toString() },
    ]
    const eliteStats = {}
    for (const s of (athleteStats || [])) {
      eliteStats[s.key || s.label] = s.value
    }
    rows = metricMeta
      .filter((m) => userMetrics[m.key] != null)
      .map((m) => {
        const userVal = userMetrics[m.key]
        const eliteVal = eliteStats[m.key]
        const bothHave = userVal != null && eliteVal != null
        let diffColor = ''
        if (bothHave) {
          const diff = m.key === 'cadence' ? userVal - eliteVal : eliteVal - userVal
          diffColor = diff >= 0 ? c.accent : '#ff4757'
        }
        return {
          label: isZh ? m.labelZh : m.labelEn,
          userDisplay: userVal != null ? m.format(userVal) : '–',
          eliteDisplay: eliteVal != null ? m.format(eliteVal) : '–',
          unit: m.unit,
          diffColor,
        }
      })
  }

  if (rows.length > 0) {
    // Table background card
    const tableH = 8 + 24 + rows.slice(0, 4).length * 36 + 8
    ctx.fillStyle = c.accentBg
    roundRect(ctx, PAD, y, W - PAD * 2, tableH + 8, 10)
    ctx.fill()

    y += 8

    // Table header
    const col1 = PAD + 16
    const col2 = PAD + 130
    const col3 = PAD + 210
    const col4 = W - PAD - 16

    ctx.textAlign = 'left'
    ctx.fillStyle = c.accentDim
    ctx.font = '10px ' + FONT
    ctx.fillText('', col1, y + 14)
    ctx.textAlign = 'center'
    ctx.fillText(isZh ? '你' : 'YOU', col2 + 24, y + 14)
    ctx.fillText(isZh ? (athleteName || '精英') : (athleteName || 'ELITE'), col3 + 24, y + 14)

    y += 24

    // Table rows
    const rowH = 36
    rows.slice(0, 4).forEach((row, i) => {
      const ry = y + i * rowH

      // Row background (alternating in accent)
      if (i % 2 === 0) {
        ctx.fillStyle = 'rgba(255,255,255,0.02)'
        ctx.fillRect(PAD, ry, W - PAD * 2, rowH)
      }

      ctx.textAlign = 'left'
      ctx.fillStyle = 'rgba(255,255,255,0.8)'
      ctx.font = '12px ' + FONT
      ctx.fillText(row.label, col1, ry + rowH / 2 + 4)

      // User value — in accent color
      ctx.textAlign = 'center'
      ctx.fillStyle = c.accent
      ctx.font = 'bold 13px ' + FONT
      ctx.fillText(row.userDisplay, col2 + 24, ry + rowH / 2 + 4)

      // Elite value
      ctx.fillStyle = '#ffffff'
      ctx.font = '13px ' + FONT
      ctx.fillText(row.eliteDisplay, col3 + 24, ry + rowH / 2 + 4)

      // Gap indicator (colored bar on right)
      if (row.diffColor) {
        ctx.fillStyle = row.diffColor
        ctx.fillRect(col4 - 4, ry + rowH / 2 - 1, 4, 2)
      }
    })

    y += rows.slice(0, 4).length * rowH + 12

    // Unit hint
    if (rows[0] && rows[0].unit) {
      ctx.textAlign = 'right'
      ctx.fillStyle = 'rgba(255,255,255,0.3)'
      ctx.font = '9px ' + FONT
      ctx.fillText(isZh ? `单位: ${rows[0].unit}` : `Unit: ${rows[0].unit}`, W - PAD, y)
      y += 16
    }
  } else {
    // No comparison data
    ctx.textAlign = 'center'
    ctx.fillStyle = 'rgba(255,255,255,0.3)'
    ctx.font = '12px ' + FONT
    ctx.fillText(isZh ? '点击查看完整对比' : 'Tap to view full comparison', W / 2, y + 20)
    y += 40
  }

  return y
}

// ─── Scenario: insight (洞察报告分享) ───
// RF-1011: 周趋势迷你图 + AI建议摘要 + 小程序码

function drawInsightScenario(ctx, data) {
  let y = 30
  const c = _colors('insight')
  const {
    comparison, trendDatasets, trendLabels, aiAdvice, badges,
    confidencePct, dateDisplay,
  } = data

  // Header
  y = drawHeader(ctx, y, 'insight')
  y = drawDivider(ctx, y)

  // ── Title ──
  ctx.textAlign = 'center'
  ctx.fillStyle = '#ffffff'
  ctx.font = 'bold 18px ' + FONT
  ctx.fillText(isZh ? '周训练洞察' : 'Weekly Training Insight', W / 2, y + 20)
  y += 46

  // ── Date / score info ──
  if (dateDisplay || confidencePct != null) {
    ctx.textAlign = 'center'
    ctx.fillStyle = 'rgba(255,255,255,0.4)'
    ctx.font = '11px ' + FONT
    let infoLine = ''
    if (dateDisplay) infoLine += dateDisplay
    if (confidencePct != null) {
      infoLine += infoLine ? ` · ${isZh ? '综合' : 'Score'} ${confidencePct}` : `${isZh ? '综合评分' : 'Score'} ${confidencePct}`
    }
    ctx.fillText(infoLine, W / 2, y)
    y += 22
  }

  // Divider
  y = drawDivider(ctx, y - 2)

  // ── Weekly change comparison cards ──
  if (comparison && comparison.length > 0) {
    ctx.textAlign = 'left'
    ctx.fillStyle = c.accentDim
    ctx.font = '11px ' + FONT
    ctx.fillText(isZh ? '本周 vs 上周' : 'This Week vs Last Week', PAD, y)
    y += 18

    const cardW = (W - PAD * 2 - 16) / Math.min(comparison.length, 4)
    comparison.slice(0, 4).forEach((item, i) => {
      const cx = PAD + i * (cardW + 4)
      const cardH = 48
      const pct = item.changePct
      const isGood = pct > 0

      ctx.fillStyle = c.accentBg
      roundRect(ctx, cx, y, cardW, cardH, 6)
      ctx.fill()

      ctx.fillStyle = 'rgba(255,255,255,0.6)'
      ctx.font = '9px ' + FONT
      ctx.textAlign = 'center'
      ctx.fillText(item.label, cx + cardW / 2, y + 14)

      const changeColor = isGood ? c.accent : '#ff4757'
      const changeText = (pct > 0 ? '+' : '') + pct.toFixed(1) + '%'
      ctx.fillStyle = changeColor
      ctx.font = 'bold 13px ' + FONT
      ctx.fillText(changeText, cx + cardW / 2, y + 34)
    })
    y += 56
  }

  // ── Trend mini sparklines ──
  if (trendDatasets && trendDatasets.length > 0) {
    ctx.textAlign = 'left'
    ctx.fillStyle = c.accentDim
    ctx.font = '11px ' + FONT
    ctx.fillText(isZh ? '4周趋势' : '4-Week Trend', PAD, y)
    y += 16

    // Layout: label + sparkline per dataset
    const sparkH = 28
    const sparkW = 100
    const labelW = 50
    const maxDs = Math.min(trendDatasets.length, 3)

    trendDatasets.slice(0, maxDs).forEach((ds, i) => {
      const ry = y + i * (sparkH + 6)

      // Label
      ctx.textAlign = 'right'
      ctx.fillStyle = 'rgba(255,255,255,0.5)'
      ctx.font = '10px ' + FONT
      ctx.fillText(ds.label, PAD + labelW - 4, ry + sparkH / 2 + 4)

      // Sparkline
      _drawSparkline(ctx, ds.data, PAD + labelW + 4, ry, sparkW, sparkH, ds.color || c.accent)
    })

    y += maxDs * (sparkH + 6) + 8
  }

  // ── AI advice summary ──
  if (aiAdvice) {
    ctx.textAlign = 'left'
    ctx.fillStyle = c.accentDim
    ctx.font = '11px ' + FONT
    ctx.fillText(isZh ? 'AI 教练建议' : 'AI Coach Advice', PAD, y)
    y += 16

    // Advice background
    const adviceLines = _wrapText(ctx, aiAdvice, W - PAD * 2 - 16, 11, FONT, false)
    const adviceH = 8 + adviceLines.length * 18 + 8

    ctx.fillStyle = 'rgba(167,139,250,0.08)'
    roundRect(ctx, PAD, y, W - PAD * 2, adviceH, 8)
    ctx.fill()

    ctx.fillStyle = 'rgba(255,255,255,0.7)'
    ctx.font = '11px ' + FONT
    ctx.textAlign = 'left'
    adviceLines.forEach((line, i) => {
      ctx.fillText(line, PAD + 12, y + 16 + i * 18)
    })

    y += adviceH + 8
  }

  // ── Badges summary ──
  if (badges && badges.length > 0) {
    ctx.textAlign = 'left'
    ctx.fillStyle = c.accentDim
    ctx.font = '11px ' + FONT
    ctx.fillText(isZh ? '本周成就' : 'Achievements', PAD, y)
    y += 16

    const badgeW = Math.min((W - PAD * 2) / badges.length, 100)
    badges.slice(0, 3).forEach((b, i) => {
      const bx = PAD + i * badgeW
      ctx.fillStyle = 'rgba(255,255,255,0.5)'
      ctx.font = '24px ' + FONT
      ctx.textAlign = 'center'
      ctx.fillText(b.icon || '🏅', bx + badgeW / 2, y + 8)
    })
    y += 38
  }

  return y
}

// ─── Text wrapping helper (move to module level) ───

function _wrapText(ctx, text, maxWidth, fontSize, fontFace, center) {
  if (!text) return []
  // Approximate: set font then measure
  const prevFont = ctx.font
  ctx.font = (fontSize || 12) + 'px ' + (fontFace || FONT)
  const chars = text.replace(/\n/g, ' ').split('')
  const lines = []
  let current = ''
  for (const ch of chars) {
    const test = current + ch
    if (ctx.measureText(test).width > maxWidth && current.length > 0) {
      lines.push(current)
      current = ch
    } else {
      current = test
    }
  }
  if (current) lines.push(current)
  ctx.font = prevFont
  return lines.slice(0, 4) // Max 4 lines
}

// ─── Footer: QR code + CTA ───

function drawFooter(ctx, y, qrCodeImage, scenario) {
  const c = _colors(scenario)

  // Divider
  y += 4
  ctx.strokeStyle = 'rgba(255,255,255,0.08)'
  ctx.lineWidth = 1
  ctx.beginPath()
  ctx.moveTo(PAD, y)
  ctx.lineTo(W - PAD, y)
  ctx.stroke()
  y += 16

  // CTA text — different per scenario
  ctx.textAlign = 'left'
  ctx.fillStyle = 'rgba(255,255,255,0.6)'
  ctx.font = '12px ' + FONT

  let ctaText
  switch (scenario) {
    case 'compare':
      ctaText = isZh ? '扫码对比你的跑姿 →' : 'Scan to compare your run →'
      break
    case 'insight':
      ctaText = isZh ? '扫码查看你的洞察 →' : 'Scan to see your insight →'
      break
    case 'analysis':
    default:
      ctaText = isZh ? '扫码测测你的跑姿 →' : 'Scan to analyze your run →'
      break
  }
  ctx.fillText(ctaText, PAD, y + 14)

  // QR code — use real image if available, otherwise draw patterned placeholder
  const qrX = W - PAD - 48
  const qrY = y - 4
  const qrSize = 48

  if (qrCodeImage) {
    try {
      ctx.drawImage(qrCodeImage, qrX, qrY, qrSize, qrSize)
    } catch (_) {
      _drawQRPlaceholder(ctx, qrX, qrY, qrSize)
    }
  } else {
    _drawQRPlaceholder(ctx, qrX, qrY, qrSize)
  }

  y += 56

  // Bottom branding
  ctx.textAlign = 'center'
  ctx.fillStyle = 'rgba(255,255,255,0.2)'
  ctx.font = '9px ' + FONT
  ctx.fillText(
    isZh ? 'Powered by RunForm · movenova.ai' : 'Powered by RunForm · movenova.ai',
    W / 2,
    y + 10
  )

  return y + 20
}

// ─── Main generate function ───

/**
 * Generate a share card image using Canvas 2D.
 *
 * @param {Object} options
 * @param {string} options.canvasId      - Canvas component ID (e.g. 'shareCanvas')
 * @param {string} options.scenario      - 'analysis' | 'compare' | 'insight'
 * @param {Object} options.data          - Data for the card (varies by scenario)
 * @param {Function} options.onSuccess   - Called with tempFilePath
 * @param {Function} options.onFail      - Called with error
 * @param {Object} [options.ctx]         - Optional: pre-acquired Canvas context
 * @param {CanvasImageSource} [options.qrCodeImage] - Optional: WeChat Canvas Image object
 *        for the mini-program QR code.  If omitted, a stylized placeholder is drawn.
 *        Obtain via cloud.openapi.wxacode.getUnlimited or a static asset in assets/.
 */
function generate(options) {
  const { canvasId, scenario, data, onSuccess, onFail, pageInstance } = options

  if (!pageInstance) {
    console.error('[ShareCard] pageInstance is required to query canvas')
    if (onFail) onFail(new Error('pageInstance required'))
    return
  }

  const query = wx.createSelectorQuery().in(pageInstance)
  query.select(`#${canvasId}`)
    .fields({ node: true, size: true })
    .exec((res) => {
      if (!res || !res[0] || !res[0].node) {
        const err = new Error('Canvas node not found: #' + canvasId)
        console.error('[ShareCard]', err.message)
        if (onFail) onFail(err)
        return
      }

      try {
        const canvas = res[0].node
        const ctx = canvas.getContext('2d')
        const dpr = wx.getSystemInfoSync().pixelRatio || 2

        canvas.width = W * dpr
        canvas.height = H * dpr
        ctx.scale(dpr, dpr)

        // Clear
        ctx.clearRect(0, 0, W, H)

        // Draw background (scenario-aware)
        drawBackground(ctx, scenario)

        // Draw scenario-specific content
        let contentEndY
        switch (scenario) {
          case 'compare':
            contentEndY = drawCompareScenario(ctx, data)
            break
          case 'insight':
            contentEndY = drawInsightScenario(ctx, data)
            break
          case 'history':
            // Backward compat: 'history' maps to basic analysis-style card
            contentEndY = drawInsightScenario(ctx, data)
            break
          case 'analysis':
          default:
            contentEndY = drawAnalysisScenario(ctx, data)
            break
        }

        // Draw shared footer (scenario-aware)
        drawFooter(ctx, contentEndY + 8, options.qrCodeImage, scenario)

        // Export to temp file
        wx.canvasToTempFilePath({
          canvas,
          success: (tempRes) => {
            if (onSuccess) onSuccess(tempRes.tempFilePath)
          },
          fail: (err) => {
            console.error('[ShareCard] canvasToTempFilePath failed:', err)
            if (onFail) onFail(err)
          },
        })
      } catch (e) {
        console.error('[ShareCard] draw error:', e)
        if (onFail) onFail(e)
      }
    })
}

/**
 * Save a temp file image to the user's photo album.
 * Requires scope.writePhotosAlbum permission.
 *
 * @param {string} tempFilePath - Path from canvasToTempFilePath
 */
function saveToAlbum(tempFilePath) {
  if (!tempFilePath) {
    wx.showToast({ title: t('shareGenNoImage'), icon: 'none' })
    return
  }

  wx.saveImageToPhotosAlbum({
    filePath: tempFilePath,
    success: () => {
      wx.showToast({ title: t('shareImageSaved'), icon: 'success' })
    },
    fail: (err) => {
      if (err.errMsg && err.errMsg.includes('auth deny')) {
        wx.showModal({
          title: t('albumPermTitle'),
          content: t('albumPermDesc'),
          confirmText: t('albumPermGoSettings'),
          success: (res) => {
            if (res.confirm) {
              wx.openSetting()
            }
          },
        })
      } else {
        wx.showToast({ title: t('saveFailed'), icon: 'none' })
      }
    },
  })
}

module.exports = { generate, saveToAlbum, tryFetchQRCode: _tryFetchQRCode, W, H }
