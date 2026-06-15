// utils/voice-coach.js
// RF-305: Voice feedback via pre-recorded audio + wx.createInnerAudioContext
//
// WeChat mini-programs do NOT support system TTS (e.g. AVSpeechSynthesizer on iOS).
// This module provides an equivalent: it plays pre-recorded mp3 audio prompts
// generated from prompts.json using tools/generate-voice-prompts.py.
//
// Audio file convention:
//   /assets/audio/{lang}/{key}.mp3   e.g. /assets/audio/zh/cadence_low.mp3
//
// Usage:
//   const voiceCoach = require('../../utils/voice-coach')
//   voiceCoach.playPrompt('cadence_low')
//   voiceCoach.playMetricsFeedback(metrics)
//   voiceCoach.stopPrompt()
//   voiceCoach.dispose()

let _currentContext = null   // wx.InnerAudioContext instance
let _currentLang = 'zh'      // 'zh' | 'en'
let _playQueue = []          // Queue of { key, lang } to play sequentially
let _isPlaying = false
let _muted = false
let _enabled = true          // Global enable/disable toggle
let _playbackState = 'stopped'  // 'stopped' | 'playing' | 'paused'
let _onStateChange = null    // External state callback

// ──────────── Metric thresholds for anomaly detection ────────────

const THRESHOLDS = {
  cadence:       { low: 160, high: 190, unit: 'spm' },
  stride_length: { low: 0.8, high: 1.3, unit: 'm' },       // meters
  vertical_oscillation: { low: 0.04, high: 0.10, unit: 'm' }, // meters
  ground_contact_time: { low: 180, high: 300, unit: 'ms' },
}

// Map metric name patterns to prompt keys
function detectAnomalies(metrics) {
  const results = []

  // Normalize metrics: accept either object of { label, pct } or raw key-value pairs
  const raw = {}
  if (Array.isArray(metrics)) {
    metrics.forEach((m) => {
      raw[m.label] = typeof m.pct === 'number' ? m.pct : m.value
    })
  } else if (typeof metrics === 'object') {
    Object.assign(raw, metrics)
  }

  const find = (candidates) => {
    for (const k of candidates) {
      if (raw[k] !== undefined) return raw[k]
    }
    return undefined
  }

  // Cadence
  const cadenceVal = find(['cadence', '步频', 'cadence '])
  if (cadenceVal !== undefined) {
    if (cadenceVal < 40) {
      results.push('cadence_low')
    } else if (cadenceVal > 85) {
      results.push('cadence_high')
    }
  }

  // Stride length
  const strideVal = find(['stride length', 'stride_length', '步幅', 'stride'])
  if (strideVal !== undefined) {
    if (strideVal < 40) {
      results.push('stride_short')
    } else if (strideVal > 85) {
      results.push('stride_long')
    }
  }

  // Vertical oscillation
  const oscVal = find(['vertical oscillation', 'vertical_oscillation', '垂直振幅', 'oscillation'])
  if (oscVal !== undefined) {
    if (oscVal > 75) {
      results.push('oscillation_high')
    } else if (oscVal < 25) {
      results.push('oscillation_low')
    }
  }

  // Ground contact time
  const gctVal = find(['ground contact time', 'ground_contact_time', '触地时间', 'gct', 'contact'])
  if (gctVal !== undefined) {
    if (gctVal > 75) {
      results.push('gct_long')
    } else if (gctVal < 25) {
      results.push('gct_short')
    }
  }

  // Knee lift
  const kneeVal = find(['knee lift', 'knee_lift', '膝盖抬起', 'knee'])
  if (kneeVal !== undefined && kneeVal < 35) {
    results.push('knee_lift_low')
  }

  // Arm swing
  const armVal = find(['arm swing', 'arm_swing', '摆臂', 'arm'])
  if (armVal !== undefined && armVal < 35) {
    results.push('arm_swing_narrow')
  }

  // Trunk lean
  const trunkVal = find(['trunk lean', 'trunk_lean', '躯干倾斜', 'trunk'])
  if (trunkVal !== undefined) {
    if (trunkVal > 80) {
      results.push('trunk_lean_forward')
    } else if (trunkVal < 25) {
      results.push('trunk_lean_backward')
    }
  }

  // Foot strike
  const footVal = find(['foot strike', 'foot_strike', '着地方式', 'foot strike '])
  if (footVal !== undefined && footVal < 35) {
    results.push('foot_strike_heel')
  }

  // Hip drop
  const hipVal = find(['hip drop', 'hip_drop', '髋部', 'hip'])
  if (hipVal !== undefined && hipVal < 35) {
    results.push('hip_drop')
  }

  // Shoulder tension
  const shoulderVal = find(['shoulder', 'shoulder_tension', '肩部', 'shoulders'])
  if (shoulderVal !== undefined && shoulderVal < 35) {
    results.push('shoulder_tension')
  }

  // If nothing detected, add general prompts
  if (results.length === 0) {
    results.push('general_good')
  }

  return results
}

// ──────────── Audio context management ────────────

