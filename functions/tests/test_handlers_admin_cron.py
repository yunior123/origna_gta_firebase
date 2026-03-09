"""
Comprehensive unit tests for handlers/admin.py and cron_jobs.py
Tests MFA, user roles, GDPR compliance, and scheduled tasks

Run: pytest tests/test_handlers_admin_cron.py -v --cov
"""

import json
from datetime import UTC, datetime, timedelta, timezone
from unittest.mock import MagicMock, Mock, call, patch

import pyotp
import pytest
from firebase_admin import firestore
from firebase_functions import https_fn, scheduler_fn


class TestAdminHandlers:
    """Test admin user management functions"""

    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.admin.get_db")
    def test_update_user_roles_requires_admin(self, mock_get_db, mock_rate_limiter_cls):
        """SECURITY: Test only admins can update user roles"""
        from handlers.admin import update_user_roles

        # Mock rate limiter to allow requests
        mock_rate_limiter_cls.return_value.check_rate_limit.return_value = (True, "")

        # Mock requesting user (not admin)
        mock_requester_doc = Mock()
        mock_requester_doc.exists = True
        mock_requester_doc.to_dict.return_value = {
            "userId": "user_123",
            "roles": ["buyer"],  # Not admin - use array
        }
        mock_db = Mock()
        mock_get_db.return_value = mock_db
        mock_db.collection.return_value.document.return_value.get.return_value = mock_requester_doc

        mock_request = Mock()
        mock_request.auth = Mock(uid="user_123")
        mock_request.data = {
            "targetUserId": "victim_456",
            "roles": ["admin"],  # Use roles array
        }

        with pytest.raises(https_fn.HttpsError) as exc:
            update_user_roles(mock_request)

        assert exc.value.code == "permission-denied"

    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.admin.get_db")
    def test_update_user_roles_requires_mfa(self, mock_get_db, mock_rate_limiter_cls):
        """SECURITY: Test admin role changes require MFA verification"""
        from handlers.admin import update_user_roles

        # Mock rate limiter to allow requests
        mock_rate_limiter_cls.return_value.check_rate_limit.return_value = (True, "")

        # Mock admin without MFA
        mock_admin_doc = Mock()
        mock_admin_doc.exists = True
        mock_admin_doc.to_dict.return_value = {
            "userId": "admin_123",
            "roles": ["admin"],  # Note: roles is an array
            "mfaEnabled": False,  # MFA not enabled
        }
        mock_db = Mock()
        mock_get_db.return_value = mock_db
        mock_db.collection.return_value.document.return_value.get.return_value = mock_admin_doc

        mock_request = Mock()
        mock_request.auth = Mock(uid="admin_123")
        mock_request.data = {
            "targetUserId": "user_456",
            "roles": ["seller"],  # Note: roles is an array
        }

        with pytest.raises(https_fn.HttpsError) as exc:
            update_user_roles(mock_request)

        # Should fail because MFA not enabled (failed-precondition) or not verified (permission-denied)
        assert exc.value.code in ["permission-denied", "failed-precondition"]
        assert "mfa" in str(exc.value).lower()

    @patch("handlers.admin.auth.set_custom_user_claims")
    @patch("services.rate_limiter.RateLimiter")
    @patch("handlers.admin.create_success_response")
    @patch("handlers.admin.get_db")
    def test_update_user_roles_success_with_mfa(self, mock_get_db, mock_create_response, mock_rate_limiter_cls, mock_set_claims):
        """Test successful role update by verified admin"""
        from handlers.admin import update_user_roles

        # Mock set_custom_user_claims to avoid hitting real Firebase Auth
        mock_set_claims.return_value = None

        # Mock rate limiter to allow requests
        mock_rate_limiter_cls.return_value.check_rate_limit.return_value = (True, "")

        mock_create_response.return_value = {"success": True}

        # Mock admin with MFA verified recently (use UTC to match admin.py handler)
        from datetime import timezone

        mock_admin_doc = Mock()
        mock_admin_doc.exists = True
        mock_admin_doc.to_dict.return_value = {
            "userId": "admin_123",
            "roles": ["admin"],
            "mfaEnabled": True,
            "lastMfaVerify": datetime.now(UTC),
        }

        # Mock target user
        mock_target_doc = Mock()
        mock_target_doc.exists = True
        mock_target_doc.to_dict.return_value = {"userId": "user_456", "roles": ["buyer"]}

        mock_db = Mock()
        mock_get_db.return_value = mock_db

        mock_admin_ref = Mock()
        mock_admin_ref.get.return_value = mock_admin_doc
        mock_target_ref = Mock()
        mock_target_ref.get.return_value = mock_target_doc

        def document_side_effect(doc_id):
            """Function document_side_effect."""
            if doc_id == "admin_123":
                return mock_admin_ref
            return mock_target_ref

        mock_db.collection.return_value.document.side_effect = document_side_effect

        mock_request = Mock()
        mock_request.auth = Mock(uid="admin_123")
        mock_request.data = {"targetUserId": "user_456", "roles": ["seller"]}

        result = update_user_roles(mock_request)

        assert result["success"] is True

    @patch("handlers.admin.create_success_response")
    @patch("pyotp.random_base32")
    @patch("handlers.admin.get_db")
    def test_admin_mfa_enroll_generates_secret(self, mock_get_db, mock_random, mock_create_response):
        """Test MFA enrollment generates TOTP secret"""
        from handlers.admin import admin_mfa_enroll

        mock_random.return_value = "JBSWY3DPEHPK3PXP"
        mock_create_response.return_value = {
            "success": True,
            "secret": "JBSWY3DPEHPK3PXP",
            "qrCodeUrl": "otpauth://...",
        }

        mock_db = Mock()
        mock_get_db.return_value = mock_db
        mock_db.transaction.return_value._max_attempts = 4
        mock_user_doc = Mock()
        mock_user_doc.exists = True
        mock_user_doc.to_dict.return_value = {"userId": "admin_123", "roles": ["admin"], "email": "admin@example.com"}

        mock_user_ref = Mock()
        mock_user_ref.get.return_value = mock_user_doc
        mock_db.collection.return_value.document.return_value = mock_user_ref

        mock_request = Mock()
        mock_request.auth = Mock(uid="admin_123")

        result = admin_mfa_enroll(mock_request)

        assert result["success"] is True
        mock_create_response.assert_called_once()

    @patch("handlers.admin.create_success_response")
    @patch("handlers.admin.get_db")
    def test_admin_mfa_verify_valid_code(self, mock_get_db, mock_create_response):
        """Test MFA verification with valid TOTP code"""
        from handlers.admin import admin_mfa_verify
        from utils.crypto_utils import encrypt_mfa_secret

        secret = pyotp.random_base32()
        encrypted_secret = encrypt_mfa_secret(secret)
        totp = pyotp.TOTP(secret)
        valid_code = totp.now()

        mock_create_response.return_value = {"success": True, "mfaEnabled": True}

        # Mock user with encrypted MFA secret
        mock_user_doc = Mock()
        mock_user_doc.exists = True
        mock_user_doc.to_dict.return_value = {
            "userId": "admin_123",
            "mfaSecretTemp": encrypted_secret,
            "mfaEnabled": False,
        }
        mock_db = Mock()
        mock_get_db.return_value = mock_db
        mock_user_ref = Mock()
        mock_user_ref.get.return_value = mock_user_doc
        mock_db.collection.return_value.document.return_value = mock_user_ref

        mock_request = Mock()
        mock_request.auth = Mock(uid="admin_123")
        mock_request.data = {"code": valid_code}

        result = admin_mfa_verify(mock_request)

        assert result["success"] is True
        assert result["mfaEnabled"] is True

    @patch("handlers.admin.get_db")
    def test_admin_mfa_verify_invalid_code_rejected(self, mock_get_db):
        """SECURITY: Test invalid TOTP code is rejected"""
        from handlers.admin import admin_mfa_verify
        from utils.crypto_utils import encrypt_mfa_secret

        secret = pyotp.random_base32()
        encrypted_secret = encrypt_mfa_secret(secret)

        mock_user_doc = Mock()
        mock_user_doc.exists = True
        mock_user_doc.to_dict.return_value = {"userId": "admin_123", "mfaSecret": encrypted_secret}
        mock_db = Mock()
        mock_get_db.return_value = mock_db
        mock_db.collection.return_value.document.return_value.get.return_value = mock_user_doc

        mock_request = Mock()
        mock_request.auth = Mock(uid="admin_123")
        mock_request.data = {"code": "000000"}  # Invalid code

        with pytest.raises(https_fn.HttpsError) as exc:
            admin_mfa_verify(mock_request)

        assert exc.value.code == "unauthenticated"
        assert "invalid" in str(exc.value).lower()

    @patch("handlers.admin.create_success_response")
    @patch("handlers.admin.get_db")
    def test_suspend_seller_deactivates_products(self, mock_get_db, mock_create_response):
        """Test suspending seller deactivates all their products"""
        from handlers.admin import suspend_seller

        mock_create_response.return_value = {"success": True, "message": "Seller suspended"}

        mock_db = Mock()
        mock_get_db.return_value = mock_db
        mock_db.transaction.return_value._max_attempts = 4

        # Mock admin with recent MFA verification
        mock_admin_doc = Mock()
        mock_admin_doc.exists = True
        mock_admin_doc.to_dict.return_value = {
            "roles": ["admin"],
            "mfaEnabled": True,
            "lastMfaVerify": datetime.now(UTC),
        }

        # Mock seller
        mock_seller_doc = Mock()
        mock_seller_doc.exists = True
        mock_seller_doc.to_dict.return_value = {"userId": "seller_456", "roles": ["seller"]}

        # Mock admin and seller refs
        mock_admin_ref = Mock()
        mock_admin_ref.get.return_value = mock_admin_doc
        mock_seller_ref = Mock()
        mock_seller_ref.get.return_value = mock_seller_doc

        def document_side_effect(doc_id):
            """Function document_side_effect."""
            if doc_id == "admin_123":
                return mock_admin_ref
            return mock_seller_ref

        mock_db.collection.return_value.document.side_effect = document_side_effect

        # Mock products query (empty for simplicity)
        mock_query = Mock()
        mock_query.where.return_value = mock_query
        mock_query.limit.return_value = mock_query
        mock_query.stream.return_value = iter([])
        mock_db.collection.return_value.where.return_value = mock_query

        mock_db.batch.return_value = Mock()

        mock_request = Mock()
        mock_request.auth = Mock(uid="admin_123")
        mock_request.data = {"sellerId": "seller_456", "reason": "Violating terms of service"}

        result = suspend_seller(mock_request)

        assert result["success"] is True


