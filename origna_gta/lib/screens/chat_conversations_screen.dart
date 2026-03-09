// coverage:ignore-file
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/routes.dart';
import 'package:origna_gta/features/chat/chat_provider.dart';
import 'package:origna_gta/features/chat/chat_repository.dart';
import 'package:origna_gta/features/subscription/subscription_provider.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/widgets/animations.dart';
import 'package:origna_gta/widgets/custom_app_bar.dart';
import 'package:origna_gta/widgets/modern_button.dart';
import 'package:origna_gta/widgets/modern_loading_indicator.dart';
import 'package:origna_gta/widgets/premium_paywall_widget.dart';

/// Documentation for ChatConversationsScreen
class ChatConversationsScreen extends ConsumerWidget {
  const ChatConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subscriptionAsync = ref.watch(subscriptionStreamProvider);

    return Container(
      decoration: BoxDecoration(
        gradient: DesignTokens.backgroundGradient(isDark: isDark),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBarFactory.simple(
          title: 'chat.inbox_title'.tr(),
          subtitle: 'chat.inbox_subtitle'.tr(),
        ),
        body: subscriptionAsync.when(
          loading: () => const Center(child: ModernLoadingIndicator()),
          // CHAT-SEC-1: On subscription stream error, default to paywall.
          // Never grant chat access when premium status cannot be verified.
          error: (_, _) => Center(
            child: SingleChildScrollView(
              child: PremiumPaywallWidget(
                featureName: 'chat.inbox_title'.tr(),
              ),
            ),
          ),
          data: (sub) {
            final isPremium = sub?.isPremium ?? false;
            if (!isPremium) {
              return Center(
                child: SingleChildScrollView(
                  child: PremiumPaywallWidget(
                    featureName: 'chat.inbox_title'.tr(),
                  ),
                ),
              );
            }
            return _ChatInboxBody();
          },
        ),
      ),
    );
  }
}

class _ChatInboxBody extends ConsumerWidget {
  const _ChatInboxBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadsAsync = ref.watch(myAllChatsProvider);
    final uid = ref.watch(userIdProvider) ?? '';

    return threadsAsync.when(
      loading: () => const Center(child: ModernLoadingIndicator()),
      error: (error, _) => AnimatedEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'common.error'.tr(),
        subtitle: error.toString(),
        action: ModernButton(
          label: 'common.retry'.tr(),
          icon: Icons.refresh,
          isPrimary: false,
          onPressed: () => ref.invalidate(myAllChatsProvider),
        ),
      ),
      data: (threads) {
        if (threads.isEmpty) {
          return AnimatedEmptyState(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'chat.inbox_empty'.tr(),
            subtitle: 'chat.inbox_empty_desc'.tr(),
          );
        }

        return RefreshIndicator(
          color: DesignTokens.primary,
          onRefresh: () async => ref.invalidate(myAllChatsProvider),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: threads.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              indent: 76,
              endIndent: 16,
              color: DesignTokens.outlineVariant.withValues(alpha: 0.5),
            ),
            itemBuilder: (context, index) {
              final thread = threads[index];
              final isBuyer = thread.buyerId == uid;
              final unreadCount = isBuyer ? thread.buyerUnreadCount : thread.sellerUnreadCount;
              return FadeSlideIn(
                delay: Duration(milliseconds: 30 * index.clamp(0, 10)),
                child: _ChatThreadTile(
                  thread: thread,
                  unreadCount: unreadCount,
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRoutes.chat,
                    arguments: ChatArgs(
                      productId: thread.productId,
                      productTitle: thread.productTitle,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ChatThreadTile extends StatelessWidget {
  final ChatThread thread;
  final int unreadCount;
  final VoidCallback onTap;

  const _ChatThreadTile({
    required this.thread,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasUnread = unreadCount > 0;

    return Semantics(
      button: true,
      label: 'chat-thread-${thread.chatId}',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _ProductAvatar(
                imageUrl: thread.productImageUrl,
                productTitle: thread.productTitle,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            thread.productTitle,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                              color: isDark ? DesignTokens.textOnDark : DesignTokens.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (thread.lastMessageAt != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            _formatTime(thread.lastMessageAt!),
                            style: TextStyle(
                              fontSize: 12,
                              color: hasUnread ? DesignTokens.primary : DesignTokens.textSecondary,
                              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            thread.lastMessage ?? 'chat.tap_to_chat'.tr(),
                            style: TextStyle(
                              fontSize: 13,
                              color: hasUnread
                                  ? (isDark ? DesignTokens.textOnDark : DesignTokens.textPrimary)
                                  : DesignTokens.textSecondary,
                              fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasUnread) ...[
                          const SizedBox(width: 8),
                          Container(
                            constraints: const BoxConstraints(minWidth: 20),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: DesignTokens.primaryGradient,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: DesignTokens.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat('MMM d').format(time);
  }
}

class _ProductAvatar extends StatelessWidget {
  final String? imageUrl;
  final String productTitle;

  const _ProductAvatar({this.imageUrl, required this.productTitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            DesignTokens.primary.withValues(alpha: 0.15),
            DesignTokens.secondary.withValues(alpha: 0.15),
          ],
        ),
        border: Border.all(color: DesignTokens.primary.withValues(alpha: 0.2)),
      ),
      child: ClipOval(
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => _fallbackIcon(),
                errorWidget: (context, url, error) => _fallbackIcon(),
              )
            : _fallbackIcon(),
      ),
    );
  }

  Widget _fallbackIcon() {
    return ShaderMask(
      shaderCallback: (bounds) => DesignTokens.primaryGradient.createShader(bounds),
      child: const Icon(Icons.inventory_2_outlined, size: 22, color: Colors.white),
    );
  }
}

// ─── Flutter Previews ────────────────────────────────────────────────────────

