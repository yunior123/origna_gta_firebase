"""Module db.py."""
from typing import Any

from google.cloud.firestore import Client

_db: Client | None = None
_firestore: Any | None = None


def get_db() -> Client:
    """Get Firestore client (lazy initialization, shared singleton)."""
    global _db, _firestore
    if _db is None:
        from firebase_admin import firestore as fs

        _firestore = fs
        _db = fs.client()
    return _db


def get_firestore() -> Any:
    """Get Firestore module (lazy initialization, shared singleton)."""
    global _firestore
    if _firestore is None:
        from firebase_admin import firestore as fs

        _firestore = fs
    return _firestore


def get_server_timestamp() -> Any:
    """Get Firestore SERVER_TIMESTAMP sentinel."""
    return get_firestore().SERVER_TIMESTAMP


def get_delete_field() -> Any:
    """Get Firestore DELETE_FIELD sentinel."""
    return get_firestore().DELETE_FIELD
