"""Module test_shipping_service_estimates.py."""
import pytest

from services.shipping_service import (
    estimate_delivery_date_range,
    get_international_shipping_estimate,
)


def test_international_shipping_estimate_weight_surcharge_applies():
    """Function test_international_shipping_estimate_weight_surcharge_applies."""
    est = get_international_shipping_estimate("aliexpress", speed="express", weight_kg=3.0)
    # base 15.99 + (3.0-1.0)*3.0 = 21.99
    assert est["cost"] == pytest.approx(21.99)


def test_international_shipping_estimate_tracking_true_for_express():
    """Function test_international_shipping_estimate_tracking_true_for_express."""
    est = get_international_shipping_estimate("other", speed="express", weight_kg=0.5)
    assert est["tracking"] is True


def test_estimate_delivery_date_range_parses_supplier_days_range():
    """Function test_estimate_delivery_date_range_parses_supplier_days_range."""
    out = estimate_delivery_date_range(
        supplier_info={"type": "temu", "shippingDays": "7-15", "hasTracking": True},
        seller_estimated_days=3,
        is_international=False,
    )
    assert out["min_days"] == 7
    assert out["max_days"] == 15
    assert out["display_text"] == "7-15 business days"
    assert out["source"] == "international_supplier"


def test_estimate_delivery_date_range_invalid_supplier_days_falls_back():
    """Function test_estimate_delivery_date_range_invalid_supplier_days_falls_back."""
    out = estimate_delivery_date_range(
        supplier_info={"type": "aliexpress", "shippingDays": "unknown", "hasTracking": False},
        seller_estimated_days=3,
        is_international=False,
    )
    # aliexpress standard default is 15-30
    assert out["min_days"] == 15
    assert out["max_days"] == 30
    assert out["display_text"] == "15-30 business days"
    assert out["source"] == "international_supplier"


def test_estimate_delivery_date_range_domestic_defaults():
    """Function test_estimate_delivery_date_range_domestic_defaults."""
    out = estimate_delivery_date_range(
        supplier_info=None,
        seller_estimated_days=4,
        is_international=False,
    )
    assert out["min_days"] == 4
    assert out["max_days"] == 7
    assert out["display_text"] == "4-7 business days"
    assert out["source"] == "domestic"
