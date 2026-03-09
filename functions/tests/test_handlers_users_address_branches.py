from unittest.mock import MagicMock, Mock, patch

import pytest
from firebase_functions import https_fn

from schema_constants import Collections, ConsentMethodValues, COUNTRY_CANADA, Fields


def _auth_req(uid="user_123", data=None):
    req = Mock()
    req.auth = Mock()
    req.auth.uid = uid
    req.auth.token = {"email": "u@example.com", "email_verified": True}
    req.data = data or {}
    return req


class TestCreateAndUpdateUserProfileMore:
    @patch("handlers.users.get_server_timestamp", return_value="ts")
    @patch("handlers.users.get_db")
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.users.verify_turnstile_token", return_value=True)
    def test_create_user_profile_short_name_forces_user_and_accepts_whitelisted_consent_method(
        self, _mock_turnstile, mock_rl_cls, mock_get_db, _mock_ts
    ):
        from handlers.users import create_user_profile

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
        user_ref = Mock()
        user_ref.get.return_value = Mock(exists=False)
        mock_get_db.return_value.collection.return_value.document.return_value = user_ref

        req = _auth_req(
            data={
                Fields.NAME: "x",  # too short after sanitize => line 118
                Fields.CONSENT_METHOD: ConsentMethodValues.GOOGLE_OAUTH,  # line 134
            }
        )
        out = create_user_profile(req)
        assert out["success"] is True
        payload = user_ref.set.call_args.args[0]
        assert payload[Fields.NAME] == "User"
        assert payload[Fields.CONSENT_METHOD] == ConsentMethodValues.GOOGLE_OAUTH

    @patch("handlers.users.get_db")
    @patch("services.rate_limiter.RateLimiter")
    def test_update_user_profile_sets_tax_exemption_payload(self, mock_rl_cls, mock_get_db):
        from handlers.users import update_user_profile

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
        user_ref = Mock()
        user_ref.get.return_value = Mock(exists=True)
        mock_get_db.return_value.collection.return_value.document.return_value = user_ref

        req = _auth_req(data={Fields.TAX_EXEMPTION: {Fields.GST_NUMBER: "123456789RT0001"}})
        out = update_user_profile(req)
        assert out["success"] is True
        update_payload = user_ref.update.call_args.args[0]
        assert Fields.TAX_EXEMPTION in update_payload
        assert update_payload[Fields.TAX_EXEMPTION][Fields.GST_NUMBER] == "123456789RT0001"

    @patch("handlers.users.get_db")
    @patch("services.rate_limiter.RateLimiter")
    def test_update_user_profile_address_validation_error_and_non_canada_rethrow(self, mock_rl_cls, mock_get_db):
        from handlers.users import update_user_profile

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
        user_ref = Mock()
        user_ref.get.return_value = Mock(exists=True)
        mock_get_db.return_value.collection.return_value.document.return_value = user_ref

        # Invalid address shape -> generic validation exception branch
        with pytest.raises(https_fn.HttpsError) as bad_addr:
            update_user_profile(_auth_req(data={Fields.ADDRESS: {"city": "Toronto"}}))
        assert bad_addr.value.code == "invalid-argument"

        # Non-Canada address -> explicit HttpsError path re-raised
        with pytest.raises(https_fn.HttpsError) as non_ca:
            update_user_profile(
                _auth_req(
                    data={
                        Fields.ADDRESS: {
                            "street": "1 Main",
                            "city": "Toronto",
                            "state": "ON",
                            "postalCode": "M5V2H1",
                            "country": "United States",
                        }
                    }
                )
            )
        assert non_ca.value.code == "invalid-argument"

    @patch("handlers.users.get_db")
    @patch("services.rate_limiter.RateLimiter")
    def test_update_user_profile_valid_canadian_address_sets_address_payload(self, mock_rl_cls, mock_get_db):
        from handlers.users import update_user_profile

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
        user_ref = Mock()
        user_ref.get.return_value = Mock(exists=True)
        mock_get_db.return_value.collection.return_value.document.return_value = user_ref

        req = _auth_req(
            data={
                Fields.ADDRESS: {
                    "street": "1 Main",
                    "city": "Toronto",
                    "state": "ON",
                    "postalCode": "M5V2H1",
                    "country": COUNTRY_CANADA,
                }
            }
        )
        out = update_user_profile(req)
        assert out["success"] is True
        payload = user_ref.update.call_args.args[0]
        assert Fields.ADDRESS in payload

    @patch("handlers.users.get_db")
    @patch("services.rate_limiter.RateLimiter")
    def test_update_user_profile_rejects_name_outside_allowed_length(self, mock_rl_cls, mock_get_db):
        from handlers.users import update_user_profile

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "ok")
        user_ref = Mock()
        user_ref.get.return_value = Mock(exists=True)
        mock_get_db.return_value.collection.return_value.document.return_value = user_ref

        with pytest.raises(https_fn.HttpsError) as exc:
            update_user_profile(_auth_req(data={Fields.NAME: "x"}))
        assert exc.value.code == "invalid-argument"


