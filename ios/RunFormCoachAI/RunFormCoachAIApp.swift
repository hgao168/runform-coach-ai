import SwiftUI
import os.signpost

@main
struct RunFormCoachAIApp: App {
    @StateObject private var appStore = AppStore()
    @State private var launchCompleted = false

    init() {
        // Mark the instant main() is entered for launch timing.
        PerformanceOptimizer.markMainEntry()
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
