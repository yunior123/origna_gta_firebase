// coverage:ignore-file
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/routes.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/features/cart/cart_provider.dart';
import 'package:origna_gta/features/orders/buyer_orders_viewmodel.dart';
import 'package:origna_gta/models/generated/models.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/widgets/animations.dart';
import 'package:origna_gta/widgets/modern_loading_indicator.dart';
import 'package:origna_gta/widgets/rating_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

/// Maps per-item delivery status string → 3-step package timeline step.
/// Steps: 0=Preparing, 1=Shipped, 2=Delivered
int getItemDeliveryStep(String status) {
  switch (status) {
    case DeliveryStatusValues.pending:
      return 0;
    case DeliveryStatusValues.shipped:
      return 1;
    case DeliveryStatusValues.delivered:
      return 2;
    default:
      return -1; // terminal (refunded)
  }
}

StatusConfig getItemStatusConfig(String status) {
  if (status == OrderStatusValues.confirmed) {
    return StatusConfig(
      color: DesignTokens.info,
      icon: Icons.verified_outlined,
      label: 'orders.status.confirmed'.tr(),
      description: 'orders.status.confirmed_desc'.tr(),
    );
  } else if (status == OrderStatusValues.processing) {
    return StatusConfig(
      color: DesignTokens.primary,
      icon: Icons.autorenew,
      label: 'orders.status.processing'.tr(),
      description: 'orders.status.processing_desc'.tr(),
    );
  } else if (status == OrderStatusValues.shipped) {
    return StatusConfig(
      color: DesignTokens.statusShipped,
      icon: Icons.local_shipping,
      label: 'orders.status.shipped'.tr(),
      description: 'orders.status.shipped_desc'.tr(),
    );
  } else if (status == OrderStatusValues.delivered) {
    return StatusConfig(
      color: DesignTokens.success,
      icon: Icons.check_circle,
      label: 'orders.status.delivered'.tr(),
      description: 'orders.status.delivered_desc'.tr(),
    );
  } else if (status == DeliveryStatusValues.refunded) {
    return StatusConfig(
      color: DesignTokens.warning,
      icon: Icons.money_off,
      label: 'orders.status.refunded'.tr(),
      description: 'orders.status.refunded_desc'.tr(),
    );
  } else if (status == OrderStatusValues.cancelled) {
    return StatusConfig(
      color: DesignTokens.error,
      icon: Icons.cancel_outlined,
      label: 'orders.status.cancelled'.tr(),
      description: 'orders.status.cancelled_desc'.tr(),
    );
  } else if (status == OrderStatusValues.disputed) {
    return StatusConfig(color: DesignTokens.error, icon: Icons.gavel, label: 'orders.status.disputed'.tr(), description: 'orders.status.disputed_desc'.tr());
  } else if (status == OrderStatusValues.inTransit) {
    return StatusConfig(
      color: DesignTokens.info,
      icon: Icons.local_shipping_rounded,
      label: 'orders.status.in_transit'.tr(),
      description: 'orders.status.in_transit_desc'.tr(),
    );
  } else if (status == OrderStatusValues.failed) {
    return StatusConfig(
      color: DesignTokens.error,
      icon: Icons.error_rounded,
      label: 'orders.status.failed'.tr(),
      description: 'orders.status.failed_desc'.tr(),
    );
  } else if (status == OrderStatusValues.expired) {
    return StatusConfig(
      color: DesignTokens.textSecondary,
      icon: Icons.timer_off_rounded,
      label: 'orders.status.expired'.tr(),
      description: 'orders.status.expired_desc'.tr(),
    );
  } else if (status == OrderStatusValues.partiallyRefunded) {
    return StatusConfig(
      color: DesignTokens.warning,
      icon: Icons.money_off_rounded,
      label: 'orders.status.partially_refunded'.tr(),
      description: 'orders.status.partially_refunded_desc'.tr(),
    );
  } else {
    return StatusConfig(
      color: DesignTokens.secondary,
      icon: Icons.hourglass_empty,
      label: 'orders.status.pending'.tr(),
      description: 'orders.status.pending_desc'.tr(),
    );
  }
}

