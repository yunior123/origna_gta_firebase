import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:origna_gta/features/chat/chat_provider.dart';
import 'package:origna_gta/features/chat/chat_repository.dart';

@GenerateNiceMocks([
  MockSpec<ChatRepository>(),
])
import 'chat_provider_test.mocks.dart';

void main() {
  late MockChatRepository mockRepo;
  late ProviderContainer container;

  setUp(() {
    mockRepo = MockChatRepository();
    container = ProviderContainer(
      overrides: [
        chatRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
  });

  group('ChatViewModel Tests', () {
    test('openChat sets chatId on success', () async {
      when(mockRepo.getOrCreateChat('p1')).thenAnswer((_) async => 'chat_123');
      
      final notifier = container.read(chatViewModelProvider('p1').notifier);
      await notifier.openChat();
      
      final state = container.read(chatViewModelProvider('p1'));
      expect(state.chatId, 'chat_123');
      expect(state.isLoading, isFalse);
    });

    test('sendMessage calls repository', () async {
      when(mockRepo.getOrCreateChat('p1')).thenAnswer((_) async => 'chat_123');
      final notifier = container.read(chatViewModelProvider('p1').notifier);
      await notifier.openChat();
      
      await notifier.sendMessage('Hello world');
      
      verify(mockRepo.sendMessage('chat_123', 'Hello world')).called(1);
    });

    test('sendMessage rejects short messages', () async {
      when(mockRepo.getOrCreateChat('p1')).thenAnswer((_) async => 'chat_123');
      final notifier = container.read(chatViewModelProvider('p1').notifier);
      await notifier.openChat();
      
      await notifier.sendMessage('Hi'); // Too short
      
      final state = container.read(chatViewModelProvider('p1'));
      expect(state.errorMessage, contains('short'));
      verifyNever(mockRepo.sendMessage(any, any));
    });
  });
}
