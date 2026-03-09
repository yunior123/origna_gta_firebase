import base64
from unittest.mock import Mock, patch

import pytest
from firebase_functions import https_fn

from schema_constants import BusinessRules, Collections, Fields, ProductConstraints


def _snap(data=None, *, exists=True):
    snap = Mock()
    snap.exists = exists
    snap.to_dict.return_value = {} if data is None else data
    snap.reference = Mock()
    return snap


def _query(*, stream_return=None, stream_side_effect=None):
    q = Mock()
    q.where.return_value = q
    q.limit.return_value = q
    q.order_by.return_value = q
    q.start_after.return_value = q
    if stream_side_effect is not None:
        q.stream.side_effect = stream_side_effect
    else:
        q.stream.return_value = [] if stream_return is None else stream_return
    return q


def _seller_db(*, roles=None, suspended=False, onboarding_completed=True):
    db = Mock()
    user_doc = _snap({Fields.ROLES: roles or ["seller"], Fields.SUSPENDED: suspended}, exists=True)
    profile_doc = _snap({Fields.ONBOARDING_COMPLETED: onboarding_completed}, exists=True)

    users_col = Mock()
    users_col.document.return_value.get.return_value = user_doc
    profiles_col = Mock()
    profiles_col.document.return_value.get.return_value = profile_doc

    db.collection.side_effect = lambda name: {
        Collections.USERS: users_col,
        Collections.SELLER_PROFILES: profiles_col,
    }.get(name, Mock())
    return db, user_doc, profile_doc


@pytest.fixture(autouse=True)
def _reset_products_caches():
    import handlers.products as products

    products._r2_creds = None
    products._s3_client_cache = None
    yield
    products._r2_creds = None
    products._s3_client_cache = None


class TestProductCacheHelpers:
    @patch("handlers.products.get_r2_credentials", return_value={"access_key": "ak", "secret_key": "sk", "account_id": "acc"})
    def test_get_cached_r2_credentials_is_cached(self, mock_get_r2):
        from handlers.products import _get_cached_r2_credentials

        c1 = _get_cached_r2_credentials()
        c2 = _get_cached_r2_credentials()

        assert c1 == c2
        mock_get_r2.assert_called_once()

    @patch("handlers.products._get_cached_r2_credentials", return_value={"access_key": "ak"})
    def test_get_cached_s3_client_raises_when_credentials_missing(self, _mock_creds):
        from handlers.products import _get_cached_s3_client

        with pytest.raises(https_fn.HttpsError) as exc:
            _get_cached_s3_client()

        assert exc.value.code == "failed-precondition"

    @patch("boto3.client")
    @patch("handlers.products._get_cached_r2_credentials", return_value={"access_key": "ak", "secret_key": "sk", "account_id": "acc"})
    def test_get_cached_s3_client_reuses_client(self, _mock_creds, mock_boto_client):
        from handlers.products import _get_cached_s3_client

        mock_boto_client.return_value = Mock()
        c1 = _get_cached_s3_client()
        c2 = _get_cached_s3_client()

        assert c1 is c2
        mock_boto_client.assert_called_once()

    def test_generate_product_slug_and_stock_validator(self):
        from handlers.products import _generate_product_slug, _is_valid_stock_quantity

        slug = _generate_product_slug("Premium Keyboard ++ RGB")
        assert slug.startswith("premium-keyboard-rgb-")
        assert len(slug.split("-")[-1]) == 8

        assert _is_valid_stock_quantity(0) is True
        assert _is_valid_stock_quantity(2.5) is True
        assert _is_valid_stock_quantity(-1) is False
        assert _is_valid_stock_quantity("10") is False


class TestUploadProductImages:
    def test_upload_product_images_requires_auth(self):
        from handlers.products import upload_product_images

        req = Mock()
        req.auth = None
        req.data = {}
        with pytest.raises(https_fn.HttpsError) as exc:
            upload_product_images(req)
        assert exc.value.code == "unauthenticated"

    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_upload_product_images_user_not_found(self, mock_get_db, mock_rl):
        from handlers.products import upload_product_images

        user_doc = _snap(exists=False)
        users_col = Mock()
        users_col.document.return_value.get.return_value = user_doc
        db = Mock()
        db.collection.side_effect = lambda name: {Collections.USERS: users_col}.get(name, Mock())
        mock_get_db.return_value = db
        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {"fileNames": ["x.jpg"], "contentTypes": ["image/jpeg"]}
        with pytest.raises(https_fn.HttpsError) as exc:
            upload_product_images(req)
        assert exc.value.code == "not-found"

    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_upload_product_images_suspended_user_blocked(self, mock_get_db, mock_rl):
        from handlers.products import upload_product_images

        db, _, _ = _seller_db(suspended=True)
        mock_get_db.return_value = db
        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {"fileNames": ["x.jpg"], "contentTypes": ["image/jpeg"]}
        with pytest.raises(https_fn.HttpsError) as exc:
            upload_product_images(req)
        assert exc.value.code == "permission-denied"

    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_upload_product_images_role_required(self, mock_get_db, mock_rl):
        from handlers.products import upload_product_images

        db, _, _ = _seller_db(roles=["buyer"], onboarding_completed=True)
        mock_get_db.return_value = db
        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        req = Mock()
        req.auth = Mock(uid="buyer_1")
        req.data = {"fileNames": ["x.jpg"], "contentTypes": ["image/jpeg"]}
        with pytest.raises(https_fn.HttpsError) as exc:
            upload_product_images(req)
        assert exc.value.code == "permission-denied"

    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_upload_product_images_rejects_empty_and_mismatched_payload(self, mock_get_db, mock_rl):
        from handlers.products import upload_product_images

        db, _, _ = _seller_db(onboarding_completed=True)
        mock_get_db.return_value = db
        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {"fileNames": [], "contentTypes": []}
        with pytest.raises(https_fn.HttpsError) as exc:
            upload_product_images(req)
        assert exc.value.code == "invalid-argument"

        req.data = {"fileNames": ["x.jpg"], "contentTypes": []}
        with pytest.raises(https_fn.HttpsError) as exc2:
            upload_product_images(req)
        assert exc2.value.code == "invalid-argument"

    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_upload_product_images_rejects_more_than_max_images(self, mock_get_db, mock_rl):
        from handlers.products import upload_product_images

        db, _, _ = _seller_db(onboarding_completed=True)
        mock_get_db.return_value = db
        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {
            "fileNames": [f"f{i}.jpg" for i in range(BusinessRules.MAX_PRODUCT_IMAGES + 1)],
            "contentTypes": ["image/jpeg"] * (BusinessRules.MAX_PRODUCT_IMAGES + 1),
        }
        with pytest.raises(https_fn.HttpsError) as exc:
            upload_product_images(req)
        assert exc.value.code == "invalid-argument"

    @patch("handlers.products.create_success_response", side_effect=lambda payload: {"success": True, **payload})
    @patch("handlers.products._get_cached_s3_client")
    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_upload_product_images_success(self, mock_get_db, mock_rl, mock_get_s3, _mock_resp):
        from handlers.products import upload_product_images

        db, _, _ = _seller_db(onboarding_completed=True)
        mock_get_db.return_value = db
        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        s3 = Mock()
        s3.generate_presigned_url.return_value = "https://signed.example.com/put"
        mock_get_s3.return_value = s3

        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {
            "fileNames": ["a.jpg", "b.png"],
            "contentTypes": ["image/jpeg", "image/png"],
        }

        out = upload_product_images(req)
        assert out["success"] is True
        assert len(out["uploadUrls"]) == 2

    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_upload_product_images_rejects_invalid_mime(self, mock_get_db, mock_rl):
        from handlers.products import upload_product_images

        db, _, _ = _seller_db(onboarding_completed=True)
        mock_get_db.return_value = db
        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {"fileNames": ["x.jpg"], "contentTypes": ["application/pdf"]}

        with pytest.raises(https_fn.HttpsError) as exc:
            upload_product_images(req)
        assert exc.value.code == "invalid-argument"

    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_upload_product_images_rejects_invalid_extension(self, mock_get_db, mock_rl):
        from handlers.products import upload_product_images

        db, _, _ = _seller_db(onboarding_completed=True)
        mock_get_db.return_value = db
        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {"fileNames": ["x.exe"], "contentTypes": ["image/png"]}

        with pytest.raises(https_fn.HttpsError) as exc:
            upload_product_images(req)
        assert exc.value.code == "invalid-argument"

    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_upload_product_images_requires_onboarding_for_non_admin(self, mock_get_db, mock_rl):
        from handlers.products import upload_product_images

        db, _, _ = _seller_db(onboarding_completed=False)
        mock_get_db.return_value = db
        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {"fileNames": ["x.jpg"], "contentTypes": ["image/jpeg"]}

        with pytest.raises(https_fn.HttpsError) as exc:
            upload_product_images(req)
        assert exc.value.code == "failed-precondition"

    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_upload_product_images_rate_limited(self, mock_get_db, mock_rl):
        from handlers.products import upload_product_images

        db, _, _ = _seller_db(onboarding_completed=True)
        mock_get_db.return_value = db
        mock_rl.return_value.check_rate_limit.return_value = (False, "too many uploads")

        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {"fileNames": ["x.jpg"], "contentTypes": ["image/jpeg"]}

        with pytest.raises(https_fn.HttpsError) as exc:
            upload_product_images(req)
        assert exc.value.code == "resource-exhausted"

    @patch("handlers.products._get_cached_s3_client")
    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_upload_product_images_s3_failure_becomes_internal(self, mock_get_db, mock_rl, mock_get_s3):
        from handlers.products import upload_product_images

        db, _, _ = _seller_db(onboarding_completed=True)
        mock_get_db.return_value = db
        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        mock_get_s3.return_value.generate_presigned_url.side_effect = RuntimeError("r2 down")

        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {"fileNames": ["x.jpg"], "contentTypes": ["image/jpeg"]}

        with pytest.raises(https_fn.HttpsError) as exc:
            upload_product_images(req)
        assert exc.value.code == "internal"


