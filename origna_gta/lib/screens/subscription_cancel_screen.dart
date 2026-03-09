// coverage:ignore-file
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:origna_gta/core/routes.dart';
import 'package:origna_gta/utils/design_tokens.dart';

// ─── Flutter Previews ────────────────────────────────────────────────────────

/// Screen shown when the user cancels Stripe checkout before completing payment.
///
/// Reassures the user that no charge was made and offers two CTAs:
/// - **Resubscribe** — returns to [AppRoutes.subscription] to retry.
/// - **Back to Home** — clears the navigation stack and returns to [AppRoutes.home].
///
/// Layout is responsive: content is centered and capped at 500 logical pixels
/// wide so it looks correct on mobile, tablet, and desktop.
class SubscriptionCancelScreen extends StatelessWidget {
  const SubscriptionCancelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [DesignTokens.darkBackground, DesignTokens.darkSurface]
                : [DesignTokens.surface, Colors.white],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 24,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Spacer(),

                          // Neutral icon
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: DesignTokens.textDisabled.withValues(
                                alpha: 0.1,
                              ),
                              border: Border.all(
                                color: DesignTokens.outline,
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.workspace_premium_outlined,
                              color: DesignTokens.textSecondary,
                              size: 44,
                            ),
                          ),

                          const SizedBox(height: 32),

                          Text(
                            'subscription.checkout_cancelled'.tr(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : DesignTokens.textPrimary,
                            ),
                          ),

                          const SizedBox(height: 12),

                          Text(
                            'subscription.no_charge_message'.tr(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              color: DesignTokens.textSecondary,
                              height: 1.5,
                            ),
                          ),

                          const SizedBox(height: 48),

                          // Resubscribe
                          Semantics(
                            button: true,
                            label: 'btn-resubscribe',
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => Navigator.of(
                                  context,
                                ).pushReplacementNamed(AppRoutes.subscription),
                                icon: const Icon(Icons.workspace_premium),
                                label: Text(
                                  'subscription.upgrade_to_premium'.tr(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: DesignTokens.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Back to home
                          Semantics(
                            button: true,
                            label: 'btn-back-home',
                            child: SizedBox(
                              width: double.infinity,
                              child: TextButton(
                                onPressed: () => Navigator.of(context)
                                    .pushNamedAndRemoveUntil(
                                      AppRoutes.home,
                                      (route) => false,
                                    ),
                                style: TextButton.styleFrom(
                                  foregroundColor: DesignTokens.textSecondary,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                child: Text('subscription.back_to_home'.tr()),
                              ),
                            ),
                          ),

                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
