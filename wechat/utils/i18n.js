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

    // Result page
    resultTitle: '分析结果',
    confidence: '置信度',
    metrics: '动作评估',
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
    resultTitle: 'Analysis Result',
    confidence: 'Confidence',
    metrics: 'Form Metrics',
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
