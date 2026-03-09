from datetime import UTC, datetime
from unittest.mock import Mock, patch

import pytest
from firebase_functions import https_fn

from schema_constants import (
    Collections,
    Fields,
    ProductLifecycleStatusValues,
    UserRoleValues,
    WarehouseTypeValues,
)


def _snap(data=None, *, exists=True, doc_id="doc_1"):
    snap = Mock()
    snap.exists = exists
    snap.id = doc_id
    snap.to_dict.return_value = {} if data is None else data
    snap.reference = Mock()
    return snap


def _req(uid: str | None, data: dict):
    req = Mock()
    req.auth = Mock(uid=uid) if uid else None
    req.data = data
    req.raw_request = Mock()
    req.raw_request.headers = {}
    return req


class TestCatalogEndpointsDeep:
    @patch("handlers.products.create_success_response", side_effect=lambda payload: {"success": True, **payload})
    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_configure_algolia_admin_success(self, mock_get_db, mock_rl_cls, _mock_resp):
        from handlers.products import configure_algolia

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "")
        admin_doc = _snap({Fields.ROLES: [UserRoleValues.ADMIN]})
        users_col = Mock()
        users_col.document.return_value.get.return_value = admin_doc
        db = Mock()
        db.collection.return_value = users_col
        mock_get_db.return_value = db

        req = _req("admin_1", {})
        with patch("services.algolia_service.configure_algolia_index") as mock_cfg:
            out = configure_algolia(req)
        assert out["success"] is True
        assert "configured" in out["message"].lower()
        mock_cfg.assert_called_once()

    @patch("handlers.products.create_success_response", side_effect=lambda payload: {"success": True, **payload})
    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_get_products_paginated_public_success_with_cursor(self, mock_get_db, mock_rl_cls, _mock_resp):
        from handlers.products import get_products_paginated

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "")

        start_doc = _snap({}, exists=True, doc_id="cursor_1")
        d1 = _snap(
            {Fields.NAME: "P1", "supplier": {"secret": "x"}, "supplierSku": "S1", "supplierUrl": "https://x"},
            doc_id="p1",
        )
        d2 = _snap({Fields.NAME: "P2"}, doc_id="p2")

        query = Mock()
        query.where.return_value = query
        query.order_by.return_value = query
        query.start_after.return_value = query
        query.limit.return_value = query
        query.stream.return_value = [d1, d2]

        products_col = Mock()
        products_col.where.return_value = query
        products_col.document.return_value.get.return_value = start_doc

        db = Mock()
        db.collection.return_value = products_col
        mock_get_db.return_value = db

        req = _req(
            None,
            {
                "limit": 1,
                "startAfter": "cursor_1",
                "orderBy": Fields.CREATED_AT,
                "orderDirection": "desc",
            },
        )
        req.raw_request.headers = {"X-Forwarded-For": "1.2.3.4"}

        out = get_products_paginated(req)
        assert out["success"] is True
        assert out["hasMore"] is True
        assert out["nextCursor"] == "p1"
        assert "supplier" not in out["products"][0]
        assert "supplierSku" not in out["products"][0]
        assert "supplierUrl" not in out["products"][0]

    @patch("handlers.products.create_success_response", side_effect=lambda payload: {"success": True, **payload})
    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_get_seller_products_paginated_owner_can_include_inactive(self, mock_get_db, mock_rl_cls, _mock_resp):
        from handlers.products import get_seller_products_paginated

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "")

        d1 = _snap({Fields.NAME: "P1"}, doc_id="p1")
        d2 = _snap({Fields.NAME: "P2"}, doc_id="p2")
        query = Mock()
        query.where.return_value = query
        query.order_by.return_value = query
        query.start_after.return_value = query
        query.limit.return_value = query
        query.stream.return_value = [d1, d2]

        products_col = Mock()
        products_col.where.return_value = query
        products_col.document.return_value.get.return_value = _snap({}, exists=True)

        db = Mock()
        db.collection.return_value = products_col
        mock_get_db.return_value = db

        req = _req("seller_1", {Fields.SELLER_ID: "seller_1", "includeInactive": True, "limit": 1})
        out = get_seller_products_paginated(req)
        assert out["success"] is True
        assert out["hasMore"] is True
        assert out["totalFetched"] == 1

    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_get_seller_products_paginated_other_user_needs_admin(self, mock_get_db, mock_rl_cls):
        from handlers.products import get_seller_products_paginated

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "")

        non_admin_doc = _snap({Fields.ROLES: ["seller"]})
        users_col = Mock()
        users_col.document.return_value.get.return_value = non_admin_doc
        db = Mock()
        db.collection.side_effect = lambda name: users_col if name == Collections.USERS else Mock()
        mock_get_db.return_value = db

        req = _req("viewer_1", {Fields.SELLER_ID: "seller_1", "includeInactive": True})
        with pytest.raises(https_fn.HttpsError) as exc:
            get_seller_products_paginated(req)
        assert exc.value.code == "permission-denied"

    @patch("handlers.products.create_success_response", side_effect=lambda payload: {"success": True, **payload})
    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_get_product_ratings_paginated_enriches_user_name(self, mock_get_db, mock_rl_cls, _mock_resp):
        from handlers.products import get_product_ratings_paginated

        mock_rl_cls.return_value.check_rate_limit.return_value = (True, "")

        r1 = _snap({Fields.PRODUCT_ID: "p1", Fields.USER_ID: "u1", Fields.RATING: 5, Fields.COMMENT: "Great"}, doc_id="r1")
        r2 = _snap({Fields.PRODUCT_ID: "p1", Fields.USER_ID: "u2", Fields.RATING: 4, Fields.COMMENT: "Good"}, doc_id="r2")

        ratings_query = Mock()
        ratings_query.where.return_value = ratings_query
        ratings_query.order_by.return_value = ratings_query
        ratings_query.start_after.return_value = ratings_query
        ratings_query.limit.return_value = ratings_query
        ratings_query.stream.return_value = [r1, r2]

        ratings_col = Mock()
        ratings_col.where.return_value = ratings_query
        ratings_col.document.return_value.get.return_value = _snap({}, exists=True)

        users_col = Mock()
        users_col.document.side_effect = lambda uid: Mock(id=uid)

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.PRODUCT_RATINGS: ratings_col,
            Collections.USERS: users_col,
        }[name]
        db.get_all.return_value = [
            _snap({Fields.NAME: "Alice Doe"}, doc_id="u1"),
            _snap({Fields.NAME: "Bob Smith"}, doc_id="u2"),
        ]
        mock_get_db.return_value = db

        req = _req("buyer_1", {Fields.PRODUCT_ID: "p1", "limit": 1, "minRating": 4})
        out = get_product_ratings_paginated(req)

        assert out["success"] is True
        assert out["hasMore"] is True
        assert out[Fields.RATINGS][0]["userName"] in {"Alice", "Bob"}


