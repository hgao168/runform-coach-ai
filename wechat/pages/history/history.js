// pages/history/history.js
const storage = require('../../utils/storage')
const { t, isZh } = require('../../utils/i18n')
const ShareCard = require('../../utils/share-card')

function scoreColor(score) {
  const pct = Math.round((score || 0) * 100)
  if (pct >= 70) return '#00f5a0'
  if (pct >= 45) return '#ff9f30'
  return '#ff4757'
}

function formatDate(isoStr) {
  try {
    const d = new Date(isoStr)
    const y = d.getFullYear()
    const mo = String(d.getMonth() + 1).padStart(2, '0')
    const day = String(d.getDate()).padStart(2, '0')
    return `${y}-${mo}-${day}`
  } catch {
    return isoStr || ''
  }
}

function formatDateShort(isoStr) {
  try {
    const d = new Date(isoStr)
    const mo = String(d.getMonth() + 1).padStart(2, '0')
    const day = String(d.getDate()).padStart(2, '0')
    return `${mo}/${day}`
  } catch {
    return ''
  }
}

/**
 * Extract a metric value from a history item's result.
 * Tries raw values first, falls back to normalized scores.
 */
function extractMetric(result, key, rawKey, scoreScale) {
  const fm = result.form_metrics || result.metrics || {}
  if (fm[rawKey] != null) return fm[rawKey]
  if (fm[key] != null) {
    const v = fm[key]
    // If it's a score (0-1), scale it
    if (typeof v === 'number' && v <= 1 && v >= 0) {
      return scoreScale ? Math.round(v * scoreScale[0] + scoreScale[1]) : Math.round(v * 100)
    }
    return v
  }
  return null
}

/**
 * Build chart datasets from history items (reversed = chronological order).
 */
function buildChartData(rawItems) {
  // rawItems are already reversed (newest first). We want oldest first for chart.
  const items = [...rawItems].reverse()
  const recent = items.slice(-20) // last 20

  const labels = recent.map((item) => formatDateShort(item.date))
  const cadenceData = []
  const oscData = []
  const gctData = []

  for (const item of recent) {
    // cadence: raw = cadence_spm, score = cadence (scale 120-220)
    const cad = extractMetric(item.result, 'cadence', 'cadence_spm', [100, 120])
    // vertical oscillation: raw = vertical_oscillation_cm, score = vertical_oscillation (scale 5-13)
    const osc = extractMetric(item.result, 'vertical_oscillation', 'vertical_oscillation_cm', [8, 5])
    // ground contact time: raw = ground_contact_time_ms, score = ground_contact_time (scale 150-300)
    const gct = extractMetric(item.result, 'ground_contact_time', 'ground_contact_time_ms', [150, 150])

    cadenceData.push(cad)
    oscData.push(osc)
    gctData.push(gct)
  }

  return {
    labels,
    datasets: [
      { label: t('trendCadence'), data: cadenceData, color: '#00f5a0' },
      { label: t('trendOscillation'), data: oscData, color: '#00d4ff' },
      { label: t('trendGCT'), data: gctData, color: '#ff9f30' },
    ],
    hasData: recent.length >= 2 && (cadenceData.some((v) => v != null) || oscData.some((v) => v != null) || gctData.some((v) => v != null)),
  }
}

// Chart rendering constants
const CHART_PADDING_TOP = 40
const CHART_PADDING_RIGHT = 24
const CHART_PADDING_BOTTOM = 48
const CHART_PADDING_LEFT = 48
const DOT_RADIUS = 5
const LINE_WIDTH = 2.5
const GRID_COLOR = 'rgba(255,255,255,0.06)'
const TEXT_COLOR = 'rgba(255,255,255,0.4)'
const TOOLTIP_BG = 'rgba(10,10,15,0.92)'

