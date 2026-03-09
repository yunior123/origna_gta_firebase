// Schema Constants - Single Source of Truth for Field Names
//
// This file defines all Firestore field names as constants to:
// 1. Eliminate magic strings throughout the codebase
// 2. Enable IDE autocomplete and refactoring
// 3. Catch typos at compile time rather than runtime
// 4. Provide a single place to update field names
//
// USAGE:
//   // Instead of: doc.get('createdAt')
//   // Use: doc.get(Fields.createdAt)
//
//   // Instead of: FirebaseFirestore.instance.collection('orders')
//   // Use: FirebaseFirestore.instance.collection(Collections.orders)
//
// NAMING CONVENTION:
// - Dart constants: camelCase (e.g., createdAt)
// - Firestore fields: camelCase (e.g., 'createdAt')
// - Values match the actual Firestore field names
//
// See: docs/database_schema.json for full schema documentation

// =============================================================================
// COLLECTIONS - Top-level Firestore collection names
// =============================================================================

/// Standard address labels
abstract final class AddressLabelValues {
  static const home = 'Home';
  static const work = 'Work';
  static const other = 'Other';
}

// =============================================================================
// DOCUMENTS - Singleton document IDs within collections
// =============================================================================

abstract final class AdminActionValues {
  static const paymentProviderUpdate = 'payment_provider_update';
  static const stockUpdate = 'stock_update';
  static const orderRefund = 'order_refund';
  static const reviewDelete = 'review_delete';
  static const reviewFlag = 'review_flag';
}

// =============================================================================
// FIELD NAMES - All Firestore document field names
// =============================================================================

abstract final class AlgoliaActionValues {
  static const index = 'index';
  static const delete = 'delete';
}

// =============================================================================
// ENUM VALUES - Valid values for enum fields
// =============================================================================

/// Algolia replica index suffixes for sort options.
/// Appended to the base index name: `<base>_price_asc`, `<base>_price_desc`.
abstract final class AlgoliaReplicaSuffixes {
  static const priceAsc = '_price_asc';
  static const priceDesc = '_price_desc';
}

/// Cloud Function API parameter and response keys.
/// These are NOT Firestore fields — they are the contract between
/// Flutter and Cloud Functions (request params + response keys).
abstract final class ApiKeys {
  // === REQUEST PARAMS (sent to Cloud Functions) ===
  static const turnstileToken = 'turnstileToken'; // Cloudflare Turnstile challenge token (web-only)
  static const eulaAccepted = 'eulaAccepted'; // Digital product EULA acceptance flag
  static const ageVerificationAccepted = 'ageVerificationAccepted'; // Buyer age-gate confirmation for age-restricted items
  static const add = 'add';
  static const remove = 'remove';
  static const reason = 'reason';
  static const code = 'code';
  static const provider = 'provider';
  static const enabled = 'enabled';
  static const refreshUrl = 'refreshUrl';
  static const returnUrl = 'returnUrl';
  static const newStatus = 'newStatus';
  static const approved = 'approved';
  static const newShippingCost = 'newShippingCost';
  static const subtotal = 'subtotal';
  static const subtotalCents = 'subtotalCents';
  static const itemIds = 'itemIds';
  static const idempotencyKey = 'idempotencyKey';
  static const productId = 'productId';

  // === RESPONSE KEYS (returned from Cloud Functions) ===
  static const success = 'success';
  static const itemStatus = 'itemStatus';
  static const allItemsDelivered = 'allItemsDelivered';
  static const providerName = 'providerName';
  static const checkoutUrl = 'checkoutUrl';
  static const sessionId = 'sessionId';
  static const url = 'url';
  static const downloadUrl = 'downloadUrl';
  static const secret = 'secret';
  static const qrCodeUrl = 'qrCodeUrl';
  static const provisioningUri = 'provisioning_uri';
  static const backupCodes = 'backup_codes';
  static const mfaVerified = 'mfaVerified';
  static const remainingCodes = 'remainingCodes';
  static const detailsSubmitted = 'detailsSubmitted';
  static const requirementsCurrentlyDue = 'requirementsCurrentlyDue';
  static const duplicate = 'duplicate';
  static const emulatorMode = 'emulatorMode';
  static const captured = 'captured';
  static const message = 'message';
  static const revokedLicenseCount = 'revokedLicenseCount';
  static const paymentIntentId = 'paymentIntentId';
  static const accountId = 'accountId';
  static const existing = 'existing';
  static const hasChanges = 'hasChanges';
  static const priceChanges = 'priceChanges';
  static const stockChanges = 'stockChanges';
  static const removedProducts = 'removedProducts';
  static const oldPrice = 'oldPrice';
  static const newPrice = 'newPrice';
  static const requested = 'requested';
  static const available = 'available';
  static const productName = 'productName';
  static const productData = 'productData';
  static const images = 'images';
  static const testImageUrls = 'testImageUrls';

  // === PAYMENT PROVIDER RESPONSE KEYS ===
  static const supportedCurrencies = 'supportedCurrencies';
  static const supportedCountries = 'supportedCountries';
  static const features = 'features';
  static const providers = 'providers';
  static const providerStatus = 'providerStatus';
  static const configured = 'configured';
  static const missingKeys = 'missingKeys';
  static const enabledProviders = 'enabledProviders';

  // === SHIPPING RESPONSE KEYS ===
  static const allItemsShipped = 'allItemsShipped';
  static const approvalRequired = 'approvalRequired';
  static const cartSubtotalCents = 'cartSubtotalCents';
  static const action = 'action';
  static const approve = 'approve';
  static const markReceived = 'mark_received';
  static const expectedCostCents = 'expectedCostCents';
  static const licenseKey = 'licenseKey';
  static const platform = 'platform';

  // === GDPR / PIPEDA DATA EXPORT KEYS ===
  static const profile = 'profile';
  static const orders = 'orders';
  static const favorites = 'favorites';
  static const exportedAt = 'exportedAt';
}

/// Business rule constants
abstract final class BusinessRules {
  static const platformFeePercent = 2.5;
  static const autoConfirmDays = 5; // Must be < authorizationExpiryDays (2-day safety margin)
  static const authorizationExpiryDays = 6; // 6-day cutoff gives 24h safety margin before Stripe auto-voids at day 7
  static const returnWindowDays = 7; // No returns/refunds after 7 days post-delivery
  static const maxCaptureAttempts = 3;
  static const defaultCurrency = 'cad';
  static const allowedShippingCountries = {'Canada', 'CA'};
  static const ordersPageSize = 50; // Initial load limit for order lists — cursor pagination planned
  static const favoritesPageSize = 50; // Max favorites streamed per query — pagination planned
  static const maxShippingCostCad = 500; // $500 CAD absolute maximum shipping cost
  static const sellerDisputeRateThreshold = 0.05; // 5% dispute rate triggers health alert
  static const sellerRefundRateThreshold = 0.10; // 10% refund rate threshold
  static const maxMessagesPerThread = 500; // Hard cap per thread to prevent unbounded storage
  static const minMessageLength = 10; // Must match Python ValidationLimits.MIN_MESSAGE_LENGTH
  static const maxMessageLength = 1000; // Must match Python ValidationLimits.MAX_MESSAGE_LENGTH
  static const maxProductImages = 5; // Maximum number of images per product listing
  static const maxVideoBytes = 100 * 1024 * 1024; // 100 MB max video size
  static const maxVideoDurationSeconds = 60; // 60s max video duration
  static const trendingTopN = 20; // Number of products to mark as trending
  static const trendingWindowHours = 24; // Rolling window for trending calculation
  static const trendingPurchaseWeight = 3; // Weight for purchase events
  static const trendingFavoriteWeight = 2; // Weight for favorite events
  static const freeShippingThresholdCents = 7500; // $75 CAD — subtotals at or above qualify for free standard shipping
  static const localDeliveryRadiusKm = 50.0; // 50km radius for local delivery Eligibility (BUG-L1)
  // BOOT-L1: session timeout extracted to constant
  static const sessionTimeoutMinutes = 15;
  // FAV-M2: seller product list page size — cursor pagination planned for >200 sellers
  static const sellerProductsPageSize = 200;
  // Sellers can be from any country — no country restriction on seller addresses

  // F-103: Coupon & Margin safety
  static const minCheckoutTotalCents = 100; // $1.00 minimum to cover Stripe's $0.30 fixed fee
  static const maxCouponDiscountRatio = 0.95; // Max 95% off via automated coupons
  static const maxAdminCouponDiscountPercent = 90; // Admin-created coupons capped at 90%
  static const premiumSubscriptionPriceCad = 7.86; // Monthly premium membership fee in CAD
  static const premiumSubscriptionPriceCents = 786; // Monthly premium membership fee in cents

  /// Tax rates by province
  static const taxRates = {
    'AB': {'GST': 5.0},
    'BC': {'GST': 5.0, 'PST': 7.0},
    'MB': {'GST': 5.0, 'PST': 7.0},
    'NB': {'HST': 15.0},
    'NL': {'HST': 15.0},
    'NS': {'HST': 14.0}, // Changed from 15% to 14% on April 1, 2025 (CRA)
    'NT': {'GST': 5.0},
    'NU': {'GST': 5.0},
    'ON': {'HST': 13.0},
    'PE': {'HST': 15.0},
    'QC': {'GST': 5.0, 'QST': 9.975},
    'SK': {'GST': 5.0, 'PST': 6.0},
    'YT': {'GST': 5.0},
  };
}

abstract final class CancellationReasonValues {
  static const buyerRequested = 'requested_by_customer';
  static const sellerCancelled = 'seller_cancelled';
  static const shippingRejected = 'Buyer rejected shipping cost';
  static const paymentFailed = 'payment_failed';
  static const expired = 'authorization_expired';
}

/// Normalized shipping carrier identifiers
abstract final class CarrierValues {
  static const ups = 'ups';
  static const fedex = 'fedex';
  static const canadaPost = 'canada_post';
  static const purolator = 'purolator';
  static const dhl = 'dhl';
  static const usps = 'usps';
  static const maritime = 'maritime';
  static const other = 'other';

