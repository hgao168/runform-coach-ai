import base64
import hashlib
import hmac
import json
import os
import time
from typing import Any
from urllib.parse import urlencode

import httpx
from cryptography.fernet import Fernet, InvalidToken
from sqlalchemy import select
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
        return value
    raise StravaOAuthConfigError(f"Missing required environment variable: {name}")


def _client_id() -> str:
    return _required_env("STRAVA_CLIENT_ID")


def _client_secret() -> str:
    return _required_env("STRAVA_CLIENT_SECRET")


def _redirect_uri() -> str:
    return _required_env("STRAVA_REDIRECT_URI")


def _state_secret() -> str:
    # Fallback to client secret if dedicated state secret is not configured.
    return os.getenv("STRAVA_STATE_SECRET") or _client_secret()


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


def make_state(ios_user_id: str) -> str:
    payload = {"uid": ios_user_id, "ts": int(time.time())}
    payload_raw = json.dumps(payload, separators=(",", ":")).encode("utf-8")
    payload_part = _b64url(payload_raw)
    sig = hmac.new(_state_secret().encode("utf-8"), payload_part.encode("utf-8"), hashlib.sha256).digest()
    return f"{payload_part}.{_b64url(sig)}"


def verify_state(state: str, max_age_seconds: int = 900) -> str:
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

    return user_id


def build_authorize_url(ios_user_id: str) -> dict[str, str]:
    state = make_state(ios_user_id)
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


async def deauthorize_access_token(access_token: str) -> None:
    async with httpx.AsyncClient(timeout=20) as client:
        response = await client.post(STRAVA_DEAUTHORIZE_URL, data={"access_token": access_token})
    if response.status_code >= 400:
        raise StravaOAuthError(f"Strava deauthorize failed: {response.text}")


def upsert_strava_connection(session: Session, ios_user_id: str, token_payload: dict[str, Any]) -> OAuthConnection:
    athlete = token_payload.get("athlete") or {}
    athlete_id = athlete.get("id")
    access_token = token_payload.get("access_token")
    refresh_token = token_payload.get("refresh_token")
    expires_at_epoch = token_payload.get("expires_at")

    if not athlete_id or not access_token or not refresh_token or not expires_at_epoch:
        raise StravaOAuthError("Incomplete token payload returned by Strava.")

    user = session.scalar(select(User).where(User.ios_user_id == ios_user_id))
    if user is None:
        user = User(ios_user_id=ios_user_id)
        session.add(user)
        session.flush()

    conn = session.scalar(
        select(OAuthConnection).where(OAuthConnection.user_id == user.id, OAuthConnection.provider == "strava")
    )
    if conn is None:
        conn = OAuthConnection(
            user_id=user.id,
            provider="strava",
            provider_athlete_id=str(athlete_id),
            access_token_encrypted=encrypt_secret(access_token),
            refresh_token_encrypted=encrypt_secret(refresh_token),
            expires_at=time_to_utc_datetime(int(expires_at_epoch)),
            scope=token_payload.get("scope"),
        )
        session.add(conn)
    else:
        conn.provider_athlete_id = str(athlete_id)
        conn.access_token_encrypted = encrypt_secret(access_token)
        conn.refresh_token_encrypted = encrypt_secret(refresh_token)
        conn.expires_at = time_to_utc_datetime(int(expires_at_epoch))
        conn.scope = token_payload.get("scope")

    session.flush()
    return conn


def get_strava_connection(session: Session, ios_user_id: str) -> OAuthConnection | None:
    user = session.scalar(select(User).where(User.ios_user_id == ios_user_id))
    if user is None:
        return None
    return session.scalar(select(OAuthConnection).where(OAuthConnection.user_id == user.id, OAuthConnection.provider == "strava"))


def time_to_utc_datetime(epoch_seconds: int):
    from datetime import datetime, timezone

    return datetime.fromtimestamp(epoch_seconds, tz=timezone.utc)


def app_callback_url() -> str | None:
    return os.getenv("STRAVA_APP_CALLBACK_URL")
