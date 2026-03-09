// coverage:ignore-file
// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/features/admin/admin_actions_viewmodel.dart';
import 'package:origna_gta/features/admin/admin_providers.dart';
import 'package:origna_gta/utils/constants.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/utils/utils.dart';
import 'package:origna_gta/widgets/animations.dart';
import 'package:origna_gta/widgets/modern_loading_indicator.dart';

/// Documentation for AdminUsersTab
class AdminUsersTab extends ConsumerStatefulWidget {
  const AdminUsersTab({super.key});

  @override
  ConsumerState<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends ConsumerState<AdminUsersTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _roleFilter = 'all';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        // Modern Search and Filter Bar
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? DesignTokens.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(DesignTokens.radius16),
            boxShadow: DesignTokens.shadowSm,
          ),
          child: Column(
            children: [
              TextField(
                key: const Key('admin_users_search_field'),
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'admin.users.search_hint'.tr(),
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
              Row(
                children: [
                  _filterChip('admin.users.filter_all'.tr(), 'all'),
                  const SizedBox(width: 6),
                  _filterChip(
                    'admin.users.filter_sellers'.tr(),
                    UserRoles.seller,
                  ),
                  const SizedBox(width: 6),
                  _filterChip(
                    'admin.users.filter_admins'.tr(),
                    UserRoles.admin,
                  ),
                  const SizedBox(width: 6),
                  _filterChip(
                    'admin.users.filter_buyers'.tr(),
                    UserRoles.buyer,
                  ),
                ],
              ),
            ],
          ),
        ),

        // Users List
        Expanded(
          child: ref
              .watch(adminUsersProvider)
              .when(
                loading: () => const ModernLoadingIndicator.fullScreen(),
                error: (error, stack) => Center(
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
                    ],
                  ),
                ),
                data: (usersRaw) {
                  if (usersRaw.isEmpty) {
                    return AnimatedEmptyState(
                      icon: Icons.people_outline,
                      title: 'admin.users.no_users_found'.tr(),
                    );
                  }

                  final users = usersRaw.where((data) {
                    final name = data.name.toLowerCase();
                    final email = data.email.toLowerCase();
                    final roles = data.roles;

                    final matchesSearch =
                        _searchQuery.isEmpty ||
                        name.contains(_searchQuery) ||
                        email.contains(_searchQuery);
                    final matchesRole = _roleFilter == 'all'
                        ? true
                        : _roleFilter == 'buyer'
                        ? !roles.contains(UserRoles.seller) &&
                              !roles.contains(UserRoles.admin)
                        : roles.contains(_roleFilter);

                    return matchesSearch && matchesRole;
                  }).toList();

                  if (users.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.filter_alt_off_rounded,
                            size: 40,
                            color: DesignTokens.outlineVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'admin.users.no_users_match'.tr(),
                            style: TextStyle(color: DesignTokens.textSecondary),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final data = users[index];
                      return FadeSlideIn(
                        delay: Duration(milliseconds: 30 * index.clamp(0, 10)),
                        child: _UserCard(user: data),
                      );
                    },
                  );
                },
              ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _roleFilter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _roleFilter = value),
        child: AnimatedContainer(
          duration: DesignTokens.durationFast,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? DesignTokens.primary
                : DesignTokens.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
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
      ),
    );
  }
}

