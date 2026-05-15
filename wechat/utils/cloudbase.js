// utils/cloudbase.js
// RF-306: CloudBase 接入准备
// CloudBase initialization, database collections, and local-fallback wrapper.

const Storage = require('./storage')
const { t } = require('./i18n')

// CloudBase environment ID — update to your real env when approved
const CLOUD_ENV = 'runform-coach-ai-xxxxxx'

/** Collections mirror WeChat cloud DB */
const COLLECTIONS = {
  analyses: 'analyses',
  plans: 'plans',
  profiles: 'profiles',
  feedbacks: 'feedbacks',
}

/**
 * Initialise CloudBase.
 * Call once from app.js onLaunch.
 */
function init() {
  if (!wx.cloud) {
    console.warn('[cloudbase] wx.cloud not available — running in devtools without cloud support')
    return false
  }
  try {
    wx.cloud.init({
      env: CLOUD_ENV,
      traceUser: true,
    })
    console.log('[cloudbase] Initialised, env:', CLOUD_ENV)
    return true
  } catch (e) {
    console.error('[cloudbase] Init failed:', e)
    return false
  }
}

/**
 * Check whether the device currently has a network connection.
 * Returns true if connected (Wi-Fi or cellular).
 */
function isOnline() {
  return new Promise((resolve) => {
    wx.getNetworkType({
      success(res) {
        resolve(res.networkType !== 'none')
      },
      fail() {
        resolve(false)
      },
    })
  })
}

/**
 * Get the cloud DB collection reference (lazy).
 * Returns null if cloud is not available.
 */
function _db() {
  if (!wx.cloud || !wx.cloud.database) return null
  return wx.cloud.database()
}

/**
 * Generic query: cloudDB.get(collection, { where, orderBy, limit, skip })
 * Auto-falls back to local storage when offline or cloud unavailable.
 *
 * @param {string} collectionKey — one of COLLECTIONS keys
 * @param {object} [opts]
 * @param {object} [opts.where]     — MongoDB-style filter
 * @param {string} [opts.orderBy]   — field name
 * @param {string} [opts.order]     — 'asc' | 'desc'
 * @param {number} [opts.limit]     — default 20
 * @param {number} [opts.skip]      — default 0
 * @returns {Promise<{data: Array, from: string}>} from: 'cloud' | 'local' | 'empty'
 */
async function get(collectionKey, opts = {}) {
  const col = COLLECTIONS[collectionKey]
  if (!col) throw new Error(`Unknown collection: ${collectionKey}`)

  const online = await isOnline()
  const db = _db()

  if (online && db) {
    try {
      let query = db.collection(col)
      if (opts.where) query = query.where(opts.where)
      if (opts.orderBy) query = query.orderBy(opts.orderBy, opts.order || 'desc')
      if (opts.limit) query = query.limit(opts.limit)
      if (opts.skip) query = query.skip(opts.skip)
      const res = await query.get()
      return { data: res.data, from: 'cloud' }
    } catch (e) {
      console.warn(`[cloudbase] Cloud query failed for ${col}, falling back:`, e.message)
    }
  }

  // Local fallback via storage.js
  const local = _localFallbackGet(collectionKey, opts)
  return { data: local, from: local.length ? 'local' : 'empty' }
}

/**
 * Add a document.
 * Online: insert to cloud.
 * Offline: push to local queue for later sync.
 *
 * @param {string} collectionKey
 * @param {object} doc
 * @returns {Promise<{id: string, from: string}>}
 */
async function add(collectionKey, doc) {
  const col = COLLECTIONS[collectionKey]
  if (!col) throw new Error(`Unknown collection: ${collectionKey}`)

  const docWithMeta = {
    ...doc,
    _createTime: new Date().toISOString(),
    _pendingSync: true,
  }

  const online = await isOnline()
  const db = _db()

  if (online && db) {
    try {
      const res = await db.collection(col).add({ data: docWithMeta })
      return { id: res._id, from: 'cloud' }
    } catch (e) {
      console.warn(`[cloudbase] Cloud add failed for ${col}, queuing locally:`, e.message)
    }
  }

  // Local fallback
  const localId = `local_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`
  const localDoc = { ...docWithMeta, _id: localId, _localOnly: true }
  _localFallbackAdd(collectionKey, localDoc)
  return { id: localId, from: 'local' }
}

/**
 * Update a document by _id.
 *
 * @param {string} collectionKey
 * @param {string} id
 * @param {object} updates
 * @returns {Promise<{updated: number, from: string}>}
 */
