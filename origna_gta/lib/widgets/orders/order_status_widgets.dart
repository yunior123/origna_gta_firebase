// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:origna_gta/utils/design_tokens.dart';

/// Documentation for EmptyOrdersCard
class EmptyOrdersCard extends StatelessWidget {
  final String? filterLabel;
  const EmptyOrdersCard({super.key, this.filterLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spacing24, vertical: DesignTokens.spacing40),
      decoration: BoxDecoration(
        color: DesignTokens.darkCard,
        borderRadius: BorderRadius.circular(DesignTokens.radius16),
        border: Border.all(color: DesignTokens.darkOutline, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: DesignTokens.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.receipt_long_outlined, color: DesignTokens.primary, size: 34),
          ),
          const SizedBox(height: DesignTokens.spacing16),
          Text(
            filterLabel != null ? 'No $filterLabel orders' : 'No orders yet',
            style: const TextStyle(color: Colors.white, fontSize: DesignTokens.fontSizeLg, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: DesignTokens.spacing8),
          Text(
            filterLabel != null ? 'You have no orders with "$filterLabel" status.' : 'Your order history will appear here once you make a purchase.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: DesignTokens.textSecondary, fontSize: DesignTokens.fontSizeSm),
          ),
        ],
      ),
    );
  }
}

/// Documentation for InfoChip
class InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const InfoChip({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: DesignTokens.darkSurfaceVariant, borderRadius: BorderRadius.circular(DesignTokens.radius8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: DesignTokens.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: DesignTokens.textSecondary, fontSize: DesignTokens.fontSizeXs),
          ),
        ],
      ),
    );
  }
}

enum OrderStatus { confirmed, processing, shipped, delivered, cancelled, refunded, pending }

/// Documentation for OrderSummaryCard
class OrderSummaryCard extends StatelessWidget {
  final String orderId;

  final OrderStatus status;
  final int itemCount;
  final String total;
  final String date;
  final String? sellerName;
  const OrderSummaryCard({
    super.key,
    required this.orderId,
    required this.status,
    required this.itemCount,
    required this.total,
    required this.date,
    this.sellerName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.darkCard,
        borderRadius: BorderRadius.circular(DesignTokens.radius16),
        border: Border.all(color: DesignTokens.darkOutline, width: 1),
        boxShadow: DesignTokens.shadowMd,
      ),
      padding: const EdgeInsets.all(DesignTokens.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #$orderId',
                    style: const TextStyle(color: Colors.white, fontSize: DesignTokens.fontSizeMd, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date,
                    style: const TextStyle(color: DesignTokens.textSecondary, fontSize: DesignTokens.fontSizeXs),
                  ),
                ],
              ),
              StatusBadge(status: status, large: true),
            ],
          ),
          const SizedBox(height: DesignTokens.spacing12),
          const Divider(color: DesignTokens.darkOutline, height: 1),
          const SizedBox(height: DesignTokens.spacing12),
          Row(
            children: [
              InfoChip(icon: Icons.shopping_bag_outlined, label: '$itemCount item${itemCount == 1 ? '' : 's'}'),
              const SizedBox(width: DesignTokens.spacing8),
              if (sellerName != null) InfoChip(icon: Icons.storefront_outlined, label: sellerName!),
            ],
          ),
          const SizedBox(height: DesignTokens.spacing12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(color: DesignTokens.textSecondary, fontSize: DesignTokens.fontSizeSm),
              ),
              Text(
                total,
                style: const TextStyle(color: Colors.white, fontSize: DesignTokens.fontSizeLg, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Documentation for StatusBadge
class StatusBadge extends StatelessWidget {
  final OrderStatus status;

  final bool large;
  const StatusBadge({super.key, required this.status, this.large = false});

  @override
  Widget build(BuildContext context) {
    final color = status.color;
    final double iconSize = large ? 16 : 13;
    final double fontSize = large ? DesignTokens.fontSizeSm : DesignTokens.fontSizeXs;
    final EdgeInsets padding = large ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6) : const EdgeInsets.symmetric(horizontal: 8, vertical: 4);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(DesignTokens.radius32),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, color: color, size: iconSize),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.w600, letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }
}

/// Documentation for TimelineStep
class TimelineStep extends StatelessWidget {
  final OrderStatus status;

  final String label;
  final String subtitle;
  final bool isActive;
  final bool isCompleted;
  final bool isLast;
  const TimelineStep({
    super.key,
    required this.status,
    required this.label,
    required this.subtitle,
    required this.isActive,
    required this.isCompleted,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final Color nodeColor = isCompleted || isActive ? status.color : DesignTokens.timelineInactiveDark;
    final Color lineColor = isCompleted ? status.color.withValues(alpha: 0.5) : DesignTokens.timelineInactiveDark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 32,
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: nodeColor.withValues(alpha: isActive || isCompleted ? 0.2 : 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(color: nodeColor, width: isActive ? 2 : 1),
                ),
                child: Icon(isCompleted ? Icons.check_rounded : status.icon, color: nodeColor, size: 16),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 36,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(color: lineColor, borderRadius: BorderRadius.circular(1)),
                ),
            ],
          ),
        ),
        const SizedBox(width: DesignTokens.spacing12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isActive || isCompleted ? Colors.white : DesignTokens.textSecondary,
                    fontSize: DesignTokens.fontSizeSm,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: DesignTokens.textSecondary, fontSize: DesignTokens.fontSizeXs),
                ),
                SizedBox(height: isLast ? 0 : DesignTokens.spacing24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

extension OrderStatusX on OrderStatus {
  Color get color => switch (this) {
    OrderStatus.confirmed => DesignTokens.info,
    OrderStatus.processing => DesignTokens.primary,
    OrderStatus.shipped => DesignTokens.statusShipped,
    OrderStatus.delivered => DesignTokens.success,
    OrderStatus.cancelled => DesignTokens.error,
    OrderStatus.refunded => DesignTokens.warning,
    OrderStatus.pending => DesignTokens.textSecondary,
  };

  IconData get icon => switch (this) {
    OrderStatus.confirmed => Icons.check_circle_outline,
    OrderStatus.processing => Icons.autorenew_rounded,
    OrderStatus.shipped => Icons.local_shipping_outlined,
    OrderStatus.delivered => Icons.inventory_2_outlined,
    OrderStatus.cancelled => Icons.cancel_outlined,
    OrderStatus.refunded => Icons.replay_rounded,
    OrderStatus.pending => Icons.hourglass_empty_rounded,
  };

  String get label => switch (this) {
    OrderStatus.confirmed => 'Confirmed',
    OrderStatus.processing => 'Processing',
    OrderStatus.shipped => 'Shipped',
    OrderStatus.delivered => 'Delivered',
    OrderStatus.cancelled => 'Cancelled',
    OrderStatus.refunded => 'Refunded',
    OrderStatus.pending => 'Pending',
  };
}
