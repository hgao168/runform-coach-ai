// app.js
App({
  globalData: {
    profile: null,
    history: [],
    nextWeekPlan: null,
  },

  onLaunch() {
    try {
      const profile = wx.getStorageSync('rf_profile')
      const history = wx.getStorageSync('rf_history')
      const plan = wx.getStorageSync('rf_nextWeekPlan')
      if (profile) this.globalData.profile = profile
      if (history) this.globalData.history = history
      if (plan) this.globalData.nextWeekPlan = plan
    } catch (e) {
      console.error('Storage load error:', e)
    }
  },

  saveProfile(profile) {
    this.globalData.profile = profile
    wx.setStorageSync('rf_profile', profile)
  },

  addHistory(item) {
    const list = this.globalData.history || []
    list.unshift(item)
    const trimmed = list.slice(0, 50)
    this.globalData.history = trimmed
    wx.setStorageSync('rf_history', trimmed)
  },

  saveNextWeekPlan(plan) {
    this.globalData.nextWeekPlan = plan
    wx.setStorageSync('rf_nextWeekPlan', plan)
  },

  getDefaultProfile() {
    return {
      firstName: '',
      lastName: '',
      nickname: '',
      level: 'Beginner',
      weeklyMileageKm: 15,
      runningDaysPerWeek: 3,
      target: 'General Fitness',
      injuryNote: '',
      gender: 'unspecified',
      shoeSize: '',
      legLengthCm: '',
      shoeBrandModel: '',
    }
  },
})
