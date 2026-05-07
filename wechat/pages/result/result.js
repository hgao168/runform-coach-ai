// pages/result/result.js
const { t, getVideoSearchUrl } = require('../../utils/i18n')

Page({
  data: {
    i: {
      confidence: t('confidence'),
      metrics: t('metrics'),
      strengthFocus: t('strengthFocus'),
      noIssues: t('noIssues'),
      compareWithElite: t('compareWithElite'),
      tutorialCopied: t('tutorialCopied'),
    },

    confidenceDisplay: '–',
    confidencePct: 0,
    scoreColor: '#00f5a0',
    overallAssessment: '',
    metrics: [],
    insights: [],
    exercises: [],

    rawResult: null,
  },

  onLoad() {
    const result = wx.getStorageSync('rf_pendingResult')
    if (!result) {
      wx.showToast({ title: '无结果数据', icon: 'error' })
      return
    }
    this._parseResult(result)
  },

  _parseResult(r) {
    const raw = r

    // Confidence / overall score
    const conf = r.confidence_score ?? r.overall_score ?? 0
    const confPct = Math.round(conf * 100)
    let scoreColor = '#00f5a0'
    if (confPct < 40) scoreColor = '#ff4757'
    else if (confPct < 65) scoreColor = '#ff9f30'

    const overallAssessment = r.overall_assessment || r.summary || ''

    // Form metrics — normalise various backend field shapes
    const metricNames = r.form_metrics || r.metrics || {}
    const metrics = Object.entries(metricNames).map(([key, val]) => {
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

    // Issues / insights
    const issues = r.issues || r.insights || []
    const insights = issues.map((iss) => {
      const sev = (iss.severity || 'low').toLowerCase()
      let color = '#00f5a0'
      let severityText = '轻'
      if (sev === 'high' || sev === 'critical') { color = '#ff4757'; severityText = '高' }
      else if (sev === 'medium') { color = '#ff9f30'; severityText = '中' }
      return {
        title: iss.title || iss.name || '',
        description: iss.description || iss.detail || '',
        color,
        severityText,
      }
    })

    // Exercises
    const exercises = (r.strength_focus || r.exercises || []).map((ex) => ({
      name: ex.name || ex.exercise_name || '',
      description: ex.description || ex.detail || '',
      sets: ex.sets,
      reps: ex.reps,
      duration: ex.duration,
      frequency_per_week: ex.frequency_per_week,
      searchUrl: getVideoSearchUrl(ex.name || ex.exercise_name || ''),
    }))

    this.setData({
      rawResult: raw,
      confidenceDisplay: `${confPct}%`,
      confidencePct: confPct,
      scoreColor,
      overallAssessment,
      metrics,
      insights,
      exercises,
    })
  },

  openExercise(e) {
    const idx = e.currentTarget.dataset.index
    const ex = this.data.exercises[idx]
    if (!ex) return
    const url = ex.searchUrl
    // Use webview if URL is bilibili/youtube; copy to clipboard as fallback
    wx.setClipboardData({
      data: url,
      success: () => {
        wx.showToast({ title: this.data.i.tutorialCopied, icon: 'none', duration: 2500 })
      },
    })
  },

  goCompare() {
    wx.navigateTo({ url: '/pages/compare/compare' })
  },

  shareResult() {
    wx.showToast({ title: '分享功能开发中', icon: 'none' })
  },
})
