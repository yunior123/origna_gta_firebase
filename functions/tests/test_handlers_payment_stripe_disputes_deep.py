from unittest.mock import Mock, patch

import pytest
from firebase_functions import https_fn

from schema_constants import (
    ApiKeys,
    Collections,
    DeliveryStatusValues,
    Fields,
    OrderStatusValues,
    PaymentStatusValues,
    PlatformDebtStatusValues,
    PayoutStatusValues,
    SecurityAlertTypes,
    StripeConstants,
)


def _snap(data=None, *, exists=True, doc_id="doc_1"):
    snap = Mock()
    snap.exists = exists
    snap.id = doc_id
    snap.to_dict.return_value = {} if data is None else data
    snap.reference = Mock()
    return snap


def _req(uid: str | None, data: dict, token: dict | None = None):
    req = Mock()
    req.auth = Mock(uid=uid, token=(token or {})) if uid else None
    req.data = data
    return req


class TestDisputeHandlersDeep:
    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("handlers.payment_stripe.enqueue_email_task")
    @patch("handlers.payment_stripe.stripe.Transfer.create_reversal")
    @patch("handlers.payment_stripe.get_db")
    def test_process_dispute_created_partial_reversal_and_seller_email(
        self,
        mock_get_db,
        mock_create_reversal,
        mock_email,
        _mock_ts,
    ):
        from handlers.payment_stripe import process_dispute_created

        mock_create_reversal.return_value = Mock(id="rev_1")

        alert_ref = Mock()
        security_col = Mock()
        security_col.add.return_value = ("wr", alert_ref)

        order_doc = _snap(
            {
                Fields.TOTAL_AMOUNT_CENTS: 1000,
                Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
                Fields.ITEMS: [{Fields.SELLER_ID: "seller_1"}],
            },
            doc_id="order_1",
        )

        orders_q = Mock()
        orders_q.where.return_value = orders_q
        orders_q.limit.return_value = orders_q
        orders_q.stream.return_value = [order_doc]
        orders_col = Mock()
        orders_col.where.return_value = orders_q

        payout_doc = _snap(
            {
                Fields.STRIPE_TRANSFER_ID: "tr_1",
                Fields.NET_AMOUNT_CENTS: 800,
                Fields.CUMULATIVE_REVERSED_CENTS: 0,
                Fields.SELLER_ID: "seller_1",
            },
            doc_id="payout_1",
        )

        payouts_q = Mock()
        payouts_q.where.return_value = payouts_q
        payouts_q.stream.return_value = [payout_doc]
        payouts_col = Mock()
        payouts_col.where.return_value = payouts_q

        seller_doc = _snap({Fields.EMAIL: "seller@example.com"})
        users_col = Mock()
        users_col.document.return_value.get.return_value = seller_doc

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.SECURITY_ALERTS: security_col,
            Collections.ORDERS: orders_col,
            Collections.PAYOUTS: payouts_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        dispute = {
            StripeConstants.OBJECT_ID: "dp_1",
            StripeConstants.CHARGE: "ch_1",
            StripeConstants.PAYMENT_INTENT: "pi_1",
            Fields.AMOUNT: 500,
            Fields.REASON: "fraudulent",
            StripeConstants.CURRENCY: "cad",
        }
        out = process_dispute_created(dispute)

        assert "reversed 1 transfers" in out
        # 500/1000 of payout net 800 => 400 proportional reversal
        assert mock_create_reversal.call_args.kwargs[Fields.AMOUNT] == 400
        payout_doc.reference.update.assert_called_once()
        order_doc.reference.update.assert_called_once()
        mock_email.assert_called_once()
        alert_ref.update.assert_called()

    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("handlers.payment_stripe.get_db")
    def test_process_dispute_created_without_payment_intent_returns_early(self, mock_get_db, _mock_ts):
        from handlers.payment_stripe import process_dispute_created

        security_col = Mock()
        security_col.add.return_value = ("wr", Mock())

        db = Mock()
        db.collection.return_value = security_col
        mock_get_db.return_value = db

        out = process_dispute_created({StripeConstants.CHARGE: "ch_1", Fields.AMOUNT: 100})
        assert "no payment_intent" in out

    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("handlers.payment_stripe.get_firestore")
    @patch("handlers.payment_stripe.get_db")
    def test_process_dispute_created_missing_transfer_id_records_reversal_error(
        self,
        mock_get_db,
        mock_get_firestore,
        _mock_ts,
    ):
        from handlers.payment_stripe import process_dispute_created

        mock_get_firestore.return_value.ArrayUnion.side_effect = lambda vals: ("au", vals)

        alert_ref = Mock()
        security_col = Mock()
        security_col.add.return_value = ("wr", alert_ref)

        order_doc = _snap(
            {
                Fields.TOTAL_AMOUNT_CENTS: 1000,
                Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
                Fields.ITEMS: [],
            },
            doc_id="order_1",
        )
        orders_q = Mock()
        orders_q.where.return_value = orders_q
        orders_q.limit.return_value = orders_q
        orders_q.stream.return_value = [order_doc]
        orders_col = Mock()
        orders_col.where.return_value = orders_q

        payout_doc = _snap(
            {
                Fields.NET_AMOUNT_CENTS: 800,
                Fields.CUMULATIVE_REVERSED_CENTS: 0,
                # No stripeTransferId on purpose
            },
            doc_id="payout_1",
        )
        payouts_q = Mock()
        payouts_q.where.return_value = payouts_q
        payouts_q.stream.return_value = [payout_doc]
        payouts_col = Mock()
        payouts_col.where.return_value = payouts_q

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.SECURITY_ALERTS: security_col,
            Collections.ORDERS: orders_col,
            Collections.PAYOUTS: payouts_col,
            Collections.USERS: Mock(),
        }[name]
        mock_get_db.return_value = db

        out = process_dispute_created(
            {
                StripeConstants.OBJECT_ID: "dp_2",
                StripeConstants.CHARGE: "ch_2",
                StripeConstants.PAYMENT_INTENT: "pi_2",
                Fields.AMOUNT: 500,
            }
        )

        assert "reversed 0 transfers" in out
        alert_ref.update.assert_called()

    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("handlers.payment_stripe.get_firestore")
    @patch("handlers.payment_stripe.stripe.Transfer.create_reversal")
    @patch("handlers.payment_stripe.get_db")
    def test_process_dispute_created_insufficient_funds_error_suspends_seller(
        self,
        mock_get_db,
        mock_create_reversal,
        mock_get_firestore,
        _mock_ts,
    ):
        from handlers import payment_stripe as hps
        from handlers.payment_stripe import process_dispute_created

        mock_get_firestore.return_value.ArrayUnion.side_effect = lambda vals: ("au", vals)
        mock_create_reversal.side_effect = hps.stripe.error.InvalidRequestError("insufficient funds")

        alert_ref = Mock()
        security_col = Mock()
        security_col.add.return_value = ("wr", alert_ref)

        order_doc = _snap(
            {
                Fields.TOTAL_AMOUNT_CENTS: 1000,
                Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
                Fields.ITEMS: [],
            },
            doc_id="order_3",
        )
        orders_q = Mock()
        orders_q.where.return_value = orders_q
        orders_q.limit.return_value = orders_q
        orders_q.stream.return_value = [order_doc]
        orders_col = Mock()
        orders_col.where.return_value = orders_q

        payout_doc = _snap(
            {
                Fields.STRIPE_TRANSFER_ID: "tr_fail",
                Fields.NET_AMOUNT_CENTS: 800,
                Fields.CUMULATIVE_REVERSED_CENTS: 0,
                Fields.SELLER_ID: "seller_fail",
            },
            doc_id="payout_fail",
        )
        payouts_q = Mock()
        payouts_q.where.return_value = payouts_q
        payouts_q.stream.return_value = [payout_doc]
        payouts_col = Mock()
        payouts_col.where.return_value = payouts_q

        users_col = Mock()
        users_col.document.return_value.update = Mock()

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.SECURITY_ALERTS: security_col,
            Collections.ORDERS: orders_col,
            Collections.PAYOUTS: payouts_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        out = process_dispute_created(
            {
                StripeConstants.OBJECT_ID: "dp_3",
                StripeConstants.CHARGE: "ch_3",
                StripeConstants.PAYMENT_INTENT: "pi_3",
                Fields.AMOUNT: 500,
            }
        )

        assert "reversed 0 transfers" in out
        assert users_col.document.return_value.update.called
        alert_ref.update.assert_called()

    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("handlers.payment_stripe.get_db")
    def test_process_dispute_updated_updates_alert_and_order(self, mock_get_db, _mock_ts):
        from handlers.payment_stripe import process_dispute_updated

        alert_doc = _snap({}, doc_id="alert_1")
        order_doc = _snap({}, doc_id="order_1")

        alerts_q = Mock()
        alerts_q.where.return_value = alerts_q
        alerts_q.limit.return_value = alerts_q
        alerts_q.stream.return_value = [alert_doc]

        orders_q = Mock()
        orders_q.where.return_value = orders_q
        orders_q.limit.return_value = orders_q
        orders_q.stream.return_value = [order_doc]

        sec_col = Mock()
        sec_col.where.return_value = alerts_q
        orders_col = Mock()
        orders_col.where.return_value = orders_q

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.SECURITY_ALERTS: sec_col,
            Collections.ORDERS: orders_col,
        }[name]
        mock_get_db.return_value = db

        out = process_dispute_updated(
            {
                StripeConstants.OBJECT_ID: "dp_1",
                StripeConstants.CHARGE: "ch_1",
                StripeConstants.PAYMENT_INTENT: "pi_1",
                Fields.STATUS: "under_review",
                Fields.REASON: "fraudulent",
            }
        )

        assert "dp_1" in out
        alert_doc.reference.update.assert_called_once()
        order_doc.reference.update.assert_called_once()

    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("handlers.payment_stripe.get_db")
    def test_process_dispute_funds_reinstated_logs_low_severity_alert(self, mock_get_db, _mock_ts):
        from handlers.payment_stripe import process_dispute_funds_reinstated

        security_col = Mock()
        db = Mock()
        db.collection.return_value = security_col
        mock_get_db.return_value = db

        out = process_dispute_funds_reinstated(
            {
                StripeConstants.OBJECT_ID: "dp_1",
                StripeConstants.CHARGE: "ch_1",
                StripeConstants.PAYMENT_INTENT: "pi_1",
                Fields.AMOUNT: 250,
            }
        )

        assert "Funds reinstated" in out
        payload = security_col.add.call_args.args[0]
        assert payload[Fields.TYPE] == SecurityAlertTypes.DISPUTE_FUNDS_REINSTATED
        assert payload[Fields.RESOLVED] is True

    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("services.email_task.enqueue_email_task")
    @patch("handlers.payment_stripe._get_seller_stripe_snapshot", return_value={"seller_1": "acct_1"})
    @patch("handlers.payment_stripe.stripe.Transfer.create")
    @patch("handlers.payment_stripe.get_db")
    def test_process_dispute_closed_won_retransfers_and_restores_order_status(
        self,
        mock_get_db,
        mock_transfer_create,
        _mock_snapshot,
        mock_email,
        _mock_ts,
    ):
        from handlers.payment_stripe import process_dispute_closed

        mock_transfer_create.return_value = Mock(id="tr_new")

        alert_doc = _snap({}, doc_id="alert_1")
        alerts_q = Mock()
        alerts_q.where.return_value = alerts_q
        alerts_q.limit.return_value = alerts_q
        alerts_q.stream.return_value = [alert_doc]
        sec_col = Mock()
        sec_col.where.return_value = alerts_q

        order_doc = _snap(
            {
                Fields.PRE_DISPUTE_STATUS: OrderStatusValues.CONFIRMED,
                Fields.ITEMS: [{Fields.SELLER_ID: "seller_1"}],
            },
            doc_id="order_1",
        )
        orders_q = Mock()
        orders_q.where.return_value = orders_q
        orders_q.limit.return_value = orders_q
        orders_q.stream.return_value = [order_doc]
        orders_col = Mock()
        orders_col.where.return_value = orders_q

        payout_doc = _snap(
            {
                Fields.SELLER_ID: "seller_1",
                Fields.CUMULATIVE_REVERSED_CENTS: 320,
            },
            doc_id="order_1_seller_1",
        )
        payouts_q = Mock()
        payouts_q.where.return_value = payouts_q
        payouts_q.limit.return_value = payouts_q
        payouts_q.stream.return_value = [payout_doc]
        payouts_col = Mock()
        payouts_col.where.return_value = payouts_q

        seller_doc = _snap({Fields.EMAIL: "seller@example.com"})
        users_col = Mock()
        users_col.document.return_value.get.return_value = seller_doc

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.SECURITY_ALERTS: sec_col,
            Collections.ORDERS: orders_col,
            Collections.PAYOUTS: payouts_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        out = process_dispute_closed(
            {
                StripeConstants.CHARGE: "ch_1",
                StripeConstants.PAYMENT_INTENT: "pi_1",
                StripeConstants.OBJECT_ID: "dp_1",
                Fields.STATUS: "won",
            }
        )

        assert out == "Dispute closed: won"
        alert_doc.reference.update.assert_called_once()
        payout_doc.reference.update.assert_called_once()
        order_doc.reference.update.assert_called_once()
        mock_transfer_create.assert_called_once()
        mock_email.assert_called_once()

    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("handlers.payment_stripe._get_seller_stripe_snapshot", return_value={"seller_1": "acct_1"})
    @patch("handlers.payment_stripe.stripe.Transfer.create", side_effect=RuntimeError("transfer failed"))
    @patch("handlers.payment_stripe.get_db")
    def test_process_dispute_closed_won_retransfer_failure_logs_security_alert(
        self,
        mock_get_db,
        _mock_transfer,
        _mock_snapshot,
        _mock_ts,
    ):
        from handlers.payment_stripe import process_dispute_closed

        alert_doc = _snap({}, doc_id="alert_1")
        alerts_q = Mock()
        alerts_q.where.return_value = alerts_q
        alerts_q.limit.return_value = alerts_q
        alerts_q.stream.return_value = [alert_doc]

        sec_col = Mock()
        sec_col.where.return_value = alerts_q

        order_doc = _snap({Fields.PRE_DISPUTE_STATUS: OrderStatusValues.CONFIRMED, Fields.ITEMS: []}, doc_id="order_1")
        orders_q = Mock()
        orders_q.where.return_value = orders_q
        orders_q.limit.return_value = orders_q
        orders_q.stream.return_value = [order_doc]
        orders_col = Mock()
        orders_col.where.return_value = orders_q

        payout_doc = _snap({Fields.SELLER_ID: "seller_1", Fields.CUMULATIVE_REVERSED_CENTS: 200}, doc_id="order_1_seller_1")
        payouts_q = Mock()
        payouts_q.where.return_value = payouts_q
        payouts_q.limit.return_value = payouts_q
        payouts_q.stream.return_value = [payout_doc]
        payouts_col = Mock()
        payouts_col.where.return_value = payouts_q

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.SECURITY_ALERTS: sec_col,
            Collections.ORDERS: orders_col,
            Collections.PAYOUTS: payouts_col,
            Collections.USERS: Mock(),
        }[name]
        mock_get_db.return_value = db

        out = process_dispute_closed(
            {
                StripeConstants.CHARGE: "ch_1",
                StripeConstants.PAYMENT_INTENT: "pi_1",
                StripeConstants.OBJECT_ID: "dp_1",
                Fields.STATUS: "won",
            }
        )

        assert out == "Dispute closed: won"
        assert sec_col.add.called


