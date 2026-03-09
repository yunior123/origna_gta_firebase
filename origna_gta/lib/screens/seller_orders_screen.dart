// coverage:ignore-file
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/routes.dart';
import 'package:origna_gta/core/schema/schema_constants.dart' show CarrierValues;
import 'package:origna_gta/features/auth/auth_provider.dart';
import 'package:origna_gta/features/orders/orders_provider.dart';
import 'package:origna_gta/features/orders/seller_orders_viewmodel.dart';
import 'package:origna_gta/features/products/products_provider.dart';
import 'package:origna_gta/models/generated/models.dart';
import 'package:origna_gta/utils/constants.dart' hide PaymentStatus, ShippingApprovalStatus, OrderStatus;
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/utils/responsive_layout.dart';
import 'package:origna_gta/utils/utils.dart';
import 'package:origna_gta/widgets/animations.dart';
import 'package:origna_gta/widgets/custom_app_bar.dart';
import 'package:origna_gta/widgets/modern_button.dart';
import 'package:origna_gta/widgets/modern_loading_indicator.dart';

/// Documentation for SellerOrdersScreen
class SellerOrdersScreen extends ConsumerWidget {
  const SellerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final userProfile = ref.watch(userProfileProvider).valueOrNull;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      return Container(
        decoration: BoxDecoration(gradient: DesignTokens.backgroundGradient(isDark: isDark)),
        child: Scaffold(
          appBar: AppBarFactory.simple(title: 'seller.manage_orders'.tr()),
          backgroundColor: Colors.transparent,
          body: AnimatedEmptyState(icon: Icons.login_rounded, title: 'seller.login_required'.tr(), subtitle: 'seller.login_to_view'.tr()),
        ),
      );
    }

    if (userProfile?.suspended == true) {
      return Container(
        decoration: BoxDecoration(gradient: DesignTokens.backgroundGradient(isDark: isDark)),
        child: Scaffold(
          appBar: AppBarFactory.simple(title: 'seller.manage_orders'.tr()),
          backgroundColor: Colors.transparent,
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: FadeSlideIn(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: DesignTokens.error.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: Icon(Icons.block_rounded, size: 56, color: DesignTokens.error),
                    ),
                    const SizedBox(height: DesignTokens.spacing20),
                    Text('seller.account_suspended'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: DesignTokens.spacing8),
                    Text('seller.contact_support'.tr(), style: TextStyle(color: DesignTokens.textSecondary)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final ordersAsync = ref.watch(sellerOrdersProvider);

    return Container(
      decoration: BoxDecoration(gradient: DesignTokens.backgroundGradient(isDark: isDark)),
      child: Scaffold(
        key: const Key('seller_orders_screen_title'),
        appBar: AppBarFactory.custom(
          title: 'seller.manage_orders'.tr(),
          actions: [
            _UnansweredQaBadge(sellerId: user.uid),
            Tooltip(
              message: 'seller_integration.title'.tr(),
              child: IconButton(
                icon: const Icon(Icons.integration_instructions_outlined),
                tooltip: 'seller_integration.title'.tr(),
                onPressed: () => Navigator.pushNamed(context, AppRoutes.sellerIntegration),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        body: ordersAsync.when(
          loading: () => Center(
            child: Container(
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
          ),
          error: (error, _) => AnimatedEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'seller.something_wrong'.tr(),
            subtitle: AppError.getMessage(error),
            action: ModernButton(label: 'common.retry'.tr(), icon: Icons.refresh, onPressed: () => ref.invalidate(sellerOrdersProvider), isOutlined: true),
          ),
          data: (orders) {
            if (orders.isEmpty) {
              return AnimatedEmptyState(icon: Icons.storefront_outlined, title: 'seller.no_orders_yet'.tr(), subtitle: 'seller.orders_appear_here'.tr());
            }

            // Compute seller's earnings summary (display-only approximation)
            var totalRevenue = 0.0;
            var pendingCount = 0;
            var completedCount = 0;
            // Terminal/excluded statuses: not active orders
            const excludedStatuses = {
              OrderStatus.cancelled,
              OrderStatus.failed,
              OrderStatus.expired,
              OrderStatus.refunded,
              OrderStatus.partiallyRefunded,
              OrderStatus.disputed,
            };
            for (final order in orders) {
              final sellerItems = order.items.where((i) => i.sellerId == user.uid);
              final subtotal = sellerItems.fold<double>(0.0, (acc, i) => acc + i.price * i.quantity);
              // Derive seller's share of platform fee proportional to their items
              final orderSubtotal = order.subtotal > 0 ? order.subtotal : subtotal;
              final feeShare = orderSubtotal > 0 ? (order.platformFeeTotal / orderSubtotal) * subtotal : 0.0;
              totalRevenue += subtotal - feeShare;
              if (order.orderStatus == OrderStatus.delivered) {
                completedCount++;
              } else if (!excludedStatuses.contains(order.orderStatus)) {
                pendingCount++;
              }
            }

            // Cap to 840px on desktop for readability — cards shouldn't stretch to 1200px
            final ordersMaxWidth = ResponsiveBreakpoints.isDesktop(context) ? 840.0 : ResponsiveBreakpoints.contentMaxWidth.toDouble();
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: ordersMaxWidth),
                child: RefreshIndicator(
                  color: DesignTokens.primary,
                  onRefresh: () async => ref.invalidate(sellerOrdersProvider),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(DesignTokens.spacing16),
                    itemCount: orders.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: DesignTokens.spacing16),
                          child: _EarningsSummaryCard(totalRevenue: totalRevenue, pendingCount: pendingCount, completedCount: completedCount, isDark: isDark),
                        );
                      }
                      final order = orders[index - 1];
                      return FadeSlideIn(
                        delay: Duration(milliseconds: 50 * (index - 1).clamp(0, 8)),
                        child: _SellerOrderCard(order: order, sellerId: user.uid),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Revenue summary card shown at the top of the seller orders list.
class _EarningsSummaryCard extends StatelessWidget {
  final double totalRevenue;
  final int pendingCount;
  final int completedCount;
  final bool isDark;

  const _EarningsSummaryCard({required this.totalRevenue, required this.pendingCount, required this.completedCount, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [DesignTokens.gradientStart, DesignTokens.gradientMiddle], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(DesignTokens.radius16),
        boxShadow: [BoxShadow(color: DesignTokens.primary.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'seller.total_earnings'.tr(),
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${totalRevenue.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                ),
                Text('seller.after_platform_fee'.tr(), style: const TextStyle(color: Colors.white54, fontSize: 10)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _StatPill(icon: Icons.hourglass_empty_rounded, label: '$pendingCount', sublabel: 'seller.pending'.tr(), color: DesignTokens.warning),
              const SizedBox(height: 8),
              _StatPill(icon: Icons.check_circle_rounded, label: '$completedCount', sublabel: 'seller.completed'.tr(), color: DesignTokens.success),
            ],
          ),
        ],
      ),
    );
  }
}

class _SellerOrderCard extends ConsumerWidget {
  final Order order;
  final String sellerId;

  const _SellerOrderCard({required this.order, required this.sellerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sellerItems = order.items.where((item) => item.sellerId == sellerId).toList();
    if (sellerItems.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final sellerTotal = sellerItems.fold<double>(0.0, (acc, item) => acc + (item.price * item.quantity));
    // Per-seller fee = seller's own subtotal × platform fee rate (not the full order fee)
    final platformFee = sellerTotal * (BusinessRules.platformFeePercent / 100.0);
    final sellerNet = sellerTotal - platformFee;

    return Container(
      margin: const EdgeInsets.only(bottom: DesignTokens.spacing16),
      decoration: BoxDecoration(
        color: isDark ? DesignTokens.darkSurfaceVariant : Colors.white,
        borderRadius: BorderRadius.circular(DesignTokens.radius16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : DesignTokens.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${'seller.order_prefix'.tr()}${order.orderId.substring(0, 8).toUpperCase()}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('MMM dd, yyyy').format(order.createdAt),
                        style: TextStyle(fontSize: 12, color: DesignTokens.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(gradient: DesignTokens.primaryGradient, borderRadius: BorderRadius.circular(20)),
                  child: Tooltip(
                    message: 'Gross: \$${sellerTotal.toStringAsFixed(2)} − \$${platformFee.toStringAsFixed(2)} fee',
                    child: Text(
                      '\$${sellerNet.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : DesignTokens.surfaceVariant,
                borderRadius: BorderRadius.circular(DesignTokens.radius8),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 14, color: DesignTokens.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      order.shippingAddress?.formattedAddress ?? '',
                      style: TextStyle(fontSize: 12, color: isDark ? DesignTokens.textDisabled : DesignTokens.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 28, color: isDark ? Colors.white.withValues(alpha: 0.08) : DesignTokens.outlineVariant),
            if (order.paymentStatus == PaymentStatus.awaitingPayment) _buildAuthorizationBanner(context, ref, isDark),
            // Delivery instructions from buyer
            if (order.deliveryInstructions != null && order.deliveryInstructions!.isNotEmpty) _buildDeliveryInstructionsBanner(isDark),
            Text(
              'seller.your_items'.tr(),
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: isDark ? Colors.white : DesignTokens.textPrimary),
            ),
            const SizedBox(height: 8),
            ...sellerItems.map((item) => _buildSellerItem(context, ref, item, isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthorizationBanner(BuildContext context, WidgetRef ref, bool isDark) {
    final actualShipping = order.actualShipping;
    final approvalStatus = order.shippingApprovalStatus;
    final isLoading = ref.watch(sellerOrdersViewModelProvider.select((state) => state.isLoading));

    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [DesignTokens.primary.withValues(alpha: 0.08), DesignTokens.secondary.withValues(alpha: 0.05)]),
        borderRadius: BorderRadius.circular(DesignTokens.radius12),
        border: Border.all(color: DesignTokens.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: DesignTokens.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.payment_rounded, size: 16, color: DesignTokens.primary),
              ),
              const SizedBox(width: 10),
              Text(
                'seller.payment_authorized'.tr(),
                style: TextStyle(fontWeight: FontWeight.w700, color: DesignTokens.primary, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            actualShipping <= 0.0
                ? 'seller.enter_shipping_cost'.tr()
                : (approvalStatus == ShippingApprovalStatus.pending ? 'seller.waiting_buyer_approval'.tr() : 'seller.ready_to_capture'.tr()),
            style: TextStyle(fontSize: 12, color: isDark ? DesignTokens.textDisabled : DesignTokens.textSecondary),
          ),
          if (actualShipping <= 0.0) ...[
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: ModernButton(
                label: 'seller.confirm_shipping_ship'.tr(),
                onPressed: isLoading ? null : () => _showUpdateShippingDialog(context, ref),
                isLoading: isLoading,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeliveryInstructionsBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: DesignTokens.info.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(DesignTokens.radius12),
        border: Border.all(color: DesignTokens.info.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: DesignTokens.info.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.edit_note_outlined, size: 16, color: DesignTokens.info),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'seller.delivery_instructions'.tr(),
                  style: TextStyle(fontWeight: FontWeight.w700, color: DesignTokens.info, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  order.deliveryInstructions!,
                  style: TextStyle(fontSize: 13, color: isDark ? DesignTokens.outlineVariant : DesignTokens.textPrimary, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerItem(BuildContext context, WidgetRef ref, OrderItem item, bool isDark) {
    final statusStr = item.status;
    final isAuthorized = order.paymentStatus == PaymentStatus.awaitingPayment;
    final isRefunded = statusStr == DeliveryStatusValues.refunded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(DesignTokens.radius8),
          child: item.imageUrls.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: item.imageUrls.first,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: DesignTokens.surfaceVariant, borderRadius: BorderRadius.circular(DesignTokens.radius8)),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(DesignTokens.radius8),
                      gradient: LinearGradient(
                        colors: [DesignTokens.primary.withValues(alpha: 0.1), DesignTokens.secondary.withValues(alpha: 0.07)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: DesignTokens.primary.withValues(alpha: 0.12), width: 1),
                    ),
                    child: Icon(Icons.camera_alt_outlined, color: DesignTokens.primary.withValues(alpha: 0.5), size: 18),
                  ),
                )
              : Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: DesignTokens.surfaceVariant, borderRadius: BorderRadius.circular(DesignTokens.radius8)),
                  child: Icon(Icons.image_outlined, color: DesignTokens.textDisabled, size: 20),
                ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                item.name,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (item.isDigital) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: DesignTokens.digital.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.download_outlined, size: 10, color: DesignTokens.digital),
                    const SizedBox(width: 3),
                    const Text(
                      'Digital',
                      style: TextStyle(fontSize: 10, color: DesignTokens.digital, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${'seller.qty_prefix'.tr()} ${item.quantity}',
                    style: TextStyle(fontSize: 12, color: DesignTokens.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusChip(statusStr),
              ],
            ),
            if (item.carrier != null)
              Text('${'seller.carrier_prefix'.tr()} ${item.carrier}', style: TextStyle(fontSize: 11, color: DesignTokens.textSecondary)),
            if (item.refundedAt != null)
              Text(
                '${'seller.refunded_prefix'.tr()} ${DateFormat.yMd().format(item.refundedAt!)}',
                style: TextStyle(fontSize: 11, color: DesignTokens.warning),
              ),
            if (item.buyerNote != null && item.buyerNote!.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: DesignTokens.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: DesignTokens.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.edit_note_rounded, size: 14, color: DesignTokens.warning),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${'cart.item_note_label'.tr()}: ${item.buyerNote}',
                        style: TextStyle(fontSize: 12, color: DesignTokens.textPrimary, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        // Suppress mark-shipped button for digital items — fulfilled automatically
        trailing: !item.isDigital && !isAuthorized
            ? (statusStr == DeliveryStatusValues.pending && !isRefunded
                  ? Container(
                      decoration: BoxDecoration(color: DesignTokens.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(DesignTokens.radius8)),
                      child: IconButton(
                        icon: Icon(Icons.local_shipping_rounded, color: DesignTokens.primary, size: 22),
                        tooltip: 'seller.mark_shipped'.tr(),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _showMarkAsShippedDialog(context, ref, item);
                        },
                      ),
                    )
                  : (statusStr == DeliveryStatusValues.shipped
                        ? Container(
                            decoration: BoxDecoration(
                              color: DesignTokens.info.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(DesignTokens.radius8),
                            ),
                            child: IconButton(
                              icon: Icon(Icons.edit_rounded, color: DesignTokens.info, size: 20),
                              tooltip: 'seller.edit_tracking'.tr(),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                _showMarkAsShippedDialog(
                                  context,
                                  ref,
                                  item,
                                  prefillTracking: item.trackingNumber,
                                  prefillCarrier: item.carrier,
                                  prefillCarrierNote: item.carrierNote,
                                );
                              },
                            ),
                          )
                        : null))
            : null,
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    if (status == DeliveryStatusValues.delivered) {
      color = DesignTokens.success;
    } else if (status == DeliveryStatusValues.shipped) {
      color = DesignTokens.primary;
    } else if (status == DeliveryStatusValues.refunded) {
      color = DesignTokens.warning;
    } else {
      color = DesignTokens.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: Text(
        _getStatusDisplayText(status),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  String _getStatusDisplayText(String status) {
    if (status == DeliveryStatusValues.pending) return 'seller.status.pending'.tr();
    if (status == DeliveryStatusValues.shipped) return 'seller.status.shipped'.tr();
    if (status == DeliveryStatusValues.delivered) return 'seller.status.delivered'.tr();
    if (status == DeliveryStatusValues.refunded) return 'seller.status.refunded'.tr();
    return status;
  }

  void _showMarkAsShippedDialog(
    BuildContext context,
    WidgetRef ref,
    OrderItem item, {
    String? prefillTracking,
    String? prefillCarrier,
    String? prefillCarrierNote,
  }) {
    final trackingController = TextEditingController(text: prefillTracking ?? '');
    final carrierNoteController = TextEditingController(text: prefillCarrierNote ?? '');
    String? selectedCarrier = prefillCarrier;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radius20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [DesignTokens.primary.withValues(alpha: 0.15), DesignTokens.secondary.withValues(alpha: 0.15)]),
                  borderRadius: BorderRadius.circular(DesignTokens.radius8),
                ),
                child: Icon(Icons.local_shipping_rounded, size: 18, color: DesignTokens.primary),
              ),
              const SizedBox(width: 12),
              Text('seller.mark_shipped'.tr(), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Carrier dropdown
              DropdownButtonFormField<String>(
                menuMaxHeight: ResponsiveBreakpoints.dropdownMaxHeight(context),
                initialValue: selectedCarrier,
                decoration: InputDecoration(
                  labelText: 'seller.carrier_label'.tr(),
                  prefixIcon: Icon(Icons.local_shipping_outlined, color: DesignTokens.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(DesignTokens.radius12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radius12),
                    borderSide: BorderSide(color: DesignTokens.primary, width: 2),
                  ),
                ),
                items: CarrierValues.all.map((c) => DropdownMenuItem(value: c, child: Text(_carrierLabel(c)))).toList(),
                onChanged: (value) => setState(() => selectedCarrier = value),
              ),
              // Carrier note (only when 'other' is selected)
              if (selectedCarrier == CarrierValues.other) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: carrierNoteController,
                  decoration: InputDecoration(
                    labelText: 'seller.carrier_note_label'.tr(),
                    prefixIcon: Icon(Icons.edit_outlined, color: DesignTokens.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(DesignTokens.radius12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DesignTokens.radius12),
                      borderSide: BorderSide(color: DesignTokens.primary, width: 2),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              // Tracking number
              Semantics(
                textField: true,
                label: 'input-tracking-number',
                child: TextField(
                  controller: trackingController,
                  decoration: InputDecoration(
                    labelText: 'seller.tracking_number'.tr(),
                    prefixIcon: Icon(Icons.qr_code_rounded, color: DesignTokens.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(DesignTokens.radius12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DesignTokens.radius12),
                      borderSide: BorderSide(color: DesignTokens.primary, width: 2),
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('common.cancel'.tr(), style: TextStyle(color: DesignTokens.textSecondary)),
            ),
            SizedBox(
              width: 120,
              child: ModernButton(
                label: 'common.confirm'.tr(),
                onPressed: () {
                  final tracking = trackingController.text.trim();
                  if (tracking.isNotEmpty) {
                    final note = selectedCarrier == CarrierValues.other ? carrierNoteController.text.trim() : null;
                    Navigator.pop(context);
                    ref
                        .read(sellerOrdersViewModelProvider.notifier)
                        .updateItemStatus(
                          order.orderId,
                          item.productId,
                          DeliveryStatusValues.shipped,
                          trackingNumber: tracking,
                          carrier: selectedCarrier,
                          carrierNote: note,
                        );
                  }
                },
                height: 42,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpdateShippingDialog(BuildContext context, WidgetRef ref) {
    final estimatedShipping = order.shippingCost;
    final shippingController = TextEditingController(text: estimatedShipping.toStringAsFixed(2));
    final trackingController = TextEditingController();
    final carrierNoteController = TextEditingController();
    String? selectedCarrier;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radius20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [DesignTokens.primary.withValues(alpha: 0.15), DesignTokens.secondary.withValues(alpha: 0.15)]),
                  borderRadius: BorderRadius.circular(DesignTokens.radius8),
                ),
                child: Icon(Icons.payment_rounded, size: 18, color: DesignTokens.primary),
              ),
              const SizedBox(width: 12),
              Text('seller.confirm_shipping'.tr(), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                textField: true,
                label: 'input-actual-cost',
                child: TextField(
                  controller: shippingController,
                  decoration: InputDecoration(
                    labelText: 'seller.actual_cost'.tr(),
                    prefixIcon: Icon(Icons.attach_money_rounded, color: DesignTokens.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(DesignTokens.radius12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DesignTokens.radius12),
                      borderSide: BorderSide(color: DesignTokens.primary, width: 2),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(height: 14),
              // Carrier dropdown
              DropdownButtonFormField<String>(
                menuMaxHeight: ResponsiveBreakpoints.dropdownMaxHeight(context),
                initialValue: selectedCarrier,
                decoration: InputDecoration(
                  labelText: 'seller.carrier_label'.tr(),
                  prefixIcon: Icon(Icons.local_shipping_outlined, color: DesignTokens.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(DesignTokens.radius12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radius12),
                    borderSide: BorderSide(color: DesignTokens.primary, width: 2),
                  ),
                ),
                items: CarrierValues.all.map((c) => DropdownMenuItem(value: c, child: Text(_carrierLabel(c)))).toList(),
                onChanged: (value) => setState(() => selectedCarrier = value),
              ),
              // Carrier note (only when 'other' is selected)
              if (selectedCarrier == CarrierValues.other) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: carrierNoteController,
                  decoration: InputDecoration(
                    labelText: 'seller.carrier_note_label'.tr(),
                    prefixIcon: Icon(Icons.edit_outlined, color: DesignTokens.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(DesignTokens.radius12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DesignTokens.radius12),
                      borderSide: BorderSide(color: DesignTokens.primary, width: 2),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Semantics(
                textField: true,
                label: 'input-tracking-number-update',
                child: TextField(
                  controller: trackingController,
                  decoration: InputDecoration(
                    labelText: 'seller.tracking_number'.tr(),
                    prefixIcon: Icon(Icons.qr_code_rounded, color: DesignTokens.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(DesignTokens.radius12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DesignTokens.radius12),
                      borderSide: BorderSide(color: DesignTokens.primary, width: 2),
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('common.cancel'.tr(), style: TextStyle(color: DesignTokens.textSecondary)),
            ),
            SizedBox(
              width: 120,
              child: ModernButton(
                label: 'common.confirm'.tr(),
                onPressed: () {
                  final cost = double.tryParse(shippingController.text);
                  final tracking = trackingController.text.trim();
                  if (cost != null && tracking.isNotEmpty) {
                    final note = selectedCarrier == CarrierValues.other ? carrierNoteController.text.trim() : null;
                    Navigator.pop(context);
                    ref
                        .read(sellerOrdersViewModelProvider.notifier)
                        .updateShippingAndCapture(order.orderId, cost, tracking, carrier: selectedCarrier, carrierNote: note);
                  }
                },
                height: 42,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Human-readable label for a [CarrierValues] constant.
  static String _carrierLabel(String carrier) {
    switch (carrier) {
      case CarrierValues.ups:
        return 'UPS';
      case CarrierValues.fedex:
        return 'FedEx';
      case CarrierValues.canadaPost:
        return 'Canada Post';
      case CarrierValues.purolator:
        return 'Purolator';
      case CarrierValues.dhl:
        return 'DHL';
      case CarrierValues.usps:
        return 'USPS';
      case CarrierValues.maritime:
        return 'Maritime (International)';
      case CarrierValues.other:
        return 'seller.carrier_other'.tr();
      default:
        return carrier;
    }
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;

  const _StatPill({required this.icon, required this.label, required this.sublabel, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
          ),
          const SizedBox(width: 4),
          Text(sublabel, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }
}

// U-03: Badge widget showing unanswered Q&A count for the seller
class _UnansweredQaBadge extends ConsumerWidget {
  final String sellerId;
  const _UnansweredQaBadge({required this.sellerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(sellerUnansweredQaProvider(sellerId));
    final count = countAsync.valueOrNull ?? 0;

    return Tooltip(
      message: count > 0 ? 'seller.unanswered_questions_plural'.tr(args: [count.toString()]) : 'seller.no_pending_questions'.tr(),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            icon: const Icon(Icons.forum_outlined),
            tooltip: count > 0 ? 'seller.unanswered_questions_plural'.tr(args: [count.toString()]) : 'seller.no_pending_questions'.tr(),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.sellerProducts),
          ),
          if (count > 0)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: DesignTokens.error,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
