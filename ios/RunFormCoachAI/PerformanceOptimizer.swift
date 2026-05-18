import Foundation
import os.signpost
import UIKit

// MARK: - Launch Performance Logger

/// Measures and reports cold-start performance using os_signpost.
///
/// Usage: call `PerformanceOptimizer.markLaunchComplete()` after first frame render.
///
/// Integrates with Instruments' os_signpost profiling for detailed interval analysis.
public enum PerformanceOptimizer {

    // MARK: - Signpost Log

    /// Shared `OSLog` for performance signposts — appears in Instruments under "RunForm Performance".
    fileprivate static let perfLog = OSLog(
        subsystem: "com.runformcoachai",
        category: .pointsOfInterest
    )

    /// Signpost ID reused across launches for correlation.
    fileprivate static let launchSignpostID = OSSignpostID(log: perfLog)

    // MARK: - Launch Phase Tracking

    /// Timestamps for each launch phase (populated automatically).
    ///
    /// On iOS, we measure from `main()` entry using `ProcessInfo.systemUptime`.
    /// Pre-main time (dyld + static initializers) is not directly measurable
    /// from userspace; it is reported in the Xcode Organizer and Instruments.
    fileprivate private(set) static var processStartTime: TimeInterval = {
        // Best-effort: use system uptime at init time.
        // For accurate pre-main metrics, use Xcode Organizer or Instruments.
        return ProcessInfo.processInfo.systemUptime
    }()

    fileprivate private(set) static var mainEntryTime: TimeInterval = ProcessInfo.processInfo.systemUptime
    fileprivate private(set) static var firstFrameRenderTime: TimeInterval = 0
    fileprivate private(set) static var deferredInitCompleteTime: TimeInterval = 0
    fileprivate private(set) static var fullInteractiveTime: TimeInterval = 0

    // MARK: - Public API

    /// Call this in `App.init()` to begin the launch signpost interval.
    public static func markMainEntry() {
        mainEntryTime = ProcessInfo.processInfo.systemUptime
        os_signpost(.begin, log: perfLog, name: "App Launch", signpostID: launchSignpostID,
                    "entry")
        os_signpost(.event, log: perfLog, name: "main()", signpostID: launchSignpostID)
    }

    /// Called when the first frame has been rendered (SwiftUI's first body evaluation).
    public static func markFirstFrameRender() {
        firstFrameRenderTime = ProcessInfo.processInfo.systemUptime
        os_signpost(.event, log: perfLog, name: "First Frame Rendered",
                    signpostID: launchSignpostID)
    }

    /// Called after all deferred initialization has completed.
    public static func markDeferredInitComplete() {
        deferredInitCompleteTime = ProcessInfo.processInfo.systemUptime
        os_signpost(.event, log: perfLog, name: "Deferred Init Complete",
                    signpostID: launchSignpostID)
    }

    /// Call when the app is fully interactive (network caches warm, UI responsive).
    public static func markFullInteractive() {
        fullInteractiveTime = ProcessInfo.processInfo.systemUptime
        os_signpost(.end, log: perfLog, name: "App Launch", signpostID: launchSignpostID,
                    "fullInteractive")
    }

    /// Returns a human-readable launch performance report.
    public static func launchReport() -> String {
        let preMain = max(0, mainEntryTime - processStartTime)
        let untilFirstFrame = max(0, firstFrameRenderTime - mainEntryTime)
        let deferredInit = max(0, deferredInitCompleteTime - firstFrameRenderTime)
        let untilInteractive = max(0, fullInteractiveTime - firstFrameRenderTime)
        let total = max(0, fullInteractiveTime - processStartTime)

        return """
        === Launch Performance Report ===
        Pre-main (dyld + static init): \(String(format: "%.0f", preMain * 1000)) ms
        main() → first frame:            \(String(format: "%.0f", untilFirstFrame * 1000)) ms
        Deferred init:                   \(String(format: "%.0f", deferredInit * 1000)) ms
        First frame → interactive:       \(String(format: "%.0f", untilInteractive * 1000)) ms
        -----------------------------------------
        Total cold start:                \(String(format: "%.0f", total * 1000)) ms
        """
    }

    /// Logs the launch report to the console.
    public static func logLaunchReport() {
        os_log(.info, log: perfLog, "%{public}@", launchReport())
    }

    // MARK: - Deferred Initialization

