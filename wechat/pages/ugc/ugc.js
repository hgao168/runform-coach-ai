// pages/ugc/ugc.js
// RF-604: UGC Content Submission — List & Management
const { t, isZh } = require('../../utils/i18n')

const PLATFORM_LABELS = {
  douyin: 'ugcPlatformDouyin',
  bilibili: 'ugcPlatformBilibili',
  xiaohongshu: 'ugcPlatformXiaohongshu',
  pengyouquan: 'ugcPlatformPengyouquan',
}

const STATUS_LABELS = {
  pending: 'ugcStatusPending',
  approved: 'ugcStatusApproved',
  rejected: 'ugcStatusRejected',
}

const STATUS_COLORS = {
  pending: '#ff9f30',
  approved: '#00f5a0',
  rejected: '#ff4757',
}

Page({
  data: {
    i: {
      ugcListTitle: t('ugcListTitle'),
      ugcListEmpty: t('ugcListEmpty'),
      ugcListEmptySub: t('ugcListEmptySub'),
    },
    submissions: [],
    expandedId: '',
  },

  onShow() {
    this._loadSubmissions()
  },

  _loadSubmissions() {
    try {
      const list = wx.getStorageSync('rf_ugc_submissions') || []
      // Newest first
      const sorted = [...list].reverse()
      const formatted = sorted.map((item) => ({
        ...item,
        platformName: t(PLATFORM_LABELS[item.platform] || item.platform),
        statusName: t(STATUS_LABELS[item.status] || item.status),
        statusColor: STATUS_COLORS[item.status] || '#888888',
        dateDisplay: this._formatDate(item.createdAt),
        noteShort: item.note
          ? item.note.length > 40 ? item.note.slice(0, 40) + '...' : item.note
          : '',
      }))
      this.setData({ submissions: formatted })
    } catch (e) {
      console.error('[ugc] Failed to load submissions:', e)
      this.setData({ submissions: [] })
    }
  },

  _formatDate(isoStr) {
    try {
      const d = new Date(isoStr)
      const y = d.getFullYear()
      const mo = String(d.getMonth() + 1).padStart(2, '0')
      const day = String(d.getDate()).padStart(2, '0')
      const h = String(d.getHours()).padStart(2, '0')
      const m = String(d.getMinutes()).padStart(2, '0')
      return `${y}-${mo}-${day} ${h}:${m}`
    } catch {
      return isoStr || ''
    }
  },

  /**
   * Toggle expand/collapse for a submission to show/hide note.
   */
  toggleExpand(e) {
    const id = e.currentTarget.dataset.id
    this.setData({
      expandedId: this.data.expandedId === id ? '' : id,
    })
  },

  /**
   * Copy link to clipboard.
   */
  copyLink(e) {
    const link = e.currentTarget.dataset.link
    if (!link) return
    wx.setClipboardData({
      data: link,
      success: () => {
        wx.showToast({ title: isZh ? '已复制链接' : 'Link copied', icon: 'success' })
      },
    })
  },

  /**
   * Delete a submission (long press).
   */
  deleteSubmission(e) {
    const id = e.currentTarget.dataset.id
    wx.showModal({
      title: isZh ? '删除投稿' : 'Delete submission?',
      content: isZh ? '确定要删除这条投稿记录吗？' : 'Are you sure you want to delete this submission?',
      confirmColor: '#ff4757',
      success: (res) => {
        if (res.confirm) {
          try {
            let list = wx.getStorageSync('rf_ugc_submissions') || []
            list = list.filter((item) => item.id !== id)
            wx.setStorageSync('rf_ugc_submissions', list)
            this._loadSubmissions()
            wx.showToast({ title: isZh ? '已删除' : 'Deleted', icon: 'success' })
          } catch (e) {
            console.error('[ugc] Failed to delete:', e)
          }
        }
      },
    })
  },
})
