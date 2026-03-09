"""Digital product handlers: license activation, book redirect, deactivation."""

import json
import logging
import re
import secrets
from datetime import UTC, datetime, timedelta

from firebase_functions import https_fn

from schema_constants import (
    ApiKeys,
    Collections,
    DigitalTypeValues,
    Fields,
    LicenseStatusValues,
    RateLimitActions,
)
from services.rate_limiter import RateLimiter
from utils.db import get_db
from utils.function_options import DEFAULT_OPTIONS, WEBHOOK_OPTIONS

logger = logging.getLogger(__name__)


# Regex for license key format validation (prevents DB lookup on garbage input)
_LICENSE_KEY_RE = re.compile(r"^[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$")
_TOKEN_RE = re.compile(r"^tok_[a-f0-9]+$")  # relaxed for tests (hex suffix length varies)

APP_BASE_URL = "https://app.origna.com"

try:
    from config import BASE_URL as _BASE_URL
    APP_BASE_URL = _BASE_URL
except ImportError:
    logger.info("config.BASE_URL not available; using default APP_BASE_URL")


# ── Internal implementations (pure functions, testable without HTTP context) ──


def _activate_license_impl(license_key: str, device_id: str, platform: str, caller_uid: str | None = None) -> dict:
    """Core activation logic. Raises ValueError with error code on failure.
    caller_uid: if provided, verifies the license belongs to this user (ownership enforcement).
    """
    if not _LICENSE_KEY_RE.match(license_key):
        raise ValueError("invalid_key_format")

    db = get_db()
    lic_doc = db.collection(Collections.LICENSES).document(license_key).get()
    if not lic_doc.exists:
        raise ValueError("not_found")

    lic = lic_doc.to_dict()
    if lic.get(Fields.STATUS) != LicenseStatusValues.ACTIVE:
        raise ValueError("revoked")

    # Ownership check: verify the caller owns this license (only when authenticated)
    # verify_license is intentionally unauthenticated — the license key acts as the credential
    if caller_uid and lic.get(Fields.USER_ID) != caller_uid:
        raise ValueError("unauthorized")

    supported = lic.get(Fields.SUPPORTED_PLATFORMS, [])
    if platform not in supported:
        raise ValueError("platform_not_supported")

    activations: list = list(lic.get(Fields.ACTIVATIONS, []))
    now = datetime.now(UTC)

    # Idempotent re-activation: same device already registered
    digital_type = lic.get(Fields.DIGITAL_TYPE)
    for i, act in enumerate(activations):
        if act.get(Fields.DEVICE_ID) == device_id:
            activations[i] = {**act, Fields.LAST_VERIFIED_AT: now}
            db.collection(Collections.LICENSES).document(license_key).update(
                {"activations": activations, "updatedAt": now}
            )
            builds = lic.get(Fields.DIGITAL_BUILDS, {})
            activated_at = act.get("activatedAt")
            # Never expose real seller download URLs — software downloads use /sdl token redirect
            safe_builds: dict = {p: "" for p in builds} if digital_type == DigitalTypeValues.SOFTWARE else {}
            return {
                "approved": True,
                "licenseKey": license_key,
                "activatedAt": activated_at.isoformat() if hasattr(activated_at, 'isoformat') else str(activated_at) if activated_at else None,
                Fields.PRODUCT_NAME: lic.get(Fields.PRODUCT_NAME, ""),
                "platforms": list(builds.keys()) if builds else [],
                "downloadUrls": safe_builds,
            }

    # SECURITY FIX: Unauthenticated callers (verify_license path) may only RE-VERIFY
    # existing device IDs, never register a new one. License key sharing would otherwise
    # grant free activations up to the device_limit without any ownership check.
    if not caller_uid:
        raise ValueError("auth_required_for_new_device")

    # Check device limit
    device_limit = lic.get(Fields.DEVICE_LIMIT)
    if device_limit is not None and len(activations) >= device_limit:
        raise ValueError("device_limit_exceeded")

    # New activation
    new_activation = {
        Fields.DEVICE_ID: device_id,
        "platform": platform,
        "activatedAt": now,
        Fields.LAST_VERIFIED_AT: now,
    }
    activations.append(new_activation)
    db.collection(Collections.LICENSES).document(license_key).update({"activations": activations, "updatedAt": now})

    builds = lic.get(Fields.DIGITAL_BUILDS, {})
    # Never expose real seller download URLs — software downloads use /sdl token redirect
    safe_builds_new: dict = {p: "" for p in builds} if digital_type == DigitalTypeValues.SOFTWARE else {}
    return {
        "approved": True,
        "licenseKey": license_key,
        "activatedAt": now.isoformat(),
        Fields.PRODUCT_NAME: lic.get(Fields.PRODUCT_NAME, ""),
        "platforms": list(builds.keys()) if builds else [],
        "downloadUrls": safe_builds_new,
    }


