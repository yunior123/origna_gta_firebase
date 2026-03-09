import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/features/auth/auth_provider.dart';
import 'package:origna_gta/features/terms/terms_provider.dart';
import 'package:origna_gta/screens/authwrapper_screen.dart';
import 'package:origna_gta/screens/common_screens.dart';
import 'package:origna_gta/screens/main_screen.dart';
import 'package:origna_gta/widgets/modern_button.dart';
import 'package:origna_gta/widgets/modern_loading_indicator.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:origna_gta/core/repositories/user_repository.dart';
import 'package:origna_gta/core/repositories/product_repository.dart';


import '../test_utils.dart';

@GenerateNiceMocks([
  MockSpec<auth.User>(),
  MockSpec<UserRepository>(),
  MockSpec<auth.FirebaseAuth>(),
  MockSpec<FirebaseFunctions>(),
  MockSpec<ProductRepository>(),
])
import 'authwrapper_screen_test.mocks.dart';

void main() {
  late MockUser mockUser;
  late MockUserRepository mockUserRepository;
  late MockFirebaseAuth mockAuth;
  late MockFirebaseFunctions mockFunctions;
  late MockProductRepository mockProductRepository;

  setUp(() {
    mockUser = MockUser();
    mockUserRepository = MockUserRepository();
    mockAuth = MockFirebaseAuth();
    mockFunctions = MockFirebaseFunctions();
    mockProductRepository = MockProductRepository();
    when(mockUser.uid).thenReturn('u1');
    when(mockUserRepository.watchSellerAccountStatus(any)).thenAnswer((_) => Stream.value(const SellerAccountStatus(isSeller: false, chargesEnabled: false)));
    
    when(mockProductRepository.fetchProducts(
      searchQuery: anyNamed('searchQuery'),
      categoryId: anyNamed('categoryId'),
      subcategory: anyNamed('subcategory'),
      lastDocument: anyNamed('lastDocument'),
      pageSize: anyNamed('pageSize'),
      sortOption: anyNamed('sortOption'),
      minPriceCents: anyNamed('minPriceCents'),
      maxPriceCents: anyNamed('maxPriceCents'),
    )).thenAnswer((_) async => ProductQueryResult(products: [], hasMore: false));

    initTestMocks();
  });

  Widget createTestApp({
    required Widget child,
    AsyncValue<auth.User?> authState = const AsyncValue.data(null),
    bool needsTermsUpdate = false,
    AsyncValue<String> termsState = const AsyncValue.data('Terms and conditions mock text.'),
  }) {
    return TestWrapper(
      overrides: [
        firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
        firebaseAuthProvider.overrideWithValue(mockAuth),
        firebaseFunctionsProvider.overrideWithValue(mockFunctions),
        productRepositoryProvider.overrideWithValue(mockProductRepository),
        authStateProvider.overrideWith((ref) {
          if (authState.isLoading) return const Stream.empty();
          if (authState.hasError) return Stream.error(authState.error!, authState.stackTrace!);
          return Stream.value(authState.value);
        }),
        needsTermsUpdateProvider.overrideWithValue(needsTermsUpdate),
        termsProvider.overrideWith((ref) async {
          if (termsState.isLoading) {
            // Simulate loading by returning a future that doesn't complete immediately
            await Future.delayed(const Duration(seconds: 1));
            return 'Loaded';
          }
          if (termsState.hasError) throw termsState.error!;
          return termsState.value!;
        }),
        userRepositoryProvider.overrideWithValue(mockUserRepository),
      ],
      child: child,
    );
  }

  group('AuthWrapper Tests', () {
    testWidgets('shows MainScreen directly when auth state is loading', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const AuthWrapper(),
        authState: const AsyncValue.loading(),
      ));
      await tester.pump();

      expect(find.byType(MainScreen), findsOneWidget);
    });

    testWidgets('shows MainScreen when auth state has error', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const AuthWrapper(),
        authState: AsyncValue.error('Auth error', StackTrace.empty),
      ));
      await tester.pump();
      await tester.pump();

      expect(find.byType(MainScreen), findsOneWidget);
    });

    testWidgets('shows MainScreen when user is null (unauthenticated)', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const AuthWrapper(),
        authState: const AsyncValue.data(null),
      ));
      await tester.pump();
      await tester.pump();

      expect(find.byType(MainScreen), findsOneWidget);
    });

    testWidgets('shows EmailVerificationRequiredScreen if email not verified and not emulator', (tester) async {
      when(mockUser.emailVerified).thenReturn(false);

      await tester.pumpWidget(createTestApp(
        child: const AuthWrapper(),
        authState: AsyncValue.data(mockUser),
      ));
      await tester.pump();
      await tester.pump();
      
      expect(find.byType(EmailVerificationRequiredScreen), findsOneWidget);
    });

    testWidgets('shows TermsUpdateGate if user is verified but needs terms update', (tester) async {
      when(mockUser.emailVerified).thenReturn(true);

      await tester.pumpWidget(createTestApp(
        child: const AuthWrapper(),
        authState: AsyncValue.data(mockUser),
        needsTermsUpdate: true,
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.policy_outlined), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('shows MainScreen if user is verified and terms are up to date', (tester) async {
      when(mockUser.emailVerified).thenReturn(true);

      await tester.pumpWidget(createTestApp(
        child: const AuthWrapper(),
        authState: AsyncValue.data(mockUser),
        needsTermsUpdate: false,
      ));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(MainScreen), findsOneWidget);
    });

    group('TermsUpdateGate Interactions', () {
      testWidgets('Accept button is disabled initially and enabled after scrolling', (tester) async {
        when(mockUser.emailVerified).thenReturn(true);
        final longTerms = List.generate(50, (index) => 'Line $index of terms.').join('\n');

        await tester.pumpWidget(createTestApp(
          child: const AuthWrapper(),
          authState: AsyncValue.data(mockUser),
          needsTermsUpdate: true,
          termsState: AsyncValue.data(longTerms),
        ));
        await tester.pumpAndSettle();

        final acceptButtonFinder = find.byKey(const Key('btn-terms-accept'));
        expect(acceptButtonFinder, findsOneWidget);
        
        final modernButton = tester.widget<ModernButton>(acceptButtonFinder);
        expect(modernButton.onPressed, isNull, reason: 'Button should be disabled before scrolling');

        // Scroll to the bottom
        await tester.drag(find.byType(ListView), const Offset(0, -3000));
        await tester.pumpAndSettle();

        // Button should now be enabled
        final updatedButton = tester.widget<ModernButton>(acceptButtonFinder);
        expect(updatedButton.onPressed, isNotNull, reason: 'Button should be enabled after scrolling');
      });

      testWidgets('Accept button calls repository method when tapped', (tester) async {
        when(mockUser.emailVerified).thenReturn(true);
        when(mockUserRepository.recordTermsAcceptance()).thenAnswer((_) async {});
        final longTerms = List.generate(50, (index) => 'Line $index of terms.').join('\n');

        await tester.pumpWidget(createTestApp(
          child: const AuthWrapper(),
          authState: AsyncValue.data(mockUser),
          needsTermsUpdate: true,
          termsState: AsyncValue.data(longTerms), 
        ));
        await tester.pumpAndSettle();
        
        await tester.drag(find.byType(ListView), const Offset(0, -3000));
        await tester.pumpAndSettle();

        final acceptButtonFinder = find.byKey(const Key('btn-terms-accept'));
        await tester.tap(acceptButtonFinder);
        await tester.pump();
        
        verify(mockUserRepository.recordTermsAcceptance()).called(1);
      });
      
      testWidgets('Shows error SnackBar when repository call fails', (tester) async {
        when(mockUser.emailVerified).thenReturn(true);
        when(mockUserRepository.recordTermsAcceptance()).thenAnswer((_) => Future.error(Exception('Failed to accept')));
        final longTerms = List.generate(50, (index) => 'Line $index of terms.').join('\n');

        await tester.pumpWidget(createTestApp(
          child: const AuthWrapper(),
          authState: AsyncValue.data(mockUser),
          needsTermsUpdate: true,
          termsState: AsyncValue.data(longTerms), 
        ));
        await tester.pumpAndSettle();
        
        await tester.drag(find.byType(ListView), const Offset(0, -3000));
        await tester.pumpAndSettle();

        final acceptButtonFinder = find.byKey(const Key('btn-terms-accept'));
        await tester.tap(acceptButtonFinder);
        await tester.pumpAndSettle(); 
        
        expect(find.byType(SnackBar), findsOneWidget);
      });
      
      testWidgets('Shows loading indicator when terms are loading', (tester) async {
        when(mockUser.emailVerified).thenReturn(true);

        await tester.pumpWidget(createTestApp(
          child: const AuthWrapper(),
          authState: AsyncValue.data(mockUser),
          needsTermsUpdate: true,
          termsState: const AsyncValue.loading(), 
        ));
        await tester.pump();
        await tester.pump();

        expect(find.byType(ModernLoadingIndicator), findsOneWidget);
        
        // Let the fake loading future finish
        await tester.pump(const Duration(seconds: 1));
      });
      
      testWidgets('Shows error text when terms fail to load', (tester) async {
        when(mockUser.emailVerified).thenReturn(true);

        await tester.pumpWidget(createTestApp(
          child: const AuthWrapper(),
          authState: AsyncValue.data(mockUser),
          needsTermsUpdate: true,
          termsState: AsyncValue.error('Fetch failed', StackTrace.empty), 
        ));
        await tester.pumpAndSettle();

        expect(find.text('legal.terms_load_error'), findsOneWidget);
      });
    });
  });
}
