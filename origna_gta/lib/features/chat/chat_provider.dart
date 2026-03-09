// coverage:ignore-file
import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/providers.dart';

import 'package:origna_gta/core/schema/schema_constants.dart';

import 'chat_repository.dart';

// ─── Repository ────────────────────────────────────────────────────────────

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseFunctionsProvider),
  );
});

// ─── Messages stream ───────────────────────────────────────────────────────

final chatMessagesProvider =
    StreamProvider.autoDispose.family<List<ChatMessage>, String>((ref, chatId) {
  return ref.watch(chatRepositoryProvider).messagesStream(chatId);
});

// ─── User's buyer chats stream ─────────────────────────────────────────────

final myBuyerChatsProvider = StreamProvider.autoDispose<List<ChatThread>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(chatRepositoryProvider).userChatsStream(uid);
});

// ─── User's seller chats stream ────────────────────────────────────────────

final mySellerChatsProvider = StreamProvider.autoDispose<List<ChatThread>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(chatRepositoryProvider).sellerChatsStream(uid);
});

// ─── Unified chat inbox (buyer + seller merged, deduped, sorted) ───────────

/// F-71: Single inbox for users who are both buyer and seller.
/// Use this provider for the main chat inbox screen.
final myAllChatsProvider = StreamProvider.autoDispose<List<ChatThread>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(chatRepositoryProvider).allChatsStream(uid);
});

// ─── Chat ViewModel ────────────────────────────────────────────────────────

/// Documentation for ChatState
class ChatState {
  final bool isLoading;
  final String? errorMessage;
  final String? chatId;
  /// True when the current user is the seller of this product — they should use their seller inbox.
  final bool isOwnProduct;

  const ChatState({this.isLoading = false, this.errorMessage, this.chatId, this.isOwnProduct = false});

  ChatState copyWith({bool? isLoading, String? errorMessage, String? chatId, bool? isOwnProduct, bool clearError = false}) {
    return ChatState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      chatId: chatId ?? this.chatId,
      isOwnProduct: isOwnProduct ?? this.isOwnProduct,
    );
  }
}

final chatViewModelProvider =
    StateNotifierProvider.autoDispose.family<ChatViewModel, ChatState, String>((ref, productId) {
  return ChatViewModel(ref, productId);
});

/// Documentation for ChatViewModel
class ChatViewModel extends StateNotifier<ChatState> {
  final Ref _ref;
  final String _productId;
  Timer? _markReadTimer;

  ChatViewModel(this._ref, this._productId) : super(const ChatState());

  @override
  void dispose() {
    _markReadTimer?.cancel();
    super.dispose();
  }

  Future<void> openChat() async {
    if (state.chatId != null || state.isLoading) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final chatId = await _ref.read(chatRepositoryProvider).getOrCreateChat(_productId);
      state = state.copyWith(isLoading: false, chatId: chatId);
    } catch (e) {
      // Detect self-chat (seller viewing own product) and surface a clear UX state
      final isSelfChat = e is FirebaseFunctionsException && e.code == 'permission-denied' &&
          (e.message?.contains('yourself') ?? false);
      state = state.copyWith(
        isLoading: false,
        isOwnProduct: isSelfChat,
        errorMessage: isSelfChat ? null : _parseError(e),
      );
    }
  }

  Future<void> sendMessage(String text) async {
    final chatId = state.chatId;
    final trimmed = text.trim();
    if (chatId == null || trimmed.isEmpty) return;
    if (state.isLoading) return; // in-flight guard

    // Mirror backend ValidationLimits (BusinessRules) to avoid unnecessary round-trips.
    // These constants are the single source of truth — also used by the TextField maxLength.
    if (trimmed.length < BusinessRules.minMessageLength) {
      state = state.copyWith(errorMessage: 'Message is too short (minimum ${BusinessRules.minMessageLength} characters).');
      return;
    }
    if (trimmed.length > BusinessRules.maxMessageLength) {
      state = state.copyWith(errorMessage: 'Message exceeds the maximum length of ${BusinessRules.maxMessageLength} characters.');
      return;
    }

    state = state.copyWith(isLoading: true);
    try {
      await _ref.read(chatRepositoryProvider).sendMessage(chatId, trimmed);
    } catch (e) {
      state = state.copyWith(errorMessage: _parseError(e));
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Debounced markRead — coalesces rapid message batches into a single Firestore write.
  void markReadDebounced() {
    _markReadTimer?.cancel();
    _markReadTimer = Timer(const Duration(milliseconds: 500), () => markRead());
  }

  Future<void> markRead() async {
    final chatId = state.chatId;
    if (chatId == null) return;
    await _ref.read(chatRepositoryProvider).markRead(chatId);
  }

  String _parseError(Object e) {
    if (e is FirebaseFunctionsException) {
      switch (e.code) {
        case 'permission-denied':
          if (e.message?.toLowerCase().contains('premium') == true) {
            return 'A Premium membership is required to chat with sellers.';
          }
          return e.message ?? 'Access denied.';
        case 'resource-exhausted':
          return 'Too many messages. Please slow down.';
        case 'failed-precondition':
          return e.message ?? 'Action not allowed.';
        default:
          return e.message ?? e.toString();
      }
    }
    final str = e.toString();
    if (str.contains('] ')) return str.split('] ').last;
    return str;
  }
}