  static const all = {ups, fedex, canadaPost, purolator, dhl, usps, maritime, other};
}

abstract final class CartVerificationReasonValues {
  static const deactivated = 'deactivated';
}

/// Product category IDs
abstract final class CategoryIds {
  static const electronics = 1;
  static const computers = 2;
  static const gaming = 3;
  static const homeKitchen = 4;
  static const fashion = 5;
  static const shoesAccessories = 6;
  static const jewelryWatches = 7;
  static const beautyPersonalCare = 8;
  static const healthWellness = 9;
  static const sportsFitness = 10;
  static const automotive = 11;
  static const toolsHardware = 12;
  static const officeSupplies = 13;
  static const books = 14;
  static const musicInstruments = 15;
  static const toysGames = 16;
  static const babyKids = 17;
  static const petSupplies = 18;
  static const groceries = 19;
  static const artCollectibles = 20;
  static const digitalProducts = 21;

  static const min = 1;
  static const max = 21;
}

/// Cloud Function endpoint names. Update here ONLY if backend function names change.
/// Prevents endpoint name drift between frontend and backend.
abstract final class CloudFunctionEndpoints {
  // === ADDRESS ENDPOINTS ===
  static const getAddressSuggestions = 'get_address_suggestions';

  // === AUTH ENDPOINTS ===
  static const deleteAccount = 'delete_account';
  static const createUserProfile = 'create_user_profile';
  static const exportUserData = 'export_my_data';

  // === ADMIN ENDPOINTS ===
  static const updateUserRoles = 'update_user_roles';
  static const suspendSeller = 'suspend_seller';
  static const unsuspendSeller = 'unsuspend_seller';
  static const adminUpdateProductStock = 'admin_update_product_stock';
  static const adminDeleteReview = 'admin_delete_review';
  static const adminFlagReview = 'admin_flag_review';
  static const adminRefundOrder = 'admin_refund_order';
  static const adminMfaEnroll = 'admin_mfa_enroll';
  static const adminMfaVerify = 'admin_mfa_verify';
  static const adminMfaDisable = 'admin_mfa_disable';
  static const adminApproveProduct = 'admin_approve_product';
  static const adminRejectProduct = 'admin_reject_product';

  // === PRODUCT ENDPOINTS ===
  static const deleteProduct = 'delete_product';
  static const uploadProductImages = 'upload_product_images';
  static const uploadReviewImages = 'upload_review_images';
  static const deleteProductImages = 'delete_product_images';
  static const uploadProductVideo = 'upload_product_video';
  static const createProductAtomic = 'create_product_atomic';
  static const updateProduct = 'update_product';
  static const submitProductRating = 'submit_product_rating';
  static const submitProductRatingAtomic = 'submit_product_rating_atomic';
  static const toggleFavorite = 'toggle_favorite';
  // Review helpfulness (N-04)
  static const voteReviewHelpful = 'vote_review_helpful';
  // Back-in-stock (TASK 07)
  static const subscribeStockNotification = 'subscribe_stock_notification';
  static const unsubscribeStockNotification = 'unsubscribe_stock_notification';
  // Product Q&A (TASK 09)
  static const askProductQuestion = 'ask_product_question';
  static const answerProductQuestion = 'answer_product_question';
  static const getProductQuestions = 'get_product_questions';

  // === BULK OPERATIONS ===
  static const bulkUpdateProducts = 'bulk_update_products';

  // === WAREHOUSE ENDPOINTS ===
  static const createWarehouse = 'create_warehouse';
  static const updateWarehouse = 'update_warehouse';
  static const deleteWarehouse = 'delete_warehouse';
  static const getSellerWarehouses = 'get_seller_warehouses';

  // === ORDER ENDPOINTS ===
  static const updateOrderStatus = 'update_order_status';
  static const confirmItemReceipt = 'confirm_item_receipt';
  static const updateItemStatus = 'update_item_status';
  static const cancelOrder = 'cancel_order';
  static const refundOrderItem = 'refund_order_item';
  static const approveShippingCost = 'approve_shipping_cost';
  static const updateShippingCost = 'update_shipping_cost';

  // === PAYMENT ENDPOINTS ===
  static const createCheckoutSession = 'create_checkout_session';
  static const verifyCartPrices = 'verify_cart_prices';
  static const capturePayment = 'capture_payment';
  static const createConnectAccount = 'create_connect_account';
  static const createAccountLink = 'create_account_link';
  static const getConnectAccountStatus = 'get_connect_account_status';
  static const getPaymentProviders = 'get_payment_providers';
  static const updatePaymentProvider = 'update_payment_provider';
  static const getProviderStatus = 'get_provider_status';

  // === SUBSCRIPTION ENDPOINTS ===
  static const createSubscription = 'create_subscription';
  static const cancelSubscription = 'cancel_subscription';
  static const getSubscriptionStatus = 'get_subscription_status';
  static const reactivateSubscription = 'reactivate_subscription';

  // === USER PROFILE ENDPOINTS ===
  static const updateNotificationPreferences = 'update_notification_preferences';
  static const cleanupFcmToken = 'cleanup_fcm_token'; // T-3: FCM token cleanup on logout
  static const updateUserProfile = 'update_user_profile'; // F-006: centralized endpoint name
  // === ADDRESS MANAGEMENT ENDPOINTS (F-006) ===
  static const addBuyerAddress = 'add_buyer_address';
  static const deleteBuyerAddress = 'delete_buyer_address';
  static const updateBuyerAddress = 'update_buyer_address';
  static const setDefaultBuyerAddress = 'set_default_buyer_address';

  // === SELLER ENDPOINTS ===
  static const createStripeLoginLink = 'create_stripe_login_link';

  // === CHAT ENDPOINTS ===
  static const getOrCreateChat = 'get_or_create_chat';
  static const markMessagesRead = 'mark_messages_read';
  static const sendMessage = 'send_message';
  static const deleteMessage = 'delete_message'; // CHAT-H2/H3

  // === DIGITAL DOWNLOAD ENDPOINTS ===
  static const generateSoftwareDownloadSession = 'generate_software_download_session';
  static const generateBookDownloadSession = 'generate_book_download_session';

  // === COUPON ENDPOINTS (N-07) ===
  static const applyCoupon = 'apply_coupon';
  static const adminCreateCoupon = 'admin_create_coupon';
}

/// Firestore collection names
abstract final class Collections {
  static const users = 'users';
  static const products = 'products';
  static const orders = 'orders';
  static const payouts = 'payouts';
  static const refunds = 'refunds';
  static const webhookLogs = 'webhook_logs';
  static const webhookEvents = 'webhook_events';
  static const securityAlerts = 'security_alerts';
  static const rateLimits = 'rate_limits';
  static const config = 'config';
  static const adminLogs = 'admin_logs';
  static const productRatings = 'product_ratings';
  static const sellerRatings = 'seller_ratings'; // F-315: Separate seller performance
  static const reviewVotes = 'review_votes'; // subcollection of product_ratings/{ratingId}
  static const algoliaSyncFailures = 'algolia_sync_failures';
  static const cronLocks = '_cron_locks';
  static const cronFailures = '_cron_failures'; // M-14: Alerting on unhandled cron exceptions

  // Subcollections
  static const warehouses = 'warehouses'; // users/{sellerId}/warehouses
  static const cart = 'cart'; // users/{userId}/cart
  static const favorites = 'favorites'; // users/{userId}/favorites
  static const notifications = 'notifications'; // users/{uid}/notifications
  static const fcmTokens = 'fcm_tokens'; // users/{uid}/fcm_tokens — multi-device push tokens
  static const productQuestions = 'product_questions'; // top-level: product_questions/{questionId}
  static const addresses = 'addresses'; // users/{userId}/addresses
  static const stockNotifications = 'stock_notifications'; // Tasks 07
  static const sellerMetrics = 'seller_metrics'; // Tasks 11
  static const coupons = 'coupons'; // N-07: coupon/promo code system
  static const inventoryLevels = 'inventoryLevels'; // products/{productId}/inventoryLevels/{warehouseId}
  static const orderEvents = 'events'; // orders/{orderId}/events/{eventId}
  static const couponUses = 'coupon_uses'; // coupons/{couponId}/coupon_uses/{userId}

  // Digital Products Collections
  static const licenses = 'licenses'; // users/{userId}/licenses
  static const bookAccessTokens = 'book_access_tokens'; // users/{userId}/book_access_tokens
  static const softwareAccessTokens = 'software_access_tokens'; // users/{userId}/software_access_tokens

  // Premium & Chat collections
  static const subscriptions = 'subscriptions'; // subscriptions/{userId}
  static const chats = 'chats'; // chats/{chatId}
  static const chatMessages = 'messages'; // chats/{chatId}/messages/{msgId}

  // Security (backend-only)
  static const userSecurity = 'user_security'; // Backend-only MFA secrets — allow read: if false
  static const sellerProfiles = 'seller_profiles'; // Seller-only profile data
  static const sellerSkus = 'seller_skus'; // Collision docs for atomic SKU uniqueness

  // Email infrastructure (backend-only — never accessed from client)
  static const mailLogs = '_mail_logs'; // Transactional email delivery audit log
  static const pendingRedemptions = 'pending_redemptions'; // Pending coupon/gift card redemption records

  // Return tracking
  static const returnRequests = 'return_requests';

  // Temporary pre-verification storage (cleared after user doc creation)
  static const pendingProfiles = 'pending_profiles'; // pending_profiles/{uid}
  static const messageReports = 'message_reports'; // F-121: Flagged messages for review

  // Financial audit (backend-only)
  static const platformDebt = 'platform_debt'; // A-05/F-139: debt records when seller reversal fails due to zero balance
}

/// Confirmation values for sensitive operations requiring explicit confirmation
abstract final class ConfirmationValues {
  /// Confirmation string for account deletion
  static const deleteMyAccount = 'DELETE_MY_ACCOUNT';
}

/// Consent method values for CASL compliance tracking
abstract final class ConsentMethodValues {
  static const signup = 'signup';
  static const signupForm = 'signup_form';
  static const googleOauth = 'google_oauth';
  static const appleOauth = 'apple_oauth';
  static const checkbox = 'checkbox';
  static const doubleOptIn = 'double_opt_in';
  static const implied = 'implied';
  static const userPreference = 'user_preference';
  static const unsubscribe = 'unsubscribe';

