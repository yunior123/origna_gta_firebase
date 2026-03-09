// coverage:ignore-file
import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/utils/responsive_layout.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/widgets/custom_app_bar.dart';
import 'package:origna_gta/widgets/modern_loading_indicator.dart';
import 'package:origna_gta/widgets/premium_paywall_widget.dart';

import '../core/schema/schema_constants.dart';
import '../features/chat/chat_provider.dart';
import '../features/chat/chat_repository.dart';

/// Documentation for ChatScreenArgs
class ChatScreenArgs {
  final String productId;
  final String productTitle;

  const ChatScreenArgs({required this.productId, required this.productTitle});
}

/// Documentation for ChatScreen
class ChatScreen extends ConsumerStatefulWidget {
  final String productId;
  final String productTitle;

  const ChatScreen({super.key, required this.productId, required this.productTitle});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _inputFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(chatViewModelProvider(widget.productId).notifier).openChat();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!mounted || !_scrollController.hasClients) return;
    try {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } catch (_) {
      // Position may not be ready during layout — safe to ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final vmState = ref.watch(chatViewModelProvider(widget.productId));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final myUid = ref.watch(userIdProvider) ?? '';

    return Scaffold(
      appBar: AppBarFactory.simple(title: widget.productTitle),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: ResponsiveBreakpoints.contentMaxWidth),
          child: Column(
        children: [
          if (vmState.isOwnProduct)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.storefront, size: 48, color: DesignTokens.textSecondary),
                      const SizedBox(height: 16),
                      Text(
                        'chat.own_product_title'.tr(),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: isDark ? Colors.white : DesignTokens.textPrimary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'chat.own_product_body'.tr(),
                        style: TextStyle(color: DesignTokens.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (vmState.errorMessage != null && vmState.errorMessage!.contains('Premium'))
            Expanded(
              child: Center(
                child: PremiumPaywallWidget(featureName: 'subscription.chat_with_sellers'.tr()),
              ),
            )
          else if (vmState.errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(vmState.errorMessage!, style: TextStyle(color: DesignTokens.error)),
            )
          else if (vmState.isLoading && vmState.chatId == null)
            const Expanded(child: Center(child: ModernLoadingIndicator()))
          else if (vmState.chatId != null) ...[
            Expanded(
              child: _MessagesList(
                chatId: vmState.chatId!,
                productId: widget.productId,
                myUid: myUid,
                isDark: isDark,
                scrollController: _scrollController,
                onNewMessages: _scrollToBottom,
                onFocusInput: () => _inputFocusNode.requestFocus(),
              ),
            ),
            _MessageInput(
              controller: _textController,
              focusNode: _inputFocusNode,
              isDark: isDark,
              isSending: vmState.isLoading && vmState.chatId != null,
              onSend: () async {
                final text = _textController.text.trim();
                if (text.isEmpty) return;
                _textController.clear();
                try {
                  await ref.read(chatViewModelProvider(widget.productId).notifier).sendMessage(text);
                  WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                } catch (_) {
                  // Only restore text if input is empty — don't overwrite what the user typed next
                  if (_textController.text.trim().isEmpty) {
                    _textController.text = text;
                  }
                }
              },
            ),
          ],
        ],
          ),
        ),
      ),
    );
  }
}

class _MessagesList extends ConsumerWidget {
  final String chatId;
  final String productId;
  final String myUid;
  final bool isDark;
  final ScrollController scrollController;
  final VoidCallback onNewMessages;
  final VoidCallback onFocusInput;

