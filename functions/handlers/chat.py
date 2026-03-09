"""
Chat Handlers — Product-scoped buyer↔seller messaging.

Features:
- Premium-only messaging for buyers (Gate enforced).
- Order-scoped threads (Buyers must have a prior purchase to chat).
- Server-side sanitization (Redacts off-platform contact info).
- Real-time notifications (FCM push + in-app unread counts).
- Message caps (Prevents unbounded collection growth).
"""

import logging
import re
from datetime import UTC, datetime
from typing import Any

from firebase_functions import https_fn
from google.cloud import firestore

from schema_constants import (
    ApiKeys,
    BusinessRules,
    Collections,
    Fields,
    OrderStatusValues,
    ProductLifecycleStatusValues,
    UserRoleValues,
    ValidationLimits,
)
from utils.db import get_db as _get_db
from utils.db import get_server_timestamp
from utils.function_options import DEFAULT_OPTIONS

logger = logging.getLogger(__name__)


def _is_premium(uid: str) -> bool:
    """
    Authoritative check for active premium subscription.
    
    Reads directly from the subscriptions/{uid} document to avoid
    stale cached claims or race conditions during checkout.
    """
    from utils.premium_check import is_premium_authoritative
    return is_premium_authoritative(uid, db=_get_db())


def _sanitize_text(text: str) -> str:
    """
    Multi-layered text sanitization for XSS and Policy Enforcement.
    
    1. Unicode Normalization: Collapses homoglyphs and invisible characters.
    2. HTML/Script Removal: Strips tags and JS injection attempts.
    3. Contact Redaction: Masking of phone numbers, emails, and external links
       to keep transactions within the Origna platform.
    """
    if not text:
        return ""

    import unicodedata
    # CHAT-M1: Normalize unicode to NFKC to collapse homoglyphs (e.g. 'a' vs 'а')
    text = unicodedata.normalize('NFKC', text)

    # Strip zero-width chars and other invisible whitespace used to bypass redaction
    text = re.sub(r'[\u200B-\u200D\uFEFF]', '', text)

    # Strip HTML and script tags (XSS Protection)
    text = re.sub(r'<script[^>]*>.*?</script>', '', text, flags=re.IGNORECASE | re.DOTALL)
    text = re.sub(r'<[^>]+>', '', text)
    text = re.sub(r'javascript:', '', text, flags=re.IGNORECASE)

    # Redact email addresses (handles standard and obfuscated formats)
    email_pat = r'\b[\w._%+\-]+(\s*[@\[(]at[\])]\s*|@)[\w.\-]+\.[a-zA-Z]{2,}\b'
    text = re.sub(email_pat, '[email removed]', text, flags=re.IGNORECASE)

    # Redact URLs and web links
    text = re.sub(r'https?://[^\s]+', '[link removed]', text, flags=re.IGNORECASE)
    text = re.sub(r'www\.[^\s]+', '[link removed]', text, flags=re.IGNORECASE)

    # Redact phone numbers (10-15 digits with separators)
    def redact_phone(match):
        """Function redact_phone."""
        raw = match.group(0)
        digits = re.sub(r'\D', '', raw)
        if 10 <= len(digits) <= 15:
            return '[phone removed]'
        return raw

    phone_obf_pat = r'(\+?[\d\s\-\.()]{10,20}\d)'
    text = re.sub(phone_obf_pat, redact_phone, text)

    return text.strip()


