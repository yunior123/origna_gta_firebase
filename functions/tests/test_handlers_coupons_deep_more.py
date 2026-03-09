from datetime import UTC, datetime, timedelta
from unittest.mock import Mock, patch

import pytest
from firebase_functions import https_fn

from schema_constants import BusinessRules, Collections, CouponDiscountTypeValues, Fields


def _apply_db(coupon_data: dict, *, coupon_exists=True, user_use_exists=False, user_use_count=0):
    db = Mock()
    coupon_ref = Mock()
    coupon_snap = Mock()
    coupon_snap.exists = coupon_exists
    coupon_snap.to_dict.return_value = coupon_data
    coupon_ref.get.return_value = coupon_snap

    use_ref = Mock()
    use_snap = Mock()
    use_snap.exists = user_use_exists
    use_snap.to_dict.return_value = {"useCount": user_use_count}
    use_ref.get.return_value = use_snap

    coupon_ref.collection.return_value.document.return_value = use_ref
    db.collection.return_value.document.return_value = coupon_ref
    return db, coupon_ref


def _admin_req(data=None, *, admin=True):
    req = Mock()
    req.auth = Mock(uid="admin_1", token={"admin": admin})
    req.data = data or {}
    return req


class TestCouponHelperExtra:
    def test_compute_discount_low_subtotal_and_unknown_type(self):
        from handlers.coupons import _compute_discount

        assert _compute_discount({Fields.DISCOUNT_TYPE: CouponDiscountTypeValues.PERCENT, Fields.DISCOUNT_VALUE: 50}, 100) == 0
        assert _compute_discount({Fields.DISCOUNT_TYPE: CouponDiscountTypeValues.PERCENT, Fields.DISCOUNT_VALUE: 99}, 150) == 50
        assert _compute_discount({Fields.DISCOUNT_TYPE: "unknown", Fields.DISCOUNT_VALUE: 10}, 5000) == 0


class TestApplyCouponExtra:
    @patch("handlers.coupons.create_success_response", side_effect=lambda data: data)
    @patch("handlers.coupons.RateLimiter")
    @patch("handlers.coupons.get_db")
    def test_apply_coupon_handles_seller_ids_type_and_expiry_conversion_paths(self, mock_get_db, mock_rl, _mock_resp):
        from handlers.coupons import apply_coupon

        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        # sellerIds wrong type -> coerced to []
        coupon = {"isActive": True, Fields.DISCOUNT_TYPE: CouponDiscountTypeValues.PERCENT, Fields.DISCOUNT_VALUE: 10}
        db, _ = _apply_db(coupon)
        mock_get_db.return_value = db
        req = Mock(auth=Mock(uid="u1"), data={Fields.COUPON_CODE: "SAVE10", "cartSubtotalCents": 1000, Fields.SELLER_IDS: "bad"})
        out = apply_coupon(req)
        assert out["valid"] is True

        # expiresAt via ToDatetime path
        ts_like = Mock()
        ts_like.ToDatetime.return_value = datetime.now(UTC) + timedelta(days=1)
        coupon_ts = {"isActive": True, Fields.EXPIRES_AT: ts_like, Fields.DISCOUNT_TYPE: CouponDiscountTypeValues.PERCENT, Fields.DISCOUNT_VALUE: 10}
        db_ts, _ = _apply_db(coupon_ts)
        mock_get_db.return_value = db_ts
        out_ts = apply_coupon(req)
        assert out_ts["valid"] is True

        # expiresAt fallback unknown object path (no astimezone/ToDatetime)
        coupon_fallback = {"isActive": True, Fields.EXPIRES_AT: object(), Fields.DISCOUNT_TYPE: CouponDiscountTypeValues.PERCENT, Fields.DISCOUNT_VALUE: 10}
        db_fallback, _ = _apply_db(coupon_fallback)
        mock_get_db.return_value = db_fallback
        out_fb = apply_coupon(req)
        assert out_fb["valid"] is True

    @patch("handlers.coupons.RateLimiter")
    @patch("handlers.coupons.get_db")
    def test_apply_coupon_missing_code_and_invalid_subtotal(self, mock_get_db, mock_rl):
        from handlers.coupons import apply_coupon

        mock_get_db.return_value = Mock()
        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        with pytest.raises(https_fn.HttpsError) as no_code:
            apply_coupon(Mock(auth=Mock(uid="u1"), data={Fields.COUPON_CODE: "", "cartSubtotalCents": 1000}))
        assert no_code.value.code == "invalid-argument"

        with pytest.raises(https_fn.HttpsError) as bad_subtotal:
            apply_coupon(Mock(auth=Mock(uid="u1"), data={Fields.COUPON_CODE: "SAVE10", "cartSubtotalCents": "1000"}))
        assert bad_subtotal.value.code == "invalid-argument"


