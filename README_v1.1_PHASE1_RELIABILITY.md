# RunForm Phase 1 Reliability Update

Apply from repo root:

```bash
python apply_phase1_reliability.py
git diff
git add backend/app ios/RunFormCoachAI README_PHASE1_RELIABILITY.md
git commit -m "Add phase 1 analysis reliability and video quality scoring"
git push
```

What this adds:
- On-device video quality score
- Pose detection rate
- Quality notes for bad clips
- More stable cadence peak detection
- Quality-adjusted backend confidence
- Video Quality metric in result cards

After push:
- Redeploy Railway backend
- Rebuild iOS/TestFlight
- Test with 3 clips: good side-view, bad cropped clip, dark/low-light clip
