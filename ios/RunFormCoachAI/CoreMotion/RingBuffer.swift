import Foundation

// MARK: - RingBuffer

/// A thread-safe, fixed-capacity circular buffer.
///
/// When full, appending a new element silently overwrites the oldest element.
/// Designed for high-throughput sensor pipelines (e.g. 100 Hz CoreMotion data).
///
/// Usage:
/// ```swift
/// var buffer = RingBuffer<SensorFrame>(capacity: 600)
/// buffer.append(frame)
/// let latest6s = buffer.all()  // up to 600 frames
/// let last100 = buffer.last(100)
/// ```
public struct RingBuffer<Element>: @unchecked Sendable {

    // MARK: - Private storage

    private final class Storage: @unchecked Sendable {
        var buffer: [Element?]
        var head: Int = 0   // next write position
        var count: Int = 0
        let capacity: Int
        let lock = os_unfair_lock_t.allocate(capacity: 1)

        init(capacity: Int, repeatedValue: Element.Type) {
            self.capacity = capacity
            self.buffer = Array<Element?>(repeating: nil, count: capacity)
            self.lock.initialize(to: os_unfair_lock())
        }

        deinit {
            lock.deinitialize(count: 1)
            lock.deallocate()
        }

        func synchronized<T>(_ block: () throws -> T) rethrows -> T {
            os_unfair_lock_lock(lock)
            defer { os_unfair_lock_unlock(lock) }
            return try block()
        }
    }

    private let storage: Storage

    // MARK: - Public properties

    /// Maximum number of elements the buffer can hold.
    public var capacity: Int { storage.capacity }

    /// Current number of elements in the buffer.
    public var count: Int {
        storage.synchronized { storage.count }
    }

    /// Whether the buffer is full (count == capacity).
    public var isFull: Bool {
        storage.synchronized { storage.count == storage.capacity }
    }

    /// Whether the buffer is empty.
    public var isEmpty: Bool {
        storage.synchronized { storage.count == 0 }
    }

    // MARK: - Init

    /// Create a ring buffer with the specified capacity.
    /// - Parameter capacity: Maximum number of elements (default 600 ≈ 6s at 100 Hz).
    public init(capacity: Int = 600) {
        precondition(capacity > 0, "RingBuffer capacity must be > 0")
        self.storage = Storage(capacity: capacity, repeatedValue: Element.self)
    }

    // MARK: - Write

    /// Append a single element. Overwrites the oldest element when the buffer is full.
    public mutating func append(_ element: Element) {
        storage.synchronized {
            storage.buffer[storage.head] = element
            storage.head = (storage.head + 1) % storage.capacity
            if storage.count < storage.capacity {
                storage.count += 1
            }
        }
    }

    /// Append a sequence of elements. Each exceeds-capacity write overwrites the oldest.
    public mutating func append(contentsOf elements: some Sequence<Element>) {
        for element in elements {
            append(element)
        }
    }

    // MARK: - Read

    /// Return all elements in FIFO order (oldest → newest).
    /// - Complexity: O(capacity).
    public func all() -> [Element] {
        storage.synchronized {
            var result: [Element] = []
            result.reserveCapacity(storage.count)
            let start = storage.count < storage.capacity
                ? 0
                : storage.head
            for i in 0..<storage.count {
                let idx = (start + i) % storage.capacity
                if let element = storage.buffer[idx] {
                    result.append(element)
                }
            }
            return result
        }
    }

    /// Return the most recent `n` elements (newest last).
    /// If `n` exceeds the current count, returns all elements.
    /// - Complexity: O(n).
    public func last(_ n: Int) -> [Element] {
        storage.synchronized {
            let limit = Swift.min(n, storage.count)
            guard limit > 0 else { return [] }
            var result: [Element] = []
            result.reserveCapacity(limit)
            // Walk backwards from (head - 1) then reverse
            for offset in 0..<limit {
                let idx = (storage.head - 1 - offset + storage.capacity) % storage.capacity
                if let element = storage.buffer[idx] {
                    result.append(element)
                }
            }
            return result.reversed()
        }
    }

    /// Return the element at the given logical index (0 = oldest, count-1 = newest).
    /// Returns `nil` if the index is out of bounds.
    public subscript(index: Int) -> Element? {
        storage.synchronized {
            guard index >= 0, index < storage.count else { return nil }
            let start = storage.count < storage.capacity
                ? 0
                : storage.head
            let physical = (start + index) % storage.capacity
            return storage.buffer[physical]
        }
    }

    /// Return the oldest element, or `nil` if empty.
    public var oldest: Element? {
        self[0]
    }

    /// Return the newest element, or `nil` if empty.
    public var newest: Element? {
        storage.synchronized {
            guard storage.count > 0 else { return nil }
            let idx = (storage.head - 1 + storage.capacity) % storage.capacity
            return storage.buffer[idx]
        }
    }

    // MARK: - Mutate

    /// Remove all elements.
    public mutating func reset() {
        storage.synchronized {
            storage.head = 0
            storage.count = 0
            // Clear references to allow deallocation
            for i in 0..<storage.capacity {
                storage.buffer[i] = nil
            }
        }
    }
}

// MARK: - Sequence conformance

extension RingBuffer: Sequence {
    public typealias Iterator = RingBufferIterator<Element>

    public func makeIterator() -> RingBufferIterator<Element> {
        RingBufferIterator(buffer: self)
    }
}

public struct RingBufferIterator<Element>: IteratorProtocol {
    private let snapshot: [Element]
    private var index = 0

    fileprivate init(buffer: RingBuffer<Element>) {
        self.snapshot = buffer.all()
    }

    public mutating func next() -> Element? {
        guard index < snapshot.count else { return nil }
        defer { index += 1 }
        return snapshot[index]
    }
}
