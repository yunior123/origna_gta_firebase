// coverage:ignore-file
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/repositories/user_repository.dart';
import 'package:origna_gta/core/routes.dart';
import 'package:origna_gta/features/auth/auth_provider.dart';
import 'package:origna_gta/features/seller/seller_account_status_viewmodel.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/widgets/animations.dart';
import 'package:origna_gta/widgets/modern_button.dart';
import 'package:origna_gta/widgets/modern_loading_indicator.dart';

// ─── Flutter Previews ────────────────────────────────────────────────────────

/// Screen shown when seller returns from Stripe Connect onboarding
class SellerSetupCompleteScreen extends ConsumerStatefulWidget {
  const SellerSetupCompleteScreen({super.key});

  @override
  ConsumerState<SellerSetupCompleteScreen> createState() => _SellerSetupCompleteScreenState();
}

/// Screen shown when seller needs to refresh/retry Stripe Connect onboarding
class SellerSetupRefreshScreen extends StatelessWidget {
  const SellerSetupRefreshScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(gradient: DesignTokens.backgroundGradient(isDark: isDark)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: FadeSlideIn(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: DesignTokens.info.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: DesignTokens.info.withValues(alpha: 0.15), blurRadius: 24, offset: const Offset(0, 8))],
                          ),
                          child: Icon(Icons.refresh_rounded, size: 72, color: DesignTokens.info),
                        ),
                        const SizedBox(height: DesignTokens.spacing32),
                        Text(
                          'seller.continue_setup_title'.tr(),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: DesignTokens.spacing16),
                        Text(
                          'seller.continue_setup_body'.tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15, color: DesignTokens.textSecondary, height: 1.6),
                        ),
                        const SizedBox(height: DesignTokens.spacing40),
                        SizedBox(
                          width: double.infinity,
                          child: ModernButton(
                            label: 'seller.continue_setup'.tr(),
                            icon: Icons.arrow_forward_rounded,
                            onPressed: () {
                              Navigator.of(context).pushReplacementNamed(AppRoutes.sellerRegistration);
                            },
                            height: 54,
                          ),
                        ),
                        const SizedBox(height: DesignTokens.spacing12),
                        TextButton(
                          onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false),
                          child: Text(
                            'seller.back_to_home'.tr(),
                            style: TextStyle(color: DesignTokens.primary, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _CheckResult { success, pending, error }

class _SellerSetupCompleteScreenState extends ConsumerState<SellerSetupCompleteScreen> {
  static const _minCheckInterval = Duration(seconds: 10); // Rate limit: 10 seconds between checks
  bool _isRefreshing = false;
  String? _statusMessage;
  DateTime? _lastCheckTime;

  _CheckResult? _checkResult;

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(sellerAccountStatusProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isRefreshing) {
      return Container(
        decoration: BoxDecoration(gradient: DesignTokens.backgroundGradient(isDark: isDark)),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: SingleChildScrollView(
              child: FadeSlideIn(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: DesignTokens.shadowMd,
                      ),
                      child: ShaderMask(
                        shaderCallback: (bounds) => DesignTokens.primaryGradient.createShader(bounds),
                        child: const ModernLoadingIndicator(strokeWidth: 3, color: Colors.white, centered: false),
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spacing20),
                    Text(
                      'seller.checking_status'.tr(),
                      style: TextStyle(fontSize: 15, color: DesignTokens.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(gradient: DesignTokens.backgroundGradient(isDark: isDark)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: statusAsync.when(
                    loading: () => FadeSlideIn(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: DesignTokens.shadowMd,
                            ),
                            child: ShaderMask(
                              shaderCallback: (bounds) => DesignTokens.primaryGradient.createShader(bounds),
                              child: const ModernLoadingIndicator(strokeWidth: 3, color: Colors.white, centered: false),
                            ),
                          ),
                          const SizedBox(height: DesignTokens.spacing20),
                          Text(
                            'seller.verifying_account'.tr(),
                            style: TextStyle(fontSize: 15, color: DesignTokens.textSecondary, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    error: (error, _) => _buildError(context, 'seller.failed_verify'.tr()),
                    data: (status) {
                      if (status.isComplete) {
                        return _buildSuccess(context);
                      } else if (status.isPendingVerification) {
                        return _buildPendingVerification(context);
                      } else {
                        return _buildIncomplete(context, status);
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, String error) {
    return FadeSlideIn(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: DesignTokens.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: DesignTokens.error.withValues(alpha: 0.15), blurRadius: 24, offset: const Offset(0, 8))],
            ),
            child: Icon(Icons.error_outline_rounded, size: 56, color: DesignTokens.error),
          ),
          const SizedBox(height: DesignTokens.spacing24),
          Text(error, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, height: 1.5)),
          const SizedBox(height: DesignTokens.spacing32),
          SizedBox(
            width: double.infinity,
            child: ModernButton(label: 'common.retry'.tr(), onPressed: _checkStatusAgain, height: 52),
          ),
          const SizedBox(height: DesignTokens.spacing12),
          TextButton(
            onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false),
            child: Text(
              'seller.go_home'.tr(),
              style: TextStyle(color: DesignTokens.primary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// User has NOT completed all Stripe requirements yet
  Widget _buildIncomplete(BuildContext context, SellerAccountStatus status) {
    final hasDocumentRequirements = status.needsIdentityDocuments;
    final requirementsDescription = status.pendingRequirementsDescription;

    return FadeSlideIn(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: DesignTokens.warning.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: DesignTokens.warning.withValues(alpha: 0.15), blurRadius: 24, offset: const Offset(0, 8))],
            ),
            child: Icon(hasDocumentRequirements ? Icons.badge_outlined : Icons.assignment_outlined, size: 72, color: DesignTokens.warning),
          ),
          const SizedBox(height: DesignTokens.spacing32),
          Text(
            hasDocumentRequirements ? 'seller.identity_verification_required'.tr() : 'seller.complete_your_setup'.tr(),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DesignTokens.spacing16),
          Text(
            hasDocumentRequirements ? 'seller.stripe_verify_body'.tr() : 'seller.stripe_finish_body'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: DesignTokens.textSecondary, height: 1.6),
          ),
          const SizedBox(height: DesignTokens.spacing24),
          if (requirementsDescription.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: DesignTokens.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(DesignTokens.radius16),
                border: Border.all(color: DesignTokens.warning.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: DesignTokens.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.info_outline_rounded, color: DesignTokens.warning, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'seller.still_needed'.tr(),
                        style: TextStyle(fontWeight: FontWeight.w700, color: DesignTokens.warning, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('• $requirementsDescription', style: TextStyle(fontSize: 14, color: DesignTokens.textPrimary, height: 1.5)),
                ],
              ),
            ),
          ],
          const SizedBox(height: DesignTokens.spacing32),
          SizedBox(
            width: double.infinity,
            child: ModernButton(
              label: hasDocumentRequirements ? 'seller.submit_documents'.tr() : 'seller.continue_setup'.tr(),
              icon: Icons.arrow_forward_rounded,
              onPressed: () {
                Navigator.of(context).pushReplacementNamed(AppRoutes.sellerRegistration);
              },
              height: 54,
              backgroundColor: DesignTokens.warning,
            ),
          ),
          const SizedBox(height: DesignTokens.spacing12),
          TextButton(
            onPressed: _goToHome,
            child: Text(
              'seller.go_to_home'.tr(),
              style: TextStyle(color: DesignTokens.primary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// User has submitted the form but Stripe is verifying identity
  Widget _buildPendingVerification(BuildContext context) {
    return FadeSlideIn(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: DesignTokens.warning.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: DesignTokens.warning.withValues(alpha: 0.15), blurRadius: 24, offset: const Offset(0, 8))],
            ),
            child: Icon(Icons.hourglass_empty_rounded, size: 72, color: DesignTokens.warning),
          ),
          const SizedBox(height: DesignTokens.spacing32),
          Text(
            'seller.identity_pending'.tr(),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DesignTokens.spacing16),
          Text(
            'seller.identity_pending_body'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: DesignTokens.textSecondary, height: 1.6),
          ),
          const SizedBox(height: DesignTokens.spacing40),
          SizedBox(
            width: double.infinity,
            child: ModernButton(label: 'seller.go_to_home'.tr(), onPressed: _goToHome, height: 54),
          ),
          const SizedBox(height: DesignTokens.spacing12),
          TextButton(
            onPressed: _checkStatusAgain,
            child: Text(
              'seller.check_verification'.tr(),
              style: TextStyle(color: DesignTokens.primary, fontWeight: FontWeight.w600),
            ),
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: DesignTokens.spacing16),
            FadeSlideIn(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _checkResult == _CheckResult.success
                      ? DesignTokens.success.withValues(alpha: 0.1)
                      : _checkResult == _CheckResult.error
                      ? DesignTokens.error.withValues(alpha: 0.1)
                      : DesignTokens.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(DesignTokens.radius12),
                ),
                child: Text(
                  _statusMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _checkResult == _CheckResult.success
                        ? DesignTokens.success
                        : _checkResult == _CheckResult.error
                        ? DesignTokens.error
                        : DesignTokens.primary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuccess(BuildContext context) {
    return FadeSlideIn(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: DesignTokens.success.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: DesignTokens.success.withValues(alpha: 0.2), blurRadius: 24, offset: const Offset(0, 8))],
            ),
            child: Icon(Icons.check_circle_rounded, size: 72, color: DesignTokens.success),
          ),
          const SizedBox(height: DesignTokens.spacing32),
          ShaderMask(
            shaderCallback: (bounds) => DesignTokens.primaryGradient.createShader(bounds),
            child: Text(
              'seller.account_ready'.tr(),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: DesignTokens.spacing16),
          Text(
            'seller.account_ready_body'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: DesignTokens.textSecondary, height: 1.5),
          ),
          const SizedBox(height: DesignTokens.spacing40),
          SizedBox(
            width: double.infinity,
            child: ModernButton(label: 'seller.start_selling'.tr(), icon: Icons.storefront_rounded, onPressed: _goToHome, height: 54),
          ),
        ],
      ),
    );
  }

  Future<void> _checkStatusAgain() async {
    // Rate limiting - prevent spam clicking
    if (_lastCheckTime != null) {
      final elapsed = DateTime.now().difference(_lastCheckTime!);
      if (elapsed < _minCheckInterval) {
        final remaining = _minCheckInterval - elapsed;
        setState(() {
          _checkResult = _CheckResult.pending;
          _statusMessage = 'seller.wait_seconds'.tr(namedArgs: {'seconds': remaining.inSeconds.toString()});
        });
        return;
      }
    }

    _lastCheckTime = DateTime.now();

    setState(() {
      _isRefreshing = true;
      _statusMessage = null;
      _checkResult = null;
    });

    try {
      // Use refreshSellerStatusProvider to manually sync with Stripe backend
      // This is the ONLY place where we call the backend - user explicitly requested it
      final status = await ref.read(refreshSellerStatusProvider(null).future);

      // Also invalidate userProfileProvider so HomeScreen gets fresh data
      ref.invalidate(userProfileProvider);

      if (mounted) {
        setState(() {
          _isRefreshing = false;
          if (status.isComplete) {
            _checkResult = _CheckResult.success;
            _statusMessage = 'seller.verification_complete'.tr();
          } else {
            _checkResult = _CheckResult.pending;
            _statusMessage = 'seller.verification_in_progress'.tr();
          }
        });

        // Clear message after 5 seconds
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) {
            setState(() {
              _statusMessage = null;
              _checkResult = null;
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _checkResult = _CheckResult.error;
          _statusMessage = 'seller.status_check_failed'.tr();
        });
      }
    }
  }

  Future<void> _goToHome() async {
    // Show loading indicator
    setState(() => _isRefreshing = true);

    try {
      // Call backend to sync Stripe status with Firestore
      // This ensures chargesEnabled, payoutsEnabled, onboardingCompleted are updated
      await ref.read(refreshSellerStatusProvider(null).future);
    } catch (e) {
      // Ignore errors - we'll still navigate home
    }

    // Refresh user profile to get updated seller status from Firestore
    ref.invalidate(userProfileProvider);

    if (mounted) {
      // Use pushNamedAndRemoveUntil to properly update browser URL on web
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
    }
  }
}