  static const all = {signup, signupForm, googleOauth, appleOauth, checkbox, doubleOptIn, implied, userPreference, unsubscribe};
}

/// Valid values for country fields
abstract final class CountryValues {
  static const canada = 'Canada';
  static const canadaCode = 'CA';

  static const all = {canada, canadaCode};
}

/// Valid values for coupon discount types (N-07)
abstract final class CouponDiscountTypeValues {
  static const percent = 'percent';
  static const fixedCents = 'fixed_cents';

  static const all = {percent, fixedCents};
}

abstract final class CronLockStatusValues {
  static const running = 'running';
  static const completed = 'completed';
}

/// Centralized per-item delivery status transitions.
/// Must match schema_constants.py DeliveryItemStatusTransitions.VALID_TRANSITIONS.
abstract final class DeliveryItemStatusTransitions {
  static const validTransitions = <String, List<String>>{
    DeliveryStatusValues.pending: [DeliveryStatusValues.shipped],
    DeliveryStatusValues.shipped: [DeliveryStatusValues.delivered],
    DeliveryStatusValues.delivered: [DeliveryStatusValues.refunded],
    DeliveryStatusValues.refunded: [], // Terminal
  };
}

/// Valid values for deliveryStatus/status field on order items
abstract final class DeliveryStatusValues {
  static const pending = 'pending';
  static const shipped = 'shipped';
  static const delivered = 'delivered';
  static const refunded = 'refunded';

  static const all = {pending, shipped, delivered, refunded};
}

/// Valid values for delivery option types
abstract final class DeliveryTypeValues {
  static const pickup = 'pickup';
  static const standard = 'standard';
  static const express = 'express';
  static const sameDay = 'same_day';
  static const localDelivery = 'local_delivery';
  static const international = 'international';
  static const internationalExpress = 'international_express';
  static const custom = 'custom';
}

/// Valid values for supportedPlatforms field
abstract final class DigitalPlatformValues {
  static const macos = 'macos';
  static const windows = 'windows';
  static const linux = 'linux';

  static const all = [macos, windows, linux];
}

/// Valid values for digitalType field
abstract final class DigitalTypeValues {
  static const software = 'software';
  static const book = 'book';

  static const all = [software, book];
}

/// Valid values for shipping discount types
abstract final class DiscountTypeValues {
  static const percent = 'percent';
  static const fixed = 'fixed';
  static const flatRate = 'flat_rate';

  static const all = {percent, fixed, flatRate};
}

/// Singleton document IDs within collections
abstract final class Documents {
  static const paymentProviders = 'payment_providers';
}

/// Email and CASL compliance constants — Dart mirror of Python EmailConfig
abstract final class EmailConfig {
  static const supportEmail = 'support@orignaventures.ca';
  static const senderName = 'Origna GTA';
  static const copyrightText = '\u00a9 2026 Origna Ventures Inc. All rights reserved.';
  static const appTagline = "Canada's Modern Marketplace";
  static const prodUrl = 'https://orignagta.ca';

  // === CASL COMPLIANCE ===
  /// Physical mailing address — REQUIRED by CASL in every commercial email
  static const physicalAddress = 'Origna Ventures Inc., 136 Shaver Ave N, Toronto, ON M9B 4N8, Canada';

  /// GST/HST Registration Number — REQUIRED on all receipts (Excise Tax Act)
  static const gstHstNumber = '708286364RC0001';

  /// Unsubscribe URL — REQUIRED by CASL
  static const unsubscribeUrl = 'https://orignagta.ca/unsubscribe';

  /// Privacy Officer contact — REQUIRED by Quebec Law 25
  /// NOTE: Using support@ until dedicated privacy@ mailbox is provisioned
  static const privacyOfficerEmail = 'privacy@orignagta.ca';
  static const privacyOfficerName = 'Yunior Rodriguez Osorio';
}

abstract final class ErrorCodeValues {
  static const priceChanged = 'PRICE_CHANGED';
}

// =============================================================================
// EMAIL & COMPLIANCE CONFIGURATION
// =============================================================================

// =============================================================================
// EXTERNAL URLS — centralised to avoid magic strings
// =============================================================================

abstract final class ExternalUrls {
  static const stripeDashboard = 'https://dashboard.stripe.com/express';
}

// =============================================================================
// BUSINESS CONSTANTS
// =============================================================================

/// Firestore document field names.
///
/// IMPORTANT: These are the canonical field names. All code MUST use these
/// constants instead of string literals to prevent drift.
///
/// Convention:
/// - Timestamps: Use [createdAt] for creation time across ALL collections
/// - IDs: Use {entity}Id pattern (e.g., userId, productId, orderId)
/// - Amounts: Use {name}Cents for money (e.g., subtotalCents, taxAmountCents)
abstract final class Fields {
  // === COMMON TIMESTAMPS (used across multiple collections) ===
  static const createdAt = 'createdAt';
  static const updatedAt = 'updatedAt';
  static const version = 'version'; // Optimistic concurrency version, starts at 1
  static const schemaVersion = 'schemaVersion'; // Schema layout version for migration tracking
  static const savedAt = 'savedAt'; // N-05: Save for Later timestamp
  static const String deletedAt = 'deletedAt';
  static const String deletedBy = 'deletedBy';
  static const String deleted = 'deleted';
  static const String anonymizedAt = 'anonymizedAt';
  static const String originalUserDeleted = 'originalUserDeleted';

  // === USER FIELDS ===
  static const uid = 'uid';
  static const email = 'email';
  static const name = 'name';
  static const roles = 'roles';
  static const address = 'address';
  static const customerId = 'customerId';
  static const fcmToken = 'fcmToken';
  static const fcmTokenUpdatedAt = 'fcmTokenUpdatedAt';
  static const fcmTokenKey = 'token'; // Field name inside fcm_tokens subcollection docs
  static const lastCheckoutSession = 'lastCheckoutSession';
  static const lastOrderId = 'lastOrderId';
  static const lastCheckoutTimestamp = 'lastCheckoutTimestamp';
  static const stripeAccountId = 'stripeAccountId';
  static const snapshotAccountId = 'snapshotAccountId';
  static const liveAccountId = 'liveAccountId';
  static const payoutsEnabled = 'payoutsEnabled';
  static const chargesEnabled = 'chargesEnabled';
  static const onboardingCompleted = 'onboardingCompleted';
  static const pendingRequirements = 'pendingRequirements';
  static const paymentProvider = 'paymentProvider';
  static const oldEnabled = 'oldEnabled';
  static const newEnabled = 'newEnabled';
  static const suspended = 'suspended';
  static const suspendedAt = 'suspendedAt';
  static const unsuspendedAt = 'unsuspendedAt';
  static const unsuspendedBy = 'unsuspendedBy';
  static const suspendedBy = 'suspendedBy';
  static const suspensionReason = 'suspensionReason';
  static const commissionRateBps = 'commissionRateBps'; // 250 = 2.50% (basis points)
  static const verified = 'verified';
  static const verificationStatus = 'verificationStatus';
  static const platform = 'platform';
  static const businessName = 'businessName';
  static const payoutHoldDays = 'payoutHoldDays';
  static const avgRating = 'avgRating';
  static const totalReviews = 'totalReviews';
  static const itemRating = 'rating'; // F-315: Product quality rating
  static const itemRatingCount = 'ratingCount'; // F-315: Number of product reviews
  static const totalSales = 'totalSales';
  static const bankAccountLast4 = 'bankAccountLast4';
  static const acceptsReturns = 'acceptsReturns';
  static const returnWindowDaysField = 'returnWindowDays'; // seller-profile field name

  // === USER MFA FIELDS (admin only) ===
  static const mfaEnabled = 'mfaEnabled';
  static const mfaSecret = 'mfaSecret';
  static const mfaSecretTemp = 'mfaSecretTemp';
  static const mfaFailedAttempts = 'mfaFailedAttempts';
  static const mfaLockoutUntil = 'mfaLockoutUntil';
  static const lastMfaVerify = 'lastMfaVerify';
  static const mfaBackupCodes = 'mfaBackupCodes';
  static const mfaBackupCodesTemp = 'mfaBackupCodesTemp';
  static const mfaBackupCodesSalt = 'mfaBackupCodesSalt';
  static const mfaEnrolledAt = 'mfaEnrolledAt';
  static const lastRoleUpdate = 'lastRoleUpdate';
  static const lastRoleUpdateBy = 'lastRoleUpdateBy';

  // === USER PROFILE FIELDS (missing, synced from Python) ===
  static const sellerProfile = 'sellerProfile';
  static const businessAddress = 'businessAddress';
  static const fullName = 'fullName';
  static const isCorporate = 'isCorporate';
  static const bankDetails = 'bankDetails';

  // === PRODUCT FIELDS ===
  static const productId = 'productId';
  static const madeInCountry = 'madeInCountry'; // F-277: For USMCA/Origin differentiation
  static const price = 'price';
  static const priceCents = 'priceCents'; // Integer cents derived from price — use for arithmetic

