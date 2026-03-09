import base64
import sys
from types import SimpleNamespace
from unittest.mock import patch

import pytest

from utils import crypto_utils as crypto


VALID_KEY_B64 = base64.b64encode(b"k" * 32).decode("ascii")


class TestEncryptionKeyLoading:
    def test_get_encryption_key_emulator_uses_deterministic_fallback(self, monkeypatch):
        monkeypatch.setenv("FUNCTIONS_EMULATOR", "true")
        monkeypatch.delenv("MFA_ENCRYPTION_KEY", raising=False)
        key = crypto._get_encryption_key()
        assert isinstance(key, bytes)
        assert len(key) == 32

    def test_get_encryption_key_emulator_rejects_invalid_base64(self, monkeypatch):
        monkeypatch.setenv("FUNCTIONS_EMULATOR", "true")
        monkeypatch.setenv("MFA_ENCRYPTION_KEY", "a")
        with pytest.raises(RuntimeError, match="not valid base64"):
            crypto._get_encryption_key()

    def test_get_encryption_key_emulator_rejects_wrong_key_length(self, monkeypatch):
        monkeypatch.setenv("FUNCTIONS_EMULATOR", "true")
        monkeypatch.setenv("MFA_ENCRYPTION_KEY", base64.b64encode(b"short").decode("ascii"))
        with pytest.raises(RuntimeError, match="must be 32 bytes"):
            crypto._get_encryption_key()

    def test_get_encryption_key_production_secret_manager_error(self, monkeypatch):
        monkeypatch.setenv("FUNCTIONS_EMULATOR", "false")

        class FailingSecretParam:
            def __init__(self, _name):
                raise RuntimeError("missing secret")

        firebase_mod = sys.modules["firebase_functions"]
        monkeypatch.setattr(firebase_mod, "params", SimpleNamespace(SecretParam=FailingSecretParam), raising=False)

        with pytest.raises(RuntimeError, match="not configured in Secret Manager"):
            crypto._get_encryption_key()

    def test_get_encryption_key_production_secret_manager_success(self, monkeypatch):
        monkeypatch.setenv("FUNCTIONS_EMULATOR", "false")
        key_b64 = base64.b64encode(b"x" * 32).decode("ascii")

        class SecretParam:
            def __init__(self, _name):
                self.value = key_b64

        firebase_mod = sys.modules["firebase_functions"]
        monkeypatch.setattr(firebase_mod, "params", SimpleNamespace(SecretParam=SecretParam), raising=False)

        key = crypto._get_encryption_key()
        assert key == b"x" * 32

    def test_get_encryption_key_production_empty_secret_value_rejected(self, monkeypatch):
        monkeypatch.setenv("FUNCTIONS_EMULATOR", "false")

        class SecretParam:
            def __init__(self, _name):
                self.value = ""

        firebase_mod = sys.modules["firebase_functions"]
        monkeypatch.setattr(firebase_mod, "params", SimpleNamespace(SecretParam=SecretParam), raising=False)

        with pytest.raises(RuntimeError, match="is empty"):
            crypto._get_encryption_key()


class TestEncryptDecrypt:
    def test_encrypt_rejects_empty_secret(self):
        with pytest.raises(ValueError, match="Cannot encrypt empty MFA secret"):
            crypto.encrypt_mfa_secret("")

    def test_encrypt_and_decrypt_with_aad_v2(self, monkeypatch):
        monkeypatch.setenv("FUNCTIONS_EMULATOR", "true")
        monkeypatch.setenv("MFA_ENCRYPTION_KEY", VALID_KEY_B64)

        encrypted = crypto.encrypt_mfa_secret("BASE32SECRET", associated_data="user_123")
        assert encrypted.startswith("v2:")
        assert crypto.decrypt_mfa_secret(encrypted, associated_data="user_123") == "BASE32SECRET"

    def test_decrypt_rejects_empty_ciphertext(self):
        with pytest.raises(ValueError, match="MFA secret is empty"):
            crypto.decrypt_mfa_secret("")

    def test_decrypt_rejects_plaintext_and_logs_critical(self):
        with patch.object(crypto.logger, "critical") as mock_critical:
            with pytest.raises(ValueError, match="Plaintext MFA secret detected"):
                crypto.decrypt_mfa_secret("PLAINTEXT_SECRET")
        mock_critical.assert_called_once()

    def test_decrypt_rejects_invalid_v2_format(self):
        with pytest.raises(ValueError, match="Invalid v2 encrypted MFA secret format"):
            crypto.decrypt_mfa_secret("v2:only_nonce", associated_data="user_123")

    def test_decrypt_rejects_invalid_v1_format(self):
        with pytest.raises(ValueError, match="Invalid encrypted MFA secret format"):
            crypto.decrypt_mfa_secret("too:many:parts")

    def test_decrypt_rejects_invalid_base64(self):
        with pytest.raises(ValueError, match="Invalid base64"):
            crypto.decrypt_mfa_secret("v2:a:a", associated_data="user_123")

    def test_decrypt_rejects_invalid_nonce_length(self):
        nonce_b64 = base64.b64encode(b"short").decode("ascii")
        ct_b64 = base64.b64encode(b"cipher").decode("ascii")
        with pytest.raises(ValueError, match="Invalid nonce length"):
            crypto.decrypt_mfa_secret(f"{nonce_b64}:{ct_b64}")

    def test_decrypt_v1_with_aad_falls_back_without_aad(self, monkeypatch):
        monkeypatch.setenv("FUNCTIONS_EMULATOR", "true")
        monkeypatch.setenv("MFA_ENCRYPTION_KEY", VALID_KEY_B64)

        encrypted_v1 = crypto.encrypt_mfa_secret("BASE32SECRET", associated_data=None)
        with patch.object(crypto.logger, "warning") as mock_warning:
            plaintext = crypto.decrypt_mfa_secret(encrypted_v1, associated_data="user_123")
        assert plaintext == "BASE32SECRET"
        mock_warning.assert_called_once()

    def test_decrypt_with_wrong_aad_fails_after_fallback(self, monkeypatch):
        monkeypatch.setenv("FUNCTIONS_EMULATOR", "true")
        monkeypatch.setenv("MFA_ENCRYPTION_KEY", VALID_KEY_B64)

        encrypted = crypto.encrypt_mfa_secret("BASE32SECRET", associated_data="user_123")
        with pytest.raises(RuntimeError, match="Failed to decrypt MFA secret"):
            crypto.decrypt_mfa_secret(encrypted, associated_data="different_user")

    def test_decrypt_without_aad_fails_for_tampered_ciphertext(self, monkeypatch):
        monkeypatch.setenv("FUNCTIONS_EMULATOR", "true")
        monkeypatch.setenv("MFA_ENCRYPTION_KEY", VALID_KEY_B64)

        encrypted = crypto.encrypt_mfa_secret("BASE32SECRET")
        parts = encrypted.split(":")
        parts[1] = parts[1][:-2] + "AA"
        tampered = ":".join(parts)

        with pytest.raises(RuntimeError, match="Failed to decrypt MFA secret"):
            crypto.decrypt_mfa_secret(tampered)
