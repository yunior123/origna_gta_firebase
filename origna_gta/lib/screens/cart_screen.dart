// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:shimmer/shimmer.dart';
import 'package:origna_gta/core/routes.dart';
import 'package:origna_gta/features/auth/auth_provider.dart';
import 'package:origna_gta/features/cart/cart_provider.dart';
import 'package:origna_gta/screens/cartitem_screen.dart';
import 'package:origna_gta/utils/constants.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/utils/responsive_layout.dart';
import 'package:origna_gta/utils/utils.dart';
import 'package:origna_gta/widgets/animations.dart';
import 'package:origna_gta/widgets/custom_app_bar.dart';
import 'package:origna_gta/widgets/modern_button.dart';
import 'package:origna_gta/widgets/modern_loading_indicator.dart';

/// Cart screen using optimized Riverpod patterns
/// - Main screen only watches cart item IDs (lightweight)
/// - Each cart item widget watches its own data via family provider
/// - Summary widget only watches what it needs
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  static const checkoutButtonKey = Key('cart_checkout_button');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      return Scaffold(
        appBar: AppBarFactory.simple(title: 'cart.your_cart'.tr()),
        body: AnimatedEmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'auth.sign_in_required'.tr(),
          subtitle: 'cart.sign_in_subtitle'.tr(),
        ),
      );
    }

    // Use select to only rebuild when product IDs change (not quantities)
    final productIdsAsync = ref.watch(
      cartItemsProvider.select(
        (async) =>
            async.whenData((items) => items.map((i) => i.cartItemId).toList()),
      ),
    );

    return Scaffold(
      key: const Key('cart_screen_title'),
      appBar: AppBarFactory.simple(title: 'cart.your_cart'.tr()),
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: DesignTokens.backgroundGradient(isDark: isDark),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: (ResponsiveBreakpoints.isTablet(context) || ResponsiveBreakpoints.isDesktop(context))
                  ? ResponsiveBreakpoints.contentMaxWidth
                  : double.infinity,
            ),
            child: productIdsAsync.when(
              loading: () => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            DesignTokens.primary.withValues(alpha: 0.15),
                            DesignTokens.secondary.withValues(alpha: 0.15),
                          ],
                        ),
                      ),
                      child: Center(
                        child: ShaderMask(
                          shaderCallback: (bounds) =>
                              DesignTokens.primaryGradient.createShader(bounds),
                          child: const SizedBox(
                            width: 32,
                            height: 32,
                            child: ModernLoadingIndicator(
                              size: 32,
                              strokeWidth: 3,
                              color: Colors.white,
                              centered: false,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'cart.loading_cart'.tr(),
                      style: TextStyle(
                        color: DesignTokens.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              error: (error, stack) => AnimatedEmptyState(
                icon: Icons.error_outline_rounded,
                title: 'cart.unable_to_load'.tr(),
                subtitle: 'cart.load_error_subtitle'.tr(),
              ),
              data: (productIds) {
                if (productIds.isEmpty) {
                  return AnimatedEmptyState(
                    key: const Key('cart_empty_message'),
                    icon: Icons.shopping_cart_outlined,
                    title: 'cart.empty_cart'.tr(),
                    subtitle: 'cart.empty_cart_desc'.tr(),
                    showMascot: true,
                    action: SizedBox(
                      width: 240,
                      child: ModernButton(
                        label: 'common.go_shopping'.tr(),
                        icon: Icons.arrow_back,
                        onPressed: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            Navigator.of(
                              context,
                            ).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
                          }
                        },
                      ),
                    ),
                  );
                }

                final isWideLayout = ResponsiveBreakpoints.isTablet(context) || ResponsiveBreakpoints.isDesktop(context);
                final summaryWidth = ResponsiveBreakpoints.isDesktop(context) ? 360.0 : 280.0;

                final unavailableBanner = Consumer(
                  builder: (context, ref, _) {
                    final unavailableAsync = ref.watch(unavailableCartItemsProvider);
                    return unavailableAsync.maybeWhen(
                      data: (ids) {
                        if (ids.isEmpty) return const SizedBox.shrink();
                        return Container(
                          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: DesignTokens.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: DesignTokens.warning.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 18, color: DesignTokens.warning),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'cart.unavailable_items_warning'.tr(namedArgs: {'count': ids.length.toString()}),
                                  style: TextStyle(fontSize: 13, color: DesignTokens.warning, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    );
                  },
                );

                final itemsList = Expanded(
                  child: RefreshIndicator(
                    color: DesignTokens.primary,
                    onRefresh: () async => ref.invalidate(cartItemsProvider),
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: productIds.length,
                      itemBuilder: (context, index) {
                        final cartItemDocId = productIds[index];
                        return FadeSlideIn(
                          delay: Duration(milliseconds: 50 * index.clamp(0, 8)),
                          child: _CartItemWidget(
                            key: ValueKey(cartItemDocId),
                            cartItemDocId: cartItemDocId,
                          ),
                        );
                      },
                    ),
                  ),
                );

                if (isWideLayout) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [unavailableBanner, itemsList],
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: summaryWidth,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(0, 12, 16, 16),
                          child: const _CartSummary(isSidebar: true),
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    unavailableBanner,
                    itemsList,
                    FadeSlideIn(
                      delay: Duration(milliseconds: 50 * productIds.length),
                      beginOffset: const Offset(0, 0.2),
                      child: const _CartSummary(),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Individual cart item widget - only rebuilds when THIS item's data changes
class _CartItemWidget extends ConsumerWidget {
  final String cartItemDocId;

  const _CartItemWidget({super.key, required this.cartItemDocId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch only this specific item's details via family provider
    final itemAsync = ref.watch(cartItemDetailProvider(cartItemDocId));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return itemAsync.when(
      loading: () => Shimmer.fromColors(
        baseColor: isDark ? DesignTokens.darkCard : DesignTokens.outlineVariant,
        highlightColor: isDark ? DesignTokens.darkSurfaceVariant : DesignTokens.surface,
        child: Container(
          margin: const EdgeInsets.only(bottom: DesignTokens.spacing12),
          padding: const EdgeInsets.all(DesignTokens.spacing12),
          height: 104,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(DesignTokens.radius16),
          ),
          child: Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(DesignTokens.radius12),
                ),
              ),
              const SizedBox(width: DesignTokens.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 60,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      error: (error, stack) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Container(
          decoration: BoxDecoration(
            color: DesignTokens.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: DesignTokens.error.withValues(alpha: 0.2)),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.error_outline_rounded, color: DesignTokens.error, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('cart.item_load_error'.tr(), style: TextStyle(color: DesignTokens.error, fontSize: 13))),
              TextButton(
                onPressed: () => ref.invalidate(cartItemDetailProvider(cartItemDocId)),
                child: Text('common.retry'.tr()),
              ),
            ],
          ),
        ),
      ),
      data: (item) {
        if (item == null) {
          // Item document was deleted externally (e.g. product removed by seller).
          // Show a dismissible error card rather than silently hiding the row.
          // cartItemDocId format: "productId" or "productId_variantId" (unused, kept for reference)
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: DesignTokens.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(DesignTokens.radius12),
                border: Border.all(color: DesignTokens.warning.withValues(alpha: 0.25)),
              ),
              padding: const EdgeInsets.all(DesignTokens.spacing12),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: DesignTokens.warning, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text('cart.item_no_longer_available'.tr(), style: TextStyle(color: DesignTokens.warningText, fontSize: 13))),
                  TextButton(
                    onPressed: () => ref.read(cartControllerProvider).removeFromCart(cartItemDocId),
                    child: Text('common.remove'.tr(), style: TextStyle(color: DesignTokens.warning, fontSize: 12)),
                  ),
                ],
              ),
            ),
          );
        }
        return CartItemScreen(
          productId: item.productId,
          cartItemId: cartItemDocId,
          item: item.toMap(),
          onRemove: () =>
              ref.read(cartControllerProvider).removeFromCart(cartItemDocId),
        );
      },
    );
  }
}

