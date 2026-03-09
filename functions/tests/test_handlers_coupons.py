from datetime import UTC, datetime, timedelta
from unittest.mock import Mock, patch

import pytest
from firebase_functions import https_fn

from schema_constants import (
    Collections,
    CouponDiscountTypeValues,
    Fields,
    UserRoleValues,
)


def _build_apply_coupon_db(
    *,
    coupon_exists: bool = True,
    coupon_data: dict | None = None,
    user_use_exists: bool = False,
    user_use_count: int = 0,
):
    db = Mock()
    coupon_ref = Mock()
    coupon_snap = Mock()
    coupon_snap.exists = coupon_exists
    coupon_snap.to_dict.return_value = coupon_data or {}
    coupon_ref.get.return_value = coupon_snap

    use_ref = Mock()
    use_snap = Mock()
    use_snap.exists = user_use_exists
    use_snap.to_dict.return_value = {"useCount": user_use_count}
    use_ref.get.return_value = use_snap

    coupon_ref.collection.return_value.document.return_value = use_ref
    db.collection.return_value.document.return_value = coupon_ref
    return db, coupon_ref, use_ref


class TestCouponHelpers:
    def test_validate_coupon_code_accepts_upper_alnum_and_rejects_invalid(self):
        from handlers.coupons import _validate_coupon_code

        assert _validate_coupon_code("SAVE10") is True
        assert _validate_coupon_code("AB12") is True
        assert _validate_coupon_code("ab12") is False
        assert _validate_coupon_code("BAD-CODE") is False
        assert _validate_coupon_code("A1") is False

    def test_compute_discount_percent_caps_and_respects_min_remaining(self):
        from handlers.coupons import _compute_discount

        coupon = {
            Fields.DISCOUNT_TYPE: CouponDiscountTypeValues.PERCENT,
            Fields.DISCOUNT_VALUE: 99,  # gets capped by BusinessRules.MAX_COUPON_DISCOUNT_RATIO
        }
        # Should never discount below minimum checkout total.
        discount = _compute_discount(coupon, 2000)
        assert discount < 2000
        assert 2000 - discount >= 100

    def test_compute_discount_fixed_cents_keeps_minimum_total(self):
        from handlers.coupons import _compute_discount

        coupon = {
            Fields.DISCOUNT_TYPE: CouponDiscountTypeValues.FIXED_CENTS,
            Fields.DISCOUNT_VALUE: 5000,
        }
        discount = _compute_discount(coupon, 1200)
        assert discount == 1100  # keep at least 100 cents remaining