  /// Original/crossed-out price for sale display (null = no active sale)
  static const compareAtPrice = 'compareAtPrice';
  static const compareAtPriceHistory = 'compareAtPriceHistory';
  static const description = 'description';
  static const nameF = 'nameF';
  static const descriptionF = 'descriptionF';
  static const imageUrls = 'imageUrls';
  static const sellerId = 'sellerId';
  static const sellerAddress = 'sellerAddress';
  static const sellerSku = 'sellerSku';
  static const sellerName = 'sellerName'; // Seller display name snapshotted at purchase time
  static const warehouseIds = 'warehouseIds';
  static const warehouseStock = 'warehouseStock';
  static const warehouseStockMap = 'warehouseStockMap'; // per-warehouse stock allocation: {warehouseId: qty}
  static const fulfillmentWarehouseId = 'fulfillmentWarehouseId'; // TASK 02: warehouse used to fulfill order item
  static const shipFromCity = 'shipFromCity';
  static const shipFromProvince = 'shipFromProvince';
  static const shipFromCountry = 'shipFromCountry';
  static const shipFromCountries = 'shipFromCountries';
  static const primaryWarehouseId = 'primaryWarehouseId';
  static const categoryId = 'categoryId';
  static const stockQuantity = 'stockQuantity';
  static const rating = 'rating';
  static const ratingCount = 'ratingCount';
  static const sellerRating = 'sellerRating'; // F-315: Average seller rating
  static const sellerRatingCount = 'sellerRatingCount'; // F-315: Number of seller ratings
  static const keywords = 'keywords';
  static const approvalRejectionReason = 'approvalRejectionReason';
  static const lifecycleStatus = 'lifecycleStatus';
  static const isDigital = 'isDigital';
  static const isAgeRestricted = 'isAgeRestricted'; // Product requires buyer age 18+ confirmation
  // Digital product extended fields
  static const digitalType = 'digitalType';
  static const slug = 'slug';
  static const digitalBuilds = 'digitalBuilds';
  // bookSourceUrl intentionally server-side only — do NOT expose in client
  static const deviceLimit = 'deviceLimit';
  static const licenseKey = 'licenseKey';
  static const digitalUnlocked = 'digitalUnlocked';
  static const supportedPlatforms = 'supportedPlatforms';
  static const activations = 'activations';
  static const deviceId = 'deviceId';
  static const lastVerifiedAt = 'lastVerifiedAt';
  static const accessToken = 'accessToken';
  static const productName = 'productName'; // stored in license doc; denormalized from product
  static const weightKg = 'weightKg';
  static const weightUnit = 'weightUnit'; // F-280: 'kg' or 'lb'
  static const lengthCm = 'lengthCm';
  static const widthCm = 'widthCm';
  static const heightCm = 'heightCm';
  static const dimensionUnit = 'dimensionUnit'; // F-280: 'cm' or 'in'
  static const isLocalDeliveryOnly = 'isLocalDeliveryOnly';
  static const isPerishable = 'isPerishable';
  static const estimatedShipDays = 'estimatedShipDays';
  static const deliveryOptions = 'deliveryOptions';
  static const estimatedDays = 'estimatedDays';
  static const cost = 'cost';
  static const costCents = 'costCents';
  static const minimumOrderQuantity = 'minimumOrderQuantity';
  static const freeShipping = 'freeShipping';
  static const taxCode = 'taxCode';
  static const videoUrl = 'videoUrl';
  static const videoDurationSeconds = 'videoDurationSeconds';
  static const isInternational = 'isInternational';
  static const supplierType = 'supplierType';
  static const isRelatedParty = 'isRelatedParty'; // F-312: Gaming prevention
  static const supplier = 'supplier';
  static const supplierSku = 'supplierSku'; // Supplier's product SKU (internal use, not exposed to buyers)
  static const supplierUrl = 'supplierUrl'; // Direct URL to supplier product (internal use, not exposed to buyers)
  static const inventory = 'inventory';
  // Inventory sub-fields (keys inside the `inventory` map)
  static const allowBackorder = 'allowBackorder';
  static const lowStockThreshold = 'lowStockThreshold';
  static const trackQuantity = 'trackQuantity';
  static const reservationHoldMinutes = 'reservationHoldMinutes';
  // Inventory levels subcollection fields
  static const availableQuantity = 'availableQuantity';
  static const reservedQuantity = 'reservedQuantity';
  static const lastSyncedAt = 'lastSyncedAt';
  static const status = 'status';
  static const deliverySpeed = 'deliverySpeed';

  // === RETURN REQUEST FIELDS ===
  static const returnId = 'returnId';
  static const returnStatus = 'returnStatus';
  static const returnReason = 'returnReason';
  static const returnTrackingNumber = 'returnTrackingNumber';
  static const returnRefundAmountCents = 'returnRefundAmountCents';
  static const returnAdminNote = 'returnAdminNote';

  // === ORDER FIELDS ===
  static const orderId = 'orderId';
  static const userId = 'userId';
  static const customerEmail = 'customerEmail';
  static const items = 'items';
  static const sellerIds = 'sellerIds';
  static const subtotalCents = 'subtotalCents';
  static const taxes = 'taxes';
  static const taxAmountCents = 'taxAmountCents';
  static const shippingCostCents = 'shippingCostCents';
  static const itemShippingCents = 'itemShippingCents';
  static const sellerShippingCosts = 'sellerShippingCosts'; // Map<sellerId, cents> for multi-seller orders
  static const shippingCostDeltaCents = 'shippingCostDeltaCents';
  static const totalAmountCents = 'totalAmountCents';
  static const currency = 'currency';
  static const orderStatus = 'orderStatus';
  static const paymentStatus = 'paymentStatus';
  static const shippingAddress = 'shippingAddress';
  static const stripeSessionId = 'stripeSessionId';
  static const stripePaymentIntentId = 'stripePaymentIntentId';
  static const captureAttempts = 'captureAttempts';
  static const fraudScore = 'fraudScore';
  static const sellerCaptures = 'sellerCaptures';
  static const capturedAt = 'capturedAt';
  static const expiresAt = 'expiresAt';
  static const confirmedByClient = 'confirmedByClient';
  static const confirmedAt = 'confirmedAt';
  static const autoConfirmed = 'autoConfirmed';
  static const autoCaptured = 'autoCaptured';
  static const sellerPayouts = 'sellerPayouts';
  static const platformFeeTotalCents = 'platformFeeTotalCents';
  static const platformFeeRatio = 'platformFeeRatio'; // Stored at checkout for capture-time fee rate
  static const payoutStatus = 'payoutStatus';
  static const ratings = 'ratings';
  static const orderRefundCents = 'refundAmountCents';
  static const refundAmount = 'refundAmount';
  static const refundedAt = 'refundedAt';
  static const shippingApprovalStatus = 'shippingApprovalStatus';
  static const shippingApprovalRequired = 'shippingApprovalRequired';
  static const actualShippingCents = 'actualShippingCents';
  static const pendingTotalCents = 'pendingTotalCents';
  static const requiresManualReview = 'requiresManualReview';
  static const manualReviewReason = 'manualReviewReason';
  static const payoutErrors = 'payoutErrors';

  // === STRIPE METADATA FIELDS ===
  static const metadataPlatformFee = 'platformFee';

  static const paymentCompletedAt = 'paymentCompletedAt';
  static const paymentError = 'paymentError';

  // === ORDER FIELDS (missing from Dart, present in Python) ===
  static const shippingApproval = 'shippingApproval';
  static const stockRestored = 'stockRestored';
  static const lastLowStockAlertAt = 'lastLowStockAlertAt';
  static const cancelledBy = 'cancelledBy';
  static const cancelledAt = 'cancelledAt';
  static const cancellationReason = 'cancellationReason';
  static const respondedAt = 'respondedAt';
  static const actualCost = 'actualCost';
  static const taxCents = 'taxCents';
  static const taxRate = 'taxRate';
  static const lastCaptureError = 'lastCaptureError';
  static const sellerStripeAccounts = 'sellerStripeAccounts';
  static const archivedAt = 'archivedAt';
  static const updatedBy = 'updatedBy';
  static const originalCostCents = 'originalCostCents';
  static const newCostCents = 'newCostCents';
  static const requestedBy = 'requestedBy';
  static const requestedAt = 'requestedAt';
  static const action = 'action';
  static const productIds = 'productIds';
  static const customerName = 'customerName';
  static const searchKeywords = 'searchKeywords';
  static const deactivationReason = 'deactivationReason';
  static const retries = 'retries';

  // === NOTIFICATIONS / PUSH / ACTOR ===
  static const notificationsSent = 'notificationsSent';
  static const pushEnabled = 'pushEnabled';
  static const lastActorId = 'lastActorId';
  static const isSeller = 'isSeller';
  static const hasDispute = 'hasDispute';
  static const sellerAmountCents = 'sellerAmountCents';
  static const escalatedAt = 'escalatedAt';
  static const escalationReason = 'escalationReason';

  // === TAX FIELDS (new) ===
  static const itemTaxes = 'itemTaxes';
  static const taxExempt = 'taxExempt';
  static const taxExemption = 'taxExemption';
  static const gstNumber = 'gstNumber';

  // === CONSENT & COMPLIANCE FIELDS (CASL + PIPEDA + Quebec Law 25) ===
  static const emailConsent = 'emailConsent';
  static const marketingOptIn = 'marketingOptIn';
  static const consentTimestamp = 'consentTimestamp';
  static const consentMethod = 'consentMethod';
  static const englishOnlyConsent = 'englishOnlyConsent'; // F-279: Bill 96 compliance
  static const dateOfBirth = 'dateOfBirth'; // F-282: age verification (ISO YYYY-MM-DD)
  static const privacyAcceptedAt = 'privacyAcceptedAt';
  static const termsAcceptedAt = 'termsAcceptedAt';
  static const privacyPolicyVersion = 'privacyPolicyVersion';
  static const termsVersion = 'termsVersion';
  static const preferredLanguage = 'preferredLanguage';
  static const unsubscribedAt = 'unsubscribedAt';
  static const dataProcessingConsent = 'dataProcessingConsent';

  // === PREMIUM SUBSCRIPTION FIELDS ===
  static const isPremium = 'isPremium';
  static const premiumSince = 'premiumSince';
  static const premiumExpiresAt = 'premiumExpiresAt';
  static const stripeSubscriptionId = 'stripeSubscriptionId';
  static const notifyNewProducts = 'notifyNewProducts';
  static const notifyTrending = 'notifyTrending';

  // === TRENDING PRODUCT FIELDS ===
  static const trendingScore = 'trendingScore';
  static const viewCount = 'viewCount';
  static const isTrending = 'isTrending';
  static const trendingAt = 'trendingAt';
  static const purchaseCount = 'purchaseCount';

  // === SUBSCRIPTION DOCUMENT FIELDS ===
  // Note: subscription.status uses the generic Fields.status constant ('status')
  static const currentPeriodStart = 'currentPeriodStart';
  static const currentPeriodEnd = 'currentPeriodEnd';
  static const cancelAtPeriodEnd = 'cancelAtPeriodEnd';
  static const cancelScheduledAt = 'cancelScheduledAt'; // datetime — when cancellation was requested

