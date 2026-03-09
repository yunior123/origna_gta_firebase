import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:origna_gta/widgets/rating_dialog.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/repositories/product_repository.dart';
import 'package:origna_gta/features/subscription/subscription_provider.dart';
import 'package:origna_gta/features/subscription/subscription_state.dart';
import '../test_utils.dart';

@GenerateNiceMocks([
  MockSpec<ProductRepository>(),
])
import 'rating_dialog_test.mocks.dart';

void main() {
  late MockProductRepository mockRepo;

  setUp(() {
    mockRepo = MockProductRepository();
    initTestMocks();
  });

  Widget createTestWidget({
    bool isPremium = false,
  }) {
    return TestWrapper(
      overrides: [
        productRepositoryProvider.overrideWithValue(mockRepo),
        subscriptionStreamProvider.overrideWith((ref) => Stream.value(SubscriptionInfo(
          isPremium: isPremium, 
          status: isPremium ? 'active' : 'inactive',
        ))),
      ],
      child: const Scaffold(
        body: RatingDialog(
          orderId: 'order_123',
          productId: 'prod_123',
          productName: 'Test Product',
        ),
      ),
    );
  }

  group('RatingDialog Widget Tests', () {
    testWidgets('renders basic dialog structure', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('rating.title'.tr()), findsOneWidget);
      expect(find.text('Test Product'), findsOneWidget);
      expect(find.text('rating.tap_to_rate'.tr()), findsOneWidget);
    });

    testWidgets('can select rating', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Tap 4th star
      await tester.tap(find.byIcon(Icons.star_border).at(3));
      await tester.pump();

      expect(find.text('rating.very_good'.tr()), findsOneWidget);
      expect(find.byIcon(Icons.star), findsNWidgets(4));
    });

    testWidgets('shows premium label for photos when not premium', (tester) async {
      await tester.pumpWidget(createTestWidget(isPremium: false));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('common.premium'.tr()), findsOneWidget);
      expect(find.text('rating.photos_premium_only'.tr()), findsOneWidget);
    });

    testWidgets('can submit rating', (tester) async {
      when(mockRepo.submitRatingAtomic(any, any, any, reviewImages: anyNamed('reviewImages'), reviewText: anyNamed('reviewText')))
          .thenAnswer((_) async => Future.value());

      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Select rating
      await tester.tap(find.byIcon(Icons.star_border).at(4)); // 5 stars
      await tester.pump();

      // Enter review
      await tester.enterText(find.byType(TextField), 'Great product!');
      await tester.pump();

      // Submit
      await tester.tap(find.text('common.submit'.tr()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      verify(mockRepo.submitRatingAtomic('order_123', 'prod_123', 5, reviewText: 'Great product!', reviewImages: null)).called(1);
    });

    testWidgets('shows error on submission failure', (tester) async {
      when(mockRepo.submitRatingAtomic(any, any, any, reviewImages: anyNamed('reviewImages'), reviewText: anyNamed('reviewText')))
          .thenThrow(Exception('Failed to submit'));

      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Select rating
      await tester.tap(find.byIcon(Icons.star_border).first);
      await tester.pump();

      // Submit
      await tester.tap(find.text('common.submit'.tr()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Failed to submit rating'), findsOneWidget);
    });
   group('RatingDialog Photo Picker (Premium)', () {
    testWidgets('shows photo picker when premium', (tester) async {
      await tester.pumpWidget(createTestWidget(isPremium: true));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
      expect(find.text('(0/3)'), findsOneWidget);
    });
  });
  });
}
