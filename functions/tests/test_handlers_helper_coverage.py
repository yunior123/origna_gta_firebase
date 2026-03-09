from datetime import UTC, datetime, timedelta
from unittest.mock import Mock, patch

import pytest
import requests
from firebase_functions import https_fn

from schema_constants import BusinessRules, Collections, Fields, PaymentStatusValues


class _FakeTimestamp:
    """Simple Firestore-like timestamp wrapper for return-window tests."""

    def __init__(self, dt: datetime):
        self._dt = dt

    def timestamp(self) -> float:
        return self._dt.timestamp()


class TestOrderHelperCoverage:
    @patch("handlers.orders.get_server_timestamp", return_value="ts")
    @patch("handlers.orders.get_firestore")
    @patch("handlers.orders.get_db")
    def test_restore_stock_to_batch_updates_warehouse_inventory(
        self, mock_get_db, mock_get_firestore, _mock_ts
    ):
        from handlers.orders import _restore_stock_to_batch

        batch = Mock()
        db = Mock()
        mock_get_db.return_value = db

        fs = Mock()
        fs.Increment.side_effect = lambda value: ("inc", value)
        mock_get_firestore.return_value = fs

        product_ref = Mock()
        inventory_ref = Mock()
        db.collection.return_value.document.return_value = product_ref
        product_ref.collection.return_value.document.return_value = inventory_ref

        items = [
            {
                Fields.PRODUCT_ID: "prod_1",
                Fields.QUANTITY: 3,
                Fields.IS_DIGITAL: False,
                Fields.FULFILLMENT_WAREHOUSE_ID: "wh_1",
            }
        ]

        _restore_stock_to_batch(batch, items)

        batch.update.assert_called_once_with(
            product_ref,
            {
                Fields.STOCK_QUANTITY: ("inc", 3),
                Fields.UPDATED_AT: "ts",
                f"{Fields.WAREHOUSE_STOCK}.wh_1": ("inc", 3),
            },
        )
        batch.set.assert_called_once_with(
            inventory_ref,
            {
                Fields.AVAILABLE_QUANTITY: ("inc", 3),
                Fields.LAST_SYNCED_AT: "ts",
            },
            merge=True,
        )

    @patch("handlers.orders.get_firestore")
    @patch("handlers.orders.get_db")
    def test_restore_stock_to_batch_skips_digital_items(self, mock_get_db, _mock_get_firestore):
        from handlers.orders import _restore_stock_to_batch

        batch = Mock()
        _restore_stock_to_batch(
            batch,
            [{Fields.PRODUCT_ID: "prod_digital", Fields.QUANTITY: 1, Fields.IS_DIGITAL: True}],
        )

        mock_get_db.assert_not_called()
        batch.update.assert_not_called()
        batch.set.assert_not_called()

    def test_assert_within_return_window_accepts_recent_iso_timestamp(self):
        from handlers.orders import _assert_within_return_window

        recent = (datetime.now(UTC) - timedelta(days=max(BusinessRules.RETURN_WINDOW_DAYS - 1, 0))).isoformat()
        _assert_within_return_window({Fields.DELIVERED_AT: recent})

    def test_assert_within_return_window_rejects_expired_firestore_timestamp(self):
        from handlers.orders import _assert_within_return_window

        old_date = datetime.now(UTC) - timedelta(days=BusinessRules.RETURN_WINDOW_DAYS + 2)
        with pytest.raises(https_fn.HttpsError) as exc:
            _assert_within_return_window({Fields.DELIVERED_AT: _FakeTimestamp(old_date)})

        assert exc.value.code == "failed-precondition"
        assert "Return window expired" in str(exc.value)

    @patch("handlers.orders.get_db")
    @patch("handlers.orders.enqueue_email_task")
    def test_handle_payment_status_email_ignores_non_refund_status(self, mock_enqueue, mock_get_db):
        from handlers.orders import _handle_payment_status_email

        _handle_payment_status_email(
            "order_1",
            {Fields.USER_ID: "buyer_1"},
            PaymentStatusValues.CAPTURED,
            buyer_email="buyer@example.com",
        )

        mock_get_db.assert_not_called()
        mock_enqueue.assert_not_called()

    @patch("google.cloud.firestore_v1.transaction.transactional", new=lambda fn: fn)
    @patch("handlers.orders.get_firestore")
    @patch("handlers.orders.get_db")
    @patch("handlers.orders.enqueue_email_task")
    def test_handle_payment_status_email_dedup_skips_duplicate_sends(
        self, mock_enqueue, mock_get_db, mock_get_firestore
    ):
        from handlers.orders import _handle_payment_status_email

        db = Mock()
        mock_get_db.return_value = db
        db.transaction.return_value = Mock()
        order_ref = Mock()
        db.collection.return_value.document.return_value = order_ref

        order_doc = Mock()
        order_doc.exists = True
        order_doc.to_dict.return_value = {
            Fields.NOTIFICATIONS_SENT: [f"payment_email:{PaymentStatusValues.REFUNDED}"]
        }
        order_ref.get.return_value = order_doc
        mock_get_firestore.return_value.ArrayUnion.side_effect = lambda vals: vals

        _handle_payment_status_email(
            "order_dup_1",
            {Fields.USER_ID: "buyer_1"},
            PaymentStatusValues.REFUNDED,
            buyer_email="buyer@example.com",
        )

        mock_enqueue.assert_not_called()

    @patch("google.cloud.firestore_v1.transaction.transactional", new=lambda fn: fn)
    @patch("handlers.orders._email_t", return_value="Refunded {oid}")
    @patch("handlers.orders.get_order_refunded_email", return_value="<p>refunded</p>")
    @patch("handlers.orders.get_firestore")
    @patch("handlers.orders.get_db")
    @patch("handlers.orders.enqueue_email_task")
    def test_handle_payment_status_email_refunded_enqueues_email(
        self,
        mock_enqueue,
        mock_get_db,
        mock_get_firestore,
        _mock_refunded_template,
        _mock_translate,
    ):
        from handlers.orders import _handle_payment_status_email

        db = Mock()
        mock_get_db.return_value = db
        txn = Mock()
        db.transaction.return_value = txn
        order_ref = Mock()
        db.collection.return_value.document.return_value = order_ref

        order_doc = Mock()
        order_doc.exists = True
        order_doc.to_dict.return_value = {Fields.NOTIFICATIONS_SENT: []}
        order_ref.get.return_value = order_doc
        mock_get_firestore.return_value.ArrayUnion.side_effect = lambda vals: vals

        _handle_payment_status_email(
            "order_abcdefgh123",
            {
                Fields.USER_ID: "buyer_1",
                Fields.PREFERRED_LANGUAGE: "en",
                Fields.CUMULATIVE_REFUNDED_CENTS: 1200,
            },
            PaymentStatusValues.REFUNDED,
            buyer_email="buyer@example.com",
        )

        assert txn.update.called
        mock_enqueue.assert_called_once()
        kwargs = mock_enqueue.call_args.kwargs
        assert kwargs["to_email"] == "buyer@example.com"
        assert kwargs["event_type"] == "order_refunded"


