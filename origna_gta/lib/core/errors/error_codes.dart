/// Standardized error codes for OrignaGTA.
/// Format: ORIGNA-{DOMAIN}-{NUMBER}
/// Each code is documented in docs/ARCHITECTURE.md
abstract final class ErrorCodes {
  // AUTH domain
  static const authEmailInUse = 'ORIGNA-AUTH-001';
  static const authWrongPassword = 'ORIGNA-AUTH-002';
  static const authUserNotFound = 'ORIGNA-AUTH-003';
  static const authWeakPassword = 'ORIGNA-AUTH-004';
  static const authTooManyRequests = 'ORIGNA-AUTH-005';
  static const authGoogleSignInFailed = 'ORIGNA-AUTH-006';
  static const authAppleSignInFailed = 'ORIGNA-AUTH-007';
  static const authSessionExpired = 'ORIGNA-AUTH-008';
  static const authMfaRequired = 'ORIGNA-AUTH-009';

  // PAY domain
  static const payCardDeclined = 'ORIGNA-PAY-001';
  static const payInsufficientFunds = 'ORIGNA-PAY-002';
  static const payExpiredCard = 'ORIGNA-PAY-003';
  static const payInvalidCard = 'ORIGNA-PAY-004';
  static const payAmountMismatch = 'ORIGNA-PAY-005';
  static const payCheckoutExpired = 'ORIGNA-PAY-006';
  static const payRefundFailed = 'ORIGNA-PAY-007';
  static const paySellerSuspended = 'ORIGNA-PAY-008';
  static const payProductUnavailable = 'ORIGNA-PAY-009';
  static const payAsyncPending = 'ORIGNA-PAY-010';

  // ORD domain
  static const ordNotFound = 'ORIGNA-ORD-001';
  static const ordCancelNotAllowed = 'ORIGNA-ORD-002';
  static const ordAlreadyCancelled = 'ORIGNA-ORD-003';
  static const ordReturnWindowExpired = 'ORIGNA-ORD-004';
  static const ordReturnNotAllowed = 'ORIGNA-ORD-005';
  static const ordStatusInvalid = 'ORIGNA-ORD-006';
  static const ordBiometricFailed = 'ORIGNA-ORD-007';

  // SHIP domain
  static const shipCostCalculationFailed = 'ORIGNA-SHIP-001';
  static const shipAddressInvalid = 'ORIGNA-SHIP-002';
  static const shipProviderUnavailable = 'ORIGNA-SHIP-003';
  static const shipApprovalExpired = 'ORIGNA-SHIP-004';
  static const shipCostTooHigh = 'ORIGNA-SHIP-005';

  // PROD domain
  static const prodNotFound = 'ORIGNA-PROD-001';
  static const prodOutOfStock = 'ORIGNA-PROD-002';
  static const prodNotAvailable = 'ORIGNA-PROD-003';
  static const prodImageUploadFailed = 'ORIGNA-PROD-004';
  static const prodInvalidCategory = 'ORIGNA-PROD-005';

  // SELL domain
  static const sellOnboardingIncomplete = 'ORIGNA-SELL-001';
  static const sellPayoutsDisabled = 'ORIGNA-SELL-002';
  static const sellAccountSuspended = 'ORIGNA-SELL-003';
  static const sellStripeNotConnected = 'ORIGNA-SELL-004';

  // PERM domain
  static const permUnauthorized = 'ORIGNA-PERM-001';
  static const permSellerRequired = 'ORIGNA-PERM-002';
  static const permAdminRequired = 'ORIGNA-PERM-003';
  static const permPremiumRequired = 'ORIGNA-PERM-004';
  static const permSelfPurchaseBlocked = 'ORIGNA-PERM-005';

  // SYS domain
  static const sysNetworkError = 'ORIGNA-SYS-001';
  static const sysServerError = 'ORIGNA-SYS-002';
  static const sysTimeout = 'ORIGNA-SYS-003';
  static const sysUnknown = 'ORIGNA-SYS-999';
}
