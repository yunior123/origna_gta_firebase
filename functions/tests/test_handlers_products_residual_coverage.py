import base64
import importlib
import sys
from unittest.mock import Mock, patch

import pytest
from firebase_functions import https_fn

from config import Environment
from schema_constants import (
    Collections,
    Fields,
    ProductLifecycleStatusValues,
    UserRoleValues,
    WarehouseTypeValues,
)


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


def _snap(data=None, *, exists=True, doc_id="doc_1"):
    snap = Mock()
    snap.exists = exists
    snap.id = doc_id
    snap.to_dict.return_value = {} if data is None else data
    snap.reference = Mock()
    return snap


def _req(uid: str | None, data: dict | None = None, *, token: dict | None = None):
    req = Mock()
    req.auth = Mock(uid=uid, token=(token or {})) if uid else None
    req.data = data or {}
    req.raw_request = Mock()
    req.raw_request.headers = {}
    return req


def _event(product_id: str, before: dict, after: dict):
    event = Mock()
    event.params = {Fields.PRODUCT_ID: product_id}
    event.data = Mock()
    event.data.before.to_dict.return_value = before
    event.data.after.to_dict.return_value = after
    return event


class TestDeleteAndGeoapifyResidual:
    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.create_success_response", side_effect=lambda payload: payload)
    @patch("handlers.products.get_server_timestamp", return_value="ts")
    @patch("handlers.products._get_cached_s3_client")
    @patch("handlers.products.algolia_delete_product")
    @patch("handlers.products.get_db")
    def test_delete_product_r2_skip_and_favorites_empty_page_break(
        self, mock_get_db, _mock_algolia_delete, mock_s3, _mock_ts, _mock_resp, mock_rl
    ):
        from handlers.products import delete_product

        product_ref = Mock()
        product_ref.get.return_value = _snap(
            {
                Fields.SELLER_ID: "seller_1",
                Fields.IMAGE_URLS: ["https://example.com/not-origna.jpg"],
            },
            exists=True,
            doc_id="prod_1",
        )
        products_col = Mock()
        products_col.document.return_value = product_ref

        users_col = Mock()
        users_col.document.return_value.get.return_value = _snap(
            {Fields.ROLES: [UserRoleValues.SELLER]}, exists=True
        )

        orders_q = Mock()
        orders_q.where.return_value = orders_q
        orders_q.limit.return_value = orders_q
        orders_q.stream.return_value = []
        orders_col = Mock()
        orders_col.where.return_value = orders_q

        stock_q = Mock()
        stock_q.where.return_value = stock_q
        stock_q.limit.return_value = stock_q
        stock_q.stream.side_effect = [[]]
        stock_col = Mock()
        stock_col.where.return_value = stock_q

        fav_q = Mock()
        fav_q.where.return_value = fav_q
        fav_q.limit.return_value = fav_q
        fav_q.stream.return_value = []

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.PRODUCTS: products_col,
            Collections.USERS: users_col,
            Collections.ORDERS: orders_col,
            Collections.STOCK_NOTIFICATIONS: stock_col,
        }[name]
        db.collection_group.return_value = fav_q
        mock_get_db.return_value = db
        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        out = delete_product(_req("seller_1", {Fields.PRODUCT_ID: "prod_1"}))
        assert out["message"] == "Product deleted successfully"
        product_ref.update.assert_called_once()
        mock_s3.return_value.delete_object.assert_not_called()

    @patch("handlers.products.get_geoapify_api_key", return_value="geo_key")
    @patch("handlers.products.requests.get")
    def test_verify_address_with_geoapify_http_non_200(self, mock_get, _mock_key):
        from handlers.products import _verify_address_with_geoapify

        mock_get.return_value = Mock(status_code=500)
        ok, reason = _verify_address_with_geoapify("p1", 43.0, -79.0, "1 Main", "Toronto", "M5V2T6", "CA")
        assert ok is False
        assert "HTTP 500" in reason

    @patch("handlers.products.get_geoapify_api_key", return_value="geo_key")
    @patch("handlers.products.requests.get")
    def test_verify_address_with_geoapify_empty_features(self, mock_get, _mock_key):
        from handlers.products import _verify_address_with_geoapify

        resp = Mock(status_code=200)
        resp.json.return_value = {"features": []}
        mock_get.return_value = resp
        ok, reason = _verify_address_with_geoapify("p1", 43.0, -79.0, "1 Main", "Toronto", "M5V2T6", "CA")
        assert ok is False
        assert "returned no results" in reason

    @patch("handlers.products.get_geoapify_api_key", return_value="geo_key")
    @patch("handlers.products.requests.get")
    def test_verify_address_with_geoapify_country_and_postal_mismatch(self, mock_get, _mock_key):
        from handlers.products import _verify_address_with_geoapify

        resp_country = Mock(status_code=200)
        resp_country.json.return_value = {
            "features": [{"properties": {"city": "Toronto", "postcode": "M5V2T6", "country_code": "US"}}]
        }
        mock_get.return_value = resp_country
        ok, reason = _verify_address_with_geoapify("p1", 43.0, -79.0, "1 Main", "Toronto", "M5V2T6", "CA")
        assert ok is False
        assert "Country mismatch" in reason

        resp_postal = Mock(status_code=200)
        resp_postal.json.return_value = {
            "features": [{"properties": {"city": "Toronto", "postcode": "H1A1A1", "country_code": "CA"}}]
        }
        mock_get.return_value = resp_postal
        ok, reason = _verify_address_with_geoapify("p1", 43.0, -79.0, "1 Main", "Toronto", "M5V2T6", "CA")
        assert ok is False
        assert "Postal code mismatch" in reason

    @patch("handlers.products.get_geoapify_api_key", return_value="geo_key")
    @patch("handlers.products.requests.get", side_effect=__import__("requests").Timeout())
    def test_verify_address_with_geoapify_timeout(self, _mock_get, _mock_key):
        from handlers.products import _verify_address_with_geoapify

        ok, reason = _verify_address_with_geoapify("p1", 43.0, -79.0, "1 Main", "Toronto", "M5V2T6", "CA")
        assert ok is False
        assert "timeout" in reason.lower()


