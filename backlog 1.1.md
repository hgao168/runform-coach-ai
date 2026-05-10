Do this sequence:

1. Railway Postgres
2. SQLAlchemy/Alembic backend models
3. Strava OAuth endpoints
4. iOS “Connect Strava” button
5. Sync last 8 weeks runs
6. Use synced weekly km in Plan page

- Use Strava only as user-owned training context

Important: do not use Strava data to train AI models. Strava’s API policy changes restrict third-party display/use and prohibit using Strava API data for AI/model training. Use it only to generate that user’s own plan and show their own activity insights.

## RunForm Strava Backlog 1.1

This file is the current checkpoint for the Strava integration work.

## Done

- Railway Postgres is provisioned and the backend is using a real database.
- SQLAlchemy and Alembic are in place for backend persistence.
- Strava OAuth backend endpoints exist:
  - `/integrations/strava/connect`
  - `/integrations/strava/callback`
  - `/integrations/strava/status`
  - `/integrations/strava/disconnect`
- iOS Strava connect UI exists in the Profile flow.
- Strava connect now targets the production backend when needed.
- The callback session bug is fixed.
- The SQLAlchemy session detachment bug in Strava callback is fixed.
- Staging and production currently return `200` for Strava connect/status.
- Strava sync/import pipeline is implemented:
  - `POST /integrations/strava/sync`
  - last 8 weeks import
  - run-only filtering
  - idempotent upsert by Strava activity ID
  - weekly aggregate recomputation
- iOS Plan integration now prefers synced Strava weekly mileage when available.
- Disconnect now revokes Strava access and deletes imported Strava data.
- Privacy wording now states Strava data is used only for the user's coaching and plan generation, not AI training.

## Current Goal

Make Strava useful in the product flow, not just connectable.

## What’s Left

### 1. iOS Plan integration

- Prefill the Plan page with Strava baseline when connected.
- Fall back to profile weekly mileage when Strava is not connected or not synced.
- Show the source clearly in the UI.

### 2. Data deletion and disconnect behavior

- Done.

### 3. Privacy wording

- Done.

## Recommended Next Step

Wire the Plan page to prefer the synced Strava baseline when available.

## MVP Scope

- Last 4 to 8 weeks of runs
- Weekly distance
- Run count
- Longest run
- Average pace
- Recent intensity estimate

## Product Rule

- Strava is for training load and history.
- Video analysis is for movement quality.
- Plan generation should combine both.