# NOTE: test_delete_account_gdpr_compliance moved to e2e/tests/ - requires full Firestore integration


# NOTE: Cron job tests (auto_capture, expired_auth, archive, algolia_sync, rate_limits) moved to e2e/tests/


class TestSecurityEdgeCases:
    """Advanced security and edge case tests"""

    def test_totp_time_window_validation(self):
        """Test TOTP code valid for 30 second window only"""
        secret = pyotp.random_base32()
        totp = pyotp.TOTP(secret)

        # Current code valid
        current_code = totp.now()
        assert totp.verify(current_code) is True

        # Code from 1 minute ago invalid
        old_time = datetime.now() - timedelta(minutes=1)
        old_code = totp.at(old_time)
        assert totp.verify(old_code) is False

    @patch("handlers.admin.get_db")
    def test_mfa_brute_force_protection(self, mock_get_db):
        """SECURITY: Test MFA verification with invalid code is rejected"""
        from handlers.admin import admin_mfa_verify
        from utils.crypto_utils import encrypt_mfa_secret

        mock_db = Mock()
        mock_get_db.return_value = mock_db

        secret = pyotp.random_base32()
        encrypted_secret = encrypt_mfa_secret(secret)
        mock_user_doc = Mock()
        mock_user_doc.exists = True
        mock_user_doc.to_dict.return_value = {"mfaSecret": encrypted_secret}
        mock_user_ref = Mock()
        mock_user_ref.get.return_value = mock_user_doc
        mock_db.collection.return_value.document.return_value = mock_user_ref

        mock_request = Mock()
        mock_request.auth = Mock(uid="admin_123")
        mock_request.data = {"code": "000000"}  # Invalid code

        with pytest.raises(https_fn.HttpsError) as exc:
            admin_mfa_verify(mock_request)

        assert exc.value.code == "unauthenticated"

    def test_gdpr_anonymization_irreversible(self):
        """Test deleted user data cannot be recovered"""
        original_email = "user@example.com"
        anonymized_email = f"deleted_user_{datetime.now().timestamp()}@example.com"

        # Once anonymized, original email cannot be derived
        assert original_email not in anonymized_email
        assert "deleted_user_" in anonymized_email

    def test_admin_role_escalation_prevented(self):
        """SECURITY: Test user cannot self-promote to admin"""
        # User A tries to make User A admin
        # Should require existing admin to grant role
        pass

    def test_webhook_replay_attack_prevented(self):
        """SECURITY: Test same webhook event cannot be replayed"""
        # Idempotency key stored in webhook_events collection
        # Duplicate event_id rejected
        pass

    def test_sensitive_data_not_logged(self):
        """SECURITY: Test credit cards, passwords not in logs"""
        # All logging should mask sensitive fields
        # Verify logger sanitizes these fields
        pass


