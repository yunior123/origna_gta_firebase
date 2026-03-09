// coverage:ignore-file
import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/routes.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/widgets/modern_button.dart';
import 'package:origna_gta/widgets/modern_loading_indicator.dart';

import '../features/subscription/subscription_provider.dart';

// ─── Flutter Previews ────────────────────────────────────────────────────────

/// Screen displayed after the user completes a Stripe premium subscription checkout.
///
/// Guards itself behind a Firestore `isPremium` check so the success UI only
/// appears once the webhook has fired and the subscription document is updated.
/// A 30-second timeout shows a manual-refresh fallback if activation is delayed.
///
/// Layout is responsive: content is centered and capped at 500 logical pixels
/// wide so it looks correct on mobile, tablet, and desktop.
class SubscriptionSuccessScreen extends ConsumerStatefulWidget {
  const SubscriptionSuccessScreen({super.key});

  @override
  ConsumerState<SubscriptionSuccessScreen> createState() =>
      _SubscriptionSuccessScreenState();
}

/// A single row in the premium benefits list shown on the success screen.
///
/// Renders a rounded icon container on the left, a bold [title] with a
/// checkmark, and a secondary [subtitle] description on the right.
class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;

  const _BenefitRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: DesignTokens.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: DesignTokens.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDark ? Colors.white : DesignTokens.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.check_circle_rounded,
                      color: DesignTokens.success,
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: DesignTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionSuccessScreenState
    extends ConsumerState<SubscriptionSuccessScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _glowAnimation;
  Timer? _activationTimeout;
  bool _timedOut = false;
  DateTime? _backgroundTime;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subAsync = ref.watch(subscriptionStreamProvider);

    // Gate the success UI on actual isPremium=true from Firestore
    final isPremium = subAsync.valueOrNull?.isPremium ?? false;

    // HIGH-021 FIX: Prevent success screen bypass.
    // If timed out and still not premium, show a manual refresh/error state instead of success.
    if (!isPremium) {
      return Semantics(
        label: 'subscription-success-screen',
        child: Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [DesignTokens.darkBackground, DesignTokens.darkSurface]
                    : [DesignTokens.surfaceSubtle, Colors.white],
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_timedOut) ...[
                        const ModernLoadingIndicator(),
                        const SizedBox(height: 24),
                        Text(
                          'subscription.activating_membership'.tr(),
                          style: const TextStyle(
                            fontSize: 16,
                            color: DesignTokens.textSecondary,
                          ),
                        ),
                      ] else ...[
                        const Icon(
                          Icons.timer_off_outlined,
                          size: 64,
                          color: DesignTokens.warning,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'subscription.activation_delayed_title'.tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : DesignTokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'subscription.activation_delayed_desc'.tr(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: DesignTokens.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 32),
                        ModernButton(
                          label: 'common.refresh'.tr(),
                          onPressed: () {
                            setState(() {
                              _timedOut = false;
                              _startTimeout();
                            });
                            ref.invalidate(subscriptionStreamProvider);
                          },
                          icon: Icons.refresh_rounded,
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () =>
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                AppRoutes.home,
                                (route) => false,
                              ),
                          child: Text('common.back_to_home'.tr()),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      label: 'subscription-success-screen',
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [DesignTokens.darkBackground, DesignTokens.darkSurface]
                  : [DesignTokens.surfaceSubtle, Colors.white],
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

                            // Animated premium badge
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _scaleAnimation.value,
                                  child: Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        colors: [
                                          DesignTokens.primary,
                                          DesignTokens.secondary,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: DesignTokens.primary
                                              .withValues(
                                                alpha: _glowAnimation.value,
                                              ),
                                          blurRadius: 32,
                                          spreadRadius: 4,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.workspace_premium,
                                      color: Colors.white,
                                      size: 50,
                                    ),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 32),

                            Text(
                              'subscription.welcome_to_premium'.tr(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? Colors.white
                                    : DesignTokens.textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),

                            const SizedBox(height: 12),

                            Text(
                              'subscription.subscription_active_desc'.tr(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 15,
                                color: DesignTokens.textSecondary,
                                height: 1.5,
                              ),
                            ),

                            const SizedBox(height: 40),

                            _BenefitRow(
                              icon: Icons.percent_rounded,
                              title: 'subscription.no_platform_fee'.tr(),
                              subtitle: 'subscription.no_platform_fee_desc'
                                  .tr(),
                              isDark: isDark,
                            ),
                            _BenefitRow(
                              icon: Icons.chat_bubble_outline_rounded,
                              title: 'subscription.chat_with_sellers'.tr(),
                              subtitle: 'subscription.chat_with_sellers_desc'
                                  .tr(),
                              isDark: isDark,
                            ),
                            _BenefitRow(
                              icon: Icons.question_answer_outlined,
                              title: 'subscription.ask_questions'.tr(),
                              subtitle: 'subscription.ask_questions_desc'.tr(),
                              isDark: isDark,
                            ),
                            _BenefitRow(
                              icon: Icons.photo_camera_outlined,
                              title: 'subscription.photo_reviews'.tr(),
                              subtitle: 'subscription.photo_reviews_desc'.tr(),
                              isDark: isDark,
                            ),
                            _BenefitRow(
                              icon: Icons.notifications_active_outlined,
                              title: 'subscription.smart_notifications'.tr(),
                              subtitle: 'subscription.smart_notifications_desc'
                                  .tr(),
                              isDark: isDark,
                            ),

                            const Spacer(),

                            Semantics(
                              button: true,
                              label: 'btn-start-shopping',
                              child: ModernButton(
                                label: 'subscription.start_shopping'.tr(),
                                onPressed: () => Navigator.of(context)
                                    .pushNamedAndRemoveUntil(
                                      AppRoutes.home,
                                      (route) => false,
                                    ),
                                icon: Icons.shopping_bag_outlined,
                              ),
                            ),

                            const SizedBox(height: 16),
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
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_backgroundTime != null && _activationTimeout?.isActive == true) {
        final elapsed = DateTime.now().difference(_backgroundTime!).inSeconds;
        // If we were backgrounded for a long time, trigger timeout immediately on resume
        if (elapsed > 10 && !_timedOut) {
          _activationTimeout?.cancel();
          setState(() => _timedOut = true);
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _activationTimeout?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _glowAnimation = Tween<double>(begin: 0.25, end: 0.55).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _startTimeout();
  }

  void _startTimeout() {
    _activationTimeout?.cancel();
    // 30s timeout fallback — if webhook is delayed, show a manual refresh prompt
    _activationTimeout = Timer(const Duration(seconds: 30), () {
      if (mounted) setState(() => _timedOut = true);
    });
  }
}
