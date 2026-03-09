from datetime import UTC, datetime, timedelta
from types import SimpleNamespace
from unittest.mock import Mock, call, patch

import pytest
from firebase_functions import https_fn
from pydantic import ValidationError

from schema_constants import (
    ApiKeys,
    Collections,
    Fields,
    ProductLifecycleStatusValues,
    SupplierTypeValues,
    UserRoleValues,
)


def _snap(data=None, *, exists=True, doc_id="doc_1"):
    snap = Mock()
    snap.exists = exists
    snap.id = doc_id
    snap.to_dict.return_value = {} if data is None else data
    snap.reference = Mock()
    return snap


def _req(uid: str | None, data: dict, *, token: dict | None = None):
    req = Mock()
    req.auth = Mock(uid=uid, token=(token or {})) if uid else None
    req.data = data
    req.raw_request = Mock()
    req.raw_request.headers = {}
    return req


def _favorite_doc(uid: str):
    doc = Mock()
    doc.reference = Mock()
    doc.reference.parent = Mock()
    doc.reference.parent.parent = Mock()
    doc.reference.parent.parent.id = uid
    return doc


class _FakeProductUpdate:
    def __init__(self, **kwargs):
        self._payload = dict(kwargs)

    def model_dump(self, exclude_unset=True):
        return dict(self._payload)


class TestStockNotificationHelpers:
    @patch("handlers.products.get_db")
    def test_cleanup_orphaned_variant_subscriptions_no_before_variants(self, mock_get_db):
        from handlers.products import _cleanup_orphaned_variant_subscriptions

        _cleanup_orphaned_variant_subscriptions("p1", {Fields.VARIANTS: []}, {Fields.VARIANTS: []})
        mock_get_db.assert_not_called()

    @patch("handlers.products.get_db")
    def test_cleanup_orphaned_variant_subscriptions_deletes_removed_variant_docs(self, mock_get_db):
        from handlers.products import _cleanup_orphaned_variant_subscriptions

        sub1 = _snap(doc_id="s1")
        sub2 = _snap(doc_id="s2")

        query = Mock()
        query.where.return_value = query
        query.limit.return_value = query
        query.stream.return_value = [sub1, sub2]

        stock_col = Mock()
        stock_col.where.return_value = query

        batch = Mock()
        db = Mock()
        db.collection.return_value = stock_col
        db.batch.return_value = batch
        mock_get_db.return_value = db

        _cleanup_orphaned_variant_subscriptions(
            "p1",
            {
                Fields.VARIANTS: [
                    {Fields.VARIANT_ID: "v1", Fields.VARIANT_KEY: "v1"},
                    {Fields.VARIANT_ID: "v2", Fields.VARIANT_KEY: "v2"},
                ]
            },
            {Fields.VARIANTS: [{Fields.VARIANT_ID: "v2", Fields.VARIANT_KEY: "v2"}]},
        )

        assert batch.delete.call_count == 2
        batch.commit.assert_called_once()

    @patch("handlers.products.get_db")
    @patch("handlers.products.get_server_timestamp", return_value="ts")
    @patch("services.push_service.send_push_notifications_batch")
    @patch("services.email_task.enqueue_email_task")
    def test_fire_back_in_stock_notifications_variant_success(
        self,
        mock_enqueue,
        mock_push_batch,
        _mock_ts,
        mock_get_db,
    ):
        from handlers.products import _fire_back_in_stock_notifications

        sub_ok = _snap({Fields.EMAIL: "a@b.com", Fields.USER_ID: "u1"}, doc_id="s_ok")
        sub_missing_email = _snap({Fields.USER_ID: "u2"}, doc_id="s_skip")

        q = Mock()
        q.where.return_value = q
        q.limit.return_value = q
        q.start_after.return_value = q
        q.stream.side_effect = [[sub_ok, sub_missing_email], []]

        stock_col = Mock()
        stock_col.where.return_value = q

        db = Mock()
        db.collection.return_value = stock_col
        mock_get_db.return_value = db

        _fire_back_in_stock_notifications(
            "p1",
            {
                Fields.HAS_VARIANTS: True,
                Fields.VARIANTS: [{Fields.VARIANT_ID: "v1", Fields.STOCK_QUANTITY: 0}],
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            },
            {
                Fields.HAS_VARIANTS: True,
                Fields.NAME: "Widget",
                Fields.VARIANTS: [{Fields.VARIANT_ID: "v1", Fields.STOCK_QUANTITY: 3}],
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            },
        )

        sub_ok.reference.update.assert_any_call({Fields.NOTIFIED_AT: "ts"})
        sub_ok.reference.delete.assert_called_once()
        mock_enqueue.assert_called_once()
        mock_push_batch.assert_called_once()

    @patch("handlers.products.get_db")
    @patch("handlers.products.get_server_timestamp", return_value="ts")
    @patch("services.email_task.enqueue_email_task", side_effect=RuntimeError("send fail"))
    def test_fire_back_in_stock_notifications_rolls_back_notified_at_on_send_failure(
        self,
        _mock_enqueue,
        _mock_ts,
        mock_get_db,
    ):
        from handlers.products import _fire_back_in_stock_notifications

        sub = _snap({Fields.EMAIL: "a@b.com", Fields.USER_ID: "u1"}, doc_id="s1")

        q = Mock()
        q.where.return_value = q
        q.limit.return_value = q
        q.start_after.return_value = q
        q.stream.side_effect = [[sub], []]

        stock_col = Mock()
        stock_col.where.return_value = q

        db = Mock()
        db.collection.return_value = stock_col
        mock_get_db.return_value = db

        _fire_back_in_stock_notifications(
            "p1",
            {
                Fields.HAS_VARIANTS: False,
                Fields.STOCK_QUANTITY: 0,
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            },
            {
                Fields.HAS_VARIANTS: False,
                Fields.NAME: "Widget",
                Fields.STOCK_QUANTITY: 2,
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            },
        )

        assert sub.reference.update.call_args_list[0] == call({Fields.NOTIFIED_AT: "ts"})
        assert sub.reference.update.call_args_list[-1] == call({Fields.NOTIFIED_AT: None})

    @patch("handlers.products.get_db")
    def test_fire_back_in_stock_notifications_early_return_non_variant_branches(self, mock_get_db):
        from handlers.products import _fire_back_in_stock_notifications

        # before_stock > 0 branch
        _fire_back_in_stock_notifications(
            "p1",
            {
                Fields.HAS_VARIANTS: False,
                Fields.STOCK_QUANTITY: 1,
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            },
            {
                Fields.HAS_VARIANTS: False,
                Fields.STOCK_QUANTITY: 2,
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            },
        )

        # inactive lifecycle branch
        _fire_back_in_stock_notifications(
            "p1",
            {
                Fields.HAS_VARIANTS: False,
                Fields.STOCK_QUANTITY: 0,
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            },
            {
                Fields.HAS_VARIANTS: False,
                Fields.STOCK_QUANTITY: 2,
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.PAUSED,
            },
        )

        mock_get_db.assert_not_called()

    @patch("handlers.products.get_db")
    def test_fire_back_in_stock_notifications_variant_early_return_branches(self, mock_get_db):
        from handlers.products import _fire_back_in_stock_notifications

        # No restocked variant keys branch
        _fire_back_in_stock_notifications(
            "p1",
            {
                Fields.HAS_VARIANTS: True,
                Fields.VARIANTS: [{Fields.VARIANT_ID: "v1", Fields.STOCK_QUANTITY: 1}],
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            },
            {
                Fields.HAS_VARIANTS: True,
                Fields.VARIANTS: [{Fields.VARIANT_ID: "v1", Fields.STOCK_QUANTITY: 1}],
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            },
        )

        # Inactive lifecycle branch
        _fire_back_in_stock_notifications(
            "p1",
            {
                Fields.HAS_VARIANTS: True,
                Fields.VARIANTS: [{Fields.VARIANT_ID: "v1", Fields.STOCK_QUANTITY: 0}],
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            },
            {
                Fields.HAS_VARIANTS: True,
                Fields.VARIANTS: [{Fields.VARIANT_ID: "v1", Fields.STOCK_QUANTITY: 2}],
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.PAUSED,
            },
        )

        mock_get_db.assert_not_called()

    @patch("handlers.products.get_db")
    @patch("handlers.products.get_server_timestamp", return_value="ts")
    @patch("services.email_task.enqueue_email_task", side_effect=RuntimeError("send fail"))
    def test_fire_back_in_stock_notifications_variant_rollback_failure_logs(
        self,
        _mock_enqueue,
        _mock_ts,
        mock_get_db,
    ):
        from handlers.products import _fire_back_in_stock_notifications

        sub = _snap({Fields.EMAIL: "a@b.com", Fields.USER_ID: "u1"}, doc_id="s1")
        sub.reference.update.side_effect = [None, RuntimeError("rollback fail")]

        q = Mock()
        q.where.return_value = q
        q.limit.return_value = q
        q.start_after.return_value = q
        q.stream.side_effect = [[sub], []]

        stock_col = Mock()
        stock_col.where.return_value = q

        db = Mock()
        db.collection.return_value = stock_col
        mock_get_db.return_value = db

        _fire_back_in_stock_notifications(
            "p1",
            {
                Fields.HAS_VARIANTS: True,
                Fields.VARIANTS: [{Fields.VARIANT_ID: "v1", Fields.STOCK_QUANTITY: 0}],
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            },
            {
                Fields.HAS_VARIANTS: True,
                Fields.NAME: "Widget",
                Fields.VARIANTS: [{Fields.VARIANT_ID: "v1", Fields.STOCK_QUANTITY: 3}],
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            },
        )

        assert sub.reference.update.call_args_list[0] == call({Fields.NOTIFIED_AT: "ts"})
        # rollback attempt also happened
        assert len(sub.reference.update.call_args_list) == 2

    @patch("handlers.products.get_db")
    @patch("handlers.products.get_server_timestamp", return_value="ts")
    @patch("services.push_service.send_push_notifications_batch")
    @patch("services.email_task.enqueue_email_task")
    def test_fire_back_in_stock_notifications_non_variant_success_and_missing_email(
        self,
        mock_enqueue,
        mock_push_batch,
        _mock_ts,
        mock_get_db,
    ):
        from handlers.products import _fire_back_in_stock_notifications

        sub_missing_email = _snap({Fields.USER_ID: "u_skip"}, doc_id="s_skip")
        sub_ok = _snap({Fields.EMAIL: "ok@ex.com", Fields.USER_ID: "u1"}, doc_id="s_ok")

        q = Mock()
        q.where.return_value = q
        q.limit.return_value = q
        q.start_after.return_value = q
        q.stream.side_effect = [[sub_missing_email, sub_ok], []]

        stock_col = Mock()
        stock_col.where.return_value = q

        db = Mock()
        db.collection.return_value = stock_col
        mock_get_db.return_value = db

        _fire_back_in_stock_notifications(
            "p1",
            {
                Fields.HAS_VARIANTS: False,
                Fields.STOCK_QUANTITY: 0,
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            },
            {
                Fields.HAS_VARIANTS: False,
                Fields.NAME: "Widget",
                Fields.STOCK_QUANTITY: 2,
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            },
        )

        sub_ok.reference.update.assert_any_call({Fields.NOTIFIED_AT: "ts"})
        sub_ok.reference.delete.assert_called_once()
        mock_enqueue.assert_called_once()
        mock_push_batch.assert_called_once()

    @patch("handlers.products.get_db")
    @patch("handlers.products.get_server_timestamp", return_value="ts")
    @patch("services.email_task.enqueue_email_task", side_effect=RuntimeError("send fail"))
    def test_fire_back_in_stock_notifications_non_variant_rollback_failure_logs(
        self,
        _mock_enqueue,
        _mock_ts,
        mock_get_db,
    ):
        from handlers.products import _fire_back_in_stock_notifications

        sub = _snap({Fields.EMAIL: "a@b.com", Fields.USER_ID: "u1"}, doc_id="s1")
        sub.reference.update.side_effect = [None, RuntimeError("rollback fail")]

        q = Mock()
        q.where.return_value = q
        q.limit.return_value = q
        q.start_after.return_value = q
        q.stream.side_effect = [[sub], []]

        stock_col = Mock()
        stock_col.where.return_value = q

        db = Mock()
        db.collection.return_value = stock_col
        mock_get_db.return_value = db

        _fire_back_in_stock_notifications(
            "p1",
            {
                Fields.HAS_VARIANTS: False,
                Fields.STOCK_QUANTITY: 0,
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            },
            {
                Fields.HAS_VARIANTS: False,
                Fields.NAME: "Widget",
                Fields.STOCK_QUANTITY: 2,
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
            },
        )

        assert sub.reference.update.call_args_list[0] == call({Fields.NOTIFIED_AT: "ts"})
        assert len(sub.reference.update.call_args_list) == 2


