// coverage:ignore-file
/// Flutter Widget Previewer — Order Status Badges & Cards.
/// Covers all 7 order statuses defined in schema_constants.dart.
/// Run: flutter widget-preview start
library;

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/widgets/orders/order_status_widgets.dart';

import 'package:origna_gta/previews/_preview_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// @Preview functions
// ═══════════════════════════════════════════════════════════════════════════════

// ─── 1. All status badges (compact) ──────────────────────────────────────────

@Preview(name: 'Status Badges — All (dark)', group: 'Order Status')
Widget previewAllStatusBadges() => previewWrapper(
  child: Wrap(
    spacing: DesignTokens.spacing8,
    runSpacing: DesignTokens.spacing8,
    children: OrderStatus.values.map((s) => StatusBadge(status: s)).toList(),
  ),
);

// ─── 2. All status badges (large, light mode) ────────────────────────────────

@Preview(name: 'Status Badges — Large (light)', group: 'Order Status', brightness: Brightness.light)
Widget previewAllStatusBadgesLight() => previewWrapper(
  theme: previewLightTheme,
  background: DesignTokens.surface,
  child: Wrap(
    spacing: DesignTokens.spacing8,
    runSpacing: DesignTokens.spacing8,
    children: OrderStatus.values.map((s) => StatusBadge(status: s, large: true)).toList(),
  ),
);

// ─── 8. Refunded + Pending cards (edge-case statuses) ────────────────────────

@Preview(name: 'Edge-case Status Cards', group: 'Order Status')
Widget previewEdgeCaseCards() => previewGrid(
  children: [
    const OrderSummaryCard(
      orderId: 'E5T2-9981',
      status: OrderStatus.refunded,
      itemCount: 1,
      total: '\$59.99',
      date: 'Mar 1, 2026 · 08:00 AM',
      sellerName: 'Quick Returns Co',
    ),
    const OrderSummaryCard(orderId: 'F3M7-4410', status: OrderStatus.pending, itemCount: 2, total: '\$145.00', date: 'Mar 3, 2026 · 11:55 PM'),
  ],
);

// ─── 6. Empty state — no orders at all ───────────────────────────────────────

@Preview(name: 'Empty State — No orders', group: 'Order Status')
Widget previewEmptyOrders() => previewWrapper(child: const EmptyOrdersCard());

// ─── 7. Empty state — filtered (cancelled) ───────────────────────────────────

@Preview(name: 'Empty State — Filtered (cancelled)', group: 'Order Status')
Widget previewEmptyOrdersFiltered() => previewWrapper(child: const EmptyOrdersCard(filterLabel: 'cancelled'));

// ─── 3. Order summary cards — multiple statuses ───────────────────────────────

@Preview(name: 'Order Summary Cards', group: 'Order Status')
Widget previewOrderSummaryCards() => previewGrid(
  children: [
    const OrderSummaryCard(
      orderId: 'A7F3-2901',
      status: OrderStatus.delivered,
      itemCount: 3,
      total: '\$124.99',
      date: 'Feb 28, 2026 · 09:14 AM',
      sellerName: 'TechNorth CA',
    ),
    const OrderSummaryCard(
      orderId: 'B2K8-5566',
      status: OrderStatus.shipped,
      itemCount: 1,
      total: '\$49.00',
      date: 'Mar 1, 2026 · 02:30 PM',
      sellerName: 'Maple Goods',
    ),
    const OrderSummaryCard(orderId: 'C9R1-7743', status: OrderStatus.processing, itemCount: 5, total: '\$310.50', date: 'Mar 3, 2026 · 11:00 AM'),
    const OrderSummaryCard(
      orderId: 'D4L0-1122',
      status: OrderStatus.cancelled,
      itemCount: 2,
      total: '\$88.00',
      date: 'Mar 2, 2026 · 06:45 PM',
      sellerName: 'Digital Hub',
    ),
  ],
);

// ─── 4. Order timeline — in-progress (shipped is active step) ─────────────────

