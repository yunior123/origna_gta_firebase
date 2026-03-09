// coverage:ignore-file
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/routes.dart';
import 'package:origna_gta/utils/constants.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/utils/env_config.dart';
import 'package:origna_gta/utils/responsive_layout.dart';
import 'package:origna_gta/utils/utils.dart';
import 'package:origna_gta/widgets/animations.dart';
import 'package:origna_gta/widgets/custom_app_bar.dart';
import 'package:origna_gta/widgets/modern_button.dart';
import 'package:origna_gta/widgets/modern_loading_indicator.dart';
import 'package:share_plus/share_plus.dart';

import '../core/theme_provider.dart';
import '../features/auth/auth_provider.dart';
import '../features/profile/profile_viewmodel.dart';
import '../features/subscription/subscription_provider.dart';

/// Documentation for ProfileScreen
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileProvider);
    final profileState = ref.watch(profileViewModelProvider);
    final viewModel = ref.read(profileViewModelProvider.notifier);
    final currentUser = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isPremium = ref.watch(subscriptionStreamProvider).whenOrNull(data: (s) => s?.isPremium) ?? userProfileAsync.valueOrNull?.isPremium ?? false;

    // Listen for success/error messages
    ref.listen(profileViewModelProvider, (previous, next) {
      if (next.successMessage != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.successMessage!), backgroundColor: DesignTokens.success, behavior: SnackBarBehavior.floating));
      } else if (next.errorMessage != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.errorMessage!), backgroundColor: DesignTokens.error, behavior: SnackBarBehavior.floating));
      }
    });

    return ProfileScreenLayout(
      userProfileAsync: userProfileAsync,
      currentUser: currentUser,
      isExportLoading: profileState.isLoading,
      themeMode: themeMode,
      isPremium: isPremium,
      onSignIn: () => Navigator.pushNamed(context, AppRoutes.login),
      onSignOut: () async {
        await viewModel.signOut();
        if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
        }
      },
      onDeleteAccountRequested: () => showDialog(context: context, builder: (context) => const _DeleteAccountDialog()),
      onExportData: () => viewModel.exportData(),
      onThemeChange: (mode) => ref.read(themeModeProvider.notifier).state = mode,
      onLanguageChange: (lang) async {
        final newLocale = Locale(lang);
        await context.setLocale(newLocale);
        await viewModel.updateLanguage(lang);
      },
    );
  }
}

/// Documentation for ProfileScreenLayout
class ProfileScreenLayout extends StatelessWidget {
  final AsyncValue<UserModel?> userProfileAsync;
  final User? currentUser;
  final bool isExportLoading;
  final ThemeMode themeMode;
  final bool isPremium;
  final VoidCallback onSignIn;
  final VoidCallback onSignOut;
  final VoidCallback onDeleteAccountRequested;
  final VoidCallback onExportData;
  final void Function(ThemeMode) onThemeChange;
  final void Function(String) onLanguageChange;