class TestUploadProductVideoAndDeleteImages:
    def test_upload_product_video_requires_auth(self):
        from handlers.products import upload_product_video

        req = Mock()
        req.auth = None
        req.data = {}
        with pytest.raises(https_fn.HttpsError) as exc:
            upload_product_video(req)
        assert exc.value.code == "unauthenticated"

    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_upload_product_video_rejects_missing_file(self, mock_get_db, mock_rl):
        from handlers.products import upload_product_video

        db, _, _ = _seller_db(onboarding_completed=True)
        mock_get_db.return_value = db
        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {"contentType": "video/mp4"}
        with pytest.raises(https_fn.HttpsError) as exc:
            upload_product_video(req)
        assert exc.value.code == "invalid-argument"

    @patch("handlers.products._get_cached_s3_client")
    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_upload_product_video_s3_failure_returns_internal(self, mock_get_db, mock_rl, mock_get_s3):
        from handlers.products import upload_product_video

        db, _, _ = _seller_db(onboarding_completed=True)
        mock_get_db.return_value = db
        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        mock_get_s3.return_value.generate_presigned_url.side_effect = RuntimeError("r2 down")

        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {"fileName": "demo.mp4", "contentType": "video/mp4"}
        with pytest.raises(https_fn.HttpsError) as exc:
            upload_product_video(req)
        assert exc.value.code == "internal"

    @patch("handlers.products.create_success_response", side_effect=lambda payload: {"success": True, **payload})
    @patch("handlers.products._get_cached_s3_client")
    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_upload_product_video_success(self, mock_get_db, mock_rl, mock_get_s3, _mock_resp):
        from handlers.products import upload_product_video

        db, _, _ = _seller_db(onboarding_completed=True)
        mock_get_db.return_value = db
        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        mock_get_s3.return_value.generate_presigned_url.return_value = "https://signed.example.com/video"

        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {"fileName": "demo.mp4", "contentType": "video/mp4"}

        out = upload_product_video(req)
        assert out["success"] is True
        assert out["fileName"] == "demo.mp4"

    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_upload_product_video_rejects_invalid_mime(self, mock_get_db, mock_rl):
        from handlers.products import upload_product_video

        db, _, _ = _seller_db(onboarding_completed=True)
        mock_get_db.return_value = db
        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {"fileName": "demo.mp4", "contentType": "application/octet-stream"}

        with pytest.raises(https_fn.HttpsError) as exc:
            upload_product_video(req)
        assert exc.value.code == "invalid-argument"
        assert "Allowed" in str(exc.value)
        assert "video/mp4" in ", ".join(sorted(ProductConstraints.ALLOWED_VIDEO_MIME_TYPES))

    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_upload_product_video_rejects_invalid_extension(self, mock_get_db, mock_rl):
        from handlers.products import upload_product_video

        db, _, _ = _seller_db(onboarding_completed=True)
        mock_get_db.return_value = db
        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {"fileName": "demo.avi", "contentType": "video/mp4"}

        with pytest.raises(https_fn.HttpsError) as exc:
            upload_product_video(req)
        assert exc.value.code == "invalid-argument"

    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_upload_product_video_user_role_onboarding_and_rate_limit_guards(self, mock_get_db, mock_rl):
        from handlers.products import upload_product_video

        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {"fileName": "demo.mp4", "contentType": "video/mp4"}

        users_col = Mock()
        profiles_col = Mock()
        db = Mock()
        db.collection.side_effect = lambda name: {
            Collections.USERS: users_col,
            Collections.SELLER_PROFILES: profiles_col,
        }.get(name, Mock())
        mock_get_db.return_value = db
        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        users_col.document.return_value.get.return_value = _snap(exists=False)
        with pytest.raises(https_fn.HttpsError) as missing_user:
            upload_product_video(req)
        assert missing_user.value.code == "not-found"

        users_col.document.return_value.get.return_value = _snap(
            {Fields.SUSPENDED: True, Fields.ROLES: ["seller"]}, exists=True
        )
        with pytest.raises(https_fn.HttpsError) as suspended:
            upload_product_video(req)
        assert suspended.value.code == "permission-denied"

        users_col.document.return_value.get.return_value = _snap(
            {Fields.SUSPENDED: False, Fields.ROLES: ["buyer"]}, exists=True
        )
        with pytest.raises(https_fn.HttpsError) as bad_role:
            upload_product_video(req)
        assert bad_role.value.code == "permission-denied"

        users_col.document.return_value.get.return_value = _snap(
            {Fields.SUSPENDED: False, Fields.ROLES: ["seller"]}, exists=True
        )
        profiles_col.document.return_value.get.return_value = _snap({Fields.ONBOARDING_COMPLETED: False}, exists=True)
        with pytest.raises(https_fn.HttpsError) as onboarding:
            upload_product_video(req)
        assert onboarding.value.code == "failed-precondition"

        profiles_col.document.return_value.get.return_value = _snap({Fields.ONBOARDING_COMPLETED: True}, exists=True)
        mock_rl.return_value.check_rate_limit.return_value = (False, "slow down")
        with pytest.raises(https_fn.HttpsError) as limited:
            upload_product_video(req)
        assert limited.value.code == "resource-exhausted"

    def test_delete_product_images_requires_auth(self):
        from handlers.products import delete_product_images

        req = Mock()
        req.auth = None
        req.data = {"publicUrls": ["https://cdn.origna.io/products/a.jpg"]}

        with pytest.raises(https_fn.HttpsError) as exc:
            delete_product_images(req)
        assert exc.value.code == "unauthenticated"

    @patch("handlers.products.get_db")
    def test_delete_product_images_user_guard_branches(self, mock_get_db):
        from handlers.products import delete_product_images

        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {"publicUrls": ["https://cdn.origna.io/products/a.jpg"]}

        users_col = Mock()
        db = Mock()
        db.collection.side_effect = lambda name: {Collections.USERS: users_col}.get(name, Mock())
        mock_get_db.return_value = db

        users_col.document.return_value.get.return_value = _snap(exists=False)
        with pytest.raises(https_fn.HttpsError) as missing_user:
            delete_product_images(req)
        assert missing_user.value.code == "not-found"

        users_col.document.return_value.get.return_value = _snap(
            {Fields.SUSPENDED: True, Fields.ROLES: ["seller"]}, exists=True
        )
        with pytest.raises(https_fn.HttpsError) as suspended:
            delete_product_images(req)
        assert suspended.value.code == "permission-denied"

        users_col.document.return_value.get.return_value = _snap(
            {Fields.SUSPENDED: False, Fields.ROLES: ["buyer"]}, exists=True
        )
        with pytest.raises(https_fn.HttpsError) as role_denied:
            delete_product_images(req)
        assert role_denied.value.code == "permission-denied"

    @patch("handlers.products.create_success_response", side_effect=lambda payload: {"success": True, **payload})
    @patch("handlers.products._get_cached_s3_client")
    @patch("handlers.products.get_db")
    def test_delete_product_images_invalid_url_prefix_is_counted_failed(self, mock_get_db, mock_get_s3, _mock_resp):
        from handlers.products import delete_product_images

        db, _, _ = _seller_db(onboarding_completed=True)
        mock_get_db.return_value = db
        mock_get_s3.return_value = Mock()

        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {"publicUrls": ["https://evil.example.com/not-cdn.jpg"]}

        with patch("handlers.products.CDN_BASE_URL", "https://cdn.origna.io"):
            out = delete_product_images(req)
        assert out["success"] is True
        assert out["deleted"] == 0
        assert out["failed"] == 1

    @patch("handlers.products.create_success_response", side_effect=lambda payload: {"success": True, **payload})
    @patch("handlers.products._get_cached_s3_client")
    @patch("handlers.products.get_db")
    def test_delete_product_images_mixed_urls_counts_deleted_and_failed(self, mock_get_db, mock_get_s3, _mock_resp):
        from handlers.products import delete_product_images

        db, _, _ = _seller_db(onboarding_completed=True)
        mock_get_db.return_value = db

        s3 = Mock()
        s3.delete_object.side_effect = [None, RuntimeError("delete failed")]
        mock_get_s3.return_value = s3

        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {
            "publicUrls": [
                "https://cdn.origna.io/products/ok1.jpg",
                "https://cdn.origna.io/users/not-allowed.png",
                "https://cdn.origna.io/dev/products/fail2.jpg",
            ]
        }

        with patch("handlers.products.CDN_BASE_URL", "https://cdn.origna.io"):
            out = delete_product_images(req)
        assert out["success"] is True
        assert out["deleted"] == 1
        assert out["failed"] == 2

    @patch("handlers.products.get_db")
    def test_delete_product_images_requires_non_empty_list(self, mock_get_db):
        from handlers.products import delete_product_images

        db, _, _ = _seller_db()
        mock_get_db.return_value = db

        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {"publicUrls": []}

        with pytest.raises(https_fn.HttpsError) as exc:
            delete_product_images(req)
        assert exc.value.code == "invalid-argument"

    @patch("handlers.products.get_db")
    def test_delete_product_images_rejects_too_many_urls(self, mock_get_db):
        from handlers.products import delete_product_images

        db, _, _ = _seller_db()
        mock_get_db.return_value = db
        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {"publicUrls": [f"https://cdn.origna.io/products/{i}.jpg" for i in range(11)]}
        with pytest.raises(https_fn.HttpsError) as exc:
            delete_product_images(req)
        assert exc.value.code == "invalid-argument"