class TestApplyCoupon:
    def test_apply_coupon_requires_authentication(self):
        from handlers.coupons import apply_coupon

        req = Mock()
        req.auth = None
        req.data = {}

        with pytest.raises(https_fn.HttpsError) as exc:
            apply_coupon(req)
        assert exc.value.code == "unauthenticated"

    @patch("handlers.coupons.RateLimiter")
    @patch("handlers.coupons.get_db")
    def test_apply_coupon_rate_limit_exhausted(self, mock_get_db, mock_rl):
        from handlers.coupons import apply_coupon

        mock_get_db.return_value = Mock()
        mock_rl.return_value.check_rate_limit.return_value = (False, "limited")

        req = Mock()
        req.auth = Mock(uid="user_1")
        req.data = {Fields.COUPON_CODE: "SAVE10", "cartSubtotalCents": 1000}

        with pytest.raises(https_fn.HttpsError) as exc:
            apply_coupon(req)
        assert exc.value.code == "resource-exhausted"

    @patch("handlers.coupons.RateLimiter")
    @patch("handlers.coupons.get_db")
    def test_apply_coupon_rejects_invalid_inputs(self, mock_get_db, mock_rl):
        from handlers.coupons import apply_coupon

        mock_get_db.return_value = Mock()
        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        req = Mock()
        req.auth = Mock(uid="user_1")
        req.data = {Fields.COUPON_CODE: "bad-code", "cartSubtotalCents": "1000"}

        with pytest.raises(https_fn.HttpsError) as exc:
            apply_coupon(req)
        assert exc.value.code == "invalid-argument"

    @patch("handlers.coupons.RateLimiter")
    @patch("handlers.coupons.get_db")
    def test_apply_coupon_not_found(self, mock_get_db, mock_rl):
        from handlers.coupons import apply_coupon

        db, _, _ = _build_apply_coupon_db(coupon_exists=False)
        mock_get_db.return_value = db
        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        req = Mock()
        req.auth = Mock(uid="user_1")
        req.data = {Fields.COUPON_CODE: "SAVE10", "cartSubtotalCents": 5000}

        with pytest.raises(https_fn.HttpsError) as exc:
            apply_coupon(req)
        assert exc.value.code == "not-found"

    @patch("handlers.coupons.RateLimiter")
    @patch("handlers.coupons.get_db")
    def test_apply_coupon_inactive_expired_or_limits_rejected(self, mock_get_db, mock_rl):
        from handlers.coupons import apply_coupon

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        req = Mock()
        req.auth = Mock(uid="user_1")
        req.data = {Fields.COUPON_CODE: "SAVE10", "cartSubtotalCents": 5000, Fields.SELLER_IDS: ["seller_1"]}

        # Inactive
        db, _, _ = _build_apply_coupon_db(coupon_data={"isActive": False})
        mock_get_db.return_value = db
        with pytest.raises(https_fn.HttpsError) as inactive:
            apply_coupon(req)
        assert inactive.value.code == "failed-precondition"

        # Expired
        db, _, _ = _build_apply_coupon_db(
            coupon_data={"isActive": True, Fields.EXPIRES_AT: datetime.now(UTC) - timedelta(days=1)}
        )
        mock_get_db.return_value = db
        with pytest.raises(https_fn.HttpsError) as expired:
            apply_coupon(req)
        assert expired.value.code == "failed-precondition"

        # Global limit reached
        db, _, _ = _build_apply_coupon_db(
            coupon_data={"isActive": True, Fields.USED_COUNT: 5, Fields.MAX_USES_TOTAL: 5}
        )
        mock_get_db.return_value = db
        with pytest.raises(https_fn.HttpsError) as global_limited:
            apply_coupon(req)
        assert global_limited.value.code == "resource-exhausted"

        # Per-user limit reached
        db, _, _ = _build_apply_coupon_db(
            coupon_data={"isActive": True, Fields.MAX_USES_PER_USER: 1},
            user_use_exists=True,
            user_use_count=1,
        )
        mock_get_db.return_value = db
        with pytest.raises(https_fn.HttpsError) as per_user_limited:
            apply_coupon(req)
        assert per_user_limited.value.code == "resource-exhausted"

    @patch("handlers.coupons.RateLimiter")
    @patch("handlers.coupons.get_db")
    def test_apply_coupon_rejects_seller_scope_and_min_order(self, mock_get_db, mock_rl):
        from handlers.coupons import apply_coupon

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        req = Mock()
        req.auth = Mock(uid="user_1")
        req.data = {Fields.COUPON_CODE: "SAVE10", "cartSubtotalCents": 5000, Fields.SELLER_IDS: ["seller_1"]}

        # Seller mismatch
        db, _, _ = _build_apply_coupon_db(
            coupon_data={"isActive": True, Fields.SELLER_ID: "seller_2"}
        )
        mock_get_db.return_value = db
        with pytest.raises(https_fn.HttpsError) as seller_mismatch:
            apply_coupon(req)
        assert seller_mismatch.value.code == "failed-precondition"

        # Minimum order not met
        db, _, _ = _build_apply_coupon_db(
            coupon_data={"isActive": True, Fields.MIN_ORDER_CENTS: 7000}
        )
        mock_get_db.return_value = db
        with pytest.raises(https_fn.HttpsError) as min_order:
            apply_coupon(req)
        assert min_order.value.code == "failed-precondition"

    @patch("handlers.coupons.RateLimiter")
    @patch("handlers.coupons.get_db")
    @patch("handlers.coupons.create_success_response", side_effect=lambda data: data)
    def test_apply_coupon_success_returns_discount_preview(self, _mock_resp, mock_get_db, mock_rl):
        from handlers.coupons import apply_coupon

        coupon_data = {
            "isActive": True,
            Fields.DISCOUNT_TYPE: CouponDiscountTypeValues.PERCENT,
            Fields.DISCOUNT_VALUE: 10,
            Fields.MAX_USES_PER_USER: 2,
            Fields.USED_COUNT: 0,
        }
        db, _, _ = _build_apply_coupon_db(coupon_data=coupon_data, user_use_exists=True, user_use_count=0)
        mock_get_db.return_value = db
        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        req = Mock()
        req.auth = Mock(uid="user_1")
        req.data = {
            Fields.COUPON_CODE: "save10",
            "cartSubtotalCents": 10000,
            Fields.SELLER_IDS: [],
        }

        result = apply_coupon(req)
        assert result["valid"] is True
        assert result[Fields.DISCOUNT_AMOUNT_CENTS] == 1000
        assert result[Fields.COUPON_CODE] == "SAVE10"


