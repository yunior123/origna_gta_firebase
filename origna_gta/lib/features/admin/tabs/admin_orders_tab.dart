// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/features/admin/admin_providers.dart';
import 'package:origna_gta/utils/constants.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/utils/utils.dart';
import 'package:origna_gta/widgets/animations.dart';
import 'package:origna_gta/widgets/modern_loading_indicator.dart';

/// Documentation for AdminOrdersTab
class AdminOrdersTab extends ConsumerStatefulWidget {
  const AdminOrdersTab({super.key});

  @override
  ConsumerState<AdminOrdersTab> createState() => _AdminOrdersTabState();
}

class _AdminOrderCard extends StatelessWidget {
  final OrderModel order;

  const _AdminOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final total = order.total;
    final paymentStatus = PaymentStatus.fromValue(order.paymentStatus);
    final createdAt = order.createdAt;
    final customerEmail = order.customerEmail.isNotEmpty
        ? order.customerEmail
        : 'common.unknown'.tr();
    final items = order.items;

    Color statusColor;
    switch (paymentStatus) {
      case PaymentStatus.paid:
        statusColor = DesignTokens.success;
        break;
      case PaymentStatus.authorized:
        statusColor = DesignTokens.info;
        break;
      case PaymentStatus.refunded:
        statusColor = DesignTokens.secondary;
        break;
      case PaymentStatus.paymentFailed:
        statusColor = DesignTokens.error;
        break;
      default:
        statusColor = DesignTokens.warning;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radius16),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius16),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius16),
        ),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(DesignTokens.radius12),
          ),
          child: Icon(Icons.receipt_long_rounded, color: statusColor, size: 22),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'orders.order_id_prefix'.tr(
                  namedArgs: {
                    'id': order.orderId.substring(0, 8).toUpperCase(),
                  },
                ),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              '\$${total.toStringAsFixed(2)}',
              style: TextStyle(fontWeight: FontWeight.bold, color: statusColor),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              customerEmail,
              style: TextStyle(fontSize: 12, color: DesignTokens.textSecondary),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    paymentStatus.displayText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDate(createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: DesignTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'orders.items_label'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text(item.name)),
                        Text('x${item.quantity}'),
                        const SizedBox(width: 16),
                        Text(
                          '\$${(item.price * item.quantity).toStringAsFixed(2)}',
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (paymentStatus == PaymentStatus.paid)
                      TextButton.icon(
                        onPressed: () => _showRefundDialog(context),
                        icon: const Icon(Icons.undo, size: 18),
                        label: Text('orders.refund'.tr()),
                        style: TextButton.styleFrom(
                          foregroundColor: DesignTokens.error,
                        ),
                      ),
                    TextButton.icon(
                      onPressed: () => _viewOrderDetails(context),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text('orders.full_details'.tr()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: DesignTokens.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDeliveryAddress(Map<String, dynamic> deliveryInfo) {
    final formatted = deliveryInfo[Fields.formattedAddress]?.toString();
    if (formatted != null && formatted.trim().isNotEmpty) return formatted;

    final street = deliveryInfo[Fields.street]?.toString() ?? '';
    final apartment = deliveryInfo[Fields.apartment]?.toString() ?? '';
    final city = deliveryInfo[Fields.city]?.toString() ?? '';
    final state = deliveryInfo[Fields.state]?.toString() ?? '';
    final postalCode = deliveryInfo[Fields.postalCode]?.toString() ?? '';
    final country = deliveryInfo[Fields.country]?.toString() ?? '';

    final line1 = [
      street,
      if (apartment.isNotEmpty) apartment,
    ].where((e) => e.isNotEmpty).join(' ');
    final line2 = [
      city,
      state,
      postalCode,
    ].where((e) => e.isNotEmpty).join(', ');
    final parts = [line1, line2, country].where((e) => e.isNotEmpty).toList();
    return parts.isEmpty ? 'N/A' : parts.join('\n');
  }

  void _showRefundDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          var isLoading = false;
          return StatefulBuilder(
            builder: (ctx, setState) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radius16),
              ),
              title: Row(
                children: [
                  Icon(Icons.undo_rounded, color: DesignTokens.error),
                  const SizedBox(width: 10),
                  Text('orders.issue_refund'.tr()),
                ],
              ),
              content: Text('orders.refund_warning'.tr()),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(ctx),
                  child: Text('common.cancel'.tr()),
                ),
                FilledButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          setState(() => isLoading = true);
                          try {
                            await ref
                                .read(adminRepositoryProvider)
                                .refundOrder(order.orderId);
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('orders.refund_success'.tr()),
                                  backgroundColor: DesignTokens.success,
                                ),
                              );
                            }
                          } catch (e) {
                            setState(() => isLoading = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('orders.refund_error'.tr()),
                                  backgroundColor: DesignTokens.error,
                                ),
                              );
                            }
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: DesignTokens.error,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: ModernLoadingIndicator.small(
                            color: Colors.white,
                          ),
                        )
                      : Text('orders.issue_refund'.tr()),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _viewOrderDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radius24),
        ),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: DesignTokens.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'orders.order_id_prefix'.tr(
                  namedArgs: {
                    'id': order.orderId.substring(0, 8).toUpperCase(),
                  },
                ),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildDetailRow(
                'orders.customer'.tr(),
                order.customerEmail.isNotEmpty
                    ? order.customerEmail
                    : 'common.unknown'.tr(),
              ),
              _buildDetailRow(
                'orders.user_id'.tr(),
                order.userId.isNotEmpty ? order.userId : 'common.unknown'.tr(),
              ),
              _buildDetailRow(
                'orders.payment_status'.tr(),
                PaymentStatus.fromValue(order.paymentStatus).displayText,
              ),
              _buildDetailRow(
                'orders.order_total'.tr(),
                '\$${order.total.toStringAsFixed(2)}',
              ),
              if (order.shippingAddress.isNotEmpty)
                _buildDetailRow(
                  'orders.delivery_address'.tr(),
                  _formatDeliveryAddress(order.shippingAddress),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminOrdersTabState extends ConsumerState<AdminOrdersTab> {
  String _statusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter Bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('orders.filter_all'.tr(), 'all'),
                _buildFilterChip(
                  PaymentStatus.authorized.displayText,
                  PaymentStatus.authorized.value,
                ),
                _buildFilterChip(
                  PaymentStatus.paid.displayText,
                  PaymentStatus.paid.value,
                ),
                _buildFilterChip(
                  PaymentStatus.refunded.displayText,
                  PaymentStatus.refunded.value,
                ),
                _buildFilterChip(
                  PaymentStatus.paymentFailed.displayText,
                  PaymentStatus.paymentFailed.value,
                ),
              ],
            ),
          ),
        ),

        // Orders List
        Expanded(
          child: ref
              .watch(adminOrdersProvider(_statusFilter))
              .when(
                loading: () => const ModernLoadingIndicator.fullScreen(),
                error: (error, _) =>
                    Center(child: Text('admin.users.error_fetching'.tr())),
                data: (orders) {
                  if (orders.isEmpty) {
                    return AnimatedEmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'orders.no_orders_found'.tr(),
                      subtitle: 'orders.no_orders_match'.tr(),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final data = orders[index];
                      return FadeSlideIn(
                        delay: Duration(milliseconds: 30 * index.clamp(0, 10)),
                        child: _AdminOrderCard(order: data),
                      );
                    },
                  );
                },
              ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _statusFilter = value),
        child: AnimatedContainer(
          duration: DesignTokens.durationFast,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? DesignTokens.primary : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? DesignTokens.primary
                  : DesignTokens.outlineVariant.withValues(alpha: 0.5),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: DesignTokens.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : DesignTokens.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
