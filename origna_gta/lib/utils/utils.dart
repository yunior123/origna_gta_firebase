import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:origna_gta/core/errors/error_codes.dart';
import 'package:origna_gta/core/routes.dart';
import 'package:origna_gta/models/models.dart';
import 'package:origna_gta/services/conf_services.dart';
import 'package:origna_gta/utils/constants.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/utils/env_config.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

export 'package:origna_gta/models/models.dart';

// ============================================================================
// ERROR HANDLING UTILITIES
// ============================================================================

const Map<String, Map<String, double>> provinceTaxRates = {
  'AB': {'GST': 0.05},
  'BC': {'GST': 0.05, 'PST': 0.07},
  'MB': {'GST': 0.05, 'PST': 0.07},
  'NB': {'HST': 0.15},
  'NL': {'HST': 0.15},
  'NS': {'HST': 0.14}, // Changed from 15% to 14% on April 1, 2025 (CRA)
  'NT': {'GST': 0.05},
  'NU': {'GST': 0.05},
  'ON': {'HST': 0.13},
  'PE': {'HST': 0.15},
  'QC': {'GST': 0.05, 'QST': 0.09975},
  'SK': {'GST': 0.05, 'PST': 0.06},
  'YT': {'GST': 0.05},
};

/// Maximum total keywords to generate (Firestore array limit consideration)
const int _maxKeywords = 30;

/// Maximum characters per word to generate prefixes for
const int _maxWordLength = 20;

final List<ProductCategories> productCategories = [
  ProductCategories(categoryId: 1, name: "categories.electronics", icon: Icons.devices),
  ProductCategories(categoryId: 2, name: "categories.computers", icon: Icons.computer),
  ProductCategories(categoryId: 3, name: "categories.gaming", icon: Icons.sports_esports),
  ProductCategories(categoryId: 4, name: "categories.home_kitchen", icon: Icons.kitchen),
  ProductCategories(categoryId: 5, name: "categories.fashion", icon: Icons.shopping_bag),
  ProductCategories(categoryId: 6, name: "categories.shoes_accessories", icon: Icons.backpack),
  ProductCategories(categoryId: 7, name: "categories.jewelry_watches", icon: Icons.watch),
  ProductCategories(categoryId: 8, name: "categories.beauty_personal_care", icon: Icons.spa),
  ProductCategories(categoryId: 9, name: "categories.health_wellness", icon: Icons.favorite),
  ProductCategories(categoryId: 10, name: "categories.sports_fitness", icon: Icons.fitness_center),
  ProductCategories(categoryId: 11, name: "categories.automotive", icon: Icons.directions_car),
  ProductCategories(categoryId: 12, name: "categories.tools_hardware", icon: Icons.handyman),
  ProductCategories(categoryId: 13, name: "categories.office_supplies", icon: Icons.folder),
  ProductCategories(categoryId: 14, name: "categories.books", icon: Icons.book),
  ProductCategories(categoryId: 15, name: "categories.music_instruments", icon: Icons.music_note),
  ProductCategories(categoryId: 16, name: "categories.toys_games", icon: Icons.gamepad),
  ProductCategories(categoryId: 17, name: "categories.baby_kids", icon: Icons.child_care),
  ProductCategories(categoryId: 18, name: "categories.pet_supplies", icon: Icons.pets),
  ProductCategories(categoryId: 19, name: "categories.groceries", icon: Icons.local_grocery_store),
  ProductCategories(categoryId: 20, name: "categories.art_collectibles", icon: Icons.palette),
  ProductCategories(categoryId: 21, name: "categories.digital_products", icon: Icons.cloud),
];

// Provincial tax configuration — single source of truth
// Used by checkout_screen.dart _buildTaxBreakdown() and getTaxRate()
// NOTE: These are FRONTEND ESTIMATES only. The backend uses Stripe Tax API
// for the authoritative calculation (which includes shipping in the tax base).
final taxConfig = provinceTaxRates;

