// coverage:ignore-file
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/features/orders/orders_provider.dart';
import 'package:origna_gta/features/orders/shipping_approval_viewmodel.dart';
import 'package:origna_gta/models/generated/models.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/utils/utils.dart';
import 'package:origna_gta/widgets/animations.dart';
import 'package:origna_gta/widgets/custom_app_bar.dart';
import 'package:origna_gta/widgets/modern_button.dart';
import 'package:origna_gta/widgets/modern_loading_indicator.dart';

/// Screen for buyers to approve or reject shipping cost changes
/// This is shown when the seller's actual shipping cost exceeds the estimate by more than 20%
class ShippingApprovalScreen extends ConsumerWidget {
  const ShippingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final approvalsAsync = ref.watch(pendingShippingApprovalsProvider);

    return Container(
      decoration: BoxDecoration(
        gradient: DesignTokens.backgroundGradient(isDark: isDark),
      ),
      child: Scaffold(
        appBar: AppBarFactory.simple(title: 'seller.shipping_approvals'.tr()),
        backgroundColor: Colors.transparent,
        body: approvalsAsync.when(
          loading: () => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(colors: [DesignTokens.primary, DesignTokens.secondary]).createShader(bounds),
                  child: SizedBox(
                    width: 50,
                    height: 50,
                    child: ModernLoadingIndicator(size: 50, strokeWidth: 3, color: Colors.white.withValues(alpha: 0.8), centered: false),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'seller.loading_approvals'.tr(),
                  style: TextStyle(color: DesignTokens.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          error: (error, stack) => Center(
            child: AnimatedEmptyState(
              icon: Icons.error_outline_rounded,
              title: 'common.error_loading'.tr(),
              subtitle: AppError.getMessage(error),
              action: ModernButton(
                label: 'common.retry'.tr(),
                icon: Icons.refresh,
                onPressed: () => ref.invalidate(pendingShippingApprovalsProvider),
                isPrimary: false,
              ),
            ),
          ),
          data: (approvals) {
            if (approvals.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [DesignTokens.success.withValues(alpha: 0.2), DesignTokens.success.withValues(alpha: 0.1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check_circle_outline, size: 60, color: DesignTokens.success),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'seller.no_pending_approvals'.tr(),
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: isDark ? Colors.white : DesignTokens.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'seller.approvals_appear_here'.tr(),
                      style: TextStyle(fontSize: 14, color: DesignTokens.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: approvals.length,
              itemBuilder: (context, index) {
                final order = approvals[index];
                return _ApprovalCard(order: order);
              },
            );
          },
        ),
      ),
    );
  }
}

class _ApprovalCard extends ConsumerStatefulWidget {
  final Order order;

  const _ApprovalCard({required this.order});

  @override
  ConsumerState<_ApprovalCard> createState() => _ApprovalCardState();
}

class _ApprovalCardState extends ConsumerState<_ApprovalCard> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final order = widget.order;
    final items = order.items;
    final estimatedShipping = order.shippingCost;
    final actualShipping = order.actualShipping;
    final pendingTotal = order.pendingTotal;
    final originalTotal = order.total;
    final shippingDifference = actualShipping - estimatedShipping;
    final percentIncrease = estimatedShipping > 0 ? ((shippingDifference / estimatedShipping) * 100).toStringAsFixed(0) : '0';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isDark ? DesignTokens.darkSurfaceVariant.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.8),
            isDark ? DesignTokens.darkSurface.withValues(alpha: 0.4) : DesignTokens.surface.withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DesignTokens.radius16),
        border: Border.all(color: DesignTokens.primary.withValues(alpha: 0.2), width: 1),
        boxShadow: [BoxShadow(color: DesignTokens.primary.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(colors: [DesignTokens.primary, DesignTokens.secondary]).createShader(bounds),
                        child: Text(
                          'Order #${order.orderId.substring(0, 8).toUpperCase()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        DateFormat('MMM dd, yyyy').format(order.createdAt),
                        style: TextStyle(color: DesignTokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [DesignTokens.warning.withValues(alpha: 0.2), DesignTokens.warning.withValues(alpha: 0.1)]),
                    borderRadius: BorderRadius.circular(DesignTokens.radius12),
                    border: Border.all(color: DesignTokens.warning.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pending, size: 16, color: DesignTokens.warning),
                      const SizedBox(width: 6),
                      Text(
                        'seller.approval_needed'.tr(),
                        style: TextStyle(color: DesignTokens.warning, fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            Divider(height: 1, color: DesignTokens.outlineVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 20),

            // Shipping cost comparison
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [DesignTokens.info.withValues(alpha: 0.15), DesignTokens.primary.withValues(alpha: 0.1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(DesignTokens.radius12),
                border: Border.all(color: DesignTokens.primary.withValues(alpha: 0.3), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.local_shipping, size: 22, color: DesignTokens.primary),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          'seller.shipping_cost_update'.tr(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: DesignTokens.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'seller.estimated'.tr(),
                            style: TextStyle(color: DesignTokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Text('\$${estimatedShipping.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      Icon(Icons.arrow_forward, color: DesignTokens.textDisabled),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'seller.actual'.tr(),
                            style: TextStyle(color: DesignTokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '\$${actualShipping.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: DesignTokens.primary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [DesignTokens.error.withValues(alpha: 0.2), DesignTokens.error.withValues(alpha: 0.1)]),
                      borderRadius: BorderRadius.circular(DesignTokens.radius8),
                      border: Border.all(color: DesignTokens.error.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '+\$${shippingDifference.toStringAsFixed(2)} (+$percentIncrease%)',
                      style: TextStyle(color: DesignTokens.error, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Order items summary
            Text('seller.items_count'.tr(namedArgs: {'count': items.length.toString()}), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 12),
            ...items
                .take(3)
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${item.name} x${item.quantity}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '\$${(item.price * item.quantity).toStringAsFixed(2)}',
                          style: TextStyle(color: DesignTokens.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
            if (items.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'seller.more_items'.tr(namedArgs: {'count': (items.length - 3).toString()}),
                  style: TextStyle(color: DesignTokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),

            const SizedBox(height: 20),
            Divider(height: 1, color: DesignTokens.outlineVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 20),

            // Total comparison
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'seller.original_total'.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: DesignTokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${originalTotal.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 16, color: DesignTokens.textSecondary, decoration: TextDecoration.lineThrough, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'seller.new_total'.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: DesignTokens.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${pendingTotal.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: DesignTokens.primary),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Action buttons
            if (_isProcessing)
              Center(
                child: ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(colors: [DesignTokens.primary, DesignTokens.secondary]).createShader(bounds),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: ModernLoadingIndicator(size: 40, strokeWidth: 3, color: Colors.white.withValues(alpha: 0.8), centered: false),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [DesignTokens.error.withValues(alpha: 0.2), DesignTokens.error.withValues(alpha: 0.1)]),
                        borderRadius: BorderRadius.circular(DesignTokens.radius12),
                        border: Border.all(color: DesignTokens.error.withValues(alpha: 0.4)),
                      ),
                      child: Semantics(
                        button: true,
                        label: 'btn-reject-cancel',
                        child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showRejectConfirmation(context),
                          borderRadius: BorderRadius.circular(DesignTokens.radius12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Center(
                              child: Text(
                                'seller.reject_cancel'.tr(),
                                style: TextStyle(color: DesignTokens.error, fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                            ),
                          ),
                        ),
                      ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: 'btn-approve-shipping',
                      child: ModernButton(onPressed: () => _handleApproval(true), label: 'seller.approve'.tr(), icon: Icons.check_circle),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleApproval(bool approved) async {
    setState(() => _isProcessing = true);
    final messenger = ScaffoldMessenger.of(context);
    final viewModel = ref.read(shippingApprovalViewModelProvider.notifier);

    final success = await viewModel.approveShippingCost(widget.order.orderId, approved);
    if (!mounted) return;

    if (success) {
      messenger.showSnackBar(
        SnackBar(content: Text(approved ? 'seller.shipping_approved'.tr() : 'seller.order_cancelled'.tr()), backgroundColor: approved ? DesignTokens.success : DesignTokens.warning),
      );
    } else {
      final error = ref.read(shippingApprovalViewModelProvider).errorMessage ?? 'seller.failed_update_approval'.tr();
      messenger.showSnackBar(SnackBar(content: Text(error), backgroundColor: DesignTokens.error));
    }

    setState(() => _isProcessing = false);
  }

  void _showRejectConfirmation(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radius20)),
        backgroundColor: isDark ? DesignTokens.darkSurface : Colors.white,
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: DesignTokens.warning, size: 28),
            const SizedBox(width: 12),
            Text(
              'seller.cancel_order_title'.tr(),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: isDark ? Colors.white : DesignTokens.textPrimary),
            ),
          ],
        ),
        content: Text(
          'seller.cancel_order_body'.tr(),
          style: TextStyle(color: DesignTokens.textSecondary, fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('seller.go_back'.tr(), style: TextStyle(color: DesignTokens.textSecondary)),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [DesignTokens.error.withValues(alpha: 0.9), DesignTokens.error.withValues(alpha: 0.85)]),
              borderRadius: BorderRadius.circular(DesignTokens.radius12),
            ),
            child: Material(
              color: Colors.transparent,
              child: Semantics(
                button: true,
                label: 'btn-confirm-cancel-order',
                child: InkWell(
                onTap: () {
                  Navigator.pop(dialogContext);
                  _handleApproval(false);
                },
                borderRadius: BorderRadius.circular(DesignTokens.radius12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text(
                    'seller.yes_cancel_order'.tr(),
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ),
            ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Flutter Previews ────────────────────────────────────────────────────────

