// pages/profile/profile.js
const storage = require('../../utils/storage')
const { t, isZh } = require('../../utils/i18n')

const LEVEL_OPTIONS = [
  { key: 'beginner', label: isZh ? '初级' : 'Beginner' },
  { key: 'intermediate', label: isZh ? '中级' : 'Intermediate' },
  { key: 'advanced', label: isZh ? '高级' : 'Advanced' },
]

const GOAL_OPTIONS = [
  { key: '5k', label: isZh ? '5公里' : '5K' },
  { key: '10k', label: isZh ? '10公里' : '10K' },
  { key: 'half_marathon', label: isZh ? '半马' : 'Half' },
  { key: 'marathon', label: isZh ? '全马' : 'Full' },
  { key: 'general_fitness', label: isZh ? '健身' : 'Fitness' },
]

const GENDER_OPTIONS = [
  { key: 'male', label: t('genderMale') },
  { key: 'female', label: t('genderFemale') },
  { key: 'other', label: t('genderOther') },
  { key: 'unspecified', label: t('genderUnspecified') },
]

const LEVEL_LABELS = {
  beginner: isZh ? '初级' : 'Beginner',
  intermediate: isZh ? '中级' : 'Intermediate',
  advanced: isZh ? '高级' : 'Advanced',
}

Page({
  data: {
    i: {
      firstName: t('firstName'),
      lastName: t('lastName'),
      level: t('level'),
      weeklyKmLabel: t('weeklyKmLabel'),
      runDaysPerWeek: t('runDaysPerWeek'),
      targetLabel: t('targetLabel'),
      injuryNote: t('injuryNote'),
      genderLabel: t('genderLabel'),
      shoeSizeLabel: t('shoeSizeLabel'),
      legLengthLabel: t('legLengthLabel'),
      shoeBrandModelLabel: t('shoeBrandModelLabel'),
      saveProfile: t('saveProfile'),
    },

    form: {
      firstName: '',
      lastName: '',
      level: 'intermediate',
      weeklyMileageKm: 30,
      runningDaysPerWeek: 3,
      target: 'general_fitness',
      injuryNote: '',
      gender: 'unspecified',
      shoeSize: '',
      legLengthCm: '',
      shoeBrandModel: '',
    },

    avatarInitial: '?',
    displayName: '跑步者',
    levelLabel: LEVEL_LABELS['intermediate'],

    levelOptions: LEVEL_OPTIONS,
    goalOptions: GOAL_OPTIONS,
    genderOptions: GENDER_OPTIONS,
  },

  onLoad() {
    const saved = storage.getProfile()
    if (saved) {
      this.setData({ form: { ...this.data.form, ...saved } })
    }
    this._updateDisplay()
  },

  onInput(e) {
    const { key } = e.currentTarget.dataset
    const form = { ...this.data.form, [key]: e.detail.value }
    this.setData({ form })
    this._updateDisplay()
  },

  onKmChange(e) {
    this.setData({ 'form.weeklyMileageKm': e.detail.value })
  },

  selectLevel(e) {
    const { key } = e.currentTarget.dataset
    this.setData({ 'form.level': key })
    this._updateDisplay()
  },

  selectTarget(e) {
    this.setData({ 'form.target': e.currentTarget.dataset.key })
  },

  selectGender(e) {
    this.setData({ 'form.gender': e.currentTarget.dataset.key })
  },

  decrementDays() {
    const v = Math.max(1, this.data.form.runningDaysPerWeek - 1)
    this.setData({ 'form.runningDaysPerWeek': v })
  },

  incrementDays() {
    const v = Math.min(7, this.data.form.runningDaysPerWeek + 1)
    this.setData({ 'form.runningDaysPerWeek': v })
  },

  _updateDisplay() {
    const f = this.data.form
    const initial = (f.firstName?.[0] || f.lastName?.[0] || '?').toUpperCase()
    const displayName = [f.firstName, f.lastName].filter(Boolean).join(' ') || '跑步者'
    this.setData({
      avatarInitial: initial,
      displayName,
      levelLabel: LEVEL_LABELS[f.level] || f.level,
    })
  },

  saveProfile() {
    storage.saveProfile(this.data.form)
    wx.showToast({ title: t('profileSaved'), icon: 'success' })
  },
})
