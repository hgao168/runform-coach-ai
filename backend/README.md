# RunForm backend accuracy update

Preferred endpoint: `POST /analyze-metrics`.

iOS now extracts Apple Vision pose metrics locally and sends only JSON metrics to the backend. The backend returns:

- video quality score and reasons
- no misleading `0 spm` cadence display
- cadence marked `Not measurable` when ankle visibility is poor
- targeted strength/run drill recommendations

Deploy to Railway after copying `backend/app/*.py` and `backend/requirements.txt`.
