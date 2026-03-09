// coverage:ignore-file
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/features/admin/admin_actions_viewmodel.dart';
import 'package:origna_gta/features/admin/admin_providers.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/utils/utils.dart';
import 'package:origna_gta/widgets/animations.dart';
import 'package:origna_gta/widgets/modern_loading_indicator.dart';

/// Documentation for AdminSellersTab
class AdminSellersTab extends ConsumerWidget {
  const AdminSellersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(adminSellersProvider)
        .when(
          loading: () => const ModernLoadingIndicator.fullScreen(),
          error: (error, _) => _buildErrorState(),
          data: (sellers) {
            if (sellers.isEmpty) {
              return AnimatedEmptyState(
                icon: Icons.store_outlined,
                title: 'admin.sellers.no_sellers'.tr(),
                subtitle: 'admin.sellers.no_sellers_desc'.tr(),
              );
            }

            return Column(
              children: [
                // Summary bar
                _SellersSummaryBar(sellers: sellers),
                // Seller list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: sellers.length,
                    itemBuilder: (context, index) {
                      final data = sellers[index];
                      return FadeSlideIn(
                        delay: Duration(milliseconds: 50 * index.clamp(0, 8)),
                        child: _SellerCard(user: data),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DesignTokens.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.cloud_off_rounded,
              size: 40,
              color: DesignTokens.error,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'admin.users.error_fetching'.tr(),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'admin.sellers.pull_to_refresh'.tr(),
            style: TextStyle(color: DesignTokens.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _SellersSummaryBar extends StatelessWidget {
  final List<UserModel> sellers;
  const _SellersSummaryBar({required this.sellers});

  @override
  Widget build(BuildContext context) {
    final active = sellers.where((s) => !s.suspended).length;
    final suspended = sellers.where((s) => s.suspended).length;
    final connected = sellers.where((s) => s.onboardingCompleted).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            DesignTokens.primary.withValues(alpha: 0.08),
            DesignTokens.secondary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(DesignTokens.radius12),
        border: Border.all(color: DesignTokens.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          _summaryChip(
            Icons.people_rounded,
            '$active',
            'admin.sellers.summary_active'.tr(),
            DesignTokens.success,
          ),
          const SizedBox(width: 16),
          _summaryChip(
            Icons.block_rounded,
            '$suspended',
            'admin.sellers.summary_suspended'.tr(),
            DesignTokens.error,
          ),
          const SizedBox(width: 16),
          _summaryChip(
            Icons.link_rounded,
            '$connected',
            'admin.sellers.summary_stripe'.tr(),
            DesignTokens.info,
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(IconData icon, String count, String label, Color color) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: DesignTokens.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SellerCard extends ConsumerWidget {
  final UserModel user;

  const _SellerCard({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = user.name.isNotEmpty ? user.name : 'common.unknown'.tr();
    final email = user.email;
    final stripeAccountId = user.stripeAccountId;
    final stripeOnboarded = user.onboardingCompleted;
    final isSuspended = user.suspended;
    final createdAt = user.createdAt;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radius16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Gradient avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: isSuspended
                        ? LinearGradient(
                            colors: [
                              DesignTokens.error,
                              DesignTokens.error.withValues(alpha: 0.7),
                            ],
                          )
                        : DesignTokens.primaryGradient,
                    borderRadius: BorderRadius.circular(DesignTokens.radius12),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty
                          ? name[0].toUpperCase()
                          : 'admin.users.unknown_user'.tr()[0],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSuspended) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: DesignTokens.error.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.pause_circle_filled_rounded,
                                    size: 12,
                                    color: DesignTokens.error,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'admin.sellers.summary_suspended'.tr(),
                                    style: TextStyle(
                                      color: DesignTokens.error,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: TextStyle(
                          color: DesignTokens.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Info chips row
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Stripe status chip
                _infoChip(
                  icon: stripeOnboarded
                      ? Icons.check_circle_rounded
                      : Icons.schedule_rounded,
                  label: stripeOnboarded
                      ? 'admin.sellers.stripe_connected'.tr()
                      : 'admin.sellers.stripe_pending'.tr(),
                  color: stripeOnboarded
                      ? DesignTokens.success
                      : DesignTokens.warning,
                ),
                if (stripeAccountId != null)
                  _infoChip(
                    icon: Icons.tag_rounded,
                    label: stripeAccountId.length > 14
                        ? '${stripeAccountId.substring(0, 14)}...'
                        : stripeAccountId,
                    color: DesignTokens.textSecondary,
                  ),
                _infoChip(
                  icon: Icons.calendar_today_rounded,
                  label: 'admin.users.joined_date'.tr(
                    namedArgs: {'date': _formatDate(createdAt)},
                  ),
                  color: DesignTokens.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isSuspended)
                  _actionButton(
                    icon: Icons.block_rounded,
                    label: 'admin.sellers.suspend_action'.tr(),
                    color: DesignTokens.error,
                    onTap: () => _suspendSeller(context, ref, user.uid, name),
                  )
                else
                  _actionButton(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'admin.sellers.unsuspend_action'.tr(),
                    color: DesignTokens.success,
                    onTap: () => _unsuspendSeller(context, ref, user.uid, name),
                  ),
                const SizedBox(width: 8),
                _actionButton(
                  icon: Icons.inventory_2_outlined,
                  label: 'admin.sellers.products_action'.tr(),
                  color: DesignTokens.primary,
                  onTap: () => _viewSellerProducts(context, user.uid, name),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _suspendSeller(
    BuildContext context,
    WidgetRef ref,
    String userId,
    String name,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius16),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: DesignTokens.error),
            const SizedBox(width: 10),
            Text('admin.sellers.suspend_seller_title'.tr()),
          ],
        ),
        content: Text(
          'admin.sellers.suspend_seller_confirm'.tr(namedArgs: {'name': name}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              final success = await ref
                  .read(adminActionsViewModelProvider.notifier)
                  .setUserSuspended(userId, true);
              if (!context.mounted) return;
              if (context.mounted) {
                if (success) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('admin.sellers.seller_suspended'.tr()),
                      backgroundColor: DesignTokens.error,
                    ),
                  );
                } else {
                  final error =
                      ref.read(adminActionsViewModelProvider).errorMessage ??
                      'admin.sellers.failed_suspend'.tr();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(error),
                      backgroundColor: DesignTokens.error,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: DesignTokens.error),
            child: Text('admin.sellers.suspend_action'.tr()),
          ),
        ],
      ),
    );
  }

  void _unsuspendSeller(
    BuildContext context,
    WidgetRef ref,
    String userId,
    String name,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final success = await ref
        .read(adminActionsViewModelProvider.notifier)
        .setUserSuspended(userId, false);
    if (context.mounted) {
      if (success) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('admin.sellers.seller_unsuspended'.tr()),
            backgroundColor: DesignTokens.success,
          ),
        );
      } else {
        final error =
            ref.read(adminActionsViewModelProvider).errorMessage ??
            'admin.sellers.failed_unsuspend'.tr();
        messenger.showSnackBar(
          SnackBar(content: Text(error), backgroundColor: DesignTokens.error),
        );
      }
    }
  }

  void _viewSellerProducts(BuildContext context, String sellerId, String name) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) =>
            _SellerProductsScreen(sellerId: sellerId, sellerName: name),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(curve),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 280),
      ),
    );
  }
}

