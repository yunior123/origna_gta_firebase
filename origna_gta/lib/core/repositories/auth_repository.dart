import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:origna_gta/core/constants/validation_constants.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/services/notification_service.dart';
import 'package:origna_gta/services/turnstile_service.dart';
import 'package:origna_gta/utils/env_config.dart';
import 'package:origna_gta/utils/utils.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Returns the device's preferred language if it's one we support (en/fr), else 'en'.
String _deviceLanguage() {
  final code = PlatformDispatcher.instance.locale.languageCode;
  return code == LanguageValues.french ? LanguageValues.french : LanguageValues.english;
}

abstract class AuthRepository {
  Future<void> deleteAccount();
  Future<void> ensureUserDocumentExists(); // ✅ New method to create Firestore document for verified users
  Future<bool> isEmailVerified();
  Future<UserCredential> registerWithEmail(String email, String password, String name, {bool marketingOptIn = false});
  Future<void> sendEmailVerification();
  Future<void> sendPasswordResetEmail(String email);
  Future<UserCredential> signInWithApple();
  Future<UserCredential> signInWithEmail(String email, String password);
  Future<UserCredential> signInWithGoogle();
  Future<void> signOut();

  /// Validates that the current user still exists in Firebase Auth
  /// Returns true if valid, false if user was deleted (and signs out)
  Future<bool> validateCurrentUser();

  Stream<UserModel?> watchProfile(String userId);
}

