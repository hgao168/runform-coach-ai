// utils/api.js
const { BASE_URL } = require('./config')

/**
 * JSON request helper.
 */
function request(method, path, data) {
  return new Promise((resolve, reject) => {
    wx.request({
      url: `${BASE_URL}${path}`,
      method,
      data: data || undefined,
      header: { 'Content-Type': 'application/json' },
      timeout: 60000,
      success(res) {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve(res.data)
        } else {
          const detail = (res.data && res.data.detail) || `HTTP ${res.statusCode}`
          reject(new Error(detail))
        }
      },
      fail(err) {
        reject(new Error(err.errMsg || '网络请求失败'))
      },
    })
  })
}

/**
 * Upload video file to /analyze endpoint using multipart form.
 * WeChat mini programs use wx.uploadFile for multipart uploads.
 * @param {string} filePath - temp file path from wx.chooseMedia
 * @param {string} language - 'zh-Hans' | 'en'
 * @param {object} [profile] - optional profile context for analysis
 * @param {function} [onProgress] - progress callback (percent: number)
 */
function analyzeVideo(filePath, language, profile, onProgress) {
  let profileContext = ''
  if (profile) {
    profileContext = JSON.stringify({
      gender: profile.gender || 'unspecified',
      shoe_size: profile.shoeSize || '',
      leg_length_cm: profile.legLengthCm || '',
      shoe_brand_model: profile.shoeBrandModel || '',
      weekly_mileage_km: profile.weeklyMileageKm || '',
      running_days_per_week: profile.runningDaysPerWeek || '',
      injury_note: profile.injuryNote || '',
    })
  }

  return new Promise((resolve, reject) => {
    const task = wx.uploadFile({
      url: `${BASE_URL}/analyze`,
      filePath,
      name: 'video',
      formData: {
        language: language || 'zh-Hans',
        profile_context: profileContext,
        camera_angle: (profile && profile.cameraAngle) || 'side',
      },
      timeout: 120000,
      success(res) {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          try {
            resolve(JSON.parse(res.data))
          } catch {
            reject(new Error('服务器返回格式错误'))
          }
        } else {
          let detail = `HTTP ${res.statusCode}`
          try {
            const parsed = JSON.parse(res.data)
            detail = parsed.detail || detail
          } catch { /* ignore */ }
          reject(new Error(detail))
        }
      },
      fail(err) {
        reject(new Error(err.errMsg || '上传失败'))
      },
    })
    if (onProgress && task && task.onProgressUpdate) {
      task.onProgressUpdate(({ progress }) => onProgress(progress))
    }
  })
}

/**
 * Generate a weekly training plan.
 * @param {object} input - TrainingPlanInput schema
 */
function generatePlan(input) {
  return request('POST', '/training-plan', input)
}

/**
 * Fetch list of elite athletes.
 */
function fetchAthletes() {
  return request('GET', '/athletes')
}

/**
 * Compare user metrics with an elite athlete.
 * Note: requires pose metrics from on-device analysis (iOS only path).
 * WeChat uses this with estimated metrics from analysis scores.
 * @param {string} athleteId
 * @param {object} userMetrics - PoseMetricsInput schema
 * @param {string} language
 */
function compareWithAthlete(athleteId, userMetrics, language) {
  return request('POST', '/api/v1/compare', {
    athlete_id: athleteId,
    user_metrics: userMetrics,
    language: language || 'zh-Hans',
  })
}

/**
 * Health check.
 */
function health() {
  return request('GET', '/health')
}

/**
 * Submit user feedback for an analysis result.
 * @param {object} feedback - { analysis_id, rating, comment }
 */
function submitFeedback(feedback) {
  return request('POST', '/feedback', feedback)
}

/**
 * Fetch weekly training insight report.
 * RF-1010: GET /api/v1/weekly-insight
 * Returns comparison, trend, ai_advice, badges.
 */
function getWeeklyInsight() {
  return request('GET', '/api/v1/weekly-insight')
}

// ─── Invite Code APIs ───

/**
 * Get user's invite status: existing codes and invited users list.
 * GET /api/v1/invite/status?user_id=X
 */