class TestRedeemCouponExtra:
    @patch("handlers.coupons.logger")
    @patch("handlers.coupons.get_firestore")
    @patch("handlers.coupons.get_db")
    def test_redeem_coupon_noop_transaction_branches(self, mock_get_db, mock_get_fs, mock_logger):
        from handlers.coupons import redeem_coupon

        db = Mock()
        mock_get_db.return_value = db
        fs = Mock()
        fs.transactional.side_effect = lambda fn: fn
        fs.SERVER_TIMESTAMP = "ts"
        mock_get_fs.return_value = fs
        txn = Mock()
        db.transaction.return_value = txn

        coupon_ref = Mock()
        use_ref = Mock()
        coupon_ref.collection.return_value.document.return_value = use_ref

        def _set_coupon(coupon_snap, use_snap):
            coupon_ref.get.return_value = coupon_snap
            use_ref.get.return_value = use_snap
            db.collection.side_effect = lambda name: Mock(document=Mock(return_value=coupon_ref)) if name == Collections.COUPONS else Mock()

        # coupon missing -> logs warning and returns
        missing_snap = Mock(exists=False)
        missing_use = Mock(exists=False)
        _set_coupon(missing_snap, missing_use)
        redeem_coupon("SAVE10", "u1")

        # expired in transaction
        expired_snap = Mock(exists=True)
        expired_snap.to_dict.return_value = {
            Fields.USED_COUNT: 0,
            Fields.EXPIRES_AT: datetime.now(UTC) - timedelta(minutes=1),
            Fields.MAX_USES_PER_USER: 2,
        }
        _set_coupon(expired_snap, missing_use)
        redeem_coupon("SAVE10", "u1")

        # global limit reached
        global_limit_snap = Mock(exists=True)
        global_limit_snap.to_dict.return_value = {Fields.USED_COUNT: 5, Fields.MAX_USES_TOTAL: 5, Fields.MAX_USES_PER_USER: 2}
        _set_coupon(global_limit_snap, missing_use)
        redeem_coupon("SAVE10", "u1")

        # per-user limit reached
        per_user_snap = Mock(exists=True)
        per_user_snap.to_dict.return_value = {Fields.USED_COUNT: 0, Fields.MAX_USES_PER_USER: 1}
        use_limit = Mock(exists=True)
        use_limit.to_dict.return_value = {"useCount": 1}
        _set_coupon(per_user_snap, use_limit)
        redeem_coupon("SAVE10", "u1")

        assert mock_logger.warning.called

    @patch("handlers.coupons.logger")
    @patch("handlers.coupons.get_firestore")
    @patch("handlers.coupons.get_db")
    def test_redeem_coupon_pending_redemption_write_failure_is_logged(self, mock_get_db, mock_get_fs, mock_logger):
        from handlers.coupons import redeem_coupon

        db = Mock()
        mock_get_db.return_value = db
        fs = Mock()
        fs.transactional.side_effect = lambda fn: fn
        fs.SERVER_TIMESTAMP = "ts"
        mock_get_fs.return_value = fs

        db.transaction.side_effect = RuntimeError("txn failure")
        pending_doc = Mock()
        pending_doc.set.side_effect = RuntimeError("write failure")
        db.collection.return_value.document.return_value = pending_doc

        redeem_coupon("SAVE10", "u1", order_id="ord_1")
        assert mock_logger.error.called

    @patch("handlers.coupons.get_firestore")
    @patch("handlers.coupons.get_db")
    def test_redeem_coupon_expiry_to_datetime_and_fallback_paths(self, mock_get_db, mock_get_fs):
        from handlers.coupons import redeem_coupon

        db = Mock()
        mock_get_db.return_value = db
        fs = Mock()
        fs.transactional.side_effect = lambda fn: fn
        fs.SERVER_TIMESTAMP = "ts"
        mock_get_fs.return_value = fs
        txn = Mock()
        db.transaction.return_value = txn

        coupon_ref = Mock()
        use_ref = Mock()
        use_ref.get.return_value = Mock(exists=False)
        coupon_ref.collection.return_value.document.return_value = use_ref
        db.collection.side_effect = lambda name: Mock(document=Mock(return_value=coupon_ref)) if name == Collections.COUPONS else Mock()

        # ToDatetime branch (line 233)
        ts_like = Mock()
        ts_like.ToDatetime.return_value = datetime.now(UTC) + timedelta(days=1)
        coupon_ref.get.return_value = Mock(
            exists=True,
            to_dict=Mock(
                return_value={
                    Fields.USED_COUNT: 0,
                    Fields.EXPIRES_AT: ts_like,
                    Fields.MAX_USES_PER_USER: 1,
                }
            ),
        )
        redeem_coupon("SAVE10", "u1")

        # Fallback branch (line 237)
        coupon_ref.get.return_value = Mock(
            exists=True,
            to_dict=Mock(
                return_value={
                    Fields.USED_COUNT: 0,
                    Fields.EXPIRES_AT: object(),
                    Fields.MAX_USES_PER_USER: 1,
                }
            ),
        )
        redeem_coupon("SAVE10", "u1")


