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
const PH = 667   // poster height (→ 1334 physical px at 2x DPR, 9:16 ratio)
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
        posterSlogan: t('posterSlogan'),
        posterSloganSub: t('posterSloganSub'),
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
      const result = await apiGenerateInviteCode({ ios_user_id: userId })
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
      await apiRedeemInviteCode({ code: inviteCode, ios_user_id: userId })
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
    const isZh = t('isZh')

    // ── 1. Background gradient ──
    const bgGrad = ctx.createLinearGradient(0, 0, 0, PH)
    bgGrad.addColorStop(0, '#0a0a0f')
    bgGrad.addColorStop(0.3, '#0f0f18')
    bgGrad.addColorStop(0.55, '#12121f')
    bgGrad.addColorStop(0.75, '#151520')
    bgGrad.addColorStop(1, '#0a0a0f')
    ctx.fillStyle = bgGrad
    ctx.fillRect(0, 0, PW, PH)

    // Top accent stripe
    ctx.fillStyle = '#00f5a0'
    ctx.fillRect(0, 0, PW, 4)

    // ── Decorative: running speed lines (top-right) ──
    ctx.strokeStyle = 'rgba(0,245,160,0.06)'
    ctx.lineWidth = 1
    for (let i = 0; i < 8; i++) {
      const lx = 280 + Math.random() * 80
      ctx.beginPath()
      ctx.moveTo(lx, 20 + i * 10)
      ctx.lineTo(lx - 40 - Math.random() * 60, 20 + i * 10)
      ctx.stroke()
    }

    // ── Decorative: running shoe silhouette (bottom-left) ──
    this._drawRunningShoe(ctx, 30, PH - 90, 60, 'rgba(0,245,160,0.04)')
    this._drawRunningShoe(ctx, PW - 70, 180, 50, 'rgba(0,245,160,0.03)')

    // ── Decorative: subtle dot matrix (scattered) ──
    ctx.fillStyle = 'rgba(0,245,160,0.025)'
    for (let i = 0; i < 45; i++) {
      const dx = 15 + Math.random() * (PW - 30)
      const dy = 100 + Math.random() * (PH - 130)
      ctx.beginPath()
      ctx.arc(dx, dy, 1.5 + Math.random() * 3, 0, Math.PI * 2)
      ctx.fill()
    }

    // ── 2. Header: RunForm branding ──
    // Logo circle with glow
    ctx.shadowColor = 'rgba(0,245,160,0.3)'
    ctx.shadowBlur = 12
    ctx.fillStyle = '#00f5a0'
    ctx.beginPath()
    ctx.arc(PAD + 18, 38, 20, 0, Math.PI * 2)
    ctx.fill()
    ctx.shadowColor = 'transparent'
    ctx.shadowBlur = 0

    // Runner emoji inside logo
    ctx.fillStyle = '#0a0a0f'
    ctx.font = 'bold 13px ' + FONT
    ctx.textAlign = 'center'
    ctx.textBaseline = 'middle'
    ctx.fillText('🏃', PAD + 18, 38)

    // App name
    ctx.textAlign = 'left'
    ctx.fillStyle = '#ffffff'
    ctx.font = 'bold 19px ' + FONT
    ctx.fillText(isZh ? 'RunForm 跑步教练' : 'RunForm Coach AI', PAD + 48, 28)

    ctx.fillStyle = 'rgba(255,255,255,0.4)'
    ctx.font = '12px ' + FONT
    ctx.fillText(isZh ? 'AI 跑步姿态分析 · 邀请你加入' : 'AI Running Form Analysis · Invites you', PAD + 48, 48)

    // ── 3. Anti-injury slogan (prominent) ──
    let y = 90

    // Decorative line above slogan
    ctx.strokeStyle = 'rgba(0,245,160,0.12)'
    ctx.lineWidth = 1
    ctx.beginPath()
    ctx.moveTo(PAD + 10, y)
    ctx.lineTo(PW - PAD - 10, y)
    ctx.stroke()

    y += 22

    // Main slogan — large, white
    ctx.fillStyle = '#ffffff'
    ctx.font = 'bold 24px ' + FONT
    ctx.textAlign = 'center'
    const sloganText = this.data.i.posterSlogan || t('posterSlogan')
    ctx.fillText(sloganText, PW / 2, y)

    y += 34

    // Sub-slogan — green accent
    ctx.fillStyle = '#00f5a0'
    ctx.font = '14px ' + FONT
    const sloganSubText = this.data.i.posterSloganSub || t('posterSloganSub')
    ctx.fillText(sloganSubText, PW / 2, y)

    y += 12

    // Decorative line below slogan
    ctx.strokeStyle = 'rgba(0,245,160,0.12)'
    ctx.lineWidth = 1
    ctx.beginPath()
    ctx.moveTo(PAD + 10, y)
    ctx.lineTo(PW - PAD - 10, y)
    ctx.stroke()

    y += 24

    // ── 4. Invite code (large, prominent) ──
    const codeCardY = y
    const codeCardH = 116

    // Code background card with border glow
    ctx.fillStyle = 'rgba(0,245,160,0.06)'
    ctx.strokeStyle = 'rgba(0,245,160,0.2)'
    ctx.lineWidth = 1
    this._roundRect(ctx, PAD, codeCardY, PW - PAD * 2, codeCardH, 16)
    ctx.fill()
    ctx.stroke()

    // Glow effect around card
    ctx.shadowColor = 'rgba(0,245,160,0.12)'
    ctx.shadowBlur = 24
    ctx.shadowOffsetX = 0
    ctx.shadowOffsetY = 0
    ctx.strokeStyle = 'rgba(0,245,160,0.06)'
    ctx.lineWidth = 3
    this._roundRect(ctx, PAD, codeCardY, PW - PAD * 2, codeCardH, 16)
    ctx.stroke()
    ctx.shadowColor = 'transparent'
    ctx.shadowBlur = 0

    // "INVITE CODE" label
    ctx.fillStyle = 'rgba(0,245,160,0.6)'
    ctx.font = 'bold 10px ' + FONT
    ctx.textAlign = 'center'
    ctx.fillText(isZh ? '邀请码' : 'INVITE CODE', PW / 2, codeCardY + 22)

    // The code itself — large monospace style
    ctx.fillStyle = '#00f5a0'
    ctx.font = 'bold 54px ' + FONT
    ctx.fillText(inviteCode, PW / 2, codeCardY + 78)

    y += codeCardH + 14

    // ── 5. User stats row (if available) ──
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
      ctx.fillText(isZh ? '步频' : 'Cadence', PAD + colW / 2, statsY + 16)

      ctx.fillStyle = '#ffffff'
      ctx.font = 'bold 22px ' + FONT
      ctx.fillText(userCadence > 0 ? `${Math.round(userCadence)} spm` : '--', PAD + colW / 2, statsY + 44)

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
      ctx.fillText(isZh ? '跑姿评分' : 'Form Score', PAD + colW + colW / 2, statsY + 16)

      ctx.fillStyle = '#00f5a0'
      ctx.font = 'bold 22px ' + FONT
      ctx.fillText(userFormScore > 0 ? `${Math.round(userFormScore)}` : '--', PAD + colW + colW / 2, statsY + 44)

      y += statsCardH + 14
    }

    // ── 6. Mini-program QR code area ──
    const qrY = y + 4
    const qrSize = 108
    const qrX = PW / 2 - qrSize / 2

    // QR background (white border)
    ctx.fillStyle = '#ffffff'
    this._roundRect(ctx, qrX - 14, qrY - 14, qrSize + 28, qrSize + 28, 12)
    ctx.fill()

    ctx.fillStyle = '#0a0a0f'
    ctx.fillRect(qrX, qrY, qrSize, qrSize)

    // Draw QR placeholder pattern
    this._drawQRPattern(ctx, qrX, qrY, qrSize)

    // QR label below
    y = qrY + qrSize + 36

    // ── 7. CTA text ──
    ctx.fillStyle = '#ffffff'
    ctx.font = 'bold 16px ' + FONT
    ctx.textAlign = 'center'
    const ctaText = this.data.i.posterJoinCTA || t('posterJoinCTA')
    ctx.fillText(ctaText, PW / 2, y)
    y += 26

    // Secondary CTA
    ctx.fillStyle = 'rgba(255,255,255,0.4)'
    ctx.font = '12px ' + FONT
    ctx.fillText(
      isZh ? `邀请码: ${inviteCode}  ·  微信搜索 RunForm` : `Code: ${inviteCode}  ·  Search RunForm on WeChat`,
      PW / 2, y
    )

    // ── 8. Footer branding ──
    ctx.fillStyle = 'rgba(255,255,255,0.18)'
    ctx.font = '10px ' + FONT
    const poweredText = this.data.i.posterPoweredBy || t('posterPoweredBy')
    ctx.fillText(poweredText, PW / 2, PH - 26)

    // ── 9. Export to temp file ──
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

  // ── Draw running shoe icon (simple silhouette) ──
  _drawRunningShoe(ctx, x, y, size, color) {
    ctx.save()
    ctx.fillStyle = color
    ctx.translate(x, y)
    const s = size / 80  // scale factor

    ctx.beginPath()
    // Sole
    ctx.moveTo(0, 35 * s)
    ctx.lineTo(5 * s, 40 * s)
    ctx.lineTo(60 * s, 40 * s)
    ctx.lineTo(75 * s, 38 * s)
    ctx.lineTo(80 * s, 32 * s)
    // Toe box
    ctx.lineTo(78 * s, 18 * s)
    ctx.lineTo(68 * s, 10 * s)
    ctx.lineTo(50 * s, 8 * s)
    // Heel collar
    ctx.lineTo(35 * s, 8 * s)
    ctx.lineTo(25 * s, 5 * s)
    ctx.lineTo(15 * s, 6 * s)
    ctx.lineTo(8 * s, 12 * s)
    // Ankle opening
    ctx.lineTo(2 * s, 22 * s)
    ctx.lineTo(0, 30 * s)
    ctx.closePath()
    ctx.fill()

    // Swoosh / dynamic stripe
    ctx.fillStyle = color.replace('0.04', '0.08').replace('0.03', '0.06')
    ctx.beginPath()
    ctx.moveTo(12 * s, 25 * s)
    ctx.lineTo(30 * s, 18 * s)
    ctx.lineTo(45 * s, 22 * s)
    ctx.lineTo(40 * s, 28 * s)
    ctx.lineTo(25 * s, 24 * s)
    ctx.lineTo(12 * s, 30 * s)
    ctx.closePath()
    ctx.fill()

    ctx.restore()
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
