from unittest.mock import MagicMock, Mock, patch

import pytest
from firebase_functions import https_fn

from schema_constants import (
    Collections,
    Fields,
    LanguageValues,
    OrderStatusValues,
    UserRoleValues,
)


def _auth_req(
    uid: str = "user_123",
    *,
    email: str = "user@example.com",
    verified: bool = True,
    data: dict | None = None,
):
    req = Mock()
    req.auth = Mock()
    req.auth.uid = uid
    req.auth.token = {"email": email, "email_verified": verified}
    req.data = data or {}
    return req


class TestCreateUserProfileDeep:
    def test_create_user_profile_requires_auth(self):
        from handlers.users import create_user_profile

        req = Mock()
        req.auth = None
        req.data = {}
        with pytest.raises(https_fn.HttpsError) as exc:
            create_user_profile(req)
        assert exc.value.code == "unauthenticated"

    @patch("handlers.users.get_db")
    @patch("services.rate_limiter.RateLimiter")
    def test_create_user_profile_rate_limited(self, mock_rl_cls, mock_get_db):
        from handlers.users import create_user_profile

        mock_rl_cls.return_value.check_rate_limit.return_value = (False, "too many")
        mock_get_db.return_value = MagicMock()

        with pytest.raises(https_fn.HttpsError) as exc:
            create_user_profile(_auth_req())
        assert exc.value.code == "resource-exhausted"

    @patch("handlers.users.get_db")
    @patch("services.rate_limiter.RateLimiter")
    def test_create_user_profile_rejects_unverified_email_in_non_emulator(self, mock_rl_cls, mock_get_db, monkeypatch):
        from handlers.users import create_user_profile

        monkeypatch.setenv("FUNCTIONS_EMULATOR", "false")
        monkeypatch.delenv("FIRESTORE_EMULATOR_HOST", raising=False)
        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")

        doc = MagicMock()
        doc.exists = False
        mock_get_db.return_value.collection.return_value.document.return_value.get.return_value = doc

        with pytest.raises(https_fn.HttpsError) as exc:
            create_user_profile(_auth_req(verified=False))
        assert exc.value.code == "failed-precondition"

    @patch("handlers.users.get_db")
    @patch("services.rate_limiter.RateLimiter")
    def test_create_user_profile_returns_existing_when_doc_exists(self, mock_rl_cls, mock_get_db):
        from handlers.users import create_user_profile

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
        existing_doc = MagicMock()
        existing_doc.exists = True
        mock_get_db.return_value.collection.return_value.document.return_value.get.return_value = existing_doc

        result = create_user_profile(_auth_req())
        assert result["success"] is True
        assert result["existing"] is True

    @patch("handlers.users.get_db")
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.users.verify_turnstile_token", return_value=False)
    def test_create_user_profile_blocks_on_turnstile_failure(self, _mock_turnstile, mock_rl_cls, mock_get_db):
        from handlers.users import create_user_profile

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
        missing_doc = MagicMock()
        missing_doc.exists = False
        mock_get_db.return_value.collection.return_value.document.return_value.get.return_value = missing_doc

        with pytest.raises(https_fn.HttpsError) as exc:
            create_user_profile(_auth_req(data={}))
        assert exc.value.code == "permission-denied"

    @patch("handlers.users.get_server_timestamp", return_value="server_ts")
    @patch("handlers.users.get_db")
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.users.verify_turnstile_token", return_value=True)
    def test_create_user_profile_success_sanitizes_defaults(
        self,
        _mock_turnstile,
        mock_rl_cls,
        mock_get_db,
        _mock_ts,
    ):
        from handlers.users import create_user_profile

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
        missing_doc = MagicMock()
        missing_doc.exists = False
        user_ref = MagicMock()
        user_ref.get.return_value = missing_doc
        mock_get_db.return_value.collection.return_value.document.return_value = user_ref

        req = _auth_req(
            email="fallback@example.com",
            data={
                Fields.NAME: "  ",  # triggers email-prefix fallback
                Fields.PREFERRED_LANGUAGE: "xx",  # invalid -> default en
                Fields.CONSENT_METHOD: "bad_method",  # invalid -> signup_form
                Fields.MARKETING_OPT_IN: True,
            },
        )
        result = create_user_profile(req)
        assert result["success"] is True
        payload = user_ref.set.call_args.args[0]
        assert payload[Fields.NAME] == "fallback"
        assert payload[Fields.PREFERRED_LANGUAGE] == LanguageValues.ENGLISH
        assert payload[Fields.ROLES] == [UserRoleValues.BUYER]


