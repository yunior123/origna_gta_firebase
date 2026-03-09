import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/constants/validation_constants.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/services/analytics_service.dart';

import 'login_state.dart';

final loginViewModelProvider = StateNotifierProvider.autoDispose<LoginViewModel, LoginState>((ref) {
  return LoginViewModel(ref);
});

/// Maps Firebase Auth error codes to translation keys.
/// On web, [FirebaseAuthException.message] is often just "Error",
/// so we must rely on [FirebaseAuthException.code] instead.
String _friendlyAuthError(FirebaseAuthException e) {
  switch (e.code) {
    case 'user-not-found':
      return 'auth.errors.user_not_found'.tr();
    case 'wrong-password':
      return 'auth.errors.wrong_password'.tr();
    case 'invalid-credential':
      return 'auth.errors.invalid_credential'.tr();
    case 'invalid-email':
      return 'auth.errors.invalid_email'.tr();
    case 'user-disabled':
      return 'auth.errors.user_disabled'.tr();
    case 'too-many-requests':
      return 'auth.errors.too_many_requests'.tr();
    case 'email-already-in-use':
      return 'auth.errors.email_already_in_use'.tr();
    case 'weak-password':
      return 'auth.errors.weak_password'.tr();
    case 'operation-not-allowed':
      return 'auth.errors.operation_not_allowed'.tr();
    case 'network-request-failed':
      return 'auth.errors.network_error'.tr();
    case 'account-exists-with-different-credential':
      return 'auth.errors.account_exists_different_credential'.tr();
    default:
      if (kDebugMode) {
        debugPrint('⚠️ Unhandled FirebaseAuthException code: ${e.code}, message: ${e.message}');
      }
      return 'auth.errors.authentication_failed'.tr();
  }
}

/// Documentation for LoginViewModel
class LoginViewModel extends StateNotifier<LoginState> {
  final Ref _ref;

  LoginViewModel(this._ref) : super(LoginState());

