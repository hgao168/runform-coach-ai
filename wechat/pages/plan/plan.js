// pages/plan/plan.js
const api = require('../../utils/api')
const storage = require('../../utils/storage')
const { t, backendLang, isZh } = require('../../utils/i18n')

// Map backend category keys → color
const CAT_COLORS = {
  easy: '#00f5a0',
  long: '#00d4ff',
  quality: '#ff9f30',
  recovery: '#a78bfa',
  strength: '#fb923c',
  mobility: '#34d399',
  rest: 'rgba(255,255,255,0.35)',
}

// Category display labels
const CAT_LABELS_ZH = {
  easy: '轻松跑',
  long: '长距离跑',
  quality: '质量训练',
  recovery: '恢复跑',
  strength: '力量训练',
  mobility: '灵活性训练',
  rest: '休息',
}
const CAT_LABELS_EN = {
  easy: 'Easy',
  long: 'Long Run',
  quality: 'Quality',
  recovery: 'Recovery',
  strength: 'Strength',
  mobility: 'Mobility',
  rest: 'Rest',
}
const catLabel = (key) => {
  const k = (key || '').toLowerCase()
  return isZh ? (CAT_LABELS_ZH[k] || key) : (CAT_LABELS_EN[k] || key)
}

const GOAL_VALUES = ['5k', '10k', 'half_marathon', 'marathon', 'general_fitness']
const GOAL_LABELS_ZH = ['5公里', '10公里', '半马', '全马', '健身']
const GOAL_LABELS_EN = ['5K', '10K', 'Half Marathon', 'Marathon', 'Fitness']

const DAY_SHORT = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
const DAY_LABELS_ZH = ['周一', '周二', '周三', '周四', '周五', '周六', '周日']

Page({
  data: {
    i: {
      planTitle: t('planTitle'),
      planSubtitle: t('planSubtitle'),
      weeklyKm: t('weeklyKm'),
      goal: t('goal'),
      runDays: t('runDays'),
      daysSelected: t('daysSelected'),
      injuryFlag: t('injuryFlag'),
      injuryWarning: t('injuryWarning'),
      generatePlan: t('generatePlan'),
      generating: t('generating'),
      totalKm: t('totalKm'),
      runningDays: t('runningDays'),
      nextWeekPlan: t('nextWeekPlan'),
    },

    weeklyKm: 30,
    selectedGoal: 'general_fitness',
    selectedDays: ['Tue', 'Thu', 'Sat'],
    injuryFlag: false,
    generating: false,

    goals: GOAL_VALUES.map((k, i) => ({
      key: k,
      label: isZh ? GOAL_LABELS_ZH[i] : GOAL_LABELS_EN[i],
    })),
    dayLabels: isZh ? DAY_LABELS_ZH : DAY_SHORT,

    plan: null,
  },

  onLoad() {
    // Pre-fill from saved profile
    const profile = storage.getProfile()
    if (profile) {
      const updates = {}
      if (profile.weeklyMileageKm) updates.weeklyKm = profile.weeklyMileageKm
      if (profile.target) updates.selectedGoal = profile.target
      if (Object.keys(updates).length) this.setData(updates)
    }
    // Restore saved plan
    const saved = storage.getNextWeekPlan()
    if (saved) {
      this.setData({ plan: this._parsePlan(saved) })
    }
  },

  onKmChange(e) {
    this.setData({ weeklyKm: e.detail.value })
  },

  selectGoal(e) {
    this.setData({ selectedGoal: e.currentTarget.dataset.key })
  },

  toggleDay(e) {
    const day = e.currentTarget.dataset.day
    const days = [...this.data.selectedDays]
    const idx = days.indexOf(day)
    if (idx === -1) days.push(day)
    else days.splice(idx, 1)
    this.setData({ selectedDays: days })
  },

  onInjuryChange(e) {
    this.setData({ injuryFlag: e.detail.value })
  },

  generatePlan() {
    if (this.data.generating) return
    if (this.data.selectedDays.length === 0) {
      wx.showToast({ title: '请至少选择一天', icon: 'none' })
      return
    }

    this.setData({ generating: true })

    // Map display labels back to short codes if using Chinese labels
    const dayShortSelected = this.data.selectedDays.map((label) => {
      const idx = DAY_LABELS_ZH.indexOf(label)
      return idx !== -1 ? DAY_SHORT[idx] : label
    })

    const profile = storage.getProfile()
    const input = {
      current_weekly_km: this.data.weeklyKm,
      target: this.data.selectedGoal,
      available_running_days: dayShortSelected.length,
      selected_run_days: dayShortSelected,
      injury_flag: this.data.injuryFlag,
      language: backendLang,
      first_name: profile?.firstName || '',
      runner_level: profile?.level || 'intermediate',
    }

    api.generatePlan(input)
      .then((result) => {
        storage.saveNextWeekPlan(result)
        this.setData({ generating: false, plan: this._parsePlan(result) })
        wx.pageScrollTo({ scrollTop: 99999, duration: 300 })
      })
      .catch((err) => {
        this.setData({ generating: false })
        wx.showModal({
          title: t('error'),
          content: err.message || t('planError'),
          showCancel: false,
        })
      })
  },

  _parsePlan(raw) {
    const days = (raw.days || raw.schedule || []).map((d) => {
      const cat = (d.category || d.type || 'rest').toLowerCase()
      return {
        day: d.day || d.name || '',
        type: catLabel(cat),
        description: d.description || d.detail || '',
        km: d.km || d.distance_km || null,
        notes: d.notes || '',
        color: CAT_COLORS[cat] || 'rgba(255,255,255,0.4)',
      }
    })
    return {
      total_km: raw.total_km || raw.weekly_km || 0,
      running_days: raw.running_days || days.filter((d) => d.km).length,
      days,
    }
  },
})
