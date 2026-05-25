// pages/compare/compare.js
const api = require('../../utils/api')
const { t, isZh } = require('../../utils/i18n')

function parseAthletes(raw) {
  if (!Array.isArray(raw)) return []
  return raw.map((a) => {
    const name = a.name || a.athlete_name || ''
    const initial = name ? name[0].toUpperCase() : '?'
    const stats = []
    if (a.cadence) stats.push({ label: isZh ? '步频 (步/分)' : 'Cadence', value: a.cadence })
    if (a.vertical_oscillation) stats.push({ label: isZh ? '垂直振幅' : 'Vert. Oscillation', value: a.vertical_oscillation })
    if (a.ground_contact_time) stats.push({ label: isZh ? '接地时间' : 'Ground Contact', value: a.ground_contact_time })
    if (a.stride_length) stats.push({ label: isZh ? '步幅' : 'Stride Length', value: a.stride_length })
    return {
      id: a.id || name,
      name,
      initial,
      nationality: a.nationality || a.country || '',
      event: a.event || a.specialty || '',
      bestAchievement: (a.achievements || [])[0] || a.best_time || '',
      bio: a.bio || a.description || '',
      stats,
      achievements: a.achievements || [],
    }
  })
}

Page({
  data: {
    i: {
      compareTitle: t('compareTitle'),
      compareSubtitle: t('compareSubtitle'),
      compareNote: t('compareNote'),
      athleteBio: t('athleteBio'),
      achievement: t('achievement'),
      loading: t('loading'),
      retry: t('retry'),
      back: t('back'),
    },

    loading: false,
    loadError: '',
    athletes: [],
    selectedAthlete: null,
  },

  onLoad() {
    this.loadAthletes()
  },

  loadAthletes() {
    this.setData({ loading: true, loadError: '' })
    api.fetchAthletes()
      .then((res) => {
        const list = Array.isArray(res) ? res : (res.athletes || [])
        this.setData({ loading: false, athletes: parseAthletes(list) })
      })
      .catch((err) => {
        this.setData({ loading: false, loadError: err.message || t('error') })
      })
  },

  selectAthlete(e) {
    const id = e.currentTarget.dataset.id
    const athlete = this.data.athletes.find((a) => a.id === id)
    if (athlete) this.setData({ selectedAthlete: athlete })
  },

  clearAthlete() {
    this.setData({ selectedAthlete: null })
  },
})
