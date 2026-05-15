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
  return request('POST', '/compare', {
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

module.exports = {
  analyzeVideo,
  generatePlan,
  fetchAthletes,
  compareWithAthlete,
  submitFeedback,
  health,
}
