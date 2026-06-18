from datetime import datetime, timedelta, timezone
import base64
import hashlib
import hmac
import json
import os
import time
from typing import Any
from urllib.parse import urlencode, urlparse

import httpx
from cryptography.fernet import Fernet, InvalidToken
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .db_models import OAuthConnection, User

STRAVA_AUTHORIZE_URL = "https://www.strava.com/oauth/authorize"
STRAVA_TOKEN_URL = "https://www.strava.com/oauth/token"
STRAVA_DEAUTHORIZE_URL = "https://www.strava.com/oauth/deauthorize"


class StravaOAuthConfigError(RuntimeError):
    pass


class StravaOAuthError(RuntimeError):
    pass


def _required_env(name: str) -> str:
    if value := os.getenv(name):
        return value.strip()
    raise StravaOAuthConfigError(f"Missing required environment variable: {name}")


def _client_id() -> str:
    return _required_env("STRAVA_CLIENT_ID")


def _client_secret() -> str:
    return _required_env("STRAVA_CLIENT_SECRET")


def _redirect_uri() -> str:
    return _required_env("STRAVA_REDIRECT_URI")


def _state_secret() -> str:
    # Fallback to client secret if dedicated state secret is not configured.
    if value := os.getenv("STRAVA_STATE_SECRET"):
        return value.strip()
    return _client_secret()


def _token_fernet() -> Fernet:
    key = os.getenv("STRAVA_TOKEN_ENCRYPTION_KEY")
    if not key:
        raise StravaOAuthConfigError("Missing required environment variable: STRAVA_TOKEN_ENCRYPTION_KEY")
    try:
        return Fernet(key.encode("utf-8"))
    except Exception as exc:  # pragma: no cover - defensive key validation
        raise StravaOAuthConfigError("Invalid STRAVA_TOKEN_ENCRYPTION_KEY format.") from exc


def encrypt_secret(value: str) -> str:
    return _token_fernet().encrypt(value.encode("utf-8")).decode("utf-8")


def decrypt_secret(value: str) -> str:
    try:
        return _token_fernet().decrypt(value.encode("utf-8")).decode("utf-8")
    except InvalidToken as exc:
        raise StravaOAuthError("Stored Strava token could not be decrypted.") from exc


def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode("utf-8").rstrip("=")


def _b64url_decode(value: str) -> bytes:
    padding = "=" * ((4 - len(value) % 4) % 4)
    return base64.urlsafe_b64decode((value + padding).encode("utf-8"))


def normalize_app_callback_url(raw_url: str | None) -> str | None:
    raw_url = (raw_url or "").strip()
    if not raw_url:
        return None

    parsed = urlparse(raw_url)
    if parsed.scheme == "runformcoachai":
        if parsed.netloc:
            path = parsed.path or "/callback"
            return f"runformcoachai://{parsed.netloc}{path}"
        path_parts = parsed.path.strip("/").split("/", 1)
        host = path_parts[0] if path_parts and path_parts[0] else "strava"
        path = f"/{path_parts[1]}" if len(path_parts) > 1 else "/callback"
        return f"runformcoachai://{host}{path}"

    if raw_url == "runformcoachai":
        return "runformcoachai://strava/callback"

    return None


def make_state(ios_user_id: str, app_callback_url: str | None = None) -> str:
    payload = {"uid": ios_user_id, "ts": int(time.time())}
    if callback_url := normalize_app_callback_url(app_callback_url):
        payload["cb"] = callback_url
    payload_raw = json.dumps(payload, separators=(",", ":")).encode("utf-8")
    payload_part = _b64url(payload_raw)
    sig = hmac.new(_state_secret().encode("utf-8"), payload_part.encode("utf-8"), hashlib.sha256).digest()
    return f"{payload_part}.{_b64url(sig)}"


