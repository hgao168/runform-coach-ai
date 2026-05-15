package com.runformcoach.runformcoachai.sensor

import java.util.concurrent.locks.ReentrantReadWriteLock
import kotlin.concurrent.read
import kotlin.concurrent.write

/**
 * 线程安全的泛型环形缓冲区（固定容量）。
 *
 * 容量设为 300 时，在 50 Hz 采样率下正好覆盖 6 秒窗口。
 *
 * @param T       元素类型
 * @param capacity 最大容量，构造后不可变
 *
 * 用法：
 * ```
 * val buffer = RingBuffer<SensorFrame>(capacity = 300)
 * buffer.add(frame)
 * val snapshot: List<SensorFrame> = buffer.getAll()
 * ```
 */
class RingBuffer<T>(val capacity: Int) {

    init {
        require(capacity > 0) { "容量必须大于 0，实际: $capacity" }
    }

    @Suppress("UNCHECKED_CAST")
    private val elements = arrayOfNulls<Any?>(capacity) as Array<T?>

    /** 下次写入位置，范围 [0, capacity) */
    private var writeIndex = 0

    /** 当前已存储的元素数量，范围 [0, capacity] */
    private var count = 0

    private val lock = ReentrantReadWriteLock()

    // ── 写入 ─────────────────────────────────────────────────────────────────

    /**
     * 向缓冲区追加一个元素。缓冲区满时会覆盖最旧的元素。
     */
    fun add(element: T) {
        lock.write {
            elements[writeIndex] = element
            writeIndex = (writeIndex + 1) % capacity
            if (count < capacity) {
                count++
            }
        }
    }

    // ── 读取 ─────────────────────────────────────────────────────────────────

    /**
     * 返回缓冲区中所有元素的快照，按插入顺序排列（最旧 → 最新）。
     *
     * 复杂度 O(count)，返回的是 [ArrayList] 副本，后续写入不会影响它。
     */
    fun getAll(): List<T> {
        lock.read {
            if (count == 0) return emptyList()

            val result = ArrayList<T>(count)
            // 确定读取起点：未满时从 0 开始，满时从 writeIndex（最旧元素）开始
            val start = if (count < capacity) 0 else writeIndex
            for (i in 0 until count) {
                val idx = (start + i) % capacity
                elements[idx]?.let { result.add(it) }
            }
            return result
        }
    }

    /**
     * 返回最新的 [n] 个元素（插入顺序，最旧 → 最新）。
     *
     * 若 [n] 超过当前存储量，返回所有元素。
     * 若 [n] <= 0，返回空列表。
     */
    fun getLast(n: Int): List<T> {
        require(n >= 0) { "n 不能为负: $n" }
        lock.read {
            if (count == 0 || n == 0) return emptyList()
            val take = n.coerceAtMost(count)

            val result = ArrayList<T>(take)
            val startIdx = (writeIndex - take + capacity) % capacity
            for (i in 0 until take) {
                val idx = (startIdx + i) % capacity
                elements[idx]?.let { result.add(it) }
            }
            return result
        }
    }

    // ── 辅助 ─────────────────────────────────────────────────────────────────

    /** 清空缓冲区。 */
    fun clear() {
        lock.write {
            for (i in elements.indices) {
                elements[i] = null
            }
            writeIndex = 0
            count = 0
        }
    }

    /** 当前存储的元素数量。 */
    fun size(): Int = lock.read { count }

    /** 缓冲区是否已满（已覆盖过一次）。 */
    fun isFull(): Boolean = lock.read { count == capacity }

    /** 缓冲区是否为空。 */
    fun isEmpty(): Boolean = lock.read { count == 0 }

    /** 容量。 */
    fun capacity(): Int = capacity
}
