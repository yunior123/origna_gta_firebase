// coverage:ignore-file
// seller_registration_view_model.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:url_launcher/url_launcher.dart';

import 'seller_registration_state.dart';

/// Provider to fetch backend payment provider configuration status.
/// Uses firebaseFunctionsProvider instead of direct FirebaseFunctions.instance.
final paymentProviderStatusProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    final functions = ref.read(firebaseFunctionsProvider);
    final callable = functions.httpsCallable(CloudFunctionEndpoints.getProviderStatus);
    final result = await callable.call();
    final data = Map<String, dynamic>.from(result.data as Map);
    if (data[ApiKeys.success] == true && data[ApiKeys.providers] != null) {
      return Map<String, dynamic>.from(data[ApiKeys.providers] as Map);
    }
    return {};
  } catch (e) {
    // On error, return empty map (all providers will show from static config)
    return {};
  }
});

final sellerRegistrationViewModelProvider = StateNotifierProvider.autoDispose<SellerRegistrationViewModel, SellerRegistrationState>((ref) {
  return SellerRegistrationViewModel(ref);
});

/// Documentation for SellerRegistrationViewModel
class SellerRegistrationViewModel extends StateNotifier<SellerRegistrationState> {
  final Ref _ref;
  
  /// Tracks if an operation is in progress to prevent double-clicks
  bool _isOperationInProgress = false;
  
  /// Minimum time between operations (rate limiting)
  DateTime? _lastOperationTime;
  static const _minOperationInterval = Duration(seconds: 3);

  SellerRegistrationViewModel(this._ref) : super(SellerRegistrationState());

  /// Check if operation can proceed (rate limiting + double-click prevention)
  bool _canProceed() {
    // Already in progress
    if (_isOperationInProgress || state.isLoading) {
      return false;
    }
    
    // Rate limiting
    if (_lastOperationTime != null) {
      final elapsed = DateTime.now().difference(_lastOperationTime!);
      if (elapsed < _minOperationInterval) {
        return false;
      }
    }
    
    return true;
  }

  /// Extracts a clean error message from Firebase exceptions
  String _cleanErrorMessage(dynamic error, String fallback) {
    if (error is FirebaseFunctionsException) {
      // e.message contains the actual error message from backend
      return error.message ?? fallback;
    }
    // For other exceptions, don't expose raw details
    return fallback;
  }

  /// Direct method to continue onboarding for users who already have an account ID but didn't finish
  Future<void> continueOnboarding() async {
    if (!_canProceed()) return;
    await _continueOnboarding();
  }

  /// Opens the Stripe Express Dashboard via a server-side login link.
  /// Express accounts require stripe.Account.create_login_link called server-side.
  Future<void> openStripeDashboard() async {
    if (!_canProceed()) return;
    
    _isOperationInProgress = true;
    _lastOperationTime = DateTime.now();
    
    try {
      final functions = _ref.read(firebaseFunctionsProvider);
      final callable = functions.httpsCallable(CloudFunctionEndpoints.createStripeLoginLink);
      final result = await callable.call();
      final data = result.data as Map<String, dynamic>;
      final url = data[ApiKeys.url] as String?;
      if (url != null && await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        state = state.copyWith(error: 'Could not open Stripe Dashboard');
      }
    } on FirebaseFunctionsException catch (e) {
      state = state.copyWith(error: _cleanErrorMessage(e, 'Failed to open Stripe Dashboard'));
    } catch (e) {
      state = state.copyWith(error: 'Could not open Stripe Dashboard. Please try again.');
    } finally {
      _isOperationInProgress = false;
    }
  }

  /// Refreshes the user's stripe status from the backend
  Future<void> refreshAccountStatus() async {
    // We don't necessarily need to set loading here to avoid UI flickering on resume
    try {
      final functions = _ref.read(firebaseFunctionsProvider);
      final callable = functions.httpsCallable(CloudFunctionEndpoints.getConnectAccountStatus);
      await callable.call();
      // The cloud function usually updates the user document, which the UI observes via userProfileProvider
    } on FirebaseFunctionsException catch (e) {
      state = state.copyWith(error: _cleanErrorMessage(e, 'Failed to refresh account status'));
    } catch (e) {
      // Silently fail on background refresh - don't show errors for background operations
    }
  }

  Future<void> setPaymentProvider(String provider) async {
    if (state.isLoading) return;
    state = state.copyWith(paymentProvider: provider, error: null, successMessage: null);
    try {
      final functions = _ref.read(firebaseFunctionsProvider);
      await functions.httpsCallable(CloudFunctionEndpoints.updatePaymentProvider).call({ApiKeys.provider: provider});
    } catch (e) {
      state = state.copyWith(error: 'Failed to update payment provider');
    }
  }

  /// Starts the registration process (Step 1)
  Future<void> startRegistration() async {
    if (!_canProceed()) return;
    
    _isOperationInProgress = true;
    _lastOperationTime = DateTime.now();
    state = state.copyWith(isLoading: true, error: null);

    try {
      final functions = _ref.read(firebaseFunctionsProvider);
      final createAccount = functions.httpsCallable(CloudFunctionEndpoints.createConnectAccount);

      await createAccount.call();
      // Result contains account data — proceed to onboarding
      // Note: _continueOnboarding will handle its own cleanup
      await _continueOnboarding();
    } on FirebaseFunctionsException catch (e) {
      state = state.copyWith(isLoading: false, error: _cleanErrorMessage(e, 'Failed to create seller account'));
      _isOperationInProgress = false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'An unexpected error occurred. Please try again.');
      _isOperationInProgress = false;
    }
  }

  /// Generates the onboarding link and launches it (Step 2)
  Future<void> _continueOnboarding() async {
    // If called directly (not from startRegistration), check if we can proceed
    if (!_isOperationInProgress && !_canProceed()) return;
    
    // Track operation if not already tracked by caller
    if (!_isOperationInProgress) {
      _isOperationInProgress = true;
      _lastOperationTime = DateTime.now();
    }
    
    // Note: Loading state is already true if called from startRegistration
    if (!state.isLoading) state = state.copyWith(isLoading: true, error: null);

    try {
      final functions = _ref.read(firebaseFunctionsProvider);
      final createLink = functions.httpsCallable(CloudFunctionEndpoints.createAccountLink);

      // URLs are built server-side for security (open-redirect prevention)
      final result = await createLink.call();

      final data = result.data as Map<String, dynamic>;
      final url = data[ApiKeys.url] as String?;

      if (url != null) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          // Use external browser for Stripe Connect onboarding — SFSafariViewController
          // can have issues with OAuth redirects and bank authentication flows on iOS
          await launchUrl(
            uri,
            mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
            webOnlyWindowName: '_self', // Opens in same tab on web
          );
          state = state.copyWith(isLoading: false);
        } else {
          state = state.copyWith(isLoading: false, error: 'Could not open onboarding link');
        }
      } else {
        state = state.copyWith(isLoading: false, error: 'Failed to generate onboarding link');
      }
    } on FirebaseFunctionsException catch (e) {
      state = state.copyWith(isLoading: false, error: _cleanErrorMessage(e, 'Failed to generate onboarding link'));
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Could not complete onboarding. Please try again.');
    } finally {
      _isOperationInProgress = false;
    }
  }
}
