// pages/result/result.js
const api = require('../../utils/api')
const { t, isZh, backendLang, getVideoSearchUrl } = require('../../utils/i18n')
const voiceCoach = require('../../utils/voice-coach')

const STORAGE_KEY_PENDING_FEEDBACK = 'rf_pendingFeedback'

Page({
  data: {
    i: {
      confidence: t('confidence'),
      metrics: t('metrics'),
      strengthFocus: t('strengthFocus'),
      noIssues: t('noIssues'),
      compareWithElite: t('compareWithElite'),
      tutorialCopied: t('tutorialCopied'),
      shareResult: t('shareResult'),
      feedbackTitle: t('feedbackTitle'),
      feedbackSubtitle: t('feedbackSubtitle'),
      feedbackPlaceholder: t('feedbackPlaceholder'),
      feedbackSubmit: t('feedbackSubmit'),
      feedbackSubmitted: t('feedbackSubmitted'),
      feedbackSavedOffline: t('feedbackSavedOffline'),
    },

    confidenceDisplay: '–',
    confidencePct: 0,
    scoreColor: '#00f5a0',
    overallAssessment: '',
    metrics: [],
    insights: [],
    exercises: [],

    rawResult: null,

    // RF-302: Feedback
    feedbackRating: 0,         // 0-5 star rating, 0 = no selection
    feedbackComment: '',
    feedbackSubmitted: false,
    feedbackSubmitting: false,
    feedbackSavedOffline: false,
    analysisId: '',            // ID from result for feedback target

    // RF-305: Voice coach state
    voiceEnabled: true,
    voiceMuted: false,
    voiceState: 'stopped',     // 'stopped' | 'playing' | 'paused'
    voiceQueueLength: 0,
    voiceCoachLabels: {
      title: t('voiceCoach'),
      play: t('voiceCoachPlay'),
      stop: t('voiceCoachStop'),
      mute: t('voiceCoachMute'),
      unmute: t('voiceCoachUnmute'),
      enable: t('voiceCoachEnable'),
      disabled: t('voiceCoachDisabled'),
      playing: t('voiceCoachPlaying'),
      paused: t('voiceCoachPaused'),
      stopped: t('voiceCoachStopped'),
      noAudio: t('voiceCoachNoAudio'),
    },
  },

  onLoad() {
    const result = wx.getStorageSync('rf_pendingResult')
    if (!result) {
      wx.showToast({ title: '无结果数据', icon: 'error' })
      return
    }
    this._parseResult(result)

    // Try to sync any pending offline feedback
    this._syncPendingFeedback()

    // RF-305: Initialize voice coach
    this._initVoiceCoach()
  },

  onShow() {
    // Re-check pending feedback sync when page comes to foreground
    this._syncPendingFeedback()

    // Re-sync voice coach state
    this._syncVoiceState()
  },

  onUnload() {
    // RF-305: Clean up voice coach
    voiceCoach.stopPrompt()
    voiceCoach.onStateChange(null)
  },

  _parseResult(r) {
    const raw = r

    // Confidence / overall score
    const conf = r.confidence_score ?? r.overall_score ?? 0
    const confPct = Math.round(conf * 100)
    let scoreColor = '#00f5a0'
    if (confPct < 40) scoreColor = '#ff4757'
    else if (confPct < 65) scoreColor = '#ff9f30'

    const overallAssessment = r.overall_assessment || r.summary || ''
    const analysisId = r.id || r.analysis_id || ''

    // Form metrics — normalise various backend field shapes
    const metricNames = r.form_metrics || r.metrics || {}
    const metrics = Object.entries(metricNames).map(([key, val]) => {
      const numVal = typeof val === 'number' ? val : (val?.score ?? 0)
      const pct = Math.round(Math.min(Math.max(numVal, 0), 1) * 100)
      let color = '#00f5a0'
      if (pct < 40) color = '#ff4757'
      else if (pct < 65) color = '#ff9f30'
      return {
        label: key.replace(/_/g, ' '),
        pct,
        valueText: `${pct}%`,
        color,
      }
    })

    // Issues / insights
    const issues = r.issues || r.insights || []
    const insights = issues.map((iss) => {
      const sev = (iss.severity || 'low').toLowerCase()
      let color = '#00f5a0'
      let severityText = '轻'
      if (sev === 'high' || sev === 'critical') { color = '#ff4757'; severityText = '高' }
      else if (sev === 'medium') { color = '#ff9f30'; severityText = '中' }
      return {
        title: iss.title || iss.name || '',
        description: iss.description || iss.detail || '',
        color,
        severityText,
      }
    })

    // Exercises
    const exercises = (r.strength_focus || r.exercises || []).map((ex) => ({
      name: ex.name || ex.exercise_name || '',
      description: ex.description || ex.detail || '',
      sets: ex.sets,
      reps: ex.reps,
      duration: ex.duration,
      frequency_per_week: ex.frequency_per_week,
      searchUrl: getVideoSearchUrl(ex.name || ex.exercise_name || ''),
    }))

    // Check if feedback was already submitted for this analysis
    const submittedKey = `rf_feedback_done_${analysisId}`
    let alreadySubmitted = false
    try {
      alreadySubmitted = !!wx.getStorageSync(submittedKey)
    } catch (e) { /* ignore */ }

    this.setData({
      rawResult: raw,
      confidenceDisplay: `${confPct}%`,
      confidencePct: confPct,
      scoreColor,
      overallAssessment,
      metrics,
      insights,
      exercises,
      analysisId,
      feedbackSubmitted: alreadySubmitted,
    })
  },

  // ──────────── RF-302: Feedback ────────────

  onStarTap(e) {
    if (this.data.feedbackSubmitted || this.data.feedbackSubmitting) return
    const rating = e.currentTarget.dataset.star
    this.setData({ feedbackRating: rating, feedbackSavedOffline: false })
  },

  onFeedbackCommentInput(e) {
    this.setData({ feedbackComment: e.detail.value })
  },

  submitFeedback() {
    const { feedbackRating, feedbackComment, analysisId, feedbackSubmitting, feedbackSubmitted } = this.data
    if (feedbackSubmitted || feedbackSubmitting) return
    if (feedbackRating === 0) {
      wx.showToast({ title: isZh ? '请先选择评分' : 'Please select a rating', icon: 'none' })
      return
    }

    const feedback = {
      analysis_id: analysisId,
      rating: feedbackRating,
      comment: feedbackComment.trim() || undefined,
    }

    this.setData({ feedbackSubmitting: true })

    api.submitFeedback(feedback)
      .then(() => {
        this.setData({
          feedbackSubmitted: true,
          feedbackSubmitting: false,
          feedbackSavedOffline: false,
        })
        // Mark as done for this analysis
        if (analysisId) {
          wx.setStorageSync(`rf_feedback_done_${analysisId}`, true)
        }
        wx.showToast({ title: this.data.i.feedbackSubmitted, icon: 'success' })
      })
      .catch(() => {
        // RF-302: Offline fallback — store pending feedback locally
        this._savePendingFeedback(feedback)
        this.setData({
          feedbackSubmitting: false,
          feedbackSavedOffline: true,
        })
        wx.showToast({ title: this.data.i.feedbackSavedOffline, icon: 'none', duration: 2500 })
      })
  },

  _savePendingFeedback(feedback) {
    try {
      let pending = []
      const stored = wx.getStorageSync(STORAGE_KEY_PENDING_FEEDBACK)
      if (stored) pending = stored
      // Avoid duplicates for same analysis
      pending = pending.filter((f) => f.analysis_id !== feedback.analysis_id)
      pending.push({ ...feedback, savedAt: Date.now() })
      wx.setStorageSync(STORAGE_KEY_PENDING_FEEDBACK, pending)
    } catch (e) {
      console.error('Failed to save pending feedback:', e)
    }
  },

  _syncPendingFeedback() {
    try {
      const pending = wx.getStorageSync(STORAGE_KEY_PENDING_FEEDBACK)
      if (!pending || pending.length === 0) return

      // Sync one at a time to avoid overwhelming the API
      const item = pending[0]
      api.submitFeedback(item)
        .then(() => {
          // Remove synced item
          const remaining = pending.slice(1)
          wx.setStorageSync(STORAGE_KEY_PENDING_FEEDBACK, remaining)
          // Mark as done
          if (item.analysis_id) {
            wx.setStorageSync(`rf_feedback_done_${item.analysis_id}`, true)
          }
          // Continue syncing
          this._syncPendingFeedback()
        })
        .catch(() => {
          // Will retry on next onShow
        })
    } catch (e) {
      console.error('Failed to sync pending feedback:', e)
    }
  },

  // ──────────── Original handlers ────────────

  openExercise(e) {
    const idx = e.currentTarget.dataset.index
    const ex = this.data.exercises[idx]
    if (!ex) return
    const url = ex.searchUrl
    wx.setClipboardData({
      data: url,
      success: () => {
        wx.showToast({ title: this.data.i.tutorialCopied, icon: 'none', duration: 2500 })
      },
    })
  },

  goCompare() {
    wx.navigateTo({ url: '/pages/compare/compare' })
  },

  // ──────────── RF-304: Share ────────────

  shareResult() {
    // Trigger the system share sheet via onShareAppMessage
    // WeChat mini-program: when button is tapped, system looks for
    // onShareAppMessage on the Page. We use the open-type="share" on button
    // in WXML instead of this handler for proper behavior.
    // This handler is kept as a fallback.
    wx.showToast({ title: isZh ? '请点击右上角分享' : 'Tap top-right to share', icon: 'none', duration: 2000 })
  },

  /**
   * WeChat custom share card.
   * Called when user taps the share button (open-type="share") or
   * the native share menu in the top-right corner.
   *
   * RF-941: Dynamic share title with form metrics.
   * Template: "我步频 X SPM，跑姿评分 X 分，来测测你的？"
   */
  onShareAppMessage() {
    const { confidencePct, overallAssessment, analysisId, metrics } = this.data
    const lang = isZh

    // RF-941: Build dynamic share title based on available metrics
    const cadenceMetric = metrics.find((m) =>
      m.label.toLowerCase().includes('cadence') || m.label.includes('步频')
    )
    const cadence = cadenceMetric ? cadenceMetric.pct : null
    const score = confidencePct

    // Determine share scenario for template selection
    const scenario = this._detectShareScenario()

    let title = ''
    if (lang) {
      // Chinese — three scenario templates
      switch (scenario) {
        case 'analysis':
          title = cadence
            ? `🏃 我步频 ${cadence} SPM，跑姿评分 ${score} 分，来测测你的？`
            : `🏃 我的跑姿评分 ${score} 分，AI 分析了我的跑步姿态，来测测你的？`
          break
        case 'weekly':
          title = cadence
            ? `📊 本周跑姿数据：步频 ${cadence} SPM，综合 ${score} 分。你的数据如何？`
            : `📊 本周跑姿报告：综合评分 ${score} 分。来看看你的数据？`
          break
        case 'kipchoge':
          title = cadence
            ? `⚡ 我的步频 ${cadence} SPM，Kipchoge 是 180 SPM。来对比你的跑姿？`
            : `⚡ 我的跑姿 vs Kipchoge：评分 ${score} 分。你也来对比一下？`
          break
        default:
          title = cadence
            ? `🏃 RunForm：步频 ${cadence} SPM，跑姿评分 ${score} 分`
            : `🏃 RunForm 跑步姿态分析 — ${score}%`
      }
    } else {
      // English — three scenario templates
      switch (scenario) {
        case 'analysis':
          title = cadence
            ? `🏃 My cadence: ${cadence} SPM, form score: ${score}%. Test yours?`
            : `🏃 My running form scored ${score}% — AI analyzed my gait. Test yours?`
          break
        case 'weekly':
          title = cadence
            ? `📊 Weekly run report: cadence ${cadence} SPM, overall ${score}%. How's yours?`
            : `📊 Weekly running report: overall score ${score}%. See your data?`
          break
        case 'kipchoge':
          title = cadence
            ? `⚡ My cadence ${cadence} SPM vs Kipchoge 180 SPM. Compare yours?`
            : `⚡ My form vs Kipchoge: scored ${score}%. Compare your run?`
          break
        default:
          title = cadence
            ? `🏃 RunForm: cadence ${cadence} SPM, form score ${score}%`
            : `🏃 RunForm Run Analysis — ${score}%`
      }
    }

    const path = `/pages/result/result?analysis_id=${encodeURIComponent(analysisId)}`

    // RF-941: Use custom share image if available, else default
    const imageUrl = this._shareImagePath || ''

    return {
      title,
      path,
      imageUrl,
    }
  },

  /**
   * RF-941: Detect the share scenario to pick the right template.
   * - 'analysis':  just completed an analysis (confidence > 0)
   * - 'weekly':    viewing historical / weekly report
   * - 'kipchoge':  coming from compare page (Kipchoge comparison)
   */
  _detectShareScenario() {
    // Check if user came from compare page (Kipchoge scenario)
    const pages = getCurrentPages()
    if (pages.length >= 2) {
      const prevRoute = pages[pages.length - 2].route || ''
      if (prevRoute.includes('compare')) {
        return 'kipchoge'
      }
    }

    // Check if this is a weekly report (analysisId suggests historical)
    const { analysisId } = this.data
    if (analysisId && analysisId.startsWith('weekly_')) {
      return 'weekly'
    }

    // Default: fresh analysis
    return 'analysis'
  },

  // ──────────── RF-941: Enhanced Canvas share image ────────────

  /**
   * Generate a share image using Canvas.
   * RF-941: Enhanced version with avatar, key metrics, and mini-program QR code placeholder.
   * Call this before sharing to attach a custom image.
   */
  generateShareImage() {
    const { confidencePct, overallAssessment, metrics, insights } = this.data
    const query = wx.createSelectorQuery()
    query.select('#shareCanvas')
      .fields({ node: true, size: true })
      .exec((res) => {
        if (!res || !res[0] || !res[0].node) {
          wx.showToast({ title: 'Canvas not available', icon: 'none' })
          return
        }
        const canvas = res[0].node
        const ctx = canvas.getContext('2d')
        const dpr = wx.getSystemInfoSync().pixelRatio
        const w = 375  // Standard share card width
        const h = 500  // Taller for more content
        canvas.width = w * dpr
        canvas.height = h * dpr
        ctx.scale(dpr, dpr)

        // ── Background ──
        // Dark gradient background
        const bgGrad = ctx.createLinearGradient(0, 0, 0, h)
        bgGrad.addColorStop(0, '#0a0a0f')
        bgGrad.addColorStop(0.5, '#12121a')
        bgGrad.addColorStop(1, '#0a0a0f')
        ctx.fillStyle = bgGrad
        ctx.fillRect(0, 0, w, h)

        // Accent band at top
        ctx.fillStyle = '#00f5a0'
        ctx.fillRect(0, 0, w, 4)

        let y = 32

        // ── Avatar placeholder (circle) + app name ──
        ctx.fillStyle = '#00f5a0'
        ctx.beginPath()
        ctx.arc(32, y + 18, 16, 0, Math.PI * 2)
        ctx.fill()

        ctx.fillStyle = '#0a0a0f'
        ctx.font = 'bold 10px -apple-system, sans-serif'
        ctx.textAlign = 'center'
        ctx.fillText('🏃', 32, y + 22)

        ctx.textAlign = 'left'
        ctx.fillStyle = '#ffffff'
        ctx.font = 'bold 16px -apple-system, sans-serif'
        ctx.fillText(isZh ? 'RunForm 跑步教练' : 'RunForm Coach AI', 56, y + 14)

        ctx.fillStyle = 'rgba(255,255,255,0.4)'
        ctx.font = '11px -apple-system, sans-serif'
        ctx.fillText(isZh ? 'AI 跑姿分析' : 'AI Run Analysis', 56, y + 32)

        y += 58

        // ── Divider ──
        ctx.strokeStyle = 'rgba(255,255,255,0.08)'
        ctx.lineWidth = 1
        ctx.beginPath()
        ctx.moveTo(24, y)
        ctx.lineTo(w - 24, y)
        ctx.stroke()

        y += 20

        // ── Score card ──
        // Score background
        ctx.fillStyle = 'rgba(0,245,160,0.08)'
        ctx.beginPath()
        ctx.roundRect(24, y, w - 48, 100, 12)
        ctx.fill()

        // Score number
        ctx.fillStyle = '#00f5a0'
        ctx.font = 'bold 56px -apple-system, sans-serif'
        ctx.textAlign = 'center'
        ctx.fillText(`${confidencePct}`, w / 2, y + 56)

        ctx.fillStyle = 'rgba(255,255,255,0.6)'
        ctx.font = '13px -apple-system, sans-serif'
        ctx.fillText(isZh ? '跑姿评分' : 'FORM SCORE', w / 2, y + 82)

        y += 120

        // ── Key metrics in a row ──
        const keyMetrics = metrics.slice(0, 4)
        if (keyMetrics.length > 0) {
          ctx.textAlign = 'left'
          const colW = (w - 48) / Math.min(keyMetrics.length, 4)
          keyMetrics.forEach((m, i) => {
            const cx = 24 + i * colW + colW / 2
            const pct = m.pct

            // Small circle progress
            const radius = 16
            // Background circle
            ctx.beginPath()
            ctx.arc(cx, y + 20, radius, 0, Math.PI * 2)
            ctx.strokeStyle = 'rgba(255,255,255,0.1)'
            ctx.lineWidth = 3
            ctx.stroke()

            // Progress arc
            ctx.beginPath()
            const startAngle = -Math.PI / 2
            const endAngle = startAngle + (Math.PI * 2 * pct) / 100
            ctx.arc(cx, y + 20, radius, startAngle, endAngle)
            ctx.strokeStyle = m.color || '#00f5a0'
            ctx.lineWidth = 3
            ctx.stroke()

            // Label
            ctx.fillStyle = 'rgba(255,255,255,0.7)'
            ctx.font = '10px -apple-system, sans-serif'
            ctx.textAlign = 'center'
            const shortLabel = m.label.length > 8 ? m.label.slice(0, 7) + '…' : m.label
            ctx.fillText(shortLabel, cx, y + 52)

            // Value
            ctx.fillStyle = '#ffffff'
            ctx.font = 'bold 12px -apple-system, sans-serif'
            ctx.fillText(m.valueText, cx, y + 68)
          })
          y += 82
        }

        // ── Top insight ──
        if (insights && insights.length > 0) {
          const topInsight = insights[0]
          ctx.textAlign = 'left'
          ctx.fillStyle = 'rgba(255,255,255,0.4)'
          ctx.font = '11px -apple-system, sans-serif'
          ctx.fillText(isZh ? '关键发现' : 'KEY FINDING', 24, y + 14)

          ctx.fillStyle = '#ffffff'
          ctx.font = '13px -apple-system, sans-serif'
          const insightText = topInsight.title.length > 36
            ? topInsight.title.slice(0, 36) + '...'
            : topInsight.title
          ctx.fillText(insightText, 24, y + 34)
          y += 50
        } else if (overallAssessment) {
          ctx.textAlign = 'left'
          ctx.fillStyle = 'rgba(255,255,255,0.4)'
          ctx.font = '11px -apple-system, sans-serif'
          ctx.fillText(isZh ? '综合评估' : 'ASSESSMENT', 24, y + 14)

          ctx.fillStyle = '#ffffff'
          ctx.font = '13px -apple-system, sans-serif'
          const short = overallAssessment.length > 40
            ? overallAssessment.slice(0, 40) + '...'
            : overallAssessment
          ctx.fillText(short, 24, y + 34)
          y += 50
        }

        // ── Divider ──
        ctx.strokeStyle = 'rgba(255,255,255,0.08)'
        ctx.beginPath()
        ctx.moveTo(24, y)
        ctx.lineTo(w - 24, y)
        ctx.stroke()
        y += 16

        // ── Footer: CTA + QR code placeholder ──
        ctx.textAlign = 'left'
        ctx.fillStyle = 'rgba(255,255,255,0.6)'
        ctx.font = '12px -apple-system, sans-serif'
        ctx.fillText(isZh ? '扫码测测你的跑姿 →' : 'Scan to analyze your form →', 24, y + 14)

        // Mini-program QR code placeholder (right side)
        ctx.textAlign = 'right'
        ctx.fillStyle = 'rgba(0,245,160,0.15)'
        ctx.fillRect(w - 56, y - 4, 40, 40)
        ctx.fillStyle = 'rgba(0,245,160,0.5)'
        ctx.font = '10px -apple-system, sans-serif'
        ctx.fillText('QR', w - 36, y + 20)

        y += 56

        // ── Bottom branding ──
        ctx.textAlign = 'center'
        ctx.fillStyle = 'rgba(255,255,255,0.2)'
        ctx.font = '9px -apple-system, sans-serif'
        ctx.fillText(
          isZh ? 'Powered by RunForm · movenova.ai' : 'Powered by RunForm · movenova.ai',
          w / 2,
          y + 10
        )

        // ── Export ──
        wx.canvasToTempFilePath({
          canvas,
          success: (tempRes) => {
            this._shareImagePath = tempRes.tempFilePath
            wx.showToast({ title: isZh ? '分享图已生成' : 'Share image ready', icon: 'success' })
          },
          fail: (err) => {
            console.error('Canvas export failed:', err)
          },
        })
      })
  },

  // ──────────── RF-305: Voice Coach ────────────

  /**
   * Initialize voice coach: set language, register state callback,
   * then auto-play metrics feedback.
   */
  _initVoiceCoach() {
    // Set language based on system locale
    voiceCoach.setLang(isZh ? 'zh' : 'en')

    // Register state change callback
    voiceCoach.onStateChange((state) => {
      this.setData({
        voiceState: state.state,
        voiceMuted: state.muted,
        voiceEnabled: state.enabled,
        voiceQueueLength: state.queueLength,
      })
    })

    // Restore persisted mute preference
    try {
      const muted = wx.getStorageSync('rf_voiceCoachMuted')
      if (muted === true) {
        voiceCoach.setMuted(true)
      }
    } catch (_) { /* ignore */ }

    this._syncVoiceState()

    // Auto-play feedback based on parsed metrics
    const { metrics, insights } = this.data
    if (metrics && metrics.length > 0) {
      // Delay slightly so page transition finishes
      setTimeout(() => {
        voiceCoach.playMetricsFeedback(metrics)
      }, 800)
    }
  },

  /**
   * Sync voice coach state from module into page data.
   */
  _syncVoiceState() {
    const state = voiceCoach.getState()
    this.setData({
      voiceState: state.state,
      voiceMuted: state.muted,
      voiceEnabled: state.enabled,
      voiceQueueLength: state.queueLength,
    })
  },

  /**
   * Toggle play/pause/restart voice coaching.
   */
  onVoiceCoachToggle() {
    const { voiceState } = this.data
    if (voiceState === 'playing') {
      voiceCoach.pausePrompt()
    } else if (voiceState === 'paused') {
      voiceCoach.resumePrompt()
    } else {
      // Stopped or idle — replay metrics feedback
      const { metrics } = this.data
      voiceCoach.playMetricsFeedback(metrics)
    }
  },

  /**
   * Stop voice coaching and clear queue.
   */
  onVoiceCoachStop() {
    voiceCoach.stopPrompt()
  },

  /**
   * Toggle mute.
   */
  onVoiceCoachMuteToggle() {
    const muted = !voiceCoach.isMuted()
    voiceCoach.setMuted(muted)
    // Persist preference
    try {
      wx.setStorageSync('rf_voiceCoachMuted', muted)
    } catch (_) { /* ignore */ }
  },

  /**
   * Enable/disable voice coach entirely.
   */
  onVoiceCoachEnableToggle() {
    const enabled = !voiceCoach.isEnabled()
    voiceCoach.setEnabled(enabled)
  },

  _wrapText(ctx, text, maxWidth) {
    if (!text) return []
    // Simple character-based wrapping for CJK text
    const chars = text.split('')
    const lines = []
    let current = ''
    for (const ch of chars) {
      const test = current + ch
      if (ctx.measureText(test).width > maxWidth) {
        lines.push(current)
        current = ch
      } else {
        current = test
      }
    }
    if (current) lines.push(current)
    return lines.slice(0, 4) // Max 4 lines
  },
})