@Preview(name: 'Order Timeline — Shipped (active)', group: 'Order Status')
Widget previewOrderTimeline() => previewWrapper(
  child: Container(
    padding: const EdgeInsets.all(DesignTokens.spacing20),
    decoration: BoxDecoration(
      color: DesignTokens.darkCard,
      borderRadius: BorderRadius.circular(DesignTokens.radius16),
      border: Border.all(color: DesignTokens.darkOutline, width: 1),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Order Timeline',
          style: TextStyle(color: Colors.white, fontSize: DesignTokens.fontSizeLg, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: DesignTokens.spacing20),
        const TimelineStep(
          status: OrderStatus.confirmed,
          label: 'Order Confirmed',
          subtitle: 'Feb 28, 2026 · 09:14 AM',
          isActive: false,
          isCompleted: true,
          isLast: false,
        ),
        const TimelineStep(
          status: OrderStatus.processing,
          label: 'Processing',
          subtitle: 'Mar 1, 2026 · 10:00 AM',
          isActive: false,
          isCompleted: true,
          isLast: false,
        ),
        const TimelineStep(
          status: OrderStatus.shipped,
          label: 'Shipped',
          subtitle: 'Mar 2, 2026 · 03:22 PM — In transit',
          isActive: true,
          isCompleted: false,
          isLast: false,
        ),
        const TimelineStep(
          status: OrderStatus.delivered,
          label: 'Delivered',
          subtitle: 'Estimated Mar 5, 2026',
          isActive: false,
          isCompleted: false,
          isLast: true,
        ),
      ],
    ),
  ),
);

// ─── 5. Order timeline — fully delivered ─────────────────────────────────────

@Preview(name: 'Order Timeline — Delivered (complete)', group: 'Order Status')
Widget previewOrderTimelineComplete() => previewWrapper(
  child: Container(
    padding: const EdgeInsets.all(DesignTokens.spacing20),
    decoration: BoxDecoration(
      color: DesignTokens.darkCard,
      borderRadius: BorderRadius.circular(DesignTokens.radius16),
      border: Border.all(color: DesignTokens.darkOutline, width: 1),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Order Delivered',
              style: TextStyle(color: Colors.white, fontSize: DesignTokens.fontSizeLg, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: DesignTokens.spacing8),
            const StatusBadge(status: OrderStatus.delivered, large: true),
          ],
        ),
        const SizedBox(height: DesignTokens.spacing20),
        const TimelineStep(
          status: OrderStatus.confirmed,
          label: 'Order Confirmed',
          subtitle: 'Feb 20, 2026 · 08:00 AM',
          isActive: false,
          isCompleted: true,
          isLast: false,
        ),
        const TimelineStep(
          status: OrderStatus.processing,
          label: 'Processing',
          subtitle: 'Feb 21, 2026 · 11:30 AM',
          isActive: false,
          isCompleted: true,
          isLast: false,
        ),
        const TimelineStep(
          status: OrderStatus.shipped,
          label: 'Shipped',
          subtitle: 'Feb 22, 2026 · 04:00 PM',
          isActive: false,
          isCompleted: true,
          isLast: false,
        ),
        const TimelineStep(
          status: OrderStatus.delivered,
          label: 'Delivered',
          subtitle: 'Feb 25, 2026 · 01:15 PM',
          isActive: false,
          isCompleted: true,
          isLast: true,
        ),
      ],
    ),
  ),
);

// ─── 9. Badge color reference sheet ──────────────────────────────────────────

@Preview(name: 'Status Color Reference', group: 'Order Status')
Widget previewStatusColorReference() => previewWrapper(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Order Status — Color Reference',
        style: TextStyle(color: Colors.white, fontSize: DesignTokens.fontSizeLg, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: DesignTokens.spacing16),
      ...(OrderStatus.values.map(
        (s) => Padding(
          padding: const EdgeInsets.only(bottom: DesignTokens.spacing8),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: DesignTokens.spacing8),
              SizedBox(
                width: 110,
                child: Text(
                  s.label,
                  style: const TextStyle(color: Colors.white, fontSize: DesignTokens.fontSizeSm, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                _colorHex(s.color),
                style: const TextStyle(color: DesignTokens.textSecondary, fontSize: DesignTokens.fontSizeXs, fontFamily: 'monospace'),
              ),
              const SizedBox(width: DesignTokens.spacing8),
              StatusBadge(status: s),
            ],
          ),
        ),
      )),
    ],
  ),
);

String _colorHex(Color c) {
  final v = c.toARGB32();
  return '#${v.toRadixString(16).substring(2).toUpperCase()}';
}
