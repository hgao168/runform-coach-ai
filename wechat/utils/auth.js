// utils/auth.js
// WeChat-native auth helpers. Login identifies the user via CloudBase openid;
// profile fields such as nickname/avatar are collected separately by explicit UI.

const AUTH_KEY = 'rf_auth'
const LEGACY_USER_ID_KEY = 'userId'

function _app() {
  try { return getApp() } catch (_) { return null }
}

function _setGlobalAuth(auth) {
  const app = _app()
  if (!app || !app.globalData) return
  app.globalData.auth = auth || null
  if (auth && auth.userId) {
    app.globalData.userId = auth.userId
  }
}

function _buildUserId(auth) {
  if (auth && auth.unionid) return `wx_union_${auth.unionid}`
  if (auth && auth.openid) return `wx_${auth.openid}`
  return ''
}

function getAuth() {
  const app = _app()
  if (app && app.globalData && app.globalData.auth) {
    return app.globalData.auth
  }
  try {
    const auth = wx.getStorageSync(AUTH_KEY) || null
    if (auth) _setGlobalAuth(auth)
    return auth
  } catch (_) {
    return null
  }
}

function saveAuth(auth) {
  if (!auth) return null
  const normalized = {
    ...auth,
    provider: auth.provider || 'wechat',
    userId: auth.userId || _buildUserId(auth),
    loggedInAt: auth.loggedInAt || new Date().toISOString(),
  }
  try {
    wx.setStorageSync(AUTH_KEY, normalized)
    if (normalized.userId) {
      wx.setStorageSync(LEGACY_USER_ID_KEY, normalized.userId)
    }
  } catch (_) { /* ignore */ }
  _setGlobalAuth(normalized)
  return normalized
}

function clearAuth() {
  try {
    wx.removeStorageSync(AUTH_KEY)
    wx.removeStorageSync(LEGACY_USER_ID_KEY)
  } catch (_) { /* ignore */ }
  _setGlobalAuth(null)
}

function isLoggedIn() {
  const auth = getAuth()
  return !!(auth && auth.provider === 'wechat' && auth.openid)
}

function maskOpenId(openid) {
  if (!openid) return ''
  if (openid.length <= 10) return openid
  return `${openid.slice(0, 6)}...${openid.slice(-4)}`
}

function loginWithWeChat(forceRefresh) {
  return new Promise((resolve, reject) => {
    const cached = getAuth()
    if (!forceRefresh && cached && cached.openid) {
      resolve(cached)
      return
    }

    if (!wx.cloud || !wx.cloud.callFunction) {
      reject(new Error('wechat_cloud_unavailable'))
      return
    }

    wx.cloud.callFunction({
      name: 'login',
      data: {},
      success(res) {
        const result = (res && res.result) || {}
        if (!result.openid) {
          reject(new Error('wechat_openid_missing'))
          return
        }
        resolve(saveAuth({
          provider: 'wechat',
          openid: result.openid,
          appid: result.appid || '',
          unionid: result.unionid || '',
          userId: _buildUserId(result),
          loggedInAt: new Date().toISOString(),
        }))
      },
      fail(err) {
        reject(new Error((err && err.errMsg) || 'wechat_login_failed'))
      },
    })
  })
}

module.exports = {
  AUTH_KEY,
  getAuth,
  saveAuth,
  clearAuth,
  isLoggedIn,
  maskOpenId,
  loginWithWeChat,
}
