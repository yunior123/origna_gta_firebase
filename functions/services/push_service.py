"""
FCM Push Notification Service
Sends Firebase Cloud Messaging notifications to user devices.
"""

import logging
from typing import Any

from schema_constants import Collections, Fields

logger = logging.getLogger(__name__)

_db = None


def _get_db():
    """Lazy Firestore client initialization."""
    global _db
    if _db is None:
        from firebase_admin import firestore as fs

        _db = fs.client()
    return _db


def send_push_notification(user_id: str, title: str, body: str, data: dict | None = None) -> bool:
    """
    Send FCM push notification to all active devices for a user.
    Reads tokens from users/{uid}/fcm_tokens subcollection (multi-device support).
    On UnregisteredError per token, removes the stale token doc atomically.
    Returns True if at least one message succeeded, False otherwise.
    """
    try:
        from firebase_admin import messaging
    except ImportError:
        logger.warning("firebase_admin.messaging not available — push skipped")
        return False

    try:
        user_ref = _get_db().collection(Collections.USERS).document(user_id)
        user_doc = user_ref.get()
        if not user_doc.exists:
            return False

        user_data = user_doc.to_dict() or {}

        # Respect opt-out preference
        if not user_data.get(Fields.PUSH_ENABLED, True):
            return False

        # Collect all tokens from subcollection (multi-device)
        token_docs = list(user_ref.collection(Collections.FCM_TOKENS).stream())

        # Deduplicate tokens to avoid sending multiple pushes to the same device
        unique_tokens: dict[str, object] = {}
        for d in token_docs:
            token_str = d.to_dict().get("token")
            if token_str:
                unique_tokens[token_str] = d.reference

        tokens_with_refs: list[tuple[str, object]] = list(unique_tokens.items())

        if not tokens_with_refs:
            return False

        token_list = [t for t, _ in tokens_with_refs]
        msg = messaging.MulticastMessage(
            tokens=token_list,
            notification=messaging.Notification(title=title, body=body),
            data={k: str(v) for k, v in (data or {}).items()},
        )
        batch_response = messaging.send_each_for_multicast(msg)

        success = False
        for idx, response in enumerate(batch_response.responses):
            if response.success:
                success = True
            elif response.exception:
                err_str = str(response.exception)
                if "registration-token-not-registered" in err_str or "invalid-registration-token" in err_str:
                    # Remove stale token from subcollection
                    _, token_ref = tokens_with_refs[idx]
                    try:
                        if token_ref:
                            token_ref.delete()
                        logger.info(f"Removed stale FCM token for user {user_id}")
                    except Exception as del_err:
                        logger.warning(f"Failed to remove stale FCM token: {del_err}")

        if success:
            logger.info(f"Push sent to user {user_id} ({batch_response.success_count}/{len(token_list)} tokens)")
        return success
    except Exception as e:
        logger.warning(f"FCM push failed for user {user_id}: {e}")
        return False


def send_push_notifications_batch(user_ids: list[str], title: str, body: str, data: dict | None = None, image_url: str | None = None) -> int:
    """
    PERFORMANCE (HIGH): Send FCM push to multiple users using collectionGroup query.
    Avoids N+1 Firestore reads.
    
    Args:
        user_ids: List of UIDs to notify.
        title: Notification title.
        body: Notification body.
        data: Custom data payload.
        image_url: Optional image URL for the notification.
        
    Returns:
        Total number of messages successfully sent.
    """
    if not user_ids:
        return 0

    try:
        from firebase_admin import messaging
    except ImportError:
        logger.warning("firebase_admin.messaging not available — push skipped")
        return 0

    unique_user_ids = list(set(user_ids))
    total_sent = 0

    # Chunks of 30 for where("userId", "in", chunk) filter
    for i in range(0, len(unique_user_ids), 30):
        chunk = unique_user_ids[i:i + 30]

        # 1. Fetch all tokens for these users in one query
        # Requires 'userId' field in fcm_tokens docs + collectionGroup index
        token_query = (
            _get_db()
            .collection_group(Collections.FCM_TOKENS)
            .where(Fields.USER_ID, "in", chunk)
        )
        token_docs = list(token_query.stream())

        # Group tokens by userId
        # user_tokens[uid] = [(token, doc_ref), ...]
        user_tokens: dict[str, list[tuple[str, Any]]] = {}
        for d in token_docs:
            d_dict = d.to_dict() or {}
            uid = d_dict.get(Fields.USER_ID)
            token = d_dict.get("token")
            if uid and token:
                if uid not in user_tokens:
                    user_tokens[uid] = []
                user_tokens[uid].append((token, d.reference))

        if not user_tokens:
            continue

        # 2. Fetch user docs to check Fields.PUSH_ENABLED and daily limits (NOTIF-L1)
        users_ref = _get_db().collection(Collections.USERS)
        user_docs = _get_db().get_all([users_ref.document(uid) for uid in user_tokens])

        from datetime import UTC, datetime
        today_str = datetime.now(UTC).strftime("%Y-%m-%d")

        all_eligible_tokens_with_refs: list[tuple[str, Any, str]] = [] # (token, ref, uid)
        for user_doc in user_docs:
            if not user_doc.exists:
                continue
            u_data = user_doc.to_dict() or {}
            uid = user_doc.id

            # Respect opt-out preference
            if not u_data.get(Fields.PUSH_ENABLED, True):
                continue

            # NOTIF-L1: Daily per-user rate limit (cap at 20 pushes/day for mass alerts)
            push_stats = u_data.get("dailyPushStats", {})
            if push_stats.get("lastDate") == today_str and push_stats.get("count", 0) >= 20:
                logger.warning(f"NOTIF-L1: Daily push limit reached for user {uid}")
                continue

            # Update the count (best-effort, not inside FCM loop for performance)
            new_count = (push_stats.get("count", 0) + 1) if push_stats.get("lastDate") == today_str else 1
            user_doc.reference.update({
                "dailyPushStats": {"lastDate": today_str, "count": new_count}
            })

            for token, ref in user_tokens.get(uid, []):
                all_eligible_tokens_with_refs.append((token, ref, uid))

        if not all_eligible_tokens_with_refs:
            continue

        # 3. Send in batches of 500 (FCM limit)
        for j in range(0, len(all_eligible_tokens_with_refs), 500):
            batch_chunk = all_eligible_tokens_with_refs[j:j + 500]
            tokens_to_send = [t for t, r, u in batch_chunk]

            notification = messaging.Notification(title=title, body=body, image=image_url)

            msg = messaging.MulticastMessage(
                tokens=tokens_to_send,
                notification=notification,
                data={k: str(v) for k, v in (data or {}).items()},
            )
            response = messaging.send_each_for_multicast(msg)
            total_sent += response.success_count

            # NOTIF-L2: Cleanup stale tokens from batch results
            for idx, resp in enumerate(response.responses):
                if not resp.success and resp.exception:
                    err_str = str(resp.exception)
                    if "registration-token-not-registered" in err_str or "invalid-registration-token" in err_str:
                        _, t_ref, t_uid = batch_chunk[idx]
                        try:
                            t_ref.delete()
                            logger.info(f"NOTIF-L2: Removed stale token for user {t_uid}")
                        except Exception:
                            pass

    if total_sent > 0:
        logger.info(f"Batch push sent: {total_sent} messages to {len(unique_user_ids)} users")

    return total_sent