class TestUploadReviewImages:
    def test_upload_review_images_requires_auth(self):
        from handlers.products import upload_review_images

        req = Mock()
        req.auth = None
        req.data = {}
        with pytest.raises(https_fn.HttpsError) as exc:
            upload_review_images(req)
        assert exc.value.code == "unauthenticated"

    @patch("handlers.products.create_success_response", side_effect=lambda payload: {"success": True, **payload})
    @patch("handlers.products._get_cached_s3_client")
    @patch("utils.premium_check.is_premium_authoritative", return_value=True)
    @patch("handlers.products.get_db")
    def test_upload_review_images_success(self, mock_get_db, _mock_premium, mock_get_s3, _mock_resp):
        from handlers.products import upload_review_images

        mock_get_db.return_value = Mock()
        mock_get_s3.return_value.generate_presigned_url.return_value = "https://signed.example.com/review"

        req = Mock()
        req.auth = Mock(uid="buyer_1")
        req.data = {"fileNames": ["r1.jpg"], "contentTypes": ["image/jpeg"]}

        out = upload_review_images(req)
        assert out["success"] is True
        assert len(out["uploadUrls"]) == 1

    @patch("utils.premium_check.is_premium_authoritative", return_value=False)
    @patch("handlers.products.get_db")
    def test_upload_review_images_rejects_non_premium_users(self, mock_get_db, _mock_premium):
        from handlers.products import upload_review_images

        mock_get_db.return_value = Mock()
        req = Mock()
        req.auth = Mock(uid="buyer_1")
        req.data = {"fileNames": ["r1.jpg"], "contentTypes": ["image/jpeg"]}

        with pytest.raises(https_fn.HttpsError) as exc:
            upload_review_images(req)
        assert exc.value.code == "permission-denied"

    @patch("utils.premium_check.is_premium_authoritative", return_value=True)
    @patch("handlers.products.get_db")
    def test_upload_review_images_validates_limits_and_types(self, mock_get_db, _mock_premium):
        from handlers.products import upload_review_images

        mock_get_db.return_value = Mock()
        req = Mock()
        req.auth = Mock(uid="buyer_1")
        req.data = {
            "fileNames": [f"r{i}.jpg" for i in range(BusinessRules.MAX_REVIEW_IMAGES + 1)],
            "contentTypes": ["image/jpeg"] * (BusinessRules.MAX_REVIEW_IMAGES + 1),
        }

        with pytest.raises(https_fn.HttpsError) as exc:
            upload_review_images(req)
        assert exc.value.code == "invalid-argument"

        req.data = {"fileNames": ["r1.jpg"], "contentTypes": ["image/gif"]}
        with pytest.raises(https_fn.HttpsError) as exc2:
            upload_review_images(req)
        assert exc2.value.code == "invalid-argument"

        req.data = {"fileNames": ["r1.jpg"], "contentTypes": []}
        with pytest.raises(https_fn.HttpsError) as exc3:
            upload_review_images(req)
        assert exc3.value.code == "invalid-argument"

    @patch("utils.premium_check.is_premium_authoritative", return_value=True)
    @patch("handlers.products.get_db")
    def test_upload_review_images_rejects_missing_files_and_bad_extension(self, mock_get_db, _mock_premium):
        from handlers.products import upload_review_images

        mock_get_db.return_value = Mock()
        req = Mock()
        req.auth = Mock(uid="buyer_1")
        req.data = {"fileNames": [], "contentTypes": []}

        with pytest.raises(https_fn.HttpsError) as no_files:
            upload_review_images(req)
        assert no_files.value.code == "invalid-argument"

        req.data = {"fileNames": ["photo.exe"], "contentTypes": ["image/jpeg"]}
        with pytest.raises(https_fn.HttpsError) as bad_ext:
            upload_review_images(req)
        assert bad_ext.value.code == "invalid-argument"

    @patch("handlers.products._get_cached_s3_client")
    @patch("utils.premium_check.is_premium_authoritative", return_value=True)
    @patch("handlers.products.get_db")
    def test_upload_review_images_presign_failure_returns_internal(self, mock_get_db, _mock_premium, mock_get_s3):
        from handlers.products import upload_review_images

        mock_get_db.return_value = Mock()
        mock_get_s3.return_value.generate_presigned_url.side_effect = RuntimeError("presign failed")
        req = Mock()
        req.auth = Mock(uid="buyer_1")
        req.data = {"fileNames": ["r1.jpg"], "contentTypes": ["image/jpeg"]}
        with pytest.raises(https_fn.HttpsError) as exc:
            upload_review_images(req)
        assert exc.value.code == "internal"


