// utils/share-card.js
// RF-913: Canvas 渲染分享卡片工具
// 支持 3 种场景：分析结果分享、对比结果分享、历史记录分享
// 分享卡片内容：RunForm Logo + 关键指标（步频/振幅/GCT）+ 小程序码 + "扫码体验"

const { isZh } = require('./i18n')

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
 *     scenario: 'analysis',   // 'analysis' | 'compare' | 'history'
 *     data: { ... },
 *     onSuccess: (tempFilePath) => { ... },
 *     onFail: (err) => { ... },
 *   })
 *
 *   ShareCard.saveToAlbum(tempFilePath)
 */

// ─── Layout constants ───

const W = 375                   // card width
const H = 580                   // card height (taller for 3 scenarios)
const PAD = 24                  // horizontal padding
const ACCENT = '#00f5a0'       // mint green
const BG_START = '#0a0a0f'
const BG_MID = '#12121a'
const FONT = '-apple-system, "PingFang SC", sans-serif'

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

function drawBackground(ctx) {
  const bgGrad = ctx.createLinearGradient(0, 0, 0, H)
  bgGrad.addColorStop(0, BG_START)
  bgGrad.addColorStop(0.5, BG_MID)
  bgGrad.addColorStop(1, BG_START)
  ctx.fillStyle = bgGrad
  ctx.fillRect(0, 0, W, H)

  // Accent band
  ctx.fillStyle = ACCENT
  ctx.fillRect(0, 0, W, 4)
}