class TestProductHelperCoverage:
    def test_validate_warehouse_address_requires_map(self):
        from handlers.products import _validate_warehouse_address

        with pytest.raises(https_fn.HttpsError) as exc:
            _validate_warehouse_address("not-a-map")

        assert exc.value.code == "invalid-argument"

    def test_validate_warehouse_address_rejects_invalid_canadian_postal(self):
        from handlers.products import _validate_warehouse_address

        with pytest.raises(https_fn.HttpsError) as exc:
            _validate_warehouse_address(
                {
                    Fields.STREET: "123 Main St",
                    Fields.CITY: "Toronto",
                    Fields.COUNTRY: "CA",
                    Fields.STATE: "ON",
                    Fields.POSTAL_CODE: "12345",
                }
            )

        assert exc.value.code == "invalid-argument"
        assert "postal code" in str(exc.value).lower()

    def test_validate_warehouse_address_allows_international_without_ca_rules(self):
        from handlers.products import _validate_warehouse_address

        _validate_warehouse_address(
            {
                Fields.STREET: "1 Market St",
                Fields.CITY: "San Francisco",
                Fields.COUNTRY: "US",
                Fields.STATE: "CA",
                Fields.POSTAL_CODE: "94105",
            }
        )

    def test_derive_ship_from_fields_digital_product_returns_empty(self):
        from handlers.products import _derive_ship_from_fields

        assert _derive_ship_from_fields("seller_1", {Fields.IS_DIGITAL: True}) == {}

    def test_derive_ship_from_fields_uses_seller_address_when_no_warehouses(self):
        from handlers.products import _derive_ship_from_fields

        result = _derive_ship_from_fields(
            "seller_1",
            {
                Fields.SELLER_ADDRESS: {
                    Fields.CITY: "Toronto",
                    Fields.STATE: "ON",
                    Fields.COUNTRY: "Canada",
                }
            },
        )

        assert result[Fields.SHIP_FROM_CITY] == "Toronto"
        assert result[Fields.SHIP_FROM_PROVINCE] == "ON"
        assert result[Fields.SHIP_FROM_COUNTRY] == "Canada"
        assert result[Fields.SHIP_FROM_COUNTRIES] == ["Canada"]

    @patch("handlers.products.get_db")
    def test_derive_ship_from_fields_prefers_default_warehouse(self, mock_get_db):
        from handlers.products import _derive_ship_from_fields

        db = Mock()
        mock_get_db.return_value = db
        db.collection.return_value.document.return_value.collection.return_value.document.side_effect = [
            Mock(),
            Mock(),
        ]

        wh_doc_a = Mock()
        wh_doc_a.exists = True
        wh_doc_a.to_dict.return_value = {
            "isDefault": False,
            "address": {
                Fields.CITY: "Montreal",
                Fields.STATE: "QC",
                Fields.COUNTRY: "Canada",
            },
        }
        wh_doc_b = Mock()
        wh_doc_b.exists = True
        wh_doc_b.to_dict.return_value = {
            "isDefault": True,
            "address": {
                Fields.CITY: "New York",
                Fields.STATE: "NY",
                Fields.COUNTRY: "USA",
            },
        }
        db.get_all.return_value = [wh_doc_a, wh_doc_b]

        result = _derive_ship_from_fields(
            "seller_1",
            {
                Fields.WAREHOUSE_IDS: ["wh_a", "wh_b"],
                Fields.IS_DIGITAL: False,
            },
        )

        assert result[Fields.SHIP_FROM_CITY] == "New York"
        assert result[Fields.SHIP_FROM_PROVINCE] == "NY"
        assert result[Fields.SHIP_FROM_COUNTRY] == "USA"
        assert result[Fields.SELLER_ADDRESS][Fields.CITY] == "New York"
        assert result[Fields.SHIP_FROM_COUNTRIES] == ["Canada", "USA"]

    @patch("handlers.products.requests.head")
    def test_check_digital_url_reachability_flags_failed_urls(self, mock_head):
        from handlers.products import _check_digital_url_reachability

        def _head_side_effect(url, **_kwargs):
            if url.endswith("/http-fail"):
                return Mock(status_code=500)
            if url.endswith("/net-fail"):
                raise requests.exceptions.ConnectionError("network down")
            return Mock(status_code=200)

        mock_head.side_effect = _head_side_effect

        dead = _check_digital_url_reachability(
            "prod_1",
            {
                Fields.BOOK_SOURCE_URL: "https://example.com/http-fail",
                Fields.DIGITAL_BUILDS: {
                    "windows": "https://example.com/ok",
                    "mac": "https://example.com/net-fail",
                },
            },
        )

        assert set(dead) == {"bookSourceUrl", "digitalBuilds.mac"}

    @patch("handlers.products.get_db")
    def test_cleanup_orphaned_variant_subscriptions_deletes_removed_variants(self, mock_get_db):
        from handlers.products import _cleanup_orphaned_variant_subscriptions

        db = Mock()
        mock_get_db.return_value = db
        batch = Mock()
        db.batch.return_value = batch

        query = Mock()
        query.where.return_value = query
        query.limit.return_value = query

        sub_doc_1 = Mock()
        sub_doc_1.reference = Mock()
        sub_doc_2 = Mock()
        sub_doc_2.reference = Mock()
        query.stream.return_value = [sub_doc_1, sub_doc_2]
        db.collection.return_value.where.return_value.where.return_value.limit.return_value = query

        _cleanup_orphaned_variant_subscriptions(
            "prod_1",
            {
                Fields.VARIANTS: [
                    {Fields.VARIANT_KEY: "red"},
                    {Fields.VARIANT_KEY: "blue"},
                ]
            },
            {Fields.VARIANTS: [{Fields.VARIANT_KEY: "red"}]},
        )

        assert batch.delete.call_count == 2
        batch.commit.assert_called_once()

    @patch("handlers.products.get_db")
    def test_cleanup_orphaned_variant_subscriptions_ignores_empty_variant_keys(self, mock_get_db):
        from handlers.products import _cleanup_orphaned_variant_subscriptions

        _cleanup_orphaned_variant_subscriptions(
            "prod_1",
            {Fields.VARIANTS: [{Fields.VARIANT_KEY: ""}]},
            {Fields.VARIANTS: []},
        )

        mock_get_db.assert_not_called()

    @patch("handlers.products.get_db")
    def test_track_price_history_skips_when_price_unchanged(self, mock_get_db):
        from handlers.products import _track_price_history

        db = Mock()
        mock_get_db.return_value = db
        product_ref = Mock()
        db.collection.return_value.document.return_value = product_ref

        _track_price_history(
            "prod_1",
            {Fields.PRICE: 10.0, Fields.COMPARE_AT_PRICE: 12.0},
            {Fields.PRICE: 10.0, Fields.COMPARE_AT_PRICE: 12.0},
        )

        product_ref.update.assert_not_called()

    @patch("firebase_admin.firestore.ArrayUnion", new=lambda values: values)
    @patch("handlers.products.get_db")
    def test_track_price_history_appends_array_entry_on_change(self, mock_get_db):
        from handlers.products import _track_price_history

        db = Mock()
        mock_get_db.return_value = db
        product_ref = Mock()
        db.collection.return_value.document.return_value = product_ref

        _track_price_history(
            "prod_1",
            {Fields.PRICE: 10.0, Fields.COMPARE_AT_PRICE: 14.0},
            {Fields.PRICE: 9.0, Fields.COMPARE_AT_PRICE: 12.0},
        )

        product_ref.update.assert_called_once()
        payload = product_ref.update.call_args.args[0]
        assert Fields.PRICE_HISTORY in payload
        entry = payload[Fields.PRICE_HISTORY][0]
        assert entry[Fields.PRICE] == 9.0
        assert entry[Fields.COMPARE_AT_PRICE] == 12.0
        assert "changedAt" in entry
