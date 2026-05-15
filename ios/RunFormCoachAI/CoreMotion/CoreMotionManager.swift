import CoreMotion
import Foundation
import os.log

// MARK: - SensorFrame

/// A single raw sensor sample captured at 100 Hz.
/// Contains unfiltered accelerometer and gyroscope data with a monotonic timestamp.
public struct SensorFrame: Sendable {
    /// Timestamp in seconds since the device booted (mach_absolute_time).
    public let timestamp: TimeInterval

    /// Raw accelerometer data (g-force).  x = lateral, y = longitudinal, z = vertical.
    public let accelerationX: Double
    public let accelerationY: Double
    public let accelerationZ: Double

    /// Raw gyroscope data (rad/s).  x = pitch rate, y = roll rate, z = yaw rate.
    public let rotationRateX: Double
    public let rotationRateY: Double
    public let rotationRateZ: Double

    public init(
        timestamp: TimeInterval,
        accelerationX: Double,
        accelerationY: Double,
        accelerationZ: Double,
        rotationRateX: Double,
        rotationRateY: Double,
        rotationRateZ: Double
    ) {
        self.timestamp = timestamp
        self.accelerationX = accelerationX
        self.accelerationY = accelerationY
        self.accelerationZ = accelerationZ
        self.rotationRateX = rotationRateX
        self.rotationRateY = rotationRateY
        self.rotationRateZ = rotationRateZ
    }
}

// MARK: - CoreMotionManager

/// Wraps `CMMotionManager` and exposes a continuous `AsyncStream<SensorFrame>` at 100 Hz.
///
/// Usage:
/// ```swift
/// let manager = CoreMotionManager()
/// Task {
///     for await frame in manager.startUpdates() {
///         // process frame at ~100 Hz
///     }
/// }
/// // When done:
/// manager.stopUpdates()
/// ```
public final class CoreMotionManager: @unchecked Sendable {

    // MARK: - Public properties

    /// Whether the manager is currently delivering frames.
    public var isActive: Bool {
        queue.sync { _active }
    }

    /// The configured sampling rate in Hz (default 100).
    public let samplingRate: Double

    /// Whether device motion is available on this hardware.
    public var isDeviceMotionAvailable: Bool {
        motionManager.isDeviceMotionAvailable
    }

    // MARK: - Private

    private let motionManager: CMMotionManager
    private let samplingQueue: OperationQueue
    private let queue = DispatchQueue(label: "com.runformcoachai.coremotion.sync")
    private var _active = false
    private var continuation: AsyncStream<SensorFrame>.Continuation?

    // MARK: - Init

    /// - Parameter samplingRate: Target sampling rate in Hz (default 100).  Clamped to hardware max ~ 100.
    public init(samplingRate: Double = 100) {
        self.samplingRate = min(samplingRate, 100)
        self.motionManager = CMMotionManager()

        let opQueue = OperationQueue()
        opQueue.name = "com.runformcoachai.coremotion.sampling"
        opQueue.maxConcurrentOperationCount = 1
        opQueue.qualityOfService = .userInteractive
        self.samplingQueue = opQueue
    }

    // MARK: - Public API

    /// Start device-motion updates and return an `AsyncStream<SensorFrame>`.
    ///
    /// Frames are delivered at the configured `samplingRate`.  The stream terminates when
    /// `stopUpdates()` is called or when the `CMMotionManager` hardware stops.
    ///
    /// - Precondition: Call this only once per manager instance.
    /// - Returns: A stream that yields `SensorFrame` values indefinitely.
    public func startUpdates() -> AsyncStream<SensorFrame> {
        AsyncStream { [weak self] continuation in
            guard let self else {
                continuation.finish()
                return
            }

            self.queue.sync {
                self._active = true
                self.continuation = continuation

                self.motionManager.deviceMotionUpdateInterval = 1.0 / self.samplingRate

                self.motionManager.startDeviceMotionUpdates(
                    to: self.samplingQueue
                ) { [weak self] deviceMotion, error in
                    guard let self, self._active else {
                        continuation.finish()
                        return
                    }

                    if let error {
                        // Log the error but continue – transient sensor errors
                        // should not tear down the stream.
                        os_log(
                            .error,
                            log: .default,
                            "CoreMotionManager: sensor error – %{public}@",
                            error.localizedDescription
                        )
                        return
                    }

                    guard let motion = deviceMotion else { return }

                    let frame = SensorFrame(
                        timestamp: motion.timestamp,
                        accelerationX: motion.userAcceleration.x,
                        accelerationY: motion.userAcceleration.y,
                        accelerationZ: motion.userAcceleration.z,
                        rotationRateX: motion.rotationRate.x,
                        rotationRateY: motion.rotationRate.y,
                        rotationRateZ: motion.rotationRate.z
                    )

                    continuation.yield(frame)
                }
            }

            continuation.onTermination = { [weak self] _ in
                self?.stopUpdates()
            }
        }
    }

    /// Stop device-motion updates and tear down the stream.
    public func stopUpdates() {
        queue.sync {
            guard _active else { return }
            _active = false
            motionManager.stopDeviceMotionUpdates()
            continuation?.finish()
            continuation = nil
        }
    }
}
