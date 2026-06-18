// pages/compare/compare.js
const api = require('../../utils/api')
const { t, isZh, backendLang } = require('../../utils/i18n')
const ShareCard = require('../../utils/share-card')

function parseAthletes(raw) {
  if (!Array.isArray(raw)) return []
  return raw.map((a) => {
    const name = a.name || a.athlete_name || ''
    const initial = name ? name[0].toUpperCase() : '?'
    const stats = []
    if (a.cadence) stats.push({ label: isZh ? '步频 (步/分)' : 'Cadence', value: a.cadence, key: 'cadence' })
    if (a.vertical_oscillation) stats.push({ label: isZh ? '垂直振幅' : 'Vert. Oscillation', value: a.vertical_oscillation, key: 'vertical_oscillation' })
    if (a.ground_contact_time) stats.push({ label: isZh ? '接地时间' : 'Ground Contact', value: a.ground_contact_time, key: 'ground_contact_time' })
    if (a.stride_length) stats.push({ label: isZh ? '步幅' : 'Stride Length', value: a.stride_length, key: 'stride_length' })
    return {
      id: a.id || name,
      name,
      initial,
      nationality: a.nationality || a.country || '',
      event: a.event || a.specialty || '',
      bestAchievement: (a.achievements || [])[0] || a.best_time || '',
      bio: a.bio || a.description || '',
      stats,
      achievements: a.achievements || [],
    }
  })
}

/**
 * Extract user metrics from analysis result.
 * Tries raw values first, falls back to normalized scores.
 */
function extractUserMetrics(result) {
  const fm = result.form_metrics || result.metrics || {}
  const metrics = {}

  // Cadence
  if (fm.cadence_spm != null) metrics.cadence = fm.cadence_spm
  else if (fm.cadence != null) metrics.cadence = typeof fm.cadence === 'number' && fm.cadence <= 1 ? Math.round(fm.cadence * 100 + 120) : fm.cadence

  // Vertical oscillation (cm)
  if (fm.vertical_oscillation_cm != null) metrics.vertical_oscillation = fm.vertical_oscillation_cm
  else if (fm.vertical_oscillation != null) metrics.vertical_oscillation = typeof fm.vertical_oscillation === 'number' && fm.vertical_oscillation <= 1 ? +(fm.vertical_oscillation * 8 + 5).toFixed(1) : fm.vertical_oscillation

  // Ground contact time (ms)
  if (fm.ground_contact_time_ms != null) metrics.ground_contact_time = fm.ground_contact_time_ms
  else if (fm.ground_contact_time != null) metrics.ground_contact_time = typeof fm.ground_contact_time === 'number' && fm.ground_contact_time <= 1 ? Math.round(fm.ground_contact_time * 150 + 150) : fm.ground_contact_time

  // Stride length (m)
  if (fm.stride_length_m != null) metrics.stride_length = fm.stride_length_m
  else if (fm.stride_length != null) metrics.stride_length = typeof fm.stride_length === 'number' && fm.stride_length <= 1 ? +(fm.stride_length * 0.5 + 0.8).toFixed(2) : fm.stride_length

  return metrics
}

/**
 * Build comparison rows from user metrics and athlete stats.
 */
function buildComparison(userMetrics, athlete) {
  const metricMeta = [
    { key: 'cadence', labelZh: '步频', labelEn: 'Cadence', unit: isZh ? '步/分' : 'spm', format: (v) => Math.round(v).toString() },
    { key: 'vertical_oscillation', labelZh: '垂直振幅', labelEn: 'Vert. Osc.', unit: 'cm', format: (v) => v.toFixed(1) },
    { key: 'ground_contact_time', labelZh: '触地时间', labelEn: 'GCT', unit: 'ms', format: (v) => Math.round(v).toString() },
    { key: 'stride_length', labelZh: '步幅', labelEn: 'Stride', unit: 'm', format: (v) => v.toFixed(2) },
  ]

  const athleteStats = {}
  for (const s of athlete.stats) {
    athleteStats[s.key] = s.value
  }

  return metricMeta
    .filter((m) => userMetrics[m.key] != null || athleteStats[m.key] != null)
    .map((m) => {
      const userVal = userMetrics[m.key]
      const eliteVal = athleteStats[m.key]
      const bothHave = userVal != null && eliteVal != null
      let diff = null
      let diffColor = ''
      if (bothHave) {
        diff = userVal - eliteVal
        // Cadence: higher is better; oscillation & GCT: lower is better
        if (m.key === 'cadence') {
          diffColor = diff >= 0 ? '#00f5a0' : '#ff4757'
        } else {
          diffColor = diff <= 0 ? '#00f5a0' : '#ff4757'
        }
      }
      return {
        label: isZh ? m.labelZh : m.labelEn,
        unit: m.unit,
        userDisplay: userVal != null ? m.format(userVal) : '–',
        eliteDisplay: eliteVal != null ? m.format(eliteVal) : '–',
        userVal,
        eliteVal,
        diff,
        diffDisplay: bothHave ? (diff >= 0 ? `+${m.format(Math.abs(diff))}` : `-${m.format(Math.abs(diff))}`) : '–',
        diffColor,
        bothHave,
      }
    })
}

