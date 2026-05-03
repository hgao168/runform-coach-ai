# RunForm Phase 5A Fix — True Analyze → Plan Connection

Apply this from the root of your latest GitHub repo:

```bash
python apply_phase5a_true_connected_plan.py
```

What it changes:

- iOS `TrainingPlanInput` now sends:
  - `form_issues`
  - `recommended_exercises`
- iOS `PlanBuilderView` reads the latest analysis from `appStore.history.first`.
- The Plan page shows a small “Connected coaching” card.
- Backend `TrainingPlanInput` accepts `form_issues` and `recommended_exercises`.
- Backend `/training-plan` passes those into the LLM and deterministically enhances workout details, purpose, and notes.
- Injury flag replaces hard workouts with easy running + mobility.

After applying:

```bash
git diff
git add ios/RunFormCoachAI backend/app
git commit -m "Connect latest form analysis to training plan"
git push
```

Then redeploy Railway and rebuild iOS/TestFlight.
