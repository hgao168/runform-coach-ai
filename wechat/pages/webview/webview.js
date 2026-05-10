// pages/webview/webview.js
Page({
  data: {
    url: '',
  },

  onLoad(query) {
    // Expect ?url=<encoded URL> passed via navigateTo
    const url = decodeURIComponent(query.url || '')
    if (!url) {
      wx.showToast({ title: '无效链接', icon: 'error' })
      return
    }
    this.setData({ url })
    wx.setNavigationBarTitle({ title: query.title || '网页' })
  },

  onMessage() {
    // Handle postMessage from embedded page if needed
  },

  onError() {
    wx.showToast({ title: '页面加载失败', icon: 'error' })
  },
})
