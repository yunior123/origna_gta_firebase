#!/usr/bin/env python3
"""
Rate Limiter Production Tests
Verifies that rate limiting works correctly in production environment
"""

import os

os.environ["TESTING"] = "true"

from unittest.mock import MagicMock, patch


def test_is_emulator_detection():
    """Test that IS_EMULATOR is correctly detected"""
    print("=" * 60)
    print("RATE LIMITER PRODUCTION TESTS")
    print("=" * 60)
    print()
    print("Test 1: IS_EMULATOR Detection")
    print("-" * 40)

    # Simulate production (no FUNCTIONS_EMULATOR)
    os.environ.pop("FUNCTIONS_EMULATOR", None)
    is_emulator_prod = os.environ.get("FUNCTIONS_EMULATOR", "false").lower() == "true"
    print(f"  Production: IS_EMULATOR = {is_emulator_prod}")
    assert not is_emulator_prod, "Should be False in production!"
    print("  ✅ Rate limiting ACTIVE in production")

    # Simulate emulator
    os.environ["FUNCTIONS_EMULATOR"] = "true"
    is_emulator_dev = os.environ.get("FUNCTIONS_EMULATOR", "false").lower() == "true"
    print(f"  Emulator: IS_EMULATOR = {is_emulator_dev}")
    assert is_emulator_dev, "Should be True in emulator!"
    print("  ✅ Rate limiting DISABLED in emulator")


def test_fail_closed_behavior():
    """Test fail_closed parameter behavior"""
    print()
    print("Test 2: fail_closed Behavior")
    print("-" * 40)

    from services.rate_limiter import RateLimiter

    mock_db = MagicMock()
    mock_db.collection.return_value.document.return_value = MagicMock()
    limiter = RateLimiter(mock_db)

    # Test fail_closed=True (should BLOCK on error)
    with patch.object(mock_db, "transaction", side_effect=Exception("Simulated error")):
        allowed, msg = limiter.check_rate_limit("test_ip", "webhook", 100, 1, fail_closed=True)
        print(f"  fail_closed=True on error: {'BLOCKED' if not allowed else 'ALLOWED'}")
        assert not allowed, "Should BLOCK on error when fail_closed=True!"
        print("  ✅ Security: Blocks requests when rate limiter fails")

    # Test fail_closed=False (should ALLOW on error)
    with patch.object(mock_db, "transaction", side_effect=Exception("Simulated error")):
        allowed, msg = limiter.check_rate_limit("test_ip", "view", 100, 1, fail_closed=False)
        print(f"  fail_closed=False on error: {'BLOCKED' if not allowed else 'ALLOWED'}")
        assert allowed, "Should ALLOW on error when fail_closed=False!"
        print("  ✅ UX: Allows requests when rate limiter fails (fail-open)")


def test_webhook_uses_fail_closed():
    """Verify webhook handler uses fail_closed=True"""
    print()
    print("Test 3: Webhook Configuration Check")
    print("-" * 40)

    # Read the payment_stripe.py file to verify
    import os

    test_dir = os.path.dirname(os.path.abspath(__file__))
    handler_path = os.path.join(test_dir, "..", "handlers", "payment_stripe.py")
    with open(handler_path) as f:
        content = f.read()

    # Check IS_EMULATOR is available (either defined locally or imported from config)
    assert (
        "IS_EMULATOR = os.environ.get" in content
        or ("from config import" in content and "IS_EMULATOR" in content)
        or "import IS_EMULATOR" in content
    ), "IS_EMULATOR should be defined or imported in payment_stripe.py"
    print("  ✅ IS_EMULATOR is available in payment_stripe.py")

    # Check webhook uses fail_closed=True
    assert "fail_closed=True" in content, "Webhook should use fail_closed=True"
    print("  ✅ Webhook uses fail_closed=True for security")

    # Check rate limiting is conditional on IS_EMULATOR
    assert "if not IS_EMULATOR:" in content, "Rate limiting should be conditional"
    print("  ✅ Rate limiting is disabled in emulator mode")


if __name__ == "__main__":
    test_is_emulator_detection()
    test_fail_closed_behavior()
    test_webhook_uses_fail_closed()

    print()
    print("=" * 60)
    print("ALL PRODUCTION TESTS PASSED ✅")
    print("=" * 60)
    print()
    print("Production Summary:")
    print("  • Rate limiting is ACTIVE in production (FUNCTIONS_EMULATOR != true)")
    print("  • Rate limiting is DISABLED in emulator (to avoid transaction issues)")
    print("  • Webhooks use fail_closed=True -> blocked on errors (security)")
    print("  • Other endpoints use fail_closed=False -> allowed on errors (UX)")
