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
   */
  onShareAppMessage() {
    const { confidencePct, overallAssessment, analysisId } = this.data
    const lang = isZh

    // Build share title from analysis summary
    let title = lang
      ? `RunForm 跑步姿态分析 — ${confidencePct}%`
      : `RunForm Run Analysis — ${confidencePct}%`

    if (overallAssessment) {
      const short = overallAssessment.length > 40
        ? overallAssessment.slice(0, 40) + '...'
        : overallAssessment
      title = lang
        ? `🏃 RunForm分析: ${short}`
        : `🏃 RunForm: ${short}`
    }

    const path = `/pages/result/result?analysis_id=${encodeURIComponent(analysisId)}`

    return {
      title,
      path,
      imageUrl: '', // Uses default screenshot
    }
  },

  // ──────────── RF-304: Canvas share image (optional) ────────────

  /**
   * Generate a share image using Canvas.
   * Call this before sharing to attach a custom image.
   */
  generateShareImage() {
    const { confidencePct, overallAssessment, metrics } = this.data
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
        const w = 300
        const h = 400
        canvas.width = w * dpr
        canvas.height = h * dpr
        ctx.scale(dpr, dpr)

        // Background
        ctx.fillStyle = '#0a0a0f'
        ctx.fillRect(0, 0, w, h)

        // Card background
        ctx.fillStyle = 'rgba(0,245,160,0.1)'
        ctx.beginPath()
        ctx.roundRect(16, 16, w - 32, h - 32, 16)
        ctx.fill()

        // Title
        ctx.fillStyle = '#ffffff'
        ctx.font = 'bold 20px -apple-system, sans-serif'
        ctx.fillText('RunForm Coach AI', 32, 56)

        // Score
        ctx.fillStyle = '#00f5a0'
        ctx.font = 'bold 64px -apple-system, sans-serif'
        ctx.fillText(`${confidencePct}%`, 32, 140)

        // Summary
        ctx.fillStyle = 'rgba(255,255,255,0.8)'
        ctx.font = '14px -apple-system, sans-serif'
        const lines = this._wrapText(ctx, overallAssessment, w - 64)
        lines.forEach((line, i) => {
          ctx.fillText(line, 32, 176 + i * 22)
        })

        // Metrics
        let y = 176 + lines.length * 22 + 24
        ctx.fillStyle = 'rgba(255,255,255,0.5)'
        ctx.font = '12px -apple-system, sans-serif'
        metrics.slice(0, 4).forEach((m) => {
          ctx.fillText(`${m.label}: ${m.valueText}`, 32, y)
          y += 20
        })

        // Footer
        ctx.fillStyle = 'rgba(255,255,255,0.3)'
        ctx.font = '10px -apple-system, sans-serif'
        ctx.fillText('Powered by RunForm Coach AI', 32, h - 24)

        // Export
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

