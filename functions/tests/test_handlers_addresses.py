from unittest.mock import Mock, patch

import pytest
import requests
from firebase_functions import https_fn


class TestGetAddressSuggestions:
    def test_requires_authentication(self):
        from handlers.addresses import get_address_suggestions

        req = Mock()
        req.auth = None
        req.data = {"query": "Toronto"}

        with pytest.raises(https_fn.HttpsError) as exc:
            get_address_suggestions(req)
        assert exc.value.code == "unauthenticated"

    def test_requires_query(self):
        from handlers.addresses import get_address_suggestions

        req = Mock()
        req.auth = Mock(uid="user_1")
        req.data = {"query": "   "}

        with pytest.raises(https_fn.HttpsError) as exc:
            get_address_suggestions(req)
        assert exc.value.code == "invalid-argument"

    @patch("handlers.addresses.get_geoapify_api_key", return_value="")
    def test_returns_empty_when_api_key_missing(self, _mock_key):
        from handlers.addresses import get_address_suggestions

        req = Mock()
        req.auth = Mock(uid="user_1")
        req.data = {"query": "Toronto"}

        assert get_address_suggestions(req) == {"features": []}

    @patch("handlers.addresses.requests.get")
    @patch("handlers.addresses.get_geoapify_api_key", return_value="geo_key")
    def test_proxies_geoapify_and_caps_limit(self, _mock_key, mock_get):
        from handlers.addresses import get_address_suggestions

        resp = Mock()
        resp.json.return_value = {"features": [{"formatted": "Toronto, ON"}]}
        resp.raise_for_status.return_value = None
        mock_get.return_value = resp

        req = Mock()
        req.auth = Mock(uid="user_1")
        req.data = {"query": "Tor", "limit": 99}

        out = get_address_suggestions(req)
        assert out == {"features": [{"formatted": "Toronto, ON"}]}

        call = mock_get.call_args
        assert call.kwargs["params"]["limit"] == 10
        assert call.kwargs["params"]["filter"] == "countrycode:ca"

    @patch("handlers.addresses.requests.get", side_effect=requests.exceptions.Timeout())
    @patch("handlers.addresses.get_geoapify_api_key", return_value="geo_key")
    def test_maps_timeout_to_deadline_exceeded(self, _mock_key, _mock_get):
        from handlers.addresses import get_address_suggestions

        req = Mock()
        req.auth = Mock(uid="user_1")
        req.data = {"query": "Toronto"}

        with pytest.raises(https_fn.HttpsError) as exc:
            get_address_suggestions(req)
        assert exc.value.code == "deadline-exceeded"

    @patch("handlers.addresses.requests.get")
    @patch("handlers.addresses.get_geoapify_api_key", return_value="geo_key")
    def test_maps_http_error_to_internal(self, _mock_key, mock_get):
        from handlers.addresses import get_address_suggestions

        resp = Mock()
        resp.raise_for_status.side_effect = requests.exceptions.HTTPError("429")
        mock_get.return_value = resp

        req = Mock()
        req.auth = Mock(uid="user_1")
        req.data = {"query": "Toronto"}

        with pytest.raises(https_fn.HttpsError) as exc:
            get_address_suggestions(req)
        assert exc.value.code == "internal"
        assert "Address service error" in str(exc.value)

    @patch("handlers.addresses.requests.get", side_effect=RuntimeError("network down"))
    @patch("handlers.addresses.get_geoapify_api_key", return_value="geo_key")
    def test_maps_unexpected_error_to_internal(self, _mock_key, _mock_get):
        from handlers.addresses import get_address_suggestions

        req = Mock()
        req.auth = Mock(uid="user_1")
        req.data = {"query": "Toronto"}

        with pytest.raises(https_fn.HttpsError) as exc:
            get_address_suggestions(req)
        assert exc.value.code == "internal"
        assert "Unexpected error" in str(exc.value)