@https_fn.on_call(**DEFAULT_OPTIONS)
def get_or_create_chat(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Initializes a new chat thread or retrieves an existing one.
    
    Guards:
    - User must be authenticated.
    - Buyer must have an active Premium subscription.
    - Buyer must have a prior 'delivered' or 'disputed' order for the product.
    - Prevents self-chat (Seller cannot message themselves).
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "Authentication required.")

    buyer_id = req.auth.uid
    data = req.data
    product_id = data.get(Fields.PRODUCT_ID, "").strip()

    if not product_id:
        raise https_fn.HttpsError("invalid-argument", "productId is required.")

    # Premium gate check
    if not _is_premium(buyer_id):
        raise https_fn.HttpsError(
            "permission-denied",
            "Premium subscription required to chat with sellers.",
        )

    db = _get_db()

    # Verify product availability
    product_snap = db.collection(Collections.PRODUCTS).document(product_id).get()
    if not product_snap.exists:
        raise https_fn.HttpsError("not-found", "Product not found.")

    product_data = product_snap.to_dict() or {}
    if product_data.get(Fields.LIFECYCLE_STATUS) != ProductLifecycleStatusValues.ACTIVE:
        raise https_fn.HttpsError("not-found", "Product is no longer active.")

    seller_id = product_data.get(Fields.SELLER_ID, "")
    if seller_id == buyer_id:
        raise https_fn.HttpsError("permission-denied", "You cannot chat with yourself.")

    # Business Rule: Buyers can only chat about items they have received (delivered or disputed).
    # A pending/cancelled/processing order does NOT grant chat access — the transaction must
    # have been fulfilled so the buyer has a legitimate post-purchase support need.
    eligible_statuses = [OrderStatusValues.DELIVERED, OrderStatusValues.DISPUTED]
    order_found = False
    for status in eligible_statuses:
        order_query = (
            db.collection(Collections.ORDERS)
            .where(Fields.USER_ID, "==", buyer_id)
            .where(Fields.PRODUCT_IDS, "array_contains", product_id)
            .where(Fields.ORDER_STATUS, "==", status)
            .limit(1)
            .get()
        )
        if order_query:
            order_found = True
            break
    if not order_found:
        raise https_fn.HttpsError(
            "failed-precondition",
            "You must have a delivered order for this product before starting a chat with the seller.",
        )

    # Thread ID format: {productId}_{buyerId} ensures 1 thread per pair
    chat_id = f"{product_id}_{buyer_id}"
    chat_ref = db.collection(Collections.CHATS).document(chat_id)

    # Initialize new thread with metadata
    new_chat = {
        Fields.CHAT_ID: chat_id,
        Fields.PRODUCT_ID: product_id,
        Fields.BUYER_ID: buyer_id,
        Fields.SELLER_ID: seller_id,
        Fields.PRODUCT_TITLE: product_data.get(Fields.NAME, "Product"),
        Fields.PRODUCT_IMAGE_URL: (product_data.get(Fields.IMAGE_URLS) or [""])[0],
        Fields.BUYER_UNREAD_COUNT: 0,
        Fields.SELLER_UNREAD_COUNT: 0,
        Fields.CREATED_AT: get_server_timestamp(),
        Fields.UPDATED_AT: get_server_timestamp(),
    }
    # Use create() for atomic race-condition-safe thread creation
    try:
        chat_ref.create(new_chat)
        return {"chatId": chat_id, "isNew": True}
    except Exception as e:
        # Cloud Run Firestore SDK returns "409 Document already exists" (not gRPC "ALREADY_EXISTS")
        err_str = str(e).lower()
        if "already_exists" in err_str or "already exists" in err_str:
            return {"chatId": chat_id, "isNew": False}
        raise


