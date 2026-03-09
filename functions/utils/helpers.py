"""Module helpers.py."""
import html
import logging
import re
from typing import Any

from pydantic import ValidationError

# Import Pydantic models for type hinting and internal validation
from models.base import Address
from models.order import OrderItem
from schema_constants import ApiKeys, Fields, OrderStatusValues, ValidationLimits

logger = logging.getLogger(__name__)

# RFC 5322 compliant email regex
RFC_5322_EMAIL = re.compile(
    r"^(?:[a-zA-Z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-zA-Z0-9!#$%&'*+/=?^_`{|}~-]+)*)@"
    r"(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$"
)

# Allow letters, spaces, hyphens, apostrophes, periods (O'Brien, Jr., María-José)
# Excludes × (U+00D7) and ÷ (U+00F7) intentionally
NAME_REGEX = re.compile(r"^[A-Za-zÀ-ÖØ-öø-ÿ][A-Za-zÀ-ÖØ-öø-ÿ' .\-]*[A-Za-zÀ-ÖØ-öø-ÿ.]?$")
POSTAL_CODE_CA_REGEX = re.compile(r"^[A-Za-z]\d[A-Za-z][ -]?\d[A-Za-z]\d$")

CONTROL_CHARS = re.compile(r"[\x00-\x1F\x7F]")

# Validation limits — imported from centralized schema_constants.ValidationLimits
MAX_EMAIL_LENGTH = ValidationLimits.MAX_EMAIL_LENGTH
MAX_NAME_LENGTH = ValidationLimits.MAX_NAME_LENGTH
MAX_STREET_LENGTH = ValidationLimits.MAX_STREET_LENGTH
MAX_CITY_LENGTH = ValidationLimits.MAX_CITY_LENGTH
MAX_MESSAGE_LENGTH = ValidationLimits.MAX_MESSAGE_LENGTH
MIN_MESSAGE_LENGTH = ValidationLimits.MIN_MESSAGE_LENGTH
MAX_ITEM_QUANTITY = ValidationLimits.MAX_ITEM_QUANTITY


def sanitized_text(value: str) -> str:
    """
    XSS Prevention: Sanitize user-provided text for safe display in the UI.
    Uses html.escape() (allowlist approach) per OWASP best practices.
    
    IMPORTANT: Idempotent — unescape first to prevent double-encoding.
    
    Args:
        value: The raw input string from the client.
        
    Returns:
        A clean, HTML-escaped version of the input string.
    """
    if value is None:
        return ""

    text = str(value)

    # Unescape first to prevent double-encoding on re-trigger.
    # html.escape(html.unescape(x)) is idempotent for any x.
    text = html.unescape(text)

    # html.escape handles: & < > " '
    # This is the OWASP-recommended approach — encode everything.
    return html.escape(text, quote=True)


def sanitize_path(path: str) -> str:
    """
    Sanitize file paths to prevent path traversal attacks.
    Returns only the basename — all directory components stripped.
    """
    if path is None:
        return ""

    import os

    path_str = str(path)

    # os.path.basename() is the primary defense — extracts filename only
    path_str = os.path.basename(path_str)

    # Defense in depth: remove any remaining path separators
    path_str = path_str.replace("/", "").replace("\\", "")

    # Reject hidden files (dotfiles)
    if path_str.startswith("."):
        return ""

    return path_str


def sanitize_text(value: str, max_length: int, field_name: str = "input", min_length: int = 1) -> str:
    """Sanitize text input: strip, remove control chars, enforce length constraints.

    NOTE: This is for INPUT validation — does NOT html-escape.
    Use sanitized_text() for OUTPUT encoding (XSS prevention).
    """
    if value is None:
        raise ValueError(f"{field_name} is required")
    text = str(value).strip()
    text = CONTROL_CHARS.sub("", text)
    text = re.sub(r"\s+", " ", text)
    if len(text) < min_length:
        raise ValueError(f"{field_name} is too short")
    if len(text) > max_length:
        raise ValueError(f"{field_name} exceeds max length")
    return text


def sanitize_email(email: str) -> str:
    """Sanitize and validate email address (RFC 5322 compliant)"""
    if email is None:
        raise ValueError("Email is required")
    email = str(email).strip().lower()
    if len(email) > MAX_EMAIL_LENGTH:
        raise ValueError("Email exceeds max length")
    if not RFC_5322_EMAIL.match(email):
        raise ValueError("Invalid email format")
    return email


def validate_name(name: str) -> str:
    """Validate person name (letters, spaces, hyphens, apostrophes, periods)."""
    cleaned = sanitize_text(name, MAX_NAME_LENGTH, field_name="name", min_length=2)
    if not NAME_REGEX.match(cleaned):
        raise ValueError("Invalid name format")
    return cleaned


