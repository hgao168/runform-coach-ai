// utils/config.js
// Toggle BASE_URL for staging vs production
const ENV = 'staging' // 'staging' | 'production'

const BASE_URLS = {
  staging: 'https://runform-coach-ai-staging.up.railway.app',
  production: 'https://runform-coach-ai-production.up.railway.app',
}

module.exports = {
  BASE_URL: BASE_URLS[ENV],
  ENV,
}
