import SwiftUI
import os.signpost

@main
struct RunFormCoachAIApp: App {
    @StateObject private var appStore = AppStore()
    @State private var launchCompleted = false

    init() {
        PerformanceOptimizer.markMainEntry()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appStore)
                .onAppear {
                    if !launchCompleted {
                        launchCompleted = true
                        PerformanceOptimizer.markFirstFrameRender()
                        // Hotfix: keep launch path minimal to avoid startup-time crashes
                        // from non-critical deferred background initialization.
                        PerformanceOptimizer.markDeferredInitComplete()
                        PerformanceOptimizer.markFullInteractive()
                        PerformanceOptimizer.logLaunchReport()
                    }
                }
        }
    }
}
