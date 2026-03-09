import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:origna_gta/features/qa/qa_provider.dart';
import 'package:origna_gta/features/qa/qa_repository.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/features/subscription/subscription_provider.dart';
import 'package:origna_gta/features/subscription/subscription_state.dart';

@GenerateNiceMocks([
  MockSpec<QARepository>(),
])
import 'qa_provider_test.mocks.dart';

void main() {
  late MockQARepository mockRepo;
  late ProviderContainer container;

  setUp(() {
    mockRepo = MockQARepository();
    container = ProviderContainer(
      overrides: [
        qaRepositoryProvider.overrideWithValue(mockRepo),
        userIdProvider.overrideWith((ref) => 'user_123'),
        subscriptionStreamProvider.overrideWith((ref) => Stream.value(
          const SubscriptionInfo(isPremium: true, status: 'active')
        )),
      ],
    );
    
    when(mockRepo.submitQuestion(any, any)).thenAnswer((_) async => {});
    when(mockRepo.submitAnswer(any, any)).thenAnswer((_) async => {});
  });

  group('QAController Tests', () {
    test('askQuestion calls repository when premium', () async {
      // Wait for subscription state to load
      await container.read(subscriptionStreamProvider.future);
      
      await container.read(qaControllerProvider.notifier).askQuestion('p1', 'What is this?');
      
      verify(mockRepo.submitQuestion('p1', 'What is this?')).called(1);
      expect(container.read(qaControllerProvider).hasError, isFalse);
    });

    test('askQuestion fails when not premium', () async {
      container = ProviderContainer(
        overrides: [
          qaRepositoryProvider.overrideWithValue(mockRepo),
          userIdProvider.overrideWith((ref) => 'user_123'),
          subscriptionStreamProvider.overrideWith((ref) => Stream.value(
            const SubscriptionInfo(isPremium: false, status: 'none')
          )),
        ],
      );
      
      await container.read(subscriptionStreamProvider.future);
      await container.read(qaControllerProvider.notifier).askQuestion('p1', 'What is this?');
      
      expect(container.read(qaControllerProvider).hasError, isTrue);
      expect(container.read(qaControllerProvider).error, isA<PremiumRequiredException>());
      verifyNever(mockRepo.submitQuestion(any, any));
    });

    test('answerQuestion calls repository', () async {
      await container.read(qaControllerProvider.notifier).answerQuestion(qaId: 'q1', answer: 'Ans');
      
      verify(mockRepo.submitAnswer('q1', 'Ans')).called(1);
    });
  });
}
