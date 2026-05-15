// utils/cadence.js
// 微信小程序步频检测模块
//
// 使用 wx.onAccelerometerChange 采集加速度数据，通过峰值检测算法
// 实时计算跑步步频（步/分钟，spm）。
//
// 限制说明：
//   - wx.onAccelerometerChange 仅在前台工作，无法后台录音
//   - iOS 采样率上限 ~60Hz，Android 通常更低（~30Hz）
//   - 建议用户手持设备或固定在腰部/手臂以获得稳定信号
//
// API：
//   startCadenceDetection(durationSeconds, callback) → 开始检测
//   stopCadenceDetection() → 停止检测
//   callback 接收 { cadence, confidence, timestamp, totalSteps, elapsedSec }

const MAX_SAMPLES = 180           // 环形缓冲区容量（~3 秒 @ 60Hz）
const PEAK_MIN_INTERVAL_MS = 200  // 两峰最小间隔（对应 300 spm 上限）
const PEAK_WINDOW_SIZE = 7        // 局部峰值搜索窗口（单侧）
const GRAVITY = 9.8               // 重力加速度 m/s²
const LOWPASS_ALPHA = 0.4         // 低通滤波平滑系数
const CADENCE_WINDOW_SEC = 3.0    // 计算步频的滑动窗口（秒）

// ── 模块内部状态 ──
let buffer = []                   // 环形缓冲区：{ t, mag }
let writeIdx = 0
let bufferCount = 0
let lastPeakTime = 0
let peakTimestamps = []           // 用于步频计算的峰时间戳列表
let stepCount = 0
let startTime = 0
let accelListener = null
let isRunning = false
let callbackFn = null
let durationMs = 0
let timerId = null

// ── 工具函数 ──

/** 三维加速度合成 */
function calcMagnitude(x, y, z) {
  return Math.sqrt(x * x + y * y + z * z)
}

/** 简单指数移动平均低通滤波器 */
function lowpass(newVal, prevVal) {
  if (prevVal === null || prevVal === undefined) return newVal
  return prevVal + LOWPASS_ALPHA * (newVal - prevVal)
}

/** 获取环形缓冲区中的元素 */
function bufferGet(offset) {
  if (bufferCount === 0) return null
  const idx = (writeIdx - 1 - offset + MAX_SAMPLES) % MAX_SAMPLES
  return buffer[idx] || null
}

/** 推入环形缓冲区 */
function bufferPush(t, mag) {
  if (bufferCount < MAX_SAMPLES) bufferCount++
  buffer[writeIdx] = { t, mag }
  writeIdx = (writeIdx + 1) % MAX_SAMPLES
}

// ── 峰值检测 ──

/**
 * 在环形缓冲区中检测峰值。
 * 策略：当前点 >= 两侧各 PEAK_WINDOW_SIZE 个点，且幅度超过自适应阈值。
 */
function detectPeak(idxOffset) {
  const current = bufferGet(idxOffset)
  if (!current) return false

  // 需要足够的上下文窗口
  if (bufferCount < PEAK_WINDOW_SIZE * 2 + 1) return false

  // 自适应阈值：使用最近缓冲区的平均值 * 系数
  let sum = 0
  let cnt = 0
  for (let i = 0; i < Math.min(bufferCount, 60); i++) {
    const s = bufferGet(i)
    if (s) { sum += s.mag; cnt++ }
  }
  const mean = cnt > 0 ? sum / cnt : 4
  const threshold = Math.max(mean * 1.15, 2.0)  // 至少要超过 2.0 m/s²

  // 检查当前点是否大于阈值
  if (current.mag < threshold) return false

  // 检查是否为局部最大值
  for (let i = 1; i <= PEAK_WINDOW_SIZE; i++) {
    const left = bufferGet(idxOffset + i)
    const right = bufferGet(idxOffset - i)
    if ((left && left.mag >= current.mag) || (right && right.mag >= current.mag)) {
      return false
    }
  }

  // 检查与上一个峰的间隔（避免重复计数）
  const now = Date.now()
  if (now - lastPeakTime < PEAK_MIN_INTERVAL_MS) return false

  lastPeakTime = now
  return true
}

// ── 步频计算 ──