StatusConfig getOrderStatusConfig(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return StatusConfig(
        color: DesignTokens.secondary,
        icon: Icons.hourglass_empty,
        label: 'orders.status.pending'.tr(),
        description: 'orders.status.pending_desc'.tr(),
      );
    case OrderStatus.confirmed:
      return StatusConfig(
        color: DesignTokens.info,
        icon: Icons.verified_outlined,
        label: 'orders.status.confirmed'.tr(),
        description: 'orders.status.confirmed_desc'.tr(),
      );
    case OrderStatus.processing:
      return StatusConfig(
        color: DesignTokens.primary,
        icon: Icons.autorenew,
        label: 'orders.status.processing'.tr(),
        description: 'orders.status.processing_desc'.tr(),
      );
    case OrderStatus.shipped:
      return StatusConfig(
        color: DesignTokens.statusShipped,
        icon: Icons.local_shipping,
        label: 'orders.status.shipped'.tr(),
        description: 'orders.status.shipped_desc'.tr(),
      );
    case OrderStatus.inTransit:
      return StatusConfig(
        color: DesignTokens.statusInTransit,
        icon: Icons.flight_takeoff,
        label: 'orders.status.in_transit'.tr(),
        description: 'orders.status.in_transit_desc'.tr(),
      );
    case OrderStatus.delivered:
      return StatusConfig(
        color: DesignTokens.success,
        icon: Icons.check_circle,
        label: 'orders.status.delivered'.tr(),
        description: 'orders.status.delivered_desc'.tr(),
      );
    case OrderStatus.cancelled:
      return StatusConfig(
        color: DesignTokens.error,
        icon: Icons.cancel_outlined,
        label: 'orders.status.cancelled'.tr(),
        description: 'orders.status.cancelled_desc'.tr(),
      );
    case OrderStatus.failed:
      return StatusConfig(
        color: DesignTokens.error,
        icon: Icons.error_outline,
        label: 'orders.status.failed'.tr(),
        description: 'orders.status.failed_desc'.tr(),
      );
    case OrderStatus.expired:
      return StatusConfig(
        color: DesignTokens.textSecondary,
        icon: Icons.timer_off,
        label: 'orders.status.expired'.tr(),
        description: 'orders.status.expired_desc'.tr(),
      );
    case OrderStatus.disputed:
      return StatusConfig(color: DesignTokens.error, icon: Icons.gavel, label: 'orders.status.disputed'.tr(), description: 'orders.status.disputed_desc'.tr());
    case OrderStatus.refunded:
      return StatusConfig(color: DesignTokens.info, icon: Icons.replay, label: 'orders.status.refunded'.tr(), description: 'orders.status.refunded_desc'.tr());
    case OrderStatus.partiallyRefunded:
      return StatusConfig(
        color: DesignTokens.info,
        icon: Icons.replay,
        label: 'orders.status.partially_refunded'.tr(),
        description: 'orders.status.partially_refunded_desc'.tr(),
      );
  }
}

int getTimelineStep(OrderStatus status) {
  switch (status) {
    case OrderStatus.confirmed:
      return 0;
    case OrderStatus.processing:
      return 1;
    case OrderStatus.shipped:
      return 2;
    case OrderStatus.inTransit:
      return 3;
    case OrderStatus.delivered:
      return 4;
    default:
      return -1;
  }
}

// ─── Flutter Widget Previews ─────────────────────────────────────────────────

/// Documentation for BookDownloadButton
class BookDownloadButton extends ConsumerStatefulWidget {
  final OrderItem item;
  const BookDownloadButton({super.key, required this.item});

  @override
  ConsumerState<BookDownloadButton> createState() => _BookDownloadButtonState();
}

// ============================================================================
// WIDGETS
// ============================================================================

/// Documentation for BuyerOrderCard
class BuyerOrderCard extends ConsumerStatefulWidget {
  final Order order;
  final bool isDetailView;
  const BuyerOrderCard({super.key, required this.order, this.isDetailView = false});

  @override
  ConsumerState<BuyerOrderCard> createState() => _BuyerOrderCardState();
}

// ============================================================================
// DIGITAL ITEM ACTIONS
// ============================================================================

/// Documentation for DigitalItemActions
class DigitalItemActions extends ConsumerWidget {
  final OrderItem item;
  const DigitalItemActions({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.licenseKey != null) ...[
            Text('orders.license_key'.tr(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: SelectableText(item.licenseKey!, style: const TextStyle(fontFamily: 'monospace', fontSize: 13, letterSpacing: 1.2)),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: 'common.copy'.tr(),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: item.licenseKey!));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('orders.license_key_copied'.tr()), duration: const Duration(seconds: 2)));
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (item.digitalType == DigitalTypeValues.software && item.digitalBuilds != null) SoftwareDownloadLinks(item: item),
          if (item.digitalType == DigitalTypeValues.book) BookDownloadButton(item: item),
        ],
      ),
    );
  }
}

/// Documentation for OrderStatusTimeline
class OrderStatusTimeline extends StatelessWidget {
  static const _steps = [Icons.verified_outlined, Icons.autorenew, Icons.local_shipping, Icons.flight_takeoff, Icons.check_circle];
  static const _stepColors = [
    DesignTokens.info, // confirmed
    DesignTokens.primary, // processing
    DesignTokens.statusShipped, // shipped
    DesignTokens.statusInTransit, // in transit
    DesignTokens.success, // delivered
  ];

  static List<String> get _stepLabels => [
    'orders.status.confirmed'.tr(),
    'orders.status.processing'.tr(),
    'orders.status.shipped'.tr(),
    'orders.status.in_transit'.tr(),
    'orders.status.delivered'.tr(),
  ];

  final int currentStep;