class TestStockSubscriptionEndpoints:
    @patch("handlers.products.RateLimiter")
    def test_subscribe_stock_notification_rate_limited(self, mock_rl):
        from handlers.products import subscribe_stock_notification

        mock_rl.return_value.check_rate_limit.return_value = (False, "slow down")
        req = _req("u1", {Fields.PRODUCT_ID: "p1"})

        with pytest.raises(https_fn.HttpsError) as exc:
            subscribe_stock_notification(req)
        assert exc.value.code == "resource-exhausted"

    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_subscribe_stock_notification_invalid_product_id_format(self, mock_get_db, mock_rl):
        from handlers.products import subscribe_stock_notification

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        db = Mock()
        mock_get_db.return_value = db
        req = _req("u1", {Fields.PRODUCT_ID: "../bad"})

        with pytest.raises(https_fn.HttpsError) as exc:
            subscribe_stock_notification(req)
        assert exc.value.code == "invalid-argument"
        db.collection.assert_not_called()

    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_subscribe_stock_notification_variant_key_too_long(self, mock_get_db, mock_rl):
        from handlers.products import subscribe_stock_notification

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        db = Mock()
        mock_get_db.return_value = db
        req = _req("u1", {Fields.PRODUCT_ID: "p1", Fields.VARIANT_KEY: "x" * 501})

        with pytest.raises(https_fn.HttpsError) as exc:
            subscribe_stock_notification(req)
        assert exc.value.code == "invalid-argument"
        db.collection.assert_not_called()

    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_subscribe_stock_notification_existing_subscription_is_idempotent(self, mock_get_db, mock_rl):
        from handlers.products import subscribe_stock_notification

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        product_doc = _snap(
            {
                Fields.SELLER_ID: "seller_x",
                Fields.HAS_VARIANTS: False,
                Fields.STOCK_QUANTITY: 0,
                Fields.NAME: "Product",
            }
        )
        user_doc = _snap({Fields.EMAIL: "u@example.com"})
        existing_sub = _snap({})

        products_col = Mock()
        products_col.document.return_value.get.return_value = product_doc

        users_col = Mock()
        users_col.document.return_value.get.return_value = user_doc

        q = Mock()
        q.where.return_value = q
        q.limit.return_value = q
        q.stream.return_value = [existing_sub]
        stock_col = Mock()
        stock_col.where.return_value = q

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.PRODUCTS: products_col,
            Collections.USERS: users_col,
            Collections.STOCK_NOTIFICATIONS: stock_col,
        }[name]
        mock_get_db.return_value = db

        req = _req("u1", {Fields.PRODUCT_ID: "p1"})
        out = subscribe_stock_notification(req)

        assert out[ApiKeys.SUCCESS] is True
        assert out["subscribed"] is True
        stock_col.add.assert_not_called()

    @patch("handlers.products.get_server_timestamp", return_value="ts")
    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_subscribe_stock_notification_success_adds_doc(self, mock_get_db, mock_rl, _mock_ts):
        from handlers.products import subscribe_stock_notification

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        product_doc = _snap(
            {
                Fields.SELLER_ID: "seller_x",
                Fields.HAS_VARIANTS: False,
                Fields.STOCK_QUANTITY: 0,
                Fields.NAME: "Product",
            }
        )
        user_doc = _snap({Fields.EMAIL: "u@example.com"})

        products_col = Mock()
        products_col.document.return_value.get.return_value = product_doc

        users_col = Mock()
        users_col.document.return_value.get.return_value = user_doc

        q = Mock()
        q.where.return_value = q
        q.limit.return_value = q
        q.stream.return_value = []

        stock_col = Mock()
        stock_col.where.return_value = q

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.PRODUCTS: products_col,
            Collections.USERS: users_col,
            Collections.STOCK_NOTIFICATIONS: stock_col,
        }[name]
        mock_get_db.return_value = db

        req = _req("u1", {Fields.PRODUCT_ID: "p1"})
        out = subscribe_stock_notification(req)

        assert out["subscribed"] is True
        stock_col.add.assert_called_once()

    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_unsubscribe_stock_notification_variant_filter_and_delete(self, mock_get_db, mock_rl):
        from handlers.products import unsubscribe_stock_notification

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        sub1 = _snap({}, doc_id="s1")
        sub2 = _snap({}, doc_id="s2")

        q = Mock()
        q.where.return_value = q
        q.limit.return_value = q
        q.stream.return_value = [sub1, sub2]

        stock_col = Mock()
        stock_col.where.return_value = q

        db = Mock()
        db.collection.return_value = stock_col
        mock_get_db.return_value = db

        req = _req("u1", {Fields.PRODUCT_ID: "p1", Fields.VARIANT_KEY: "v1"})
        out = unsubscribe_stock_notification(req)

        assert out["unsubscribed"] is True
        assert sub1.reference.delete.called
        assert sub2.reference.delete.called


