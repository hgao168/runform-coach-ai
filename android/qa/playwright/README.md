# Playwright Android UI acceptance

This folder is the black-box QA harness for the native Android app. It uses
Playwright's experimental `_android` API over ADB. It does not use a browser and
does not replace lower-level Compose UI tests.

## App contract

The debug/QA build must expose Compose `testTag` values as Android resource IDs
by enabling `testTagsAsResourceId` on the relevant semantics subtree. The
defaults are documented in `.env.example`; each tag can be overridden through
an environment variable.

The app must be installed before the suite starts. Use a resettable non-production
backend and a dedicated QA account. Never point mutating tests at production.

## One-time setup

Requirements: Node 20+, npm, Android SDK platform-tools (`adb`), one online
emulator/device, and a debug/QA APK installed on that device.

From this directory:

```bash
npm install
adb devices
```

Set environment variables in the invoking shell. `.env.example` is a reference;
the harness intentionally does not automatically load secrets from a file.

PowerShell example:

```powershell
$env:APP_PACKAGE = "com.example.runform"
$env:ANDROID_SERIAL = "emulator-5554"
$env:QA_EMAIL = "android.qa@example.test"
$env:QA_PASSWORD = "<secret>"
npm run preflight
npm run test:smoke
npm run test:acceptance
```

Bash example:

```bash
export APP_PACKAGE=com.example.runform
export ANDROID_SERIAL=emulator-5554
export QA_EMAIL=android.qa@example.test
export QA_PASSWORD='<secret>'
npm run preflight
npm run test:smoke
npm run test:acceptance
```

Use `APP_ACTIVITY` when Android cannot resolve a single launcher activity.
When multiple devices are online, `ANDROID_SERIAL` is mandatory.

## Evidence and triage

HTML and JUnit reports are written to `playwright-report/` and `test-results/`.
On a product failure, also capture:

```bash
adb -s "$ANDROID_SERIAL" logcat -d > android-logcat.txt
adb -s "$ANDROID_SERIAL" exec-out screencap -p > failure.png
```

The suite is deliberately serial because it controls one shared device and
clears app data before each test. See `ACCEPTANCE.md` for coverage and
`DEFECT_LOOP.md` for the acceptance workflow.
