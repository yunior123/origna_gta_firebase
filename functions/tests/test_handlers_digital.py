"""Tests for digital product API handlers (license activation, book redirect)."""

from datetime import UTC, datetime, timedelta, timezone
from unittest.mock import MagicMock, call, patch

import pytest

# ── Helpers ────────────────────────────────────────────────────────────────────


def _make_license(overrides=None):
    base = {
        "licenseKey": "ABCD-EFGH-IJKL-MNOP",
        "productId": "prod123",
        "orderId": "order123",
        "userId": "buyer123",
        "digitalType": "software",
        "status": "active",
        "supportedPlatforms": ["macos", "windows"],
        "deviceLimit": 3,
        "activations": [],
        "digitalBuilds": {
            "macos": "https://example.com/app.dmg",
            "windows": "https://example.com/app.exe",
        },
    }
    if overrides:
        base.update(overrides)
    return base


# ── activate_license ────────────────────────────────────────────────────────────


def test_activate_license_success(mocker):
    """Valid license + valid platform + under device limit → approved"""
    from handlers.digital import _activate_license_impl

    license_data = _make_license()
    mock_doc = MagicMock()
    mock_doc.exists = True
    mock_doc.to_dict.return_value = license_data
    mock_db = MagicMock()
    mock_db.collection.return_value.document.return_value.get.return_value = mock_doc

    with patch("handlers.digital.get_db", return_value=mock_db):
        result = _activate_license_impl("ABCD-EFGH-IJKL-MNOP", "device-uuid-001", "macos", caller_uid="buyer123")

    assert result["approved"] is True
    assert result["licenseKey"] == "ABCD-EFGH-IJKL-MNOP"
    assert "productName" in result


def test_activate_license_not_found(mocker):
    """Non-existent license key → 404"""
    from handlers.digital import _activate_license_impl

    mock_doc = MagicMock()
    mock_doc.exists = False
    mock_db = MagicMock()
    mock_db.collection.return_value.document.return_value.get.return_value = mock_doc

    with patch("handlers.digital.get_db", return_value=mock_db), pytest.raises(Exception, match="not_found"):
        _activate_license_impl("XXXX-XXXX-XXXX-XXXX", "device1", "macos", caller_uid="buyer123")


def test_activate_license_revoked(mocker):
    """Revoked license → 403"""
    from handlers.digital import _activate_license_impl

    license_data = _make_license({"status": "revoked"})
    mock_doc = MagicMock()
    mock_doc.exists = True
    mock_doc.to_dict.return_value = license_data
    mock_db = MagicMock()
    mock_db.collection.return_value.document.return_value.get.return_value = mock_doc

    with patch("handlers.digital.get_db", return_value=mock_db), pytest.raises(Exception, match="revoked"):
        _activate_license_impl("ABCD-EFGH-IJKL-MNOP", "device1", "macos", caller_uid="buyer123")


def test_activate_license_wrong_platform(mocker):
    """Platform not in supportedPlatforms → 403"""
    from handlers.digital import _activate_license_impl

    license_data = _make_license({"supportedPlatforms": ["macos"]})
    mock_doc = MagicMock()
    mock_doc.exists = True
    mock_doc.to_dict.return_value = license_data
    mock_db = MagicMock()
    mock_db.collection.return_value.document.return_value.get.return_value = mock_doc

    with (
        patch("handlers.digital.get_db", return_value=mock_db),
        pytest.raises(Exception, match="platform_not_supported"),
    ):
        _activate_license_impl("ABCD-EFGH-IJKL-MNOP", "device1", "linux", caller_uid="buyer123")


def test_activate_license_device_limit_exceeded(mocker):
    """All device slots filled → 403"""
    from handlers.digital import _activate_license_impl

    activations = [{"deviceId": f"dev{i}", "platform": "macos"} for i in range(3)]
    license_data = _make_license({"deviceLimit": 3, "activations": activations})
    mock_doc = MagicMock()
    mock_doc.exists = True
    mock_doc.to_dict.return_value = license_data
    mock_db = MagicMock()
    mock_db.collection.return_value.document.return_value.get.return_value = mock_doc

    with (
        patch("handlers.digital.get_db", return_value=mock_db),
        pytest.raises(Exception, match="device_limit_exceeded"),
    ):
        _activate_license_impl("ABCD-EFGH-IJKL-MNOP", "dev-new", "macos", caller_uid="buyer123")


