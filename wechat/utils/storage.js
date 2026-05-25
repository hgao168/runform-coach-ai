// utils/storage.js

const Storage = {
  _app() {
    return getApp()
  },

  getProfile() {
    const app = this._app()
    if (app && app.globalData && app.globalData.profile) {
      return app.globalData.profile
    }
    // fallback to wx storage
    try {
      return wx.getStorageSync('rf_profile') || {}
    } catch {
      return {}
    }
  },

  saveProfile(profile) {
    try { wx.setStorageSync('rf_profile', profile) } catch { /* ignore */ }
    const app = this._app()
    if (app && app.saveProfile) app.saveProfile(profile)
  },

  getHistory() {
    const app = this._app()
    if (app && app.globalData && app.globalData.history) {
      return app.globalData.history
    }
    try { return wx.getStorageSync('rf_history') || [] } catch { return [] }
  },

  addHistory(item) {
    const app = this._app()
    if (app && app.addHistory) app.addHistory(item)
  },

  getNextWeekPlan() {
    const app = this._app()
    if (app && app.globalData && app.globalData.nextWeekPlan) {
      return app.globalData.nextWeekPlan
    }
    try { return wx.getStorageSync('rf_nextWeekPlan') || null } catch { return null }
  },

  saveNextWeekPlan(plan) {
    try { wx.setStorageSync('rf_nextWeekPlan', plan) } catch { /* ignore */ }
    const app = this._app()
    if (app && app.saveNextWeekPlan) app.saveNextWeekPlan(plan)
  },

  clearAll() {
    const app = this._app()
    if (app && app.globalData) {
      app.globalData.profile = null
      app.globalData.history = []
      app.globalData.nextWeekPlan = null
    }
    wx.removeStorageSync('rf_profile')
    wx.removeStorageSync('rf_history')
    wx.removeStorageSync('rf_nextWeekPlan')
  },
}

module.exports = Storage
