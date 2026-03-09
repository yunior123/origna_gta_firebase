// coverage:ignore-file
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/features/cart/cart_provider.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:shimmer/shimmer.dart';

/// Documentation for CartItemScreen
class CartItemScreen extends StatelessWidget {
  final String productId;
  final String cartItemId;
  final Map<String, dynamic> item;
  final VoidCallback onRemove;

  const CartItemScreen({super.key, required this.productId, required this.cartItemId, required this.item, required this.onRemove});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Extract item fields using schema constants (static - won't rebuild on quantity change)
    final imageUrlsList = (item[Fields.imageUrls] as List<dynamic>?)?.cast<String>() ?? [];
    final name = item[Fields.name] as String? ?? 'product.product_fallback'.tr();
    final unitPrice = (item[Fields.price] ?? 0.0).toDouble();
    final isDigital = item[Fields.isDigital] as bool? ?? false;
    final buyerNote = item[Fields.buyerNote] as String?;

    return Dismissible(
      key: ValueKey('dismiss_$cartItemId'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      confirmDismiss: (_) async {
        HapticFeedback.mediumImpact();
        return true;
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: DesignTokens.spacing12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [DesignTokens.error.withValues(alpha: 0.8), DesignTokens.error],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(DesignTokens.radius16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 28),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: DesignTokens.spacing12),
        padding: const EdgeInsets.all(DesignTokens.spacing12),
        decoration: BoxDecoration(
          color: isDark ? DesignTokens.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(DesignTokens.radius16),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : DesignTokens.outline.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: DesignTokens.primary.withValues(alpha: isDark ? 0.08 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Product image
                ClipRRect(
                  borderRadius: BorderRadius.circular(DesignTokens.radius12),
                  child: SizedBox(width: 80, height: 80, child: _buildImage(imageUrlsList, isDark)),
                ),
                const SizedBox(width: DesignTokens.spacing12),
                // Name + price
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white : DesignTokens.textPrimary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isDigital) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.download_outlined, size: 11, color: DesignTokens.digital.withValues(alpha: 0.8)),
                            const SizedBox(width: 3),
                            Text(
                              'cart.digital_instant_delivery'.tr(),
                              style: TextStyle(fontSize: 11, color: DesignTokens.digital.withValues(alpha: 0.8), fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      // Price display wrapped in Consumer - only this rebuilds when quantity changes
                      Consumer(
                        builder: (context, ref, _) {
                          final quantityAsync = ref.watch(cartItemQuantityProvider(cartItemId));
                          final quantity = quantityAsync.valueOrNull ?? 1;
                          final totalPrice = unitPrice * quantity;
                          return ShaderMask(
                            shaderCallback: (bounds) => DesignTokens.primaryGradient.createShader(bounds),
                            child: Text(
                              '\$${totalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          );
                        },
                      ),
                      // Unit price hint when qty > 1
                      Consumer(
                        builder: (context, ref, _) {
                          final quantityAsync = ref.watch(cartItemQuantityProvider(cartItemId));
                          final quantity = quantityAsync.valueOrNull ?? 1;
                          if (quantity <= 1) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '\$${unitPrice.toStringAsFixed(2)} ${'cart.each_suffix'.tr()}',
                              style: TextStyle(fontSize: 11, color: DesignTokens.textSecondary, fontWeight: FontWeight.w500),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // Quantity controls + delete
                Column(
                  children: [
                    Consumer(
                      builder: (context, ref, _) {
                        final quantityAsync = ref.watch(cartItemQuantityProvider(cartItemId));
                        final quantity = quantityAsync.valueOrNull ?? 0;
                        final cartController = ref.read(cartControllerProvider);

                        if (quantity <= 0) return const SizedBox.shrink();

                        return Container(
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.06) : DesignTokens.surfaceVariant,
                            borderRadius: BorderRadius.circular(DesignTokens.radius12),
                            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : DesignTokens.outline.withValues(alpha: 0.6)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _QuantityButton(
                                key: Key('cart_qty_minus_$cartItemId'),
                                icon: Icons.remove_rounded,
                                onPressed: quantity > 1 ? () => cartController.updateQuantity(cartItemId, quantity - 1) : null,
                                isDark: isDark,
                                semanticLabel: 'btn-cart-qty-minus',
                              ),
                              AnimatedSwitcher(
                                duration: DesignTokens.durationFast,
                                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                                child: Padding(
                                  key: ValueKey(quantity),
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Text(
                                    '$quantity',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: isDark ? Colors.white : DesignTokens.textPrimary),
                                  ),
                                ),
                              ),
                              _QuantityButton(
                                key: Key('cart_qty_plus_$cartItemId'),
                                icon: Icons.add_rounded,
                                onPressed: () async {
                                  // AUDIT FIX (H6): Show feedback if stock limit reached
                                  final success = await cartController.updateQuantity(cartItemId, quantity + 1);
                                  if (!success && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('cart.stock_limit_reached'.tr()),
                                        duration: const Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                },
                                isDark: isDark,
                                semanticLabel: 'btn-cart-qty-plus',
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: DesignTokens.spacing8),
                    IconButton(
                      tooltip: 'cart.remove_from_cart'.tr(),
                      icon: Icon(Icons.delete_outline_rounded, color: DesignTokens.error.withValues(alpha: 0.7), size: 20),
                      onPressed: onRemove,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 18,
                    ),
                    const SizedBox(height: DesignTokens.spacing4),
                    Consumer(
                      builder: (context, ref, _) {
                        return IconButton(
                          tooltip: 'cart.save_for_later'.tr(),
                          icon: Icon(Icons.bookmark_outline_rounded, color: DesignTokens.primary.withValues(alpha: 0.8), size: 20),
                          onPressed: () => _saveForLater(context, ref, productId, cartItemId),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          splashRadius: 18,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            _buildNoteRow(context, isDark, buyerNote),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(List<String> imageUrlsList, bool isDark) {
    if (imageUrlsList.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [DesignTokens.gradientStart.withValues(alpha: 0.9), DesignTokens.gradientMiddle.withValues(alpha: 0.9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
            ),
            child: const Icon(Icons.camera_alt_outlined, size: 26, color: Colors.white),
          ),
        ),
      );
    }

    if (imageUrlsList.length == 1) {
      return CachedNetworkImage(
        imageUrl: imageUrlsList[0],
        fit: BoxFit.cover,
        placeholder: (context, url) => Shimmer.fromColors(
          baseColor: isDark ? DesignTokens.darkOutline : DesignTokens.outlineVariant,
          highlightColor: isDark ? DesignTokens.darkSurfaceVariant : DesignTokens.surface,
          child: Container(color: isDark ? DesignTokens.darkSurface : Colors.white),
        ),
        errorWidget: (context, url, error) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [DesignTokens.gradientStart.withValues(alpha: 0.85), DesignTokens.gradientMiddle.withValues(alpha: 0.85)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
              ),
              child: const Icon(Icons.camera_alt_outlined, size: 24, color: Colors.white),
            ),
          ),
        ),
      );
    }

    // Multiple images - swipeable PageView
    return Stack(
      children: [
        PageView.builder(
          itemCount: imageUrlsList.length,
          itemBuilder: (context, index) {
            return CachedNetworkImage(
              imageUrl: imageUrlsList[index],
              fit: BoxFit.cover,
              placeholder: (context, url) => Shimmer.fromColors(
                baseColor: isDark ? DesignTokens.darkSurface : DesignTokens.outlineVariant,
                highlightColor: isDark ? DesignTokens.darkSurfaceVariant : DesignTokens.surface,
                child: Container(color: isDark ? DesignTokens.darkSurface : Colors.white),
              ),
              errorWidget: (context, url, error) => Container(
                color: isDark ? const Color(0xFF2A2A3E) : DesignTokens.surface,
                child: Icon(Icons.image_not_supported_outlined, size: 24, color: DesignTokens.textDisabled),
              ),
            );
          },
        ),
        Positioned(
          bottom: 4,
          right: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.collections, color: Colors.white, size: 10),
                const SizedBox(width: 2),
                Text(
                  '${imageUrlsList.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoteRow(BuildContext context, bool isDark, String? buyerNote) {
    if (buyerNote == null || buyerNote.isEmpty) {
      return InkWell(
        onTap: () => _showAddNoteSheet(context),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_comment_outlined, size: 14, color: DesignTokens.primary),
              const SizedBox(width: 6),
              Text(
                'cart.item_note_add'.tr(),
                style: TextStyle(fontSize: 12, color: DesignTokens.primary, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: () => _showAddNoteSheet(context, initialNote: buyerNote),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? DesignTokens.surfaceVariant : DesignTokens.surface,
          border: Border.all(color: DesignTokens.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.edit_note_outlined, size: 16, color: DesignTokens.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('cart.item_note_label'.tr(), style: TextStyle(fontSize: 10, color: DesignTokens.textSecondary)),
                  const SizedBox(height: 2),
                  Text(
                    buyerNote,
                    style: TextStyle(fontSize: 12, color: DesignTokens.textPrimary, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            Icon(Icons.edit_outlined, size: 14, color: DesignTokens.primary),
          ],
        ),
      ),
    );
  }

  Future<void> _saveForLater(BuildContext context, WidgetRef ref, String productId, String cartItemId) async {
    final messenger = ScaffoldMessenger.of(context);
    final success = await ref.read(cartControllerProvider).saveForLater(productId, cartItemId);
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(success ? 'cart.saved_for_later'.tr() : 'cart.save_for_later_error'.tr()),
          backgroundColor: success ? DesignTokens.success : DesignTokens.error,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _showAddNoteSheet(BuildContext context, {String? initialNote}) {
    final controller = TextEditingController(text: initialNote);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, top: 24, left: 20, right: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    initialNote == null ? 'cart.item_note_add'.tr() : 'cart.item_note_edit'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(icon: const Icon(Icons.close_rounded), tooltip: 'common.close'.tr(), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 200,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'cart.item_note_hint'.tr(),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            Consumer(
              builder: (context, ref, _) {
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesignTokens.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final note = controller.text.trim();
                    ref.read(cartControllerProvider).updateBuyerNote(cartItemId, note.isEmpty ? null : note);
                    Navigator.pop(context);
                  },
                  child: Text('cart.item_note_save'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact quantity +/- button with haptic feedback
class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isDark;
  final String semanticLabel;

  const _QuantityButton({super.key, required this.icon, this.onPressed, required this.isDark, required this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;
    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: !isDisabled,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(DesignTokens.radius8),
          onTap: isDisabled
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onPressed!();
                },
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 18, color: isDisabled ? DesignTokens.textDisabled : (isDark ? Colors.white70 : DesignTokens.primary)),
          ),
        ),
      ),
    );
  }
}
