import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:origna_gta/screens/seller_registration_screen.dart';
import 'package:origna_gta/features/auth/auth_provider.dart';
import 'package:origna_gta/features/seller/seller_account_status_viewmodel.dart';
import 'package:origna_gta/features/seller/seller_registration_view_model.dart';
import 'package:origna_gta/core/repositories/user_repository.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/models/models.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/widgets/modern_loading_indicator.dart';
import '../test_utils.dart';

@GenerateNiceMocks([
  MockSpec<FirebaseFunctions>(),
  MockSpec<HttpsCallable>(),
  MockSpec<HttpsCallableResult>(),
])
import 'seller_registration_screen_test.mocks.dart';

void main() {
  late MockFirebaseFunctions mockFunctions;
  late MockHttpsCallable mockCallable;

  setUp(() {
    mockFunctions = MockFirebaseFunctions();
    mockCallable = MockHttpsCallable();
    initTestMocks();
    
    when(mockFunctions.httpsCallable(any)).thenReturn(mockCallable);
    when(mockCallable.call(any)).thenAnswer((_) async => MockHttpsCallableResult());
  });

  final testUser = UserModel(
    uid: 'user_123',
    email: 'test@example.com',
    name: 'Test User',
    roles: ['buyer'],
    createdAt: DateTime.now(),
  );

  Widget createTestWidget({
    UserModel? user,
    SellerAccountStatus status = const SellerAccountStatus(isSeller: false, chargesEnabled: false),
  }) {
    return TestWrapper(
      overrides: [
        userProfileProvider.overrideWith((ref) => Stream.value(user)),
        sellerAccountStatusProvider.overrideWith((ref) => Stream.value(status)),
        paymentProviderStatusProvider.overrideWith((ref) => Future.value({})),
        firebaseFunctionsProvider.overrideWithValue(mockFunctions),
      ],
      child: const SellerRegistrationScreen(),
    );
  }

  group('SellerRegistrationScreen Widget Tests', () {
    testWidgets('renders loading state', (tester) async {
      await tester.pumpWidget(TestWrapper(
        overrides: [
          userProfileProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: const SellerRegistrationScreen(),
      ));
      await tester.pump();

      expect(find.byType(ModernLoadingIndicator), findsWidgets);
    });

    testWidgets('renders basic structure for logged in user', (tester) async {
      await tester.pumpWidget(createTestWidget(user: testUser));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('seller.become_seller'.tr()), findsWidgets);
      expect(find.text('seller.why_sell_with_us'.tr()), findsOneWidget);
      expect(find.text('seller.start_registration'.tr()), findsOneWidget);
    });

    testWidgets('can toggle terms checkbox', (tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(user: testUser));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      final checkbox = find.byType(CheckboxListTile);
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pump();

      final startBtn = find.byKey(const Key('seller_action_button'));
      await tester.ensureVisible(startBtn);
      await tester.tap(startBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.createConnectAccount)).called(1);
    });

    testWidgets('shows verification pending status', (tester) async {
      final userWithAccount = testUser.copyWith(stripeAccountId: 'acct_123');
      const pendingStatus = SellerAccountStatus(
        isSeller: true, 
        chargesEnabled: false, 
        detailsSubmitted: true,
      );

      await tester.pumpWidget(createTestWidget(user: userWithAccount, status: pendingStatus));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('seller.identity_pending'.tr()), findsOneWidget);
      expect(find.text('seller.check_verification'.tr()), findsOneWidget);
    });

    testWidgets('shows completed status and manage button', (tester) async {
      final userWithAccount = testUser.copyWith(stripeAccountId: 'acct_123');
      const completeStatus = SellerAccountStatus(
        isSeller: true, 
        chargesEnabled: true, 
        detailsSubmitted: true,
      );

      await tester.pumpWidget(createTestWidget(user: userWithAccount, status: completeStatus));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('seller.manage_stripe'.tr()), findsOneWidget);
    });
  });
}
