// pages/insight/insight.js
// RF-1010: Weekly Training Insight Report
// RF-1011: Share card integration
const api = require('../../utils/api')
const { t, isZh } = require('../../utils/i18n')
const ShareCard = require('../../utils/share-card')

// --- Chart rendering constants ---
const CHART_PAD_TOP = 36
const CHART_PAD_RIGHT = 20
const CHART_PAD_BOTTOM = 44
const CHART_PAD_LEFT = 44
const DOT_RADIUS = 4
const LINE_WIDTH = 2.5
const GRID_COLOR = 'rgba(255,255,255,0.06)'
const TEXT_COLOR = 'rgba(255,255,255,0.35)'

Page({
  data: {
    i: {
      title: t('insightTitle'),
      loading: t('insightLoading'),
      error: t('insightError'),
      retry: t('insightRetry'),
      compareTitle: t('insightCompareTitle'),
      trendTitle: t('insightTrendTitle'),
      aiAdviceTitle: t('insightAiAdviceTitle'),
      badgesTitle: t('insightBadgesTitle'),
      cadence: t('insightCadence'),
      oscillation: t('insightOscillation'),
      gct: t('insightGCT'),
      distance: t('insightDistance'),
      sessions: t('insightSessions'),
      spacing: t('insightSpacing'),
      noData: t('insightNoData'),
      noDataSub: t('insightNoDataSub'),
      shareInsight: t('shareInsightBtn'),
      shareGenSuccess: t('shareGenSuccess'),
      shareGenFail: t('shareGenFail'),
      shareImageSaved: t('shareImageSaved'),
    },

    loading: true,
    error: false,
    hasData: false,

    // Comparison metrics
    comparison: [],
    // trend data
    trendLabels: [],
    trendDatasets: [],
    // AI advice
    aiAdvice: '',
    // Badges
    badges: [],

    trendReady: false,
    trendHasData: false,
    trendTooltip: null,
  },

  // Internal canvas state
  _canvas: null,
  _ctx: null,
  _canvasWidth: 0,
  _canvasHeight: 0,
  _dpr: 1,
  _dataPoints: [],
  _rawData: null,

  onLoad() {
    this._fetchInsight()
  },

  onReady() {
    this._initCanvas()
  },

  // ── API ──

  _fetchInsight() {
    this.setData({ loading: true, error: false })

    api.getWeeklyInsight()
      .then((data) => {
        this._rawData = data
        this._parseData(data)
        this.setData({ loading: false })

        // Draw chart after data + canvas are ready
        setTimeout(() => this._drawChart(), 200)
      })
      .catch((err) => {
        console.error('[insight] fetch error:', err)
        this.setData({ loading: false, error: true })
      })
  },

  retry() {
    this._fetchInsight()
  },

  // ── Data parsing ──

  _parseData(data) {
    // Parse comparison metrics
    const comp = data.comparison || {}
    const comparison = [
      {
        label: t('insightCadence'),
        key: 'cadence_change_pct',
        changePct: comp.cadence_change_pct,
        unit: 'spm',
        icon: '👟',
      },
      {
        label: t('insightOscillation'),
        key: 'vertical_oscillation_change_pct',
        changePct: comp.vertical_oscillation_change_pct,
        unit: 'cm',
        icon: '↕️',
      },
      {
        label: t('insightGCT'),
        key: 'ground_contact_time_change_pct',
        changePct: comp.ground_contact_time_change_pct,
        unit: 'ms',
        icon: '⏱️',
      },
      {
        label: t('insightDistance'),
        key: 'distance_change_pct',
        changePct: comp.distance_change_pct,
        unit: 'km',
        icon: '📏',
      },
      {
        label: t('insightSessions'),
        key: 'session_count_change_pct',
        changePct: comp.session_count_change_pct,
        unit: '',
        icon: '📅',
      },
    ].filter((m) => m.changePct != null)

    // Parse trend
    const trend = data.trend || {}
    const weeks = trend.weeks || []
    const cadenceData = trend.cadence || []
    const oscData = trend.vertical_oscillation || []
    const gctData = trend.ground_contact_time || []
    const distData = trend.distance || []
    const sessData = trend.session_count || []

    const datasets = []
    // Only include datasets that have actual data
    if (cadenceData.some((v) => v != null)) {
      datasets.push({ label: t('insightCadence'), data: cadenceData, color: '#00f5a0' })
    }
    // For oscillation and GCT, lower is better, so we use a different color
    if (oscData.some((v) => v != null)) {
      datasets.push({ label: t('insightOscillation'), data: oscData, color: '#00d4ff' })
    }
    if (gctData.some((v) => v != null)) {
      datasets.push({ label: t('insightGCT'), data: gctData, color: '#ff9f30' })
    }
    // Optional: distance and sessions as secondary datasets
    if (datasets.length === 0 && distData.some((v) => v != null)) {
      datasets.push({ label: t('insightDistance'), data: distData, color: '#ff6b9d' })
    }
    if (datasets.length === 0 && sessData.some((v) => v != null)) {
      datasets.push({ label: t('insightSessions'), data: sessData, color: '#a78bfa' })
    }

    const hasTrendData = datasets.length > 0 && weeks.length >= 2 &&
      datasets.some((ds) => ds.data.filter((v) => v != null).length >= 2)

    // Parse AI advice
    const aiAdvice = data.ai_advice || ''

    // Parse badges
    const badges = (data.badges || []).map((b) => ({
      name: b.name || '',
      icon: b.icon || '🏅',
      description: b.description || '',
    }))

    this.setData({
      comparison,
      trendLabels: weeks,
      trendDatasets: datasets,
      trendHasData: hasTrendData,
      aiAdvice,
      badges,
      hasData: comparison.length > 0 || hasTrendData || aiAdvice || badges.length > 0,
    })

    this._chartData = { labels: weeks, datasets }
  },

  // ── Canvas 2D chart (reuse history.js pattern) ──

  _initCanvas() {
    const query = wx.createSelectorQuery()
    query.select('#insightTrendCanvas')
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

        if (this._chartData && this.data.trendHasData) {
          this._drawChart()
        }
      })
  },

  _drawChart() {
    if (!this._ctx || !this._chartData) return
    const { labels, datasets } = this._chartData
    if (!datasets.length || labels.length < 2) return

    const ctx = this._ctx
    const w = this._canvasWidth
    const h = this._canvasHeight

    ctx.clearRect(0, 0, w, h)

    const plotLeft = CHART_PAD_LEFT
    const plotRight = w - CHART_PAD_RIGHT
    const plotTop = CHART_PAD_TOP
    const plotBottom = h - CHART_PAD_BOTTOM
    const plotWidth = plotRight - plotLeft
    const plotHeight = plotBottom - plotTop

    // Y range
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

    const yRange = yMax - yMin || 1
    yMin = yMin - yRange * 0.15
    yMax = yMax + yRange * 0.15

    const xStep = labels.length > 1 ? plotWidth / (labels.length - 1) : plotWidth

    function toX(i) { return plotLeft + i * xStep }
    function toY(v) { return plotBottom - ((v - yMin) / (yMax - yMin)) * plotHeight }

    // Grid lines
    const gridLines = 3
    ctx.strokeStyle = GRID_COLOR
    ctx.lineWidth = 1
    for (let i = 0; i <= gridLines; i++) {
      const y = plotTop + (plotHeight / gridLines) * i
      ctx.beginPath()
      ctx.moveTo(plotLeft, y)
      ctx.lineTo(plotRight, y)
      ctx.stroke()

      const val = yMax - ((yMax - yMin) / gridLines) * i
      ctx.fillStyle = TEXT_COLOR
      ctx.font = '9px -apple-system, "PingFang SC", sans-serif'
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
    const maxLabels = Math.min(labels.length, 6)
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
      let first = true
      for (const pt of points) {
        if (first) { ctx.moveTo(pt.x, pt.y); first = false }
        else { ctx.lineTo(pt.x, pt.y) }
      }
      ctx.stroke()

      // Dots
      for (const pt of points) {
        ctx.beginPath()
        ctx.arc(pt.x, pt.y, DOT_RADIUS, 0, Math.PI * 2)
        ctx.fillStyle = color
        ctx.fill()
        ctx.beginPath()
        ctx.arc(pt.x, pt.y, DOT_RADIUS + 1.5, 0, Math.PI * 2)
        ctx.strokeStyle = 'rgba(10,10,15,0.8)'
        ctx.lineWidth = 1.5
        ctx.stroke()
      }
    }

    // Legend at top-left
    let legendX = plotLeft
    const legendY = 10
    ctx.font = '9px -apple-system, "PingFang SC", sans-serif'
    ctx.textAlign = 'left'
    ctx.textBaseline = 'middle'
    for (const ds of datasets) {
      const textWidth = ctx.measureText(ds.label).width + 18
      if (legendX + textWidth > plotRight) break
      ctx.beginPath()
      ctx.arc(legendX + 5, legendY, 4, 0, Math.PI * 2)
      ctx.fillStyle = ds.color
      ctx.fill()
      ctx.fillStyle = 'rgba(255,255,255,0.55)'
      ctx.fillText(ds.label, legendX + 14, legendY)
      legendX += textWidth + 12
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
        : String(closest.value)
      this.setData({
        trendTooltip: {
          x: closest.x,
          y: closest.y - 32,
          text: `${closest.label}: ${valueText}`,
          color: closest.color,
        },
      })
      if (this._tooltipTimer) clearTimeout(this._tooltipTimer)
      this._tooltipTimer = setTimeout(() => {
        this.setData({ trendTooltip: null })
      }, 3000)
    } else {
      this.setData({ trendTooltip: null })
    }
  },

  // ──────────── RF-1011: Share card ────────────

  /**
   * Generate a share image for the weekly insight report.
   * Uses the 'insight' scenario for differentiated layout.
   */
  generateShareImage() {
    const { comparison, trendDatasets, trendLabels, aiAdvice, badges } = this.data
    const raw = this._rawData || {}
    const confidencePct = raw.overall_score != null ? Math.round(raw.overall_score * 100) : null
    const dateDisplay = raw.week_label || ''

    ShareCard.generate({
      canvasId: 'shareCanvas',
      scenario: 'insight',
      data: {
        comparison,
        trendDatasets,
        trendLabels,
        aiAdvice,
        badges,
        confidencePct,
        dateDisplay,
      },
      pageInstance: this,
      onSuccess: (tempFilePath) => {
        this._shareImagePath = tempFilePath
        wx.showToast({ title: t('shareGenSuccess'), icon: 'success' })
      },
      onFail: (err) => {
        console.error('[insight] ShareCard generate failed:', err)
        wx.showToast({ title: t('shareGenFail'), icon: 'none' })
      },
    })
  },

  /**
   * Save the generated share image to album.
   * Generates on-demand if not already cached.
   */
  saveShareToAlbum() {
    if (this._shareImagePath) {
      ShareCard.saveToAlbum(this._shareImagePath)
    } else {
      const { comparison, trendDatasets, trendLabels, aiAdvice, badges } = this.data
      const raw = this._rawData || {}
      const confidencePct = raw.overall_score != null ? Math.round(raw.overall_score * 100) : null
      const dateDisplay = raw.week_label || ''

      ShareCard.generate({
        canvasId: 'shareCanvas',
        scenario: 'insight',
        data: {
          comparison,
          trendDatasets,
          trendLabels,
          aiAdvice,
          badges,
          confidencePct,
          dateDisplay,
        },
        pageInstance: this,
        onSuccess: (tempFilePath) => {
          this._shareImagePath = tempFilePath
          ShareCard.saveToAlbum(tempFilePath)
        },
        onFail: () => {
          wx.showToast({ title: t('shareGenFail'), icon: 'none' })
        },
      })
    }
  },

  /**
   * WeChat custom share card for insight.
   */
  onShareAppMessage() {
    const { comparison, aiAdvice } = this.data
    const lang = isZh

    // Build a data-driven share title
    const changeItems = (comparison || []).slice(0, 2)
    const changeSummary = changeItems
      .map((c) => `${c.icon || ''}${c.label} ${c.changePct > 0 ? '+' : ''}${c.changePct.toFixed(1)}%`)
      .join(' ')

    let title
    if (changeSummary) {
      title = lang
        ? `📊 本周跑步洞察：${changeSummary}`
        : `📊 Weekly Run Insight: ${changeSummary}`
    } else if (aiAdvice) {
      const snippet = aiAdvice.length > 40 ? aiAdvice.slice(0, 40) + '...' : aiAdvice
      title = lang
        ? `📊 周洞察：${snippet}`
        : `📊 Weekly Insight: ${snippet}`
    } else {
      title = lang
        ? '📊 RunForm 周训练洞察报告'
        : '📊 RunForm Weekly Training Insight'
    }

    const path = '/pages/insight/insight'
    const imageUrl = this._shareImagePath || ''

    return { title, path, imageUrl }
  },
})
