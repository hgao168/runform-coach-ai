// pages/history/history.js
const storage = require('../../utils/storage')
const { t } = require('../../utils/i18n')

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
    const hh = String(d.getHours()).padStart(2, '0')
    const mm = String(d.getMinutes()).padStart(2, '0')
    return `${y}-${mo}-${day} ${hh}:${mm}`
  } catch {
    return isoStr || ''
  }
}

Page({
  data: {
    i: {
      historyTitle: t('historyTitle'),
      historyEmpty: t('historyEmpty'),
      historyEmptySub: t('historyEmptySub'),
      deleteHistory: t('deleteHistory'),
    },
    items: [],
  },

  onShow() {
    this._loadHistory()
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
    this.setData({ items })
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
          this._loadHistory()
        }
      },
    })
  },

  goAnalyze() {
    wx.switchTab({ url: '/pages/analyze/analyze' })
  },
})