/// Cart summary - only watches what it needs for display
class _CartSummary extends ConsumerWidget {
  final bool isSidebar;
  const _CartSummary({this.isSidebar = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch only if cart is empty (for visibility logic)
    final isEmpty = ref.watch(
      cartWithDetailsProvider.select(
        (async) => async.whenData((items) => items.isEmpty),
      ),
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : DesignTokens.outline.withValues(alpha: 0.3);

    return isEmpty.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
      data: (isEmpty) {
        if (isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spacing16,
            vertical: DesignTokens.spacing20,
          ),
          decoration: BoxDecoration(
            color: isDark ? DesignTokens.darkCard : Colors.white,
            border: isSidebar
                ? Border.all(color: borderColor)
                : Border(top: BorderSide(color: borderColor)),
            boxShadow: [
              BoxShadow(
                color: DesignTokens.primary.withValues(
                  alpha: isDark ? 0.1 : 0.06,
                ),
                blurRadius: isSidebar ? 12 : 20,
                offset: isSidebar ? const Offset(0, 4) : const Offset(0, -8),
              ),
            ],
            borderRadius: isSidebar
                ? BorderRadius.circular(DesignTokens.radius16)
                : const BorderRadius.vertical(
                    top: Radius.circular(DesignTokens.radius24),
                  ),
          ),
          child: Column(
            children: [
              const _CartTotalDisplay(),
              const SizedBox(height: DesignTokens.spacing12),
              const _FreeShippingBar(),
              const SizedBox(height: DesignTokens.spacing12),
              const _CheckoutButton(),
            ],
          ),
        );
      },
    );
  }
}

