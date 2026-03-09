// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/routes.dart';
import 'package:origna_gta/features/auth/auth_provider.dart';
import 'package:origna_gta/utils/constants.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/utils/env_config.dart';
import 'package:origna_gta/widgets/animations.dart';
import 'package:origna_gta/widgets/custom_app_bar.dart';
import 'package:origna_gta/widgets/modern_button.dart';
import 'package:origna_gta/widgets/modern_loading_indicator.dart';

/// Gate widget that requires user to have admin role before showing child.
/// Must be placed inside [AuthRequiredGate] to guarantee user is authenticated.
class AdminRequiredGate extends ConsumerWidget {
  final Widget child;

  const AdminRequiredGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userProfile = ref.watch(userProfileProvider).valueOrNull;

    // Still loading profile — show spinner
    if (userProfile == null) {
      return Container(
        decoration: BoxDecoration(gradient: DesignTokens.backgroundGradient(isDark: isDark)),
        child: const Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: ModernLoadingIndicator()),
        ),
      );
    }

    // Not admin — redirect home
    if (!userProfile.roles.contains(UserRoles.admin)) {
      return Container(
        decoration: BoxDecoration(gradient: DesignTokens.backgroundGradient(isDark: isDark)),
        child: Scaffold(
          appBar: AppBarFactory.simple(title: 'admin.access_denied'.tr()),
          backgroundColor: Colors.transparent,
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: FadeSlideIn(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: DesignTokens.error.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: Icon(Icons.admin_panel_settings_rounded, size: 56, color: DesignTokens.error),
                    ),
                    const SizedBox(height: DesignTokens.spacing20),
                    Text(
                      'admin.privileges_required'.tr(),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ModernButton(
                      label: 'seller.go_home'.tr(),
                      icon: Icons.home_outlined,
                      isPrimary: false,
                      isOutlined: true,
                      onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return child;
  }
}

/// Gate widget that requires user to be authenticated before showing child
class AuthRequiredGate extends ConsumerWidget {
  final Widget child;

  const AuthRequiredGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return authState.when(
      loading: () => Container(
        decoration: BoxDecoration(gradient: DesignTokens.backgroundGradient(isDark: isDark)),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: ShaderMask(
              shaderCallback: (bounds) => DesignTokens.primaryGradient.createShader(bounds),
              child: const ModernLoadingIndicator(color: Colors.white, strokeWidth: 3, centered: false),
            ),
          ),
        ),
      ),
      error: (error, _) => ErrorScreen(message: 'errors.auth_error'.tr(namedArgs: {'error': error.toString()})),
      data: (user) {
        if (user == null) {
          return Container(
            decoration: BoxDecoration(gradient: DesignTokens.backgroundGradient(isDark: isDark)),
            child: Scaffold(
              appBar: AppBarFactory.simple(title: 'auth.sign_in_required'.tr()),
              backgroundColor: Colors.transparent,
              body: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Padding(
                    padding: const EdgeInsets.all(DesignTokens.spacing24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FadeSlideIn(
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [DesignTokens.primary.withValues(alpha: 0.12), DesignTokens.secondary.withValues(alpha: 0.08)]),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.lock_outline_rounded, size: 56, color: DesignTokens.primary),
                          ),
                        ),
                        const SizedBox(height: 24),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 50),
                          child: Text(
                            'auth.please_sign_in'.tr(),
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : DesignTokens.textPrimary),
                          ),
                        ),
                        const SizedBox(height: 8),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 100),
                          child: Text(
                            'auth.need_account_access'.tr(),
                            style: TextStyle(fontSize: 14, color: DesignTokens.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 32),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 150),
                          child: ModernButton(
                            label: 'auth.sign_in'.tr(),
                            icon: Icons.login_rounded,
                            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.login),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 200),
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false),
                            child: Text(
                              'seller.go_home'.tr(),
                              style: TextStyle(color: DesignTokens.primary, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        // Gate: block suspended users from all protected routes.
        // Wait for profile to load before granting access — null profile is not a pass.
        final userProfileAsync = ref.watch(userProfileProvider);
        if (userProfileAsync.isLoading) {
          return const Scaffold(body: Center(child: ModernLoadingIndicator(centered: false)));
        }
        // Fail closed on error — never grant access when profile can't be loaded
        if (userProfileAsync.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: DesignTokens.error),
                    const SizedBox(height: 16),
                    Text('auth.profile_load_error'.tr(), textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          );
        }
        final userProfile = userProfileAsync.valueOrNull;
        if (userProfile?.suspended == true) {
          return Container(
            decoration: BoxDecoration(gradient: DesignTokens.backgroundGradient(isDark: isDark)),
            child: Scaffold(
              appBar: AppBarFactory.simple(title: 'auth.account_suspended'.tr()),
              backgroundColor: Colors.transparent,
              body: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: FadeSlideIn(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: DesignTokens.error.withValues(alpha: 0.1), shape: BoxShape.circle),
                          child: Icon(Icons.block_rounded, size: 56, color: DesignTokens.error),
                        ),
                        const SizedBox(height: DesignTokens.spacing20),
                        Text('auth.account_suspended'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: DesignTokens.spacing8),
                        Text('auth.contact_support'.tr(), style: TextStyle(color: DesignTokens.textSecondary)),
                        const SizedBox(height: 32),
                        ModernButton(
                          label: 'seller.go_home'.tr(),
                          icon: Icons.home_outlined,
                          isPrimary: false,
                          isOutlined: true,
                          onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        // Gate: block unverified email users from protected routes
        if (!user.emailVerified && !user.providerData.any((p) => p.providerId == 'google.com') && !EnvConfig().isEmulator) {
          return const EmailVerificationRequiredScreen();
        }
        return child;
      },
    );
  }
}

