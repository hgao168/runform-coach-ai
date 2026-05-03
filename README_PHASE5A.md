# RunForm Phase 5A — Connect Analyze → Plan

This patch makes the Training Plan use the latest Analysis result as coaching context.

## What it adds

### iOS
- Adds `FormIssueContext` to send latest form issues to the backend.
- Adds computed properties in `AppStore`:
  - `latestCoachingIssues`
  - `latestAnalysisSummary`
  - `latestAnalysisConfidence`
- Adds a **Connected coaching** card to the Plan tab.
- When user taps **Generate Plan**, the request includes latest form issues from History.
- Workout cards can show `Form focus` when backend returns it.

### Backend
- Extends `/training-plan` input with:
  - `form_issues`
  - `recent_analysis_summary`
  - `recent_analysis_confidence`
- Adds deterministic mapping from latest form issue to plan focus:
  - Overstride → shorter stride + cadence drills
  - Trunk lean → posture/falling-start focus
  - Hip drop → glute/hip stability focus
  - Knee valgus → knee tracking + hip control focus
  - Arm swing → relaxed elbow-drive focus
- Adds `coaching_focus` to workouts.
- Adds `connected_analysis_used` to response.

## How to apply

From your local repo root:

```bash
python apply_phase5a_connected_plan.py
```

Then check and commit:

```bash
git diff
git add ios/RunFormCoachAI backend/app
git commit -m "Connect analysis results to adaptive training plan"
git push
```

## Test flow

1. Open app.
2. Analyze a running video.
3. Go to Plan tab.
4. Confirm the **Connected coaching** card shows recent issues.
5. Generate plan.
6. Confirm workouts include form-specific details and `Form focus`.

## Deploy

- Redeploy Railway after backend changes.
- Build and upload new TestFlight version after iOS changes.
