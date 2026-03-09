from unittest.mock import Mock, patch

import stripe

from schema_constants import (
    Collections,
    Fields,
    OrderEventTypes,
    OrderStatusValues,
    PaymentStatusValues,
    ProductLifecycleStatusValues,
    StripeConstants,
)


def _snap(data=None, *, exists=True, doc_id="doc_1"):
    snap = Mock()
    snap.exists = exists
    snap.id = doc_id
    snap.to_dict.return_value = {} if data is None else data
    snap.reference = Mock()
    return snap


class TestProcessAsyncPaymentSucceededDeep:
    def test_no_order_id_returns_none(self):
        from handlers.payment_stripe import process_async_payment_succeeded

        assert process_async_payment_succeeded({StripeConstants.METADATA: {}}) is None

    @patch("handlers.payment_stripe.get_db")
    def test_order_not_found_returns_none(self, mock_get_db):
        from handlers.payment_stripe import process_async_payment_succeeded

        orders_col = Mock()
        orders_col.document.return_value.get.return_value = _snap(exists=False)
        db = Mock()
        db.collection.return_value = orders_col
        mock_get_db.return_value = db

        out = process_async_payment_succeeded({StripeConstants.METADATA: {StripeConstants.METADATA_ORDER_ID: "o_1"}})
        assert out is None

    @patch("handlers.payment_stripe.get_db")
    def test_already_captured_is_idempotent(self, mock_get_db):
        from handlers.payment_stripe import process_async_payment_succeeded

        order_data = {Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED}
        orders_col = Mock()
        orders_col.document.return_value.get.return_value = _snap(order_data, doc_id="o_cap")
        db = Mock()
        db.collection.return_value = orders_col
        mock_get_db.return_value = db

        out = process_async_payment_succeeded({StripeConstants.METADATA: {StripeConstants.METADATA_ORDER_ID: "o_cap"}})
        assert out == "Order o_cap already captured"

    @patch("handlers.payment_stripe._restore_stock_and_cancel_order")
    @patch("handlers.payment_stripe.get_db")
    def test_amount_mismatch_cancels_order(self, mock_get_db, mock_restore):
        from handlers.payment_stripe import process_async_payment_succeeded

        order_data = {
            Fields.PAYMENT_STATUS: PaymentStatusValues.AWAITING_PAYMENT,
            Fields.TOTAL_AMOUNT_CENTS: 2000,
            Fields.ITEMS: [],
        }
        orders_col = Mock()
        orders_col.document.return_value.get.return_value = _snap(order_data, doc_id="o_mm")
        db = Mock()
        db.collection.return_value = orders_col
        mock_get_db.return_value = db

        out = process_async_payment_succeeded(
            {
                StripeConstants.METADATA: {StripeConstants.METADATA_ORDER_ID: "o_mm"},
                "amount_total": 1500,
            }
        )
        assert out == "Order o_mm cancelled - amount mismatch"
        mock_restore.assert_called_once()

    @patch("handlers.payment_stripe._restore_stock_and_cancel_order")
    @patch("handlers.payment_stripe.get_db")
    def test_all_bad_sellers_cancels_order(self, mock_get_db, mock_restore):
        from handlers.payment_stripe import process_async_payment_succeeded

        order_data = {
            Fields.PAYMENT_STATUS: PaymentStatusValues.AWAITING_PAYMENT,
            Fields.TOTAL_AMOUNT_CENTS: 1000,
            Fields.ITEMS: [{Fields.PRODUCT_ID: "p_1", Fields.SELLER_ID: "s_1"}],
        }

        order_ref = Mock()
        order_ref.get.return_value = _snap(order_data, doc_id="o_bad")
        orders_col = Mock()
        orders_col.document.return_value = order_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.PRODUCTS: Mock(),
            Collections.USERS: Mock(),
        }[name]
        db.get_all.side_effect = [
            [_snap({Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.PAUSED}, doc_id="p_1")],  # product lookup
            [_snap({Fields.SUSPENDED: True}, doc_id="s_1")],  # seller lookup
        ]
        mock_get_db.return_value = db

        out = process_async_payment_succeeded(
            {
                StripeConstants.METADATA: {StripeConstants.METADATA_ORDER_ID: "o_bad"},
                "amount_total": 1000,
            }
        )

        assert out == "Order o_bad cancelled - all sellers invalid at async payment time"
        mock_restore.assert_called_once()

    @patch("utils.helpers.get_charge_id_from_pi", return_value="ch_1")
    @patch("handlers.payment_stripe._run_post_payment_side_effects")
    @patch("handlers.payment_stripe._execute_seller_payouts", side_effect=RuntimeError("payout boom"))
    @patch("handlers.payment_stripe.OrderEvent.write", side_effect=RuntimeError("event boom"))
    @patch("handlers.payment_stripe.stripe.PaymentIntent.retrieve")
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("handlers.payment_stripe.get_db")
    def test_partial_bad_sellers_flags_review_and_continues(
        self,
        mock_get_db,
        _mock_ts,
        _mock_ensure,
        mock_pi_retrieve,
        _mock_event_write,
        mock_execute,
        mock_side_effects,
        _mock_charge_id,
    ):
        from handlers.payment_stripe import process_async_payment_succeeded

        mock_pi_retrieve.return_value = Mock()

        order_data = {
            Fields.PAYMENT_STATUS: PaymentStatusValues.AWAITING_PAYMENT,
            Fields.TOTAL_AMOUNT_CENTS: 3000,
            Fields.ITEMS: [
                {Fields.PRODUCT_ID: "p_bad", Fields.SELLER_ID: "s_bad"},
                {Fields.PRODUCT_ID: "p_good", Fields.SELLER_ID: "s_good"},
            ],
        }
        order_ref = Mock()
        order_ref.get.return_value = _snap(order_data, doc_id="o_partial")
        orders_col = Mock()
        orders_col.document.return_value = order_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.PRODUCTS: Mock(),
            Collections.USERS: Mock(),
        }[name]
        db.get_all.side_effect = [
            [_snap({Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE}, doc_id="p_good")],  # p_bad missing
            [_snap({Fields.SUSPENDED: False}, doc_id="s_bad"), _snap({Fields.SUSPENDED: False}, doc_id="s_good")],
        ]
        mock_get_db.return_value = db

        out = process_async_payment_succeeded(
            {
                StripeConstants.METADATA: {StripeConstants.METADATA_ORDER_ID: "o_partial"},
                StripeConstants.PAYMENT_INTENT: "pi_async_1",
                "amount_total": 3000,
            }
        )

        assert out == "Order o_partial payment captured"
        # Called with filtered order_data (only good seller item)
        called_order_data = mock_execute.call_args.args[1]
        assert len(called_order_data[Fields.ITEMS]) == 1
        assert called_order_data[Fields.ITEMS][0][Fields.SELLER_ID] == "s_good"
        # Manual-review update + captured update
        assert order_ref.update.call_count >= 2
        mock_side_effects.assert_called_once()