def verify_state_payload(state: str, max_age_seconds: int = 900) -> dict[str, Any]:
    try:
        payload_part, sig_part = state.split(".", 1)
    except ValueError as exc:
        raise StravaOAuthError("Invalid OAuth state format.") from exc

    expected_sig = hmac.new(_state_secret().encode("utf-8"), payload_part.encode("utf-8"), hashlib.sha256).digest()
    actual_sig = _b64url_decode(sig_part)
    if not hmac.compare_digest(expected_sig, actual_sig):
        raise StravaOAuthError("OAuth state signature mismatch.")

    payload = json.loads(_b64url_decode(payload_part).decode("utf-8"))
    user_id = payload.get("uid")
    timestamp = payload.get("ts")
    if not user_id or not isinstance(timestamp, int):
        raise StravaOAuthError("OAuth state payload is invalid.")

    if int(time.time()) - timestamp > max_age_seconds:
        raise StravaOAuthError("OAuth state expired.")

    return payload


def verify_state(state: str, max_age_seconds: int = 900) -> str:
    return verify_state_payload(state, max_age_seconds=max_age_seconds)["uid"]


def build_authorize_url(ios_user_id: str, app_callback_url: str | None = None) -> dict[str, str]:
    state = make_state(ios_user_id, app_callback_url=app_callback_url)
    scope = os.getenv("STRAVA_SCOPES", "read,activity:read_all")
    query = urlencode(
        {
            "client_id": _client_id(),
            "redirect_uri": _redirect_uri(),
            "response_type": "code",
            "approval_prompt": "auto",
            "scope": scope,
            "state": state,
        }
    )
    return {"authorize_url": f"{STRAVA_AUTHORIZE_URL}?{query}", "state": state}


async def exchange_code_for_token(code: str) -> dict[str, Any]:
    async with httpx.AsyncClient(timeout=20) as client:
        response = await client.post(
            STRAVA_TOKEN_URL,
            data={
                "client_id": _client_id(),
                "client_secret": _client_secret(),
                "code": code,
                "grant_type": "authorization_code",
            },
        )

    if response.status_code >= 400:
        raise StravaOAuthError(f"Strava token exchange failed: {response.text}")

    return response.json()


async def refresh_access_token(refresh_token: str) -> dict[str, Any]:
    async with httpx.AsyncClient(timeout=20) as client:
        response = await client.post(
            STRAVA_TOKEN_URL,
            data={
                "client_id": _client_id(),
                "client_secret": _client_secret(),
                "refresh_token": refresh_token,
                "grant_type": "refresh_token",
            },
        )

    if response.status_code >= 400:
        raise StravaOAuthError(f"Strava token refresh failed: {response.text}")

    return response.json()


async def deauthorize_access_token(access_token: str) -> None:
    async with httpx.AsyncClient(timeout=20) as client:
        response = await client.post(STRAVA_DEAUTHORIZE_URL, data={"access_token": access_token})
    if response.status_code >= 400:
        raise StravaOAuthError(f"Strava deauthorize failed: {response.text}")


def _apply_connection_tokens(
    conn: OAuthConnection,
    *,
    user_id: int,
    athlete_id: str,
    access_token_encrypted: str,
    refresh_token_encrypted: str,
    expires_at: datetime,
    scope: str | None,
) -> None:
    conn.user_id = user_id
    conn.provider_athlete_id = athlete_id
    conn.access_token_encrypted = access_token_encrypted
    conn.refresh_token_encrypted = refresh_token_encrypted
    conn.expires_at = expires_at
    conn.scope = scope
    conn.last_refresh_at = datetime.now(timezone.utc)


