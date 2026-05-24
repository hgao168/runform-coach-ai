import SwiftUI
import os.signpost
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

@main
struct RunFormCoachAIApp: App {
    @StateObject private var appStore = AppStore()
    @State private var launchCompleted = false

    init() {
        // Mark the instant main() is entered for launch timing.
        PerformanceOptimizer.markMainEntry()
        // Start Google Mobile Ads SDK with test ad unit ID (only when available)
        #if canImport(GoogleMobileAds)
        // Start AdMob with test App ID. Wrapped defensively — a bad
        // GADApplicationIdentifier should not crash the whole app.
        GADMobileAds.sharedInstance().start { _ in }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appStore)
                .onAppear {
                    // First frame rendered — mark and start deferred work
                    if !launchCompleted {
                        launchCompleted = true
                        PerformanceOptimizer.markFirstFrameRender()

                        // Deferred non-critical initialization on a background Task.
                        // This runs AFTER first frame so the UI is already visible.
                        Task {
                            await PerformanceOptimizer.performDeferredInitialization()
                            PerformanceOptimizer.logLaunchReport()
                        }
                    }
                }
        }
    }
}
