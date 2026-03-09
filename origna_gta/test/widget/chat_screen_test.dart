import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:origna_gta/screens/chat_screen.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/features/chat/chat_provider.dart';
import 'package:origna_gta/features/chat/chat_repository.dart';
import '../mock_asset_loader.dart';
import '../test_utils.dart';

@GenerateNiceMocks([
  MockSpec<ChatRepository>(),
])
import 'chat_screen_test.mocks.dart';

void main() {
  late MockChatRepository mockRepo;

  setUp(() {
    mockRepo = MockChatRepository();
    initTestMocks();
  });

  final testMessage = ChatMessage(
    id: 'msg_123',
    senderId: 'other_user',
    senderDisplayName: 'Seller',
    text: 'Hello from seller',
    createdAt: DateTime.now(),
    isRead: true,
  );

  final myMessage = ChatMessage(
    id: 'msg_456',
    senderId: 'my_uid',
    senderDisplayName: 'Me',
    text: 'Hello from me',
    createdAt: DateTime.now(),
    isRead: true,
  );

  Widget createTestApp({
    required Widget child,
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: overrides,
      child: EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('fr')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        assetLoader: MockAssetLoader(),
        useOnlyLangCode: true,
        saveLocale: false,
        child: Builder(
          builder: (context) {
            return MaterialApp(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: child,
            );
          },
        ),
      ),
    );
  }

  group('ChatScreen Widget Tests', () {
    testWidgets('renders basic screen structure', (tester) async {
      when(mockRepo.getOrCreateChat(any)).thenAnswer((_) async => 'chat_123');
      when(mockRepo.messagesStream(any)).thenAnswer((_) => Stream.value([]));

      await tester.pumpWidget(createTestApp(
        overrides: [
          userIdProvider.overrideWithValue('my_uid'),
          chatRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const ChatScreen(productId: 'prod_123', productTitle: 'Test Product'),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Test Product'), findsOneWidget);
    });

    testWidgets('renders own product message', (tester) async {
      when(mockRepo.getOrCreateChat(any)).thenThrow(
        FirebaseFunctionsException(
          code: 'permission-denied',
          message: 'You cannot chat with yourself',
        ),
      );

      await tester.pumpWidget(createTestApp(
        overrides: [
          userIdProvider.overrideWithValue('my_uid'),
          chatRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const ChatScreen(productId: 'prod_123', productTitle: 'Test Product'),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('chat.own_product_title'.tr()), findsOneWidget);
    });

    testWidgets('renders list of messages', (tester) async {
      when(mockRepo.getOrCreateChat(any)).thenAnswer((_) async => 'chat_123');
      when(mockRepo.messagesStream('chat_123')).thenAnswer((_) => Stream.value([testMessage, myMessage]));
      
      await tester.pumpWidget(createTestApp(
        overrides: [
          userIdProvider.overrideWithValue('my_uid'),
          chatRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const ChatScreen(productId: 'prod_123', productTitle: 'Test Product'),
      ));
      
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); // Wait for openChat
      await tester.pump(const Duration(seconds: 1)); // Wait for messages

      expect(find.text('Hello from seller'), findsOneWidget);
      expect(find.text('Hello from me'), findsOneWidget);
    });

    testWidgets('can send a message', (tester) async {
      when(mockRepo.getOrCreateChat(any)).thenAnswer((_) async => 'chat_123');
      when(mockRepo.messagesStream('chat_123')).thenAnswer((_) => Stream.value([]));
      
      await tester.pumpWidget(createTestApp(
        overrides: [
          userIdProvider.overrideWithValue('my_uid'),
          chatRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const ChatScreen(productId: 'prod_123', productTitle: 'Test Product'),
      ));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); // Wait for openChat

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'New message');
      await tester.pump(); // Update UI with text
      
      final sendBtn = find.byKey(const Key('chat_send_button'));
      expect(sendBtn, findsOneWidget);
      
      await tester.tap(sendBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      
      verify(mockRepo.sendMessage('chat_123', 'New message')).called(1);
    });
  });
}

class PlainException implements Exception {
  final String message;
  const PlainException(this.message);
  @override
  String toString() => message;
}