def upsert_strava_connection(session: Session, ios_user_id: str, token_payload: dict[str, Any]) -> OAuthConnection:
    athlete = token_payload.get("athlete") or {}
    athlete_id = athlete.get("id")
    access_token = token_payload.get("access_token")
    refresh_token = token_payload.get("refresh_token")
    expires_at_epoch = token_payload.get("expires_at")

    if not athlete_id or not access_token or not refresh_token or not expires_at_epoch:
        raise StravaOAuthError("Incomplete token payload returned by Strava.")

    provider_athlete_id = str(athlete_id)
    expires_at = time_to_utc_datetime(int(expires_at_epoch))
    scope = token_payload.get("scope")
    access_token_encrypted = encrypt_secret(access_token)
    refresh_token_encrypted = encrypt_secret(refresh_token)

    # Retry once if a concurrent callback races on the same athlete row.
    for attempt in range(2):
        try:
            user = session.scalar(select(User).where(User.ios_user_id == ios_user_id))
            if user is None:
                user = User(ios_user_id=ios_user_id)
                session.add(user)
                session.flush()

            athlete_conn = session.scalar(
                select(OAuthConnection).where(
                    OAuthConnection.provider == "strava",
                    OAuthConnection.provider_athlete_id == provider_athlete_id,
                )
            )
            user_conn = session.scalar(
                select(OAuthConnection).where(
                    OAuthConnection.user_id == user.id,
                    OAuthConnection.provider == "strava",
                )
            )

            if athlete_conn is not None:
                # Same athlete already exists: refresh tokens and (optionally) rebind to current local user.
                _apply_connection_tokens(
                    athlete_conn,
                    user_id=user.id,
                    athlete_id=provider_athlete_id,
                    access_token_encrypted=access_token_encrypted,
                    refresh_token_encrypted=refresh_token_encrypted,
                    expires_at=expires_at,
                    scope=scope,
                )
                if user_conn is not None and user_conn.id != athlete_conn.id:
                    session.delete(user_conn)
                conn = athlete_conn
            elif user_conn is not None:
                _apply_connection_tokens(
                    user_conn,
                    user_id=user.id,
                    athlete_id=provider_athlete_id,
                    access_token_encrypted=access_token_encrypted,
                    refresh_token_encrypted=refresh_token_encrypted,
                    expires_at=expires_at,
                    scope=scope,
                )
                conn = user_conn
            else:
                conn = OAuthConnection(
                    user_id=user.id,
                    provider="strava",
                    provider_athlete_id=provider_athlete_id,
                    access_token_encrypted=access_token_encrypted,
                    refresh_token_encrypted=refresh_token_encrypted,
                    expires_at=expires_at,
                    scope=scope,
                )
                session.add(conn)

            session.flush()
            return conn
        except IntegrityError as exc:
            session.rollback()
            if attempt == 0:
                continue
            raise StravaOAuthError(
                "This Strava account is already connected. Please retry to reconnect."
            ) from exc

    raise StravaOAuthError("Unable to upsert Strava connection.")


def get_strava_connection(session: Session, ios_user_id: str) -> OAuthConnection | None:
    user = session.scalar(select(User).where(User.ios_user_id == ios_user_id))
    if user is None:
        return None
    return session.scalar(select(OAuthConnection).where(OAuthConnection.user_id == user.id, OAuthConnection.provider == "strava"))


async def get_valid_access_token(session: Session, conn: OAuthConnection) -> str:
    now = datetime.now(timezone.utc)
    if conn.expires_at > now + timedelta(seconds=60):
        return decrypt_secret(conn.access_token_encrypted)

    refresh_token = decrypt_secret(conn.refresh_token_encrypted)
    token_payload = await refresh_access_token(refresh_token)
    access_token = token_payload.get("access_token")
    expires_at_epoch = token_payload.get("expires_at")
    if not access_token or not expires_at_epoch:
        raise StravaOAuthError("Incomplete refresh payload returned by Strava.")

    new_refresh_token = token_payload.get("refresh_token") or refresh_token
    conn.access_token_encrypted = encrypt_secret(access_token)
    conn.refresh_token_encrypted = encrypt_secret(new_refresh_token)
    conn.expires_at = time_to_utc_datetime(int(expires_at_epoch))
    conn.scope = token_payload.get("scope") or conn.scope
    conn.last_refresh_at = now
    session.flush()
    return access_token


def time_to_utc_datetime(epoch_seconds: int):
    from datetime import datetime, timezone

    return datetime.fromtimestamp(epoch_seconds, tz=timezone.utc)


def app_callback_url() -> str | None:
    return normalize_app_callback_url(os.getenv("STRAVA_APP_CALLBACK_URL"))