  // === CHAT FIELDS ===
  static const chatId = 'chatId';
  static const reportId = 'reportId';
  static const reporterId = 'reporterId';
  static const messageId = 'messageId';
  static const buyerId = 'buyerId';
  static const productTitle = 'productTitle';
  static const productImageUrl = 'productImageUrl';
  static const lastMessage = 'lastMessage'; // truncated for preview
  static const lastMessageText = 'lastMessageText'; // full text
  static const lastMessageAt = 'lastMessageAt';
  static const senderId = 'senderId';
  static const senderDisplayName = 'senderDisplayName'; // denormalized at send time
  static const messageText = 'text';
  static const isRead = 'read';
  static const buyerUnreadCount = 'buyerUnreadCount';
  static const sellerUnreadCount = 'sellerUnreadCount';
  static const firstBuyerMessageAt = 'firstBuyerMessageAt';
  static const firstSellerReplyAt = 'firstSellerReplyAt';
  static const firstReplyHours = 'firstReplyHours';
  static const messageCount = 'messageCount';

  // === DELIVERY FIELDS ===
  static const deliveryInstructions = 'deliveryInstructions';

  // === CART / ORDER ITEM NOTE ===
  static const buyerNote = 'buyerNote';
  static const cartItemId = 'cartItemId';
  static const shippingDiffCents = 'shippingDiffCents'; // recorded when PI is already captured (F-002)
  static const taxDiffCents = 'taxDiffCents'; // recorded when PI is already captured (F-002)
  static const priceSnapshot = 'priceSnapshot';

  // === FIELDS missing from Dart (present in Python) ===
  static const archived = 'archived';

  // === ORDER ITEM FIELDS ===
  static const quantity = 'quantity';
  static const trackingNumber = 'trackingNumber';
  static const carrier = 'carrier';
  static const carrierNote = 'carrierNote'; // Free-text override when carrier='other'
  static const shippedAt = 'shippedAt';
  static const deliveredAt = 'deliveredAt';
  static const refundReason = 'refundReason';
  static const refundAmountCents = 'refundAmountCents';
  static const refundId = 'refundId';
  static const confirmedByBuyer = 'confirmedByBuyer';

  // === DELIVERY / SHIPPING SUB-FIELDS ===
  static const shippingDays = 'shippingDays';
  static const hasTracking = 'hasTracking';
  static const maxItemsPerShipment = 'maxItemsPerShipment';
  static const additionalItemCostCents = 'additionalItemCostCents';
  static const availableNationwide = 'availableNationwide';
  static const quantityDiscounts = 'quantityDiscounts';
  static const discountType = 'discountType';
  static const discountValue = 'discountValue';
  static const minQuantity = 'minQuantity';

  // === PAYOUT FIELDS ===
  static const amountCents = 'amountCents';
  static const platformFeeCents = 'platformFeeCents';
  static const netAmountCents = 'netAmountCents';
  static const feeRate = 'feeRate';
  static const stripeTransferId = 'stripeTransferId';
  static const reversalId = 'reversalId';
  static const partialReversals = 'partialReversals';
  static const disputeId = 'disputeId';
  static const preDisputeStatus = 'preDisputeStatus';
  static const disputeStatus = 'disputeStatus';
  static const disputeResolvedAt = 'disputeResolvedAt';
  static const disputeResolution = 'disputeResolution';
  static const failureReason = 'failureReason';
  static const payoutDate = 'payoutDate';
  static const reversedAt = 'reversedAt';
  static const cumulativeRefundedCents = 'cumulativeRefundedCents';
  static const partialRefundAmountCents = 'partialRefundAmountCents';
  static const transfersReversed = 'transfersReversed';
  static const disputedAt = 'disputedAt';
  static const cumulativeReversedCents = 'cumulativeReversedCents';
  static const reversalReason = 'reversalReason';
  static const paymentIntentId = 'paymentIntentId';
  static const transferId = 'transferId';

  // === WEBHOOK FIELDS ===
  static const eventId = 'eventId';
  static const eventType = 'eventType';
  static const actor = 'actor';
  static const actorType = 'actorType';
  static const fromStatus = 'fromStatus';
  static const toStatus = 'toStatus';
  static const payloadSize = 'payloadSize';
  static const signatureVerified = 'signatureVerified';
  static const processingStatus = 'processingStatus';
  static const errorMessage = 'errorMessage';
  static const receivedAt = 'receivedAt';
  static const processed = 'processed';
  static const processedAt = 'processedAt';
  static const livemode = 'livemode';

  // === ADDRESS FIELDS ===
  static const formattedAddress = 'formattedAddress';
  static const street = 'street';
  static const apartment = 'apartment';
  static const city = 'city';
  static const state = 'state';
  static const postalCode = 'postalCode';
  static const country = 'country';
  static const phoneNumber = 'phoneNumber';
  static const isDefault = 'isDefault';
  static const label = 'label';
  static const latitude = 'latitude';
  static const longitude = 'longitude';

  // === PAYOUT/REFUND COMMON FIELDS ===
  static const provider = 'provider';
  static const amount = 'amount';
  static const completedAt = 'completedAt';
  static const failedAt = 'failedAt';
  static const error = 'error';
  static const paymentId = 'paymentId';

  // === SECURITY ALERT FIELDS ===
  static const type = 'type';
  static const severity = 'severity';
  static const resolved = 'resolved';
  static const resolvedAt = 'resolvedAt';

  // === NEW FEATURE FIELDS (TASKS 05-11) ===
  static const addressId = 'addressId';
  static const addressCount = 'addressCount';
  static const reviewImageUrls = 'reviewImageUrls';
  static const reviewText = 'reviewText';
  static const verifiedPurchase = 'verifiedPurchase';
  static const isFlagged = 'isFlagged';
  static const hasPhotos = 'hasPhotos';
  static const notifiedAt = 'notifiedAt';
  static const subscribedAt = 'subscribedAt';
  static const questionText = 'question';
  static const bookAccessToken = 'bookAccessToken';
  static const bookSourceUrl = 'bookSourceUrl';
  static const answerText = 'answer';
  static const answeredAt = 'answeredAt';
  static const answeredBy = 'answeredBy';
  static const isAnswered = 'isAnswered';
  static const upvotes = 'upvotes';
  static const askerId = 'askerId';
  static const questionId = 'questionId';
  static const lastCartAbandonEmailAt = 'lastCartAbandonEmailAt';
  static const disputeRate = 'disputeRate';
  static const refundRate = 'refundRate';
  static const cancellationRate = 'cancellationRate';
  static const lateShipmentRate = 'lateShipmentRate';
  static const avgResponseTimeHours = 'avgResponseTimeHours';
  static const avgShipDays = 'avgShipDays';
  static const positiveRatePct = 'positiveRatePct';
  static const breaches = 'breaches';
  static const totalOrders = 'totalOrders';
  static const totalOrders30d = 'totalOrders30d';
  static const totalRevenueCents30d = 'totalRevenueCents30d';
  static const computedAt = 'computedAt';

  static const resolution = 'resolution';
  static const timestamp = 'timestamp';
  static const chargeId = 'chargeId';
  static const accountId = 'accountId';
  static const reason = 'reason';
  static const revokedLicenseCount = 'revokedLicenseCount';
  static const destination = 'destination';
  static const failureMessage = 'failureMessage';
  static const adminId = 'adminId';
  // Alert data fields
  static const firestoreCount = 'firestoreCount';
  static const algoliaCount = 'algoliaCount';
  static const mismatchPercent = 'mismatchPercent';
  static const reversalErrors = 'reversalErrors';
  static const payoutId = 'payoutId';
  static const errorCode = 'errorCode';
  static const targetUserId = 'targetUserId';
  static const oldRoles = 'oldRoles';
  static const newRoles = 'new_roles';
  static const productsDeactivated = 'productsDeactivated';
  static const ordersCancelled = 'ordersCancelled';

  // === RATE LIMIT FIELDS ===
  static const count = 'count';
  static const firstRequest = 'first_request';
  static const lastRequest = 'last_request';

  // === CRON LOCK FIELDS ===
  static const lockedAt = 'lockedAt';
  static const lockedBy = 'lockedBy';

  // === CRON FAILURE FIELDS (M-14) ===
  static const jobName = 'jobName';
  static const errorType = 'errorType';

  // === ALGOLIA SYNC FAILURE FIELDS ===
  static const retryCount = 'retryCount';
  static const maxRetriesExceeded = 'maxRetriesExceeded';
  static const lastRetryError = 'lastRetryError';

  // === WEBHOOK EVENT FIELDS ===
  static const clientIp = 'clientIp';

  // === CART & FAVORITES FIELDS ===
  static const dateFavorited = 'dateFavorited';
  static const favoriteCount = 'favoriteCount';

  // === ALTERNATE FIELD NAMES (used in Firestore deserialization fallbacks) ===
  /// Alternate name for [confirmedByBuyer]
  static const buyerConfirmed = 'buyerConfirmed';

  /// Alternate name for [isLocalDeliveryOnly]
  static const localDeliveryOnly = 'localDeliveryOnly';

  /// Alternate name for [isPerishable]
  static const perishable = 'perishable';

  /// Alternate name for [estimatedShipDays]
  static const supplierShippingDays = 'supplierShippingDays';

  /// Alternate name for [minimumOrderQuantity]
  static const minOrderQuantity = 'minOrderQuantity';

  // === LOWERCASE TAX KEYS (used in JSON API responses) ===
  /// Lowercase variant of [GST] for JSON responses
  static const gst = 'gst';

  /// Lowercase variant of [PST] for JSON responses
  static const pst = 'pst';

  /// Lowercase variant of [HST] for JSON responses
  static const hst = 'hst';

  /// Lowercase variant of [QST] for JSON responses
  static const qst = 'qst';

  // === REVIEW/RATING FIELDS ===
  static const review = 'review';
  static const comment = 'comment';

