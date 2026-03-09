// coverage:ignore-file
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/utils/utils.dart';

/// Documentation for ChatMessage
class ChatMessage {
  final String id;
  final String senderId;
  /// Denormalized sender display name — written server-side at send time (chat.py F-70).
  /// Avoids an extra users/{uid} fetch to show the sender's name in the chat UI.
  final String senderDisplayName;
  final String text;
  final DateTime createdAt;
  final bool isRead;
  // CHAT-H2: soft-delete flag — set by delete_message callable
  final bool deleted;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderDisplayName,
    required this.text,
    required this.createdAt,
    required this.isRead,
    this.deleted = false,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final ts = data[Fields.createdAt];
    return ChatMessage(
      id: doc.id,
      senderId: data[Fields.senderId] as String? ?? '',
      senderDisplayName: data[Fields.senderDisplayName] as String? ?? '',
      text: data[Fields.messageText] as String? ?? '',
      createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
      isRead: data[Fields.isRead] as bool? ?? false,
      deleted: data[Fields.deleted] as bool? ?? false,
    );
  }
}

/// Documentation for ChatThread
class ChatThread {
  final String chatId;
  final String productId;
  final String productTitle;
  final String? productImageUrl;
  final String buyerId;
  final String sellerId;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int buyerUnreadCount;
  final int sellerUnreadCount;

  const ChatThread({
    required this.chatId,
    required this.productId,
    required this.productTitle,
    this.productImageUrl,
    required this.buyerId,
    required this.sellerId,
    this.lastMessage,
    this.lastMessageAt,
    this.buyerUnreadCount = 0,
    this.sellerUnreadCount = 0,
  });

  factory ChatThread.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final ts = data[Fields.lastMessageAt];
    return ChatThread(
      chatId: doc.id,
      productId: data[Fields.productId] as String? ?? '',
      productTitle: data[Fields.productTitle] as String? ?? '',
      productImageUrl: data[Fields.productImageUrl] as String?,
      buyerId: data[Fields.buyerId] as String? ?? '',
      sellerId: data[Fields.sellerId] as String? ?? '',
      lastMessage: data[Fields.lastMessage] as String?,
      lastMessageAt: ts is Timestamp ? ts.toDate() : null,
      buyerUnreadCount: (data[Fields.buyerUnreadCount] as int?) ?? 0,
      sellerUnreadCount: (data[Fields.sellerUnreadCount] as int?) ?? 0,
    );
  }
}

/// Documentation for ChatRepository
class ChatRepository {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  const ChatRepository(this._firestore, this._functions);

  /// Get or create a chat thread. Returns chatId.
  Future<String> getOrCreateChat(String productId) async {
    final result = await _functions
        .httpsCallable(CloudFunctionEndpoints.getOrCreateChat)
        .call({Fields.productId: productId});
    return result.data[Fields.chatId] as String;
  }

  /// Stream messages for a given chat thread (real-time).
  Stream<List<ChatMessage>> messagesStream(String chatId) {
    return _firestore
        .collection(Collections.chats)
        .doc(chatId)
        .collection(Collections.chatMessages)
        .orderBy(Fields.createdAt, descending: false)
        .limitToLast(100)
        .snapshots()
        .map((snap) => snap.docs.map(ChatMessage.fromFirestore).toList())
        .handleError((Object e, StackTrace st) {
          AppError.log(e, stackTrace: st, context: 'chat.messagesStream');
          if (e is! FirebaseException) throw e;
        });
  }

  /// Stream all chat threads for the current user (buyer or seller).
  Stream<List<ChatThread>> userChatsStream(String userId) {
    // Queries threads where user is the buyer; seller threads are via sellerChatsStream.
    // FIX 2026-03-03: limit(50) prevents unbounded listener scan at scale.
    return _firestore
        .collection(Collections.chats)
        .where(Fields.buyerId, isEqualTo: userId)
        .orderBy(Fields.lastMessageAt, descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map(ChatThread.fromFirestore).toList())
        .handleError((Object e, StackTrace st) {
          AppError.log(e, stackTrace: st, context: 'chat.userChatsStream');
          if (e is! FirebaseException) throw e;
        });
  }

  /// Stream chat threads where user is seller.
  Stream<List<ChatThread>> sellerChatsStream(String sellerId) {
    // FIX 2026-03-03: limit(50) prevents unbounded listener scan at scale.
    return _firestore
        .collection(Collections.chats)
        .where(Fields.sellerId, isEqualTo: sellerId)
        .orderBy(Fields.lastMessageAt, descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map(ChatThread.fromFirestore).toList())
        .handleError((Object e, StackTrace st) {
          AppError.log(e, stackTrace: st, context: 'chat.sellerChatsStream');
          if (e is! FirebaseException) throw e;
        });
  }

  /// F-71: Unified inbox that merges buyer and seller threads, sorted by lastMessageAt desc.
  /// A user who is both buyer and seller (e.g. a seller's own test orders) sees all
  /// conversations in one place without duplicate entries.
  Stream<List<ChatThread>> allChatsStream(String userId) {
    final controller = StreamController<List<ChatThread>>();
    List<ChatThread> buyerThreads = [];
    List<ChatThread> sellerThreads = [];

    void emit() {
      final mergedMap = <String, ChatThread>{
        for (final t in buyerThreads) t.chatId: t,
        for (final t in sellerThreads) t.chatId: t,
      };
      final merged = mergedMap.values.toList()
        ..sort((a, b) {
          final at = a.lastMessageAt;
          final bt = b.lastMessageAt;
          if (at == null && bt == null) return 0;
          if (at == null) return 1;
          if (bt == null) return -1;
          return bt.compareTo(at);
        });
      controller.add(merged);
    }

    final sub1 = userChatsStream(userId).listen(
      (threads) { buyerThreads = threads; emit(); },
      onError: controller.addError,
    );
    final sub2 = sellerChatsStream(userId).listen(
      (threads) { sellerThreads = threads; emit(); },
      onError: controller.addError,
    );

    controller.onCancel = () {
      sub1.cancel();
      sub2.cancel();
    };

    return controller.stream;
  }

  /// Send a message through the Cloud Function (sanitizes text server-side).
  Future<void> sendMessage(String chatId, String text) async {
    await _functions
        .httpsCallable(CloudFunctionEndpoints.sendMessage)
        .call({
      Fields.chatId: chatId,
      Fields.messageText: text.trim(),
    });
  }

  /// Soft-delete a message (sender or admin). Sets deleted=true, clears text/images.
  Future<void> deleteMessage(String chatId, String messageId) async {
    await _functions
        .httpsCallable(CloudFunctionEndpoints.deleteMessage)
        .call({
      Fields.chatId: chatId,
      Fields.messageId: messageId,
    });
  }

  /// Mark all unread messages in a chat as read.
  Future<void> markRead(String chatId) async {
    await _functions
        .httpsCallable(CloudFunctionEndpoints.markMessagesRead)
        .call<void>({Fields.chatId: chatId});
  }
}
