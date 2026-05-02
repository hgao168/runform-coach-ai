# RunForm — Metrics Accuracy Update

This update improves running metrics reliability and avoids misleading cadence results such as `0 spm`.

## What changed

### iOS
- Added a recording-standard guide before video upload.
- Added on-device video quality checks using pose detection rate, ankle visibility, and duration.
- Improved `PoseExtractor.swift` cadence logic with adaptive ankle-motion signal analysis.
- If cadence cannot be measured reliably, the app now shows `Not measurable` instead of a fake/false `0 spm`.
- Sends only pose metrics JSON to the backend via `/analyze-metrics`.
- Shows a Video Quality card with reasons and re-record tips.
- Default backend URL set to Railway: `https://runform-coach-ai-production.up.railway.app`.

### Backend
- Added `VideoQuality` response model.
- Expanded `PoseMetricsInput` with cadence quality, ankle visibility, detection rate, and quality reasons.
- Improved `/analyze-metrics` coaching response to handle low-quality video and unmeasurable cadence.
- Keeps `/analyze` as a legacy raw-video fallback.

## Files to copy

```bash
ios/RunFormCoachAI/Models.swift
ios/RunFormCoachAI/PoseExtractor.swift
ios/RunFormCoachAI/APIClient.swift
ios/RunFormCoachAI/ContentView.swift
ios/RunFormCoachAI/AnalysisResultView.swift
backend/app/main.py
backend/app/schemas.py
backend/app/analyzer.py
backend/requirements.txt
```

## Suggested git flow

```bash
git checkout -b improve-running-metrics-accuracy
cp -R ios/RunFormCoachAI/* /path/to/runform-coach-ai/ios/RunFormCoachAI/
cp -R backend/* /path/to/runform-coach-ai/backend/
git add ios/RunFormCoachAI backend
git commit -m "Improve video quality checks and cadence reliability"
git push origin improve-running-metrics-accuracy
```

Then redeploy Railway and upload a new TestFlight build.