class TestProcessAsyncPaymentFailedDeep:
    def test_no_order_id_returns_none(self):
        from handlers.payment_stripe import process_async_payment_failed

        assert process_async_payment_failed({StripeConstants.METADATA: {}}) is None

    @patch("services.email_service.send_payment_capture_failed_email", side_effect=RuntimeError("mail down"))
    @patch("handlers.payment_stripe.OrderEvent.write", side_effect=RuntimeError("event down"))
    @patch("handlers.payment_stripe._add_stock_restore_to_batch")
    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("handlers.payment_stripe.get_db")
    def test_stock_already_restored_skips_restore_and_handles_email_failure(
        self,
        mock_get_db,
        _mock_ts,
        mock_restore,
        _mock_event,
        _mock_mail,
    ):
        from handlers.payment_stripe import process_async_payment_failed

        order_data = {
            Fields.STOCK_RESTORED: True,
            Fields.USER_ID: "buyer_1",
            Fields.PREFERRED_LANGUAGE: "en",
            Fields.TOTAL_AMOUNT_CENTS: 1234,
        }
        order_ref = Mock()
        order_ref.get.return_value = _snap(order_data, doc_id="o_fail")
        orders_col = Mock()
        orders_col.document.return_value = order_ref

        buyer_ref = Mock()
        buyer_ref.get.return_value = _snap({Fields.EMAIL: "buyer@example.com"}, doc_id="buyer_1")
        users_col = Mock()
        users_col.document.return_value = buyer_ref

        batch = Mock()
        db = Mock()
        db.batch.return_value = batch
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        out = process_async_payment_failed({StripeConstants.METADATA: {StripeConstants.METADATA_ORDER_ID: "o_fail"}})

        assert out == "Order o_fail cancelled due to payment failure"
        mock_restore.assert_not_called()
        batch.update.assert_called_once()
        batch.commit.assert_called_once()


