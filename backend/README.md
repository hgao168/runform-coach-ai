# Backend — RunForm Coach AI V1

FastAPI service for video upload and running-form analysis.

## Run

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## Endpoints

- `GET /health`
- `POST /analyze` with multipart field `video`

V1 returns mock analysis so the mobile app can be developed immediately.