class _UserCard extends ConsumerWidget {
  final UserModel user;

  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = user.name.isNotEmpty
        ? user.name
        : 'admin.users.unknown_user'.tr();
    final email = user.email;
    final roles = user.roles;
    final isSuspended = user.suspended;
    final createdAt = user.createdAt;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radius12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: isSuspended
                    ? LinearGradient(
                        colors: [
                          DesignTokens.error,
                          DesignTokens.error.withValues(alpha: 0.7),
                        ],
                      )
                    : DesignTokens.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
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
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      ...roles.map(
                        (role) => Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _roleColor(role).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              role,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _roleColor(role),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (isSuspended) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.block_rounded,
                          size: 14,
                          color: DesignTokens.error,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 12,
                      color: DesignTokens.textSecondary,
                    ),
                  ),
                  Text(
                    'admin.users.joined_date'.tr(
                      namedArgs: {'date': _formatDate(createdAt)},
                    ),
                    style: TextStyle(
                      fontSize: 11,
                      color: DesignTokens.textDisabled,
                    ),
                  ),
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
                if (!roles.contains(UserRoles.seller))
                  _menuItem(
                    'make_seller',
                    Icons.store_rounded,
                    'admin.users.make_seller'.tr(),
                    DesignTokens.primary,
                  ),
                if (roles.contains(UserRoles.seller) &&
                    !roles.contains(UserRoles.admin))
                  _menuItem(
                    'remove_seller',
                    Icons.store_rounded,
                    'admin.users.remove_seller'.tr(),
                    DesignTokens.warning,
                  ),
                if (!roles.contains(UserRoles.admin))
                  _menuItem(
                    'make_admin',
                    Icons.admin_panel_settings_rounded,
                    'admin.users.make_admin'.tr(),
                    DesignTokens.secondary,
                  ),
                if (!isSuspended)
                  _menuItem(
                    'suspend',
                    Icons.block_rounded,
                    'admin.users.suspend_user'.tr(),
                    DesignTokens.error,
                  ),
                if (isSuspended)
                  _menuItem(
                    'unsuspend',
                    Icons.check_circle_rounded,
                    'admin.users.unsuspend_user'.tr(),
                    DesignTokens.success,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  void _handleAction(BuildContext context, WidgetRef ref, String action) async {
    final messenger = ScaffoldMessenger.of(context);
    final viewModel = ref.read(adminActionsViewModelProvider.notifier);
    bool success = false;

    // Guard: prevent admin from suspending themselves
    final currentUser = ref.read(currentUserProvider);
    if (action == 'suspend' && user.uid == currentUser?.uid) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('admin.users.cannot_suspend_self'.tr()),
          backgroundColor: DesignTokens.error,
        ),
      );
      return;
    }

    switch (action) {
      case 'make_seller':
        success = await viewModel.updateUserRoles(
          user.uid,
          add: [UserRoles.seller],
        );
        break;
      case 'remove_seller':
        final confirmedRemove = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radius16),
            ),
            title: Row(
              children: [
                Icon(Icons.store_rounded, color: DesignTokens.warning),
                const SizedBox(width: 10),
                Text('admin.users.confirm_remove_seller_title'.tr()),
              ],
            ),
            content: Text(
              'admin.users.confirm_remove_seller_body'.tr(
                namedArgs: {'name': user.name.isNotEmpty ? user.name : user.email},
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('common.cancel'.tr()),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: DesignTokens.warning,
                ),
                child: Text('admin.users.remove_seller'.tr()),
              ),
            ],
          ),
        );
        if (confirmedRemove != true) return;
        success = await viewModel.updateUserRoles(
          user.uid,
          remove: [UserRoles.seller],
        );
        break;
      case 'make_admin':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radius16),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.admin_panel_settings_rounded,
                  color: DesignTokens.secondary,
                ),
                const SizedBox(width: 10),
                Text('admin.users.make_admin'.tr()),
              ],
            ),
            content: Text(
              'admin.users.make_admin_confirm'.tr(args: [user.email]),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('common.cancel'.tr()),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: DesignTokens.secondary,
                ),
                child: Text('admin.users.confirm_grant_admin'.tr()),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        success = await viewModel.updateUserRoles(
          user.uid,
          add: [UserRoles.admin],
        );
        break;
      case 'suspend':
        final confirmedSuspend = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radius16),
            ),
            title: Row(
              children: [
                Icon(Icons.block_rounded, color: DesignTokens.error),
                const SizedBox(width: 10),
                Text('admin.users.confirm_suspend_title'.tr()),
              ],
            ),
            content: Text(
              'admin.users.confirm_suspend_body'.tr(
                namedArgs: {'name': user.name.isNotEmpty ? user.name : user.email},
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('common.cancel'.tr()),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: DesignTokens.error,
                ),
                child: Text('admin.users.suspend_user'.tr()),
              ),
            ],
          ),
        );
        if (confirmedSuspend != true) return;
        success = await viewModel.setUserSuspended(user.uid, true);
        break;
      case 'unsuspend':
        success = await viewModel.setUserSuspended(user.uid, false);
        break;
    }

    if (!context.mounted) return;
    if (success) {
      switch (action) {
        case 'make_seller':
          messenger.showSnackBar(
            SnackBar(
              content: Text('admin.users.user_is_seller'.tr()),
              backgroundColor: DesignTokens.success,
            ),
          );
          break;
        case 'remove_seller':
          messenger.showSnackBar(
            SnackBar(
              content: Text('admin.users.seller_role_removed'.tr()),
              backgroundColor: DesignTokens.warning,
            ),
          );
          break;
        case 'make_admin':
          messenger.showSnackBar(
            SnackBar(
              content: Text('admin.users.user_is_admin'.tr()),
              backgroundColor: DesignTokens.success,
            ),
          );
          break;
        case 'suspend':
          messenger.showSnackBar(
            SnackBar(
              content: Text('admin.users.user_suspended'.tr()),
              backgroundColor: DesignTokens.warning,
            ),
          );
          break;
        case 'unsuspend':
          messenger.showSnackBar(
            SnackBar(
              content: Text('admin.users.user_unsuspended'.tr()),
              backgroundColor: DesignTokens.success,
            ),
          );
          break;
      }
    } else {
      final error =
          ref.read(adminActionsViewModelProvider).errorMessage ??
          'admin.users.action_failed'.tr();
      messenger.showSnackBar(
        SnackBar(content: Text(error), backgroundColor: DesignTokens.error),
      );
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

  Color _roleColor(String role) {
    if (role == UserRoles.admin) return DesignTokens.secondary;
    if (role == UserRoles.seller) return DesignTokens.info;
    return DesignTokens.textSecondary;
  }
}
