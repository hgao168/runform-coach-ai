Your current RunForm direction is already strong:

* SwiftUI frontend
* FastAPI backend on Railway
* Analyze / History / Plan / Profile tabs
* Video upload + pose analysis
* Initial metrics + coaching recommendations

The biggest opportunity now is:

> move from “video analyzer” → “continuous AI running coach platform”

Based on your current state, the Loopwijzer coaching framework, and your existing roadmap, here’s how I’d break down the updates.

---

# Recommended Product Evolution

## Current State (V1)

You already have:

* video upload
* pose estimation
* some metrics
* recommendations
* history
* basic plans

This is enough for MVP/TestFlight.

Now focus on:

1. analysis quality
2. coaching loop
3. engagement
4. retention
5. premium differentiation

---

# Proposed Product Architecture

```text id="x7n2l9"
Record Run
    ↓
AI Pose Extraction
    ↓
Metric Engine
    ↓
Issue Detection Engine
    ↓
Coach Recommendation Engine
    ↓
Strength / Mobility Plan
    ↓
Progress Tracking
    ↓
Adaptive AI Coaching
```

---

# Recommended Breakdown

# Phase 1 — Fix Analysis Reliability (MOST IMPORTANT)

You already identified this correctly.

## Goal

Make analysis trustworthy.

Without this:

* users won’t trust recommendations
* retention dies quickly

---

## 1. Video Recording Guidance Mode

### Build first

Inspired by:

* Nike Run Club
* Runna
* AR body scanners

### Features

* full-body detection
* feet visible check
* side-view validation
* distance validation
* lighting validation
* “move back”
* “camera too low”
* “runner not centered”

### Why critical

Your metric accuracy depends heavily on video quality.

This is probably the single highest ROI feature right now.

---

## 2. Improve Metric Detection Stability

Current likely issues:

* cadence = 0
* unstable pose points
* frame drops
* left/right swaps

### Add:

* confidence scoring
* smoothing filter
* multi-frame averaging
* bad-frame rejection
* confidence heatmap

---

## 3. Add Video Quality Score

Example:

```text id="nwp7lu"
Video Quality: 82/100

Issues:
- feet partially outside frame
- low lighting
- side angle not ideal
```

This prevents “AI is wrong” complaints.

---

# Phase 2 — Structured Coaching Engine

This is where Loopwijzer becomes powerful.

---

# Build a Problem → Cause → Solution Framework

## Example

```text id="2h4x7m"
Problem:
Low cadence

Likely Causes:
- overstriding
- weak stiffness
- slow arm rhythm

Recommendations:
- fast feet drill
- cadence metronome
- calf pogo jumps

Strength:
- split squat
- calf raises

Mobility:
- ankle mobility
```

---

# Suggested Internal Data Model

```json
{
  "issue": "low_cadence",
  "severity": 0.72,
  "confidence": 0.88,
  "causes": [
    "overstride",
    "slow_leg_recovery"
  ],
  "recommendations": [
    "fast_feet",
    "cadence_drill"
  ],
  "strength": [
    "split_squat"
  ],
  "mobility": [
    "ankle_mobility"
  ]
}
```

This becomes the heart of your coaching system.

---

# Phase 3 — Expand Metrics

Right now you should NOT try to detect everything.

Prioritize high-confidence/high-value metrics.

---

# Recommended Metric Priority

## Tier 1 (Now)

Easy to detect reliably.

| Metric               | Value     |
| -------------------- | --------- |
| Cadence              | VERY HIGH |
| Torso lean           | HIGH      |
| Vertical oscillation | HIGH      |
| Head posture         | HIGH      |
| Arm symmetry         | HIGH      |
| Foot strike          | HIGH      |
| Knee lift            | HIGH      |

---

## Tier 2

Needs better pose quality.

| Metric                  | Value     |
| ----------------------- | --------- |
| Hip drop                | VERY HIGH |
| Dynamic valgus          | VERY HIGH |
| Ground contact estimate | HIGH      |
| Stride length           | HIGH      |
| Left/right asymmetry    | HIGH      |