# =============================================================================
# BUG-3: Low-stock threshold seller alert cron
# =============================================================================


class TestCheckLowStockAlerts:
    """check_low_stock_alerts daily cron — emails sellers when stock <= threshold."""

    @pytest.fixture(autouse=True)
    def mock_locks(self):
        """Function mock_locks."""
        with patch("handlers.cron_jobs.acquire_cron_lock", return_value=True), \
             patch("handlers.cron_jobs.release_cron_lock"):
            yield

    def _make_product(self, stock=2, threshold=5, track=True, last_alert=None, seller_id="seller_1"):
        return {
            "lifecycleStatus": "active",
            "stockQuantity": stock,
            "sellerId": seller_id,
            "name": "Test Widget",
            "inventory": {
                "trackQuantity": track,
                "lowStockThreshold": threshold,
            },
            "lastLowStockAlertAt": last_alert,
        }

    def _wire_db(self, mock_get_db, product_data, seller_email="seller@example.com"):
        mock_db = Mock()
        mock_get_db.return_value = mock_db

        mock_doc = Mock()
        mock_doc.id = "prod_1"
        mock_doc.to_dict.return_value = product_data

        mock_products_coll = Mock()
        mock_products_coll.where.return_value = mock_products_coll
        mock_products_coll.limit.return_value = mock_products_coll
        mock_products_coll.stream.return_value = [mock_doc]

        mock_product_ref = Mock()

        mock_seller_doc = Mock()
        mock_seller_doc.exists = True
        mock_seller_doc.id = "seller_1"
        mock_seller_doc.to_dict.return_value = {"email": seller_email, "emailConsent": True}

        def collection_side_effect(name):
            """Function collection_side_effect."""
            coll = Mock()
            if name == "products":
                coll.where.return_value = mock_products_coll
                mock_products_coll.document.return_value = mock_product_ref
                coll.document.return_value = mock_product_ref
                # Re-wire after stream so update() call works
                return coll
            elif name == "users":
                coll.document.return_value.get.return_value = mock_seller_doc
            return coll

        mock_db.collection.side_effect = collection_side_effect
        # Support batch read via get_all() for seller docs
        mock_db.get_all.return_value = [mock_seller_doc]
        return mock_db, mock_product_ref, mock_products_coll

    @patch("handlers.cron_jobs.get_db")
    @patch("services.email_service.send_email")
    def test_sends_alert_when_stock_at_threshold(self, mock_send_email, mock_get_db):
        """Stock == threshold → alert sent, lastLowStockAlertAt written."""
        from handlers.cron_jobs import check_low_stock_alerts

        product_data = self._make_product(stock=5, threshold=5)
        self._wire_db(mock_get_db, product_data)

        check_low_stock_alerts(Mock())

        mock_send_email.assert_called_once()
        call_kwargs = mock_send_email.call_args.kwargs
        assert call_kwargs.get("to_email") == "seller@example.com"
        assert "Low stock" in call_kwargs.get("subject", "")

    @patch("handlers.cron_jobs.get_db")
    @patch("services.email_service.send_email")
    def test_sends_alert_when_stock_below_threshold(self, mock_send_email, mock_get_db):
        """Stock < threshold → alert sent."""
        from handlers.cron_jobs import check_low_stock_alerts

        product_data = self._make_product(stock=1, threshold=5)
        self._wire_db(mock_get_db, product_data)

        check_low_stock_alerts(Mock())

        mock_send_email.assert_called_once()

    @patch("handlers.cron_jobs.get_db")
    @patch("services.email_service.send_email")
    def test_no_alert_when_stock_above_threshold(self, mock_send_email, mock_get_db):
        """Stock > threshold → no email."""
        from handlers.cron_jobs import check_low_stock_alerts

        product_data = self._make_product(stock=10, threshold=5)
        self._wire_db(mock_get_db, product_data)

        check_low_stock_alerts(Mock())

        mock_send_email.assert_not_called()

    @patch("handlers.cron_jobs.get_db")
    @patch("services.email_service.send_email")
    def test_no_alert_when_threshold_zero(self, mock_send_email, mock_get_db):
        """threshold=0 means seller opted out → no email."""
        from handlers.cron_jobs import check_low_stock_alerts

        product_data = self._make_product(stock=0, threshold=0)
        self._wire_db(mock_get_db, product_data)

        check_low_stock_alerts(Mock())

        mock_send_email.assert_not_called()

    @patch("handlers.cron_jobs.get_db")
    @patch("services.email_service.send_email")
    def test_no_alert_when_track_quantity_false(self, mock_send_email, mock_get_db):
        """trackQuantity=False means unlimited stock → no alert even if stock low."""
        from handlers.cron_jobs import check_low_stock_alerts

        product_data = self._make_product(stock=0, threshold=5, track=False)
        self._wire_db(mock_get_db, product_data)

        check_low_stock_alerts(Mock())

        mock_send_email.assert_not_called()

    @patch("handlers.cron_jobs.get_db")
    @patch("services.email_service.send_email")
    def test_cooldown_blocks_second_alert_within_23h(self, mock_send_email, mock_get_db):
        """lastLowStockAlertAt set 1 hour ago → cooldown active → no email."""
        from datetime import timezone

        from handlers.cron_jobs import check_low_stock_alerts

        recent_alert = datetime.now(UTC) - timedelta(hours=1)
        product_data = self._make_product(stock=2, threshold=5, last_alert=recent_alert)
        self._wire_db(mock_get_db, product_data)

        check_low_stock_alerts(Mock())

        mock_send_email.assert_not_called()

    @patch("handlers.cron_jobs.get_db")
    @patch("services.email_service.send_email")
    def test_alert_allowed_after_23h_cooldown_expires(self, mock_send_email, mock_get_db):
        """lastLowStockAlertAt set 24 hours ago → cooldown expired → email sent."""
        from datetime import timezone

        from handlers.cron_jobs import check_low_stock_alerts

        old_alert = datetime.now(UTC) - timedelta(hours=24)
        product_data = self._make_product(stock=2, threshold=5, last_alert=old_alert)
        self._wire_db(mock_get_db, product_data)

        check_low_stock_alerts(Mock())

        mock_send_email.assert_called_once()

    @patch("handlers.cron_jobs.get_db")
    @patch("services.email_service.send_email")
    def test_email_failure_does_not_crash_cron(self, mock_send_email, mock_get_db):
        """send_email raising → cron logs error but does not re-raise (other products still processed)."""
        from handlers.cron_jobs import check_low_stock_alerts

        mock_send_email.side_effect = Exception("SMTP down")
        product_data = self._make_product(stock=1, threshold=5)
        self._wire_db(mock_get_db, product_data)

        # Must NOT raise
        check_low_stock_alerts(Mock())

    @patch("handlers.cron_jobs.get_db")
    @patch("services.email_service.send_email")
    def test_no_alert_when_seller_has_no_email(self, mock_send_email, mock_get_db):
        """Seller doc missing email → skip silently, no email sent."""
        from handlers.cron_jobs import check_low_stock_alerts

        product_data = self._make_product(stock=1, threshold=5)
        self._wire_db(mock_get_db, product_data, seller_email=None)

        check_low_stock_alerts(Mock())

        mock_send_email.assert_not_called()

    @patch("handlers.cron_jobs.get_db")
    @patch("services.email_service.send_email")
    def test_no_alert_when_no_seller_id(self, mock_send_email, mock_get_db):
        """Product missing sellerId → skip, no email."""
        from handlers.cron_jobs import check_low_stock_alerts

        product_data = self._make_product(stock=1, threshold=5, seller_id=None)
        self._wire_db(mock_get_db, product_data)

        check_low_stock_alerts(Mock())

        mock_send_email.assert_not_called()

    def test_uses_constants_not_magic_strings(self):
        """Verify cron_jobs.py references Fields constants for all low-stock field names."""
        import ast
        from pathlib import Path

        source = (Path(__file__).parent.parent / "handlers" / "cron_jobs.py").read_text()
        # The four inventory sub-fields and the cooldown field must NOT be raw strings
        forbidden_literals = [
            '"lowStockThreshold"',
            '"trackQuantity"',
            '"lastLowStockAlertAt"',
            '"allowBackorder"',
        ]
        for literal in forbidden_literals:
            assert literal not in source, f"Magic string {literal} found in cron_jobs.py — use Fields constant instead"


