// pages/cadence/cadence.js
// 步频检测演示页面
const cadence = require('../../utils/cadence')
const { t } = require('../../utils/i18n')

Page({
  data: {
    // 文本
    i: {
      title: t('cadenceTitle') || (t('isZh') ? '步频检测' : 'Cadence'),
      startBtn: t('cadenceStartBtn') || (t('isZh') ? '开始检测' : 'Start'),
      stopBtn: t('cadenceStopBtn') || (t('isZh') ? '停止' : 'Stop'),
      cadenceLabel: t('cadenceLabel') || (t('isZh') ? '步频' : 'Cadence'),
      spmUnit: t('spmUnit') || 'spm',
      confidenceLabel: t('confidenceLabel') || (t('isZh') ? '置信度' : 'Confidence'),
      stepsLabel: t('stepsLabel') || (t('isZh') ? '步数' : 'Steps'),
      elapsedLabel: t('elapsedLabel') || (t('isZh') ? '时长' : 'Elapsed'),
      secUnit: 's',
      detecting: t('detecting') || (t('isZh') ? '检测中...' : 'Detecting...'),
      ready: t('cadenceReady') || (t('isZh') ? '准备就绪，点击下方按钮开始' : 'Ready. Tap the button below to start.'),
      tipTitle: t('cadenceTipTitle') || (t('isZh') ? '使用提示' : 'Tips'),
      tipBody: t('cadenceTipBody') || (t('isZh')
        ? '请将手机握在手中或固定于腰部/臂带，保持自然跑步姿势。步频数据仅在屏幕亮起时采集，iOS 采样率约 60Hz，Android 约 30Hz。检测结果仅供参考，正式评估请使用视频分析功能。'
        : 'Hold the phone in your hand or secure it at your waist/arm. Cadence data is only collected while the screen is on. iOS samples at ~60Hz, Android at ~30Hz. For formal assessment use the video analysis feature.'),
    },

    // 实时数据
    cadence: 0,
    confidence: 0,
    totalSteps: 0,
    elapsedSec: 0,
    isRunning: false,
    error: '',

    // 最终结果
    finalResult: null,
  },

  // ── 生命周期 ──

  onLoad() {
    console.log('[cadence page] 步频检测页面加载')
  },

  onShow() {
    // 如果之前有残留状态就刷新一下
    if (cadence.isDetecting()) {
      this.setData({ isRunning: true })
    }
  },

  onUnload() {
    // 离开页面时自动停止
    if (cadence.isDetecting()) {
      cadence.stopCadenceDetection()
    }
    this.setData({ isRunning: false })
  },

  // ── 操作方法 ──

  /** 开始检测（默认 30 秒） */
  startDetection() {
    if (this.data.isRunning) return

    // 请求加速度计权限（微信部分版本需要用户授权）
    this.setData({ isRunning: true, finalResult: null, error: '', cadence: 0, confidence: 0, totalSteps: 0, elapsedSec: 0 })

    cadence.startCadenceDetection(30, (data) => {
      // 处理错误
      if (data.error) {
        this.setData({
          isRunning: false,
          error: data.error,
        })
        return
      }

      // 实时更新页面数据
      this.setData({
        cadence: data.cadence,
        confidence: data.confidence,
        totalSteps: data.totalSteps,
        elapsedSec: data.elapsedSec,
      })
    })
  },

  /** 手动停止检测 */
  stopDetection() {
    if (!this.data.isRunning) return

    const result = cadence.stopCadenceDetection()
    this.setData({
      isRunning: false,
      cadence: result ? result.cadence : this.data.cadence,
      confidence: result ? result.confidence : this.data.confidence,
      totalSteps: result ? result.totalSteps : this.data.totalSteps,
      elapsedSec: result ? result.elapsedSec : this.data.elapsedSec,
      finalResult: result,
    })
  },
})