/** 基于滑动窗口内的峰时间戳计算步频 */
function calcCadence() {
  const now = Date.now()
  // 清理超过窗口的旧峰
  peakTimestamps = peakTimestamps.filter(ts => now - ts <= CADENCE_WINDOW_SEC * 1000)

  if (peakTimestamps.length < 2) return { spm: 0, confidence: 0 }

  // 计算平均间隔
  let totalInterval = 0
  for (let i = 1; i < peakTimestamps.length; i++) {
    totalInterval += (peakTimestamps[i] - peakTimestamps[i - 1])
  }
  const avgIntervalSec = totalInterval / (peakTimestamps.length - 1) / 1000
  const spm = Math.round(60 / avgIntervalSec)

  // 置信度：基于窗口内峰的数量和均匀性
  const expectedPeaks = CADENCE_WINDOW_SEC * 3  // 假设步频 180 spm = 3 步/秒
  const peakCountFactor = Math.min(peakTimestamps.length / expectedPeaks, 1.0)

  // 计算间隔均匀性
  let variance = 0
  if (peakTimestamps.length >= 3) {
    const intervals = []
    for (let i = 1; i < peakTimestamps.length; i++) {
      intervals.push(peakTimestamps[i] - peakTimestamps[i - 1])
    }
    const meanInt = intervals.reduce((a, b) => a + b, 0) / intervals.length
    variance = intervals.reduce((s, v) => s + (v - meanInt) * (v - meanInt), 0) / intervals.length
  }
  const uniformity = Math.max(0, 1 - Math.sqrt(variance) / 200)  // 方差越小越均匀

  const confidence = Math.min(peakCountFactor * 0.6 + uniformity * 0.4, 1.0)

  return { spm, confidence: Math.round(confidence * 100) / 100 }
}

// ── 加速度回调 ──
let prevMagFiltered = null

function onAccelerometerChange(res) {
  if (!isRunning) return

  const { x, y, z } = res
  const mag = calcMagnitude(x, y, z)

  // 去重力 + 低通滤波
  const bodyAccel = Math.abs(mag - GRAVITY)
  const magFiltered = lowpass(bodyAccel, prevMagFiltered)
  prevMagFiltered = magFiltered

  const now = Date.now()
  bufferPush(now, magFiltered)

  // 在最新样本上检测峰值
  if (detectPeak(0)) {
    peakTimestamps.push(now)
    stepCount++
  }

  // 定期回调更新（每 3-4 个样本更新一次，避免过于频繁 setData）
  if (bufferCount % 4 === 0) {
    const { spm, confidence } = calcCadence()
    const elapsedSec = ((now - startTime) / 1000).toFixed(1)

    if (callbackFn) {
      callbackFn({
        cadence: spm,
        confidence,
        timestamp: now,
        totalSteps: stepCount,
        elapsedSec: parseFloat(elapsedSec),
      })
    }
  }
}

// ── 公开 API ──

/**
 * 开始步频检测
 * @param {number}  durationSeconds  检测时长（秒），0 表示手动停止
 * @param {function} callback        回调函数，接收 { cadence, confidence, timestamp, totalSteps, elapsedSec }
 */
function startCadenceDetection(durationSeconds, callback) {
  if (isRunning) {
    console.warn('[cadence] 检测已在运行中')
    return
  }

  // 重置状态
  buffer = []
  writeIdx = 0
  bufferCount = 0
  lastPeakTime = 0
  peakTimestamps = []
  stepCount = 0
  startTime = Date.now()
  prevMagFiltered = null
  isRunning = true
  callbackFn = callback
  durationMs = (durationSeconds || 0) * 1000

  // 启动加速度计
  wx.startAccelerometer({
    interval: 'game',  // 最高采样率 ~20ms/次
    success() {
      accelListener = onAccelerometerChange
      wx.onAccelerometerChange(accelListener)
    },
    fail(err) {
      console.error('[cadence] 启动加速度计失败:', err)
      isRunning = false
      if (callback) {
        callback({
          cadence: 0,
          confidence: 0,
          timestamp: Date.now(),
          totalSteps: 0,
          elapsedSec: 0,
          error: 'accelerometer_unavailable',
        })
      }
    },
  })

  // 如果指定了时长，设置自动停止定时器
  if (durationMs > 0) {
    timerId = setTimeout(() => {
      stopCadenceDetection()
    }, durationMs)
  }

  console.log(`[cadence] 检测开始，持续 ${durationSeconds || '无限'} 秒`)
}

/**
 * 停止步频检测
 * @returns {{ cadence, confidence, timestamp, totalSteps, elapsedSec }}
 */
function stopCadenceDetection() {
  if (!isRunning) return null

  // 清除定时器
  if (timerId) {
    clearTimeout(timerId)
    timerId = null
  }

  // 停止加速度计
  if (accelListener) {
    wx.offAccelerometerChange(accelListener)
    accelListener = null
  }
  wx.stopAccelerometer({
    success() {},
    fail() {},
  })

  isRunning = false

  const elapsedSec = parseFloat(((Date.now() - startTime) / 1000).toFixed(1))
  const { spm, confidence } = calcCadence()

  const result = {
    cadence: spm,
    confidence,
    timestamp: Date.now(),
    totalSteps: stepCount,
    elapsedSec,
  }

  console.log(`[cadence] 检测结束 — 步频: ${spm} spm, 步数: ${stepCount}, 置信度: ${confidence}, 时长: ${elapsedSec}s`)

  // 最终回调
  if (callbackFn) {
    callbackFn(result)
    callbackFn = null
  }

  return result
}

/** 检查检测是否在运行中 */
function isDetecting() {
  return isRunning
}

module.exports = {
  startCadenceDetection,
  stopCadenceDetection,
  isDetecting,
}