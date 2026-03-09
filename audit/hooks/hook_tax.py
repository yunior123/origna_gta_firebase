"""
🧾 Tax & Compliance Audit Hook — Canadian GST/HST/PST/QST tax system.

Audits: tax rates, Stripe Tax integration, exemptions, cross-stack sync,
        CRA compliance, place-of-supply rules, and receipt requirements.
"""
from .base import BaseHook, register_hook
from .prompts import STRUCTURED_OUTPUT_INSTRUCTION, PROJECT_CONTEXT


@register_hook
class TaxHook(BaseHook):
    """Class TaxHook."""
    hook_name = "tax"
    description = "Tax compliance: GST/HST/PST/QST rates, Stripe Tax, exemptions, CRA compliance"
    emoji = "🧾"

    watch_patterns = [
        "functions/schema_constants.py",
        "functions/handlers/payment_stripe.py",
        "functions/services/shipping_service.py",
        "functions/config.py",
        "functions/models/order.py",
        "functions/handlers/users.py",
        "origna_gta/lib/utils/utils.dart",
        "origna_gta/lib/core/schema/schema_constants.dart",
        "origna_gta/lib/features/checkout/*",
        "origna_gta/lib/screens/checkout_screen.dart",
        "origna_gta/lib/screens/cart_screen.dart",
        "docs/database_schema.json",
    ]

    target_files = [
        "functions/schema_constants.py",              # Source of truth — TAX_RATES
        "functions/handlers/payment_stripe.py",       # Tax calculation logic
        "functions/services/shipping_service.py",     # _TAX_RATES_CACHE
        "functions/config.py",                        # CATEGORY_TAX_CODE_MAP, Stripe Tax config
        "functions/models/order.py",                  # Taxes Pydantic model
        "functions/handlers/users.py",                # GST number management
        "origna_gta/lib/utils/utils.dart",            # provinceTaxRates, getTaxRate()
        "origna_gta/lib/core/schema/schema_constants.dart",  # BusinessRules.taxRates
        "origna_gta/lib/features/checkout/checkout_provider.dart",
        "origna_gta/lib/features/checkout/checkout_state.dart",
        "origna_gta/lib/screens/checkout_screen.dart",
        "origna_gta/lib/screens/cart_screen.dart",
        "e2e/scripts/seed/seed-orders.py",
        "docs/TAX_SECURITY.md",
    ]

    def get_prompt(self) -> str:
        """Function get_prompt."""
        return f"""You are a senior tax compliance engineer auditing the CANADIAN TAX SYSTEM of a production e-commerce marketplace (Flutter + Firebase + Stripe Connect).

{PROJECT_CONTEXT}

## Canadian Tax Context (as of April 1, 2025 — verified with CRA)

OFFICIAL CRA RATES (https://www.canada.ca/en/revenue-agency/services/tax/businesses/topics/gst-hst-businesses/charge-collect-which-rate/calculator.html):
- AB: GST 5%
- BC: GST 5% + PST 7% = 12%
- MB: GST 5% + PST 7% = 12%
- NB: HST 15%
- NL: HST 15%
- **NS: HST 14% (CHANGED from 15% on April 1, 2025)**
- NT: GST 5%
- NU: GST 5%
- ON: HST 13%
- PE: HST 15%
- QC: GST 5% + QST 9.975% = 14.975%
- SK: GST 5% + PST 6% = 11%
- YT: GST 5%

## Focus Areas

1. **TAX RATE ACCURACY** — Do ALL tax rate definitions (backend, frontend, schema, tests, seeders) match the current CRA-published rates? Are all 13 provinces/territories covered? Is Nova Scotia at 14% (not 15%)?

2. **CROSS-STACK CONSISTENCY** — Do tax rates in `schema_constants.py`, `schema_constants.dart`, `utils.dart`, `shipping_service.py`, `payment_stripe.py`, `database_schema.json`, `seed-orders.py` ALL match? Are there hardcoded rates that bypass the single source of truth?

3. **TAX BASE CORRECTNESS** — Is GST/HST applied to shipping charges? (Required by CRA in Canada.) Is the frontend estimate consistent with backend calculation? Does `_buildTaxBreakdown()` use the same base as `Estimated Total`?

4. **STRIPE TAX INTEGRATION** — Is `STRIPE_TAX_ENABLED` feature flag working? Does fallback calculation match Stripe Tax results? Is B2B exemption ONLY applied when Stripe validates GST number? Are tax codes correct for each category?

5. **EXEMPTIONS** — Children's clothing exempt in ON, BC, MB, SK only? Basic groceries zero-rated in ALL provinces? Are there other mandatory Canadian exemptions missing (prescription drugs, medical devices)?

6. **B2B / GST NUMBER** — Format validation `^\\d{{9}}[A-Z]{{2}}\\d{{4}}$`? Rate-limited (3/day)? Stripe-only validation (no manual bypass)? Reverse charge correctly applied?

7. **PLACE OF SUPPLY** — Tax based on delivery address province (not seller province)? Required by CRA GST/HST rules. What happens when address province is unknown?

8. **RECEIPTS & INVOICES** — Does order data include: GST/HST registration number, tax breakdown by type, total before/after tax? Required by CRA for GST/HST registrants.

9. **REFUND TAX HANDLING** — Proportional tax refund on partial refunds? Full tax refund on full refunds? Is tax-on-shipping refunded?

10. **MARKETPLACE OPERATOR OBLIGATIONS** — As a "distribution platform operator" under ETA 2021 amendments, does the platform collect and remit GST/HST on behalf of sellers? Are records maintained for 6 years?

11. **FRONTEND UI ACCURACY** — Cart screen tax info text correct? Checkout screen tax breakdown correct? Rate ranges displayed to user accurate?

12. **EDGE CASES** — Unknown province fallback (currently defaults to Ontario 13%)? Digital-only orders (no shipping, tax still applies)? Zero-dollar orders? Free shipping (tax on $0 shipping = $0)?

## Rules
- Verify EVERY tax rate against the CRA official rates listed above
- Flag ANY rate that differs from CRA (this is a legal compliance issue)
- Check cross-stack consistency: Python ↔ Dart ↔ JSON ↔ Tests
- Assume adversarial users who will set province to lowest-tax area
- Create at least 25 tax evasion/manipulation scenarios
- Every finding must reference specific files and line numbers
- If something is solid/correct, say it in ONE line
- Focus on scenarios where the platform charges WRONG tax (legal liability)

{STRUCTURED_OUTPUT_INSTRUCTION}

Project files:
"""