---

## Tier 3

Advanced ML later.

| Metric            | Value   |
| ----------------- | ------- |
| Running economy   | PREMIUM |
| Injury prediction | PREMIUM |
| Fatigue detection | PREMIUM |
| Elastic return    | PREMIUM |

---

# Phase 4 — Training Recommendation Engine

This is your biggest differentiator.

Most apps only say:

> “Your cadence is low.”

Very few say:

> WHY + WHAT TO FIX + HOW TO TRAIN

---

# Recommendation Layers

## Layer 1

Immediate cues

```text id="5prmq1"
Run with shorter steps.
```

---

## Layer 2

Drills

```text id="glukvt"
Fast feet drill
A-skip
Wall drill
```

---

## Layer 3

Strength training

```text id="9jlyvu"
Bulgarian split squat
Single-leg RDL
Calf pogo jumps
```

---

## Layer 4

Mobility

```text id="8w4j9s"
Hip flexor stretch
Ankle mobility
Thoracic opener
```

---

# Phase 5 — Progress Tracking (Retention Engine)

This is what turns your app from:

* “used once”
  to
* “daily coaching app”

---

# Add Trend Tracking

## Example

```text id="kz1x31"
Cadence:
158 → 164 → 169

Hip Drop:
Moderate → Mild

Vertical Oscillation:
Reduced 12%
```

---

# Add “Improvement Journey”

```text id="46qazx"
Week 1:
Overstriding detected

Week 4:
Improved cadence by 7%

Week 8:
Ground contact reduced
```

This massively increases engagement.

---

# Phase 6 — AI Coach Personality

VERY IMPORTANT for premium feel.

Instead of generic reports:

```text id="dxl6bn"
Your right hip drops during stance phase.
This usually indicates glute instability and causes energy leakage.

Focus this week:
- single-leg balance
- lateral glute activation
- cadence target: 170
```

This is where GPT adds huge value.

---

# Phase 7 — Feature Differentiators

These can separate RunForm from generic apps.

---

## 1. Real-Time Audio Coaching

Example:

* “Shorter steps”
* “Relax shoulders”
* “Cadence improving”

Apple Watch later.

---

## 2. Side-by-Side Comparison

Compare:

* before/after
* elite runner overlay
* user progress

---

## 3. Coach Review Marketplace

Future premium feature:

* AI analysis first
* human coach review upsell

VERY strong business model.

---

## 4. Injury Risk Engine

Based on:

* asymmetry
* hip drop
* overstride
* contact time

---

# Proposed Engineering Breakdown

# Backend Modules

## 1. Pose Engine

```text id="3a0o7v"
video → keypoints
```

---

## 2. Metrics Engine

```text id="o3s3x8"
keypoints → cadence / lean / symmetry
```

---

## 3. Rule Engine

```text id="6yvx0r"
metrics → detected issues
```

---

## 4. Recommendation Engine

```text id="klw0oz"
issues → drills / strength / mobility
```

---

## 5. AI Coaching Layer

```text id="akq83w"
structured findings → natural coaching
```

---

# Best Next Sprint (What I Recommend You Build NOW)

## Sprint 1

### Highest ROI

### MUST HAVE

* video guidance mode
* better cadence stability
* video quality scoring
* confidence scoring
* issue detection abstraction layer

---

## Sprint 2

* trend tracking
* progress charts
* structured recommendations
* saved reports

---

## Sprint 3

* adaptive weekly plans
* AI conversational coach
* drill library
* coach voice/audio

---

# My Strategic Recommendation

Your strongest market positioning is NOT:

> “AI running analyzer”

Too crowded.

Your strongest positioning is:

```text id="0t8lmn"
AI Running Form Correction System
+
Strength & Mobility Prescription Engine
```

That is much more differentiated.

Especially because:

* most apps only measure
* very few FIX the runner

And your Loopwijzer-style framework is actually excellent for this.
Before integration with Garmin and Strava, what database structure to create to keep user's data.