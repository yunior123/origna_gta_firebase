import base64
import importlib
import sys
from unittest.mock import Mock, patch

import pytest
from firebase_functions import https_fn
from google.api_core.exceptions import AlreadyExists
from pydantic import BaseModel, ValidationError

from config import Environment
from schema_constants import (
    BusinessRules,
    Collections,
    Fields,
    ProductLifecycleStatusValues,
    UserRoleValues,
)


def _snap(data=None, *, exists=True, doc_id=None):
    snap = Mock()
    snap.exists = exists
    snap.to_dict.return_value = {} if data is None else data
    snap.id = doc_id or "doc_1"
    snap.reference = Mock()
    return snap


def _req(uid: str, data: dict):
    req = Mock()
    req.auth = Mock(uid=uid)
    req.data = data
    return req


def _decorator_passthrough(*args, **kwargs):
    if len(args) == 1 and callable(args[0]) and not kwargs:
        return args[0]

    def _decorator(func):
        return func

    return _decorator


@pytest.fixture(autouse=True)
def _reload_products_module_with_firestore_passthrough():
    ff = sys.modules["firebase_functions"]
    if not hasattr(ff, "firestore_fn"):
        ff.firestore_fn = Mock()
    ff.firestore_fn.on_document_created = _decorator_passthrough
    ff.firestore_fn.on_document_updated = _decorator_passthrough
    ff.firestore_fn.on_document_deleted = _decorator_passthrough

    import handlers.products as products

    importlib.reload(products)
    yield


class _FakeProductCreate:
    def __init__(self, **kwargs):
        self._payload = dict(kwargs)

    def model_dump(self, exclude_none=True):
        return dict(self._payload)