function _createContext() {
  if (_currentContext) {
    try { _currentContext.destroy() } catch (_) { /* ignore */ }
  }
  _currentContext = wx.createInnerAudioContext()
  _currentContext.obeyMuteSwitch = false  // Play even when device is in silent mode

  _currentContext.onPlay(() => {
    _playbackState = 'playing'
    _notifyState()
  })

  _currentContext.onPause(() => {
    _playbackState = 'paused'
    _notifyState()
  })

  _currentContext.onStop(() => {
    _playbackState = 'stopped'
    _notifyState()
  })

  _currentContext.onEnded(() => {
    _playbackState = 'stopped'
    _isPlaying = false
    _notifyState()
    _playNext()
  })

  _currentContext.onError((err) => {
    console.error('[voice-coach] Audio error:', err.errCode, err.errMsg)
    _playbackState = 'stopped'
    _isPlaying = false
    _notifyState()
    _playNext()
  })

  return _currentContext
}

function _getContext() {
  if (!_currentContext) {
    _createContext()
  }
  return _currentContext
}

function _notifyState() {
  if (typeof _onStateChange === 'function') {
    _onStateChange({
      state: _playbackState,
      muted: _muted,
      enabled: _enabled,
      queueLength: _playQueue.length,
    })
  }
}

function _playNext() {
  if (_playQueue.length === 0) {
    _isPlaying = false
    _notifyState()
    return
  }

  const next = _playQueue.shift()
  const ctx = _getContext()
  const lang = next.lang || _currentLang
  const src = `/assets/audio/${lang}/${next.key}.mp3`

  ctx.src = src
  _isPlaying = true

  try {
    ctx.play()
  } catch (e) {
    console.error('[voice-coach] Play failed:', e)
    _isPlaying = false
    _notifyState()
    _playNext()
  }
}

// ──────────── Public API ────────────

/**
 * Play a single voice prompt by key.
 * @param {string} key - Prompt key from prompts.json (e.g. 'cadence_low')
 * @param {string} [lang] - 'zh' or 'en', defaults to current language
 */
function playPrompt(key, lang) {
  if (!_enabled || _muted) return
  if (!key) return

  _playQueue.push({ key, lang: lang || _currentLang })

  if (!_isPlaying) {
    _playNext()
  }
}

/**
 * Analyze metrics and queue relevant voice prompts.
 * @param {Array|Object} metrics - Array of {label, pct} or key-value object
 */
function playMetricsFeedback(metrics) {
  if (!_enabled || _muted) return
  if (!metrics) return

  const anomalies = detectAnomalies(metrics)

  // Add welcome + coaching complete as bookends
  if (anomalies.length > 0) {
    _playQueue.push({ key: 'welcome_result', lang: _currentLang })
  }

  anomalies.forEach((key) => {
    _playQueue.push({ key, lang: _currentLang })
  })

  if (anomalies.length > 0) {
    _playQueue.push({ key: 'coaching_complete', lang: _currentLang })
  }

  if (!_isPlaying) {
    _playNext()
  }
}

/**
 * Stop current playback and clear the queue.
 */
function stopPrompt() {
  _playQueue = []
  try {
    if (_currentContext) {
      _currentContext.stop()
    }
  } catch (_) { /* ignore */ }
  _isPlaying = false
  _playbackState = 'stopped'
  _notifyState()
}

/**
 * Pause current playback.
 */
function pausePrompt() {
  try {
    if (_currentContext) {
      _currentContext.pause()
    }
  } catch (_) { /* ignore */ }
}

/**
 * Resume paused playback.
 */
function resumePrompt() {
  try {
    if (_currentContext) {
      _currentContext.play()
    }
  } catch (_) { /* ignore */ }
}

/**
 * Set language for subsequent prompts.
 * @param {string} lang - 'zh' | 'en'
 */
function setLang(lang) {
  _currentLang = lang === 'en' ? 'en' : 'zh'
}

/**
 * Get current language.
 */
function getLang() {
  return _currentLang
}

/**
 * Mute/unmute voice coach.
 * @param {boolean} muted
 */
function setMuted(muted) {
  _muted = !!muted
  if (_muted) {
    stopPrompt()
  }
  _notifyState()
}

/**
 * Check if muted.
 */
function isMuted() {
  return _muted
}

/**
 * Enable/disable the voice coach globally.
 * @param {boolean} enabled
 */
function setEnabled(enabled) {
  _enabled = !!enabled
  if (!_enabled) {
    stopPrompt()
  }
  _notifyState()
}

/**
 * Check if enabled.
 */
function isEnabled() {
  return _enabled
}

/**
 * Get current playback state.
 * @returns {{ state: string, muted: boolean, enabled: boolean, queueLength: number }}
 */
function getState() {
  return {
    state: _playbackState,
    muted: _muted,
    enabled: _enabled,
    queueLength: _playQueue.length,
  }
}

/**
 * Register a callback for state changes.
 * @param {function} callback - Receives { state, muted, enabled, queueLength }
 */
function onStateChange(callback) {
  _onStateChange = callback
}

/**
 * Dispose the audio context. Call when page is unloaded.
 */
function dispose() {
  stopPrompt()
  try {
    if (_currentContext) {
      _currentContext.destroy()
    }
  } catch (_) { /* ignore */ }
  _currentContext = null
  _onStateChange = null
  _isPlaying = false
  _playQueue = []
}

module.exports = {
  playPrompt,
  playMetricsFeedback,
  stopPrompt,
  pausePrompt,
  resumePrompt,
  setLang,
  getLang,
  setMuted,
  isMuted,
  setEnabled,
  isEnabled,
  getState,
  onStateChange,
  detectAnomalies,
  dispose,
}
