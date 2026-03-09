import importlib
import sys
from types import SimpleNamespace
from unittest.mock import Mock, patch

import pytest
import requests
from firebase_functions import https_fn

from schema_constants import (
    Collections,
    Fields,
    ProductLifecycleStatusValues,
    RateLimitActions,
    UserRoleValues,
)


def _snap(data=None, *, exists=True, doc_id="doc_1"):
    snap = Mock()
    snap.exists = exists
    snap.id = doc_id
    snap.to_dict.return_value = {} if data is None else data
    snap.reference = Mock()
    return snap


def _req(uid: str | None = None, data: dict | None = None, headers: dict | None = None):
    req = Mock()
    req.auth = Mock(uid=uid) if uid else None
    req.data = {} if data is None else data
    req.raw_request = Mock(headers=headers or {})
    return req


def _decorator_passthrough(*args, **kwargs):
    if len(args) == 1 and callable(args[0]) and not kwargs:
        return args[0]

    def _decorator(func):
        return func

    return _decorator


@pytest.fixture(autouse=True)
def _reload_products_with_firestore_passthrough():
    ff = sys.modules["firebase_functions"]
    if not hasattr(ff, "firestore_fn"):
        ff.firestore_fn = Mock()
    ff.firestore_fn.on_document_created = _decorator_passthrough
    ff.firestore_fn.on_document_updated = _decorator_passthrough
    ff.firestore_fn.on_document_deleted = _decorator_passthrough

    import handlers.products as products

    importlib.reload(products)
    yield