class TestAddBuyerAddressMore:
    def test_add_buyer_address_requires_auth(self):
        from handlers.users import add_buyer_address

        req = Mock()
        req.auth = None
        req.data = {}
        with pytest.raises(https_fn.HttpsError) as exc:
            add_buyer_address(req)
        assert exc.value.code == "unauthenticated"

    def test_add_buyer_address_invalid_address_and_non_canada(self):
        from handlers.users import add_buyer_address

        # Invalid address shape
        with pytest.raises(https_fn.HttpsError) as bad:
            add_buyer_address(_auth_req(data={"street": "1 Main"}))
        assert bad.value.code == "invalid-argument"

        # Valid shape but non-Canada
        with pytest.raises(https_fn.HttpsError) as non_ca:
            add_buyer_address(
                _auth_req(
                    data={
                        "street": "1 Main",
                        "city": "Toronto",
                        "state": "ON",
                        "postalCode": "M5V2H1",
                        "country": "United States",
                    }
                )
            )
        assert non_ca.value.code == "invalid-argument"

    @patch("utils.helpers.geocode_address")
    @patch("handlers.users.get_db")
    def test_add_buyer_address_unsets_existing_default_when_new_default(self, mock_get_db, mock_geocode):
        from handlers.users import add_buyer_address

        mock_geocode.return_value = (
            True,
            "",
            {
                "street": "1 Main",
                "city": "Toronto",
                "state": "ON",
                "postalCode": "M5V2H1",
                "country": COUNTRY_CANADA,
                Fields.IS_DEFAULT: True,
            },
        )

        db = MagicMock()
        tx = MagicMock()
        db.transaction.return_value = tx
        mock_get_db.return_value = db

        existing_default_doc = MagicMock()
        existing_default_doc.reference = MagicMock()

        user_ref = MagicMock()
        user_snap = MagicMock()
        user_snap.to_dict.return_value = {Fields.ADDRESS_COUNT: 1}
        user_ref.get = lambda transaction=None: user_snap

        addresses_ref = MagicMock()
        addresses_ref.where.return_value.get.return_value = [existing_default_doc]
        new_ref = MagicMock()
        new_ref.id = "addr_new"
        addresses_ref.document.return_value = new_ref
        user_ref.collection.return_value = addresses_ref

        db.collection.return_value.document.return_value = user_ref

        with patch("firebase_admin.firestore.transactional", lambda f: lambda txn: f(txn)):
            out = add_buyer_address(
                _auth_req(
                    data={
                        "street": "1 Main",
                        "city": "Toronto",
                        "state": "ON",
                        "postalCode": "M5V2H1",
                        "country": COUNTRY_CANADA,
                        Fields.IS_DEFAULT: True,
                    }
                )
            )
        assert out["success"] is True
        tx.update.assert_any_call(existing_default_doc.reference, {Fields.IS_DEFAULT: False})


