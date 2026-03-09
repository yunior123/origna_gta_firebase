import importlib
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
    RateLimitActions,
)


def _snap(data=None, *, exists=True):
    snap = Mock()
    snap.exists = exists
    snap.to_dict.return_value = {} if data is None else data
    snap.reference = Mock()
    return snap


def _license(**overrides):
    base = {
        Fields.STATUS: LicenseStatusValues.ACTIVE,
        Fields.USER_ID: "buyer_1",
        Fields.SUPPORTED_PLATFORMS: ["windows"],
        Fields.ACTIVATIONS: [],
        Fields.DEVICE_LIMIT: 2,
        Fields.DIGITAL_TYPE: DigitalTypeValues.SOFTWARE,
        Fields.DIGITAL_BUILDS: {"windows": "https://dl.example.com/win.zip"},
        Fields.BOOK_SOURCE_URL: "https://cdn.example.com/book.pdf",
        Fields.PRODUCT_ID: "prod_1",
        Fields.PRODUCT_NAME: "Product 1",
    }
    base.update(overrides)
    return base


def _mock_response(body, status=200, headers=None, content_type=None):
    payload = body if isinstance(body, bytes) else str(body).encode()
    return SimpleNamespace(status_code=status, response=[payload], headers=headers or {}, mimetype=content_type)


