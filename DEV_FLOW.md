# RunForm Coach AI — Development Flow

This project follows the requested four-step flow.

## Step 1 — Windows development

Goal: build most of the product logic before opening Xcode.

What you can do on Windows:

1. Write and edit SwiftUI source files under `ios/RunFormCoachAI/`.
2. Run the backend API locally.
3. Develop and test the running-form analysis logic in Python.
4. Commit and push all code to GitHub.

Recommended Windows tools:

- VS Code
- Git for Windows
- Python 3.11+
- PowerShell
- GitHub Desktop or Git CLI

Backend commands:

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

API test:

```powershell
Invoke-RestMethod http://127.0.0.1:8000/health
```

Analyzer logic test:

```powershell
python scripts/test_analyzer.py
```

## Step 2 — GitHub

Create a GitHub repo, then run:

```powershell
git init
git add .
git commit -m "Initial RunForm Coach AI V1"
git branch -M main
git remote add origin https://github.com/<your-user>/runform-coach-ai.git
git push -u origin main
```

## Step 3 — Mac / cloud Mac

1. Clone the GitHub repo.
2. Open Xcode.
3. Create a new iOS App project named `RunFormCoachAI`.
4. Copy files from `ios/RunFormCoachAI/` into the Xcode project.
5. Update `APIClient.swift` backend URL:
   - Simulator: `http://127.0.0.1:8000`
   - Physical iPhone: your Windows/Mac LAN IP, for example `http://192.168.1.20:8000`
6. Run the backend.
7. Run the app in iOS Simulator.
8. Fix UI/layout bugs in Xcode.

## Step 4 — TestFlight

1. In Xcode, set Bundle Identifier and Team.
2. Archive the app.
3. Upload to App Store Connect.
4. Add internal testers.
5. Run TestFlight feedback cycle.

V1 TestFlight checklist:

- Pick video works.
- Upload request reaches backend.
- Analysis result screen renders correctly.
- Error state is understandable when backend is offline.
- UI works on common iPhone sizes.