  // === TAX FIELDS ===
  // ignore: constant_identifier_names
  static const GST = 'GST';
  // ignore: constant_identifier_names
  static const PST = 'PST';
  // ignore: constant_identifier_names
  static const HST = 'HST';
  // ignore: constant_identifier_names
  static const QST = 'QST';

  // === API REQUEST/RESPONSE FIELDS ===
  static const fileName = 'fileName';
  static const uploadUrl = 'uploadUrl';
  static const confirmation = 'confirmation';

  // === N-03/N-04: Product ratings ===
  static const ratingId = 'ratingId';
  static const reviewId = 'reviewId';
  static const flagged = 'flagged';

  // === N-03: Seller reply to reviews ===
  static const sellerReply = 'sellerReply';
  static const sellerReplyAt = 'sellerReplyAt';

  // === N-04: Review helpfulness voting ===
  static const helpfulCount = 'helpfulCount';
  static const helpfulVoterIds = 'helpfulVoterIds';

  // === N-06: Price history ===
  static const priceHistory = 'priceHistory';

  // === N-07: Coupon/promo code system ===
  static const couponCode = 'couponCode';
  static const couponPrereserved = 'couponPrereserved';
  static const couponSellerId = 'couponSellerId'; // seller_id of scoped coupon (null = platform-wide)
  static const discountAmountCents = 'discountAmountCents';
  static const minOrderCents = 'minOrderCents';
  static const maxUsesTotal = 'maxUsesTotal';
  static const maxUsesPerUser = 'maxUsesPerUser';
  static const usedCount = 'usedCount';
  static const useCount = 'useCount'; // coupon_uses subcollection: per-user use count
  static const usedAt = 'usedAt'; // coupon_uses subcollection: first use timestamp
  static const lastUsedAt = 'lastUsedAt'; // coupon_uses subcollection: most recent use timestamp

  // === N-09: Product variants ===
  static const hasVariants = 'hasVariants';
  static const variants = 'variants';
  static const variantId = 'variantId';
  static const variantKey = 'variantKey';
  static const variantOptions = 'variantOptions';
  static const variantTitle = 'variantTitle';
  static const variantSku = 'variantSku';
  static const optionValues = 'optionValues';

  // === N-11: Subcategories ===
  static const subcategory = 'subcategory';
  static const condition = 'condition'; // Product condition: new|like_new|good|fair|for_parts
  static const isSmallSupplier = 'isSmallSupplier';
}

// =============================================================================
// CATEGORY IDS
// =============================================================================

/// Filter sentinel values — special values used in query filters to mean "no filter"
abstract final class FilterValues {
  /// Special filter value meaning "show all items regardless of status"
  static const all = 'all';
}

/// Geographic constants
abstract final class GeoValues {
  static const countryCanada = 'Canada';
}

/// Language preference defaults (ISO 639-1 codes)
abstract final class LanguageValues {
  static const english = 'en';
  static const french = 'fr';
}

/// Valid values for license status field
abstract final class LicenseStatusValues {
  static const active = 'active';
  static const revoked = 'revoked';
  static const all = [active, revoked];
  LicenseStatusValues._();
}

/// SharedPreferences keys for client-side persistence.
abstract final class LocalStorageKeys {
  /// JSON-encoded `List<String>` of recent product IDs (max 10). Written by product detail screen.
  static const recentlyViewed = 'recently_viewed';

  /// JSON-encoded `List<String>` of recent search queries (max 5).
  static const recentSearches = 'recent_searches';
}

// =============================================================================
// API KEYS - Cloud Function request/response parameter names
// =============================================================================

// =============================================================================
// NOTIFICATION TYPES - Parity with Python NotificationTypes
// =============================================================================

abstract final class NotificationTypes {
  static const orderStatus = 'order_status';
  static const orderUpdate = 'order_update';
  static const newMessage = 'new_message';
  static const promo = 'promo';
  static const system = 'system';
  static const account = 'account';
  static const returnRequest = 'return_request';
  static const returnStatus = 'return_status';
  static const backInStock = 'back_in_stock';
  static const refundIssued = 'refund_issued';
  static const messageReport = 'message_report'; // F-121: Flagged chat message
  static const perishableOrderUrgent = 'perishable_order_urgent'; // GAP-13: Urgent perishable order alert to seller

  static const all = {
    orderStatus,
    orderUpdate,
    newMessage,
    promo,
    system,
    account,
    returnRequest,
    returnStatus,
    backInStock,
    refundIssued,
    messageReport,
    perishableOrderUrgent,
  };
}

// =============================================================================
// CLOUD FUNCTION ENDPOINTS - Single source of truth for all Firebase callable names
// =============================================================================

// =============================================================================
// ORDER EVENT TYPES — tracks every status transition
// =============================================================================

abstract final class OrderEventTypes {
  static const statusChanged = 'status_changed';
  static const paymentAuthorized = 'payment_authorized';
  static const paymentCaptured = 'payment_captured';
  static const paymentFailed = 'payment_failed';
  static const refundIssued = 'refund_issued';
  static const itemShipped = 'item_shipped';
  static const itemDelivered = 'item_delivered';
  static const cancellationConfirmed = 'cancellation_confirmed';
  static const noteAdded = 'note_added';
  static const autoConfirmed = 'auto_confirmed';
  static const orderConfirmedBuyer = 'order_confirmed_buyer';
  static const orderConfirmedSeller = 'order_confirmed_seller';
  static const disputeCreated = 'dispute_created';
  static const disputeResolved = 'dispute_resolved';
  static const refundInitiated = 'refund_initiated';
  static const itemStatusChanged = 'item_status_changed';
}

/// Special values for itemId parameter in updateItemStatus.
/// Convention: 'all' means apply the status change to the entire order (all items).
abstract final class OrderItemIdValues {
  /// Apply status change to all items in the order
  static const all = 'all';
}

/// Valid values for orderStatus field
abstract final class OrderStatusValues {
  static const pending = 'pending';
  static const confirmed = 'confirmed';
  static const processing = 'processing';
  static const shipped = 'shipped';
  static const inTransit = 'in_transit';
  static const delivered = 'delivered';
  static const cancelled = 'cancelled';
  static const failed = 'failed';
  static const expired = 'expired';
  static const disputed = 'disputed';

  static const all = {pending, confirmed, processing, shipped, inTransit, delivered, cancelled, failed, expired, disputed, refunded, partiallyRefunded};

  static const refunded = 'refunded';
  static const partiallyRefunded = 'partially_refunded';

  /// Centralized state machine — single source of truth for order transitions.
  /// Must match schema_constants.py OrderStatusValues.VALID_TRANSITIONS.
  static const validTransitions = <String, List<String>>{
    pending: [confirmed, cancelled, failed, expired],
    confirmed: [processing, cancelled, expired],
    processing: [shipped, cancelled],
    shipped: [inTransit, delivered],
    inTransit: [delivered, cancelled],
    delivered: [disputed], // Must dispute first; refund is resolved via disputed state
    cancelled: [], // Terminal
    failed: [pending], // Retry
    expired: [pending], // Retry
    disputed: [], // Terminal via Stripe webhook only — resolved by charge.refunded or dispute.closed events
    refunded: [], // Terminal
    partiallyRefunded: [], // Terminal
  };

  /// Terminal states — no further transitions allowed.
  static const terminalStates = {cancelled, refunded, partiallyRefunded};
}

/// Valid values for payment provider
abstract final class PaymentProviderValues {
  static const stripe = 'stripe';

  static const all = {stripe};
}

/// Valid values for paymentStatus field
abstract final class PaymentStatusValues {
  static const awaitingPayment = 'awaiting_payment';
  static const processing = 'processing';
  static const paid = 'paid';
  static const paymentFailed = 'payment_failed';
  static const refunded = 'refunded';
  static const partiallyRefunded = 'partially_refunded';
  static const sessionExpired = 'session_expired';
  static const authorized = 'authorized';
  static const captured = 'captured';
  static const cancelled = 'cancelled';
  static const authorizationExpired = 'authorization_expired';
  static const disputed = 'disputed';
  // Transitional states (internal use, not stored long-term)
  static const capturing = 'capturing';
  static const cancelling = 'cancelling';
  static const expiring = 'expiring';
  static const voided = 'voided';
  static const cancelFailed = 'cancel_failed';

  static const all = {
    awaitingPayment,
    processing,
    paid,
    paymentFailed,
    refunded,
    partiallyRefunded,
    sessionExpired,
    authorized,
    captured,
    cancelled,
    authorizationExpired,
    disputed,
    capturing,
    cancelling,
    expiring,
    voided,
    cancelFailed,
  };
}

/// Valid values for payoutStatus field
abstract final class PayoutStatusValues {
  static const pending = 'pending';
  static const processing = 'processing';
  static const completed = 'completed';
  static const partial = 'partial';
  static const failed = 'failed';
  static const reversed = 'reversed';
  static const partiallyReversed = 'partially_reversed';
  static const reversedDispute = 'reversed_dispute';

  static const all = {pending, processing, completed, partial, failed, reversed, partiallyReversed, reversedDispute};
}

// =============================================================================
// SYSTEM VALUES - Default values and system constants (not user-facing)
// =============================================================================

abstract final class PlaceholderAddressValues {
  static const unknownText = 'N/A';
  static const defaultState = 'ON';
  static const defaultPostalCode = 'M5V 3A8';
  static const defaultCountry = 'Canada';
}

/// Default policy/terms version numbers
abstract final class PolicyVersionValues {
  static const defaultVersion = '1.0';
}

/// Product condition values for marketplace-style listings
abstract final class ProductConditionValues {
  static const newCondition = 'new';
  static const likeNew = 'like_new';
  static const good = 'good';
  static const fair = 'fair';
  static const forParts = 'for_parts';

  static const all = {newCondition, likeNew, good, fair, forParts};
}

/// Single lifecycle status replacing isActive + status + approvalStatus.
/// State machine: draft → under_review → approved → active → paused | archived
abstract final class ProductLifecycleStatusValues {
  static const draft = 'draft';
  static const underReview = 'under_review';
  static const approved = 'approved';
  static const active = 'active';
  static const paused = 'paused';
  static const archived = 'archived';
  static const rejected = 'rejected';
}