class TestProductAddressAndSellerHelpers:
    def test_validate_warehouse_address_required_fields_and_type(self):
        from handlers.products import _validate_warehouse_address

        with pytest.raises(https_fn.HttpsError) as exc:
            _validate_warehouse_address("not-a-map")
        assert exc.value.code == "invalid-argument"

        with pytest.raises(https_fn.HttpsError):
            _validate_warehouse_address({Fields.CITY: "Toronto", Fields.COUNTRY: "CA"})
        with pytest.raises(https_fn.HttpsError):
            _validate_warehouse_address({Fields.STREET: "1 Main", Fields.COUNTRY: "CA"})
        with pytest.raises(https_fn.HttpsError):
            _validate_warehouse_address({Fields.STREET: "1 Main", Fields.CITY: "Toronto"})

    def test_validate_warehouse_address_canada_rules_and_international(self):
        from handlers.products import _validate_warehouse_address

        with pytest.raises(https_fn.HttpsError):
            _validate_warehouse_address(
                {
                    Fields.STREET: "1 Main",
                    Fields.CITY: "Toronto",
                    Fields.COUNTRY: "Canada",
                    Fields.STATE: "XX",
                    Fields.POSTAL_CODE: "M5V3A8",
                }
            )

        with pytest.raises(https_fn.HttpsError):
            _validate_warehouse_address(
                {
                    Fields.STREET: "1 Main",
                    Fields.CITY: "Toronto",
                    Fields.COUNTRY: "CA",
                    Fields.STATE: "ON",
                    Fields.POSTAL_CODE: "INVALID",
                }
            )

        _validate_warehouse_address(
            {
                Fields.STREET: "1 Main",
                Fields.CITY: "Paris",
                Fields.COUNTRY: "France",
            }
        )

    @patch("handlers.products.get_db")
    def test_derive_ship_from_fields_for_digital_and_seller_address(self, mock_get_db):
        from handlers.products import _derive_ship_from_fields

        assert _derive_ship_from_fields("seller_1", {Fields.IS_DIGITAL: True}) == {}

        out = _derive_ship_from_fields(
            "seller_1",
            {
                Fields.IS_DIGITAL: False,
                Fields.SELLER_ADDRESS: {
                    Fields.CITY: "Toronto",
                    Fields.STATE: "ON",
                    Fields.COUNTRY: "Canada",
                },
            },
        )
        assert out[Fields.SHIP_FROM_CITY] == "Toronto"
        assert out[Fields.SHIP_FROM_PROVINCE] == "ON"
        assert out[Fields.SHIP_FROM_COUNTRY] == "Canada"
        assert out[Fields.SHIP_FROM_COUNTRIES] == ["Canada"]
        mock_get_db.assert_not_called()

    @patch("handlers.products.get_db")
    def test_derive_ship_from_fields_from_warehouses(self, mock_get_db):
        from handlers.products import _derive_ship_from_fields

        users_col = Mock()
        seller_ref = Mock()
        wh_col = Mock()
        wh_col.document.side_effect = lambda wid: SimpleNamespace(id=wid)
        seller_ref.collection.return_value = wh_col
        users_col.document.return_value = seller_ref

        db = Mock()
        db.collection.return_value = users_col
        db.get_all.return_value = [
            _snap({"address": {Fields.CITY: "Montreal", Fields.STATE: "QC", Fields.COUNTRY: "Canada"}}, doc_id="wh_1"),
            _snap(
                {"isDefault": True, "address": {Fields.CITY: "New York", Fields.STATE: "NY", Fields.COUNTRY: "USA"}},
                doc_id="wh_2",
            ),
            _snap(exists=False, doc_id="wh_missing"),
        ]
        mock_get_db.return_value = db

        out = _derive_ship_from_fields(
            "seller_1",
            {
                Fields.WAREHOUSE_IDS: ["wh_1", "wh_2", "wh_missing"],
                Fields.IS_DIGITAL: False,
            },
        )
        assert out[Fields.SHIP_FROM_CITY] == "New York"
        assert out[Fields.SHIP_FROM_PROVINCE] == "NY"
        assert out[Fields.SHIP_FROM_COUNTRY] == "USA"
        assert out[Fields.SELLER_ADDRESS][Fields.COUNTRY] == "USA"
        assert out[Fields.SHIP_FROM_COUNTRIES] == ["Canada", "USA"]

    @patch("handlers.products.get_db")
    def test_get_seller_email_and_lang_variants(self, mock_get_db):
        from handlers.products import _get_seller_email, _get_seller_email_and_lang

        assert _get_seller_email(None) is None
        assert _get_seller_email_and_lang(None) == (None, "en")

        db = Mock()
        user_doc = _snap({Fields.EMAIL: "seller@example.com", Fields.PREFERRED_LANGUAGE: "fr"})
        db.collection.return_value.document.return_value.get.return_value = user_doc
        mock_get_db.return_value = db
        assert _get_seller_email("seller_1") == "seller@example.com"
        assert _get_seller_email_and_lang("seller_1") == ("seller@example.com", "fr")

        mock_get_db.side_effect = RuntimeError("db down")
        assert _get_seller_email("seller_2") is None
        assert _get_seller_email_and_lang("seller_2") == (None, "en")

    @patch("handlers.products.requests.head")
    def test_check_digital_url_reachability_collects_http_and_network_failures(self, mock_head):
        from handlers.products import _check_digital_url_reachability

        ok = Mock(status_code=200)
        bad = Mock(status_code=404)
        mock_head.side_effect = [bad, requests.exceptions.RequestException("dns"), ok]

        dead = _check_digital_url_reachability(
            "prod_1",
            {
                Fields.BOOK_SOURCE_URL: "https://books.example.com/a",
                Fields.DIGITAL_BUILDS: {
                    "win": "https://downloads.example.com/win",
                    "mac": "https://downloads.example.com/mac",
                },
            },
        )
        assert dead == ["bookSourceUrl", "digitalBuilds.win"]