class TestRefundAndCaptureDeep:
    @patch("handlers.payment_stripe.get_db")
    def test_process_charge_refunded_blocks_transitional_payment_status(self, mock_get_db):
        from handlers.payment_stripe import process_charge_refunded

        order_doc = _snap({Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURING}, doc_id="order_1")
        orders_q = Mock()
        orders_q.where.return_value = orders_q
        orders_q.limit.return_value = orders_q
        orders_q.stream.return_value = [order_doc]
        orders_col = Mock()
        orders_col.where.return_value = orders_q

        db = Mock()
        db.collection.return_value = orders_col
        mock_get_db.return_value = db

        with pytest.raises(Exception):
            process_charge_refunded(
                {
                    StripeConstants.PAYMENT_INTENT: "pi_1",
                    "amount_refunded": 500,
                    Fields.AMOUNT: 500,
                }
            )

    @patch("handlers.payment_stripe.get_db")
    def test_process_charge_refunded_idempotent_when_already_counted(self, mock_get_db):
        from handlers.payment_stripe import process_charge_refunded

        order_doc = _snap(
            {
                Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
                Fields.CUMULATIVE_REFUNDED_CENTS: 700,
            },
            doc_id="order_1",
        )
        orders_q = Mock()
        orders_q.where.return_value = orders_q
        orders_q.limit.return_value = orders_q
        orders_q.stream.return_value = [order_doc]
        orders_col = Mock()
        orders_col.where.return_value = orders_q

        db = Mock()
        db.collection.return_value = orders_col
        mock_get_db.return_value = db

        out = process_charge_refunded(
            {
                StripeConstants.PAYMENT_INTENT: "pi_1",
                "amount_refunded": 500,
                Fields.AMOUNT: 1000,
            }
        )
        assert "already processed" in out

    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("handlers.payment_stripe.stripe.Transfer.create_reversal")
    @patch("handlers.digital._revoke_digital_licenses_for_order", return_value=0)
    @patch("handlers.payment_stripe.get_db")
    def test_process_charge_refunded_partial_success_tracks_cumulative_reversed(
        self,
        mock_get_db,
        _mock_revoke,
        mock_reversal,
        _mock_ts,
    ):
        from handlers.payment_stripe import process_charge_refunded

        mock_reversal.return_value = Mock(id="rev_ok")

        order_ref = Mock()
        order_doc = _snap(
            {
                Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
                Fields.CUMULATIVE_REFUNDED_CENTS: 0,
                Fields.SUBTOTAL_CENTS: 1000,
            },
            doc_id="order_partial",
        )
        order_doc.reference = order_ref

        orders_q = Mock()
        orders_q.where.return_value = orders_q
        orders_q.limit.return_value = orders_q
        orders_q.stream.return_value = [order_doc]
        orders_col = Mock()
        orders_col.where.return_value = orders_q

        payout_doc = _snap(
            {
                Fields.STRIPE_TRANSFER_ID: "tr_partial",
                Fields.CUMULATIVE_REVERSED_CENTS: 100,
                Fields.NET_AMOUNT_CENTS: 1000,
                Fields.SELLER_ID: "seller_1",
            },
            doc_id="payout_partial",
        )
        payouts_q = Mock()
        payouts_q.where.return_value = payouts_q
        payouts_q.limit.return_value = payouts_q
        payouts_q.stream.return_value = [payout_doc]
        payouts_col = Mock()
        payouts_col.where.return_value = payouts_q

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.PAYOUTS: payouts_col,
            Collections.SECURITY_ALERTS: Mock(),
            Collections.USERS: Mock(),
            Collections.PLATFORM_DEBT: Mock(),
        }[name]
        mock_get_db.return_value = db

        out = process_charge_refunded(
            {
                StripeConstants.PAYMENT_INTENT: "pi_partial",
                "amount_refunded": 300,
                Fields.AMOUNT: 1000,
            }
        )

        # cumulative_target=300, already_reversed=100 => delta=200
        assert mock_reversal.call_args.kwargs[Fields.AMOUNT] == 200
        payout_doc.reference.update.assert_called_once()
        assert "partially refunded" in out

    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("handlers.payment_stripe._restore_stock_for_order")
    @patch("handlers.payment_stripe.stripe.Transfer.create_reversal", return_value=Mock(id="rev_full"))
    @patch("handlers.digital._revoke_digital_licenses_for_order", return_value=1)
    @patch("handlers.payment_stripe.get_db")
    def test_process_charge_refunded_full_refund_restores_stock_when_needed(
        self,
        mock_get_db,
        _mock_revoke,
        _mock_reversal,
        mock_restore_stock,
        _mock_ts,
    ):
        from handlers.payment_stripe import process_charge_refunded

        order_ref = Mock()
        order_doc = _snap(
            {
                Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
                Fields.CUMULATIVE_REFUNDED_CENTS: 0,
                Fields.STOCK_RESTORED: False,
                Fields.SUBTOTAL_CENTS: 1000,
            },
            doc_id="order_full",
        )
        order_doc.reference = order_ref

        orders_q = Mock()
        orders_q.where.return_value = orders_q
        orders_q.limit.return_value = orders_q
        orders_q.stream.return_value = [order_doc]
        orders_col = Mock()
        orders_col.where.return_value = orders_q

        payout_doc = _snap(
            {
                Fields.STRIPE_TRANSFER_ID: "tr_full",
                Fields.CUMULATIVE_REVERSED_CENTS: 0,
                Fields.NET_AMOUNT_CENTS: 900,
                Fields.SELLER_ID: "seller_1",
            },
            doc_id="payout_full",
        )
        payouts_q = Mock()
        payouts_q.where.return_value = payouts_q
        payouts_q.limit.return_value = payouts_q
        payouts_q.stream.return_value = [payout_doc]
        payouts_col = Mock()
        payouts_col.where.return_value = payouts_q

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.PAYOUTS: payouts_col,
            Collections.SECURITY_ALERTS: Mock(),
            Collections.USERS: Mock(),
            Collections.PLATFORM_DEBT: Mock(),
        }[name]
        mock_get_db.return_value = db

        out = process_charge_refunded(
            {
                StripeConstants.PAYMENT_INTENT: "pi_full",
                "amount_refunded": 1000,
                Fields.AMOUNT: 1000,
            }
        )

        mock_restore_stock.assert_called_once()
        order_ref.update.assert_called_once()
        assert "fully refunded" in out

    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("handlers.payment_stripe.stripe.Transfer.create_reversal", side_effect=RuntimeError("reversal failed"))
    @patch("handlers.digital._revoke_digital_licenses_for_order", return_value=0)
    @patch("handlers.payment_stripe.get_db")
    def test_process_charge_refunded_reversal_failure_suspends_seller_and_tracks_platform_debt(
        self,
        mock_get_db,
        _mock_revoke,
        _mock_reversal,
        _mock_ts,
    ):
        from handlers.payment_stripe import process_charge_refunded

        order_ref = Mock()
        order_doc = _snap(
            {
                Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
                Fields.CUMULATIVE_REFUNDED_CENTS: 0,
                Fields.STOCK_RESTORED: True,
                Fields.SUBTOTAL_CENTS: 1000,
            },
            doc_id="order_1",
        )
        order_ref.get.return_value = order_doc
        order_doc.reference = order_ref

        orders_q = Mock()
        orders_q.where.return_value = orders_q
        orders_q.limit.return_value = orders_q
        orders_q.stream.return_value = [order_doc]
        orders_col = Mock()
        orders_col.where.return_value = orders_q

        payout_doc = _snap(
            {
                Fields.STRIPE_TRANSFER_ID: "tr_1",
                Fields.CUMULATIVE_REVERSED_CENTS: 0,
                Fields.NET_AMOUNT_CENTS: 900,
                Fields.SELLER_ID: "seller_1",
                Fields.AMOUNT_CENTS: 900,
            },
            doc_id="payout_1",
        )

        failed_lookup_doc = _snap({Fields.SELLER_ID: "seller_1", Fields.AMOUNT_CENTS: 900}, doc_id="payout_lookup")

        payouts_q = Mock()
        payouts_q.where.return_value = payouts_q
        payouts_q.limit.return_value = payouts_q
        payouts_q.stream.return_value = [payout_doc]
        payouts_q.get.return_value = [failed_lookup_doc]
        payouts_col = Mock()
        payouts_col.where.return_value = payouts_q

        users_col = Mock()
        users_col.document.return_value.update = Mock()

        security_col = Mock()
        platform_debt_col = Mock()

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.PAYOUTS: payouts_col,
            Collections.USERS: users_col,
            Collections.SECURITY_ALERTS: security_col,
            Collections.PLATFORM_DEBT: platform_debt_col,
        }[name]
        mock_get_db.return_value = db

        out = process_charge_refunded(
            {
                StripeConstants.PAYMENT_INTENT: "pi_1",
                "amount_refunded": 1000,
                Fields.AMOUNT: 1000,
            }
        )

        assert "fully refunded" in out
        assert security_col.add.called
        assert users_col.document.return_value.update.called
        assert platform_debt_col.add.called
        order_ref.update.assert_called_once()

    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("utils.helpers.get_charge_id_from_pi", return_value="ch_1")
    @patch("handlers.payment_stripe.stripe.PaymentIntent.retrieve")
    @patch("handlers.payment_stripe.stripe.Transfer.create")
    @patch("handlers.payment_stripe._get_seller_stripe_snapshot", return_value={"seller_1": "acct_1"})
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_providers.require_provider_enabled")
    @patch("handlers.payment_stripe.get_db")
    def test_capture_payment_impl_already_captured_creates_missing_payout_records(
        self,
        mock_get_db,
        _mock_provider,
        _mock_ensure,
        _mock_snapshot,
        mock_transfer_create,
        _mock_pi_retrieve,
        _mock_charge,
        _mock_ts,
    ):
        from handlers.payment_stripe import _capture_payment_impl

        mock_transfer_create.return_value = Mock(id="tr_1")

        order_ref = Mock()
        order_ref.get.return_value = _snap(
            {
                Fields.USER_ID: "buyer_1",
                Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
                Fields.ORDER_STATUS: OrderStatusValues.DELIVERED,
                Fields.CONFIRMED_BY_CLIENT: False,
                Fields.STRIPE_PAYMENT_INTENT_ID: "pi_1",
                Fields.ITEMS: [
                    {
                        Fields.SELLER_ID: "seller_1",
                        Fields.PRICE: 10.0,
                        Fields.QUANTITY: 2,
                        Fields.STATUS: "delivered",
                    }
                ],
                Fields.SUBTOTAL_CENTS: 2000,
                Fields.DISCOUNT_AMOUNT_CENTS: 0,
            },
            doc_id="order_1",
        )

        orders_col = Mock()
        orders_col.document.return_value = order_ref

        payout_ref = Mock()
        payout_ref.get.return_value = _snap(exists=False)
        payouts_col = Mock()
        payouts_col.document.return_value = payout_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.PAYOUTS: payouts_col,
            Collections.SELLER_PROFILES: Mock(),
        }[name]
        mock_get_db.return_value = db

        req = _req("buyer_1", {Fields.ORDER_ID: "order_1"}, token={})
        out = _capture_payment_impl(req)

        assert out[ApiKeys.SUCCESS] is True
        assert out[ApiKeys.CAPTURED] is True
        order_ref.update.assert_called_once()
        payout_ref.set.assert_called_once()
        payout_ref.update.assert_called_once()

    @patch("time.sleep", return_value=None)
    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("utils.helpers.get_charge_id_from_pi", return_value="ch_1")
    @patch("handlers.payment_stripe.stripe.Transfer.create")
    @patch("handlers.payment_stripe.stripe.Charge.retrieve")
    @patch("handlers.payment_stripe.stripe.PaymentIntent.capture")
    @patch("handlers.payment_stripe.stripe.PaymentIntent.retrieve")
    @patch(
        "handlers.payment_stripe._get_seller_stripe_snapshot",
        return_value={
            "seller_1": "acct_snap_1",
            "seller_2": "acct_2",
            "seller_4": "acct_4",
            "seller_5": "acct_err",
            "seller_6": "acct_6",
        },
    )
    @patch("handlers.payment_stripe.get_transactional", return_value=lambda fn: fn)
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_providers.require_provider_enabled")
    @patch("handlers.payment_stripe.get_db")
    def test_capture_payment_impl_authorized_payout_loop_handles_multi_seller_edge_cases(
        self,
        mock_get_db,
        _mock_provider,
        _mock_ensure,
        _mock_get_transactional,
        _mock_snapshot,
        mock_pi_retrieve,
        mock_pi_capture,
        mock_charge_retrieve,
        mock_transfer_create,
        _mock_charge_id,
        _mock_ts,
        _mock_sleep,
    ):
        from handlers.payment_stripe import _capture_payment_impl

        mock_pi_retrieve.return_value = Mock(status=StripeConstants.STATUS_REQUIRES_CAPTURE, amount=6000)
        mock_pi_capture.return_value = Mock(id="pi_3_test")
        mock_charge_retrieve.return_value = Mock(dispute=None)

        def transfer_side_effect(**kwargs):
            if kwargs.get("destination") == "acct_err":
                raise RuntimeError("transfer failed")
            return Mock(id=f"tr_{kwargs.get('destination')}")

        mock_transfer_create.side_effect = transfer_side_effect

        items = [
            {
                Fields.SELLER_ID: "seller_1",
                Fields.PRICE: 10.0,
                Fields.QUANTITY: 1,
                Fields.STATUS: DeliveryStatusValues.DELIVERED,
            },
            {
                Fields.SELLER_ID: "seller_2",
                Fields.PRICE: 10.0,
                Fields.QUANTITY: 1,
                Fields.STATUS: DeliveryStatusValues.DELIVERED,
            },
            {
                Fields.SELLER_ID: "seller_3",
                Fields.PRICE: 10.0,
                Fields.QUANTITY: 1,
                Fields.STATUS: DeliveryStatusValues.DELIVERED,
            },
            {
                Fields.SELLER_ID: "seller_4",
                Fields.PRICE: 10.0,
                Fields.QUANTITY: 1,
                Fields.STATUS: DeliveryStatusValues.DELIVERED,
            },
            {
                Fields.SELLER_ID: "seller_5",
                Fields.PRICE: 10.0,
                Fields.QUANTITY: 1,
                Fields.STATUS: DeliveryStatusValues.DELIVERED,
            },
            {
                Fields.SELLER_ID: "seller_6",
                Fields.PRICE: 10.0,
                Fields.QUANTITY: 1,
                Fields.STATUS: DeliveryStatusValues.DELIVERED,
            },
        ]

        order_ref = Mock()
        order_ref.get.return_value = _snap(
            {
                Fields.USER_ID: "buyer_1",
                Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
                Fields.ORDER_STATUS: OrderStatusValues.SHIPPED,
                Fields.STRIPE_PAYMENT_INTENT_ID: "pi_3_test",
                Fields.CAPTURE_ATTEMPTS: 0,
                Fields.TOTAL_AMOUNT_CENTS: 6000,
                Fields.SUBTOTAL_CENTS: 6000,
                Fields.DISCOUNT_AMOUNT_CENTS: 600,
                Fields.COUPON_SELLER_ID: "seller_1",
                Fields.PLATFORM_FEE_RATIO: 0.1,
                Fields.ITEMS: items,
            },
            doc_id="order_1",
        )
        orders_col = Mock()
        orders_col.document.return_value = order_ref

        sec_query = Mock()
        sec_query.where.return_value = sec_query
        sec_query.limit.return_value = sec_query
        sec_query.get.return_value = []
        security_col = Mock()
        security_col.where.return_value = sec_query

        users_by_id = {
            "seller_1": _snap({Fields.SUSPENDED: False}, doc_id="seller_1"),
            "seller_2": _snap({Fields.SUSPENDED: True}, doc_id="seller_2"),
            "seller_3": _snap({Fields.SUSPENDED: False}, doc_id="seller_3"),
            "seller_4": _snap({Fields.SUSPENDED: False}, doc_id="seller_4"),
            "seller_5": _snap({Fields.SUSPENDED: False}, doc_id="seller_5"),
            "seller_6": _snap({Fields.SUSPENDED: False}, doc_id="seller_6"),
        }
        users_col = Mock()
        users_col.document.side_effect = lambda uid: Mock(get=Mock(return_value=users_by_id[uid]))

        sp_by_id = {
            "seller_1": _snap({Fields.STRIPE_ACCOUNT_ID: "acct_live_1", Fields.CHARGES_ENABLED: True}, doc_id="seller_1"),
            "seller_2": _snap({Fields.STRIPE_ACCOUNT_ID: "acct_2", Fields.CHARGES_ENABLED: True}, doc_id="seller_2"),
            "seller_3": _snap({Fields.CHARGES_ENABLED: True}, doc_id="seller_3"),
            "seller_4": _snap({Fields.STRIPE_ACCOUNT_ID: "acct_4", Fields.CHARGES_ENABLED: False}, doc_id="seller_4"),
            "seller_5": _snap({Fields.STRIPE_ACCOUNT_ID: "acct_err", Fields.CHARGES_ENABLED: True}, doc_id="seller_5"),
            "seller_6": _snap({Fields.STRIPE_ACCOUNT_ID: "acct_6", Fields.CHARGES_ENABLED: True}, doc_id="seller_6"),
        }
        seller_profiles_col = Mock()
        seller_profiles_col.document.side_effect = lambda uid: Mock(get=Mock(return_value=sp_by_id[uid]))

        current_seller = {"id": None}
        payout_query = Mock()

        def payout_where(field, _op, value):
            if field == Fields.SELLER_ID:
                current_seller["id"] = value
            return payout_query

        payout_query.where.side_effect = payout_where
        payout_query.limit.return_value = payout_query
        payout_query.get.side_effect = lambda: [_snap({}, doc_id="existing")] if current_seller["id"] == "seller_6" else []

        payout_refs = {
            "order_1_seller_1": Mock(),
            "order_1_seller_5": Mock(),
        }
        payout_refs["order_1_seller_1"].update.side_effect = [Exception("fs1"), Exception("fs2"), Exception("fs3")]

        payouts_col = Mock()
        payouts_col.where.side_effect = payout_where
        payouts_col.document.side_effect = lambda doc_id: payout_refs.setdefault(doc_id, Mock())

        db = Mock()
        db.transaction.return_value = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.SECURITY_ALERTS: security_col,
            Collections.USERS: users_col,
            Collections.SELLER_PROFILES: seller_profiles_col,
            Collections.PAYOUTS: payouts_col,
        }[name]
        mock_get_db.return_value = db

        out = _capture_payment_impl(_req("buyer_1", {Fields.ORDER_ID: "order_1"}, token={}))

        assert out[ApiKeys.SUCCESS] is True
        assert out[ApiKeys.CAPTURED] is True
        assert out[Fields.PAYOUT_ERRORS] is True
        assert security_col.add.call_count >= 2
        assert payout_refs["order_1_seller_1"].set.called
        assert payout_refs["order_1_seller_1"].update.call_count == 3
        final_update = order_ref.update.call_args_list[-1].args[0]
        assert final_update[Fields.PAYMENT_STATUS] == PaymentStatusValues.CAPTURED
        assert final_update[Fields.REQUIRES_MANUAL_REVIEW] is True
        assert final_update[Fields.PAYOUT_ERRORS][0][Fields.SELLER_ID] == "seller_5"

    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("utils.helpers.get_charge_id_from_pi", return_value="ch_1")
    @patch("handlers.payment_stripe.stripe.Charge.retrieve")
    @patch("handlers.payment_stripe.stripe.PaymentIntent.capture")
    @patch("handlers.payment_stripe.stripe.PaymentIntent.retrieve")
    @patch("handlers.payment_stripe.get_transactional", return_value=lambda fn: fn)
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_providers.require_provider_enabled")
    @patch("handlers.payment_stripe.get_db")
    def test_capture_payment_impl_disputed_charge_rolls_back_status(
        self,
        mock_get_db,
        _mock_provider,
        _mock_ensure,
        _mock_get_transactional,
        mock_pi_retrieve,
        mock_pi_capture,
        mock_charge_retrieve,
        _mock_charge_id,
        _mock_ts,
    ):
        from handlers.payment_stripe import _capture_payment_impl

        mock_pi_retrieve.return_value = Mock(status=StripeConstants.STATUS_REQUIRES_CAPTURE, amount=1000)
        mock_pi_capture.return_value = Mock(id="pi_3_test_dispute")
        mock_charge_retrieve.return_value = Mock(dispute="dp_live")

        order_ref = Mock()
        order_ref.get.return_value = _snap(
            {
                Fields.USER_ID: "buyer_1",
                Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
                Fields.ORDER_STATUS: OrderStatusValues.SHIPPED,
                Fields.STRIPE_PAYMENT_INTENT_ID: "pi_3_test_dispute",
                Fields.CAPTURE_ATTEMPTS: 0,
                Fields.TOTAL_AMOUNT_CENTS: 1000,
                Fields.ITEMS: [
                    {
                        Fields.SELLER_ID: "seller_1",
                        Fields.PRICE: 10.0,
                        Fields.QUANTITY: 1,
                        Fields.STATUS: DeliveryStatusValues.DELIVERED,
                    }
                ],
            },
            doc_id="order_dispute",
        )
        orders_col = Mock()
        orders_col.document.return_value = order_ref

        sec_query = Mock()
        sec_query.where.return_value = sec_query
        sec_query.limit.return_value = sec_query
        sec_query.get.return_value = []
        security_col = Mock()
        security_col.where.return_value = sec_query

        db = Mock()
        db.transaction.return_value = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.SECURITY_ALERTS: security_col,
        }[name]
        mock_get_db.return_value = db

        with pytest.raises(https_fn.HttpsError) as exc:
            _capture_payment_impl(_req("buyer_1", {Fields.ORDER_ID: "order_dispute"}, token={}))

        assert exc.value.code == "failed-precondition"
        disputed_payload = order_ref.update.call_args_list[0].args[0]
        rollback_payload = order_ref.update.call_args_list[-1].args[0]
        assert disputed_payload[Fields.PAYMENT_STATUS] == PaymentStatusValues.DISPUTED
        assert rollback_payload[Fields.PAYMENT_STATUS] == PaymentStatusValues.AUTHORIZED

    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_providers.require_provider_enabled")
    @patch("handlers.payment_stripe.get_db")
    def test_capture_payment_impl_rejects_non_authorized_payment_status(
        self,
        mock_get_db,
        _mock_provider,
        _mock_key,
    ):
        from handlers.payment_stripe import _capture_payment_impl

        order_ref = Mock()
        order_ref.get.return_value = _snap(
            {
                Fields.USER_ID: "buyer_1",
                Fields.PAYMENT_STATUS: PaymentStatusValues.AWAITING_PAYMENT,
                Fields.ORDER_STATUS: OrderStatusValues.SHIPPED,
            },
            doc_id="order_bad_status",
        )
        orders_col = Mock()
        orders_col.document.return_value = order_ref
        db = Mock()
        db.collection.return_value = orders_col
        mock_get_db.return_value = db

        with pytest.raises(https_fn.HttpsError) as exc:
            _capture_payment_impl(_req("buyer_1", {Fields.ORDER_ID: "order_bad_status"}, token={}))
        assert exc.value.code == "failed-precondition"

    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_providers.require_provider_enabled")
    @patch("handlers.payment_stripe.get_db")
    def test_capture_payment_impl_blocks_active_dispute(
        self,
        mock_get_db,
        _mock_provider,
        _mock_key,
    ):
        from handlers.payment_stripe import _capture_payment_impl

        order_ref = Mock()
        order_ref.get.return_value = _snap(
            {
                Fields.USER_ID: "buyer_1",
                Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
                Fields.ORDER_STATUS: OrderStatusValues.SHIPPED,
                Fields.STRIPE_PAYMENT_INTENT_ID: "pi_1",
                Fields.CAPTURE_ATTEMPTS: 0,
            },
            doc_id="order_dispute_block",
        )
        orders_col = Mock()
        orders_col.document.return_value = order_ref

        sec_q = Mock()
        sec_q.where.return_value = sec_q
        sec_q.limit.return_value = sec_q
        sec_q.get.return_value = [_snap({}, doc_id="alert")]
        sec_col = Mock()
        sec_col.where.return_value = sec_q

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.SECURITY_ALERTS: sec_col,
        }[name]
        mock_get_db.return_value = db

        with pytest.raises(https_fn.HttpsError) as exc:
            _capture_payment_impl(_req("buyer_1", {Fields.ORDER_ID: "order_dispute_block"}, token={}))
        assert exc.value.code == "failed-precondition"

    @patch("handlers.payment_stripe.get_transactional", return_value=lambda fn: fn)
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_providers.require_provider_enabled")
    @patch("handlers.payment_stripe.get_db")
    def test_capture_payment_impl_lock_returns_already_captured_payload(
        self,
        mock_get_db,
        _mock_provider,
        _mock_key,
        _mock_get_txn,
    ):
        from handlers.payment_stripe import _capture_payment_impl

        order_ref = Mock()
        order_ref.get.side_effect = [
            _snap(
                {
                    Fields.USER_ID: "buyer_1",
                    Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
                    Fields.ORDER_STATUS: OrderStatusValues.SHIPPED,
                    Fields.STRIPE_PAYMENT_INTENT_ID: "pi_lock",
                    Fields.CAPTURE_ATTEMPTS: 0,
                },
                doc_id="order_lock",
            ),
            _snap(
                {
                    Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
                    Fields.CAPTURE_ATTEMPTS: 1,
                },
                doc_id="order_lock",
            ),
        ]
        orders_col = Mock()
        orders_col.document.return_value = order_ref

        sec_q = Mock()
        sec_q.where.return_value = sec_q
        sec_q.limit.return_value = sec_q
        sec_q.get.return_value = []
        sec_col = Mock()
        sec_col.where.return_value = sec_q

        db = Mock()
        db.transaction.return_value = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.SECURITY_ALERTS: sec_col,
        }[name]
        mock_get_db.return_value = db

        out = _capture_payment_impl(_req("buyer_1", {Fields.ORDER_ID: "order_lock"}, token={}))
        assert out[ApiKeys.SUCCESS] is True
        assert out[ApiKeys.CAPTURED] is True

    @patch("handlers.payment_stripe.get_transactional", return_value=lambda fn: fn)
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_providers.require_provider_enabled")
    @patch("handlers.payment_stripe.get_db")
    def test_capture_payment_impl_lock_missing_or_changed_status_errors(
        self,
        mock_get_db,
        _mock_provider,
        _mock_key,
        _mock_get_txn,
    ):
        from handlers.payment_stripe import _capture_payment_impl

        order_ref = Mock()
        order_ref.get.side_effect = [
            _snap(
                {
                    Fields.USER_ID: "buyer_1",
                    Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
                    Fields.ORDER_STATUS: OrderStatusValues.SHIPPED,
                    Fields.STRIPE_PAYMENT_INTENT_ID: "pi_lock_err",
                    Fields.CAPTURE_ATTEMPTS: 0,
                },
                doc_id="order_lock_err",
            ),
            _snap(exists=False, doc_id="order_lock_err"),
        ]
        orders_col = Mock()
        orders_col.document.return_value = order_ref

        sec_q = Mock()
        sec_q.where.return_value = sec_q
        sec_q.limit.return_value = sec_q
        sec_q.get.return_value = []
        sec_col = Mock()
        sec_col.where.return_value = sec_q

        db = Mock()
        db.transaction.return_value = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.SECURITY_ALERTS: sec_col,
        }[name]
        mock_get_db.return_value = db

        with pytest.raises(https_fn.HttpsError) as missing_exc:
            _capture_payment_impl(_req("buyer_1", {Fields.ORDER_ID: "order_lock_err"}, token={}))
        assert missing_exc.value.code == "not-found"

        order_ref.get.side_effect = [
            _snap(
                {
                    Fields.USER_ID: "buyer_1",
                    Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
                    Fields.ORDER_STATUS: OrderStatusValues.SHIPPED,
                    Fields.STRIPE_PAYMENT_INTENT_ID: "pi_lock_err",
                    Fields.CAPTURE_ATTEMPTS: 0,
                },
                doc_id="order_lock_err2",
            ),
            _snap({Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURING}, exists=True, doc_id="order_lock_err2"),
        ]

        with pytest.raises(https_fn.HttpsError) as changed_exc:
            _capture_payment_impl(_req("buyer_1", {Fields.ORDER_ID: "order_lock_err2"}, token={}))
        assert changed_exc.value.code == "failed-precondition"

    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("handlers.payment_stripe.IS_EMULATOR", False)
    @patch("handlers.payment_stripe.get_transactional", return_value=lambda fn: fn)
    @patch("handlers.payment_stripe.stripe.PaymentIntent.capture")
    @patch("handlers.payment_stripe.stripe.PaymentIntent.retrieve")
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_providers.require_provider_enabled")
    @patch("handlers.payment_stripe.get_db")
    def test_capture_payment_impl_amount_mismatch_and_no_charge_paths(
        self,
        mock_get_db,
        _mock_provider,
        _mock_key,
        mock_pi_retrieve,
        mock_pi_capture,
        _mock_get_txn,
        _mock_ts,
    ):
        from handlers.payment_stripe import _capture_payment_impl

        order_ref = Mock()
        order_ref.get.side_effect = [
            _snap(
                {
                    Fields.USER_ID: "buyer_1",
                    Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
                    Fields.ORDER_STATUS: OrderStatusValues.SHIPPED,
                    Fields.STRIPE_PAYMENT_INTENT_ID: "pi_amt",
                    Fields.CAPTURE_ATTEMPTS: 0,
                    Fields.TOTAL_AMOUNT_CENTS: 1000,
                    Fields.ITEMS: [],
                },
                doc_id="order_amt",
            ),
            _snap({Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED, Fields.CAPTURE_ATTEMPTS: 0}, doc_id="order_amt"),
        ]
        orders_col = Mock()
        orders_col.document.return_value = order_ref

        sec_q = Mock()
        sec_q.where.return_value = sec_q
        sec_q.limit.return_value = sec_q
        sec_q.get.return_value = []
        sec_col = Mock()
        sec_col.where.return_value = sec_q

        db = Mock()
        db.transaction.return_value = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.SECURITY_ALERTS: sec_col,
        }[name]
        mock_get_db.return_value = db

        mock_pi_retrieve.return_value = Mock(status=StripeConstants.STATUS_REQUIRES_CAPTURE, amount=999)
        with pytest.raises(https_fn.HttpsError) as amt_exc:
            _capture_payment_impl(_req("buyer_1", {Fields.ORDER_ID: "order_amt"}, token={}))
        assert amt_exc.value.code == "failed-precondition"

        order_ref.get.side_effect = [
            _snap(
                {
                    Fields.USER_ID: "buyer_1",
                    Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
                    Fields.ORDER_STATUS: OrderStatusValues.SHIPPED,
                    Fields.STRIPE_PAYMENT_INTENT_ID: "pi_no_charge",
                    Fields.CAPTURE_ATTEMPTS: 0,
                    Fields.TOTAL_AMOUNT_CENTS: 1000,
                    Fields.ITEMS: [],
                },
                doc_id="order_no_charge",
            ),
            _snap({Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED, Fields.CAPTURE_ATTEMPTS: 0}, doc_id="order_no_charge"),
        ]
        mock_pi_retrieve.return_value = Mock(status=StripeConstants.STATUS_REQUIRES_CAPTURE, amount=1000)
        mock_pi_capture.return_value = Mock(id="pi_no_charge")
        with patch("utils.helpers.get_charge_id_from_pi", return_value=None):
            with pytest.raises(https_fn.HttpsError) as charge_exc:
                _capture_payment_impl(_req("buyer_1", {Fields.ORDER_ID: "order_no_charge"}, token={}))
        assert charge_exc.value.code == "internal"

    @patch("handlers.payment_stripe.get_db")
    def test_process_transfer_reversed_returns_none_when_no_payout(self, mock_get_db):
        from handlers.payment_stripe import process_transfer_reversed

        payouts_q = Mock()
        payouts_q.where.return_value = payouts_q
        payouts_q.limit.return_value = payouts_q
        payouts_q.stream.return_value = []
        payouts_col = Mock()
        payouts_col.where.return_value = payouts_q
        db = Mock()
        db.collection.return_value = payouts_col
        mock_get_db.return_value = db

        assert process_transfer_reversed({StripeConstants.OBJECT_ID: "tr_missing"}) is None

    @patch("handlers.payment_stripe.get_db")
    def test_process_charge_refunded_returns_none_when_order_not_found(self, mock_get_db):
        from handlers.payment_stripe import process_charge_refunded

        orders_q = Mock()
        orders_q.where.return_value = orders_q
        orders_q.limit.return_value = orders_q
        orders_q.stream.return_value = []
        orders_col = Mock()
        orders_col.where.return_value = orders_q
        db = Mock()
        db.collection.return_value = orders_col
        mock_get_db.return_value = db

        out = process_charge_refunded(
            {
                StripeConstants.PAYMENT_INTENT: "pi_missing",
                "amount_refunded": 100,
                Fields.AMOUNT: 100,
            }
        )
        assert out is None

    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("handlers.payment_stripe.stripe.Transfer.create_reversal", return_value=Mock(id="rev_full"))
    @patch("handlers.digital._revoke_digital_licenses_for_order", return_value=0)
    @patch("handlers.payment_stripe.get_db")
    def test_process_charge_refunded_transfer_edge_paths(
        self,
        mock_get_db,
        _mock_revoke,
        mock_reversal,
        _mock_ts,
    ):
        from handlers.payment_stripe import process_charge_refunded

        order_ref = Mock()
        order_doc = _snap(
            {
                Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
                Fields.CUMULATIVE_REFUNDED_CENTS: 0,
                Fields.STOCK_RESTORED: True,
                Fields.SUBTOTAL_CENTS: 1000,
            },
            doc_id="order_refund_edges",
        )
        order_doc.reference = order_ref
        orders_q = Mock()
        orders_q.where.return_value = orders_q
        orders_q.limit.return_value = orders_q
        orders_q.stream.return_value = [order_doc]
        orders_col = Mock()
        orders_col.where.return_value = orders_q

        payout_missing_transfer = _snap(
            {Fields.NET_AMOUNT_CENTS: 1000, Fields.CUMULATIVE_REVERSED_CENTS: 0},
            doc_id="payout_missing_transfer",
        )
        payout_fully_reversed = _snap(
            {Fields.STRIPE_TRANSFER_ID: "tr_done", Fields.NET_AMOUNT_CENTS: 500, Fields.CUMULATIVE_REVERSED_CENTS: 500},
            doc_id="payout_done",
        )
        payout_partial = _snap(
            {Fields.STRIPE_TRANSFER_ID: "tr_partial", Fields.NET_AMOUNT_CENTS: 1000, Fields.CUMULATIVE_REVERSED_CENTS: 100},
            doc_id="payout_partial",
        )
        payouts_q = Mock()
        payouts_q.where.return_value = payouts_q
        payouts_q.limit.return_value = payouts_q
        payouts_q.stream.return_value = [payout_missing_transfer, payout_fully_reversed, payout_partial]
        payouts_col = Mock()
        payouts_col.where.return_value = payouts_q

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.PAYOUTS: payouts_col,
            Collections.SECURITY_ALERTS: Mock(),
            Collections.USERS: Mock(),
            Collections.PLATFORM_DEBT: Mock(),
        }[name]
        mock_get_db.return_value = db

        out = process_charge_refunded(
            {
                StripeConstants.PAYMENT_INTENT: "pi_refund_edges",
                "amount_refunded": 1000,
                Fields.AMOUNT: 1000,
            }
        )

        assert "fully refunded" in out
        assert mock_reversal.call_count == 1
        assert mock_reversal.call_args.args[0] == "tr_partial"
        assert mock_reversal.call_args.kwargs[Fields.AMOUNT] == 900

    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("handlers.payment_stripe._restore_stock_for_order", side_effect=RuntimeError("restore failed"))
    @patch("handlers.payment_stripe.stripe.Transfer.create_reversal", side_effect=RuntimeError("reversal failed"))
    @patch("handlers.digital._revoke_digital_licenses_for_order", return_value=0)
    @patch("handlers.payment_stripe.get_db")
    def test_process_charge_refunded_suspend_failure_and_restore_failure_paths(
        self,
        mock_get_db,
        _mock_revoke,
        _mock_reversal,
        _mock_restore,
        _mock_ts,
    ):
        from handlers.payment_stripe import process_charge_refunded

        order_ref = Mock()
        order_doc = _snap(
            {
                Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
                Fields.CUMULATIVE_REFUNDED_CENTS: 0,
                Fields.STOCK_RESTORED: False,
                Fields.SUBTOTAL_CENTS: 1000,
            },
            doc_id="order_refund_failures",
        )
        order_doc.reference = order_ref
        orders_q = Mock()
        orders_q.where.return_value = orders_q
        orders_q.limit.return_value = orders_q
        orders_q.stream.return_value = [order_doc]
        orders_col = Mock()
        orders_col.where.return_value = orders_q

        payout_doc = _snap(
            {
                Fields.STRIPE_TRANSFER_ID: "tr_fail",
                Fields.NET_AMOUNT_CENTS: 900,
                Fields.CUMULATIVE_REVERSED_CENTS: 0,
                Fields.SELLER_ID: "seller_1",
                Fields.AMOUNT_CENTS: 900,
            },
            doc_id="payout_fail",
        )
        failed_lookup_doc = _snap({Fields.SELLER_ID: "seller_1", Fields.AMOUNT_CENTS: 900}, doc_id="lookup")
        payouts_q = Mock()
        payouts_q.where.return_value = payouts_q
        payouts_q.limit.return_value = payouts_q
        payouts_q.stream.return_value = [payout_doc]
        payouts_q.get.return_value = [failed_lookup_doc]
        payouts_col = Mock()
        payouts_col.where.return_value = payouts_q

        users_col = Mock()
        users_col.document.return_value.update.side_effect = RuntimeError("suspend failed")

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.PAYOUTS: payouts_col,
            Collections.USERS: users_col,
            Collections.SECURITY_ALERTS: Mock(),
            Collections.PLATFORM_DEBT: Mock(),
        }[name]
        mock_get_db.return_value = db

        out = process_charge_refunded(
            {
                StripeConstants.PAYMENT_INTENT: "pi_refund_failures",
                "amount_refunded": 1000,
                Fields.AMOUNT: 1000,
            }
        )
        assert "fully refunded" in out

    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("handlers.payment_stripe.get_db")
    def test_process_refund_failed_charge_lookup_failure_skips_order_update(self, mock_get_db, _mock_ts, _mock_ensure):
        from handlers.payment_stripe import process_refund_failed

        security_col = Mock()
        orders_col = Mock()
        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.SECURITY_ALERTS: security_col,
            Collections.ORDERS: orders_col,
        }[name]
        mock_get_db.return_value = db

        with patch("handlers.payment_stripe.stripe.Charge.retrieve", side_effect=RuntimeError("charge lookup failed")):
            process_refund_failed({StripeConstants.CHARGE: "ch_missing", Fields.AMOUNT: 123})

        security_col.add.assert_called_once()

    @patch("services.email_task.enqueue_email_task", side_effect=RuntimeError("email down"))
    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("handlers.payment_stripe.get_firestore")
    @patch("handlers.payment_stripe.stripe.Transfer.create_reversal")
    @patch("handlers.payment_stripe.get_db")
    def test_process_dispute_created_misc_branches(
        self,
        mock_get_db,
        mock_reversal,
        mock_get_firestore,
        _mock_ts,
        _mock_email,
    ):
        from handlers.payment_stripe import process_dispute_created

        mock_get_firestore.return_value.ArrayUnion.side_effect = lambda vals: ("au", vals)

        def _reversal_side_effect(transfer_id, **kwargs):
            if transfer_id == "tr_runtime":
                raise RuntimeError("runtime reversal failure")
            return Mock(id=f"rev_{transfer_id}")

        mock_reversal.side_effect = _reversal_side_effect

        alert_ref = Mock()
        security_col = Mock()
        security_col.add.return_value = ("wr", alert_ref)

        order_doc = _snap(
            {
                Fields.TOTAL_AMOUNT_CENTS: 1000,
                Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
                Fields.ITEMS: [{Fields.SELLER_ID: ""}, {Fields.SELLER_ID: "seller_1"}],
            },
            doc_id="order_dispute_misc",
        )
        orders_q = Mock()
        orders_q.where.return_value = orders_q
        orders_q.limit.return_value = orders_q
        orders_q.stream.return_value = [order_doc]
        orders_col = Mock()
        orders_col.where.return_value = orders_q

        payout_fully_reversed = _snap(
            {Fields.STRIPE_TRANSFER_ID: "tr_done", Fields.NET_AMOUNT_CENTS: 100, Fields.CUMULATIVE_REVERSED_CENTS: 100},
            doc_id="payout_done",
        )
        payout_partial_full_refund = _snap(
            {Fields.STRIPE_TRANSFER_ID: "tr_partial_full", Fields.NET_AMOUNT_CENTS: 800, Fields.CUMULATIVE_REVERSED_CENTS: 100, Fields.SELLER_ID: "seller_1"},
            doc_id="payout_partial_full",
        )
        payout_runtime_error = _snap(
            {Fields.STRIPE_TRANSFER_ID: "tr_runtime", Fields.NET_AMOUNT_CENTS: 700, Fields.CUMULATIVE_REVERSED_CENTS: 0, Fields.SELLER_ID: "seller_1"},
            doc_id="payout_runtime",
        )
        payouts_q = Mock()
        payouts_q.where.return_value = payouts_q
        payouts_q.stream.return_value = [payout_fully_reversed, payout_partial_full_refund, payout_runtime_error]
        payouts_col = Mock()
        payouts_col.where.return_value = payouts_q

        users_col = Mock()
        users_col.document.return_value.get.return_value = _snap({Fields.EMAIL: "seller@example.com"}, exists=True)

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.SECURITY_ALERTS: security_col,
            Collections.ORDERS: orders_col,
            Collections.PAYOUTS: payouts_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        out = process_dispute_created(
            {
                StripeConstants.OBJECT_ID: "dp_misc",
                StripeConstants.CHARGE: "ch_misc",
                StripeConstants.PAYMENT_INTENT: "pi_misc",
                Fields.AMOUNT: 1000,
            }
        )

        assert "reversed" in out
        alert_ref.update.assert_called()

    @patch("services.email_task.enqueue_email_task", side_effect=RuntimeError("mail fail"))
    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("handlers.payment_stripe._get_seller_stripe_snapshot", return_value={})
    @patch("handlers.payment_stripe.get_db")
    def test_process_dispute_closed_lost_and_won_fallback_paths(
        self,
        mock_get_db,
        _mock_snapshot,
        _mock_ts,
        _mock_email,
    ):
        from handlers.payment_stripe import process_dispute_closed

        alert_doc = _snap({}, doc_id="alert_1")
        alerts_q = Mock()
        alerts_q.where.return_value = alerts_q
        alerts_q.limit.return_value = alerts_q
        alerts_q.stream.return_value = [alert_doc]
        sec_col = Mock()
        sec_col.where.return_value = alerts_q

        order_doc = _snap(
            {
                Fields.PRE_DISPUTE_STATUS: OrderStatusValues.CONFIRMED,
                Fields.ITEMS: [{Fields.SELLER_ID: ""}, {Fields.SELLER_ID: "seller_1"}],
            },
            doc_id="order_closed_misc",
        )
        orders_q = Mock()
        orders_q.where.return_value = orders_q
        orders_q.limit.return_value = orders_q
        orders_q.stream.return_value = [order_doc]
        orders_col = Mock()
        orders_col.where.return_value = orders_q

        payout_doc = _snap({Fields.SELLER_ID: "seller_1", Fields.CUMULATIVE_REVERSED_CENTS: 200}, doc_id="payout_1")
        payouts_q = Mock()
        payouts_q.where.return_value = payouts_q
        payouts_q.limit.return_value = payouts_q
        payouts_q.stream.return_value = [payout_doc]
        payouts_col = Mock()
        payouts_col.where.return_value = payouts_q

        seller_profile_ref = Mock()
        seller_profile_ref.get.return_value = _snap({}, exists=False)
        seller_profiles_col = Mock()
        seller_profiles_col.document.return_value = seller_profile_ref

        users_col = Mock()
        users_col.document.return_value.get.return_value = _snap({Fields.EMAIL: "seller@example.com"}, exists=True)

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.SECURITY_ALERTS: sec_col,
            Collections.ORDERS: orders_col,
            Collections.PAYOUTS: payouts_col,
            Collections.SELLER_PROFILES: seller_profiles_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        out_lost = process_dispute_closed(
            {
                StripeConstants.CHARGE: "ch_lost",
                StripeConstants.PAYMENT_INTENT: "pi_lost",
                StripeConstants.OBJECT_ID: "dp_lost",
                Fields.STATUS: "lost",
            }
        )
        out_won = process_dispute_closed(
            {
                StripeConstants.CHARGE: "ch_won",
                StripeConstants.PAYMENT_INTENT: "pi_won",
                StripeConstants.OBJECT_ID: "dp_won",
                Fields.STATUS: "won",
            }
        )

        assert out_lost == "Dispute closed: lost"
        assert out_won == "Dispute closed: won"


