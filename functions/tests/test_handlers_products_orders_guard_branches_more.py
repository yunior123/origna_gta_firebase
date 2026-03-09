from datetime import UTC, datetime, timedelta
from unittest.mock import Mock, patch

import pytest
from firebase_functions import https_fn

from schema_constants import (
    Collections,
    DeliveryStatusValues,
    Fields,
    ProductLifecycleStatusValues,
    ReturnStatusValues,
    UserRoleValues,
)


def _req(uid: str | None, data: dict | None = None, token: dict | None = None):
    req = Mock()
    req.auth = Mock(uid=uid, token=(token or {})) if uid else None
    req.data = data or {}
    req.raw_request = Mock()
    req.raw_request.headers = {}
    return req


def _snap(data=None, *, exists=True, doc_id="doc_1"):
    snap = Mock()
    snap.exists = exists
    snap.id = doc_id
    snap.to_dict.return_value = {} if data is None else data
    snap.reference = Mock()
    return snap


class TestProductsGuardBranchesMore:
    def test_subscribe_stock_notification_requires_auth(self):
        from handlers.products import subscribe_stock_notification

        with pytest.raises(https_fn.HttpsError) as exc:
            subscribe_stock_notification(_req(None))
        assert exc.value.code == "unauthenticated"

    @patch("handlers.products.RateLimiter")
    def test_subscribe_stock_notification_requires_product_id(self, mock_rl):
        from handlers.products import subscribe_stock_notification

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        with pytest.raises(https_fn.HttpsError) as exc:
            subscribe_stock_notification(_req("u1", {}))
        assert exc.value.code == "invalid-argument"

    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_subscribe_stock_notification_product_and_user_guard_paths(self, mock_get_db, mock_rl):
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

        # Product missing
        products_col.document.return_value.get.return_value = _snap(exists=False)
        with pytest.raises(https_fn.HttpsError) as missing:
            subscribe_stock_notification(_req("u1", {Fields.PRODUCT_ID: "p1"}))
        assert missing.value.code == "not-found"

        # Seller cannot subscribe to own product
        products_col.document.return_value.get.return_value = _snap(
            {Fields.SELLER_ID: "u1", Fields.HAS_VARIANTS: False, Fields.STOCK_QUANTITY: 0}
        )
        with pytest.raises(https_fn.HttpsError) as own_product:
            subscribe_stock_notification(_req("u1", {Fields.PRODUCT_ID: "p1"}))
        assert own_product.value.code == "permission-denied"

        # Missing buyer email
        products_col.document.return_value.get.return_value = _snap(
            {Fields.SELLER_ID: "seller_2", Fields.HAS_VARIANTS: False, Fields.STOCK_QUANTITY: 0}
        )
        users_col.document.return_value.get.return_value = _snap({}, exists=True)
        with pytest.raises(https_fn.HttpsError) as no_email:
            subscribe_stock_notification(_req("u1", {Fields.PRODUCT_ID: "p1"}))
        assert no_email.value.code == "failed-precondition"

    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_subscribe_stock_notification_variant_specific_validation(self, mock_get_db, mock_rl):
        from handlers.products import subscribe_stock_notification

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        users_col = Mock()
        users_col.document.return_value.get.return_value = _snap({Fields.EMAIL: "buyer@example.com"}, exists=True)
        stock_query = Mock()
        stock_query.where.return_value = stock_query
        stock_query.limit.return_value = stock_query
        stock_query.stream.return_value = []
        stock_col = Mock()
        stock_col.where.return_value = stock_query
        products_col = Mock()

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.PRODUCTS: products_col,
            Collections.USERS: users_col,
            Collections.STOCK_NOTIFICATIONS: stock_col,
        }[name]
        mock_get_db.return_value = db

        # variantKey provided but product has no variants
        products_col.document.return_value.get.return_value = _snap(
            {Fields.SELLER_ID: "seller_2", Fields.HAS_VARIANTS: False, Fields.STOCK_QUANTITY: 0}
        )
        with pytest.raises(https_fn.HttpsError) as no_variants:
            subscribe_stock_notification(_req("u1", {Fields.PRODUCT_ID: "p1", Fields.VARIANT_KEY: "v1"}))
        assert no_variants.value.code == "invalid-argument"

        # Product has variants but variant key missing
        products_col.document.return_value.get.return_value = _snap(
            {Fields.SELLER_ID: "seller_2", Fields.HAS_VARIANTS: True, Fields.VARIANTS: []}
        )
        with pytest.raises(https_fn.HttpsError) as missing_variant_key:
            subscribe_stock_notification(_req("u1", {Fields.PRODUCT_ID: "p1"}))
        assert missing_variant_key.value.code == "invalid-argument"

        # Variant already in stock
        products_col.document.return_value.get.return_value = _snap(
            {
                Fields.SELLER_ID: "seller_2",
                Fields.HAS_VARIANTS: True,
                Fields.VARIANTS: [{Fields.VARIANT_ID: "v1", Fields.STOCK_QUANTITY: 2}],
            }
        )
        with pytest.raises(https_fn.HttpsError) as in_stock_variant:
            subscribe_stock_notification(_req("u1", {Fields.PRODUCT_ID: "p1", Fields.VARIANT_KEY: "v1"}))
        assert in_stock_variant.value.code == "failed-precondition"

    @patch("handlers.products.RateLimiter")
    def test_unsubscribe_and_toggle_favorite_require_product_id(self, mock_rl):
        from handlers.products import toggle_favorite, unsubscribe_stock_notification

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        with pytest.raises(https_fn.HttpsError) as unsub_exc:
            unsubscribe_stock_notification(_req("u1", {}))
        assert unsub_exc.value.code == "invalid-argument"

        with pytest.raises(https_fn.HttpsError) as fav_exc:
            toggle_favorite(_req("u1", {}))
        assert fav_exc.value.code == "invalid-argument"

    def test_toggle_favorite_requires_auth(self):
        from handlers.products import toggle_favorite

        with pytest.raises(https_fn.HttpsError) as exc:
            toggle_favorite(_req(None, {Fields.PRODUCT_ID: "p1"}))
        assert exc.value.code == "unauthenticated"

    @patch("handlers.products.get_server_timestamp", return_value="ts")
    @patch("handlers.products.get_firestore")
    @patch("handlers.products.get_db")
    def test_toggle_favorite_not_found_unavailable_and_internal(self, mock_get_db, mock_get_firestore, _mock_ts):
        from handlers.products import toggle_favorite

        mock_get_firestore.return_value.transactional = lambda fn: fn
        mock_get_firestore.return_value.Increment.side_effect = lambda n: ("inc", n)

        product_ref = Mock()
        products_col = Mock()
        products_col.document.return_value = product_ref

        fav_ref = Mock()
        favorites_col = Mock()
        favorites_col.document.return_value = fav_ref
        user_ref = Mock()
        user_ref.collection.return_value = favorites_col
        users_col = Mock()
        users_col.document.return_value = user_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.PRODUCTS: products_col,
            Collections.USERS: users_col,
        }[name]
        db.transaction.return_value = Mock()
        mock_get_db.return_value = db

        # Product missing
        fav_ref.get.return_value = _snap(exists=False)
        product_ref.get.return_value = _snap(exists=False)
        with pytest.raises(https_fn.HttpsError) as not_found:
            toggle_favorite(_req("u1", {Fields.PRODUCT_ID: "p1"}))
        assert not_found.value.code == "not-found"

        # Product unavailable
        product_ref.get.return_value = _snap({Fields.LIFECYCLE_STATUS: ProductLifecycleStatusValues.PAUSED}, exists=True)
        with pytest.raises(https_fn.HttpsError) as unavailable:
            toggle_favorite(_req("u1", {Fields.PRODUCT_ID: "p1"}))
        assert unavailable.value.code == "failed-precondition"

        # Internal error path
        product_ref.get.side_effect = RuntimeError("transaction blew up")
        with pytest.raises(https_fn.HttpsError) as internal:
            toggle_favorite(_req("u1", {Fields.PRODUCT_ID: "p1"}))
        assert internal.value.code == "internal"

    def test_ask_answer_get_question_guard_paths(self):
        from handlers.products import answer_product_question, ask_product_question, get_product_questions

        with pytest.raises(https_fn.HttpsError) as ask_auth:
            ask_product_question(_req(None))
        assert ask_auth.value.code == "unauthenticated"

        with pytest.raises(https_fn.HttpsError) as answer_auth:
            answer_product_question(_req(None))
        assert answer_auth.value.code == "unauthenticated"

        with pytest.raises(https_fn.HttpsError) as list_auth:
            get_product_questions(_req(None))
        assert list_auth.value.code == "unauthenticated"

    @patch("handlers.products.RateLimiter")
    @patch("utils.premium_check.is_premium_authoritative", return_value=True)
    @patch("handlers.products.get_db")
    def test_ask_question_rate_limit_and_validation(self, mock_get_db, _mock_premium, mock_rl):
        from handlers.products import ask_product_question

        mock_rl.return_value.check_rate_limit.return_value = (False, "too many")
        with pytest.raises(https_fn.HttpsError) as limited:
            ask_product_question(_req("u1", {Fields.PRODUCT_ID: "p1", Fields.QUESTION_TEXT: "hello world"}))
        assert limited.value.code == "resource-exhausted"

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        with pytest.raises(https_fn.HttpsError) as missing_fields:
            ask_product_question(_req("u1", {Fields.PRODUCT_ID: "p1"}))
        assert missing_fields.value.code == "invalid-argument"

        with patch("utils.helpers.sanitized_text", side_effect=lambda s: s):
            with pytest.raises(https_fn.HttpsError) as too_short:
                ask_product_question(_req("u1", {Fields.PRODUCT_ID: "p1", Fields.QUESTION_TEXT: "short"}))
            assert too_short.value.code == "invalid-argument"

        # Product not found
        db = Mock()
        db.collection.return_value.document.return_value.get.return_value = _snap(exists=False)
        mock_get_db.return_value = db
        with patch("utils.helpers.sanitized_text", side_effect=lambda s: s):
            with pytest.raises(https_fn.HttpsError) as not_found:
                ask_product_question(
                    _req("u1", {Fields.PRODUCT_ID: "p_missing", Fields.QUESTION_TEXT: "Is this available tomorrow?"})
                )
            assert not_found.value.code == "not-found"

    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_answer_question_validation_branches(self, mock_get_db, mock_rl):
        from handlers.products import answer_product_question

        mock_rl.return_value.check_rate_limit.return_value = (False, "slow down")
        with pytest.raises(https_fn.HttpsError) as limited:
            answer_product_question(_req("seller_1", {Fields.QUESTION_ID: "q1", Fields.ANSWER_TEXT: "valid answer text"}))
        assert limited.value.code == "resource-exhausted"

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        with pytest.raises(https_fn.HttpsError) as missing_fields:
            answer_product_question(_req("seller_1", {Fields.QUESTION_ID: "q1"}))
        assert missing_fields.value.code == "invalid-argument"

        with patch("utils.helpers.sanitized_text", side_effect=lambda s: s):
            with pytest.raises(https_fn.HttpsError) as short_answer:
                answer_product_question(_req("seller_1", {Fields.QUESTION_ID: "q1", Fields.ANSWER_TEXT: "short"}))
            assert short_answer.value.code == "invalid-argument"

        # Question not found
        db = Mock()
        db.collection.return_value.document.return_value.get.return_value = _snap(exists=False)
        mock_get_db.return_value = db
        with patch("utils.helpers.sanitized_text", side_effect=lambda s: s):
            with pytest.raises(https_fn.HttpsError) as not_found:
                answer_product_question(_req("seller_1", {Fields.QUESTION_ID: "q_missing", Fields.ANSWER_TEXT: "valid answer"}))
            assert not_found.value.code == "not-found"

    @patch("handlers.products.get_db")
    def test_get_questions_requires_product_id(self, _mock_get_db):
        from handlers.products import get_product_questions

        with pytest.raises(https_fn.HttpsError) as exc:
            get_product_questions(_req("u1", {}))
        assert exc.value.code == "invalid-argument"

    @patch("handlers.products.get_db")
    def test_admin_delete_question_and_rating_guard_paths(self, mock_get_db):
        from handlers.products import admin_delete_product_question, admin_delete_product_rating

        with pytest.raises(https_fn.HttpsError) as q_auth:
            admin_delete_product_question(_req(None))
        assert q_auth.value.code == "unauthenticated"

        with pytest.raises(https_fn.HttpsError) as r_auth:
            admin_delete_product_rating(_req(None))
        assert r_auth.value.code == "unauthenticated"

        # token admin true but missing IDs
        with pytest.raises(https_fn.HttpsError) as q_missing:
            admin_delete_product_question(_req("admin_1", {}, token={"admin": True}))
        assert q_missing.value.code == "invalid-argument"

        with pytest.raises(https_fn.HttpsError) as r_missing:
            admin_delete_product_rating(_req("admin_1", {}, token={"admin": True}))
        assert r_missing.value.code == "invalid-argument"

        # Not found paths
        db = Mock()
        db.collection.return_value.document.return_value.get.return_value = _snap(exists=False)
        mock_get_db.return_value = db

        with pytest.raises(https_fn.HttpsError) as q_not_found:
            admin_delete_product_question(_req("admin_1", {Fields.QUESTION_ID: "q1"}, token={"admin": True}))
        assert q_not_found.value.code == "not-found"

        with pytest.raises(https_fn.HttpsError) as r_not_found:
            admin_delete_product_rating(_req("admin_1", {"ratingId": "r1"}, token={"admin": True}))
        assert r_not_found.value.code == "not-found"

        # Incomplete rating payload
        db.collection.return_value.document.return_value.get.return_value = _snap({Fields.RATING: 4}, exists=True)
        with pytest.raises(https_fn.HttpsError) as incomplete_rating:
            admin_delete_product_rating(_req("admin_1", {"ratingId": "r1"}, token={"admin": True}))
        assert incomplete_rating.value.code == "internal"

    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_answer_review_and_vote_helpful_guard_paths(self, mock_get_db, mock_rl):
        from handlers.products import answer_review, vote_review_helpful

        with pytest.raises(https_fn.HttpsError) as answer_auth:
            answer_review(_req(None))
        assert answer_auth.value.code == "unauthenticated"

        mock_rl.return_value.check_rate_limit.return_value = (False, "too many")
        with pytest.raises(https_fn.HttpsError) as answer_limited:
            answer_review(_req("seller_1", {Fields.RATING_ID: "r1", Fields.PRODUCT_ID: "p1", Fields.SELLER_REPLY: "ok"}))
        assert answer_limited.value.code == "resource-exhausted"

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        with pytest.raises(https_fn.HttpsError) as answer_missing:
            answer_review(_req("seller_1", {Fields.RATING_ID: "r1"}))
        assert answer_missing.value.code == "invalid-argument"

        with pytest.raises(https_fn.HttpsError) as vote_auth:
            vote_review_helpful(_req(None))
        assert vote_auth.value.code == "unauthenticated"

        with pytest.raises(https_fn.HttpsError) as vote_missing:
            vote_review_helpful(_req("u1", {}))
        assert vote_missing.value.code == "invalid-argument"

        with pytest.raises(https_fn.HttpsError) as vote_type:
            vote_review_helpful(_req("u1", {Fields.RATING_ID: "r1", Fields.PRODUCT_ID: "p1", "helpful": "yes"}))
        assert vote_type.value.code == "invalid-argument"

        # Rating not found in vote transaction path
        rating_ref = Mock()
        rating_ref.get.return_value = _snap(exists=False)
        rating_ref.collection.return_value.document.return_value.get.return_value = _snap(exists=False)
        db = Mock()
        db.collection.return_value.document.return_value = rating_ref
        db.transaction.return_value = Mock()
        mock_get_db.return_value = db

        with patch("firebase_admin.firestore.transactional", side_effect=lambda fn: fn):
            with pytest.raises(https_fn.HttpsError) as rating_missing:
                vote_review_helpful(_req("u1", {Fields.RATING_ID: "r1", Fields.PRODUCT_ID: "p1", "helpful": True}))
        assert rating_missing.value.code == "not-found"

    @patch("handlers.products.get_db")
    def test_vote_review_helpful_remaining_guard_and_error_branches(self, mock_get_db):
        from handlers.products import vote_review_helpful

        rating_ref = Mock()
        vote_ref = Mock()
        rating_ref.collection.return_value.document.return_value = vote_ref

        products_col = Mock()
        products_col.document.return_value.get.return_value = _snap({Fields.SELLER_ID: "seller_other"}, exists=True)

        ratings_col = Mock()
        ratings_col.document.return_value = rating_ref

        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.PRODUCT_RATINGS: ratings_col,
            Collections.PRODUCTS: products_col,
        }[name]
        db.transaction.return_value = Mock()
        mock_get_db.return_value = db

        with patch("firebase_admin.firestore.transactional", side_effect=lambda fn: fn):
            # Mismatched rating/product
            rating_ref.get.return_value = _snap({Fields.PRODUCT_ID: "other", Fields.USER_ID: "reviewer_1"}, exists=True)
            vote_ref.get.return_value = _snap(exists=False)
            with pytest.raises(https_fn.HttpsError) as mismatch:
                vote_review_helpful(_req("u1", {Fields.RATING_ID: "r1", Fields.PRODUCT_ID: "p1", "helpful": True}))
            assert mismatch.value.code == "invalid-argument"

            # Self voting
            rating_ref.get.return_value = _snap({Fields.PRODUCT_ID: "p1", Fields.USER_ID: "u1"}, exists=True)
            with pytest.raises(https_fn.HttpsError) as self_vote:
                vote_review_helpful(_req("u1", {Fields.RATING_ID: "r1", Fields.PRODUCT_ID: "p1", "helpful": True}))
            assert self_vote.value.code == "permission-denied"

            # Seller voting on own product
            rating_ref.get.return_value = _snap({Fields.PRODUCT_ID: "p1", Fields.USER_ID: "reviewer_1"}, exists=True)
            products_col.document.return_value.get.return_value = _snap({Fields.SELLER_ID: "u1"}, exists=True)
            with pytest.raises(https_fn.HttpsError) as seller_vote:
                vote_review_helpful(_req("u1", {Fields.RATING_ID: "r1", Fields.PRODUCT_ID: "p1", "helpful": True}))
            assert seller_vote.value.code == "permission-denied"

            # Already voted
            products_col.document.return_value.get.return_value = _snap({Fields.SELLER_ID: "seller_other"}, exists=True)
            vote_ref.get.return_value = _snap(exists=True)
            with pytest.raises(https_fn.HttpsError) as already:
                vote_review_helpful(_req("u1", {Fields.RATING_ID: "r1", Fields.PRODUCT_ID: "p1", "helpful": True}))
            assert already.value.code == "already-exists"

            # Remove vote when none exists
            vote_ref.get.return_value = _snap(exists=False)
            with pytest.raises(https_fn.HttpsError) as remove_missing:
                vote_review_helpful(_req("u1", {Fields.RATING_ID: "r1", Fields.PRODUCT_ID: "p1", "helpful": False}))
            assert remove_missing.value.code == "failed-precondition"

        # Transaction wrapper throws -> internal
        with patch(
            "firebase_admin.firestore.transactional",
            side_effect=lambda _fn: (lambda _txn: (_ for _ in ()).throw(RuntimeError("txn failed"))),
        ):
            with pytest.raises(https_fn.HttpsError) as internal:
                vote_review_helpful(_req("u1", {Fields.RATING_ID: "r1", Fields.PRODUCT_ID: "p1", "helpful": True}))
            assert internal.value.code == "internal"