class TestWarehouseEndpointsDeep:
    @patch("handlers.products.create_success_response", side_effect=lambda payload: payload)
    @patch("handlers.products.get_firestore")
    @patch("handlers.products.get_db")
    def test_admin_update_warehouse_commission_success(self, mock_get_db, mock_get_firestore, _mock_resp):
        from handlers.products import admin_update_warehouse_commission

        mock_get_firestore.return_value.transactional = lambda fn: fn
        tx = Mock()

        admin_doc = _snap({Fields.ROLES: [UserRoleValues.ADMIN]})
        wh_snap = _snap({Fields.COMMISSION_RATE_BPS: 900})
        audit_ref = Mock()
        wh_ref = Mock()
        wh_ref.get.return_value = wh_snap
        wh_ref.collection.return_value.document.return_value = audit_ref

        admin_user_ref = Mock()
        admin_user_ref.get.return_value = admin_doc
        seller_user_ref = Mock()
        warehouses_col = Mock()
        seller_user_ref.collection.return_value = warehouses_col
        warehouses_col.document.return_value = wh_ref

        users_col = Mock()
        users_col.document.side_effect = lambda uid: admin_user_ref if uid == "admin_1" else seller_user_ref

        db = Mock()
        db.collection.return_value = users_col
        db.transaction.return_value = tx
        mock_get_db.return_value = db

        req = _req(
            "admin_1",
            {
                Fields.SELLER_ID: "seller_1",
                "warehouseId": "wh_1",
                Fields.COMMISSION_RATE_BPS: 1200,
                Fields.REASON: "Manual fix",
            },
        )
        out = admin_update_warehouse_commission(req)
        assert out["newRateBps"] == 1200
        tx.update.assert_called()
        tx.set.assert_called()

    @patch("handlers.products.create_success_response", side_effect=lambda payload: payload)
    @patch("handlers.products._geocode_warehouse_address", side_effect=lambda a: {**a, Fields.LATITUDE: 43.0, Fields.LONGITUDE: -79.0})
    @patch("handlers.products._validate_warehouse_address")
    @patch("handlers.products.get_db")
    def test_create_warehouse_default_true_clears_existing_default(
        self, mock_get_db, _mock_validate, _mock_geocode, _mock_resp
    ):
        from handlers.products import create_warehouse

        tx = Mock()
        existing_default = _snap({"isDefault": True}, doc_id="old_default")
        wh_col = Mock()
        wh_col.where.return_value.stream.return_value = [existing_default]
        new_wh_ref = Mock()
        new_wh_ref.id = "wh_new"
        wh_col.document.return_value = new_wh_ref

        seller_ref = Mock()
        seller_ref.collection.return_value = wh_col
        users_col = Mock()
        users_col.document.return_value = seller_ref

        db = Mock()
        db.collection.return_value = users_col
        db.transaction.return_value = tx
        mock_get_db.return_value = db

        req = _req(
            "seller_1",
            {
                "label": "Montreal Hub",
                "type": WarehouseTypeValues.WAREHOUSE,
                "address": {
                    Fields.STREET: "1 Main",
                    Fields.CITY: "Montreal",
                    Fields.STATE: "QC",
                    Fields.POSTAL_CODE: "H2Y1C6",
                    Fields.COUNTRY: "Canada",
                },
                "isDefault": True,
            },
        )
        out = create_warehouse(req)
        assert out["warehouseId"] == "wh_new"
        tx.update.assert_called()
        tx.set.assert_called()

    @patch("handlers.products.create_success_response", side_effect=lambda payload: payload)
    @patch("handlers.products._derive_ship_from_fields", return_value={Fields.SHIP_FROM_COUNTRY: "Canada"})
    @patch("handlers.products._geocode_warehouse_address", side_effect=lambda a: {**a, Fields.LATITUDE: 43.0, Fields.LONGITUDE: -79.0})
    @patch("handlers.products._validate_warehouse_address")
    @patch("handlers.products.get_db")
    def test_update_warehouse_syncs_product_ship_from_after_address_change(
        self,
        mock_get_db,
        _mock_validate,
        _mock_geocode,
        _mock_ship_from,
        _mock_resp,
    ):
        from handlers.products import update_warehouse

        tx = Mock()
        wh_doc = _snap({"label": "Old", "isDefault": False})
        wh_ref = Mock()
        wh_ref.get.return_value = wh_doc

        wh_col = Mock()
        wh_col.document.return_value = wh_ref
        other_default = _snap({"isDefault": True}, doc_id="other")
        wh_col.where.return_value.stream.return_value = [other_default]

        pdoc = _snap({Fields.WAREHOUSE_IDS: ["wh_1"], Fields.IS_DIGITAL: False}, doc_id="prod_1")
        prod_query = Mock()
        prod_query.where.return_value = prod_query
        prod_query.limit.return_value.get.side_effect = [[pdoc], []]

        products_col = Mock()
        products_col.where.return_value = prod_query
        products_col.document.return_value = Mock()

        users_col = Mock()
        users_col.document.return_value.collection.return_value = wh_col

        sync_batch = Mock()
        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
        }[name]
        db.transaction.return_value = tx
        db.batch.return_value = sync_batch
        mock_get_db.return_value = db

        req = _req(
            "seller_1",
            {
                "warehouseId": "wh_1",
                "address": {
                    Fields.STREET: "1 Main",
                    Fields.CITY: "Toronto",
                    Fields.STATE: "ON",
                    Fields.POSTAL_CODE: "M5V2T6",
                    Fields.COUNTRY: "Canada",
                },
                "isDefault": True,
            },
        )
        out = update_warehouse(req)
        assert out["warehouseId"] == "wh_1"
        sync_batch.update.assert_called()
        sync_batch.commit.assert_called()

    @patch("handlers.products.create_success_response", side_effect=lambda payload: payload)
    @patch("handlers.products._derive_ship_from_fields", return_value={})
    @patch("handlers.products.get_db")
    def test_delete_warehouse_success_cleans_associations_then_deletes(
        self,
        mock_get_db,
        _mock_ship_from,
        _mock_resp,
    ):
        from handlers.products import delete_warehouse

        wh_snap = _snap({Fields.IS_DEFAULT: False})
        wh_ref = Mock()
        wh_ref.get.return_value = wh_snap

        wh_col = Mock()
        wh_col.document.return_value = wh_ref
        seller_ref = Mock()
        seller_ref.collection.return_value = wh_col
        users_col = Mock()
        users_col.document.return_value = seller_ref

        pdoc = _snap({Fields.WAREHOUSE_IDS: ["wh_1"], Fields.WAREHOUSE_STOCK: {}, Fields.NAME: "P"}, doc_id="prod_1")
        products_query = Mock()
        products_query.where.return_value = products_query
        products_query.stream.return_value = []
        products_query.limit.return_value = products_query
        products_query.get.side_effect = [[pdoc], []]

        p_ref = Mock()
        p_ref.collection.return_value.document.return_value = Mock()
        products_col = Mock()
        products_col.where.return_value = products_query
        products_col.document.return_value = p_ref

        orders_query = Mock()
        orders_query.where.return_value = orders_query
        orders_query.limit.return_value = orders_query
        orders_query.get.return_value = []
        orders_col = Mock()
        orders_col.where.return_value = orders_query

        cleanup_batch = Mock()
        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
            Collections.ORDERS: orders_col,
        }[name]
        db.batch.return_value = cleanup_batch
        mock_get_db.return_value = db

        req = _req("seller_1", {"warehouseId": "wh_1"})
        out = delete_warehouse(req)
        assert out["warehouseId"] == "wh_1"
        cleanup_batch.update.assert_called()
        wh_ref.delete.assert_called_once()

    @patch("handlers.products.create_success_response", side_effect=lambda payload: payload)
    @patch("handlers.products.get_db")
    def test_get_seller_warehouses_and_clear_default_helper(self, mock_get_db, _mock_resp):
        from handlers.products import _clear_default_warehouse, get_seller_warehouses

        created_at = datetime(2026, 1, 2, tzinfo=UTC)
        w1 = _snap({"isDefault": True, Fields.CREATED_AT: created_at, "label": "Main"}, doc_id="wh_1")
        w2 = _snap({"isDefault": False, Fields.CREATED_AT: created_at, "label": "Backup"}, doc_id="wh_2")

        wh_col = Mock()
        wh_col.order_by.return_value.order_by.return_value.get.return_value = [w1, w2]
        wh_col.where.return_value.get.return_value = [w1, w2]

        seller_ref = Mock()
        seller_ref.collection.return_value = wh_col
        users_col = Mock()
        users_col.document.return_value = seller_ref

        db = Mock()
        db.collection.return_value = users_col
        mock_get_db.return_value = db

        req = _req("seller_1", {})
        out = get_seller_warehouses(req)
        assert out["warehouses"][0]["warehouseId"] == "wh_1"
        assert "T" in out["warehouses"][0][Fields.CREATED_AT]

        _clear_default_warehouse("seller_1", exclude_id="wh_2")
        w1.reference.update.assert_called_once_with({"isDefault": False})
        w2.reference.update.assert_not_called()