class TestUpdateAndGetUserProfileDeep:
    def test_update_user_profile_requires_auth(self):
        from handlers.users import update_user_profile

        req = Mock()
        req.auth = None
        req.data = {}
        with pytest.raises(https_fn.HttpsError) as exc:
            update_user_profile(req)
        assert exc.value.code == "unauthenticated"

    @patch("handlers.users.get_db")
    @patch("services.rate_limiter.RateLimiter")
    def test_update_user_profile_tax_exemption_rate_limited(self, mock_rl_cls, mock_get_db):
        from handlers.users import update_user_profile

        mock_rl_cls.return_value.check_rate_limit.return_value = (False, "limited")
        mock_get_db.return_value.collection.return_value.document.return_value.get.return_value.exists = True
        req = _auth_req(data={Fields.TAX_EXEMPTION: {Fields.GST_NUMBER: "123456789RT0001"}})

        with pytest.raises(https_fn.HttpsError) as exc:
            update_user_profile(req)
        assert exc.value.code == "resource-exhausted"

    @patch("handlers.users.get_db")
    @patch("services.rate_limiter.RateLimiter")
    def test_update_user_profile_rejects_invalid_gst_number(self, mock_rl_cls, mock_get_db):
        from handlers.users import update_user_profile

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
        mock_get_db.return_value.collection.return_value.document.return_value.get.return_value.exists = True
        req = _auth_req(data={Fields.TAX_EXEMPTION: {Fields.GST_NUMBER: "invalid"}})

        with pytest.raises(https_fn.HttpsError) as exc:
            update_user_profile(req)
        assert exc.value.code == "invalid-argument"

    @patch("handlers.users.get_db")
    @patch("services.rate_limiter.RateLimiter")
    def test_update_user_profile_rejects_non_string_name(self, mock_rl_cls, mock_get_db):
        from handlers.users import update_user_profile

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
        mock_get_db.return_value.collection.return_value.document.return_value.get.return_value.exists = True
        req = _auth_req(data={Fields.NAME: 123})
        with pytest.raises(https_fn.HttpsError) as exc:
            update_user_profile(req)
        assert exc.value.code == "invalid-argument"

    @patch("handlers.users.get_db")
    @patch("services.rate_limiter.RateLimiter")
    def test_update_user_profile_rejects_invalid_language(self, mock_rl_cls, mock_get_db):
        from handlers.users import update_user_profile

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
        mock_get_db.return_value.collection.return_value.document.return_value.get.return_value.exists = True
        req = _auth_req(data={Fields.PREFERRED_LANGUAGE: "zz"})
        with pytest.raises(https_fn.HttpsError) as exc:
            update_user_profile(req)
        assert exc.value.code == "invalid-argument"

    @patch("handlers.users.get_db")
    @patch("services.rate_limiter.RateLimiter")
    def test_update_user_profile_raises_when_user_missing(self, mock_rl_cls, mock_get_db):
        from handlers.users import update_user_profile

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
        user_doc = MagicMock()
        user_doc.exists = False
        mock_get_db.return_value.collection.return_value.document.return_value.get.return_value = user_doc

        req = _auth_req(data={Fields.NAME: "Valid Name"})
        with pytest.raises(https_fn.HttpsError) as exc:
            update_user_profile(req)
        assert exc.value.code == "not-found"

    @patch("handlers.users.get_db")
    @patch("services.rate_limiter.RateLimiter")
    def test_update_user_profile_success_path(self, mock_rl_cls, mock_get_db):
        from handlers.users import update_user_profile

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
        user_doc = MagicMock()
        user_doc.exists = True
        user_ref = MagicMock()
        user_ref.get.return_value = user_doc
        mock_get_db.return_value.collection.return_value.document.return_value = user_ref

        req = _auth_req(
            data={
                Fields.NAME: " Updated Name ",
                Fields.PREFERRED_LANGUAGE: LanguageValues.FRENCH,
                Fields.TAX_EXEMPTION: None,
            }
        )
        result = update_user_profile(req)
        assert result["success"] is True
        assert result["updated"] is True
        assert Fields.NAME in result["fields"]
        assert Fields.PREFERRED_LANGUAGE in result["fields"]

    def test_get_user_profile_requires_auth(self):
        from handlers.users import get_user_profile

        req = Mock()
        req.auth = None
        req.data = {}
        with pytest.raises(https_fn.HttpsError) as exc:
            get_user_profile(req)
        assert exc.value.code == "unauthenticated"

    @patch("handlers.users.get_db")
    def test_get_user_profile_not_found(self, mock_get_db):
        from handlers.users import get_user_profile

        user_doc = MagicMock()
        user_doc.exists = False
        mock_get_db.return_value.collection.return_value.document.return_value.get.return_value = user_doc
        with pytest.raises(https_fn.HttpsError) as exc:
            get_user_profile(_auth_req())
        assert exc.value.code == "not-found"

    @patch("handlers.users.get_db")
    def test_get_user_profile_success(self, mock_get_db):
        from handlers.users import get_user_profile

        user_doc = MagicMock()
        user_doc.exists = True
        user_doc.to_dict.return_value = {
            Fields.EMAIL: "user@example.com",
            Fields.NAME: "User",
            Fields.ROLES: [UserRoleValues.BUYER],
        }
        mock_get_db.return_value.collection.return_value.document.return_value.get.return_value = user_doc

        result = get_user_profile(_auth_req())
        assert result["success"] is True
        assert result[Fields.EMAIL] == "user@example.com"


