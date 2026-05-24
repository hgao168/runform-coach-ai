Summary of fixes pushed to staging:

Commit	Fix
b4309bf	Reverted bundle ID to com.movex.runformcoachai in project.yml and IOS_APP_BUNDLE_ID env in both ios-staging.yml and ios-build.yml to match the existing RunFormCoachAI-Prod provisioning profile
7f6e517	Removed stale duplicate ios/project.yml (CI uses root project.yml)
05f10dc	Swift 6 fixes: Swift.min(...) in RingBuffer.swift; inlined timer?.invalidate() in deinit of RunSessionReplayView.swift (deinit can't call a @MainActor method)
c4248ab	Added self.makeMultipartBody(...) in APIClient.swift; moved .frame(height: 50) inside the #if DEBUG/#else block in AnalysisResultView.swift so the modifier binds to the AdBanner expression

Additional review notes (non-blocking):

actions/checkout@v4 is still emitting a Node 20 deprecation warning — bump when next touching workflows.
Info.plist has a placeholder GADApplicationIdentifier (ca-app-pub-XXXXXXXX~XXXXXXXX). Currently safe because GoogleMobileAds is not linked (no SPM package in root project.yml, and source is #if canImport(GoogleMobileAds)-guarded), but replace before re-enabling AdMob.
ios-test.yml runs xcodebuild test -scheme RunFormCoachAI but root project.yml defines no test target, so XCTests don’t actually execute on CI. Add a test target to root project.yml if you want tests running.
Internal "com.runformcoachai.*" strings (DispatchQueue labels, os.Logger subsystem, cache paths) are unrelated to bundle ID and safe to keep.