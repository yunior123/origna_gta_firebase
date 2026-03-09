// coverage:ignore-file
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/routes.dart';
import 'package:origna_gta/features/cart/cart_provider.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/utils/utils.dart';

/// Factory methods for common AppBar configurations
class AppBarFactory {
  /// AppBar with custom leading widget
  static CustomAppBar custom({
    required String title,
    String? subtitle,
    Widget? leading,
    List<Widget>? actions,
    bool showCartBadge = false,
  }) {
    return CustomAppBar(
      title: title,
      subtitle: subtitle,
      leading: leading,
      actions: actions,
      showBackButton: false,
      showCartBadge: showCartBadge,
    );
  }

  /// AppBar without back button (for main screens)
  static CustomAppBar main({
    required String title,
    List<Widget>? actions,
    bool showCartBadge = false,
  }) {
    return CustomAppBar(
      title: title,
      actions: actions,
      showBackButton: false,
      showCartBadge: showCartBadge,
    );
  }

  /// Simple AppBar with just title and back button
  static CustomAppBar simple({
    required String title,
    String? subtitle,
    VoidCallback? onBackPressed,
  }) {
    return CustomAppBar(title: title, subtitle: subtitle, onBackPressed: onBackPressed);
  }

  /// AppBar with cart badge
  static CustomAppBar withCart({
    required String title,
    List<Widget>? actions,
    VoidCallback? onBackPressed,
  }) {
    return CustomAppBar(
      title: title,
      actions: actions,
      showCartBadge: true,
      onBackPressed: onBackPressed,
    );
  }
}

/// Styled icon button for use in CustomAppBar actions
class AppBarIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String
  tooltip; // WCAG 4.1.2: Required — every IconButton needs a tooltip

  const AppBarIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: Colors.white),
      onPressed: onPressed,
      tooltip: tooltip,
    );
  }
}

/// Reusable custom AppBar with gradient background.
/// Provides consistent styling across the app.
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBackButton;
  final bool showCartBadge;
  final VoidCallback? onBackPressed;
  final double height;

  const CustomAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.showBackButton = true,
    this.showCartBadge = false,
    this.onBackPressed,
    this.height = 60,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [DesignTokens.gradientStart, DesignTokens.gradientMiddle, DesignTokens.gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: DesignTokens.gradientStart.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              // Leading widget or back button
              if (leading != null)
                leading!
              else if (showBackButton)
                _buildIconButton(
                  icon: Icons.arrow_back,
                  tooltip: 'common.back'.tr(),
                  onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
                ),

              // Title (+ optional subtitle)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: subtitle != null
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 17,
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              subtitle!,
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12,
                                letterSpacing: 0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        )
                      : Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 18,
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ),

              // Actions
              if (actions != null) ...actions!,

              // Cart badge (optional)
              if (showCartBadge) const _CartBadge(),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    return IconButton(
      icon: Icon(icon, color: Colors.white),
      onPressed: onPressed,
      tooltip: tooltip,
    );
  }
}

class _CartBadge extends ConsumerWidget {
  const _CartBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartItemCountProvider);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CustomAppBar._buildIconButton(
          icon: Icons.shopping_cart_outlined,
          tooltip: 'common.cart'.tr(),
          onPressed: () {
            final user = ref.read(currentUserProvider);
            if (!context.mounted) return;
            if (user == null) {
              showLoginPrompt(context);
              return;
            }
            Navigator.pushNamed(context, AppRoutes.cart);
          },
        ),
        if (cartCount > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                cartCount > 99 ? '99+' : cartCount.toString(),
                style: TextStyle(
                  color: DesignTokens.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