  const _MessagesList({
    required this.chatId,
    required this.productId,
    required this.myUid,
    required this.isDark,
    required this.scrollController,
    required this.onNewMessages,
    required this.onFocusInput,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(chatMessagesProvider(chatId));

    ref.listen(chatMessagesProvider(chatId), (prev, next) {
      if (next.hasValue) {
        final prevCount = prev?.value?.length ?? 0;
        final nextCount = next.value?.length ?? 0;
        // Only scroll + markRead when new messages arrive (not on our own sends)
        if (nextCount > prevCount) {
          WidgetsBinding.instance.addPostFrameCallback((_) => onNewMessages());
          ref.read(chatViewModelProvider(productId).notifier).markReadDebounced();
        }
      }
    });

    return messagesAsync.when(
      loading: () => const Center(child: ModernLoadingIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (messages) {
        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'chat.empty_state_no_messages'.tr(),
                  style: TextStyle(color: DesignTokens.textSecondary),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: onFocusInput,
                  child: Text('chat.send_message_cta'.tr()),
                ),
              ],
            ),
          );
        }
        // CHAT-H2: provide delete callback to bubbles via InheritedWidget
        return _ChatDeleteScope(
          onDelete: (messageId) async {
            try {
              await ref.read(chatRepositoryProvider).deleteMessage(chatId, messageId);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('chat.delete_failed'.tr()), backgroundColor: DesignTokens.error),
                );
              }
            }
          },
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: messages.length,
            itemBuilder: (ctx, i) => _AnimatedMessageBubble(
              key: ValueKey(messages[i].id),
              index: i,
              message: messages[i],
              isMe: messages[i].senderId == myUid,
              isDark: isDark,
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedMessageBubble extends StatefulWidget {
  final int index;
  final ChatMessage message;
  final bool isMe;
  final bool isDark;

  const _AnimatedMessageBubble({
    super.key,
    required this.index,
    required this.message,
    required this.isMe,
    required this.isDark,
  });

  @override
  State<_AnimatedMessageBubble> createState() => _AnimatedMessageBubbleState();
}

class _AnimatedMessageBubbleState extends State<_AnimatedMessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  Timer? _animationTimer;

  @override
  void initState() {
    super.initState();
    // Cap stagger at 12 items (max 240 ms delay) to keep it snappy for long histories.
    final delayMs = (widget.index.clamp(0, 12) * 20).toInt();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _animationTimer = Timer(Duration(milliseconds: delayMs), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: _MessageBubble(
          message: widget.message,
          isMe: widget.isMe,
          isDark: widget.isDark,
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool isDark;

  const _MessageBubble({required this.message, required this.isMe, required this.isDark});

  @override
  Widget build(BuildContext context) {
    // CHAT-H2: show placeholder for soft-deleted messages
    if (message.deleted) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            'chat.message_deleted'.tr(),
            style: TextStyle(
              color: isDark ? DesignTokens.textDisabled : DesignTokens.textTertiary,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    final semanticLabel = isMe
        ? 'chat-message-me: ${message.text}'
        : 'chat-message-other: ${message.text}';
    return Semantics(
      label: semanticLabel,
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: () {
            // CHAT-H2: sender can delete their own messages
            if (isMe) {
              showModalBottomSheet<void>(
                context: context,
                builder: (_) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.copy_outlined),
                        title: Text('chat.copy_message'.tr()),
                        onTap: () {
                          Navigator.pop(context);
                          Clipboard.setData(ClipboardData(text: message.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('chat.message_copied'.tr()), duration: const Duration(seconds: 1)),
                          );
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.delete_outline, color: DesignTokens.error),
                        title: Text('chat.delete_message'.tr(), style: TextStyle(color: DesignTokens.error)),
                        onTap: () {
                          Navigator.pop(context);
                          // Delegate deletion to parent via callback stored in context
                          _ChatDeleteScope.of(context)?.onDelete(message.id);
                        },
                      ),
                    ],
                  ),
                ),
              );
            } else {
              Clipboard.setData(ClipboardData(text: message.text));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('chat.message_copied'.tr()), duration: const Duration(seconds: 1)),
              );
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
            decoration: BoxDecoration(
              color: isMe
                  ? DesignTokens.primary
                  : (isDark ? DesignTokens.darkSurface : DesignTokens.surfaceVariant),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.text,
                  style: TextStyle(
                    color: isMe ? Colors.white : (isDark ? DesignTokens.textOnDark : DesignTokens.textPrimary),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat.jm().format(message.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: isMe ? Colors.white.withValues(alpha: 0.65) : DesignTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// InheritedWidget scope that lets _MessageBubble call the delete handler
/// without needing direct access to the repository or chat ID.
class _ChatDeleteScope extends InheritedWidget {
  final void Function(String messageId) onDelete;

  const _ChatDeleteScope({required this.onDelete, required super.child});

  static _ChatDeleteScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ChatDeleteScope>();

  @override
  bool updateShouldNotify(_ChatDeleteScope old) => onDelete != old.onDelete;
}

class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool isDark;
  final bool isSending;
  final VoidCallback onSend;

  const _MessageInput({required this.controller, required this.isDark, required this.onSend, this.focusNode, this.isSending = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: isDark ? DesignTokens.darkSurface : Colors.white,
        border: Border(top: BorderSide(color: isDark ? DesignTokens.darkOutline : DesignTokens.outline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              minLines: 1,
              maxLines: 4,
              maxLength: BusinessRules.maxMessageLength,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              // Hide the default counter label — VM error message handles user feedback.
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'chat.type_a_message'.tr(),
                hintStyle: TextStyle(color: DesignTokens.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDark ? DesignTokens.darkSurfaceVariant : DesignTokens.surfaceVariant,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: isSending ? null : (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'btn-send-message',
            child: IconButton.filled(
              key: const Key('chat_send_button'),
              icon: const Icon(Icons.send_rounded),
              onPressed: isSending ? null : onSend,
              tooltip: 'Send',
              style: IconButton.styleFrom(
                backgroundColor: DesignTokens.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Flutter Previews ────────────────────────────────────────────────────────