class TestStockRestoreHelpersDeep:
    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("handlers.payment_stripe.get_firestore")
    @patch("handlers.payment_stripe.get_db")
    def test_add_stock_restore_to_batch_restores_warehouse_inventory(
        self,
        mock_get_db,
        mock_get_fs,
        _mock_ts,
    ):
        from handlers.payment_stripe import _add_stock_restore_to_batch

        mock_get_fs.return_value.Increment.side_effect = lambda n: ("inc", n)

        product_ref = Mock()
        inv_ref = Mock()
        product_ref.collection.return_value.document.return_value = inv_ref
        products_col = Mock()
        products_col.document.return_value = product_ref

        db = Mock()
        db.collection.side_effect = lambda name: {Collections.PRODUCTS: products_col}[name]
        mock_get_db.return_value = db

        batch = Mock()
        _add_stock_restore_to_batch(
            batch,
            {
                Fields.ITEMS: [
                    {
                        Fields.PRODUCT_ID: "p_1",
                        Fields.QUANTITY: 2,
                        Fields.FULFILLMENT_WAREHOUSE_ID: "wh_1",
                        Fields.IS_DIGITAL: False,
                    }
                ]
            },
        )

        batch.update.assert_called_once()
        batch.set.assert_called_once_with(
            inv_ref,
            {Fields.AVAILABLE_QUANTITY: ("inc", 2), Fields.LAST_SYNCED_AT: "ts"},
            merge=True,
        )

    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("handlers.payment_stripe.get_firestore")
    @patch("handlers.payment_stripe.get_db")
    def test_add_stock_restore_to_transaction_restores_warehouse_inventory(
        self,
        mock_get_db,
        mock_get_fs,
        _mock_ts,
    ):
        from handlers.payment_stripe import _add_stock_restore_to_transaction

        mock_get_fs.return_value.Increment.side_effect = lambda n: ("inc", n)

        product_ref = Mock()
        inv_ref = Mock()
        product_ref.collection.return_value.document.return_value = inv_ref
        products_col = Mock()
        products_col.document.return_value = product_ref

        db = Mock()
        db.collection.side_effect = lambda name: {Collections.PRODUCTS: products_col}[name]
        mock_get_db.return_value = db

        tx = Mock()
        _add_stock_restore_to_transaction(
            tx,
            {
                Fields.ITEMS: [
                    {
                        Fields.PRODUCT_ID: "p_1",
                        Fields.QUANTITY: 3,
                        Fields.FULFILLMENT_WAREHOUSE_ID: "wh_2",
                        Fields.IS_DIGITAL: False,
                    }
                ]
            },
        )

        assert tx.update.call_count == 1
        tx.set.assert_called_once_with(
            inv_ref,
            {Fields.AVAILABLE_QUANTITY: ("inc", 3), Fields.LAST_SYNCED_AT: "ts"},
            merge=True,
        )