Future<bool> addToCart({required String productId, required int quantity, required BuildContext context}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    Navigator.of(context).pushNamed(AppRoutes.login);
    return false;
  }

  if (quantity <= 0) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('cart.invalid_quantity'.tr()), backgroundColor: DesignTokens.error));
    }
    return false;
  }

  final cartRef = FirebaseFirestore.instance.collection(Collections.users).doc(user.uid).collection(Collections.cart);

  // Use productId as deterministic cart doc ID so we can transactionally read it.
  final cartItemRef = cartRef.doc(productId);

  try {
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      // Check product stock before adding to cart
      final productRef = FirebaseFirestore.instance.collection(Collections.products).doc(productId);
      final productSnapshot = await transaction.get(productRef);
      if (!productSnapshot.exists) {
        throw Exception('cart.product_not_found'.tr());
      }
      final productData = productSnapshot.data()!;
      final stockQuantity = productData[Fields.stockQuantity] as int? ?? 0;

      // Read existing cart item with deterministic ID — safe inside transaction.
      final existingSnapshot = await transaction.get(cartItemRef);
      final currentQty = existingSnapshot.exists ? (existingSnapshot.data()?[Fields.quantity] as num?)?.toInt() ?? 0 : 0;
      final newTotalQty = currentQty + quantity;

      if (newTotalQty > stockQuantity) {
        throw Exception('cart.stock_limit_count'.tr(namedArgs: {'count': stockQuantity.toString()}));
      }

      if (existingSnapshot.exists) {
        transaction.update(cartItemRef, {Fields.quantity: newTotalQty});
      } else {
        transaction.set(cartItemRef, CartModel(productId: productId, quantity: quantity, createdAt: DateTime.now()).toMap());
      }
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('cart.updated'.tr()), backgroundColor: DesignTokens.success));
    }
  } catch (e, stack) {
    AppError.log(e, stackTrace: stack, context: 'addToCart');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppError.getMessage(e)), backgroundColor: DesignTokens.error));
    }
    return false;
  }
  return true;
}

// Calculate detailed taxes based on selected province
Map<String, double> calculateDetailedTaxes(Address? address, double total) {
  if (address == null) return {};

  final province = address.state;
  final rates = provinceTaxRates[province] ?? {'GST': 0.05};

  Map<String, double> breakdown = {};
  rates.forEach((name, rate) {
    breakdown[name] = total * rate;
  });
  return breakdown;
}

/// Fallback shipping calculation when coordinates are unavailable.
/// Uses province-based flat rates.
double calculateFallbackShipping(List<CartItemDetailModel> items, String sellerProvince, String buyerProvince) {
  final totalItems = items.fold(0, (i, item) => i + item.quantity);
  double baseCost = 26.99;

  if (sellerProvince == buyerProvince) {
    baseCost = 12.99;
  } else if (_areAdjacentProvinces(sellerProvince, buyerProvince)) {
    baseCost = 18.99;
  } else if (_areSameRegion(sellerProvince, buyerProvince)) {
    baseCost = 22.99;
  }

  final additionalItemsCost = (totalItems - 1).clamp(0, 999) * (baseCost * 0.15);

  return baseCost + additionalItemsCost;
}