  const OrderStatusTimeline({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveColor = isDark ? Colors.white12 : Colors.black12;

    return SizedBox(
      height: 70,
      child: Row(
        children: List.generate(_steps.length * 2 - 1, (index) {
          if (index.isEven) {
            final stepIndex = index ~/ 2;
            final isCompleted = stepIndex < currentStep;
            final isCurrent = stepIndex == currentStep;
            final isActive = isCompleted || isCurrent;
            final color = _stepColors[stepIndex];

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: isCurrent ? 36 : 28,
                  height: isCurrent ? 36 : 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isActive ? LinearGradient(colors: [color, color.withValues(alpha: 0.7)]) : null,
                    color: isActive ? null : inactiveColor,
                    boxShadow: isCurrent ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 2)] : null,
                  ),
                  child: Icon(
                    isCompleted ? Icons.check_rounded : _steps[stepIndex],
                    size: isCurrent ? 18 : 14,
                    color: isActive ? Colors.white : (isDark ? Colors.white38 : Colors.black38),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _stepLabels[stepIndex],
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isActive ? color : (isDark ? Colors.white38 : Colors.black38),
                  ),
                ),
              ],
            );
          } else {
            final lineIndex = index ~/ 2;
            final isCompleted = lineIndex < currentStep;
            final fromColor = _stepColors[lineIndex];
            final toColor = _stepColors[lineIndex + 1];

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    gradient: isCompleted ? LinearGradient(colors: [fromColor, toColor]) : null,
                    color: isCompleted ? null : inactiveColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            );
          }
        }),
      ),
    );
  }
}

/// Documentation for PendingApprovalsBanner
class PendingApprovalsBanner extends StatelessWidget {
  final int count;
  const PendingApprovalsBanner({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(
      beginOffset: const Offset(0, -0.1),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [DesignTokens.warning, DesignTokens.warning.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(DesignTokens.radius16),
          boxShadow: [BoxShadow(color: DesignTokens.warning.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(DesignTokens.radius16),
          child: InkWell(
            onTap: () => Navigator.pushNamed(context, AppRoutes.shippingApproval),
            borderRadius: BorderRadius.circular(DesignTokens.radius16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.pending_actions, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'orders.orders_need_approval'.tr(namedArgs: {'count': count.toString()}),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'orders.review_shipping_cost'.tr(),
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.chevron_right, color: Colors.white, size: 20),
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

/// Compact 3-step timeline for a single seller's package.
/// Steps: Preparing → Shipped → Delivered
class SellerPackageTimeline extends StatelessWidget {
  static const _steps = [Icons.inventory_2_outlined, Icons.local_shipping_outlined, Icons.check_circle_outline];
  static const _stepColors = [
    DesignTokens.primary, // Preparing
    DesignTokens.statusShipped, // Shipped
    DesignTokens.success, // Delivered
  ];

  static List<String> get _stepLabels => ['orders.status.processing'.tr(), 'orders.status.shipped'.tr(), 'orders.status.delivered'.tr()];

  final int currentStep;
  const SellerPackageTimeline({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveColor = isDark ? Colors.white12 : Colors.black12;

    return SizedBox(
      height: 64,
      child: Row(
        children: List.generate(_steps.length * 2 - 1, (index) {
          if (index.isEven) {
            final stepIndex = index ~/ 2;
            final isCompleted = stepIndex < currentStep;
            final isCurrent = stepIndex == currentStep;
            final isActive = isCompleted || isCurrent;
            final color = _stepColors[stepIndex];
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: isCurrent ? 34 : 26,
                  height: isCurrent ? 34 : 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isActive ? LinearGradient(colors: [color, color.withValues(alpha: 0.7)]) : null,
                    color: isActive ? null : inactiveColor,
                    boxShadow: isCurrent ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 2)] : null,
                  ),
                  child: Icon(
                    isCompleted ? Icons.check_rounded : _steps[stepIndex],
                    size: isCurrent ? 17 : 13,
                    color: isActive ? Colors.white : (isDark ? Colors.white38 : Colors.black38),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _stepLabels[stepIndex],
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isActive ? color : (isDark ? Colors.white38 : Colors.black38),
                  ),
                ),
              ],
            );
          } else {
            final lineIndex = index ~/ 2;
            final isCompleted = lineIndex < currentStep;
            final fromColor = _stepColors[lineIndex];
            final toColor = _stepColors[lineIndex + 1];
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 17),
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    gradient: isCompleted ? LinearGradient(colors: [fromColor, toColor]) : null,
                    color: isCompleted ? null : inactiveColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            );
          }
        }),
      ),
    );
  }
}

/// Documentation for SoftwareDownloadLinks
class SoftwareDownloadLinks extends ConsumerStatefulWidget {
  final OrderItem item;
  const SoftwareDownloadLinks({super.key, required this.item});

  @override
  ConsumerState<SoftwareDownloadLinks> createState() => _SoftwareDownloadLinksState();
}

// ============================================================================
// STATUS MODELS & HELPERS
// ============================================================================

/// Documentation for StatusConfig
class StatusConfig {
  final Color color;
  final IconData icon;
  final String label;
  final String description;

