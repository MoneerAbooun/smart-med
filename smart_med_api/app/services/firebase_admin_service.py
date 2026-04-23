from __future__ import annotations

from dataclasses import dataclass

import firebase_admin
from fastapi import Header, HTTPException, status
from firebase_admin import auth, credentials, firestore


@dataclass(frozen=True)
class VerifiedFirebaseUser:
    uid: str
    email: str | None = None


def _ensure_initialized() -> None:
    if firebase_admin._apps:
        return

    try:
        firebase_admin.initialize_app()
    except ValueError:
        firebase_admin.initialize_app(credentials.ApplicationDefault())


def get_firestore_client() -> firestore.Client:
    _ensure_initialized()
    return firestore.client()


def verify_firebase_user(
    authorization: str | None = Header(default=None),
) -> VerifiedFirebaseUser:
    if authorization is None or not authorization.lower().startswith("bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Firebase bearer token.",
        )

    token = authorization.split(" ", 1)[1].strip()
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Firebase bearer token.",
        )

    _ensure_initialized()

    try:
        decoded_token = auth.verify_id_token(token)
    except Exception as exc:  # pragma: no cover - Firebase SDK errors vary.
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Firebase token.",
        ) from exc

    return VerifiedFirebaseUser(
        uid=str(decoded_token["uid"]),
        email=decoded_token.get("email"),
    )