def _deactivate_license_impl(license_key: str, device_id: str, caller_uid: str) -> dict:
    """Remove a device activation. Requires caller to be the license owner."""
    if not _LICENSE_KEY_RE.match(license_key):
        raise ValueError("invalid_key_format")

    db = get_db()
    lic_doc = db.collection(Collections.LICENSES).document(license_key).get()
    if not lic_doc.exists:
        raise ValueError("not_found")

    lic = lic_doc.to_dict()
    if lic.get(Fields.USER_ID) != caller_uid:
        raise ValueError("unauthorized")

    activations = [a for a in lic.get(Fields.ACTIVATIONS, []) if a.get(Fields.DEVICE_ID) != device_id]
    db.collection(Collections.LICENSES).document(license_key).update(
        {"activations": activations, "updatedAt": datetime.now(UTC)}
    )
    return {"deactivated": True, "remainingActivations": len(activations)}


def _generate_book_download_session_impl(license_key: str, caller_uid: str) -> dict:
    """Create a new 15-min single-use download token for a book license.
    Returns { downloadUrl } pointing to /dl?t={token}.
    """
    if not _LICENSE_KEY_RE.match(license_key):
        raise ValueError("invalid_key_format")

    db = get_db()
    lic_doc = db.collection(Collections.LICENSES).document(license_key).get()
    if not lic_doc.exists:
        raise ValueError("not_found")

    lic = lic_doc.to_dict()
    if lic.get(Fields.USER_ID) != caller_uid:
        raise ValueError("unauthorized")
    if lic.get(Fields.STATUS) != LicenseStatusValues.ACTIVE:
        raise ValueError("revoked")
    if lic.get(Fields.DIGITAL_TYPE) != DigitalTypeValues.BOOK:
        raise ValueError("not_a_book_license")

    token = "tok_" + secrets.token_hex(32)
    now = datetime.now(UTC)
    token_doc = {
        Fields.ACCESS_TOKEN: token,
        Fields.LICENSE_KEY: license_key,
        Fields.USER_ID: caller_uid,
        Fields.PRODUCT_ID: lic.get(Fields.PRODUCT_ID),
        Fields.BOOK_SOURCE_URL: lic.get(Fields.BOOK_SOURCE_URL),
        "expiresAt": now + timedelta(minutes=15),
        "used": False,
        Fields.CREATED_AT: now,
    }
    db.collection(Collections.BOOK_ACCESS_TOKENS).document(token).set(token_doc)

    return {ApiKeys.DOWNLOAD_URL: f"{APP_BASE_URL}/dl?t={token}"}


def _get_book_redirect_impl(token: str) -> str:
    """Validate token and return the bookSourceUrl for redirect.
    Marks token as used to prevent re-use.
    Raises ValueError with error code on any failure.
    """
    db = get_db()
    token_ref = db.collection(Collections.BOOK_ACCESS_TOKENS).document(token)
    doc = token_ref.get()

    if not doc.exists:
        raise ValueError("not_found")

    data = doc.to_dict()
    now = datetime.now(UTC)

    # Atomically mark token as used — prevents double-use on concurrent requests
    from firebase_admin import firestore as _fs_tok

    @_fs_tok.transactional
    def _mark_used(txn, ref):
        snap = ref.get(transaction=txn)
        tok_data = snap.to_dict() or {}
        if tok_data.get("used"):
            raise ValueError("already_used")
        expires_at = tok_data.get("expiresAt")
        if hasattr(expires_at, "tzinfo"):
            expires_dt = expires_at if expires_at.tzinfo else expires_at.replace(tzinfo=UTC)
        else:
            expires_dt = expires_at
        if expires_dt is not None and expires_dt < now:
            raise ValueError("expired")
        txn.update(ref, {"used": True, "usedAt": now})
        return tok_data

    data = _mark_used(db.transaction(), token_ref)

    book_url = data.get(Fields.BOOK_SOURCE_URL, "")
    if not book_url:
        raise ValueError("missing_source_url")
    return book_url


