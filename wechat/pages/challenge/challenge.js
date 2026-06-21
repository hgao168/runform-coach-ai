// pages/challenge/challenge.js
// C2: 接通真实后端挑战赛 API
const { t, isZh } = require('../../utils/i18n')
const {
  getChallenges,
  joinChallenge: apiJoinChallenge,
  getLeaderboard: apiGetLeaderboard,
  checkInChallenge: apiCheckInChallenge,
  getUserId,
} = require('../../utils/api')

// ─── Canvas 2D progress ring ───
const W = 220
const H = 220
const DPR = 2
const FONT = '-apple-system, "PingFang SC", sans-serif'

Page({
  data: {
    i: {},
    // Challenge state
    challengeId: '',    // C2: active challenge ID from backend
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
        // Pre-computed challenges task strings for WXML (can't call t() in mustache)
        taskRunDrills: isZh ? '完成5分钟跑姿基础训练' : 'Complete 5-minute form drills',
        taskRecordVideo: isZh ? '录制并分析一段跑步视频' : 'Record and analyze a running video',
        taskComplete: isZh ? '🎉 挑战完成！' : '🎉 Challenge complete!',
      },
    })
    this._loadChallengeData()
  },

  onReady() {
    if (this.data.joined) {
      this._drawProgressRing()
    }
  },

  // C2: 接通真实挑战赛 API — 获取挑战列表、排行榜
  async _loadChallengeData() {
    const app = getApp()
    const iosUserId = getUserId()
    let challengeId = ''
    let joined = false
    let completedDays = 0
    let todayCompleted = false
    let challengeDays = this.data.challengeDays
    let leaderboardData = []

    // C2: Step 1 — fetch challenges list from backend (with ios_user_id for personal state)
    try {
      const challenges = await getChallenges(iosUserId)
      if (challenges && Array.isArray(challenges) && challenges.length > 0) {
        const first = challenges[0]
        challengeId = first.id || first.challenge_id || ''
        challengeDays = first.days || first.total_days || 14
        // Backend returns: joined, completed_days, today_completed (when ios_user_id provided)
        joined = first.joined || false
        completedDays = first.completed_days || first.completedDays || 0
        todayCompleted = first.today_completed || first.todayCompleted || false

        // Persist to globalData for fallback
        app.globalData.challenge = { joined, completedDays, todayCompleted, challengeId, challengeDays }
        app.globalData.challengeId = challengeId
      }
    } catch (err) {
      console.warn('[Challenge] Fetch challenges API failed, using local fallback:', err.message)
    }

    // C2: Fallback — use globalData mock
    if (!challengeId) {
      const mockData = app.globalData.challenge || this._getDefaultChallenge()
      joined = mockData.joined || false
      completedDays = mockData.completedDays || 0
      todayCompleted = mockData.todayCompleted || false
    }

    const progressPct = Math.round((completedDays / challengeDays) * 100)

    // C2: Step 2 — fetch leaderboard if challenge ID is available
    if (challengeId) {
      try {
        const lb = await apiGetLeaderboard(challengeId, iosUserId)
        if (lb && Array.isArray(lb)) {
          leaderboardData = lb.map((item, idx) => ({
            ...item,
            // Backend ChallengeLeaderboardEntry fields: display_name, completed_days, is_me, rank, days
            // Use ?? to avoid falsy-0 fallthrough (completed_days===0 should NOT fallback to days)
            name: item.display_name || item.name || item.nickname || `User ${idx + 1}`,
            days: item.completed_days ?? item.days ?? 0,
            avatarText: (item.display_name || item.name || item.nickname || '?')[0].toUpperCase(),
            isMe: item.is_me || item.isMe || false,
          }))
          // Persist to globalData
          app.globalData.challengeLeaderboard = leaderboardData
        } else if (lb && lb.entries) {
          leaderboardData = lb.entries.map((item, idx) => ({
            ...item,
            name: item.display_name || item.name || item.nickname || `User ${idx + 1}`,
            days: item.completed_days ?? item.days ?? 0,
            avatarText: (item.display_name || item.name || item.nickname || '?')[0].toUpperCase(),
            isMe: item.is_me || item.isMe || false,
          }))
          app.globalData.challengeLeaderboard = leaderboardData
        }
      } catch (err) {
        console.warn('[Challenge] Fetch leaderboard API failed, using local fallback:', err.message)
      }
    }

    // C2: Fallback leaderboard — use mock
    if (!leaderboardData.length) {
      leaderboardData = app.globalData.challengeLeaderboard || this._getDemoLeaderboard(joined)
    }

    this.setData({
      challengeId,
      joined,
      challengeDays,
      completedDays: Math.min(completedDays, challengeDays),
      todayCompleted,
      progressPct,
      leaderboard: leaderboardData.slice(0, 20),
      myRank: joined
        ? leaderboardData.findIndex((e) => e.isMe) + 1 || '-'
        : '-',
      loading: false,
    })
  },

  _getDefaultChallenge() {
    return { joined: false, completedDays: 0, todayCompleted: false }
  },

  _getDemoLeaderboard(joined) {
    const names = ['跑者小明', '马拉松侠', '清晨跑者', '追风者', 'RunnerX',
      '铁腿阿强', '慢跑侠', '夜跑达人', '晨光跑者', '飞毛腿']
    return names.map((name, i) => ({
      name,
      days: Math.max(0, 14 - i),
      avatarText: name[0],
      isMe: i === 5 && joined,
    })).sort((a, b) => b.days - a.days)
  },

  // ─── Tab switch ───
  switchTab(e) {
    const tab = e.currentTarget.dataset.tab
    this.setData({ activeTab: tab })
  },

  // ─── Join challenge ───
  // C2: 调用 POST /api/v1/challenges/{challenge_id}/join
  async joinChallenge() {
    const app = getApp()
    const userId = getUserId()
    const challengeId = this.data.challengeId || app.globalData.challengeId || ''

    // Try backend API first
    let apiJoined = false
    if (challengeId) {
      try {
        await apiJoinChallenge(challengeId, { ios_user_id: userId })
        apiJoined = true
        console.log('[Challenge] Joined via API:', challengeId)
      } catch (err) {
        console.warn('[Challenge] Join API failed, using local state:', err.message)
        // C2: 降级到本地状态
        wx.showToast({ title: isZh ? '加入失败，使用本地模式' : 'Join failed, using local mode', icon: 'none' })
      }
    }

    // Update local state (both on success and fallback)
    const challengeData = {
      joined: true,
      completedDays: 0,
      todayCompleted: false,
      challengeId: challengeId || this.data.challengeId,
    }
    app.globalData.challenge = challengeData

    // Regenerate leaderboard with isMe
    const newLeaderboard = this._getDemoLeaderboard(true)
    app.globalData.challengeLeaderboard = newLeaderboard

    this.setData({
      joined: true,
      completedDays: 0,
      todayCompleted: false,
      progressPct: 0,
      leaderboard: newLeaderboard.slice(0, 20),
      myRank: newLeaderboard.findIndex((e) => e.isMe) + 1 || '-',
    })

    // Draw initial progress ring
    setTimeout(() => this._drawProgressRing(), 300)

    wx.showToast({ title: apiJoined ? (t('joinedLabel') || '已加入挑战！') : (t('joinedLabel') || '已加入挑战！'), icon: 'success' })
  },

  // ─── Daily check-in ───
  // C2: 调用 POST /api/v1/challenges/{challenge_id}/check-in
  async checkInToday() {
    if (this.data.todayCompleted) {
      wx.showToast({ title: t('checkedIn') || '今日已打卡', icon: 'none' })
      return
    }

    const app = getApp()
    const userId = getUserId()
    const challengeId = this.data.challengeId || app.globalData.challengeId || ''

    // C2: Try backend API first
    let apiCheckedIn = false
    if (challengeId) {
      try {
        await apiCheckInChallenge(challengeId, { user_id: userId })
        apiCheckedIn = true
        console.log('[Challenge] Check-in via API:', challengeId)
      } catch (err) {
        console.warn('[Challenge] Check-in API failed, using local state:', err.message)
        // C2: 降级到本地状态 — continue with local tracking
      }
    }

    const newCompleted = Math.min(this.data.completedDays + 1, this.data.challengeDays)
    const progressPct = Math.round((newCompleted / this.data.challengeDays) * 100)
    const allDone = newCompleted >= this.data.challengeDays

    if (!app.globalData.challenge) app.globalData.challenge = {}
    app.globalData.challenge.completedDays = newCompleted
    app.globalData.challenge.todayCompleted = true

    // Update leaderboard days for "me"
    const updatedLeaderboard = this.data.leaderboard.map((item) => {
      if (item.isMe) {
        return { ...item, days: Math.min((item.days || 0) + 1, this.data.challengeDays) }
      }
      return item
    }).sort((a, b) => b.days - a.days)

    const newRank = updatedLeaderboard.findIndex((e) => e.isMe) + 1

    this.setData({
      completedDays: newCompleted,
      todayCompleted: true,
      progressPct,
      leaderboard: updatedLeaderboard,
      myRank: newRank || '-',
    })

    this._drawProgressRing()

    if (allDone) {
      wx.showModal({
        title: '🎉',
        content: isZh ? '恭喜完成14天跑姿改善挑战！' : 'Congratulations! You completed the 14-day challenge!',
        showCancel: false,
      })
    } else {
      wx.showToast({
        title: t('checkedIn') || '打卡成功！',
        icon: 'success',
      })
    }
  },

  // ─── Canvas 2D Progress Ring (with retry) ───
  _drawProgressRing(attempt) {
    const retryAttempt = attempt || 0
    const query = wx.createSelectorQuery().in(this)
    query.select('#progressCanvas')
      .fields({ node: true, size: true })
      .exec((res) => {
        if (!res || !res[0] || !res[0].node) {
          if (retryAttempt < 3) {
            // Retry after short delay — canvas may not be in DOM yet
            setTimeout(() => this._drawProgressRing(retryAttempt + 1), 200)
          } else {
            console.warn('[Challenge] Canvas node not found after 3 retries')
          }
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
        ctx.font = 'bold 48px ' + FONT
        ctx.textAlign = 'center'
        ctx.textBaseline = 'middle'
        ctx.fillText(`${this.data.completedDays}`, cx, cy - 8)

        // Sub label
        ctx.fillStyle = 'rgba(255,255,255,0.4)'
        ctx.font = '14px ' + FONT
        ctx.fillText(
          t('daysCompleted') || '天已完成',
          cx,
          cy + 28
        )

        // "of 14" below
        ctx.fillStyle = 'rgba(255,255,255,0.25)'
        ctx.font = '11px ' + FONT
        ctx.fillText(`/ ${this.data.challengeDays}`, cx, cy + 48)
      })
  },

  // ─── Share ───
  onShareAppMessage() {
    const { completedDays, challengeDays } = this.data
    return {
      title: isZh
        ? `我已坚持 ${completedDays}/${challengeDays} 天跑姿改善挑战！`
        : `I've completed ${completedDays}/${challengeDays} days of the running form challenge!`,
      path: '/pages/challenge/challenge',
    }
  },
})

// (FONT moved to top of file)
