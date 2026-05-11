Recommended Plan Page V2
1. Add Training Level Layer

Instead of only:

5K
10K
Half
Marathon

Make it:

Goal	Level	Duration
5K	Beginner / Intermediate / Advanced	8 / 12 weeks
10K	Beginner / Intermediate / Advanced	10 / 12 weeks
Half Marathon	Beginner / Intermediate / Advanced	12 / 16 weeks
Marathon	Beginner / Intermediate / Advanced	12 / 16 / 12 or 16 weeks user choose
General Fitness	Starter / Fat Loss / Endurance	Flexible

This immediately makes the app feel:

more premium
more coach-like
more personalized
2. Recommended Default Durations

Here’s what I’d recommend for your AI generation engine:

Goal	Beginner	Intermediate	Advanced
General Fitness	4–8 weeks	ongoing	ongoing
5K	8 weeks	10 weeks	12 weeks
10K	10 weeks	12 weeks	12 weeks
Half Marathon	12 weeks	14 weeks	16 weeks
Marathon	12 weeks	16 weeks	12 or 16 weeks or users choice 

This mirrors real coaching progression much better than fixed durations.

3. Add “Training Focus”

This is where your app becomes differentiated from generic plans.

After user selects race:

Improve Speed
Build Endurance
Injury Prevention
Weight Loss
Running Form Improvement
Return From Injury
Hybrid Strength + Running

This fits perfectly with your:

form analysis
strength recommendations
AI coaching direction

Most running apps DO NOT integrate biomechanics into training plans.

That is your moat.

4. Add AI Adaptive Layer (Big Opportunity)

Instead of static PDF-style plans:

Current industry:

“Week 4 = do this”

Your future direction:

“Your cadence dropped and fatigue increased last week, reducing interval load by 15%.”

This is where your app becomes:

AI coach
not training calendar

You already have foundations via:

video form analysis
movement metrics
strength recommendation direction
Strava integration

You should expose this on the Plan page visually.

5. Suggested UX Structure
Example UI
Goal
General Fitness
5K
10K
Half Marathon
Marathon
Experience
Beginner
Intermediate
Advanced
Duration
Recommended
Custom
Focus
Speed
Endurance
Form
Injury Prevention
Strength
Weekly Availability
3 days
4 days
5 days
6 days
AI Features

☑ Adaptive weekly adjustment
☑ Form-based workout suggestions
☑ Recovery monitoring
☑ Strength integration

6. Most Important Missing Feature

Right now your plans are likely:
“distance-centric”

You should evolve toward:
“runner-centric”

Meaning:

available time
injury risk
cadence stability
fatigue
form quality
strength imbalance
terrain
race target

all influence the plan.

That aligns perfectly with your MoveNova.ai direction.

7. My Highest Priority Recommendation

If you only implement ONE upgrade next:

Add:
Beginner / Intermediate / Advanced

AND

durations for every race

This alone dramatically improves perceived professionalism.

Example:

Goal	Available Plans
5K	8w Beginner / 10w Intermediate / 12w Advanced
10K	10w Beginner / 12w Intermediate / 12w Advanced
Half	12w Beginner / 16w Advanced
Marathon	12w / 16w / user choose either 12 weeks or 16 weeks

This is likely the highest ROI update for the current stage of your app.

---

Three distinct states now shown in the "Connected coaching" card:

| State | Subtitle displayed |
|---|---|
| No analysis, no Strava | "Generate an analysis or connect to Strava to personalise your plan." |
| No analysis, Strava connected | "Using your Strava runs to adjust plan." |
| Has analysis, no Strava | "Using your latest form analysis to adjust the plan." |
| Has analysis + Strava connected | "Using your latest form analysis and Strava runs to adjust plan." |

---

## Implementation Status (audit May 12, 2026)

### ✅ Done

- [x] **Training Level layer** — Beginner / Intermediate / Advanced picker added to Plan builder. `TrainingLevel` enum in `Models.swift`; UI in `PlanBuilderView.swift` (~L437).
- [x] **Recommended durations per goal × level** — matches spec table. `_getDurationOptionsForTarget` in `PlanBuilderView.swift` (~L878).
- [x] **Backend level scaling** — `_apply_level_scaling()` in `planner.py` scales weekly km by level.
- [x] **Weekly availability (3–6 days)** — `runningDaysPerWeek` + `selectedRunDays`.
- [x] **Connected coaching card — 4 distinct states** — see table above.
- [x] **Race day Sunday shows exact race distance** — 5K → 5.0 km, 10K → 10.0 km, Half → 21.1 km, Marathon → 42.2 km. `buildDisplayWorkouts(for:)` in both `RacePlanDetailView` and `MarathonPlanDetailView`.
- [x] **Hide "Long run: x km" on race day/week** — wrapped in `if !isRaceWeek` / `if !isRace` in both detail views.

### 🐛 Bugs fixed (May 12, 2026)

- [x] **Marathon race-week target showed hardcoded `47.7 km`** — replaced with `42.2 km` to match the actual race distance, mirroring 5K/10K/Half plans.
- [x] **Marathon race-week silently rewrote Saturday workout** — removed the hardcoded "5.5 km easy run" Saturday override. Saturday is now left to the backend planner's taper logic (consistent with 5K/10K/Half race-week behavior, which only overrides Sunday).

### 📋 TODO — not yet implemented (from spec sections 3, 4, 5)

- [ ] **Training Focus selector** (spec §3) — add `TrainingFocus` enum + UI control + backend field. Options: Improve Speed, Build Endurance, Injury Prevention, Weight Loss, Running Form Improvement, Return From Injury, Hybrid Strength + Running. *No code exists yet.*
- [ ] **Custom duration option** (spec §5) — currently only "Recommended" durations are exposed in the Picker. Add a "Custom" toggle that lets the user pick any number of weeks within a sensible range.
- [ ] **AI Features toggles on Plan page** (spec §5) — visible checkboxes:
  - [ ] Adaptive weekly adjustment
  - [ ] Form-based workout suggestions
  - [ ] Recovery monitoring
  - [ ] Strength integration
- [ ] **AI Adaptive Layer messaging** (spec §4) — surface AI-driven plan adjustments on the Plan page with human-readable reasoning (e.g., *"Your cadence dropped 4% and fatigue rose last week — reducing interval load by 15%."*). Backend hooks (auto-injury detection from logged outcomes) exist, but the UI does not currently show the *reasoning* for adjustments.
- [ ] **Marathon duration picker — level-aware** (consistency fix) — currently always returns `[12, 16]` regardless of level. Decide whether to keep "user choice" semantics (current) or filter by level like 5K/10K/Half. Add code comment either way to document the intent.

### ⏭️ Deferred / out of scope

- "Most Important Missing Feature" runner-centric inputs (cadence stability, fatigue, form quality, strength imbalance, terrain) — these depend on broader data plumbing (form analysis history + Strava streams). Track separately if/when prioritized.

