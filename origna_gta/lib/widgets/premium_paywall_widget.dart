import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:origna_gta/core/routes.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/widgets/modern_button.dart';

/// Shown when a premium-only feature is accessed by a non-premium user.
class PremiumPaywallWidget extends StatelessWidget {
  final String featureName;
  final String? description;

  const PremiumPaywallWidget({super.key, required this.featureName, this.description});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [DesignTokens.primary.withValues(alpha: 0.08), DesignTokens.secondary.withValues(alpha: 0.08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DesignTokens.primary.withValues(alpha: 0.2), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [DesignTokens.primary, DesignTokens.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: const Icon(Icons.workspace_premium, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            'subscription.premium_required'.tr(),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? DesignTokens.textOnDark : DesignTokens.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            description ?? 'subscription.premium_feature_description'.tr(namedArgs: {'featureName': featureName}),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: DesignTokens.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 20),
          Semantics(
            button: true,
            label: 'btn-upgrade-premium',
            child: ModernButton(
              key: const Key('paywall_upgrade_button'),
              label: 'subscription.upgrade_to_premium'.tr(),
              onPressed: () => Navigator.pushNamed(context, AppRoutes.subscription),
              icon: Icons.workspace_premium,
            ),
          ),
        ],
      ),
    );
  }
}