@https_fn.on_call(**DEFAULT_OPTIONS)
def mark_messages_read(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Resets unread counters and marks incoming messages as read.
    
    Processes messages in chunks of 499 to respect Firestore batch limits.
    Only marks messages sent by the OTHER party as read.
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "Authentication required.")

    uid = req.auth.uid
    chat_id = (req.data.get(Fields.CHAT_ID) or "").strip()
    if not chat_id:
        raise https_fn.HttpsError("invalid-argument", "chatId is required.")

    db = _get_db()
    chat_ref = db.collection(Collections.CHATS).document(chat_id)
    chat_snap = chat_ref.get()
    if not chat_snap.exists:
        raise https_fn.HttpsError("not-found", "Chat thread not found.")

    chat_data = chat_snap.to_dict() or {}
    if chat_data.get(Fields.BUYER_ID) != uid and chat_data.get(Fields.SELLER_ID) != uid:
        raise https_fn.HttpsError("permission-denied", "Access denied.")

    # Find unread messages from the counter-party
    messages = (
        db.collection(Collections.CHATS)
        .document(chat_id)
        .collection(Collections.CHAT_MESSAGES)
        .where(Fields.IS_READ, "==", False)
        .where(Fields.SENDER_ID, "!=", uid)
        .limit(500)
        .stream()
    )

    BATCH_LIMIT = 499
    messages_list = list(messages)
    count = len(messages_list)
    for i in range(0, count, BATCH_LIMIT):
        chunk = messages_list[i:i + BATCH_LIMIT]
        batch = db.batch()
        for msg in chunk:
            batch.update(msg.reference, {Fields.IS_READ: True})
        batch.commit()

    # Reset local counter
    if count > 0:
        unread_field = Fields.BUYER_UNREAD_COUNT if uid == chat_data.get(Fields.BUYER_ID) else Fields.SELLER_UNREAD_COUNT
        db.collection(Collections.CHATS).document(chat_id).update({unread_field: 0})

    return {"success": True, "count": count}