/// Calculate shipping cost based on distance, quantity, weight, and delivery speed.
/// Aligns with backend shipping_service.py for deterministic totals.
/// Returns a Map of sellerId to shipping cost.
Future<Map<String, double>> calculateShippingCost(
  List<CartItemDetailModel> items,
  Address? buyerAddress, {
  DeliverySpeed chosenSpeed = DeliverySpeed.standard,
}) async {
  if (buyerAddress == null || buyerAddress.latitude == null || buyerAddress.longitude == null) {
    return {};
  }

  final Map<String, double> sellerCosts = {};
  final String apiKey = ConfigService().geoapifyKey;

  final Map<String, List<CartItemDetailModel>> itemsBySeller = {};
  for (var item in items) {
    itemsBySeller.putIfAbsent(item.sellerId, () => []).add(item);
  }

  for (var entry in itemsBySeller.entries) {
    final sellerId = entry.key;
    final sellerItems = entry.value;
    double sellerTotal = 0.0;

    final seller = sellerItems.first.sellerAddress;
    final sellerState = seller.state;
    final buyerState = buyerAddress.state;

    final chargeableItems = sellerItems.where((i) => !i.freeShipping).toList();
    if (chargeableItems.isEmpty) {
      sellerCosts[sellerId] = 0.0;
      continue;
    }

    final hasLocalRestriction = sellerItems.any((i) => i.isLocalDeliveryOnly || i.isPerishable);
    if (hasLocalRestriction && sellerState != buyerState) {
      sellerTotal += 50.0;
    }

    final hasFixedPrice = _hasFixedPriceForSpeed(chargeableItems, chosenSpeed);
    if (hasFixedPrice.isEnabled) {
      sellerTotal += hasFixedPrice.total;
      sellerCosts[sellerId] = sellerTotal;
      continue;
    }

    if (seller.latitude != null && seller.longitude != null && apiKey.isNotEmpty) {
      try {
        final url = Uri.parse("https://api.geoapify.com/v1/routematrix?apiKey=$apiKey");
        final response = await http
            .post(
              url,
              headers: {"Content-Type": "application/json"},
              body: jsonEncode({
                "mode": "drive",
                "sources": [
                  {
                    "location": [seller.longitude, seller.latitude],
                  },
                ],
                "targets": [
                  {
                    "location": [buyerAddress.longitude, buyerAddress.latitude],
                  },
                ],
              }),
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final distanceMeters = (data['sources_to_targets'] as List).first.first['distance'] as num? ?? 0;
          final distanceKm = distanceMeters / 1000.0;

          if (hasLocalRestriction && distanceKm > 100) {
            sellerTotal += 75.0;
            sellerCosts[sellerId] = sellerTotal;
            continue;
          }

          sellerTotal += _calculateTieredShipping(distanceKm, chargeableItems, chosenSpeed);
          sellerCosts[sellerId] = sellerTotal;
          continue;
        }
      } catch (e, stack) {
        AppError.log(e, stackTrace: stack, context: 'calculateShippingCost');
      }
    }

    sellerTotal += calculateFallbackShipping(chargeableItems, sellerState, buyerState);
    sellerCosts[sellerId] = sellerTotal;
  }

  return sellerCosts;
}

double calculateTieredShipping(double distanceKm, List<CartItemDetailModel> sellerItems, DeliverySpeed speed) {
  return _calculateTieredShipping(distanceKm, sellerItems, speed);
}

/// Check if current user's email is verified. Returns true if verified or in emulator mode.
/// Shows dialog and returns false if not verified.
Future<bool> checkEmailVerifiedOrPrompt(BuildContext context, {FirebaseAuth? auth}) async {
  final firebaseAuth = auth ?? FirebaseAuth.instance;
  final user = firebaseAuth.currentUser;
  if (user == null) return false;

  // BOOT-H1: emulator bypass is intentional for local dev only.
  // Restricted to kDebugMode to ensure it cannot fire in release builds.
  // Logs a warning so behavior divergence is visible during development.
  if (EnvConfig().isEmulator && kDebugMode) {
    debugPrint('⚠️ BOOT-H1: email verification bypassed in emulator mode');
    return true;
  }

  try {
    await user.reload();
  } catch (e) {
    // reload() failed (network error on non-emulator env) — fail closed to protect verification gate
    debugPrint('checkEmailVerifiedOrPrompt: reload failed: $e');
    if (!EnvConfig().isEmulator && context.mounted) {
      showEmailVerificationDialog(
        context,
        auth: firebaseAuth,
        onResend: () async {
          try {
            await firebaseAuth.currentUser?.sendEmailVerification();
          } catch (_) {}
        },
      );
      return false;
    }
    return true; // emulator: treat as verified
  }
  final freshUser = firebaseAuth.currentUser;
  if (freshUser != null && freshUser.emailVerified) {
    return true;
  }

  if (context.mounted) {
    showEmailVerificationDialog(
      context,
      auth: firebaseAuth,
      onResend: () async {
        try {
          await freshUser?.sendEmailVerification();
        } catch (_) {}
      },
    );
  }
  return false;
}

/// Helper to convert dynamic date/timestamp to Firestore Timestamp
Timestamp dynamicToTimestamp(dynamic value) {
  if (value is Timestamp) return value;
  if (value is DateTime) return Timestamp.fromDate(value);
  return Timestamp.now();
}