function drawHeader(ctx, y) {
  // RunForm logo circle
  ctx.fillStyle = ACCENT
  ctx.beginPath()
  ctx.arc(PAD + 16, y + 18, 16, 0, Math.PI * 2)
  ctx.fill()

  ctx.fillStyle = BG_START
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
  ctx.fillText(isZh ? 'AI 跑姿分析' : 'AI Run Analysis', PAD + 40, y + 32)

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

// ─── Scenario: analysis (分析结果分享) ───

function drawAnalysisScenario(ctx, data) {
  let y = 30
  const { confidencePct, metrics, insights, overallAssessment } = data

  // Header
  y = drawHeader(ctx, y)

  // Divider
  y = drawDivider(ctx, y)

  // ── Score card ──
  ctx.fillStyle = 'rgba(0,245,160,0.08)'
  roundRect(ctx, PAD, y, W - PAD * 2, 100, 12)
  ctx.fill()

  ctx.fillStyle = ACCENT
  ctx.font = 'bold 56px ' + FONT
  ctx.textAlign = 'center'
  const scoreText = confidencePct != null ? `${confidencePct}` : '–'
  ctx.fillText(scoreText, W / 2, y + 56)

  ctx.fillStyle = 'rgba(255,255,255,0.6)'
  ctx.font = '13px ' + FONT
  ctx.fillText(isZh ? '跑姿评分' : 'FORM SCORE', W / 2, y + 82)

  y += 120

  // ── Key metrics circle row ──
  // Extract real metrics: cadence (步频), vertical oscillation (振幅), GCT (触地时间)
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

      // Progress arc
      const pct = m.pct || 0
      ctx.beginPath()
      const startAngle = -Math.PI / 2
      const endAngle = startAngle + (Math.PI * 2 * pct) / 100
      ctx.arc(cx, y + 20, 16, startAngle, endAngle)
      ctx.strokeStyle = m.color || ACCENT
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
      ctx.fillText(m.valueText || `${m.pct}%`, cx, y + 68)
    })
    y += 82
  }

  // ── Key finding ──
  if (insights && insights.length > 0) {
    ctx.textAlign = 'left'
    ctx.fillStyle = 'rgba(255,255,255,0.4)'
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
    ctx.fillStyle = 'rgba(255,255,255,0.4)'
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

function drawCompareScenario(ctx, data) {
  let y = 30
  const { userMetrics, athleteName, athleteStats, comparisonRows } = data

  // Header
  y = drawHeader(ctx, y)

  // Title
  y = drawDivider(ctx, y)

  ctx.textAlign = 'center'
  ctx.fillStyle = '#ffffff'
  ctx.font = 'bold 18px ' + FONT
  const vsTitle = isZh
    ? `你 vs ${athleteName || '精英'}`
    : `You vs ${athleteName || 'Elite'}`
  ctx.fillText(vsTitle, W / 2, y + 20)

  y += 52

  // ── Comparison table ──
  // Use comparisonRows from the compare page if available; otherwise build from raw data
  let rows = comparisonRows || []

  if (rows.length === 0 && athleteStats && userMetrics) {
    // Build basic comparison from raw stats
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
          diffColor = diff >= 0 ? ACCENT : '#ff4757'
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
    // Table header
    const col1 = PAD + 8
    const col2 = PAD + 120
    const col3 = PAD + 210
    const col4 = W - PAD - 8

    ctx.textAlign = 'left'
    ctx.fillStyle = 'rgba(255,255,255,0.4)'
    ctx.font = '10px ' + FONT
    ctx.fillText('', col1, y + 14)
    ctx.textAlign = 'center'
    ctx.fillText(isZh ? '你' : 'YOU', col2 + 24, y + 14)
    ctx.fillText(isZh ? '精英' : 'ELITE', col3 + 24, y + 14)

    y += 24

    // Table rows
    const rowH = 36
    rows.slice(0, 3).forEach((row, i) => {
      const ry = y + i * rowH

      // Row background (alternating)
      if (i % 2 === 0) {
        ctx.fillStyle = 'rgba(255,255,255,0.03)'
        ctx.fillRect(PAD, ry, W - PAD * 2, rowH)
      }

      ctx.textAlign = 'left'
      ctx.fillStyle = 'rgba(255,255,255,0.8)'
      ctx.font = '12px ' + FONT
      ctx.fillText(row.label, col1, ry + rowH / 2 + 4)

      ctx.textAlign = 'center'
      ctx.fillStyle = ACCENT
      ctx.font = 'bold 12px ' + FONT
      ctx.fillText(row.userDisplay, col2 + 24, ry + rowH / 2 + 4)

      ctx.fillStyle = '#ffffff'
      ctx.font = '12px ' + FONT
      ctx.fillText(row.eliteDisplay, col3 + 24, ry + rowH / 2 + 4)
    })

    y += rows.slice(0, 3).length * rowH + 8

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

// ─── Scenario: history (历史记录分享) ───

function drawHistoryScenario(ctx, data) {
  let y = 30
  const { confidencePct, dateDisplay, overallAssessment, metrics, analysisCount } = data

  // Header
  y = drawHeader(ctx, y)
  y = drawDivider(ctx, y)

  // Title
  ctx.textAlign = 'center'
  ctx.fillStyle = '#ffffff'
  ctx.font = 'bold 18px ' + FONT
  ctx.fillText(isZh ? '历史跑姿记录' : 'Run History Record', W / 2, y + 20)
  y += 52

  // ── Score card (compact) ──
  ctx.fillStyle = 'rgba(0,245,160,0.08)'
  roundRect(ctx, PAD, y, W - PAD * 2, 80, 12)
  ctx.fill()

  ctx.fillStyle = ACCENT
  ctx.font = 'bold 48px ' + FONT
  ctx.textAlign = 'center'
  ctx.fillText(`${confidencePct != null ? confidencePct : '–'}`, W / 2, y + 44)

  ctx.fillStyle = 'rgba(255,255,255,0.6)'
  ctx.font = '12px ' + FONT
  ctx.fillText(isZh ? '跑姿评分' : 'FORM SCORE', W / 2, y + 66)

  y += 96

  // Date + analysis count
  ctx.textAlign = 'center'
  if (dateDisplay) {
    ctx.fillStyle = 'rgba(255,255,255,0.5)'
    ctx.font = '13px ' + FONT
    ctx.fillText(dateDisplay, W / 2, y)
    y += 24
  }

  if (analysisCount != null && analysisCount > 1) {
    ctx.fillStyle = 'rgba(255,255,255,0.4)'
    ctx.font = '12px ' + FONT
    ctx.fillText(
      isZh ? `共 ${analysisCount} 次分析记录` : `${analysisCount} analysis records`,
      W / 2,
      y
    )
    y += 28
  }

  // ── Key metrics inline ──
  if (metrics && metrics.length > 0) {
    y += 8
    const displayMetrics = metrics.slice(0, 3)
    const colW = (W - PAD * 2) / displayMetrics.length
    displayMetrics.forEach((m, i) => {
      const cx = PAD + i * colW + colW / 2
      const pct = m.pct || 0

      ctx.beginPath()
      ctx.arc(cx, y + 14, 14, 0, Math.PI * 2)
      ctx.strokeStyle = 'rgba(255,255,255,0.1)'
      ctx.lineWidth = 2.5
      ctx.stroke()

      ctx.beginPath()
      const sa = -Math.PI / 2
      const ea = sa + (Math.PI * 2 * pct) / 100
      ctx.arc(cx, y + 14, 14, sa, ea)
      ctx.strokeStyle = m.color || ACCENT
      ctx.stroke()

      ctx.fillStyle = 'rgba(255,255,255,0.6)'
      ctx.font = '9px ' + FONT
      ctx.textAlign = 'center'
      const short = m.label.length > 6 ? m.label.slice(0, 5) + '…' : m.label
      ctx.fillText(short, cx, y + 42)

      ctx.fillStyle = '#ffffff'
      ctx.font = 'bold 11px ' + FONT
      ctx.fillText(m.valueText || `${pct}%`, cx, y + 56)
    })
    y += 74
  }

  // Assessment text
  if (overallAssessment) {
    ctx.textAlign = 'center'
    ctx.fillStyle = 'rgba(255,255,255,0.55)'
    ctx.font = '11px ' + FONT
    const short = overallAssessment.length > 50
      ? overallAssessment.slice(0, 50) + '...'
      : overallAssessment
    ctx.fillText(short, W / 2, y + 8)
    y += 32
  }

  return y
}

// ─── Footer: QR code + CTA ───

function drawFooter(ctx, y, qrCodeImage) {
  // Divider
  y += 4
  ctx.strokeStyle = 'rgba(255,255,255,0.08)'
  ctx.lineWidth = 1
  ctx.beginPath()
  ctx.moveTo(PAD, y)
  ctx.lineTo(W - PAD, y)
  ctx.stroke()
  y += 16

  // CTA text
  ctx.textAlign = 'left'
  ctx.fillStyle = 'rgba(255,255,255,0.6)'
  ctx.font = '12px ' + FONT
  ctx.fillText(isZh ? '扫码测测你的跑姿 →' : 'Scan to analyze your run →', PAD, y + 14)

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
 * @param {string} options.scenario      - 'analysis' | 'compare' | 'history'
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

        // Draw background
        drawBackground(ctx)

        // Draw scenario-specific content
        let contentEndY
        switch (scenario) {
          case 'compare':
            contentEndY = drawCompareScenario(ctx, data)
            break
          case 'history':
            contentEndY = drawHistoryScenario(ctx, data)
            break
          case 'analysis':
          default:
            contentEndY = drawAnalysisScenario(ctx, data)
            break
        }

        // Draw shared footer
        drawFooter(ctx, contentEndY + 8, options.qrCodeImage)

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
    wx.showToast({ title: isZh ? '图片未生成' : 'Image not ready', icon: 'none' })
    return
  }

  wx.saveImageToPhotosAlbum({
    filePath: tempFilePath,
    success: () => {
      wx.showToast({ title: isZh ? '已保存到相册' : 'Saved to album', icon: 'success' })
    },
    fail: (err) => {
      if (err.errMsg && err.errMsg.includes('auth deny')) {
        wx.showModal({
          title: isZh ? '需要相册权限' : 'Album permission needed',
          content: isZh ? '请在设置中开启相册权限' : 'Please enable album permission in settings',
          confirmText: isZh ? '去设置' : 'Settings',
          success: (res) => {
            if (res.confirm) {
              wx.openSetting()
            }
          },
        })
      } else {
        wx.showToast({ title: isZh ? '保存失败' : 'Save failed', icon: 'none' })
      }
    },
  })
}

module.exports = { generate, saveToAlbum, tryFetchQRCode: _tryFetchQRCode, W, H }
