# RunForm UI Facelift

This package refreshes the iOS app with a modern dark iPhone fitness-app style while keeping the existing analyze/history/profile flow intact.

## What changed

- New shared design system in `AppTheme.swift`
  - dark gradient background
  - glass cards
  - gradient buttons
  - icon bubbles
  - status badges
  - section titles
- Redesigned `ContentView.swift`
  - stronger hero section
  - clearer upload card
  - better recording guide
  - polished buttons and state banners
- Redesigned `AnalysisResultView.swift`
  - cleaner confidence ring
  - improved video quality card
  - better metric cards
  - issue-based exercise cards with “why this helps” highlighted
- Redesigned `HistoryView.swift`
  - dark style history list
  - improved empty state
  - polished result detail page
- Redesigned `ProfileView.swift`
  - dark profile form
  - cleaner runner setup controls
- Redesigned `FeedbackView.swift`
  - nicer feedback card matching the app
- App icon assets are included under `Assets.xcassets/AppIcon.appiconset`.

## Files to copy into your repo

```bash
cp -R ios/RunFormCoachAI/* /path/to/runform-coach-ai/ios/RunFormCoachAI/
```

Then open the project in Xcode, clean build folder, and run.

## Suggested git flow

```bash
git checkout -b ui-facelift
cp -R ios/RunFormCoachAI/* ../runform-coach-ai/ios/RunFormCoachAI/
git add ios/RunFormCoachAI
git commit -m "Refresh iOS app UI"
git push origin ui-facelift
```