  const ProfileScreenLayout({
    super.key,
    required this.userProfileAsync,
    required this.currentUser,
    required this.isExportLoading,
    required this.themeMode,
    required this.isPremium,
    required this.onSignIn,
    required this.onSignOut,
    required this.onDeleteAccountRequested,
    required this.onExportData,
    required this.onThemeChange,
    required this.onLanguageChange,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBarFactory.simple(title: 'profile.settings'.tr()),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [isDark ? DesignTokens.darkSurface : DesignTokens.surface, isDark ? DesignTokens.darkSurfaceVariant : Colors.white],
          ),
        ),
        child: userProfileAsync.when(
          loading: () => Center(
            child: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [DesignTokens.primary, DesignTokens.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: const ModernLoadingIndicator(color: Colors.white, strokeWidth: 3, centered: false),
            ),
          ),
          error: (err, stack) =>
              AnimatedEmptyState(icon: Icons.error_outline_rounded, title: 'profile.error_loading'.tr(), subtitle: 'common.retry_later'.tr()),
          data: (userModel) {
            if (userModel == null) {
              if (currentUser != null) {
                final needsVerification =
                    !currentUser!.emailVerified && !currentUser!.providerData.any((p) => p.providerId == 'google.com') && !EnvConfig().isEmulator;
                if (needsVerification) {
                  return _EmailVerificationRequiredView(user: currentUser!);
                }
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(colors: [DesignTokens.primary, DesignTokens.secondary]).createShader(bounds),
                        child: const ModernLoadingIndicator(color: Colors.white, strokeWidth: 3, centered: false),
                      ),
                      const SizedBox(height: 16),
                      Text('profile.setting_up'.tr(), style: TextStyle(fontSize: 16, color: DesignTokens.textSecondary)),
                    ],
                  ),
                );
              }
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline, size: 80, color: DesignTokens.textDisabled),
                    const SizedBox(height: 16),
                    Text('profile.sign_in_prompt'.tr(), style: TextStyle(fontSize: 18, color: DesignTokens.textPrimary)),
                    const SizedBox(height: 16),
                    Semantics(
                      button: true,
                      label: 'btn-sign-in',
                      child: ElevatedButton.icon(
                        key: const Key('profile_sign_in_button'),
                        onPressed: onSignIn,
                        icon: const Icon(Icons.login_rounded),
                        label: Text('auth.sign_in'.tr()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DesignTokens.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            final isSeller = userModel.roles.contains(UserRoles.seller) || userModel.roles.contains(UserRoles.admin);
            final isAdmin = userModel.roles.contains(UserRoles.admin);

            final maxWidth = ResponsiveBreakpoints.getValue<double>(context: context, mobile: double.infinity, mobilePlus: 500, tablet: 600, desktop: 700);
            final padding = ResponsiveBreakpoints.getSpacing(context, SpacingSize.lg);

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    children: [
                      FadeSlideIn(child: _buildProfileHeader(userModel, isDark, isPremium: isPremium)),
                      SizedBox(height: ResponsiveBreakpoints.getSpacing(context, SpacingSize.xl)),

                      FadeSlideIn(
                        delay: const Duration(milliseconds: 50),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(context, 'profile.section_navigation'.tr()),
                            _buildMenuItem(
                              context,
                              key: const Key('profile_my_orders_button'),
                              icon: Icons.shopping_bag_outlined,
                              semanticLabel: 'menu-my-orders',
                              title: 'profile.my_orders'.tr(),
                              subtitle: 'profile.view_purchases'.tr(),
                              onTap: () => Navigator.pushNamed(context, AppRoutes.orders),
                            ),
                            if (isSeller) ...[
                              _buildMenuItem(
                                context,
                                key: const Key('profile_seller_orders_button'),
                                icon: Icons.store_outlined,
                                semanticLabel: 'menu-seller-orders',
                                title: 'profile.seller_orders'.tr(),
                                subtitle: 'profile.manage_sales'.tr(),
                                onTap: () => Navigator.pushNamed(context, AppRoutes.sellerOrders),
                              ),
                              _buildMenuItem(
                                context,
                                key: const Key('profile_seller_dashboard_button'),
                                icon: Icons.dashboard_outlined,
                                semanticLabel: 'menu-seller-dashboard',
                                title: 'profile.seller_dashboard'.tr(),
                                subtitle: 'profile.manage_products_account'.tr(),
                                onTap: () => Navigator.pushNamed(context, AppRoutes.sellerProducts),
                              ),
                            ] else
                              _buildMenuItem(
                                context,
                                key: const Key('profile_become_seller_button'),
                                icon: Icons.storefront,
                                semanticLabel: 'menu-become-seller',
                                title: 'profile.become_seller'.tr(),
                                subtitle: 'profile.start_selling'.tr(),
                                onTap: () => Navigator.pushNamed(context, AppRoutes.sellerRegistration),
                              ),
                            if (isAdmin)
                              _buildMenuItem(
                                context,
                                key: const Key('profile_admin_panel_button'),
                                icon: Icons.admin_panel_settings,
                                semanticLabel: 'menu-admin-panel',
                                title: 'profile.admin_panel'.tr(),
                                subtitle: 'profile.platform_management'.tr(),
                                onTap: () => Navigator.pushNamed(context, AppRoutes.adminPanel),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      FadeSlideIn(delay: const Duration(milliseconds: 75), child: _buildPremiumMenuItem(context, isPremium)),
                      const SizedBox(height: 24),

                      FadeSlideIn(
                        delay: const Duration(milliseconds: 100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(context, 'profile.section_settings'.tr()),
                            if (isPremium)
                              _buildMenuItem(
                                context,
                                key: const Key('profile_notifications_button'),
                                icon: Icons.notifications_outlined,
                                semanticLabel: 'menu-notifications',
                                title: 'profile.notifications'.tr(),
                                subtitle: 'profile.manage_notifications'.tr(),
                                onTap: () => Navigator.pushNamed(context, AppRoutes.notifications),
                              ),
                            _buildMenuItem(
                              context,
                              key: const Key('profile_messages_button'),
                              icon: Icons.chat_bubble_outline_rounded,
                              semanticLabel: 'menu-my-messages',
                              title: 'chat.inbox_title'.tr(),
                              subtitle: 'chat.inbox_subtitle'.tr(),
                              onTap: () => Navigator.pushNamed(context, AppRoutes.chatInbox),
                            ),
                            _buildMenuItem(
                              context,
                              key: const Key('profile_favorites_button'),
                              icon: Icons.bookmark_border_rounded,
                              semanticLabel: 'menu-favorites',
                              title: 'favorites.my_favorites'.tr(),
                              subtitle: 'profile.your_saved_products'.tr(),
                              onTap: () => Navigator.pushNamed(context, AppRoutes.favorites),
                            ),
                            _buildMenuItem(
                              context,
                              key: const Key('profile_address_button'),
                              icon: Icons.location_on_outlined,
                              semanticLabel: 'menu-address',
                              title: 'profile.address'.tr(),
                              subtitle: 'profile.manage_delivery_address'.tr(),
                              onTap: () => Navigator.pushNamed(context, AppRoutes.addressManagement),
                            ),
                            _buildMenuItem(
                              context,
                              key: const Key('profile_terms_button'),
                              icon: Icons.description_outlined,
                              semanticLabel: 'menu-terms',
                              title: 'profile.terms_conditions'.tr(),
                              subtitle: 'profile.legal_agreements'.tr(),
                              onTap: () => openTermsOfService(context),
                            ),
                            _buildMenuItem(
                              context,
                              key: const Key('profile_privacy_button'),
                              icon: Icons.lock_outline,
                              semanticLabel: 'menu-privacy',
                              title: 'profile.privacy_policy'.tr(),
                              subtitle: 'profile.how_we_protect'.tr(),
                              onTap: () => openPrivacyPolicy(context),
                            ),
                            _buildMenuItem(
                              context,
                              key: const Key('profile_language_button'),
                              icon: Icons.language,
                              semanticLabel: 'menu-language',
                              title: 'profile.language'.tr(),
                              subtitle: context.locale.languageCode == 'fr' ? 'Français' : 'English',
                              onTap: () {
                                final newLocale = context.locale.languageCode == 'fr' ? 'en' : 'fr';
                                onLanguageChange(newLocale);
                              },
                            ),
                            _buildThemeToggle(context, isDark),
                            _buildMenuItem(
                              context,
                              key: const Key('profile_export_button'),
                              icon: Icons.download_for_offline_outlined,
                              semanticLabel: 'menu-export-data',
                              title: 'profile.export_data'.tr(),
                              subtitle: 'profile.export_desc'.tr(),
                              isLoading: isExportLoading,
                              onTap: onExportData,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      FadeSlideIn(
                        delay: const Duration(milliseconds: 125),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [_buildSectionHeader(context, 'profile.section_support'.tr()), _buildAppInfoSection(context, isDark)],
                        ),
                      ),
                      const SizedBox(height: 24),

                      FadeSlideIn(
                        delay: const Duration(milliseconds: 150),
                        child: Column(
                          children: [
                            Semantics(
                              button: true,
                              label: 'btn-sign-out',
                              child: ModernButton(
                                key: const Key('profile_sign_out_button'),
                                label: 'auth.sign_out'.tr(),
                                onPressed: onSignOut,
                                icon: Icons.logout,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Semantics(
                              button: true,
                              label: 'btn-delete-account',
                              child: GestureDetector(
                                key: const Key('profile_delete_account_button'),
                                onTap: onDeleteAccountRequested,
                                behavior: HitTestBehavior.opaque,
                                child: Semantics(
                                  container: true,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: Center(
                                      child: Text(
                                        'profile.delete_account'.tr(),
                                        style: TextStyle(color: DesignTokens.error, fontSize: 15, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppInfoSection(BuildContext context, bool isDark) {
    const appVersion = '1.1.0';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'profile.app_info'.tr(),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: DesignTokens.textSecondary, letterSpacing: 0.8),
          ),
        ),
        _buildMenuItem(
          context,
          key: const Key('profile_rate_app_button'),
          icon: Icons.star_outline_rounded,
          semanticLabel: 'menu-rate-app',
          title: 'profile.rate_app'.tr(),
          subtitle: 'profile.rate_app_desc'.tr(),
          onTap: () {},
        ),
        _buildMenuItem(
          context,
          key: const Key('profile_share_app_button'),
          icon: Icons.share_outlined,
          semanticLabel: 'menu-share-app',
          title: 'profile.share_app'.tr(),
          subtitle: 'profile.share_app_desc'.tr(),
          onTap: () => SharePlus.instance.share(ShareParams(text: 'profile.share_text'.tr())),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? DesignTokens.darkSurfaceVariant.withValues(alpha: 0.5) : Colors.white,
            borderRadius: BorderRadius.circular(DesignTokens.radius12),
            border: Border.all(color: isDark ? DesignTokens.darkOutline : DesignTokens.outlineVariant, width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [DesignTokens.primary.withValues(alpha: 0.15), DesignTokens.secondary.withValues(alpha: 0.15)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(DesignTokens.radius8),
                ),
                child: const Icon(Icons.info_outline_rounded, color: DesignTokens.primary, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'profile.app_version'.tr(namedArgs: {'version': appVersion}),
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: isDark ? DesignTokens.textOnDark : DesignTokens.textPrimary),
                ),
              ),
              Text('OrignaGTA', style: TextStyle(fontSize: 13, color: DesignTokens.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    Key? key,
    required IconData icon,
    String? semanticLabel,
    required String title,
    String? subtitle,
    bool isLoading = false,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? DesignTokens.darkSurfaceVariant.withValues(alpha: 0.5) : Colors.white,
        borderRadius: BorderRadius.circular(DesignTokens.radius12),
        border: Border.all(color: isDark ? DesignTokens.darkOutline : DesignTokens.outlineVariant, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Semantics(
        button: true,
        label: semanticLabel ?? 'menu-${title.toLowerCase().replaceAll(' ', '-')}',
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          behavior: HitTestBehavior.opaque,
          child: Semantics(
            container: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [DesignTokens.primary.withValues(alpha: 0.15), DesignTokens.secondary.withValues(alpha: 0.15)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(DesignTokens.radius8),
                    ),
                    child: Icon(icon, color: DesignTokens.primary, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? DesignTokens.textOnDark : DesignTokens.textPrimary),
                        ),
                        if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle, style: TextStyle(fontSize: 12, color: DesignTokens.textSecondary))],
                      ],
                    ),
                  ),
                  if (isLoading) const ModernLoadingIndicator.small() else Icon(Icons.chevron_right, color: DesignTokens.textDisabled, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumMenuItem(BuildContext context, bool isPremium) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            DesignTokens.primary.withValues(alpha: isPremium ? 0.1 : 0.06),
            DesignTokens.secondary.withValues(alpha: isPremium ? 0.1 : 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DesignTokens.radius12),
        border: Border.all(
          color: DesignTokens.primary.withValues(alpha: isPremium ? 0.3 : 0.15),
          width: isPremium ? 1.5 : 1,
        ),
      ),
      child: Semantics(
        button: true,
        label: 'menu-premium',
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.pushNamed(context, AppRoutes.subscription);
          },
          behavior: HitTestBehavior.opaque,
          child: Semantics(
            container: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [DesignTokens.primary, DesignTokens.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(DesignTokens.radius8),
                    ),
                    child: const Icon(Icons.workspace_premium, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'subscription.premium_label'.tr(),
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? DesignTokens.textOnDark : DesignTokens.textPrimary),
                            ),
                            if (isPremium) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: DesignTokens.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                                child: Text(
                                  'subscription.status_active'.tr(),
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: DesignTokens.success),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isPremium ? 'subscription.menu_manage_desc'.tr() : 'subscription.menu_upgrade_desc'.tr(),
                          style: TextStyle(fontSize: 12, color: DesignTokens.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: DesignTokens.textDisabled, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(UserModel userModel, bool isDark, {required bool isPremium}) {
    final initials = userModel.name.isNotEmpty ? userModel.name[0].toUpperCase() : 'U';
    final isSeller = userModel.roles.contains(UserRoles.seller) || userModel.roles.contains(UserRoles.admin);
    final isAdmin = userModel.roles.contains(UserRoles.admin);

    return Builder(
      builder: (context) {
        final headerPadding = ResponsiveBreakpoints.getSpacing(context, SpacingSize.xl);
        final avatarSize = ResponsiveBreakpoints.getValue<double>(context: context, mobile: 76.0, mobilePlus: 86.0, tablet: 96.0, desktop: 106.0);
        final fontSize = ResponsiveBreakpoints.getValue<double>(context: context, mobile: 32.0, mobilePlus: 36.0, tablet: 40.0, desktop: 44.0);

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [DesignTokens.gradientStart, DesignTokens.gradientMiddle, DesignTokens.gradientEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(DesignTokens.radius20),
            boxShadow: [
              BoxShadow(color: DesignTokens.primary.withValues(alpha: 0.45), blurRadius: 28, offset: const Offset(0, 10)),
              BoxShadow(color: DesignTokens.secondary.withValues(alpha: 0.2), blurRadius: 44, offset: const Offset(0, 18)),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Decorative blob — top right (cyan)
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [DesignTokens.accent.withValues(alpha: 0.28), Colors.transparent]),
                  ),
                ),
              ),
              // Decorative blob — bottom left (coral)
              Positioned(
                bottom: -15,
                left: -15,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [DesignTokens.tertiary.withValues(alpha: 0.22), Colors.transparent]),
                  ),
                ),
              ),
              // Main content
              Padding(
                padding: EdgeInsets.all(headerPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar with triple concentric glow rings
                    Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // Outermost pulse ring — golden for premium
                        Container(
                          width: avatarSize + 32,
                          height: avatarSize + 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isPremium ? DesignTokens.warning.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        // Middle ring
                        Container(
                          width: avatarSize + 16,
                          height: avatarSize + 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.1),
                            border: Border.all(
                              color: isPremium ? DesignTokens.warning.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.18),
                              width: isPremium ? 1.5 : 1,
                            ),
                          ),
                        ),
                        // Inner avatar circle
                        Container(
                          width: avatarSize,
                          height: avatarSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Colors.white.withValues(alpha: 0.3), Colors.white.withValues(alpha: 0.14)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2.5),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 22, offset: const Offset(0, 8)),
                              if (isPremium) BoxShadow(color: DesignTokens.warning.withValues(alpha: 0.35), blurRadius: 24, spreadRadius: 2),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              initials,
                              style: TextStyle(fontSize: fontSize, color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: -2),
                            ),
                          ),
                        ),
                        // Premium crown badge — bottom-right of avatar
                        if (isPremium)
                          Positioned(
                            right: (avatarSize + 32) / 2 - avatarSize / 2 - 2,
                            bottom: (avatarSize + 32) / 2 - avatarSize / 2 - 2,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [DesignTokens.warning, DesignTokens.tertiary],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [BoxShadow(color: DesignTokens.warning.withValues(alpha: 0.6), blurRadius: 8, spreadRadius: 1)],
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Center(child: Icon(Icons.workspace_premium, size: 14, color: Colors.white)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      userModel.name,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      userModel.email,
                      style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.72), letterSpacing: 0.1),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isAdmin || isSeller) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(isAdmin ? Icons.admin_panel_settings_rounded : Icons.storefront_rounded, color: Colors.white, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              isAdmin ? 'Admin' : 'Seller',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    _ProfileCompletionBar(userModel: userModel, isPremium: isPremium),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        title,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: DesignTokens.textSecondary, letterSpacing: 0.8),
      ),
    );
  }

  Widget _buildThemeToggle(BuildContext context, bool isDark) {
    final themeMode = this.themeMode;

    return Container(
      key: const Key('profile_theme_button'),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? DesignTokens.darkSurfaceVariant.withValues(alpha: 0.5) : Colors.white,
        borderRadius: BorderRadius.circular(DesignTokens.radius12),
        border: Border.all(color: isDark ? DesignTokens.darkOutline : DesignTokens.outlineVariant, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Semantics(
        label: 'menu-appearance',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [DesignTokens.primary.withValues(alpha: 0.15), DesignTokens.secondary.withValues(alpha: 0.15)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(DesignTokens.radius8),
                ),
                child: Icon(
                  themeMode == ThemeMode.dark
                      ? Icons.dark_mode_rounded
                      : themeMode == ThemeMode.light
                      ? Icons.light_mode_rounded
                      : Icons.brightness_auto_rounded,
                  color: DesignTokens.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'profile.theme'.tr(),
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: isDark ? DesignTokens.textOnDark : DesignTokens.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text('profile.theme_desc'.tr(), style: TextStyle(fontSize: 13, color: DesignTokens.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 3-segment pill toggle: Light | System | Dark
              Container(
                decoration: BoxDecoration(
                  color: isDark ? DesignTokens.darkSurface : DesignTokens.surfaceVariant,
                  borderRadius: BorderRadius.circular(DesignTokens.radius20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ThemePill(
                      icon: Icons.light_mode_rounded,
                      label: 'profile.theme_light'.tr(),
                      selected: themeMode == ThemeMode.light,
                      isDark: isDark,
                      onTap: () => onThemeChange(ThemeMode.light),
                    ),
                    _ThemePill(
                      icon: Icons.brightness_auto_rounded,
                      label: 'profile.theme_system'.tr(),
                      selected: themeMode == ThemeMode.system,
                      isDark: isDark,
                      onTap: () => onThemeChange(ThemeMode.system),
                    ),
                    _ThemePill(
                      icon: Icons.dark_mode_rounded,
                      label: 'profile.theme_dark'.tr(),
                      selected: themeMode == ThemeMode.dark,
                      isDark: isDark,
                      onTap: () => onThemeChange(ThemeMode.dark),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  late final TextEditingController confirmController;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profileState = ref.watch(profileViewModelProvider);
    final viewModel = ref.read(profileViewModelProvider.notifier);

    ref.listen(profileViewModelProvider, (previous, next) {
      if (next.isDeleted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('auth.account_deleted'.tr()), backgroundColor: DesignTokens.success));
      } else if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.errorMessage!), backgroundColor: DesignTokens.error));
      }
    });

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radius20)),
      backgroundColor: isDark ? DesignTokens.darkSurface : Colors.white,
      title: Row(
        children: [
          Icon(Icons.warning_rounded, color: DesignTokens.error, size: 28),
          const SizedBox(width: 12),
          Text(
            'profile.delete_account'.tr(),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: isDark ? DesignTokens.textOnDark : DesignTokens.textPrimary),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'profile.delete_warning_short'.tr(),
              style: TextStyle(color: DesignTokens.error, fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Text('profile.type_delete'.tr(), style: TextStyle(color: DesignTokens.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              decoration: InputDecoration(
                hintText: 'profile.type_delete_hint'.tr(),
                prefixIcon: const Icon(Icons.lock_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(DesignTokens.radius12)),
              ),
              onChanged: (value) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('common.cancel'.tr(), style: TextStyle(color: DesignTokens.textSecondary)),
        ),
        ModernButton(
          onPressed: confirmController.text == 'profile.type_delete_keyword'.tr() && !profileState.isLoading
              ? () => viewModel.deleteAccount(confirmController.text.trim())
              : null,
          label: 'profile.delete_account'.tr(),
          isLoading: profileState.isLoading,
          backgroundColor: confirmController.text == 'profile.type_delete_keyword'.tr() ? DesignTokens.error : DesignTokens.textDisabled,
        ),
      ],
    );
  }

  @override
  void dispose() {
    confirmController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    confirmController = TextEditingController();
  }
}

/// Widget shown inside ProfileScreen when user is authenticated but email is not verified
class _EmailVerificationRequiredView extends ConsumerStatefulWidget {
  final User user;
  const _EmailVerificationRequiredView({required this.user});

  @override
  ConsumerState<_EmailVerificationRequiredView> createState() => _EmailVerificationRequiredViewState();
}

class _EmailVerificationRequiredViewState extends ConsumerState<_EmailVerificationRequiredView> {
  bool _isChecking = false;
  bool _isResending = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              FadeSlideIn(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [DesignTokens.warning.withValues(alpha: 0.15), DesignTokens.warning.withValues(alpha: 0.08)]),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.mark_email_unread_outlined, size: 56, color: DesignTokens.warning),
                ),
              ),
              const SizedBox(height: 24),
              FadeSlideIn(
                delay: const Duration(milliseconds: 50),
                child: Text(
                  'profile.verify_email_title'.tr(),
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: isDark ? DesignTokens.textOnDark : DesignTokens.textPrimary),
                ),
              ),
              const SizedBox(height: 8),
              FadeSlideIn(
                delay: const Duration(milliseconds: 75),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(color: DesignTokens.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    widget.user.email ?? '',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: DesignTokens.primary),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FadeSlideIn(
                delay: const Duration(milliseconds: 100),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? DesignTokens.darkSurfaceVariant.withValues(alpha: 0.5) : DesignTokens.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? DesignTokens.darkOutline : DesignTokens.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('profile.verify_email_desc'.tr(), style: TextStyle(fontSize: 14, color: DesignTokens.textSecondary, height: 1.5)),
                      const SizedBox(height: 16),
                      _buildStep('1', 'profile.verify_step_1'.tr()),
                      _buildStep('2', 'profile.verify_step_2'.tr()),
                      _buildStep('3', 'profile.verify_step_3'.tr()),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              FadeSlideIn(
                delay: const Duration(milliseconds: 150),
                child: ModernButton(
                  label: _isChecking ? 'profile.checking_button'.tr() : 'profile.verified_button'.tr(),
                  icon: Icons.check_circle_outline,
                  isLoading: _isChecking,
                  onPressed: _isChecking ? () {} : _checkVerification,
                ),
              ),
              const SizedBox(height: 12),
              FadeSlideIn(
                delay: const Duration(milliseconds: 175),
                child: ModernButton(
                  label: _isResending ? 'profile.sending_button'.tr() : 'profile.resend_verification_button'.tr(),
                  icon: Icons.send_outlined,
                  isPrimary: false,
                  isLoading: _isResending,
                  onPressed: _isResending ? () {} : _resendEmail,
                ),
              ),
              const SizedBox(height: 20),
              FadeSlideIn(
                delay: const Duration(milliseconds: 200),
                child: TextButton.icon(
                  onPressed: () async {
                    await ref.read(authRepositoryProvider).signOut();
                    if (context.mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
                    }
                  },
                  icon: Icon(Icons.logout, size: 16, color: DesignTokens.textSecondary),
                  label: Text(
                    'profile.sign_in_different'.tr(),
                    style: TextStyle(color: DesignTokens.textSecondary, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(gradient: DesignTokens.primaryGradient, shape: BoxShape.circle),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 14, color: isDark ? DesignTokens.outlineVariant : DesignTokens.textPrimary, height: 1.4)),
          ),
        ],
      ),
    );
  }

  Future<void> _checkVerification() async {
    setState(() => _isChecking = true);
    try {
      // LEG-H2: use firebaseAuthProvider instead of FirebaseAuth.instance directly
      final auth = ref.read(firebaseAuthProvider);
      final user = auth.currentUser;
      if (user != null) {
        await user.reload();
        final freshUser = auth.currentUser;
        if (freshUser != null && freshUser.emailVerified) {
          // Email is now verified! Create the Firestore document
          await ref.read(authRepositoryProvider).ensureUserDocumentExists();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('🎉 ${'profile.email_verified_snackbar'.tr()}'),
                backgroundColor: DesignTokens.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
            // userProfileProvider stream will auto-update with the new Firestore document
            // ProfileScreen will automatically rebuild and show the full profile
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('profile.not_verified_error'.tr()), backgroundColor: DesignTokens.warning, behavior: SnackBarBehavior.floating),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('errors.verification_error'.tr()), backgroundColor: DesignTokens.error, behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _resendEmail() async {
    setState(() => _isResending = true);
    try {
      await ref.read(authRepositoryProvider).sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('profile.verification_sent'.tr()), backgroundColor: DesignTokens.primary, behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('too-many-requests') ? 'Please wait before requesting another email.' : 'Failed to send email. Please try again later.',
            ),
            backgroundColor: DesignTokens.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }
}

/// Profile completion bar shown inside the profile header card.
/// 4 steps: name set · address added · notifications on · premium
class _ProfileCompletionBar extends StatelessWidget {
  final UserModel userModel;

  /// Authoritative premium flag from subscriptionStreamProvider — never
  /// use userModel.isPremium here as it can lag behind subscription updates.
  final bool isPremium;
  const _ProfileCompletionBar({required this.userModel, required this.isPremium});

  @override
  Widget build(BuildContext context) {
    final steps = [
      userModel.name.isNotEmpty, // Name set
      userModel.address != null, // Address added
      userModel.notifyNewProducts || userModel.notifyTrending, // Notifications
      isPremium, // Premium — from subscriptionStreamProvider (authoritative)
    ];
    final completed = steps.where((s) => s).length;
    final pct = completed / steps.length;

    if (pct >= 1.0) return const SizedBox.shrink(); // 100% — hide bar

    final pctInt = (pct * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'profile.completion'.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.4),
              ),
            ),
            Text(
              '$pctInt%',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 5,
            backgroundColor: Colors.white.withValues(alpha: 0.15),
            valueColor: const AlwaysStoppedAnimation<Color>(DesignTokens.accent),
          ),
        ),
      ],
    );
  }
}

/// Single pill segment for the theme toggle row.
class _ThemePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _ThemePill({required this.icon, required this.label, required this.selected, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: DesignTokens.durationFast,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(gradient: selected ? DesignTokens.primaryGradient : null, borderRadius: BorderRadius.circular(DesignTokens.radius20)),
        child: Icon(icon, size: 16, color: selected ? Colors.white : DesignTokens.textSecondary),
      ),
    );
  }
}
