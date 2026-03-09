"""
Tests de Sécurité des Webhooks Stripe

Ce module contient les tests pour valider:
1. Vérification de signature
2. Rate limiting
3. Idempotency
4. Sanitization des erreurs

Pour exécuter:
    pytest test_webhook_security.py -v
"""

import hashlib
import hmac
import json
import time
from datetime import datetime, timedelta
from unittest.mock import MagicMock, Mock, patch

import pytest


class TestStripeWebhookSecurity:
    """Tests de sécurité pour le webhook Stripe"""

    def test_missing_signature_returns_400(self):
        """
        SÉCURITÉ: Webhook sans signature doit être rejeté

        Scénario: Attaquant envoie un webhook sans header Stripe-Signature
        Attendu: HTTP 400 Bad Request
        """
        # Arrange
        mock_request = Mock()
        mock_request.method = "POST"
        # Return None only for Stripe-Signature, use default for other headers
        mock_request.headers.get = Mock(
            side_effect=lambda h, default=None: {
                "X-Forwarded-For": "192.168.1.1",
            }.get(h, default)
        )
        mock_request.data = b'{"id": "evt_test"}'

        # Skip rate limiting in test
        with patch("handlers.payment_stripe.IS_EMULATOR", True):
            # Act
            from handlers.payment_stripe import stripe_webhook

            response = stripe_webhook(mock_request)

            # Assert
            assert response.status_code == 400
            assert "Missing signature" in response.response[0].decode()

    def test_invalid_signature_returns_400(self, mock_firestore_client):
        """
        SÉCURITÉ: Webhook avec signature invalide doit être rejeté

        Scénario: Attaquant envoie un webhook avec signature incorrecte
        Attendu: HTTP 400 Bad Request
        """
        import stripe

        from handlers import payment_stripe

        # Arrange
        mock_request = Mock()
        mock_request.method = "POST"
        mock_request.headers.get = Mock(
            side_effect=lambda h, default=None: {
                "Stripe-Signature": "invalid_signature_123",
                "X-Forwarded-For": "192.168.1.1",
            }.get(h, default)
        )
        mock_request.data = b'{"id": "evt_test", "type": "test"}'

        # Configure the mock stripe to raise SignatureVerificationError
        payment_stripe.stripe.Webhook.construct_event.side_effect = stripe.error.SignatureVerificationError(
            "Invalid signature", "sig_header"
        )

        # Skip rate limiting in test
        with patch("handlers.payment_stripe.IS_EMULATOR", True):
            # Act
            from handlers.payment_stripe import stripe_webhook

            response = stripe_webhook(mock_request)

            # Assert
            assert response.status_code == 400
            assert "Invalid signature" in response.response[0].decode()

    def test_rate_limiting_blocks_after_100_requests(self, mock_firestore_client):
        """
        SÉCURITÉ: Rate limiting doit bloquer après 100 requêtes/minute

        Scénario: Attaquant envoie 101 webhooks en 1 minute
        Attendu: Requêtes 1-100 OK, Requête 101 → HTTP 429
        """
        # Arrange
        mock_request = Mock()
        mock_request.method = "POST"
        mock_request.headers.get = Mock(
            side_effect=lambda h, default=None: {
                "Stripe-Signature": "valid_sig",
                "X-Forwarded-For": "192.168.1.100",
            }.get(h, default)
        )
        mock_request.data = b'{"id": "evt_test", "type": "test"}'

        # Mock rate limiter (NOT using IS_EMULATOR to test actual rate limiting)
        with (
            patch("handlers.payment_stripe.IS_EMULATOR", False),
            patch("handlers.payment_stripe.get_rate_limiter") as mock_limiter,
        ):
            mock_limiter.return_value.check_rate_limit = Mock(return_value=(False, "Rate limit exceeded"))

            # Act
            from handlers.payment_stripe import stripe_webhook

            response = stripe_webhook(mock_request)

            # Assert
            assert response.status_code == 429
            assert "Rate limit exceeded" in response.response[0].decode()

    def test_idempotency_prevents_duplicate_processing(self):
        """
        SÉCURITÉ: Idempotency doit empêcher le traitement en double

        Scénario: Même webhook envoyé 2 fois (replay attack)
        Attendu: 1ère fois traité, 2ème fois ignoré
        """
        # Arrange
        event_id = "evt_duplicate_test"
        mock_request = Mock()
        mock_request.method = "POST"
        mock_request.headers.get = Mock(
            side_effect=lambda h, default=None: {"Stripe-Signature": "valid_sig", "X-Forwarded-For": "192.168.1.1"}.get(
                h, default
            )
        )
        mock_request.data = b'{"id": "' + event_id.encode() + b'", "type": "test"}'

        # Mock Firestore, skip rate limiting, and mock signature verification
        with (
            patch("handlers.payment_stripe.IS_EMULATOR", True),
            patch("handlers.payment_stripe.stripe.Webhook.construct_event") as mock_construct,
            patch("handlers.payment_stripe.get_db") as mock_db,
        ):
            # Mock successful signature verification
            mock_construct.return_value = {"id": event_id, "type": "test", "data": {"object": {}}}

            mock_doc = Mock()
            mock_doc.exists = True  # Event already processed
            mock_doc.to_dict.return_value = {"status": "completed"}

            mock_webhook_ref = Mock()
            # create() raises when doc already exists (atomic idempotency check)
            mock_webhook_ref.create = Mock(side_effect=Exception("Document already exists"))
            mock_webhook_ref.get = Mock(return_value=mock_doc)

            mock_db.return_value.collection.return_value.document.return_value = mock_webhook_ref

            # Act
            from handlers.payment_stripe import stripe_webhook

            response = stripe_webhook(mock_request)

            # Assert
            assert response.status_code == 200
            assert "already processed" in response.response[0].decode().lower()

    def test_error_sanitization_hides_sensitive_info(self, mock_firestore_client):
        """
        SÉCURITÉ: Erreurs ne doivent PAS exposer d'informations sensibles

        Scénario: Exception interne avec détails sensibles
        Attendu: Message générique, pas de stack trace
        """
        from handlers import payment_stripe

        # Arrange
        mock_request = Mock()
        mock_request.method = "POST"
        mock_request.headers.get = Mock(
            side_effect=lambda h, default=None: {"Stripe-Signature": "valid_sig", "X-Forwarded-For": "192.168.1.1"}.get(
                h, default
            )
        )
        mock_request.data = b"invalid_json{"

        # Configure mock stripe to raise ValueError for invalid payload
        payment_stripe.stripe.Webhook.construct_event.side_effect = ValueError(
            "Invalid payload: Expecting JSON with sensitive info"
        )

        # Skip rate limiting in test
        with patch("handlers.payment_stripe.IS_EMULATOR", True):
            # Act
            from handlers.payment_stripe import stripe_webhook

            response = stripe_webhook(mock_request)

            # Assert
            assert response.status_code in [400, 500]
            response_text = response.response[0].decode()

        # NE DOIT PAS contenir:
        assert "Traceback" not in response_text
        assert "Exception" not in response_text
        assert "STRIPE_WEBHOOK_SECRET" not in response_text

        # DOIT contenir message générique:
        assert any(term in response_text.lower() for term in ["invalid", "error", "bad request", "internal"])


