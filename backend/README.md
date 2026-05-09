# RunForm backend accuracy update

Preferred endpoint: `POST /analyze-metrics`.

iOS now extracts Apple Vision pose metrics locally and sends only JSON metrics to the backend. The backend returns:

- video quality score and reasons
- no misleading `0 spm` cadence display
- cadence marked `Not measurable` when ankle visibility is poor
- targeted strength/run drill recommendations

Deploy to Railway after copying `backend/app/*.py` and `backend/requirements.txt`.

## Postgres setup (Phase 1)

Set `DATABASE_URL` on Railway for the backend service.

- Railway usually provides a Postgres connection URL.
- Backend health endpoint now validates DB connectivity when configured:
	- `GET /health` returns `db.status = "ok"` when connection succeeds.
	- If `DATABASE_URL` is missing, `db.status = "not_configured"`.

Example expected health payload:

```json
{
	"status": "ok",
	"service": "runform-coach-ai",
	"version": "0.5.0",
	"environment": "production",
	"db": {
		"configured": true,
		"status": "ok"
	}
}
```
