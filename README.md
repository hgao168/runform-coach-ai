# RunForm — Phase 1 Cool iPhone UI + App Icon Build

This package updates the Phase 1 TestFlight build with a shorter iPhone display name and a refreshed modern fitness-app UI.

## What changed

- App display name changed to **RunForm** so it fits cleanly under the iPhone icon.
- Added full iOS **AppIcon.appiconset** generated from the approved RunForm icon.
- Redesigned Analyze tab with dark navy gradient, glass cards, mint/cyan action style and iPhone-native feel.
- Redesigned result cards with confidence ring, movement metrics, and strength recommendations.
- Redesigned History and Profile screens with cleaner card layout.
- Preserved Phase 1 functionality: upload video, analyze, save local history, capture tester feedback and profile.

## Files changed

```text
ios/RunFormCoachAI/
├── Assets.xcassets/AppIcon.appiconset/  # new app icon set
├── AppTheme.swift                       # new shared UI theme
├── ContentView.swift                    # redesigned main coach UI
├── AnalysisResultView.swift             # redesigned result + strength plan
├── FeedbackView.swift                   # redesigned feedback card
├── HistoryView.swift                    # redesigned history
└── ProfileView.swift                    # redesigned profile

project.yml                              # CFBundleDisplayName = RunForm
```

## How to apply

Copy these files into your GitHub repo, then regenerate/open the Xcode project as you normally do.

```bash
git checkout -b ui-refresh-runform-icon
cp -R ios/RunFormCoachAI/* /path/to/your/repo/ios/RunFormCoachAI/
cp project.yml /path/to/your/repo/project.yml
git add ios/RunFormCoachAI project.yml
git commit -m "Add RunForm app icon and modern iPhone UI refresh"
git push origin ui-refresh-runform-icon
```

Then rebuild and upload a new TestFlight build.