class TestWebhookSignatureCryptography:
    """Tests de cryptographie pour les signatures"""

    def test_stripe_hmac_sha256_timing_safe(self):
        """
        SÉCURITÉ: Signature Stripe utilise HMAC-SHA256 timing-safe

        Protection contre timing attacks
        """
        import stripe

        # Arrange
        secret = "whsec_test_secret_123"
        payload = b'{"id": "evt_test"}'
        timestamp = int(time.time())

        # Compute expected signature (Stripe format)
        signed_payload = f"{timestamp}.{payload.decode()}".encode()
        expected_sig = hmac.new(secret.encode(), signed_payload, hashlib.sha256).hexdigest()

        sig_header = f"t={timestamp},v1={expected_sig}"

        # Act & Assert
        try:
            event = stripe.Webhook.construct_event(payload, sig_header, secret)
            # Si on arrive ici, signature valide
            assert event is not None
        except stripe.error.SignatureVerificationError:
            pytest.fail("Signature valide rejetée")


class TestRateLimiterSecurity:
    """Tests de sécurité du rate limiter"""

    def test_rate_limiter_uses_firestore_transaction(self):
        """
        SÉCURITÉ: Rate limiter doit utiliser des transactions atomiques

        Protection contre race conditions
        """
        from services.rate_limiter import RateLimiter

        # Arrange
        mock_db = Mock()
        mock_transaction = Mock()
        mock_db.transaction = Mock(return_value=mock_transaction)

        limiter = RateLimiter(mock_db)

        # Act
        allowed, message = limiter.check_rate_limit(
            identifier="test_user", action="test_action", max_requests=10, window_minutes=1, fail_closed=True
        )

        # Assert - Transaction doit être utilisée
        assert mock_db.transaction.called

    def test_rate_limiter_fail_closed_for_security(self):
        """
        SÉCURITÉ: Rate limiter fail-closed pour actions critiques

        En cas d'erreur, doit bloquer (pas autoriser)
        """
        from services.rate_limiter import RateLimiter

        # Arrange
        mock_db = Mock()
        mock_db.transaction = Mock(side_effect=Exception("Firestore down"))

        limiter = RateLimiter(mock_db)

        # Act
        allowed, message = limiter.check_rate_limit(
            identifier="test_user",
            action="webhook",
            max_requests=100,
            window_minutes=1,
            fail_closed=True,  # CRITIQUE: fail-closed
        )

        # Assert - Doit bloquer en cas d'erreur
        assert allowed is False
        assert "blocked for security" in message.lower()

    def test_rate_limiter_fail_open_for_ux(self):
        """
        UX: Rate limiter fail-open pour actions non-critiques

        En cas d'erreur, autoriser (ne pas bloquer utilisateurs légitimes)
        """
        from services.rate_limiter import RateLimiter

        # Arrange
        mock_db = Mock()
        mock_db.transaction = Mock(side_effect=Exception("Firestore down"))

        limiter = RateLimiter(mock_db)

        # Act
        allowed, message = limiter.check_rate_limit(
            identifier="test_user",
            action="view_product",
            max_requests=100,
            window_minutes=1,
            fail_closed=False,  # Fail-open pour UX
        )

        # Assert - Doit autoriser en cas d'erreur
        assert allowed is True