def validate_phone(phone: str) -> str:
    """Validate phone number (10-15 digits only)."""
    if phone is None:
        raise ValueError("Phone is required")
    value = str(phone).strip()
    if not re.fullmatch(r"\d{10,15}", value):
        raise ValueError("Invalid phone format")
    return value


def validate_message(message: str) -> str:
    """Validate message length (10-1000) and sanitize."""
    cleaned = sanitize_text(message, MAX_MESSAGE_LENGTH, field_name="message", min_length=MIN_MESSAGE_LENGTH)
    return cleaned


def validate_postal_code(postal_code: str) -> str:
    """Validate Canadian postal code format."""
    cleaned = sanitize_text(postal_code, 7, field_name="postalCode", min_length=6).upper()
    if not POSTAL_CODE_CA_REGEX.match(cleaned):
        raise ValueError("Invalid postal code format")
    return cleaned


def validate_address_map(address: dict[str, Any]) -> Address:
    """
    Validate and sanitize delivery address using Pydantic Address model.
    Returns validated Address object.
    Raises ValidationError for consistency with other validation functions.
    """
    # CONSISTENCY FIX: Let ValidationError propagate (don't convert to ValueError)
    # This standardizes error handling - callers use try/except ValidationError
    validated_address = Address(**address)
    return validated_address


def validate_item(item: dict) -> tuple[bool, str]:
    """
    Validate individual item data using OrderItem model.
    Returns (True, "") on success or (False, error_message) on failure.
    """
    try:
        # Create OrderItem to validate structure
        validated_item = OrderItem(**item)

        # Additional business rules
        if validated_item.quantity > MAX_ITEM_QUANTITY:
            return False, f"quantity exceeds maximum ({MAX_ITEM_QUANTITY})"

        return True, ""
    except ValidationError as e:
        errors = e.errors()
        if errors:
            field = errors[0].get("loc", ["unknown"])[0]
            msg = errors[0].get("msg", "Invalid value")
            return False, f"{field}: {msg}"
        return False, "Invalid item data"
    except Exception as e:
        return False, str(e)


def validate_order_data(data: dict[str, Any]) -> tuple[bool, str | None]:
    """
    Validate order data structure using Pydantic models.
    This is a lightweight check before creating full Order object.
    Returns (True, None) on success or (False, error_message) on failure.
    """
    for field in [Fields.USER_ID, Fields.ITEMS]:
        if field not in data:
            return False, f"Missing required field: {field}"

    if not isinstance(data[Fields.ITEMS], list) or len(data[Fields.ITEMS]) == 0:
        return False, "Invalid items: must be non-empty array"

    # totalAmountCents is required (integer cents)
    amount_cents = data.get(Fields.TOTAL_AMOUNT_CENTS)
    if (
        amount_cents is None
        or not isinstance(amount_cents, (int, float))
        or isinstance(amount_cents, bool)
        or amount_cents < 0
    ):
        return False, "Invalid totalAmountCents: must be non-negative integer"

    # customerEmail is optional (can be fetched from user doc)
    customer_email = data.get(Fields.CUSTOMER_EMAIL)
    if customer_email:
        try:
            from pydantic import EmailStr, TypeAdapter

            TypeAdapter(EmailStr).validate_python(customer_email)
        except Exception:
            return False, "Invalid email address format"

    # Validate address (only for physical items)
    has_physical_items = any(not item.get(Fields.IS_DIGITAL, False) for item in data[Fields.ITEMS])
    if has_physical_items:
        shipping_address = data.get(Fields.SHIPPING_ADDRESS)
        if not shipping_address:
            return False, "Missing required field: shippingAddress"

        try:
            validate_address_map(shipping_address)
        except Exception as e:
            return False, str(e)

    # Validate each item
    for idx, item in enumerate(data[Fields.ITEMS]):
        is_valid, error_msg = validate_item(item)
        if not is_valid:
            return False, f"Item {idx}: {error_msg}"

    return True, None


def create_success_response(data: dict[str, Any], status_code: int = 200) -> dict[str, Any]:
    """
    Standardizes successful Cloud Function responses.
    
    Ensures all successful responses contain the 'success': true flag,
    which is expected by the Flutter 'ApiKeys.SUCCESS' contract.
    
    Args:
        data: The payload to return to the client.
        status_code: Optional HTTP status code (defaults to 200).
        
    Returns:
        A dictionary containing the success flag and the provided data.
    """
    return {ApiKeys.SUCCESS: True, **data}


