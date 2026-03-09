import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/repositories/auth_repository.dart';
import 'package:origna_gta/core/repositories/order_repository.dart';
import 'package:origna_gta/core/repositories/user_repository.dart';
import 'package:origna_gta/features/auth/auth_provider.dart';
import 'package:origna_gta/features/cart/cart_provider.dart';
import 'package:origna_gta/features/checkout/checkout_provider.dart';
import 'package:origna_gta/features/subscription/subscription_provider.dart';
import 'package:origna_gta/models/models.dart';
import 'package:origna_gta/screens/checkout_screen.dart';
import 'package:origna_gta/utils/constants.dart';

import '../test_utils.dart';
@GenerateNiceMocks([MockSpec<OrderRepository>(), MockSpec<UserRepository>(), MockSpec<AuthRepository>()])
import 'checkout_screen_test.mocks.dart';

void main() {
  late MockOrderRepository mockOrderRepo;
  late MockUserRepository mockUserRepo;
  late MockAuthRepository mockAuthRepo;

  setUp(() {
    mockOrderRepo = MockOrderRepository();
    mockUserRepo = MockUserRepository();
    mockAuthRepo = MockAuthRepository();
    initTestMocks();
  });

  final testUser = UserModel(uid: 'user_123', email: 'test@example.com', name: 'Test User', roles: ['buyer'], createdAt: DateTime.now());

  final testAddress = Address(street: '123 Main St', city: 'Toronto', state: 'ON', postalCode: 'M5V 3A8', country: 'Canada', isDefault: true);

  final testItem = CartItemDetailModel(
    productId: 'prod_1',
    name: 'Test Product',
    description: 'Test description',
    price: 50.0,
    quantity: 1,
    sellerId: 'seller_1',
    sellerName: 'Seller 1',
    imageUrls: [],
    isDigital: false,
    isPerishable: false,
    isLocalDeliveryOnly: false,
    estimatedShipDays: 3,
    sellerAddress: testAddress,
    createdAt: Timestamp.now(),
  );

  Widget createTestWidget({List<CartItemDetailModel> items = const [], UserModel? user, CheckoutState? initialState}) {
    return TestWrapper(
      overrides: [
        userProfileProvider.overrideWith((ref) => Stream.value(user)),
        orderRepositoryProvider.overrideWithValue(mockOrderRepo),
        userRepositoryProvider.overrideWithValue(mockUserRepo),
        authRepositoryProvider.overrideWithValue(mockAuthRepo),
        userIdProvider.overrideWithValue('user_123'),
        userAddressesProvider.overrideWith((ref) => Stream.value([])),
        cartSubtotalProvider.overrideWith((ref) => items.fold(0.0, (total, i) => total + (i.price * i.quantity))),
        cartWithDetailsProvider.overrideWith((ref) => items),
        subscriptionStreamProvider.overrideWith((ref) => Stream.value(null)),
        deliveryInstructionsProvider.overrideWith((ref) => ''),
        // Use real notifier but we can still seed its state if we override it carefully
        if (initialState != null)
          checkoutStateProvider.overrideWith((ref) {
            final notifier = CheckoutNotifier(ref);
            // Internal hack to set state for testing if needed
            // But usually we just want the real one to initialize
            return notifier;
          }),
      ],
      child: CheckoutScreen(items: items, total: items.fold(0.0, (total, i) => total + (i.price * i.quantity))),
    );
  }

  group('CheckoutScreen Widget Tests', () {
    testWidgets('renders stepper and address section when address exists', (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Make sure repo returns the address so initialize() finds it
      when(mockUserRepo.getUserProfile(any)).thenAnswer((_) async => testUser.copyWith(address: testAddress));

      await tester.pumpWidget(createTestWidget(user: testUser, items: [testItem]));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('checkout.checkout'.tr()), findsWidgets);
      // Wait for initialize to complete and UI to update
      expect(find.textContaining('123 Main St', skipOffstage: false), findsWidgets);
    });

    testWidgets('shows no address view when address is null', (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(mockUserRepo.getUserProfile(any)).thenAnswer((_) async => testUser.copyWith(address: null));

      await tester.pumpWidget(createTestWidget(user: testUser, items: [testItem]));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('checkout.no_address_title'.tr()), findsOneWidget);
    });
  });
}

class NativeRemoveListener {
  final void Function() callback;
  NativeRemoveListener(this.callback);
  void call() => callback();
}
