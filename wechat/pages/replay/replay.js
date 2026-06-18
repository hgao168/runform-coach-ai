// pages/replay/replay.js
const storage = require('../../utils/storage')
const { t, isZh } = require('../../utils/i18n')

// ── Chart constants (reuse history.js sizing) ──
const CHART_PADDING_TOP = 36
const CHART_PADDING_RIGHT = 20
const CHART_PADDING_BOTTOM = 44
const CHART_PADDING_LEFT = 46
const DOT_RADIUS = 4.5
const LINE_WIDTH = 2.5
const GRID_COLOR = 'rgba(255,255,255,0.06)'
const TEXT_COLOR = 'rgba(255,255,255,0.4)'

// ── Score color helper ──
function scoreColor(score) {
  const pct = Math.round((score || 0) * 100)
  if (pct >= 70) return '#00f5a0'
  if (pct >= 45) return '#ff9f30'
  return '#ff4757'
}

// ── Extract metric helper (same as history.js) ──
function extractMetric(result, key, rawKey, scoreScale) {
  const fm = result.form_metrics || result.metrics || {}
  if (fm[rawKey] != null) return fm[rawKey]
  if (fm[key] != null) {
    const v = fm[key]
    if (typeof v === 'number' && v <= 1 && v >= 0) {
      return scoreScale ? Math.round(v * scoreScale[0] + scoreScale[1]) : Math.round(v * 100)
    }
    return v
  }
  return null
}

