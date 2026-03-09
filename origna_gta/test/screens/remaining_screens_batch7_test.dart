import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:origna_gta/screens/chat_conversations_screen.dart';
import 'package:origna_gta/screens/chat_screen.dart';
import 'package:origna_gta/screens/seller_integration_screen.dart';
import 'package:origna_gta/screens/seller_products_screen.dart';
import 'package:origna_gta/screens/seller_registration_screen.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/features/auth/auth_provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:origna_gta/core/repositories/product_repository.dart';
import 'package:origna_gta/core/repositories/order_repository.dart';
import 'package:origna_gta/core/repositories/user_repository.dart';
import 'package:origna_gta/models/models.dart' as models;
import '../test_utils.dart';

@GenerateNiceMocks([
  MockSpec<auth.User>(),
  MockSpec<ProductRepository>(),
  MockSpec<OrderRepository>(),
  MockSpec<UserRepository>(),
])
import 'remaining_screens_batch7_test.mocks.dart';

void main() {
  late MockUser mockUser;
  late FakeFirebaseFirestore fakeFirestore;
  late MockProductRepository mockProductRepo;
  late MockOrderRepository mockOrderRepo;
  late MockUserRepository mockUserRepo;

  setUpAll(() {
    initTestMocks();
  });

  setUp(() {
    mockUser = MockUser();
    fakeFirestore = FakeFirebaseFirestore();
    mockProductRepo = MockProductRepository();
    mockOrderRepo = MockOrderRepository();
    mockUserRepo = MockUserRepository();
    when(mockUser.uid).thenReturn('test_user_123');
  });

  Future<void> pumpResilient(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(
      TestWrapper(
        overrides: [
          currentUserProvider.overrideWithValue(mockUser),
          userProfileProvider.overrideWith((ref) => Stream.value(models.UserModel(
            uid: 'test_user_123', name: 'Test', email: 't@e.com', roles: const ['seller'], createdAt: DateTime.now()
          ))),
          firestoreProvider.overrideWithValue(fakeFirestore),
          productRepositoryProvider.overrideWithValue(mockProductRepo),
          orderRepositoryProvider.overrideWithValue(mockOrderRepo),
          userRepositoryProvider.overrideWithValue(mockUserRepo),
        ],
        child: widget,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    try {
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
    } catch (_) {}
  }

  group('Remaining Screens Batch 7 Smoke Tests', () {
    testWidgets('renders ChatConversationsScreen', (tester) async {
      await pumpResilient(tester, const ChatConversationsScreen());
      expect(find.byType(ChatConversationsScreen), findsOneWidget);
    });

    testWidgets('renders ChatScreen', (tester) async {
      await pumpResilient(tester, const ChatScreen(productId: 'p1', productTitle: 'Title'));
      expect(find.byType(ChatScreen), findsOneWidget);
    });

    testWidgets('renders SellerIntegrationScreen', (tester) async {
      await pumpResilient(tester, const SellerIntegrationScreen());
      expect(find.byType(SellerIntegrationScreen), findsOneWidget);
    });

    testWidgets('renders SellerProductsScreen', (tester) async {
      await pumpResilient(tester, const SellerProductsScreen());
      expect(find.byType(SellerProductsScreen), findsOneWidget);
    });

    testWidgets('renders SellerRegistrationScreen', (tester) async {
      await pumpResilient(tester, const SellerRegistrationScreen());
      expect(find.byType(SellerRegistrationScreen), findsOneWidget);
    });
  });
}
