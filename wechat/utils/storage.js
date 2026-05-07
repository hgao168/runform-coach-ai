// utils/storage.js
const app = getApp()

const Storage = {
  getProfile() {
    return app.globalData.profile || app.getDefaultProfile()
  },

  saveProfile(profile) {
    app.saveProfile(profile)
  },

  getHistory() {
    return app.globalData.history || []
  },

  addHistory(item) {
    app.addHistory(item)
  },

  getNextWeekPlan() {
    return app.globalData.nextWeekPlan || null
  },

  saveNextWeekPlan(plan) {
    app.saveNextWeekPlan(plan)
  },

  clearAll() {
    app.globalData.profile = null
    app.globalData.history = []
    app.globalData.nextWeekPlan = null
    wx.removeStorageSync('rf_profile')
    wx.removeStorageSync('rf_history')
    wx.removeStorageSync('rf_nextWeekPlan')
  },
}

module.exports = Storage