  Future<void> handleAppleSignIn() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, errorMessage: null);
    final repository = _ref.read(authRepositoryProvider);

    try {
      await repository.signInWithApple();
      unawaited(AnalyticsService.logLogin(method: 'apple'));
      state = state.copyWith(isLoading: false, isSuccess: true);
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _friendlyAuthError(e));
    } catch (e) {
      state = state.copyWith(isLoading: false);
      if (!e.toString().contains('cancelled') && !e.toString().contains('user_cancelled')) {
        state = state.copyWith(errorMessage: 'auth.errors.apple_signin_failed'.tr());
      }
    }
  }

  Future<void> handleAuth({required String email, required String password, String? name, bool marketingOptIn = false}) async {
    if (state.isLoading) return;

    // Validate email for both login and registration
    final emailError = _validateEmail(email);
    if (emailError != null) {
      state = state.copyWith(errorMessage: emailError.tr());
      return;
    }

    // SECURITY FIX M-3: Enforce strong password policy for registration
    if (!state.isLogin) {
      final passwordError = _validatePasswordStrength(password);
      if (passwordError != null) {
        state = state.copyWith(errorMessage: passwordError.tr());
        return;
      }

      // Validate name
      final nameError = _validateName(name);
      if (nameError != null) {
        state = state.copyWith(errorMessage: nameError.tr());
        return;
      }
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    final repository = _ref.read(authRepositoryProvider);

    try {
      if (state.isLogin) {
        await repository.signInWithEmail(email, password);
        // [F-82] Allow sign-in even if not verified, but show a warning or hint in UI if needed.
        // The business logic elsewhere (checkout) will block actions requiring verification.
        unawaited(AnalyticsService.logLogin(method: 'email'));
      } else {
        await repository.registerWithEmail(email, password, name ?? 'User', marketingOptIn: marketingOptIn);
        unawaited(AnalyticsService.logSignUp(method: 'email'));

        // [F-80] Stay signed in after registration so profile is created immediately
        state = state.copyWith(
          isLoading: false,
          successMessage: 'auth.errors.registration_success'.tr(namedArgs: {'email': email}),
          errorMessage: null,
          isSuccess: true,
        );
        return;
      }
      state = state.copyWith(isLoading: false, isSuccess: true);
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        debugPrint('🔐 FirebaseAuthException — code: ${e.code}, message: ${e.message}');
      }
      state = state.copyWith(isLoading: false, errorMessage: _friendlyAuthError(e));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🔐 Unexpected auth error: $e');
      }
      String errorMessage = 'auth.errors.generic_error';
      final errorStr = e.toString().toLowerCase();

      if (errorStr.contains('permission-denied') || errorStr.contains('permission_denied')) {
        errorMessage = state.isLogin ? 'auth.errors.profile_setup_failed' : 'auth.errors.account_creation_failed';
      } else if (errorStr.contains('network')) {
        errorMessage = 'auth.errors.network_error';
      } else if (errorStr.contains('email-already-in-use')) {
        errorMessage = 'auth.errors.email_already_in_use';
      }

      state = state.copyWith(isLoading: false, errorMessage: errorMessage.tr());
    }
  }

  Future<void> handleGoogleSignIn() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, errorMessage: null);
    final repository = _ref.read(authRepositoryProvider);

    try {
      await repository.signInWithGoogle();
      unawaited(AnalyticsService.logLogin(method: 'google'));
      state = state.copyWith(isLoading: false, isSuccess: true);
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _friendlyAuthError(e));
    } catch (e) {
      state = state.copyWith(isLoading: false);
      if (!e.toString().contains('popup-closed') && !e.toString().contains('cancelled')) {
        state = state.copyWith(errorMessage: 'auth.errors.google_signin_failed'.tr());
      }
    }
  }

  Future<void> resetPassword(String email) async {
    await _ref.read(authRepositoryProvider).sendPasswordResetEmail(email);
  }

  void setAcceptedTerms(bool value) {
    state = state.copyWith(acceptedTerms: value);
  }

  void setMarketingOptIn(bool value) {
    state = state.copyWith(marketingOptIn: value);
  }

  void toggleAuthMode() {
    state = state.copyWith(isLogin: !state.isLogin, acceptedTerms: false, marketingOptIn: false);
  }

  void toggleObscurePassword() {
    state = state.copyWith(obscurePassword: !state.obscurePassword);
  }

  /// Validate email format
  String? _validateEmail(String? email) {
    if (email == null || email.trim().isEmpty) {
      return 'auth.validation.email_required_validation';
    }

    final trimmedEmail = email.trim().toLowerCase();

    if (trimmedEmail.length < ValidationConstants.minEmailLength) {
      return 'auth.validation.email_too_short';
    }

    if (trimmedEmail.length > ValidationConstants.maxEmailLength) {
      return 'auth.validation.email_too_long';
    }

    if (!ValidationConstants.emailRegex.hasMatch(trimmedEmail)) {
      return 'auth.validation.email_invalid_validation';
    }

    return null; // Valid
  }

  /// Validate name format (must match Firestore rules)
  String? _validateName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return 'auth.validation.name_required_validation';
    }

    final trimmedName = name.trim();

    if (trimmedName.length < ValidationConstants.minNameLength) {
      return 'auth.validation.name_too_short';
    }

    if (trimmedName.length > ValidationConstants.maxNameLength) {
      return 'auth.validation.name_too_long';
    }

    // Allow any Unicode letter + space/hyphen/apostrophe/period — mirrors backend
    final nameRegex = RegExp(r"^[\p{L} '\-\.·]+$", unicode: true);
    if (!nameRegex.hasMatch(trimmedName)) {
      return 'auth.validation.name_invalid_format';
    }

    return null; // Valid
  }

  /// Validate password strength (SECURITY FIX M-3)
  String? _validatePasswordStrength(String password) {
    // F-84: Enforce centralised password policy for registration
    if (password.length < ValidationConstants.minPasswordLength) {
      return 'auth.validation.password_min_8';
    }
    
    if (!ValidationConstants.passwordRegex.hasMatch(password)) {
      // Specific hints for better UX
      if (!password.contains(RegExp(r'[A-Z]'))) return 'auth.validation.password_uppercase';
      if (!password.contains(RegExp(r'[a-z]'))) return 'auth.validation.password_lowercase';
      if (!password.contains(RegExp(r'[0-9]'))) return 'auth.validation.password_number';
      if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) return 'auth.validation.password_special';
      return 'auth.validation.password_weak';
    }

    // Check against common passwords
    if (ValidationConstants.commonPasswords.contains(password.toLowerCase())) {
      return 'auth.validation.password_common';
    }

    return null; // Valid
  }
}