List<String> generateSearchKeywords(String name) {
  final cleanName = name.toLowerCase().trim();
  if (cleanName.isEmpty) return [''];

  final keywords = <String>{};
  final words = cleanName.split(RegExp(r'\s+'));
  final prefixLimit = _maxKeywords > 1 ? _maxKeywords - 1 : 0;

  for (final word in words) {
    final maxLen = word.length < _maxWordLength ? word.length : _maxWordLength;
    var temp = '';
    for (int i = 0; i < maxLen; i++) {
      temp += word[i];
      keywords.add(temp);
      if (keywords.length >= prefixLimit) break;
    }
    if (keywords.length >= prefixLimit) break;
  }

  keywords.add(cleanName);
  return keywords.take(_maxKeywords).toList();
}

Future<int> getCartItemCount(String userId) async {
  final query = FirebaseFirestore.instance.collection(Collections.users).doc(userId).collection(Collections.cart);

  final snapshot = await query.count().get();
  return snapshot.count ?? 0;
}

Stream<List<CartItemModel>> getCartStream(String userId) {
  return FirebaseFirestore.instance.collection(Collections.users).doc(userId).collection(Collections.cart).snapshots().map((snapshot) {
    return snapshot.docs.map((doc) => CartItemModel.fromMap(doc.data(), docId: doc.id)).toList();
  });
}

int getCrossAxisCount(BuildContext context) {
  if (TargetPlatform.android == defaultTargetPlatform || TargetPlatform.iOS == defaultTargetPlatform) {
    return 2;
  }
  final width = MediaQuery.of(context).size.width;

  if (kIsWeb) {
    if (width < 600) {
      return 2;
    } else if (width < 1024) {
      return 3;
    } else {
      return 4;
    }
  } else {
    return 2;
  }
}

double getTaxRate(String province) {
  // Derive combined rate from the canonical provinceTaxRates map
  final rates = provinceTaxRates[province];
  if (rates == null) return 0.13; // Default: Ontario HST
  // Round to 5 decimals to avoid IEEE 754 floating-point artifacts while preserving QC's 14.975%
  final total = rates.values.fold(0.0, (acc, rate) => acc + rate);
  return double.parse(total.toStringAsFixed(5));
}

bool hasValidAddress(Address? address) {
  if (address == null) return false;
  final stateCode = address.state.trim().toUpperCase();
  return address.street.trim().isNotEmpty &&
      address.city.trim().isNotEmpty &&
      stateCode.isNotEmpty &&
      ProvinceCodeValues.all.contains(stateCode) &&
      address.postalCode.trim().isNotEmpty &&
      address.country.trim().isNotEmpty;
}

bool isValidTaxCode(String? taxCode) {
  if (taxCode == null || taxCode.trim().isEmpty) return true;
  final value = taxCode.trim();
  return RegExp(r'^txcd_\d{8}$').hasMatch(value);
}

/// Opens Privacy Policy page
/// On web: navigates to /privacy-policy URL (required for OAuth verification)
/// On mobile: shows in-app screen
void openPrivacyPolicy(BuildContext context) {
  if (kIsWeb) {
    // Navigate to actual URL for OAuth compliance
    _launchPath(AppRoutes.privacyPolicy);
  } else {
    Navigator.pushNamed(context, AppRoutes.privacyPolicy);
  }
}

/// Opens Terms of Service page
/// On web: navigates to /terms-of-service URL (required for OAuth verification)
/// On mobile: shows in-app screen
void openTermsOfService(BuildContext context) {
  if (kIsWeb) {
    // Navigate to actual URL for OAuth compliance
    _launchPath(AppRoutes.termsOfService);
  } else {
    Navigator.pushNamed(context, AppRoutes.termsOfService);
  }
}

AddressDetails parseAddressSuggestion(Map<String, dynamic> suggestion) {
  final props = suggestion['properties'] ?? {};

  final houseNumber = props['housenumber'];
  final streetName = props['street'];
  final addressLine1 = [?houseNumber, ?streetName].join(' ');

  return AddressDetails(
    street: props['formatted'] ?? addressLine1,
    city: props['city'] ?? '',
    state: props['state_code'] ?? 'ON',
    postalCode: props['postcode'] ?? '',
    latitude: (suggestion['geometry']?['coordinates']?[1] ?? 0).toDouble(),
    longitude: (suggestion['geometry']?['coordinates']?[0] ?? 0).toDouble(),
  );
}