/// Canadian province code values
abstract final class ProvinceCodeValues {
  static const alberta = 'AB';
  static const britishColumbia = 'BC';
  static const manitoba = 'MB';
  static const newBrunswick = 'NB';
  static const newfoundland = 'NL';
  static const northwestTerritories = 'NT';
  static const novaScotia = 'NS';
  static const nunavut = 'NU';
  static const ontario = 'ON';
  static const princeEdwardIsland = 'PE';
  static const quebec = 'QC';
  static const saskatchewan = 'SK';
  static const yukon = 'YT';

  static const all = [
    alberta,
    britishColumbia,
    manitoba,
    newBrunswick,
    newfoundland,
    northwestTerritories,
    novaScotia,
    nunavut,
    ontario,
    princeEdwardIsland,
    quebec,
    saskatchewan,
    yukon,
  ];

  static const names = {
    alberta: 'Alberta',
    britishColumbia: 'British Columbia',
    manitoba: 'Manitoba',
    newBrunswick: 'New Brunswick',
    newfoundland: 'Newfoundland and Labrador',
    northwestTerritories: 'Northwest Territories',
    novaScotia: 'Nova Scotia',
    nunavut: 'Nunavut',
    ontario: 'Ontario',
    princeEdwardIsland: 'Prince Edward Island',
    quebec: 'Quebec',
    saskatchewan: 'Saskatchewan',
    yukon: 'Yukon',
  };
}

/// Action identifiers for rate limiting to prevent magic strings.
abstract final class RateLimitActions {
  static const verifyCart = 'verify_cart_prices';
  static const createCheckout = 'create_checkout';
  static const stripeWebhook = 'stripe_webhook';
  static const unsubscribe = 'unsubscribe_email';
  static const exportData = 'export_data';
  static const mfaEnroll = 'mfa_enroll';
  static const mfaVerify = 'mfa_verify';
  static const mfaDisable = 'mfa_disable';
  static const mfaBackupVerify = 'mfa_backup_verify';
  static const createConnectAccount = 'create_connect_account';
  static const createAccountLink = 'create_account_link';
  static const getConnectStatus = 'get_connect_account_status';
  static const capturePayment = 'capture_payment';
  static const updateUserRoles = 'update_user_roles';
  static const suspendSeller = 'suspend_seller';
  static const unsuspendSeller = 'unsuspend_seller';
  static const adminUpdateStock = 'admin_update_stock';
  static const deleteAccount = 'delete_account';
  static const updateOrderStatus = 'update_order_status';
  static const updateItemStatus = 'update_item_status';
  static const cancelOrder = 'cancel_order';
  static const refundOrderItem = 'refund_order_item';
  static const approveShippingCost = 'approve_shipping_cost';
  static const updateShippingCost = 'update_shipping_cost';
  static const createReturnRequest = 'create_return_request';
  static const approveReturnRequest = 'approve_return_request';
  static const rejectReturnRequest = 'reject_return_request';
  static const escalateReturnRequest = 'escalate_return_request';
  static const uploadImages = 'upload_images';
  static const uploadVideo = 'upload_video';
  static const deleteProduct = 'delete_product';
  static const submitRating = 'submit_rating';
  static const createProduct = 'create_product';
  static const configureAlgolia = 'configure_algolia';
  static const getProducts = 'get_products';
  static const getSellerProducts = 'get_seller_products';
  static const getProductRatings = 'get_product_ratings';
  static const askProductQuestion = 'ask_product_question';
  static const answerProductQuestion = 'answer_product_question';
  static const answerReview = 'answer_review';
  static const createUserProfile = 'create_user_profile';
  static const updateTaxExemption = 'update_tax_exemption';
  static const applyCoupon = 'apply_coupon';
  static const activateLicense = 'activate_license';
  static const verifyLicense = 'verify_license';
  static const verifyLicenseIp = 'verify_license_ip';
  static const getPaymentProviders = 'get_payment_providers';
  static const updatePaymentProvider = 'update_payment_provider';
  static const getProviderStatus = 'get_provider_status';
  static const subscribeStockNotification = 'subscribe_stock_notification';
  static const unsubscribeStockNotification = 'unsubscribe_stock_notification';
}

abstract final class RefundReasonValues {
  static const returnApproved = 'Return approved';
  static const outOfStock = 'item_out_of_stock';
  static const buyerRequested = 'requested_by_customer';
  static const damaged = 'item_damaged';
  static const incorrectItem = 'incorrect_item';
}

/// Firebase RemoteConfig keys
abstract final class RemoteConfigKeys {
  static const algoliaAppId = 'algolia_app_id';
  static const algoliaSearchApiKey = 'algolia_search_api_key';
  static const geoapifyApiKey = 'geoapify_api_key';
  static const imageBaseUrl = 'image_base_url';
  static const sentryDnsKey = 'sentry_dns';
}

/// Valid values for return request status — state machine for physical returns.
abstract final class ReturnStatusValues {
  static const requested = 'requested';
  static const approved = 'approved';
  static const labelIssued = 'label_issued';
  static const received = 'received';
  static const refunded = 'refunded';
  static const rejected = 'rejected';
  static const escalated = 'escalated';
}

/// Registry of expected fields per collection.
/// Used for validation and to get the correct timestamp field.
abstract final class SchemaRegistry {
  /// Timestamp field mapping (which field name each collection uses)
  static const timestampField = {
    Collections.users: Fields.createdAt,
    Collections.products: Fields.createdAt,
    Collections.orders: Fields.createdAt,
    Collections.payouts: Fields.createdAt,
    Collections.cart: Fields.createdAt,
  };

  /// Get the correct timestamp field name for a collection.
  static String getTimestampField(String collection) {
    return timestampField[collection] ?? Fields.createdAt;
  }
}

/// Security alert type values
abstract final class SecurityAlertTypes {
  static const algoliaSyncIssue = 'algolia_sync_issue';
  static const disputeCreated = 'dispute_created';
  static const disputeFundsReinstated = 'dispute_funds_reinstated';
  static const roleChange = 'role_change';
  static const sellerSuspended = 'seller_suspended';
  static const sellerUnsuspended = 'seller_unsuspended';
  static const paymentProviderDisabled = 'payment_provider_disabled';
  static const refundReversalFailed = 'refund_reversal_failed';
  static const payoutFailed = 'payout_failed';
  static const refundFailed = 'refund.failed';
  static const sellerAccountChanged = 'seller_account_changed';
  static const payoutRecordIncomplete = 'payout_record_incomplete';
  static const mfaLowBackupCodes = 'mfa_low_backup_codes';
  static const sellerKycFailed = 'seller_kyc_failed';
  static const invalidGstAttempt = 'invalid_gst_attempt';
  static const blockedGstAttempt = 'blocked_gst_attempt';
  static const sharedGstNumber = 'shared_gst_number';
  static const taxExemptionPendingReview = 'tax_exemption_pending_review';
  static const suspiciousTaxExemption = 'suspicious_tax_exemption';
  static const authDeletionFailed = 'auth_deletion_failed';
  static const tokenRevocationFailed = 'token_revocation_failed'; // Suspension token revoke failed
  static const sellerMetricsBreach = 'seller_metrics_breach'; // TASK 11
  static const stripeTaxFallbackGst = 'stripe_tax_fallback_gst'; // Stripe Tax down for GST-exempt buyer
}

/// Security alert severity levels
abstract final class SeverityLevels {
  static const low = 'low';
  static const medium = 'medium';
  static const high = 'high';
  static const critical = 'critical';
}

/// Valid values for shippingApprovalStatus field
abstract final class ShippingApprovalStatusValues {
  static const notRequired = 'not_required';
  static const pending = 'pending';
  static const approved = 'approved';
  static const rejected = 'rejected';

  static const all = {notRequired, pending, approved, rejected};
}

abstract final class ShippingSourceValues {
  static const internationalSupplier = 'international_supplier';
  static const internationalGeneric = 'international_generic';
  static const domestic = 'domestic';
}

/// Sort options for product listings.
/// Each maps to a specific Algolia index replica or sort parameter.
enum SortOption {
  /// Default relevance ranking — uses the main Algolia index (no replica).
  relevance,

  /// Price ascending — maps to Algolia replica `<index>_price_asc`.
  priceLowToHigh,

  /// Price descending — maps to Algolia replica `<index>_price_desc`.
  priceHighToLow,

  /// Newest first — sorts by [Fields.createdAt] descending.
  newest,
}

/// Stripe API specific constants to avoid magic strings
abstract final class StripeConstants {
  static const reverseCharge = 'reverse_charge';
  static const shippingReference = 'shipping';
  static const taxExemptNone = 'none';
  static const addressSourceShipping = 'shipping';
  static const addressSource = 'address_source';
  static const value = 'value';

  // Session / Intent modes & statuses
  static const modePayment = 'payment';
  static const paymentMethodCard = 'card';
  static const statusPaid = 'paid';
  static const statusSucceeded = 'succeeded';
  static const statusRequiresCapture = 'requires_capture';
  static const accountTypeExpress = 'express';
  static const typeAccountOnboarding = 'account_onboarding';
  static const amount = 'amount';
  static const reason = 'reason';

  // Line item keys (Checkout Sessions / Invoices)
  static const priceData = 'price_data';
  static const productData = 'product_data';
  static const unitAmount = 'unit_amount';
  static const currency = 'currency';
  static const quantity = 'quantity';
  static const images = 'images';
  static const taxCode = 'tax_code';
  static const description = 'description';
  static const name = 'name';

  // Metadata keys
  static const metadataOrderId = 'order_id';
  static const metadataUserId = 'user_id';

  // Stripe Tax Calculation keys (Stripe Tax API specifically uses these names)
  static const taxCalcAmount = 'amount';
  static const taxCalcReference = 'reference';
  static const taxCalcTaxCode = 'tax_code';

  // Customer details keys
  static const customerTaxId = 'tax_id';
  static const customerTaxExempt = 'tax_exempt';
  static const customerEmail = 'customer_email';

