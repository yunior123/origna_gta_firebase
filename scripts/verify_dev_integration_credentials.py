#!/usr/bin/env python3
"""Module verify_dev_integration_credentials.py."""

import argparse
import json
import re
import ssl
import urllib.error
import urllib.request
from pathlib import Path

try:
    import certifi  # type: ignore
except Exception:  # pragma: no cover
    certifi = None


def _read_dev_api_key(repo_root: Path) -> str:
    dev_config = repo_root / "origna_gta" / "lib" / "config" / "firebase_config_dev.dart"
    content = dev_config.read_text(encoding="utf-8")
    # Example: apiKey: 'AIzaSy...'
    m = re.search(r"apiKey\s*:\s*'([^']+)'", content)
    if not m:
        raise RuntimeError(f"Could not find apiKey in {dev_config}")
    return m.group(1)


def _post_json(url: str, payload: dict) -> tuple[int, dict]:
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    context = None
    # macOS Python installs can fail to locate system CA roots.
    # Prefer certifi's CA bundle when available.
    if certifi is not None:
        context = ssl.create_default_context(cafile=certifi.where())

    try:
        with urllib.request.urlopen(req, timeout=20, context=context) as resp:
            body = resp.read().decode("utf-8")
            return resp.status, json.loads(body) if body else {}
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8")
        try:
            parsed = json.loads(body) if body else {}
        except Exception:
            parsed = {"raw": body}
        return e.code, parsed


def _validate_password(role: str, api_key: str, email: str, password: str) -> bool:
    if not email.strip() or not password:
        print(f"FAIL {role}: missing email/password (check your defines file)")
        return False
    if "__FILL_ME__" in password:
        print(f"FAIL {role}: password is still __FILL_ME__")
        return False

    url = f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={api_key}"
    status, data = _post_json(
        url,
        {"email": email, "password": password, "returnSecureToken": True},
    )

    if status == 200 and isinstance(data, dict) and data.get("idToken"):
        print(f"OK {role}")
        return True

    err_code = None
    if isinstance(data, dict):
        err = data.get("error")
        if isinstance(err, dict):
            err_code = err.get("message")

    print(f"FAIL {role}: {err_code or f'HTTP_{status}'}")
    return False


def main() -> int:
    """Function main."""
    parser = argparse.ArgumentParser(
        description=(
            "Verify integration TEST_* passwords against DEV Firebase Auth (signInWithPassword). "
            "Does not print emails or passwords."
        )
    )
    parser.add_argument(
        "--defines",
        required=True,
        help="Path to JSON used for --dart-define-from-file (contains TEST_* keys)",
    )
    parser.add_argument(
        "--api-key",
        default=None,
        help="Override Firebase Web API key (defaults to reading firebase_config_dev.dart)",
    )

    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[1]
    defines_path = Path(args.defines).expanduser().resolve()

    defines = json.loads(defines_path.read_text(encoding="utf-8"))
    api_key = args.api_key or _read_dev_api_key(repo_root)

    buyer_email = str(defines.get("TEST_BUYER_EMAIL", ""))
    buyer_password = str(defines.get("TEST_BUYER_PASSWORD", ""))
    seller_email = str(defines.get("TEST_SELLER_EMAIL", ""))
    seller_password = str(defines.get("TEST_SELLER_PASSWORD", ""))
    admin_email = str(defines.get("TEST_ADMIN_EMAIL", ""))
    admin_password = str(defines.get("TEST_ADMIN_PASSWORD", ""))

    # Allow seller to reuse admin creds if not provided.
    if not seller_email.strip():
        seller_email = admin_email
    if not seller_password:
        seller_password = admin_password

    ok = True
    ok &= _validate_password("buyer", api_key, buyer_email, buyer_password)
    ok &= _validate_password("seller", api_key, seller_email, seller_password)
    ok &= _validate_password("admin", api_key, admin_email, admin_password)

    return 0 if ok else 2


if __name__ == "__main__":
    raise SystemExit(main())