class TestFavoritesAndQA:
    @patch("handlers.products.get_firestore")
    @patch("handlers.products.get_db")
    def test_toggle_favorite_adds_when_not_favorited(self, mock_get_db, mock_get_firestore):
        from handlers.products import toggle_favorite

        mock_get_firestore.return_value.transactional = lambda fn: fn
        mock_get_firestore.return_value.Increment = lambda n: ("inc", n)

        tx = Mock()

        product_ref = Mock()
        product_ref.get.return_value = _snap({Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE})

        fav_ref = Mock()
        fav_ref.get.return_value = _snap(exists=False)

        products_col = Mock()
        products_col.document.return_value = product_ref

        user_ref = Mock()
        favs_col = Mock()
        favs_col.document.return_value = fav_ref
        user_ref.collection.return_value = favs_col

        users_col = Mock()
        users_col.document.return_value = user_ref

        db = Mock()
        db.collection.side_effect = lambda name: {Collections.PRODUCTS: products_col, Collections.USERS: users_col}[name]
        db.transaction.return_value = tx
        mock_get_db.return_value = db

        out = toggle_favorite(_req("u1", {Fields.PRODUCT_ID: "p1"}))

        assert out["favorited"] is True
        tx.set.assert_called_once()
        tx.update.assert_called_once()

    @patch("handlers.products.get_firestore")
    @patch("handlers.products.get_db")
    def test_toggle_favorite_removes_when_already_favorited(self, mock_get_db, mock_get_firestore):
        from handlers.products import toggle_favorite

        mock_get_firestore.return_value.transactional = lambda fn: fn
        mock_get_firestore.return_value.Increment = lambda n: ("inc", n)

        tx = Mock()

        product_ref = Mock()
        product_ref.get.return_value = _snap({Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE})

        fav_ref = Mock()
        fav_ref.get.return_value = _snap(exists=True)

        products_col = Mock()
        products_col.document.return_value = product_ref

        user_ref = Mock()
        favs_col = Mock()
        favs_col.document.return_value = fav_ref
        user_ref.collection.return_value = favs_col

        users_col = Mock()
        users_col.document.return_value = user_ref

        db = Mock()
        db.collection.side_effect = lambda name: {Collections.PRODUCTS: products_col, Collections.USERS: users_col}[name]
        db.transaction.return_value = tx
        mock_get_db.return_value = db

        out = toggle_favorite(_req("u1", {Fields.PRODUCT_ID: "p1"}))

        assert out["favorited"] is False
        tx.delete.assert_called_once_with(fav_ref)

    @patch("handlers.products.RateLimiter")
    @patch("utils.premium_check.is_premium_authoritative", return_value=False)
    def test_ask_product_question_requires_premium(self, _mock_premium, mock_rl):
        from handlers.products import ask_product_question

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        with pytest.raises(https_fn.HttpsError) as exc:
            ask_product_question(_req("u1", {Fields.PRODUCT_ID: "p1", Fields.QUESTION_TEXT: "How long delivery?"}))
        assert exc.value.code == "permission-denied"

    @patch("handlers.products.create_success_response", side_effect=lambda payload: {"success": True, **payload})
    @patch("services.email_task.enqueue_email_task")
    @patch("utils.helpers.sanitized_text", side_effect=lambda s: s)
    @patch("handlers.products.RateLimiter")
    @patch("utils.premium_check.is_premium_authoritative", return_value=True)
    @patch("handlers.products.get_db")
    def test_ask_product_question_success_and_seller_notification(
        self,
        mock_get_db,
        _mock_premium,
        mock_rl,
        _mock_sanitized,
        mock_enqueue,
        _mock_resp,
    ):
        from handlers.products import ask_product_question

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        product_doc = _snap({Fields.SELLER_ID: "seller_1", Fields.NAME: "Product Alpha"})
        seller_doc = _snap({Fields.EMAIL: "seller@example.com"})

        products_col = Mock()
        products_col.document.return_value.get.return_value = product_doc

        users_col = Mock()
        users_col.document.return_value.get.return_value = seller_doc

        question_ref = Mock()
        question_ref.id = "q1"
        questions_col = Mock()
        questions_col.document.return_value = question_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.PRODUCTS: products_col,
            Collections.USERS: users_col,
            Collections.PRODUCT_QUESTIONS: questions_col,
        }[name]
        mock_get_db.return_value = db

        req = _req("buyer_1", {Fields.PRODUCT_ID: "p1", Fields.QUESTION_TEXT: "Is this available in red color?"})
        out = ask_product_question(req)

        assert out["success"] is True
        assert out[Fields.QUESTION_ID] == "q1"
        question_ref.set.assert_called_once()
        mock_enqueue.assert_called_once()

    @patch("handlers.products.create_success_response", side_effect=lambda payload: payload)
    @patch("services.email_task.enqueue_email_task")
    @patch("utils.helpers.sanitized_text", side_effect=lambda s: s)
    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_answer_product_question_as_admin_success(
        self,
        mock_get_db,
        mock_rl,
        _mock_sanitized,
        mock_enqueue,
        _mock_resp,
    ):
        from handlers.products import answer_product_question

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        question_ref = Mock()
        question_doc = _snap(
            {
                Fields.SELLER_ID: "seller_1",
                Fields.ASKER_ID: "buyer_1",
                Fields.PRODUCT_ID: "p1",
                Fields.QUESTION_TEXT: "Do you ship fast?",
            }
        )
        question_ref.get.return_value = question_doc

        questions_col = Mock()
        questions_col.document.return_value = question_ref

        asker_doc = _snap({Fields.EMAIL: "buyer@example.com"})
        users_col = Mock()
        users_col.document.return_value.get.return_value = asker_doc

        product_doc = _snap({Fields.NAME: "Product A"})
        products_col = Mock()
        products_col.document.return_value.get.return_value = product_doc

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.PRODUCT_QUESTIONS: questions_col,
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
        }[name]
        mock_get_db.return_value = db

        req = _req(
            "admin_1",
            {Fields.QUESTION_ID: "q1", Fields.ANSWER_TEXT: "Yes, usually within 2-3 days."},
            token={"admin": True},
        )
        out = answer_product_question(req)

        assert out["answered"] is True
        question_ref.update.assert_called_once()
        mock_enqueue.assert_called_once()

    @patch("handlers.products.RateLimiter")
    @patch("utils.helpers.sanitized_text", side_effect=lambda s: s)
    @patch("handlers.products.get_db")
    def test_answer_product_question_permission_denied_for_non_seller(self, mock_get_db, _mock_sanitized, mock_rl):
        from handlers.products import answer_product_question

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        question_ref = Mock()
        question_ref.get.return_value = _snap({Fields.SELLER_ID: "seller_1"})

        questions_col = Mock()
        questions_col.document.return_value = question_ref

        db = Mock()
        db.collection.return_value = questions_col
        mock_get_db.return_value = db

        req = _req("other_user", {Fields.QUESTION_ID: "q1", Fields.ANSWER_TEXT: "A valid answer text"})

        with pytest.raises(https_fn.HttpsError) as exc:
            answer_product_question(req)
        assert exc.value.code == "permission-denied"

    @patch("handlers.products.create_success_response", side_effect=lambda payload: payload)
    @patch("handlers.products.get_db")
    def test_get_product_questions_answered_only(self, mock_get_db, _mock_resp):
        from handlers.products import get_product_questions

        d1 = _snap(
            {
                Fields.QUESTION_TEXT: "Q1",
                Fields.ANSWER_TEXT: "A1",
                Fields.ANSWERED_AT: datetime.now(UTC),
                Fields.IS_ANSWERED: True,
                Fields.UPVOTES: 2,
                Fields.CREATED_AT: datetime.now(UTC),
            },
            doc_id="q1",
        )

        q = Mock()
        q.where.return_value = q
        q.order_by.return_value = q
        q.limit.return_value = q
        q.stream.return_value = [d1]

        col = Mock()
        col.where.return_value = q

        db = Mock()
        db.collection.return_value = col
        mock_get_db.return_value = db

        out = get_product_questions(_req("u1", {Fields.PRODUCT_ID: "p1", "answeredOnly": True, "limit": 5}))

        assert out["questions"][0][Fields.QUESTION_ID] == "q1"
        assert out["total"] == 1