class TestRedeemCoupon:
    @patch("handlers.coupons.get_db")
    def test_redeem_coupon_noops_on_empty_input(self, mock_get_db):
        from handlers.coupons import redeem_coupon

        redeem_coupon("", "user_1")
        redeem_coupon("SAVE10", "")
        mock_get_db.assert_not_called()

    @patch("handlers.coupons.get_firestore")
    @patch("handlers.coupons.get_db")
    def test_redeem_coupon_creates_first_usage(self, mock_get_db, mock_get_firestore):
        from handlers.coupons import redeem_coupon

        db = Mock()
        mock_get_db.return_value = db
        fs = Mock()
        fs.transactional.side_effect = lambda fn: fn
        fs.SERVER_TIMESTAMP = "server_ts"
        mock_get_firestore.return_value = fs

        coupon_ref = Mock()
        use_ref = Mock()
        coupon_snap = Mock()
        coupon_snap.exists = True
        coupon_snap.to_dict.return_value = {Fields.USED_COUNT: 0, Fields.MAX_USES_PER_USER: 2}
        use_snap = Mock()
        use_snap.exists = False

        coupon_ref.get.return_value = coupon_snap
        use_ref.get.return_value = use_snap
        coupon_ref.collection.return_value.document.return_value = use_ref

        def _collection_side_effect(name):
            coll = Mock()
            if name == Collections.COUPONS:
                coll.document.return_value = coupon_ref
            return coll

        db.collection.side_effect = _collection_side_effect
        db.transaction.return_value = Mock()

        redeem_coupon("save10", "user_1")

        txn = db.transaction.return_value
        txn.update.assert_any_call(coupon_ref, {Fields.USED_COUNT: 1})
        txn.set.assert_called_once()

    @patch("handlers.coupons.get_firestore")
    @patch("handlers.coupons.get_db")
    def test_redeem_coupon_updates_existing_usage(self, mock_get_db, mock_get_firestore):
        from handlers.coupons import redeem_coupon

        db = Mock()
        mock_get_db.return_value = db
        fs = Mock()
        fs.transactional.side_effect = lambda fn: fn
        fs.SERVER_TIMESTAMP = "server_ts"
        mock_get_firestore.return_value = fs

        coupon_ref = Mock()
        use_ref = Mock()
        coupon_snap = Mock()
        coupon_snap.exists = True
        coupon_snap.to_dict.return_value = {Fields.USED_COUNT: 2, Fields.MAX_USES_PER_USER: 5}
        use_snap = Mock()
        use_snap.exists = True
        use_snap.to_dict.return_value = {"useCount": 2}

        coupon_ref.get.return_value = coupon_snap
        use_ref.get.return_value = use_snap
        coupon_ref.collection.return_value.document.return_value = use_ref

        db.collection.side_effect = lambda name: Mock(document=Mock(return_value=coupon_ref)) if name == Collections.COUPONS else Mock()
        db.transaction.return_value = Mock()

        redeem_coupon("SAVE10", "user_1")

        txn = db.transaction.return_value
        txn.update.assert_any_call(coupon_ref, {Fields.USED_COUNT: 3})
        txn.update.assert_any_call(use_ref, {"useCount": 3, "lastUsedAt": "server_ts"})

    @patch("handlers.coupons.get_firestore")
    @patch("handlers.coupons.get_db")
    def test_redeem_coupon_writes_pending_redemption_on_failure(self, mock_get_db, mock_get_firestore):
        from handlers.coupons import redeem_coupon

        db = Mock()
        mock_get_db.return_value = db
        fs = Mock()
        fs.transactional.side_effect = lambda fn: fn
        fs.SERVER_TIMESTAMP = "server_ts"
        mock_get_firestore.return_value = fs
        db.transaction.side_effect = RuntimeError("firestore down")

        redeem_coupon("SAVE10", "user_1", order_id="order_1")

        db.collection.assert_any_call("pending_redemptions")
        db.collection.return_value.document.return_value.set.assert_called()


