// pages/invite/invite.js
const { t } = require('../../utils/i18n')
const app = getApp()

Page({
  data: {
    i: {},
    inviteCode: '',
    inviteCount: 0,
    invitedList: [],
    loading: true,
    sharing: false,
  },

  onLoad() {
    this.setData({
      i: {
        inviteTitle: t('inviteTitle'),
        myInviteCode: t('myInviteCode'),
        shareInvite: t('shareInvite'),
        invitedFriends: t('invitedFriends'),
        noInviteesYet: t('noInviteesYet'),
        noInviteesSub: t('noInviteesSub'),
        copyCode: t('copyCode'),
        codeCopied: t('codeCopied'),
        inviteTip: t('inviteTip'),
        inviteReward: t('inviteReward'),
        loading: t('loading'),
      },
    })
    this._loadInviteData()
  },

  onShow() {
    this._loadInviteData()
  },

  _loadInviteData() {
    const inviteData = app.globalData.inviteData || this._generateInviteData()
    this.setData({
      inviteCode: inviteData.code || 'RUNFORM001',
      inviteCount: (inviteData.invited || []).length,
      invitedList: (inviteData.invited || []).map((item, idx) => ({
        ...item,
        displayName: item.nickname || item.name || (t('isZh') ? `好友${idx + 1}` : `Friend ${idx + 1}`),
        avatarText: (item.nickname || item.name || '?')[0].toUpperCase(),
      })),
      loading: false,
    })
  },

  _generateInviteData() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
    let code = ''
    for (let i = 0; i < 8; i++) {
      code += chars[Math.floor(Math.random() * chars.length)]
    }
    return { code, invited: [] }
  },

  copyInviteCode() {
    wx.setClipboardData({
      data: this.data.inviteCode,
      success: () => {
        wx.showToast({ title: t('codeCopied'), icon: 'success' })
      },
    })
  },

  shareInvite() {
    this.setData({ sharing: true })
    // Trigger WeChat share sheet
    wx.showShareMenu({
      withShareTicket: true,
      menus: ['shareAppMessage', 'shareTimeline'],
    })
    this.setData({ sharing: false })
  },

  onShareAppMessage() {
    return {
      title: t('isZh')
        ? `用 RunForm 改善你的跑步姿态！邀请码: ${this.data.inviteCode}`
        : `Improve your running form with RunForm! Invite code: ${this.data.inviteCode}`,
      path: `/pages/analyze/analyze?invite=${this.data.inviteCode}`,
      imageUrl: '',
    }
  },

  onShareTimeline() {
    return {
      title: t('isZh') ? 'RunForm AI 跑步教练 - 免费分析跑步姿态' : 'RunForm AI Running Coach - Free Gait Analysis',
    }
  },
})