  const StatusConfig({required this.color, required this.icon, required this.label, required this.description});
}

class _BookDownloadButtonState extends ConsumerState<BookDownloadButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: _loading ? const SizedBox(width: 16, height: 16, child: ModernLoadingIndicator.small()) : const Icon(Icons.download_outlined, size: 16),
      label: Text('orders.download_book'.tr()),
      onPressed: _loading ? null : _download,
    );
  }

  Future<void> _download() async {
    setState(() => _loading = true);
    try {
      final result = await ref.read(firebaseFunctionsProvider).httpsCallable(CloudFunctionEndpoints.generateBookDownloadSession).call({
        Fields.licenseKey: widget.item.licenseKey,
      });
      final downloadUrl = result.data[ApiKeys.downloadUrl] as String?;
      if (downloadUrl == null) throw Exception('Download URL not available');
      await launchUrl(Uri.parse(downloadUrl), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('orders.download_failed'.tr())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _BuyerOrderCardState extends ConsumerState<BuyerOrderCard> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final order = widget.order;
    final statusConfig = getOrderStatusConfig(order.orderStatus);
    final isAuthorized = order.paymentStatus == PaymentStatus.authorized;
    final isPendingApproval = order.shippingApprovalStatus == ShippingApprovalStatus.pending;
    final isTerminal = [
      OrderStatus.cancelled,
      OrderStatus.failed,
      OrderStatus.expired,
      OrderStatus.disputed,
      OrderStatus.refunded,
      OrderStatus.partiallyRefunded,
    ].contains(order.orderStatus);

    return Container(
      margin: widget.isDetailView ? EdgeInsets.zero : const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? DesignTokens.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(DesignTokens.radius20),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : DesignTokens.primary.withValues(alpha: 0.12), width: 1),
        boxShadow: widget.isDetailView
            ? []
            : [
                BoxShadow(
                  color: DesignTokens.primary.withValues(alpha: isDark ? 0.15 : 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: DesignTokens.textPrimary.withValues(alpha: isDark ? 0.3 : 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── ORDER HEADER ───────────────────────────────────
          _buildHeader(order, statusConfig, isDark),

          // ─── TERMINAL BADGE (cancelled / failed / refunded) ─────────
          if (isTerminal) _buildTerminalBadge(statusConfig, isDark),

          // ─── STATUS DESCRIPTION ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [statusConfig.color.withValues(alpha: 0.1), statusConfig.color.withValues(alpha: 0.04)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(DesignTokens.radius12),
                border: Border.all(color: statusConfig.color.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(statusConfig.icon, size: 18, color: statusConfig.color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      statusConfig.description,
                      style: TextStyle(fontSize: 13, color: statusConfig.color, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── PAYMENT BANNER (authorized orders, NOT delivered/terminal) ──
          if (isAuthorized && !isTerminal && order.orderStatus != OrderStatus.delivered)
            Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 16), child: _buildPaymentStatusBanner(isPendingApproval)),

          // ─── DIVIDER ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Divider(height: 1, color: (isDark ? Colors.white : DesignTokens.textSecondary).withValues(alpha: 0.1)),
          ),

          // ─── SELLER PACKAGES (Amazon-style per-seller grouping) ─────
          _buildSellerPackages(order, isDark),

          // ─── PRICE BREAKDOWN ─────────────────────────────────
          Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 8), child: _buildPriceBreakdown(order, isDark)),

          // ─── BUY AGAIN (delivered orders only) ──────────────
          if (order.orderStatus == OrderStatus.delivered)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: SizedBox(
                width: double.infinity,
                child: _actionButton(
                  icon: Icons.replay_rounded,
                  label: 'orders.buy_again'.tr(),
                  color: DesignTokens.primary,
                  onTap: () => _reorderItems(order),
                ),
              ),
            ),

          // ─── DELIVERY ADDRESS ───────────────────────────────
          if (order.shippingAddress != null)
            Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 0), child: _buildAddressSection(order.shippingAddress!, isDark)),

          // ─── DELIVERY INSTRUCTIONS ───────────────────────────
          if (order.deliveryInstructions != null && order.deliveryInstructions!.isNotEmpty)
            Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 20), child: _buildDeliveryInstructionsSection(order.deliveryInstructions!, isDark))
          else
            const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _actionButton({IconData? icon, required String label, required Color color, bool isLoading = false, VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radius12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color.withValues(alpha: 0.12), color.withValues(alpha: 0.04)]),
            borderRadius: BorderRadius.circular(DesignTokens.radius12),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                ModernLoadingIndicator(size: 14, strokeWidth: 2, color: color, centered: false)
              else if (icon != null)
                Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressSection(Address address, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'orders.shipping_to'.tr(),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: DesignTokens.textSecondary),
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(address.street, style: TextStyle(fontSize: 13, color: isDark ? Colors.white : DesignTokens.textPrimary)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text('${address.city}, ${address.state} ${address.postalCode}', style: TextStyle(fontSize: 13, color: DesignTokens.textSecondary)),
        ),
      ],
    );
  }

  Widget _buildDeliveryInstructionsSection(String instructions, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'orders.delivery_instructions'.tr(),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: DesignTokens.textSecondary),
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Text(instructions, style: TextStyle(fontSize: 13, color: isDark ? Colors.white : DesignTokens.textPrimary)),
        ),
      ],
    );
  }

  Widget _buildEstimatedDelivery(OrderItem item, DateTime orderDate, bool isCanada, bool isDark) {
    // International adds ~7 additional business days on top of seller's estimate
    final extraDays = isCanada ? 0 : 7;
    // Calculate from the order creation date, not DateTime.now()
    final earliest = orderDate.add(Duration(days: item.estimatedShipDays + extraDays));
    final latest = earliest.add(const Duration(days: 3));
    final fmt = DateFormat('MMM d');
    final rangeStr = '${fmt.format(earliest)} – ${fmt.format(latest)}';

    return Row(
      children: [
        Icon(Icons.access_time_rounded, size: 13, color: DesignTokens.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'orders.est_delivery'.tr(namedArgs: {'date': rangeStr}),
            style: const TextStyle(fontSize: 11, color: DesignTokens.textSecondary, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(Order order, StatusConfig statusConfig, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusConfig.color.withValues(alpha: 0.06), Colors.transparent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(DesignTokens.radius20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: statusConfig.color,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: statusConfig.color.withValues(alpha: 0.5), blurRadius: 6)],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      statusConfig.label.toUpperCase(),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusConfig.color, letterSpacing: 1.2),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [isDark ? Colors.white : DesignTokens.textPrimary, isDark ? DesignTokens.outlineVariant : DesignTokens.textPrimary],
                  ).createShader(bounds),
                  child: Text(
                    'orders.order_id_prefix'.tr() + (order.orderId.length > 8 ? order.orderId.substring(0, 8).toUpperCase() : order.orderId.toUpperCase()),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMMM dd, yyyy · h:mm a').format(order.createdAt),
                  style: TextStyle(color: DesignTokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: DesignTokens.primaryGradient,
              borderRadius: BorderRadius.circular(DesignTokens.radius16),
              boxShadow: [BoxShadow(color: DesignTokens.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Text(
              '\$${order.total.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(BuildContext context, OrderItem item, bool isOrderConfirmed) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusConfig = getItemStatusConfig(item.status);
    final isDelivered = item.status == OrderStatusValues.delivered;
    final isConfirmed = item.confirmedByBuyer == true || isOrderConfirmed;
    final isConfirmingThis = ref.watch(buyerOrdersViewModelProvider.select((s) => s.confirmingItemId)) == '${widget.order.orderId}_${item.productId}';
    final isRated = widget.order.ratings.any((r) => r.productId == item.productId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : DesignTokens.surfaceVariant,
        borderRadius: BorderRadius.circular(DesignTokens.radius16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : DesignTokens.textSecondary.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _productImage(item.imageUrls.isNotEmpty ? item.imageUrls.first : null),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white : DesignTokens.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _infoPill('orders.qty_prefix'.tr(namedArgs: {'count': item.quantity.toString()}), isDark),
                        _infoPill('\$${item.price.toStringAsFixed(2)}', isDark),
                      ],
                    ),
                    if (item.variantTitle != null && item.variantTitle!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (item.variantOptions != null)
                            ...item.variantOptions!.entries.map(
                              (e) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark ? DesignTokens.darkCard : DesignTokens.surfaceVariant,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: DesignTokens.outline.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  '${e.key}: ${e.value}',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : DesignTokens.textSecondary),
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark ? DesignTokens.darkCard : DesignTokens.surfaceVariant,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.variantTitle!,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : DesignTokens.textSecondary),
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (!item.isDigital && item.trackingNumber != null && item.trackingNumber!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildTrackingWidget(item, isDark),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [statusConfig.color.withValues(alpha: 0.15), statusConfig.color.withValues(alpha: 0.05)]),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusConfig.color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusConfig.icon, size: 14, color: statusConfig.color),
                    const SizedBox(width: 4),
                    Text(
                      statusConfig.label,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusConfig.color),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // ── Digital item: license key + download actions ──
          if (item.isDigital && item.digitalUnlocked == true) ...[const SizedBox(height: 12), DigitalItemActions(item: item)],

          if (isDelivered) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.only(top: 14),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: DesignTokens.textSecondary.withValues(alpha: 0.1))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!isConfirmed && !isOrderConfirmed)
                    _actionButton(
                      icon: isConfirmingThis ? null : Icons.check_circle_outline,
                      label: isConfirmingThis ? 'orders.confirming'.tr() : 'orders.confirm_receipt'.tr(),
                      color: DesignTokens.success,
                      isLoading: isConfirmingThis,
                      onTap: isConfirmingThis ? null : () => _confirmReceipt(item),
                    ),
                  if (isConfirmed || isOrderConfirmed) _statusIndicator(Icons.verified, 'orders.confirmed_action'.tr(), DesignTokens.success),
                  const SizedBox(width: 10),
                  if (!isRated)
                    _actionButton(
                      icon: Icons.star_outline_rounded,
                      label: 'orders.rate_action'.tr(),
                      color: DesignTokens.warning,
                      onTap: () => showRatingDialog(context: context, orderId: widget.order.orderId, productId: item.productId, productName: item.name),
                    ),
                  if (isRated) _statusIndicator(Icons.star_rounded, 'orders.rated_action'.tr(), DesignTokens.warning),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentStatusBanner(bool isPendingApproval) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DesignTokens.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DesignTokens.info.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: DesignTokens.info),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isPendingApproval ? 'orders.payment_waiting_approval'.tr() : 'orders.payment_authorized'.tr(),
              style: const TextStyle(fontSize: 12, color: DesignTokens.info, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceBreakdown(Order order, bool isDark) {
    row(String label, String value, {bool bold = false, Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: bold ? (isDark ? Colors.white : DesignTokens.textPrimary) : DesignTokens.textSecondary,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: color ?? (bold ? (isDark ? Colors.white : DesignTokens.textPrimary) : DesignTokens.textSecondary),
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : DesignTokens.textPrimary).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(DesignTokens.radius12),
      ),
      child: Column(
        children: [
          row('orders.subtotal'.tr(), '\$${order.subtotal.toStringAsFixed(2)}'),
          if (order.discountAmountCents > 0)
            row('orders.discount'.tr(), '-\$${(order.discountAmountCents / 100).toStringAsFixed(2)}', color: DesignTokens.success),
          if (order.shippingCostCents > 0) row('orders.shipping'.tr(), '\$${order.shippingCost.toStringAsFixed(2)}'),
          if (order.taxAmountCents > 0) ...[
            row('orders.tax'.tr(), '\$${order.taxAmount.toStringAsFixed(2)}'),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('GST/HST# ${EmailConfig.gstHstNumber}', style: TextStyle(fontSize: 10, color: DesignTokens.textSecondary.withValues(alpha: 0.7))),
              ),
            ),
          ],
          const SizedBox(height: 4),
          row('orders.total'.tr(), '\$${order.total.toStringAsFixed(2)}', bold: true),
        ],
      ),
    );
  }

  Widget _buildSellerPackage(List<OrderItem> items, Order order, bool isDark, {required int index, required int total}) {
    final first = items.first;
    final sellerName = (first.sellerName?.isNotEmpty == true) ? first.sellerName! : 'orders.unknown_seller'.tr();
    final country = first.sellerAddress?.country ?? '';
    final isCanada = country.toLowerCase().contains('canada') || country.toLowerCase() == 'ca';

    final hasPerishable = items.any((i) => i.isPerishable);

    // Compute the most-behind item's step for this package's collective status, excluding completely refunded terminal items
    final activeItems = items.where((i) => i.status != DeliveryStatusValues.refunded).toList();
    final steps = activeItems.isNotEmpty ? activeItems.map((i) => getItemDeliveryStep(i.status)).toList() : [-1];
    final packageStep = steps.reduce((a, b) => a < b ? a : b);

    // Package is terminal ONLY if EVERY item is refunded, not if just one is.
    final isTerminalPackage = items.every((i) => i.status == DeliveryStatusValues.refunded);
    final isDelivered = packageStep == 2;

    // Representative status config = worst active item's
    final worstItem = activeItems.isNotEmpty
        ? activeItems.firstWhere((i) => getItemDeliveryStep(i.status) == packageStep, orElse: () => activeItems.first)
        : items.first;
    final packageStatusConfig = getItemStatusConfig(worstItem.status);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
        borderRadius: BorderRadius.circular(DesignTokens.radius16),
        border: Border.all(
          color: isTerminalPackage
              ? DesignTokens.error.withValues(alpha: 0.3)
              : isDelivered
              ? DesignTokens.success.withValues(alpha: 0.3)
              : packageStatusConfig.color.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: packageStatusConfig.color.withValues(alpha: isDark ? 0.08 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Package header ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [packageStatusConfig.color.withValues(alpha: 0.07), Colors.transparent]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(DesignTokens.radius16)),
            ),
            child: Row(
              children: [
                // Flag + origin chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isCanada ? DesignTokens.canadaRed.withValues(alpha: 0.08) : DesignTokens.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isCanada ? DesignTokens.canadaRed.withValues(alpha: 0.2) : DesignTokens.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(isCanada ? '🇨🇦' : '🌍', style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 5),
                      Text(
                        isCanada ? 'orders.ships_from_canada'.tr() : 'orders.ships_international'.tr(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isCanada ? DesignTokens.canadaRed : DesignTokens.primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sellerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : DesignTokens.textPrimary),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (total > 1) ...[
                            Flexible(
                              child: Text(
                                'orders.package_label'.tr(namedArgs: {'index': index.toString(), 'total': total.toString()}),
                                style: TextStyle(fontSize: 10, color: DesignTokens.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasPerishable) const SizedBox(width: 6),
                          ],
                          if (hasPerishable)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: DesignTokens.success.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: DesignTokens.success.withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('🥬', style: TextStyle(fontSize: 10)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'orders.perishable_chip'.tr(),
                                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: DesignTokens.success),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Package status badge
                if (!isTerminalPackage)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [packageStatusConfig.color.withValues(alpha: 0.15), packageStatusConfig.color.withValues(alpha: 0.05)]),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: packageStatusConfig.color.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(packageStatusConfig.icon, size: 12, color: packageStatusConfig.color),
                        const SizedBox(width: 4),
                        Text(
                          packageStatusConfig.label,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: packageStatusConfig.color),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // ── Per-package timeline ────────────────────────────────────────
          if (!isTerminalPackage)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
              child: SellerPackageTimeline(currentStep: packageStep),
            ),

          // ── Perishable urgency banner (only when preparing / not yet shipped) ──
          if (hasPerishable && packageStep == 0 && !isTerminalPackage)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: DesignTokens.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(DesignTokens.radius12),
                  border: Border.all(color: DesignTokens.warning.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 14, color: DesignTokens.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'orders.perishable_urgency'.tr(),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: DesignTokens.warning),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Estimated delivery (not delivered, not terminal) ────────────
          if (!isTerminalPackage && !isDelivered && first.estimatedShipDays > 0)
            Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 10), child: _buildEstimatedDelivery(first, order.createdAt, isCanada, isDark)),

          // ── Divider ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Divider(height: 1, color: (isDark ? Colors.white : DesignTokens.textSecondary).withValues(alpha: 0.1)),
          ),

          // ── Items in this package ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(children: items.map((item) => _buildOrderItem(context, item, order.confirmedByClient)).toList()),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SELLER PACKAGES — Amazon-style per-seller grouping with individual timelines
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSellerPackages(Order order, bool isDark) {
    // Group items by sellerId, preserving insertion order
    final grouped = <String, List<OrderItem>>{};
    for (final item in order.items) {
      grouped.putIfAbsent(item.sellerId, () => []).add(item);
    }

    final entries = grouped.entries.toList();
    return Column(
      children: List.generate(entries.length, (i) {
        return _buildSellerPackage(entries[i].value, order, isDark, index: i + 1, total: entries.length);
      }),
    );
  }

  Widget _buildTerminalBadge(StatusConfig config, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [config.color.withValues(alpha: 0.15), config.color.withValues(alpha: 0.05)]),
          borderRadius: BorderRadius.circular(DesignTokens.radius12),
          border: Border.all(color: config.color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: config.color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(config.icon, size: 20, color: config.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    config.label,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: config.color),
                  ),
                  const SizedBox(height: 2),
                  Text(config.description, style: TextStyle(fontSize: 12, color: config.color.withValues(alpha: 0.8))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingWidget(OrderItem item, bool isDark) {
    final carrier = item.carrier;
    final trackingNum = item.trackingNumber!;
    final trackingUrl = _carrierTrackingUrl(carrier, trackingNum);
    final carrierLabel = _carrierLabel(carrier, item.carrierNote);
    final carrierIcon = _carrierIcon(carrier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Carrier + tracking number row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [DesignTokens.statusShipped.withValues(alpha: 0.12), DesignTokens.statusShipped.withValues(alpha: 0.04)]),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: DesignTokens.statusShipped.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(carrierIcon, size: 14, color: DesignTokens.statusShipped),
                  const SizedBox(width: 6),
                  Text(
                    carrierLabel,
                    style: const TextStyle(fontSize: 11, color: DesignTokens.statusShipped, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.qr_code_2, size: 12, color: DesignTokens.statusShipped),
                  const SizedBox(width: 4),
                  Flexible(
                    child: GestureDetector(
                      onLongPress: () => Clipboard.setData(ClipboardData(text: trackingNum)),
                      child: Text(
                        trackingNum,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white70 : DesignTokens.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (carrier != CarrierValues.other) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => Clipboard.setData(ClipboardData(text: trackingNum)),
                      child: const Icon(Icons.copy_rounded, size: 12, color: DesignTokens.statusShipped),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        // "Track Package" button — only for known carriers with URLs
        if (trackingUrl != null) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () async {
              final uri = Uri.parse(trackingUrl);
              if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [DesignTokens.gradientStart, DesignTokens.gradientEnd],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.open_in_new_rounded, size: 12, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    'orders.track_package'.tr(),
                    style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  IconData _carrierIcon(String? carrier) {
    return switch (carrier) {
      CarrierValues.canadaPost => Icons.mail_outline_rounded,
      CarrierValues.ups || CarrierValues.fedex || CarrierValues.purolator || CarrierValues.dhl || CarrierValues.usps => Icons.local_shipping_outlined,
      CarrierValues.maritime => Icons.directions_boat_outlined,
      _ => Icons.inventory_2_outlined,
    };
  }

  String _carrierLabel(String? carrier, String? carrierNote) {
    return switch (carrier) {
      CarrierValues.canadaPost => 'Canada Post',
      CarrierValues.ups => 'UPS',
      CarrierValues.fedex => 'FedEx',
      CarrierValues.purolator => 'Purolator',
      CarrierValues.dhl => 'DHL',
      CarrierValues.usps => 'USPS',
      CarrierValues.maritime => 'Maritime (International)',
      CarrierValues.other => carrierNote?.isNotEmpty == true ? carrierNote! : 'Other carrier',
      _ => 'Tracking',
    };
  }

  String? _carrierTrackingUrl(String? carrier, String trackingNum) {
    if (carrier == null || carrier == CarrierValues.other) return null;
    final encoded = Uri.encodeComponent(trackingNum);
    return switch (carrier) {
      CarrierValues.canadaPost => 'https://www.canadapost-postescanada.ca/track-reperage/en#/details/$encoded',
      CarrierValues.ups => 'https://www.ups.com/track?tracknum=$encoded',
      CarrierValues.fedex => 'https://www.fedex.com/fedextrack/?trknbr=$encoded',
      CarrierValues.purolator => 'https://www.purolator.com/en/shipping/tracker?Pin=$encoded',
      CarrierValues.dhl => 'https://www.dhl.com/ca-en/home/tracking/tracking-express.html?submit=1&tracking-id=$encoded',
      CarrierValues.usps => 'https://tools.usps.com/go/TrackConfirmAction?tLabels=$encoded',
      CarrierValues.maritime => 'https://www.track-trace.com/container?container=$encoded',
      _ => null,
    };
  }

  Future<void> _confirmReceipt(OrderItem item) async {
    final itemKey = '${widget.order.orderId}_${item.productId}';
    final messenger = ScaffoldMessenger.of(context);
    final viewModel = ref.read(buyerOrdersViewModelProvider.notifier);

    final success = await viewModel.confirmReceipt(widget.order.orderId, itemKey);
    if (!mounted) return;

    if (success) {
      messenger.showSnackBar(SnackBar(content: Text('orders.receipt_confirmed'.tr()), backgroundColor: DesignTokens.success));
    } else {
      final error = ref.read(buyerOrdersViewModelProvider).errorMessage ?? 'orders.failed_confirm_receipt'.tr();
      messenger.showSnackBar(SnackBar(content: Text(error), backgroundColor: DesignTokens.error));
    }
  }

  Widget _infoPill(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.08) : DesignTokens.textSecondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: DesignTokens.textSecondary, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _productImage(String? url) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [DesignTokens.primary.withValues(alpha: 0.1), DesignTokens.secondary.withValues(alpha: 0.07)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: DesignTokens.primary.withValues(alpha: 0.12), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: url != null
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(child: ModernLoadingIndicator(size: 20)),
                errorWidget: (context, url, error) => Icon(Icons.camera_alt_outlined, color: DesignTokens.primary.withValues(alpha: 0.5), size: 28),
              )
            : Icon(Icons.camera_alt_outlined, color: DesignTokens.primary.withValues(alpha: 0.5), size: 28),
      ),
    );
  }

  Future<void> _reorderItems(Order order) async {
    final messenger = ScaffoldMessenger.of(context);
    final cartController = ref.read(cartControllerProvider);
    int added = 0;

    for (final item in order.items) {
      if (item.isDigital) continue; // skip digital — already owned
      final success = await cartController.addToCart(item.productId, item.quantity, variantId: item.variantId);
      if (success) added++;
    }

    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('orders.items_added_to_cart'.tr(namedArgs: {'count': added.toString()})),
        backgroundColor: DesignTokens.success,
        action: SnackBarAction(label: 'cart.view_cart'.tr(), textColor: Colors.white, onPressed: () => Navigator.pushNamed(context, AppRoutes.cart)),
      ),
    );
  }

  Widget _statusIndicator(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _SoftwareDownloadLinksState extends ConsumerState<SoftwareDownloadLinks> {
  final Map<String, bool> _loading = {};

  @override
  Widget build(BuildContext context) {
    final builds = widget.item.digitalBuilds ?? {};
    if (builds.isEmpty) return const SizedBox.shrink();

    const platformLabels = {'macos': 'macOS', 'windows': 'Windows', 'linux': 'Linux'};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('common.download'.tr(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: builds.keys.map((platform) {
            final isLoading = _loading[platform] == true;
            final label = platformLabels[platform] ?? platform;
            return OutlinedButton.icon(
              icon: isLoading
                  ? const SizedBox(width: 14, height: 14, child: ModernLoadingIndicator(size: 14, strokeWidth: 2, centered: false))
                  : const Icon(Icons.download_outlined, size: 16),
              label: Text(label),
              onPressed: isLoading ? null : () => _download(platform),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _download(String platform) async {
    setState(() => _loading[platform] = true);
    try {
      final result = await ref.read(firebaseFunctionsProvider).httpsCallable(CloudFunctionEndpoints.generateSoftwareDownloadSession).call({
        Fields.licenseKey: widget.item.licenseKey,
        Fields.platform: platform,
      });
      final downloadUrl = result.data[ApiKeys.downloadUrl] as String?;
      if (downloadUrl == null) throw Exception('Download URL not available');
      await launchUrl(Uri.parse(downloadUrl), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('orders.download_failed'.tr())));
      }
    } finally {
      if (mounted) setState(() => _loading[platform] = false);
    }
  }
}