class TestAdminCreateCoupon:
    def test_admin_create_coupon_requires_admin(self):
        from handlers.coupons import admin_create_coupon

        req = Mock()
        req.auth = Mock(uid="user_1", token={})
        req.data = {}

        with patch("handlers.coupons.get_db") as mock_get_db:
            user_doc = Mock()
            user_doc.exists = True
            user_doc.to_dict.return_value = {Fields.ROLES: []}
            mock_get_db.return_value.collection.return_value.document.return_value.get.return_value = user_doc

            with pytest.raises(https_fn.HttpsError) as exc:
                admin_create_coupon(req)
            assert exc.value.code == "permission-denied"

    @patch("handlers.coupons.get_db")
    def test_admin_create_coupon_validates_fixed_discount_min_order(self, mock_get_db):
        from handlers.coupons import admin_create_coupon

        req = Mock()
        req.auth = Mock(uid="admin_1", token={"admin": True})
        req.data = {
            Fields.COUPON_CODE: "FLAT5",
            Fields.DISCOUNT_TYPE: CouponDiscountTypeValues.FIXED_CENTS,
            Fields.DISCOUNT_VALUE: 500,
            Fields.MIN_ORDER_CENTS: 100,  # too low for fixed discount rule
        }
        mock_get_db.return_value.collection.return_value.document.return_value.get.return_value.exists = False

        with pytest.raises(https_fn.HttpsError) as exc:
            admin_create_coupon(req)
        assert exc.value.code == "invalid-argument"

    @patch("handlers.coupons.get_db")
    def test_admin_create_coupon_rejects_duplicate_code(self, mock_get_db):
        from handlers.coupons import admin_create_coupon

        req = Mock()
        req.auth = Mock(uid="admin_1", token={"admin": True})
        req.data = {
            Fields.COUPON_CODE: "SAVE10",
            Fields.DISCOUNT_TYPE: CouponDiscountTypeValues.PERCENT,
            Fields.DISCOUNT_VALUE: 10,
        }

        existing = Mock()
        existing.exists = True
        mock_get_db.return_value.collection.return_value.document.return_value.get.return_value = existing

        with pytest.raises(https_fn.HttpsError) as exc:
            admin_create_coupon(req)
        assert exc.value.code == "already-exists"

    @patch("handlers.coupons.create_success_response", side_effect=lambda data: data)
    @patch("handlers.coupons.get_db")
    def test_admin_create_coupon_success(self, mock_get_db, _mock_resp):
        from handlers.coupons import admin_create_coupon

        req = Mock()
        req.auth = Mock(uid="admin_1", token={"admin": True})
        req.data = {
            Fields.COUPON_CODE: "save20",
            Fields.DISCOUNT_TYPE: CouponDiscountTypeValues.PERCENT,
            Fields.DISCOUNT_VALUE: 20,
            Fields.MIN_ORDER_CENTS: 1000,
            Fields.MAX_USES_PER_USER: 2,
        }

        coupon_ref = Mock()
        dup = Mock()
        dup.exists = False
        coupon_ref.get.return_value = dup
        mock_get_db.return_value.collection.return_value.document.return_value = coupon_ref

        result = admin_create_coupon(req)

        assert result[Fields.COUPON_CODE] == "SAVE20"
        assert result["created"] is True
        coupon_ref.set.assert_called_once()