function getInviteStatus(userId) {
  return request('GET', `/api/v1/invite/status?user_id=${encodeURIComponent(userId)}`)
}

/**
 * Validate an invite code.
 * GET /api/v1/invite/{code}
 */
function getInviteCode(code) {
  return request('GET', `/api/v1/invite/${encodeURIComponent(code)}`)
}

/**
 * Generate a new invite code for a user.
 * POST /api/v1/invite/generate
 */
function generateInviteCode(data) {
  return request('POST', '/api/v1/invite/generate', data)
}

/**
 * Redeem an invite code (friend joins via invite).
 * POST /api/v1/invite/redeem
 */
function redeemInviteCode(data) {
  return request('POST', '/api/v1/invite/redeem', data)
}

// ─── Challenge APIs ───

/**
 * Fetch available challenges list.
 * GET /api/v1/challenges
 */
function getChallenges() {
  return request('GET', '/api/v1/challenges')
}

/**
 * Join a challenge.
 * POST /api/v1/challenges/{challenge_id}/join
 */
function joinChallenge(challengeId, data) {
  return request('POST', `/api/v1/challenges/${encodeURIComponent(challengeId)}/join`, data)
}

/**
 * Get a challenge's leaderboard.
 * GET /api/v1/challenges/{challenge_id}/leaderboard
 */
function getLeaderboard(challengeId) {
  return request('GET', `/api/v1/challenges/${encodeURIComponent(challengeId)}/leaderboard`)
}

/**
 * Daily check-in for a challenge.
 * POST /api/v1/challenges/{challenge_id}/check-in
 */
function checkInChallenge(challengeId, data) {
  return request('POST', `/api/v1/challenges/${encodeURIComponent(challengeId)}/check-in`, data)
}

// ─── Coach APIs (RF-602) ───

/**
 * Generate a coach code for the current user.
 * POST /api/v1/coach/generate-code
 * @param {string} userId
 */
function generateCoachCode(userId) {
  return request('POST', '/api/v1/coach/generate-code', { user_id: userId })
}

/**
 * Student joins a coach via code.
 * POST /api/v1/coach/join
 * @param {string} studentId
 * @param {string} coachCode
 */
function joinCoach(studentId, coachCode) {
  return request('POST', '/api/v1/coach/join', { student_id: studentId, coach_code: coachCode })
}

/**
 * Get students list for a coach.
 * GET /api/v1/coach/students?coach_id=X
 * @param {string} coachId
 */
function getCoachStudents(coachId) {
  return request('GET', `/api/v1/coach/students?coach_id=${encodeURIComponent(coachId)}`)
}

/**
 * Get coach dashboard summary.
 * GET /api/v1/coach/dashboard?coach_id=X
 * @param {string} coachId
 */
function getCoachDashboard(coachId) {
  return request('GET', `/api/v1/coach/dashboard?coach_id=${encodeURIComponent(coachId)}`)
}

// ─── Shared helpers ───

/**
 * Get or create a persistent user_id for API calls.
 * Checks globalData first, then storage. Generates a UUID if neither exists.
 */
function getUserId() {
  const app = getApp()
  if (app && app.globalData && app.globalData.userId) {
    return app.globalData.userId
  }
  let userId = ''
  try {
    userId = wx.getStorageSync('userId') || ''
  } catch (_) { /* ignore */ }
  if (!userId) {
    userId = 'u_' + Date.now().toString(36) + '_' + Math.random().toString(36).slice(2, 10)
    try {
      wx.setStorageSync('userId', userId)
    } catch (_) { /* ignore */ }
    if (app && app.globalData) {
      app.globalData.userId = userId
    }
  }
  return userId
}

module.exports = {
  analyzeVideo,
  generatePlan,
  fetchAthletes,
  compareWithAthlete,
  submitFeedback,
  health,
  getWeeklyInsight,
  // Invite
  getInviteStatus,
  getInviteCode,
  generateInviteCode,
  redeemInviteCode,
  // Challenge
  getChallenges,
  joinChallenge,
  getLeaderboard,
  checkInChallenge,
  // Coach (RF-602)
  generateCoachCode,
  joinCoach,
  getCoachStudents,
  getCoachDashboard,
  // Helpers
  getUserId,
}