class TestAdminCreateCouponExtra:
    def _base_data(self):
        return {
            Fields.COUPON_CODE: "SAVE10",
            Fields.DISCOUNT_TYPE: CouponDiscountTypeValues.PERCENT,
            Fields.DISCOUNT_VALUE: 10,
            Fields.MIN_ORDER_CENTS: 1000,
            Fields.MAX_USES_PER_USER: 1,
        }

    def test_admin_create_coupon_requires_auth(self):
        from handlers.coupons import admin_create_coupon

        req = Mock(auth=None, data={})
        with pytest.raises(https_fn.HttpsError) as exc:
            admin_create_coupon(req)
        assert exc.value.code == "unauthenticated"

    @patch("handlers.coupons.get_db")
    def test_admin_create_coupon_non_admin_missing_user_doc_denied(self, mock_get_db):
        from handlers.coupons import admin_create_coupon

        req = _admin_req(self._base_data(), admin=False)
        caller_doc = Mock()
        caller_doc.exists = False
        mock_get_db.return_value.collection.return_value.document.return_value.get.return_value = caller_doc
        with pytest.raises(https_fn.HttpsError) as exc:
            admin_create_coupon(req)
        assert exc.value.code == "permission-denied"

    @patch("handlers.coupons.get_db")
    @pytest.mark.parametrize(
        "patch_data,expected_code",
        [
            ({Fields.COUPON_CODE: ""}, "invalid-argument"),  # code required
            ({Fields.COUPON_CODE: "bad-code"}, "invalid-argument"),  # invalid format
            ({Fields.DISCOUNT_TYPE: "weird"}, "invalid-argument"),
            ({Fields.DISCOUNT_VALUE: 0}, "invalid-argument"),
            ({Fields.DISCOUNT_VALUE: 200}, "invalid-argument"),  # percent out of bounds
            ({Fields.DISCOUNT_TYPE: CouponDiscountTypeValues.FIXED_CENTS, Fields.DISCOUNT_VALUE: 50}, "invalid-argument"),
            ({Fields.MIN_ORDER_CENTS: -1}, "invalid-argument"),
            ({Fields.MAX_USES_TOTAL: 0}, "invalid-argument"),
            ({Fields.MAX_USES_PER_USER: 0}, "invalid-argument"),
            ({"isActive": "yes"}, "invalid-argument"),
            ({Fields.EXPIRES_AT: "not-an-iso-date"}, "invalid-argument"),
        ],
    )
    def test_admin_create_coupon_validation_branches(self, mock_get_db, patch_data, expected_code):
        from handlers.coupons import admin_create_coupon

        data = self._base_data()
        data.update(patch_data)
        req = _admin_req(data, admin=True)

        dup_snap = Mock()
        dup_snap.exists = False
        mock_get_db.return_value.collection.return_value.document.return_value.get.return_value = dup_snap

        with pytest.raises(https_fn.HttpsError) as exc:
            admin_create_coupon(req)
        assert exc.value.code == expected_code

    @patch("handlers.coupons.get_db")
    def test_admin_create_coupon_invalid_max_uses_total_field(self, mock_get_db):
        from handlers.coupons import admin_create_coupon

        data = self._base_data()
        data[Fields.MAX_USES_TOTAL] = "many"
        req = _admin_req(data, admin=True)

        dup_snap = Mock()
        dup_snap.exists = False
        mock_get_db.return_value.collection.return_value.document.return_value.get.return_value = dup_snap

        with pytest.raises(https_fn.HttpsError) as exc:
            admin_create_coupon(req)
        assert exc.value.code == "invalid-argument"

    @patch("handlers.coupons.get_db")
    def test_admin_create_coupon_fixed_discount_too_small_and_bad_min_order(self, mock_get_db):
        from handlers.coupons import admin_create_coupon

        data = {
            Fields.COUPON_CODE: "FLAT50",
            Fields.DISCOUNT_TYPE: CouponDiscountTypeValues.FIXED_CENTS,
            Fields.DISCOUNT_VALUE: 50,
            Fields.MIN_ORDER_CENTS: 1000,
        }
        req = _admin_req(data, admin=True)
        mock_get_db.return_value.collection.return_value.document.return_value.get.return_value.exists = False

        with pytest.raises(https_fn.HttpsError) as exc:
            admin_create_coupon(req)
        assert exc.value.code == "invalid-argument"

        data2 = {
            Fields.COUPON_CODE: "FLAT500",
            Fields.DISCOUNT_TYPE: CouponDiscountTypeValues.FIXED_CENTS,
            Fields.DISCOUNT_VALUE: 500,
            Fields.MIN_ORDER_CENTS: 100,
        }
        req2 = _admin_req(data2, admin=True)
        with pytest.raises(https_fn.HttpsError) as exc2:
            admin_create_coupon(req2)
        assert exc2.value.code == "invalid-argument"
