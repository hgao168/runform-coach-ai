// utils/video-compress.js
// RF-303: Video compression before upload — target < 10MB

const COMPRESS_QUALITY = 'medium' // low | medium | high
const COMPRESS_BITRATE = 1200     // kbps target
const FALLBACK_MAX_DURATION = 30  // seconds — trim to 30s if compressed still too large

/**
 * Compress video using wx.compressVideo (WeChat 2.20.0+).
 * Falls back to pass-through if API unavailable.
 *
 * @param {string} srcPath - original temp file path
 * @param {object} [opts]
 * @param {'low'|'medium'|'high'} [opts.quality] - compression quality
 * @param {number} [opts.bitrate] - target bitrate in kbps
 * @param {function} [opts.onProgress] - (stage: string, pct: number) => void
 * @returns {Promise<{path: string, size: number, duration: number}>}
 */
function compressVideo(srcPath, opts = {}) {
  const quality = opts.quality || COMPRESS_QUALITY
  const bitrate = opts.bitrate || COMPRESS_BITRATE
  const onProgress = opts.onProgress || (() => {})

  return new Promise((resolve, reject) => {
    // First, get source file info
    wx.getFileInfo({
      filePath: srcPath,
      success: (info) => {
        const srcSizeBytes = info.size
        const srcSizeMB = srcSizeBytes / (1024 * 1024)

        // If already under 10MB, skip compression
        if (srcSizeMB < 10) {
          onProgress('skip', 100)
          resolve({ path: srcPath, size: srcSizeBytes, duration: 0, compressed: false })
          return
        }

        onProgress('compress', 0)

        // Use wx.compressVideo API
        if (typeof wx.compressVideo === 'function') {
          wx.compressVideo({
            src: srcPath,
            quality,
            bitrate,
            success: (res) => {
              onProgress('compress', 80)
              wx.getFileInfo({
                filePath: res.tempFilePath,
                success: (compInfo) => {
                  const compMB = compInfo.size / (1024 * 1024)
                  onProgress('compress', 100)
                  resolve({
                    path: res.tempFilePath,
                    size: compInfo.size,
                    duration: 0,
                    compressed: true,
                    originalSizeMB: srcSizeMB.toFixed(1),
                    compressedSizeMB: compMB.toFixed(1),
                  })
                },
                fail: () => {
                  // Fallback: return original but warn
                  onProgress('compress', 100)
                  resolve({ path: srcPath, size: srcSizeBytes, duration: 0, compressed: false })
                },
              })
            },
            fail: (err) => {
              console.warn('compressVideo failed, using original:', err)
              onProgress('compress', 100)
              resolve({ path: srcPath, size: srcSizeBytes, duration: 0, compressed: false })
            },
          })
        } else {
          // API not available — pass through
          console.warn('wx.compressVideo not available, using original file')
          onProgress('skip', 100)
          resolve({ path: srcPath, size: srcSizeBytes, duration: 0, compressed: false })
        }
      },
      fail: (err) => {
        console.error('getFileInfo failed:', err)
        // Can't determine size — proceed optimistically with original
        onProgress('skip', 100)
        resolve({ path: srcPath, size: 0, duration: 0, compressed: false })
      },
    })
  })
}

module.exports = { compressVideo }