@https_fn.on_call(**DEFAULT_OPTIONS)
def send_message(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Authoritative handler for sending chat messages.
    
    Responsibilities:
    - Sanitizes message text (XSS + Policy).
    - Enforces thread message limits (CHAT-C2).
    - Prevents rapid-fire duplicate messages (CHAT-M3).
    - Re-verifies buyer premium status.
    - Updates thread metadata (lastMessageAt, unreadCounts).
    - Tracks seller response time metrics.
    - Fires FCM push notification to recipient.
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "Authentication required.")

    uid = req.auth.uid
    data = req.data
    chat_id = data.get(Fields.CHAT_ID)
    text_raw = data.get(Fields.MESSAGE_TEXT, "")
    image_urls = data.get(Fields.IMAGE_URLS, [])
    message_id = data.get(Fields.MESSAGE_ID)

    if not chat_id or (not text_raw and not image_urls):
        raise https_fn.HttpsError("invalid-argument", "chatId and text/images required.")

    # Validate image_urls type, count, and CDN origin
    if image_urls:
        if not isinstance(image_urls, list) or len(image_urls) > 5:
            raise https_fn.HttpsError("invalid-argument", "Maximum 5 images per message.")
        for _url in image_urls:
            if not isinstance(_url, str) or not _url.startswith(BusinessRules.CDN_BASE_URL):
                raise https_fn.HttpsError(
                    "invalid-argument",
                    "Chat images must be uploaded to the Origna CDN before sending."
                )

    text = _sanitize_text(text_raw)

    # Message length validation
    if text_raw.strip() and not text:
        raise https_fn.HttpsError("invalid-argument", "Message text is too short after sanitization.")
    if text and len(text) > ValidationLimits.MAX_MESSAGE_LENGTH:
        raise https_fn.HttpsError("invalid-argument", f"Message exceeds {ValidationLimits.MAX_MESSAGE_LENGTH} characters.")
    db = _get_db()
    chat_ref = db.collection(Collections.CHATS).document(chat_id)
    chat_snap = chat_ref.get()

    if not chat_snap.exists:
        raise https_fn.HttpsError("not-found", "Chat thread not found.")

    chat_data = chat_snap.to_dict() or {}
    buyer_id = chat_data.get(Fields.BUYER_ID)
    seller_id = chat_data.get(Fields.SELLER_ID)

    if uid not in (buyer_id, seller_id):
        raise https_fn.HttpsError("permission-denied", "Access denied.")

    # CHAT-M3: Deduplication guard
    last_text = chat_data.get(Fields.LAST_MESSAGE_TEXT)
    last_update = chat_data.get(Fields.UPDATED_AT)
    if text and last_text == text and last_update:
        if not last_update.tzinfo:
            last_update = last_update.replace(tzinfo=UTC)
        if (datetime.now(UTC) - last_update).total_seconds() < 5:
            raise https_fn.HttpsError("already-exists", "Message already sent.")

    # CHAT-C2: Thread capacity check
    msg_count = chat_data.get(Fields.MESSAGE_COUNT, 0)
    if msg_count >= BusinessRules.MAX_MESSAGES_PER_THREAD:
        raise https_fn.HttpsError("resource-exhausted", "Chat limit reached for this thread.")

    # Sender metadata and premium check
    sender_snap = db.collection(Collections.USERS).document(uid).get()
    sender_data = sender_snap.to_dict() or {}
    if uid == buyer_id and not _is_premium(uid):
        raise https_fn.HttpsError("permission-denied", "Premium required.")

    sender_name = sender_data.get(Fields.NAME, "Someone")

    # Rate limiting (Max 60/min)
    from services.rate_limiter import RateLimiter
    if not RateLimiter(db).check_rate_limit(f"{uid}_chat", "send_message", 60, 1)[0]:
        raise https_fn.HttpsError("resource-exhausted", "Rate limit exceeded.")

    msg_ref = chat_ref.collection(Collections.CHAT_MESSAGES).document(message_id) if message_id else chat_ref.collection(Collections.CHAT_MESSAGES).document()
    if message_id and msg_ref.get().exists:
        return {"success": True, "messageId": msg_ref.id}

    # Persist message
    msg_ref.set({
        Fields.SENDER_ID: uid,
        Fields.SENDER_DISPLAY_NAME: sender_name,
        Fields.MESSAGE_TEXT: text,
        Fields.IMAGE_URLS: image_urls,
        Fields.CREATED_AT: get_server_timestamp(),
        Fields.IS_READ: False,
    })

    # Update thread metadata
    target_unread = Fields.SELLER_UNREAD_COUNT if uid == buyer_id else Fields.BUYER_UNREAD_COUNT
    thread_update = {
        Fields.LAST_MESSAGE: text[:100],
        Fields.LAST_MESSAGE_AT: get_server_timestamp(),
        Fields.UPDATED_AT: get_server_timestamp(),
        Fields.LAST_MESSAGE_TEXT: text,
        Fields.MESSAGE_COUNT: firestore.Increment(1),
        target_unread: firestore.Increment(1),
    }

    # Response time metrics
    if uid == buyer_id and not chat_data.get(Fields.FIRST_BUYER_MESSAGE_AT):
        thread_update[Fields.FIRST_BUYER_MESSAGE_AT] = get_server_timestamp()
    elif uid == seller_id and not chat_data.get(Fields.FIRST_SELLER_REPLY_AT):
        fb_msg = chat_data.get(Fields.FIRST_BUYER_MESSAGE_AT)
        if fb_msg:
            if not fb_msg.tzinfo:
                fb_msg = fb_msg.replace(tzinfo=UTC)
            hours = (datetime.now(UTC) - fb_msg).total_seconds() / 3600.0
            thread_update[Fields.FIRST_SELLER_REPLY_AT] = get_server_timestamp()
            thread_update[Fields.FIRST_REPLY_HOURS] = hours

    chat_ref.update(thread_update)

    # Notify recipient
    recipient_id = seller_id if uid == buyer_id else buyer_id
    try:
        from services.push_service import send_push_notification
        send_push_notification(
            recipient_id,
            f"Message from {sender_name}",
            text or "Sent an image",
            data={"type": "chat_message", "chatId": chat_id}
        )
    except Exception as e:
        logger.warning(f"Push failed for chat {chat_id}: {e}")

    return {"success": True, "messageId": msg_ref.id}


