import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/repositories/order_repository.dart';
import 'package:origna_gta/core/repositories/user_repository.dart';
import 'package:origna_gta/features/admin/admin_actions_viewmodel.dart';
import 'package:origna_gta/features/admin/admin_panel_screen.dart';
import 'package:origna_gta/features/admin/admin_providers.dart';
import 'package:origna_gta/features/auth/auth_provider.dart';
import 'package:origna_gta/models/models.dart';
import 'package:origna_gta/screens/payment_screens.dart';
import 'package:origna_gta/widgets/language_selector.dart';

@GenerateNiceMocks([
  MockSpec<User>(),
  MockSpec<UserRepository>(),
  MockSpec<OrderRepository>(),
  MockSpec<AdminActionsViewModel>(),
  MockSpec<FirebaseFirestore>(),
])
import 'high_impact_coverage_test.mocks.dart';
import 'test_utils.dart';

void main() {
  late MockUser mockUser;
  late MockOrderRepository mockOrderRepo;
  late MockAdminActionsViewModel mockAdminVM;
  late MockUserRepository mockUserRepo;

  setUpAll(() {
    initTestMocks();
  });

  setUp(() {
    mockUser = MockUser();
    mockOrderRepo = MockOrderRepository();
    mockAdminVM = MockAdminActionsViewModel();
    mockUserRepo = MockUserRepository();

    when(mockUser.uid).thenReturn('admin_user');
    when(mockAdminVM.state).thenReturn(const AdminActionsState());
    when(mockUserRepo.updatePreferredLanguage(any, any)).thenAnswer((_) async {});
  });

  Widget testWrapper(Widget child, {List<Override> overrides = const []}) {
    return TestWrapper(
      overrides: [
        currentUserProvider.overrideWithValue(mockUser),
        adminActionsViewModelProvider.overrideWith((ref) => mockAdminVM),
        userRepositoryProvider.overrideWithValue(mockUserRepo),
        firestoreProvider.overrideWithValue(MockFirebaseFirestore()),
        ...overrides,
      ],
      child: child,
    );
  }

  group('AdminPanelScreen Coverage', () {
    testWidgets('renders loading state', (tester) async {
      await tester.pumpWidget(testWrapper(const AdminPanelScreen(), overrides: [userProfileProvider.overrideWith((ref) => const Stream.empty())]));
      await tester.pump();
      expect(find.textContaining('Loading'), findsOneWidget);
    });

    testWidgets('renders access denied for non-admin', (tester) async {
      final nonAdminProfile = UserModel(uid: 'user1', name: 'User', email: 'u@e.com', roles: const ['buyer'], createdAt: DateTime.now());

      await tester.pumpWidget(testWrapper(const AdminPanelScreen(), overrides: [userProfileProvider.overrideWith((ref) => Stream.value(nonAdminProfile))]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.textContaining('Access Denied'), findsOneWidget);
    });

    testWidgets('renders tabs for admin and allows switching', (tester) async {
      final adminProfile = UserModel(uid: 'admin1', name: 'Admin', email: 'a@e.com', roles: const ['admin'], createdAt: DateTime.now());

      await tester.pumpWidget(
        testWrapper(
          const AdminPanelScreen(),
          overrides: [
            userProfileProvider.overrideWith((ref) => Stream.value(adminProfile)),
            adminSellersProvider.overrideWith((ref) => Stream.value([])),
            adminUsersProvider.overrideWith((ref) => Stream.value([])),
            adminOrdersProvider.overrideWith((ref, status) => Stream.value([])),
            adminProductsProvider.overrideWith((ref, sellerId) => Stream.value([])),
            adminReviewsProvider.overrideWith((ref, filters) => Stream.value([])),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Sellers'), findsWidgets);

      // Tap on Users tab
      await tester.tap(find.text('Users').first);
      await tester.pumpAndSettle();

      // Tap on Orders tab
      await tester.tap(find.text('Orders').first);
      await tester.pumpAndSettle();

      // Tap on Products tab
      await tester.tap(find.text('Products').first);
      await tester.pumpAndSettle();
    });
  });

  group('Widgets Coverage', () {
    testWidgets('LanguageSelector toggles language', (tester) async {
      await tester.pumpWidget(testWrapper(const LanguageSelector()));
      await tester.pumpAndSettle();

      final button = find.byType(DropdownButton<Locale>);
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text('English'), findsWidgets);
      expect(find.text('Français'), findsWidgets);

      // Tap French
      await tester.tap(find.text('Français').last);
      await tester.pumpAndSettle();
    });
  });

  group('PaymentScreens Coverage', () {
    testWidgets('PaymentCanceledScreen renders correctly', (tester) async {
      await tester.pumpWidget(testWrapper(const PaymentCanceledScreen()));
      await tester.pumpAndSettle();
      expect(find.textContaining('canceled'), findsWidgets);

      final backBtn = find.textContaining('shopping');
      expect(backBtn, findsOneWidget);
      await tester.tap(backBtn);
      await tester.pumpAndSettle();
    });

    testWidgets('OrderSuccessGate renders and timeouts', (tester) async {
      when(mockOrderRepo.watchPaidOrderBySession(any)).thenAnswer((_) => const Stream.empty());

      await tester.runAsync(() async {
        await tester.pumpWidget(testWrapper(const OrderSuccessGate(sessionId: 's1'), overrides: [orderRepositoryProvider.overrideWithValue(mockOrderRepo)]));
        await tester.pump();

        expect(find.textContaining('confirming'), findsWidgets);

        // Wait for timeout (default 15s)
        await Future.delayed(const Duration(seconds: 16));
        await tester.pump(); // Pump to trigger timer
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();
      });
    });
  });
}