/// Screen shown when user needs to verify their email before accessing a feature
class EmailVerificationRequiredScreen extends ConsumerStatefulWidget {
  const EmailVerificationRequiredScreen({super.key});

  @override
  ConsumerState<EmailVerificationRequiredScreen> createState() => _EmailVerificationRequiredScreenState();
}

/// Generic error screen
class ErrorScreen extends StatelessWidget {
  final String message;

  const ErrorScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(gradient: DesignTokens.backgroundGradient(isDark: isDark)),
      child: Scaffold(
        appBar: AppBarFactory.simple(title: 'errors.error_title'.tr()),
        backgroundColor: Colors.transparent,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.all(DesignTokens.spacing24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FadeSlideIn(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [DesignTokens.error.withValues(alpha: 0.15), DesignTokens.error.withValues(alpha: 0.08)]),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.error_outline_rounded, size: 64, color: DesignTokens.error),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 50),
                    child: Text(
                      'errors.generic_error'.tr(),
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: isDark ? Colors.white : DesignTokens.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 100),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: DesignTokens.textSecondary, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 32),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 150),
                    child: ModernButton(
                      label: 'seller.go_home'.tr(),
                      icon: Icons.home_outlined,
                      onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmailVerificationRequiredScreenState extends ConsumerState<EmailVerificationRequiredScreen> {
  bool _isChecking = false;
  bool _isResending = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(gradient: DesignTokens.backgroundGradient(isDark: isDark)),
      child: Scaffold(
        appBar: AppBarFactory.simple(title: 'email_verification.title'.tr()),
        backgroundColor: Colors.transparent,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(DesignTokens.spacing24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeSlideIn(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [DesignTokens.warning.withValues(alpha: 0.15), DesignTokens.warning.withValues(alpha: 0.08)]),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.mark_email_unread_outlined, size: 56, color: DesignTokens.warning),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 50),
                    child: Text(
                      'email_verification.title'.tr(),
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: isDark ? Colors.white : DesignTokens.textPrimary),
                    ),
                  ),
                  if (user?.email != null) ...[
                    const SizedBox(height: 8),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 75),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(color: DesignTokens.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          user!.email!,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: DesignTokens.primary),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 100),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? DesignTokens.darkSurfaceVariant.withValues(alpha: 0.5) : DesignTokens.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? DesignTokens.textPrimary : DesignTokens.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('email_verification.instruction_title'.tr(), style: TextStyle(fontSize: 14, color: DesignTokens.textSecondary, height: 1.5)),
                          const SizedBox(height: 16),
                          _buildStep(context, '1', 'email_verification.step1'.tr()),
                          _buildStep(context, '2', 'email_verification.step2'.tr()),
                          _buildStep(context, '3', 'email_verification.step3'.tr()),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 150),
                    child: ModernButton(
                      label: _isChecking ? 'email_verification.checking'.tr() : 'email_verification.verify_button'.tr(),
                      icon: Icons.check_circle_outline,
                      isLoading: _isChecking,
                      onPressed: _isChecking ? () {} : _checkVerification,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 175),
                    child: ModernButton(
                      label: _isResending ? 'email_verification.sending'.tr() : 'email_verification.resend_button'.tr(),
                      icon: Icons.send_outlined,
                      isPrimary: false,
                      isLoading: _isResending,
                      onPressed: _isResending ? () {} : _resendEmail,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 200),
                    child: TextButton.icon(
                      onPressed: () async {
                        await ref.read(authRepositoryProvider).signOut();
                        if (context.mounted) {
                          Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
                        }
                      },
                      icon: Icon(Icons.logout, size: 16, color: DesignTokens.textSecondary),
                      label: Text(
                        'email_verification.different_account'.tr(),
                        style: TextStyle(color: DesignTokens.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, String number, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(gradient: DesignTokens.primaryGradient, shape: BoxShape.circle),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 14, color: isDark ? DesignTokens.outlineVariant : DesignTokens.textPrimary, height: 1.4)),
          ),
        ],
      ),
    );
  }

  Future<void> _checkVerification() async {
    setState(() => _isChecking = true);
    try {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        await user.reload();
        final freshUser = ref.read(firebaseAuthProvider).currentUser;
        if (freshUser != null && freshUser.emailVerified) {
          await ref.read(authRepositoryProvider).ensureUserDocumentExists();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('🎉 ${'email_verification.verified_success'.tr()}'),
                backgroundColor: DesignTokens.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('email_verification.not_verified_error'.tr()), backgroundColor: DesignTokens.warning, behavior: SnackBarBehavior.floating),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('errors.verification_error'.tr()), backgroundColor: DesignTokens.error, behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _resendEmail() async {
    setState(() => _isResending = true);
    try {
      await ref.read(authRepositoryProvider).sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ ${'email_verification.sent_success'.tr()}'), backgroundColor: DesignTokens.primary, behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().contains('too-many-requests') ? 'email_verification.too_many_requests'.tr() : 'email_verification.send_failed'.tr()),
            backgroundColor: DesignTokens.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }
}

// ─── Flutter Previews ────────────────────────────────────────────────────────

