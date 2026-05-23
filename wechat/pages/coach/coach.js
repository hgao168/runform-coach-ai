// pages/coach/coach.js
// RF-602: WeChat 教练面板 MVP
const { t, isZh } = require('../../utils/i18n')
const {
  generateCoachCode,
  joinCoach,
  getCoachStudents,
  getCoachDashboard,
  getUserId,
} = require('../../utils/api')

Page({
  data: {
    i: {},
    // Mode: 'coach' | 'student'
    mode: 'coach',

    // Coach mode data
    coachCode: '',
    coachCodeLoading: false,
    students: [],
    dashboard: null,

    // Student mode data
    joinCodeInput: '',
    joinLoading: false,
    joinedCoaches: [],

    // Shared
    loading: true,
  },

  onLoad() {
    this._initI18n()
    this._loadData()
  },

  onShow() {
    this._loadData()
  },

  _initI18n() {
    this.setData({
      i: {
        coachTitle: t('coachTitle'),
        coachMode: t('coachMode'),
        studentMode: t('studentMode'),
        myCoachCode: t('myCoachCode'),
        coachCodePlaceholder: t('coachCodePlaceholder'),
        joinCoachBtn: t('joinCoachBtn'),
        joinCoachSuccess: t('joinCoachSuccess'),
        joinCoachFail: t('joinCoachFail'),
        coachCodeEmpty: t('coachCodeEmpty'),
        coachStudents: t('coachStudents'),
        coachDashboard: t('coachDashboard'),
        totalStudents: t('totalStudents'),
        avgScore: t('avgScore'),
        activeStudents: t('activeStudents'),
        noStudentsYet: t('noStudentsYet'),
        noStudentsYetSub: t('noStudentsYetSub'),
        copyCoachCode: t('copyCoachCode'),
        coachCodeCopied: t('coachCodeCopied'),
        shareCoachCode: t('shareCoachCode'),
        coachJoinedList: t('coachJoinedList'),
        noCoachJoined: t('noCoachJoined'),
        noCoachJoinedSub: t('noCoachJoinedSub'),
        studentCadence: t('studentCadence'),
        studentFormScore: t('studentFormScore'),
        studentJoinedDate: t('studentJoinedDate'),
        refreshBtn: t('refreshBtn'),
        generatingCode: t('generatingCode'),
        loading: t('loading'),
      },
    })
  },

  async _loadData() {
    const userId = getUserId()

    // Load coach data (always try — user might be both coach and student)
    try {
      const savedCoachCode = wx.getStorageSync('coachCode') || ''
      if (savedCoachCode) {
        this.setData({ coachCode: savedCoachCode })
      }
      // Load students and dashboard if we have a coach code
      if (this.data.coachCode || savedCoachCode) {
        await this._loadCoachPanel(userId)
      }
    } catch (err) {
      console.warn('[Coach] Load coach data failed:', err.message)
    }

    // Load joined coaches from storage
    try {
      const joined = wx.getStorageSync('joinedCoaches') || []
      if (joined.length > 0) {
        this.setData({ joinedCoaches: joined })
      }
    } catch (_) { /* ignore */ }

    this.setData({ loading: false })
  },

  async _loadCoachPanel(userId) {
    try {
      // Fetch students list
      const students = await getCoachStudents(userId)
      const studentList = (students && students.students) || (Array.isArray(students) ? students : [])

      // Fetch dashboard
      const dashboard = await getCoachDashboard(userId)

      this.setData({
        students: studentList.map((s, idx) => ({
          ...s,
          displayName: s.nickname || s.name || (isZh ? `学员${idx + 1}` : `Student ${idx + 1}`),
          avatarText: (s.nickname || s.name || '?')[0].toUpperCase(),
          cadence: s.cadence || s.latest_cadence || 0,
          formScore: s.form_score || s.latest_form_score || 0,
          joinedAt: s.joined_at || s.join_date || '',
        })),
        dashboard: dashboard || null,
      })
    } catch (err) {
      console.warn('[Coach] Panel load failed:', err.message)
      // Don't block — show empty state
    }
  },

  // Toggle mode
  switchMode(e) {
    const mode = e.currentTarget.dataset.mode
    this.setData({ mode })
    if (mode === 'coach') {
      this._loadData()
    }
  },

  // ─── Coach mode actions ───

  async generateCode() {
    if (this.data.coachCodeLoading) return
    this.setData({ coachCodeLoading: true })

    const userId = getUserId()
    try {
      const result = await generateCoachCode(userId)
      const code = result && (result.coach_code || result.code || '')
      if (code) {
        this.setData({ coachCode: code })
        wx.setStorageSync('coachCode', code)
        wx.showToast({ title: t('coachCodeCopied'), icon: 'success' })
        // Refresh panel
        await this._loadCoachPanel(userId)
      }
    } catch (err) {
      console.warn('[Coach] Generate code failed:', err.message)
      wx.showToast({ title: t('isZh') ? '生成失败' : 'Generate failed', icon: 'none' })
    }
    this.setData({ coachCodeLoading: false })
  },

  copyCoachCode() {
    if (!this.data.coachCode) {
      this.generateCode()
      return
    }
    wx.setClipboardData({
      data: this.data.coachCode,
      success: () => {
        wx.showToast({ title: t('coachCodeCopied'), icon: 'success' })
      },
    })
  },

  shareCoachCode() {
    // WeChat share
  },

  // ─── Student mode actions ───

  onJoinCodeInput(e) {
    this.setData({ joinCodeInput: e.detail.value.trim() })
  },

  async joinCoachByCode() {
    const code = this.data.joinCodeInput
    if (!code) {
      wx.showToast({ title: t('coachCodeEmpty'), icon: 'none' })
      return
    }
    if (this.data.joinLoading) return
    this.setData({ joinLoading: true })

    const userId = getUserId()
    try {
      await joinCoach(userId, code)

      // Save to local joined list
      const joined = wx.getStorageSync('joinedCoaches') || []
      const exists = joined.find(c => c.code === code)
      if (!exists) {
        joined.unshift({
          code,
          coachName: '',
          joinedAt: new Date().toISOString().slice(0, 10),
        })
        wx.setStorageSync('joinedCoaches', joined)
        this.setData({ joinedCoaches: joined, joinCodeInput: '' })
      }

      wx.showToast({ title: t('joinCoachSuccess'), icon: 'success' })
    } catch (err) {
      console.warn('[Coach] Join failed:', err.message)
      wx.showToast({ title: t('joinCoachFail'), icon: 'none' })
    }
    this.setData({ joinLoading: false })
  },

  // ─── Share handler ───

  onShareAppMessage() {
    const code = this.data.coachCode
    return {
      title: isZh
        ? `加入我的 RunForm 教练面板！教练码: ${code}`
        : `Join my RunForm Coach Panel! Code: ${code}`,
      path: `/pages/coach/coach?code=${code}`,
      imageUrl: '',
    }
  },

  // ─── Refresh ───

  refresh() {
    this.setData({ loading: true })
    this._loadData()
  },
})
