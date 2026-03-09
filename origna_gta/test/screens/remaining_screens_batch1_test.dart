import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:origna_gta/screens/notifications_screen.dart';
import 'package:origna_gta/screens/favorites_screen.dart';
import 'package:origna_gta/screens/ordersuccess_screen.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/features/products/products_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import '../test_utils.dart';

@GenerateNiceMocks([MockSpec<User>()])
import 'remaining_screens_batch1_test.mocks.dart';

void main() {
  setUpAll(() {
    initTestMocks();
  });
  late MockUser mockUser;
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    mockUser = MockUser();
    fakeFirestore = FakeFirebaseFirestore();
    when(mockUser.uid).thenReturn('test_user_123');
  });

  group('Remaining Screens Batch 1 Smoke Tests', () {
    testWidgets('renders notifications screen', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestWrapper(
          overrides: [
            currentUserProvider.overrideWithValue(mockUser),
            firestoreProvider.overrideWithValue(fakeFirestore),
          ],
          child: const NotificationsScreen(),
        ),
      );
      
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(NotificationsScreen), findsOneWidget);
    });

    testWidgets('renders favorites screen', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestWrapper(
          overrides: [
            currentUserProvider.overrideWithValue(mockUser),
            firestoreProvider.overrideWithValue(fakeFirestore),
            favoritesProvider.overrideWith((ref) => Stream.value(<String>{})),
          ],
          child: const FavoritesScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(FavoritesScreen), findsOneWidget);
    });

    testWidgets('renders order success screen', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestWrapper(
          overrides: [
            currentUserProvider.overrideWithValue(mockUser),
            firestoreProvider.overrideWithValue(fakeFirestore),
          ],
          child: const OrderSuccessScreen(orderId: 'order_123'),
        ),
      );
      await tester.pump();
      // Add enough time for mascot jump timers to complete
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(OrderSuccessScreen), findsOneWidget);
    });
  });
}
