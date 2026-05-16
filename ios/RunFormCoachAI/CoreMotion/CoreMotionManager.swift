import CoreMotion
import Foundation
import os.log

// MARK: - CoreMotionManager

/// Wraps `CMMotionManager` with separate accelerometer + gyroscope streams at configurable Hz.
/// Data is buffered into a `RingBuffer<SensorFrame>` for sliding-window analysis.
///
/// Supports iOS foreground-service-style persistent collection via
/// `allowsBackgroundUpdates` (requires HealthKit or location background mode entitlement).
///
/// Usage:
/// ```swift
/// let manager = CoreMotionManager(samplingRate: 60, windowSeconds: 6)
/// manager.onFrame = { frame in
///     // process each frame at ~60 Hz
/// }
/// manager.startUpdates()
/// // When done:
/// manager.stopUpdates()
/// ```
public final class CoreMotionManager: @unchecked Sendable {

    // MARK: - Public properties

    /// Whether the manager is currently delivering frames.
    public private(set) var isActive: Bool = false

    /// The configured sampling rate in Hz (default 60).
    public let samplingRate: Double

    /// Sliding-window buffer holding the most recent `windowSeconds` of frames.
    public private(set) var buffer: RingBuffer<SensorFrame>

    /// The window duration in seconds that the ring buffer covers.
    public let windowSeconds: TimeInterval

    /// Whether device motion is available on this hardware.
    public var isDeviceMotionAvailable: Bool {
        motionManager.isDeviceMotionAvailable
    }

    /// Whether accelerometer data is available.
    public var isAccelerometerAvailable: Bool {
        motionManager.isAccelerometerAvailable
    }

    /// Whether gyroscope data is available.
    public var isGyroAvailable: Bool {
        motionManager.isGyroAvailable
    }

    /// Callback invoked on each new `SensorFrame` (on the sampling queue, not main thread).
    public var onFrame: (@Sendable (SensorFrame) -> Void)?

    // MARK: - Private

    private let motionManager: CMMotionManager
    private let samplingQueue: OperationQueue
    private let queue = DispatchQueue(label: "com.runformcoachai.coremotion.sync")
    private var accelContinuation: AsyncStream<SensorFrame>.Continuation?
    private var bufferCapacity: Int

    // MARK: - Init

    /// - Parameters:
    ///   - samplingRate: Target sampling rate in Hz (default 60). Hardware max ~100.
    ///   - windowSeconds: Ring-buffer window duration in seconds (clamped 3–10, default 6).
    public init(samplingRate: Double = 60, windowSeconds: TimeInterval = 6) {
        self.samplingRate = min(samplingRate, 100)
        self.windowSeconds = max(3, min(10, windowSeconds))
        self.motionManager = CMMotionManager()
        self.bufferCapacity = max(Int(self.windowSeconds * self.samplingRate), 60)
        self.buffer = RingBuffer<SensorFrame>(capacity: bufferCapacity)

        let opQueue = OperationQueue()
        opQueue.name = "com.runformcoachai.coremotion.sampling"
        opQueue.maxConcurrentOperationCount = 1
        opQueue.qualityOfService = .userInteractive
        self.samplingQueue = opQueue
    }

    // MARK: - Public API

    /// Start separate accelerometer and gyroscope updates.
    ///
    /// Each callback produces a `SensorFrame` fusing the latest accel + gyro data.
    /// Frames are delivered at the configured `samplingRate`.
    ///
    /// For background collection, ensure your app has the necessary background mode
    /// entitlements (e.g., HealthKit or location) — this method will keep collecting
    /// while the app is in the foreground. With proper entitlements, iOS will extend
    /// execution in the background.
    public func startUpdates() {
        queue.sync {
            guard !isActive else { return }
            isActive = true

            motionManager.accelerometerUpdateInterval = 1.0 / samplingRate
            motionManager.gyroUpdateInterval = 1.0 / samplingRate

            // Shared timestamp for accel+gyro pairing
            var lastAccel: (x: Double, y: Double, z: Double, ts: TimeInterval)?
            var lastGyro: (x: Double, y: Double, z: Double, ts: TimeInterval)?

            let lock = os_unfair_lock_t.allocate(capacity: 1)
            lock.initialize(to: os_unfair_lock())

            motionManager.startAccelerometerUpdates(
                to: samplingQueue
            ) { [weak self] accelData, error in
                guard let self, self.isActive else { return }
                if let error {
                    os_log(.error, log: .default,
                           "CoreMotionManager: accelerometer error – %{public}@",
                           error.localizedDescription)
                    return
                }
                guard let accel = accelData else { return }

                os_unfair_lock_lock(lock)
                lastAccel = (accel.acceleration.x, accel.acceleration.y,
                             accel.acceleration.z, accel.timestamp)
                // Try to emit fused frame
                if let gyro = lastGyro, accel.timestamp - gyro.ts < 0.05 {
                    let frame = SensorFrame(
                        timestamp: accel.timestamp,
                        accelerationX: accel.acceleration.x,
                        accelerationY: accel.acceleration.y,
                        accelerationZ: accel.acceleration.z,
                        rotationRateX: gyro.x,
                        rotationRateY: gyro.y,
                        rotationRateZ: gyro.z
                    )
                    self.deliver(frame)
                }
                os_unfair_lock_unlock(lock)
            }

            motionManager.startGyroUpdates(
                to: samplingQueue
            ) { [weak self] gyroData, error in
                guard let self, self.isActive else { return }
                if let error {
                    os_log(.error, log: .default,
                           "CoreMotionManager: gyroscope error – %{public}@",
                           error.localizedDescription)
                    return
                }
                guard let gyro = gyroData else { return }

                os_unfair_lock_lock(lock)
                lastGyro = (gyro.rotationRate.x, gyro.rotationRate.y,
                            gyro.rotationRate.z, gyro.timestamp)
                // Try to emit fused frame
                if let accel = lastAccel, gyro.timestamp - accel.ts < 0.05 {
                    let frame = SensorFrame(
                        timestamp: gyro.timestamp,
                        accelerationX: accel.x,
                        accelerationY: accel.y,
                        accelerationZ: accel.z,
                        rotationRateX: gyro.rotationRate.x,
                        rotationRateY: gyro.rotationRate.y,
                        rotationRateZ: gyro.rotationRate.z
                    )
                    self.deliver(frame)
                }
                os_unfair_lock_unlock(lock)
            }
        }
    }

    /// Start updates and return an `AsyncStream<SensorFrame>` (convenience).
    /// - Returns: A stream that yields `SensorFrame` values indefinitely.
    public func startStream() -> AsyncStream<SensorFrame> {
        AsyncStream { [weak self] continuation in
            guard let self else {
                continuation.finish()
                return
            }
            self.queue.sync {
                self.accelContinuation = continuation
            }
            self.startUpdates()
            continuation.onTermination = { [weak self] _ in
                self?.stopUpdates()
            }
        }
    }

    /// Stop all sensor updates and tear down.
    public func stopUpdates() {
        queue.sync {
            guard isActive else { return }
            isActive = false
            motionManager.stopAccelerometerUpdates()
            motionManager.stopGyroUpdates()
            accelContinuation?.finish()
            accelContinuation = nil
        }
    }

    /// Get a snapshot of the current sensor buffer.
    public func bufferSnapshot() -> [SensorFrame] {
        buffer.all()
    }

    // MARK: - Private helpers

    private func deliver(_ frame: SensorFrame) {
        buffer.append(frame)
        onFrame?(frame)
        accelContinuation?.yield(frame)
    }
}