/// Show a dialog prompting the user to verify their email before proceeding.
/// [onResend] optional callback to resend verification email.
/// Returns true if user dismissed, false if they tapped resend.
void showEmailVerificationDialog(BuildContext context, {FirebaseAuth? auth, VoidCallback? onResend}) {
  final firebaseAuth = auth ?? FirebaseAuth.instance;
  final user = firebaseAuth.currentUser;
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(color: Color(0xFFFFF3E0), shape: BoxShape.circle),
        child: const Icon(Icons.mark_email_unread_outlined, color: Color(0xFFF57C00), size: 36),
      ),
      title: Text('email_verification.title'.tr(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (user?.email != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: DesignTokens.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)),
              child: Text(
                user!.email!,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: DesignTokens.primary),
              ),
            ),
          Text(
            'email_verification.instruction_title'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: DesignTokens.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('  1. ${'email_verification.step1'.tr()}', style: TextStyle(fontSize: 13, color: DesignTokens.textPrimary)),
                const SizedBox(height: 4),
                Text('  2. ${'email_verification.step2'.tr()}', style: TextStyle(fontSize: 13, color: DesignTokens.textPrimary)),
                const SizedBox(height: 4),
                Text('  3. ${'email_verification.step3'.tr()}', style: TextStyle(fontSize: 13, color: DesignTokens.textPrimary)),
                const SizedBox(height: 4),
                Text('  4. ${'email_verification.step4'.tr()}', style: TextStyle(fontSize: 13, color: DesignTokens.textPrimary)),
              ],
            ),
          ),
          if (onResend != null) ...[
            const SizedBox(height: 16),
            Text("email_verification.did_not_receive".tr(), style: TextStyle(fontSize: 13, color: DesignTokens.textSecondary)),
          ],
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        if (onResend != null)
          TextButton.icon(
            onPressed: () {
              onResend();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('email_verification.sent_success'.tr()), backgroundColor: DesignTokens.primary, behavior: SnackBarBehavior.floating),
              );
            },
            icon: const Icon(Icons.send, size: 16),
            label: Text('email_verification.resend_button'.tr()),
            style: TextButton.styleFrom(foregroundColor: DesignTokens.primary),
          ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx),
          style: ElevatedButton.styleFrom(
            backgroundColor: DesignTokens.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          ),
          child: Text('common.got_it'.tr()),
        ),
      ],
    ),
  );
}

/// Displays a modal dialog prompting the user to sign in.
///
/// [text] is a translation key for the dialog body (defaults to cart sign-in prompt).
/// Tapping "Sign in" navigates to the login screen; tapping "Cancel" dismisses.
void showLoginPrompt(BuildContext context, {String text = 'auth.sign_in_cart_required'}) {
  // Capture the ROOT navigator from the CALLER's context before showing dialog.
  // rootNavigator: true is required in Flutter Web to update the browser URL.
  // Without it, a nested navigator (e.g., inside a tab) handles the push
  // and the browser URL is never updated, breaking deep-linking and E2E tests.
  final navigator = Navigator.of(context, rootNavigator: true);
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('auth.sign_in_required'.tr()),
      content: Text(text.tr()),
      actions: [
        TextButton(key: const Key('login_dialog_cancel_button'), onPressed: () => Navigator.pop(dialogContext), child: Text('common.cancel'.tr())),
        ElevatedButton(
          key: const Key('login_dialog_sign_in_button'),
          onPressed: () {
            Navigator.pop(dialogContext);
            navigator.pushNamed(AppRoutes.login);
          },
          style: ElevatedButton.styleFrom(backgroundColor: DesignTokens.primary, foregroundColor: Colors.white),
          child: Text('auth.sign_in'.tr()),
        ),
      ],
    ),
  );
}

/// Validates a video file based on size and duration business rules.
VideoValidationError validateVideoFile({required int sizeInBytes, required int durationInSeconds}) {
  if (sizeInBytes > BusinessRules.maxVideoBytes) {
    return VideoValidationError.tooLarge;
  }
  if (durationInSeconds > BusinessRules.maxVideoDurationSeconds) {
    return VideoValidationError.tooLong;
  }
  return VideoValidationError.none;
}