class TestDeleteProductDeep:
    def test_delete_product_requires_auth(self):
        from handlers.products import delete_product

        req = Mock()
        req.auth = None
        req.data = {Fields.PRODUCT_ID: "p1"}
        with pytest.raises(https_fn.HttpsError) as exc:
            delete_product(req)
        assert exc.value.code == "unauthenticated"

    @patch("handlers.products.create_success_response", side_effect=lambda payload: {"success": True, **payload})
    @patch("handlers.products._get_cached_s3_client")
    @patch("handlers.products.algolia_delete_product", side_effect=RuntimeError("algolia unavailable"))
    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_delete_product_success_cleans_images_notifications_and_favorites(
        self, mock_get_db, mock_rl, _mock_algolia, mock_get_s3, _mock_resp
    ):
        from handlers.products import delete_product

        db = Mock()
        mock_get_db.return_value = db
        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        product_doc = _snap(
            {
                Fields.SELLER_ID: "seller_1",
                Fields.IMAGE_URLS: [
                    "https://cdn.origna.io/products/ok1.jpg",
                    "https://cdn.origna.io/users/ignored.jpg",
                ],
            }
        )
        product_ref = Mock()
        product_ref.get.return_value = product_doc

        user_doc = _snap({Fields.ROLES: ["seller"]})
        user_ref = Mock()
        user_ref.get.return_value = user_doc

        orders_q = _query(stream_return=[])

        sub1 = _snap()
        sub2 = _snap()
        stock_q = _query(stream_side_effect=[[sub1, sub2], []])

        fav1 = _snap()
        favorites_q = _query(stream_side_effect=[[fav1]])

        products_col = Mock()
        products_col.document.return_value = product_ref
        users_col = Mock()
        users_col.document.return_value = user_ref
        orders_col = Mock()
        orders_col.where.return_value = orders_q
        stock_col = Mock()
        stock_col.where.return_value = stock_q

        db.collection.side_effect = lambda name: {
            Collections.PRODUCTS: products_col,
            Collections.USERS: users_col,
            Collections.ORDERS: orders_col,
            Collections.STOCK_NOTIFICATIONS: stock_col,
        }.get(name, Mock())
        db.collection_group.return_value = favorites_q

        batch_stock = Mock()
        batch_fav = Mock()
        db.batch.side_effect = [batch_stock, batch_fav]

        s3 = Mock()
        mock_get_s3.return_value = s3

        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {Fields.PRODUCT_ID: "prod_1"}

        with patch("handlers.products.CDN_BASE_URL", "https://cdn.origna.io"):
            out = delete_product(req)

        assert out["success"] is True
        product_ref.update.assert_called_once()
        s3.delete_object.assert_called_once()
        batch_stock.delete.assert_any_call(sub1.reference)
        batch_stock.delete.assert_any_call(sub2.reference)
        batch_stock.commit.assert_called_once()
        batch_fav.delete.assert_called_once_with(fav1.reference)
        batch_fav.commit.assert_called_once()

    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_delete_product_blocks_when_pending_orders_exist(self, mock_get_db, mock_rl):
        from handlers.products import delete_product

        db = Mock()
        mock_get_db.return_value = db
        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        product_ref = Mock()
        product_ref.get.return_value = _snap({Fields.SELLER_ID: "seller_1"})
        user_ref = Mock()
        user_ref.get.return_value = _snap({Fields.ROLES: ["seller"]})

        pending_order = _snap({Fields.ITEMS: [{Fields.PRODUCT_ID: "prod_1"}]})
        orders_q = _query(stream_return=[pending_order])

        products_col = Mock()
        products_col.document.return_value = product_ref
        users_col = Mock()
        users_col.document.return_value = user_ref
        orders_col = Mock()
        orders_col.where.return_value = orders_q

        db.collection.side_effect = lambda name: {
            Collections.PRODUCTS: products_col,
            Collections.USERS: users_col,
            Collections.ORDERS: orders_col,
        }.get(name, Mock())

        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {Fields.PRODUCT_ID: "prod_1"}

        with pytest.raises(https_fn.HttpsError) as exc:
            delete_product(req)
        assert exc.value.code == "failed-precondition"

    @patch("handlers.products.get_db")
    def test_delete_product_requires_product_id(self, mock_get_db):
        from handlers.products import delete_product

        mock_get_db.return_value = Mock()
        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {}

        with pytest.raises(https_fn.HttpsError) as exc:
            delete_product(req)
        assert exc.value.code == "invalid-argument"

    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_delete_product_rejects_non_owner_non_admin(self, mock_get_db, mock_rl):
        from handlers.products import delete_product

        db = Mock()
        mock_get_db.return_value = db
        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        product_ref = Mock()
        product_ref.get.return_value = _snap({Fields.SELLER_ID: "other_seller"})
        user_ref = Mock()
        user_ref.get.return_value = _snap({Fields.ROLES: ["buyer"]})

        products_col = Mock()
        products_col.document.return_value = product_ref
        users_col = Mock()
        users_col.document.return_value = user_ref

        db.collection.side_effect = lambda name: {
            Collections.PRODUCTS: products_col,
            Collections.USERS: users_col,
        }.get(name, Mock())

        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {Fields.PRODUCT_ID: "prod_1"}

        with pytest.raises(https_fn.HttpsError) as exc:
            delete_product(req)
        assert exc.value.code == "permission-denied"

    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_delete_product_rate_limited(self, mock_get_db, mock_rl):
        from handlers.products import delete_product

        mock_get_db.return_value = Mock()
        mock_rl.return_value.check_rate_limit.return_value = (False, "slow down")
        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {Fields.PRODUCT_ID: "prod_1"}
        with pytest.raises(https_fn.HttpsError) as exc:
            delete_product(req)
        assert exc.value.code == "resource-exhausted"

    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_delete_product_not_found(self, mock_get_db, mock_rl):
        from handlers.products import delete_product

        db = Mock()
        mock_get_db.return_value = db
        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        product_ref = Mock()
        product_ref.get.return_value = _snap(exists=False)
        products_col = Mock()
        products_col.document.return_value = product_ref
        db.collection.side_effect = lambda name: {Collections.PRODUCTS: products_col}.get(name, Mock())

        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {Fields.PRODUCT_ID: "prod_1"}
        with pytest.raises(https_fn.HttpsError) as exc:
            delete_product(req)
        assert exc.value.code == "not-found"

    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_delete_product_user_not_found_after_product_lookup(self, mock_get_db, mock_rl):
        from handlers.products import delete_product

        db = Mock()
        mock_get_db.return_value = db
        mock_rl.return_value.check_rate_limit.return_value = (True, "")

        product_ref = Mock()
        product_ref.get.return_value = _snap({Fields.SELLER_ID: "seller_1"}, exists=True)
        user_ref = Mock()
        user_ref.get.return_value = _snap(exists=False)

        products_col = Mock()
        products_col.document.return_value = product_ref
        users_col = Mock()
        users_col.document.return_value = user_ref
        db.collection.side_effect = lambda name: {
            Collections.PRODUCTS: products_col,
            Collections.USERS: users_col,
        }.get(name, Mock())

        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {Fields.PRODUCT_ID: "prod_1"}
        with pytest.raises(https_fn.HttpsError) as exc:
            delete_product(req)
        assert exc.value.code == "not-found"


