"""Module shipping.py."""
import logging

from firebase_functions import https_fn

from services.shipping_service import calculate_shipping_cost as _calculate_shipping_cost
from utils.function_options import DEFAULT_OPTIONS

logger = logging.getLogger(__name__)

@https_fn.on_call(**DEFAULT_OPTIONS)
def calculate_shipping_cost(req: https_fn.CallableRequest) -> dict:
    """
    Cloud Function wrapper for shipping cost calculation.
    Allows clients to get accurate shipping estimates without exposing Geoapify keys.
    """
    if not req.auth:
        raise https_fn.HttpsError("unauthenticated", "User must be authenticated")

    try:
        items = req.data.get("items", [])
        address = req.data.get("address", {})
        speed = req.data.get("speed", "standard")

        if not items:
            raise https_fn.HttpsError("invalid-argument", "Items are required")
        if not address:
            raise https_fn.HttpsError("invalid-argument", "Address is required")

        cost = _calculate_shipping_cost(items, address, speed=speed)

        return {"success": True, "cost": cost}
    except https_fn.HttpsError:
        # Preserve explicit validation/permission errors from this handler.
        raise
    except ValueError as e:
        raise https_fn.HttpsError("invalid-argument", str(e)) from e
    except Exception as e:
        logger.error(f"Error calculating shipping cost: {e}")
        raise https_fn.HttpsError("internal", "Internal error calculating shipping cost") from e
