import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/repositories/auth_repository.dart';
import 'package:origna_gta/core/repositories/order_repository.dart';
import 'package:origna_gta/core/repositories/product_repository.dart';
import 'package:origna_gta/core/repositories/user_repository.dart';
import 'package:origna_gta/features/auth/auth_provider.dart';
import 'package:origna_gta/features/cart/cart_provider.dart';
import 'package:origna_gta/features/chat/chat_provider.dart';
import 'package:origna_gta/features/subscription/subscription_provider.dart';
import 'package:origna_gta/models/generated/models.dart' as gen;
import 'package:origna_gta/models/models.dart';
import 'package:origna_gta/screens/addproduct_screen.dart';
import 'package:origna_gta/screens/addressmanagement_screen.dart';
import 'package:origna_gta/screens/cart_screen.dart';
import 'package:origna_gta/screens/chat_conversations_screen.dart';
import 'package:origna_gta/screens/chat_screen.dart';
import 'package:origna_gta/screens/checkout_screen.dart';
import 'package:origna_gta/screens/editaddress_screen.dart';
import 'package:origna_gta/screens/editproduct_screen.dart';
import 'package:origna_gta/screens/favorites_screen.dart';
import 'package:origna_gta/screens/home_screen.dart';
import 'package:origna_gta/screens/login_screen.dart';
import 'package:origna_gta/screens/notifications_screen.dart';
import 'package:origna_gta/screens/order_detail_screen.dart';
import 'package:origna_gta/screens/orders_screen.dart';
import 'package:origna_gta/screens/payment_screens.dart';
import 'package:origna_gta/screens/privacy_policy_screen.dart';
import 'package:origna_gta/screens/productdetails_screen.dart';
import 'package:origna_gta/screens/profile_screen.dart';
import 'package:origna_gta/screens/reset_password_screen.dart';
import 'package:origna_gta/screens/seller_orders_screen.dart';
import 'package:origna_gta/screens/seller_registration_screen.dart';
import 'package:origna_gta/screens/seller_setup_screen.dart';
import 'package:origna_gta/screens/shipping_approval_screen.dart';
import 'package:origna_gta/screens/subscription_cancel_screen.dart';
import 'package:origna_gta/screens/subscription_screen.dart';
import 'package:origna_gta/screens/subscription_success_screen.dart';
import 'package:origna_gta/screens/terms_of_service_screen.dart';
import 'package:origna_gta/utils/env_config.dart';

@GenerateNiceMocks([
  MockSpec<User>(),
  MockSpec<FirebaseFunctions>(),
  MockSpec<ProductRepository>(),
  MockSpec<OrderRepository>(),
  MockSpec<UserRepository>(),
  MockSpec<AuthRepository>(),
  MockSpec<EnvConfig>(),
])
import 'coverage_booster_test.mocks.dart';
import 'test_utils.dart';