class TestWarehouseGuardBranchesMore:
    @patch("handlers.products._geocode_warehouse_address", side_effect=RuntimeError("geocode down"))
    @patch("handlers.products._validate_warehouse_address")
    @patch("handlers.products.get_db")
    def test_create_warehouse_guards_and_internal_error(self, mock_get_db, _mock_validate, _mock_geocode):
        from handlers.products import create_warehouse

        with pytest.raises(https_fn.HttpsError) as unauth:
            create_warehouse(_req(None, {}))
        assert unauth.value.code == "unauthenticated"

        with pytest.raises(https_fn.HttpsError) as bad_label:
            create_warehouse(
                _req(
                    "seller_1",
                    {
                        "label": "",
                        "type": WarehouseTypeValues.WAREHOUSE,
                        "address": {Fields.STATE: "ON", Fields.POSTAL_CODE: "M5V2T6", Fields.COUNTRY: "Canada"},
                    },
                )
            )
        assert bad_label.value.code == "invalid-argument"

        with pytest.raises(https_fn.HttpsError) as bad_type:
            create_warehouse(
                _req(
                    "seller_1",
                    {
                        "label": "WH",
                        "type": "bad",
                        "address": {Fields.STATE: "ON", Fields.POSTAL_CODE: "M5V2T6", Fields.COUNTRY: "Canada"},
                    },
                )
            )
        assert bad_type.value.code == "invalid-argument"

        with pytest.raises(https_fn.HttpsError) as bad_addr:
            create_warehouse(_req("seller_1", {"label": "WH", "type": WarehouseTypeValues.WAREHOUSE, "address": "bad"}))
        assert bad_addr.value.code == "invalid-argument"

        db = Mock()
        db.collection.return_value.document.return_value.collection.return_value.document.return_value = Mock(id="wh_new")
        db.transaction.return_value = Mock()
        mock_get_db.return_value = db
        with pytest.raises(https_fn.HttpsError) as internal:
            create_warehouse(
                _req(
                    "seller_1",
                    {
                        "label": "WH",
                        "type": WarehouseTypeValues.WAREHOUSE,
                        "address": {Fields.STATE: "ON", Fields.POSTAL_CODE: "M5V2T6", Fields.COUNTRY: "Canada"},
                    },
                )
            )
        assert internal.value.code == "internal"

    @patch("handlers.products._geocode_warehouse_address", side_effect=RuntimeError("geocode down"))
    @patch("handlers.products._validate_warehouse_address")
    @patch("handlers.products.get_db")
    def test_update_warehouse_guards_and_internal_error(self, mock_get_db, _mock_validate, _mock_geocode):
        from handlers.products import update_warehouse

        with pytest.raises(https_fn.HttpsError) as unauth:
            update_warehouse(_req(None, {}))
        assert unauth.value.code == "unauthenticated"

        with pytest.raises(https_fn.HttpsError) as missing_id:
            update_warehouse(_req("seller_1", {}))
        assert missing_id.value.code == "invalid-argument"

        wh_ref = Mock()
        wh_ref.get.return_value = _snap(exists=False)
        wh_col = Mock()
        wh_col.document.return_value = wh_ref
        users_col = Mock()
        users_col.document.return_value.collection.return_value = wh_col
        db = Mock()
        db.collection.side_effect = lambda name: {Collections.USERS: users_col, Collections.PRODUCTS: Mock()}[name]
        mock_get_db.return_value = db

        with pytest.raises(https_fn.HttpsError) as not_found:
            update_warehouse(_req("seller_1", {"warehouseId": "wh_1", "label": "New"}))
        assert not_found.value.code == "not-found"

        wh_ref.get.return_value = _snap({"label": "Old"}, exists=True)
        with pytest.raises(https_fn.HttpsError) as bad_label:
            update_warehouse(_req("seller_1", {"warehouseId": "wh_1", "label": ""}))
        assert bad_label.value.code == "invalid-argument"

        with pytest.raises(https_fn.HttpsError) as bad_type:
            update_warehouse(_req("seller_1", {"warehouseId": "wh_1", "type": "bad"}))
        assert bad_type.value.code == "invalid-argument"

        with pytest.raises(https_fn.HttpsError) as bad_addr:
            update_warehouse(_req("seller_1", {"warehouseId": "wh_1", "address": "bad"}))
        assert bad_addr.value.code == "invalid-argument"

        with pytest.raises(https_fn.HttpsError) as no_fields:
            update_warehouse(_req("seller_1", {"warehouseId": "wh_1"}))
        assert no_fields.value.code == "invalid-argument"

        with pytest.raises(https_fn.HttpsError) as internal:
            update_warehouse(
                _req(
                    "seller_1",
                    {
                        "warehouseId": "wh_1",
                        "address": {Fields.STATE: "ON", Fields.POSTAL_CODE: "M5V2T6", Fields.COUNTRY: "Canada"},
                    },
                )
            )
        assert internal.value.code == "internal"

    @patch("handlers.products._derive_ship_from_fields", return_value={})
    @patch("handlers.products.get_db")
    def test_delete_warehouse_stock_and_order_guards(self, mock_get_db, _mock_ship_from):
        from handlers.products import delete_warehouse

        wh_snap = _snap({Fields.IS_DEFAULT: False}, exists=True)
        wh_ref = Mock()
        wh_ref.get.return_value = wh_snap

        wh_col = Mock()
        wh_col.document.return_value = wh_ref
        seller_ref = Mock()
        seller_ref.collection.return_value = wh_col
        users_col = Mock()
        users_col.document.return_value = seller_ref

        pdoc = _snap({Fields.WAREHOUSE_IDS: ["wh_1"], Fields.WAREHOUSE_STOCK: {}, Fields.NAME: "P"}, doc_id="prod_1")
        products_query = Mock()
        products_query.where.return_value = products_query
        products_query.limit.return_value = products_query
        products_query.get.side_effect = [[], []]
        products_query.stream.return_value = [pdoc]

        inv_doc = _snap({Fields.AVAILABLE_QUANTITY: 2}, exists=True)
        p_ref = Mock()
        p_ref.collection.return_value.document.return_value.get.return_value = inv_doc
        products_col = Mock()
        products_col.where.return_value = products_query
        products_col.document.return_value = p_ref

        orders_query = Mock()
        orders_query.where.return_value = orders_query
        orders_query.limit.return_value = orders_query
        orders_query.get.return_value = []
        orders_col = Mock()
        orders_col.where.return_value = orders_query

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
            Collections.ORDERS: orders_col,
        }[name]
        mock_get_db.return_value = db

        with pytest.raises(https_fn.HttpsError) as stock_guard:
            delete_warehouse(_req("seller_1", {"warehouseId": "wh_1"}))
        assert stock_guard.value.code == "failed-precondition"

        p_ref.collection.return_value.document.return_value.get.return_value = _snap({Fields.AVAILABLE_QUANTITY: 0}, exists=True)
        products_query.stream.return_value = []
        orders_query.get.return_value = [_snap({Fields.ITEMS: [{Fields.FULFILLMENT_WAREHOUSE_ID: "wh_1"}]}, doc_id="ord_1")]
        with pytest.raises(https_fn.HttpsError) as order_guard:
            delete_warehouse(_req("seller_1", {"warehouseId": "wh_1"}))
        assert order_guard.value.code == "failed-precondition"

    @patch("handlers.products.create_success_response", side_effect=lambda payload: payload)
    @patch("handlers.products._derive_ship_from_fields", return_value={})
    @patch("handlers.products.get_db")
    def test_delete_warehouse_promotes_other_default(self, mock_get_db, _mock_ship_from, _mock_resp):
        from handlers.products import delete_warehouse

        wh_snap = _snap({Fields.IS_DEFAULT: True}, exists=True)
        wh_ref = Mock()
        wh_ref.get.return_value = wh_snap

        other_wh = _snap({Fields.IS_DEFAULT: False}, exists=True, doc_id="wh_2")
        wh_col = Mock()
        wh_col.document.return_value = wh_ref
        wh_col.where.return_value.limit.return_value.stream.return_value = [other_wh]

        seller_ref = Mock()
        seller_ref.collection.return_value = wh_col
        users_col = Mock()
        users_col.document.return_value = seller_ref

        products_query = Mock()
        products_query.where.return_value = products_query
        products_query.limit.return_value = products_query
        products_query.get.side_effect = [[], []]
        products_query.stream.return_value = []
        products_col = Mock()
        products_col.where.return_value = products_query
        products_col.document.return_value = Mock()

        orders_query = Mock()
        orders_query.where.return_value = orders_query
        orders_query.limit.return_value = orders_query
        orders_query.get.return_value = []
        orders_col = Mock()
        orders_col.where.return_value = orders_query

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
            Collections.ORDERS: orders_col,
        }[name]
        db.batch.return_value = Mock()
        mock_get_db.return_value = db

        out = delete_warehouse(_req("seller_1", {"warehouseId": "wh_1"}))
        assert out["warehouseId"] == "wh_1"
        other_wh.reference.update.assert_called_once_with({Fields.IS_DEFAULT: True})
        wh_ref.delete.assert_called_once()