/// Documentation for FirebaseAuthRepository
class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final bool _isWeb;
  final EnvConfig _envConfig;

  /// For testing purposes only: override Turnstile token generation
  @visibleForTesting
  Future<String?> Function()? turnstileOverride;

  FirebaseAuthRepository(this._auth, this._firestore, this._functions, {bool? isWeb, EnvConfig? envConfig})
    : _isWeb = isWeb ?? kIsWeb,
      _envConfig = envConfig ?? EnvConfig();

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Call the collective delete function which handles Firestore, Auth, and Stripe
    await _functions.httpsCallable(CloudFunctionEndpoints.deleteAccount).call({Fields.confirmation: ConfirmationValues.deleteMyAccount});
  }

  @override
  Future<void> ensureUserDocumentExists() async {
    /// ✅ Create Firestore document for authenticated users (verified or not)
    /// This is called on app startup to ensure users have their profile
    final user = _auth.currentUser;
    if (user == null) return;

    // Reload to get fresh verification status
    try {
      await user.reload();
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Could not reload user: $e');
    }
    final freshUser = _auth.currentUser;
    if (freshUser == null) return;

    // F-80: Create document regardless of verification status to avoid "Broken Auth"
    await _createUserDocumentIfNeeded(freshUser);
    if (kDebugMode) {
      debugPrint('✅ Firestore document ensured for user ${freshUser.email}');
    }
  }

  @override
  Future<bool> isEmailVerified() async {
    /// Check if current user's email is verified
    /// Required before allowing checkout
    /// In emulator mode, always return true (emulator doesn't persist emailVerified reliably)
    final user = _auth.currentUser;
    if (user == null) return false;

    // Bypass in emulator mode — emulator Auth doesn't persist emailVerified
    if (_envConfig.isEmulator) {
      if (kDebugMode) debugPrint('🔧 EMULATOR: Bypassing email verification for ${user.email}');
      return true;
    }

    // Refresh user data to get latest verification status
    await user.reload();
    return user.emailVerified;
  }

  @override
  Future<UserCredential> registerWithEmail(String email, String password, String name, {bool marketingOptIn = false}) async {
    final trimmedEmail = email.trim().toLowerCase();

    if (!ValidationConstants.emailRegex.hasMatch(trimmedEmail)) {
      throw FirebaseAuthException(code: 'invalid-email', message: 'Email format is invalid');
    }

    final userCredential = await _auth.createUserWithEmailAndPassword(email: trimmedEmail, password: password);

    // [F-80] Create Firestore document IMMEDIATELY to avoid "Broken Auth"
    if (userCredential.user != null) {
      await userCredential.user!.updateDisplayName(name);
      if (kDebugMode) debugPrint('✅ Display name "$name" saved to Firebase Auth profile');

      // Call profile creation service BEFORE email verification
      await _createUserDocumentIfNeeded(userCredential.user, name: name, initialMarketingOptIn: marketingOptIn);
    }

    // AUTO-SEND VERIFICATION EMAIL after registration
    if (userCredential.user != null) {
      try {
        await userCredential.user!.sendEmailVerification();
        if (kDebugMode) {
          debugPrint('✅ Verification email sent to $trimmedEmail during registration');
        }
      } catch (e) {
        debugPrint('Failed to send verification email: $e');
      }
    }

    return userCredential;
  }

  @override
  Future<void> sendEmailVerification() async {
    /// EMAIL VERIFICATION - CRITICAL BUSINESS LOGIC
    ///
    /// Issue: Users with typo emails lose access to their account.
    /// Solution: Require email verification before checkout is possible.
    ///
    /// This function:
    /// 1. Sends verification email to user's email address
    /// 2. User must click link and return to app
    /// 3. App checks emailVerified flag before allowing checkout
    ///
    /// Risk if NOT implemented:
    /// - Users register with typo (john@gmial.com instead of john@gmail.com)
    /// - Can't reset password (no email access)
    /// - Loses order history (linked to wrong email)
    /// - Bad UX: can't complete purchases
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'no-current-user', message: 'No authenticated user');
    }

    if (user.emailVerified) {
      if (kDebugMode) debugPrint('✅ Email already verified for ${user.email}');
      return;
    }

    try {
      await user.sendEmailVerification();
      if (kDebugMode) {
        debugPrint('✅ Verification email sent to ${user.email}');
        debugPrint('');
        debugPrint('📧 EMULATOR MODE: Check Emulator UI for verification link');
        debugPrint('   Open: http://localhost:4000/auth');
        debugPrint('   Or toggle "Email Verified" manually');
        debugPrint('');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Failed to send verification email: $e');
      rethrow;
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    final trimmedEmail = email.trim().toLowerCase();

    if (!ValidationConstants.emailRegex.hasMatch(trimmedEmail)) {
      throw FirebaseAuthException(code: 'invalid-email', message: 'Email format is invalid');
    }

    try {
      await _auth.sendPasswordResetEmail(email: trimmedEmail);
    } on FirebaseAuthException catch (e) {
      // SECURITY FIX M-1: Prevent email enumeration
      // Don't expose if email exists or not
      if (e.code == 'user-not-found') {
        // Log for monitoring but return success to client
        if (kDebugMode) {
          debugPrint('[SECURITY] Password reset attempted for non-existent email');
        }
        // Don't throw - client sees success either way
        return;
      }
      // Re-throw other errors (network, etc.)
      rethrow;
    }
    // Client always receives success (no error thrown)
  }

  @override
  Future<UserCredential> signInWithApple() async {
    final appleCredential = await SignInWithApple.getAppleIDCredential(scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName]);

    final OAuthCredential credential = OAuthProvider(
      'apple.com',
    ).credential(idToken: appleCredential.identityToken, accessToken: appleCredential.authorizationCode);

    final userCredential = await _auth.signInWithCredential(credential);

    // Pass name if provided by Apple (Apple only provides it ONCE on first sign-in)
    String? fullName;
    if (appleCredential.givenName != null || appleCredential.familyName != null) {
      fullName = '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'.trim();
    }

    // F-88: Persistent name capture for Apple Sign-In
    if (fullName != null && fullName.isNotEmpty && userCredential.user != null) {
      try {
        await _firestore.collection(Collections.pendingProfiles).doc(userCredential.user!.uid).set({
          Fields.name: fullName,
          Fields.updatedAt: FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Failed to save Apple name to pending_profiles: $e');
      }
    }

    await _createUserDocumentIfNeeded(userCredential.user, name: fullName);
    return userCredential;
  }

  @override
  Future<UserCredential> signInWithEmail(String email, String password) async {
    final trimmedEmail = email.trim().toLowerCase();

    if (!ValidationConstants.emailRegex.hasMatch(trimmedEmail)) {
      throw FirebaseAuthException(code: 'invalid-email', message: 'Email format is invalid');
    }

    final userCredential = await _auth.signInWithEmailAndPassword(email: trimmedEmail, password: password);

    // [F-80] Ensure profile exists regardless of verification status
    if (userCredential.user != null) {
      await _createUserDocumentIfNeeded(userCredential.user);
    }

    return userCredential;
  }

  @override
  Future<UserCredential> signInWithGoogle() async {
    final googleProvider = GoogleAuthProvider();
    googleProvider.addScope('email');
    googleProvider.addScope('profile');

    final UserCredential userCredential;
    if (_isWeb) {
      userCredential = await _auth.signInWithPopup(googleProvider);
    } else {
      userCredential = await _auth.signInWithProvider(googleProvider);
    }

    await _createUserDocumentIfNeeded(userCredential.user);
    return userCredential;
  }

  @override
  Future<void> signOut() async {
    try {
      // Clear FCM token before signing out
      await NotificationService.instance.clearTokenFromFirestore();
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Failed to clear FCM token on sign out: $e');
    }
    await _auth.signOut();

    // On Flutter Web (et parfois avec l'émulateur), la propagation du sign-out
    // peut être asynchrone/retardée. Attendre l'évènement authStateChanges
    // rend l'état UI (gates/providers) beaucoup plus fiable.
    try {
      await _auth.authStateChanges().firstWhere((user) => user == null).timeout(const Duration(seconds: 5));
    } catch (_) {
      // Best-effort only: ne pas bloquer la navigation si l'event tarde.
    }
  }

  @override
  Future<bool> validateCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return true; // No user, nothing to validate

    try {
      // Try to reload the user from Firebase Auth server
      // This will throw if user was deleted from Auth
      await user.reload();
      final freshUser = _auth.currentUser;

      // If email is not verified, the user won't have a Firestore doc yet - that's expected
      // Don't sign them out; they need to verify their email first
      if (freshUser != null && !freshUser.emailVerified && !_envConfig.isEmulator) {
        if (kDebugMode) {
          debugPrint('ℹ️ User ${freshUser.email} email not verified - skipping Firestore profile check');
        }
        return true;
      }

      // Check if Firestore profile exists (only for verified users)
      final doc = await _firestore.collection(Collections.users).doc(user.uid).get();
      if (!doc.exists) {
        if (kDebugMode) {
          debugPrint('⚠️ Verified user profile not found in Firestore, signing out stale session');
        }
        await signOut();
        return false;
      }

      return true;
    } on FirebaseAuthException catch (e) {
      // user-not-found or user-disabled means the account was deleted
      if (e.code == 'user-not-found' || e.code == 'user-disabled' || e.code == 'user-token-expired') {
        if (kDebugMode) {
          debugPrint('⚠️ User account no longer exists (${e.code}), signing out stale session');
        }
        await signOut();
        return false;
      }
      // Network error - don't sign out, could be temporary
      if (kDebugMode) debugPrint('⚠️ Error validating user: ${e.code}');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Unexpected error validating user: $e');
      return true; // Don't sign out on unexpected errors
    }
  }

  @override
  Stream<UserModel?> watchProfile(String userId) {
    return _firestore.collection(Collections.users).doc(userId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromMap({...doc.data()!, Fields.uid: doc.id});
    });
  }

  Future<void> _createUserDocumentIfNeeded(User? user, {String? name, bool? initialMarketingOptIn}) async {
    if (user == null) return;

    // Check if the doc already exists before calling the server (avoids unnecessary CF invocation)
    final userDoc = _firestore.collection(Collections.users).doc(user.uid);
    final docSnapshot = await userDoc.get();

    if (!docSnapshot.exists) {
      // F-82/F-90: Only call the profile creation function if the email is verified
      // to avoid 'failed-precondition' errors for unverified users.
      // Bypass in emulator mode AND for SSO providers (Apple/Google verify email ownership
      // server-side; Firebase may return emailVerified=false on first Apple Sign In with
      // "Hide My Email" relay before the auth token is refreshed).
      final isSsoProvider = user.providerData.any((p) => p.providerId == 'apple.com' || p.providerId == 'google.com');
      if (!user.emailVerified && !_envConfig.isEmulator && !isSsoProvider) {
        // [F-88] Save name to pending_profiles so it's not lost when they eventually verify
        if ((name != null && name.isNotEmpty) || initialMarketingOptIn != null) {
          try {
            final Map<String, dynamic> dataToSave = {Fields.updatedAt: FieldValue.serverTimestamp()};
            if (name != null) dataToSave[Fields.name] = name;
            if (initialMarketingOptIn != null) dataToSave[Fields.marketingOptIn] = initialMarketingOptIn;

            await _firestore.collection(Collections.pendingProfiles).doc(user.uid).set(dataToSave, SetOptions(merge: true));
            if (kDebugMode) debugPrint('✅ Saved unverified user data to pending_profiles for ${user.email}');
          } catch (e) {
            if (kDebugMode) debugPrint('⚠️ Failed to save unverified user data to pending_profiles: $e');
          }
        }
        return;
      }

      final callable = _functions.httpsCallable(CloudFunctionEndpoints.createUserProfile);

      String? savedName = name;
      bool marketingOptIn = initialMarketingOptIn ?? false;

      // F-88: Attempt to recover name from pending_profiles if not provided
      try {
        final pendingDoc = await _firestore.collection(Collections.pendingProfiles).doc(user.uid).get();
        if (pendingDoc.exists) {
          final data = pendingDoc.data();
          if (savedName == null || savedName.isEmpty) {
            savedName = data?[Fields.name] as String?;
          }
          if (initialMarketingOptIn == null) {
            marketingOptIn = data?[Fields.marketingOptIn] as bool? ?? false;
          }
          // Clean up
          await _firestore.collection(Collections.pendingProfiles).doc(user.uid).delete();
        }
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Could not check pending_profiles: $e');
      }

      // SECURITY: All legal-compliance fields (CASL/PIPEDA/Law 25) are set server-side.
      final providerData = user.providerData;
      final isGoogle = providerData.any((p) => p.providerId == 'google.com');
      final isApple = providerData.any((p) => p.providerId == 'apple.com');

      String consentMethod = ConsentMethodValues.signupForm;
      if (isGoogle) consentMethod = ConsentMethodValues.googleOauth;
      if (isApple) consentMethod = ConsentMethodValues.appleOauth;

      // Web: attach Turnstile bot-protection token; mobile uses App Check.
      final turnstileToken = await (turnstileOverride?.call() ?? TurnstileService.getToken());

      await callable.call<Map<String, dynamic>>({
        Fields.name: savedName ?? user.displayName ?? 'User',
        Fields.preferredLanguage: _deviceLanguage(),
        Fields.marketingOptIn: marketingOptIn,
        Fields.consentMethod: consentMethod,
        ApiKeys.turnstileToken: turnstileToken,
      });
    }
    // If doc already exists, roles are managed server-side by the CF — no direct write here.
  }
}
