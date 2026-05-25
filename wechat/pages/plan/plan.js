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

// Phase display labels
const PHASE_LABELS = {
  base: isZh ? '基础期' : 'Base Phase',
  build: isZh ? '建设期' : 'Build Phase',
  peak: isZh ? '巅峰期' : 'Peak Phase',
  taper: isZh ? '减量期' : 'Taper Phase',
}

const GOAL_VALUES = ['5k', '10k', 'half_marathon', 'marathon', 'general_fitness']
const GOAL_LABELS_ZH = ['5公里', '10公里', '半马', '全马', '健身']
const GOAL_LABELS_EN = ['5K', '10K', 'Half Marathon', 'Marathon', 'Fitness']

const DAY_SHORT = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
const DAY_LABELS_ZH = ['周一', '周二', '周三', '周四', '周五', '周六', '周日']

// Marathon major options
const MARATHON_MAJORS = [
  { key: 'Boston', labelZh: '波士顿马拉松', labelEn: 'Boston Marathon' },
  { key: 'London', labelZh: '伦敦马拉松', labelEn: 'London Marathon' },
  { key: 'Berlin', labelZh: '柏林马拉松', labelEn: 'Berlin Marathon' },
  { key: 'Chicago', labelZh: '芝加哥马拉松', labelEn: 'Chicago Marathon' },
  { key: 'NYC', labelZh: '纽约马拉松', labelEn: 'NYC Marathon' },
  { key: 'Tokyo', labelZh: '东京马拉松', labelEn: 'Tokyo Marathon' },
  { key: 'Custom', labelZh: '自定义赛事', labelEn: 'Custom Race' },
]