/// Check if two provinces are adjacent
bool _areAdjacentProvinces(String p1, String p2) {
  const adjacency = {
    'BC': ['AB', 'YT', 'NT'],
    'AB': ['BC', 'SK', 'NT'],
    'SK': ['AB', 'MB', 'NT', 'NU'],
    'MB': ['SK', 'ON', 'NU'],
    'ON': ['MB', 'QC'],
    'QC': ['ON', 'NB', 'NL'],
    'NB': ['QC', 'NS', 'PE'],
    'NS': ['NB', 'PE'],
    'PE': ['NB', 'NS'],
    'NL': ['QC'],
    'YT': ['BC', 'NT'],
    'NT': ['BC', 'AB', 'SK', 'YT', 'NU'],
    'NU': ['SK', 'MB', 'NT'],
  };

  return adjacency[p1]?.contains(p2) ?? false;
}

/// Check if two provinces are in the same region
bool _areSameRegion(String p1, String p2) {
  const regions = {
    'West': ['BC', 'AB'],
    'Prairies': ['SK', 'MB'],
    'Central': ['ON', 'QC'],
    'Atlantic': ['NB', 'NS', 'PE', 'NL'],
    'North': ['YT', 'NT', 'NU'],
  };

  for (var region in regions.values) {
    if (region.contains(p1) && region.contains(p2)) {
      return true;
    }
  }
  return false;
}

double _calculateTieredShipping(double distanceKm, List<CartItemDetailModel> sellerItems, DeliverySpeed speed) {
  double baseCost = 26.99;

  if (distanceKm <= 15) {
    baseCost = 1.99;
  } else if (distanceKm <= 50) {
    baseCost = 4.99;
  } else if (distanceKm <= 150) {
    baseCost = 9.99;
  } else if (distanceKm <= 500) {
    baseCost = 14.99;
  } else if (distanceKm <= 1200) {
    baseCost = 18.99;
  } else if (distanceKm <= 2500) {
    baseCost = 22.99;
  }

  double weightSurcharge = 0;
  int totalItems = 0;
  for (final item in sellerItems) {
    final qty = item.quantity;
    totalItems += qty;

    final actualWeight = item.weightKg ?? 0.5;
    final length = item.lengthCm ?? 10;
    final width = item.widthCm ?? 10;
    final height = item.heightCm ?? 10;
    final volWeight = (length * width * height) / 5000.0;
    final effectiveWeight = actualWeight > volWeight ? actualWeight : volWeight;

    if (effectiveWeight > 2.0) {
      weightSurcharge += (effectiveWeight - 2.0) * 1.5 * qty;
    }
  }

  final subtotal = baseCost + weightSurcharge + ((totalItems - 1).clamp(0, 999) * (baseCost * 0.15));

  double multiplier = 1.0;
  if (speed == DeliverySpeed.express) {
    if (distanceKm <= 15) {
      multiplier = 4.0;
    } else if (distanceKm <= 50) {
      multiplier = 1.6;
    } else if (distanceKm <= 150) {
      multiplier = 1.5;
    } else {
      multiplier = 1.6;
    }
  } else if (speed == DeliverySpeed.sameDay) {
    if (distanceKm <= 15) {
      multiplier = 4.5;
    } else if (distanceKm <= 50) {
      multiplier = 1.8;
    } else if (distanceKm <= 150) {
      multiplier = 1.8;
    } else {
      multiplier = 2.5;
    }
  }

  return subtotal * multiplier;
}

_FixedPriceResult _hasFixedPriceForSpeed(List<CartItemDetailModel> items, DeliverySpeed speed) {
  double total = 0;
  for (final item in items) {
    final matches = item.deliveryOptions.where((o) => o.type == speed.value);
    if (matches.isEmpty) {
      return const _FixedPriceResult(isEnabled: false, total: 0);
    }

    final option = matches.first;
    final cost = option.calculateCostForQuantity(item.quantity);
    // Only treat as fixed-price shipping when cost is positive.
    // `freeShipping` is handled separately via the product flag.
    if (cost.isNaN || cost.isInfinite || cost <= 0) {
      return const _FixedPriceResult(isEnabled: false, total: 0);
    }

    total += cost;
  }

  return _FixedPriceResult(isEnabled: true, total: total);
}

// ============================================================================
// LEGAL PAGE NAVIGATION - OAuth Compliance
// ============================================================================

Future<void> _launchPath(String path) async {
  // Ensure you use https://
  final Uri url = Uri.parse('https://orignagta.ca$path');

  if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
    throw Exception('Could not launch $url');
  }
}

