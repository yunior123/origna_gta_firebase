"""Authoritative premium status check — reads subscriptions/{uid}, not user cache."""
_db = None


def _get_db():
    """Lazy Firestore client (uses same pattern as handlers for testing)."""
    global _db
    if _db is None:
        from firebase_admin import firestore as fs
        _db = fs.client()
    return _db


def is_premium_authoritative(uid: str, db=None) -> bool:
    """Returns True if user has an active/trialing subscription in Firestore.

    Args:
        uid: User ID to check.
        db: Optional Firestore client. Pass the calling handler's get_db() result
            so tests can use their mocked db instance.
    """
    from schema_constants import Collections, Fields, SubscriptionStatusValues
    if db is None:
        db = _get_db()
    snap = db.collection(Collections.SUBSCRIPTIONS).document(uid).get()
    if not snap.exists:
        return False
    status = (snap.to_dict() or {}).get(Fields.STATUS, "")
    return status in SubscriptionStatusValues.PREMIUM_ACTIVE