class TestCreateProductAtomicDeep:
    def _base_product_payload(self):
        return {
            Fields.NAME: "Fresh Apples",
            Fields.DESCRIPTION: "Ontario apples",
            Fields.PRICE: 12.99,
            Fields.CATEGORY_ID: 1,
            Fields.STOCK_QUANTITY: 5,
            Fields.IS_DIGITAL: False,
            Fields.SELLER_ADDRESS: {
                Fields.STREET: "1 Main St",
                Fields.CITY: "Toronto",
                Fields.STATE: "ON",
                Fields.POSTAL_CODE: "M5V2T6",
                Fields.COUNTRY: "Canada",
            },
        }

    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_create_product_atomic_auth_role_and_rate_limit_guards(self, mock_get_db, mock_rl_cls):
        from handlers.products import create_product_atomic

        req = Mock()
        req.auth = None
        req.data = {}
        with pytest.raises(https_fn.HttpsError) as unauth:
            create_product_atomic(req)
        assert unauth.value.code == "unauthenticated"

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "")
        users_col = Mock()
        profiles_col = Mock()
        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.SELLER_PROFILES: profiles_col,
        }.get(name, Mock())
        mock_get_db.return_value = db

        req = _req("seller_1", {"productData": {}, "images": []})
        users_col.document.return_value.get.return_value = _snap(exists=False)
        with pytest.raises(https_fn.HttpsError) as missing_user:
            create_product_atomic(req)
        assert missing_user.value.code == "not-found"

        users_col.document.return_value.get.return_value = _snap({Fields.SUSPENDED: True, Fields.ROLES: [UserRoleValues.SELLER]})
        with pytest.raises(https_fn.HttpsError) as suspended:
            create_product_atomic(req)
        assert suspended.value.code == "permission-denied"

        users_col.document.return_value.get.return_value = _snap({Fields.SUSPENDED: False, Fields.ROLES: ["buyer"]})
        with pytest.raises(https_fn.HttpsError) as role_denied:
            create_product_atomic(req)
        assert role_denied.value.code == "permission-denied"

        users_col.document.return_value.get.return_value = _snap({Fields.SUSPENDED: False, Fields.ROLES: [UserRoleValues.SELLER]})
        profiles_col.document.return_value.get.return_value = _snap({Fields.ONBOARDING_COMPLETED: False})
        with pytest.raises(https_fn.HttpsError) as onboarding:
            create_product_atomic(req)
        assert onboarding.value.code == "failed-precondition"

        profiles_col.document.return_value.get.return_value = _snap({Fields.ONBOARDING_COMPLETED: True})
        mock_rl_cls.return_value.check_rate_limit.return_value = (False, "too many")
        with pytest.raises(https_fn.HttpsError) as limited:
            create_product_atomic(req)
        assert limited.value.code == "resource-exhausted"

    @patch("handlers.products.CURRENT_ENV", Environment.EMULATOR)
    @patch("handlers.products._derive_ship_from_fields", return_value={})
    @patch("handlers.products.ProductCreate", _FakeProductCreate)
    @patch("handlers.products.get_server_timestamp", return_value="ts")
    @patch("utils.helpers.geocode_address")
    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_create_product_atomic_payload_and_image_validation_guards(
        self,
        mock_get_db,
        mock_rl_cls,
        mock_geocode,
        _mock_ts,
        _mock_ship_from,
    ):
        from handlers.products import create_product_atomic

        mock_geocode.return_value = (
            True,
            "",
            {
                Fields.STREET: "1 Main St",
                Fields.CITY: "Toronto",
                Fields.STATE: "ON",
                Fields.POSTAL_CODE: "M5V2T6",
                Fields.COUNTRY: "Canada",
                Fields.LATITUDE: 43.65,
                Fields.LONGITUDE: -79.38,
                "apartment": "",
            },
        )
        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "")

        user_doc = _snap({Fields.ROLES: [UserRoleValues.SELLER], Fields.SUSPENDED: False})
        profile_doc = _snap({Fields.ONBOARDING_COMPLETED: True})
        users_col = Mock()
        users_col.document.return_value.get.return_value = user_doc
        profiles_col = Mock()
        profiles_col.document.return_value.get.return_value = profile_doc
        products_col = Mock()
        products_col.document.return_value = Mock(id="prod_x")

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.SELLER_PROFILES: profiles_col,
            Collections.PRODUCTS: products_col,
            Collections.SELLER_SKUS: Mock(),
        }.get(name, Mock())
        mock_get_db.return_value = db

        with pytest.raises(https_fn.HttpsError) as missing_payload:
            create_product_atomic(_req("seller_1", {"images": []}))
        assert missing_payload.value.code == "invalid-argument"

        with pytest.raises(https_fn.HttpsError) as images_not_list:
            create_product_atomic(_req("seller_1", {"productData": self._base_product_payload(), "images": "not-list"}))
        assert images_not_list.value.code == "invalid-argument"

        too_many = [{"data": "AA==", "contentType": "image/png"}] * (BusinessRules.MAX_PRODUCT_IMAGES + 1)
        with pytest.raises(https_fn.HttpsError) as max_images:
            create_product_atomic(_req("seller_1", {"productData": self._base_product_payload(), "images": too_many}))
        assert max_images.value.code == "invalid-argument"

        with pytest.raises(https_fn.HttpsError) as bad_mime:
            create_product_atomic(
                _req(
                    "seller_1",
                    {
                        "productData": self._base_product_payload(),
                        "images": [{"data": "AA==", "contentType": "application/pdf"}],
                    },
                )
            )
        assert bad_mime.value.code == "invalid-argument"

        with pytest.raises(https_fn.HttpsError) as bad_b64:
            create_product_atomic(
                _req(
                    "seller_1",
                    {
                        "productData": self._base_product_payload(),
                        "images": [{"data": "@@@@", "contentType": "image/png"}],
                    },
                )
            )
        assert bad_b64.value.code == "invalid-argument"

        with pytest.raises(https_fn.HttpsError) as empty_data:
            create_product_atomic(
                _req(
                    "seller_1",
                    {
                        "productData": self._base_product_payload(),
                        "images": [{"data": "", "contentType": "image/png"}],
                    },
                )
            )
        assert empty_data.value.code == "invalid-argument"

        with pytest.raises(https_fn.HttpsError) as bad_magic:
            create_product_atomic(
                _req(
                    "seller_1",
                    {
                        "productData": self._base_product_payload(),
                        "images": [{"data": "bm90LWltYWdl", "contentType": "image/png"}],  # "not-image"
                    },
                )
            )
        assert bad_magic.value.code == "invalid-argument"

        with pytest.raises(https_fn.HttpsError) as no_images:
            create_product_atomic(_req("seller_1", {"productData": self._base_product_payload(), "images": []}))
        assert no_images.value.code == "invalid-argument"

    @patch("handlers.products.create_success_response", side_effect=lambda payload: {"success": True, **payload})
    @patch("handlers.products._derive_ship_from_fields", return_value={Fields.SHIP_FROM_COUNTRY: "Canada"})
    @patch("handlers.products.ProductCreate", _FakeProductCreate)
    @patch("handlers.products.get_server_timestamp", return_value="ts")
    @patch("utils.helpers.geocode_address")
    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    @patch("handlers.products.CURRENT_ENV", Environment.EMULATOR)
    def test_create_product_atomic_success_with_test_image_urls(
        self,
        mock_get_db,
        mock_rl_cls,
        mock_geocode,
        _mock_ts,
        _mock_resp,
        _mock_ship_from,
    ):
        from handlers.products import create_product_atomic

        mock_geocode.return_value = (
            True,
            "",
            {
                Fields.STREET: "1 Main St",
                Fields.CITY: "Toronto",
                Fields.STATE: "ON",
                Fields.POSTAL_CODE: "M5V2T6",
                Fields.COUNTRY: "Canada",
                Fields.LATITUDE: 43.65,
                Fields.LONGITUDE: -79.38,
                "apartment": "",
            },
        )
        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "")

        user_doc = _snap({Fields.ROLES: [UserRoleValues.SELLER], Fields.SUSPENDED: False})
        profile_doc = _snap({Fields.ONBOARDING_COMPLETED: True})
        product_ref = Mock()
        product_ref.id = "prod_new_1"
        sku_collision_ref = Mock()

        users_col = Mock()
        users_col.document.return_value.get.return_value = user_doc
        profiles_col = Mock()
        profiles_col.document.return_value.get.return_value = profile_doc
        products_col = Mock()
        products_col.document.return_value = product_ref
        skus_col = Mock()
        skus_col.document.return_value = sku_collision_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.SELLER_PROFILES: profiles_col,
            Collections.PRODUCTS: products_col,
            Collections.SELLER_SKUS: skus_col,
        }[name]
        mock_get_db.return_value = db

        req = _req(
            "seller_1",
            {
                "productData": {
                    Fields.NAME: "Fresh Apples",
                    Fields.DESCRIPTION: "Ontario apples",
                    Fields.PRICE: 12.99,
                    Fields.CATEGORY_ID: 1,
                    Fields.STOCK_QUANTITY: 5,
                    Fields.SELLER_SKU: "APPLE-1",
                    Fields.IS_DIGITAL: False,
                    Fields.SELLER_ADDRESS: {
                        Fields.STREET: "1 Main St",
                        Fields.CITY: "Toronto",
                        Fields.STATE: "ON",
                        Fields.POSTAL_CODE: "M5V2T6",
                        Fields.COUNTRY: "Canada",
                    },
                },
                "images": [],
                "testImageUrls": ["https://cdn.test/products/a.jpg"],
            },
        )

        out = create_product_atomic(req)
        assert out["success"] is True
        assert out[Fields.PRODUCT_ID] == "prod_new_1"
        assert out["imageUrls"] == ["https://cdn.test/products/a.jpg"]
        product_ref.set.assert_called_once()

    @patch("handlers.products._derive_ship_from_fields", return_value={})
    @patch("handlers.products.get_server_timestamp", return_value="ts")
    @patch("utils.helpers.geocode_address")
    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    @patch("handlers.products.CURRENT_ENV", Environment.EMULATOR)
    def test_create_product_atomic_validation_error_cleans_up_sku_doc(
        self,
        mock_get_db,
        mock_rl_cls,
        mock_geocode,
        _mock_ts,
        _mock_ship_from,
    ):
        from handlers import products

        class _FailModel(BaseModel):
            qty: int

        try:
            _FailModel(qty="x")
        except ValidationError as ve:
            validation_error = ve

        mock_geocode.return_value = (
            True,
            "",
            {
                Fields.STREET: "1 Main St",
                Fields.CITY: "Toronto",
                Fields.STATE: "ON",
                Fields.POSTAL_CODE: "M5V2T6",
                Fields.COUNTRY: "Canada",
                Fields.LATITUDE: 43.65,
                Fields.LONGITUDE: -79.38,
                "apartment": "",
            },
        )
        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "")

        user_doc = _snap({Fields.ROLES: [UserRoleValues.SELLER], Fields.SUSPENDED: False})
        profile_doc = _snap({Fields.ONBOARDING_COMPLETED: True})
        product_ref = Mock()
        product_ref.id = "prod_new_2"
        sku_collision_ref = Mock()

        users_col = Mock()
        users_col.document.return_value.get.return_value = user_doc
        profiles_col = Mock()
        profiles_col.document.return_value.get.return_value = profile_doc
        products_col = Mock()
        products_col.document.return_value = product_ref
        skus_col = Mock()
        skus_col.document.return_value = sku_collision_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.SELLER_PROFILES: profiles_col,
            Collections.PRODUCTS: products_col,
            Collections.SELLER_SKUS: skus_col,
        }[name]
        mock_get_db.return_value = db

        req = _req(
            "seller_1",
            {
                "productData": {
                    Fields.NAME: "Fresh Apples",
                    Fields.DESCRIPTION: "Ontario apples",
                    Fields.PRICE: 12.99,
                    Fields.CATEGORY_ID: 1,
                    Fields.STOCK_QUANTITY: 5,
                    Fields.SELLER_SKU: "APPLE-2",
                    Fields.IS_DIGITAL: False,
                    Fields.SELLER_ADDRESS: {
                        Fields.STREET: "1 Main St",
                        Fields.CITY: "Toronto",
                        Fields.STATE: "ON",
                        Fields.POSTAL_CODE: "M5V2T6",
                        Fields.COUNTRY: "Canada",
                    },
                },
                "images": [],
                "testImageUrls": ["https://cdn.test/products/a.jpg"],
            },
        )

        with patch("handlers.products.ProductCreate", side_effect=validation_error):
            with pytest.raises(https_fn.HttpsError) as exc:
                products.create_product_atomic(req)
        assert exc.value.code == "invalid-argument"
        sku_collision_ref.delete.assert_called_once()

    @patch("handlers.products.CURRENT_ENV", Environment.EMULATOR)
    @patch("handlers.products._derive_ship_from_fields", return_value={})
    @patch("handlers.products.ProductCreate", _FakeProductCreate)
    @patch("handlers.products.get_server_timestamp", return_value="ts")
    @patch("handlers.products._get_cached_s3_client")
    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    @patch("utils.helpers.geocode_address", return_value=(True, "", {"lat": 43.6532, "lng": -79.3832}))
    def test_create_product_atomic_firestore_write_failure_cleans_r2_objects(
        self,
        mock_geocode,
        mock_get_db,
        mock_rl_cls,
        mock_get_s3,
        _mock_ts,
        _mock_ship_from,
    ):
        from handlers import products

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "")
        s3 = Mock()
        mock_get_s3.return_value = s3

        user_doc = _snap({Fields.ROLES: [UserRoleValues.ADMIN], Fields.SUSPENDED: False})
        product_ref = Mock()
        product_ref.id = "prod_new_3"
        product_ref.set.side_effect = RuntimeError("db down")

        users_col = Mock()
        users_col.document.return_value.get.return_value = user_doc
        profiles_col = Mock()
        products_col = Mock()
        products_col.document.return_value = product_ref
        skus_col = Mock()

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.SELLER_PROFILES: profiles_col,
            Collections.PRODUCTS: products_col,
            Collections.SELLER_SKUS: skus_col,
        }.get(name, Mock())
        mock_get_db.return_value = db

        png_magic = next(iter(products.BusinessRules.IMAGE_MAGIC_BYTES.keys()))
        req = _req(
            "admin_1",
            {
                "productData": {
                    Fields.NAME: "Fresh Apples",
                    Fields.DESCRIPTION: "Ontario apples",
                    Fields.PRICE: 12.99,
                    Fields.CATEGORY_ID: 1,
                    Fields.STOCK_QUANTITY: 5,
                    Fields.IS_DIGITAL: False,
                    Fields.SELLER_ADDRESS: {
                        Fields.CITY: "Toronto",
                        Fields.STATE: "ON",
                        Fields.COUNTRY: "Canada",
                    },
                },
                "images": [{"data": base64.b64encode(png_magic + b"abc").decode("ascii"), "contentType": "image/png"}],
            },
        )

        with pytest.raises(https_fn.HttpsError) as exc:
            products.create_product_atomic(req)
        assert exc.value.code == "internal"
        s3.delete_object.assert_called()

    @patch("handlers.products.create_success_response", side_effect=lambda payload: {"success": True, **payload})
    @patch("handlers.products.CURRENT_ENV", Environment.EMULATOR)
    @patch("handlers.products._derive_ship_from_fields", return_value={})
    @patch("handlers.products.ProductCreate", _FakeProductCreate)
    @patch("handlers.products.get_server_timestamp", return_value="ts")
    @patch("utils.helpers.geocode_address")
    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_create_product_atomic_sku_conflict_and_supplier_private_write(
        self,
        mock_get_db,
        mock_rl_cls,
        mock_geocode,
        _mock_ts,
        _mock_ship_from,
        _mock_resp,
    ):
        from handlers import products

        mock_geocode.return_value = (
            True,
            "",
            {
                Fields.STREET: "1 Main St",
                Fields.CITY: "Toronto",
                Fields.STATE: "ON",
                Fields.POSTAL_CODE: "M5V2T6",
                Fields.COUNTRY: "Canada",
                Fields.LATITUDE: 43.65,
                Fields.LONGITUDE: -79.38,
                "apartment": "",
            },
        )
        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "")

        user_doc = _snap({Fields.ROLES: [UserRoleValues.SELLER], Fields.SUSPENDED: False})
        profile_doc = _snap({Fields.ONBOARDING_COMPLETED: True})
        product_ref = Mock()
        product_ref.id = "prod_new_sku"
        sku_ref = Mock()
        sku_ref.create.side_effect = AlreadyExists("duplicate")

        users_col = Mock()
        users_col.document.return_value.get.return_value = user_doc
        profiles_col = Mock()
        profiles_col.document.return_value.get.return_value = profile_doc
        products_col = Mock()
        products_col.document.return_value = product_ref
        skus_col = Mock()
        skus_col.document.return_value = sku_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.SELLER_PROFILES: profiles_col,
            Collections.PRODUCTS: products_col,
            Collections.SELLER_SKUS: skus_col,
        }[name]
        mock_get_db.return_value = db

        payload = self._base_product_payload()
        payload[Fields.SELLER_SKU] = "APPLE-DUP"
        with pytest.raises(https_fn.HttpsError) as duplicate:
            products.create_product_atomic(
                _req("seller_1", {"productData": payload, "images": [], "testImageUrls": ["https://cdn.test/a.jpg"]})
            )
        assert duplicate.value.code == "already-exists"

        sku_ref.create.side_effect = None
        payload = self._base_product_payload()
        payload[Fields.SELLER_SKU] = "APPLE-UNIQUE"
        payload["supplier"] = {"supplierSku": "SUP-1", "supplierUrl": "https://supplier.example.com"}
        out = products.create_product_atomic(
            _req("seller_1", {"productData": payload, "images": [], "testImageUrls": ["https://cdn.test/a.jpg"]})
        )
        assert out["success"] is True
        product_ref.collection.assert_called_once_with("supplier_private")
        product_ref.collection.return_value.document.return_value.set.assert_called_once()

    @patch("handlers.products.CURRENT_ENV", Environment.EMULATOR)
    @patch("handlers.products._derive_ship_from_fields", return_value={})
    @patch("handlers.products.ProductCreate", _FakeProductCreate)
    @patch("handlers.products.get_server_timestamp", return_value="ts")
    @patch("utils.helpers.geocode_address")
    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_create_product_atomic_warehouse_validation_branches(
        self,
        mock_get_db,
        mock_rl_cls,
        mock_geocode,
        _mock_ts,
        _mock_ship_from,
    ):
        from handlers.products import create_product_atomic

        mock_geocode.return_value = (True, "", self._base_product_payload()[Fields.SELLER_ADDRESS] | {Fields.LATITUDE: 1.0, Fields.LONGITUDE: 2.0, "apartment": ""})
        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "")

        user_doc = _snap({Fields.ROLES: [UserRoleValues.SELLER], Fields.SUSPENDED: False})
        profile_doc = _snap({Fields.ONBOARDING_COMPLETED: True})
        product_ref = Mock()
        product_ref.id = "prod_wh"

        users_col = Mock()
        users_col.document.return_value.get.return_value = user_doc
        profiles_col = Mock()
        profiles_col.document.return_value.get.return_value = profile_doc
        products_col = Mock()
        products_col.document.return_value = product_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.SELLER_PROFILES: profiles_col,
            Collections.PRODUCTS: products_col,
            Collections.SELLER_SKUS: Mock(),
        }.get(name, Mock())
        mock_get_db.return_value = db

        payload = self._base_product_payload()
        payload[Fields.WAREHOUSE_IDS] = ["wh_1"]

        db.get_all.return_value = [_snap(exists=False, doc_id="wh_1")]
        with pytest.raises(https_fn.HttpsError) as missing_wh:
            create_product_atomic(_req("seller_1", {"productData": payload, "images": [], "testImageUrls": ["https://cdn.test/a.jpg"]}))
        assert missing_wh.value.code == "not-found"

        db.get_all.return_value = [_snap({"address": {Fields.COUNTRY: "CA"}}, doc_id="wh_1")]
        with pytest.raises(https_fn.HttpsError) as incomplete_addr:
            create_product_atomic(_req("seller_1", {"productData": payload, "images": [], "testImageUrls": ["https://cdn.test/a.jpg"]}))
        assert incomplete_addr.value.code == "invalid-argument"

        db.get_all.return_value = [_snap({"address": {Fields.CITY: "Toronto", Fields.COUNTRY: "CA"}}, doc_id="wh_1")]
        with pytest.raises(https_fn.HttpsError) as no_geo:
            create_product_atomic(_req("seller_1", {"productData": payload, "images": [], "testImageUrls": ["https://cdn.test/a.jpg"]}))
        assert no_geo.value.code == "failed-precondition"

    @patch("handlers.products.CURRENT_ENV", Environment.EMULATOR)
    @patch("handlers.products._derive_ship_from_fields", return_value={})
    @patch("handlers.products.ProductCreate", _FakeProductCreate)
    @patch("handlers.products.get_server_timestamp", return_value="ts")
    @patch("utils.helpers.geocode_address")
    @patch("handlers.products._get_cached_s3_client")
    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_create_product_atomic_write_failure_cleans_up_sku_lock(
        self,
        mock_get_db,
        mock_rl_cls,
        mock_get_s3,
        mock_geocode,
        _mock_ts,
        _mock_ship_from,
    ):
        from handlers import products

        mock_geocode.return_value = (
            True,
            "",
            {
                Fields.STREET: "1 Main St",
                Fields.CITY: "Toronto",
                Fields.STATE: "ON",
                Fields.POSTAL_CODE: "M5V2T6",
                Fields.COUNTRY: "Canada",
                Fields.LATITUDE: 43.65,
                Fields.LONGITUDE: -79.38,
                "apartment": "",
            },
        )
        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "")
        mock_get_s3.return_value = Mock()

        user_doc = _snap({Fields.ROLES: [UserRoleValues.SELLER], Fields.SUSPENDED: False})
        profile_doc = _snap({Fields.ONBOARDING_COMPLETED: True})
        product_ref = Mock()
        product_ref.id = "prod_fail_sku"
        product_ref.set.side_effect = RuntimeError("write failed")
        sku_ref = Mock()

        users_col = Mock()
        users_col.document.return_value.get.return_value = user_doc
        profiles_col = Mock()
        profiles_col.document.return_value.get.return_value = profile_doc
        products_col = Mock()
        products_col.document.return_value = product_ref
        skus_col = Mock()
        skus_col.document.return_value = sku_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.SELLER_PROFILES: profiles_col,
            Collections.PRODUCTS: products_col,
            Collections.SELLER_SKUS: skus_col,
        }[name]
        mock_get_db.return_value = db

        payload = self._base_product_payload()
        payload[Fields.SELLER_SKU] = "APPLE-FAIL"
        with pytest.raises(https_fn.HttpsError) as exc:
            products.create_product_atomic(
                _req("seller_1", {"productData": payload, "images": [], "testImageUrls": ["https://cdn.test/a.jpg"]})
            )
        assert exc.value.code == "internal"
        sku_ref.delete.assert_called_once()

    @patch("handlers.products.CURRENT_ENV", Environment.EMULATOR)
    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    @patch("handlers.products._get_cached_s3_client")
    @patch("handlers.products.ProductCreate", _FakeProductCreate)
    def test_create_product_atomic_r2_upload_failure_cleans_partial_uploads(
        self,
        mock_s3_client,
        mock_get_db,
        mock_rl_cls,
    ):
        from handlers.products import create_product_atomic

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "")

        users_col = Mock()
        users_col.document.return_value.get.return_value = _snap(
            {Fields.ROLES: [UserRoleValues.SELLER], Fields.SUSPENDED: False}
        )
        profiles_col = Mock()
        profiles_col.document.return_value.get.return_value = _snap({Fields.ONBOARDING_COMPLETED: True})

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.SELLER_PROFILES: profiles_col,
            Collections.PRODUCTS: Mock(),
            Collections.SELLER_SKUS: Mock(),
        }[name]
        mock_get_db.return_value = db

        s3 = Mock()
        s3.put_object.side_effect = [None, RuntimeError("r2 boom")]
        mock_s3_client.return_value = s3

        jpeg_b64 = base64.b64encode(b"\xff\xd8\xff\xe0valid-image").decode()
        payload = self._base_product_payload()

        with patch("handlers.products.uuid.uuid4", side_effect=["id1", "id2"]):
            with pytest.raises(https_fn.HttpsError) as exc:
                create_product_atomic(
                    _req(
                        "seller_1",
                        {
                            "productData": payload,
                            "images": [
                                {"data": jpeg_b64, "contentType": "image/jpeg"},
                                {"data": jpeg_b64, "contentType": "image/jpeg"},
                            ],
                        },
                    )
                )
        assert exc.value.code == "internal"
        s3.delete_object.assert_called_once()

    @patch("handlers.products.CURRENT_ENV", Environment.EMULATOR)
    @patch("handlers.products._derive_ship_from_fields", return_value={})
    @patch("handlers.products.ProductCreate", _FakeProductCreate)
    @patch("handlers.products.get_server_timestamp", return_value="ts")
    @patch("utils.helpers.geocode_address")
    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_create_product_atomic_rejects_invalid_subcategory_for_category(
        self,
        mock_get_db,
        mock_rl_cls,
        mock_geocode,
        _mock_ts,
        _mock_ship_from,
    ):
        from handlers.products import create_product_atomic

        mock_geocode.return_value = (
            True,
            "",
            {
                Fields.STREET: "1 Main St",
                Fields.CITY: "Toronto",
                Fields.STATE: "ON",
                Fields.POSTAL_CODE: "M5V2T6",
                Fields.COUNTRY: "Canada",
                Fields.LATITUDE: 43.65,
                Fields.LONGITUDE: -79.38,
                "apartment": "",
            },
        )
        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "")

        users_col = Mock()
        users_col.document.return_value.get.return_value = _snap(
            {Fields.ROLES: [UserRoleValues.SELLER], Fields.SUSPENDED: False}
        )
        profiles_col = Mock()
        profiles_col.document.return_value.get.return_value = _snap({Fields.ONBOARDING_COMPLETED: True})
        products_col = Mock()
        products_col.document.return_value = Mock(id="prod_bad_subcat")
        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.SELLER_PROFILES: profiles_col,
            Collections.PRODUCTS: products_col,
            Collections.SELLER_SKUS: Mock(),
        }[name]
        mock_get_db.return_value = db

        payload = self._base_product_payload()
        payload[Fields.CATEGORY_ID] = 1
        payload[Fields.SUBCATEGORY] = "definitely-not-a-real-subcategory"

        with pytest.raises(https_fn.HttpsError) as exc:
            create_product_atomic(
                _req("seller_1", {"productData": payload, "images": [], "testImageUrls": ["https://cdn.test/a.jpg"]})
            )
        assert exc.value.code == "invalid-argument"