class TestCreateProductResidual:
    def _base_product(self):
        return {
            Fields.NAME: "Product A",
            Fields.DESCRIPTION: "Desc",
            Fields.PRICE: 10.0,
            Fields.CATEGORY_ID: 1,
            Fields.STOCK_QUANTITY: 2,
            Fields.IS_DIGITAL: False,
            Fields.SELLER_ADDRESS: {
                Fields.STREET: "1 Main",
                Fields.CITY: "Toronto",
                Fields.STATE: "ON",
                Fields.POSTAL_CODE: "M5V2T6",
                Fields.COUNTRY: "Canada",
            },
        }

    def _db_for_create(self):
        users_col = Mock()
        users_col.document.return_value.get.return_value = _snap(
            {Fields.ROLES: [UserRoleValues.SELLER], Fields.SUSPENDED: False}, exists=True
        )
        profiles_col = Mock()
        profiles_col.document.return_value.get.return_value = _snap(
            {Fields.ONBOARDING_COMPLETED: True}, exists=True
        )
        products_col = Mock()
        product_ref = Mock()
        product_ref.id = "prod_new"
        products_col.document.return_value = product_ref
        sku_col = Mock()
        sku_ref = Mock()
        sku_col.document.return_value = sku_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.SELLER_PROFILES: profiles_col,
            Collections.PRODUCTS: products_col,
            Collections.SELLER_SKUS: sku_col,
        }[name]
        return db, product_ref, sku_ref

    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_create_product_atomic_base64_decode_exception_branch(self, mock_get_db, mock_rl):
        from handlers.products import create_product_atomic

        db, _product_ref, _sku_ref = self._db_for_create()
        mock_get_db.return_value = db
        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        with pytest.raises(https_fn.HttpsError) as exc:
            create_product_atomic(
                _req(
                    "seller_1",
                    {
                        "productData": self._base_product(),
                        "images": [{"data": object(), "contentType": "image/png"}],
                    },
                )
            )
        assert exc.value.code == "invalid-argument"

    @patch("handlers.products.BusinessRules.MAX_IMAGE_BYTES", 2)
    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_create_product_atomic_image_too_large_branch(self, mock_get_db, mock_rl):
        from handlers.products import create_product_atomic

        db, _product_ref, _sku_ref = self._db_for_create()
        mock_get_db.return_value = db
        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        encoded = base64.b64encode(b"\x89PNG").decode("ascii")

        with pytest.raises(https_fn.HttpsError) as exc:
            create_product_atomic(
                _req(
                    "seller_1",
                    {
                        "productData": self._base_product(),
                        "images": [{"data": encoded, "contentType": "image/png"}],
                    },
                )
            )
        assert exc.value.code == "invalid-argument"

    @patch("handlers.products.CURRENT_ENV", Environment.EMULATOR)
    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_create_product_atomic_video_url_and_international_guards(self, mock_get_db, mock_rl):
        from handlers.products import create_product_atomic

        db, _product_ref, _sku_ref = self._db_for_create()
        mock_get_db.return_value = db
        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        product_with_bad_video = self._base_product()
        product_with_bad_video[Fields.VIDEO_URL] = "https://evil.example.com/video.mp4"
        with pytest.raises(https_fn.HttpsError) as bad_video:
            create_product_atomic(
                _req(
                    "seller_1",
                    {
                        "productData": product_with_bad_video,
                        "images": [],
                        "testImageUrls": ["https://cdn.test/products/a.jpg"],
                    },
                )
            )
        assert bad_video.value.code == "invalid-argument"

        intl_no_ship_from = self._base_product()
        intl_no_ship_from[Fields.IS_INTERNATIONAL] = True
        with pytest.raises(https_fn.HttpsError) as bad_ship_from:
            create_product_atomic(
                _req(
                    "seller_1",
                    {
                        "productData": intl_no_ship_from,
                        "images": [],
                        "testImageUrls": ["https://cdn.test/products/a.jpg"],
                    },
                )
            )
        assert bad_ship_from.value.code == "invalid-argument"

    @patch("handlers.products.CURRENT_ENV", Environment.EMULATOR)
    @patch("utils.helpers.geocode_address", return_value=(False, "bad address", {}))
    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_create_product_atomic_geocode_failure_branch(self, mock_get_db, mock_rl, _mock_geocode):
        from handlers.products import create_product_atomic

        db, _product_ref, _sku_ref = self._db_for_create()
        mock_get_db.return_value = db
        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        with pytest.raises(https_fn.HttpsError) as exc:
            create_product_atomic(
                _req(
                    "seller_1",
                    {
                        "productData": self._base_product(),
                        "images": [],
                        "testImageUrls": ["https://cdn.test/products/a.jpg"],
                    },
                )
            )
        assert exc.value.code == "invalid-argument"

    @patch("handlers.products.create_success_response", side_effect=lambda payload: payload)
    @patch("handlers.products.ProductCreate")
    @patch("handlers.products._derive_ship_from_fields", return_value={})
    @patch("handlers.products.get_server_timestamp", return_value="ts")
    @patch(
        "utils.helpers.geocode_address",
        return_value=(
            True,
            "",
            {
                Fields.STREET: "1 Main",
                Fields.CITY: "Toronto",
                Fields.STATE: "ON",
                Fields.POSTAL_CODE: "M5V2T6",
                Fields.COUNTRY: "Canada",
                Fields.LATITUDE: 43.7,
                Fields.LONGITUDE: -79.4,
            },
        ),
    )
    @patch("handlers.products.CURRENT_ENV", Environment.EMULATOR)
    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_create_product_atomic_non_conflict_sku_error_warning_path(
        self,
        mock_get_db,
        mock_rl,
        _mock_geocode,
        _mock_ts,
        _mock_ship_from,
        mock_product_create,
        _mock_resp,
    ):
        from handlers.products import create_product_atomic

        db, product_ref, sku_ref = self._db_for_create()
        mock_get_db.return_value = db
        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        sku_ref.create.side_effect = RuntimeError("transient sku write issue")

        fake_model = Mock()
        fake_model.model_dump.return_value = dict(self._base_product())
        mock_product_create.return_value = fake_model

        product_data = self._base_product()
        product_data[Fields.SELLER_SKU] = "SKU-1"
        out = create_product_atomic(
            _req(
                "seller_1",
                {
                    "productData": product_data,
                    "images": [],
                    "testImageUrls": ["https://cdn.test/products/a.jpg"],
                },
            )
        )
        assert out[Fields.PRODUCT_ID] == "prod_new"
        product_ref.set.assert_called_once()
        sku_ref.create.assert_called_once()