Page({
  data: {
    i: {
      compareTitle: t('compareTitle'),
      compareSubtitle: t('compareSubtitle'),
      compareNote: t('compareNote'),
      athleteBio: t('athleteBio'),
      achievement: t('achievement'),
      loading: t('loading'),
      retry: t('retry'),
      back: t('back'),
      compareResult: t('compareResult'),
      yourMetrics: t('yourMetrics'),
      eliteMetrics: t('eliteMetrics'),
      gap: t('gap'),
      noAnalysisForCompare: t('noAnalysisForCompare'),
      goAnalyzeNow: t('goAnalyzeNow'),
      comparing: t('comparing'),
      compareError: t('compareError'),
      compareVs: t('compareVs'),
      noCompareData: t('noCompareData'),
      trainingParams: t('trainingParams'),
      shareResult: t('shareResult'),

      // Compare result view
      similarityLabel: t('similarityLabel'),
      aiCoachCommentTitle: t('aiCoachCommentTitle'),
      topGapsTitle: t('topGapsTitle'),
      gapArea: t('gapArea'),
      gapSuggestion: t('gapSuggestion'),
      yourValueShort: t('yourValueShort'),
      eliteValueShort: t('eliteValueShort'),
      gapValue: t('gapValue'),
      aiPoweredBadge: t('aiPoweredBadge'),
      coachQuote: t('coachQuote'),
      progressTarget: t('progressTarget'),
      higherBetter: t('higherBetter'),
      lowerBetter: t('lowerBetter'),
      closeToElite: t('closeToElite'),
      needsWork: t('needsWork'),
    },

    loading: false,
    loadError: '',
    athletes: [],
    selectedAthlete: null,

    // Comparison state
    hasAnalysis: false,
    comparing: false,
    compareError: '',
    comparisonRows: [],

    // Result detail view (from CompareResponse)
    showResultView: false,
    similarityScore: 0,
    coachingNarrative: '',
    topGaps: [],
    metricGrid: [],
  },

  onLoad() {
    this.loadAthletes()
  },

  onShow() {
    // Refresh analysis availability when page shows
    this._checkAnalysis()
  },

  _checkAnalysis() {
    try {
      const lastResult = wx.getStorageSync('lastAnalysisResult')
      this._lastAnalysisResult = lastResult || null
      this.setData({ hasAnalysis: !!lastResult })
    } catch {
      this._lastAnalysisResult = null
      this.setData({ hasAnalysis: false })
    }
  },

  loadAthletes() {
    this.setData({ loading: true, loadError: '' })
    api.fetchAthletes()
      .then((res) => {
        const list = Array.isArray(res) ? res : (res.athletes || [])
        this.setData({ loading: false, athletes: parseAthletes(list) })
      })
      .catch((err) => {
        this.setData({ loading: false, loadError: err.message || t('error') })
      })
  },

  selectAthlete(e) {
    const id = e.currentTarget.dataset.id
    const athlete = this.data.athletes.find((a) => a.id === id)
    if (!athlete) return

    this.setData({
      selectedAthlete: athlete,
      comparing: false,
      compareError: '',
      comparisonRows: [],
      showResultView: false,
      similarityScore: 0,
      coachingNarrative: '',
      topGaps: [],
      metricGrid: [],
    })

    // If user has analysis data, run comparison
    if (this._lastAnalysisResult) {
      this._runComparison(athlete)
    }
  },

  _runComparison(athlete) {
    const userMetrics = extractUserMetrics(this._lastAnalysisResult)
    if (!userMetrics || Object.keys(userMetrics).length === 0) {
      this.setData({ compareError: t('compareError') })
      return
    }

    this.setData({ comparing: true, compareError: '', showResultView: false })

    api.compareWithAthlete(athlete.id, userMetrics, backendLang)
      .then((res) => {
        // Build basic comparison rows for the simple table
        const mergedMetrics = res.user_metrics || res.comparison || null
        const rows = buildComparison(mergedMetrics || userMetrics, athlete)

        // Parse enriched CompareResponse fields for the result detail view
        const similarityScore = res.similarityScore != null ? Math.round(res.similarityScore) : 0
        const coachingNarrative = res.coachingNarrative || ''
        const topGaps = this._parseTopGaps(res.topGaps || [])
        const metricGrid = this._buildMetricGrid(res.metricComparison || [], userMetrics, athlete)

        const hasRichResult = similarityScore > 0 || coachingNarrative || topGaps.length > 0 || metricGrid.length > 0

        this.setData({
          comparing: false,
          comparisonRows: rows,
          showResultView: hasRichResult,
          similarityScore,
          coachingNarrative,
          topGaps,
          metricGrid,
        }, () => {
          if (hasRichResult) {
            // Draw ring chart after DOM renders
            setTimeout(() => this.drawSimilarityRing(), 200)
          }
        })
      })
      .catch((err) => {
        // Fallback: build comparison from local data even if API fails
        const rows = buildComparison(userMetrics, athlete)
        this.setData({
          comparing: false,
          comparisonRows: rows,
          compareError: rows.length === 0 ? (err.message || t('compareError')) : '',
          showResultView: false,
        })
      })
  },

  _parseTopGaps(rawGaps) {
    if (!Array.isArray(rawGaps)) return []
    return rawGaps.map((g, i) => ({
      id: `gap_${i}`,
      metric: g.metric || g.label || g.area || '',
      gap: g.gap != null ? g.gap : (g.value || ''),
      suggestion: g.suggestion || '',
    }))
  },

  _buildMetricGrid(apiComparison, userMetrics, athlete) {
    // If API returns metricComparison, use it; otherwise build from local data
    if (Array.isArray(apiComparison) && apiComparison.length > 0) {
      return apiComparison.map((m) => {
        const userVal = m.userValue != null ? m.userValue : (m.user_value || 0)
        const eliteVal = m.eliteValue != null ? m.eliteValue : (m.elite_value || 0)
        const diff = m.diff != null ? m.diff : (userVal - eliteVal)
        const maxVal = Math.max(Math.abs(userVal), Math.abs(eliteVal), 1)
        // Determine if higher is better for this metric
        const higherIsBetter = m.higherIsBetter != null
          ? m.higherIsBetter
          : !!(m.label && (m.label.toLowerCase().includes('cadence') || m.label.toLowerCase().includes('步频')))
        // Progress: user value as percentage of elite target (capped at 100%)
        const userPct = Math.min(Math.round((Math.abs(userVal) / Math.abs(maxVal)) * 100), 100)
        const elitePct = Math.min(Math.round((Math.abs(eliteVal) / Math.abs(maxVal)) * 100), 100)
        // Color: green if user meets/exceeds elite (for higher-is-better) or if user <= elite (for lower-is-better)
        const isGood = higherIsBetter ? userVal >= eliteVal : userVal <= eliteVal
        return {
          label: m.label || m.metric || '',
          unit: m.unit || '',
          userDisplay: userVal != null ? (typeof userVal === 'number' ? userVal.toFixed(1) : String(userVal)) : '–',
          eliteDisplay: eliteVal != null ? (typeof eliteVal === 'number' ? eliteVal.toFixed(1) : String(eliteVal)) : '–',
          diffDisplay: diff !== 0 ? (diff > 0 ? `+${diff.toFixed(1)}` : diff.toFixed(1)) : '0',
          userPct,
          elitePct,
          isGood,
          higherIsBetter,
          progressColor: isGood ? '#00f5a0' : '#ff4757',
          trackColor: isGood ? 'rgba(0,245,160,0.2)' : 'rgba(255,71,87,0.2)',
        }
      })
    }

    // Fallback: build from local userMetrics and athlete stats
    const athleteStats = {}
    for (const s of athlete.stats) {
      athleteStats[s.key] = s.value
    }
    const keys = ['cadence', 'vertical_oscillation', 'ground_contact_time', 'stride_length']
    return keys
      .filter((k) => userMetrics[k] != null || athleteStats[k] != null)
      .map((k) => {
        const userVal = userMetrics[k] || 0
        const eliteVal = athleteStats[k] || 0
        const diff = userVal - eliteVal
        const higherIsBetter = k === 'cadence'
        const maxVal = Math.max(Math.abs(userVal), Math.abs(eliteVal), 1)
        const userPct = Math.min(Math.round((Math.abs(userVal) / Math.abs(maxVal)) * 100), 100)
        const elitePct = Math.min(Math.round((Math.abs(eliteVal) / Math.abs(maxVal)) * 100), 100)
        const isGood = higherIsBetter ? userVal >= eliteVal : userVal <= eliteVal
        const labelMap = {
          cadence: isZh ? '步频' : 'Cadence',
          vertical_oscillation: isZh ? '垂直振幅' : 'Vert. Osc.',
          ground_contact_time: isZh ? '触地时间' : 'GCT',
          stride_length: isZh ? '步幅' : 'Stride',
        }
        return {
          label: labelMap[k] || k,
          unit: '',
          userDisplay: userVal != null ? (typeof userVal === 'number' ? userVal.toFixed(1) : '–') : '–',
          eliteDisplay: eliteVal != null ? (typeof eliteVal === 'number' ? eliteVal.toFixed(1) : '–') : '–',
          diffDisplay: diff !== 0 ? (diff > 0 ? `+${diff.toFixed(1)}` : diff.toFixed(1)) : '0',
          userPct,
          elitePct,
          isGood,
          higherIsBetter,
          progressColor: isGood ? '#00f5a0' : '#ff4757',
          trackColor: isGood ? 'rgba(0,245,160,0.2)' : 'rgba(255,71,87,0.2)',
        }
      })
  },

  drawSimilarityRing() {
    const query = wx.createSelectorQuery()
    query.select('#similarityRingCanvas')
      .fields({ node: true, size: true })
      .exec((res) => {
        if (!res || !res[0] || !res[0].node) return
        const canvas = res[0].node
        const ctx = canvas.getContext('2d')
        const dpr = wx.getSystemInfoSync().pixelRatio
        const w = res[0].width
        const h = res[0].height
        canvas.width = w * dpr
        canvas.height = h * dpr
        ctx.scale(dpr, dpr)

        const score = this.data.similarityScore || 0
        const pct = Math.min(score, 100) / 100
        const centerX = w / 2
        const centerY = h / 2
        const radius = Math.min(w, h) / 2 - 10
        const lineWidth = 10

        // Clear
        ctx.clearRect(0, 0, w, h)

        // Background ring
        ctx.beginPath()
        ctx.arc(centerX, centerY, radius, 0, Math.PI * 2)
        ctx.strokeStyle = 'rgba(255,255,255,0.08)'
        ctx.lineWidth = lineWidth
        ctx.lineCap = 'round'
        ctx.stroke()

        // Score arc (clockwise from top)
        const startAngle = -Math.PI / 2
        const endAngle = startAngle + pct * Math.PI * 2

        const gradient = ctx.createLinearGradient(0, 0, w, h)
        gradient.addColorStop(0, '#00f5a0')
        gradient.addColorStop(1, '#00d4ff')

        ctx.beginPath()
        ctx.arc(centerX, centerY, radius, startAngle, endAngle)
        ctx.strokeStyle = gradient
        ctx.lineWidth = lineWidth
        ctx.lineCap = 'round'
        ctx.stroke()
      })
  },

  clearAthlete() {
    this.setData({
      selectedAthlete: null,
      comparing: false,
      compareError: '',
      comparisonRows: [],
      showResultView: false,
      similarityScore: 0,
      coachingNarrative: '',
      topGaps: [],
      metricGrid: [],
    })
  },

  goAnalyze() {
    wx.switchTab({ url: '/pages/analyze/analyze' })
  },

  // ──────────── RF-913: Share card ────────────

  generateShareImage() {
    const { selectedAthlete, comparisonRows } = this.data
    const userMetrics = this._lastAnalysisResult
      ? extractUserMetrics(this._lastAnalysisResult)
      : null

    ShareCard.generate({
      canvasId: 'shareCanvas',
      scenario: 'compare',
      data: {
        athleteName: selectedAthlete ? selectedAthlete.name : '',
        athleteStats: selectedAthlete ? selectedAthlete.stats : [],
        userMetrics,
        comparisonRows,
      },
      pageInstance: this,
      onSuccess: (tempFilePath) => {
        this._shareImagePath = tempFilePath
        wx.showToast({ title: t('shareGenSuccess'), icon: 'success' })
      },
      onFail: (err) => {
        console.error('[compare] ShareCard generate failed:', err)
      },
    })
  },

  saveShareToAlbum() {
    if (this._shareImagePath) {
      ShareCard.saveToAlbum(this._shareImagePath)
    } else {
      const { selectedAthlete, comparisonRows } = this.data

      ShareCard.generate({
        canvasId: 'shareCanvas',
        scenario: 'compare',
        data: {
          athleteName: selectedAthlete ? selectedAthlete.name : '',
          athleteStats: selectedAthlete ? selectedAthlete.stats : [],
          userMetrics: this._lastAnalysisResult ? extractUserMetrics(this._lastAnalysisResult) : null,
          comparisonRows,
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

  onShareAppMessage() {
    const { selectedAthlete, comparisonRows } = this.data
    const lang = isZh

    let title
    if (selectedAthlete && comparisonRows.length > 0) {
      title = lang
        ? `🏃 我与 ${selectedAthlete.name} 的跑步数据对比`
        : `🏃 My run metrics vs ${selectedAthlete.name}`
    } else if (selectedAthlete) {
      title = lang
        ? `🏅 精英运动员：${selectedAthlete.name}`
        : `🏅 Elite Athlete: ${selectedAthlete.name}`
    } else {
      title = lang ? 'RunForm 精英对比' : 'RunForm Elite Compare'
    }

    const path = '/pages/compare/compare'
    const imageUrl = this._shareImagePath || ''

    return { title, path, imageUrl }
  },
})
