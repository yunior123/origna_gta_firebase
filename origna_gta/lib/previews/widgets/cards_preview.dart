// coverage:ignore-file
/// Flutter Widget Previewer — ModernCard variants.
library;

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/widgets/modern_card.dart';

import 'package:origna_gta/previews/_preview_theme.dart';

@Preview(name: 'Basic card — dark', group: 'Cards')
Widget previewCardBasic() => previewWrapper(
  child: ModernCard(
    onTap: () {},
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: DesignTokens.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.store_outlined, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Toronto Vintage', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                  Text('4.8 ★  ·  142 sales', style: TextStyle(color: Colors.white54, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(color: Colors.white12),
        const SizedBox(height: 12),
        const Text('Vintage clothing from the 80s and 90s. Authenticated and curated.', style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
      ],
    ),
  ),
);

@Preview(name: 'Info card — stats', group: 'Cards')
Widget previewCardStats() => previewWrapper(
  child: ModernCard(
    child: Column(
      children: [
        const Text('Order Summary', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
        const SizedBox(height: 16),
        _statRow('Subtotal', '\$89.99'),
        _statRow('Platform Fee (2.5%)', '\$2.25'),
        _statRow('Estimated Tax', '\$11.70'),
        _statRow('Shipping', '\$12.00'),
        const Divider(color: Colors.white12, height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('Total', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
            Text('\$115.94', style: TextStyle(color: DesignTokens.primary, fontWeight: FontWeight.w700, fontSize: 20)),
          ],
        ),
      ],
    ),
  ),
);

Widget _statRow(String label, String value) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
    ],
  ),
);

@Preview(name: 'Alert card — warning', group: 'Cards')
Widget previewCardWarning() => previewWrapper(
  child: ModernCard(
    backgroundColor: DesignTokens.warning.withValues(alpha: 0.15),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: DesignTokens.warning.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.warning_amber_rounded, color: DesignTokens.warning, size: 22),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Stock running low', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              Text('Only 2 items left in stock.', style: TextStyle(color: Colors.white54, fontSize: 13)),
            ],
          ),
        ),
      ],
    ),
  ),
);

@Preview(name: 'Success card', group: 'Cards')
Widget previewCardSuccess() => previewWrapper(
  child: ModernCard(
    backgroundColor: DesignTokens.success.withValues(alpha: 0.12),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: DesignTokens.success.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_outline, color: DesignTokens.success, size: 28),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Order Placed!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
              Text('Your order #ORD-2025-8472 is confirmed.', style: TextStyle(color: Colors.white60, fontSize: 13)),
            ],
          ),
        ),
      ],
    ),
  ),
);

@Preview(name: 'Empty state card', group: 'Cards')
Widget previewCardEmpty() => previewWrapper(
  child: ModernCard(
    child: Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: DesignTokens.primaryGradient,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 16),
        const Text('No orders yet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18)),
        const SizedBox(height: 8),
        const Text('Browse the marketplace and\nplace your first order.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5)),
      ],
    ),
  ),
);

@Preview(name: 'Light mode', group: 'Cards', brightness: Brightness.light)
Widget previewCardLight() => previewWrapper(
  theme: previewLightTheme,
  background: DesignTokens.surface,
  child: ModernCard(
    backgroundColor: Colors.white,
    onTap: () {},
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Product Title', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        SizedBox(height: 4),
        Text('By Toronto Vintage  ·  4.8 ★', style: TextStyle(color: DesignTokens.textSecondary, fontSize: 13)),
        SizedBox(height: 12),
        Text('\$89.99 CAD', style: TextStyle(color: DesignTokens.primary, fontWeight: FontWeight.w700, fontSize: 22)),
      ],
    ),
  ),
);
