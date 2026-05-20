// utils/i18n.js
const sysInfo = wx.getSystemInfoSync()
const sysLang = sysInfo.language || 'zh_CN'
const isZh = sysLang.toLowerCase().startsWith('zh')

const strings = {
  zh: {
    // Tabs
    analyze: '分析',
    plan: '计划',
    history: '历史',
    profile: '我的',

    // Analyze page
    analyzeTitle: '跑步姿态分析',
    analyzeSubtitle: '上传跑步视频，AI 分析你的跑步姿态',
    pickVideo: '选择视频',
    recordVideo: '录制视频',
    analyzeBtn: '开始分析',
    analyzing: '分析中，请稍候...',
    uploadProgress: '上传中',
    videoGuide: '拍摄指南',
    videoGuideBody: '从侧面或后方拍摄，保持全身入镜，自然跑步速度，光线充足，建议 10–30 秒。',
    noVideoSelected: '请先选择视频',
    analysisError: '分析失败，请重试',
    // RF-308: Angle selection
    cameraAngle: '拍摄角度',
    angleSide: '侧面',
    angleRear: '后方',
    angleFront: '前方',
    angleSideDesc: '侧面拍摄，全身体态清晰',
    angleRearDesc: '后方拍摄，观察步宽和骨盆',
    angleFrontDesc: '前方拍摄，观察膝盖和脚部',

    // Result page
    resultTitle: '分析结果',
    confidence: '置信度',
    metrics: '动作评估',
    insightsTitle: '姿态分析',
    strengthFocus: '强化重点',
    explanation: '说明',
    watchTutorial: '搜索训练视频',
    tutorialCopied: '已复制搜索链接，请在浏览器中打开',
    compareWithElite: '与精英运动员对比',
    noIssues: '太棒了！未发现明显姿态问题。',

    // Plan page
    planTitle: '训练计划',
    planSubtitle: '设置目标、里程和训练天数，生成个性化周计划',
    weeklyKm: '当前周跑量 (km)',
    goal: '目标',
    runDays: '训练天数',
    daysSelected: '天已选择',
    injuryFlag: '受伤/疼痛标记',
    injuryWarning: '已开启：强度降低，质量训练替换为轻松跑',
    generatePlan: '生成训练计划',
    generating: '生成中...',
    planError: '计划生成失败，请重试',
    totalKm: '总里程',
    runningDays: '跑步天数',
    nextWeekPlan: '下周计划',

    // Goals
    goal5K: '5公里',
    goal10K: '10公里',
    goalHalf: '半程马拉松',
    goalMarathon: '全程马拉松',
    goalFitness: '日常健身',

    // Workout categories
    catEasy: '轻松跑',
    catLong: '长距离',
    catQuality: '质量训练',
    catRecovery: '恢复跑',
    catStrength: '力量训练',
    catMobility: '灵活性训练',

    // Day labels
    days: ['周一', '周二', '周三', '周四', '周五', '周六', '周日'],
    dayShort: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],

    // History page
    historyTitle: '历史记录',
    historyEmpty: '暂无历史记录',
    historyEmptySub: '完成第一次跑步分析后\n记录将显示在这里',
    deleteHistory: '清除所有记录',
    deleteConfirm: '确定清除所有历史记录？',
    deleteOk: '清除',
    deleteCancel: '取消',
    trendTitle: '趋势图表',
    trendToggle: '展开',
    trendToggleHide: '收起',
    trendCadence: '步频',
    trendOscillation: '垂直振幅',
    trendGCT: '触地时间',
    trendNoData: '至少需要 2 条记录才能生成趋势图',
    trendTapHint: '点击数据点查看数值',

    // Profile page
    profileTitle: '我的',
    firstName: '名字',
    lastName: '姓氏',
    nickname: '昵称',
    level: '跑步水平',
    levelBeginner: '初级',
    levelIntermediate: '中级',
    levelAdvanced: '高级',
    weeklyKmLabel: '每周跑量 (km)',
    runDaysPerWeek: '每周跑步天数',
    targetLabel: '训练目标',
    injuryNote: '伤病备注',
    genderLabel: '性别',
    shoeSizeLabel: '鞋码',
    legLengthLabel: '腿长 (cm)',
    shoeBrandModelLabel: '跑鞋品牌/型号',
    genderMale: '男',
    genderFemale: '女',
    genderOther: '其他',
    genderUnspecified: '不透露',
    saveProfile: '保存',
    profileSaved: '已保存',

    // Compare page
    compareTitle: '精英对比',
    compareSubtitle: '浏览世界级精英运动员资料',
    compareNote: '完整对比功能需要在 iOS 版完成动作分析后使用',
    viewProfile: '查看资料',
    athleteBio: '运动员简介',
    achievement: '成就',
    nationality: '国籍',
    event: '项目',
    compareResult: '对比结果',
    yourMetrics: '你的数据',
    eliteMetrics: '精英数据',
    gap: '差距',
    noAnalysisForCompare: '请先完成一次视频分析',
    goAnalyzeNow: '去分析',
    comparing: '对比中...',
    compareError: '对比失败，请重试',
    compareVs: 'VS',
    noCompareData: '暂无可对比指标',
    trainingParams: '训练参数',
    startFirstAnalysis: '开始第一次分析',

    // Common
    loading: '加载中...',
    error: '出错了',
    retry: '重试',
    back: '返回',
    save: '保存',
    cancel: '取消',
    confirm: '确认',
    km: 'km',
    min: '分钟',
    sets: '组',
    times: '次',
    perWeek: '次/周',

    // Feedback
    feedbackTitle: '反馈评分',
    feedbackSubtitle: '帮助我们改进教练质量',
    feedbackPlaceholder: '可选：哪里不对或有帮助？',
    feedbackSubmit: '提交反馈',
    feedbackSubmitted: '感谢反馈！',
    feedbackSavedOffline: '已离线保存，联网后自动同步',
    feedbackNoRating: '请先选择评分',

    // Share
    shareResult: '分享结果',
    shareTapHint: '请点击右上角分享',

    // RF-913: Save share image
    saveToAlbum: '保存到相册',

    // RF-963: Rewarded video ad
    adWatchTitle: '观看广告支持我们',
    adWatchDesc: '观看一段短视频广告，帮助我们持续优化教练服务 🙏',
    adWatchButton: '观看广告',

    // Feedback submitting state
    feedbackSubmitting: '提交中...',

    // RF-305: Voice Coach
    voiceCoach: '语音教练',
    voiceCoachPlay: '播放语音播报',
    voiceCoachStop: '停止播报',
    voiceCoachMute: '静音',
    voiceCoachUnmute: '取消静音',
    voiceCoachDisabled: '语音已关闭',
    voiceCoachEnable: '开启语音',
    voiceCoachPlaying: '正在播报...',
    voiceCoachPaused: '已暂停',
    voiceCoachStopped: '播报完毕',
    voiceCoachNoAudio: '语音文件未生成，请运行 tools/generate-voice-prompts.py',
  },

  en: {
    analyze: 'Analyze',
    plan: 'Plan',
    history: 'History',
    profile: 'Profile',
    analyzeTitle: 'Running Analysis',
    analyzeSubtitle: 'Upload a running video for AI biomechanics coaching',
    pickVideo: 'Pick Video',
    recordVideo: 'Record',
    analyzeBtn: 'Analyze',
    analyzing: 'Analyzing, please wait...',
    uploadProgress: 'Uploading',
    videoGuide: 'Recording Guide',
    videoGuideBody: 'Film from side or rear, keep full body in frame, natural pace, good lighting, 10–30 seconds recommended.',
    noVideoSelected: 'Please select a video first',
    analysisError: 'Analysis failed, please try again',
    // RF-308: Angle selection
    cameraAngle: 'Camera Angle',
    angleSide: 'Side',
    angleRear: 'Rear',
    angleFront: 'Front',
    angleSideDesc: 'Side view — full body posture',
    angleRearDesc: 'Rear view — stride width & pelvis',
    angleFrontDesc: 'Front view — knees & foot strike',
    resultTitle: 'Analysis Result',
    confidence: 'Confidence',
    metrics: 'Form Metrics',
    insightsTitle: 'Posture Analysis',
    strengthFocus: 'Strength Focus',
    explanation: 'Explanation',
    watchTutorial: 'Search Exercise Video',
    tutorialCopied: 'Search link copied — open in browser',
    compareWithElite: 'Compare with Elite',
    noIssues: 'Great! No major form issues found.',
    planTitle: 'Training Plan',
    planSubtitle: 'Set your goal, volume and days to get a personalised week plan',
    weeklyKm: 'Current weekly km',
    goal: 'Goal',
    runDays: 'Run days',
    daysSelected: 'days selected',
    injuryFlag: 'Injury / pain flag',
    injuryWarning: 'On: volume reduced, hard sessions replaced with easy runs',
    generatePlan: 'Generate Plan',
    generating: 'Generating...',
    planError: 'Plan generation failed, please try again',
    totalKm: 'Total km',
    runningDays: 'Running days',
    nextWeekPlan: 'Next Week Plan',
    goal5K: '5K',
    goal10K: '10K',
    goalHalf: 'Half Marathon',
    goalMarathon: 'Marathon',
    goalFitness: 'General Fitness',
    catEasy: 'Easy',
    catLong: 'Long',
    catQuality: 'Quality',
    catRecovery: 'Recovery',
    catStrength: 'Strength',
    catMobility: 'Mobility',
    days: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    dayShort: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    historyTitle: 'History',
    historyEmpty: 'No history yet',
    historyEmptySub: 'Your analysis history will\nappear here',
    deleteHistory: 'Clear All',
    deleteConfirm: 'Clear all history records?',
    deleteOk: 'Clear',
    deleteCancel: 'Cancel',
    trendTitle: 'Trend Chart',
    trendToggle: 'Expand',
    trendToggleHide: 'Collapse',
    trendCadence: 'Cadence',
    trendOscillation: 'Vert. Osc.',
    trendGCT: 'GCT',
    trendNoData: 'Need at least 2 records for trend chart',
    trendTapHint: 'Tap data point to see value',
    profileTitle: 'Profile',
    firstName: 'First name',
    lastName: 'Last name',
    nickname: 'Nickname',
    level: 'Runner level',
    levelBeginner: 'Beginner',
    levelIntermediate: 'Intermediate',
    levelAdvanced: 'Advanced',
    weeklyKmLabel: 'Weekly mileage (km)',
    runDaysPerWeek: 'Running days / week',
    targetLabel: 'Training target',
    injuryNote: 'Injury notes',
    genderLabel: 'Gender',
    shoeSizeLabel: 'Shoe size',
    legLengthLabel: 'Leg length (cm)',
    shoeBrandModelLabel: 'Shoe brand/model',
    genderMale: 'Male',
    genderFemale: 'Female',
    genderOther: 'Other',
    genderUnspecified: 'Prefer not to say',
    saveProfile: 'Save',
    profileSaved: 'Saved',
    compareTitle: 'Elite Compare',
    compareSubtitle: 'Browse world-class elite athlete profiles',
    compareNote: 'Full comparison requires completing an analysis in the iOS app',
    viewProfile: 'View Profile',
    athleteBio: 'Bio',
    achievement: 'Achievement',
    nationality: 'Nationality',
    event: 'Event',
    compareResult: 'Comparison',
    yourMetrics: 'Your Metrics',
    eliteMetrics: 'Elite Metrics',
    gap: 'Gap',
    noAnalysisForCompare: 'Complete a video analysis first',
    goAnalyzeNow: 'Analyze',
    comparing: 'Comparing...',
    compareError: 'Comparison failed, retry',
    compareVs: 'VS',
    noCompareData: 'No comparable metrics',
    trainingParams: 'Training Params',
    startFirstAnalysis: 'Start First Analysis',
    loading: 'Loading...',
    error: 'Error',
    retry: 'Retry',
    back: 'Back',
    save: 'Save',
    cancel: 'Cancel',
    confirm: 'Confirm',
    km: 'km',
    min: 'min',
    sets: 'sets',
    times: 'reps',
    perWeek: 'x/week',

    // Feedback
    feedbackTitle: 'Feedback',
    feedbackSubtitle: 'Help improve coaching quality',
    feedbackPlaceholder: 'Optional: what was wrong or useful?',
    feedbackSubmit: 'Submit Feedback',
    feedbackSubmitted: 'Thank you!',
    feedbackSavedOffline: 'Saved offline, will sync when online',
    feedbackNoRating: 'Please select a rating first',

    // Share
    shareResult: 'Share Result',
    shareTapHint: 'Tap top-right to share',

    // RF-913: Save share image
    saveToAlbum: 'Save to Album',

    // RF-963: Rewarded video ad
    adWatchTitle: 'Watch ad to support us',
    adWatchDesc: 'Watch a short video ad to help us improve coaching 🙏',
    adWatchButton: 'Watch Ad',

    // Feedback submitting state
    feedbackSubmitting: 'Submitting...',

    // RF-305: Voice Coach
    voiceCoach: 'Voice Coach',
    voiceCoachPlay: 'Play Voice Feedback',
    voiceCoachStop: 'Stop',
    voiceCoachMute: 'Mute',
    voiceCoachUnmute: 'Unmute',
    voiceCoachDisabled: 'Voice off',
    voiceCoachEnable: 'Enable Voice',
    voiceCoachPlaying: 'Playing...',
    voiceCoachPaused: 'Paused',
    voiceCoachStopped: 'Finished',
    voiceCoachNoAudio: 'Voice files not generated. Run tools/generate-voice-prompts.py',
  },
}

const t = (key) => {
  const dict = isZh ? strings.zh : strings.en
  return dict[key] !== undefined ? dict[key] : key
}

// Detect China region for video platform links
const isChina = () => {
  const region = sysInfo.region || ''
  return isZh && !region.toLowerCase().includes('taiwan') && !region.toLowerCase().includes('hong kong')
}

const getVideoSearchUrl = (exerciseName) => {
  const query = encodeURIComponent(`${exerciseName} 跑步训练`)
  if (isChina()) {
    return `https://search.bilibili.com/all?keyword=${query}`
  }
  return `https://www.youtube.com/results?search_query=${encodeURIComponent(exerciseName + ' running exercise form')}`
}

const backendLang = isZh ? 'zh-Hans' : 'en'

module.exports = { t, isZh, backendLang, isChina, getVideoSearchUrl, strings }