def _revoke_digital_licenses_for_order(order_id: str) -> int:
    """Revoke all active licenses belonging to an order.

    Idempotent: already-revoked licenses are skipped.
    Returns count of licenses updated to revoked.
    Called on any refund (partial or full) — lifetime license model means
    any refund invalidates the license.
    """
    db = get_db()
    # Cost fix: limit to 100 — an order cannot have more licenses than cart items (bounded by MAX_CART_ITEMS)
    licenses = db.collection(Collections.LICENSES).where(Fields.ORDER_ID, "==", order_id).limit(100).stream()
    count = 0
    now = datetime.now(UTC)
    batch = db.batch()
    for lic_doc in licenses:
        lic = lic_doc.to_dict()
        if lic.get(Fields.STATUS) == LicenseStatusValues.ACTIVE:
            batch.update(
                lic_doc.reference,
                {
                    Fields.STATUS: LicenseStatusValues.REVOKED,
                    "revokedAt": now,
                    "revokedReason": "refunded",
                    Fields.UPDATED_AT: now,
                },
            )
            count += 1
            logger.info(f"License {lic_doc.id} revoked for order {order_id} (refund)")
    if count > 0:
        batch.commit()
    return count


# ── Cloud Function endpoints ──────────────────────────────────────────────────


@https_fn.on_request(**WEBHOOK_OPTIONS)
def activate_license(req: https_fn.Request) -> https_fn.Response:
    """POST /activate_license — supports authenticated and unauthenticated callers.
    Body: { licenseKey, deviceId, platform }  OR Firebase callable wrapper: { data: {...} }
    If Authorization header is present, verifies ownership (licenseKey must belong to the caller).
    """
    if req.method != "POST":
        return https_fn.Response("Method not allowed", status=405)

    try:
        body = req.get_json(silent=True) or {}
        # Accept both direct format { licenseKey, ... } and Firebase callable wrapper { data: { licenseKey, ... } }
        data = body.get("data", body) if isinstance(body.get("data"), dict) else body
        license_key = str(data.get("licenseKey", "")).strip().upper()
        device_id = str(data.get("deviceId", "")).strip()
        platform = str(data.get("platform", "")).strip().lower()

        if not license_key or not device_id or not platform:
            return https_fn.Response(
                json.dumps({"error": "licenseKey, deviceId, and platform are required"}),
                status=400,
                content_type="application/json",
            )

        # Verify caller identity from Authorization header (required)
        caller_uid: str | None = None
        auth_header = req.headers.get("Authorization", "")
        if not auth_header.startswith("Bearer "):
            return https_fn.Response(
                json.dumps({"error": "unauthenticated", "message": "Authorization required to activate a license"}),
                status=401,
                content_type="application/json",
            )
        id_token = auth_header[len("Bearer "):]
        try:
            from firebase_admin import auth as fb_auth
            decoded = fb_auth.verify_id_token(id_token)
            caller_uid = decoded["uid"]
        except Exception:
            return https_fn.Response(
                json.dumps({"error": "invalid_token", "message": "Invalid authorization token"}),
                status=401,
                content_type="application/json",
            )

        # Rate limit: 10 attempts per device per 10 min to block brute-force
        rate_id = f"device:{device_id[:64]}"
        limiter = RateLimiter(get_db())
        allowed, msg = limiter.check_rate_limit(
            identifier=rate_id,
            action=RateLimitActions.ACTIVATE_LICENSE,
            max_requests=10,
            window_minutes=10,
            fail_closed=True,
        )
        if not allowed:
            return https_fn.Response(
                json.dumps({"error": "rate_limited", "message": msg}),
                status=429,
                content_type="application/json",
            )

        result = _activate_license_impl(license_key, device_id, platform, caller_uid)
        # Wrap result in Firebase callable format so callCallable/callOk works correctly
        return https_fn.Response(json.dumps({"result": result}), status=200, content_type="application/json")

    except ValueError as e:
        code = str(e)
        status_map = {
            "not_found": 404,
            "revoked": 403,
            "platform_not_supported": 403,
            "device_limit_exceeded": 403,
            "invalid_key_format": 400,
            "unauthorized": 403,
        }
        status = status_map.get(code, 400)
        msg_map = {
            "unauthorized": "You do not own this license",
            "not_found": "License key not found",
            "revoked": "License has been revoked",
            "platform_not_supported": "Platform not supported by this license",
            "device_limit_exceeded": "Device activation limit reached",
            "invalid_key_format": "Invalid license key format",
        }
        return https_fn.Response(
            json.dumps({"error": {"code": code, "message": msg_map.get(code, code)}}),
            status=status,
            content_type="application/json",
        )
    except Exception:
        logger.exception("activate_license unexpected error")
        return https_fn.Response(json.dumps({"error": {"code": "internal_error", "message": "Internal error"}}), status=500, content_type="application/json")