class TestProductsEndpointGuards:
    def test_configure_algolia_requires_auth(self):
        from handlers.products import configure_algolia

        with pytest.raises(https_fn.HttpsError) as exc:
            configure_algolia(_req())
        assert exc.value.code == "unauthenticated"

    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_configure_algolia_authz_and_rate_limit_guards(self, mock_get_db, mock_rl_cls):
        from handlers.products import configure_algolia

        rl = Mock()
        rl.check_rate_limit.return_value = (True, "")
        mock_rl_cls.return_value = rl

        users_col = Mock()
        db = Mock()
        db.collection.return_value = users_col
        mock_get_db.return_value = db

        users_col.document.return_value.get.return_value = _snap(exists=False)
        with pytest.raises(https_fn.HttpsError) as not_found:
            configure_algolia(_req("u1"))
        assert not_found.value.code == "not-found"

        users_col.document.return_value.get.return_value = _snap({Fields.ROLES: []})
        with pytest.raises(https_fn.HttpsError) as denied:
            configure_algolia(_req("u1"))
        assert denied.value.code == "permission-denied"

        users_col.document.return_value.get.return_value = _snap({Fields.ROLES: [UserRoleValues.ADMIN]})
        rl.check_rate_limit.return_value = (False, "slow down")
        with pytest.raises(https_fn.HttpsError) as limited:
            configure_algolia(_req("u1"))
        assert limited.value.code == "resource-exhausted"

    @patch("services.algolia_service.configure_algolia_index", side_effect=RuntimeError("algolia down"))
    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_configure_algolia_maps_internal_errors(self, mock_get_db, mock_rl_cls, _mock_cfg):
        from handlers.products import configure_algolia

        rl = Mock()
        rl.check_rate_limit.return_value = (True, "")
        mock_rl_cls.return_value = rl

        db = Mock()
        db.collection.return_value.document.return_value.get.return_value = _snap({Fields.ROLES: [UserRoleValues.ADMIN]})
        mock_get_db.return_value = db

        with pytest.raises(https_fn.HttpsError) as exc:
            configure_algolia(_req("admin_1"))
        assert exc.value.code == "internal"

    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_get_products_paginated_rate_limit_and_validation_guards(self, mock_get_db, mock_rl_cls):
        from handlers.products import get_products_paginated

        rl = Mock()
        mock_rl_cls.return_value = rl
        db = Mock()
        mock_get_db.return_value = db

        rl.check_rate_limit.return_value = (False, "ip limited")
        with pytest.raises(https_fn.HttpsError) as ip_limited:
            get_products_paginated(_req(None, {}, headers={"X-Forwarded-For": "1.2.3.4"}))
        assert ip_limited.value.code == "resource-exhausted"

        rl.check_rate_limit.return_value = (True, "")
        db.collection.return_value.document.return_value.get.return_value = _snap({Fields.ROLES: []})
        with pytest.raises(https_fn.HttpsError) as bad_order:
            get_products_paginated(_req("u1", {"orderBy": "bad"}))
        assert bad_order.value.code == "invalid-argument"

        with pytest.raises(https_fn.HttpsError) as bad_dir:
            get_products_paginated(_req("u1", {"orderDirection": "sideways"}))
        assert bad_dir.value.code == "invalid-argument"

    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_get_products_paginated_maps_query_exceptions(self, mock_get_db, mock_rl_cls):
        from handlers.products import get_products_paginated

        rl = Mock()
        rl.check_rate_limit.return_value = (True, "")
        mock_rl_cls.return_value = rl

        query = Mock()
        query.where.return_value = query
        query.order_by.return_value = query
        query.limit.return_value = query
        query.stream.side_effect = RuntimeError("query down")

        db = Mock()
        db.collection.return_value = query
        mock_get_db.return_value = db

        with pytest.raises(https_fn.HttpsError) as exc:
            get_products_paginated(_req(None, {"orderBy": Fields.CREATED_AT, "orderDirection": "desc"}))
        assert exc.value.code == "internal"

    @patch("handlers.products.RateLimiter")
    def test_get_seller_products_paginated_guard_paths(self, mock_rl_cls):
        from handlers.products import get_seller_products_paginated

        rl = Mock()
        rl.check_rate_limit.return_value = (False, "too many")
        mock_rl_cls.return_value = rl

        with patch("handlers.products.get_db", return_value=Mock()):
            with pytest.raises(https_fn.HttpsError) as limited:
                get_seller_products_paginated(_req("seller_1", {Fields.SELLER_ID: "seller_1"}))
        assert limited.value.code == "resource-exhausted"

        with pytest.raises(https_fn.HttpsError) as unauth:
            get_seller_products_paginated(_req(None, {}))
        assert unauth.value.code == "unauthenticated"

        with pytest.raises(https_fn.HttpsError) as denied:
            get_seller_products_paginated(_req(None, {Fields.SELLER_ID: "seller_1", "includeInactive": True}))
        assert denied.value.code == "permission-denied"

    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_get_seller_products_paginated_include_inactive_owner_checks_and_internal(self, mock_get_db, mock_rl_cls):
        from handlers.products import get_seller_products_paginated

        rl = Mock()
        rl.check_rate_limit.return_value = (True, "")
        mock_rl_cls.return_value = rl

        users_col = Mock()
        query = Mock()
        query.where.return_value = query
        query.order_by.return_value = query
        query.limit.return_value = query
        query.stream.side_effect = RuntimeError("stream down")

        db = Mock()
        db.collection.side_effect = lambda name: users_col if name == Collections.USERS else query
        mock_get_db.return_value = db

        users_col.document.return_value.get.return_value = _snap(exists=False)
        with pytest.raises(https_fn.HttpsError) as missing_user:
            get_seller_products_paginated(_req("viewer", {Fields.SELLER_ID: "seller_1", "includeInactive": True}))
        assert missing_user.value.code == "not-found"

        users_col.document.return_value.get.return_value = _snap({Fields.ROLES: []})
        with pytest.raises(https_fn.HttpsError) as denied:
            get_seller_products_paginated(_req("viewer", {Fields.SELLER_ID: "seller_1", "includeInactive": True}))
        assert denied.value.code == "permission-denied"

        users_col.document.return_value.get.return_value = _snap({Fields.ROLES: [UserRoleValues.ADMIN]})
        with pytest.raises(https_fn.HttpsError) as internal:
            get_seller_products_paginated(_req("admin_1", {Fields.SELLER_ID: "seller_1", "includeInactive": True}))
        assert internal.value.code == "internal"

    def test_get_product_ratings_paginated_auth_guard(self):
        from handlers.products import get_product_ratings_paginated

        with pytest.raises(https_fn.HttpsError) as exc:
            get_product_ratings_paginated(_req(None, {}))
        assert exc.value.code == "unauthenticated"

    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_get_product_ratings_paginated_validation_and_internal_paths(self, mock_get_db, mock_rl_cls):
        from handlers.products import get_product_ratings_paginated

        rl = Mock()
        rl.check_rate_limit.return_value = (True, "")
        mock_rl_cls.return_value = rl

        db = Mock()
        mock_get_db.return_value = db

        req = _req("u1", {})
        with pytest.raises(https_fn.HttpsError) as missing_pid:
            get_product_ratings_paginated(req)
        assert missing_pid.value.code == "invalid-argument"

        with pytest.raises(https_fn.HttpsError) as bad_min:
            get_product_ratings_paginated(_req("u1", {Fields.PRODUCT_ID: "p1", "minRating": 10}))
        assert bad_min.value.code == "invalid-argument"

        query = Mock()
        query.where.return_value = query
        query.order_by.return_value = query
        query.limit.return_value = query
        query.stream.side_effect = RuntimeError("ratings down")
        db.collection.return_value = query

        with pytest.raises(https_fn.HttpsError) as internal:
            get_product_ratings_paginated(_req("u1", {Fields.PRODUCT_ID: "p1"}))
        assert internal.value.code == "internal"

    @patch("handlers.products.get_db")
    @patch("handlers.products.algolia_delete_product", side_effect=RuntimeError("algolia down"))
    def test_on_product_deleted_handles_algolia_and_cleanup_errors(self, _mock_algolia, mock_get_db):
        from handlers.products import on_product_deleted

        notifications = Mock()
        notifications.where.return_value = notifications
        notifications.limit.return_value = notifications
        notifications.stream.side_effect = RuntimeError("subs down")

        favorites = Mock()
        favorites.where.return_value = favorites
        favorites.limit.return_value = favorites
        favorites.stream.side_effect = RuntimeError("favs down")

        db = Mock()
        db.collection.side_effect = lambda name: notifications if name == Collections.STOCK_NOTIFICATIONS else Mock()
        db.collection_group.return_value = favorites
        mock_get_db.return_value = db

        event = Mock()
        event.params = {Fields.PRODUCT_ID: "prod_1"}
        on_product_deleted(event)