void main() {
  late MockUser mockUser;
  late MockProductRepository mockProductRepo;
  late MockOrderRepository mockOrderRepo;
  late MockUserRepository mockUserRepo;
  late MockAuthRepository mockAuthRepo;
  late MockEnvConfig mockConfig;

  setUpAll(() {
    initTestMocks();
  });

  setUp(() {
    mockUser = MockUser();
    mockProductRepo = MockProductRepository();
    mockOrderRepo = MockOrderRepository();
    mockUserRepo = MockUserRepository();
    mockAuthRepo = MockAuthRepository();
    mockConfig = MockEnvConfig();

    when(mockUser.uid).thenReturn('test_user');
    when(mockConfig.isDev).thenReturn(true);

    when(
      mockProductRepo.fetchProducts(
        searchQuery: anyNamed('searchQuery'),
        categoryId: anyNamed('categoryId'),
        subcategory: anyNamed('subcategory'),
        lastDocument: anyNamed('lastDocument'),
        pageSize: anyNamed('pageSize'),
        sortOption: anyNamed('sortOption'),
        minPriceCents: anyNamed('minPriceCents'),
        maxPriceCents: anyNamed('maxPriceCents'),
      ),
    ).thenAnswer((_) async => ProductQueryResult(products: [], lastDocument: null, hasMore: false));

    when(mockUserRepo.watchAddresses(any)).thenAnswer((_) => Stream.value([]));
    when(mockOrderRepo.watchBuyerOrders(any)).thenAnswer((_) => Stream.value([]));
    when(mockOrderRepo.watchSellerOrders(any)).thenAnswer((_) => Stream.value([]));
  });

  Widget boosterWrapper(Widget child) {
    return TestWrapper(
      overrides: [
        currentUserProvider.overrideWithValue(mockUser),
        userProfileProvider.overrideWith(
          (ref) => Stream.value(
            UserModel(
              uid: 'test_user',
              name: 'Test',
              email: 't@e.com',
              roles: const ['seller', 'admin'],
              createdAt: DateTime.now(),
              address: Address(street: 'S', city: 'C', state: 'ON', postalCode: 'M1M 1M1', country: 'CA'),
            ),
          ),
        ),
        productRepositoryProvider.overrideWithValue(mockProductRepo),
        orderRepositoryProvider.overrideWithValue(mockOrderRepo),
        userRepositoryProvider.overrideWithValue(mockUserRepo),
        authRepositoryProvider.overrideWithValue(mockAuthRepo),
        envConfigProvider.overrideWithValue(mockConfig),
        subscriptionStreamProvider.overrideWith((ref) => Stream.value(null)),
        cartItemsProvider.overrideWith((ref) => Stream.value([])),
        myAllChatsProvider.overrideWith((ref) => Stream.value([])),
      ],
      child: Scaffold(body: child),
    );
  }

  group('Coverage Booster — Pumping All Screens', () {
    testWidgets('pumps HomeScreen', (tester) async {
      await tester.pumpWidget(boosterWrapper(const HomeScreen()));
      await tester.pump();
    });

    testWidgets('pumps ProfileScreen', (tester) async {
      await tester.pumpWidget(boosterWrapper(const ProfileScreen()));
      await tester.pump();
    });

    testWidgets('pumps ProductDetailScreen', (tester) async {
      await tester.pumpWidget(boosterWrapper(const ProductDetailScreen(productId: 'p1')));
      await tester.pump();
    });

    testWidgets('pumps CartScreen', (tester) async {
      await tester.pumpWidget(boosterWrapper(const CartScreen()));
      await tester.pump();
    });

    testWidgets('pumps FavoritesScreen', (tester) async {
      await tester.pumpWidget(boosterWrapper(const FavoritesScreen()));
      await tester.pump();
    });

    testWidgets('pumps SellerOrdersScreen', (tester) async {
      await tester.pumpWidget(boosterWrapper(const SellerOrdersScreen()));
      await tester.pump();
    });

    testWidgets('pumps OrdersScreen', (tester) async {
      await tester.pumpWidget(boosterWrapper(const OrdersScreen()));
      await tester.pump();
    });

    testWidgets('pumps EditProductScreen', (tester) async {
      final p = gen.Product(
        productId: 'p1',
        name: 'N',
        price: 10,
        categoryId: 1,
        sellerId: 's1',
        createdAt: DateTime.now(),
        imageUrls: const [],
        description: 'D',
        stockQuantity: 1,
        sellerAddress: const gen.Address(street: 'S', city: 'C', state: 'ON', postalCode: 'M1M 1M1', country: 'CA'),
      );
      await tester.pumpWidget(boosterWrapper(EditProductScreen(product: p)));
      await tester.pump();
    });

    testWidgets('pumps SellerSetupCompleteScreen', (tester) async {
      await tester.pumpWidget(boosterWrapper(const SellerSetupCompleteScreen()));
      await tester.pump();
    });

    testWidgets('pumps SubscriptionSuccessScreen', (tester) async {
      await tester.pumpWidget(boosterWrapper(const SubscriptionSuccessScreen()));
      await tester.pump();
    });

    testWidgets('pumps LoginScreen', (tester) async {
      await tester.pumpWidget(boosterWrapper(const LoginScreen()));
      await tester.pump();
    });

    testWidgets('pumps ResetPasswordScreen', (tester) async {
      await tester.pumpWidget(boosterWrapper(const ResetPasswordScreen(oobCode: '123')));
      await tester.pump();
    });

    testWidgets('pumps AddProductScreen', (tester) async {
      await tester.pumpWidget(boosterWrapper(const AddProductScreen()));
      await tester.pump();
    });

    testWidgets('pumps AddressManagementScreen', (tester) async {
      await tester.pumpWidget(boosterWrapper(const AddressManagementScreen()));
      await tester.pump();
    });

    testWidgets('pumps AddEditAddressScreen', (tester) async {
      await tester.pumpWidget(boosterWrapper(const AddEditAddressScreen()));
      await tester.pump();
    });

    testWidgets('pumps CheckoutScreen', (tester) async {
      await tester.pumpWidget(boosterWrapper(const CheckoutScreen(items: [], total: 0)));
      await tester.pump();
    });

    testWidgets('pumps ShippingApprovalScreen', (tester) async {
      await tester.pumpWidget(boosterWrapper(const ShippingApprovalScreen()));
      await tester.pump();
    });

    testWidgets('pumps SellerRegistrationScreen', (tester) async {
      await tester.pumpWidget(boosterWrapper(const SellerRegistrationScreen()));
      await tester.pump();
    });

    testWidgets('pumps SubscriptionScreen', (tester) async {
      await tester.pumpWidget(boosterWrapper(const SubscriptionScreen()));
      await tester.pump();
    });

    testWidgets('pumps PrivacyPolicyScreen', (tester) async {
      await tester.pumpWidget(boosterWrapper(PrivacyPolicyScreen()));
      await tester.pump();
    });

    testWidgets('pumps TermsOfServiceScreen', (tester) async {
      await tester.pumpWidget(boosterWrapper(TermsOfServiceScreen()));
      await tester.pump();
    });

    testWidgets('pumps OrderDetailScreen', (tester) async {
      await tester.pumpWidget(boosterWrapper(const OrderDetailScreen(orderId: 'o1')));
      await tester.pump();
    });

    testWidgets('pumps ChatConversationsScreen', (tester) async {
      await tester.pumpWidget(boosterWrapper(const ChatConversationsScreen()));
      await tester.pump();
    });

    testWidgets('pumps ChatScreen', (tester) async {
      await tester.pumpWidget(boosterWrapper(const ChatScreen(productId: 'p1', productTitle: 'Title')));
      await tester.pump();
    });

    testWidgets('pumps NotificationsScreen', (tester) async {
      await tester.pumpWidget(boosterWrapper(const NotificationsScreen()));
      await tester.pump();
    });

    testWidgets('pumps PaymentCanceledScreen', (tester) async {
      await tester.pumpWidget(boosterWrapper(const PaymentCanceledScreen()));
      await tester.pump();
    });

    testWidgets('pumps SubscriptionCancelScreen', (tester) async {
      await tester.pumpWidget(boosterWrapper(const SubscriptionCancelScreen()));
      await tester.pump();
    });
  });
}