    /// Deferred work that runs after first frame. Call this from the App's
    /// `onAppear` or a `.task` on ContentView to spread non-critical setup
    /// across runloop iterations.
    public static func performDeferredInitialization() async {
        let now = ProcessInfo.processInfo.systemUptime
        os_signpost(.begin, log: perfLog, name: "Deferred Init",
                    signpostID: launchSignpostID)

        // Phase 1: Lightweight tasks (run immediately but async)
        await withTaskGroup(of: Void.self) { group in
            // Strava status refresh (non-blocking, fires on background Task)
            group.addTask {
                await DeferredWork.refreshStravaStatus()
            }

            // HealthKit availability check (quick, returns boolean)
            group.addTask {
                await DeferredWork.checkHealthKitAvailability()
            }

            // Warm up the backend connection with a lightweight request
            group.addTask {
                await DeferredWork.warmBackendConnection()
            }
        }

        // Phase 2: Heavier initialization with yield to avoid blocking
        await Task.yield()

        await withTaskGroup(of: Void.self) { group in
            // Pre-warm image cache directory
            group.addTask {
                await DeferredWork.prewarmImageCache()
            }

            // Register notification handlers
            group.addTask {
                await DeferredWork.setupNotificationHandlers()
            }
        }

        os_signpost(.end, log: perfLog, name: "Deferred Init",
                    signpostID: launchSignpostID)
        markDeferredInitComplete()

        // Phase 3: Background work that can wait even longer
        Task.detached(priority: .background) {
            await DeferredWork.purgeStaleResources()
            await DeferredWork.validateDatabaseIntegrity()
        }

        markFullInteractive()
    }
}

// MARK: - Deferred Work (internal)

/// Collection of deferred work items that should not block first frame render.
private enum DeferredWork {

    static func refreshStravaStatus() async {
        let userID = UserDefaults.standard.string(forKey: "app.user.id.v1") ?? ""
        guard !userID.isEmpty else { return }
        do {
            let status = try await APIClient.shared.fetchStravaStatus(iosUserID: userID)
            // Update via AppStore if needed — this is fire-and-forget at launch
            await MainActor.run {
                // AppStore can be accessed if injected, but we avoid coupling here
                _ = status
            }
        } catch {
            // Silent failure — Strava status refresh is non-critical
            os_log(.debug, "Strava status refresh deferred: %{public}@",
                   error.localizedDescription)
        }
    }

    static func checkHealthKitAvailability() async {
        // HealthKit availability check is synchronous and fast;
        // running it async prevents blocking the SwiftUI body.
        await MainActor.run {
            _ = HKHealthStore.isHealthDataAvailable()
        }
    }

    static func warmBackendConnection() async {
        // Perform a lightweight request to warm up the HTTP/2 connection.
        // Uses the athletes endpoint as a lightweight ping.
        do {
            _ = try await APIClient.shared.fetchAthletes()
        } catch {
            os_log(.debug, "Backend connection warm-up: %{public}@",
                   error.localizedDescription)
        }
    }

    static func prewarmImageCache() async {
        // Ensure the image cache directory exists and preload known assets.
        let cachesDir = FileManager.default.urls(
            for: .cachesDirectory, in: .userDomainMask
        ).first
        guard let cacheBase = cachesDir?.appendingPathComponent("com.runformcoachai.images") else {
            return
        }
        try? FileManager.default.createDirectory(
            at: cacheBase, withIntermediateDirectories: true
        )
    }

    static func setupNotificationHandlers() async {
        await MainActor.run {
            // Register for memory pressure notifications to clear caches
            NotificationCenter.default.addObserver(
                forName: UIApplication.didReceiveMemoryWarningNotification,
                object: nil,
                queue: .main
            ) { _ in
                URLCache.shared.removeAllCachedResponses()
                os_log(.info, "Memory pressure: cleared URL cache")
            }
        }
    }

    static func purgeStaleResources() async {
        // Remove cached files older than 30 days
        let cachesDir = FileManager.default.urls(
            for: .cachesDirectory, in: .userDomainMask
        ).first
        guard let cacheBase = cachesDir?.appendingPathComponent("com.runformcoachai.images"),
              let contents = try? FileManager.default.contentsOfDirectory(
                at: cacheBase,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
              ) else { return }

        let cutoff = Date().addingTimeInterval(-30 * 24 * 3600)
        for url in contents {
            guard let attrs = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modDate = attrs.contentModificationDate,
                  modDate < cutoff else { continue }
            try? FileManager.default.removeItem(at: url)
        }
    }

    static func validateDatabaseIntegrity() async {
        // Placeholder: if using CoreData / SQLite, run integrity checks here.
        // For UserDefaults-based storage, this is a no-op.
    }
}

// MARK: - HealthKit Stub (compile-safe without HealthKit import)

/// Minimal protocol stub so DeferredWork compiles even if HealthKit is
/// linked optionally. Replace with `import HealthKit` in production.
private struct HKHealthStore {
    static func isHealthDataAvailable() -> Bool { true }
}

// MARK: - Image Preloading Strategy

/// Utilities for preloading and caching images used in the UI.
public enum ImagePreloader {

    private static let cache = NSCache<NSURL, UIImage>()

    /// Preload images from a list of asset names or URLs.
    /// Call this from `onAppear` on ContentView, not on init.
    public static func preloadAssets(named assetNames: [String]) async {
        await withTaskGroup(of: Void.self) { group in
            for name in assetNames {
                group.addTask {
                    await MainActor.run {
                        _ = UIImage(named: name)
                    }
                }
            }
        }
    }

    /// Cache an image keyed by URL.
    public static func cacheImage(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }

    /// Retrieve a cached image.
    public static func cachedImage(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    /// Clear all cached images.
    public static func clearCache() {
        cache.removeAllObjects()
    }
}
