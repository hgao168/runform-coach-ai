# Android authentication acceptance matrix

The accepted commit must pass every applicable required scenario on the agreed
emulator/API level. A skipped required scenario is not a pass.

| ID | Priority | Scenario | Automation | Required result |
|---|---|---|---|---|
| AUTH-01 | P0 | Login screen loads | `@smoke` | Email, password, submit, register, and reset targets are visible |
| AUTH-02 | P0 | Valid login | `@acceptance` | Home target becomes visible |
| AUTH-03 | P0 | Invalid password | `@acceptance` | Error is visible and retry remains possible |
| AUTH-04 | P0 | Logout | `@acceptance` | Session ends and login screen returns |
| AUTH-05 | P1 | Empty/malformed input | Add when validation contract is fixed | Submit is blocked and field error is accessible |
| AUTH-06 | P1 | Registration success | Add with resettable QA identity | Account is created and expected destination appears |
| AUTH-07 | P1 | Duplicate registration | Add with seeded QA identity | Non-destructive duplicate-account error appears |
| AUTH-08 | P1 | Password mismatch | Add when registration tags exist | Local mismatch error appears |
| AUTH-09 | P1 | Password reset request | Add with test email sink | Confirmation appears without account enumeration |
| AUTH-10 | P1 | Offline/server failure | Add with controllable backend/network | Recoverable error; no stuck loading state |
| AUTH-11 | P1 | Relaunch persistence | Add after session policy is agreed | Session state matches the product requirement |
| AUTH-12 | P1 | Duplicate submit | Add when loading tag exists | One request; submit disabled while loading |

## Exit criteria

- The tested commit SHA and APK checksum are recorded.
- All P0 and agreed P1 scenarios pass on the target device/API.
- No open P0/P1 defects and no known open defects within the agreed scope.
- Failures have screenshots/traces and a logcat excerpt where relevant.
- The final regression run is against the same immutable commit proposed for merge.
