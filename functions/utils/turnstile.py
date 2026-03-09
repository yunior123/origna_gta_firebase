"""
Cloudflare Turnstile verification utility.

Protects new user registration (and other sensitive flows) from bots.
Turnstile is web-only — mobile uses Firebase App Check instead.

Secret stored in APP_SECRETS JSON blob under key 'cloudflare_turnstile_secret'.
Dev: key absent → skip verification (fail open).
If a network error occurs, fail open — never block a legitimate user.
"""

import logging
from typing import Optional

import requests

logger = logging.getLogger(__name__)

_VERIFY_URL = "https://challenges.cloudflare.com/turnstile/v0/siteverify"
_TIMEOUT_S = 5


def verify_turnstile_token(token: Optional[str], remote_ip: Optional[str] = None) -> bool:
    """
    Verify a Cloudflare Turnstile token against the Cloudflare API.

    Returns True  if the token is valid.
    Returns True  if cloudflare_turnstile_secret is absent in APP_SECRETS (dev).
    Returns False if the token is present but invalid.
    Returns True  on network errors (fail open — never block legitimate users).
    """
    from config import _secrets  # local import avoids circular at module load

    secret = _secrets().get("cloudflare_turnstile_secret", "")
    if not secret:
        # Not configured — skip verification (dev environment)
        return True

    if not token:
        logger.warning("Turnstile: empty token rejected")
        return False

    payload: dict = {"secret": secret, "response": token}
    if remote_ip:
        payload["remoteip"] = remote_ip

    try:
        resp = requests.post(_VERIFY_URL, data=payload, timeout=_TIMEOUT_S)
        resp.raise_for_status()
        result = resp.json()
        success = bool(result.get("success", False))
        if not success:
            logger.warning(
                "Turnstile: token rejected — error_codes=%s",
                result.get("error-codes", []),
            )
        return success
    except Exception as exc:
        # Fail open — Cloudflare network hiccup must not block users
        logger.warning("Turnstile: verification request failed (%s) — allowing through", exc)
        return True
