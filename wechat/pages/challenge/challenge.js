// pages/challenge/challenge.js
const { t } = require('../../utils/i18n')

// ─── Canvas 2D progress ring ───
const W = 220
const H = 220
const DPR = 2

Page({
  data: {
    i: {},
    // Challenge state
    joined: false,
    challengeDays: 14,
    completedDays: 0,
    todayCompleted: false,
    progressPct: 0,

    // Leaderboard
    leaderboard: [],
    myRank: '-',

    // Tab
    activeTab: 'progress', // 'progress' | 'leaderboard'

    loading: true,
  },

  onLoad() {
    this.setData({
      i: {
        challengeTitle: t('challengeTitle'),
        challengeSub: t('challengeSub'),
        challengeDesc: t('challengeDesc'),
        joinChallenge: t('joinChallenge'),
        joinedLabel: t('joinedLabel'),
        progressLabel: t('progressLabel'),
        leaderboardLabel: t('leaderboardLabel'),
        todayTask: t('todayTask'),
        checkIn: t('checkIn'),
        checkedIn: t('checkedIn'),
        dayLabel: t('dayLabel'),
        daysCompleted: t('daysCompleted'),
        rank: t('rank'),
        noRank: t('noRank'),
        loading: t('loading'),
      },
    })
    this._loadChallengeData()
  },

  onReady() {
    if (this.data.joined) {
      this._drawProgressRing()
    }
  },

  _loadChallengeData() {
    // Simulate loading challenge data from storage/API
    const app = getApp()
    const challengeData = app.globalData.challenge || this._getDefaultChallenge()
    const leaderboardData = app.globalData.challengeLeaderboard || this._getDemoLeaderboard()

    const completedDays = challengeData.completedDays || 0
    const progressPct = Math.round((completedDays / this.data.challengeDays) * 100)

    this.setData({
      joined: challengeData.joined || false,
      completedDays,
      todayCompleted: challengeData.todayCompleted || false,
      progressPct,
      leaderboard: leaderboardData.slice(0, 20),
      myRank: challengeData.joined
        ? leaderboardData.findIndex((e) => e.isMe) + 1 || '-'
        : '-',
      loading: false,
    })
  },

  _getDefaultChallenge() {
    return { joined: false, completedDays: 0, todayCompleted: false }
  },

  _getDemoLeaderboard() {
    const names = ['跑者小明', '马拉松侠', '清晨跑者', '追风者', 'RunnerX',
      '铁腿阿强', '慢跑侠', '夜跑达人', '晨光跑者', '飞毛腿']
    return names.map((name, i) => ({
      name,
      days: Math.max(0, 14 - i),
      avatarText: name[0],
      isMe: i === 5 && this.data.joined,
    })).sort((a, b) => b.days - a.days)
  },

  // ─── Tab switch ───
  switchTab(e) {
    const tab = e.currentTarget.dataset.tab
    this.setData({ activeTab: tab })
  },

  // ─── Join challenge ───
  joinChallenge() {
    const app = getApp()
    const challengeData = {
      joined: true,
      completedDays: 0,
      todayCompleted: false,
    }
    app.globalData.challenge = challengeData

    this.setData({
      joined: true,
      completedDays: 0,
      todayCompleted: false,
      progressPct: 0,
    })

    // Draw initial progress ring
    setTimeout(() => this._drawProgressRing(), 200)

    wx.showToast({ title: t('joinedLabel') || '已加入挑战！', icon: 'success' })
  },

  // ─── Daily check-in ───
  checkInToday() {
    if (this.data.todayCompleted) {
      wx.showToast({ title: t('checkedIn') || '今日已打卡', icon: 'none' })
      return
    }

    const newCompleted = Math.min(this.data.completedDays + 1, this.data.challengeDays)
    const progressPct = Math.round((newCompleted / this.data.challengeDays) * 100)
    const allDone = newCompleted >= this.data.challengeDays

    const app = getApp()
    if (!app.globalData.challenge) app.globalData.challenge = {}
    app.globalData.challenge.completedDays = newCompleted
    app.globalData.challenge.todayCompleted = true

    this.setData({
      completedDays: newCompleted,
      todayCompleted: true,
      progressPct,
    })

    this._drawProgressRing()

    if (allDone) {
      wx.showModal({
        title: '🎉',
        content: t('isZh') ? '恭喜完成14天跑姿改善挑战！' : 'Congratulations! You completed the 14-day challenge!',
        showCancel: false,
      })
    } else {
      wx.showToast({
        title: t('checkedIn') || '打卡成功！',
        icon: 'success',
      })
    }
  },

  // ─── Canvas 2D Progress Ring ───
  _drawProgressRing() {
    const query = wx.createSelectorQuery().in(this)
    query.select('#progressCanvas')
      .fields({ node: true, size: true })
      .exec((res) => {
        if (!res || !res[0] || !res[0].node) {
          console.warn('[Challenge] Canvas node not found')
          return
        }

        const canvas = res[0].node
        const ctx = canvas.getContext('2d')

        canvas.width = W * DPR
        canvas.height = H * DPR
        ctx.scale(DPR, DPR)

        const cx = W / 2
        const cy = H / 2
        const radius = 80
        const lineWidth = 12

        // Clear
        ctx.clearRect(0, 0, W, H)

        // Background ring
        ctx.beginPath()
        ctx.arc(cx, cy, radius, 0, Math.PI * 2)
        ctx.strokeStyle = 'rgba(255,255,255,0.08)'
        ctx.lineWidth = lineWidth
        ctx.stroke()

        // Progress arc
        const pct = Math.min(this.data.progressPct, 100)
        if (pct > 0) {
          // Gradient stroke
          const grad = ctx.createLinearGradient(0, 0, W, H)
          grad.addColorStop(0, '#00f5a0')
          grad.addColorStop(0.6, '#00d4ff')
          grad.addColorStop(1, '#a78bfa')

          const startAngle = -Math.PI / 2
          const endAngle = startAngle + (Math.PI * 2 * pct) / 100
          ctx.beginPath()
          ctx.arc(cx, cy, radius, startAngle, endAngle)
          ctx.strokeStyle = grad
          ctx.lineWidth = lineWidth
          ctx.lineCap = 'round'
          ctx.stroke()

          // Glow effect
          ctx.beginPath()
          ctx.arc(cx, cy, radius, startAngle, endAngle)
          ctx.strokeStyle = 'rgba(0,245,160,0.25)'
          ctx.lineWidth = lineWidth + 6
          ctx.lineCap = 'round'
          ctx.stroke()
        }

        // Center text: days
        ctx.fillStyle = '#ffffff'
        ctx.font = 'bold 48px -apple-system, "PingFang SC", sans-serif'
        ctx.textAlign = 'center'
        ctx.textBaseline = 'middle'
        ctx.fillText(`${this.data.completedDays}`, cx, cy - 8)

        // Sub label
        ctx.fillStyle = 'rgba(255,255,255,0.4)'
        ctx.font = '14px -apple-system, "PingFang SC", sans-serif'
        ctx.fillText(
          t('daysCompleted') || '天已完成',
          cx,
          cy + 28
        )

        // "of 14" below
        ctx.fillStyle = 'rgba(255,255,255,0.25)'
        ctx.font = '11px -apple-system, "PingFang SC", sans-serif'
        ctx.fillText(`/ ${this.data.challengeDays}`, cx, cy + 48)
      })
  },

  // ─── Share ───
  onShareAppMessage() {
    const { completedDays, challengeDays } = this.data
    return {
      title: t('isZh')
        ? `我已坚持 ${completedDays}/${challengeDays} 天跑姿改善挑战！`
        : `I've completed ${completedDays}/${challengeDays} days of the running form challenge!`,
      path: '/pages/challenge/challenge',
    }
  },
})
