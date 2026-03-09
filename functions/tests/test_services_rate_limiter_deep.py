from datetime import UTC, datetime, timedelta
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from schema_constants import Fields
from services.rate_limiter import RateLimiter


def _build_limiter_with_doc(doc_snapshot):
    db = MagicMock()
    tx = MagicMock()
    ref = MagicMock()
    ref.get.return_value = doc_snapshot
    db.collection.return_value.document.return_value = ref
    db.transaction.return_value = tx
    return RateLimiter(db), db, tx, ref


class TestRateLimiterCheckRateLimit:
    def test_first_seen_request_creates_rate_limit_document(self):
        doc = MagicMock()
        doc.exists = False
        limiter, _db, tx, _ref = _build_limiter_with_doc(doc)

        with patch("services.rate_limiter._EMULATOR_RATE_MULTIPLIER", 1):
            allowed, message = limiter.check_rate_limit("ip_1.2.3.4", "checkout", 5, 10)

        assert allowed is True
        assert message == "OK"
        tx.set.assert_called_once()
        tx.update.assert_not_called()

    def test_existing_doc_without_first_request_resets_window(self):
        doc = MagicMock()
        doc.exists = True
        doc.to_dict.return_value = {Fields.COUNT: 8}
        limiter, _db, tx, _ref = _build_limiter_with_doc(doc)

        with patch("services.rate_limiter._EMULATOR_RATE_MULTIPLIER", 1):
            allowed, message = limiter.check_rate_limit("user_1", "create_order", 5, 10)

        assert allowed is True
        assert message == "OK"
        tx.set.assert_called_once()
        tx.update.assert_not_called()

    def test_expired_window_with_naive_timestamp_resets(self):
        doc = MagicMock()
        doc.exists = True
        doc.to_dict.return_value = {
            Fields.COUNT: 2,
            Fields.FIRST_REQUEST: datetime.now() - timedelta(minutes=20),  # naive + expired
        }
        limiter, _db, tx, _ref = _build_limiter_with_doc(doc)

        with patch("services.rate_limiter._EMULATOR_RATE_MULTIPLIER", 1):
            allowed, message = limiter.check_rate_limit("user_1", "create_order", 5, 5)

        assert allowed is True
        assert message == "OK"
        tx.set.assert_called_once()
        tx.update.assert_not_called()

    def test_limit_exceeded_within_window_blocks(self):
        doc = MagicMock()
        doc.exists = True
        doc.to_dict.return_value = {
            Fields.COUNT: 3,
            Fields.FIRST_REQUEST: datetime.now(UTC),
        }
        limiter, _db, tx, _ref = _build_limiter_with_doc(doc)

        with patch("services.rate_limiter._EMULATOR_RATE_MULTIPLIER", 1):
            allowed, message = limiter.check_rate_limit("user_1", "webhook", 3, 10)

        assert allowed is False
        assert "Rate limit exceeded: 3 requests per 10 minutes" in message
        tx.update.assert_not_called()

    def test_under_limit_within_window_increments_counter(self):
        doc = MagicMock()
        doc.exists = True
        doc.to_dict.return_value = {
            Fields.COUNT: 2,
            Fields.FIRST_REQUEST: datetime.now(UTC),
        }
        limiter, _db, tx, ref = _build_limiter_with_doc(doc)

        with patch("services.rate_limiter._EMULATOR_RATE_MULTIPLIER", 1):
            allowed, message = limiter.check_rate_limit("user_1", "webhook", 5, 10)

        assert allowed is True
        assert message == "OK"
        tx.update.assert_called_once()
        update_args = tx.update.call_args.args
        assert update_args[0] is ref
        assert update_args[1][Fields.COUNT] == 3

    def test_contention_error_fail_open_for_non_critical_paths(self):
        db = MagicMock()
        db.transaction.side_effect = RuntimeError("ABORTED: too much contention")
        limiter = RateLimiter(db)

        with patch("services.rate_limiter._EMULATOR_RATE_MULTIPLIER", 1):
            allowed, message = limiter.check_rate_limit("ip_x", "browse", 5, 10, fail_closed=False)

        assert allowed is True
        assert message == "OK"

    def test_contention_error_fail_closed_for_security_paths(self):
        db = MagicMock()
        db.transaction.side_effect = RuntimeError("concurrent modification detected")
        limiter = RateLimiter(db)

        with patch("services.rate_limiter._EMULATOR_RATE_MULTIPLIER", 1):
            allowed, message = limiter.check_rate_limit("ip_x", "payment", 5, 10, fail_closed=True)

        assert allowed is False
        assert "request blocked for security" in message


class TestRateLimiterGetIdentifier:
    def test_uses_uid_and_fingerprint_when_available(self):
        limiter = RateLimiter(MagicMock())
        req = SimpleNamespace(
            auth=SimpleNamespace(
                uid="user_123",
                token={"fingerprint": "0123456789abcdefEXTRA"},
            )
        )

        identifier = limiter.get_identifier(req)
        assert identifier == "user_user_123_0123456789abcdef"

    def test_uses_uid_when_no_fingerprint_or_device_id(self):
        limiter = RateLimiter(MagicMock())
        req = SimpleNamespace(auth=SimpleNamespace(uid="user_123", token={}))

        assert limiter.get_identifier(req) == "user_user_123"

    def test_prefers_last_x_forwarded_for_ip(self):
        limiter = RateLimiter(MagicMock())
        req = SimpleNamespace(headers={"X-Forwarded-For": "1.1.1.1, 2.2.2.2, 3.3.3.3"})

        assert limiter.get_identifier(req) == "ip_3.3.3.3"

    def test_falls_back_to_x_real_ip(self):
        limiter = RateLimiter(MagicMock())
        req = SimpleNamespace(headers={"X-Real-IP": "10.0.0.8"})

        assert limiter.get_identifier(req) == "ip_10.0.0.8"

    def test_returns_unknown_without_auth_or_headers(self):
        limiter = RateLimiter(MagicMock())
        req = SimpleNamespace()

        assert limiter.get_identifier(req) == "unknown"