/// Centralized error handler - logs to console and Sentry
/// Use this for all caught errors to ensure visibility
class AppError {
  /// Extract user-friendly message from error.
  ///
  /// For [FirebaseFunctionsException], returns the backend message (safe — our
  /// backend already sanitises messages before raising HttpsError), but filters
  /// out any raw Firestore exceptions that might have leaked.
  /// For [FirebaseException], returns a safe generic message, as raw Firebase
  /// messages often contain internal structure details.
  /// For everything else, returns [fallback] to avoid leaking internals.
  ///
  /// If [code] is provided it is appended to the message so users can quote it
  /// when contacting support: e.g. "Card declined [ORIGNA-PAY-001]".
  /// When [code] is omitted the method attempts to infer one automatically via
  /// [_inferCode].
  static String getMessage(dynamic error, [String? fallback, String? code]) {
    final defaultFallback = 'errors.generic_error'.tr();
    final actualFallback = fallback ?? defaultFallback;

    String rawMsg;

    if (error is FirebaseFunctionsException) {
      final msg = error.message ?? '';
      // Filter out leaked backend errors
      if (msg.contains('FailedPrecondition') || msg.contains('The query requires an index')) {
        rawMsg = 'errors.service_unavailable'.tr();
      } else {
        rawMsg = msg.isNotEmpty ? msg : actualFallback;
      }
    } else if (error is FirebaseException) {
      // Don't expose raw Firebase exceptions to the user UI
      rawMsg = 'errors.service_unavailable'.tr();
    } else {
      // NEVER expose raw e.toString() — it can contain stack traces,
      // type names and server internals.
      rawMsg = actualFallback;
    }

    // If the backend already embedded a code (e.g. "Order not found [ORIGNA-ORD-001]")
    // do not append a second one.
    if (rawMsg.contains('[ORIGNA-')) {
      return rawMsg;
    }

    final displayCode = code ?? _inferCode(error);
    if (displayCode != null) {
      return '$rawMsg [$displayCode]';
    }
    return rawMsg;
  }

  /// Log error with optional user message
  /// - Logs to debugPrint in development
  /// - Sends to Sentry in production
  static void log(dynamic error, {StackTrace? stackTrace, String? context, Map<String, dynamic>? extras}) {
    final contextPrefix = context != null ? '[$context] ' : '';
    debugPrint('$contextPrefix$error');
    if (stackTrace != null) {
      debugPrint('$stackTrace');
    }

    // Send to Sentry (non-blocking)
    Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        if (context != null) {
          scope.setTag('context', context);
        }
        if (extras != null) {
          scope.setContexts('extras', extras);
        }
      },
    );
  }

  /// Show error to user via SnackBar and log it
  static void show(
    BuildContext context,
    String userMessage, {
    dynamic error,
    StackTrace? stackTrace,
    String? logContext,
    Duration duration = const Duration(seconds: 4),
  }) {
    // Log the error
    if (error != null) {
      log(error, stackTrace: stackTrace, context: logContext);
    }

    // Show user-friendly message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(userMessage),
        backgroundColor: DesignTokens.error,
        duration: duration,
        action: SnackBarAction(
          label: 'common.dismiss'.tr(),
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Infer an ORIGNA error code from a known Firebase / Stripe error code or
  /// from the exception type.  Returns null when no mapping exists.
  static String? _inferCode(dynamic error) {
    if (error is FirebaseFunctionsException) {
      return null; // Backend already appends codes; no client-side inference needed.
    }
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'email-already-in-use' => ErrorCodes.authEmailInUse,
        'wrong-password' => ErrorCodes.authWrongPassword,
        'user-not-found' => ErrorCodes.authUserNotFound,
        'weak-password' => ErrorCodes.authWeakPassword,
        'too-many-requests' => ErrorCodes.authTooManyRequests,
        'session-cookie-expired' || 'user-token-expired' => ErrorCodes.authSessionExpired,
        _ => ErrorCodes.sysUnknown,
      };
    }
    if (error is FirebaseException) {
      return ErrorCodes.sysServerError;
    }
    return null;
  }
}

/// Enum for video validation errors
enum VideoValidationError { none, tooLarge, tooLong, invalidFormat }

class _FixedPriceResult {
  final bool isEnabled;
  final double total;

  const _FixedPriceResult({required this.isEnabled, required this.total});
}
