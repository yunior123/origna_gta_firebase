import importlib
from unittest.mock import Mock, patch

import pytest

from schema_constants import Fields


def _sample_order_data() -> dict:
    return {
        Fields.SHIPPING_ADDRESS: {
            Fields.STREET: "123 Main St",
            Fields.CITY: "Toronto",
            Fields.STATE: "ON",
            Fields.POSTAL_CODE: "M5V2H1",
            Fields.COUNTRY: "Canada",
            Fields.PHONE_NUMBER: "+1-416-555-1000",
        },
        Fields.CUSTOMER_EMAIL: "buyer@example.com",
        Fields.ORDER_STATUS: "confirmed",
        Fields.ITEMS: [
            {Fields.NAME: "Keyboard", Fields.QUANTITY: 2, Fields.PRICE: 99.99},
            {Fields.NAME: "Mouse", Fields.QUANTITY: 1, Fields.PRICE: 39.99},
        ],
        Fields.SUBTOTAL_CENTS: 23997,
        Fields.SHIPPING_COST_CENTS: 500,
        Fields.TAXES: {"GST": 12.0, "HST": 24.0},
        Fields.TOTAL_AMOUNT_CENTS: 28497,
    }


class TestPdfInvoiceServiceDeep:
    def test_generate_invoice_pdf_returns_none_when_reportlab_disabled(self):
        import services.pdf_invoice_service as pdf_service

        with patch.object(pdf_service, "HAS_REPORTLAB", False):
            out = pdf_service.generate_invoice_pdf(_sample_order_data(), "order_1", preferred_language="en")
        assert out is None

    def test_generate_invoice_pdf_handles_invalid_language_by_falling_back_to_en(self):
        import services.pdf_invoice_service as pdf_service

        if not pdf_service.HAS_REPORTLAB:
            pytest.skip("reportlab not installed in environment")

        out = pdf_service.generate_invoice_pdf(_sample_order_data(), "order_2", preferred_language="zz")
        assert isinstance(out, bytes)
        assert out.startswith(b"%PDF")

    def test_generate_invoice_pdf_french_branch_with_phone_and_tax_breakdown(self):
        import services.pdf_invoice_service as pdf_service

        if not pdf_service.HAS_REPORTLAB:
            pytest.skip("reportlab not installed in environment")

        out = pdf_service.generate_invoice_pdf(_sample_order_data(), "order_3", preferred_language="fr")
        assert isinstance(out, bytes)
        assert out.startswith(b"%PDF")

    def test_generate_invoice_pdf_handles_build_exceptions(self):
        import services.pdf_invoice_service as pdf_service

        if not pdf_service.HAS_REPORTLAB:
            pytest.skip("reportlab not installed in environment")

        with patch.object(pdf_service, "SimpleDocTemplate", side_effect=Exception("doc failure")):
            out = pdf_service.generate_invoice_pdf(_sample_order_data(), "order_4", preferred_language="en")
        assert out is None

    def test_module_import_sets_has_reportlab_false_when_reportlab_missing(self):
        import services.pdf_invoice_service as pdf_service

        real_import = __import__

        def _fake_import(name, globals=None, locals=None, fromlist=(), level=0):
            if name.startswith("reportlab"):
                raise ImportError("reportlab unavailable")
            return real_import(name, globals, locals, fromlist, level)

        try:
            with patch("builtins.__import__", side_effect=_fake_import):
                reloaded = importlib.reload(pdf_service)
                assert reloaded.HAS_REPORTLAB is False
        finally:
            importlib.reload(pdf_service)
