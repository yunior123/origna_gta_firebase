import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/features/chat/chat_repository.dart';

@GenerateNiceMocks([MockSpec<FirebaseFunctions>(), MockSpec<HttpsCallable>(), MockSpec<HttpsCallableResult>()])
import 'chat_repository_test.mocks.dart';

void main() {
  late ChatRepository repository;
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseFunctions mockFunctions;
  late MockHttpsCallable mockCallable;
  late MockHttpsCallableResult mockResult;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockFunctions = MockFirebaseFunctions();
    mockCallable = MockHttpsCallable();
    mockResult = MockHttpsCallableResult();

    repository = ChatRepository(fakeFirestore, mockFunctions);

    when(mockFunctions.httpsCallable(any)).thenReturn(mockCallable);
    when(mockCallable.call(any)).thenAnswer((_) async => mockResult);
  });

  group('ChatRepository', () {
    test('getOrCreateChat calls correct cloud function', () async {
      when(mockResult.data).thenReturn({Fields.chatId: 'c123'});
      final result = await repository.getOrCreateChat('p1');
      expect(result, 'c123');
      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.getOrCreateChat)).called(1);
    });

    test('sendMessage calls correct cloud function', () async {
      await repository.sendMessage('c123', 'Hello');
      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.sendMessage)).called(1);
      verify(mockCallable.call({Fields.chatId: 'c123', Fields.messageText: 'Hello'})).called(1);
    });

    test('markRead calls correct cloud function', () async {
      await repository.markRead('c123');
      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.markMessagesRead)).called(1);
    });

    test('deleteMessage calls correct cloud function', () async {
      await repository.deleteMessage('c123', 'm456');
      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.deleteMessage)).called(1);
    });

    test('messagesStream returns stream of ChatMessage', () async {
      final convoRef = fakeFirestore.collection(Collections.chats).doc('c1');
      await convoRef.collection(Collections.chatMessages).add({
        Fields.senderId: 'u1',
        Fields.messageText: 'Msg 1',
        Fields.createdAt: Timestamp.now(),
        Fields.isRead: false,
      });

      final stream = repository.messagesStream('c1');
      final messages = await stream.first;
      expect(messages.length, 1);
      expect(messages.first.text, 'Msg 1');
    });

    test('userChatsStream returns stream of ChatThread', () async {
      await fakeFirestore.collection(Collections.chats).add({
        Fields.buyerId: 'u1',
        Fields.productId: 'p1',
        Fields.productTitle: 'Product',
        Fields.lastMessage: 'Hi',
        Fields.lastMessageAt: Timestamp.now(),
      });

      final stream = repository.userChatsStream('u1');
      final threads = await stream.first;
      expect(threads.length, 1);
      expect(threads.first.productTitle, 'Product');
    });
  });
}
