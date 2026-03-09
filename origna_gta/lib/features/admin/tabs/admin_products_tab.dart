// coverage:ignore-file
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/features/admin/admin_actions_viewmodel.dart';
import 'package:origna_gta/features/admin/admin_providers.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/utils/utils.dart';
import 'package:origna_gta/widgets/animations.dart';
import 'package:origna_gta/widgets/modern_loading_indicator.dart';

/// Documentation for AdminProductsTab
class AdminProductsTab extends ConsumerStatefulWidget {
  const AdminProductsTab({super.key});

  @override
  ConsumerState<AdminProductsTab> createState() => _AdminProductsTabState();
}

class _AdminProductsTabState extends ConsumerState<AdminProductsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _stockFilter = 'all';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search and Filter
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(DesignTokens.radius16),
            boxShadow: DesignTokens.shadowSm,
          ),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'admin.sellers.search_hint'.tr(),
                  hintStyle: TextStyle(
                    color: DesignTokens.textDisabled,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: DesignTokens.primary,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: DesignTokens.textSecondary,
                            size: 20,
                          ),
                          tooltip: 'common.clear'.tr(),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: DesignTokens.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radius12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      'admin.sellers.filter_all_products'.tr(),
                      'all',
                    ),
                    _buildApprovalFilterChip(),
                    _buildFilterChip(
                      'admin.sellers.filter_in_stock'.tr(),
                      'in_stock',
                    ),
                    _buildFilterChip(
                      'admin.sellers.filter_out_of_stock'.tr(),
                      'out_of_stock',
                    ),
                    _buildFilterChip(
                      'admin.sellers.filter_low_stock'.tr(),
                      'low_stock',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Products List
        Expanded(
          child: ref
              .watch(adminProductsProvider(null))
              .when(
                loading: () => const ModernLoadingIndicator.fullScreen(),
                error: (error, stack) =>
                    Center(child: Text('admin.users.error_fetching'.tr())),
                data: (productsRaw) {
                  if (productsRaw.isEmpty) {
                    return AnimatedEmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'admin.sellers.no_products'.tr(),
                    );
                  }

                  final products = productsRaw.where((data) {
                    final name = data.name.toLowerCase();
                    final stock = data.stockQuantity;

                    final matchesSearch =
                        _searchQuery.isEmpty || name.contains(_searchQuery);

                    bool matchesStock = true;
                    switch (_stockFilter) {
                      case 'pending_review':
                        matchesStock =
                            data.lifecycleStatus ==
                            ProductLifecycleStatusValues.underReview;
                        break;
                      case 'in_stock':
                        matchesStock = stock > 0;
                        break;
                      case 'out_of_stock':
                        matchesStock = stock == 0;
                        break;
                      case 'low_stock':
                        matchesStock = stock > 0 && stock < 5;
                        break;
                    }

                    return matchesSearch && matchesStock;
                  }).toList();

                  if (products.isEmpty) {
                    return Center(child: Text('admin.sellers.no_match'.tr()));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final data = products[index];
                      return FadeSlideIn(
                        delay: Duration(milliseconds: 30 * index.clamp(0, 10)),
                        child: _ProductCard(product: data),
                      );
                    },
                  );
                },
              ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  Widget _buildApprovalFilterChip() {
    return ref
        .watch(adminProductsProvider(null))
        .when(
          loading: () => const SizedBox.shrink(),
          error: (err, stack) => const SizedBox.shrink(),
          data: (products) {
            final pendingCount = products
                .where(
                  (p) =>
                      p.lifecycleStatus ==
                      ProductLifecycleStatusValues.underReview,
                )
                .length;
            final isSelected = _stockFilter == 'pending_review';
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _stockFilter = 'pending_review'),
                child: AnimatedContainer(
                  duration: DesignTokens.durationFast,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? DesignTokens.warning : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? DesignTokens.warning
                          : DesignTokens.outlineVariant.withValues(alpha: 0.5),
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: DesignTokens.warning.withValues(
                                alpha: 0.25,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '⏳ Pending Review',
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : DesignTokens.textSecondary,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          fontSize: 12,
                        ),
                      ),
                      if (pendingCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.3)
                                : DesignTokens.warning,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$pendingCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _stockFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _stockFilter = value),
        child: AnimatedContainer(
          duration: DesignTokens.durationFast,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _ApprovalBadge extends StatelessWidget {
  final String lifecycleStatus;
  const _ApprovalBadge({required this.lifecycleStatus});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;
    switch (lifecycleStatus) {
      case ProductLifecycleStatusValues.active:
      case ProductLifecycleStatusValues.approved:
        color = const Color(0xFF22C55E);
        label = 'Approved';
        icon = Icons.check_circle_rounded;
        break;
      case ProductLifecycleStatusValues.rejected:
        color = const Color(0xFFEF4444);
        label = 'Rejected';
        icon = Icons.cancel_rounded;
        break;
      default:
        color = const Color(0xFFF59E0B);
        label = 'Under Review';
        icon = Icons.hourglass_top_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  final ProductModel product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = product.name;
    final price = product.price;
    final stock = product.stockQuantity;
    final imageUrls = product.imageUrls;

    Color stockColor;
    String stockText;
    IconData stockIcon;
    if (stock == 0) {
      stockColor = DesignTokens.error;
      stockText = 'product.out_of_stock'.tr();
      stockIcon = Icons.remove_circle_rounded;
    } else if (stock < 5) {
      stockColor = DesignTokens.warning;
      stockText = 'admin.sellers.low_stock_count'.tr(
        namedArgs: {'count': stock.toString()},
      );
      stockIcon = Icons.warning_rounded;
    } else {
      stockColor = DesignTokens.success;
      stockText = 'admin.sellers.in_stock_count'.tr(
        namedArgs: {'count': stock.toString()},
      );
      stockIcon = Icons.check_circle_rounded;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radius16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Product Image
            ClipRRect(
              borderRadius: BorderRadius.circular(DesignTokens.radius12),
              child: imageUrls.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrls.first,
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: DesignTokens.surfaceVariant,
                          borderRadius: BorderRadius.circular(
                            DesignTokens.radius12,
                          ),
                        ),
                        child: Icon(
                          Icons.image_rounded,
                          color: DesignTokens.textDisabled,
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: DesignTokens.surfaceVariant,
                          borderRadius: BorderRadius.circular(
                            DesignTokens.radius12,
                          ),
                        ),
                        child: Icon(
                          Icons.broken_image_rounded,
                          color: DesignTokens.textDisabled,
                        ),
                      ),
                    )
                  : Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: DesignTokens.surfaceVariant,
                        borderRadius: BorderRadius.circular(
                          DesignTokens.radius12,
                        ),
                      ),
                      child: Icon(
                        Icons.image_rounded,
                        color: DesignTokens.textDisabled,
                      ),
                    ),
            ),
            const SizedBox(width: 14),

            // Product Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '\$${price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: DesignTokens.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: stockColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(stockIcon, size: 13, color: stockColor),
                        const SizedBox(width: 4),
                        Text(
                          stockText,
                          style: TextStyle(
                            color: stockColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  _ApprovalBadge(lifecycleStatus: product.lifecycleStatus),
                ],
              ),
            ),

            // Actions
            PopupMenuButton<String>(
              onSelected: (value) => _handleAction(context, ref, value),
              icon: Icon(
                Icons.more_vert_rounded,
                color: DesignTokens.textDisabled,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radius12),
              ),
              itemBuilder: (context) => [
                if (product.lifecycleStatus !=
                    ProductLifecycleStatusValues.active)
                  _menuItem(
                    'approve',
                    Icons.check_circle_rounded,
                    'Approve Product',
                    DesignTokens.success,
                  ),
                if (product.lifecycleStatus !=
                    ProductLifecycleStatusValues.rejected)
                  _menuItem(
                    'reject',
                    Icons.cancel_rounded,
                    'Reject Product',
                    DesignTokens.error,
                  ),
                _menuItem(
                  'set_stock',
                  Icons.edit_rounded,
                  'admin.sellers.set_stock'.tr(),
                  DesignTokens.primary,
                ),
                _menuItem(
                  'mark_out_of_stock',
                  Icons.remove_circle_outline_rounded,
                  'admin.sellers.mark_out_of_stock'.tr(),
                  DesignTokens.warning,
                ),
                _menuItem(
                  'view_seller',
                  Icons.person_rounded,
                  'admin.sellers.view_seller'.tr(),
                  DesignTokens.info,
                ),
                if (product.isDigital)
                  _menuItem(
                    'view_urls',
                    Icons.link_rounded,
                    'View Download URLs',
                    DesignTokens.info,
                  ),
                _menuItem(
                  'delete',
                  Icons.delete_rounded,
                  'admin.sellers.delete_product'.tr(),
                  DesignTokens.error,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _approveProduct(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    // Confirmation dialog — prevents accidental approval (H-15)
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('admin.products.approve_confirm_title'.tr()),
        content: Text('admin.products.approve_confirm_body'.tr(namedArgs: {'name': product.name})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('admin.products.approve_action'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final success = await ref
        .read(adminActionsViewModelProvider.notifier)
        .approveProduct(product.id);
    if (!context.mounted) return;
    if (success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('admin.products.approve_success'.tr()),
          backgroundColor: const Color(0xFF22C55E),
        ),
      );
    } else {
      final error =
          ref.read(adminActionsViewModelProvider).errorMessage ??
          'admin.products.approve_error'.tr();
      messenger.showSnackBar(
        SnackBar(content: Text(error), backgroundColor: DesignTokens.error),
      );
    }
  }

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(color: DesignTokens.textSecondary, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          ),
        ),
      ],
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'approve':
        _approveProduct(context, ref);
        break;
      case 'reject':
        _showRejectDialog(context, ref);
        break;
      case 'view_urls':
        _showDigitalUrls(context);
        break;
      case 'set_stock':
        _showSetStockDialog(context, ref);
        break;
      case 'mark_out_of_stock':
        _setStock(context, ref, 0);
        break;
      case 'view_seller':
        _viewSeller(context, ref);
        break;
      case 'delete':
        _showDeleteDialog(context, ref);
        break;
    }
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label,
    Color color,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 13, color: color)),
        ],
      ),
    );
  }

  void _setStock(BuildContext context, WidgetRef ref, int quantity) async {
    final messenger = ScaffoldMessenger.of(context);
    final success = await ref
        .read(adminActionsViewModelProvider.notifier)
        .updateProductStock(product.id, quantity);
    if (!context.mounted) return;
    if (success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            quantity == 0
                ? 'product.out_of_stock'.tr()
                : 'admin.sellers.stock_updated'.tr(
                    namedArgs: {'quantity': quantity.toString()},
                  ),
          ),
          backgroundColor: quantity == 0
              ? DesignTokens.warning
              : DesignTokens.success,
        ),
      );
    } else {
      final error =
          ref.read(adminActionsViewModelProvider).errorMessage ??
          'admin.sellers.failed_stock_update'.tr();
      messenger.showSnackBar(
        SnackBar(content: Text(error), backgroundColor: DesignTokens.error),
      );
    }
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
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
            Text('admin.sellers.delete_product'.tr()),
          ],
        ),
        content: Text(
          'admin.sellers.delete_confirm'.tr(namedArgs: {'name': product.name}),
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
                  .deleteProduct(product.id);
              if (!context.mounted) return;
              if (success) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('admin.sellers.deleted_success'.tr()),
                    backgroundColor: DesignTokens.error,
                  ),
                );
              } else {
                final error =
                    ref.read(adminActionsViewModelProvider).errorMessage ??
                    'admin.sellers.failed_delete'.tr();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(error),
                    backgroundColor: DesignTokens.error,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: DesignTokens.error),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );
  }

  void _showDigitalUrls(BuildContext context) {
    final builds = product.digitalBuilds ?? {};
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius16),
        ),
        title: Row(
          children: [
            Icon(Icons.link_rounded, color: DesignTokens.info),
            const SizedBox(width: 10),
            Text('admin.products.download_urls_title'.tr()),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'admin.products.digital_type_label'.tr(namedArgs: {'type': product.digitalType ?? 'unknown'}),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              if (builds.isEmpty)
                Text(
                  'admin.products.no_download_urls'.tr(),
                  style: const TextStyle(color: Color(0xFF6B7280)),
                )
              else
                ...builds.entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.key,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        SelectableText(
                          e.value,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.close'.tr()),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context, WidgetRef ref) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius16),
        ),
        title: Row(
          children: [
            Icon(Icons.cancel_rounded, color: DesignTokens.error),
            const SizedBox(width: 10),
            Text('admin.products.reject_title'.tr()),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'admin.products.reject_product_label'.tr(namedArgs: {'name': product.name}),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              maxLength: 1000,
              decoration: InputDecoration(
                labelText: 'admin.products.reject_reason_label'.tr(),
                border: const OutlineInputBorder(),
                hintText: 'admin.products.reject_reason_hint'.tr(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              final success = await ref
                  .read(adminActionsViewModelProvider.notifier)
                  .rejectProduct(product.id, reason);
              if (!context.mounted) return;
              if (success) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('admin.products.reject_success'.tr()),
                    backgroundColor: DesignTokens.error,
                  ),
                );
              } else {
                final error =
                    ref.read(adminActionsViewModelProvider).errorMessage ??
                    'admin.products.reject_error'.tr();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(error),
                    backgroundColor: DesignTokens.error,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: DesignTokens.error),
            child: Text('admin.products.reject_action'.tr()),
          ),
        ],
      ),
    );
  }

  void _showSetStockDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(
      text: product.stockQuantity.toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('admin.sellers.set_stock_title'.tr()),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'admin.sellers.stock_quantity_label'.tr(),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              final newStock = int.tryParse(controller.text) ?? 0;
              Navigator.pop(ctx);
              _setStock(context, ref, newStock);
            },
            child: Text('common.update'.tr()),
          ),
        ],
      ),
    );
  }

  void _viewSeller(BuildContext context, WidgetRef ref) async {
    final sellerId = product.sellerId;

    final messenger = ScaffoldMessenger.of(context);
    final sellerData = await ref
        .read(adminActionsViewModelProvider.notifier)
        .fetchUserById(sellerId);
    if (!context.mounted) return;
    if (sellerData == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('admin.sellers.seller_not_found'.tr()),
          backgroundColor: DesignTokens.error,
        ),
      );
      return;
    }

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radius16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: DesignTokens.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: DesignTokens.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text('admin.sellers.seller_info'.tr()),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow(
                'common.name'.tr(),
                sellerData.name.isNotEmpty
                    ? sellerData.name
                    : 'common.unknown'.tr(),
              ),
              const SizedBox(height: 8),
              _detailRow(
                'common.email'.tr(),
                sellerData.email.isNotEmpty
                    ? sellerData.email
                    : 'common.unknown'.tr(),
              ),
              const SizedBox(height: 8),
              _detailRow(
                'Stripe',
                sellerData.onboardingCompleted
                    ? 'admin.sellers.stripe_connected'.tr()
                    : 'admin.sellers.stripe_pending'.tr(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('common.close'.tr()),
            ),
          ],
        ),
      );
    }
  }
}
