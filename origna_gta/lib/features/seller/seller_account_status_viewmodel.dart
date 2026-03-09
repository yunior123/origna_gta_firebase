// coverage:ignore-file
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/repositories/user_repository.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';

/// Main provider - watches Firestore in realtime for seller status updates
/// When webhook updates Firestore, UI automatically reflects the change
/// Use [refreshSellerStatusProvider] to manually sync with Stripe backend
final sellerAccountStatusProvider = StreamProvider.autoDispose<SellerAccountStatus>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.error(Exception('Please log in to continue'));
  }

  // Watch Firestore in realtime - updates automatically when webhook changes data
  return ref.read(userRepositoryProvider).watchSellerAccountStatus(user.uid);
});

/// Manual refresh provider - calls backend to sync Stripe status with Firestore
/// Use this ONLY when user explicitly requests a status check (e.g., "Check Status" button)
final refreshSellerStatusProvider = FutureProvider.family.autoDispose<SellerAccountStatus, void>((ref, _) async {
  final user = ref.read(currentUserProvider);
  if (user == null) {
    throw Exception('Please log in to continue');
  }

  try {
    final functions = ref.read(firebaseFunctionsProvider);
    final callable = functions.httpsCallable(CloudFunctionEndpoints.getConnectAccountStatus);
    final result = await callable.call();
    final data = result.data as Map<String, dynamic>;
    
    final chargesEnabled = data[Fields.chargesEnabled] == true;
    final payoutsEnabled = data[Fields.payoutsEnabled] == true;
    final detailsSubmitted = data[ApiKeys.detailsSubmitted] == true;
    final requirementsDue = data[ApiKeys.requirementsCurrentlyDue] is List
        ? (data[ApiKeys.requirementsCurrentlyDue] as List<dynamic>).map((e) => e.toString()).toList()
        : <String>[];
    
    if (kDebugMode) {
      debugPrint('Stripe Status - charges: $chargesEnabled, payouts: $payoutsEnabled');
    }

    // Stream provider auto-updates from Firestore once CF writes the new status — no invalidate needed.
    return SellerAccountStatus(
      isSeller: true,
      chargesEnabled: chargesEnabled && payoutsEnabled,
      detailsSubmitted: detailsSubmitted,
      hasPendingRequirements: requirementsDue.isNotEmpty,
      pendingRequirements: requirementsDue,
    );
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Error syncing status from backend: $e');
    }
    rethrow;
  }
});