class TestSubmitProductRatingAtomicDeep:
    def test_submit_product_rating_atomic_requires_auth(self):
        from handlers.products import submit_product_rating_atomic

        req = Mock()
        req.auth = None
        req.data = {}
        with pytest.raises(https_fn.HttpsError) as exc:
            submit_product_rating_atomic(req)
        assert exc.value.code == "unauthenticated"

    @patch("handlers.products.get_db")
    def test_submit_product_rating_atomic_validates_required_and_rating_range(self, mock_get_db):
        from handlers.products import submit_product_rating_atomic

        mock_get_db.return_value = Mock()
        req = Mock()
        req.auth = Mock(uid="buyer_1")
        req.data = {Fields.PRODUCT_ID: "p1"}
        with pytest.raises(https_fn.HttpsError) as exc:
            submit_product_rating_atomic(req)
        assert exc.value.code == "invalid-argument"

        req.data = {Fields.PRODUCT_ID: "p1", Fields.ORDER_ID: "o1", Fields.RATING: 6}
        with pytest.raises(https_fn.HttpsError) as exc2:
            submit_product_rating_atomic(req)
        assert exc2.value.code == "invalid-argument"

    @patch("handlers.products.get_db")
    def test_submit_product_rating_atomic_image_premium_and_max_guards(self, mock_get_db):
        from handlers.products import submit_product_rating_atomic

        mock_get_db.return_value = Mock()
        req = Mock()
        req.auth = Mock(uid="buyer_1")

        with patch("utils.premium_check.is_premium_authoritative", return_value=False):
            req.data = {
                Fields.PRODUCT_ID: "p1",
                Fields.ORDER_ID: "o1",
                Fields.RATING: 5,
                "images": [{"contentType": "image/jpeg", "data": "AQ=="}],
            }
            with pytest.raises(https_fn.HttpsError) as premium_exc:
                submit_product_rating_atomic(req)
            assert premium_exc.value.code == "permission-denied"

        with patch("utils.premium_check.is_premium_authoritative", return_value=True):
            req.data = {
                Fields.PRODUCT_ID: "p1",
                Fields.ORDER_ID: "o1",
                Fields.RATING: 5,
                "images": [{"contentType": "image/jpeg", "data": "AQ=="}] * (BusinessRules.MAX_REVIEW_IMAGES + 1),
            }
            with pytest.raises(https_fn.HttpsError) as max_exc:
                submit_product_rating_atomic(req)
            assert max_exc.value.code == "invalid-argument"

    @patch("handlers.products.get_db")
    def test_submit_product_rating_atomic_order_validation_branches(self, mock_get_db):
        from handlers.products import submit_product_rating_atomic

        order_ref = Mock()
        orders_col = Mock()
        orders_col.document.return_value = order_ref
        db = Mock()
        db.collection.side_effect = lambda name: {Collections.ORDERS: orders_col}.get(name, Mock())
        mock_get_db.return_value = db

        req = Mock()
        req.auth = Mock(uid="buyer_1")
        req.data = {Fields.PRODUCT_ID: "p1", Fields.ORDER_ID: "o1", Fields.RATING: 5}

        order_ref.get.return_value = _snap(exists=False)
        with pytest.raises(https_fn.HttpsError) as exc:
            submit_product_rating_atomic(req)
        assert exc.value.code == "not-found"

        order_ref.get.return_value = _snap({Fields.USER_ID: "other", Fields.ORDER_STATUS: "delivered", Fields.ITEMS: []})
        with pytest.raises(https_fn.HttpsError) as exc2:
            submit_product_rating_atomic(req)
        assert exc2.value.code == "permission-denied"

        order_ref.get.return_value = _snap({Fields.USER_ID: "buyer_1", Fields.ORDER_STATUS: "processing", Fields.ITEMS: []})
        with pytest.raises(https_fn.HttpsError) as exc3:
            submit_product_rating_atomic(req)
        assert exc3.value.code == "failed-precondition"

        order_ref.get.return_value = _snap(
            {
                Fields.USER_ID: "buyer_1",
                Fields.ORDER_STATUS: "delivered",
                Fields.ITEMS: [{Fields.PRODUCT_ID: "another"}],
            }
        )
        with pytest.raises(https_fn.HttpsError) as exc4:
            submit_product_rating_atomic(req)
        assert exc4.value.code == "invalid-argument"

    @patch("handlers.products.create_success_response", side_effect=lambda payload: {"success": True, **payload})
    @patch("handlers.products.algolia_partial_update")
    @patch("handlers.products.get_firestore")
    @patch("handlers.products.get_db")
    def test_submit_product_rating_atomic_success_without_images(
        self, mock_get_db, mock_get_fs, mock_algolia_partial, _mock_resp
    ):
        from handlers.products import submit_product_rating_atomic

        mock_get_fs.return_value.transactional = lambda fn: fn

        db = Mock()
        tx = Mock()
        db.transaction.return_value = tx
        mock_get_db.return_value = db

        order_ref = Mock()
        order_ref.get.return_value = _snap(
            {
                Fields.USER_ID: "buyer_1",
                Fields.ORDER_STATUS: "delivered",
                Fields.ITEMS: [{Fields.PRODUCT_ID: "prod_1", Fields.SELLER_ID: "seller_1"}],
            }
        )
        orders_col = Mock()
        orders_col.document.return_value = order_ref

        product_ref = Mock()
        product_ref.get.return_value = _snap({Fields.RATING: 4.0, Fields.RATING_COUNT: 2})
        products_col = Mock()
        products_col.document.return_value = product_ref

        q1 = _query(stream_return=[])
        q2 = _query(stream_return=[])
        ratings_col = Mock()
        ratings_col.where.side_effect = [q1, q2]
        ratings_col.document.return_value = Mock()

        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.PRODUCTS: products_col,
            Collections.PRODUCT_RATINGS: ratings_col,
        }[name]

        req = Mock()
        req.auth = Mock(uid="buyer_1")
        req.data = {
            Fields.PRODUCT_ID: "prod_1",
            Fields.ORDER_ID: "order_1",
            Fields.RATING: 5,
            Fields.REVIEW: "Great product",
            "images": [],
        }

        out = submit_product_rating_atomic(req)

        assert out["success"] is True
        tx.create.assert_called_once()
        tx.update.assert_called_once()
        mock_algolia_partial.assert_called_once()

    @patch("utils.premium_check.is_premium_authoritative", return_value=True)
    @patch("handlers.products.get_firestore")
    @patch("handlers.products._get_cached_s3_client")
    @patch("handlers.products.get_db")
    def test_submit_product_rating_atomic_rolls_back_uploaded_images_on_failure(
        self, mock_get_db, mock_get_s3, mock_get_fs, _mock_premium
    ):
        from handlers.products import submit_product_rating_atomic

        mock_get_fs.return_value.transactional = lambda fn: fn

        db = Mock()
        db.transaction.return_value = Mock()
        mock_get_db.return_value = db

        order_ref = Mock()
        order_ref.get.return_value = _snap(
            {
                Fields.USER_ID: "buyer_1",
                Fields.ORDER_STATUS: "delivered",
                Fields.ITEMS: [{Fields.PRODUCT_ID: "prod_1", Fields.SELLER_ID: "seller_1"}],
            }
        )
        orders_col = Mock()
        orders_col.document.return_value = order_ref

        products_col = Mock()
        products_col.document.return_value = Mock()

        ratings_col = Mock()
        ratings_col.where.side_effect = RuntimeError("ratings query failed")
        ratings_col.document.return_value = Mock()

        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.PRODUCTS: products_col,
            Collections.PRODUCT_RATINGS: ratings_col,
        }[name]

        s3 = Mock()
        mock_get_s3.return_value = s3

        img_b64 = base64.b64encode(b"image-bytes").decode("utf-8")
        req = Mock()
        req.auth = Mock(uid="buyer_1")
        req.data = {
            Fields.PRODUCT_ID: "prod_1",
            Fields.ORDER_ID: "order_1",
            Fields.RATING: 4,
            "images": [{"contentType": "image/jpeg", "data": img_b64}],
        }

        with pytest.raises(https_fn.HttpsError) as exc:
            submit_product_rating_atomic(req)
        assert exc.value.code == "internal"
        s3.put_object.assert_called_once()
        assert s3.delete_object.called

    @patch("utils.premium_check.is_premium_authoritative", return_value=True)
    @patch("handlers.products._get_cached_s3_client")
    @patch("handlers.products.get_db")
    def test_submit_product_rating_atomic_upload_error_cleans_partial_r2_objects(
        self, mock_get_db, mock_get_s3, _mock_premium
    ):
        from handlers.products import submit_product_rating_atomic

        db = Mock()
        mock_get_db.return_value = db

        order_ref = Mock()
        order_ref.get.return_value = _snap(
            {
                Fields.USER_ID: "buyer_1",
                Fields.ORDER_STATUS: "delivered",
                Fields.ITEMS: [{Fields.PRODUCT_ID: "prod_1", Fields.SELLER_ID: "seller_1"}],
            }
        )
        orders_col = Mock()
        orders_col.document.return_value = order_ref
        db.collection.side_effect = lambda name: {Collections.ORDERS: orders_col}.get(name, Mock())

        s3 = Mock()
        s3.put_object.side_effect = [None, RuntimeError("r2 down")]
        mock_get_s3.return_value = s3

        img_b64 = base64.b64encode(b"image-bytes").decode("utf-8")
        req = Mock()
        req.auth = Mock(uid="buyer_1")
        req.data = {
            Fields.PRODUCT_ID: "prod_1",
            Fields.ORDER_ID: "order_1",
            Fields.RATING: 5,
            "images": [
                {"contentType": "image/jpeg", "data": img_b64},
                {"contentType": "image/png", "data": img_b64},
            ],
        }

        with pytest.raises(https_fn.HttpsError) as exc:
            submit_product_rating_atomic(req)
        assert exc.value.code == "internal"
        assert s3.put_object.call_count == 2
        assert s3.delete_object.called

    @patch("handlers.products.get_db")
    def test_submit_product_rating_atomic_blocks_seller_self_rating(self, mock_get_db):
        from handlers.products import submit_product_rating_atomic

        db = Mock()
        mock_get_db.return_value = db

        order_ref = Mock()
        order_ref.get.return_value = _snap(
            {
                Fields.USER_ID: "seller_1",
                Fields.ORDER_STATUS: "delivered",
                Fields.ITEMS: [{Fields.PRODUCT_ID: "prod_1", Fields.SELLER_ID: "seller_1"}],
            }
        )
        orders_col = Mock()
        orders_col.document.return_value = order_ref
        db.collection.side_effect = lambda name: orders_col if name == Collections.ORDERS else Mock()

        req = Mock()
        req.auth = Mock(uid="seller_1")
        req.data = {
            Fields.PRODUCT_ID: "prod_1",
            Fields.ORDER_ID: "order_1",
            Fields.RATING: 5,
        }

        with pytest.raises(https_fn.HttpsError) as exc:
            submit_product_rating_atomic(req)
        assert exc.value.code == "permission-denied"

    @patch("utils.premium_check.is_premium_authoritative", return_value=True)
    @patch("handlers.products.get_firestore")
    @patch("handlers.products._get_cached_s3_client")
    @patch("handlers.products.get_db")
    def test_submit_product_rating_atomic_duplicate_and_product_missing_branches(
        self, mock_get_db, mock_get_s3, mock_get_fs, _mock_premium
    ):
        from handlers.products import submit_product_rating_atomic

        mock_get_fs.return_value.transactional = lambda fn: fn

        order_ref = Mock()
        order_ref.get.return_value = _snap(
            {
                Fields.USER_ID: "buyer_1",
                Fields.ORDER_STATUS: "delivered",
                Fields.ITEMS: [{Fields.PRODUCT_ID: "prod_1", Fields.SELLER_ID: "seller_1"}],
            }
        )
        orders_col = Mock()
        orders_col.document.return_value = order_ref

        product_ref = Mock()
        product_ref.get.return_value = _snap({Fields.RATING: 4.0, Fields.RATING_COUNT: 2})
        products_col = Mock()
        products_col.document.return_value = product_ref

        q_order_dup = _query(stream_return=[_snap({Fields.ORDER_ID: "order_1"})])
        q_empty_1 = _query(stream_return=[])
        q_user_dup = _query(stream_return=[_snap({Fields.USER_ID: "buyer_1"})])
        q_empty_2 = _query(stream_return=[])
        q_empty_3 = _query(stream_return=[])
        ratings_col = Mock()
        ratings_col.where.side_effect = [q_order_dup, q_empty_1, q_user_dup, q_empty_2, q_empty_3]
        ratings_col.document.return_value = Mock()

        db = Mock()
        db.transaction.return_value = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.PRODUCTS: products_col,
            Collections.PRODUCT_RATINGS: ratings_col,
        }[name]
        mock_get_db.return_value = db

        s3 = Mock()
        mock_get_s3.return_value = s3

        req = Mock()
        req.auth = Mock(uid="buyer_1")
        req.data = {
            Fields.PRODUCT_ID: "prod_1",
            Fields.ORDER_ID: "order_1",
            Fields.RATING: 5,
            # Exercise "skip bad mime" and "skip empty bytes" branches.
            "images": [
                {"contentType": "text/plain", "data": "AQ=="},
                {"contentType": "image/jpeg", "data": ""},
            ],
        }

        with pytest.raises(https_fn.HttpsError) as dup_order_exc:
            submit_product_rating_atomic(req)
        assert dup_order_exc.value.code == "already-exists"

        with pytest.raises(https_fn.HttpsError) as dup_user_exc:
            submit_product_rating_atomic(req)
        assert dup_user_exc.value.code == "already-exists"

        product_ref.get.return_value = _snap(exists=False)
        with pytest.raises(https_fn.HttpsError) as product_missing_exc:
            submit_product_rating_atomic(req)
        assert product_missing_exc.value.code == "not-found"

        # No successful upload expected because all images were skipped.
        s3.put_object.assert_not_called()