class TestAdminApprovalAndRejectionResidual:
    @patch("handlers.products.get_db")
    def test_admin_approve_product_guard_matrix(self, mock_get_db):
        from handlers.products import admin_approve_product

        with pytest.raises(https_fn.HttpsError) as unauth:
            admin_approve_product(_req(None, {Fields.PRODUCT_ID: "p1"}))
        assert unauth.value.code == "unauthenticated"

        users_col = Mock()
        products_col = Mock()
        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
        }[name]
        mock_get_db.return_value = db

        users_col.document.return_value.get.return_value = _snap(exists=False)
        with pytest.raises(https_fn.HttpsError) as missing_user:
            admin_approve_product(_req("admin_1", {Fields.PRODUCT_ID: "p1"}))
        assert missing_user.value.code == "not-found"

        users_col.document.return_value.get.return_value = _snap({Fields.ROLES: []}, exists=True)
        with pytest.raises(https_fn.HttpsError) as denied:
            admin_approve_product(_req("admin_1", {Fields.PRODUCT_ID: "p1"}))
        assert denied.value.code == "permission-denied"

        users_col.document.return_value.get.return_value = _snap(
            {Fields.ROLES: [UserRoleValues.ADMIN]}, exists=True
        )
        with pytest.raises(https_fn.HttpsError) as missing_pid:
            admin_approve_product(_req("admin_1", {}))
        assert missing_pid.value.code == "invalid-argument"

        products_col.document.return_value.get.return_value = _snap(exists=False)
        with pytest.raises(https_fn.HttpsError) as missing_product:
            admin_approve_product(_req("admin_1", {Fields.PRODUCT_ID: "p1"}))
        assert missing_product.value.code == "not-found"

    @patch("handlers.products.create_success_response", side_effect=lambda payload: payload)
    @patch("handlers.products._notify_premium_users_new_product")
    @patch("handlers.products._send_product_approval_email", side_effect=RuntimeError("mail down"))
    @patch("handlers.products._get_seller_email_and_lang", return_value=("seller@example.com", "en"))
    @patch("handlers.products.index_product")
    @patch("handlers.products.get_db")
    def test_admin_approve_product_swallows_approval_email_failure(
        self,
        mock_get_db,
        _mock_index,
        _mock_seller_info,
        _mock_send_email,
        _mock_notify,
        _mock_resp,
    ):
        from handlers.products import admin_approve_product

        user_doc = _snap({Fields.ROLES: [UserRoleValues.ADMIN]}, exists=True)
        product_doc = _snap(
            {
                Fields.NAME: "Digital Book",
                Fields.SELLER_ID: "seller_1",
                Fields.IS_DIGITAL: False,
            },
            exists=True,
            doc_id="p1",
        )
        fresh_doc = _snap(
            {
                Fields.NAME: "Digital Book",
                Fields.SELLER_ID: "seller_1",
                Fields.IS_DIGITAL: False,
            },
            exists=True,
            doc_id="p1",
        )

        product_ref = Mock()
        product_ref.get.side_effect = [product_doc, fresh_doc]
        products_col = Mock()
        products_col.document.return_value = product_ref
        users_col = Mock()
        users_col.document.return_value.get.return_value = user_doc

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
            Collections.ADMIN_LOGS: Mock(),
        }[name]
        mock_get_db.return_value = db

        out = admin_approve_product(_req("admin_1", {Fields.PRODUCT_ID: "p1"}))
        assert out == {}
        product_ref.update.assert_called_once()

    @patch("handlers.products.create_success_response", side_effect=lambda payload: payload)
    @patch("handlers.products._send_product_rejection_email", side_effect=RuntimeError("mail down"))
    @patch("handlers.products._get_seller_email_and_lang", return_value=("seller@example.com", "en"))
    @patch("handlers.products.get_db")
    def test_admin_reject_product_swallows_rejection_email_failure(
        self,
        mock_get_db,
        _mock_seller_info,
        _mock_send_email,
        _mock_resp,
    ):
        from handlers.products import admin_reject_product

        user_doc = _snap({Fields.ROLES: [UserRoleValues.ADMIN]}, exists=True)
        product_doc = _snap(
            {Fields.NAME: "Product", Fields.SELLER_ID: "seller_1"},
            exists=True,
            doc_id="p1",
        )
        product_ref = Mock()
        product_ref.get.return_value = product_doc
        products_col = Mock()
        products_col.document.return_value = product_ref
        users_col = Mock()
        users_col.document.return_value.get.return_value = user_doc

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
            Collections.ADMIN_LOGS: Mock(),
        }[name]
        mock_get_db.return_value = db

        out = admin_reject_product(_req("admin_1", {Fields.PRODUCT_ID: "p1", "reason": "policy"}))
        assert out == {}
        product_ref.update.assert_called_once()


