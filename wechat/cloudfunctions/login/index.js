// cloudfunctions/login/index.js
// CloudBase 登录云函数 — 获取用户 openid
const cloud = require('wx-server-sdk')
cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV })

exports.main = async (event, context) => {
  const { OPENID, APPID, UNIONID } = cloud.getWXContext()
  return {
    openid: OPENID,
    appid: APPID,
    unionid: UNIONID || null,
  }
}
