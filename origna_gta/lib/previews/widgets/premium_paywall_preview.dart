// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/previews/_preview_theme.dart';
import 'package:origna_gta/widgets/premium_paywall_widget.dart';

@Preview(name: 'Premium Paywall — Responsive', group: 'PremiumPaywall')
Widget previewPaywallResponsive() => previewResponsiveBreakpoints(
  builder: (bp) => const Center(child: PremiumPaywallWidget(featureName: 'Global Shipping Discounts')),
);

@Preview(name: 'Premium Paywall — Variants', group: 'PremiumPaywall')
Widget previewPaywallVariants() => previewGrid(
  children: [
    const PremiumPaywallWidget(featureName: 'Product Video Upload'),
    const PremiumPaywallWidget(featureName: 'Advanced Analytics', description: 'Upgrade for detailed insights into your shop sales and visitor behavior.'),
  ],
);

@Preview(name: 'Premium Paywall Light — Responsive', group: 'PremiumPaywall')
Widget previewPaywallResponsiveLight() => previewResponsiveBreakpoints(
  theme: previewLightTheme,
  builder: (bp) => const Center(child: PremiumPaywallWidget(featureName: 'Global Shipping Discounts')),
);

@Preview(name: 'Premium Paywall Light — Variants', group: 'PremiumPaywall')
Widget previewPaywallVariantsLight() => previewGrid(
  theme: previewLightTheme,
  children: [
    const PremiumPaywallWidget(featureName: 'Product Video Upload'),
    const PremiumPaywallWidget(featureName: 'Advanced Analytics', description: 'Upgrade for detailed insights into your shop sales and visitor behavior.'),
  ],
);