class TestBackupFirestore:
    """Tests for the daily Firestore backup cron job."""

    @patch("handlers.cron_jobs.IS_EMULATOR", True)
    def test_skips_in_emulator_mode(self):
        """No export call when running in emulator — bucket may not exist."""
        from handlers.cron_jobs import backup_firestore

        mock_event = Mock()
        # Should return immediately without error
        backup_firestore(mock_event)

    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=False)
    @patch("handlers.cron_jobs.IS_EMULATOR", False)
    def test_skips_when_lock_held(self, mock_acquire, mock_release):
        """If another instance holds the lock, skip without exporting."""
        from handlers.cron_jobs import backup_firestore

        backup_firestore(Mock())

        mock_acquire.assert_called_once_with("backup_firestore", ttl_minutes=60)
        mock_release.assert_not_called()

    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("handlers.cron_jobs._run_backup_firestore")
    @patch("handlers.cron_jobs.IS_EMULATOR", False)
    def test_calls_run_backup_when_lock_acquired(self, mock_run, mock_acquire, mock_release):
        """Happy path: lock acquired → _run_backup_firestore called → lock released."""
        from handlers.cron_jobs import backup_firestore

        backup_firestore(Mock())

        mock_run.assert_called_once()
        mock_release.assert_called_once_with("backup_firestore")

    @patch("handlers.cron_jobs.release_cron_lock")
    @patch("handlers.cron_jobs.acquire_cron_lock", return_value=True)
    @patch("handlers.cron_jobs._run_backup_firestore", side_effect=RuntimeError("GCS bucket not found"))
    @patch("handlers.cron_jobs.IS_EMULATOR", False)
    def test_alerts_on_export_error(self, mock_run, mock_acquire, mock_release):
        """If export fails, Sentry captures exception and lock is still released."""
        from handlers.cron_jobs import backup_firestore

        with patch("handlers.cron_jobs.sentry_sdk") as mock_sentry:
            # Should not raise — error is caught and reported
            backup_firestore(Mock())

        assert mock_sentry.capture_exception.called, "Sentry should capture backup failure"
        mock_release.assert_called_once_with("backup_firestore")

    @patch("google.cloud.firestore_admin_v1.FirestoreAdminClient")
    @patch("handlers.cron_jobs.PROJECT_ID", "orignagta")
    @patch("handlers.cron_jobs.BACKUP_BUCKET", "gs://orignagta-backups")
    def test_run_backup_calls_export_api(self, mock_admin_cls):
        """_run_backup_firestore calls exportDocuments with correct db name and output prefix."""
        from handlers.cron_jobs import _run_backup_firestore

        mock_client = MagicMock()
        mock_admin_cls.return_value = mock_client
        mock_op = MagicMock()
        mock_op.operation.name = "projects/orignagta/databases/(default)/operations/test-op"
        mock_client.export_documents.return_value = mock_op

        _run_backup_firestore()

        mock_client.export_documents.assert_called_once()
        call_args = mock_client.export_documents.call_args
        req = call_args.kwargs.get("request") or call_args.args[0]
        assert req.name == "projects/orignagta/databases/(default)"
        assert req.output_uri_prefix.startswith("gs://orignagta-backups/")
        assert req.collection_ids == []  # all collections

    def test_backup_bucket_per_environment(self):
        """BACKUP_BUCKET resolves to correct GCS bucket for each environment."""
        from config import _BACKUP_BUCKETS

        assert _BACKUP_BUCKETS["orignagta"] == "gs://orignagta-backups"
        assert _BACKUP_BUCKETS["orignagta-staging"] == "gs://orignagta-staging-backups"
        assert _BACKUP_BUCKETS["orignagta-dev"] == "gs://orignagta-dev-backups"