  // Stripe Event object keys
  static const objectId = 'id';
  static const data = 'data';
  static const object = 'object';
  static const metadata = 'metadata';
  static const paymentIntent = 'payment_intent';
  static const paymentIntentData = 'payment_intent_data';
  static const paymentStatus = 'payment_status';
  static const subscription = 'subscription';
  static const charge = 'charge';
  static const created = 'created';

  // Stripe Tax types to internal tax labels
  static const taxTypeMap = {'gst_hst': 'GST', 'gst': 'GST', 'hst': 'HST', 'pst': 'PST', 'qst': 'QST', 'rst': 'PST'};
}

/// Stripe webhook event types
abstract final class StripeEventTypes {
  static const checkoutCompleted = 'checkout.session.completed';
  static const asyncPaymentSucceeded = 'checkout.session.async_payment_succeeded';
  static const asyncPaymentFailed = 'checkout.session.async_payment_failed';
  static const sessionExpired = 'checkout.session.expired';
  static const paymentIntentSucceeded = 'payment_intent.succeeded';
  static const paymentIntentPaymentFailed = 'payment_intent.payment_failed';
  static const paymentIntentCanceled = 'payment_intent.canceled';
  static const chargeRefunded = 'charge.refunded';
  static const disputeCreated = 'charge.dispute.created';
  static const disputeUpdated = 'charge.dispute.updated';
  static const disputeClosed = 'charge.dispute.closed';
  static const disputeFundsReinstated = 'charge.dispute.funds_reinstated';
  static const transferReversed = 'transfer.reversed';
  static const payoutFailed = 'payout.failed';
  static const refundFailed = 'refund.failed';
  static const accountUpdated = 'account.updated';
  static const subscriptionCreated = 'customer.subscription.created';
  static const subscriptionUpdated = 'customer.subscription.updated';
  static const subscriptionDeleted = 'customer.subscription.deleted';
  static const invoicePaymentFailed = 'invoice.payment_failed';
  static const invoicePaid = 'invoice.paid';
}

/// Subcategory constants — maps category display name to subcategory list.
/// Used by add/edit product screens to show subcategory dropdowns. (N-11)
abstract final class SubcategoryConstants {
  /// Lookup subcategories by category ID (matches productCategories list in utils.dart).
  static const Map<int, List<String>> _byId = {
    1: ['Smartphones', 'Laptops', 'Tablets', 'Cameras', 'Audio', 'Gaming', 'Smart Home', 'Wearables'], // Electronics
    2: ['Laptops', 'Desktops', 'Monitors', 'Components', 'Networking', 'Accessories'], // Computers
    3: ['Consoles', 'Video Games', 'Controllers', 'Headsets', 'PC Gaming', 'VR'], // Gaming
    4: ['Furniture', 'Decor', 'Kitchen', 'Bedding', 'Lighting', 'Garden & Outdoor', 'Storage'], // Home & Kitchen
    5: ["Men's Clothing", "Women's Clothing", "Kids' Clothing", 'Outerwear', 'Activewear', 'Underwear'], // Fashion
    6: ['Sneakers', 'Boots', 'Sandals', 'Bags', 'Belts', 'Hats', 'Sunglasses'], // Shoes & Accessories
    7: ['Watches', 'Necklaces', 'Rings', 'Earrings', 'Bracelets', 'Fine Jewelry'], // Jewelry & Watches
    8: ['Skincare', 'Haircare', 'Makeup', 'Fragrance', "Men's Grooming"], // Beauty & Personal Care
    9: ['Vitamins & Supplements', 'Medical Devices', 'Personal Care', 'Diet & Nutrition'], // Health & Wellness
    10: ['Fitness', 'Outdoor Recreation', 'Team Sports', 'Water Sports', 'Winter Sports', 'Cycling'], // Sports & Fitness
    11: ['Car Accessories', 'Motorcycle', 'Tools & Equipment', 'Replacement Parts', 'Car Care'], // Automotive
    12: ['Power Tools', 'Hand Tools', 'Hardware', 'Plumbing', 'Electrical', 'Building Materials'], // Tools & Hardware
    13: ['Pens & Pencils', 'Paper', 'Binders & Folders', 'Desk Accessories', 'Printers & Ink', 'School Supplies'], // Office Supplies
    14: ['Fiction', 'Non-Fiction', 'Children', 'Textbooks', 'Comics & Graphic Novels', 'Audiobooks'], // Books
    15: ['Guitars', 'Keyboards', 'Drums', 'Recording Equipment', 'DJ Gear', 'Accessories'], // Music & Instruments
    16: ['Puzzles & Board Games', 'Building Toys', 'Dolls & Playsets', 'Action Figures', 'Outdoor Play'], // Toys & Games
    17: ['Baby Clothing', 'Feeding', 'Nursery', 'Strollers', 'Toys', 'Diapering'], // Baby & Kids
    18: ['Dogs', 'Cats', 'Fish', 'Birds', 'Small Animals', 'Reptiles'], // Pet Supplies
    19: ['Snacks', 'Beverages', 'Health Foods', 'Specialty Foods', 'Baking', 'Pantry Staples'], // Groceries
    20: ['Painting', 'Sculpture', 'Photography', 'Mixed Media', 'Antiques', 'Coins & Stamps'], // Art & Collectibles
    21: ['Software', 'eBooks', 'Digital Art', 'Audio & Music', 'Courses & Tutorials', 'Templates'], // Digital Products
  };

  /// Lookup subcategories by category ID (matches productCategories list in utils.dart).
  static List<String> forCategoryId(int categoryId) {
    return _byId[categoryId] ?? const [];
  }
}

// =============================================================================
// N-11: SUBCATEGORIES — Maps categoryId to list of subcategory names
// =============================================================================

/// Stripe subscription status values
abstract final class SubscriptionStatusValues {
  static const active = 'active';
  static const canceled = 'canceled';
  static const inactive = 'inactive';
  static const pastDue = 'past_due';
  static const incomplete = 'incomplete';
  static const incompleteExpired = 'incomplete_expired';
  static const trialing = 'trialing';
  static const unpaid = 'unpaid';

  static const all = [active, canceled, inactive, pastDue, incomplete, incompleteExpired, trialing, unpaid];
  static const premiumActive = {active, trialing};
}

/// Valid values for supplier currency — mirrors Python SupplierCurrencyValues
abstract final class SupplierCurrencyValues {
  static const cad = 'CAD';
  static const usd = 'USD';
  static const eur = 'EUR';
  static const gbp = 'GBP';
  static const cny = 'CNY';
  static const jpy = 'JPY';
  static const krw = 'KRW';
  static const inr = 'INR';
  static const aud = 'AUD';
  static const mxn = 'MXN';
  static const brl = 'BRL';
  static const hkd = 'HKD';
  static const sgd = 'SGD';
  static const twd = 'TWD';

  static const defaultCurrency = 'USD';
  static const all = {cad, usd, eur, gbp, cny, jpy, krw, inr, aud, mxn, brl, hkd, sgd, twd};
}

/// Valid values for supplier platform types
abstract final class SupplierTypeValues {
  static const aliexpress = 'aliexpress';
  static const dhgate = 'dhgate';
  static const alibaba = 'alibaba';
  static const s1688 = '1688'; // Can't start with number, so use 's1688' as const name
  static const temu = 'temu';
  static const cjdropshipping = 'cjdropshipping';
  static const local = 'local';
  static const other = 'other';
  // Extended supplier platforms
  static const spocket = 'spocket';
  static const oberlo = 'oberlo';
  static const printful = 'printful';
  static const printify = 'printify';
  static const madeInChina = 'made_in_china';
  static const globalSources = 'global_sources';
  static const gmarket = 'gmarket';
  static const coupang = 'coupang';
  static const rakuten = 'rakuten';
  static const faire = 'faire';
  static const amazonEurope = 'amazon_europe';
  static const amazonUsa = 'amazon_usa';
  static const amazonJapan = 'amazon_japan';
  static const walmart = 'walmart';
  static const costco = 'costco';
  static const etsyWholesale = 'etsy_wholesale';
  static const indiamart = 'indiamart';
  static const tradeindia = 'tradeindia';
  static const custom = 'custom';

  static const all = {
    aliexpress,
    dhgate,
    alibaba,
    s1688,
    temu,
    cjdropshipping,
    local,
    other,
    spocket,
    oberlo,
    printful,
    printify,
    madeInChina,
    globalSources,
    gmarket,
    coupang,
    rakuten,
    faire,
    amazonEurope,
    amazonUsa,
    amazonJapan,
    walmart,
    costco,
    etsyWholesale,
    indiamart,
    tradeindia,
    custom,
  };

  /// International suppliers (non-local)
  static const international = {aliexpress, dhgate, alibaba, s1688, temu, cjdropshipping};
}

abstract final class TransactionSentinel {
  static const alreadyRefunded = 'already_refunded';
  static const refunded = 'refunded';
}

/// User-facing UI messages
abstract final class UIMessages {
  static const sessionExpired = 'Session expired due to inactivity. Please login again.';
  static const sessionExpiredTitle = 'Session Expired';
}

/// Valid values for roles array
abstract final class UserRoleValues {
  static const admin = 'admin';
  static const seller = 'seller';
  static const buyer = 'buyer';

  static const all = {admin, seller, buyer};
}

// =============================================================================
// SORT OPTIONS — Product listing sort modes (GAP #1)
// =============================================================================

abstract final class WarehouseTypeValues {
  static const warehouse = 'warehouse';
  static const personal = 'personal';

  static const all = {warehouse, personal};
}

// =============================================================================
// LOCAL STORAGE KEYS — SharedPreferences keys (GAP #6, GAP #7)
// =============================================================================

abstract final class WebhookResponseStatus {
  static const processed = 'processed';
  static const ignored = 'ignored';
  static const error = 'error';
}

// =============================================================================
// ALGOLIA INDEX REPLICAS — Index names for sort replicas (GAP #1)
// =============================================================================

/// Valid values for webhook processing status
abstract final class WebhookStatusValues {
  static const processing = 'processing';
  static const completed = 'completed';
  static const failed = 'failed';

  static const all = {processing, completed, failed};
}