class TestUpdateBuyerAddressMore:
    def test_update_buyer_address_invalid_parse_non_canada_and_geocode_fail(self):
        from handlers.users import update_buyer_address

        # Invalid parse
        with pytest.raises(https_fn.HttpsError) as bad:
            update_buyer_address(_auth_req(data={Fields.ADDRESS_ID: "a1", "street": "x"}))
        assert bad.value.code == "invalid-argument"

        # Non-Canada
        with pytest.raises(https_fn.HttpsError) as non_ca:
            update_buyer_address(
                _auth_req(
                    data={
                        Fields.ADDRESS_ID: "a1",
                        "street": "1 Main",
                        "city": "Toronto",
                        "state": "ON",
                        "postalCode": "M5V2H1",
                        "country": "United States",
                    }
                )
            )
        assert non_ca.value.code == "invalid-argument"

        # Geocode fail
        with patch("utils.helpers.geocode_address", return_value=(False, "geo fail", {})):
            with pytest.raises(https_fn.HttpsError) as geo:
                update_buyer_address(
                    _auth_req(
                        data={
                            Fields.ADDRESS_ID: "a1",
                            "street": "1 Main",
                            "city": "Toronto",
                            "state": "ON",
                            "postalCode": "M5V2H1",
                            "country": COUNTRY_CANADA,
                        }
                    )
                )
        assert geo.value.code == "invalid-argument"

    @patch("utils.helpers.geocode_address")
    @patch("handlers.users.get_db")
    def test_update_buyer_address_transaction_branches(self, mock_get_db, mock_geocode):
        from handlers.users import update_buyer_address

        mock_geocode.return_value = (
            True,
            "",
            {
                "street": "1 Main",
                "city": "Toronto",
                "state": "ON",
                "postalCode": "M5V2H1",
                "country": COUNTRY_CANADA,
                Fields.IS_DEFAULT: True,
            },
        )

        db = MagicMock()
        tx = MagicMock()
        db.transaction.return_value = tx
        mock_get_db.return_value = db

        addresses_ref = MagicMock()
        address_ref = MagicMock()
        addresses_ref.document.return_value = address_ref

        users_doc_ref = MagicMock()
        users_doc_ref.collection.return_value = addresses_ref
        db.collection.return_value.document.return_value = users_doc_ref

        with patch("firebase_admin.firestore.transactional", lambda f: lambda txn: f(txn)):
            # not found branch
            missing_doc = MagicMock()
            missing_doc.exists = False
            address_ref.get.return_value = missing_doc
            with pytest.raises(https_fn.HttpsError) as nf:
                update_buyer_address(
                    _auth_req(
                        data={
                            Fields.ADDRESS_ID: "a1",
                            "street": "1 Main",
                            "city": "Toronto",
                            "state": "ON",
                            "postalCode": "M5V2H1",
                            "country": COUNTRY_CANADA,
                        }
                    )
                )
            assert nf.value.code == "not-found"

            # promote branch (new default true, old default false)
            current_doc = MagicMock()
            current_doc.exists = True
            current_doc.id = "a1"
            current_doc.to_dict.return_value = {Fields.IS_DEFAULT: False}
            address_ref.get.return_value = current_doc

            other_default_doc = MagicMock()
            other_default_doc.id = "other"
            other_default_doc.reference = MagicMock()
            other_default_doc.to_dict.return_value = {Fields.IS_DEFAULT: True}
            addresses_ref.get.return_value = [other_default_doc]

            out1 = update_buyer_address(
                _auth_req(
                    data={
                        Fields.ADDRESS_ID: "a1",
                        "street": "1 Main",
                        "city": "Toronto",
                        "state": "ON",
                        "postalCode": "M5V2H1",
                        "country": COUNTRY_CANADA,
                        Fields.IS_DEFAULT: True,
                    }
                )
            )
            assert out1["success"] is True
            tx.update.assert_any_call(other_default_doc.reference, {Fields.IS_DEFAULT: False})

            # demote branch with >1 existing addresses
            mock_geocode.return_value = (
                True,
                "",
                {
                    "street": "1 Main",
                    "city": "Toronto",
                    "state": "ON",
                    "postalCode": "M5V2H1",
                    "country": COUNTRY_CANADA,
                    Fields.IS_DEFAULT: False,
                },
            )
            current_doc.to_dict.return_value = {Fields.IS_DEFAULT: True}
            alt_doc = MagicMock()
            alt_doc.id = "other2"
            alt_doc.reference = MagicMock()
            addresses_ref.get.return_value = [current_doc, alt_doc]

            out2 = update_buyer_address(
                _auth_req(
                    data={
                        Fields.ADDRESS_ID: "a1",
                        "street": "1 Main",
                        "city": "Toronto",
                        "state": "ON",
                        "postalCode": "M5V2H1",
                        "country": COUNTRY_CANADA,
                        Fields.IS_DEFAULT: False,
                    }
                )
            )
            assert out2["success"] is True
            tx.update.assert_any_call(alt_doc.reference, {Fields.IS_DEFAULT: True})

            # plain update branch (no default change)
            current_doc.to_dict.return_value = {Fields.IS_DEFAULT: False}
            out3 = update_buyer_address(
                _auth_req(
                    data={
                        Fields.ADDRESS_ID: "a1",
                        "street": "1 Main",
                        "city": "Toronto",
                        "state": "ON",
                        "postalCode": "M5V2H1",
                        "country": COUNTRY_CANADA,
                        Fields.IS_DEFAULT: False,
                    }
                )
            )
            assert out3["success"] is True
            tx.update.assert_called()


class TestDeleteBuyerAddressMore:
    @patch("handlers.users.get_db")
    def test_delete_buyer_address_not_found_and_ownership_denied(self, mock_get_db):
        from handlers.users import delete_buyer_address

        db = MagicMock()
        mock_get_db.return_value = db

        address_ref = MagicMock()
        addresses_ref = MagicMock()
        addresses_ref.document.return_value = address_ref
        user_ref = MagicMock()
        user_ref.collection.return_value = addresses_ref
        db.collection.return_value.document.return_value = user_ref

        # not found
        missing_doc = MagicMock()
        missing_doc.exists = False
        address_ref.get.return_value = missing_doc
        with pytest.raises(https_fn.HttpsError) as nf:
            delete_buyer_address(_auth_req(data={Fields.ADDRESS_ID: "a1"}))
        assert nf.value.code == "not-found"

        # ownership denied
        found_doc = MagicMock()
        found_doc.exists = True
        found_doc.to_dict.return_value = {}
        address_ref.get.return_value = found_doc
        address_ref.parent.parent.id = "other_user"
        with pytest.raises(https_fn.HttpsError) as denied:
            delete_buyer_address(_auth_req(data={Fields.ADDRESS_ID: "a1"}))
        assert denied.value.code == "permission-denied"