class TestDisputeResidualBranches:
    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("handlers.payment_stripe.stripe.Transfer.create_reversal", side_effect=RuntimeError("reversal boom"))
    @patch("handlers.digital._revoke_digital_licenses_for_order", return_value=0)
    @patch("handlers.payment_stripe.get_db")
    def test_process_charge_refunded_skips_empty_transfer_id_in_reversal_error_loop(
        self,
        mock_get_db,
        _mock_revoke,
        _mock_reversal,
        _mock_ts,
    ):
        from handlers.payment_stripe import process_charge_refunded

        class _ToggleTruthy:
            def __init__(self):
                self._reads = 0

            def __bool__(self):
                self._reads += 1
                return self._reads == 1

            def __str__(self):
                return "tr_toggle"

        order_ref = Mock()
        order_doc = _snap(
            {
                Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
                Fields.CUMULATIVE_REFUNDED_CENTS: 0,
                Fields.STOCK_RESTORED: True,
                Fields.SUBTOTAL_CENTS: 1000,
            },
            doc_id="order_refund_toggle",
        )
        order_doc.reference = order_ref
        orders_q = Mock()
        orders_q.where.return_value = orders_q
        orders_q.limit.return_value = orders_q
        orders_q.stream.return_value = [order_doc]
        orders_col = Mock()
        orders_col.where.return_value = orders_q

        payouts_q = Mock()
        payouts_q.where.return_value = payouts_q
        payouts_q.limit.return_value = payouts_q
        payouts_q.stream.return_value = [
            _snap(
                {
                    Fields.STRIPE_TRANSFER_ID: _ToggleTruthy(),
                    Fields.NET_AMOUNT_CENTS: 1000,
                    Fields.CUMULATIVE_REVERSED_CENTS: 0,
                    Fields.SELLER_ID: "seller_1",
                },
                doc_id="payout_toggle",
            )
        ]
        payouts_col = Mock()
        payouts_col.where.return_value = payouts_q

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.PAYOUTS: payouts_col,
            Collections.SECURITY_ALERTS: Mock(),
            Collections.USERS: Mock(),
            Collections.PLATFORM_DEBT: Mock(),
        }[name]
        mock_get_db.return_value = db

        out = process_charge_refunded(
            {
                StripeConstants.PAYMENT_INTENT: "pi_toggle",
                "amount_refunded": 1000,
                Fields.AMOUNT: 1000,
            }
        )

        assert "fully refunded" in out
        order_ref.update.assert_called_once()

    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("handlers.payment_stripe.stripe.Transfer.create_reversal")
    @patch("handlers.payment_stripe.get_db")
    def test_process_dispute_created_skips_zero_amount_reversal(
        self,
        mock_get_db,
        mock_reversal,
        _mock_ts,
    ):
        from handlers.payment_stripe import process_dispute_created

        alert_ref = Mock()
        security_col = Mock()
        security_col.add.return_value = ("wr", alert_ref)

        order_doc = _snap(
            {
                Fields.TOTAL_AMOUNT_CENTS: 1000,
                Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
                Fields.ITEMS: [],
            },
            doc_id="order_zero",
        )
        orders_q = Mock()
        orders_q.where.return_value = orders_q
        orders_q.limit.return_value = orders_q
        orders_q.stream.return_value = [order_doc]
        orders_col = Mock()
        orders_col.where.return_value = orders_q

        payouts_q = Mock()
        payouts_q.where.return_value = payouts_q
        payouts_q.stream.return_value = [
            _snap(
                {
                    Fields.STRIPE_TRANSFER_ID: "tr_zero",
                    Fields.NET_AMOUNT_CENTS: -10,
                    Fields.CUMULATIVE_REVERSED_CENTS: -20,
                    Fields.SELLER_ID: "seller_1",
                },
                doc_id="payout_zero",
            )
        ]
        payouts_col = Mock()
        payouts_col.where.return_value = payouts_q

        users_col = Mock()
        users_col.document.return_value.get.return_value = _snap(exists=False)

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.SECURITY_ALERTS: security_col,
            Collections.ORDERS: orders_col,
            Collections.PAYOUTS: payouts_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        out = process_dispute_created(
            {
                StripeConstants.OBJECT_ID: "dp_zero",
                StripeConstants.CHARGE: "ch_zero",
                StripeConstants.PAYMENT_INTENT: "pi_zero",
                Fields.AMOUNT: 1000,
            }
        )

        assert "reversed 0 transfers" in out


