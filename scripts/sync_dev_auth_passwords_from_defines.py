#!/usr/bin/env python3
"""Module sync_dev_auth_passwords_from_defines.py."""

import argparse
import json
from pathlib import Path

import firebase_admin
from firebase_admin import auth, credentials


def _require_not_prod(project_id: str) -> None:
    if project_id.strip() == "orignagta":
        raise SystemExit(
            "Refusing to modify prod project 'orignagta'. Use --project orignagta-dev."
        )


def _read_defines(defines_path: Path) -> dict:
    data = json.loads(defines_path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise SystemExit("Defines file must be a JSON object")
    return data


def _get_str(defines: dict, key: str) -> str:
    val = defines.get(key, "")
    return "" if val is None else str(val)


def _validate_inputs(role: str, email: str, password: str) -> None:
    if not email.strip():
        raise SystemExit(f"{role}: missing email")
    if not password:
        raise SystemExit(f"{role}: missing password")
    if "__FILL_ME__" in password:
        raise SystemExit(f"{role}: password still __FILL_ME__")


def _init_admin(repo_root: Path, project_id: str, REDACTED_SECRET_path: str | None) -> None:
    if firebase_admin._apps:
        return

    candidate_paths: list[Path] = []
    if REDACTED_SECRET_path:
        candidate_paths.append(Path(REDACTED_SECRET_path).expanduser().resolve())

    # Common local path (gitignored) in this repo.
    candidate_paths.append(repo_root / "functions" / "serviceAccountKey.json")

    for path in candidate_paths:
        if path.exists():
            firebase_admin.initialize_app(
                credential=credentials.Certificate(str(path)),
                options={"projectId": project_id},
            )
            return

    # Fallback to ADC (requires `gcloud auth application-default login`).
    firebase_admin.initialize_app(
        credential=credentials.ApplicationDefault(),
        options={"projectId": project_id},
    )


def _ensure_password(email: str, password: str) -> None:
    try:
        user = auth.get_user_by_email(email)
        auth.update_user(user.uid, password=password, email_verified=True)
    except auth.UserNotFoundError:
        auth.create_user(email=email, password=password, email_verified=True)


def main() -> int:
    """Function main."""
    parser = argparse.ArgumentParser(
        description=(
            "Sync DEV Firebase Auth passwords from an integration defines JSON. "
            "Does not print emails/passwords. Refuses to run on prod."
        )
    )
    parser.add_argument(
        "--project",
        default="orignagta-dev",
        help="Firebase project id (default: orignagta-dev)",
    )
    parser.add_argument(
        "--defines",
        required=True,
        help="Path to JSON used for --dart-define-from-file (contains TEST_* keys)",
    )
    parser.add_argument(
        "--service-account",
        default=None,
        help=(
            "Path to a Firebase service account JSON (optional). "
            "If omitted, tries functions/serviceAccountKey.json, then ADC."
        ),
    )

    args = parser.parse_args()

    project_id = str(args.project)
    _require_not_prod(project_id)

    repo_root = Path(__file__).resolve().parents[1]

    defines_path = Path(args.defines).expanduser().resolve()
    defines = _read_defines(defines_path)

    buyer_email = _get_str(defines, "TEST_BUYER_EMAIL")
    buyer_password = _get_str(defines, "TEST_BUYER_PASSWORD")
    seller_email = _get_str(defines, "TEST_SELLER_EMAIL")
    seller_password = _get_str(defines, "TEST_SELLER_PASSWORD")
    admin_email = _get_str(defines, "TEST_ADMIN_EMAIL")
    admin_password = _get_str(defines, "TEST_ADMIN_PASSWORD")

    # Allow seller to reuse admin creds if not provided.
    if not seller_email.strip():
        seller_email = admin_email
    if not seller_password:
        seller_password = admin_password

    _validate_inputs("buyer", buyer_email, buyer_password)
    _validate_inputs("seller", seller_email, seller_password)
    _validate_inputs("admin", admin_email, admin_password)

    _init_admin(repo_root, project_id, args.REDACTED_SECRET)

    # Ensure accounts exist + force passwords.
    _ensure_password(buyer_email, buyer_password)
    _ensure_password(seller_email, seller_password)
    _ensure_password(admin_email, admin_password)

    # Minimal output; safe for logs.
    print("OK synced buyer/seller/admin passwords on DEV")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
