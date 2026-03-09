"""
User Management Handlers
- User profile updates
- Tax exemption management

NOTE: Stripe Tax handles GST validation and B2B exemption automatically.
We only store the GST number - Stripe validates it during checkout.
"""

import logging
from typing import Any

from firebase_functions import https_fn

from schema_constants import (
    COUNTRY_CANADA,
    BusinessRules,
    Collections,
    ConsentMethodValues,
    Fields,
    LanguageValues,
    OrderStatusValues,
    PolicyVersionValues,
    RateLimitActions,
    UserRoleValues,
    ValidationLimits,
)
from utils.db import get_db, get_server_timestamp
from utils.function_options import DEFAULT_OPTIONS
from utils.helpers import create_success_response, sanitized_text
from utils.turnstile import verify_turnstile_token

logger = logging.getLogger(__name__)


def _get_firestore_increment(n: int):
    """Return a Firestore Increment sentinel for atomic counter updates."""
    from firebase_admin import firestore

    return firestore.Increment(n)


@https_fn.on_call(**DEFAULT_OPTIONS)
def create_user_profile(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Create the Firestore user document server-side after Firebase Auth sign-in/sign-up.

    Server controls all legal-compliance fields (CASL / PIPEDA / Law 25):
      dataProcessingConsent, emailConsent, consentTimestamp, termsAcceptedAt,
      privacyAcceptedAt, consentMethod, privacyPolicyVersion, termsVersion.

    Idempotent: safe to call on every login — no-ops if doc already exists.

    Request data:
        - name: string (required — display name)
        - preferredLanguage: 'en' | 'fr' (optional, defaults to 'en')
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    user_id = req.auth.uid
    token = req.auth.token
    email = token.get("email", "")
    email_verified = token.get("email_verified", False)
    data = req.data or {}

    from services.rate_limiter import RateLimiter
    _limiter = RateLimiter(get_db())
    allowed, msg = _limiter.check_rate_limit(
        identifier=user_id,
        action=RateLimitActions.CREATE_USER_PROFILE,
        max_requests=5,
        window_minutes=60,
        fail_closed=True,
    )
    if not allowed:
        logger.warning(f"Rate limit exceeded for create_user_profile uid={user_id}")
        raise https_fn.HttpsError(
            "resource-exhausted", "Too many profile creation attempts. Please try again later."
        )

    # F-90: OAuth Account Takeover Prevention
    # Ensure email is verified before creating a profile to prevent hijacking.
    # Bypass only in emulator mode for testing.
    from os import environ
    is_emulator = environ.get("FUNCTIONS_EMULATOR") == "true" or environ.get("FIRESTORE_EMULATOR_HOST")

    if not email_verified and not is_emulator:
        logger.warning("Attempted profile creation for unverified email: %s (uid=%s)", email, user_id)
        raise https_fn.HttpsError(
            "failed-precondition",
            "Email verification required before profile creation. Please check your inbox."
        )

    user_ref = get_db().collection(Collections.USERS).document(user_id)
    doc = user_ref.get()
    if doc.exists:
        return create_success_response({"created": False, "existing": True})

    # Cloudflare Turnstile — bot protection for new registrations (web-only).
    # Mobile clients do not send a token; verification is skipped if secret not set (dev).
    from schema_constants import ApiKeys
    turnstile_token = data.get(ApiKeys.TURNSTILE_TOKEN)
    if not verify_turnstile_token(turnstile_token):
        logger.warning("Turnstile verification failed for new user uid=%s", user_id)
        raise https_fn.HttpsError(
            "permission-denied",
            "Bot verification failed. Please try again.",
        )

    # Validate and sanitize name
    name_raw = data.get(Fields.NAME, "").strip()
    if not name_raw:
        # Fall back to email prefix as display name
        name_raw = email.split("@")[0] if email else "User"
    name = sanitized_text(name_raw)[: ValidationLimits.MAX_NAME_LENGTH]
    if len(name) < ValidationLimits.MIN_NAME_LENGTH:
        name = "User"

    # Validate preferredLanguage
    lang = data.get(Fields.PREFERRED_LANGUAGE, LanguageValues.ENGLISH)
    if lang not in LanguageValues.ALL:
        lang = LanguageValues.ENGLISH

    # F-81: Accept consentMethod from client (google_oauth vs signup_form) for CASL compliance.
    # Validate against allowlist — never trust client strings blindly.
    consent_method_raw = data.get(Fields.CONSENT_METHOD, "")
    if consent_method_raw in (
        ConsentMethodValues.GOOGLE_OAUTH,
        ConsentMethodValues.APPLE_OAUTH,
        ConsentMethodValues.SIGNUP_FORM,
        ConsentMethodValues.SIGNUP,
    ):
        consent_method = consent_method_raw
    else:
        consent_method = ConsentMethodValues.SIGNUP_FORM

    server_ts = get_server_timestamp()

    user_ref.set({
        Fields.UID: user_id,
        Fields.EMAIL: email,
        Fields.NAME: name,
        Fields.ROLES: [UserRoleValues.BUYER],
        Fields.CREATED_AT: server_ts,
        Fields.PREFERRED_LANGUAGE: lang,
        # === LEGAL COMPLIANCE — server-only (CASL / PIPEDA / Law 25) ===
        Fields.DATA_PROCESSING_CONSENT: True,
        Fields.EMAIL_CONSENT: True,
        Fields.MARKETING_OPT_IN: bool(data.get(Fields.MARKETING_OPT_IN, False)),  # CASL: explicit opt-in required
        Fields.CONSENT_TIMESTAMP: server_ts,
        Fields.TERMS_ACCEPTED_AT: server_ts,
        Fields.PRIVACY_ACCEPTED_AT: server_ts,
        Fields.CONSENT_METHOD: consent_method,
        Fields.ENGLISH_ONLY_CONSENT: bool(data.get(Fields.ENGLISH_ONLY_CONSENT, False)), # F-279
        Fields.DATE_OF_BIRTH: data.get(Fields.DATE_OF_BIRTH), # F-282: optional DOB
        Fields.PRIVACY_POLICY_VERSION: PolicyVersionValues.DEFAULT,
        Fields.TERMS_VERSION: PolicyVersionValues.DEFAULT,
        Fields.PUSH_ENABLED: bool(data.get(Fields.PUSH_ENABLED, True)),  # Default to True unless explicitly denied
    })

    logger.info("Created user profile server-side for uid=%s", user_id)
    return create_success_response({"created": True})


@https_fn.on_call(**DEFAULT_OPTIONS)
def update_user_profile(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Update user profile fields including tax exemption.

    NOTE: Stripe Tax will validate the GST number during checkout.
    We only do basic format validation here.

    Request data:
        - taxExemption: {gstNumber: "123456789RT0001"} | null (optional)
        - address: Address object (optional)
        - name: string (optional)
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    user_id = req.auth.uid
    data = req.data

    # Build update data
    update_data = {
        Fields.UPDATED_AT: get_server_timestamp(),
    }

    # Handle terms acceptance (e.g., user checked terms box during checkout)
    # Server always sets the timestamp — client only sends a boolean flag.
    if data.get(Fields.TERMS_ACCEPTED_AT) is True:
        update_data[Fields.TERMS_ACCEPTED_AT] = get_server_timestamp()
        update_data[Fields.CONSENT_METHOD] = ConsentMethodValues.CHECKBOX
        update_data[Fields.TERMS_VERSION] = PolicyVersionValues.DEFAULT

    # Handle tax exemption update
    if Fields.TAX_EXEMPTION in data:
        # Rate limiting: 3 tax exemption changes per day per user
        from services.rate_limiter import RateLimiter

        _limiter = RateLimiter(get_db())
        allowed, msg = _limiter.check_rate_limit(
            identifier=f"{user_id}_tax_exemption",
            action=RateLimitActions.UPDATE_TAX_EXEMPTION,
            max_requests=3,
            window_minutes=1440,  # 24 hours
            fail_closed=True,
        )
        if not allowed:
            raise https_fn.HttpsError(
                "resource-exhausted", "Too many tax exemption updates. Please try again tomorrow."
            )

        tax_exemption = data[Fields.TAX_EXEMPTION]

        if tax_exemption is None:
            # Remove tax exemption
            update_data[Fields.TAX_EXEMPTION] = None
        else:
            gst_number = tax_exemption.get(Fields.GST_NUMBER, "").strip().upper()

            # Basic format validation only
            # Stripe Tax will do full validation during checkout
            import re

            if gst_number and not re.match(BusinessRules.GST_NUMBER_REGEX, gst_number):
                raise https_fn.HttpsError("invalid-argument", "Invalid GST number format. Expected: 123456789RT0001")

            # Store the GST number - Stripe will validate it
            update_data[Fields.TAX_EXEMPTION] = {
                Fields.GST_NUMBER: gst_number,
                Fields.UPDATED_AT: get_server_timestamp(),
            }

    # Handle address update
    if Fields.ADDRESS in data:
        from models.base import Address

        try:
            address = Address(**data[Fields.ADDRESS])
            if address.country != COUNTRY_CANADA:
                raise https_fn.HttpsError("invalid-argument", "Address must be in Canada")
            update_data[Fields.ADDRESS] = address.model_dump()
        except https_fn.HttpsError:
            raise
        except Exception as e:
            logger.error(f"Address validation error: {e}")
            raise https_fn.HttpsError(
                "invalid-argument", "Invalid address. Please check all fields and try again."
            ) from e

    # Handle name update
    if Fields.NAME in data:
        name_raw = data.get(Fields.NAME)
        if not isinstance(name_raw, str):
            raise https_fn.HttpsError("invalid-argument", "Name must be a string")
        name = sanitized_text(name_raw.strip())[: ValidationLimits.MAX_NAME_LENGTH]
        if len(name) < ValidationLimits.MIN_NAME_LENGTH or len(name) > ValidationLimits.MAX_NAME_LENGTH:
            raise https_fn.HttpsError(
                "invalid-argument",
                f"Name must be between {ValidationLimits.MIN_NAME_LENGTH} and {ValidationLimits.MAX_NAME_LENGTH} characters",
            )
        update_data[Fields.NAME] = name

    # Handle preferredLanguage update (Quebec Bill 96 / CASL compliance)
    if Fields.PREFERRED_LANGUAGE in data:
        lang = data[Fields.PREFERRED_LANGUAGE]
        if lang not in LanguageValues.ALL:
            raise https_fn.HttpsError("invalid-argument", f"Invalid language. Must be one of: {list(LanguageValues.ALL)}")
        update_data[Fields.PREFERRED_LANGUAGE] = lang
        # Record consent per Quebec Bill 96 / CASL language preference tracking
        update_data[Fields.CONSENT_METHOD] = ConsentMethodValues.USER_PREFERENCE
        update_data[Fields.CONSENT_TIMESTAMP] = get_server_timestamp()

    # Update user document
    user_ref = get_db().collection(Collections.USERS).document(user_id)
    user_doc = user_ref.get()

    if not user_doc.exists:
        raise https_fn.HttpsError("not-found", "User not found")

    user_ref.update(update_data)

    return create_success_response(
        {
            "updated": True,
            "fields": list(update_data.keys()),
        }
    )


@https_fn.on_call(**DEFAULT_OPTIONS)
def get_user_profile(req: https_fn.CallableRequest) -> dict[str, Any]:
    """Get current user's profile including tax exemption status."""
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    user_id = req.auth.uid
    user_ref = get_db().collection(Collections.USERS).document(user_id)
    user_doc = user_ref.get()

    if not user_doc.exists:
        raise https_fn.HttpsError("not-found", "User not found")

    user_data = user_doc.to_dict()

    return create_success_response(
        {
            Fields.UID: user_id,
            Fields.EMAIL: user_data.get(Fields.EMAIL),
            Fields.NAME: user_data.get(Fields.NAME),
            Fields.ADDRESS: user_data.get(Fields.ADDRESS),
            Fields.TAX_EXEMPTION: user_data.get(Fields.TAX_EXEMPTION),
            Fields.ROLES: user_data.get(Fields.ROLES, [UserRoleValues.BUYER]),
            Fields.CREATED_AT: user_data.get(Fields.CREATED_AT),
            Fields.UPDATED_AT: user_data.get(Fields.UPDATED_AT),
        }
    )


@https_fn.on_call(**DEFAULT_OPTIONS)
def update_email_consent(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    CASL compliance: Update user's email marketing consent.

    Canada's Anti-Spam Legislation (CASL) requires:
    - Express consent for commercial electronic messages (CEMs)
    - One-click unsubscribe mechanism
    - Record of consent timestamp and method

    Transactional emails (order confirmations, security alerts) are
    exempt from CASL and are always sent regardless of this setting.

    Request data:
        emailConsent: bool — opt-in (true) or opt-out (false)

    Returns:
        {success: True, emailConsent: bool}
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    user_id = req.auth.uid
    data = req.data

    email_consent = data.get(Fields.EMAIL_CONSENT)
    if not isinstance(email_consent, bool):
        raise https_fn.HttpsError("invalid-argument", "emailConsent must be a boolean")

    user_ref = get_db().collection(Collections.USERS).document(user_id)
    user_doc = user_ref.get()

    if not user_doc.exists:
        raise https_fn.HttpsError("not-found", "User not found")

    user_ref.update(
        {
            Fields.EMAIL_CONSENT: email_consent,
            Fields.CONSENT_TIMESTAMP: get_server_timestamp(),
            Fields.CONSENT_METHOD: ConsentMethodValues.USER_PREFERENCE if email_consent else ConsentMethodValues.UNSUBSCRIBE,
            Fields.UPDATED_AT: get_server_timestamp(),
        }
    )

    return create_success_response(
        {
            Fields.EMAIL_CONSENT: email_consent,
        }
    )


# ============================================================================
# BUYER ADDRESS BOOK MANAGEMENT
# ============================================================================


@https_fn.on_call(**DEFAULT_OPTIONS)
def add_buyer_address(req: https_fn.CallableRequest) -> dict[str, Any]:
    """Add a new address to the buyer's address book."""
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    user_id = req.auth.uid
    data = req.data

    from models.base import Address

    try:
        address = Address(**data)
    except Exception as e:
        raise https_fn.HttpsError("invalid-argument", f"Invalid address: {e}") from e

    if address.country != COUNTRY_CANADA:
        raise https_fn.HttpsError("invalid-argument", "Shipping addresses must be in Canada")

    # ADDR-H2: Server-side geocoding ensures coordinates are verified and accurate
    # Prevents "stuck" users by surfacing specific Geoapify errors.
    from utils.helpers import geocode_address
    success, error_msg, geocoded_address = geocode_address(address.model_dump())
    if not success:
        logger.warning(f"Address geocoding failed for UID {user_id}: {error_msg}")
        raise https_fn.HttpsError("invalid-argument", error_msg)

    address_dict = geocoded_address

    db = get_db()
    from firebase_admin import firestore as _fs

    user_ref = db.collection(Collections.USERS).document(user_id)
    addresses_ref = user_ref.collection(Collections.ADDRESSES)
    new_ref = addresses_ref.document()

    @_fs.transactional
    def _add_address_txn(transaction):
        user_snap = user_ref.get(transaction=transaction)
        user_data = user_snap.to_dict() or {}
        address_count = max(0, int(user_data.get(Fields.ADDRESS_COUNT, 0)))
        if address_count >= 10:
            raise https_fn.HttpsError("resource-exhausted", "Maximum of 10 addresses allowed.")

        addr = dict(address_dict)
        # First address is automatically default
        if address_count == 0:
            addr[Fields.IS_DEFAULT] = True

        # If new address is default, unset the current default
        if addr.get(Fields.IS_DEFAULT) and address_count > 0:
            existing_defaults = list(addresses_ref.where(Fields.IS_DEFAULT, "==", True).get(transaction=transaction))
            for doc in existing_defaults:
                transaction.update(doc.reference, {Fields.IS_DEFAULT: False})

        transaction.set(new_ref, addr)
        transaction.update(user_ref, {Fields.ADDRESS_COUNT: _get_firestore_increment(1)})

    transaction = db.transaction()
    _add_address_txn(transaction)
    address_id = new_ref.id

    return create_success_response({Fields.ADDRESS_ID: address_id})


@https_fn.on_call(**DEFAULT_OPTIONS)
def update_buyer_address(req: https_fn.CallableRequest) -> dict[str, Any]:
    """Update an existing address in the buyer's address book."""
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    user_id = req.auth.uid
    data = req.data
    address_id = data.get(Fields.ADDRESS_ID)

    if not address_id:
        raise https_fn.HttpsError("invalid-argument", "addressId is required")

    # Validate syntax by passing through Pydantic
    from models.base import Address

    try:
        address = Address(**data)
    except Exception as e:
        raise https_fn.HttpsError("invalid-argument", f"Invalid address: {e}") from e

    if address.country != COUNTRY_CANADA:
        raise https_fn.HttpsError("invalid-argument", "Shipping addresses must be in Canada")

    # ADDR-H2: Server-side geocoding on update
    from utils.helpers import geocode_address
    success, error_msg, geocoded_address = geocode_address(address.model_dump())
    if not success:
        logger.warning(f"Address geocoding failed for update UID {user_id}: {error_msg}")
        raise https_fn.HttpsError("invalid-argument", error_msg)

    address_dict = geocoded_address
    address_dict.pop('address_id', None)  # doc ID is read from doc.id — never stored as a field

    db = get_db()
    from firebase_admin import firestore as _fs

    addresses_ref = db.collection(Collections.USERS).document(user_id).collection(Collections.ADDRESSES)
    address_ref = addresses_ref.document(address_id)

    @_fs.transactional
    def _update_address_txn(transaction):
        doc = address_ref.get(transaction=transaction)
        if not doc.exists:
            raise https_fn.HttpsError("not-found", "Address not found")

        was_default = doc.to_dict().get(Fields.IS_DEFAULT, False)
        new_is_default = address_dict.get(Fields.IS_DEFAULT, False)

        # Promoting this address to default: clear any existing default
        if new_is_default and not was_default:
            existing = list(addresses_ref.get(transaction=transaction))
            for existing_doc in existing:
                if existing_doc.id != address_id and existing_doc.to_dict().get(Fields.IS_DEFAULT):
                    transaction.update(existing_doc.reference, {Fields.IS_DEFAULT: False})
            transaction.update(address_ref, address_dict)

        # Demoting current default: auto-promote another address
        elif not new_is_default and was_default:
            existing = list(addresses_ref.get(transaction=transaction))
            if len(existing) > 1:
                promoted = False
                for existing_doc in existing:
                    if existing_doc.id != address_id and not promoted:
                        transaction.update(existing_doc.reference, {Fields.IS_DEFAULT: True})
                        promoted = True
                transaction.update(address_ref, address_dict)
            else:
                # Cannot demote the only address — force it to stay default
                forced = dict(address_dict)
                forced[Fields.IS_DEFAULT] = True
                transaction.update(address_ref, forced)

        # No default change: plain update
        else:
            transaction.update(address_ref, address_dict)

    transaction = db.transaction()
    _update_address_txn(transaction)

    return create_success_response({"updated": True})


@https_fn.on_call(**DEFAULT_OPTIONS)
def delete_buyer_address(req: https_fn.CallableRequest) -> dict[str, Any]:
    """Delete an address from the buyer's address book."""
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    user_id = req.auth.uid
    data = req.data
    address_id = data.get(Fields.ADDRESS_ID)

    if not address_id:
        raise https_fn.HttpsError("invalid-argument", "addressId is required")

    db = get_db()
    addresses_ref = db.collection(Collections.USERS).document(user_id).collection(Collections.ADDRESSES)
    address_ref = addresses_ref.document(address_id)
    doc = address_ref.get()

    if not doc.exists:
        raise https_fn.HttpsError("not-found", "Address not found")

    # Ownership check: verify the address belongs to the calling user
    address_owner_id = address_ref.parent.parent.id if address_ref.parent and address_ref.parent.parent else None
    if address_owner_id != user_id:
        raise https_fn.HttpsError("permission-denied", "You do not have permission to delete this address")

    # ADDR-H1: Prevent deleting address if used by any active (non-final) physical orders
    # Even though orders snapshot the address, deleting it from the book while
    # an order is pending is confusing for UX and prevents re-selection.
    active_order_statuses = [
        OrderStatusValues.PENDING,
        OrderStatusValues.CONFIRMED,
        OrderStatusValues.PROCESSING,
        OrderStatusValues.SHIPPED,
        OrderStatusValues.IN_TRANSIT,
    ]

    # We compare the address snapshot in the order with the current address
    # Since addresses don't have a unique ID that is shared across book and order
    # (they are just maps in orders), we check if ANY active order for this user
    # has a shippingAddress that matches this one.

    active_orders = (
        db.collection(Collections.ORDERS)
        .where(Fields.USER_ID, "==", user_id)
        .where(Fields.ORDER_STATUS, "in", active_order_statuses)
        .stream()
    )

    from utils.helpers import compare_addresses
    current_address = doc.to_dict()
    for order_doc in active_orders:
        order_data = order_doc.to_dict()
        if compare_addresses(order_data.get(Fields.SHIPPING_ADDRESS), current_address):
            raise https_fn.HttpsError(
                "failed-precondition",
                "This address cannot be deleted because it is currently associated with an active order. "
                "Please wait until your order is delivered or cancelled."
            )

    user_ref = db.collection(Collections.USERS).document(user_id)

    from firebase_admin import firestore as _fs

    @_fs.transactional
    def _delete_address_txn(transaction):
        # Re-read inside transaction to ensure consistency under concurrent deletes
        snap = address_ref.get(transaction=transaction)
        if not snap.exists:
            # Idempotent: already deleted by a concurrent request
            return

        is_default = snap.to_dict().get(Fields.IS_DEFAULT, False)
        transaction.delete(address_ref)
        transaction.update(user_ref, {Fields.ADDRESS_COUNT: _get_firestore_increment(-1)})

        if is_default:
            existing = list(addresses_ref.get(transaction=transaction))
            promoted = False
            for existing_doc in existing:
                if existing_doc.id != address_id and not promoted:
                    transaction.update(existing_doc.reference, {Fields.IS_DEFAULT: True})
                    promoted = True

    transaction = db.transaction()
    _delete_address_txn(transaction)

    return create_success_response({"deleted": True})


@https_fn.on_call(**DEFAULT_OPTIONS)
def set_default_buyer_address(req: https_fn.CallableRequest) -> dict[str, Any]:
    """Set an address as the default buyer address."""
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    user_id = req.auth.uid
    data = req.data
    address_id = data.get(Fields.ADDRESS_ID)

    if not address_id:
        raise https_fn.HttpsError("invalid-argument", "addressId is required")

    db = get_db()
    from firebase_admin import firestore as _fs

    addresses_ref = db.collection(Collections.USERS).document(user_id).collection(Collections.ADDRESSES)
    address_ref = addresses_ref.document(address_id)

    @_fs.transactional
    def _set_default_txn(transaction):
        doc = address_ref.get(transaction=transaction)
        if not doc.exists:
            raise https_fn.HttpsError("not-found", "Address not found")
        existing_addresses = addresses_ref.get(transaction=transaction)
        for existing_doc in existing_addresses:
            if existing_doc.id == address_id:
                transaction.update(existing_doc.reference, {Fields.IS_DEFAULT: True})
            elif existing_doc.to_dict().get(Fields.IS_DEFAULT):
                transaction.update(existing_doc.reference, {Fields.IS_DEFAULT: False})

    transaction = db.transaction()
    _set_default_txn(transaction)

    return create_success_response({"updated": True})


@https_fn.on_call(**DEFAULT_OPTIONS)
def update_notification_preferences(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Update premium notification preferences for the authenticated user.
    Uses Admin SDK to prevent field injection attacks.
    Validates isPremium server-side — only premium users can enable these preferences.
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "Authentication required.")

    uid = req.auth.uid
    db = get_db()

    # Validate isPremium from Firestore (never trust client)
    user_doc = db.collection(Collections.USERS).document(uid).get()
    if not user_doc.exists:
        raise https_fn.HttpsError("not-found", "User profile not found.")
    user_data = user_doc.to_dict() or {}
    if not user_data.get(Fields.IS_PREMIUM, False):
        raise https_fn.HttpsError("permission-denied", "Premium membership required to change notification preferences.")

    # Only allow the two notification fields — no other fields accepted
    allowed = {Fields.NOTIFY_NEW_PRODUCTS, Fields.NOTIFY_TRENDING}
    updates = {k: v for k, v in req.data.items() if k in allowed and isinstance(v, bool)}
    if not updates:
        raise https_fn.HttpsError("invalid-argument", "No valid notification fields provided.")

    updates[Fields.UPDATED_AT] = get_server_timestamp()
    db.collection(Collections.USERS).document(uid).update(updates)
    return create_success_response({})


@https_fn.on_call(**DEFAULT_OPTIONS)
def cleanup_fcm_token(req: https_fn.CallableRequest) -> dict[str, Any]:
    """Delete a specific FCM push token for the authenticated user on logout.

    T-3: FCM token cleanup — prevents push notifications to stale/logged-out devices.

    Call this from the Flutter client immediately before FirebaseAuth.signOut().

    Request data:
        - token: str — the FCM registration token (used as the Firestore doc ID)

    Returns:
        {success: True, deleted: bool}
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    uid = req.auth.uid
    data = req.data or {}
    token_id = data.get(Fields.FCM_TOKEN_KEY, "")

    if not token_id or not isinstance(token_id, str):
        raise https_fn.HttpsError("invalid-argument", "token (the FCM registration token) is required")

    db = get_db()
    token_ref = (
        db.collection(Collections.USERS)
        .document(uid)
        .collection(Collections.FCM_TOKENS)
        .document(token_id)
    )
    doc = token_ref.get()

    if not doc.exists:
        # Idempotent — token already gone is not an error
        logger.info("FCM token already removed for uid=%s (idempotent)", uid)
        return create_success_response({"deleted": False})

    token_ref.delete()
    logger.info("FCM token cleaned up on logout for uid=%s", uid)
    return create_success_response({"deleted": True})