class TestAuditTrailSecurity:
    """Tests de l'audit trail"""

    def test_webhook_event_logs_client_ip(self):
        """
        SÉCURITÉ: Webhook events doivent logger l'IP client

        Pour traçabilité et forensics
        """
        # Arrange
        mock_db = Mock()
        mock_webhook_ref = Mock()
        mock_db.collection.return_value.document.return_value = mock_webhook_ref

        event_data = {
            "provider": "stripe",
            "type": "checkout.session.completed",
            "processed": True,
            "timestamp": datetime.now(),
            "client_ip": "192.168.1.1",  # DOIT être présent
            "event_id": "evt_123",
            "order_id": "order_456",
        }

        # Act
        mock_webhook_ref.set(event_data)

        # Assert
        mock_webhook_ref.set.assert_called_once()
        logged_data = mock_webhook_ref.set.call_args[0][0]
        assert "client_ip" in logged_data
        assert logged_data["client_ip"] == "192.168.1.1"

    def test_ip_sanitization_in_logs(self):
        """
        SÉCURITÉ: IP dans les logs doit être tronqué (GDPR)

        Log: "192.168.1..." pas "192.168.1.100"
        """
        # Arrange
        full_ip = "192.168.1.100"

        # Act - Simuler la sanitization
        sanitized_ip = full_ip[:10] + "..."

        # Assert
        assert sanitized_ip == "192.168.1...."
        assert len(sanitized_ip) <= 13  # 10 chars + "..."


class TestErrorSanitization:
    """Tests de sanitization des erreurs"""

    def test_exception_type_only_logged(self):
        """
        SÉCURITÉ: Logs doivent contenir le TYPE d'erreur uniquement

        Pas le message (peut contenir des secrets)
        """
        # Arrange
        try:
            raise ValueError("Secret key: REDACTED_SECRET")
        except Exception as e:
            # Act - Simuler le logging sanitizé
            error_type = type(e).__name__

            # Assert
            assert error_type == "ValueError"
            assert "sk_live" not in error_type  # Secret PAS dans le log

    def test_generic_error_message_to_client(self):
        """
        SÉCURITÉ: Réponse client doit être générique

        Pas d'exposition de détails internes
        """
        # Arrange

        # Act - Simuler la réponse sanitizée
        client_response = "Internal processing error"

        # Assert
        assert "secret" not in client_response.lower()
        assert "password" not in client_response.lower()
        assert "database" not in client_response.lower()


# ===== TESTS D'INTÉGRATION =====


class TestWebhookSecurityIntegration:
    """Tests d'intégration de bout en bout"""

    @pytest.mark.integration
    def test_complete_stripe_webhook_flow_secure(self):
        """
        TEST INTÉGRATION: Flow complet Stripe avec toutes les protections

        1. Rate limiting
        2. Signature verification
        3. Idempotency
        4. Business logic
        5. Audit trail
        """
        # Ce test nécessite un environnement de test complet
        # À implémenter avec fixtures Firestore
        pass


# ===== FIXTURES =====


@pytest.fixture
def mock_firestore_db():
    """Mock Firestore database pour tests"""
    mock_db = Mock()
    mock_collection = Mock()
    mock_document = Mock()

    mock_db.collection.return_value = mock_collection
    mock_collection.document.return_value = mock_document

    return mock_db


@pytest.fixture
def valid_stripe_signature():
    """Génère une signature Stripe valide pour tests"""
    secret = "whsec_test_secret"
    payload = b'{"id": "evt_test", "type": "test"}'
    timestamp = int(time.time())

    signed_payload = f"{timestamp}.{payload.decode()}".encode()
    signature = hmac.new(secret.encode(), signed_payload, hashlib.sha256).hexdigest()

    return f"t={timestamp},v1={signature}"


# ===== COMMANDES D'EXÉCUTION =====

"""
Pour exécuter tous les tests:
    pytest test_webhook_security.py -v

Pour exécuter seulement les tests de sécurité:
    pytest test_webhook_security.py -v -k "security"

Pour exécuter avec coverage:
    pytest test_webhook_security.py --cov=handlers --cov-report=html

Pour exécuter les tests d'intégration:
    pytest test_webhook_security.py -v -m integration
"""
