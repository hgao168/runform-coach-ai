// pages/profile/profile.js
const storage = require('../../utils/storage')
const auth = require('../../utils/auth')
const api = require('../../utils/api')
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
      nickname: t('nickname'),
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
      authTitle: t('authTitle'),
      authSubtitle: t('authSubtitle'),
      authLoggedIn: t('authLoggedIn'),
      authNotLoggedIn: t('authNotLoggedIn'),
      useWechatLogin: t('useWechatLogin'),
      wechatLoginSuccess: t('wechatLoginSuccess'),
      wechatLoginFailed: t('wechatLoginFailed'),
      chooseAvatar: t('chooseAvatar'),
      linkedAccount: t('linkedAccount'),
    },

    form: {
      firstName: '',
      lastName: '',
      nickname: '',
      level: 'intermediate',
      weeklyMileageKm: 30,
      runningDaysPerWeek: 3,
      target: 'general_fitness',
      injuryNote: '',
      gender: 'unspecified',
      shoeSize: '',
      legLengthCm: '',
      shoeBrandModel: '',
      avatarUrl: '',
      wechatOpenId: '',
      wechatUnionId: '',
      isWechatRegistered: false,
    },

    avatarInitial: '?',
    displayName: '跑步者',
    levelLabel: LEVEL_LABELS['intermediate'],
    isZh,
    authLoggedIn: false,
    authLoading: false,
    maskedOpenId: '',

    levelOptions: LEVEL_OPTIONS,
    goalOptions: GOAL_OPTIONS,
    genderOptions: GENDER_OPTIONS,
  },

  onLoad() {
    const saved = storage.getProfile()
    if (saved) {
      this.setData({ form: { ...this.data.form, ...saved } })
    }
    this._syncAuthState()
    this._updateDisplay()
  },

  onShow() {
    this._syncAuthState()
  },

  onInput(e) {
    const { key } = e.currentTarget.dataset
    const form = { ...this.data.form, [key]: e.detail.value }
    this.setData({ form })
    this._updateDisplay()
  },

  onChooseAvatar(e) {
    const avatarUrl = e.detail && e.detail.avatarUrl
    if (!avatarUrl) return
    this.setData({ 'form.avatarUrl': avatarUrl })
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
    const initial = (f.nickname?.[0] || f.firstName?.[0] || f.lastName?.[0] || '?').toUpperCase()
    const displayName = f.nickname || [f.firstName, f.lastName].filter(Boolean).join(' ') || '跑步者'
    this.setData({
      avatarInitial: initial,
      displayName,
      levelLabel: LEVEL_LABELS[f.level] || f.level,
    })
  },

  _syncAuthState() {
    const currentAuth = auth.getAuth()
    this.setData({
      authLoggedIn: !!(currentAuth && currentAuth.openid),
      maskedOpenId: currentAuth && currentAuth.openid ? auth.maskOpenId(currentAuth.openid) : '',
    })
  },

  useWechatLogin() {
    if (this.data.authLoading) return
    this.setData({ authLoading: true })

    auth.loginWithWeChat(true)
      .then((wechatAuth) => {
        const form = {
          ...this.data.form,
          wechatOpenId: wechatAuth.openid || '',
          wechatUnionId: wechatAuth.unionid || '',
          isWechatRegistered: true,
        }
        this.setData({
          form,
          authLoggedIn: true,
          authLoading: false,
          maskedOpenId: auth.maskOpenId(wechatAuth.openid),
        })
        storage.saveProfile(form)
        this._syncProfileToBackend(form, wechatAuth.userId)
        wx.showToast({ title: t('wechatLoginSuccess'), icon: 'success' })
      })
      .catch((err) => {
        console.error('[profile] WeChat login failed:', err)
        this.setData({ authLoading: false })
        wx.showModal({
          title: t('error'),
          content: t('wechatLoginFailed'),
          showCancel: false,
        })
      })
  },

  saveProfile() {
    const currentAuth = auth.getAuth()
    const form = {
      ...this.data.form,
      wechatOpenId: currentAuth?.openid || this.data.form.wechatOpenId || '',
      wechatUnionId: currentAuth?.unionid || this.data.form.wechatUnionId || '',
      isWechatRegistered: !!(currentAuth?.openid || this.data.form.wechatOpenId),
    }
    this.setData({ form })
    storage.saveProfile(form)
    this._syncProfileToBackend(form, currentAuth?.userId)
    wx.showToast({ title: t('profileSaved'), icon: 'success' })
  },

  _syncProfileToBackend(form, userId) {
    api.saveProfile(form, userId)
      .catch((err) => {
        console.warn('[profile] Backend profile sync failed:', err.message)
      })
  },

  // RF-604: Navigate to UGC submissions
  goUgc() {
    wx.navigateTo({ url: '/pages/ugc/ugc' })
  },
})