class TestEmailConsentAndAddressDeep:
    def test_update_email_consent_requires_auth(self):
        from handlers.users import update_email_consent

        req = Mock()
        req.auth = None
        req.data = {}
        with pytest.raises(https_fn.HttpsError) as exc:
            update_email_consent(req)
        assert exc.value.code == "unauthenticated"

    def test_update_email_consent_requires_boolean(self):
        from handlers.users import update_email_consent

        with pytest.raises(https_fn.HttpsError) as exc:
            update_email_consent(_auth_req(data={Fields.EMAIL_CONSENT: "yes"}))
        assert exc.value.code == "invalid-argument"

    @patch("handlers.users.get_db")
    def test_update_email_consent_not_found(self, mock_get_db):
        from handlers.users import update_email_consent

        doc = MagicMock()
        doc.exists = False
        mock_get_db.return_value.collection.return_value.document.return_value.get.return_value = doc
        with pytest.raises(https_fn.HttpsError) as exc:
            update_email_consent(_auth_req(data={Fields.EMAIL_CONSENT: False}))
        assert exc.value.code == "not-found"

    @patch("handlers.users.get_db")
    def test_update_email_consent_success(self, mock_get_db):
        from handlers.users import update_email_consent

        doc = MagicMock()
        doc.exists = True
        user_ref = MagicMock()
        user_ref.get.return_value = doc
        mock_get_db.return_value.collection.return_value.document.return_value = user_ref

        result = update_email_consent(_auth_req(data={Fields.EMAIL_CONSENT: False}))
        assert result["success"] is True
        assert result[Fields.EMAIL_CONSENT] is False

    @patch("utils.helpers.geocode_address", return_value=(False, "bad geo", {}))
    def test_add_buyer_address_rejects_failed_geocoding(self, _mock_geo):
        from handlers.users import add_buyer_address

        req = _auth_req(
            data={
                "street": "1 Main St",
                "city": "Toronto",
                "state": "ON",
                "postalCode": "M5V2H1",
                "country": "Canada",
            }
        )
        with pytest.raises(https_fn.HttpsError) as exc:
            add_buyer_address(req)
        assert exc.value.code == "invalid-argument"

    def test_update_buyer_address_requires_auth(self):
        from handlers.users import update_buyer_address

        req = Mock()
        req.auth = None
        req.data = {}
        with pytest.raises(https_fn.HttpsError) as exc:
            update_buyer_address(req)
        assert exc.value.code == "unauthenticated"

    @patch("utils.helpers.geocode_address", return_value=(True, "", {"street": "1 Main", "city": "Toronto", "state": "ON", "postalCode": "M5V2H1", "country": "Canada", "isDefault": False}))
    @patch("handlers.users.get_db")
    def test_update_buyer_address_demoting_only_address_forces_default(self, mock_get_db, _mock_geo):
        from handlers.users import update_buyer_address

        db = MagicMock()
        tx = MagicMock()
        db.transaction.return_value = tx
        mock_get_db.return_value = db

        addresses_ref = MagicMock()
        address_ref = MagicMock()
        doc = MagicMock()
        doc.exists = True
        doc.to_dict.return_value = {Fields.IS_DEFAULT: True}
        address_ref.get.return_value = doc
        addresses_ref.document.return_value = address_ref
        addresses_ref.get.return_value = [doc]  # only one address

        users_doc_ref = MagicMock()
        users_doc_ref.collection.return_value = addresses_ref
        db.collection.return_value.document.return_value = users_doc_ref

        with patch("firebase_admin.firestore.transactional", lambda f: lambda txn: f(txn)):
            result = update_buyer_address(
                _auth_req(
                    data={
                        Fields.ADDRESS_ID: "addr_1",
                        "street": "1 Main St",
                        "city": "Toronto",
                        "state": "ON",
                        "postalCode": "M5V2H1",
                        "country": "Canada",
                    }
                )
            )

        assert result["success"] is True
        forced_payload = tx.update.call_args.args[1]
        assert forced_payload[Fields.IS_DEFAULT] is True

    def test_delete_buyer_address_requires_auth(self):
        from handlers.users import delete_buyer_address

        req = Mock()
        req.auth = None
        req.data = {}
        with pytest.raises(https_fn.HttpsError) as exc:
            delete_buyer_address(req)
        assert exc.value.code == "unauthenticated"

    def test_delete_buyer_address_requires_address_id(self):
        from handlers.users import delete_buyer_address

        with pytest.raises(https_fn.HttpsError) as exc:
            delete_buyer_address(_auth_req(data={}))
        assert exc.value.code == "invalid-argument"

    @patch("handlers.users.get_db")
    def test_delete_buyer_address_blocks_when_used_in_active_order(self, mock_get_db):
        from handlers.users import delete_buyer_address

        db = MagicMock()
        mock_get_db.return_value = db

        address_doc = MagicMock()
        address_doc.exists = True
        address_doc.to_dict.return_value = {Fields.STREET: "1 Main St"}
        address_ref = MagicMock()
        address_ref.get.return_value = address_doc
        address_ref.parent.parent.id = "user_123"

        addresses_ref = MagicMock()
        addresses_ref.document.return_value = address_ref

        user_ref = MagicMock()
        user_ref.collection.return_value = addresses_ref

        order_doc = MagicMock()
        order_doc.to_dict.return_value = {Fields.SHIPPING_ADDRESS: {Fields.STREET: "1 Main St"}}
        orders_ref = MagicMock()
        orders_ref.where.return_value = orders_ref
        orders_ref.stream.return_value = [order_doc]

        def collection_side_effect(name):
            if name == Collections.USERS:
                c = MagicMock()
                c.document.return_value = user_ref
                return c
            if name == Collections.ORDERS:
                return orders_ref
            return MagicMock()

        db.collection.side_effect = collection_side_effect

        with patch("utils.helpers.compare_addresses", return_value=True):
            with pytest.raises(https_fn.HttpsError) as exc:
                delete_buyer_address(_auth_req(data={Fields.ADDRESS_ID: "addr_1"}))
        assert exc.value.code == "failed-precondition"

    @patch("handlers.users.get_db")
    def test_delete_buyer_address_transaction_idempotent_when_already_deleted(self, mock_get_db):
        from handlers.users import delete_buyer_address

        db = MagicMock()
        tx = MagicMock()
        db.transaction.return_value = tx
        mock_get_db.return_value = db

        pre_doc = MagicMock()
        pre_doc.exists = True
        pre_doc.to_dict.return_value = {Fields.IS_DEFAULT: False}

        txn_doc = MagicMock()
        txn_doc.exists = False

        address_ref = MagicMock()
        address_ref.get.side_effect = [pre_doc, txn_doc]
        address_ref.parent.parent.id = "user_123"

        addresses_ref = MagicMock()
        addresses_ref.document.return_value = address_ref
        addresses_ref.get.return_value = []

        user_ref = MagicMock()
        user_ref.collection.return_value = addresses_ref

        orders_ref = MagicMock()
        orders_ref.where.return_value = orders_ref
        orders_ref.stream.return_value = []

        def collection_side_effect(name):
            if name == Collections.USERS:
                c = MagicMock()
                c.document.return_value = user_ref
                return c
            if name == Collections.ORDERS:
                return orders_ref
            return MagicMock()

        db.collection.side_effect = collection_side_effect

        with patch("firebase_admin.firestore.transactional", lambda f: lambda txn: f(txn)):
            result = delete_buyer_address(_auth_req(data={Fields.ADDRESS_ID: "addr_1"}))
        assert result["success"] is True

    def test_set_default_buyer_address_requires_auth(self):
        from handlers.users import set_default_buyer_address

        req = Mock()
        req.auth = None
        req.data = {}
        with pytest.raises(https_fn.HttpsError) as exc:
            set_default_buyer_address(req)
        assert exc.value.code == "unauthenticated"

    def test_set_default_buyer_address_requires_id(self):
        from handlers.users import set_default_buyer_address

        with pytest.raises(https_fn.HttpsError) as exc:
            set_default_buyer_address(_auth_req(data={}))
        assert exc.value.code == "invalid-argument"

    @patch("handlers.users.get_db")
    def test_set_default_buyer_address_not_found(self, mock_get_db):
        from handlers.users import set_default_buyer_address

        db = MagicMock()
        tx = MagicMock()
        db.transaction.return_value = tx
        mock_get_db.return_value = db
        addresses_ref = MagicMock()
        address_ref = MagicMock()
        address_doc = MagicMock()
        address_doc.exists = False
        address_ref.get.return_value = address_doc
        addresses_ref.document.return_value = address_ref
        db.collection.return_value.document.return_value.collection.return_value = addresses_ref

        with patch("firebase_admin.firestore.transactional", lambda f: lambda txn: f(txn)):
            with pytest.raises(https_fn.HttpsError) as exc:
                set_default_buyer_address(_auth_req(data={Fields.ADDRESS_ID: "addr_1"}))
        assert exc.value.code == "not-found"


