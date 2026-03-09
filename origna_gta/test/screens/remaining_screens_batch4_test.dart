import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:origna_gta/screens/order_detail_screen.dart';
import 'package:origna_gta/screens/seller_products_screen.dart';
import 'package:origna_gta/screens/shipping_approval_screen.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/features/auth/auth_provider.dart';
import 'package:origna_gta/features/products/products_provider.dart';
import 'package:origna_gta/features/orders/orders_provider.dart';
import 'package:origna_gta/features/seller/seller_products_viewmodel.dart';
import 'package:origna_gta/models/models.dart' as models;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import '../test_utils.dart';

@GenerateNiceMocks([MockSpec<User>()])
import 'remaining_screens_batch4_test.mocks.dart';

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

  group('Remaining Screens Batch 4 Smoke Tests', () {
    testWidgets('renders order detail screen', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestWrapper(
          overrides: [
            currentUserProvider.overrideWithValue(mockUser),
            firestoreProvider.overrideWithValue(fakeFirestore),
            orderByIdProvider('order_123').overrideWith((ref) => Future.value(null)),
          ],
          child: const OrderDetailScreen(orderId: 'order_123'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(OrderDetailScreen), findsOneWidget);
    });

    testWidgets('renders seller products screen', (WidgetTester tester) async {
      final testUserModel = models.UserModel(
        uid: 'test_user_123',
        name: 'Test',
        email: 'test@example.com',
        roles: ['seller'],
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        TestWrapper(
          overrides: [
            currentUserProvider.overrideWithValue(mockUser),
            userProfileProvider.overrideWith((ref) => Stream.value(testUserModel)),
            firestoreProvider.overrideWithValue(fakeFirestore),
            sellerProductsProvider.overrideWith((ref) => Stream.value([])),
            sellerUnansweredQaProvider('test_user_123').overrideWith((ref) => Stream.value(0)),
          ],
          child: const SellerProductsScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SellerProductsScreen), findsOneWidget);
    });

    testWidgets('renders shipping approval screen', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestWrapper(
          overrides: [
            currentUserProvider.overrideWithValue(mockUser),
            firestoreProvider.overrideWithValue(fakeFirestore),
            pendingShippingApprovalsProvider.overrideWithValue(const AsyncValue.data([])),
          ],
          child: const ShippingApprovalScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ShippingApprovalScreen), findsOneWidget);
    });
  });
}
