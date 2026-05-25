// utils/exercise-video-map.js
// Curated B站 (Bilibili) video BV numbers for running-related exercises.
// Each entry maps an exercise name (English or Chinese) to a B站 video BV number.
// The full URL is: https://www.bilibili.com/video/{BV}

const EXERCISE_VIDEO_MAP = {
  "Ankle Mobility": "BV1iG4y117RT",
  "Banded Lateral Walk": "BV1U44y1W7gh",
  "Banded Walks": "BV1U44y1W7gh",
  "Bird Dog": "BV1HZ4y1W7L2",
  "Bodyweight Squat": "BV1Ax4y1W7BH",
  "Butt Kicks": "BV1HG411z7MX",
  "Calf Raises": "BV1WZ4y1H7Xj",
  "Clamshell": "BV1GJ4m1M7Mk",
  "Core Training": "BV1sW411v7q7",
  "Dead Bug": "BV1mF411z7d2",
  "Forward Lunge": "BV1Ni4y1R7Ec",
  "Glute Bridge": "BV1kF411F7YG",
  "High Knees": "BV1YJ4m1u7Ev",
  "Hip Mobility": "BV1JF411x7Cp",
  "Hip Thrust": "BV1ZG411r7qK",
  "Lunge": "BV1Ni4y1R7Ec",
  "Plank": "BV1sW411v7q7",
  "Quick Steps": "BV1Dt421K7xE",
  "Running Form": "BV1U5411u7Hf",
  "Side Plank": "BV1o54y1U7EG",
  "Single Leg Balance": "BV1vG411k7Sf",
  "Single Leg Calf Raises": "BV1WZ4y1H7Xj",
  "Single Leg Glute Bridge": "BV1kF411F7YG",
  "Single Leg Stance": "BV1vG411k7Sf",
  "Squat": "BV1Ax4y1W7BH",
  "Stretching": "BV1Dk4y167JJ",
  "Superman": "BV1eF411y7Ha",
  "Walking Lunge": "BV1Ni4y1R7Ec",
  "Wall Sit": "BV1bN4y1U7Wi",
  "侧平板支撑": "BV1o54y1U7EG",
  "单腿平衡": "BV1vG411k7Sf",
  "单腿提踵": "BV1WZ4y1H7Xj",
  "单腿站立": "BV1vG411k7Sf",
  "单腿臀桥": "BV1kF411F7YG",
  "后踢腿": "BV1HG411z7MX",
  "小步跑": "BV1Dt421K7xE",
  "平板支撑": "BV1sW411v7q7",
  "弓步蹲": "BV1Ni4y1R7Ec",
  "弹力带侧走": "BV1U44y1W7gh",
  "弹力带行走": "BV1U44y1W7gh",
  "拉伸": "BV1Dk4y167JJ",
  "提踵": "BV1WZ4y1H7Xj",
  "核心训练": "BV1sW411v7q7",
  "死虫式": "BV1mF411z7d2",
  "深蹲": "BV1Ax4y1W7BH",
  "臀推": "BV1ZG411r7qK",
  "臀桥": "BV1kF411F7YG",
  "自重深蹲": "BV1Ax4y1W7BH",
  "蚌式开合": "BV1GJ4m1M7Mk",
  "超人式": "BV1eF411y7Ha",
  "跑步姿势": "BV1U5411u7Hf",
  "踝关节活动度": "BV1iG4y117RT",
  "靠墙静蹲": "BV1bN4y1U7Wi",
  "髋关节活动度": "BV1JF411x7Cp",
  "高抬腿": "BV1YJ4m1u7Ev",
  "鸟狗式": "BV1HZ4y1W7L2",
};

/**
 * Get a curated B站 video URL for an exercise.
 * Falls back to B站 search if no curated video exists.
 * @param {string} exerciseName - Exercise name (e.g. "Glute Bridge", "臀桥")
 * @returns {string|null} B站 video URL or null
 */
function getCuratedVideoUrl(exerciseName) {
  if (!exerciseName) return null;
  
  // Exact match first
  if (EXERCISE_VIDEO_MAP[exerciseName]) {
    return `https://www.bilibili.com/video/${EXERCISE_VIDEO_MAP[exerciseName]}`;
  }
  
  // Case-insensitive match
  const lower = exerciseName.toLowerCase();
  for (const [key, bv] of Object.entries(EXERCISE_VIDEO_MAP)) {
    if (key.toLowerCase() === lower) {
      return `https://www.bilibili.com/video/${bv}`;
    }
  }
  
  // Partial match — check if exercise name contains a known key
  for (const [key, bv] of Object.entries(EXERCISE_VIDEO_MAP)) {
    if (lower.includes(key.toLowerCase()) || key.toLowerCase().includes(lower)) {
      return `https://www.bilibili.com/video/${bv}`;
    }
  }
  
  return null;
}

/**
 * Get the best video URL for an exercise.
 * Uses curated B站 video if available, otherwise falls back to B站 search.
 * For non-China users, returns YouTube search URL.
 * @param {string} exerciseName
 * @param {boolean} isChina - Whether the user is in China mainland
 * @returns {string} Video URL
 */
function getBestVideoUrl(exerciseName, isChina) {
  if (isChina) {
    const curated = getCuratedVideoUrl(exerciseName);
    if (curated) return curated;
    // Fallback to B站 search
    const query = encodeURIComponent(`${exerciseName} 动作教学`);
    return `https://search.bilibili.com/all?keyword=${query}&order=click`;
  }
  return `https://www.youtube.com/results?search_query=${encodeURIComponent(exerciseName + ' running exercise form')}`;
}

module.exports = {
  EXERCISE_VIDEO_MAP,
  getCuratedVideoUrl,
  getBestVideoUrl,
};