class TestProductTriggerLifecycleDeep:
    @patch("handlers.products.get_db")
    def test_on_product_created_no_payload_returns_early(self, mock_get_db):
        from handlers.products import on_product_created

        event = Mock()
        event.params = {Fields.PRODUCT_ID: "prod_none"}
        event.data = Mock()
        event.data.to_dict.return_value = {}

        on_product_created(event)
        mock_get_db.assert_not_called()

    @patch("handlers.products._send_product_rejection_email", side_effect=RuntimeError("smtp down"))
    @patch("handlers.products._get_seller_email_and_lang", return_value=("seller@example.com", "en"))
    @patch("handlers.products.get_db")
    def test_on_product_created_duplicate_sku_deactivates_and_swallows_email_failure(
        self, mock_get_db, _mock_seller_email, _mock_send_reject
    ):
        from handlers.products import on_product_created

        seller_doc = _snap({Fields.SUSPENDED: False})
        duplicate_doc = _snap({}, doc_id="prod_existing")

        dup_query = Mock()
        dup_query.where.return_value = dup_query
        dup_query.limit.return_value = dup_query
        dup_query.get.return_value = [duplicate_doc]

        product_ref = Mock()
        products_col = Mock()
        products_col.where.return_value = dup_query
        products_col.document.return_value = product_ref

        users_col = Mock()
        users_col.document.return_value.get.return_value = seller_doc

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
        }[name]
        mock_get_db.return_value = db

        event = Mock()
        event.params = {Fields.PRODUCT_ID: "prod_new"}
        event.data = Mock()
        event.data.to_dict.return_value = {
            Fields.SELLER_ID: "seller_1",
            Fields.SELLER_SKU: "SKU-1",
        }

        on_product_created(event)

        update_payload = product_ref.update.call_args.args[0]
        assert update_payload[Fields.LIFECYCLE_STATUS] == ProductLifecycleStatusValues.DRAFT
        assert "Duplicate sellerSku" in update_payload[Fields.DEACTIVATION_REASON]

    @patch("handlers.products._generate_product_slug", return_value="dup-slug")
    @patch("handlers.products._derive_ship_from_fields", side_effect=RuntimeError("ship-from explode"))
    @patch("handlers.products._notify_admins_new_product")
    @patch("handlers.products.validate_image_magic_bytes", return_value=True)
    @patch("handlers.products.get_db")
    def test_on_product_created_slug_fallback_and_ship_from_error_branch(
        self,
        mock_get_db,
        _mock_magic,
        mock_notify,
        _mock_ship_from,
        _mock_slug,
    ):
        from handlers.products import on_product_created

        seller_doc = _snap({Fields.SUSPENDED: False})
        slug_exists = _snap({}, doc_id="existing_slug")
        product_ref = Mock()

        products_q = Mock()
        products_q.where.return_value = products_q
        products_q.limit.return_value = products_q
        products_q.get.return_value = [slug_exists]

        products_col = Mock()
        products_col.where.return_value = products_q
        products_col.document.return_value = product_ref

        users_col = Mock()
        users_col.document.return_value.get.return_value = seller_doc

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
        }[name]
        mock_get_db.return_value = db

        event = Mock()
        event.params = {Fields.PRODUCT_ID: "prod_slug_fallback"}
        event.data = Mock()
        event.data.to_dict.return_value = {
            Fields.SELLER_ID: "seller_1",
            Fields.NAME: "Fresh Carrots",
            Fields.DESCRIPTION: "Organic",
            Fields.PRICE: 8.5,
            Fields.HAS_VARIANTS: False,
            Fields.STOCK_QUANTITY: 6,
            Fields.CATEGORY_ID: 1,
            Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            Fields.IS_DIGITAL: False,
            Fields.IS_LOCAL_DELIVERY_ONLY: False,
            Fields.DELIVERY_OPTIONS: [],
            Fields.WAREHOUSE_IDS: ["wh_1"],
            Fields.IMAGE_URLS: [],
        }

        with patch("utils.helpers.sanitized_text", side_effect=lambda s: s):
            on_product_created(event)

        # Internal patches include fallback slug and default standard delivery option.
        applied_payload = product_ref.update.call_args.args[0]
        assert applied_payload[Fields.SLUG].startswith("product-")
        assert applied_payload[Fields.DELIVERY_OPTIONS][0][Fields.TYPE] == "standard"
        mock_notify.assert_called_once()

    @patch("handlers.products._notify_admins_new_product", side_effect=RuntimeError("admin notify down"))
    @patch("handlers.products._generate_product_slug", return_value="digital-item-1")
    @patch("handlers.products.get_db")
    def test_on_product_created_digital_https_rejection_and_draft_status_update_error(
        self,
        mock_get_db,
        _mock_slug,
        _mock_notify,
    ):
        from handlers.products import on_product_created

        seller_doc = _snap({Fields.SUSPENDED: False})
        product_ref = Mock()
        # Only the explicit draft->under_review write should fail.
        def _update_side_effect(payload):
            if payload.get(Fields.LIFECYCLE_STATUS) == ProductLifecycleStatusValues.UNDER_REVIEW:
                raise RuntimeError("status update failed")
            return None

        product_ref.update.side_effect = _update_side_effect

        products_q = Mock()
        products_q.where.return_value = products_q
        products_q.limit.return_value = products_q
        products_q.get.return_value = []

        products_col = Mock()
        products_col.where.return_value = products_q
        products_col.document.return_value = product_ref

        users_col = Mock()
        users_col.document.return_value.get.return_value = seller_doc

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
        }[name]
        mock_get_db.return_value = db

        bad_digital_event = Mock()
        bad_digital_event.params = {Fields.PRODUCT_ID: "prod_bad_digital"}
        bad_digital_event.data = Mock()
        bad_digital_event.data.to_dict.return_value = {
            Fields.SELLER_ID: "seller_1",
            Fields.NAME: "Digital Pack",
            Fields.DESCRIPTION: "Files",
            Fields.PRICE: 19.0,
            Fields.HAS_VARIANTS: False,
            Fields.STOCK_QUANTITY: 1,
            Fields.CATEGORY_ID: 1,
            Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            Fields.IS_DIGITAL: True,
            Fields.FREE_SHIPPING: True,
            Fields.BOOK_SOURCE_URL: "http://insecure.example.com/file.pdf",
            Fields.IMAGE_URLS: [],
        }

        on_product_created(bad_digital_event)
        reject_payload = product_ref.update.call_args_list[-1].args[0]
        assert reject_payload[Fields.LIFECYCLE_STATUS] == ProductLifecycleStatusValues.REJECTED
        assert Fields.APPROVAL_REJECTION_REASON in reject_payload

        draft_event = Mock()
        draft_event.params = {Fields.PRODUCT_ID: "prod_draft"}
        draft_event.data = Mock()
        draft_event.data.to_dict.return_value = {
            Fields.SELLER_ID: "seller_1",
            Fields.NAME: "Digital OK",
            Fields.DESCRIPTION: "Secure file",
            Fields.PRICE: 9.0,
            Fields.HAS_VARIANTS: False,
            Fields.STOCK_QUANTITY: 2,
            Fields.CATEGORY_ID: 1,
            Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.DRAFT,
            Fields.IS_DIGITAL: True,
            Fields.FREE_SHIPPING: True,
            Fields.BOOK_SOURCE_URL: "https://secure.example.com/file.pdf",
            Fields.IMAGE_URLS: [],
            Fields.SLUG: "already-there",
        }

        on_product_created(draft_event)
        # Two calls happened in draft run: internal patches + attempted draft->under_review.
        assert product_ref.update.call_count >= 3

    @patch("handlers.products._notify_admins_new_product")
    @patch("handlers.products._derive_ship_from_fields", return_value={Fields.SHIP_FROM_COUNTRY: "Canada"})
    @patch("handlers.products._generate_product_slug", return_value="fresh-apples-abc12345")
    @patch("handlers.products.validate_image_magic_bytes", return_value=True)
    @patch("handlers.products.get_db")
    def test_on_product_created_applies_internal_fixes_and_notifies_admins(
        self,
        mock_get_db,
        _mock_magic,
        _mock_slug,
        _mock_ship_from,
        mock_notify_admins,
    ):
        from handlers import products

        seller_doc = _snap({Fields.SUSPENDED: False})
        product_ref = Mock()
        products_query = Mock()
        products_query.where.return_value = products_query
        products_query.limit.return_value = products_query
        products_query.get.return_value = []

        users_col = Mock()
        users_col.document.return_value.get.return_value = seller_doc
        products_col = Mock()
        products_col.where.return_value = products_query
        products_col.document.return_value = product_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
        }[name]
        mock_get_db.return_value = db

        product_data = {
            Fields.SELLER_ID: "seller_1",
            Fields.SELLER_SKU: "SKU-123",
            Fields.NAME: "<b>Fresh Apples</b>",
            Fields.DESCRIPTION: "<i>Sweet</i>",
            Fields.PRICE: 10.0,
            Fields.COMPARE_AT_PRICE: 10.6,
            Fields.HAS_VARIANTS: False,
            Fields.STOCK_QUANTITY: 3,
            Fields.SELLER_ADDRESS: {
                Fields.COUNTRY: "Canada",
                Fields.LATITUDE: 43.65,
                Fields.LONGITUDE: -79.38,
                Fields.STREET: "1 Main",
                Fields.CITY: "Toronto",
                Fields.POSTAL_CODE: "M5V2T6",
            },
            Fields.CATEGORY_ID: 1,
            Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            Fields.IS_DIGITAL: False,
            Fields.IS_LOCAL_DELIVERY_ONLY: False,
            Fields.DELIVERY_OPTIONS: [],
            Fields.IMAGE_URLS: [f"{products.CDN_BASE_URL}/products/a.jpg"],
        }

        event = Mock()
        event.params = {Fields.PRODUCT_ID: "prod_1"}
        event.data = Mock()
        event.data.to_dict.return_value = product_data

        with patch("utils.helpers.sanitized_text", side_effect=lambda s: s.replace("<", "").replace(">", "")):
            products.on_product_created(event)

        product_ref.update.assert_called()
        mock_notify_admins.assert_called_once()

    @patch("handlers.products.CURRENT_ENV", Environment.PRODUCTION)
    @patch("handlers.products._verify_address_with_geoapify", return_value=(True, ""))
    @patch("handlers.products.validate_image_magic_bytes", return_value=True)
    @patch("handlers.products.get_db")
    def test_on_product_created_validation_deactivation_guard_matrix(
        self,
        mock_get_db,
        _mock_magic,
        _mock_verify_addr,
    ):
        from handlers.products import on_product_created

        seller_doc = _snap({Fields.SUSPENDED: False})
        product_ref = Mock()
        products_q = Mock()
        products_q.where.return_value = products_q
        products_q.limit.return_value = products_q
        products_q.get.return_value = []

        products_col = Mock()
        products_col.where.return_value = products_q
        products_col.document.return_value = product_ref
        users_col = Mock()
        users_col.document.return_value.get.return_value = seller_doc

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
        }[name]
        mock_get_db.return_value = db

        base = {
            Fields.SELLER_ID: "seller_1",
            Fields.SELLER_SKU: "SKU-OK",
            Fields.NAME: "Fresh Item",
            Fields.DESCRIPTION: "Desc",
            Fields.PRICE: 10.0,
            Fields.COMPARE_AT_PRICE: 11.5,
            Fields.HAS_VARIANTS: False,
            Fields.VARIANTS: [],
            Fields.STOCK_QUANTITY: 3,
            Fields.SELLER_ADDRESS: {
                Fields.COUNTRY: "Canada",
                Fields.LATITUDE: 43.65,
                Fields.LONGITUDE: -79.38,
                Fields.STREET: "1 Main",
                Fields.CITY: "Toronto",
                Fields.POSTAL_CODE: "M5V2T6",
            },
            Fields.CATEGORY_ID: 1,
            Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            Fields.IS_DIGITAL: False,
            Fields.IMAGE_URLS: [],
            Fields.DELIVERY_OPTIONS: [{Fields.TYPE: "standard", Fields.ESTIMATED_DAYS: 3}],
        }

        cases = [
            {Fields.PRICE: 0},
            {Fields.COMPARE_AT_PRICE: 10.1},
            {Fields.HAS_VARIANTS: True, Fields.VARIANTS: []},
            {Fields.STOCK_QUANTITY: -1},
            {Fields.SELLER_ADDRESS: {Fields.CITY: "Toronto"}},
            {Fields.CATEGORY_ID: -5},
            {
                Fields.IS_PERISHABLE: True,
                Fields.DELIVERY_OPTIONS: [{Fields.TYPE: "standard", Fields.ESTIMATED_DAYS: 7}],
                Fields.IS_LOCAL_DELIVERY_ONLY: False,
            },
            {Fields.IMAGE_URLS: ["https://cdn.origna.com/products/bad.jpg"]},
        ]

        for idx, delta in enumerate(cases):
            payload = dict(base)
            payload.update(delta)
            evt = Mock()
            evt.params = {Fields.PRODUCT_ID: f"prod_guard_{idx}"}
            evt.data = Mock()
            evt.data.to_dict.return_value = payload

            with patch("utils.helpers.sanitized_text", side_effect=lambda s: s):
                if idx == 7:
                    with patch("handlers.products.validate_image_magic_bytes", return_value=False):
                        on_product_created(evt)
                else:
                    on_product_created(evt)

        assert product_ref.update.call_count >= len(cases)

    @patch("handlers.products._track_price_history")
    @patch("handlers.products._fire_back_in_stock_notifications")
    @patch("handlers.products.algolia_partial_update")
    @patch("handlers.products.get_db")
    def test_on_product_updated_stock_only_change_uses_partial_index(
        self,
        mock_get_db,
        mock_algolia_partial,
        mock_back_in_stock,
        mock_track_price,
    ):
        from handlers.products import on_product_updated

        products_col = Mock()
        products_col.document.return_value = Mock()
        db = Mock()
        db.collection.return_value = products_col
        mock_get_db.return_value = db

        before = {
            Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            Fields.STOCK_QUANTITY: 0,
            Fields.PRICE: 10.0,
            Fields.NAME: "Fresh Apples",
        }
        after = {
            Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            Fields.STOCK_QUANTITY: 4,
            Fields.PRICE: 10.0,
            Fields.NAME: "Fresh Apples",
        }

        event = Mock()
        event.params = {Fields.PRODUCT_ID: "prod_2"}
        event.data = Mock()
        event.data.before.to_dict.return_value = before
        event.data.after.to_dict.return_value = after

        on_product_updated(event)

        mock_algolia_partial.assert_called_once_with("prod_2", {Fields.STOCK_QUANTITY: 4})
        mock_back_in_stock.assert_called_once()
        mock_track_price.assert_called_once()

    @patch("handlers.products._cleanup_orphaned_variant_subscriptions")
    @patch("handlers.products._fire_back_in_stock_notifications")
    @patch("handlers.products._track_price_history")
    @patch("handlers.products.index_product")
    @patch("handlers.products.get_db")
    def test_on_product_updated_full_validation_path_indexes_active_product(
        self,
        mock_get_db,
        mock_index_product,
        mock_track_price,
        mock_back_in_stock,
        mock_cleanup_orphans,
    ):
        from handlers.products import on_product_updated

        seller_doc = _snap({Fields.SUSPENDED: False})
        product_ref = Mock()
        users_col = Mock()
        users_col.document.return_value.get.return_value = seller_doc
        products_col = Mock()
        products_col.document.return_value = product_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
        }[name]
        mock_get_db.return_value = db

        before = {
            Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            Fields.SELLER_ID: "seller_1",
            Fields.NAME: "<b>Fresh Apples</b>",
            Fields.DESCRIPTION: "<i>Sweet</i>",
            Fields.PRICE: 10.0,
            Fields.COMPARE_AT_PRICE: 11.0,
            Fields.STOCK_QUANTITY: 5,
            Fields.SELLER_ADDRESS: {
                Fields.COUNTRY: "Canada",
                Fields.LATITUDE: 43.65,
                Fields.LONGITUDE: -79.38,
                Fields.STREET: "1 Main",
                Fields.CITY: "Toronto",
                Fields.POSTAL_CODE: "M5V2T6",
            },
            Fields.WAREHOUSE_IDS: [],
            Fields.IS_DIGITAL: False,
            Fields.SHIP_FROM_COUNTRY: "Canada",
        }
        after = dict(before)
        after[Fields.PRICE] = 9.5
        after[Fields.COMPARE_AT_PRICE] = 10.5
        after[Fields.NAME] = "<b>Fresh Apples 2</b>"

        event = Mock()
        event.params = {Fields.PRODUCT_ID: "prod_22"}
        event.data = Mock()
        event.data.before.to_dict.return_value = before
        event.data.after.to_dict.return_value = after

        with patch("utils.helpers.sanitized_text", side_effect=lambda s: s.replace("<", "").replace(">", "")):
            on_product_updated(event)

        product_ref.update.assert_called()
        mock_track_price.assert_called_once()
        mock_back_in_stock.assert_called_once()
        mock_cleanup_orphans.assert_called_once()
        mock_index_product.assert_called_once()

    @patch("handlers.products._cleanup_orphaned_variant_subscriptions")
    @patch("handlers.products._fire_back_in_stock_notifications")
    @patch("handlers.products._track_price_history")
    @patch("handlers.products.index_product", side_effect=RuntimeError("index failed"))
    @patch("handlers.products._derive_ship_from_fields", side_effect=RuntimeError("ship-from failed"))
    @patch("handlers.products.get_db")
    def test_on_product_updated_warehouse_recalc_and_ship_from_error_paths(
        self,
        mock_get_db,
        _mock_ship_from,
        _mock_index,
        _mock_track,
        _mock_back_in_stock,
        _mock_cleanup,
    ):
        from handlers.products import on_product_updated

        seller_doc = _snap({Fields.SUSPENDED: False})
        product_ref = Mock()
        users_col = Mock()
        users_col.document.return_value.get.return_value = seller_doc
        products_col = Mock()
        products_col.document.return_value = product_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
        }[name]
        mock_get_db.return_value = db

        before = {
            Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            Fields.SELLER_ID: "seller_1",
            Fields.NAME: "Item",
            Fields.DESCRIPTION: "Desc",
            Fields.PRICE: 10.0,
            Fields.COMPARE_AT_PRICE: 11.0,
            Fields.STOCK_QUANTITY: 1,
            Fields.WAREHOUSE_STOCK_MAP: {"wh_1": 1},
            Fields.WAREHOUSE_IDS: [],
            Fields.IS_DIGITAL: True,
            Fields.SELLER_ADDRESS: {Fields.COUNTRY: "Canada"},
        }
        after = dict(before)
        after[Fields.WAREHOUSE_STOCK_MAP] = {"wh_1": 3}
        after[Fields.WAREHOUSE_IDS] = ["wh_1"]
        after[Fields.SHIP_FROM_COUNTRY] = ""

        event = Mock()
        event.params = {Fields.PRODUCT_ID: "prod_recalc"}
        event.data = Mock()
        event.data.before.to_dict.return_value = before
        event.data.after.to_dict.return_value = after

        with patch("utils.helpers.sanitized_text", side_effect=lambda s: s):
            on_product_updated(event)

        first_update = product_ref.update.call_args_list[0].args[0]
        assert first_update[Fields.STOCK_QUANTITY] == 3

    @patch("handlers.products.get_db")
    def test_on_product_updated_address_changed_missing_coordinates_pauses_product(self, mock_get_db):
        from handlers.products import on_product_updated

        seller_doc = _snap({Fields.SUSPENDED: False})
        product_ref = Mock()
        users_col = Mock()
        users_col.document.return_value.get.return_value = seller_doc
        products_col = Mock()
        products_col.document.return_value = product_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
        }[name]
        mock_get_db.return_value = db

        before = {
            Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            Fields.SELLER_ID: "seller_1",
            Fields.PRICE: 10.0,
            Fields.COMPARE_AT_PRICE: 11.0,
            Fields.STOCK_QUANTITY: 2,
            Fields.WAREHOUSE_IDS: [],
            Fields.IS_DIGITAL: False,
            Fields.SELLER_ADDRESS: {
                Fields.COUNTRY: "Canada",
                Fields.LATITUDE: 43.65,
                Fields.LONGITUDE: -79.38,
                Fields.STREET: "1 Main",
                Fields.CITY: "Toronto",
                Fields.POSTAL_CODE: "M5V2T6",
            },
        }
        after = dict(before)
        after[Fields.SELLER_ADDRESS] = {
            Fields.COUNTRY: "Canada",
            Fields.STREET: "1 Main",
            Fields.CITY: "Toronto",
            Fields.POSTAL_CODE: "M5V2T6",
        }

        event = Mock()
        event.params = {Fields.PRODUCT_ID: "prod_addr"}
        event.data = Mock()
        event.data.before.to_dict.return_value = before
        event.data.after.to_dict.return_value = after

        with patch("utils.helpers.sanitized_text", side_effect=lambda s: s):
            on_product_updated(event)

        update_payload = product_ref.update.call_args.args[0]
        assert update_payload[Fields.LIFECYCLE_STATUS] == ProductLifecycleStatusValues.PAUSED
        assert Fields.DEACTIVATION_REASON in update_payload

    @patch("handlers.products._verify_address_with_geoapify", return_value=(False, "geo mismatch"))
    @patch("handlers.products.get_db")
    def test_on_product_updated_validation_pause_matrix(self, mock_get_db, _mock_verify):
        from handlers.products import on_product_updated

        seller_doc = _snap({Fields.SUSPENDED: False})
        product_ref = Mock()
        users_col = Mock()
        users_col.document.return_value.get.return_value = seller_doc
        products_col = Mock()
        products_col.document.return_value = product_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
        }[name]
        mock_get_db.return_value = db

        before = {
            Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            Fields.SELLER_ID: "seller_1",
            Fields.PRICE: 10.0,
            Fields.COMPARE_AT_PRICE: 12.0,
            Fields.STOCK_QUANTITY: 2,
            Fields.WAREHOUSE_IDS: [],
            Fields.IS_DIGITAL: False,
            Fields.SELLER_ADDRESS: {
                Fields.COUNTRY: "Canada",
                Fields.LATITUDE: 43.65,
                Fields.LONGITUDE: -79.38,
                Fields.STREET: "1 Main",
                Fields.CITY: "Toronto",
                Fields.POSTAL_CODE: "M5V2T6",
            },
        }

        cases = [
            {Fields.PRICE: -2},
            {Fields.COMPARE_AT_PRICE: 9.0},
            {Fields.STOCK_QUANTITY: "bad"},
            {Fields.SELLER_ADDRESS: {Fields.CITY: "Toronto"}},
            {
                Fields.SELLER_ADDRESS: {
                    Fields.COUNTRY: "Canada",
                    Fields.LATITUDE: 44.0,
                    Fields.LONGITUDE: -79.0,
                    Fields.STREET: "2 Main",
                    Fields.CITY: "Toronto",
                    Fields.POSTAL_CODE: "M5V2T6",
                }
            },
        ]

        for idx, delta in enumerate(cases):
            after = dict(before)
            after.update(delta)
            event = Mock()
            event.params = {Fields.PRODUCT_ID: f"prod_update_guard_{idx}"}
            event.data = Mock()
            event.data.before.to_dict.return_value = before
            event.data.after.to_dict.return_value = after
            with patch("utils.helpers.sanitized_text", side_effect=lambda s: s):
                on_product_updated(event)

        assert product_ref.update.call_count >= len(cases)

    @patch("handlers.products.create_success_response", side_effect=lambda payload: {"success": True, **payload})
    @patch("handlers.products._send_product_rejection_email")
    @patch("handlers.products._get_seller_email_and_lang", return_value=("seller@example.com", "en"))
    @patch("handlers.products._check_digital_url_reachability", return_value=["bookSourceUrl"])
    @patch("handlers.products.get_db")
    def test_admin_approve_product_rejects_unreachable_digital_urls(
        self,
        mock_get_db,
        _mock_dead_urls,
        _mock_seller_lang,
        mock_send_reject,
        _mock_resp,
    ):
        from handlers.products import admin_approve_product

        admin_doc = _snap({Fields.ROLES: [UserRoleValues.ADMIN]}, exists=True)
        product_doc = _snap(
            {
                Fields.IS_DIGITAL: True,
                Fields.SELLER_ID: "seller_1",
                Fields.NAME: "Digital Item",
            },
            exists=True,
        )
        product_ref = Mock()
        product_ref.get.return_value = product_doc

        users_col = Mock()
        users_col.document.return_value.get.return_value = admin_doc
        products_col = Mock()
        products_col.document.return_value = product_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
        }[name]
        mock_get_db.return_value = db

        req = _req("admin_1", {Fields.PRODUCT_ID: "prod_digital"})
        out = admin_approve_product(req)
        assert out["success"] is True
        assert out["rejected"] is True
        mock_send_reject.assert_called_once()

    @patch("handlers.products.create_success_response", side_effect=lambda payload: {"success": True, **payload})
    @patch("handlers.products._notify_premium_users_new_product", side_effect=RuntimeError("push down"))
    @patch("handlers.products._send_product_approval_email", side_effect=RuntimeError("smtp down"))
    @patch("handlers.products.index_product", side_effect=RuntimeError("algolia down"))
    @patch("handlers.products.get_db")
    def test_admin_approve_product_swallows_index_and_email_errors(
        self,
        mock_get_db,
        _mock_index,
        _mock_send_approval,
        _mock_notify,
        _mock_resp,
    ):
        from handlers.products import admin_approve_product

        admin_doc = _snap({Fields.ROLES: [UserRoleValues.ADMIN]}, exists=True)
        product_doc = _snap(
            {
                Fields.IS_DIGITAL: False,
                Fields.SELLER_ID: "seller_1",
                Fields.NAME: "Physical Item",
            },
            exists=True,
        )
        fresh_doc = _snap(product_doc.to_dict(), exists=True)

        product_ref = Mock()
        product_ref.get.side_effect = [product_doc, fresh_doc]
        products_col = Mock()
        products_col.document.return_value = product_ref

        users_col = Mock()
        users_col.document.return_value.get.return_value = admin_doc

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
            Collections.ADMIN_LOGS: Mock(),
        }[name]
        mock_get_db.return_value = db

        out = admin_approve_product(_req("admin_1", {Fields.PRODUCT_ID: "prod_ok"}))
        assert out["success"] is True
        assert "algoliaWarning" in out

    @patch("handlers.products.get_db")
    def test_admin_reject_product_guard_matrix(self, mock_get_db):
        from handlers.products import admin_reject_product

        db = Mock()
        mock_get_db.return_value = db
        users_col = Mock()
        products_col = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
        }[name]
        # Override auth to None for explicit unauth branch.
        req_unauth = Mock(auth=None, data={})
        with pytest.raises(https_fn.HttpsError) as unauth2:
            admin_reject_product(req_unauth)
        assert unauth2.value.code == "unauthenticated"

        users_col.document.return_value.get.return_value = _snap(exists=False)
        with pytest.raises(https_fn.HttpsError) as no_user:
            admin_reject_product(_req("admin_1", {Fields.PRODUCT_ID: "p1", "reason": "x"}))
        assert no_user.value.code == "not-found"

        users_col.document.return_value.get.return_value = _snap({Fields.ROLES: ["buyer"]}, exists=True)
        with pytest.raises(https_fn.HttpsError) as denied:
            admin_reject_product(_req("admin_1", {Fields.PRODUCT_ID: "p1", "reason": "x"}))
        assert denied.value.code == "permission-denied"

        users_col.document.return_value.get.return_value = _snap({Fields.ROLES: [UserRoleValues.ADMIN]}, exists=True)
        with pytest.raises(https_fn.HttpsError) as missing_pid:
            admin_reject_product(_req("admin_1", {"reason": "x"}))
        assert missing_pid.value.code == "invalid-argument"

        with pytest.raises(https_fn.HttpsError) as missing_reason:
            admin_reject_product(_req("admin_1", {Fields.PRODUCT_ID: "p1"}))
        assert missing_reason.value.code == "invalid-argument"

        with pytest.raises(https_fn.HttpsError) as long_reason:
            admin_reject_product(_req("admin_1", {Fields.PRODUCT_ID: "p1", "reason": "x" * 1001}))
        assert long_reason.value.code == "invalid-argument"

        products_col.document.return_value.get.return_value = _snap(exists=False)
        with pytest.raises(https_fn.HttpsError) as no_product:
            admin_reject_product(_req("admin_1", {Fields.PRODUCT_ID: "p1", "reason": "policy"}))
        assert no_product.value.code == "not-found"

    @patch("handlers.products.algolia_delete_product")
    @patch("handlers.products.get_db")
    def test_on_product_deleted_cleans_stock_notifications_in_batches(self, mock_get_db, mock_algolia_delete):
        from handlers.products import on_product_deleted

        sub_doc = _snap({}, doc_id="sub_1")
        fav_doc = _snap({}, doc_id="fav_1")
        stock_query = Mock()
        stock_query.where.return_value = stock_query
        stock_query.limit.return_value = stock_query
        stock_query.stream.side_effect = [[sub_doc], []]

        fav_query = Mock()
        fav_query.where.return_value = fav_query
        fav_query.limit.return_value = fav_query
        fav_query.stream.side_effect = [[fav_doc], []]

        db = Mock()
        db.collection.side_effect = lambda name: stock_query if name == Collections.STOCK_NOTIFICATIONS else Mock()
        db.collection_group.return_value = fav_query
        batch = Mock()
        db.batch.return_value = batch
        mock_get_db.return_value = db

        event = Mock()
        event.params = {Fields.PRODUCT_ID: "prod_3"}

        on_product_deleted(event)

        mock_algolia_delete.assert_called_once_with("prod_3")
        assert batch.delete.call_count == 2
        assert batch.commit.call_count == 2

    @patch("services.email_task.enqueue_email_task")
    @patch("handlers.products.get_db")
    def test_notify_admins_new_product_only_emails_admins_with_addresses(self, mock_get_db, mock_enqueue):
        from handlers.products import _notify_admins_new_product

        admin_with_email = _snap({Fields.EMAIL: "admin1@example.com"}, doc_id="admin_1")
        admin_without_email = _snap({}, doc_id="admin_2")
        admin_query = Mock()
        admin_query.where.return_value = admin_query
        admin_query.limit.return_value = admin_query
        admin_query.get.return_value = [admin_with_email, admin_without_email]

        db = Mock()
        db.collection.return_value = admin_query
        mock_get_db.return_value = db

        _notify_admins_new_product(
            "prod_4",
            {
                Fields.NAME: "Keyboard",
                Fields.SELLER_ID: "seller_1",
                Fields.IS_DIGITAL: False,
                Fields.PRICE: 49.99,
            },
        )

        mock_enqueue.assert_called_once()
        assert mock_enqueue.call_args.kwargs["to_email"] == "admin1@example.com"

    @patch("services.email_task.enqueue_email_task")
    def test_send_product_approval_and_rejection_email_language_branches(self, mock_enqueue):
        from handlers.products import _send_product_approval_email, _send_product_rejection_email

        _send_product_approval_email("seller@example.com", "Produit", "prod_1", lang="fr")
        _send_product_rejection_email("seller@example.com", "Product", "Invalid listing", lang="en")

        assert mock_enqueue.call_count == 2
        subjects = [c.kwargs["subject"] for c in mock_enqueue.call_args_list]
        assert any("Votre produit" in s for s in subjects)
        assert any("Product review update" in s for s in subjects)

    @patch("services.push_service.send_push_notifications_batch", return_value=2)
    @patch("handlers.products.get_db")
    def test_notify_premium_users_new_product_paginates(self, mock_get_db, mock_push_batch):
        from handlers.products import _notify_premium_users_new_product

        u1 = _snap({}, doc_id="u1")
        u2 = _snap({}, doc_id="u2")
        query = Mock()
        query.where.return_value = query
        query.limit.return_value = query
        query.start_after.return_value = query
        query.stream.side_effect = [[u1, u2], []]

        db = Mock()
        db.collection.return_value = query
        mock_get_db.return_value = db

        _notify_premium_users_new_product(
            {Fields.NAME: "Fresh Apples", Fields.IMAGE_URLS: ["https://cdn.example.com/img.jpg"]},
            "prod_5",
        )

        mock_push_batch.assert_called_once()
        assert mock_push_batch.call_args.kwargs["user_ids"] == ["u1", "u2"]
        assert mock_push_batch.call_args.kwargs["image_url"] == "https://cdn.example.com/img.jpg"