class TestModerationReviewAndVoting:
    @patch("handlers.products.get_firestore")
    @patch("handlers.products.get_db")
    def test_admin_delete_product_question_success(self, mock_get_db, mock_get_firestore):
        from handlers.products import admin_delete_product_question

        mock_get_firestore.return_value.transactional = lambda fn: fn

        tx = Mock()
        question_ref = Mock()
        question_ref.get.return_value = _snap({Fields.QUESTION_TEXT: "Q"})

        questions_col = Mock()
        questions_col.document.return_value = question_ref

        db = Mock()
        db.collection.side_effect = lambda name: questions_col if name == Collections.PRODUCT_QUESTIONS else Mock()
        db.transaction.return_value = tx
        mock_get_db.return_value = db

        req = _req("admin_1", {Fields.QUESTION_ID: "q1", "reason": "Spam"}, token={"admin": True})
        out = admin_delete_product_question(req)

        assert out[ApiKeys.SUCCESS] is True
        tx.set.assert_called_once()
        tx.delete.assert_called_once_with(question_ref)

    @patch("handlers.products.get_db")
    def test_admin_delete_product_question_denied_without_admin(self, mock_get_db):
        from handlers.products import admin_delete_product_question

        user_doc = _snap({Fields.ROLES: [UserRoleValues.SELLER]})
        users_col = Mock()
        users_col.document.return_value.get.return_value = user_doc

        db = Mock()
        db.collection.side_effect = lambda name: users_col if name == Collections.USERS else Mock()
        mock_get_db.return_value = db

        req = _req("u1", {Fields.QUESTION_ID: "q1"}, token={"admin": False})

        with pytest.raises(https_fn.HttpsError) as exc:
            admin_delete_product_question(req)
        assert exc.value.code == "permission-denied"

    @patch("handlers.products.get_firestore")
    @patch("handlers.products.get_db")
    def test_admin_delete_product_rating_recalculates_average(self, mock_get_db, mock_get_firestore):
        from handlers.products import admin_delete_product_rating

        mock_get_firestore.return_value.transactional = lambda fn: fn

        tx = Mock()
        rating_ref = Mock()
        rating_ref.get.return_value = _snap({Fields.PRODUCT_ID: "p1", Fields.RATING: 4}, doc_id="r1")

        ratings_col = Mock()
        ratings_col.document.return_value = rating_ref

        product_ref = Mock()
        product_ref.get.return_value = _snap({Fields.RATING: 5.0, Fields.RATING_COUNT: 2})
        products_col = Mock()
        products_col.document.return_value = product_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.PRODUCT_RATINGS: ratings_col,
            Collections.PRODUCTS: products_col,
        }.get(name, Mock())
        db.transaction.return_value = tx
        mock_get_db.return_value = db

        req = _req("admin_1", {"ratingId": "r1", "reason": "Abusive"}, token={"admin": True})
        out = admin_delete_product_rating(req)

        assert out[ApiKeys.SUCCESS] is True
        tx.update.assert_called_once()
        tx.delete.assert_called_once_with(rating_ref)

    @patch("utils.helpers.sanitized_text", side_effect=lambda s: s)
    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_answer_review_success(self, mock_get_db, mock_rl, _mock_sanitized):
        from handlers.products import answer_review

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        product_ref = Mock()
        product_ref.get.return_value = _snap({Fields.SELLER_ID: "seller_1"})

        rating_ref = Mock()
        rating_ref.get.return_value = _snap({Fields.PRODUCT_ID: "p1"})

        products_col = Mock()
        products_col.document.return_value = product_ref

        ratings_col = Mock()
        ratings_col.document.return_value = rating_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.PRODUCTS: products_col,
            Collections.PRODUCT_RATINGS: ratings_col,
        }[name]
        mock_get_db.return_value = db

        req = _req(
            "seller_1",
            {Fields.RATING_ID: "r1", Fields.PRODUCT_ID: "p1", Fields.SELLER_REPLY: "Thanks for your feedback!"},
        )
        out = answer_review(req)

        assert out["replied"] is True
        rating_ref.update.assert_called_once()

    @patch("utils.helpers.sanitized_text", side_effect=lambda s: s)
    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_answer_review_edit_blocked_after_24h(self, mock_get_db, mock_rl, _mock_sanitized):
        from handlers.products import answer_review

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        product_ref = Mock()
        product_ref.get.return_value = _snap({Fields.SELLER_ID: "seller_1"})

        rating_ref = Mock()
        rating_ref.get.return_value = _snap(
            {
                Fields.PRODUCT_ID: "p1",
                Fields.SELLER_REPLY: "old",
                Fields.SELLER_REPLY_AT: datetime.now(UTC) - timedelta(days=2),
            }
        )

        products_col = Mock()
        products_col.document.return_value = product_ref

        ratings_col = Mock()
        ratings_col.document.return_value = rating_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.PRODUCTS: products_col,
            Collections.PRODUCT_RATINGS: ratings_col,
        }[name]
        mock_get_db.return_value = db

        req = _req(
            "seller_1",
            {Fields.RATING_ID: "r1", Fields.PRODUCT_ID: "p1", Fields.SELLER_REPLY: "Updated reply"},
        )

        with pytest.raises(https_fn.HttpsError) as exc:
            answer_review(req)
        assert exc.value.code == "already-exists"

    @patch("firebase_admin.firestore.transactional", lambda fn: fn)
    @patch("handlers.products.create_success_response", side_effect=lambda payload: payload)
    @patch("handlers.products.get_db")
    def test_vote_review_helpful_add_vote_success(self, mock_get_db, _mock_resp):
        from handlers.products import vote_review_helpful

        tx = Mock()

        rating_ref = Mock()
        rating_ref.get.return_value = _snap(
            {Fields.PRODUCT_ID: "p1", Fields.USER_ID: "reviewer_1", Fields.HELPFUL_COUNT: 1}
        )

        vote_ref = Mock()
        vote_ref.get.return_value = _snap(exists=False)
        rating_ref.collection.return_value.document.return_value = vote_ref

        ratings_col = Mock()
        ratings_col.document.return_value = rating_ref

        product_ref = Mock()
        product_ref.get.return_value = _snap({Fields.SELLER_ID: "seller_x"})
        products_col = Mock()
        products_col.document.return_value = product_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.PRODUCT_RATINGS: ratings_col,
            Collections.PRODUCTS: products_col,
        }[name]
        db.transaction.return_value = tx
        mock_get_db.return_value = db

        req = _req("u1", {Fields.RATING_ID: "r1", Fields.PRODUCT_ID: "p1", "helpful": True})
        out = vote_review_helpful(req)

        assert out["helpfulCount"] == 2
        tx.set.assert_called_once()
        tx.update.assert_called_once()

    @patch("firebase_admin.firestore.transactional", lambda fn: fn)
    @patch("handlers.products.get_db")
    def test_vote_review_helpful_remove_without_existing_vote_fails(self, mock_get_db):
        from handlers.products import vote_review_helpful

        tx = Mock()

        rating_ref = Mock()
        rating_ref.get.return_value = _snap(
            {Fields.PRODUCT_ID: "p1", Fields.USER_ID: "reviewer_1", Fields.HELPFUL_COUNT: 1}
        )

        vote_ref = Mock()
        vote_ref.get.return_value = _snap(exists=False)
        rating_ref.collection.return_value.document.return_value = vote_ref

        ratings_col = Mock()
        ratings_col.document.return_value = rating_ref

        product_ref = Mock()
        product_ref.get.return_value = _snap({Fields.SELLER_ID: "seller_x"})
        products_col = Mock()
        products_col.document.return_value = product_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.PRODUCT_RATINGS: ratings_col,
            Collections.PRODUCTS: products_col,
        }[name]
        db.transaction.return_value = tx
        mock_get_db.return_value = db

        req = _req("u1", {Fields.RATING_ID: "r1", Fields.PRODUCT_ID: "p1", "helpful": False})

        with pytest.raises(https_fn.HttpsError) as exc:
            vote_review_helpful(req)
        assert exc.value.code == "failed-precondition"