def get_charge_id_from_pi(pi: Any) -> str | None:
    """
    Robustly extract Charge ID (ch_xxx) from a Stripe PaymentIntent object.
    
    Stripe API behavior varies: 'latest_charge' can be a simple string ID 
    or an expanded 'Charge' object depending on the request's expansion params.
    This helper handles both cases to prevent runtime AttributeErrors.
    
    Args:
        pi: A stripe.PaymentIntent object (from retrieve, capture, or confirm).
        
    Returns:
        The Charge ID string (e.g., 'ch_123') or None if not present.
    """
    if not pi:
        return None

    latest = getattr(pi, "latest_charge", None)
    if not latest:
        return None

    if isinstance(latest, str):
        return latest

    return getattr(latest, "id", None)


def compare_addresses(addr1: dict | None, addr2: dict | None) -> bool:
    """
    Performs a deep, case-insensitive comparison of two address dictionaries.
    
    Used for order idempotency checks (PAY-H1) and preventing redundant 
    address book entries. Ignores formatting differences like whitespace
    and missing vs. None fields.
    
    Args:
        addr1: First address dictionary.
        addr2: Second address dictionary.
        
    Returns:
        True if the core physical address fields match.
    """
    if addr1 is addr2:
        return True
    if addr1 is None or addr2 is None:
        return False

    # Standard field set from the Address Pydantic model
    fields = [
        Fields.STREET, Fields.CITY, Fields.STATE, Fields.POSTAL_CODE,
        Fields.COUNTRY, Fields.APARTMENT, Fields.PHONE_NUMBER
    ]

    for f in fields:
        v1 = str(addr1.get(f) or "").strip().lower()
        v2 = str(addr2.get(f) or "").strip().lower()
        if v1 != v2:
            return False

    return True


def is_valid_order_status_transition(current_status: str, new_status: str) -> bool:
    """
    Enforces the Order State Machine (OSM) business rules.
    
    This is the server-side source of truth for all order transitions.
    It protects the ledger from invalid states (e.g., Shipped -> Cancelled).
    
    Args:
        current_status: The existing status in Firestore.
        new_status: The requested status update.
        
    Returns:
        True if the transition is permitted by BusinessRules.
    """
    allowed_next_states = OrderStatusValues.VALID_TRANSITIONS.get(current_status, [])
    is_valid = new_status in allowed_next_states

    if not is_valid:
        logger.error(f"❌ INVALID STATE TRANSITION: {current_status} → {new_status}")
    else:
        logger.info(f"✅ Valid state transition: {current_status} → {new_status}")

    return is_valid


def geocode_address(address: dict) -> tuple[bool, str, dict]:
    """
    Verifies and geocodes a physical address using the Geoapify API.
    
    Resolves a human-readable address into GPS coordinates (lat/lon).
    Used by sellers for shipping origins and buyers for delivery targets.
    
    Args:
        address: Dictionary containing street, city, state, etc.
        
    Returns:
        A tuple of (success_bool, error_message, updated_address_with_coords).
    """
    from config import get_geoapify_api_key
    import requests
    from schema_constants import AppConfig

    geo_key = get_geoapify_api_key()
    if not geo_key:
        return False, "Address verification service not configured", address

    # Construct a canonical query string for Geoapify
    parts = [
        address.get(Fields.STREET, ""),
        address.get(Fields.CITY, ""),
        address.get(Fields.POSTAL_CODE, ""),
        address.get(Fields.COUNTRY, ""),
    ]
    query = ", ".join(p for p in parts if p).strip()
    if not query:
        return False, "Address is empty", address

    try:
        url = "https://api.geoapify.com/v1/geocode/search"
        response = requests.get(
            url,
            params={"text": query, "apiKey": geo_key, "limit": 1},
            timeout=AppConfig.GEOAPIFY_TIMEOUT_SECONDS
        )

        # Handle specific API error conditions with user-friendly messages
        if response.status_code == 401:
            return False, "Address service authentication failed", address
        if response.status_code == 429:
            return False, "Address service rate limit exceeded", address
        if response.status_code != 200:
            return False, f"Address service error (HTTP {response.status_code})", address

        data = response.json()
        features = data.get("features", [])
        if not features:
            return False, f"No coordinates found for the provided address: '{query}'", address

        props = features[0].get("properties", {})
        rank = props.get("rank", {})
        confidence = rank.get("confidence", 0)

        coords = features[0].get("geometry", {}).get("coordinates", [])
        if len(coords) >= 2:
            updated_addr = dict(address)
            updated_addr[Fields.LONGITUDE] = coords[0]
            updated_addr[Fields.LATITUDE] = coords[1]
            # Log confidence for auditing but do NOT persist — field is not in Address schema
            logger.info("Geocoding confidence=%.3f for query='%s'", confidence, query)
            return True, "", updated_addr

        return False, "Geocoding returned invalid results", address

    except requests.exceptions.Timeout:
        return False, "Address verification timed out — please try again", address
    except Exception as e:
        logger.error(f"Geocoding error for '{query}': {e}")
        return False, f"Address verification unexpected error: {type(e).__name__}", address
