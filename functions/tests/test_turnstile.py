"""Tests for functions/utils/turnstile.py"""

from unittest.mock import MagicMock, patch

import pytest

from utils.turnstile import verify_turnstile_token


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _mock_response(success: bool, error_codes: list[str] | None = None) -> MagicMock:
    resp = MagicMock()
    resp.raise_for_status = MagicMock()
    body: dict = {"success": success}
    if error_codes:
        body["error-codes"] = error_codes
    resp.json.return_value = body
    return resp


def _secrets_with(key: str) -> dict:
    return {"cloudflare_turnstile_secret": key}


def _secrets_empty() -> dict:
    return {}


# ---------------------------------------------------------------------------
# Tests — no secret configured (dev / not set)
# ---------------------------------------------------------------------------

class TestNoSecret:
    """Class TestNoSecret."""
    def test_empty_token_passes_when_no_secret(self) -> None:
        """Function test_empty_token_passes_when_no_secret."""
        with patch("config._secrets", return_value=_secrets_empty()):
            assert verify_turnstile_token(None) is True

    def test_valid_token_passes_when_no_secret(self) -> None:
        """Function test_valid_token_passes_when_no_secret."""
        with patch("config._secrets", return_value=_secrets_empty()):
            assert verify_turnstile_token("some-token") is True


# ---------------------------------------------------------------------------
# Tests — secret configured
# ---------------------------------------------------------------------------

class TestWithSecret:
    """Class TestWithSecret."""
    _SECRET = "test-secret-key"

    def test_valid_token_returns_true(self) -> None:
        """Function test_valid_token_returns_true."""
        with patch("config._secrets", return_value=_secrets_with(self._SECRET)), \
             patch("utils.turnstile.requests.post", return_value=_mock_response(True)):
            assert verify_turnstile_token("good-token") is True

    def test_invalid_token_returns_false(self) -> None:
        """Function test_invalid_token_returns_false."""
        with patch("config._secrets", return_value=_secrets_with(self._SECRET)), \
             patch("utils.turnstile.requests.post",
                   return_value=_mock_response(False, ["invalid-input-response"])):
            assert verify_turnstile_token("bad-token") is False

    def test_empty_token_returns_false(self) -> None:
        """Function test_empty_token_returns_false."""
        with patch("config._secrets", return_value=_secrets_with(self._SECRET)):
            assert verify_turnstile_token(None) is False

    def test_empty_string_token_returns_false(self) -> None:
        """Function test_empty_string_token_returns_false."""
        with patch("config._secrets", return_value=_secrets_with(self._SECRET)):
            assert verify_turnstile_token("") is False

    def test_network_error_fails_open(self) -> None:
        """Function test_network_error_fails_open."""
        with patch("config._secrets", return_value=_secrets_with(self._SECRET)), \
             patch("utils.turnstile.requests.post", side_effect=ConnectionError("timeout")):
            assert verify_turnstile_token("some-token") is True

    def test_remote_ip_forwarded_to_cloudflare(self) -> None:
        """Function test_remote_ip_forwarded_to_cloudflare."""
        mock_post = MagicMock(return_value=_mock_response(True))
        with patch("config._secrets", return_value=_secrets_with(self._SECRET)), \
             patch("utils.turnstile.requests.post", mock_post):
            verify_turnstile_token("tok", remote_ip="1.2.3.4")
        call_kwargs = mock_post.call_args
        assert call_kwargs.kwargs["data"]["remoteip"] == "1.2.3.4"

    def test_no_remote_ip_omits_field(self) -> None:
        """Function test_no_remote_ip_omits_field."""
        mock_post = MagicMock(return_value=_mock_response(True))
        with patch("config._secrets", return_value=_secrets_with(self._SECRET)), \
             patch("utils.turnstile.requests.post", mock_post):
            verify_turnstile_token("tok")
        call_kwargs = mock_post.call_args
        assert "remoteip" not in call_kwargs.kwargs["data"]