class TestNotificationAndTokenHandlersDeep:
    def test_update_notification_preferences_requires_auth(self):
        from handlers.users import update_notification_preferences

        req = Mock()
        req.auth = None
        req.data = {}
        with pytest.raises(https_fn.HttpsError) as exc:
            update_notification_preferences(req)
        assert exc.value.code == "unauthenticated"

    @patch("handlers.users.get_db")
    def test_update_notification_preferences_user_not_found(self, mock_get_db):
        from handlers.users import update_notification_preferences

        doc = MagicMock()
        doc.exists = False
        mock_get_db.return_value.collection.return_value.document.return_value.get.return_value = doc
        with pytest.raises(https_fn.HttpsError) as exc:
            update_notification_preferences(_auth_req(data={Fields.NOTIFY_NEW_PRODUCTS: True}))
        assert exc.value.code == "not-found"

    @patch("handlers.users.get_db")
    def test_update_notification_preferences_requires_premium(self, mock_get_db):
        from handlers.users import update_notification_preferences

        doc = MagicMock()
        doc.exists = True
        doc.to_dict.return_value = {Fields.IS_PREMIUM: False}
        mock_get_db.return_value.collection.return_value.document.return_value.get.return_value = doc
        with pytest.raises(https_fn.HttpsError) as exc:
            update_notification_preferences(_auth_req(data={Fields.NOTIFY_NEW_PRODUCTS: True}))
        assert exc.value.code == "permission-denied"

    @patch("handlers.users.get_db")
    def test_update_notification_preferences_rejects_no_valid_fields(self, mock_get_db):
        from handlers.users import update_notification_preferences

        doc = MagicMock()
        doc.exists = True
        doc.to_dict.return_value = {Fields.IS_PREMIUM: True}
        mock_get_db.return_value.collection.return_value.document.return_value.get.return_value = doc
        with pytest.raises(https_fn.HttpsError) as exc:
            update_notification_preferences(_auth_req(data={"unexpected": True}))
        assert exc.value.code == "invalid-argument"

    @patch("handlers.users.get_db")
    def test_update_notification_preferences_success(self, mock_get_db):
        from handlers.users import update_notification_preferences

        doc = MagicMock()
        doc.exists = True
        doc.to_dict.return_value = {Fields.IS_PREMIUM: True}
        user_ref = MagicMock()
        user_ref.get.return_value = doc
        mock_get_db.return_value.collection.return_value.document.return_value = user_ref

        result = update_notification_preferences(
            _auth_req(data={Fields.NOTIFY_NEW_PRODUCTS: True, Fields.NOTIFY_TRENDING: False})
        )
        assert result["success"] is True
        updates = user_ref.update.call_args.args[0]
        assert updates[Fields.NOTIFY_NEW_PRODUCTS] is True
        assert updates[Fields.NOTIFY_TRENDING] is False

    def test_cleanup_fcm_token_requires_auth(self):
        from handlers.users import cleanup_fcm_token

        req = Mock()
        req.auth = None
        req.data = {}
        with pytest.raises(https_fn.HttpsError) as exc:
            cleanup_fcm_token(req)
        assert exc.value.code == "unauthenticated"

    def test_cleanup_fcm_token_requires_valid_token(self):
        from handlers.users import cleanup_fcm_token

        with pytest.raises(https_fn.HttpsError) as exc:
            cleanup_fcm_token(_auth_req(data={Fields.FCM_TOKEN_KEY: ""}))
        assert exc.value.code == "invalid-argument"

    @patch("handlers.users.get_db")
    def test_cleanup_fcm_token_idempotent_when_missing(self, mock_get_db):
        from handlers.users import cleanup_fcm_token

        doc = MagicMock()
        doc.exists = False
        token_ref = MagicMock()
        token_ref.get.return_value = doc
        fcm_tokens = MagicMock()
        fcm_tokens.document.return_value = token_ref
        user_ref = MagicMock()
        user_ref.collection.return_value = fcm_tokens
        mock_get_db.return_value.collection.return_value.document.return_value = user_ref

        result = cleanup_fcm_token(_auth_req(data={Fields.FCM_TOKEN_KEY: "tok_1"}))
        assert result["success"] is True
        assert result["deleted"] is False

    @patch("handlers.users.get_db")
    def test_cleanup_fcm_token_deletes_existing_token(self, mock_get_db):
        from handlers.users import cleanup_fcm_token

        doc = MagicMock()
        doc.exists = True
        token_ref = MagicMock()
        token_ref.get.return_value = doc
        fcm_tokens = MagicMock()
        fcm_tokens.document.return_value = token_ref
        user_ref = MagicMock()
        user_ref.collection.return_value = fcm_tokens
        mock_get_db.return_value.collection.return_value.document.return_value = user_ref

        result = cleanup_fcm_token(_auth_req(data={Fields.FCM_TOKEN_KEY: "tok_1"}))
        assert result["success"] is True
        assert result["deleted"] is True
        token_ref.delete.assert_called_once()
