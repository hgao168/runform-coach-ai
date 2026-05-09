// pages/analyze/analyze.js
const api = require('../../utils/api')
const storage = require('../../utils/storage')
const { t, backendLang } = require('../../utils/i18n')

Page({
  data: {
    i: {
      analyzeTitle: t('analyzeTitle'),
      analyzeSubtitle: t('analyzeSubtitle'),
      videoGuide: t('videoGuide'),
      videoGuideBody: t('videoGuideBody'),
      pickVideo: t('pickVideo'),
      analyzeBtn: t('analyzeBtn'),
      analyzing: t('analyzing'),
      uploadProgress: t('uploadProgress'),
    },
    tips: [
      { icon: '📷', text: t('isZh') ? '侧面或后方拍摄，全身入镜' : 'Film from the side or rear, full body in frame' },
      { icon: '🔆', text: t('isZh') ? '光线充足，避免逆光' : 'Good lighting, avoid backlight' },
      { icon: '⏱', text: t('isZh') ? '建议 10–30 秒' : '10–30 seconds recommended' },
      { icon: '🏃', text: t('isZh') ? '保持自然跑步速度' : 'Run at natural pace' },
    ],

    videoPath: '',
    videoName: '',
    videoDurationText: '',
    videoSizeText: '',
    analyzing: false,
    uploadProgress: 0,
  },

  onLoad() {},

  pickVideo() {
    wx.chooseMedia({
      count: 1,
      mediaType: ['video'],
      sourceType: ['album', 'camera'],
      maxDuration: 60,
      camera: 'back',
      success: (res) => {
        const item = res.tempFiles[0]
        const sizeKB = Math.round((item.size || 0) / 1024)
        const sizeMB = (sizeKB / 1024).toFixed(1)
        const durationSec = Math.round(item.duration || 0)
        this.setData({
          videoPath: item.tempFilePath,
          videoName: item.tempFilePath.split('/').pop() || 'video.mp4',
          videoDurationText: `${durationSec}s`,
          videoSizeText: sizeKB >= 1024 ? `${sizeMB} MB` : `${sizeKB} KB`,
        })
      },
      fail(err) {
        if (err.errMsg && !err.errMsg.includes('cancel')) {
          wx.showToast({ title: '视频选择失败', icon: 'error' })
        }
      },
    })
  },

  analyze() {
    if (!this.data.videoPath) {
      wx.showToast({ title: t('noVideoSelected'), icon: 'none' })
      return
    }
    if (this.data.analyzing) return

    this.setData({ analyzing: true, uploadProgress: 0 })

    api.analyzeVideo(
      this.data.videoPath,
      backendLang,
      storage.getProfile(),
      (progress) => {
        this.setData({ uploadProgress: progress })
      },
    )
      .then((result) => {
        // Store result for result page
        wx.setStorageSync('rf_pendingResult', result)

        // Add to history
        storage.addHistory({
          id: Date.now().toString(),
          date: new Date().toISOString(),
          summary: result.overall_assessment || result.summary || '',
          overallScore: result.overall_score,
          result,
        })

        this.setData({ analyzing: false, uploadProgress: 0 })
        wx.navigateTo({ url: '/pages/result/result' })
      })
      .catch((err) => {
        this.setData({ analyzing: false, uploadProgress: 0 })
        wx.showModal({
          title: t('error'),
          content: err.message || t('analysisError'),
          showCancel: false,
        })
      })
  },
})
