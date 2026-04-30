# RunForm Coach AI — V1 Starter

This is a first MVP codebase for a running-video analysis app.

V1 includes:
- iOS SwiftUI app skeleton
- Video picker
- Upload video to backend
- Mock running form analysis response
- Strength/mobility recommendation UI
- FastAPI backend with `/analyze`

The backend currently uses rule-based mock output. Replace `analyzer.py` with real pose analysis using Apple Vision, MediaPipe, or OpenCV later.

## Project structure

```text
runform-coach-ai-v1/
├── ios/RunFormCoachAI/
│   ├── RunFormCoachAIApp.swift
│   ├── ContentView.swift
│   ├── VideoPicker.swift
│   ├── APIClient.swift
│   ├── Models.swift
│   ├── AnalysisResultView.swift
│   └── Info.plist
├── backend/
│   ├── app/
│   │   ├── main.py
│   │   ├── analyzer.py
│   │   └── schemas.py
│   ├── requirements.txt
│   └── README.md
└── README.md
```


## Development flow

This repo is designed for your requested flow:

```text
Step 1 Windows: SwiftUI source + backend API + running-form logic
Step 2 GitHub: push code
Step 3 Mac/cloud Mac: open in Xcode, run, fix UI bugs
Step 4 TestFlight: internal testing
```

See `DEV_FLOW.md` for the exact commands and handoff checklist.

## Run backend

```bash
cd backend
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Test:

```bash
curl http://localhost:8000/health
```

## Run iOS app

1. Open Xcode.
2. Create a new iOS App project named `RunFormCoachAI`.
3. Replace generated Swift files with the files in `ios/RunFormCoachAI/`.
4. In `APIClient.swift`, update `baseURL`:
   - iOS Simulator: `http://127.0.0.1:8000`
   - Physical iPhone: use your computer LAN IP, for example `http://192.168.1.20:8000`
5. Run the app.

## V1 product flow

```text
Pick running video
→ Upload to backend
→ Mock analyzer returns form issues
→ App shows issues and strength plan
```

## Next steps

1. Add Apple Vision or MediaPipe landmark extraction.
2. Store analysis history locally with SwiftData.
3. Add real metrics: hip drop, knee valgus, overstride, trunk lean.
4. Add Strava integration in V2.