class TestProductUpdatedAndDeletedResidual:
    @patch("handlers.products.CURRENT_ENV", Environment.PRODUCTION)
    @patch("handlers.products._get_seller_email_and_lang", return_value=(None, "en"))
    @patch("handlers.products.get_db")
    def test_on_product_created_rejects_missing_coordinates_in_production(
        self, mock_get_db, _mock_seller_info
    ):
        from handlers.products import on_product_created

        product_ref = Mock()
        products_col = Mock()
        products_col.document.return_value = product_ref

        users_col = Mock()
        users_col.document.return_value.get.return_value = _snap(exists=False)

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
        }[name]
        mock_get_db.return_value = db

        event = Mock()
        event.params = {Fields.PRODUCT_ID: "p1"}
        event.data = Mock()
        event.data.to_dict.return_value = {
            Fields.NAME: "Product A",
            Fields.PRICE: 12.0,
            Fields.STOCK_QUANTITY: 3,
            Fields.IS_DIGITAL: False,
            Fields.SELLER_ADDRESS: {
                Fields.COUNTRY: "CA",
                Fields.CITY: "Toronto",
                Fields.POSTAL_CODE: "M5V2T6",
                Fields.STREET: "1 Main",
            },
        }

        on_product_created(event)
        args = product_ref.update.call_args.args[0]
        assert "Address not verified via Geoapify" in args[Fields.DEACTIVATION_REASON]

    @patch("handlers.products._fire_price_drop_notifications", side_effect=RuntimeError("price-drop failed"))
    @patch("handlers.products._track_price_history", side_effect=RuntimeError("history failed"))
    @patch("handlers.products._fire_back_in_stock_notifications", side_effect=RuntimeError("stock failed"))
    @patch("handlers.products.index_product", side_effect=RuntimeError("index failed"))
    @patch("handlers.products.get_db")
    def test_on_product_updated_skip_validation_error_branches(
        self,
        mock_get_db,
        _mock_index,
        _mock_stock,
        _mock_history,
        _mock_price_drop,
    ):
        from handlers.products import on_product_updated

        product_ref = Mock()
        db = Mock()
        db.collection.return_value.document.return_value = product_ref
        mock_get_db.return_value = db

        before = {
            Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            Fields.DEACTIVATION_REASON: 10,
        }
        after = {
            Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            Fields.DEACTIVATION_REASON: 5,
        }
        event = _event("p_skip", before, after)

        # Force the price-drop block in the stock-only branch to execute.
        with patch.object(__import__("handlers.products", fromlist=["Fields"]).Fields, "PRICE", Fields.DEACTIVATION_REASON):
            on_product_updated(event)

    @patch("handlers.products.get_db")
    def test_on_product_updated_full_validation_suspended_seller_branch(self, mock_get_db):
        from handlers.products import on_product_updated

        product_ref = Mock()
        products_col = Mock()
        products_col.document.return_value = product_ref

        users_col = Mock()
        users_col.document.return_value.get.return_value = _snap({Fields.SUSPENDED: True}, exists=True)

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
        }[name]
        mock_get_db.return_value = db

        before = {Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE, Fields.NAME: "old"}
        after = {
            Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            Fields.NAME: "new",
            Fields.SELLER_ID: "seller_1",
            Fields.PRICE: 10.0,
            Fields.STOCK_QUANTITY: 1,
            Fields.IS_DIGITAL: True,
        }
        on_product_updated(_event("p_susp", before, after))
        args = product_ref.update.call_args.args[0]
        assert args[Fields.DEACTIVATION_REASON] == "Seller is suspended"

    @patch("handlers.products.get_db")
    def test_on_product_updated_full_validation_invalid_stock_branch(self, mock_get_db):
        from handlers.products import on_product_updated

        product_ref = Mock()
        products_col = Mock()
        products_col.document.return_value = product_ref

        db = Mock()
        db.collection.return_value = products_col
        mock_get_db.return_value = db

        before = {Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE, Fields.NAME: "old"}
        after = {
            Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            Fields.NAME: "new",
            Fields.PRICE: 10.0,
            Fields.STOCK_QUANTITY: -1,
            Fields.IS_DIGITAL: True,
        }
        on_product_updated(_event("p_stock", before, after))
        product_ref.update.assert_called_once_with({Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.PAUSED})

    @patch("handlers.products._cleanup_orphaned_variant_subscriptions", side_effect=RuntimeError("cleanup failed"))
    @patch("handlers.products._fire_back_in_stock_notifications", side_effect=RuntimeError("stock failed"))
    @patch("handlers.products._track_price_history", side_effect=RuntimeError("history failed"))
    @patch(
        "handlers.products._derive_ship_from_fields",
        return_value={
            Fields.SHIP_FROM_COUNTRY: "Canada",
            Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.PAUSED,
        },
    )
    @patch("handlers.products.get_db")
    def test_on_product_updated_ship_from_and_non_active_index_branch(
        self,
        mock_get_db,
        _mock_ship_from,
        _mock_history,
        _mock_stock,
        _mock_cleanup,
    ):
        from handlers.products import on_product_updated

        product_ref = Mock()
        products_col = Mock()
        products_col.document.return_value = product_ref
        users_col = Mock()
        users_col.document.return_value.get.return_value = _snap(exists=False)

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
        }[name]
        mock_get_db.return_value = db

        before = {
            Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.PAUSED,
            Fields.WAREHOUSE_IDS: ["w1"],
            Fields.NAME: "A",
        }
        after = {
            Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            Fields.WAREHOUSE_IDS: ["w2"],
            Fields.SELLER_ID: "seller_1",
            Fields.NAME: "B",
            Fields.PRICE: 10.0,
            Fields.STOCK_QUANTITY: 2,
            Fields.IS_DIGITAL: True,
        }
        on_product_updated(_event("p_ship", before, after))
        assert product_ref.update.called

    @patch("handlers.products.get_db")
    @patch("handlers.products.algolia_delete_product")
    def test_on_product_deleted_favorites_empty_loop_break(self, _mock_algolia, mock_get_db):
        from handlers.products import on_product_deleted

        stock_q = Mock()
        stock_q.where.return_value = stock_q
        stock_q.limit.return_value = stock_q
        stock_q.stream.side_effect = [[]]
        stock_col = Mock()
        stock_col.where.return_value = stock_q

        fav_q = Mock()
        fav_q.where.return_value = fav_q
        fav_q.limit.return_value = fav_q
        fav_q.stream.return_value = []

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.STOCK_NOTIFICATIONS: stock_col
        }.get(name, Mock())
        db.collection_group.return_value = fav_q
        mock_get_db.return_value = db

        event = Mock()
        event.params = {Fields.PRODUCT_ID: "p_deleted"}
        on_product_deleted(event)