/// Cart total display with info icons and delivery instructions
class _CartTotalDisplay extends ConsumerWidget {
  const _CartTotalDisplay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final deliveryInstructions = ref.watch(deliveryInstructionsProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            DesignTokens.primary.withValues(alpha: 0.08),
            DesignTokens.secondary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DesignTokens.radius16),
        border: Border.all(
          color: DesignTokens.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subtotal row with item count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Consumer(
                  builder: (context, ref, _) {
                    final totalItems = ref.watch(cartItemCountProvider);
                    return Text(
                      '${'cart.subtotal_with_count'.tr(namedArgs: {'count': totalItems.toString()})}:',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : DesignTokens.textPrimary,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Only this Consumer rebuilds when the subtotal value changes
              Flexible(
                child: Consumer(
                  builder: (context, ref, _) {
                    final subtotalAsync = ref.watch(
                      cartWithDetailsProvider.select(
                        (async) => async.whenData(
                          (items) => items.fold(
                            0.0,
                            (total, item) => total + (item.price * item.quantity),
                          ),
                        ),
                      ),
                    );
                    return subtotalAsync.when(
                      loading: () => const SizedBox(width: 100, height: 28),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (subtotal) => ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [DesignTokens.primary, DesignTokens.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            NumberFormat.currency(
                              locale: "en_CA",
                              symbol: "CAD \$",
                            ).format(subtotal),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Service fees row with info icon
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: DesignTokens.info.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'cart.service_fees'.tr(),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? DesignTokens.outlineVariant : DesignTokens.textPrimary,
                  ),
                ),
              ),
              Text(
                '${BusinessRules.platformFeePercent.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? DesignTokens.outlineVariant : DesignTokens.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message:
                    'cart.service_fee_tooltip'.tr(namedArgs: {'percent': BusinessRules.platformFeePercent.toStringAsFixed(1)}),
                child: Semantics(
                  button: true,
                  label: 'btn-info-service-fee',
                  child: InkWell(
                    onTap: () => _showInfoSheet(
                      context,
                      'cart.service_fees'.tr(),
                    'cart.service_fee_info'.tr(namedArgs: {'percent': BusinessRules.platformFeePercent.toStringAsFixed(1)}),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: DesignTokens.info.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Tax estimate row with info icon
          Row(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 16,
                color: DesignTokens.warning.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'cart.tax_estimate'.tr(),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? DesignTokens.outlineVariant : DesignTokens.textPrimary,
                  ),
                ),
              ),
              Consumer(
                builder: (context, ref, _) {
                  final profileProvince = ref
                    .watch(userProfileProvider)
                    .valueOrNull
                    ?.address
                    ?.state;
                  final province = (profileProvince == null ||
                      profileProvince.trim().isEmpty)
                      ? ProvinceCodeValues.ontario
                    : profileProvince.trim();

                  final subtotalAsync = ref.watch(
                    cartWithDetailsProvider.select(
                      (async) => async.whenData(
                        (items) => items.fold(
                          0.0,
                          (total, item) =>
                              total + (item.price * item.quantity),
                        ),
                      ),
                    ),
                  );

                  return subtotalAsync.when(
                    loading: () => const SizedBox(width: 70, height: 16),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (subtotal) {
                      final estimatedTax = subtotal * getTaxRate(province);
                      return Text(
                        NumberFormat.currency(
                          locale: "en_CA",
                          symbol: "CAD \$",
                        ).format(estimatedTax),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? DesignTokens.outlineVariant
                              : DesignTokens.textPrimary,
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(width: 4),
              Tooltip(
                message:
                    'cart.tax_tooltip'.tr(),
                child: Semantics(
                  button: true,
                  label: 'btn-info-tax-estimate',
                  child: InkWell(
                    onTap: () => _showInfoSheet(
                      context,
                      'cart.tax_estimate_title'.tr(),
                    'cart.tax_info'.tr(),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: DesignTokens.info.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Estimated Total row (subtotal + service fee [waived for premium] + estimated tax)
          Consumer(
            builder: (context, ref, _) {
              final profileProvince = ref.watch(userProfileProvider).valueOrNull?.address?.state;
              final province = (profileProvince == null || profileProvince.trim().isEmpty)
                  ? ProvinceCodeValues.ontario
                  : profileProvince.trim();
              final subtotalAsync = ref.watch(
                cartWithDetailsProvider.select(
                  (async) => async.whenData(
                    (items) => items.fold(0.0, (t, item) => t + (item.price * item.quantity)),
                  ),
                ),
              );
              return subtotalAsync.maybeWhen(
                data: (subtotal) {
                  // Platform fee is deducted from seller payout — NOT added to buyer charge.
                  // Stripe PaymentIntent = subtotal + tax only. Display fee row for transparency,
                  // but do NOT include it in the estimated total (matches checkout_screen logic).
                  // Tax estimate: excludes shipping (unknown at cart stage) — label as estimated
                  final tax = subtotal * getTaxRate(province);
                  final estimatedTotal = subtotal + tax;
                  return Column(
                    children: [
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'checkout.estimated_total'.tr(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : DesignTokens.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            NumberFormat.currency(locale: 'en_CA', symbol: 'CAD \$').format(estimatedTotal),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: DesignTokens.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                },
                orElse: () => const SizedBox.shrink(),
              );
            },
          ),

          // Delivery instructions row with pencil icon
          Semantics(
            button: true,
            label: 'btn-delivery-instructions',
            child: InkWell(
            onTap: () => _showDeliveryInstructionsDialog(
              context,
              ref,
              deliveryInstructions,
            ),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : DesignTokens.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: deliveryInstructions.isNotEmpty
                      ? DesignTokens.primary.withValues(alpha: 0.3)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.edit_note_outlined,
                    size: 20,
                    color: deliveryInstructions.isNotEmpty
                        ? DesignTokens.primary
                        : (isDark ? DesignTokens.textDisabled : DesignTokens.textSecondary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'common.delivery_instructions'.tr(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : DesignTokens.textPrimary,
                          ),
                        ),
                        if (deliveryInstructions.isNotEmpty)
                          Text(
                            deliveryInstructions,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? DesignTokens.textDisabled
                                  : DesignTokens.textSecondary,
                            ),
                          )
                        else
                          Text(
                            'cart.add_instructions_optional'.tr(),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? DesignTokens.textSecondary
                                  : DesignTokens.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: isDark ? DesignTokens.textDisabled : DesignTokens.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }

  void _showInfoSheet(BuildContext context, String title, String content) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? DesignTokens.darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: DesignTokens.info,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : DesignTokens.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              content,
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: isDark ? DesignTokens.outlineVariant : DesignTokens.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('common.understood'.tr(), style: const TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeliveryInstructionsDialog(
    BuildContext context,
    WidgetRef ref,
    String currentInstructions,
  ) {
    final controller = TextEditingController(text: currentInstructions);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? DesignTokens.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.edit_note_outlined, color: DesignTokens.primary),
            const SizedBox(width: 12),
            Text('common.delivery_instructions'.tr()),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'cart.delivery_instructions_desc'.tr(),
              style: TextStyle(
                fontSize: 14,
                color: isDark ? DesignTokens.outlineVariant : DesignTokens.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'cart.delivery_hint'.tr(),
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? DesignTokens.textSecondary : DesignTokens.textDisabled,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? DesignTokens.textPrimary : DesignTokens.outlineVariant,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: DesignTokens.primary),
                ),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : DesignTokens.surface,
              ),
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : DesignTokens.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(deliveryInstructionsProvider.notifier).state = controller
                  .text
                  .trim();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: DesignTokens.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('common.save'.tr()),
          ),
        ],
      ),
    );
  }
}

/// Checkout button - static widget, reads cart data lazily on press
class _CheckoutButton extends ConsumerWidget {
  const _CheckoutButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ModernButton(
      key: CartScreen.checkoutButtonKey,
      label: 'cart.proceed_to_checkout'.tr(),
      onPressed: () {
        final cartDetails = ref.read(cartWithDetailsProvider);
        cartDetails.whenData((itemsWithDetails) {
          if (itemsWithDetails.isEmpty) return;
          final subtotal = itemsWithDetails.fold(
            0.0,
            (total, item) => total + (item.price * item.quantity),
          );
          Navigator.pushNamed(
            context,
            AppRoutes.checkout,
            arguments: CheckoutArgs(items: itemsWithDetails, total: subtotal),
          );
        });
      },
      fullWidth: true,
      icon: Icons.payment,
    );
  }
}

/// Free shipping progress bar shown above the checkout button.
/// Encourages higher order values by showing how close the buyer is to qualifying.
class _FreeShippingBar extends ConsumerWidget {
  const _FreeShippingBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtotalAsync = ref.watch(
      cartWithDetailsProvider.select(
        (async) => async.whenData(
          (items) => items.fold(
            0.0,
            (total, item) => total + (item.price * item.quantity),
          ),
        ),
      ),
    );

    return subtotalAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (subtotalDollars) {
        final thresholdDollars =
            BusinessRules.freeShippingThresholdCents / 100.0;
        final qualified = subtotalDollars >= thresholdDollars;
        final progress =
            (subtotalDollars / thresholdDollars).clamp(0.0, 1.0);
        final remaining = thresholdDollars - subtotalDollars;
        final remainingFormatted = NumberFormat.currency(
          locale: 'en_CA',
          symbol: '\$',
          decimalDigits: 2,
        ).format(remaining);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: qualified
                ? DesignTokens.success.withValues(alpha: isDark ? 0.12 : 0.08)
                : (isDark
                    ? DesignTokens.primary.withValues(alpha: 0.10)
                    : DesignTokens.surfaceSubtle),
            borderRadius: BorderRadius.circular(DesignTokens.radius12),
            border: Border.all(
              color: qualified
                  ? DesignTokens.success.withValues(alpha: 0.35)
                  : DesignTokens.primary.withValues(alpha: 0.20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status line
              Text(
                qualified
                    ? 'cart.free_shipping_qualified'.tr()
                    : 'cart.free_shipping_progress'
                        .tr(namedArgs: {'amount': remainingFormatted}),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: qualified
                      ? DesignTokens.success
                      : (isDark ? Colors.white : DesignTokens.textPrimary),
                ),
              ),
              const SizedBox(height: 8),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : DesignTokens.outline.withValues(alpha: 0.4),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    qualified ? DesignTokens.success : DesignTokens.primary,
                  ),
                ),
              ),
              if (!qualified) ...[
                const SizedBox(height: 6),
                Text(
                  'cart.free_shipping_threshold'.tr(),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? DesignTokens.textSecondary
                        : DesignTokens.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Extension to add copyWith method to CartItemDetailModel
extension CartItemDetailModelExtension on CartItemDetailModel {
  CartItemDetailModel copyWith({
    String? productId,
    String? name,
    String? description,
    double? price,
    List<String>? imageUrls,
    int? quantity,
    dynamic createdAt,
    Address? sellerAddress,
    String? sellerId,
    String? sellerName,
    String? status,
    bool? isDigital,
  }) {
    return CartItemDetailModel(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrls: imageUrls ?? this.imageUrls,
      quantity: quantity ?? this.quantity,
      createdAt: createdAt ?? this.createdAt,
      sellerAddress: sellerAddress ?? this.sellerAddress,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      status: status ?? this.status,
      isDigital: isDigital ?? this.isDigital,
    );
  }
}

// ─── Flutter Previews ────────────────────────────────────────────────────────