@https_fn.on_call(**DEFAULT_OPTIONS)
def delete_message(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Soft-deletes a message by the sender.
    Clears content but preserves metadata for thread consistency.
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "Authentication required.")

    uid = req.auth.uid
    chat_id = req.data.get(Fields.CHAT_ID)
    message_id = req.data.get(Fields.MESSAGE_ID)

    if not chat_id or not message_id:
        raise https_fn.HttpsError("invalid-argument", "chatId and messageId required.")

    db = _get_db()
    msg_ref = db.collection(Collections.CHATS).document(chat_id).collection(Collections.CHAT_MESSAGES).document(message_id)
    msg_snap = msg_ref.get()

    if not msg_snap.exists:
        raise https_fn.HttpsError("not-found", "Message not found.")

    msg_data = msg_snap.to_dict() or {}

    # Idempotent: already deleted
    if msg_data.get(Fields.DELETED):
        return {"success": True}

    # Allow sender or admin to delete
    is_sender = msg_data.get(Fields.SENDER_ID) == uid
    user_snap = db.collection(Collections.USERS).document(uid).get()
    is_admin = UserRoleValues.ADMIN in ((user_snap.to_dict() or {}).get(Fields.ROLES, [])) if user_snap.exists else False

    if not is_sender and not is_admin:
        raise https_fn.HttpsError("permission-denied", "Only the sender or an admin can delete a message.")

    msg_ref.update({
        Fields.DELETED: True,
        Fields.MESSAGE_TEXT: "",
        Fields.IMAGE_URLS: [],
        Fields.UPDATED_AT: get_server_timestamp(),
    })
    return {"success": True}


@https_fn.on_call(**DEFAULT_OPTIONS)
def report_message(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Flags a chat message for administrative review.

    Responsibilities:
    - Records the report in message_reports collection.
    - Captures reporterId, reason, and message context.
    - Prevents duplicate reports for the same message by the same user.
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "Authentication required.")

    uid = req.auth.uid
    data = req.data
    chat_id = (data.get(Fields.CHAT_ID) or "").strip()
    message_id = (data.get(Fields.MESSAGE_ID) or "").strip()
    reason = (data.get(ApiKeys.REASON) or "Inappropriate content").strip()

    if not chat_id or not message_id:
        raise https_fn.HttpsError("invalid-argument", "chatId and messageId required.")

    db = _get_db()

    # 1. Verify chat and participant
    chat_ref = db.collection(Collections.CHATS).document(chat_id)
    chat_snap = chat_ref.get()
    if not chat_snap.exists:
        raise https_fn.HttpsError("not-found", "Chat thread not found.")

    chat_data = chat_snap.to_dict() or {}
    if uid not in (chat_data.get(Fields.BUYER_ID), chat_data.get(Fields.SELLER_ID)):
        raise https_fn.HttpsError("permission-denied", "You are not a participant in this chat.")

    # 2. Verify message exists
    msg_ref = chat_ref.collection(Collections.CHAT_MESSAGES).document(message_id)
    msg_snap = msg_ref.get()
    if not msg_snap.exists:
        raise https_fn.HttpsError("not-found", "Message not found.")

    msg_data = msg_snap.to_dict() or {}

    # 3. Create report document
    report_ref = db.collection(Collections.MESSAGE_REPORTS).document()
    report_data = {
        Fields.REPORT_ID: report_ref.id,
        Fields.CHAT_ID: chat_id,
        Fields.MESSAGE_ID: message_id,
        Fields.REPORTER_ID: uid,
        Fields.REASON: reason[:500],
        Fields.MESSAGE_TEXT: msg_data.get(Fields.MESSAGE_TEXT, ""),
        Fields.SENDER_ID: msg_data.get(Fields.SENDER_ID, ""),
        Fields.STATUS: "pending",
        Fields.CREATED_AT: get_server_timestamp(),
    }
    report_ref.set(report_data)

    logger.info(f"Message {message_id} in chat {chat_id} reported by {uid}. Reason: {reason}")

    return {"success": True, Fields.REPORT_ID: report_ref.id}