class TestDigitalInternalBranchPack:
    def test_module_import_falls_back_to_default_base_url_when_config_missing(self):
        import handlers.digital as digital

        real_import = __import__

        def _fake_import(name, globals=None, locals=None, fromlist=(), level=0):
            if name == "config":
                raise ImportError("config unavailable")
            return real_import(name, globals, locals, fromlist, level)

        try:
            with patch("builtins.__import__", side_effect=_fake_import):
                reloaded = importlib.reload(digital)
                assert reloaded.APP_BASE_URL == "https://app.origna.com"
        finally:
            importlib.reload(digital)

    def test_activate_license_impl_invalid_key_and_unauthorized(self):
        from handlers.digital import _activate_license_impl

        with pytest.raises(ValueError, match="invalid_key_format"):
            _activate_license_impl("bad", "dev_1", "windows", caller_uid="buyer_1")

        lic_doc = _snap(_license(userId="buyer_2"))
        db = Mock()
        db.collection.return_value.document.return_value.get.return_value = lic_doc
        with patch("handlers.digital.get_db", return_value=db), pytest.raises(ValueError, match="unauthorized"):
            _activate_license_impl("ABCD-EFGH-IJKL-MNOP", "dev_1", "windows", caller_uid="buyer_1")

    @pytest.mark.parametrize(
        "license_key,exists,user_id,expected",
        [
            ("bad", True, "buyer_1", "invalid_key_format"),
            ("ABCD-EFGH-IJKL-MNOP", False, "buyer_1", "not_found"),
            ("ABCD-EFGH-IJKL-MNOP", True, "buyer_2", "unauthorized"),
        ],
    )
    def test_deactivate_license_impl_error_branches(self, license_key, exists, user_id, expected):
        from handlers.digital import _deactivate_license_impl

        lic_doc = _snap(_license(userId=user_id), exists=exists)
        db = Mock()
        db.collection.return_value.document.return_value.get.return_value = lic_doc
        with patch("handlers.digital.get_db", return_value=db), pytest.raises(ValueError, match=expected):
            _deactivate_license_impl(license_key, "dev_1", "buyer_1")

    @pytest.mark.parametrize(
        "license_key,exists,status,digital_type,expected",
        [
            ("bad", True, LicenseStatusValues.ACTIVE, DigitalTypeValues.BOOK, "invalid_key_format"),
            ("ABCD-EFGH-IJKL-MNOP", False, LicenseStatusValues.ACTIVE, DigitalTypeValues.BOOK, "not_found"),
            ("ABCD-EFGH-IJKL-MNOP", True, LicenseStatusValues.REVOKED, DigitalTypeValues.BOOK, "revoked"),
            (
                "ABCD-EFGH-IJKL-MNOP",
                True,
                LicenseStatusValues.ACTIVE,
                DigitalTypeValues.SOFTWARE,
                "not_a_book_license",
            ),
        ],
    )
    def test_generate_book_download_session_impl_error_branches(
        self, license_key, exists, status, digital_type, expected
    ):
        from handlers.digital import _generate_book_download_session_impl

        lic_doc = _snap(_license(status=status, digitalType=digital_type), exists=exists)
        db = Mock()
        db.collection.return_value.document.return_value.get.return_value = lic_doc
        with patch("handlers.digital.get_db", return_value=db), pytest.raises(ValueError, match=expected):
            _generate_book_download_session_impl(license_key, "buyer_1")

    @patch("handlers.digital.get_db")
    def test_get_book_redirect_impl_not_found(self, mock_get_db):
        from handlers.digital import _get_book_redirect_impl

        db = Mock()
        db.collection.return_value.document.return_value.get.return_value = _snap(exists=False)
        mock_get_db.return_value = db

        with pytest.raises(ValueError, match="not_found"):
            _get_book_redirect_impl("tok_missing")

    @patch("handlers.digital.get_db")
    def test_get_book_redirect_impl_expires_without_tzinfo_attr(self, mock_get_db):
        from handlers.digital import _get_book_redirect_impl

        token_ref = Mock()
        token_ref.get.return_value = _snap(
            {
                "used": False,
                "expiresAt": None,  # triggers line where expires_at has no tzinfo attribute
                Fields.BOOK_SOURCE_URL: "https://cdn.example.com/book.pdf",
            }
        )
        db = Mock()
        db.collection.return_value.document.return_value = token_ref
        db.transaction.return_value = Mock()
        mock_get_db.return_value = db

        assert _get_book_redirect_impl("tok_ok") == "https://cdn.example.com/book.pdf"

    @pytest.mark.parametrize(
        "license_key,exists,user_id,status,digital_type,platform,expected",
        [
            ("bad", True, "buyer_1", LicenseStatusValues.ACTIVE, DigitalTypeValues.SOFTWARE, "windows", "invalid_key_format"),
            ("ABCD-EFGH-IJKL-MNOP", False, "buyer_1", LicenseStatusValues.ACTIVE, DigitalTypeValues.SOFTWARE, "windows", "not_found"),
            ("ABCD-EFGH-IJKL-MNOP", True, "buyer_2", LicenseStatusValues.ACTIVE, DigitalTypeValues.SOFTWARE, "windows", "unauthorized"),
            ("ABCD-EFGH-IJKL-MNOP", True, "buyer_1", LicenseStatusValues.REVOKED, DigitalTypeValues.SOFTWARE, "windows", "revoked"),
            (
                "ABCD-EFGH-IJKL-MNOP",
                True,
                "buyer_1",
                LicenseStatusValues.ACTIVE,
                DigitalTypeValues.BOOK,
                "windows",
                "not_a_software_license",
            ),
            (
                "ABCD-EFGH-IJKL-MNOP",
                True,
                "buyer_1",
                LicenseStatusValues.ACTIVE,
                DigitalTypeValues.SOFTWARE,
                "linux",
                "platform_not_supported",
            ),
        ],
    )
    def test_generate_software_download_session_impl_error_branches(
        self, license_key, exists, user_id, status, digital_type, platform, expected
    ):
        from handlers.digital import _generate_software_download_session_impl

        lic_doc = _snap(_license(userId=user_id, status=status, digitalType=digital_type), exists=exists)
        db = Mock()
        db.collection.return_value.document.return_value.get.return_value = lic_doc
        with patch("handlers.digital.get_db", return_value=db), pytest.raises(ValueError, match=expected):
            _generate_software_download_session_impl(license_key, platform, "buyer_1")

    @patch("handlers.digital.get_db")
    def test_get_software_redirect_impl_not_found_already_used_expired_and_missing_source(self, mock_get_db):
        from handlers.digital import _get_software_redirect_impl

        db = Mock()
        token_ref = Mock()
        db.collection.return_value.document.return_value = token_ref
        db.transaction.return_value = Mock()
        mock_get_db.return_value = db

        token_ref.get.return_value = _snap(exists=False)
        with pytest.raises(ValueError, match="not_found"):
            _get_software_redirect_impl("tok_missing")

        token_ref.get.return_value = _snap({"used": True, "expiresAt": datetime.now(UTC) + timedelta(minutes=5)})
        with pytest.raises(ValueError, match="already_used"):
            _get_software_redirect_impl("tok_used")

        token_ref.get.return_value = _snap({"used": False, "expiresAt": datetime.now(UTC) - timedelta(minutes=1)})
        with pytest.raises(ValueError, match="expired"):
            _get_software_redirect_impl("tok_expired")

        token_ref.get.return_value = _snap({"used": False, "expiresAt": datetime.now(UTC) + timedelta(minutes=5)})
        with pytest.raises(ValueError, match="missing_source_url"):
            _get_software_redirect_impl("tok_nourl")

    @patch("handlers.digital.get_db")
    def test_get_software_redirect_impl_expiration_without_tzinfo_attr_path(self, mock_get_db):
        from handlers.digital import _get_software_redirect_impl

        db = Mock()
        token_ref = Mock()
        token_ref.get.return_value = _snap({"used": False, "expiresAt": None, ApiKeys.DOWNLOAD_URL: "https://dl.example.com/win.zip"})
        db.collection.return_value.document.return_value = token_ref
        db.transaction.return_value = Mock()
        mock_get_db.return_value = db

        assert _get_software_redirect_impl("tok_ok") == "https://dl.example.com/win.zip"