class TestCapturePaymentResidualBranches:
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_providers.require_provider_enabled")
    @patch("utils.helpers.get_charge_id_from_pi", return_value="ch_live_scoped")
    @patch("handlers.payment_stripe.stripe.Transfer.create")
    @patch("handlers.payment_stripe.stripe.PaymentIntent.retrieve", return_value=Mock(id="pi_scoped"))
    @patch("handlers.payment_stripe._get_seller_stripe_snapshot", return_value={"seller_1": "acct_1", "seller_2": "acct_2"})
    @patch("handlers.payment_stripe.get_db")
    def test_capture_impl_already_captured_scoped_coupon_non_coupon_seller_transfer_failure(
        self,
        mock_get_db,
        _mock_snapshot,
        _mock_pi_retrieve,
        mock_transfer_create,
        _mock_charge_id,
        _mock_provider,
        _mock_key,
    ):
        from handlers.payment_stripe import _capture_payment_impl

        def _transfer_side_effect(**kwargs):
            if kwargs.get("destination") == "acct_2":
                raise RuntimeError("bank down")
            return Mock(id=f"tr_{kwargs.get('destination')}")

        mock_transfer_create.side_effect = _transfer_side_effect

        order_ref = Mock()
        order_ref.get.return_value = _snap(
            {
                Fields.USER_ID: "buyer_1",
                Fields.PAYMENT_STATUS: PaymentStatusValues.CAPTURED,
                Fields.ORDER_STATUS: OrderStatusValues.DELIVERED,
                Fields.CONFIRMED_BY_CLIENT: False,
                Fields.STRIPE_PAYMENT_INTENT_ID: "pi_scoped",
                Fields.ITEMS: [
                    {Fields.SELLER_ID: "seller_1", Fields.STATUS: DeliveryStatusValues.DELIVERED, Fields.PRICE: 10.0, Fields.QUANTITY: 1},
                    {Fields.SELLER_ID: "seller_2", Fields.STATUS: DeliveryStatusValues.DELIVERED, Fields.PRICE: 20.0, Fields.QUANTITY: 1},
                ],
                Fields.SUBTOTAL_CENTS: 3000,
                Fields.DISCOUNT_AMOUNT_CENTS: 1000,
                Fields.COUPON_SELLER_ID: "seller_1",
                Fields.PLATFORM_FEE_RATIO: 0.1,
            },
            doc_id="order_already_scoped",
        )
        orders_col = Mock()
        orders_col.document.return_value = order_ref

        payout_ref_s1 = Mock()
        payout_ref_s1.get.return_value = _snap({}, exists=False, doc_id="order_already_scoped_seller_1")
        payout_ref_s2 = Mock()
        payout_ref_s2.get.return_value = _snap({}, exists=False, doc_id="order_already_scoped_seller_2")

        payouts_col = Mock()
        payouts_col.document.side_effect = lambda doc_id: {
            "order_already_scoped_seller_1": payout_ref_s1,
            "order_already_scoped_seller_2": payout_ref_s2,
        }[doc_id]

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.PAYOUTS: payouts_col,
            Collections.SELLER_PROFILES: Mock(),
        }[name]
        mock_get_db.return_value = db

        out = _capture_payment_impl(_req("buyer_1", {Fields.ORDER_ID: "order_already_scoped"}, token={}))

        assert out[ApiKeys.SUCCESS] is True
        assert out[ApiKeys.CAPTURED] is True
        payout_ref_s1.update.assert_called_once()
        payout_ref_s2.update.assert_called_once()
        failed_payload = payout_ref_s2.update.call_args.args[0]
        assert failed_payload[Fields.STATUS] == PayoutStatusValues.FAILED
        # seller_2 (non-coupon seller) should remain un-discounted under scoped coupons.
        assert payout_ref_s2.set.call_args.args[0][Fields.AMOUNT_CENTS] == 2000

    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("utils.helpers.get_charge_id_from_pi", return_value="ch_global")
    @patch("handlers.payment_stripe.stripe.Transfer.create", return_value=Mock(id="tr_global"))
    @patch("handlers.payment_stripe.stripe.Charge.retrieve", return_value=Mock(dispute=None))
    @patch("handlers.payment_stripe.stripe.PaymentIntent.capture", return_value=Mock(id="pi_3_global"))
    @patch("handlers.payment_stripe.stripe.PaymentIntent.retrieve", return_value=Mock(status=StripeConstants.STATUS_REQUIRES_CAPTURE, amount=1000))
    @patch("handlers.payment_stripe._get_seller_stripe_snapshot", return_value={"seller_1": "acct_1"})
    @patch("handlers.payment_stripe.get_transactional", return_value=lambda fn: fn)
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_providers.require_provider_enabled")
    @patch("handlers.payment_stripe.get_db")
    def test_capture_impl_authorized_global_discount_records_completed_payout(
        self,
        mock_get_db,
        _mock_provider,
        _mock_key,
        _mock_get_txn,
        _mock_snapshot,
        _mock_pi_retrieve,
        _mock_pi_capture,
        _mock_charge_retrieve,
        _mock_transfer,
        _mock_charge_id,
        _mock_ts,
    ):
        from handlers.payment_stripe import _capture_payment_impl

        order_ref = Mock()
        order_ref.get.side_effect = [
            _snap(
                {
                    Fields.USER_ID: "buyer_1",
                    Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
                    Fields.ORDER_STATUS: OrderStatusValues.SHIPPED,
                    Fields.STRIPE_PAYMENT_INTENT_ID: "pi_3_global",
                    Fields.CAPTURE_ATTEMPTS: 0,
                    Fields.TOTAL_AMOUNT_CENTS: 1000,
                    Fields.SUBTOTAL_CENTS: 1000,
                    Fields.DISCOUNT_AMOUNT_CENTS: 200,
                    Fields.COUPON_SELLER_ID: None,
                    Fields.PLATFORM_FEE_RATIO: 0.1,
                    Fields.ITEMS: [
                        {
                            Fields.SELLER_ID: "seller_1",
                            Fields.PRICE: 10.0,
                            Fields.QUANTITY: 1,
                            Fields.STATUS: DeliveryStatusValues.DELIVERED,
                        }
                    ],
                },
                doc_id="order_global",
            ),
            _snap(
                {
                    Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
                    Fields.CAPTURE_ATTEMPTS: 0,
                },
                doc_id="order_global",
            ),
        ]
        orders_col = Mock()
        orders_col.document.return_value = order_ref

        sec_q = Mock()
        sec_q.where.return_value = sec_q
        sec_q.limit.return_value = sec_q
        sec_q.get.return_value = []
        security_col = Mock()
        security_col.where.return_value = sec_q
        security_col.add = Mock()

        users_col = Mock()
        users_col.document.return_value.get.return_value = _snap({Fields.SUSPENDED: False}, exists=True, doc_id="seller_1")

        seller_profiles_col = Mock()
        seller_profiles_col.document.return_value.get.return_value = _snap(
            {Fields.STRIPE_ACCOUNT_ID: "acct_1", Fields.CHARGES_ENABLED: True},
            exists=True,
            doc_id="seller_1",
        )

        payout_lookup_q = Mock()
        payout_lookup_q.where.return_value = payout_lookup_q
        payout_lookup_q.limit.return_value = payout_lookup_q
        payout_lookup_q.get.return_value = []

        payout_ref = Mock()
        payouts_col = Mock()
        payouts_col.where.return_value = payout_lookup_q
        payouts_col.document.return_value = payout_ref

        db = Mock()
        db.transaction.return_value = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.SECURITY_ALERTS: security_col,
            Collections.USERS: users_col,
            Collections.SELLER_PROFILES: seller_profiles_col,
            Collections.PAYOUTS: payouts_col,
        }[name]
        mock_get_db.return_value = db

        out = _capture_payment_impl(_req("buyer_1", {Fields.ORDER_ID: "order_global"}, token={}))

        assert out[ApiKeys.SUCCESS] is True
        assert out[ApiKeys.CAPTURED] is True
        payload = payout_ref.set.call_args.args[0]
        assert payload[Fields.AMOUNT_CENTS] == 800  # 20% global discount
        payout_ref.update.assert_called_once()

    @patch("time.sleep", return_value=None)
    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("utils.helpers.get_charge_id_from_pi", return_value="ch_alert_fail")
    @patch("handlers.payment_stripe.stripe.Transfer.create", return_value=Mock(id="tr_alert_fail"))
    @patch("handlers.payment_stripe.stripe.Charge.retrieve", return_value=Mock(dispute=None))
    @patch("handlers.payment_stripe.stripe.PaymentIntent.capture", return_value=Mock(id="pi_3_alert_fail"))
    @patch("handlers.payment_stripe.stripe.PaymentIntent.retrieve", return_value=Mock(status=StripeConstants.STATUS_REQUIRES_CAPTURE, amount=1000))
    @patch("handlers.payment_stripe._get_seller_stripe_snapshot", return_value={"seller_1": "acct_1"})
    @patch("handlers.payment_stripe.get_transactional", return_value=lambda fn: fn)
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_providers.require_provider_enabled")
    @patch("handlers.payment_stripe.get_db")
    def test_capture_impl_alert_write_failure_after_payout_record_retry(
        self,
        mock_get_db,
        _mock_provider,
        _mock_key,
        _mock_get_txn,
        _mock_snapshot,
        _mock_pi_retrieve,
        _mock_pi_capture,
        _mock_charge_retrieve,
        _mock_transfer,
        _mock_charge_id,
        _mock_ts,
        _mock_sleep,
    ):
        from handlers.payment_stripe import _capture_payment_impl

        order_ref = Mock()
        order_ref.get.side_effect = [
            _snap(
                {
                    Fields.USER_ID: "buyer_1",
                    Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
                    Fields.ORDER_STATUS: OrderStatusValues.SHIPPED,
                    Fields.STRIPE_PAYMENT_INTENT_ID: "pi_3_alert_fail",
                    Fields.CAPTURE_ATTEMPTS: 0,
                    Fields.TOTAL_AMOUNT_CENTS: 1000,
                    Fields.SUBTOTAL_CENTS: 1000,
                    Fields.DISCOUNT_AMOUNT_CENTS: 0,
                    Fields.COUPON_SELLER_ID: None,
                    Fields.PLATFORM_FEE_RATIO: 0.1,
                    Fields.ITEMS: [
                        {
                            Fields.SELLER_ID: "seller_1",
                            Fields.PRICE: 10.0,
                            Fields.QUANTITY: 1,
                            Fields.STATUS: DeliveryStatusValues.DELIVERED,
                        }
                    ],
                },
                doc_id="order_alert_fail",
            ),
            _snap(
                {
                    Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
                    Fields.CAPTURE_ATTEMPTS: 0,
                },
                doc_id="order_alert_fail",
            ),
        ]
        orders_col = Mock()
        orders_col.document.return_value = order_ref

        sec_q = Mock()
        sec_q.where.return_value = sec_q
        sec_q.limit.return_value = sec_q
        sec_q.get.return_value = []
        security_col = Mock()
        security_col.where.return_value = sec_q
        security_col.add.side_effect = RuntimeError("security alert write failed")

        users_col = Mock()
        users_col.document.return_value.get.return_value = _snap({Fields.SUSPENDED: False}, exists=True, doc_id="seller_1")

        seller_profiles_col = Mock()
        seller_profiles_col.document.return_value.get.return_value = _snap(
            {Fields.STRIPE_ACCOUNT_ID: "acct_1", Fields.CHARGES_ENABLED: True},
            exists=True,
            doc_id="seller_1",
        )

        payout_lookup_q = Mock()
        payout_lookup_q.where.return_value = payout_lookup_q
        payout_lookup_q.limit.return_value = payout_lookup_q
        payout_lookup_q.get.return_value = []

        payout_ref = Mock()
        payout_ref.update.side_effect = [RuntimeError("fs1"), RuntimeError("fs2"), RuntimeError("fs3")]
        payouts_col = Mock()
        payouts_col.where.return_value = payout_lookup_q
        payouts_col.document.return_value = payout_ref

        db = Mock()
        db.transaction.return_value = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.SECURITY_ALERTS: security_col,
            Collections.USERS: users_col,
            Collections.SELLER_PROFILES: seller_profiles_col,
            Collections.PAYOUTS: payouts_col,
        }[name]
        mock_get_db.return_value = db

        out = _capture_payment_impl(_req("buyer_1", {Fields.ORDER_ID: "order_alert_fail"}, token={}))

        assert out[ApiKeys.SUCCESS] is True
        assert out[ApiKeys.CAPTURED] is True
        assert payout_ref.update.call_count == 3

    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("handlers.payment_stripe.stripe.PaymentIntent.retrieve", return_value=Mock(status="requires_payment_method", amount=1000))
    @patch("handlers.payment_stripe.get_transactional", return_value=lambda fn: fn)
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_providers.require_provider_enabled")
    @patch("handlers.payment_stripe.get_db")
    def test_capture_impl_https_error_rollback_failure_branch(
        self,
        mock_get_db,
        _mock_provider,
        _mock_key,
        _mock_get_txn,
        _mock_pi_retrieve,
        _mock_ts,
    ):
        from handlers.payment_stripe import _capture_payment_impl

        order_ref = Mock()
        order_ref.get.side_effect = [
            _snap(
                {
                    Fields.USER_ID: "buyer_1",
                    Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
                    Fields.ORDER_STATUS: OrderStatusValues.SHIPPED,
                    Fields.STRIPE_PAYMENT_INTENT_ID: "pi_3_https_rollback",
                    Fields.CAPTURE_ATTEMPTS: 0,
                    Fields.TOTAL_AMOUNT_CENTS: 1000,
                    Fields.ITEMS: [],
                },
                doc_id="order_https_rollback",
            ),
            _snap(
                {
                    Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
                    Fields.CAPTURE_ATTEMPTS: 0,
                },
                doc_id="order_https_rollback",
            ),
        ]
        order_ref.update.side_effect = RuntimeError("rollback write failed")
        orders_col = Mock()
        orders_col.document.return_value = order_ref

        sec_q = Mock()
        sec_q.where.return_value = sec_q
        sec_q.limit.return_value = sec_q
        sec_q.get.return_value = []
        security_col = Mock()
        security_col.where.return_value = sec_q

        db = Mock()
        db.transaction.return_value = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.SECURITY_ALERTS: security_col,
        }[name]
        mock_get_db.return_value = db

        with pytest.raises(https_fn.HttpsError) as exc:
            _capture_payment_impl(_req("buyer_1", {Fields.ORDER_ID: "order_https_rollback"}, token={}))
        assert exc.value.code == "failed-precondition"

    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("handlers.payment_stripe.get_transactional", return_value=lambda fn: fn)
    @patch("handlers.payment_stripe.ensure_stripe_key")
    @patch("handlers.payment_providers.require_provider_enabled")
    @patch("handlers.payment_stripe.get_db")
    def test_capture_impl_exception_mapping_paths(
        self,
        mock_get_db,
        _mock_provider,
        _mock_key,
        _mock_get_txn,
        _mock_ts,
    ):
        from handlers.payment_stripe import _capture_payment_impl

        class CardError(Exception):
            def __init__(self, code=None, user_message=None):
                super().__init__("card error")
                self.code = code
                self.user_message = user_message

        class InvalidRequestError(Exception):
            pass

        order_ref = Mock()
        order_ref.get.side_effect = [
            _snap(
                {
                    Fields.USER_ID: "buyer_1",
                    Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
                    Fields.ORDER_STATUS: OrderStatusValues.SHIPPED,
                    Fields.STRIPE_PAYMENT_INTENT_ID: "pi_3_map",
                    Fields.CAPTURE_ATTEMPTS: 0,
                    Fields.TOTAL_AMOUNT_CENTS: 1000,
                    Fields.ITEMS: [],
                },
                doc_id="order_map",
            ),
            _snap({Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED, Fields.CAPTURE_ATTEMPTS: 0}, doc_id="order_map"),
            _snap(
                {
                    Fields.USER_ID: "buyer_1",
                    Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
                    Fields.ORDER_STATUS: OrderStatusValues.SHIPPED,
                    Fields.STRIPE_PAYMENT_INTENT_ID: "pi_3_map",
                    Fields.CAPTURE_ATTEMPTS: 0,
                    Fields.TOTAL_AMOUNT_CENTS: 1000,
                    Fields.ITEMS: [],
                },
                doc_id="order_map",
            ),
            _snap({Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED, Fields.CAPTURE_ATTEMPTS: 0}, doc_id="order_map"),
            _snap(
                {
                    Fields.USER_ID: "buyer_1",
                    Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
                    Fields.ORDER_STATUS: OrderStatusValues.SHIPPED,
                    Fields.STRIPE_PAYMENT_INTENT_ID: "pi_3_map",
                    Fields.CAPTURE_ATTEMPTS: 0,
                    Fields.TOTAL_AMOUNT_CENTS: 1000,
                    Fields.ITEMS: [],
                },
                doc_id="order_map",
            ),
            _snap({Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED, Fields.CAPTURE_ATTEMPTS: 0}, doc_id="order_map"),
            _snap(
                {
                    Fields.USER_ID: "buyer_1",
                    Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED,
                    Fields.ORDER_STATUS: OrderStatusValues.SHIPPED,
                    Fields.STRIPE_PAYMENT_INTENT_ID: "pi_3_map",
                    Fields.CAPTURE_ATTEMPTS: 0,
                    Fields.TOTAL_AMOUNT_CENTS: 1000,
                    Fields.ITEMS: [],
                },
                doc_id="order_map",
            ),
            _snap({Fields.PAYMENT_STATUS: PaymentStatusValues.AUTHORIZED, Fields.CAPTURE_ATTEMPTS: 0}, doc_id="order_map"),
        ]
        orders_col = Mock()
        orders_col.document.return_value = order_ref

        sec_q = Mock()
        sec_q.where.return_value = sec_q
        sec_q.limit.return_value = sec_q
        sec_q.get.return_value = []
        security_col = Mock()
        security_col.where.return_value = sec_q

        db = Mock()
        db.transaction.return_value = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.SECURITY_ALERTS: security_col,
        }[name]
        mock_get_db.return_value = db

        with patch("handlers.payment_stripe.stripe.PaymentIntent.retrieve", side_effect=CardError(code="authentication_required")):
            with pytest.raises(https_fn.HttpsError) as auth_required_exc:
                _capture_payment_impl(_req("buyer_1", {Fields.ORDER_ID: "order_map"}, token={}))
        assert auth_required_exc.value.code == "failed-precondition"
        assert "additional verification" in str(auth_required_exc.value)

        with patch("handlers.payment_stripe.stripe.PaymentIntent.retrieve", side_effect=CardError(code="declined", user_message=None)):
            with pytest.raises(https_fn.HttpsError) as card_decline_exc:
                _capture_payment_impl(_req("buyer_1", {Fields.ORDER_ID: "order_map"}, token={}))
        assert card_decline_exc.value.code == "failed-precondition"
        assert "declined" in str(card_decline_exc.value).lower()

        with patch("handlers.payment_stripe.stripe.PaymentIntent.retrieve", side_effect=InvalidRequestError("bad request")):
            with pytest.raises(https_fn.HttpsError) as invalid_req_exc:
                _capture_payment_impl(_req("buyer_1", {Fields.ORDER_ID: "order_map"}, token={}))
        assert invalid_req_exc.value.code == "failed-precondition"

        # Rollback failure + generic internal error mapping.
        order_ref.update.side_effect = RuntimeError("rollback write failed")
        with patch("handlers.payment_stripe.stripe.PaymentIntent.retrieve", side_effect=RuntimeError("unknown boom")):
            with pytest.raises(https_fn.HttpsError) as generic_exc:
                _capture_payment_impl(_req("buyer_1", {Fields.ORDER_ID: "order_map"}, token={}))
        assert generic_exc.value.code == "internal"

    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("handlers.payment_stripe.get_firestore")
    @patch("handlers.payment_stripe.stripe.Transfer.create_reversal")
    @patch("handlers.payment_stripe.get_db")
    def test_process_dispute_created_suspend_failure_path_is_non_fatal(
        self,
        mock_get_db,
        mock_create_reversal,
        mock_get_firestore,
        _mock_ts,
    ):
        from handlers import payment_stripe as hps
        from handlers.payment_stripe import process_dispute_created

        mock_get_firestore.return_value.ArrayUnion.side_effect = lambda vals: ("au", vals)
        mock_create_reversal.side_effect = hps.stripe.error.InvalidRequestError("insufficient funds")

        alert_ref = Mock()
        security_col = Mock()
        security_col.add.return_value = ("wr", alert_ref)

        order_doc = _snap(
            {
                Fields.TOTAL_AMOUNT_CENTS: 1000,
                Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
                Fields.ITEMS: [],
            },
            doc_id="order_suspend_fail",
        )
        orders_q = Mock()
        orders_q.where.return_value = orders_q
        orders_q.limit.return_value = orders_q
        orders_q.stream.return_value = [order_doc]
        orders_col = Mock()
        orders_col.where.return_value = orders_q

        payouts_q = Mock()
        payouts_q.where.return_value = payouts_q
        payouts_q.stream.return_value = [
            _snap(
                {
                    Fields.STRIPE_TRANSFER_ID: "tr_insufficient",
                    Fields.NET_AMOUNT_CENTS: 800,
                    Fields.CUMULATIVE_REVERSED_CENTS: 0,
                    Fields.SELLER_ID: "seller_fail",
                },
                doc_id="payout_suspend_fail",
            )
        ]
        payouts_col = Mock()
        payouts_col.where.return_value = payouts_q

        users_col = Mock()
        users_col.document.return_value.update.side_effect = RuntimeError("suspend write failed")

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.SECURITY_ALERTS: security_col,
            Collections.ORDERS: orders_col,
            Collections.PAYOUTS: payouts_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        out = process_dispute_created(
            {
                StripeConstants.OBJECT_ID: "dp_suspend_fail",
                StripeConstants.CHARGE: "ch_suspend_fail",
                StripeConstants.PAYMENT_INTENT: "pi_suspend_fail",
                Fields.AMOUNT: 500,
            }
        )

        assert "reversed 0 transfers" in out
        alert_ref.update.assert_called()

    @patch("handlers.payment_stripe.get_server_timestamp", return_value="ts")
    @patch("handlers.payment_stripe.get_db")
    def test_process_dispute_created_email_notification_block_failure_is_swallowed(self, mock_get_db, _mock_ts):
        from handlers.payment_stripe import process_dispute_created

        alert_ref = Mock()
        security_col = Mock()
        security_col.add.return_value = ("wr", alert_ref)

        order_doc = _snap(
            {
                Fields.TOTAL_AMOUNT_CENTS: 1000,
                Fields.ORDER_STATUS: OrderStatusValues.CONFIRMED,
                Fields.ITEMS: [{Fields.SELLER_ID: "seller_mail_fail"}],
            },
            doc_id="order_mail_fail",
        )
        orders_q = Mock()
        orders_q.where.return_value = orders_q
        orders_q.limit.return_value = orders_q
        orders_q.stream.return_value = [order_doc]
        orders_col = Mock()
        orders_col.where.return_value = orders_q

        payouts_q = Mock()
        payouts_q.where.return_value = payouts_q
        payouts_q.stream.return_value = []
        payouts_col = Mock()
        payouts_col.where.return_value = payouts_q

        users_col = Mock()
        users_col.document.side_effect = RuntimeError("seller lookup exploded")

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.SECURITY_ALERTS: security_col,
            Collections.ORDERS: orders_col,
            Collections.PAYOUTS: payouts_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        out = process_dispute_created(
            {
                StripeConstants.OBJECT_ID: "dp_mail_fail",
                StripeConstants.CHARGE: "ch_mail_fail",
                StripeConstants.PAYMENT_INTENT: "pi_mail_fail",
                Fields.AMOUNT: 1000,
            }
        )

        assert "reversed 0 transfers" in out