class TestSubmitProductRatingDeep:
    def test_submit_product_rating_requires_auth(self):
        from handlers.products import submit_product_rating

        req = Mock()
        req.auth = None
        req.data = {}
        with pytest.raises(https_fn.HttpsError) as exc:
            submit_product_rating(req)
        assert exc.value.code == "unauthenticated"

    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_submit_product_rating_guard_matrix(self, mock_get_db, mock_rl):
        from handlers.products import submit_product_rating

        db = Mock()
        mock_get_db.return_value = db

        req = Mock()
        req.auth = Mock(uid="buyer_1")

        mock_rl.return_value.check_rate_limit.return_value = (False, "slow down")
        req.data = {Fields.PRODUCT_ID: "p1", Fields.ORDER_ID: "o1", Fields.RATING: 5}
        with pytest.raises(https_fn.HttpsError) as rate_exc:
            submit_product_rating(req)
        assert rate_exc.value.code == "resource-exhausted"

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        req.data = {Fields.REVIEW_IMAGE_URLS: "not-a-list", Fields.PRODUCT_ID: "p1", Fields.ORDER_ID: "o1", Fields.RATING: 5}
        with pytest.raises(https_fn.HttpsError) as not_list_exc:
            submit_product_rating(req)
        assert not_list_exc.value.code == "invalid-argument"

        req.data = {
            Fields.REVIEW_IMAGE_URLS: ["https://cdn.origna.io/a.jpg"] * (BusinessRules.MAX_REVIEW_IMAGES + 1),
            Fields.PRODUCT_ID: "p1",
            Fields.ORDER_ID: "o1",
            Fields.RATING: 5,
        }
        with pytest.raises(https_fn.HttpsError) as too_many_exc:
            submit_product_rating(req)
        assert too_many_exc.value.code == "invalid-argument"

        req.data = {
            Fields.REVIEW_IMAGE_URLS: ["https://cdn.origna.io/a.jpg"],
            Fields.PRODUCT_ID: "p1",
            Fields.ORDER_ID: "o1",
            Fields.RATING: 5,
        }
        with patch("utils.premium_check.is_premium_authoritative", return_value=False):
            with pytest.raises(https_fn.HttpsError) as premium_exc:
                submit_product_rating(req)
        assert premium_exc.value.code == "permission-denied"

        req.data = {Fields.PRODUCT_ID: "p1", Fields.ORDER_ID: "o1"}
        with pytest.raises(https_fn.HttpsError) as required_exc:
            submit_product_rating(req)
        assert required_exc.value.code == "invalid-argument"

        req.data = {Fields.PRODUCT_ID: "p1", Fields.ORDER_ID: "o1", Fields.RATING: 0}
        with pytest.raises(https_fn.HttpsError) as rating_exc:
            submit_product_rating(req)
        assert rating_exc.value.code == "invalid-argument"

        order_ref = Mock()
        orders_col = Mock()
        orders_col.document.return_value = order_ref
        db.collection.side_effect = lambda name: {Collections.ORDERS: orders_col}.get(name, Mock())

        req.data = {Fields.PRODUCT_ID: "p1", Fields.ORDER_ID: "o1", Fields.RATING: 5}
        order_ref.get.return_value = _snap({Fields.USER_ID: "other", Fields.ORDER_STATUS: "delivered", Fields.ITEMS: []})
        with pytest.raises(https_fn.HttpsError) as ownership_exc:
            submit_product_rating(req)
        assert ownership_exc.value.code == "permission-denied"

        order_ref.get.return_value = _snap(
            {
                Fields.USER_ID: "buyer_1",
                Fields.ORDER_STATUS: "delivered",
                Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.SELLER_ID: "buyer_1"}],
            }
        )
        with pytest.raises(https_fn.HttpsError) as self_rate_exc:
            submit_product_rating(req)
        assert self_rate_exc.value.code == "permission-denied"

        order_ref.get.return_value = _snap(
            {
                Fields.USER_ID: "buyer_1",
                Fields.ORDER_STATUS: "processing",
                Fields.ITEMS: [{Fields.PRODUCT_ID: "p1", Fields.SELLER_ID: "seller_1"}],
            }
        )
        with pytest.raises(https_fn.HttpsError) as status_exc:
            submit_product_rating(req)
        assert status_exc.value.code == "failed-precondition"

        order_ref.get.return_value = _snap(
            {
                Fields.USER_ID: "buyer_1",
                Fields.ORDER_STATUS: "delivered",
                Fields.ITEMS: [{Fields.PRODUCT_ID: "different", Fields.SELLER_ID: "seller_1"}],
            }
        )
        with pytest.raises(https_fn.HttpsError) as missing_product_exc:
            submit_product_rating(req)
        assert missing_product_exc.value.code == "invalid-argument"

    @patch("handlers.products.create_success_response", side_effect=lambda payload: {"success": True, **payload})
    @patch("handlers.products.algolia_partial_update")
    @patch("handlers.products.get_firestore")
    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_submit_product_rating_success_updates_product_and_seller_rating(
        self, mock_get_db, mock_rl, mock_get_fs, mock_algolia, _mock_resp
    ):
        from handlers.products import submit_product_rating

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        mock_get_fs.return_value.transactional = lambda fn: fn

        order_ref = Mock()
        order_ref.get.return_value = _snap(
            {
                Fields.USER_ID: "buyer_1",
                Fields.ORDER_STATUS: "delivered",
                Fields.SHIPPING_ADDRESS: {"street": "1 Queen", "city": "Toronto", "state": "ON", "postalCode": "M5H2N2"},
                Fields.ITEMS: [
                    {
                        Fields.PRODUCT_ID: "prod_1",
                        Fields.SELLER_ID: "seller_1",
                        Fields.SELLER_ADDRESS: {
                            "street": "1 Queen",
                            "city": "Toronto",
                            "state": "ON",
                            "postalCode": "M5H2N2",
                        },
                    }
                ],
            }
        )
        orders_col = Mock()
        orders_col.document.return_value = order_ref

        product_ref = Mock()
        product_ref.get.return_value = _snap({Fields.RATING: 4.0, Fields.RATING_COUNT: 2, Fields.SELLER_ID: "seller_1"})
        products_col = Mock()
        products_col.document.return_value = product_ref

        q_order = _query(stream_return=[])
        q_user_product = _query(stream_return=[])
        ratings_col = Mock()
        ratings_col.where.side_effect = [q_order, q_user_product]
        ratings_col.document.return_value = Mock()

        seller_ref = Mock()
        seller_ref.get.return_value = _snap({Fields.AVG_RATING: 4.2, Fields.TOTAL_REVIEWS: 10})
        users_col = Mock()
        users_col.document.return_value = seller_ref

        seller_ratings_col = Mock()
        seller_ratings_col.document.return_value = Mock()

        tx = Mock()
        db = Mock()
        db.transaction.return_value = tx
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.PRODUCTS: products_col,
            Collections.PRODUCT_RATINGS: ratings_col,
            Collections.USERS: users_col,
            Collections.SELLER_RATINGS: seller_ratings_col,
        }[name]
        mock_get_db.return_value = db

        req = Mock()
        req.auth = Mock(uid="buyer_1")
        req.data = {
            Fields.PRODUCT_ID: "prod_1",
            Fields.ORDER_ID: "order_1",
            Fields.RATING: 5,
            Fields.SELLER_RATING: 4,
            Fields.REVIEW: "Excellent",
        }

        out = submit_product_rating(req)
        assert out["success"] is True
        mock_algolia.assert_called_once()
        # 1 create for product rating + 1 create for seller rating
        assert tx.create.call_count == 2
        assert tx.update.call_count >= 2

    @patch("handlers.products.get_firestore")
    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_submit_product_rating_duplicate_order_is_blocked(self, mock_get_db, mock_rl, mock_get_fs):
        from handlers.products import submit_product_rating

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        mock_get_fs.return_value.transactional = lambda fn: fn

        order_ref = Mock()
        order_ref.get.return_value = _snap(
            {
                Fields.USER_ID: "buyer_1",
                Fields.ORDER_STATUS: "delivered",
                Fields.ITEMS: [{Fields.PRODUCT_ID: "prod_1", Fields.SELLER_ID: "seller_1"}],
            }
        )
        orders_col = Mock()
        orders_col.document.return_value = order_ref

        products_col = Mock()
        products_col.document.return_value = Mock()

        existing_rating = _snap({Fields.ORDER_ID: "order_1"})
        q_order = _query(stream_return=[existing_rating])
        ratings_col = Mock()
        ratings_col.where.return_value = q_order
        ratings_col.document.return_value = Mock()

        db = Mock()
        db.transaction.return_value = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.PRODUCTS: products_col,
            Collections.PRODUCT_RATINGS: ratings_col,
        }[name]
        mock_get_db.return_value = db

        req = Mock()
        req.auth = Mock(uid="buyer_1")
        req.data = {Fields.PRODUCT_ID: "prod_1", Fields.ORDER_ID: "order_1", Fields.RATING: 5}

        with pytest.raises(https_fn.HttpsError) as exc:
            submit_product_rating(req)
        assert exc.value.code == "already-exists"

    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_submit_product_rating_review_image_urls_require_cdn_and_premium(self, mock_get_db, mock_rl):
        from handlers.products import submit_product_rating

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        mock_get_db.return_value = Mock()

        req = Mock()
        req.auth = Mock(uid="buyer_1")
        req.data = {
            Fields.PRODUCT_ID: "prod_1",
            Fields.ORDER_ID: "order_1",
            Fields.RATING: 5,
            Fields.REVIEW_IMAGE_URLS: ["https://evil.example.com/a.jpg"],
        }

        with patch("utils.premium_check.is_premium_authoritative", return_value=True):
            with pytest.raises(https_fn.HttpsError) as exc:
                submit_product_rating(req)
        assert exc.value.code == "invalid-argument"

    @patch("handlers.products.get_firestore")
    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_submit_product_rating_duplicate_user_and_product_missing_branches(self, mock_get_db, mock_rl, mock_get_fs):
        from handlers.products import submit_product_rating

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        mock_get_fs.return_value.transactional = lambda fn: fn

        order_ref = Mock()
        order_ref.get.return_value = _snap(
            {
                Fields.USER_ID: "buyer_1",
                Fields.ORDER_STATUS: "delivered",
                Fields.ITEMS: [{Fields.PRODUCT_ID: "prod_1", Fields.SELLER_ID: "seller_1"}],
            }
        )
        orders_col = Mock()
        orders_col.document.return_value = order_ref

        product_ref = Mock()
        product_ref.get.return_value = _snap({Fields.RATING: 4.0, Fields.RATING_COUNT: 1, Fields.SELLER_ID: "seller_1"})
        products_col = Mock()
        products_col.document.return_value = product_ref

        q_order_empty_1 = _query(stream_return=[])
        q_user_dup = _query(stream_return=[_snap({Fields.PRODUCT_ID: "prod_1"})])
        q_order_empty_2 = _query(stream_return=[])
        q_user_empty = _query(stream_return=[])
        ratings_col = Mock()
        ratings_col.where.side_effect = [q_order_empty_1, q_user_dup, q_order_empty_2, q_user_empty]
        ratings_col.document.return_value = Mock()

        db = Mock()
        db.transaction.return_value = Mock()
        db.collection.side_effect = lambda name: {
            Collections.ORDERS: orders_col,
            Collections.PRODUCTS: products_col,
            Collections.PRODUCT_RATINGS: ratings_col,
        }[name]
        mock_get_db.return_value = db

        req = Mock()
        req.auth = Mock(uid="buyer_1")
        req.data = {Fields.PRODUCT_ID: "prod_1", Fields.ORDER_ID: "order_1", Fields.RATING: 5}

        with pytest.raises(https_fn.HttpsError) as dup_user_exc:
            submit_product_rating(req)
        assert dup_user_exc.value.code == "already-exists"

        product_ref.get.return_value = _snap(exists=False)
        with pytest.raises(https_fn.HttpsError) as missing_product_exc:
            submit_product_rating(req)
        assert missing_product_exc.value.code == "not-found"

    @patch("handlers.products.get_firestore")
    @patch("handlers.products.RateLimiter")
    @patch("handlers.products.get_db")
    def test_submit_product_rating_review_images_set_and_null_txn_result_maps_not_found(
        self, mock_get_db, mock_rl, mock_get_fs
    ):
        from handlers.products import CDN_BASE_URL, submit_product_rating

        mock_rl.return_value.check_rate_limit.return_value = (True, "")
        # Simulate a transaction wrapper that returns (None, None) without setting _txn_error.
        mock_get_fs.return_value.transactional = lambda _fn: (lambda _tx: (None, None))

        order_ref = Mock()
        order_ref.get.return_value = _snap(
            {
                Fields.USER_ID: "buyer_1",
                Fields.ORDER_STATUS: "delivered",
                Fields.ITEMS: [{Fields.PRODUCT_ID: "prod_1", Fields.SELLER_ID: "seller_1"}],
            }
        )
        orders_col = Mock()
        orders_col.document.return_value = order_ref

        db = Mock()
        db.transaction.return_value = Mock()
        db.collection.side_effect = lambda name: {Collections.ORDERS: orders_col}.get(name, Mock())
        mock_get_db.return_value = db

        req = Mock()
        req.auth = Mock(uid="buyer_1")
        req.data = {
            Fields.PRODUCT_ID: "prod_1",
            Fields.ORDER_ID: "order_1",
            Fields.RATING: 5,
            Fields.REVIEW_IMAGE_URLS: [f"{CDN_BASE_URL}/reviews/a.jpg"],
        }

        with patch("utils.premium_check.is_premium_authoritative", return_value=True):
            with pytest.raises(https_fn.HttpsError) as exc:
                submit_product_rating(req)
        assert exc.value.code == "not-found"


