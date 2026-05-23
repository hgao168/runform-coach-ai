// pages/club-leaderboard/club-leaderboard.js
// RF-603: 跑团专属排行榜 (Club Leaderboard)
const { t } = require('../../utils/i18n')

Page({
  data: {
    i: {},
    clubCode: '',
    clubName: '',
    leaderboard: [],
    loading: true,
    // API not ready flag — shows coming-soon banner with mock data
    isMock: false,
  },

  onLoad(options) {
    const clubCode = options.clubCode || options.clubcode || ''
    this.setData({ clubCode })

    this.setData({
      i: {
        clubLeaderboardTitle: t('clubLeaderboardTitle'),
        clubCodeLabel: t('clubCodeLabel'),
        clubComingSoon: t('clubComingSoon'),
        clubComingSoonSub: t('clubComingSoonSub'),
        clubMembers: t('clubMembers'),
        cadenceSpm: t('cadenceSpm'),
        formScoreLabel: t('formScoreLabel'),
        rankChange: t('rankChange'),
        rankUp: t('rankUp'),
        rankDown: t('rankDown'),
        noClubCode: t('noClubCode'),
        clubNotExist: t('clubNotExist'),
        loading: t('loading'),
        dayLabel: t('dayLabel'),
      },
    })

    if (!clubCode) {
      this.setData({ loading: false })
      return
    }

    this._loadClubLeaderboard(clubCode)
  },

  _loadClubLeaderboard(clubCode) {
    // Try backend API first; fall back to mock data with coming-soon banner
    this._tryFetchFromAPI(clubCode)
      .then((data) => {
        if (data && data.members && data.members.length > 0) {
          this.setData({
            clubName: data.clubName || clubCode,
            leaderboard: this._formatMembers(data.members),
            isMock: false,
            loading: false,
          })
        } else {
          throw new Error('No data')
        }
      })
      .catch(() => {
        // API not ready — use mock data
        const mockData = this._getMockLeaderboard(clubCode)
        this.setData({
          clubName: clubCode,
          leaderboard: mockData,
          isMock: true,
          loading: false,
        })
      })
  },

  _tryFetchFromAPI(clubCode) {
    return new Promise((resolve, reject) => {
      const { BASE_URL } = require('../../utils/config')
      wx.request({
        url: `${BASE_URL}/api/v1/clubs/${clubCode}/leaderboard`,
        method: 'GET',
        header: { 'Content-Type': 'application/json' },
        timeout: 8000,
        success(res) {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve(res.data)
          } else {
            reject(new Error(`HTTP ${res.statusCode}`))
          }
        },
        fail(err) {
          reject(new Error(err.errMsg || 'Network error'))
        },
      })
    })
  },

  _formatMembers(members) {
    return members.map((m, idx) => ({
      rank: idx + 1,
      avatar: m.avatar || '',
      avatarText: (m.nickname || m.name || '?')[0].toUpperCase(),
      nickname: m.nickname || m.name || `Runner ${idx + 1}`,
      cadence: m.cadence || 0,
      formScore: m.formScore || m.form_score || 0,
      rankChange: m.rankChange || m.rank_change || 0,
      isMe: m.isMe || m.is_me || false,
    }))
  },

  _getMockLeaderboard(clubCode) {
    // Mock data with realistic running stats
    const baseMembers = [
      { name: '马拉松侠', cadence: 182, formScore: 92, rankChange: 0 },
      { name: '追风跑者', cadence: 178, formScore: 89, rankChange: 1 },
      { name: '晨光跑者', cadence: 176, formScore: 87, rankChange: -1 },
      { name: '铁腿阿强', cadence: 180, formScore: 85, rankChange: 2 },
      { name: 'RunnerX', cadence: 174, formScore: 83, rankChange: 0 },
      { name: '夜跑达人', cadence: 172, formScore: 81, rankChange: -2 },
      { name: '慢跑侠', cadence: 170, formScore: 79, rankChange: 1 },
      { name: '飞毛腿', cadence: 168, formScore: 77, rankChange: 0 },
      { name: '跑者小明', cadence: 166, formScore: 75, rankChange: -1 },
      { name: '追风侠', cadence: 164, formScore: 72, rankChange: 0 },
      { name: '清风跑者', cadence: 162, formScore: 70, rankChange: 2 },
      { name: '远足者', cadence: 160, formScore: 68, rankChange: -1 },
    ]

    // Make the 5th member "me"
    return baseMembers.map((m, idx) => ({
      rank: idx + 1,
      avatarText: m.name[0],
      nickname: m.name,
      cadence: m.cadence,
      formScore: m.formScore,
      rankChange: m.rankChange,
      isMe: idx === 4,
    }))
  },

  onShareAppMessage() {
    return {
      title: t('isZh')
        ? `RunForm ${this.data.clubName} 跑团排行榜`
        : `RunForm ${this.data.clubName} Club Leaderboard`,
      path: `/pages/club-leaderboard/club-leaderboard?clubCode=${this.data.clubCode}`,
    }
  },
})
