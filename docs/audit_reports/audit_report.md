# Auth & Seller Onboarding Audit Report

## Findings

### 1. MFA enforcement for seller accounts with active Stripe payouts
*   **Severity:** MEDIUM
*   **File and Line:** `functions/handlers/payment_stripe.py` (specifically in `_execute_seller_payouts` or other payout-related functions).
*   **Invariant Violated:** MFA is not enforced for seller accounts when handling or initiating payouts, leaving them vulnerable to unauthorized financial actions if their account credentials are compromised. While MFA is enforced for administrative actions, it doesn't extend to seller-initiated payout operations.
*   **Recommended Fix:** Implement MFA checks for seller-initiated actions related to payouts. This would likely involve:
    1.  Adding a `Fields.MFA_ENABLED` flag to `seller_profiles/{uid}` or `users/{uid}` for sellers.
    2.  Implementing a function similar to `_require_recent_admin_mfa` that checks a seller's MFA status before allowing them to initiate payouts, change payout settings, or access sensitive financial information.
    3.  Integrating this MFA check into relevant functions like `_execute_seller_payouts` (if a seller can manually trigger payouts), or any functions that allow sellers to manage their Stripe Connect account settings.

### 2. Email verification required before first product listing
*   **Severity:** LOW
*   **File and Line:** `functions/handlers/products.py` (specifically `create_product_atomic` and related image/video upload functions).
*   **Invariant Violated:** Although unverified users cannot create a user profile (a prerequisite for becoming a seller), there isn't an explicit `email_verified` check directly within the product listing Cloud Functions. This could potentially allow a user who somehow bypasses the `create_user_profile` check (e.g., through direct Firestore writes in a compromised scenario, or future changes in Firebase Auth behavior) to become a seller and list products without a verified email.
*   **Recommended Fix:** Add an explicit `email_verified` check within the `create_product_atomic` and other product creation/modification functions (`upload_product_images`, `upload_product_video`) in `functions/handlers/products.py`. This provides a direct and robust enforcement at the point of action.
    For example, in `create_product_atomic`, add:
    ```python
    # ... existing seller role and onboarding check ...

    # Explicit email verification check for product listing
    if not req.auth.token.get("email_verified", False):
        raise https_fn.HttpsError("permission-denied", "Please verify your email address before listing a product.")

    # ... rest of the function ...
    ```