class TestDigitalEndpointBranchPack:
    @patch("handlers.digital.https_fn.Response", side_effect=_mock_response)
    def test_activate_license_endpoint_missing_fields(self, _mock_resp):
        from handlers.digital import activate_license

        req = Mock()
        req.method = "POST"
        req.get_json.return_value = {"licenseKey": "ABCD-EFGH-IJKL-MNOP", "deviceId": "dev_1"}  # missing platform
        req.headers = {"Authorization": "Bearer tok"}
        resp = activate_license(req)
        assert resp.status_code == 400

    @patch("handlers.digital.https_fn.Response", side_effect=_mock_response)
    @patch("firebase_admin.auth.verify_id_token", side_effect=Exception("bad token"))
    def test_activate_license_endpoint_invalid_token(self, _mock_verify, _mock_resp):
        from handlers.digital import activate_license

        req = Mock()
        req.method = "POST"
        req.get_json.return_value = {"licenseKey": "ABCD-EFGH-IJKL-MNOP", "deviceId": "dev_1", "platform": "windows"}
        req.headers = {"Authorization": "Bearer bad"}
        resp = activate_license(req)
        assert resp.status_code == 401

    @patch("handlers.digital.https_fn.Response", side_effect=_mock_response)
    @patch("handlers.digital._activate_license_impl", side_effect=ValueError("unauthorized"))
    @patch("handlers.digital.RateLimiter")
    @patch("firebase_admin.auth.verify_id_token", return_value={"uid": "buyer_1"})
    @patch("handlers.digital.get_db")
    def test_activate_license_endpoint_rate_limited_and_value_error_mapping(
        self, mock_get_db, _mock_verify, mock_rl, _mock_impl, _mock_resp
    ):
        from handlers.digital import activate_license

        req = Mock()
        req.method = "POST"
        req.get_json.return_value = {"licenseKey": "ABCD-EFGH-IJKL-MNOP", "deviceId": "dev_1", "platform": "windows"}
        req.headers = {"Authorization": "Bearer good"}

        mock_rl.return_value.check_rate_limit.return_value = (False, "slow down")
        rate_resp = activate_license(req)
        assert rate_resp.status_code == 429

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        map_resp = activate_license(req)
        assert map_resp.status_code == 403
        body = json.loads(map_resp.response[0].decode())
        assert body["error"]["code"] == "unauthorized"

    @patch("handlers.digital.https_fn.Response", side_effect=_mock_response)
    @patch("handlers.digital._activate_license_impl", side_effect=Exception("boom"))
    @patch("handlers.digital.RateLimiter")
    @patch("firebase_admin.auth.verify_id_token", return_value={"uid": "buyer_1"})
    @patch("handlers.digital.get_db")
    def test_activate_license_endpoint_internal_error(self, _mock_get_db, _mock_verify, mock_rl, _mock_impl, _mock_resp):
        from handlers.digital import activate_license

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        req = Mock()
        req.method = "POST"
        req.get_json.return_value = {"licenseKey": "ABCD-EFGH-IJKL-MNOP", "deviceId": "dev_1", "platform": "windows"}
        req.headers = {"Authorization": "Bearer good"}
        resp = activate_license(req)
        assert resp.status_code == 500

    def test_deactivate_license_endpoint_error_mapping(self):
        from handlers.digital import deactivate_license

        req = Mock()
        req.auth = None
        req.data = {}
        with pytest.raises(https_fn.HttpsError) as unauth:
            deactivate_license(req)
        assert unauth.value.code == "unauthenticated"

        req.auth = SimpleNamespace(uid="buyer_1")
        with pytest.raises(https_fn.HttpsError) as invalid:
            deactivate_license(req)
        assert invalid.value.code == "invalid-argument"

        with patch("handlers.digital._deactivate_license_impl", side_effect=ValueError("not_found")):
            req.data = {"licenseKey": "ABCD-EFGH-IJKL-MNOP", "deviceId": "dev_1"}
            with pytest.raises(https_fn.HttpsError) as nf:
                deactivate_license(req)
            assert nf.value.code == "not-found"

        with patch("handlers.digital._deactivate_license_impl", side_effect=ValueError("unauthorized")):
            with pytest.raises(https_fn.HttpsError) as pd:
                deactivate_license(req)
            assert pd.value.code == "permission-denied"

        with patch("handlers.digital._deactivate_license_impl", side_effect=ValueError("other")):
            with pytest.raises(https_fn.HttpsError) as other:
                deactivate_license(req)
            assert other.value.code == "invalid-argument"

    def test_generate_book_download_session_endpoint_error_mapping(self):
        from handlers.digital import generate_book_download_session

        req = Mock()
        req.auth = None
        req.data = {}
        with pytest.raises(https_fn.HttpsError) as unauth:
            generate_book_download_session(req)
        assert unauth.value.code == "unauthenticated"

        req.auth = SimpleNamespace(uid="buyer_1")
        with pytest.raises(https_fn.HttpsError) as invalid:
            generate_book_download_session(req)
        assert invalid.value.code == "invalid-argument"

        req.data = {"licenseKey": "ABCD-EFGH-IJKL-MNOP"}
        for code, expected in [
            ("not_found", "not-found"),
            ("unauthorized", "permission-denied"),
            ("revoked", "failed-precondition"),
            ("other", "invalid-argument"),
        ]:
            with patch("handlers.digital._generate_book_download_session_impl", side_effect=ValueError(code)):
                with pytest.raises(https_fn.HttpsError) as exc:
                    generate_book_download_session(req)
                assert exc.value.code == expected

    def test_get_book_redirect_endpoint_missing_token_success_and_internal_error(self):
        from handlers.digital import get_book_redirect

        req_missing = Mock()
        req_missing.args = {}
        assert get_book_redirect(req_missing).status_code == 400

        req_ok = Mock()
        req_ok.args = {"t": "tok_1"}
        with patch("handlers.digital._get_book_redirect_impl", return_value="https://cdn.example.com/book.pdf"):
            resp_ok = get_book_redirect(req_ok)
            assert resp_ok.status_code == 302
            assert resp_ok.headers["Location"].startswith("https://")

        with patch("handlers.digital._get_book_redirect_impl", side_effect=Exception("boom")):
            resp_err = get_book_redirect(req_ok)
            assert resp_err.status_code == 500

    def test_generate_software_download_session_endpoint_auth_and_input_errors(self):
        from handlers.digital import generate_software_download_session

        req = Mock()
        req.auth = None
        req.data = {}
        with pytest.raises(https_fn.HttpsError) as unauth:
            generate_software_download_session(req)
        assert unauth.value.code == "unauthenticated"

        req.auth = SimpleNamespace(uid="buyer_1")
        with pytest.raises(https_fn.HttpsError) as invalid:
            generate_software_download_session(req)
        assert invalid.value.code == "invalid-argument"

    def test_get_software_redirect_endpoint_missing_token_success_and_internal_error(self):
        from handlers.digital import get_software_redirect

        req_missing = Mock()
        req_missing.args = {}
        assert get_software_redirect(req_missing).status_code == 400

        req_ok = Mock()
        req_ok.args = {"t": "tok_1"}
        with patch("handlers.digital._get_software_redirect_impl", return_value="https://dl.example.com/win.zip"):
            resp_ok = get_software_redirect(req_ok)
            assert resp_ok.status_code == 302
            assert resp_ok.headers["Location"].startswith("https://")

        with patch("handlers.digital._get_software_redirect_impl", side_effect=Exception("boom")):
            resp_err = get_software_redirect(req_ok)
            assert resp_err.status_code == 500

    @patch("handlers.digital.https_fn.Response", side_effect=_mock_response)
    @patch("handlers.digital._activate_license_impl", side_effect=ValueError("revoked"))
    @patch("handlers.digital.RateLimiter")
    @patch("handlers.digital.get_db")
    def test_verify_license_endpoint_method_missing_ip_rate_limit_and_error_mapping(
        self, _mock_db, mock_rl, _mock_impl, _mock_resp
    ):
        from handlers.digital import verify_license

        req = Mock()
        req.method = "GET"
        req.remote_addr = "127.0.0.1"
        req.get_json.return_value = {}
        assert verify_license(req).status_code == 405

        req.method = "POST"
        req.get_json.return_value = {"licenseKey": "ABCD-EFGH-IJKL-MNOP", "deviceId": "dev_1"}
        assert verify_license(req).status_code == 400

        req.get_json.return_value = {"licenseKey": "ABCD-EFGH-IJKL-MNOP", "deviceId": "dev_1", "platform": "windows"}
        mock_rl.return_value.check_rate_limit.side_effect = [(True, ""), (False, "ip-limit")]
        assert verify_license(req).status_code == 429

        mock_rl.return_value.check_rate_limit.side_effect = [(True, ""), (True, "")]
        value_err_resp = verify_license(req)
        assert value_err_resp.status_code == 403
        body = json.loads(value_err_resp.response[0].decode())
        assert body["error"] == "revoked"

    @patch("handlers.digital.https_fn.Response", side_effect=_mock_response)
    @patch("handlers.digital._activate_license_impl", side_effect=Exception("boom"))
    @patch("handlers.digital.RateLimiter")
    @patch("handlers.digital.get_db")
    def test_verify_license_endpoint_internal_error(self, _mock_db, mock_rl, _mock_impl, _mock_resp):
        from handlers.digital import verify_license

        mock_rl.return_value.check_rate_limit.side_effect = [(True, ""), (True, "")]
        req = Mock()
        req.method = "POST"
        req.remote_addr = "127.0.0.1"
        req.get_json.return_value = {"licenseKey": "ABCD-EFGH-IJKL-MNOP", "deviceId": "dev_1", "platform": "windows"}
        resp = verify_license(req)
        assert resp.status_code == 500
