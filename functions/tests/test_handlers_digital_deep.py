import json
from datetime import UTC, datetime, timedelta
from types import SimpleNamespace
from unittest.mock import Mock, patch

import pytest
from firebase_functions import https_fn

from schema_constants import (
    ApiKeys,
    Collections,
    DigitalTypeValues,
    Fields,
    LicenseStatusValues,
)


def _snap(data=None, *, exists=True):
    snap = Mock()
    snap.exists = exists
    snap.to_dict.return_value = {} if data is None else data
    snap.reference = Mock()
    snap.id = "doc1"
    return snap


def _valid_license_data(**overrides):
    data = {
        Fields.STATUS: LicenseStatusValues.ACTIVE,
        Fields.USER_ID: "user_1",
        Fields.SUPPORTED_PLATFORMS: ["windows", "macos"],
        Fields.ACTIVATIONS: [],
        Fields.DEVICE_LIMIT: 2,
        Fields.DIGITAL_TYPE: DigitalTypeValues.SOFTWARE,
        Fields.DIGITAL_BUILDS: {"windows": "https://download.example.com/win.zip"},
        Fields.PRODUCT_NAME: "Pro Editor",
        Fields.PRODUCT_ID: "prod_1",
    }
    data.update(overrides)
    return data


def _mock_response(body, status=200, headers=None, content_type=None):
    payload = body if isinstance(body, bytes) else str(body).encode()
    return SimpleNamespace(status_code=status, response=[payload], headers=headers or {}, mimetype=content_type)


