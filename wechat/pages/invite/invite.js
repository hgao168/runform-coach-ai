// pages/invite/invite.js
// RF-600: 邀请码分享海报生成 (Invite code share poster)
// C3: 接通真实后端邀请码 API
const { t } = require('../../utils/i18n')
const {
  getInviteStatus,
  getInviteCode,
  generateInviteCode: apiGenerateInviteCode,
  redeemInviteCode: apiRedeemInviteCode,
  getUserId,
} = require('../../utils/api')
const app = getApp()

// Canvas 2D poster layout constants
const PW = 375   // poster width (logical px)
const PH = 600   // poster height
const DPR = 2    // device pixel ratio for sharp rendering
const PAD = 24   // horizontal padding
const FONT = '-apple-system, "PingFang SC", sans-serif'

Page({
  data: {
    i: {},
    inviteCode: '',
    inviteCount: 0,
    invitedList: [],
    loading: true,
    sharing: false,
    // Poster state
    showPosterPreview: false,
    posterPath: '',
    posterGenerating: false,
    // User stats for poster
    userCadence: 0,
    userFormScore: 0,
  },

  onLoad(options) {
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
        generatePoster: t('generatePoster'),
        previewPoster: t('previewPoster'),
        savePoster: t('savePoster'),
        sharePoster: t('sharePoster'),
        posterSaved: t('posterSaved'),
        posterGenerating: t('posterGenerating'),
        posterGenFailed: t('posterGenFailed'),
        posterJoinCTA: t('posterJoinCTA'),
        posterPoweredBy: t('posterPoweredBy'),
      },
    })

    // C3: If user entered via a shared invite link, redeem the code.
    const inviteParam = options && (options.invite || options.inviteCode || '')
    if (inviteParam) {
      this._redeemInviteCode(inviteParam)
    }

    this._loadInviteData()
  },

  onShow() {
    this._loadInviteData()
  },

  // C3: 接通真实邀请码 API — 加载邀请数据
  async _loadInviteData() {
    const userId = getUserId()
    let inviteCode = ''
    let inviteCount = 0
    let invitedList = []

    // Try loading from backend API
    try {
      const status = await getInviteStatus(userId)
      // Backend returns: { codes: [...], invited_users: [...] } or similar
      if (status) {
        // Use first active code if available
        if (status.codes && status.codes.length > 0) {
          inviteCode = status.codes[0].code || status.codes[0]
          // Persist code to local storage for next load
          try {
            wx.setStorageSync('inviteCode', inviteCode)
          } catch (_) { /* ignore */ }
        }
        // Map invited users
        if (status.invited_users && status.invited_users.length > 0) {
          inviteCount = status.invited_users.length
          invitedList = status.invited_users.map((item, idx) => ({
            ...item,
            displayName: item.nickname || item.name || (t('isZh') ? `好友${idx + 1}` : `Friend ${idx + 1}`),
            avatarText: (item.nickname || item.name || '?')[0].toUpperCase(),
          }))
        }
      }
    } catch (err) {
      console.warn('[Invite] API failed, falling back to local data:', err.message)
      // C3: 降级到本地状态
      wx.showToast({ title: t('isZh') ? '网络异常，使用本地数据' : 'Network error, using local data', icon: 'none' })
    }

    // Fallback: if no API data, use local storage or generate mock
    if (!inviteCode) {
      const savedCode = ''
      try {
        const sc = wx.getStorageSync('inviteCode') || ''
        inviteCode = sc
      } catch (_) { /* ignore */ }
      if (!inviteCode) {
        // Generate locally only if absolutely no code
        const localData = this._getLocalFallbackCode()
        inviteCode = localData.code
      }
    }

    // Validate saved invite code against backend if we have one
    if (inviteCode && !invitedList.length) {
      try {
        const validation = await getInviteCode(inviteCode)
        if (validation) {
          // Code is valid; update from validation response if available
          if (validation.invited_users) {
            inviteCount = validation.invited_users.length
            invitedList = validation.invited_users.map((item, idx) => ({
              ...item,
              displayName: item.nickname || item.name || (t('isZh') ? `好友${idx + 1}` : `Friend ${idx + 1}`),
              avatarText: (item.nickname || item.name || '?')[0].toUpperCase(),
            }))
          }
        }
      } catch (err) {
        // Code validation failed — may be expired, keep using it anyway as fallback
        console.warn('[Invite] Code validation failed:', err.message)
      }
    }

    // Get user stats from globalData or storage for poster
    const profile = app.globalData.profile || {}
    const latestResult = (app.globalData.history && app.globalData.history.length > 0)
      ? app.globalData.history[0] : null

    this.setData({
      inviteCode: inviteCode || 'RUNFORM001',
      inviteCount,
      invitedList,
      loading: false,
      userCadence: (latestResult && latestResult.metrics && latestResult.metrics.cadence) || 0,
      userFormScore: (latestResult && latestResult.confidence) || (profile && profile.bestScore) || 0,
    })
  },

  // C3: 调用 POST /api/v1/invite/generate 生成邀请码
  async _generateInviteData() {
    const userId = getUserId()
    try {
      const result = await apiGenerateInviteCode({ user_id: userId })
      if (result && result.code) {
        // Persist code to local storage
        try {
          wx.setStorageSync('inviteCode', result.code)
        } catch (_) { /* ignore */ }
        return { code: result.code, invited: result.invited_users || [] }
      }
    } catch (err) {
      console.warn('[Invite] Generate code API failed, using local fallback:', err.message)
      wx.showToast({ title: t('isZh') ? '生成邀请码失败' : 'Failed to generate invite code', icon: 'none' })
    }
    // C3: 降级到本地生成
    return this._getLocalFallbackCode()
  },

  // C3: 本地降级邀请码生成（仅当 API 不可用时）
  _getLocalFallbackCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
    let code = ''
    for (let i = 0; i < 8; i++) {
      code += chars[Math.floor(Math.random() * chars.length)]
    }
    try {
      wx.setStorageSync('inviteCode', code)
    } catch (_) { /* ignore */ }
    return { code, invited: [] }
  },

  // C3: 当好友通过分享链接进入时，调用 POST /api/v1/invite/redeem
  async _redeemInviteCode(inviteCode) {
    if (!inviteCode) return
    const userId = getUserId()
    try {
      await apiRedeemInviteCode({ code: inviteCode, user_id: userId })
      console.log('[Invite] Code redeemed successfully:', inviteCode)
      wx.showToast({ title: t('isZh') ? '邀请码已使用！' : 'Invite code redeemed!', icon: 'success' })
    } catch (err) {
      console.warn('[Invite] Redeem failed:', err.message)
      // Don't block user — redeem may fail if already redeemed or network issue
    }
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
    wx.showShareMenu({
      withShareTicket: true,
      menus: ['shareAppMessage', 'shareTimeline'],
    })
    this.setData({ sharing: false })
  },

  // ─── RF-600: Generate invite poster ───
  generatePoster() {
    if (this.data.posterGenerating) return
    this.setData({ posterGenerating: true })

    // Use setTimeout to let UI update before heavy canvas work
    setTimeout(() => this._drawPoster(), 150)
  },

  _drawPoster() {
    const query = wx.createSelectorQuery().in(this)
    query.select('#posterCanvas')
      .fields({ node: true, size: true })
      .exec((res) => {
        if (!res || !res[0] || !res[0].node) {
          console.warn('[Invite] Poster canvas node not found — retrying once')
          setTimeout(() => {
            const q2 = wx.createSelectorQuery().in(this)
            q2.select('#posterCanvas')
              .fields({ node: true, size: true })
              .exec((r2) => {
                if (!r2 || !r2[0] || !r2[0].node) {
                  this.setData({ posterGenerating: false })
                  wx.showToast({ title: t('posterGenFailed'), icon: 'none' })
                  return
                }
                this._renderPosterOnCanvas(r2[0].node)
              })
          }, 300)
          return
        }
        this._renderPosterOnCanvas(res[0].node)
      })
  },

  _renderPosterOnCanvas(canvasNode) {
    const canvas = canvasNode
    const ctx = canvas.getContext('2d')

    canvas.width = PW * DPR
    canvas.height = PH * DPR
    ctx.scale(DPR, DPR)

    const { inviteCode, userCadence, userFormScore } = this.data

    // ── 1. Background gradient ──
    const bgGrad = ctx.createLinearGradient(0, 0, 0, PH)
    bgGrad.addColorStop(0, '#0a0a0f')
    bgGrad.addColorStop(0.4, '#12121a')
    bgGrad.addColorStop(0.7, '#151520')
    bgGrad.addColorStop(1, '#0a0a0f')
    ctx.fillStyle = bgGrad
    ctx.fillRect(0, 0, PW, PH)

    // Top accent stripe
    ctx.fillStyle = '#00f5a0'
    ctx.fillRect(0, 0, PW, 4)

    // Subtle decorative dots pattern (bottom-right)
    ctx.fillStyle = 'rgba(0,245,160,0.03)'
    for (let i = 0; i < 30; i++) {
      const dx = 200 + Math.random() * 175
      const dy = 400 + Math.random() * 200
      ctx.beginPath()
      ctx.arc(dx, dy, 2 + Math.random() * 4, 0, Math.PI * 2)
      ctx.fill()
    }

    // ── 2. Header: RunForm branding ──
    // Logo circle
    ctx.fillStyle = '#00f5a0'
    ctx.beginPath()
    ctx.arc(PAD + 16, 36, 18, 0, Math.PI * 2)
    ctx.fill()

    ctx.fillStyle = '#0a0a0f'
    ctx.font = 'bold 11px ' + FONT
    ctx.textAlign = 'center'
    ctx.textBaseline = 'middle'
    ctx.fillText('🏃', PAD + 16, 36)

    // App name
    ctx.textAlign = 'left'
    ctx.fillStyle = '#ffffff'
    ctx.font = 'bold 18px ' + FONT
    ctx.fillText(t('isZh') ? 'RunForm 跑步教练' : 'RunForm Coach AI', PAD + 44, 28)

    ctx.fillStyle = 'rgba(255,255,255,0.4)'
    ctx.font = '11px ' + FONT
    ctx.fillText(t('isZh') ? '邀请你加入' : 'Invites you to join', PAD + 44, 48)

    // ── 3. Invite code (large, prominent) ──
    let y = 90
    const codeCardY = y
    const codeCardH = 110

    // Code background card with border glow
    ctx.fillStyle = 'rgba(0,245,160,0.06)'
    ctx.strokeStyle = 'rgba(0,245,160,0.2)'
    ctx.lineWidth = 1
    this._roundRect(ctx, PAD, codeCardY, PW - PAD * 2, codeCardH, 16)
    ctx.fill()
    ctx.stroke()

    // Glow effect around card
    ctx.shadowColor = 'rgba(0,245,160,0.15)'
    ctx.shadowBlur = 20
    ctx.shadowOffsetX = 0
    ctx.shadowOffsetY = 0
    ctx.strokeStyle = 'rgba(0,245,160,0.08)'
    ctx.lineWidth = 3
    this._roundRect(ctx, PAD, codeCardY, PW - PAD * 2, codeCardH, 16)
    ctx.stroke()
    ctx.shadowColor = 'transparent'
    ctx.shadowBlur = 0

    // "INVITE CODE" label
    ctx.fillStyle = 'rgba(0,245,160,0.6)'
    ctx.font = 'bold 10px ' + FONT
    ctx.textAlign = 'center'
    ctx.fillText(t('isZh') ? '邀请码' : 'INVITE CODE', PW / 2, codeCardY + 24)

    // The code itself — large monospace
    ctx.fillStyle = '#00f5a0'
    ctx.font = 'bold 52px ' + FONT
    ctx.fillText(inviteCode, PW / 2, codeCardY + 74)

    y += codeCardH + 16

    // ── 4. User stats row (if available) ──
    if (userCadence > 0 || userFormScore > 0) {
      const statsY = y
      const statsCardH = 64

      ctx.fillStyle = 'rgba(255,255,255,0.03)'
      ctx.strokeStyle = 'rgba(255,255,255,0.06)'
      ctx.lineWidth = 1
      this._roundRect(ctx, PAD, statsY, PW - PAD * 2, statsCardH, 12)
      ctx.fill()
      ctx.stroke()

      const colW = (PW - PAD * 2) / 2

      // Cadence
      ctx.fillStyle = 'rgba(255,255,255,0.4)'
      ctx.font = '10px ' + FONT
      ctx.textAlign = 'center'
      ctx.fillText(t('isZh') ? '步频' : 'Cadence', PAD + colW / 2, statsY + 16)

      ctx.fillStyle = '#ffffff'
      ctx.font = 'bold 22px ' + FONT
      ctx.fillText(userCadence > 0 ? `${Math.round(userCadence)} spm` : '--', PAD + colW / 2, statsY + 42)

      // Divider line
      ctx.strokeStyle = 'rgba(255,255,255,0.1)'
      ctx.lineWidth = 1
      ctx.beginPath()
      ctx.moveTo(PAD + colW, statsY + 14)
      ctx.lineTo(PAD + colW, statsY + 54)
      ctx.stroke()

      // Form score
      ctx.fillStyle = 'rgba(255,255,255,0.4)'
      ctx.font = '10px ' + FONT
      ctx.fillText(t('isZh') ? '跑姿评分' : 'Form Score', PAD + colW + colW / 2, statsY + 16)

      ctx.fillStyle = '#00f5a0'
      ctx.font = 'bold 22px ' + FONT
      ctx.fillText(userFormScore > 0 ? `${Math.round(userFormScore)}` : '--', PAD + colW + colW / 2, statsY + 42)

      y += statsCardH + 16
    }

    // ── 5. Mini-program QR code (placeholder) ──
    const qrY = y
    const qrSize = 100
    const qrX = PW / 2 - qrSize / 2

    ctx.fillStyle = '#ffffff'
    ctx.fillRect(qrX - 12, qrY - 12, qrSize + 24, qrSize + 24)
    ctx.fillStyle = '#0a0a0f'
    ctx.fillRect(qrX, qrY, qrSize, qrSize)

    // Draw QR placeholder pattern
    this._drawQRPattern(ctx, qrX, qrY, qrSize)

    y += qrSize + 36

    // ── 6. CTA text ──
    ctx.fillStyle = '#ffffff'
    ctx.font = 'bold 16px ' + FONT
    ctx.textAlign = 'center'
    const ctaText = t('posterJoinCTA')
    ctx.fillText(ctaText, PW / 2, y)
    y += 28

    // Secondary CTA
    ctx.fillStyle = 'rgba(255,255,255,0.4)'
    ctx.font = '12px ' + FONT
    ctx.fillText(
      t('isZh') ? `邀请码: ${inviteCode}  · 微信搜索 RunForm` : `Code: ${inviteCode}  ·  Search RunForm on WeChat`,
      PW / 2, y
    )

    // ── 7. Footer branding ──
    ctx.fillStyle = 'rgba(255,255,255,0.2)'
    ctx.font = '10px ' + FONT
    ctx.fillText(t('posterPoweredBy'), PW / 2, PH - 24)

    // ── 8. Export to temp file ──
    const that = this
    wx.canvasToTempFilePath({
      canvas,
      x: 0,
      y: 0,
      width: PW * DPR,
      height: PH * DPR,
      destWidth: PW * DPR,
      destHeight: PH * DPR,
      fileType: 'png',
      quality: 1,
      success(res) {
        that.setData({
          posterPath: res.tempFilePath,
          showPosterPreview: true,
          posterGenerating: false,
        })
      },
      fail() {
        that.setData({ posterGenerating: false })
        wx.showToast({ title: t('posterGenFailed'), icon: 'none' })
      },
    })
  },

  // ── QR placeholder pattern ──
  _drawQRPattern(ctx, x, y, size) {
    const cols = 7
    const rows = 7
    const cell = Math.floor(size / (cols + 1))
    const ox = x + Math.floor((size - cell * cols) / 2)
    const oy = y + Math.floor((size - cell * rows) / 2)
    ctx.fillStyle = '#00f5a0'
    for (let r = 0; r < rows; r++) {
      for (let c = 0; c < cols; c++) {
        // Skip corners (positioning marks)
        if ((c < 2 && r < 2) || (c < 2 && r >= rows - 2) || (c >= cols - 2 && r < 2)) continue
        if ((r + c * 2 + r * c) % 3 !== 0) {
          ctx.fillRect(ox + c * cell, oy + r * cell, cell, cell)
        }
      }
    }
    // Center dot
    ctx.fillStyle = '#00f5a0'
    ctx.beginPath()
    ctx.arc(x + size / 2, y + size / 2, cell * 1.3, 0, Math.PI * 2)
    ctx.fill()
  },

  // ── Round rect helper ──
  _roundRect(ctx, x, y, w, h, r) {
    ctx.beginPath()
    ctx.moveTo(x + r, y)
    ctx.lineTo(x + w - r, y)
    ctx.arcTo(x + w, y, x + w, y + r, r)
    ctx.lineTo(x + w, y + h - r)
    ctx.arcTo(x + w, y + h, x + w - r, y + h, r)
    ctx.lineTo(x + r, y + h)
    ctx.arcTo(x, y + h, x, y + h - r, r)
    ctx.lineTo(x, y + r)
    ctx.arcTo(x, y, x + r, y, r)
    ctx.closePath()
  },

  // ── Close poster preview ──
  closePosterPreview() {
    this.setData({ showPosterPreview: false })
  },

  // ── Save poster to album ──
  savePoster() {
    if (!this.data.posterPath) {
      wx.showToast({ title: t('posterGenFailed'), icon: 'none' })
      return
    }
    wx.saveImageToPhotosAlbum({
      filePath: this.data.posterPath,
      success: () => {
        wx.showToast({ title: t('posterSaved'), icon: 'success' })
      },
      fail: (err) => {
        if (err.errMsg && err.errMsg.includes('auth deny')) {
          wx.showModal({
            title: t('albumPermTitle') || '需要相册权限',
            content: t('albumPermDesc') || '请在设置中开启相册权限',
            confirmText: t('albumPermGoSettings') || '去设置',
            success: (modalRes) => {
              if (modalRes.confirm) {
                wx.openSetting()
              }
            },
          })
        } else {
          wx.showToast({ title: t('saveFailed') || '保存失败', icon: 'none' })
        }
      },
    })
  },

  // ── Share poster via file message ──
  sharePosterFile() {
    if (!this.data.posterPath) {
      wx.showToast({ title: t('posterGenFailed'), icon: 'none' })
      return
    }
    // WeChat mini programs don't have direct shareFileMessage API,
    // but we can use shareAppMessage to share with an image.
    // For direct image share, we trigger the share sheet with poster image.
    wx.showShareMenu({
      withShareTicket: true,
      menus: ['shareAppMessage'],
    })
    this.setData({ sharingPoster: true })
  },

  // ── onShareAppMessage override for poster ──
  onShareAppMessage() {
    if (this.data.sharingPoster) {
      this.setData({ sharingPoster: false })
      return {
        title: t('isZh')
          ? `RunForm AI 跑步教练 - 邀请码 ${this.data.inviteCode}`
          : `RunForm AI Coach - invite code ${this.data.inviteCode}`,
        path: `/pages/analyze/analyze?invite=${this.data.inviteCode}`,
        imageUrl: this.data.posterPath || '',
      }
    }
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