class TestOrdersReturnGuardBranchesMore:
    def test_create_return_request_requires_auth(self):
        from handlers.orders import create_return_request

        with pytest.raises(https_fn.HttpsError) as exc:
            create_return_request(_req(None))
        assert exc.value.code == "unauthenticated"

    @patch("services.rate_limiter.RateLimiter")
    def test_create_return_request_rate_limited_and_missing_fields(self, mock_rl):
        from handlers.orders import create_return_request

        mock_rl.return_value.check_rate_limit.return_value = (False, "too many")
        with pytest.raises(https_fn.HttpsError) as limited:
            create_return_request(_req("buyer_1", {}))
        assert limited.value.code == "resource-exhausted"

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        with patch("utils.helpers.sanitized_text", side_effect=lambda s: s):
            with pytest.raises(https_fn.HttpsError) as missing:
                create_return_request(_req("buyer_1", {Fields.ORDER_ID: "o1"}))
            assert missing.value.code == "invalid-argument"

            with pytest.raises(https_fn.HttpsError) as missing_reason:
                create_return_request(_req("buyer_1", {Fields.ORDER_ID: "o1", Fields.PRODUCT_ID: "p1", Fields.RETURN_REASON: "  "}))
            assert missing_reason.value.code == "invalid-argument"

    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_create_return_request_not_found_permission_and_item_checks(self, mock_get_db, mock_rl):
        from handlers.orders import create_return_request

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        with patch("utils.helpers.sanitized_text", side_effect=lambda s: s):
            # Order not found
            orders_col = Mock()
            orders_col.document.return_value.get.return_value = _snap(exists=False)
            db = Mock()
            db.collection.side_effect = lambda name: {Collections.ORDERS: orders_col}[name]
            mock_get_db.return_value = db

            with pytest.raises(https_fn.HttpsError) as no_order:
                create_return_request(
                    _req("buyer_1", {Fields.ORDER_ID: "o1", Fields.PRODUCT_ID: "p1", Fields.RETURN_REASON: "Damaged"})
                )
            assert no_order.value.code == "not-found"

            # Wrong buyer
            orders_col.document.return_value.get.return_value = _snap({Fields.USER_ID: "other", Fields.ITEMS: []}, exists=True)
            with pytest.raises(https_fn.HttpsError) as forbidden:
                create_return_request(
                    _req("buyer_1", {Fields.ORDER_ID: "o1", Fields.PRODUCT_ID: "p1", Fields.RETURN_REASON: "Damaged"})
                )
            assert forbidden.value.code == "permission-denied"

            # Item missing
            orders_col.document.return_value.get.return_value = _snap({Fields.USER_ID: "buyer_1", Fields.ITEMS: []}, exists=True)
            with pytest.raises(https_fn.HttpsError) as item_missing:
                create_return_request(
                    _req("buyer_1", {Fields.ORDER_ID: "o1", Fields.PRODUCT_ID: "p1", Fields.RETURN_REASON: "Damaged"})
                )
            assert item_missing.value.code == "not-found"

            # Item not delivered
            orders_col.document.return_value.get.return_value = _snap(
                {
                    Fields.USER_ID: "buyer_1",
                    Fields.ITEMS: [
                        {
                            Fields.PRODUCT_ID: "p1",
                            Fields.IS_DIGITAL: False,
                            Fields.STATUS: DeliveryStatusValues.SHIPPED,
                            Fields.DELIVERED_AT: datetime.now(UTC) - timedelta(days=1),
                        }
                    ],
                },
                exists=True,
            )
            with pytest.raises(https_fn.HttpsError) as not_delivered:
                create_return_request(
                    _req("buyer_1", {Fields.ORDER_ID: "o1", Fields.PRODUCT_ID: "p1", Fields.RETURN_REASON: "Damaged"})
                )
            assert not_delivered.value.code == "failed-precondition"

    def test_approve_reject_escalate_return_require_auth(self):
        from handlers.orders import approve_return_request, escalate_return_request, reject_return_request

        for fn in (approve_return_request, reject_return_request, escalate_return_request):
            with pytest.raises(https_fn.HttpsError) as exc:
                fn(_req(None))
            assert exc.value.code == "unauthenticated"

    @patch("services.rate_limiter.RateLimiter")
    def test_approve_reject_escalate_rate_limit_and_required_fields(self, mock_rl):
        from handlers.orders import approve_return_request, escalate_return_request, reject_return_request

        mock_rl.return_value.check_rate_limit.return_value = (False, "slow down")
        with pytest.raises(https_fn.HttpsError) as approve_limited:
            approve_return_request(_req("seller_1", {}))
        assert approve_limited.value.code == "resource-exhausted"

        with pytest.raises(https_fn.HttpsError) as reject_limited:
            reject_return_request(_req("seller_1", {}))
        assert reject_limited.value.code == "resource-exhausted"

        with pytest.raises(https_fn.HttpsError) as escalate_limited:
            escalate_return_request(_req("buyer_1", {}))
        assert escalate_limited.value.code == "resource-exhausted"

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        with patch("utils.helpers.sanitized_text", side_effect=lambda s: s):
            with pytest.raises(https_fn.HttpsError) as approve_missing:
                approve_return_request(_req("seller_1", {}))
            assert approve_missing.value.code == "invalid-argument"

            with pytest.raises(https_fn.HttpsError) as reject_missing:
                reject_return_request(_req("seller_1", {Fields.RETURN_ID: "r1", Fields.RETURN_ADMIN_NOTE: " "}))
            assert reject_missing.value.code == "invalid-argument"

            with pytest.raises(https_fn.HttpsError) as escalate_missing:
                escalate_return_request(_req("buyer_1", {Fields.RETURN_ID: "r1", Fields.ESCALATION_REASON: " "}))
            assert escalate_missing.value.code == "invalid-argument"

    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.orders.get_db")
    def test_approve_reject_escalate_not_found_and_permission_paths(self, mock_get_db, mock_rl):
        from handlers.orders import approve_return_request, escalate_return_request, reject_return_request

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        with patch("utils.helpers.sanitized_text", side_effect=lambda s: s):
            users_col = Mock()
            returns_col = Mock()
            db = Mock()
            db.collection.side_effect = lambda name: {
                Collections.USERS: users_col,
                Collections.RETURN_REQUESTS: returns_col,
            }[name]
            mock_get_db.return_value = db

            # approve: user not found
            users_col.document.return_value.get.return_value = _snap(exists=False)
            with pytest.raises(https_fn.HttpsError) as approve_no_user:
                approve_return_request(_req("seller_1", {Fields.RETURN_ID: "ret_1"}))
            assert approve_no_user.value.code == "not-found"

            # approve: return not found
            users_col.document.return_value.get.return_value = _snap({Fields.ROLES: [UserRoleValues.SELLER]}, exists=True)
            returns_col.document.return_value.get.return_value = _snap(exists=False)
            with pytest.raises(https_fn.HttpsError) as approve_no_return:
                approve_return_request(_req("seller_1", {Fields.RETURN_ID: "ret_1"}))
            assert approve_no_return.value.code == "not-found"

            # approve: wrong seller, not admin
            returns_col.document.return_value.get.return_value = _snap(
                {
                    Fields.SELLER_ID: "other_seller",
                    Fields.BUYER_ID: "buyer_1",
                    Fields.ORDER_ID: "o1",
                    Fields.PRODUCT_ID: "p1",
                    Fields.RETURN_STATUS: ReturnStatusValues.REQUESTED,
                },
                exists=True,
            )
            with pytest.raises(https_fn.HttpsError) as approve_forbidden:
                approve_return_request(_req("seller_1", {Fields.RETURN_ID: "ret_1", "action": "approve"}))
            assert approve_forbidden.value.code == "permission-denied"

            # reject: user/return not found
            users_col.document.return_value.get.return_value = _snap(exists=False)
            with pytest.raises(https_fn.HttpsError) as reject_no_user:
                reject_return_request(
                    _req("seller_1", {Fields.RETURN_ID: "ret_1", Fields.RETURN_ADMIN_NOTE: "No receipt"})
                )
            assert reject_no_user.value.code == "not-found"

            users_col.document.return_value.get.return_value = _snap({Fields.ROLES: [UserRoleValues.SELLER]}, exists=True)
            returns_col.document.return_value.get.return_value = _snap(exists=False)
            with pytest.raises(https_fn.HttpsError) as reject_no_return:
                reject_return_request(
                    _req("seller_1", {Fields.RETURN_ID: "ret_1", Fields.RETURN_ADMIN_NOTE: "No receipt"})
                )
            assert reject_no_return.value.code == "not-found"

            # escalate: return not found
            returns_col.document.return_value.get.return_value = _snap(exists=False)
            with pytest.raises(https_fn.HttpsError) as escalate_no_return:
                escalate_return_request(
                    _req("buyer_1", {Fields.RETURN_ID: "ret_1", Fields.ESCALATION_REASON: "No seller response"})
                )
            assert escalate_no_return.value.code == "not-found"

            # escalate: wrong buyer
            returns_col.document.return_value.get.return_value = _snap(
                {Fields.BUYER_ID: "other_buyer", Fields.RETURN_STATUS: ReturnStatusValues.REQUESTED},
                exists=True,
            )
            with pytest.raises(https_fn.HttpsError) as escalate_forbidden:
                escalate_return_request(
                    _req("buyer_1", {Fields.RETURN_ID: "ret_1", Fields.ESCALATION_REASON: "No seller response"})
                )
            assert escalate_forbidden.value.code == "permission-denied"
