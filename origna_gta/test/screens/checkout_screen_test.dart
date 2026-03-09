import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/repositories/auth_repository.dart';
import 'package:origna_gta/core/repositories/order_repository.dart';
import 'package:origna_gta/core/repositories/user_repository.dart';
import 'package:origna_gta/features/auth/auth_provider.dart';
import 'package:origna_gta/models/models.dart' as models;
import 'package:origna_gta/screens/checkout_screen.dart';
import 'package:origna_gta/widgets/modern_button.dart';

import '../test_utils.dart';
@GenerateNiceMocks([
  MockSpec<User>(),
  MockSpec<FirebaseFunctions>(),
  MockSpec<HttpsCallable>(),
  MockSpec<HttpsCallableResult<Map>>(as: #MockHttpsCallableResultMap),
  MockSpec<OrderRepository>(),
  MockSpec<UserRepository>(),
  MockSpec<AuthRepository>(),
])
import 'checkout_screen_test.mocks.dart';

void main() {
  late MockUser mockUser;
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseFunctions mockFunctions;
  late MockOrderRepository mockOrderRepo;
  late MockUserRepository mockUserRepo;
  late MockAuthRepository mockAuthRepo;

  setUpAll(() {
    initTestMocks();
  });

  setUp(() {
    mockUser = MockUser();
    fakeFirestore = FakeFirebaseFirestore();
    mockFunctions = MockFirebaseFunctions();
    mockOrderRepo = MockOrderRepository();
    mockUserRepo = MockUserRepository();
    mockAuthRepo = MockAuthRepository();

    when(mockUser.uid).thenReturn('test_user_123');
    when(mockUser.email).thenReturn('test@example.com');
    when(mockUser.displayName).thenReturn('Test User');

    when(mockAuthRepo.isEmailVerified()).thenAnswer((_) async => true);
  });

  Widget buildTestWidget({List<models.CartItemDetailModel> items = const [], double total = 0.0, List<models.Address> addresses = const []}) {
    return TestWrapper(
      overrides: [
        currentUserProvider.overrideWithValue(mockUser),
        userProfileProvider.overrideWith(
          (ref) =>
              Stream.value(models.UserModel(uid: 'test_user_123', name: 'Test User', email: 'test@example.com', roles: ['buyer'], createdAt: DateTime.now())),
        ),
        userAddressesProvider.overrideWith((ref) => Stream.value(addresses)),
        firestoreProvider.overrideWithValue(fakeFirestore),
        firebaseFunctionsProvider.overrideWithValue(mockFunctions),
        orderRepositoryProvider.overrideWithValue(mockOrderRepo),
        userRepositoryProvider.overrideWithValue(mockUserRepo),
        authRepositoryProvider.overrideWithValue(mockAuthRepo),
      ],
      child: CheckoutScreen(items: items, total: total),
    );
  }

  group('CheckoutScreen Comprehensive Test', () {
    testWidgets('processes checkout successfully', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(2000, 3000);
      tester.view.devicePixelRatio = 1.0;

      final mockItem = models.CartItemDetailModel(
        productId: 'prod_1',
        name: 'Smartphone',
        description: 'Great phone',
        price: 50.0,
        imageUrls: [],
        quantity: 1,
        createdAt: Timestamp.now(),
        sellerAddress: models.Address(street: '123 Seller St', city: 'Toronto', state: 'ON', postalCode: 'M5V 2L7', country: 'Canada'),
        sellerId: 'seller_123',
        sellerName: 'Best Seller',
        status: 'active',
      );

      final mockAddress = models.Address(street: '456 Buyer Ave', city: 'Toronto', state: 'ON', postalCode: 'M1M 1M1', country: 'Canada', isDefault: true);

      final mockVerifyCallable = MockHttpsCallable();
      final mockVerifyResult = MockHttpsCallableResultMap();
      when(mockFunctions.httpsCallable('verify_cart_prices', options: anyNamed('options'))).thenReturn(mockVerifyCallable);
      when(mockVerifyCallable.call(any)).thenAnswer((_) async => mockVerifyResult);
      when(mockVerifyResult.data).thenReturn({'hasChanges': false});

      when(mockOrderRepo.createCheckoutSession(any)).thenAnswer(
        (_) async => {'checkoutUrl': 'https://stripe.com/checkout/test_session', 'sessionId': 'sess_123', 'orderId': 'order_123', 'taxAmountCents': 650},
      );

      await tester.pumpWidget(buildTestWidget(items: [mockItem], total: 50.0, addresses: [mockAddress]));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('checkout_terms_checkbox')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('checkout_place_order_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('checkout_confirm_pay_button')));
      await tester.pump(const Duration(seconds: 1));

      verify(mockOrderRepo.createCheckoutSession(any)).called(1);
      tester.view.resetPhysicalSize();
    });

    testWidgets('Place Order button is disabled when terms not accepted', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(2000, 3000);
      final mockItem = models.CartItemDetailModel(
        productId: 'p1',
        name: 'P',
        description: '',
        price: 10,
        imageUrls: [],
        quantity: 1,
        createdAt: Timestamp.now(),
        sellerAddress: models.Address.empty(),
        sellerId: 's1',
        sellerName: 'S1',
      );
      final mockAddress = models.Address(street: 'S', city: 'C', state: 'ON', postalCode: 'M1M 1M1', country: 'CA', isDefault: true);

      await tester.pumpWidget(buildTestWidget(items: [mockItem], total: 10.0, addresses: [mockAddress]));
      await tester.pumpAndSettle();

      final placeOrderBtn = tester.widget<ModernButton>(find.byKey(const Key('checkout_place_order_button')));
      expect(placeOrderBtn.onPressed, isNull);
      tester.view.resetPhysicalSize();
    });

    testWidgets('shows error SnackBar on checkout failure', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(2000, 3000);
      final mockItem = models.CartItemDetailModel(
        productId: 'p1',
        name: 'P',
        description: '',
        price: 10,
        imageUrls: [],
        quantity: 1,
        createdAt: Timestamp.now(),
        sellerAddress: models.Address.empty(),
        sellerId: 's1',
        sellerName: 'S1',
      );
      final mockAddress = models.Address(street: 'S', city: 'C', state: 'ON', postalCode: 'M1M 1M1', country: 'CA', isDefault: true);

      final mockVerifyCallable = MockHttpsCallable();
      final mockVerifyResult = MockHttpsCallableResultMap();
      when(mockFunctions.httpsCallable('verify_cart_prices', options: anyNamed('options'))).thenReturn(mockVerifyCallable);
      when(mockVerifyCallable.call(any)).thenAnswer((_) async => mockVerifyResult);
      when(mockVerifyResult.data).thenReturn({'hasChanges': false});

      when(mockOrderRepo.createCheckoutSession(any)).thenThrow(Exception('Payment failed'));

      await tester.pumpWidget(buildTestWidget(items: [mockItem], total: 10.0, addresses: [mockAddress]));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('checkout_terms_checkbox')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('checkout_place_order_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('checkout_confirm_pay_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SnackBar), findsAtLeast(1));
      tester.view.resetPhysicalSize();
    });

    testWidgets('digital only view without address', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(2000, 3000);
      final mockItem = models.CartItemDetailModel(
        productId: 'p1',
        name: 'Software',
        description: '',
        price: 10,
        imageUrls: [],
        quantity: 1,
        createdAt: Timestamp.now(),
        sellerAddress: models.Address.empty(),
        sellerId: 's1',
        sellerName: 'S1',
        isDigital: true,
      );

      await tester.pumpWidget(buildTestWidget(items: [mockItem], total: 10.0, addresses: []));
      await tester.pumpAndSettle();

      // Check for the icon instead of text to be safe
      expect(find.byIcon(Icons.download_done), findsOneWidget);
      tester.view.resetPhysicalSize();
    });

    testWidgets('desktop layout rendering', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 1000); // Desktop size
      tester.view.devicePixelRatio = 1.0;

      final mockItem = models.CartItemDetailModel(
        productId: 'p1',
        name: 'P',
        description: '',
        price: 10,
        imageUrls: [],
        quantity: 1,
        createdAt: Timestamp.now(),
        sellerAddress: models.Address.empty(),
        sellerId: 's1',
        sellerName: 'S1',
      );
      final mockAddress = models.Address(street: 'S', city: 'C', state: 'ON', postalCode: 'M1M 1M1', country: 'CA', isDefault: true);

      await tester.pumpWidget(buildTestWidget(items: [mockItem], total: 10.0, addresses: [mockAddress]));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('checkout_summary_section')), findsOneWidget);
      tester.view.resetPhysicalSize();
    });
  });
}