class TestRestoreStockAndCancelOrderDeep:
    @patch("handlers.payment_stripe.get_transactional", return_value=lambda fn: fn)
    @patch("handlers.payment_stripe._add_stock_restore_to_transaction")
    @patch("handlers.payment_stripe.stripe.Refund.create")
    @patch("handlers.payment_stripe.stripe.PaymentIntent.retrieve")
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("handlers.payment_stripe.get_db")
    def test_restore_and_cancel_order_refunds_succeeded_payment(
        self,
        mock_get_db,
        _mock_ts,
        _mock_ensure,
        mock_pi_retrieve,
        mock_refund,
        _mock_restore_tx,
        _mock_get_transactional,
    ):
        from handlers.payment_stripe import _restore_stock_and_cancel_order

        mock_pi_retrieve.return_value = Mock(status=StripeConstants.STATUS_SUCCEEDED)

        order_ref = Mock()
        order_ref.get.return_value = _snap(
            {
                Fields.STOCK_RESTORED: False,
                Fields.STRIPE_PAYMENT_INTENT_ID: "pi_1",
                Fields.ITEMS: [],
            },
            doc_id="o_rollback",
        )
        orders_col = Mock()
        orders_col.document.return_value = order_ref
        security_col = Mock()

        db = Mock()
        db.transaction.return_value = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.SECURITY_ALERTS: security_col,
        }[name]
        mock_get_db.return_value = db

        _restore_stock_and_cancel_order("o_rollback", {Fields.STRIPE_PAYMENT_INTENT_ID: "pi_1"}, "bad post-checkout")

        mock_refund.assert_called_once()
        security_col.add.assert_not_called()
        order_ref.update.assert_not_called()  # no manual review update

    @patch("handlers.payment_stripe.get_transactional", return_value=lambda fn: fn)
    @patch("handlers.payment_stripe._add_stock_restore_to_transaction")
    @patch("handlers.payment_stripe.stripe.Refund.create")
    @patch("handlers.payment_stripe.stripe.PaymentIntent.retrieve")
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("handlers.payment_stripe.get_db")
    def test_restore_and_cancel_order_refund_failure_creates_alert_and_manual_review(
        self,
        mock_get_db,
        _mock_ts,
        _mock_ensure,
        mock_pi_retrieve,
        mock_refund,
        _mock_restore_tx,
        _mock_get_transactional,
    ):
        import handlers.payment_stripe as hps

        from handlers.payment_stripe import _restore_stock_and_cancel_order

        mock_refund.side_effect = hps.stripe.error.StripeError("refund failed")

        mock_pi_retrieve.return_value = Mock(status=StripeConstants.STATUS_SUCCEEDED)

        order_ref = Mock()
        order_ref.get.return_value = _snap(
            {
                Fields.STOCK_RESTORED: False,
                Fields.STRIPE_PAYMENT_INTENT_ID: "pi_2",
                Fields.ITEMS: [],
            },
            doc_id="o_rollback_fail",
        )
        orders_col = Mock()
        orders_col.document.return_value = order_ref
        security_col = Mock()

        db = Mock()
        db.transaction.return_value = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.SECURITY_ALERTS: security_col,
        }[name]
        mock_get_db.return_value = db

        _restore_stock_and_cancel_order("o_rollback_fail", {Fields.STRIPE_PAYMENT_INTENT_ID: "pi_2"}, "invalid state")

        security_col.add.assert_called_once()
        order_ref.update.assert_called_once()

    @patch("handlers.payment_stripe.get_transactional", return_value=lambda fn: fn)
    @patch("handlers.payment_stripe._add_stock_restore_to_transaction")
    @patch("handlers.payment_stripe.stripe.PaymentIntent.cancel")
    @patch("handlers.payment_stripe.stripe.PaymentIntent.retrieve")
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("handlers.payment_stripe.get_db")
    def test_restore_and_cancel_order_cancels_requires_capture_without_manual_review(
        self,
        mock_get_db,
        _mock_ts,
        _mock_ensure,
        mock_pi_retrieve,
        mock_pi_cancel,
        _mock_restore_tx,
        _mock_get_transactional,
    ):
        from handlers.payment_stripe import _restore_stock_and_cancel_order

        mock_pi_retrieve.return_value = Mock(status=StripeConstants.STATUS_REQUIRES_CAPTURE)

        order_ref = Mock()
        order_ref.get.return_value = _snap(
            {
                Fields.STOCK_RESTORED: False,
                Fields.STRIPE_PAYMENT_INTENT_ID: "pi_cap",
                Fields.ITEMS: [],
            },
            doc_id="o_cap",
        )
        orders_col = Mock()
        orders_col.document.return_value = order_ref
        security_col = Mock()

        db = Mock()
        db.transaction.return_value = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.SECURITY_ALERTS: security_col,
        }[name]
        mock_get_db.return_value = db

        _restore_stock_and_cancel_order("o_cap", {Fields.STRIPE_PAYMENT_INTENT_ID: "pi_cap"}, "stale checkout")

        mock_pi_cancel.assert_called_once()
        security_col.add.assert_not_called()
        order_ref.update.assert_not_called()

    @patch("handlers.payment_stripe.get_transactional", return_value=lambda fn: fn)
    @patch("handlers.payment_stripe._add_stock_restore_to_transaction")
    @patch("handlers.payment_stripe.stripe.PaymentIntent.cancel")
    @patch("handlers.payment_stripe.stripe.PaymentIntent.retrieve")
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("handlers.payment_stripe.get_db")
    def test_restore_and_cancel_order_unexpected_pi_status_marks_manual_review(
        self,
        mock_get_db,
        _mock_ts,
        _mock_ensure,
        mock_pi_retrieve,
        mock_pi_cancel,
        _mock_restore_tx,
        _mock_get_transactional,
    ):
        from handlers.payment_stripe import _restore_stock_and_cancel_order

        mock_pi_retrieve.return_value = Mock(status="canceled")

        order_ref = Mock()
        order_ref.get.return_value = _snap(
            {
                Fields.STOCK_RESTORED: False,
                Fields.STRIPE_PAYMENT_INTENT_ID: "pi_unexpected",
                Fields.ITEMS: [],
            },
            doc_id="o_unexpected",
        )
        orders_col = Mock()
        orders_col.document.return_value = order_ref
        security_col = Mock()

        db = Mock()
        db.transaction.return_value = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.SECURITY_ALERTS: security_col,
        }[name]
        mock_get_db.return_value = db

        _restore_stock_and_cancel_order(
            "o_unexpected",
            {Fields.STRIPE_PAYMENT_INTENT_ID: "pi_unexpected"},
            "post-checkout invalidation",
        )

        mock_pi_cancel.assert_not_called()
        security_col.add.assert_not_called()
        order_ref.update.assert_called_once()

    @patch("utils.helpers.get_charge_id_from_pi", side_effect=RuntimeError("charge parse failed"))
    @patch("handlers.payment_stripe._run_post_payment_side_effects")
    @patch("handlers.payment_stripe._execute_seller_payouts")
    @patch("handlers.payment_stripe.OrderEvent.write")
    @patch("handlers.payment_stripe.stripe.PaymentIntent.retrieve", return_value=Mock())
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("handlers.payment_stripe.get_db")
    def test_async_payment_succeeded_pi_lookup_failure_is_non_fatal(
        self,
        mock_get_db,
        _mock_ts,
        _mock_ensure,
        _mock_pi,
        _mock_event,
        mock_payouts,
        mock_side_effects,
        _mock_charge,
    ):
        from handlers.payment_stripe import process_async_payment_succeeded

        order_data = {
            Fields.PAYMENT_STATUS: PaymentStatusValues.AWAITING_PAYMENT,
            Fields.ORDER_STATUS: OrderStatusValues.PENDING,
            Fields.TOTAL_AMOUNT_CENTS: 1000,
            Fields.ITEMS: [{Fields.PRODUCT_ID: "prod_1", Fields.SELLER_ID: "seller_1"}],
            Fields.USER_ID: "buyer_1",
        }
        order_ref = Mock()
        order_ref.get.return_value = _snap(order_data, doc_id="order_async_pi_err")
        orders_col = Mock()
        orders_col.document.return_value = order_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.PRODUCTS: Mock(document=Mock(side_effect=lambda pid: Mock(id=pid))),
            Collections.USERS: Mock(document=Mock(side_effect=lambda uid: Mock(id=uid))),
        }[name]
        db.get_all.side_effect = [
            [_snap({Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE}, doc_id="prod_1")],
            [_snap({Fields.SUSPENDED: False}, doc_id="seller_1")],
        ]
        mock_get_db.return_value = db

        out = process_async_payment_succeeded(
            {
                StripeConstants.METADATA: {StripeConstants.METADATA_ORDER_ID: "order_async_pi_err"},
                StripeConstants.PAYMENT_INTENT: "pi_async_err",
                "amount_total": 1000,
            }
        )

        assert out == "Order order_async_pi_err payment captured"
        mock_payouts.assert_not_called()
        mock_side_effects.assert_called_once()

    @patch("handlers.payment_stripe.get_firestore")
    @patch("handlers.payment_stripe.get_db")
    def test_add_stock_restore_to_transaction_skips_digital_items(self, mock_get_db, mock_get_fs):
        from handlers.payment_stripe import _add_stock_restore_to_transaction

        mock_get_fs.return_value.Increment.side_effect = lambda n: ("inc", n)
        mock_get_db.return_value = Mock()
        tx = Mock()
        _add_stock_restore_to_transaction(
            tx,
            {
                Fields.ITEMS: [
                    {Fields.PRODUCT_ID: "d_1", Fields.QUANTITY: 1, Fields.IS_DIGITAL: True},
                ]
            },
        )
        tx.update.assert_not_called()
        tx.set.assert_not_called()

    @patch("handlers.payment_stripe.get_transactional", return_value=lambda fn: fn)
    @patch("handlers.payment_stripe._add_stock_restore_to_transaction")
    @patch("handlers.payment_stripe.get_db")
    def test_restore_and_cancel_order_transaction_order_missing_returns(
        self,
        mock_get_db,
        mock_restore_tx,
        _mock_get_transactional,
    ):
        from handlers.payment_stripe import _restore_stock_and_cancel_order

        order_ref = Mock()
        order_ref.get.return_value = _snap(exists=False, doc_id="o_missing")
        orders_col = Mock()
        orders_col.document.return_value = order_ref
        db = Mock()
        db.transaction.return_value = Mock()
        db.collection.side_effect = lambda name: {Collections.ORDERS: orders_col, Collections.SECURITY_ALERTS: Mock()}[name]
        mock_get_db.return_value = db

        _restore_stock_and_cancel_order("o_missing", {}, "missing")
        mock_restore_tx.assert_not_called()

    @patch("handlers.payment_stripe.get_transactional", return_value=lambda fn: fn)
    @patch("handlers.payment_stripe._add_stock_restore_to_transaction")
    @patch("handlers.payment_stripe.get_db")
    def test_restore_and_cancel_order_transaction_skips_when_stock_already_restored(
        self,
        mock_get_db,
        mock_restore_tx,
        _mock_get_transactional,
    ):
        from handlers.payment_stripe import _restore_stock_and_cancel_order

        order_ref = Mock()
        order_ref.get.return_value = _snap({Fields.STOCK_RESTORED: True}, doc_id="o_restored")
        orders_col = Mock()
        orders_col.document.return_value = order_ref
        db = Mock()
        db.transaction.return_value = Mock()
        db.collection.side_effect = lambda name: {Collections.ORDERS: orders_col, Collections.SECURITY_ALERTS: Mock()}[name]
        mock_get_db.return_value = db

        _restore_stock_and_cancel_order("o_restored", {}, "already restored")
        mock_restore_tx.assert_not_called()

    @patch("handlers.payment_stripe.get_transactional", return_value=lambda fn: fn)
    @patch("handlers.payment_stripe._add_stock_restore_to_transaction")
    @patch("handlers.payment_stripe.stripe.PaymentIntent.cancel")
    @patch("handlers.payment_stripe.stripe.PaymentIntent.retrieve")
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("handlers.payment_stripe.get_db")
    def test_restore_and_cancel_order_cancels_requires_payment_method_status(
        self,
        mock_get_db,
        _mock_ts,
        _mock_ensure,
        mock_pi_retrieve,
        mock_pi_cancel,
        _mock_restore_tx,
        _mock_get_transactional,
    ):
        from handlers.payment_stripe import _restore_stock_and_cancel_order

        mock_pi_retrieve.return_value = Mock(status="requires_payment_method")

        order_ref = Mock()
        order_ref.get.return_value = _snap({Fields.STOCK_RESTORED: False}, doc_id="o_req_pm")
        orders_col = Mock()
        orders_col.document.return_value = order_ref
        db = Mock()
        db.transaction.return_value = Mock()
        db.collection.side_effect = lambda name: {Collections.ORDERS: orders_col, Collections.SECURITY_ALERTS: Mock()}[name]
        mock_get_db.return_value = db

        _restore_stock_and_cancel_order("o_req_pm", {Fields.STRIPE_PAYMENT_INTENT_ID: "pi_req_pm"}, "invalidated")
        mock_pi_cancel.assert_called_once()