class TestProductImageAndAddressVerification:
    @patch("handlers.products.requests.get")
    def test_validate_image_magic_bytes_accepts_valid_signature(self, mock_get):
        from handlers.products import validate_image_magic_bytes

        from schema_constants import BusinessRules

        magic = next(iter(BusinessRules.IMAGE_MAGIC_BYTES))
        resp = Mock()
        resp.status_code = 200
        resp.raw.read.return_value = magic + b"abcdef"
        mock_get.return_value = resp

        assert validate_image_magic_bytes("https://cdn.example.com/img.jpg") is True
        resp.close.assert_called_once()

    @patch("handlers.products.requests.get")
    def test_validate_image_magic_bytes_rejects_non_200_and_bad_bytes(self, mock_get):
        from handlers.products import validate_image_magic_bytes

        bad_status = Mock()
        bad_status.status_code = 404
        mock_get.return_value = bad_status
        assert validate_image_magic_bytes("https://cdn.example.com/missing.jpg") is False

        bad_bytes = Mock()
        bad_bytes.status_code = 200
        bad_bytes.raw.read.return_value = b"not-image-bytes"
        mock_get.return_value = bad_bytes
        assert validate_image_magic_bytes("https://cdn.example.com/bad.jpg") is False

        empty_header = Mock()
        empty_header.status_code = 200
        empty_header.raw.read.return_value = b""
        mock_get.return_value = empty_header
        assert validate_image_magic_bytes("https://cdn.example.com/empty.jpg") is False

    @patch("handlers.products.requests.get", side_effect=RuntimeError("network timeout"))
    def test_validate_image_magic_bytes_fail_open_on_exception(self, _mock_get):
        from handlers.products import validate_image_magic_bytes

        assert validate_image_magic_bytes("https://cdn.example.com/flaky.jpg") is True

    @patch("handlers.products.get_geoapify_api_key", return_value="")
    def test_verify_address_with_geoapify_fails_when_service_not_configured(self, _mock_key):
        from handlers.products import _verify_address_with_geoapify

        ok, reason = _verify_address_with_geoapify("p1", 43.0, -79.0, "1 Queen", "Toronto", "M5H2N2", "CA")
        assert ok is False
        assert "not configured" in reason

    @patch("handlers.products.get_geoapify_api_key", return_value="geo_key")
    @patch("handlers.products.requests.get")
    def test_verify_address_with_geoapify_mismatch_and_success_paths(self, mock_get, _mock_key):
        from handlers.products import _verify_address_with_geoapify

        mismatch_resp = Mock()
        mismatch_resp.status_code = 200
        mismatch_resp.json.return_value = {
            "features": [{"properties": {"city": "Montreal", "postcode": "H1A1A1", "country_code": "ca"}}]
        }
        mock_get.return_value = mismatch_resp
        ok, reason = _verify_address_with_geoapify("p1", 43.0, -79.0, "1 Queen", "Toronto", "M5H2N2", "CA")
        assert ok is False
        assert "City mismatch" in reason

        success_resp = Mock()
        success_resp.status_code = 200
        success_resp.json.return_value = {
            "features": [{"properties": {"city": "Toronto", "postcode": "M5H 2N2", "country_code": "ca"}}]
        }
        mock_get.return_value = success_resp
        ok, reason = _verify_address_with_geoapify("p1", 43.0, -79.0, "1 Queen", "Toronto", "M5H2N2", "CA")
        assert ok is True
        assert reason == ""

    @patch("handlers.products.get_geoapify_api_key", return_value="geo_key")
    @patch("handlers.products.requests.get", side_effect=Exception("boom"))
    def test_verify_address_with_geoapify_handles_exceptions(self, _mock_get, _mock_key):
        from handlers.products import _verify_address_with_geoapify

        ok, reason = _verify_address_with_geoapify("p1", 43.0, -79.0, "1 Queen", "Toronto", "M5H2N2", "CA")
        assert ok is False
        assert "error" in reason.lower()

    @patch("utils.helpers.geocode_address", return_value=(True, "", {"lat": 43.0, "lon": -79.0}))
    def test_geocode_warehouse_address_returns_geocoded_value_on_success(self, _mock_geo):
        from handlers.products import _geocode_warehouse_address

        addr = {"street": "1 Queen"}
        out = _geocode_warehouse_address(addr)
        assert out["lat"] == 43.0

    @patch("utils.helpers.geocode_address", return_value=(False, "not found", {}))
    def test_geocode_warehouse_address_fails_open(self, _mock_geo):
        from handlers.products import _geocode_warehouse_address

        addr = {"street": "1 Queen"}
        out = _geocode_warehouse_address(addr)
        assert out == addr