class TestDigitalInternalImplementations:
    @patch("handlers.digital.get_db")
    def test_activate_license_impl_idempotent_existing_device(self, mock_get_db):
        from handlers.digital import _activate_license_impl

        existing_act = {Fields.DEVICE_ID: "dev_1", "activatedAt": datetime.now(UTC)}
        lic_doc = _snap(_valid_license_data(activations=[existing_act]))

        db = Mock()
        db.collection.return_value.document.return_value.get.return_value = lic_doc
        mock_get_db.return_value = db

        out = _activate_license_impl("ABCD-EFGH-IJKL-MNOP", "dev_1", "windows", caller_uid="user_1")
        assert out["approved"] is True
        assert out[Fields.PRODUCT_NAME] == "Pro Editor"
        db.collection.return_value.document.return_value.update.assert_called_once()

    @patch("handlers.digital.get_db")
    def test_activate_license_impl_requires_auth_for_new_device(self, mock_get_db):
        from handlers.digital import _activate_license_impl

        lic_doc = _snap(_valid_license_data(activations=[]))
        db = Mock()
        db.collection.return_value.document.return_value.get.return_value = lic_doc
        mock_get_db.return_value = db

        with pytest.raises(ValueError, match="auth_required_for_new_device"):
            _activate_license_impl("ABCD-EFGH-IJKL-MNOP", "dev_2", "windows", caller_uid=None)

    @patch("handlers.digital.get_db")
    def test_activate_license_impl_device_limit_exceeded(self, mock_get_db):
        from handlers.digital import _activate_license_impl

        lic_doc = _snap(
            _valid_license_data(
                **{Fields.DEVICE_LIMIT: 1},
                activations=[{Fields.DEVICE_ID: "dev_1", "activatedAt": datetime.now(UTC)}],
            )
        )
        db = Mock()
        db.collection.return_value.document.return_value.get.return_value = lic_doc
        mock_get_db.return_value = db

        with pytest.raises(ValueError, match="device_limit_exceeded"):
            _activate_license_impl("ABCD-EFGH-IJKL-MNOP", "dev_2", "windows", caller_uid="user_1")

    @patch("handlers.digital.get_db")
    def test_deactivate_license_impl_success(self, mock_get_db):
        from handlers.digital import _deactivate_license_impl

        lic_doc = _snap(
            _valid_license_data(
                activations=[{Fields.DEVICE_ID: "dev_1"}, {Fields.DEVICE_ID: "dev_2"}],
            )
        )
        db = Mock()
        db.collection.return_value.document.return_value.get.return_value = lic_doc
        mock_get_db.return_value = db

        out = _deactivate_license_impl("ABCD-EFGH-IJKL-MNOP", "dev_1", "user_1")
        assert out["deactivated"] is True
        assert out["remainingActivations"] == 1

    @patch("handlers.digital.get_db")
    def test_generate_book_download_session_impl_success(self, mock_get_db):
        from handlers.digital import _generate_book_download_session_impl

        lic_doc = _snap(
            _valid_license_data(
                digitalType=DigitalTypeValues.BOOK,
                bookSourceUrl="https://cdn.example.com/book.pdf",
            )
        )
        db = Mock()
        db.collection.return_value.document.return_value.get.return_value = lic_doc
        mock_get_db.return_value = db

        out = _generate_book_download_session_impl("ABCD-EFGH-IJKL-MNOP", "user_1")
        assert out[ApiKeys.DOWNLOAD_URL].startswith("http")
        assert "/dl?t=tok_" in out[ApiKeys.DOWNLOAD_URL]
        db.collection.return_value.document.return_value.set.assert_called_once()

    @patch("handlers.digital.get_db")
    def test_get_book_redirect_impl_marks_token_used(self, mock_get_db):
        from handlers.digital import _get_book_redirect_impl

        token_ref = Mock()
        token_doc = _snap(
            {
                "used": False,
                "expiresAt": datetime.now(UTC) + timedelta(minutes=5),
                Fields.BOOK_SOURCE_URL: "https://cdn.example.com/book.pdf",
            }
        )
        token_ref.get.return_value = token_doc

        db = Mock()
        db.collection.return_value.document.return_value = token_ref
        db.transaction.return_value = Mock()
        mock_get_db.return_value = db

        url = _get_book_redirect_impl("tok_abc123")
        assert url == "https://cdn.example.com/book.pdf"
        db.transaction.return_value.update.assert_called_once()

    @patch("handlers.digital.get_db")
    def test_get_book_redirect_impl_rejects_expired_and_missing_url(self, mock_get_db):
        from handlers.digital import _get_book_redirect_impl

        # Expired
        token_ref = Mock()
        expired_doc = _snap({"used": False, "expiresAt": datetime.now(UTC) - timedelta(minutes=1)})
        token_ref.get.return_value = expired_doc
        db = Mock()
        db.collection.return_value.document.return_value = token_ref
        db.transaction.return_value = Mock()
        mock_get_db.return_value = db
        with pytest.raises(ValueError, match="expired"):
            _get_book_redirect_impl("tok_expired")

        # Missing source URL
        ok_doc = _snap({"used": False, "expiresAt": datetime.now(UTC) + timedelta(minutes=1)})
        token_ref.get.return_value = ok_doc
        with pytest.raises(ValueError, match="missing_source_url"):
            _get_book_redirect_impl("tok_nourl")

    @patch("handlers.digital.get_db")
    def test_revoke_digital_licenses_for_order_updates_active_only(self, mock_get_db):
        from handlers.digital import _revoke_digital_licenses_for_order

        active_doc = _snap({Fields.STATUS: LicenseStatusValues.ACTIVE})
        revoked_doc = _snap({Fields.STATUS: LicenseStatusValues.REVOKED})
        query = Mock()
        query.where.return_value = query
        query.limit.return_value = query
        query.stream.return_value = [active_doc, revoked_doc]

        batch = Mock()
        db = Mock()
        db.collection.return_value = query
        db.batch.return_value = batch
        mock_get_db.return_value = db

        count = _revoke_digital_licenses_for_order("order_1")
        assert count == 1
        batch.update.assert_called_once()
        batch.commit.assert_called_once()

    @patch("handlers.digital.get_db")
    def test_generate_and_get_software_redirect_impl(self, mock_get_db):
        from handlers.digital import _generate_software_download_session_impl, _get_software_redirect_impl

        lic_doc = _snap(_valid_license_data())
        db = Mock()
        db.collection.return_value.document.return_value.get.return_value = lic_doc
        db.transaction.return_value = Mock()
        mock_get_db.return_value = db

        out = _generate_software_download_session_impl("ABCD-EFGH-IJKL-MNOP", "windows", "user_1")
        assert "/sdl?t=tok_" in out[ApiKeys.DOWNLOAD_URL]
        db.collection.return_value.document.return_value.set.assert_called_once()

        token_ref = Mock()
        token_ref.get.return_value = _snap(
            {
                "used": False,
                "expiresAt": datetime.now(UTC) + timedelta(minutes=5),
                ApiKeys.DOWNLOAD_URL: "https://download.example.com/win.zip",
            }
        )
        db.collection.return_value.document.return_value = token_ref
        url = _get_software_redirect_impl("tok_soft")
        assert "download.example.com" in url