@https_fn.on_call(**DEFAULT_OPTIONS)
def deactivate_license(req: https_fn.CallableRequest) -> dict:
    """Authenticated: buyer removes a device from their license."""
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "Login required")

    license_key = str(req.data.get("licenseKey", "")).strip().upper()
    device_id = str(req.data.get("deviceId", "")).strip()
    if not license_key or not device_id:
        raise https_fn.HttpsError("invalid-argument", "licenseKey and deviceId required")

    try:
        return _deactivate_license_impl(license_key, device_id, req.auth.uid)
    except ValueError as e:
        code = str(e)
        if code == "not_found":
            raise https_fn.HttpsError("not-found", "License not found") from e
        if code == "unauthorized":
            raise https_fn.HttpsError("permission-denied", "Not your license") from e
        raise https_fn.HttpsError("invalid-argument", code) from e


@https_fn.on_call(**DEFAULT_OPTIONS)
def generate_book_download_session(req: https_fn.CallableRequest) -> dict:
    """Authenticated: generates a 15-min single-use redirect token for a book."""
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "Login required")

    license_key = str(req.data.get("licenseKey", "")).strip().upper()
    if not license_key:
        raise https_fn.HttpsError("invalid-argument", "licenseKey required")

    try:
        return _generate_book_download_session_impl(license_key, req.auth.uid)
    except ValueError as e:
        code = str(e)
        if code == "not_found":
            raise https_fn.HttpsError("not-found", "License not found") from e
        if code == "unauthorized":
            raise https_fn.HttpsError("permission-denied", "Not your license") from e
        if code == "revoked":
            raise https_fn.HttpsError("failed-precondition", "License revoked") from e
        raise https_fn.HttpsError("invalid-argument", code) from e


@https_fn.on_request(**WEBHOOK_OPTIONS)
def get_book_redirect(req: https_fn.Request) -> https_fn.Response:
    """GET /dl?t={token} — public redirect, no auth.
    Single-use, 15-min expiry. bookSourceUrl never sent to client.
    """
    token = req.args.get("t", "").strip()
    if not token:
        return https_fn.Response("Missing token", status=400)

    try:
        book_url = _get_book_redirect_impl(token)
        return https_fn.Response(
            "",
            status=302,
            headers={"Location": book_url, "Cache-Control": "no-store"},
        )
    except ValueError as e:
        code = str(e)
        messages = {
            "not_found": "Download link not found.",
            "already_used": "This download link has already been used. Return to the app to generate a new one.",
            "expired": "This download link has expired. Return to the app to generate a new one.",
            "invalid_token_format": "Invalid download link.",
        }
        msg = messages.get(code, "Invalid request.")
        return https_fn.Response(msg, status=410)
    except Exception:
        logger.exception("get_book_redirect unexpected error")
        return https_fn.Response("Internal error", status=500)