class TestProductTriggerLifecycleAdditional:
    @patch("handlers.products.get_db")
    def test_on_product_created_suspended_seller_branch(self, mock_get_db):
        from handlers.products import on_product_created

        seller_doc = _snap({Fields.SUSPENDED: True})
        product_ref = Mock()
        users_col = Mock()
        users_col.document.return_value.get.return_value = seller_doc
        products_col = Mock()
        products_col.document.return_value = product_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
        }[name]
        mock_get_db.return_value = db

        event = Mock()
        event.params = {Fields.PRODUCT_ID: "prod_suspended"}
        event.data = Mock()
        event.data.to_dict.return_value = {Fields.SELLER_ID: "seller_1", Fields.NAME: "Blocked Product"}

        on_product_created(event)
        payload = product_ref.update.call_args.args[0]
        assert payload[Fields.LIFECYCLE_STATUS] == ProductLifecycleStatusValues.DRAFT
        assert payload[Fields.DEACTIVATION_REASON] == "Seller is suspended"

    @patch("handlers.products._notify_admins_new_product")
    @patch("handlers.products.validate_image_magic_bytes", return_value=True)
    @patch("handlers.products.CURRENT_ENV", Environment.DEV)
    @patch("handlers.products.get_db")
    def test_on_product_created_dev_missing_coords_skips_geoapify_rejection(
        self,
        mock_get_db,
        _mock_magic,
        mock_notify,
    ):
        from handlers.products import on_product_created

        users_col = Mock()
        users_col.document.return_value.get.return_value = _snap({Fields.SUSPENDED: False}, exists=True)
        products_q = Mock()
        products_q.where.return_value = products_q
        products_q.limit.return_value = products_q
        products_q.get.return_value = []
        products_col = Mock()
        products_col.where.return_value = products_q
        products_col.document.return_value = Mock()

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
        }[name]
        mock_get_db.return_value = db

        event = Mock()
        event.params = {Fields.PRODUCT_ID: "prod_dev_coords"}
        event.data = Mock()
        event.data.to_dict.return_value = {
            Fields.SELLER_ID: "seller_1",
            Fields.NAME: "Dev Product",
            Fields.DESCRIPTION: "Desc",
            Fields.PRICE: 8.0,
            Fields.STOCK_QUANTITY: 2,
            Fields.CATEGORY_ID: 1,
            Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            Fields.IS_DIGITAL: False,
            Fields.DELIVERY_OPTIONS: [{Fields.TYPE: "standard", Fields.ESTIMATED_DAYS: 3}],
            Fields.SELLER_ADDRESS: {
                Fields.COUNTRY: "Canada",
                Fields.STREET: "1 Main",
                Fields.CITY: "Toronto",
                Fields.POSTAL_CODE: "M5V2T6",
            },
            Fields.SLUG: "dev-product",
            Fields.IMAGE_URLS: [],
        }

        with patch("utils.helpers.sanitized_text", side_effect=lambda s: s):
            on_product_created(event)
        mock_notify.assert_called_once()

    @patch("handlers.products._get_seller_email_and_lang", return_value=(None, "en"))
    @patch("handlers.products._verify_address_with_geoapify", return_value=(False, "bad address"))
    @patch("handlers.products.validate_image_magic_bytes", return_value=True)
    @patch("handlers.products.CURRENT_ENV", Environment.PRODUCTION)
    @patch("handlers.products.get_db")
    def test_on_product_created_geoapify_failure_rejects_product(
        self,
        mock_get_db,
        _mock_magic,
        _mock_verify,
        _mock_email,
    ):
        from handlers.products import on_product_created

        users_col = Mock()
        users_col.document.return_value.get.return_value = _snap({Fields.SUSPENDED: False}, exists=True)
        products_q = Mock()
        products_q.where.return_value = products_q
        products_q.limit.return_value = products_q
        products_q.get.return_value = []
        product_ref = Mock()
        products_col = Mock()
        products_col.where.return_value = products_q
        products_col.document.return_value = product_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
        }[name]
        mock_get_db.return_value = db

        event = Mock()
        event.params = {Fields.PRODUCT_ID: "prod_geo_fail"}
        event.data = Mock()
        event.data.to_dict.return_value = {
            Fields.SELLER_ID: "seller_1",
            Fields.NAME: "Geo Product",
            Fields.DESCRIPTION: "Desc",
            Fields.PRICE: 8.0,
            Fields.STOCK_QUANTITY: 2,
            Fields.CATEGORY_ID: 1,
            Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            Fields.IS_DIGITAL: False,
            Fields.DELIVERY_OPTIONS: [{Fields.TYPE: "standard", Fields.ESTIMATED_DAYS: 3}],
            Fields.SELLER_ADDRESS: {
                Fields.COUNTRY: "Canada",
                Fields.LATITUDE: 43.65,
                Fields.LONGITUDE: -79.38,
                Fields.STREET: "1 Main",
                Fields.CITY: "Toronto",
                Fields.POSTAL_CODE: "M5V2T6",
            },
            Fields.SLUG: "geo-product",
            Fields.IMAGE_URLS: [],
        }

        with patch("utils.helpers.sanitized_text", side_effect=lambda s: s):
            on_product_created(event)

        payload = product_ref.update.call_args.args[0]
        assert payload[Fields.LIFECYCLE_STATUS] == ProductLifecycleStatusValues.DRAFT
        assert "Address verification failed" in payload[Fields.DEACTIVATION_REASON]

    @patch("handlers.products._notify_admins_new_product")
    @patch("handlers.products.validate_image_magic_bytes", return_value=True)
    @patch("handlers.products._generate_product_slug", return_value="digital-free-1")
    @patch("handlers.products.get_db")
    def test_on_product_created_digital_free_shipping_patch_applied(
        self,
        mock_get_db,
        _mock_slug,
        _mock_magic,
        _mock_notify,
    ):
        from handlers.products import on_product_created

        users_col = Mock()
        users_col.document.return_value.get.return_value = _snap({Fields.SUSPENDED: False}, exists=True)
        products_q = Mock()
        products_q.where.return_value = products_q
        products_q.limit.return_value = products_q
        products_q.get.return_value = []
        product_ref = Mock()
        products_col = Mock()
        products_col.where.return_value = products_q
        products_col.document.return_value = product_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
        }[name]
        mock_get_db.return_value = db

        event = Mock()
        event.params = {Fields.PRODUCT_ID: "prod_digital_free"}
        event.data = Mock()
        event.data.to_dict.return_value = {
            Fields.SELLER_ID: "seller_1",
            Fields.NAME: "Digital File",
            Fields.DESCRIPTION: "Desc",
            Fields.PRICE: 8.0,
            Fields.STOCK_QUANTITY: 2,
            Fields.CATEGORY_ID: 1,
            Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            Fields.IS_DIGITAL: True,
            Fields.FREE_SHIPPING: False,
            Fields.BOOK_SOURCE_URL: "https://cdn.example.com/book.pdf",
            Fields.IMAGE_URLS: [],
        }

        with patch("utils.helpers.sanitized_text", side_effect=lambda s: s):
            on_product_created(event)
        payload = product_ref.update.call_args.args[0]
        assert payload[Fields.FREE_SHIPPING] is True

    @patch("handlers.products._notify_admins_new_product")
    @patch("handlers.products.validate_image_magic_bytes", return_value=True)
    @patch("handlers.products._generate_product_slug", return_value="local-pickup-1")
    @patch("handlers.products.get_db")
    def test_on_product_created_local_only_adds_pickup_option(
        self,
        mock_get_db,
        _mock_slug,
        _mock_magic,
        _mock_notify,
    ):
        from handlers.products import on_product_created

        users_col = Mock()
        users_col.document.return_value.get.return_value = _snap({Fields.SUSPENDED: False}, exists=True)
        products_q = Mock()
        products_q.where.return_value = products_q
        products_q.limit.return_value = products_q
        products_q.get.return_value = []
        product_ref = Mock()
        products_col = Mock()
        products_col.where.return_value = products_q
        products_col.document.return_value = product_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
        }[name]
        mock_get_db.return_value = db

        event = Mock()
        event.params = {Fields.PRODUCT_ID: "prod_local_pickup"}
        event.data = Mock()
        event.data.to_dict.return_value = {
            Fields.SELLER_ID: "seller_1",
            Fields.NAME: "Local Item",
            Fields.DESCRIPTION: "Desc",
            Fields.PRICE: 8.0,
            Fields.STOCK_QUANTITY: 2,
            Fields.CATEGORY_ID: 1,
            Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            Fields.IS_DIGITAL: False,
            Fields.IS_LOCAL_DELIVERY_ONLY: True,
            Fields.DELIVERY_OPTIONS: [],
            Fields.SELLER_ADDRESS: {Fields.COUNTRY: "Canada", Fields.LATITUDE: 43.6, Fields.LONGITUDE: -79.3},
            Fields.IMAGE_URLS: [],
        }

        with patch("utils.helpers.sanitized_text", side_effect=lambda s: s):
            on_product_created(event)
        payload = product_ref.update.call_args.args[0]
        assert payload[Fields.DELIVERY_OPTIONS][0][Fields.TYPE] == "pickup"

    @patch("handlers.products._notify_admins_new_product")
    @patch("handlers.products.validate_image_magic_bytes", return_value=True)
    @patch("handlers.products._generate_product_slug", return_value="patch-fail-1")
    @patch("handlers.products.get_db")
    def test_on_product_created_internal_patch_write_failure_is_non_fatal(
        self,
        mock_get_db,
        _mock_slug,
        _mock_magic,
        mock_notify,
    ):
        from handlers.products import on_product_created

        users_col = Mock()
        users_col.document.return_value.get.return_value = _snap({Fields.SUSPENDED: False}, exists=True)
        products_q = Mock()
        products_q.where.return_value = products_q
        products_q.limit.return_value = products_q
        products_q.get.return_value = []
        product_ref = Mock()
        product_ref.update.side_effect = RuntimeError("patch write failed")
        products_col = Mock()
        products_col.where.return_value = products_q
        products_col.document.return_value = product_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
        }[name]
        mock_get_db.return_value = db

        event = Mock()
        event.params = {Fields.PRODUCT_ID: "prod_patch_fail"}
        event.data = Mock()
        event.data.to_dict.return_value = {
            Fields.SELLER_ID: "seller_1",
            Fields.NAME: "<b>Patch</b>",
            Fields.DESCRIPTION: "<i>Desc</i>",
            Fields.PRICE: 8.0,
            Fields.STOCK_QUANTITY: 2,
            Fields.CATEGORY_ID: 1,
            Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            Fields.IS_DIGITAL: False,
            Fields.DELIVERY_OPTIONS: [{Fields.TYPE: "standard", Fields.ESTIMATED_DAYS: 2}],
            Fields.SELLER_ADDRESS: {Fields.COUNTRY: "Canada", Fields.LATITUDE: 43.6, Fields.LONGITUDE: -79.3},
            Fields.IMAGE_URLS: [],
        }

        with patch("utils.helpers.sanitized_text", side_effect=lambda s: s.replace("<", "").replace(">", "")):
            on_product_created(event)
        mock_notify.assert_called_once()

    @patch("handlers.products._get_seller_email_and_lang", return_value=(None, "en"))
    @patch("handlers.products.validate_image_magic_bytes", return_value=False)
    @patch("handlers.products.get_db")
    def test_on_product_created_invalid_image_deactivates(
        self,
        mock_get_db,
        _mock_magic,
        _mock_seller_email,
    ):
        import handlers.products as products

        from handlers.products import on_product_created

        users_col = Mock()
        users_col.document.return_value.get.return_value = _snap({Fields.SUSPENDED: False}, exists=True)
        products_q = Mock()
        products_q.where.return_value = products_q
        products_q.limit.return_value = products_q
        products_q.get.return_value = []
        product_ref = Mock()
        products_col = Mock()
        products_col.where.return_value = products_q
        products_col.document.return_value = product_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
        }[name]
        mock_get_db.return_value = db

        event = Mock()
        event.params = {Fields.PRODUCT_ID: "prod_bad_img"}
        event.data = Mock()
        event.data.to_dict.return_value = {
            Fields.SELLER_ID: "seller_1",
            Fields.NAME: "Bad Image",
            Fields.DESCRIPTION: "Desc",
            Fields.PRICE: 8.0,
            Fields.STOCK_QUANTITY: 2,
            Fields.CATEGORY_ID: 1,
            Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            Fields.IS_DIGITAL: False,
            Fields.DELIVERY_OPTIONS: [{Fields.TYPE: "standard", Fields.ESTIMATED_DAYS: 2}],
            Fields.SELLER_ADDRESS: {Fields.COUNTRY: "Canada", Fields.LATITUDE: 43.6, Fields.LONGITUDE: -79.3},
            Fields.IMAGE_URLS: [f"{products.CDN_BASE_URL}/products/bad.jpg"],
            Fields.SLUG: "bad-image",
        }

        with patch("utils.helpers.sanitized_text", side_effect=lambda s: s):
            on_product_created(event)

        payload = product_ref.update.call_args.args[0]
        assert payload[Fields.LIFECYCLE_STATUS] == ProductLifecycleStatusValues.DRAFT
        assert "Image validation failed" in payload[Fields.DEACTIVATION_REASON]

    @patch("handlers.products._get_seller_email_and_lang", return_value=(None, "en"))
    @patch("handlers.products.validate_image_magic_bytes", return_value=True)
    @patch("handlers.products.get_db")
    def test_on_product_created_digital_non_https_build_rejects(
        self,
        mock_get_db,
        _mock_magic,
        _mock_seller_email,
    ):
        from handlers.products import on_product_created

        users_col = Mock()
        users_col.document.return_value.get.return_value = _snap({Fields.SUSPENDED: False}, exists=True)
        products_q = Mock()
        products_q.where.return_value = products_q
        products_q.limit.return_value = products_q
        products_q.get.return_value = []
        product_ref = Mock()
        products_col = Mock()
        products_col.where.return_value = products_q
        products_col.document.return_value = product_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
        }[name]
        mock_get_db.return_value = db

        event = Mock()
        event.params = {Fields.PRODUCT_ID: "prod_https_reject"}
        event.data = Mock()
        event.data.to_dict.return_value = {
            Fields.SELLER_ID: "seller_1",
            Fields.NAME: "Digital Build",
            Fields.DESCRIPTION: "Desc",
            Fields.PRICE: 8.0,
            Fields.STOCK_QUANTITY: 2,
            Fields.CATEGORY_ID: 1,
            Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            Fields.IS_DIGITAL: True,
            Fields.FREE_SHIPPING: True,
            Fields.DIGITAL_BUILDS: {"win": "http://cdn.example.com/win.zip"},
            Fields.IMAGE_URLS: [],
            Fields.SLUG: "digital-build",
        }

        with patch("utils.helpers.sanitized_text", side_effect=lambda s: s):
            on_product_created(event)

        payload = product_ref.update.call_args.args[0]
        assert payload[Fields.LIFECYCLE_STATUS] == ProductLifecycleStatusValues.REJECTED
        assert "Digital download URLs must use HTTPS" in payload[Fields.APPROVAL_REJECTION_REASON]

    @patch("handlers.products._notify_admins_new_product")
    @patch("handlers.products.validate_image_magic_bytes", return_value=True)
    @patch("handlers.products.get_db")
    def test_on_product_created_draft_transitions_to_under_review(
        self,
        mock_get_db,
        _mock_magic,
        _mock_notify,
    ):
        from handlers.products import on_product_created

        users_col = Mock()
        users_col.document.return_value.get.return_value = _snap({Fields.SUSPENDED: False}, exists=True)
        products_q = Mock()
        products_q.where.return_value = products_q
        products_q.limit.return_value = products_q
        products_q.get.return_value = []
        product_ref = Mock()
        products_col = Mock()
        products_col.where.return_value = products_q
        products_col.document.return_value = product_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
        }[name]
        mock_get_db.return_value = db

        event = Mock()
        event.params = {Fields.PRODUCT_ID: "prod_draft_to_review"}
        event.data = Mock()
        event.data.to_dict.return_value = {
            Fields.SELLER_ID: "seller_1",
            Fields.NAME: "Draft Item",
            Fields.DESCRIPTION: "Desc",
            Fields.PRICE: 8.0,
            Fields.STOCK_QUANTITY: 2,
            Fields.CATEGORY_ID: 1,
            Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.DRAFT,
            Fields.IS_DIGITAL: True,
            Fields.FREE_SHIPPING: True,
            Fields.BOOK_SOURCE_URL: "https://cdn.example.com/book.pdf",
            Fields.IMAGE_URLS: [],
            Fields.SLUG: "draft-item",
        }

        with patch("utils.helpers.sanitized_text", side_effect=lambda s: s):
            on_product_created(event)

        assert any(
            c.args[0].get(Fields.LIFECYCLE_STATUS) == ProductLifecycleStatusValues.UNDER_REVIEW
            for c in product_ref.update.call_args_list
        )

    @patch("services.email_task.enqueue_email_task")
    def test_send_product_approval_en_and_rejection_fr_language_branches(self, mock_enqueue):
        from handlers.products import _send_product_approval_email, _send_product_rejection_email

        _send_product_approval_email("seller@example.com", "Product", "prod_1", lang="en")
        _send_product_rejection_email("seller@example.com", "Produit", "Raison", lang="fr")

        assert mock_enqueue.call_count == 2
        subjects = [c.kwargs["subject"] for c in mock_enqueue.call_args_list]
        assert any("Your product is live" in s for s in subjects)
        assert any("Mise à jour de l'examen" in s for s in subjects)