// ── Format duration ──
function formatDuration(totalSec) {
  if (totalSec == null || totalSec <= 0) return null
  const h = Math.floor(totalSec / 3600)
  const m = Math.floor((totalSec % 3600) / 60)
  const s = Math.floor(totalSec % 60)
  if (h > 0) return `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
  return `${m}:${String(s).padStart(2, '0')}`
}

// ── Format distance ──
function formatDistance(meters) {
  if (meters == null || meters <= 0) return null
  if (meters >= 1000) return (meters / 1000).toFixed(2) + ' km'
  return Math.round(meters) + ' m'
}

// ── Format date ──
function formatDate(isoStr) {
  try {
    const d = new Date(isoStr)
    const y = d.getFullYear()
    const mo = String(d.getMonth() + 1).padStart(2, '0')
    const day = String(d.getDate()).padStart(2, '0')
    const h = String(d.getHours()).padStart(2, '0')
    const mi = String(d.getMinutes()).padStart(2, '0')
    return `${y}-${mo}-${day} ${h}:${mi}`
  } catch {
    return isoStr || ''
  }
}

// ── Build multi-session trend chart data for the mini line chart ──
function buildReplayChartData(sessionId, rawHistory) {
  // rawHistory is oldest-first from storage.getHistory()
  const items = [...rawHistory].reverse() // newest-first
  const recent = items.slice(0, 20).reverse() // oldest-first, last 20

  const labels = []
  const cadenceData = []
  const oscData = []
  const gctData = []
  const highlightIndices = [] // indices where session matches

  for (let i = 0; i < recent.length; i++) {
    const item = recent[i]
    const mo = String(new Date(item.date).getMonth() + 1).padStart(2, '0')
    const day = String(new Date(item.date).getDate()).padStart(2, '0')
    labels.push(`${mo}/${day}`)

    const cad = extractMetric(item.result, 'cadence', 'cadence_spm', [100, 120])
    const osc = extractMetric(item.result, 'vertical_oscillation', 'vertical_oscillation_cm', [8, 5])
    const gct = extractMetric(item.result, 'ground_contact_time', 'ground_contact_time_ms', [150, 150])

    cadenceData.push(cad)
    oscData.push(osc)
    gctData.push(gct)

    if (item.id === sessionId) {
      highlightIndices.push(i)
    }
  }

  return {
    labels,
    datasets: [
      { label: t('trendCadence'), data: cadenceData, color: '#00f5a0' },
      { label: t('trendOscillation'), data: oscData, color: '#00d4ff' },
      { label: t('trendGCT'), data: gctData, color: '#ff9f30' },
    ],
    highlightIndices,
    hasData: recent.length >= 2 && (cadenceData.some(v => v != null) || oscData.some(v => v != null) || gctData.some(v => v != null)),
  }
}

Page({
  data: {
    i: {
      replayTitle: t('replayTitle'),
      duration: t('replayDuration'),
      distance: t('replayDistance'),
      avgCadence: t('replayAvgCadence'),
      avgOscillation: t('replayAvgOscillation'),
      gct: t('replayGCT'),
      postureScore: t('replayPostureScore'),
      trendTitle: t('trendTitle'),
      trendTapHint: t('trendTapHint'),
      trendNoData: t('trendNoData'),
      pathTitle: t('replayPathTitle'),
      pathNoData: t('replayPathNoData'),
      viewDetail: t('replayViewDetail'),
      back: t('back'),
    },
    // Stats
    dateDisplay: '',
    durationDisplay: '--',
    distanceDisplay: '--',
    avgCadenceDisplay: '--',
    avgOscillationDisplay: '--',
    gctDisplay: '--',
    postureScoreDisplay: '--',
    postureScoreColor: '#00f5a0',

    // Trend chart
    trendReady: false,
    trendHasData: false,
    trendTooltip: null,
    trendDatasets: [],
    trendLabels: [],

    // Path
    hasPath: false,
    pathPoints: [],
  },

  // Internal
  _sessionData: null,
  _canvas: null,
  _ctx: null,
  _canvasWidth: 0,
  _canvasHeight: 0,
  _dpr: 1,
  _dataPoints: [],
  _chartData: null,

  // Path canvas
  _pathCanvas: null,
  _pathCtx: null,
  _pathCanvasWidth: 0,
  _pathCanvasHeight: 0,
  _pathDpr: 1,

  onLoad(options) {
    // Read session data from storage
    const sessionData = wx.getStorageSync('rf_pendingReplay')
    if (!sessionData) {
      wx.showToast({ title: isZh ? '无会话数据' : 'No session data', icon: 'error' })
      setTimeout(() => wx.navigateBack(), 1500)
      return
    }

    this._sessionData = sessionData
    this._parseSession(sessionData)
  },

  onReady() {
    this._initTrendCanvas()
  },

  _parseSession(sessionData) {
    const result = sessionData.result || {}
    const fm = result.form_metrics || result.metrics || {}

    // Date
    const dateDisplay = formatDate(sessionData.date)

    // Duration (from session data or estimate)
    const durationSec = sessionData.duration_sec || result.duration_sec || null
    const durationDisplay = formatDuration(durationSec) || '--'

    // Distance
    const distanceM = sessionData.distance_m || result.distance_m || null
    const distanceDisplay = formatDistance(distanceM) || '--'

    // Cadence
    const cadence = extractMetric(result, 'cadence', 'cadence_spm', [100, 120])
    const avgCadenceDisplay = cadence != null ? Math.round(cadence) + ' spm' : '--'

    // Vertical oscillation
    const oscillation = extractMetric(result, 'vertical_oscillation', 'vertical_oscillation_cm', [8, 5])
    const avgOscillationDisplay = oscillation != null ? oscillation.toFixed(1) + ' cm' : '--'

    // GCT
    const gct = extractMetric(result, 'ground_contact_time', 'ground_contact_time_ms', [150, 150])
    const gctDisplay = gct != null ? Math.round(gct) + ' ms' : '--'

    // Posture score
    const overallScore = result.overall_score || result.confidence_score || 0
    const postureScoreDisplay = Math.round(overallScore * 100) + '%'
    const postureScoreColor = scoreColor(overallScore)

    // GPS path points (if available)
    const pathPoints = sessionData.coordinates || result.coordinates || []
    const hasPath = Array.isArray(pathPoints) && pathPoints.length >= 2

    this.setData({
      dateDisplay,
      durationDisplay,
      distanceDisplay,
      avgCadenceDisplay,
      avgOscillationDisplay,
      gctDisplay,
      postureScoreDisplay,
      postureScoreColor,
      hasPath,
      pathPoints: hasPath ? pathPoints : [],
    })

    // Build trend chart data from all history
    const rawHistory = storage.getHistory()
    const chartData = buildReplayChartData(sessionData.id, rawHistory)
    this._chartData = chartData

    this.setData({
      trendHasData: chartData.hasData,
      trendDatasets: chartData.datasets,
      trendLabels: chartData.labels,
    })

    if (chartData.hasData) {
      // Draw after canvas init
      if (this._ctx) {
        this._drawTrendChart()
      }
    }

    // Draw path if available
    if (hasPath) {
      setTimeout(() => {
        this._initPathCanvas()
      }, 300)
    }
  },

  // ── Trend chart canvas ──

  _initTrendCanvas() {
    const query = wx.createSelectorQuery()
    query.select('#replayTrendCanvas')
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

        if (this._chartData && this._chartData.hasData) {
          this._drawTrendChart()
        }
      })
  },

  _drawTrendChart() {
    if (!this._ctx || !this._chartData || !this._chartData.hasData) return

    const ctx = this._ctx
    const w = this._canvasWidth
    const h = this._canvasHeight
    const datasets = this._chartData.datasets
    const labels = this._chartData.labels
    const highlightIndices = this._chartData.highlightIndices || []

    ctx.clearRect(0, 0, w, h)

    const plotLeft = CHART_PADDING_LEFT
    const plotRight = w - CHART_PADDING_RIGHT
    const plotTop = CHART_PADDING_TOP
    const plotBottom = h - CHART_PADDING_BOTTOM
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
    yMin = yMin - yRange * 0.1
    yMax = yMax + yRange * 0.1

    const xStep = labels.length > 1 ? plotWidth / (labels.length - 1) : plotWidth

    function toX(i) { return plotLeft + i * xStep }
    function toY(v) { return plotBottom - ((v - yMin) / (yMax - yMin)) * plotHeight }

    // Grid
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
      ctx.fillText(val >= 100 ? Math.round(val).toString() : val.toFixed(1), plotLeft - 8, y)
    }

    // X-axis labels
    ctx.fillStyle = TEXT_COLOR
    ctx.font = '9px -apple-system, "PingFang SC", sans-serif'
    ctx.textAlign = 'center'
    ctx.textBaseline = 'top'
    const maxLabels = Math.min(labels.length, 6)
    const labelStep = labels.length > maxLabels ? Math.ceil(labels.length / maxLabels) : 1
    for (let i = 0; i < labels.length; i += labelStep) {
      ctx.fillText(labels[i], toX(i), plotBottom + 8)
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
          dataPoints.push({ x: px, y: py, datasetIndex: dsIdx, dataIndex: i, value: ds.data[i], label: ds.label, color })
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

      // Line
      ctx.beginPath()
      ctx.strokeStyle = color
      ctx.lineWidth = LINE_WIDTH
      ctx.lineJoin = 'round'
      ctx.lineCap = 'round'
      let firstPoint = true
      for (const pt of points) {
        if (firstPoint) { ctx.moveTo(pt.x, pt.y); firstPoint = false }
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

    // Highlight current session with a ring
    for (const hi of highlightIndices) {
      const hx = toX(hi)
      // Find the corresponding y from any dataset
      for (const ds of datasets) {
        if (ds.data[hi] != null) {
          const hy = toY(ds.data[hi])
          ctx.beginPath()
          ctx.arc(hx, hy, DOT_RADIUS + 7, 0, Math.PI * 2)
          ctx.strokeStyle = 'rgba(255,255,255,0.5)'
          ctx.lineWidth = 2
          ctx.setLineDash([3, 3])
          ctx.stroke()
          ctx.setLineDash([])
          break
        }
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
      ctx.beginPath()
      ctx.arc(legendX + 6, legendY, 5, 0, Math.PI * 2)
      ctx.fillStyle = ds.color
      ctx.fill()
      ctx.fillStyle = 'rgba(255,255,255,0.7)'
      ctx.fillText(ds.label, legendX + 16, legendY)
      legendX += textWidth + 12
    }

    this._dataPoints = dataPoints
    this.setData({ trendReady: true })
  },

  onTrendChartTap(e) {
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
        : closest.value.toString()
      this.setData({
        trendTooltip: { x: closest.x, y: closest.y - 36, text: `${closest.label}: ${valueText}`, color: closest.color },
      })
      if (this._tooltipTimer) clearTimeout(this._tooltipTimer)
      this._tooltipTimer = setTimeout(() => this.setData({ trendTooltip: null }), 3000)
    } else {
      this.setData({ trendTooltip: null })
    }
  },

  // ── Path canvas ──

  _initPathCanvas() {
    const query = wx.createSelectorQuery()
    query.select('#replayPathCanvas')
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

        this._pathCanvas = canvas
        this._pathCtx = ctx
        this._pathCanvasWidth = width
        this._pathCanvasHeight = height
        this._pathDpr = dpr

        this._drawPath()
      })
  },

  _drawPath() {
    const ctx = this._pathCtx
    const w = this._pathCanvasWidth
    const h = this._pathCanvasHeight
    const points = this.data.pathPoints
    if (!ctx || !points || points.length < 2) return

    ctx.clearRect(0, 0, w, h)

    // Map coordinate bounds
    let minLat = Infinity, maxLat = -Infinity, minLng = Infinity, maxLng = -Infinity
    for (const pt of points) {
      const lat = pt.lat != null ? pt.lat : pt.latitude
      const lng = pt.lng != null ? pt.lng : pt.longitude
      if (lat != null && lng != null) {
        if (lat < minLat) minLat = lat
        if (lat > maxLat) maxLat = lat
        if (lng < minLng) minLng = lng
        if (lng > maxLng) maxLng = lng
      }
    }

    if (minLat === Infinity) return

    const pad = 30
    const pw = w - pad * 2
    const ph = h - pad * 2
    const latRange = maxLat - minLat || 1
    const lngRange = maxLng - minLng || 1

    function toX(lng) { return pad + ((lng - minLng) / lngRange) * pw }
    function toY(lat) { return pad + ((maxLat - lat) / latRange) * ph }

    // Background
    ctx.fillStyle = 'rgba(255,255,255,0.03)'
    ctx.fillRect(0, 0, w, h)

    // Draw route line
    ctx.beginPath()
    ctx.strokeStyle = '#00f5a0'
    ctx.lineWidth = 3
    ctx.lineJoin = 'round'
    ctx.lineCap = 'round'

    let first = true
    for (const pt of points) {
      const lat = pt.lat != null ? pt.lat : pt.latitude
      const lng = pt.lng != null ? pt.lng : pt.longitude
      if (lat == null || lng == null) continue
      const px = toX(lng)
      const py = toY(lat)
      if (first) { ctx.moveTo(px, py); first = false }
      else { ctx.lineTo(px, py) }
    }
    ctx.stroke()

    // Start point marker
    const firstPt = points[0]
    const flng = firstPt.lng != null ? firstPt.lng : firstPt.longitude
    const flat = firstPt.lat != null ? firstPt.lat : firstPt.latitude
    if (flng != null && flat != null) {
      ctx.beginPath()
      ctx.arc(toX(flng), toY(flat), 6, 0, Math.PI * 2)
      ctx.fillStyle = '#00f5a0'
      ctx.fill()
      ctx.fillStyle = '#fff'
      ctx.font = '9px -apple-system, sans-serif'
      ctx.textAlign = 'center'
      ctx.fillText(isZh ? '起' : 'S', toX(flng), toY(flat) - 12)
    }

    // End point marker
    const lastPt = points[points.length - 1]
    const llng = lastPt.lng != null ? lastPt.lng : lastPt.longitude
    const llat = lastPt.lat != null ? lastPt.lat : lastPt.latitude
    if (llng != null && llat != null) {
      ctx.beginPath()
      ctx.arc(toX(llng), toY(llat), 6, 0, Math.PI * 2)
      ctx.fillStyle = '#ff4757'
      ctx.fill()
      ctx.fillStyle = '#fff'
      ctx.font = '9px -apple-system, sans-serif'
      ctx.textAlign = 'center'
      ctx.fillText(isZh ? '终' : 'E', toX(llng), toY(llat) - 12)
    }
  },

  // ── Navigate to detail result ──
  viewDetail() {
    const sessionData = this._sessionData
    if (!sessionData || !sessionData.result) return
    wx.setStorageSync('rf_pendingResult', sessionData.result)
    wx.navigateTo({ url: '/pages/result/result' })
  },

  // ── Back ──
  goBack() {
    wx.navigateBack()
  },

  onUnload() {
    if (this._tooltipTimer) clearTimeout(this._tooltipTimer)
  },
})