class TestCatalogAndWarehouseResidual:
    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_get_products_paginated_auth_rate_limit_block(self, mock_get_db, mock_rl):
        from handlers.products import get_products_paginated

        mock_get_db.return_value = Mock()
        mock_rl.return_value.check_rate_limit.return_value = (False, "too many")
        with pytest.raises(https_fn.HttpsError) as exc:
            get_products_paginated(_req("u1", {"orderBy": Fields.CREATED_AT, "orderDirection": "desc"}))
        assert exc.value.code == "resource-exhausted"

    @patch("handlers.products.create_success_response", side_effect=lambda payload: payload)
    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_get_products_paginated_admin_filters_and_ascending_sort(
        self, mock_get_db, mock_rl, _mock_resp
    ):
        from handlers.products import get_products_paginated

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        admin_doc = _snap({Fields.ROLES: [UserRoleValues.ADMIN]}, exists=True)

        query = Mock()
        query.where.return_value = query
        query.order_by.return_value = query
        query.start_after.return_value = query
        query.limit.return_value = query
        query.stream.return_value = []

        products_col = Mock()
        products_col.where.return_value = query
        users_col = Mock()
        users_col.document.return_value.get.return_value = admin_doc

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
        }[name]
        mock_get_db.return_value = db

        out = get_products_paginated(
            _req(
                "admin_1",
                {
                    "limit": 5,
                    "orderBy": Fields.CREATED_AT,
                    "orderDirection": "asc",
                    Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.PAUSED,
                    "category": 2,
                    Fields.SUBCATEGORY: "fruit",
                    Fields.SELLER_ID: "seller_9",
                },
            )
        )
        assert out["products"] == []
        query.order_by.assert_called_with(Fields.CREATED_AT, direction="ASCENDING")

    @patch("handlers.products.create_success_response", side_effect=lambda payload: payload)
    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_get_seller_products_paginated_defaults_and_cursor_branches(
        self, mock_get_db, mock_rl, _mock_resp
    ):
        from handlers.products import get_seller_products_paginated

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        start_doc = _snap({}, exists=True, doc_id="cursor_1")
        doc = _snap({Fields.NAME: "P1"}, doc_id="p1")

        query = Mock()
        query.where.return_value = query
        query.order_by.return_value = query
        query.start_after.return_value = query
        query.limit.return_value = query
        query.stream.return_value = [doc]

        products_col = Mock()
        products_col.where.return_value = query
        products_col.document.return_value.get.return_value = start_doc

        db = Mock()
        db.collection.return_value = products_col
        mock_get_db.return_value = db

        out = get_seller_products_paginated(_req("seller_1", {"startAfter": "cursor_1"}))
        assert out["totalFetched"] == 1
        assert query.start_after.called

    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_get_product_ratings_paginated_rate_limit_and_cursor(self, mock_get_db, mock_rl):
        from handlers.products import get_product_ratings_paginated

        mock_get_db.return_value = Mock()
        mock_rl.return_value.check_rate_limit.return_value = (False, "slow down")
        with pytest.raises(https_fn.HttpsError) as exc:
            get_product_ratings_paginated(_req("u1", {Fields.PRODUCT_ID: "p1"}))
        assert exc.value.code == "resource-exhausted"

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        start_doc = _snap({}, exists=True, doc_id="r_cursor")
        rating_doc = _snap({Fields.PRODUCT_ID: "p1", Fields.USER_ID: "u2"}, doc_id="r1")
        query = Mock()
        query.where.return_value = query
        query.order_by.return_value = query
        query.start_after.return_value = query
        query.limit.return_value = query
        query.stream.return_value = [rating_doc]
        ratings_col = Mock()
        ratings_col.where.return_value = query
        ratings_col.document.return_value.get.return_value = start_doc

        users_col = Mock()
        users_col.document.side_effect = lambda uid: Mock(id=uid)
        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.PRODUCT_RATINGS: ratings_col,
            Collections.USERS: users_col,
        }[name]
        db.get_all.return_value = [_snap({Fields.NAME: "Alice Doe"}, doc_id="u2")]
        mock_get_db.return_value = db

        out = get_product_ratings_paginated(
            _req("u1", {Fields.PRODUCT_ID: "p1", "startAfter": "r_cursor"})
        )
        assert out[Fields.RATINGS][0]["userName"] == "Alice"
        assert query.start_after.called

    @patch("handlers.products.get_db")
    def test_admin_update_warehouse_commission_guard_matrix(self, mock_get_db):
        from handlers.products import admin_update_warehouse_commission

        with pytest.raises(https_fn.HttpsError) as unauth:
            admin_update_warehouse_commission(_req(None, {}))
        assert unauth.value.code == "unauthenticated"

        users_col = Mock()
        db = Mock()
        db.collection.return_value = users_col
        mock_get_db.return_value = db

        users_col.document.return_value.get.return_value = _snap(exists=False)
        with pytest.raises(https_fn.HttpsError) as denied:
            admin_update_warehouse_commission(_req("u1", {}))
        assert denied.value.code == "permission-denied"

        users_col.document.return_value.get.return_value = _snap(
            {Fields.ROLES: [UserRoleValues.ADMIN]}, exists=True
        )
        with pytest.raises(https_fn.HttpsError) as missing_fields:
            admin_update_warehouse_commission(_req("u1", {}))
        assert missing_fields.value.code == "invalid-argument"

        with pytest.raises(https_fn.HttpsError) as bad_rate:
            admin_update_warehouse_commission(
                _req(
                    "u1",
                    {
                        Fields.SELLER_ID: "seller_1",
                        "warehouseId": "wh_1",
                        Fields.COMMISSION_RATE_BPS: 12001,
                    },
                )
            )
        assert bad_rate.value.code == "invalid-argument"

        seller_ref = Mock()
        wh_col = Mock()
        wh_ref = Mock()
        wh_ref.get.return_value = _snap(exists=False)
        wh_col.document.return_value = wh_ref
        seller_ref.collection.return_value = wh_col
        users_col.document.side_effect = lambda uid: users_col.document.return_value if uid == "u1" else seller_ref
        with pytest.raises(https_fn.HttpsError) as missing_wh:
            admin_update_warehouse_commission(
                _req(
                    "u1",
                    {
                        Fields.SELLER_ID: "seller_1",
                        "warehouseId": "wh_1",
                        Fields.COMMISSION_RATE_BPS: 1000,
                    },
                )
            )
        assert missing_wh.value.code == "not-found"

    @patch("firebase_admin.firestore.transactional", side_effect=lambda fn: fn)
    @patch("handlers.products.create_success_response", side_effect=lambda payload: payload)
    @patch("handlers.products._validate_warehouse_address")
    @patch("handlers.products._geocode_warehouse_address", side_effect=lambda a: a)
    @patch("handlers.products.get_db")
    def test_update_warehouse_label_type_and_sync_continue_break(
        self,
        mock_get_db,
        _mock_geocode,
        _mock_validate,
        _mock_resp,
        _mock_txn,
    ):
        from handlers.products import update_warehouse

        wh_ref = Mock()
        wh_ref.get.return_value = _snap({"label": "Old"}, exists=True)
        wh_col = Mock()
        wh_col.document.return_value = wh_ref
        wh_col.where.return_value.stream.return_value = []

        seller_ref = Mock()
        seller_ref.collection.return_value = wh_col
        users_col = Mock()
        users_col.document.return_value = seller_ref

        pdoc_no_wh = [
            _snap({Fields.IS_DIGITAL: False, Fields.WAREHOUSE_IDS: []}, doc_id=f"p{i}")
            for i in range(200)
        ]
        prod_query = Mock()
        prod_query.where.return_value = prod_query
        prod_query.limit.return_value.get.side_effect = [pdoc_no_wh, []]
        products_col = Mock()
        products_col.where.return_value = prod_query

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
        }[name]
        db.transaction.return_value = Mock()
        db.batch.return_value = Mock()
        mock_get_db.return_value = db

        out = update_warehouse(
            _req(
                "seller_1",
                {
                    "warehouseId": "wh_1",
                    "label": "New Label",
                    "type": WarehouseTypeValues.PERSONAL,
                    "isDefault": True,
                },
            )
        )
        assert out["warehouseId"] == "wh_1"

    @patch("handlers.products.get_db")
    def test_delete_warehouse_guard_and_internal_paths(self, mock_get_db):
        from handlers.products import delete_warehouse

        with pytest.raises(https_fn.HttpsError) as unauth:
            delete_warehouse(_req(None, {"warehouseId": "wh_1"}))
        assert unauth.value.code == "unauthenticated"

        with pytest.raises(https_fn.HttpsError) as missing_id:
            delete_warehouse(_req("seller_1", {}))
        assert missing_id.value.code == "invalid-argument"

        wh_ref = Mock()
        wh_ref.get.return_value = _snap(exists=False)
        wh_col = Mock()
        wh_col.document.return_value = wh_ref
        users_col = Mock()
        users_col.document.return_value.collection.return_value = wh_col
        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: Mock(),
            Collections.ORDERS: Mock(),
        }[name]
        mock_get_db.return_value = db

        with pytest.raises(https_fn.HttpsError) as not_found:
            delete_warehouse(_req("seller_1", {"warehouseId": "wh_1"}))
        assert not_found.value.code == "not-found"

        mock_get_db.return_value = Mock()
        mock_get_db.return_value.collection.side_effect = RuntimeError("db crash")
        with pytest.raises(https_fn.HttpsError) as internal:
            delete_warehouse(_req("seller_1", {"warehouseId": "wh_1"}))
        assert internal.value.code == "internal"

    @patch("handlers.products.create_success_response", side_effect=lambda payload: payload)
    @patch("handlers.products._derive_ship_from_fields", return_value={Fields.SHIP_FROM_COUNTRY: "Canada"})
    @patch("handlers.products.get_db")
    def test_delete_warehouse_ship_from_patch_update(self, mock_get_db, _mock_ship_from, _mock_resp):
        from handlers.products import delete_warehouse

        wh_ref = Mock()
        wh_ref.get.return_value = _snap({Fields.IS_DEFAULT: False}, exists=True)
        wh_col = Mock()
        wh_col.document.return_value = wh_ref
        users_col = Mock()
        users_col.document.return_value.collection.return_value = wh_col

        pdoc = _snap(
            {
                Fields.NAME: "P1",
                Fields.WAREHOUSE_IDS: ["wh_1"],
                Fields.WAREHOUSE_STOCK: {},
            },
            doc_id="p1",
        )
        products_query = Mock()
        products_query.where.return_value = products_query
        products_query.stream.return_value = []
        products_query.limit.return_value = products_query
        products_query.get.side_effect = [[pdoc], []]
        p_ref = Mock()
        products_col = Mock()
        products_col.where.return_value = products_query
        products_col.document.return_value = p_ref

        orders_query = Mock()
        orders_query.where.return_value = orders_query
        orders_query.limit.return_value = orders_query
        orders_query.get.return_value = []
        orders_col = Mock()
        orders_col.where.return_value = orders_query

        batch = Mock()
        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
            Collections.ORDERS: orders_col,
        }[name]
        db.batch.return_value = batch
        mock_get_db.return_value = db

        out = delete_warehouse(_req("seller_1", {"warehouseId": "wh_1"}))
        assert out["warehouseId"] == "wh_1"
        assert batch.update.called

    @patch("handlers.products.get_db")
    def test_get_seller_warehouses_unauth_and_internal(self, mock_get_db):
        from handlers.products import get_seller_warehouses

        with pytest.raises(https_fn.HttpsError) as unauth:
            get_seller_warehouses(_req(None, {}))
        assert unauth.value.code == "unauthenticated"

        db = Mock()
        db.collection.return_value.document.return_value.collection.return_value.order_by.side_effect = RuntimeError(
            "read failed"
        )
        mock_get_db.return_value = db
        with pytest.raises(https_fn.HttpsError) as internal:
            get_seller_warehouses(_req("seller_1", {}))
        assert internal.value.code == "internal"


