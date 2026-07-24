# Android engineering workflow

## Scope

This directory contains the native Android application. Preserve changes outside
`android/` and do not stage or commit them as part of Android work.

## Required agents for feature acceptance

For feature implementation, bug fixes that affect user-visible behavior, or an
explicit acceptance request:

1. Spawn exactly one `android_developer` agent to implement the change.
2. Spawn exactly one `android_qa_engineer` agent to own acceptance testing.
3. Give the QA agent an immutable commit SHA or APK produced from that SHA.
4. If QA reports a reproducible defect, return it to the same developer agent.
5. Give the resulting revision back to the same QA agent and rerun the failed
   scenario plus the regression suite.
6. Continue until the acceptance gate below passes or a genuine external blocker
   requires user input.

The developer must not mark their own change accepted. The QA agent owns the
accept/reject decision.

## Acceptance gate

A change is accepted only when:

- there are no known open blocker, critical, or high-severity defects in scope;
- every required automated test that can run in the configured environment passes;
- every acceptance scenario is recorded as passed, failed, or blocked;
- failures include reproduction steps, expected and actual behavior, device/API
  level, revision, and evidence paths;
- blocked checks are reported explicitly and are never described as passing.

“No known open bugs” applies only to the documented acceptance scope; it is not
a claim that the application is defect-free.

## Commands

- Build debug APK: `./gradlew assembleDebug`
- Kotlin/unit checks: `./gradlew testDebugUnitTest`
- Android instrumented checks: `./gradlew connectedDebugAndroidTest`
- Kotlin style: `./gradlew ktlintCheck`
- Playwright Android acceptance: see `qa/playwright/README.md`

Run Gradle and the repository from the same operating-system filesystem. Do not
run Windows Gradle directly against a `\\wsl.localhost\...` working directory.

## Testability conventions

- Give important Compose controls stable `Modifier.testTag(...)` identifiers.
- Expose Compose test tags as Android resource IDs at the app root so the
  Playwright Android driver can locate them.
- Prefer stable IDs and semantic assertions over coordinates or translated text.
- Keep QA credentials and backend URLs in environment variables; never commit
  secrets or real user credentials.