def test_activate_license_idempotent_reactivation(mocker):
    """Same deviceId re-activating → approved without adding new activation"""
    from handlers.digital import _activate_license_impl

    activations = [{"deviceId": "dev-existing", "platform": "macos", "activatedAt": "2026-01-01"}]
    license_data = _make_license({"deviceLimit": 3, "activations": activations})
    mock_doc = MagicMock()
    mock_doc.exists = True
    mock_doc.to_dict.return_value = license_data
    mock_db = MagicMock()
    mock_db.collection.return_value.document.return_value.get.return_value = mock_doc

    with patch("handlers.digital.get_db", return_value=mock_db):
        result = _activate_license_impl("ABCD-EFGH-IJKL-MNOP", "dev-existing", "macos", caller_uid="buyer123")

    assert result["approved"] is True
    # Should update lastVerifiedAt but not add a new activation entry
    update_call = mock_db.collection.return_value.document.return_value.update
    update_call.assert_called_once()
    update_args = update_call.call_args[0][0]
    assert len(update_args.get("activations", activations)) == 1  # still only 1 activation


def test_activate_license_unlimited_devices(mocker):
    """deviceLimit=None means unlimited — always allow"""
    from handlers.digital import _activate_license_impl

    activations = [{"deviceId": f"dev{i}", "platform": "macos"} for i in range(100)]
    license_data = _make_license({"deviceLimit": None, "activations": activations})
    mock_doc = MagicMock()
    mock_doc.exists = True
    mock_doc.to_dict.return_value = license_data
    mock_db = MagicMock()
    mock_db.collection.return_value.document.return_value.get.return_value = mock_doc

    with patch("handlers.digital.get_db", return_value=mock_db):
        result = _activate_license_impl("ABCD-EFGH-IJKL-MNOP", "dev-new", "macos", caller_uid="buyer123")

    assert result["approved"] is True


# ── book redirect ────────────────────────────────────────────────────────────


def test_get_book_redirect_success(mocker):
    """Valid unused non-expired token → returns bookSourceUrl for redirect"""
    from handlers.digital import _get_book_redirect_impl

    now = datetime.now(UTC)
    token_data = {
        "token": "tok_abc123",
        "licenseKey": "ABCD-EFGH-IJKL-MNOP",
        "buyerId": "buyer123",
        "productId": "prod123",
        "bookSourceUrl": "https://storage.example.com/book.pdf",
        "expiresAt": now + timedelta(minutes=10),
        "used": False,
    }
    mock_doc = MagicMock()
    mock_doc.exists = True
    mock_doc.to_dict.return_value = token_data
    mock_db = MagicMock()
    mock_db.collection.return_value.document.return_value.get.return_value = mock_doc

    with patch("handlers.digital.get_db", return_value=mock_db):
        result = _get_book_redirect_impl("tok_abc123")

    assert result == "https://storage.example.com/book.pdf"


def test_get_book_redirect_already_used(mocker):
    """Used token → raises 'already_used' error"""
    from handlers.digital import _get_book_redirect_impl

    now = datetime.now(UTC)
    token_data = {
        "bookSourceUrl": "https://storage.example.com/book.pdf",
        "expiresAt": now + timedelta(minutes=10),
        "used": True,
    }
    mock_doc = MagicMock()
    mock_doc.exists = True
    mock_doc.to_dict.return_value = token_data
    mock_db = MagicMock()
    mock_db.collection.return_value.document.return_value.get.return_value = mock_doc

    with patch("handlers.digital.get_db", return_value=mock_db), pytest.raises(Exception, match="already_used"):
        _get_book_redirect_impl("tok_abc123")


def test_get_book_redirect_expired(mocker):
    """Expired token → raises 'expired' error"""
    from handlers.digital import _get_book_redirect_impl

    now = datetime.now(UTC)
    token_data = {
        "bookSourceUrl": "https://storage.example.com/book.pdf",
        "expiresAt": now - timedelta(minutes=1),  # past
        "used": False,
    }
    mock_doc = MagicMock()
    mock_doc.exists = True
    mock_doc.to_dict.return_value = token_data
    mock_db = MagicMock()
    mock_db.collection.return_value.document.return_value.get.return_value = mock_doc

    with patch("handlers.digital.get_db", return_value=mock_db), pytest.raises(Exception, match="expired"):
        _get_book_redirect_impl("tok_abc123")


# ── generate_book_download_session ──────────────────────────────────────────


def test_generate_book_download_session_success(mocker):
    """Authenticated buyer with active license → new token created"""
    from handlers.digital import _generate_book_download_session_impl

    license_data = {
        "licenseKey": "ABCD-EFGH-IJKL-MNOP",
        "userId": "buyer123",
        "digitalType": "book",
        "status": "active",
        "bookSourceUrl": "https://storage.example.com/book.pdf",
    }
    mock_lic_doc = MagicMock()
    mock_lic_doc.exists = True
    mock_lic_doc.to_dict.return_value = license_data

    mock_db = MagicMock()
    mock_db.collection.return_value.document.return_value.get.return_value = mock_lic_doc

    with patch("handlers.digital.get_db", return_value=mock_db):
        result = _generate_book_download_session_impl("ABCD-EFGH-IJKL-MNOP", "buyer123")

    assert "downloadUrl" in result
    assert "tok_" in result["downloadUrl"]


