// coverage:ignore-file
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/features/orders/orders_provider.dart';
import 'package:origna_gta/models/generated/models.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/utils/responsive_layout.dart';
import 'package:origna_gta/utils/utils.dart';
import 'package:origna_gta/widgets/animations.dart';
import 'package:origna_gta/widgets/custom_app_bar.dart';
import 'package:origna_gta/widgets/modern_button.dart';
import 'package:origna_gta/widgets/order_widgets.dart';
import 'package:shimmer/shimmer.dart';

/// Documentation for OrdersScreen
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _FilterRow extends StatelessWidget {
  final String selectedFilter;

  final ValueChanged<String> onFilterSelected;
  const _FilterRow({required this.selectedFilter, required this.onFilterSelected});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _OrderFilterChip(label: 'orders.filter_all'.tr(), selected: selectedFilter == _OrderFilter.all, onTap: () => onFilterSelected(_OrderFilter.all)),
          const SizedBox(width: 8),
          _OrderFilterChip(
            label: 'orders.filter_active'.tr(),
            selected: selectedFilter == _OrderFilter.active,
            onTap: () => onFilterSelected(_OrderFilter.active),
          ),
          const SizedBox(width: 8),
          _OrderFilterChip(
            label: 'orders.filter_delivered'.tr(),
            selected: selectedFilter == _OrderFilter.delivered,
            onTap: () => onFilterSelected(_OrderFilter.delivered),
          ),
          const SizedBox(width: 8),
          _OrderFilterChip(
            label: 'orders.filter_cancelled'.tr(),
            selected: selectedFilter == _OrderFilter.cancelled,
            onTap: () => onFilterSelected(_OrderFilter.cancelled),
          ),
        ],
      ),
    );
  }
}

// Filter identifiers — no magic strings
class _OrderFilter {
  static const String all = 'all';
  static const String active = 'active';
  static const String delivered = 'delivered';
  static const String cancelled = 'cancelled';
}

class _OrderFilterChip extends StatelessWidget {
  final String label;

  final bool selected;
  final VoidCallback onTap;
  const _OrderFilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: selected
            ? const BoxDecoration(gradient: DesignTokens.primaryGradient, borderRadius: BorderRadius.all(Radius.circular(20)))
            : BoxDecoration(
                border: Border.all(color: isDark ? DesignTokens.darkOutline : DesignTokens.outline),
                borderRadius: const BorderRadius.all(Radius.circular(20)),
                color: isDark ? DesignTokens.darkCard : DesignTokens.surface,
              ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? DesignTokens.textOnPrimary : (isDark ? DesignTokens.textOnDarkSecondary : DesignTokens.textSecondary),
          ),
        ),
      ),
    );
  }
}

/// Shimmer skeleton shown while the orders list loads.
class _OrdersLoadingSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? DesignTokens.darkCard : DesignTokens.outlineVariant,
      highlightColor: isDark ? DesignTokens.darkSurfaceVariant : DesignTokens.surface,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: 5,
        itemBuilder: (context, i) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 90,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(DesignTokens.radius16)),
        ),
      ),
    );
  }
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  static const List<OrderStatus> _activeStatuses = [
    OrderStatus.pending,
    OrderStatus.confirmed,
    OrderStatus.processing,
    OrderStatus.shipped,
    OrderStatus.inTransit,
  ];

  static const List<OrderStatus> _cancelledStatuses = [
    OrderStatus.cancelled,
    OrderStatus.failed,
    OrderStatus.expired,
    OrderStatus.refunded,
    OrderStatus.partiallyRefunded,
  ];

  String _selectedFilter = _OrderFilter.all;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return Scaffold(
        appBar: AppBarFactory.simple(title: 'orders.my_orders'.tr()),
        body: AnimatedEmptyState(icon: Icons.lock_outline_rounded, title: 'auth.sign_in_required'.tr(), subtitle: 'orders.order_history_desc'.tr()),
      );
    }

    final ordersAsync = ref.watch(buyerOrdersProvider);

    return Container(
      decoration: BoxDecoration(gradient: DesignTokens.backgroundGradient(isDark: isDark)),
      child: Scaffold(
        key: const Key('orders_screen_app_bar'),
        appBar: AppBarFactory.simple(title: 'orders.my_orders'.tr()),
        backgroundColor: Colors.transparent,
        body: ordersAsync.when(
          loading: () => _OrdersLoadingSkeleton(),
          error: (error, stack) => _buildErrorState(context, error),
          data: (orders) {
            if (orders.isEmpty) {
              return AnimatedEmptyState(
                key: const Key('orders_empty_message'),
                icon: Icons.shopping_bag_outlined,
                title: 'orders.no_orders'.tr(),
                subtitle: 'orders.no_orders_desc'.tr(),
                showMascot: true,
              );
            }

            final pendingApprovalsCount = orders.where((o) => o.shippingApprovalStatus == ShippingApprovalStatus.pending).length;
            final visibleOrders = _applyFilter(orders);

            // On desktop, cap order list to readable width (840px) — cards shouldn't stretch to 1200px
            final ordersMaxWidth = ResponsiveBreakpoints.isDesktop(context) ? 840.0 : ResponsiveBreakpoints.contentMaxWidth.toDouble();

            return Column(
              children: [
                if (pendingApprovalsCount > 0) PendingApprovalsBanner(count: pendingApprovalsCount),
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: ordersMaxWidth),
                    child: _FilterRow(selectedFilter: _selectedFilter, onFilterSelected: (filter) => setState(() => _selectedFilter = filter)),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: ordersMaxWidth),
                      child: RefreshIndicator(
                        color: DesignTokens.primary,
                        onRefresh: () async => ref.invalidate(buyerOrdersProvider),
                        child: visibleOrders.isEmpty
                            ? _buildEmptyFilter()
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: visibleOrders.length,
                                itemBuilder: (context, index) {
                                  return FadeSlideIn(
                                    delay: Duration(milliseconds: 50 * index.clamp(0, 8)),
                                    child: BuyerOrderCard(order: visibleOrders[index]),
                                  );
                                },
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Order> _applyFilter(List<Order> orders) {
    switch (_selectedFilter) {
      case _OrderFilter.active:
        return orders.where((o) => _activeStatuses.contains(o.orderStatus)).toList();
      case _OrderFilter.delivered:
        return orders.where((o) => o.orderStatus == OrderStatus.delivered).toList();
      case _OrderFilter.cancelled:
        return orders.where((o) => _cancelledStatuses.contains(o.orderStatus)).toList();
      default:
        return orders;
    }
  }

  Widget _buildEmptyFilter() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 64),
          child: AnimatedEmptyState(icon: Icons.inbox_outlined, title: 'orders.no_orders_found'.tr(), subtitle: 'orders.no_orders_match'.tr()),
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    final message = AppError.getMessage(error);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 60, color: DesignTokens.error),
            const SizedBox(height: 16),
            Text('orders.unable_to_load'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: DesignTokens.textSecondary),
            ),
            const SizedBox(height: 24),
            ModernButton(onPressed: () => ref.invalidate(buyerOrdersProvider), label: 'orders.retry'.tr(), icon: Icons.refresh),
          ],
        ),
      ),
    );
  }
}
