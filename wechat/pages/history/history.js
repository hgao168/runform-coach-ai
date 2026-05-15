// pages/history/history.js
const storage = require('../../utils/storage')
const { t, isZh } = require('../../utils/i18n')

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
    wx.setStorageSync('rf_pendingResult', item.result)
    wx.navigateTo({ url: '/pages/result/result' })
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

  goAnalyze() {
    wx.switchTab({ url: '/pages/analyze/analyze' })
  },
})
