"""
Address autocomplete proxy — keeps the Geoapify API key server-side.

Clients call `get_address_suggestions` with a query string and receive the
Geoapify autocomplete `features` array.  The API key is never sent to the
client bundle.
"""

from typing import Any

import requests
from firebase_functions import https_fn

from config import get_geoapify_api_key
from utils.function_options import DEFAULT_OPTIONS

_GEOAPIFY_AUTOCOMPLETE_URL = "https://api.geoapify.com/v1/geocode/autocomplete"

# Canada-only filter — keeps results relevant for our marketplace.
_COUNTRY_FILTER = "countrycode:ca"


@https_fn.on_call(**DEFAULT_OPTIONS)
def get_address_suggestions(req: https_fn.CallableRequest) -> dict[str, Any]:
    """
    Proxy Geoapify address autocomplete for authenticated users.

    Request payload:
        query (str, required): partial address text
        limit (int, optional): max results (default 5, max 10)

    Returns:
        {"features": [...]}  — same structure as Geoapify /geocode/autocomplete
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "Must be authenticated")

    data = req.data or {}
    query: str = (data.get("query") or "").strip()
    if not query:
        raise https_fn.HttpsError("invalid-argument", "query is required")

    limit = min(int(data.get("limit", 5)), 10)

    api_key = get_geoapify_api_key()
    if not api_key:
        # Return empty — degraded gracefully, don't crash the screen.
        return {"features": []}

    try:
        response = requests.get(
            _GEOAPIFY_AUTOCOMPLETE_URL,
            params={
                "text": query,
                "filter": _COUNTRY_FILTER,
                "limit": limit,
                "apiKey": api_key,
            },
            timeout=5,
        )
        response.raise_for_status()
        body = response.json()
        return {"features": body.get("features", [])}
    except requests.exceptions.Timeout:
        raise https_fn.HttpsError("deadline-exceeded", "Address lookup timed out") from None
    except requests.exceptions.HTTPError as e:
        raise https_fn.HttpsError("internal", f"Address service error: {e}") from e
    except Exception as e:
        raise https_fn.HttpsError("internal", f"Unexpected error: {e}") from e