class TestBulkAndUpdateOperations:
    def test_bulk_update_products_requires_auth(self):
        from handlers.products import bulk_update_products

        with pytest.raises(https_fn.HttpsError) as exc:
            bulk_update_products(_req(None, {"productIds": ["p1"], Fields.ACTION: "pause"}))
        assert exc.value.code == "unauthenticated"

    def test_bulk_update_products_rejects_empty_product_ids(self):
        from handlers.products import bulk_update_products

        with pytest.raises(https_fn.HttpsError) as exc:
            bulk_update_products(_req("seller_1", {"productIds": [], Fields.ACTION: "pause"}))
        assert exc.value.code == "invalid-argument"

    def test_bulk_update_products_rejects_invalid_action(self):
        from handlers.products import bulk_update_products

        with pytest.raises(https_fn.HttpsError) as exc:
            bulk_update_products(_req("seller_1", {"productIds": ["p1"], Fields.ACTION: "bad_action"}))
        assert exc.value.code == "invalid-argument"

    def test_bulk_update_products_rejects_more_than_50_products(self):
        from handlers.products import bulk_update_products

        too_many = [f"p{i}" for i in range(51)]
        with pytest.raises(https_fn.HttpsError) as exc:
            bulk_update_products(_req("seller_1", {"productIds": too_many, Fields.ACTION: "pause"}))
        assert exc.value.code == "invalid-argument"

    @patch("handlers.products.create_success_response", side_effect=lambda payload: payload)
    @patch("handlers.products.get_db")
    def test_bulk_update_products_skips_invalid_and_missing_product_ids(self, mock_get_db, _mock_resp):
        from handlers.products import bulk_update_products

        p1_ref = Mock(id="p1")
        p1_snap = _snap({Fields.SELLER_ID: "seller_1", Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE}, doc_id="p1")
        p1_ref.get.return_value = p1_snap

        products_col = Mock()
        products_col.document.return_value = p1_ref

        batch = Mock()
        db = Mock()
        db.collection.return_value = products_col
        db.batch.return_value = batch
        db.get_all.side_effect = lambda refs: [ref.get() for ref in refs]
        mock_get_db.return_value = db

        req = _req("seller_1", {"productIds": ["p1", " ", 123, "missing"], Fields.ACTION: "pause"})
        out = bulk_update_products(req)

        assert out["updated"] == 1
        assert out["skipped"] == 3
        batch.commit.assert_called_once()

    @patch("handlers.products.algolia_partial_update")
    @patch("handlers.products.create_success_response", side_effect=lambda payload: payload)
    @patch("handlers.products.get_db")
    def test_bulk_update_products_activate_updates_paused_and_reindexes(
        self,
        mock_get_db,
        _mock_resp,
        mock_algolia,
    ):
        from handlers.products import bulk_update_products

        p1_ref = Mock(id="p1")
        p2_ref = Mock(id="p2")

        p1_snap = _snap({Fields.SELLER_ID: "seller_1", Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.PAUSED}, doc_id="p1")
        p2_snap = _snap({Fields.SELLER_ID: "seller_1", Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE}, doc_id="p2")
        p1_ref.get.return_value = p1_snap
        p2_ref.get.return_value = p2_snap

        products_col = Mock()
        products_col.document.side_effect = lambda pid: {"p1": p1_ref, "p2": p2_ref}[pid]

        batch = Mock()

        db = Mock()
        db.collection.return_value = products_col
        db.batch.return_value = batch
        db.get_all.side_effect = lambda refs: [ref.get() for ref in refs]
        mock_get_db.return_value = db

        req = _req("seller_1", {"productIds": ["p1", "p2"], Fields.ACTION: "activate"})
        out = bulk_update_products(req)

        assert out["updated"] == 1
        assert out["skipped"] == 1
        batch.commit.assert_called_once()
        mock_algolia.assert_called_once_with("p1", {Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE})

    @patch("handlers.products.algolia_partial_update")
    @patch("handlers.products.create_success_response", side_effect=lambda payload: payload)
    @patch("handlers.products.get_db")
    def test_bulk_update_products_archive_cleans_favorites(self, mock_get_db, _mock_resp, _mock_algolia):
        from handlers.products import bulk_update_products

        p1_ref = Mock(id="p1")
        p1_snap = _snap({Fields.SELLER_ID: "seller_1", Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE}, doc_id="p1")
        p1_ref.get.return_value = p1_snap

        products_col = Mock()
        products_col.document.return_value = p1_ref

        fav1 = _snap(doc_id="f1")
        fav_query = Mock()
        fav_query.where.return_value = fav_query
        fav_query.limit.return_value = fav_query
        fav_query.stream.return_value = [fav1]

        product_batch = Mock()
        fav_batch = Mock()

        db = Mock()
        db.collection.return_value = products_col
        db.collection_group.return_value = fav_query
        db.batch.side_effect = [product_batch, fav_batch]
        db.get_all.side_effect = lambda refs: [ref.get() for ref in refs]
        mock_get_db.return_value = db

        req = _req("seller_1", {"productIds": ["p1"], Fields.ACTION: "archive"})
        out = bulk_update_products(req)

        assert out["updated"] == 1
        product_batch.commit.assert_called_once()
        fav_batch.delete.assert_called_once_with(fav1.reference)
        fav_batch.commit.assert_called_once()

    @patch("handlers.products.algolia_partial_update")
    @patch("handlers.products.create_success_response", side_effect=lambda payload: payload)
    @patch("handlers.products.get_db")
    def test_bulk_update_products_archive_handles_missing_non_owner_and_empty_favorite_pages(
        self, mock_get_db, _mock_resp, _mock_algolia
    ):
        from handlers.products import bulk_update_products

        missing_ref = Mock(id="missing")
        missing_ref.get.return_value = _snap(exists=False, doc_id="missing")
        other_ref = Mock(id="other")
        other_ref.get.return_value = _snap(
            {Fields.SELLER_ID: "seller_other", Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE},
            doc_id="other",
        )
        mine_ref = Mock(id="mine")
        mine_ref.get.return_value = _snap(
            {Fields.SELLER_ID: "seller_1", Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE},
            doc_id="mine",
        )

        products_col = Mock()
        products_col.document.side_effect = lambda pid: {
            "missing": missing_ref,
            "other": other_ref,
            "mine": mine_ref,
        }[pid]

        fav_query = Mock()
        fav_query.where.return_value = fav_query
        fav_query.limit.return_value = fav_query
        fav_query.stream.return_value = []

        product_batch = Mock()
        db = Mock()
        db.collection.return_value = products_col
        db.collection_group.return_value = fav_query
        db.batch.return_value = product_batch
        db.get_all.side_effect = lambda refs: [ref.get() for ref in refs]
        mock_get_db.return_value = db

        out = bulk_update_products(_req("seller_1", {"productIds": ["missing", "other", "mine"], Fields.ACTION: "archive"}))

        assert out["updated"] == 1
        assert out["skipped"] == 2
        product_batch.commit.assert_called_once()

    @patch("handlers.products.algolia_partial_update", side_effect=RuntimeError("algolia down"))
    @patch("handlers.products.create_success_response", side_effect=lambda payload: payload)
    @patch("handlers.products.get_db")
    def test_bulk_update_products_activate_handles_algolia_reindex_error(self, mock_get_db, _mock_resp, _mock_algolia):
        from handlers.products import bulk_update_products

        p1_ref = Mock(id="p1")
        p1_ref.get.return_value = _snap(
            {Fields.SELLER_ID: "seller_1", Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.PAUSED},
            doc_id="p1",
        )
        products_col = Mock()
        products_col.document.return_value = p1_ref

        batch = Mock()
        db = Mock()
        db.collection.return_value = products_col
        db.batch.return_value = batch
        db.get_all.side_effect = lambda refs: [ref.get() for ref in refs]
        mock_get_db.return_value = db

        out = bulk_update_products(_req("seller_1", {"productIds": ["p1"], Fields.ACTION: "activate"}))
        assert out["updated"] == 1
        assert out["skipped"] == 0
        batch.commit.assert_called_once()

    @patch("handlers.products.create_success_response", side_effect=lambda payload: payload)
    @patch("handlers.products.algolia_partial_update")
    @patch("handlers.products.get_db")
    def test_deactivate_supplier_platform_success(
        self,
        mock_get_db,
        mock_algolia,
        _mock_resp,
    ):
        from handlers.products import deactivate_supplier_platform

        admin_doc = _snap({Fields.ROLES: [UserRoleValues.ADMIN]})
        users_col = Mock()
        users_col.document.return_value.get.return_value = admin_doc

        active_doc = _snap({Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE}, doc_id="p1")
        active_doc.reference = Mock()

        prod_query = Mock()
        prod_query.where.return_value = prod_query
        prod_query.limit.return_value = prod_query
        prod_query.stream.return_value = [active_doc]
        prod_query.start_after.return_value = prod_query

        products_col = Mock()
        products_col.where.return_value = prod_query

        batch = Mock()

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
        }[name]
        db.batch.return_value = batch
        mock_get_db.return_value = db

        req = _req("admin_1", {"supplierType": SupplierTypeValues.ALIEXPRESS})
        out = deactivate_supplier_platform(req)

        assert out["updated"] == 1
        batch.update.assert_called_once()
        batch.commit.assert_called_once()
        mock_algolia.assert_called_once()

    @patch("handlers.products.get_db")
    def test_deactivate_supplier_platform_requires_auth(self, mock_get_db):
        from handlers.products import deactivate_supplier_platform

        with pytest.raises(https_fn.HttpsError) as exc:
            deactivate_supplier_platform(_req(None, {"supplierType": SupplierTypeValues.ALIEXPRESS}))
        assert "unauth" in str(exc.value.code).lower()
        mock_get_db.assert_not_called()

    @patch("handlers.products.get_db")
    def test_deactivate_supplier_platform_requires_existing_admin_user(self, mock_get_db):
        from handlers.products import deactivate_supplier_platform

        users_col = Mock()
        users_col.document.return_value.get.return_value = _snap(exists=False)

        db = Mock()
        db.collection.side_effect = lambda name: {Collections.USERS: users_col}[name]
        mock_get_db.return_value = db

        with pytest.raises(https_fn.HttpsError) as exc:
            deactivate_supplier_platform(_req("u1", {"supplierType": SupplierTypeValues.ALIEXPRESS}))
        assert "User not found" in str(exc.value)

    @patch("handlers.products.get_db")
    def test_deactivate_supplier_platform_rejects_non_admin(self, mock_get_db):
        from handlers.products import deactivate_supplier_platform

        users_col = Mock()
        users_col.document.return_value.get.return_value = _snap({Fields.ROLES: [UserRoleValues.BUYER]})

        db = Mock()
        db.collection.side_effect = lambda name: {Collections.USERS: users_col}[name]
        mock_get_db.return_value = db

        with pytest.raises(https_fn.HttpsError) as exc:
            deactivate_supplier_platform(_req("u1", {"supplierType": SupplierTypeValues.ALIEXPRESS}))
        assert "permission" in str(exc.value.code).lower()

    @patch("handlers.products.get_db")
    def test_deactivate_supplier_platform_rejects_invalid_supplier_type(self, mock_get_db):
        from handlers.products import deactivate_supplier_platform

        users_col = Mock()
        users_col.document.return_value.get.return_value = _snap({Fields.ROLES: [UserRoleValues.ADMIN]})

        db = Mock()
        db.collection.side_effect = lambda name: {Collections.USERS: users_col}[name]
        mock_get_db.return_value = db

        with pytest.raises(https_fn.HttpsError) as exc:
            deactivate_supplier_platform(_req("admin_1", {"supplierType": "definitely_invalid"}))
        assert "invalid" in str(exc.value.code).lower()

    @patch("handlers.products.get_db")
    def test_deactivate_supplier_platform_requires_supplier_type(self, mock_get_db):
        from handlers.products import deactivate_supplier_platform

        users_col = Mock()
        users_col.document.return_value.get.return_value = _snap({Fields.ROLES: [UserRoleValues.ADMIN]})
        db = Mock()
        db.collection.side_effect = lambda name: {Collections.USERS: users_col}[name]
        mock_get_db.return_value = db

        with pytest.raises(https_fn.HttpsError) as exc:
            deactivate_supplier_platform(_req("admin_1", {"supplierType": "   "}))
        assert "invalid" in str(exc.value.code).lower()

    @patch("handlers.products.create_success_response", side_effect=lambda payload: payload)
    @patch("handlers.products.get_db")
    def test_deactivate_supplier_platform_no_matching_products_returns_zero(self, mock_get_db, _mock_resp):
        from handlers.products import deactivate_supplier_platform

        users_col = Mock()
        users_col.document.return_value.get.return_value = _snap({Fields.ROLES: [UserRoleValues.ADMIN]})

        prod_query = Mock()
        prod_query.where.return_value = prod_query
        prod_query.limit.return_value = prod_query
        prod_query.stream.return_value = []
        prod_query.start_after.return_value = prod_query

        products_col = Mock()
        products_col.where.return_value = prod_query

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
        }[name]
        mock_get_db.return_value = db

        out = deactivate_supplier_platform(_req("admin_1", {"supplierType": SupplierTypeValues.ALIEXPRESS}))
        assert out == {"updated": 0, "skipped": 0}
        db.batch.assert_not_called()

    @patch("handlers.products.algolia_partial_update", side_effect=RuntimeError("index fail"))
    @patch("handlers.products.create_success_response", side_effect=lambda payload: payload)
    @patch("handlers.products.get_db")
    def test_deactivate_supplier_platform_handles_paused_docs_pagination_and_algolia_error(
        self, mock_get_db, _mock_resp, _mock_algolia
    ):
        from handlers.products import deactivate_supplier_platform

        users_col = Mock()
        users_col.document.return_value.get.return_value = _snap({Fields.ROLES: [UserRoleValues.ADMIN]})

        paused_page = []
        for i in range(499):
            d = _snap({Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.PAUSED}, doc_id=f"p{i}")
            d.reference = Mock()
            paused_page.append(d)
        active_doc = _snap({Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE}, doc_id="p_active")
        active_doc.reference = Mock()
        page1 = paused_page + [active_doc]  # len=500 exercises cursor path

        prod_query = Mock()
        prod_query.where.return_value = prod_query
        prod_query.limit.return_value = prod_query
        prod_query.stream.side_effect = [page1, []]
        prod_query.start_after.return_value = prod_query
        products_col = Mock()
        products_col.where.return_value = prod_query

        batch = Mock()
        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.PRODUCTS: products_col,
        }[name]
        db.batch.return_value = batch
        mock_get_db.return_value = db

        out = deactivate_supplier_platform(_req("admin_1", {"supplierType": SupplierTypeValues.ALIEXPRESS}))
        assert out["updated"] == 1
        assert out["skipped"] == 499
        batch.update.assert_called_once_with(
            active_doc.reference,
            {Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.PAUSED, Fields.UPDATED_AT: batch.update.call_args.args[1][Fields.UPDATED_AT]},
        )
        batch.commit.assert_called_once()

    @patch("handlers.products.create_success_response", side_effect=lambda payload: payload)
    @patch("handlers.products.get_server_timestamp", return_value="ts")
    @patch("handlers.products._get_cached_s3_client")
    @patch("handlers.products.ProductUpdate", _FakeProductUpdate)
    @patch("handlers.products.get_db")
    def test_update_product_sensitive_fields_retrigger_review_and_supplier_private_update(
        self,
        mock_get_db,
        _mock_s3,
        _mock_ts,
        _mock_resp,
    ):
        from handlers.products import CDN_BASE_URL, update_product

        product_ref = Mock()
        product_ref.get.return_value = _snap(
            {
                Fields.SELLER_ID: "seller_1",
                Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.ACTIVE,
                Fields.VIDEO_URL: f"{CDN_BASE_URL}/old.mp4",
                Fields.CATEGORY_ID: 1,
            }
        )

        supplier_private_ref = Mock()
        supplier_private_col = Mock()
        supplier_private_col.document.return_value = supplier_private_ref
        product_ref.collection.return_value = supplier_private_col

        products_col = Mock()
        products_col.document.return_value = product_ref

        db = Mock()
        db.collection.return_value = products_col
        mock_get_db.return_value = db

        req = _req(
            "seller_1",
            {
                ApiKeys.PRODUCT_ID: "p1",
                ApiKeys.PRODUCT_DATA: {
                    Fields.VIDEO_URL: f"{CDN_BASE_URL}/new.mp4",
                    Fields.IS_DIGITAL: True,
                    "supplier": {"type": SupplierTypeValues.CUSTOM, "supplierUrl": "https://example.com"},
                },
            },
        )

        out = update_product(req)

        assert out["updated"] is True
        update_payload = product_ref.update.call_args.args[0]
        assert update_payload[Fields.LIFECYCLE_STATUS] == ProductLifecycleStatusValues.UNDER_REVIEW
        assert update_payload[Fields.UPDATED_AT] == "ts"
        supplier_private_ref.set.assert_called_once()

    @patch("handlers.products.ProductUpdate", _FakeProductUpdate)
    @patch("handlers.products.get_db")
    def test_update_product_invalid_video_origin_rejected(self, mock_get_db):
        from handlers.products import update_product

        product_ref = Mock()
        product_ref.get.return_value = _snap({Fields.SELLER_ID: "seller_1", Fields.CATEGORY_ID: 1})

        products_col = Mock()
        products_col.document.return_value = product_ref

        db = Mock()
        db.collection.return_value = products_col
        mock_get_db.return_value = db

        req = _req(
            "seller_1",
            {
                ApiKeys.PRODUCT_ID: "p1",
                ApiKeys.PRODUCT_DATA: {Fields.VIDEO_URL: "https://evil.example/video.mp4"},
            },
        )

        with pytest.raises(https_fn.HttpsError) as exc:
            update_product(req)
        assert exc.value.code == "invalid-argument"

    @patch("handlers.products.get_db")
    def test_update_product_denies_non_owner_non_admin(self, mock_get_db):
        from handlers.products import update_product

        product_ref = Mock()
        product_ref.get.return_value = _snap({Fields.SELLER_ID: "seller_1", Fields.CATEGORY_ID: 1})

        products_col = Mock()
        products_col.document.return_value = product_ref

        user_doc = _snap({Fields.ROLES: [UserRoleValues.BUYER]})
        users_col = Mock()
        users_col.document.return_value.get.return_value = user_doc

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.PRODUCTS: products_col,
            Collections.USERS: users_col,
        }[name]
        mock_get_db.return_value = db

        req = _req(
            "intruder",
            {
                ApiKeys.PRODUCT_ID: "p1",
                ApiKeys.PRODUCT_DATA: {Fields.NAME: "New Name"},
            },
        )

        with pytest.raises(https_fn.HttpsError) as exc:
            update_product(req)
        assert exc.value.code == "permission-denied"

    def test_update_product_requires_auth(self):
        from handlers.products import update_product

        with pytest.raises(https_fn.HttpsError) as exc:
            update_product(_req(None, {ApiKeys.PRODUCT_ID: "p1", ApiKeys.PRODUCT_DATA: {Fields.NAME: "x"}}))
        assert exc.value.code == "unauthenticated"

    def test_update_product_requires_product_id_and_payload(self):
        from handlers.products import update_product

        with pytest.raises(https_fn.HttpsError) as exc:
            update_product(_req("seller_1", {ApiKeys.PRODUCT_ID: "p1"}))
        assert exc.value.code == "invalid-argument"

    @patch("handlers.products.get_db")
    def test_update_product_rejects_missing_product(self, mock_get_db):
        from handlers.products import update_product

        product_ref = Mock()
        product_ref.get.return_value = _snap(exists=False)
        products_col = Mock()
        products_col.document.return_value = product_ref

        db = Mock()
        db.collection.return_value = products_col
        mock_get_db.return_value = db

        with pytest.raises(https_fn.HttpsError) as exc:
            update_product(_req("seller_1", {ApiKeys.PRODUCT_ID: "p1", ApiKeys.PRODUCT_DATA: {Fields.NAME: "new"}}))
        assert exc.value.code == "not-found"

    @patch("handlers.products.ProductUpdate", _FakeProductUpdate)
    @patch("handlers.products.get_db")
    def test_update_product_rejects_invalid_subcategory_for_category(self, mock_get_db):
        from handlers.products import update_product

        product_ref = Mock()
        product_ref.get.return_value = _snap({Fields.SELLER_ID: "seller_1", Fields.CATEGORY_ID: 1})
        products_col = Mock()
        products_col.document.return_value = product_ref

        db = Mock()
        db.collection.return_value = products_col
        mock_get_db.return_value = db

        req = _req(
            "seller_1",
            {
                ApiKeys.PRODUCT_ID: "p1",
                ApiKeys.PRODUCT_DATA: {Fields.SUBCATEGORY: "not-a-valid-subcategory"},
            },
        )
        with pytest.raises(https_fn.HttpsError) as exc:
            update_product(req)
        assert exc.value.code == "invalid-argument"

    @patch("handlers.products.create_success_response", side_effect=lambda payload: payload)
    @patch("handlers.products.get_server_timestamp", return_value="ts")
    @patch("handlers.products._get_cached_s3_client")
    @patch("handlers.products.ProductUpdate", _FakeProductUpdate)
    @patch("handlers.products.get_db")
    def test_update_product_replaces_video_and_deletes_old_object(
        self,
        mock_get_db,
        mock_s3,
        _mock_ts,
        _mock_resp,
    ):
        from handlers.products import CDN_BASE_URL, update_product

        product_ref = Mock()
        product_ref.get.return_value = _snap(
            {
                Fields.SELLER_ID: "seller_1",
                Fields.CATEGORY_ID: 1,
                Fields.VIDEO_URL: f"{CDN_BASE_URL}/videos/old.mp4",
            }
        )
        products_col = Mock()
        products_col.document.return_value = product_ref

        db = Mock()
        db.collection.return_value = products_col
        mock_get_db.return_value = db

        req = _req(
            "seller_1",
            {
                ApiKeys.PRODUCT_ID: "p1",
                ApiKeys.PRODUCT_DATA: {Fields.VIDEO_URL: f"{CDN_BASE_URL}/videos/new.mp4"},
            },
        )
        out = update_product(req)
        assert out["updated"] is True
        mock_s3.return_value.delete_object.assert_called_once()
        delete_kwargs = mock_s3.return_value.delete_object.call_args.kwargs
        assert delete_kwargs["Key"] == "videos/old.mp4"
        assert "Bucket" in delete_kwargs

    @patch(
        "handlers.products.ProductUpdate",
        side_effect=ValidationError.from_exception_data(
            "ProductUpdate",
            [{"type": "string_type", "loc": ("name",), "msg": "Input should be a valid string", "input": 123}],
        ),
    )
    @patch("handlers.products.get_db")
    def test_update_product_validation_error_is_mapped_to_invalid_argument(self, mock_get_db, _mock_update):
        from handlers.products import update_product

        product_ref = Mock()
        product_ref.get.return_value = _snap({Fields.SELLER_ID: "seller_1", Fields.CATEGORY_ID: 1})
        products_col = Mock()
        products_col.document.return_value = product_ref

        db = Mock()
        db.collection.return_value = products_col
        mock_get_db.return_value = db

        req = _req("seller_1", {ApiKeys.PRODUCT_ID: "p1", ApiKeys.PRODUCT_DATA: {Fields.NAME: 123}})
        with pytest.raises(https_fn.HttpsError) as exc:
            update_product(req)
        assert exc.value.code == "invalid-argument"