Page({
  data: {
    i: {
      historyTitle: t('historyTitle'),
      historyEmpty: t('historyEmpty'),
      historyEmptySub: t('historyEmptySub'),
      deleteHistory: t('deleteHistory'),
      trendTitle: t('trendTitle'),
      trendToggle: t('trendToggle'),
      trendToggleHide: t('trendToggleHide'),
      trendNoData: t('trendNoData'),
      trendTapHint: t('trendTapHint'),
      startFirstAnalysis: t('startFirstAnalysis'),
    },
    items: [],
    // ── Milestone RF-605 ──
    milestone: null,            // { cadence, gct, score } or null
    milestoneVisible: false,    // celebration card modal
    _milestoneImagePath: '',

    // Trend chart state
    trendExpanded: false,
    trendReady: false,
    trendHasData: false,
    trendTooltip: null, // { x, y, text, color }
    trendDatasets: [],
    trendLabels: [],
  },

  // Internal
  _canvas: null,
  _ctx: null,
  _canvasWidth: 0,
  _canvasHeight: 0,
  _dpr: 1,
  _dataPoints: [], // [{ x, y, datasetIndex, dataIndex, value, label, color }]

  onShow() {
    this._loadHistory()
  },

  onReady() {
    this._initCanvas()
  },

  _initCanvas() {
    const query = wx.createSelectorQuery()
    query.select('#trendCanvas')
      .fields({ node: true, size: true })
      .exec((res) => {
        if (!res || !res[0] || !res[0].node) return
        const canvas = res[0].node
        const ctx = canvas.getContext('2d')
        const dpr = wx.getSystemInfoSync().pixelRatio || 2
        const width = res[0].width
        const height = res[0].height

        canvas.width = width * dpr
        canvas.height = height * dpr
        ctx.scale(dpr, dpr)

        this._canvas = canvas
        this._ctx = ctx
        this._canvasWidth = width
        this._canvasHeight = height
        this._dpr = dpr

        if (this.data.trendExpanded && this._chartData) {
          this._drawChart()
        }
      })
  },

  _loadHistory() {
    const raw = storage.getHistory()
    const items = [...raw].reverse().map((item) => {
      const score = item.overallScore ?? item.result?.overall_score ?? 0
      const pct = Math.round(score * 100)
      return {
        id: item.id,
        dateDisplay: formatDate(item.date),
        summary: item.summary || item.result?.overall_assessment || '',
        scoreDisplay: `${pct}%`,
        scoreColor: scoreColor(score),
        result: item.result,
      }
    })

    // Reversed items: newest first (for list). Chart needs oldest first.
    const chartData = buildChartData(raw)
    this._chartData = chartData

    this.setData({
      items,
      trendHasData: chartData.hasData,
      trendDatasets: chartData.datasets,
      trendLabels: chartData.labels,
    })

    // Redraw chart if visible
    if (this.data.trendExpanded && this._ctx) {
      this._drawChart()
    }

    // RF-605: Milestone detection
    this._detectMilestone(raw)
  },

  /**
   * RF-605: Detect running form improvement milestones.
   * Compares earliest record vs latest record for:
   *   - Cadence increase ≥ 10 SPM
   *   - GCT decrease ≥ 20 ms
   *   - Form score increase ≥ 10 points (out of 100)
   */
  _detectMilestone(rawHistory) {
    if (!rawHistory || rawHistory.length < 2) return

    const earliest = rawHistory[0]  // oldest (raw history is oldest-first)
    const latest = rawHistory[rawHistory.length - 1]  // newest

    const earlyRes = earliest && earliest.result ? earliest.result : null
    const lateRes = latest && latest.result ? latest.result : null
    if (!earlyRes || !lateRes) return

    const milestones = {}

    // Check cadence: raw cadence_spm or derived from score
    const earlyCadence = extractMetric(earlyRes, 'cadence', 'cadence_spm', [100, 120])
    const lateCadence = extractMetric(lateRes, 'cadence', 'cadence_spm', [100, 120])
    if (earlyCadence != null && lateCadence != null && lateCadence - earlyCadence >= 10) {
      milestones.cadence = Math.round(lateCadence - earlyCadence)
    }

    // Check GCT: raw ground_contact_time_ms, lower is better
    const earlyGct = extractMetric(earlyRes, 'ground_contact_time', 'ground_contact_time_ms', [150, 150])
    const lateGct = extractMetric(lateRes, 'ground_contact_time', 'ground_contact_time_ms', [150, 150])
    if (earlyGct != null && lateGct != null && earlyGct - lateGct >= 20) {
      milestones.gct = Math.round(earlyGct - lateGct)
    }

    // Check overall score: scale 0-1, 10 points = 0.1
    const earlyScore = earlyRes.overall_score || earlyRes.confidence_score || 0
    const lateScore = lateRes.overall_score || lateRes.confidence_score || 0
    if (lateScore - earlyScore >= 0.1) {
      milestones.score = Math.round((lateScore - earlyScore) * 100)
    }

    // Check if any milestone was triggered
    if (Object.keys(milestones).length > 0) {
      // Store earliest/latest reference data for celebration card
      milestones.earlyDate = earliest.date
      milestones.lateDate = latest.date

      // Persist so we don't show repeatedly for same records
      var cacheKey = 'rf_milestone_shown_' + (latest.id || latest.date)
      try {
        var alreadyShown = wx.getStorageSync(cacheKey)
        if (alreadyShown) return
      } catch (_) { /* ignore */ }

      this.setData({ milestone: milestones })

      // Mark shown
      try {
        wx.setStorageSync(cacheKey, true)
      } catch (_) { /* ignore */ }
    } else {
      this.setData({ milestone: null })
    }
  },

  toggleTrend() {
    const expanded = !this.data.trendExpanded
    this.setData({ trendExpanded: expanded, trendTooltip: null })

    if (expanded) {
      // Delay to let DOM render, then init/draw
      if (!this._ctx) {
        setTimeout(() => {
          this._initCanvas()
          setTimeout(() => this._drawChart(), 150)
        }, 200)
      } else {
        setTimeout(() => this._drawChart(), 100)
      }
    }
  },

  _drawChart() {
    if (!this._ctx || !this._chartData || !this._chartData.hasData) return

    const ctx = this._ctx
    const w = this._canvasWidth
    const h = this._canvasHeight
    const datasets = this._chartData.datasets
    const labels = this._chartData.labels

    // Clear
    ctx.clearRect(0, 0, w, h)

    const plotLeft = CHART_PADDING_LEFT
    const plotRight = w - CHART_PADDING_RIGHT
    const plotTop = CHART_PADDING_TOP
    const plotBottom = h - CHART_PADDING_BOTTOM
    const plotWidth = plotRight - plotLeft
    const plotHeight = plotBottom - plotTop

    // Collect all valid data points to determine Y range
    let yMin = Infinity
    let yMax = -Infinity
    for (const ds of datasets) {
      for (const v of ds.data) {
        if (v != null) {
          if (v < yMin) yMin = v
          if (v > yMax) yMax = v
        }
      }
    }
    if (yMin === Infinity) return

    // Add 10% padding to Y range
    const yRange = yMax - yMin || 1
    yMin = yMin - yRange * 0.1
    yMax = yMax + yRange * 0.1

    const xStep = labels.length > 1 ? plotWidth / (labels.length - 1) : plotWidth

    function toX(i) { return plotLeft + i * xStep }
    function toY(v) { return plotBottom - ((v - yMin) / (yMax - yMin)) * plotHeight }

    // Grid lines (horizontal)
    const gridLines = 4
    ctx.strokeStyle = GRID_COLOR
    ctx.lineWidth = 1
    for (let i = 0; i <= gridLines; i++) {
      const y = plotTop + (plotHeight / gridLines) * i
      ctx.beginPath()
      ctx.moveTo(plotLeft, y)
      ctx.lineTo(plotRight, y)
      ctx.stroke()

      // Y-axis labels
      const val = yMax - ((yMax - yMin) / gridLines) * i
      ctx.fillStyle = TEXT_COLOR
      ctx.font = '10px -apple-system, "PingFang SC", sans-serif'
      ctx.textAlign = 'right'
      ctx.textBaseline = 'middle'
      const labelText = val >= 100 ? Math.round(val).toString() : val.toFixed(1)
      ctx.fillText(labelText, plotLeft - 8, y)
    }

    // X-axis labels
    ctx.fillStyle = TEXT_COLOR
    ctx.font = '9px -apple-system, "PingFang SC", sans-serif'
    ctx.textAlign = 'center'
    ctx.textBaseline = 'top'
    const maxLabels = Math.min(labels.length, 8)
    const labelStep = labels.length > maxLabels ? Math.ceil(labels.length / maxLabels) : 1
    for (let i = 0; i < labels.length; i += labelStep) {
      const x = toX(i)
      ctx.fillText(labels[i], x, plotBottom + 8)
    }

    // Draw datasets
    const dataPoints = []

    for (let dsIdx = 0; dsIdx < datasets.length; dsIdx++) {
      const ds = datasets[dsIdx]
      const color = ds.color
      const points = []

      for (let i = 0; i < ds.data.length; i++) {
        if (ds.data[i] != null) {
          const px = toX(i)
          const py = toY(ds.data[i])
          points.push({ x: px, y: py, dataIndex: i, value: ds.data[i] })
          dataPoints.push({
            x: px,
            y: py,
            datasetIndex: dsIdx,
            dataIndex: i,
            value: ds.data[i],
            label: ds.label,
            color,
          })
        }
      }

      if (points.length < 2) {
        // Draw single dot if only one point
        if (points.length === 1) {
          ctx.beginPath()
          ctx.arc(points[0].x, points[0].y, DOT_RADIUS + 2, 0, Math.PI * 2)
          ctx.fillStyle = color
          ctx.fill()
        }
        continue
      }

      // Draw line
      ctx.beginPath()
      ctx.strokeStyle = color
      ctx.lineWidth = LINE_WIDTH
      ctx.lineJoin = 'round'
      ctx.lineCap = 'round'
      let firstPoint = true
      for (const pt of points) {
        if (firstPoint) {
          ctx.moveTo(pt.x, pt.y)
          firstPoint = false
        } else {
          ctx.lineTo(pt.x, pt.y)
        }
      }
      ctx.stroke()

      // Draw dots
      for (const pt of points) {
        ctx.beginPath()
        ctx.arc(pt.x, pt.y, DOT_RADIUS, 0, Math.PI * 2)
        ctx.fillStyle = color
        ctx.fill()
        // White border
        ctx.beginPath()
        ctx.arc(pt.x, pt.y, DOT_RADIUS + 1.5, 0, Math.PI * 2)
        ctx.strokeStyle = 'rgba(10,10,15,0.8)'
        ctx.lineWidth = 1.5
        ctx.stroke()
      }
    }

    // Legend
    const legendY = 10
    let legendX = plotLeft
    ctx.font = '10px -apple-system, "PingFang SC", sans-serif'
    ctx.textAlign = 'left'
    ctx.textBaseline = 'middle'
    for (const ds of datasets) {
      const textWidth = ctx.measureText(ds.label).width + 20
      if (legendX + textWidth > plotRight) break
      // Dot
      ctx.beginPath()
      ctx.arc(legendX + 6, legendY, 5, 0, Math.PI * 2)
      ctx.fillStyle = ds.color
      ctx.fill()
      // Text
      ctx.fillStyle = 'rgba(255,255,255,0.7)'
      ctx.fillText(ds.label, legendX + 16, legendY)
      legendX += textWidth + 16
    }

    this._dataPoints = dataPoints
    this.setData({ trendReady: true })
  },

  onChartTap(e) {
    if (!this._dataPoints || this._dataPoints.length === 0) return

    const touch = e.touches ? e.touches[0] : (e.changedTouches ? e.changedTouches[0] : null)
    if (!touch) return

    const x = touch.x
    const y = touch.y
    const threshold = 24

    // Find closest data point
    let closest = null
    let closestDist = Infinity
    for (const pt of this._dataPoints) {
      const dx = pt.x - x
      const dy = pt.y - y
      const dist = Math.sqrt(dx * dx + dy * dy)
      if (dist < threshold && dist < closestDist) {
        closest = pt
        closestDist = dist
      }
    }

    if (closest) {
      const valueText = typeof closest.value === 'number'
        ? (closest.value % 1 === 0 ? closest.value.toString() : closest.value.toFixed(1))
        : closest.value.toString()
      this.setData({
        trendTooltip: {
          x: closest.x,
          y: closest.y - 36,
          text: `${closest.label}: ${valueText}`,
          color: closest.color,
        },
      })

      // Auto-hide tooltip after 3 seconds
      if (this._tooltipTimer) clearTimeout(this._tooltipTimer)
      this._tooltipTimer = setTimeout(() => {
        this.setData({ trendTooltip: null })
      }, 3000)
    } else {
      this.setData({ trendTooltip: null })
    }
  },

  openItem(e) {
    const idx = e.currentTarget.dataset.index
    const item = this.data.items[idx]
    if (!item || !item.result) return

    // Navigate to replay page with full session data
    // Build session-like object from history item
    const rawHistory = wx.getStorageSync('rf_history') || []
    // Find the matching raw item (items are reversed in display, rawHistory is oldest-first)
    const rawItems = [...rawHistory].reverse()
    const rawItem = rawItems[idx]
    const sessionData = rawItem || { id: item.id, date: item.dateDisplay, result: item.result }

    wx.setStorageSync('rf_pendingReplay', sessionData)
    wx.navigateTo({ url: '/pages/replay/replay' })
  },

  // RF-1010: Navigate to weekly insight
  goInsight() {
    wx.navigateTo({ url: '/pages/insight/insight' })
  },

  confirmClear() {
    wx.showModal({
      title: t('deleteConfirm'),
      content: '',
      confirmText: t('deleteOk'),
      cancelText: t('deleteCancel'),
      confirmColor: '#ff4757',
      success: (res) => {
        if (res.confirm) {
          const app = getApp()
          app.globalData.history = []
          wx.setStorageSync('rf_history', [])
          wx.removeStorageSync('lastAnalysisResult')
          this._loadHistory()
        }
      },
    })
  },

  // ──────────── RF-913: Share card ────────────

  /**
   * Generate share image for the most recent history record.
   */
  generateShareImage() {
    const { items, trendLabels, trendDatasets } = this.data
    if (items.length === 0) {
      wx.showToast({ title: isZh ? '暂无记录可分享' : 'No records to share', icon: 'none' })
      return
    }

    const latest = items[0] // items are newest-first
    const metrics = latest.result
      ? Object.entries(latest.result.form_metrics || latest.result.metrics || {})
          .map(([key, val]) => {
            const numVal = typeof val === 'number' ? val : (val?.score ?? 0)
            const pct = Math.round(Math.min(Math.max(numVal, 0), 1) * 100)
            let color = '#00f5a0'
            if (pct < 40) color = '#ff4757'
            else if (pct < 65) color = '#ff9f30'
            return {
              label: key.replace(/_/g, ' '),
              pct,
              valueText: `${pct}%`,
              color,
            }
          })
      : []

    ShareCard.generate({
      canvasId: 'shareCanvas',
      scenario: 'history',
      data: {
        confidencePct: parseInt(latest.scoreDisplay) || 0,
        dateDisplay: latest.dateDisplay,
        overallAssessment: latest.summary,
        metrics,
        analysisCount: items.length,
      },
      pageInstance: this,
      onSuccess: (tempFilePath) => {
        this._shareImagePath = tempFilePath
        wx.showToast({ title: isZh ? '分享图已生成' : 'Share image ready', icon: 'success' })
      },
      onFail: (err) => {
        console.error('[history] ShareCard generate failed:', err)
      },
    })
  },

  saveShareToAlbum() {
    const { items } = this.data
    if (items.length === 0) {
      wx.showToast({ title: isZh ? '暂无记录可分享' : 'No records to share', icon: 'none' })
      return
    }

    if (this._shareImagePath) {
      ShareCard.saveToAlbum(this._shareImagePath)
    } else {
      const latest = items[0]
      const metrics = latest.result
        ? Object.entries(latest.result.form_metrics || latest.result.metrics || {})
            .map(([key, val]) => {
              const numVal = typeof val === 'number' ? val : (val?.score ?? 0)
              const pct = Math.round(Math.min(Math.max(numVal, 0), 1) * 100)
              let color = '#00f5a0'
              if (pct < 40) color = '#ff4757'
              else if (pct < 65) color = '#ff9f30'
              return { label: key.replace(/_/g, ' '), pct, valueText: `${pct}%`, color }
            })
        : []

      ShareCard.generate({
        canvasId: 'shareCanvas',
        scenario: 'history',
        data: {
          confidencePct: parseInt(latest.scoreDisplay) || 0,
          dateDisplay: latest.dateDisplay,
          overallAssessment: latest.summary,
          metrics,
          analysisCount: items.length,
        },
        pageInstance: this,
        onSuccess: (tempFilePath) => {
          this._shareImagePath = tempFilePath
          ShareCard.saveToAlbum(tempFilePath)
        },
        onFail: () => {
          wx.showToast({ title: isZh ? '生成分享图失败' : 'Share image failed', icon: 'none' })
        },
      })
    }
  },

  onShareAppMessage() {
    const { items } = this.data
    const lang = isZh

    let title
    if (items.length === 0) {
      title = lang ? 'RunForm 跑步教练' : 'RunForm Coach AI'
    } else {
      const latest = items[0]
      title = lang
        ? `📊 我的跑姿历史 — ${latest.scoreDisplay} | 共 ${items.length} 条记录`
        : `📊 My RunForm History — ${latest.scoreDisplay} | ${items.length} records`
    }

    const path = '/pages/history/history'
    const imageUrl = this._shareImagePath || ''

    return { title, path, imageUrl }
  },

  // ──────────── RF-605: Milestone Celebration ────────────

  /**
   * Dismiss the milestone banner.
   */
  dismissMilestone() {
    // Capture milestone before nulling
    var m = this.data.milestone
    this.setData({ milestone: null })

    // Also persist dismiss
    try {
      if (m) {
        var items = wx.getStorageSync('rf_dismissed_milestones') || []
        var key = (m.cadence || '') + '_' + (m.gct || '') + '_' + (m.score || '')
        if (items.indexOf(key) === -1) items.push(key)
        if (items.length > 10) items = items.slice(-10)
        wx.setStorageSync('rf_dismissed_milestones', items)
      }
    } catch (_) { /* ignore */ }
  },

  /**
   * Open the milestone celebration card modal.
   * Generates a Canvas share image showing improvement stats.
   */
  onMilestoneTap() {
    this.setData({ milestoneVisible: true })
    // Delay generation so DOM renders
    setTimeout(() => {
      this._generateMilestoneCard()
    }, 300)
  },

  /**
   * Close the milestone celebration modal.
   */
  closeMilestoneModal() {
    this.setData({ milestoneVisible: false })
  },

  /**
   * RF-605: Generate a celebration share card via Canvas.
   * Shows cadence/GCT/score improvements with RunForm branding.
   */
  _generateMilestoneCard() {
    var that = this
    var milestone = this.data.milestone
    if (!milestone) return

    var query = wx.createSelectorQuery().in(this)
    query.select('#milestoneCanvas')
      .fields({ node: true, size: true })
      .exec(function (res) {
        if (!res || !res[0] || !res[0].node) {
          console.error('[history] Milestone canvas not found')
          return
        }

        try {
          var canvas = res[0].node
          var ctx = canvas.getContext('2d')
          var dpr = wx.getSystemInfoSync().pixelRatio || 2

          var cardW = 375
          var cardH = 580
          canvas.width = cardW * dpr
          canvas.height = cardH * dpr
          ctx.scale(dpr, dpr)

          var PAD = 24
          var FONT = '-apple-system, "PingFang SC", sans-serif'

          // ── Background ──
          var bgGrad = ctx.createLinearGradient(0, 0, 0, cardH)
          bgGrad.addColorStop(0, '#0a0a15')
          bgGrad.addColorStop(0.5, '#12101f')
          bgGrad.addColorStop(1, '#0a0a15')
          ctx.fillStyle = bgGrad
          ctx.fillRect(0, 0, cardW, cardH)

          // Accent top band
          ctx.fillStyle = '#ff9f30'
          ctx.fillRect(0, 0, cardW, 4)

          // ── Header ──
          var y = 30
          ctx.fillStyle = '#ff9f30'
          ctx.beginPath()
          ctx.arc(PAD + 16, y + 18, 16, 0, Math.PI * 2)
          ctx.fill()
          ctx.fillStyle = '#0a0a15'
          ctx.font = 'bold 10px ' + FONT
          ctx.textAlign = 'center'
          ctx.fillText('🏃', PAD + 16, y + 22)

          ctx.textAlign = 'left'
          ctx.fillStyle = '#ffffff'
          ctx.font = 'bold 16px ' + FONT
          ctx.fillText(isZh ? 'RunForm 跑步教练' : 'RunForm Coach AI', PAD + 40, y + 14)
          ctx.fillStyle = 'rgba(255,255,255,0.4)'
          ctx.font = '11px ' + FONT
          ctx.fillText(isZh ? '跑姿改善里程碑' : 'Form Milestone', PAD + 40, y + 32)
          y += 58

          // Divider
          ctx.strokeStyle = 'rgba(255,255,255,0.08)'
          ctx.lineWidth = 1
          ctx.beginPath()
          ctx.moveTo(PAD, y)
          ctx.lineTo(cardW - PAD, y)
          ctx.stroke()
          y += 20

          // ── Big celebration title ──
          ctx.textAlign = 'center'
          ctx.fillStyle = '#ffffff'
          ctx.font = 'bold 22px ' + FONT
          ctx.fillText(isZh ? '🎉 里程碑达成！' : '🎉 Milestone Achieved!', cardW / 2, y + 10)
          y += 40

          ctx.fillStyle = 'rgba(255,255,255,0.5)'
          ctx.font = '13px ' + FONT
          ctx.fillText(isZh ? '你的跑姿取得了显著进步' : 'Your form has improved significantly', cardW / 2, y)
          y += 28

          // ── Metric cards ──
          var metrics = []
          if (milestone.cadence) {
            metrics.push({
              icon: '⬆️',
              label: isZh ? '步频提升' : 'Cadence Gain',
              value: milestone.cadence,
              unit: 'SPM',
              color: '#00f5a0',
            })
          }
          if (milestone.gct) {
            metrics.push({
              icon: '⬇️',
              label: isZh ? '触地时间缩短' : 'GCT Reduction',
              value: milestone.gct,
              unit: 'ms',
              color: '#00d4ff',
            })
          }
          if (milestone.score) {
            metrics.push({
              icon: '🏆',
              label: isZh ? '跑姿评分提升' : 'Form Score Gain',
              value: milestone.score,
              unit: isZh ? '分' : 'pts',
              color: '#ff9f30',
            })
          }

          var cardY = y + 8
          var cardBgH = 16 + metrics.length * 72 + 12
          ctx.fillStyle = 'rgba(255,159,48,0.06)'
          // roundRect simplified
          ctx.beginPath()
          ctx.moveTo(PAD + 12, cardY)
          ctx.lineTo(cardW - PAD - 12, cardY)
          ctx.lineTo(cardW - PAD - 12, cardY + cardBgH)
          ctx.lineTo(PAD + 12, cardY + cardBgH)
          ctx.closePath()
          ctx.fill()
          ctx.strokeStyle = 'rgba(255,159,48,0.12)'
          ctx.stroke()

          for (var i = 0; i < metrics.length; i++) {
            var m = metrics[i]
            var my = cardY + 16 + i * 72

            // Icon + label
            ctx.textAlign = 'left'
            ctx.font = '28px ' + FONT
            ctx.fillText(m.icon, PAD + 24, my + 6)
            ctx.fillStyle = 'rgba(255,255,255,0.7)'
            ctx.font = '13px ' + FONT
            ctx.fillText(m.label, PAD + 56, my + 6)

            // Big value
            ctx.textAlign = 'right'
            ctx.fillStyle = m.color
            ctx.font = 'bold 40px ' + FONT
            ctx.fillText('+' + m.value, cardW - PAD - 24, my + 4)

            // Unit
            ctx.fillStyle = 'rgba(255,255,255,0.4)'
            ctx.font = '14px ' + FONT
            ctx.fillText(m.unit, cardW - PAD - 24, my + 40)

            // Arrow separator if not last
            if (i < metrics.length - 1) {
              ctx.strokeStyle = 'rgba(255,255,255,0.04)'
              ctx.lineWidth = 1
              ctx.beginPath()
              ctx.moveTo(PAD + 32, my + 66)
              ctx.lineTo(cardW - PAD - 32, my + 66)
              ctx.stroke()
            }
          }
          y = cardY + cardBgH + 16

          // ── Trend arrow ──
          ctx.textAlign = 'center'
          ctx.fillStyle = '#00f5a0'
          ctx.font = 'bold 28px ' + FONT
          ctx.fillText('📈 ' + (isZh ? '趋势向好 ↑' : 'Trending Up ↑'), cardW / 2, y)
          y += 36

          // ── User nickname ──
          try {
            var app = getApp()
            var profile = app.globalData.profile || {}
            var nickname = profile.nickname || (isZh ? '跑者' : 'Runner')
            ctx.fillStyle = 'rgba(255,255,255,0.7)'
            ctx.font = '14px ' + FONT
            ctx.fillText(nickname, cardW / 2, y)
            y += 22
          } catch (_) { /* ignore */ }

          // ── Footer ──
          y += 8
          ctx.strokeStyle = 'rgba(255,255,255,0.08)'
          ctx.lineWidth = 1
          ctx.beginPath()
          ctx.moveTo(PAD, y)
          ctx.lineTo(cardW - PAD, y)
          ctx.stroke()
          y += 18

          // CTA
          ctx.textAlign = 'left'
          ctx.fillStyle = 'rgba(255,255,255,0.6)'
          ctx.font = '12px ' + FONT
          ctx.fillText(isZh ? '扫码加入 RunForm →' : 'Scan to join RunForm →', PAD, y + 14)

          // QR placeholder
          var qrX = cardW - PAD - 48
          var qrY = y - 4
          var qrSize = 48
          var cols = 7
          var cell = Math.floor(qrSize / (cols + 1))
          var ox = qrX + Math.floor((qrSize - cell * cols) / 2)
          var oy = qrY + Math.floor((qrSize - cell * cols) / 2)
          ctx.fillStyle = 'rgba(255,159,48,0.45)'
          for (var r = 0; r < cols; r++) {
            for (var c = 0; c < cols; c++) {
              if ((c < 2 && r < 2) || (c < 2 && r >= cols - 2) || (c >= cols - 2 && r < 2)) continue
              if ((r * 7 + c * 3 + c * r) % 3 !== 0) {
                ctx.fillRect(ox + c * cell, oy + r * cell, cell, cell)
              }
            }
          }
          ctx.fillStyle = 'rgba(255,159,48,0.7)'
          ctx.beginPath()
          ctx.arc(qrX + qrSize / 2, qrY + qrSize / 2, cell * 1.2, 0, Math.PI * 2)
          ctx.fill()
          y += 58

          // Bottom branding
          ctx.textAlign = 'center'
          ctx.fillStyle = 'rgba(255,255,255,0.2)'
          ctx.font = '9px ' + FONT
          ctx.fillText('Powered by RunForm · movenova.ai', cardW / 2, y + 6)

          // Export to temp file
          wx.canvasToTempFilePath({
            canvas: canvas,
            success: function (tempRes) {
              that._milestoneImagePath = tempRes.tempFilePath
            },
            fail: function (err) {
              console.error('[history] Milestone canvasToTempFilePath failed:', err)
            },
          })
        } catch (e) {
          console.error('[history] Milestone canvas draw error:', e)
        }
      })
  },

  /**
   * Save milestone celebration card to album.
   */
  saveMilestoneToAlbum() {
    if (this._milestoneImagePath) {
      ShareCard.saveToAlbum(this._milestoneImagePath)
    } else {
      // Generate first
      this._generateMilestoneCard()
      setTimeout(() => {
        if (this._milestoneImagePath) {
          ShareCard.saveToAlbum(this._milestoneImagePath)
        } else {
          wx.showToast({ title: t('milestoneGenFailed'), icon: 'none' })
        }
      }, 800)
    }
  },

  /**
   * Share milestone celebration (triggers WeChat share).
   */
  onMilestoneShare() {
    // WeChat share via open-type="share" on the button in wxml
    // This is a fallback
    wx.showToast({ title: isZh ? '请点击右上角分享' : 'Tap top-right to share', icon: 'none', duration: 2000 })
  },

  goAnalyze() {
    wx.switchTab({ url: '/pages/analyze/analyze' })
  },
})