class TestSubscriptionQaReviewAndBulkResidual:
    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_subscribe_stock_notification_stock_user_and_variant_query_branches(self, mock_get_db, mock_rl):
        from handlers.products import subscribe_stock_notification

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        products_col = Mock()
        users_col = Mock()
        stock_col = Mock()

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.PRODUCTS: products_col,
            Collections.USERS: users_col,
            Collections.STOCK_NOTIFICATIONS: stock_col,
        }[name]
        mock_get_db.return_value = db

        products_col.document.return_value.get.return_value = _snap(
            {Fields.SELLER_ID: "seller_1", Fields.HAS_VARIANTS: False, Fields.STOCK_QUANTITY: 3},
            exists=True,
        )
        with pytest.raises(https_fn.HttpsError) as in_stock:
            subscribe_stock_notification(_req("buyer_1", {Fields.PRODUCT_ID: "p1"}))
        assert in_stock.value.code == "failed-precondition"

        products_col.document.return_value.get.return_value = _snap(
            {
                Fields.SELLER_ID: "seller_1",
                Fields.HAS_VARIANTS: False,
                Fields.STOCK_QUANTITY: 0,
            },
            exists=True,
        )
        users_col.document.return_value.get.return_value = _snap(exists=False)
        with pytest.raises(https_fn.HttpsError) as missing_user:
            subscribe_stock_notification(_req("buyer_1", {Fields.PRODUCT_ID: "p1"}))
        assert missing_user.value.code == "not-found"

        products_col.document.return_value.get.return_value = _snap(
            {
                Fields.SELLER_ID: "seller_1",
                Fields.HAS_VARIANTS: True,
                Fields.VARIANTS: [{Fields.VARIANT_ID: "v1", Fields.STOCK_QUANTITY: 0}],
            },
            exists=True,
        )
        users_col.document.return_value.get.return_value = _snap({Fields.EMAIL: "buyer@example.com"}, exists=True)

        existing_q = Mock()
        existing_q.where.return_value = existing_q
        existing_q.limit.return_value = existing_q
        existing_q.stream.return_value = [_snap({}, exists=True)]
        stock_col.where.return_value = existing_q

        out = subscribe_stock_notification(
            _req("buyer_1", {Fields.PRODUCT_ID: "p1", Fields.VARIANT_KEY: "v1"})
        )
        assert out["subscribed"] is True

    @patch("handlers.products.get_db")
    @patch("handlers.products.RateLimiter")
    def test_unsubscribe_stock_notification_unauth_and_limited(self, mock_rl, mock_get_db):
        from handlers.products import unsubscribe_stock_notification

        with pytest.raises(https_fn.HttpsError) as unauth:
            unsubscribe_stock_notification(_req(None, {Fields.PRODUCT_ID: "p1"}))
        assert unauth.value.code == "unauthenticated"

        mock_get_db.return_value = Mock()
        mock_rl.return_value.check_rate_limit.return_value = (False, "slow down")
        with pytest.raises(https_fn.HttpsError) as limited:
            unsubscribe_stock_notification(_req("u1", {Fields.PRODUCT_ID: "p1"}))
        assert limited.value.code == "resource-exhausted"

    @patch("handlers.products.create_success_response", side_effect=lambda payload: payload)
    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_unsubscribe_stock_notification_non_variant_filter_path(
        self, mock_get_db, mock_rl, _mock_resp
    ):
        from handlers.products import unsubscribe_stock_notification

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        sub = _snap({}, exists=True)
        q = Mock()
        q.where.return_value = q
        q.limit.return_value = q
        q.stream.return_value = [sub]
        stock_col = Mock()
        stock_col.where.return_value = q
        db = Mock()
        db.collection.return_value = stock_col
        mock_get_db.return_value = db

        out = unsubscribe_stock_notification(_req("u1", {Fields.PRODUCT_ID: "p1"}))
        assert out["unsubscribed"] is True
        sub.reference.delete.assert_called_once()

    @patch("handlers.products.create_success_response", side_effect=lambda payload: payload)
    @patch("services.email_task.enqueue_email_task", side_effect=RuntimeError("email fail"))
    @patch("utils.helpers.sanitized_text", side_effect=lambda s: s)
    @patch("handlers.products.RateLimiter")
    @patch("utils.premium_check.is_premium_authoritative", return_value=True)
    @patch("handlers.products.get_db")
    def test_ask_question_email_exception_branch(
        self,
        mock_get_db,
        _mock_premium,
        mock_rl,
        _mock_sanitize,
        _mock_enqueue,
        _mock_resp,
    ):
        from handlers.products import ask_product_question

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        question_ref = Mock()
        question_ref.id = "q1"
        product_doc = _snap(
            {Fields.SELLER_ID: "seller_1", Fields.NAME: "Product A"},
            exists=True,
        )
        seller_doc = _snap({Fields.EMAIL: "seller@example.com"}, exists=True)

        def _doc_for_users(uid):
            ref = Mock()
            ref.get.return_value = seller_doc if uid == "seller_1" else _snap(exists=False)
            return ref

        products_col = Mock()
        products_col.document.return_value.get.return_value = product_doc
        users_col = Mock()
        users_col.document.side_effect = _doc_for_users
        questions_col = Mock()
        questions_col.document.return_value = question_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.PRODUCTS: products_col,
            Collections.USERS: users_col,
            Collections.PRODUCT_QUESTIONS: questions_col,
        }[name]
        mock_get_db.return_value = db

        out = ask_product_question(
            _req("buyer_1", {Fields.PRODUCT_ID: "p1", Fields.QUESTION_TEXT: "Is this available tomorrow?"})
        )
        assert out[Fields.QUESTION_ID] == "q1"
        question_ref.set.assert_called_once()

    @patch("handlers.products.create_success_response", side_effect=lambda payload: payload)
    @patch("services.email_task.enqueue_email_task", side_effect=RuntimeError("email fail"))
    @patch("utils.helpers.sanitized_text", side_effect=lambda s: s)
    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_answer_question_email_exception_branch(
        self, mock_get_db, mock_rl, _mock_sanitize, _mock_enqueue, _mock_resp
    ):
        from handlers.products import answer_product_question

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        question_ref = Mock()
        question_ref.get.return_value = _snap(
            {
                Fields.SELLER_ID: "seller_1",
                Fields.ASKER_ID: "buyer_1",
                Fields.PRODUCT_ID: "p1",
                Fields.QUESTION_TEXT: "Question?",
            },
            exists=True,
        )
        questions_col = Mock()
        questions_col.document.return_value = question_ref

        users_col = Mock()
        users_col.document.return_value.get.return_value = _snap({Fields.EMAIL: "buyer@example.com"}, exists=True)
        products_col = Mock()
        products_col.document.return_value.get.return_value = _snap({Fields.NAME: "Product A"}, exists=True)

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.PRODUCT_QUESTIONS: questions_col,
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
        }[name]
        mock_get_db.return_value = db

        out = answer_product_question(
            _req("seller_1", {Fields.QUESTION_ID: "q1", Fields.ANSWER_TEXT: "This is available now."})
        )
        assert out["answered"] is True
        question_ref.update.assert_called_once()

    @patch("handlers.products.get_db")
    def test_admin_delete_product_rating_fallback_admin_guard(self, mock_get_db):
        from handlers.products import admin_delete_product_rating

        users_col = Mock()
        users_col.document.return_value.get.return_value = _snap({Fields.ROLES: []}, exists=True)
        db = Mock()
        db.collection.side_effect = lambda name: users_col if name == Collections.USERS else Mock()
        mock_get_db.return_value = db

        with pytest.raises(https_fn.HttpsError) as exc:
            admin_delete_product_rating(_req("u1", {"ratingId": "r1"}))
        assert exc.value.code == "permission-denied"

    @patch("handlers.products.create_success_response", side_effect=lambda payload: payload)
    @patch("handlers.products.get_firestore")
    @patch("handlers.products.get_db")
    def test_admin_delete_product_rating_product_missing_and_single_count_branches(
        self, mock_get_db, mock_get_firestore, _mock_resp
    ):
        from handlers.products import admin_delete_product_rating

        mock_get_firestore.return_value.transactional = lambda fn: fn
        tx = Mock()

        rating_ref = Mock()
        rating_ref.get.return_value = _snap(
            {Fields.PRODUCT_ID: "p1", Fields.RATING: 4},
            exists=True,
        )
        ratings_col = Mock()
        ratings_col.document.return_value = rating_ref

        product_ref = Mock()
        product_ref.get.return_value = _snap(exists=False)
        products_col = Mock()
        products_col.document.return_value = product_ref

        audit_col = Mock()
        audit_col.document.return_value = Mock()

        db = Mock()
        db.transaction.return_value = tx
        db.collection.side_effect = lambda name: {
            Collections.PRODUCT_RATINGS: ratings_col,
            Collections.PRODUCTS: products_col,
            "admin_audit_log": audit_col,
        }[name]
        mock_get_db.return_value = db

        out = admin_delete_product_rating(_req("admin_1", {"ratingId": "r1"}, token={"admin": True}))
        assert out["success"] is True

        # Count<=1 branch -> zeroed metrics
        product_ref.get.return_value = _snap(
            {Fields.RATING: 4.0, Fields.RATING_COUNT: 1},
            exists=True,
        )
        out2 = admin_delete_product_rating(_req("admin_1", {"ratingId": "r1"}, token={"admin": True}))
        assert out2["success"] is True
        assert tx.update.call_args_list[-1].args[1][Fields.RATING_COUNT] == 0

    @patch("utils.helpers.sanitized_text", side_effect=lambda s: s)
    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_answer_review_remaining_guard_paths(self, mock_get_db, mock_rl, _mock_sanitize):
        from handlers.products import answer_review

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        with pytest.raises(https_fn.HttpsError) as empty_reply:
            answer_review(_req("seller_1", {Fields.RATING_ID: "r1", Fields.PRODUCT_ID: "p1", Fields.SELLER_REPLY: "  "}))
        assert empty_reply.value.code == "invalid-argument"

        with patch("utils.helpers.sanitized_text", return_value=""):
            with pytest.raises(https_fn.HttpsError) as sanitized_empty:
                answer_review(_req("seller_1", {Fields.RATING_ID: "r1", Fields.PRODUCT_ID: "p1", Fields.SELLER_REPLY: "x"}))
            assert sanitized_empty.value.code == "invalid-argument"

        products_col = Mock()
        products_col.document.return_value.get.return_value = _snap(exists=False)
        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.PRODUCTS: products_col,
            Collections.PRODUCT_RATINGS: Mock(),
        }.get(name, Mock())
        mock_get_db.return_value = db
        with pytest.raises(https_fn.HttpsError) as missing_product:
            answer_review(_req("seller_1", {Fields.RATING_ID: "r1", Fields.PRODUCT_ID: "p1", Fields.SELLER_REPLY: "reply"}))
        assert missing_product.value.code == "not-found"

        products_col.document.return_value.get.return_value = _snap({Fields.SELLER_ID: "other_seller"}, exists=True)
        with pytest.raises(https_fn.HttpsError) as denied:
            answer_review(_req("seller_1", {Fields.RATING_ID: "r1", Fields.PRODUCT_ID: "p1", Fields.SELLER_REPLY: "reply"}))
        assert denied.value.code == "permission-denied"

        products_col.document.return_value.get.return_value = _snap({Fields.SELLER_ID: "seller_1"}, exists=True)
        ratings_col = Mock()
        rating_ref = Mock()
        rating_ref.get.return_value = _snap(exists=False)
        ratings_col.document.return_value = rating_ref
        db.collection.side_effect = lambda name: {
            Collections.PRODUCTS: products_col,
            Collections.PRODUCT_RATINGS: ratings_col,
        }[name]
        with pytest.raises(https_fn.HttpsError) as missing_rating:
            answer_review(_req("seller_1", {Fields.RATING_ID: "r1", Fields.PRODUCT_ID: "p1", Fields.SELLER_REPLY: "reply"}))
        assert missing_rating.value.code == "not-found"

        rating_ref.get.return_value = _snap({Fields.PRODUCT_ID: "other"}, exists=True)
        with pytest.raises(https_fn.HttpsError) as mismatch:
            answer_review(_req("seller_1", {Fields.RATING_ID: "r1", Fields.PRODUCT_ID: "p1", Fields.SELLER_REPLY: "reply"}))
        assert mismatch.value.code == "invalid-argument"

        rating_ref.get.return_value = _snap(
            {
                Fields.PRODUCT_ID: "p1",
                Fields.SELLER_REPLY: "old",
                Fields.SELLER_REPLY_AT: None,
            },
            exists=True,
        )
        with pytest.raises(https_fn.HttpsError) as already:
            answer_review(_req("seller_1", {Fields.RATING_ID: "r1", Fields.PRODUCT_ID: "p1", Fields.SELLER_REPLY: "reply"}))
        assert already.value.code == "already-exists"

    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_answer_review_sanitized_reply_len_over_500_branch(self, mock_get_db, mock_rl):
        from handlers.products import answer_review

        class _OversizedSanitized:
            def __getitem__(self, _item):
                return self

            def __len__(self):
                return 501

        mock_get_db.return_value = Mock()
        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        with patch("utils.helpers.sanitized_text", return_value=_OversizedSanitized()):
            with pytest.raises(https_fn.HttpsError) as exc:
                answer_review(
                    _req(
                        "seller_1",
                        {
                            Fields.RATING_ID: "r1",
                            Fields.PRODUCT_ID: "p1",
                            Fields.SELLER_REPLY: "valid reply input",
                        },
                    )
                )
        assert exc.value.code == "invalid-argument"

    @patch("handlers.products.create_success_response", side_effect=lambda payload: payload)
    @patch("handlers.products.get_db")
    def test_vote_review_helpful_remove_vote_success_path(self, mock_get_db, _mock_resp):
        from handlers.products import vote_review_helpful

        tx = Mock()

        rating_ref = Mock()
        vote_ref = Mock()
        rating_ref.collection.return_value.document.return_value = vote_ref
        rating_ref.get.return_value = _snap(
            {
                Fields.PRODUCT_ID: "p1",
                Fields.USER_ID: "reviewer_1",
                Fields.HELPFUL_COUNT: 1,
            },
            exists=True,
        )
        vote_ref.get.return_value = _snap(exists=True)

        ratings_col = Mock()
        ratings_col.document.return_value = rating_ref

        products_col = Mock()
        products_col.document.return_value.get.return_value = _snap({Fields.SELLER_ID: "seller_1"}, exists=True)

        db = Mock()
        db.transaction.return_value = tx
        db.collection.side_effect = lambda name: {
            Collections.PRODUCT_RATINGS: ratings_col,
            Collections.PRODUCTS: products_col,
        }[name]
        mock_get_db.return_value = db

        with patch("firebase_admin.firestore.transactional", side_effect=lambda fn: fn):
            out = vote_review_helpful(
                _req("u1", {Fields.RATING_ID: "r1", Fields.PRODUCT_ID: "p1", "helpful": False})
            )
        assert out["helpfulCount"] == 0
        tx.delete.assert_called_once_with(vote_ref)

    @patch("handlers.products.create_success_response", side_effect=lambda payload: payload)
    @patch("handlers.products.get_db")
    def test_bulk_update_products_archive_favorites_cleanup_exception_branch(self, mock_get_db, _mock_resp):
        from handlers.products import bulk_update_products

        product_snap = _snap(
            {Fields.SELLER_ID: "seller_1", Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE},
            exists=True,
            doc_id="p1",
        )
        product_ref = Mock()
        products_col = Mock()
        products_col.document.return_value = product_ref

        fav_q = Mock()
        fav_q.where.return_value = fav_q
        fav_q.limit.return_value = fav_q
        fav_q.stream.side_effect = RuntimeError("favorites down")

        db = Mock()
        db.collection.return_value = products_col
        db.get_all.return_value = [product_snap]
        db.batch.return_value = Mock()
        db.collection_group.return_value = fav_q
        mock_get_db.return_value = db

        out = bulk_update_products(
            _req("seller_1", {"productIds": ["p1"], Fields.ACTION: "archive"})
        )
        assert out["updated"] == 1
