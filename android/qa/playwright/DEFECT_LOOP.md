# Developer–QA defect loop

1. Developer provides an immutable commit SHA, APK path/checksum, backend
   environment, and change summary.
2. QA runs `npm run preflight`, then the smoke and acceptance suites.
3. For each failure, QA records: scenario ID, severity, commit SHA, device/API,
   exact steps, expected/actual result, screenshot/trace, and relevant logcat.
4. Developer reproduces and fixes the defect in a new commit. Tests are added or
   strengthened when the defect is automatable.
5. QA retests the failed scenario first, then runs the full agreed regression
   matrix against the new SHA.
6. Repeat until the exit criteria in `ACCEPTANCE.md` are met.

Severity:

- P0: crash, security/data loss, or core authentication journey impossible.
- P1: incorrect behavior with no reasonable workaround in an agreed scenario.
- P2: degraded behavior with a workaround.
- P3: cosmetic or low-impact issue.

A flaky test is a defect in the harness or product, not a pass. Retries provide
diagnostic evidence only. Acceptance means zero known open defects in scope; it
does not claim the software is universally bug-free.
