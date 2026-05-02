# RunForm Phase 4 — Training Plan Inputs

Drop-in update for `https://github.com/hgao168/runform-coach-ai`.

## Adds

- Backend endpoint: `POST /training-plan`
- Training plan input model:
  - current weekly km
  - target: 5K / 10K / Half Marathon / General Fitness
  - available running days
  - injury flag
- SwiftUI `PlanBuilderView`
- TabView with Analyze + Plan
- Output workouts:
  - easy run
  - quality run when injury flag is off and enough days are available
  - long run
  - strength / mobility days

## Copy files

```bash
cp backend/app/schemas.py /path/to/runform-coach-ai/backend/app/schemas.py
cp backend/app/planner.py /path/to/runform-coach-ai/backend/app/planner.py
cp backend/app/main.py /path/to/runform-coach-ai/backend/app/main.py
cp ios/RunFormCoachAI/Models.swift /path/to/runform-coach-ai/ios/RunFormCoachAI/Models.swift
cp ios/RunFormCoachAI/APIClient.swift /path/to/runform-coach-ai/ios/RunFormCoachAI/APIClient.swift
cp ios/RunFormCoachAI/ContentView.swift /path/to/runform-coach-ai/ios/RunFormCoachAI/ContentView.swift
cp ios/RunFormCoachAI/PlanBuilderView.swift /path/to/runform-coach-ai/ios/RunFormCoachAI/PlanBuilderView.swift
```

Then commit, redeploy Railway, regenerate Xcode project if you use XcodeGen, and upload a new TestFlight build.