class TestProductUpdatedDeepBranches:
    @patch("handlers.products.get_db")
    @patch("handlers.products.algolia_delete_product")
    def test_on_product_updated_empty_and_inactive_paths(self, mock_algolia_delete, mock_get_db):
        from handlers.products import on_product_updated

        event_empty = Mock()
        event_empty.params = {Fields.PRODUCT_ID: "p_empty"}
        event_empty.data = Mock()
        event_empty.data.after.to_dict.return_value = {}
        event_empty.data.before.to_dict.return_value = {}
        on_product_updated(event_empty)

        event_inactive = Mock()
        event_inactive.params = {Fields.PRODUCT_ID: "p_inactive"}
        event_inactive.data = Mock()
        event_inactive.data.after.to_dict.return_value = {Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.PAUSED}
        event_inactive.data.before.to_dict.return_value = {}
        on_product_updated(event_inactive)
        mock_algolia_delete.assert_called_once_with("p_inactive")

        mock_algolia_delete.side_effect = RuntimeError("algolia boom")
        on_product_updated(event_inactive)

    @patch("handlers.products.get_db")
    @patch("handlers.products._notify_admins_new_product", side_effect=RuntimeError("mail down"))
    def test_on_product_updated_rejected_resubmission_resets_under_review(self, _mock_notify, mock_get_db):
        from handlers import products

        product_ref = Mock()
        db = Mock()
        db.collection.return_value.document.return_value = product_ref
        mock_get_db.return_value = db

        before = {
            Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.REJECTED,
            Fields.NAME: "Old Name",
        }
        after = {
            Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.REJECTED,
            Fields.NAME: "New Name",
        }
        event = Mock()
        event.params = {Fields.PRODUCT_ID: "p_resubmit"}
        event.data = Mock()
        event.data.before.to_dict.return_value = before
        event.data.after.to_dict.return_value = after

        # Force execution past the early inactive-branch gate to exercise resubmission logic.
        with patch.object(products.ProductLifecycleStatusValues, "ACTIVE", ProductLifecycleStatusValues.REJECTED):
            products.on_product_updated(event)
        product_ref.update.assert_called_once_with(
            {
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.UNDER_REVIEW,
                Fields.APPROVAL_REJECTION_REASON: None,
            }
        )

    @patch("handlers.products._track_price_history", side_effect=RuntimeError("history down"))
    @patch("handlers.products._fire_back_in_stock_notifications", side_effect=RuntimeError("stock down"))
    @patch("handlers.products.index_product", side_effect=RuntimeError("index down"))
    @patch("handlers.products.get_db")
    def test_on_product_updated_skip_validation_invalid_stock_and_indexing_errors(
        self,
        mock_get_db,
        _mock_index,
        _mock_stock,
        _mock_history,
    ):
        from handlers.products import on_product_updated

        product_ref = Mock()
        db = Mock()
        db.collection.return_value.document.return_value = product_ref
        mock_get_db.return_value = db

        before = {Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE, Fields.STOCK_QUANTITY: 1}
        after = {Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE, Fields.STOCK_QUANTITY: -3}
        event = Mock()
        event.params = {Fields.PRODUCT_ID: "p_bad_stock"}
        event.data = Mock()
        event.data.before.to_dict.return_value = before
        event.data.after.to_dict.return_value = after

        on_product_updated(event)
        product_ref.update.assert_called_once_with({Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.PAUSED})