class TestPriceHistoryHelpers:
    @patch("handlers.products.get_db")
    def test_track_price_history_no_change_no_write(self, mock_get_db):
        from handlers.products import _track_price_history

        _track_price_history(
            "p1",
            {Fields.PRICE: 10.0, Fields.COMPARE_AT_PRICE: 12.0},
            {Fields.PRICE: 10.0, Fields.COMPARE_AT_PRICE: 12.0},
        )
        mock_get_db.assert_not_called()

    @patch("firebase_admin.firestore.ArrayUnion", side_effect=lambda payload: ("AU", payload))
    @patch("handlers.products.get_db")
    def test_track_price_history_appends_entry_with_array_union(self, mock_get_db, _mock_array_union):
        from handlers.products import _track_price_history

        product_ref = Mock()
        products_col = Mock()
        products_col.document.return_value = product_ref

        db = Mock()
        db.collection.return_value = products_col
        mock_get_db.return_value = db

        _track_price_history(
            "p1",
            {Fields.PRICE: 10.0, Fields.COMPARE_AT_PRICE: 12.0},
            {Fields.PRICE: 8.5, Fields.COMPARE_AT_PRICE: 11.0},
        )

        product_ref.update.assert_called_once()

    @patch("services.push_service.send_push_notifications_batch", return_value=2)
    @patch("handlers.products.get_db")
    def test_fire_price_drop_notifications_significant_drop_sends_pushes(self, mock_get_db, mock_push):
        from handlers.products import _fire_price_drop_notifications

        page1 = [_favorite_doc(f"u{i}") for i in range(500)]
        page2 = [_favorite_doc("u501")]

        q = Mock()
        q.where.return_value = q
        q.order_by.return_value = q
        q.limit.return_value = q
        q.start_after.return_value = q
        q.stream.side_effect = [page1, page2]

        db = Mock()
        db.collection_group.return_value = q
        mock_get_db.return_value = db

        _fire_price_drop_notifications("p1", 100.0, 85.0, "Widget")

        assert q.start_after.called
        assert mock_push.call_count == 1
        args = mock_push.call_args.args
        assert len(args[0]) == 501

    @patch("handlers.products.get_db")
    def test_fire_price_drop_notifications_small_drop_skips(self, mock_get_db):
        from handlers.products import _fire_price_drop_notifications

        _fire_price_drop_notifications("p1", 100.0, 95.0, "Widget")
        mock_get_db.assert_not_called()

    @patch("handlers.products.get_db")
    def test_fire_price_drop_notifications_non_positive_start_price_skips(self, mock_get_db):
        from handlers.products import _fire_price_drop_notifications

        _fire_price_drop_notifications("p1", 0.0, 0.0, "Widget")
        mock_get_db.assert_not_called()
