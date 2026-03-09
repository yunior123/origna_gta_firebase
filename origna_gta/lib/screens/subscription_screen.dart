// coverage:ignore-file
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/features/auth/auth_provider.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/utils/responsive_layout.dart';
import 'package:origna_gta/widgets/custom_app_bar.dart';
import 'package:origna_gta/widgets/mascot/shop_mascot.dart';
import 'package:origna_gta/widgets/modern_loading_indicator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/subscription/subscription_provider.dart';
import '../features/subscription/subscription_state.dart';

/// Documentation for SubscriptionScreen
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAsync = ref.watch(subscriptionStreamProvider);
    final vmState = ref.watch(subscriptionViewModelProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen(subscriptionViewModelProvider.select((s) => s.checkoutUrl), (prev, next) async {
      if (next != null && next.isNotEmpty) {
        await launchUrl(Uri.parse(next), mode: LaunchMode.externalApplication);
        ref.read(subscriptionViewModelProvider.notifier).clearCheckoutUrl();
      }
    });

    return Container(
      decoration: BoxDecoration(gradient: DesignTokens.backgroundGradient(isDark: isDark)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBarFactory.simple(title: 'subscription.premium_membership'.tr()),
        body: subAsync.when(
          loading: () => const Center(child: ModernLoadingIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: DesignTokens.error),
                  const SizedBox(height: 12),
                  Text(
                    'common.error_loading'.tr(),
                    style: TextStyle(color: DesignTokens.error, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          data: (subInfo) => _buildContent(context, ref, vmState, subInfo, isDark),
        ),
      ),
    );
  }

  Widget _buildBenefitCard(IconData icon, Color iconColor, String title, String subtitle, {String? semanticsLabel, bool isDark = false}) {
    return Semantics(
      label: semanticsLabel,
      container: true,
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? DesignTokens.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.08)) : null,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [iconColor.withValues(alpha: 0.15), iconColor.withValues(alpha: 0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: isDark ? DesignTokens.textOnDark : DesignTokens.textPrimary)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: TextStyle(fontSize: 13, color: isDark ? DesignTokens.textOnDarkSecondary : DesignTokens.textSecondary, height: 1.4)),
                  ],
                ),
              ),
              const Icon(Icons.check_circle_rounded, color: DesignTokens.success, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, SubscriptionState vmState, SubscriptionInfo? subInfo, bool isDark) {
    final vm = ref.read(subscriptionViewModelProvider.notifier);
    final isPremium = subInfo?.isPremium ?? false;
    final userAsync = ref.watch(userProfileProvider);
    final notifyNew = userAsync.valueOrNull?.notifyNewProducts ?? false;
    final notifyTrending = userAsync.valueOrNull?.notifyTrending ?? false;

    // Benefit icon colours — each gets its own semantic colour
    const benefitIcons = [
      (Icons.percent_rounded,         DesignTokens.success),
      (Icons.chat_bubble_outline_rounded, DesignTokens.primary),
      (Icons.question_answer_outlined, DesignTokens.secondary),
      (Icons.notifications_active_outlined, DesignTokens.warning),
      (Icons.photo_camera_outlined,   DesignTokens.tertiary),
    ];

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: ResponsiveBreakpoints.contentMaxWidth),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Hero section (dark gradient, premium feel) ──────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [DesignTokens.gradientStart, DesignTokens.gradientMiddle, DesignTokens.gradientEnd],
              ),
            ),
            child: Stack(
              children: [
                // Decorative blobs
                Positioned(
                  top: -30, right: -30,
                  child: Container(
                    width: 160, height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [DesignTokens.accent.withValues(alpha: 0.18), Colors.transparent]),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -20, left: -40,
                  child: Container(
                    width: 140, height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [DesignTokens.tertiary.withValues(alpha: 0.15), Colors.transparent]),
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 36, 24, 36),
                  child: Column(
                    children: [
                      // Mascot + Glow ring row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Mascot cheering on the left
                          _PremiumMascot(isPremium: isPremium),
                          const SizedBox(width: 16),
                      // Glow ring + icon
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [DesignTokens.warning, DesignTokens.tertiary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(color: DesignTokens.warning.withValues(alpha: 0.5), blurRadius: 32, spreadRadius: 4),
                            BoxShadow(color: DesignTokens.warning.withValues(alpha: 0.2), blurRadius: 60, spreadRadius: 10),
                          ],
                        ),
                        child: const Icon(Icons.workspace_premium, color: Colors.white, size: 50),
                      ),
                        ], // Row children
                      ), // Row
                      const SizedBox(height: 20),
                      // "✨ PREMIUM" chip badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('✨', style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 6),
                            Text(
                              isPremium ? 'subscription.badge_premium_member'.tr() : 'subscription.badge_unlock_premium'.tr(),
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Semantics(
                        label: isPremium ? 'lbl-premium-member' : 'lbl-upgrade-to-premium',
                        container: true,
                        excludeSemantics: true,
                        child: Text(
                          isPremium ? 'subscription.youre_premium_member'.tr() : 'subscription.upgrade_to_premium'.tr(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Semantics(
                        label: isPremium ? 'lbl-enjoy-benefits' : 'lbl-price-monthly',
                        container: true,
                        excludeSemantics: true,
                        child: Text(
                          isPremium ? 'subscription.enjoy_benefits'.tr() : 'subscription.price_monthly'.tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Benefits list ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildBenefitCard(
                  benefitIcons[0].$1, benefitIcons[0].$2,
                  'subscription.no_platform_fee'.tr(), 'subscription.no_platform_fee_desc'.tr(),
                  semanticsLabel: 'benefit-no-platform-fee',
                  isDark: isDark,
                ),
                _buildBenefitCard(
                  benefitIcons[1].$1, benefitIcons[1].$2,
                  'subscription.chat_with_sellers'.tr(), 'subscription.chat_with_sellers_desc'.tr(),
                  semanticsLabel: 'benefit-chat-with-sellers',
                  isDark: isDark,
                ),
                _buildBenefitCard(
                  benefitIcons[2].$1, benefitIcons[2].$2,
                  'subscription.ask_questions'.tr(), 'subscription.ask_questions_desc'.tr(),
                  semanticsLabel: 'benefit-ask-questions',
                  isDark: isDark,
                ),
                _buildBenefitCard(
                  benefitIcons[3].$1, benefitIcons[3].$2,
                  'subscription.smart_notifications'.tr(), 'subscription.smart_notifications_desc'.tr(),
                  semanticsLabel: 'benefit-smart-notifications',
                  isDark: isDark,
                ),
                _buildBenefitCard(
                  benefitIcons[4].$1, benefitIcons[4].$2,
                  'subscription.photo_reviews'.tr(), 'subscription.photo_reviews_desc'.tr(),
                  semanticsLabel: 'benefit-photo-reviews',
                  isDark: isDark,
                ),
                const SizedBox(height: 24),

                if (isPremium) ...[
                  _buildStatusCard(subInfo!, isDark),
                  const SizedBox(height: 24),
                  _buildNotificationPrefs(ref, vm, notifyNew, notifyTrending, isDark),
                  const SizedBox(height: 24),
                  if (!subInfo.cancelAtPeriodEnd)
                    Semantics(
                      button: true,
                      label: 'btn-cancel-subscription',
                      child: OutlinedButton(
                        onPressed: vmState.isLoading ? null : () => _confirmCancel(context, vm),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: DesignTokens.error,
                          side: BorderSide(color: DesignTokens.error),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: vmState.isLoading
                            ? const ModernLoadingIndicator(size: 20)
                            : Text('subscription.cancel_subscription'.tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    )
                  else
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: DesignTokens.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: DesignTokens.warning.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            'subscription.subscription_ends_on'.tr(namedArgs: {'date': _formatDate(subInfo.currentPeriodEnd)}),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: DesignTokens.warning, fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Semantics(
                          button: true,
                          label: 'btn-reactivate-subscription',
                          child: OutlinedButton(
                            onPressed: vmState.isLoading ? null : () => vm.reactivateSubscription(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: DesignTokens.primary,
                              side: BorderSide(color: DesignTokens.primary),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: vmState.isLoading
                                ? const ModernLoadingIndicator(size: 20)
                                : Text('subscription.reactivate_subscription'.tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                ] else ...[
                  if (vmState.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        vmState.errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: DesignTokens.error, fontSize: 14),
                      ),
                    ),
                  // Premium CTA with golden gradient
                  Semantics(
                    button: true,
                    label: 'btn-subscribe-premium',
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [DesignTokens.tertiary, DesignTokens.warning, DesignTokens.tertiary],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(DesignTokens.radius16),
                        boxShadow: [BoxShadow(color: DesignTokens.warning.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))],
                      ),
                      child: vmState.isLoading
                          ? const Center(child: ModernLoadingIndicator(size: 24, color: Colors.white))
                          : Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: vmState.isLoading ? null : vm.createSubscription,
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.workspace_premium, color: Colors.white, size: 22),
                                      const SizedBox(width: 10),
                                      Text(
                                        'subscription.subscribe_button'.tr(),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.3),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    ),
      ), // ConstrainedBox
    ); // Align
  }

  Widget _buildNotificationPrefs(WidgetRef ref, SubscriptionViewModel vm, bool notifyNew, bool notifyTrending, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? DesignTokens.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? DesignTokens.darkOutline : DesignTokens.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'subscription.notification_preferences'.tr(),
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? DesignTokens.textOnDark : DesignTokens.textPrimary),
            ),
          ),
          GestureDetector(
            onTap: () => vm.updateNotificationPreferences(notifyNewProducts: !notifyNew),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('subscription.new_products'.tr(), style: const TextStyle(fontSize: 14)),
                        Text('subscription.new_products_desc'.tr(), style: const TextStyle(fontSize: 12, height: 1.5, color: DesignTokens.textSecondary)),
                      ],
                    ),
                  ),
                  Semantics(
                    label: 'switch-notify-new-products',
                    child: SizedBox(
                      height: 28,
                      child: Switch.adaptive(
                        value: notifyNew,
                        onChanged: (val) => vm.updateNotificationPreferences(notifyNewProducts: val),
                        activeThumbColor: DesignTokens.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () => vm.updateNotificationPreferences(notifyTrending: !notifyTrending),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('subscription.trending_products'.tr(), style: const TextStyle(fontSize: 14)),
                        Text('subscription.trending_products_desc'.tr(), style: const TextStyle(fontSize: 12, color: DesignTokens.textSecondary)),
                      ],
                    ),
                  ),
                  Semantics(
                    label: 'switch-notify-trending',
                    child: SizedBox(
                      height: 28,
                      child: Switch.adaptive(
                        value: notifyTrending,
                        onChanged: (val) => vm.updateNotificationPreferences(notifyTrending: val),
                        activeThumbColor: DesignTokens.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(SubscriptionInfo info, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [DesignTokens.primary.withValues(alpha: 0.1), DesignTokens.secondary.withValues(alpha: 0.1)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text('subscription.status_label'.tr(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: DesignTokens.textSecondary, fontSize: 13))),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: DesignTokens.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                child: Text(
                  info.status.toUpperCase(),
                  style: TextStyle(color: DesignTokens.success, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          if (info.currentPeriodEnd != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: Text('subscription.renews_label'.tr(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: DesignTokens.textSecondary, fontSize: 13))),
                const SizedBox(width: 8),
                Text(
                  _formatDate(info.currentPeriodEnd),
                  style: TextStyle(color: isDark ? DesignTokens.textOnDark : DesignTokens.textPrimary, fontWeight: FontWeight.w500, fontSize: 13),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _confirmCancel(BuildContext context, SubscriptionViewModel vm) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('subscription.cancel_premium_title'.tr()),
        content: Text('subscription.cancel_premium_body'.tr()),
        actions: [
          Semantics(
            button: true,
            label: 'btn-keep-premium',
            child: TextButton(onPressed: () => Navigator.pop(ctx), child: Text('subscription.keep_premium'.tr())),
          ),
          Semantics(
            button: true,
            label: 'btn-confirm-cancel-subscription',
            child: TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                vm.cancelSubscription();
              },
              child: Text('subscription.cancel_subscription'.tr(), style: TextStyle(color: DesignTokens.error)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return DateFormat('MMM d, yyyy').format(date);
  }
}

// Mascot that celebrates premium — lives in the subscription hero
class _PremiumMascot extends StatefulWidget {
  final bool isPremium;
  const _PremiumMascot({required this.isPremium});

  @override
  State<_PremiumMascot> createState() => _PremiumMascotState();
}

class _PremiumMascotState extends State<_PremiumMascot> {
  late final MascotController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MascotController();
    _controller.setExcitement(widget.isPremium ? 1.0 : 0.6);
    if (widget.isPremium) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.jump();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShopMascot(controller: _controller, size: 72, showSpeechBubble: false);
  }
}

// ─── Flutter Previews ────────────────────────────────────────────────────────