class _SellerProductsScreen extends ConsumerWidget {
  final String sellerId;
  final String sellerName;

  const _SellerProductsScreen({
    required this.sellerId,
    required this.sellerName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: DesignTokens.primaryGradient,
          ),
        ),
        title: Text(
          'admin.sellers.seller_products_title'.tr(
            namedArgs: {'name': sellerName},
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: ref
          .watch(adminProductsProvider(sellerId))
          .when(
            loading: () => const ModernLoadingIndicator.fullScreen(),
            error: (error, stack) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: DesignTokens.error,
                  ),
                  const SizedBox(height: 12),
                  Text('admin.sellers.error_loading_products'.tr()),
                ],
              ),
            ),
            data: (products) {
              if (products.isEmpty) {
                return AnimatedEmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'admin.sellers.no_products'.tr(),
                  subtitle: 'admin.sellers.no_products_desc'.tr(),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  final name = product.name;
                  final price = product.price;
                  final stock = product.stockQuantity;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        DesignTokens.radius12,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: DesignTokens.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.shopping_bag_rounded,
                          color: DesignTokens.primary,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${'admin.sellers.stock_label'.tr(namedArgs: {'stock': stock.toString()})} • \$${price.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: DesignTokens.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      trailing: stock == 0
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: DesignTokens.error.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'admin.sellers.out_of_stock'.tr(),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: DesignTokens.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : null,
                    ),
                  );
                },
              );
            },
          ),
    );
  }
}