async function update(collectionKey, id, updates) {
  const col = COLLECTIONS[collectionKey]
  if (!col) throw new Error(`Unknown collection: ${collectionKey}`)

  const online = await isOnline()
  const db = _db()

  if (online && db) {
    try {
      if (id && !id.startsWith('local_')) {
        const res = await db.collection(col).doc(id).update({ data: updates })
        return { updated: res.stats.updated, from: 'cloud' }
      }
    } catch (e) {
      console.warn(`[cloudbase] Cloud update failed for ${col}/${id}:`, e.message)
    }
  }

  // Local fallback
  _localFallbackUpdate(collectionKey, id, updates)
  return { updated: 1, from: 'local' }
}

/**
 * Remove a document by _id.
 *
 * @param {string} collectionKey
 * @param {string} id
 * @returns {Promise<{removed: number, from: string}>}
 */
async function remove(collectionKey, id) {
  const col = COLLECTIONS[collectionKey]
  if (!col) throw new Error(`Unknown collection: ${collectionKey}`)

  const online = await isOnline()
  const db = _db()

  if (online && db) {
    try {
      if (id && !id.startsWith('local_')) {
        const res = await db.collection(col).doc(id).remove()
        return { removed: res.stats.removed, from: 'cloud' }
      }
    } catch (e) {
      console.warn(`[cloudbase] Cloud remove failed for ${col}/${id}:`, e.message)
    }
  }

  // Local fallback
  _localFallbackRemove(collectionKey, id)
  return { removed: 1, from: 'local' }
}

// ── Local fallback helpers (mirror cloud collections in storage) ──

function _localStoreKey(collectionKey) {
  return `rf_cloud_${collectionKey}`
}

function _localFallbackGet(collectionKey, opts = {}) {
  try {
    let items = wx.getStorageSync(_localStoreKey(collectionKey)) || []
    if (opts.where) {
      items = items.filter((item) => {
        return Object.entries(opts.where).every(([k, v]) => item[k] === v)
      })
    }
    if (opts.orderBy) {
      const dir = opts.order === 'asc' ? 1 : -1
      items.sort((a, b) => {
        if (a[opts.orderBy] < b[opts.orderBy]) return -dir
        if (a[opts.orderBy] > b[opts.orderBy]) return dir
        return 0
      })
    }
    const skip = opts.skip || 0
    const limit = opts.limit || 20
    return items.slice(skip, skip + limit)
  } catch (_) {
    return []
  }
}

function _localFallbackAdd(collectionKey, doc) {
  try {
    const key = _localStoreKey(collectionKey)
    const items = wx.getStorageSync(key) || []
    items.unshift(doc)
    wx.setStorageSync(key, items.slice(0, 200)) // cap
  } catch (e) {
    console.warn('[cloudbase] Local add failed:', e)
  }
}

function _localFallbackUpdate(collectionKey, id, updates) {
  try {
    const key = _localStoreKey(collectionKey)
    const items = wx.getStorageSync(key) || []
    const idx = items.findIndex((i) => i._id === id)
    if (idx !== -1) {
      items[idx] = { ...items[idx], ...updates }
      wx.setStorageSync(key, items)
    }
  } catch (e) {
    console.warn('[cloudbase] Local update failed:', e)
  }
}

function _localFallbackRemove(collectionKey, id) {
  try {
    const key = _localStoreKey(collectionKey)
    const items = (wx.getStorageSync(key) || []).filter((i) => i._id !== id)
    wx.setStorageSync(key, items)
  } catch (e) {
    console.warn('[cloudbase] Local remove failed:', e)
  }
}

/**
 * Queue pending documents for sync when back online.
 * Call this whenever network status changes to 'connected'.
 */
async function syncPending() {
  const online = await isOnline()
  if (!online || !_db()) return { synced: 0 }

  let synced = 0
  for (const colKey of Object.keys(COLLECTIONS)) {
    const key = _localStoreKey(colKey)
    const items = wx.getStorageSync(key) || []
    const pending = items.filter((i) => i._pendingSync && !i._localOnly)
    for (const doc of pending) {
      try {
        const { _id, _pendingSync, _createTime, ...data } = doc
        const res = await _db().collection(COLLECTIONS[colKey]).add({ data })
        // Remove local copy, mark as synced
        const updated = items.filter((i) => i._id !== doc._id)
        wx.setStorageSync(key, updated)
        synced++
      } catch (e) {
        console.warn(`[cloudbase] Sync failed for ${colKey}/${doc._id}:`, e.message)
      }
    }
  }
  return { synced }
}

module.exports = {
  init,
  isOnline,
  get,
  add,
  update,
  remove,
  syncPending,
  COLLECTIONS,
  CLOUD_ENV,
}