def test_generate_book_download_session_wrong_buyer(mocker):
    """Buyer trying to get token for someone else's license → 403"""
    from handlers.digital import _generate_book_download_session_impl

    license_data = {
        "licenseKey": "ABCD-EFGH-IJKL-MNOP",
        "userId": "other-buyer",
        "digitalType": "book",
        "status": "active",
        "bookSourceUrl": "https://storage.example.com/book.pdf",
    }
    mock_lic_doc = MagicMock()
    mock_lic_doc.exists = True
    mock_lic_doc.to_dict.return_value = license_data
    mock_db = MagicMock()
    mock_db.collection.return_value.document.return_value.get.return_value = mock_lic_doc

    with patch("handlers.digital.get_db", return_value=mock_db), pytest.raises(Exception, match="unauthorized"):
        _generate_book_download_session_impl("ABCD-EFGH-IJKL-MNOP", "attacker-uid")


# ── Task 3: productName in activate_license response ─────────────────────────


def test_activate_license_returns_product_name():
    """activate_license response includes productName from license doc."""
    from handlers.digital import _activate_license_impl

    license_data = {
        "licenseKey": "ABCD-EFGH-IJKL-MNOP",
        "productId": "prod123",
        "orderId": "order123",
        "userId": "buyer123",
        "digitalType": "software",
        "status": "active",
        "supportedPlatforms": ["macos"],
        "deviceLimit": 3,
        "activations": [],
        "digitalBuilds": {"macos": "https://example.com/app.dmg"},
        "productName": "FXCleaner",
    }
    mock_doc = MagicMock()
    mock_doc.exists = True
    mock_doc.to_dict.return_value = license_data
    mock_db = MagicMock()
    mock_db.collection.return_value.document.return_value.get.return_value = mock_doc

    with patch("handlers.digital.get_db", return_value=mock_db):
        result = _activate_license_impl("ABCD-EFGH-IJKL-MNOP", "device-001", "macos", caller_uid="buyer123")

    assert result["productName"] == "FXCleaner"


# ── Task 5: license revocation ────────────────────────────────────────────────


def test_revoke_licenses_for_order_full_refund():
    """Full refund: all active digital licenses in order are set to status=revoked."""
    from handlers.digital import _revoke_digital_licenses_for_order

    mock_db = MagicMock()
    license1 = MagicMock()
    license1.id = "AAAA-BBBB-CCCC-DDDD"
    license1.to_dict.return_value = {"status": "active"}
    license2 = MagicMock()
    license2.id = "EEEE-FFFF-GGGG-HHHH"
    license2.to_dict.return_value = {"status": "active"}

    mock_batch = MagicMock()
    mock_db.batch.return_value = mock_batch
    mock_query = mock_db.collection.return_value.where.return_value
    mock_query.limit.return_value = mock_query
    mock_query.stream.return_value = [license1, license2]

    with patch("handlers.digital.get_db", return_value=mock_db):
        count = _revoke_digital_licenses_for_order("order123")

    assert count == 2
    # Batch write: check batch.update was called for each license
    assert mock_batch.update.call_count == 2
    assert mock_batch.commit.called
    # Verify payload of first batch.update call
    first_call_args = mock_batch.update.call_args_list[0]
    revoke_payload = first_call_args[0][1]
    assert revoke_payload["status"] == "revoked"
    assert revoke_payload["revokedReason"] == "refunded"


def test_revoke_licenses_idempotent_when_none_found():
    """Order with no digital licenses: revoke returns 0, no error."""
    from handlers.digital import _revoke_digital_licenses_for_order

    mock_db = MagicMock()
    mock_db.collection.return_value.where.return_value.stream.return_value = []

    with patch("handlers.digital.get_db", return_value=mock_db):
        count = _revoke_digital_licenses_for_order("order_no_digital")

    assert count == 0


def test_revoke_skips_already_revoked():
    """Already-revoked licenses are not double-updated."""
    from handlers.digital import _revoke_digital_licenses_for_order

    mock_db = MagicMock()
    lic = MagicMock()
    lic.id = "AAAA-BBBB-CCCC-DDDD"
    lic.to_dict.return_value = {"status": "revoked"}  # already revoked

    mock_db.collection.return_value.where.return_value.stream.return_value = [lic]

    with patch("handlers.digital.get_db", return_value=mock_db):
        count = _revoke_digital_licenses_for_order("order123")

    assert count == 0
    lic.reference.update.assert_not_called()