class TestDigitalEndpoints:
    @patch("handlers.digital.https_fn.Response", side_effect=_mock_response)
    @patch("handlers.digital._activate_license_impl", return_value={"approved": True})
    @patch("handlers.digital.RateLimiter")
    @patch("firebase_admin.auth.verify_id_token", return_value={"uid": "user_1"})
    @patch("handlers.digital.get_db")
    def test_activate_license_endpoint_success(self, _mock_db, _mock_verify, mock_rl, _mock_impl, _mock_resp):
        from handlers.digital import activate_license

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        req = Mock()
        req.method = "POST"
        req.get_json.return_value = {"licenseKey": "ABCD-EFGH-IJKL-MNOP", "deviceId": "dev_1", "platform": "windows"}
        req.headers = {"Authorization": "Bearer tok_abc"}

        resp = activate_license(req)
        assert resp.status_code == 200
        body = json.loads(resp.response[0].decode())
        assert body["result"]["approved"] is True

    @patch("handlers.digital.https_fn.Response", side_effect=_mock_response)
    def test_activate_license_endpoint_rejects_non_post_and_missing_auth(self, _mock_resp):
        from handlers.digital import activate_license

        req = Mock()
        req.method = "GET"
        req.get_json.return_value = {}
        req.headers = {}
        resp = activate_license(req)
        assert resp.status_code == 405

        req.method = "POST"
        req.get_json.return_value = {
            "licenseKey": "ABCD-EFGH-IJKL-MNOP",
            "deviceId": "dev_1",
            "platform": "windows",
        }
        resp2 = activate_license(req)
        assert resp2.status_code == 401

    @patch("handlers.digital._generate_software_download_session_impl", side_effect=ValueError("platform_not_supported"))
    def test_generate_software_download_session_maps_errors(self, _mock_impl):
        from handlers.digital import generate_software_download_session

        req = Mock()
        req.auth = Mock(uid="user_1")
        req.data = {"licenseKey": "ABCD-EFGH-IJKL-MNOP", "platform": "linux"}

        with pytest.raises(https_fn.HttpsError) as exc:
            generate_software_download_session(req)
        assert exc.value.code == "failed-precondition"

    def test_get_redirect_endpoints_map_value_errors(self):
        from handlers.digital import get_book_redirect, get_software_redirect

        req = Mock()
        req.args = {"t": "tok_abc"}
        with patch("handlers.digital._get_book_redirect_impl", side_effect=ValueError("expired")):
            resp = get_book_redirect(req)
            assert resp.status_code == 410

        with patch("handlers.digital._get_software_redirect_impl", side_effect=ValueError("not_found")):
            resp2 = get_software_redirect(req)
            assert resp2.status_code == 410

    @patch("handlers.digital._activate_license_impl", return_value={"approved": True})
    @patch("handlers.digital.RateLimiter")
    @patch("handlers.digital.get_db")
    @patch("handlers.digital.https_fn.Response", side_effect=_mock_response)
    def test_verify_license_endpoint_respects_rate_limits(self, _mock_resp, _mock_db, mock_rl, _mock_impl):
        from handlers.digital import verify_license

        req = Mock()
        req.method = "POST"
        req.remote_addr = "127.0.0.1"
        req.get_json.return_value = {"licenseKey": "ABCD-EFGH-IJKL-MNOP", "deviceId": "dev_1", "platform": "windows"}

        # First limiter call denied -> 429
        mock_rl.return_value.check_rate_limit.return_value = (False, "slow down")
        resp = verify_license(req)
        assert resp.status_code == 429

        # Allow both checks -> success
        mock_rl.return_value.check_rate_limit.side_effect = [(True, ""), (True, "")]
        resp2 = verify_license(req)
        assert resp2.status_code == 200