const PLAN_MODES = [
  { key: 'weekly', labelZh: '周计划', labelEn: 'Weekly' },
  { key: 'marathon', labelZh: '马拉松', labelEn: 'Marathon' },
  { key: 'race', labelZh: '比赛', labelEn: 'Race' },
]

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
      // Marathon translations
      planMode: t('planMode'),
      modeWeekly: t('modeWeekly'),
      modeMarathon: t('modeMarathon'),
      modeRace: t('modeRace'),
      marathonRace: t('marathonRace'),
      marathonCustom: t('marathonCustom'),
      marathonWeeks: t('marathonWeeks'),
      marathonWeeksSuffix: t('marathonWeeksSuffix'),
      marathonGenerate: t('marathonGenerate'),
      raceGenerate: t('raceGenerate'),
      marathonTargetKm: t('marathonTargetKm'),
      marathonLongRun: t('marathonLongRun'),
      marathonKeyWorkout: t('marathonKeyWorkout'),
      marathonWorkouts: t('marathonWorkouts'),
      marathonRaceWeek: t('marathonRaceWeek'),
      marathonPlanTitle: t('marathonPlanTitle'),
      racePlanTitle: t('racePlanTitle'),
    },

    weeklyKm: 30,
    selectedGoal: 'general_fitness',
    selectedDays: ['Tue', 'Thu', 'Sat'],
    injuryFlag: false,
    generating: false,

    // Plan mode: weekly | marathon | race
    planMode: 'weekly',

    // Marathon-specific
    marathonMajor: 'Berlin',
    marathonWeeks: 16,

    goals: GOAL_VALUES.map((k, i) => ({
      key: k,
      label: isZh ? GOAL_LABELS_ZH[i] : GOAL_LABELS_EN[i],
    })),
    dayLabels: isZh ? DAY_LABELS_ZH : DAY_SHORT,

    // Plan mode options
    planModes: PLAN_MODES.map((m) => ({
      key: m.key,
      label: isZh ? m.labelZh : m.labelEn,
    })),

    // Marathon major options
    marathonMajors: MARATHON_MAJORS.map((m) => ({
      key: m.key,
      label: isZh ? m.labelZh : m.labelEn,
    })),

    plan: null,          // weekly plan
    marathonPlan: null,  // marathon block result
    racePlan: null,      // race block result
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
      const parsed = this._parsePlan(saved)
      const updates = { plan: parsed.plan, marathonPlan: parsed.marathonPlan, racePlan: parsed.racePlan }
      if (parsed.marathonPlan) updates.planMode = 'marathon'
      else if (parsed.racePlan) updates.planMode = 'race'
      else updates.planMode = 'weekly'
      this.setData(updates)
    }
  },

  onKmChange(e) {
    this.setData({ weeklyKm: e.detail.value })
  },

  onMarathonWeeksChange(e) {
    this.setData({ marathonWeeks: e.detail.value })
  },

  selectGoal(e) {
    this.setData({ selectedGoal: e.currentTarget.dataset.key })
  },

  selectPlanMode(e) {
    this.setData({ planMode: e.currentTarget.dataset.key })
  },

  selectMarathonMajor(e) {
    this.setData({ marathonMajor: e.currentTarget.dataset.key })
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

  _getGenerateLabel() {
    const mode = this.data.planMode
    if (mode === 'marathon') return this.data.i.marathonGenerate
    if (mode === 'race') return this.data.i.raceGenerate
    return this.data.i.generatePlan
  },

  generatePlan() {
    if (this.data.generating) return
    if (this.data.selectedDays.length === 0) {
      wx.showToast({ title: '请至少选择一天', icon: 'none' })
      return
    }

    const mode = this.data.planMode

    // Validate marathon mode requires marathon goal
    if (mode === 'marathon' && this.data.selectedGoal !== 'marathon') {
      wx.showToast({ title: isZh ? '请先选择"全马"目标' : 'Please select Marathon goal first', icon: 'none' })
      return
    }

    // Validate race mode requires a race goal (5k, 10k, half_marathon)
    if (mode === 'race' && !['5k', '10k', 'half_marathon'].includes(this.data.selectedGoal)) {
      wx.showToast({ title: isZh ? '请选择 5K/10K/半马 目标' : 'Please select 5K/10K/Half goal', icon: 'none' })
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

    // Marathon mode
    if (mode === 'marathon') {
      input.marathon = true
      input.marathon_major = this.data.marathonMajor
      input.marathon_plan_weeks = this.data.marathonWeeks
      input.include_marathon_block = true
    }

    // Race mode
    if (mode === 'race') {
      input.race = true
      input.include_race_block = true
    }

    api.generatePlan(input)
      .then((result) => {
        storage.saveNextWeekPlan(result)
        const parsed = this._parsePlan(result)
        const updates = {
          generating: false,
          plan: parsed.plan,
          marathonPlan: parsed.marathonPlan,
          racePlan: parsed.racePlan,
        }
        this.setData(updates)
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
    // Weekly plan
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
    const plan = {
      total_km: raw.total_km || raw.weekly_km || 0,
      running_days: raw.running_days || days.filter((d) => d.km).length,
      days,
    }

    // Marathon block
    let marathonPlan = null
    if (raw.marathonPlan || raw.marathon_plan) {
      const mp = raw.marathonPlan || raw.marathon_plan
      marathonPlan = {
        race: mp.race || '',
        planProfile: mp.planProfile || mp.plan_profile || '',
        courseProfile: mp.courseProfile || mp.course_profile || '',
        elevationNote: mp.elevationNote || mp.elevation_note || '',
        totalWeeks: mp.totalWeeks || mp.total_weeks || 0,
        phaseGroups: this._buildPhaseGroups(mp.weeks || []),
      }
    }

    // Race block
    let racePlan = null
    if (raw.racePlan || raw.race_plan) {
      const rp = raw.racePlan || raw.race_plan
      racePlan = {
        target: rp.target || '',
        level: rp.level || '',
        totalWeeks: rp.totalWeeks || rp.total_weeks || 0,
        phaseGroups: this._buildPhaseGroups(rp.weeks || []),
      }
    }

    return { plan, marathonPlan, racePlan }
  },

  _buildPhaseGroups(weeks) {
    if (!weeks || weeks.length === 0) return []

    const sorted = [...weeks].sort((a, b) => a.week - b.week)
    const maxWeek = sorted[sorted.length - 1].week
    const groups = []

    for (const week of sorted) {
      const phase = (week.phase || 'base').toLowerCase()
      const phaseLabel = PHASE_LABELS[phase] || phase
      const isLastWeek = week.week === maxWeek

      if (groups.length === 0 || groups[groups.length - 1].phase !== phase) {
        groups.push({
          phase: phase,
          phaseLabel: phaseLabel,
          startWeek: week.week,
          endWeek: week.week,
          weeks: [this._normalizeWeek(week, isLastWeek)],
        })
      } else {
        const last = groups[groups.length - 1]
        last.endWeek = week.week
        last.weeks.push(this._normalizeWeek(week, isLastWeek))
      }
    }

    return groups
  },

  _normalizeWeek(w, isLastWeek) {
    const workouts = (w.workouts || []).map((wo) => ({
      day: wo.day || '',
      title: wo.title || '',
      category: wo.category || '',
      intensity: wo.intensity || '',
      details: wo.details || '',
      distanceKm: wo.distanceKm || wo.distance_km || 0,
    }))

    return {
      week: w.week,
      phase: w.phase || '',
      targetKm: w.targetKm || w.target_km || 0,
      longRunKm: w.longRunKm || w.long_run_km || 0,
      keyWorkout: w.keyWorkout || w.key_workout || '',
      workouts,
      isRaceWeek: isLastWeek,
    }
  },
})