def _generate_software_download_session_impl(license_key: str, platform: str, caller_uid: str) -> dict:
    """Create a 15-min single-use redirect token for a software build.
    The actual download URL (from digitalBuilds) is never sent to the client.
    Returns { downloadUrl } pointing to /sdl?t={token}.
    """
    if not _LICENSE_KEY_RE.match(license_key):
        raise ValueError("invalid_key_format")

    db = get_db()
    lic_doc = db.collection(Collections.LICENSES).document(license_key).get()
    if not lic_doc.exists:
        raise ValueError("not_found")

    lic = lic_doc.to_dict()
    if lic.get(Fields.USER_ID) != caller_uid:
        raise ValueError("unauthorized")
    if lic.get(Fields.STATUS) != LicenseStatusValues.ACTIVE:
        raise ValueError("revoked")
    if lic.get(Fields.DIGITAL_TYPE) != DigitalTypeValues.SOFTWARE:
        raise ValueError("not_a_software_license")

    builds = lic.get(Fields.DIGITAL_BUILDS) or {}
    if platform not in builds:
        raise ValueError("platform_not_supported")

    download_url = builds[platform]

    token = "tok_" + secrets.token_hex(32)
    now = datetime.now(UTC)
    token_doc = {
        Fields.ACCESS_TOKEN: token,
        Fields.LICENSE_KEY: license_key,
        Fields.USER_ID: caller_uid,
        Fields.PRODUCT_ID: lic.get(Fields.PRODUCT_ID),
        "platform": platform,
        ApiKeys.DOWNLOAD_URL: download_url,  # stored server-side only
        "expiresAt": now + timedelta(minutes=15),
        "used": False,
        Fields.CREATED_AT: now,
    }
    db.collection(Collections.SOFTWARE_ACCESS_TOKENS).document(token).set(token_doc)

    return {ApiKeys.DOWNLOAD_URL: f"{APP_BASE_URL}/sdl?t={token}"}


def _get_software_redirect_impl(token: str) -> str:
    """Validate token, mark used, return the seller's download URL for redirect.
    Raises ValueError with error code on any failure.
    """
    db = get_db()
    token_ref = db.collection(Collections.SOFTWARE_ACCESS_TOKENS).document(token)
    doc = token_ref.get()

    if not doc.exists:
        raise ValueError("not_found")

    from firebase_admin import firestore as _fs_stok

    now = datetime.now(UTC)

    @_fs_stok.transactional
    def _mark_used(txn, ref):
        snap = ref.get(transaction=txn)
        tok_data = snap.to_dict() or {}
        if tok_data.get("used"):
            raise ValueError("already_used")
        expires_at = tok_data.get("expiresAt")
        if hasattr(expires_at, "tzinfo"):
            expires_dt = expires_at if expires_at.tzinfo else expires_at.replace(tzinfo=UTC)
        else:
            expires_dt = expires_at
        if expires_dt is not None and expires_dt < now:
            raise ValueError("expired")
        txn.update(ref, {"used": True, "usedAt": now})
        return tok_data

    data = _mark_used(db.transaction(), token_ref)

    url = data.get(ApiKeys.DOWNLOAD_URL, "")
    if not url:
        raise ValueError("missing_source_url")
    return url


