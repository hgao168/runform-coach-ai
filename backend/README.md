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

## SQLAlchemy + Alembic (Phase 2)

This repo now includes SQLAlchemy models for Strava integration tables and Alembic migration scaffolding.

### Tables added

- `users`
- `oauth_connections`
- `strava_runs`
- `strava_weekly_stats`

### Run migrations

From `backend/`:

```powershell
set DATABASE_URL=postgresql://<user>:<password>@<host>:<port>/<db>
alembic upgrade head
```

Create a new migration later:

```powershell
alembic revision -m "describe_change"
alembic upgrade head
```

## Strava OAuth endpoints (Phase 3)

Required environment variables:

- `DATABASE_URL`
- `STRAVA_CLIENT_ID`
- `STRAVA_CLIENT_SECRET`
- `STRAVA_REDIRECT_URI` (must match Strava app settings)
- `STRAVA_TOKEN_ENCRYPTION_KEY` (Fernet key)

Optional environment variables:

- `STRAVA_SCOPES` (default: `read,activity:read_all`)
- `STRAVA_STATE_SECRET` (defaults to `STRAVA_CLIENT_SECRET`)
- `STRAVA_APP_CALLBACK_URL` (if set, callback redirects to app URL)

Endpoints:

- `GET /integrations/strava/connect?ios_user_id=<id>`
- `GET /integrations/strava/callback?code=...&state=...`
- `GET /integrations/strava/status?ios_user_id=<id>`
- `POST /integrations/strava/disconnect` with body `{ "ios_user_id": "..." }`

Generate a Fernet key example:

```powershell
python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```
