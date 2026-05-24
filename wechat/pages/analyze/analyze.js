// pages/analyze/analyze.js
const api = require('../../utils/api')
const storage = require('../../utils/storage')
const { compressVideo } = require('../../utils/video-compress')
const { t, backendLang } = require('../../utils/i18n')

Page({
  data: {
    i: {
      analyzeTitle: t('analyzeTitle'),
      analyzeSubtitle: t('analyzeSubtitle'),
      injuryPreventionBanner: t('injuryPreventionBanner'),
      videoGuide: t('videoGuide'),
      videoGuideBody: t('videoGuideBody'),
      pickVideo: t('pickVideo'),
      analyzeBtn: t('analyzeBtn'),
      analyzing: t('analyzing'),
      uploadProgress: t('uploadProgress'),
      // RF-308: Angle selection
      cameraAngle: t('cameraAngle'),
      angleSide: t('angleSide'),
      angleRear: t('angleRear'),
      angleFront: t('angleFront'),
      angleSideDesc: t('angleSideDesc'),
      angleRearDesc: t('angleRearDesc'),
      angleFrontDesc: t('angleFrontDesc'),
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
    cameraAngle: 'side',
    analyzing: false,
    uploadProgress: 0,
    compressing: false,
    compressResult: null,
  },

  onLoad() {},

  selectAngle(e) {
    this.setData({ cameraAngle: e.currentTarget.dataset.angle })
  },

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
    if (this.data.analyzing || this.data.compressing) return

    this.setData({ analyzing: true, compressing: true, uploadProgress: 0, compressResult: null })

    // RF-303: Compress video before upload (target < 10MB)
    compressVideo(this.data.videoPath, {
      quality: 'medium',
      onProgress: (stage, pct) => {
        if (stage === 'compress') {
          this.setData({ uploadProgress: Math.round(pct * 0.3) }) // compression takes ~30% of total progress
        }
      },
    })
      .then((compResult) => {
        this.setData({
          compressing: false,
          compressResult: compResult,
          uploadProgress: 30,
        })

        const uploadPath = compResult.path
        const profile = storage.getProfile()
        profile.cameraAngle = this.data.cameraAngle
        return api.analyzeVideo(
          uploadPath,
          backendLang,
          profile,
          (progress) => {
            // Scale upload progress from 30% to 100%
            this.setData({ uploadProgress: 30 + Math.round(progress * 0.7) })
          },
        )
      })
      .then((result) => {
        // Store result for result page
        wx.setStorageSync('rf_pendingResult', result)

        // Save as last analysis result for compare feature
        wx.setStorageSync('lastAnalysisResult', result)

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
        this.setData({ analyzing: false, compressing: false, uploadProgress: 0, compressResult: null })
        wx.showModal({
          title: t('error'),
          content: err.message || t('analysisError'),
          showCancel: false,
        })
      })
  },
})