@https_fn.on_call(**DEFAULT_OPTIONS)
def generate_software_download_session(req: https_fn.CallableRequest) -> dict:
    """Authenticated: generates a 15-min single-use redirect token for a software build.
    Request: { licenseKey: string, platform: "macos"|"windows"|"linux" }
    Response: { downloadUrl: string }  — points to /sdl?t={token}
    The seller's actual download URL is never sent to the client.
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "Login required")

    license_key = str(req.data.get("licenseKey", "")).strip().upper()
    platform = str(req.data.get("platform", "")).strip().lower()
    if not license_key or not platform:
        raise https_fn.HttpsError("invalid-argument", "licenseKey and platform required")

    try:
        return _generate_software_download_session_impl(license_key, platform, req.auth.uid)
    except ValueError as e:
        code = str(e)
        error_map = {
            "not_found": ("not-found", "License not found"),
            "unauthorized": ("permission-denied", "Not your license"),
            "revoked": ("failed-precondition", "License revoked"),
            "not_a_software_license": ("failed-precondition", "Not a software license"),
            "platform_not_supported": ("failed-precondition", "Platform not available for this license"),
        }
        fn_code, msg = error_map.get(code, ("invalid-argument", code))
        raise https_fn.HttpsError(fn_code, msg) from e


@https_fn.on_request(**WEBHOOK_OPTIONS)
def get_software_redirect(req: https_fn.Request) -> https_fn.Response:
    """GET /sdl?t={token} — public redirect, no auth.
    Single-use, 15-min expiry. Seller's download URL never exposed to client.
    """
    token = req.args.get("t", "").strip()
    if not token:
        return https_fn.Response("Missing token", status=400)

    try:
        url = _get_software_redirect_impl(token)
        return https_fn.Response(
            "",
            status=302,
            headers={"Location": url, "Cache-Control": "no-store, no-cache"},
        )
    except ValueError as e:
        code = str(e)
        messages = {
            "not_found": "Download link not found.",
            "already_used": "This download link has already been used. Return to the app to generate a new one.",
            "expired": "This download link has expired. Return to the app to generate a new one.",
        }
        msg = messages.get(code, "Invalid request.")
        return https_fn.Response(msg, status=410)
    except Exception:
        logger.exception("get_software_redirect unexpected error")
        return https_fn.Response("Internal error", status=500)


@https_fn.on_request(**WEBHOOK_OPTIONS)
def verify_license(req: https_fn.Request) -> https_fn.Response:
    """POST /verify_license — no auth. App periodically re-verifies license.
    Same as activate (idempotent re-activation updates lastVerifiedAt).
    Body: { licenseKey, deviceId, platform }
    """
    if req.method != "POST":
        return https_fn.Response("Method not allowed", status=405)

    try:
        body = req.get_json(silent=True) or {}
        license_key = str(body.get("licenseKey", "")).strip().upper()
        device_id = str(body.get("deviceId", "")).strip()
        platform = str(body.get("platform", "")).strip().lower()

        if not license_key or not device_id or not platform:
            return https_fn.Response(
                json.dumps({"error": "licenseKey, deviceId, platform required"}),
                status=400,
                content_type="application/json",
            )

        # Rate limit: 60 verify calls per device per hour (app calls this on launch)
        limiter = RateLimiter(get_db())
        allowed, msg = limiter.check_rate_limit(
            identifier=f"device:{device_id[:64]}",
            action=RateLimitActions.VERIFY_LICENSE,
            max_requests=60,
            window_minutes=60,
            fail_closed=False,
        )
        if not allowed:
            return https_fn.Response(
                json.dumps({"error": "rate_limited"}),
                status=429,
                content_type="application/json",
            )

        # IP-level rate limit: 200 calls per IP per hour (guards against distributed brute-force)
        ip_key = f"ip:{req.remote_addr}"
        ip_allowed, _ = limiter.check_rate_limit(
            identifier=ip_key,
            action=RateLimitActions.VERIFY_LICENSE_IP,
            max_requests=200,
            window_minutes=60,
            fail_closed=False,
        )
        if not ip_allowed:
            return https_fn.Response(
                json.dumps({"error": "rate_limited", "message": "Too many requests"}),
                status=429,
                content_type="application/json",
            )

        result = _activate_license_impl(license_key, device_id, platform)
        return https_fn.Response(json.dumps(result), status=200, content_type="application/json")

    except ValueError as e:
        code = str(e)
        status = 403 if code in ("revoked", "device_limit_exceeded") else 400
        return https_fn.Response(json.dumps({"error": code}), status=status, content_type="application/json")
    except Exception:
        logger.exception("verify_license unexpected error")
        return https_fn.Response(json.dumps({"error": "internal_error"}), status=500, content_type="application/json")
