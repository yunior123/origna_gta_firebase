import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:origna_gta/screens/profile_screen.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/routes.dart';
import 'package:origna_gta/features/auth/auth_provider.dart';
import 'package:origna_gta/features/profile/profile_viewmodel.dart';
import 'package:origna_gta/features/subscription/subscription_provider.dart';
import 'package:origna_gta/features/subscription/subscription_state.dart';
import 'package:origna_gta/core/theme_provider.dart';
import 'package:origna_gta/core/repositories/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:origna_gta/models/models.dart';
import 'package:origna_gta/widgets/modern_loading_indicator.dart';
import '../test_utils.dart';

@GenerateNiceMocks([
  MockSpec<User>(),
  MockSpec<UserInfo>(),
  MockSpec<ProfileViewModel>(),
  MockSpec<AuthRepository>(),
  MockSpec<FirebaseAuth>(),
])
import 'profile_screen_test.mocks.dart';

/// Duration long enough to settle FadeSlideIn animations (400ms + max 200ms delay)
const _animationDuration = Duration(seconds: 1);

void main() {
  setUpAll(() {
    initTestMocks();
  });

  late MockUser mockUser;
  late UserModel buyerUserModel;
  late UserModel sellerUserModel;
  late UserModel adminUserModel;
  late UserModel premiumUserModel;

  setUp(() {
    mockUser = MockUser();
    when(mockUser.uid).thenReturn('test_user_123');
    when(mockUser.email).thenReturn('test@example.com');
    when(mockUser.displayName).thenReturn('Test User');
    when(mockUser.emailVerified).thenReturn(true);
    when(mockUser.providerData).thenReturn([]);

    buyerUserModel = UserModel(
      uid: 'test_user_123',
      name: 'Test User',
      email: 'test@example.com',
      roles: const ['buyer'],
      isPremium: false,
      createdAt: DateTime(2026, 1, 1),
    );

    sellerUserModel = UserModel(
      uid: 'test_user_123',
      name: 'Seller User',
      email: 'seller@example.com',
      roles: const ['buyer', 'seller'],
      isPremium: false,
      createdAt: DateTime(2026, 1, 1),
    );

    adminUserModel = UserModel(
      uid: 'test_user_123',
      name: 'Admin User',
      email: 'admin@example.com',
      roles: const ['buyer', 'admin'],
      isPremium: false,
      createdAt: DateTime(2026, 1, 1),
    );

    premiumUserModel = UserModel(
      uid: 'test_user_123',
      name: 'Premium User',
      email: 'premium@example.com',
      roles: const ['buyer'],
      isPremium: true,
      notifyNewProducts: true,
      notifyTrending: true,
      createdAt: DateTime(2026, 1, 1),
      address: Address(
        street: '123 Main St',
        city: 'Toronto',
        state: 'ON',
        postalCode: 'M5V 1A1',
        country: 'Canada',
      ),
    );
  });

  /// Helper to build ProfileScreenLayout directly (avoids ConsumerWidget provider complexity)
  Widget buildLayout({
    required AsyncValue<UserModel?> userProfileAsync,
    User? currentUser,
    bool isExportLoading = false,
    ThemeMode themeMode = ThemeMode.light,
    bool isPremium = false,
    VoidCallback? onSignIn,
    VoidCallback? onSignOut,
    VoidCallback? onDeleteAccountRequested,
    VoidCallback? onExportData,
    void Function(ThemeMode)? onThemeChange,
    void Function(String)? onLanguageChange,
    List<Override> overrides = const [],
    Route<dynamic>? Function(RouteSettings)? onGenerateRoute,
  }) {
    return TestWrapper(
      overrides: overrides,
      onGenerateRoute: onGenerateRoute,
      child: ProfileScreenLayout(
        userProfileAsync: userProfileAsync,
        currentUser: currentUser,
        isExportLoading: isExportLoading,
        themeMode: themeMode,
        isPremium: isPremium,
        onSignIn: onSignIn ?? () {},
        onSignOut: onSignOut ?? () {},
        onDeleteAccountRequested: onDeleteAccountRequested ?? () {},
        onExportData: onExportData ?? () {},
        onThemeChange: onThemeChange ?? (_) {},
        onLanguageChange: onLanguageChange ?? (_) {},
      ),
    );
  }

  /// Pump enough to settle FadeSlideIn but not wait for infinite spinners
  Future<void> pumpLayout(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(_animationDuration);
  }

  group('ProfileScreen - Unauthenticated', () {
    testWidgets('shows sign-in prompt when user is not logged in', (tester) async {
      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: const AsyncValue.data(null),
          currentUser: null,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign in to see profile'), findsOneWidget);
      expect(find.byKey(const Key('profile_sign_in_button')), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('sign-in button calls onSignIn callback', (tester) async {
      var signInCalled = false;
      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: const AsyncValue.data(null),
          currentUser: null,
          onSignIn: () => signInCalled = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('profile_sign_in_button')));
      await tester.pump();

      expect(signInCalled, isTrue);
    });
  });

  group('ProfileScreen - Loading', () {
    testWidgets('shows loading indicator when profile is loading', (tester) async {
      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: const AsyncValue.loading(),
          currentUser: mockUser,
        ),
      );
      await tester.pump();

      expect(find.byType(ModernLoadingIndicator), findsOneWidget);
    });
  });

  group('ProfileScreen - Error', () {
    testWidgets('shows error state on profile load failure', (tester) async {
      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: AsyncValue.error(Exception('Network error'), StackTrace.current),
          currentUser: mockUser,
        ),
      );
      await pumpLayout(tester);

      expect(find.text('Error loading'), findsOneWidget);
    });
  });

  group('ProfileScreen - Setting Up', () {
    testWidgets('shows setting up view when user exists but profile is null', (tester) async {
      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: const AsyncValue.data(null),
          currentUser: mockUser,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Setting up...'), findsOneWidget);
      expect(find.byType(ModernLoadingIndicator), findsOneWidget);
    });
  });

  group('ProfileScreen - Buyer (non-premium)', () {
    testWidgets('shows buyer menu items', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: AsyncValue.data(buyerUserModel),
          currentUser: mockUser,
        ),
      );
      await pumpLayout(tester);

      // Profile header
      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('test@example.com'), findsOneWidget);

      // Navigation section
      expect(find.text('Navigation'), findsOneWidget);
      expect(find.byKey(const Key('profile_my_orders_button')), findsOneWidget);
      expect(find.text('My Orders'), findsOneWidget);

      // Buyer should see "Become a Seller"
      expect(find.byKey(const Key('profile_become_seller_button')), findsOneWidget);
      expect(find.text('Become a Seller'), findsOneWidget);

      // Should NOT show seller-specific buttons
      expect(find.byKey(const Key('profile_seller_orders_button')), findsNothing);
      expect(find.byKey(const Key('profile_seller_dashboard_button')), findsNothing);
      expect(find.byKey(const Key('profile_admin_panel_button')), findsNothing);

      // Non-premium should NOT see notifications button
      expect(find.byKey(const Key('profile_notifications_button')), findsNothing);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('shows settings section items', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: AsyncValue.data(buyerUserModel),
          currentUser: mockUser,
        ),
      );
      await pumpLayout(tester);

      expect(find.byKey(const Key('profile_address_button')), findsOneWidget);
      expect(find.byKey(const Key('profile_terms_button')), findsOneWidget);
      expect(find.byKey(const Key('profile_privacy_button')), findsOneWidget);
      expect(find.byKey(const Key('profile_language_button')), findsOneWidget);
      expect(find.byKey(const Key('profile_export_button')), findsOneWidget);
      expect(find.byKey(const Key('profile_theme_button')), findsOneWidget);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('shows premium section with upgrade prompt for non-premium', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: AsyncValue.data(buyerUserModel),
          currentUser: mockUser,
          isPremium: false,
        ),
      );
      await pumpLayout(tester);

      expect(find.text('Premium'), findsOneWidget);
      expect(find.text('Upgrade to premium'), findsOneWidget);
      // Should not show "Active" badge
      expect(find.text('Active'), findsNothing);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('shows profile completion bar for incomplete profile', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: AsyncValue.data(buyerUserModel),
          currentUser: mockUser,
        ),
      );
      await pumpLayout(tester);

      expect(find.text('Profile Completion'), findsOneWidget);
      // 1/4 steps complete (name set) = 25%
      expect(find.text('25%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('shows support section with app info', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: AsyncValue.data(buyerUserModel),
          currentUser: mockUser,
        ),
      );
      await pumpLayout(tester);

      expect(find.text('Support'), findsOneWidget);
      expect(find.text('App Info'), findsOneWidget);
      expect(find.byKey(const Key('profile_rate_app_button')), findsOneWidget);
      expect(find.byKey(const Key('profile_share_app_button')), findsOneWidget);
      expect(find.text('OrignaGTA'), findsOneWidget);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('shows messages and favorites menu items', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: AsyncValue.data(buyerUserModel),
          currentUser: mockUser,
        ),
      );
      await pumpLayout(tester);

      expect(find.byKey(const Key('profile_messages_button')), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
      expect(find.byKey(const Key('profile_favorites_button')), findsOneWidget);
      expect(find.text('Favorites'), findsOneWidget);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('shows sign out and delete account buttons', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: AsyncValue.data(buyerUserModel),
          currentUser: mockUser,
        ),
      );
      await pumpLayout(tester);

      expect(find.byKey(const Key('profile_sign_out_button')), findsOneWidget);
      expect(find.byKey(const Key('profile_delete_account_button')), findsOneWidget);
      expect(find.text('Delete Account'), findsOneWidget);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  group('ProfileScreen - Seller', () {
    testWidgets('shows seller-specific menu items', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: AsyncValue.data(sellerUserModel),
          currentUser: mockUser,
        ),
      );
      await pumpLayout(tester);

      // Header shows "Seller" badge
      expect(find.text('Seller'), findsOneWidget);
      expect(find.text('Seller User'), findsOneWidget);

      // Seller navigation items
      expect(find.byKey(const Key('profile_seller_orders_button')), findsOneWidget);
      expect(find.text('Seller Orders'), findsOneWidget);
      expect(find.byKey(const Key('profile_seller_dashboard_button')), findsOneWidget);
      expect(find.text('Seller Dashboard'), findsOneWidget);

      // Should NOT show "Become a Seller" or admin panel
      expect(find.byKey(const Key('profile_become_seller_button')), findsNothing);
      expect(find.byKey(const Key('profile_admin_panel_button')), findsNothing);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  group('ProfileScreen - Admin', () {
    testWidgets('shows admin panel button and admin badge', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: AsyncValue.data(adminUserModel),
          currentUser: mockUser,
        ),
      );
      await pumpLayout(tester);

      // Admin badge in header
      expect(find.text('Admin'), findsAtLeast(1));

      // Admin panel button
      expect(find.byKey(const Key('profile_admin_panel_button')), findsOneWidget);
      expect(find.text('Admin Panel'), findsOneWidget);
      expect(find.text('Platform management'), findsOneWidget);

      // Admin also has seller access (admin role implies isSeller)
      expect(find.byKey(const Key('profile_seller_orders_button')), findsOneWidget);
      expect(find.byKey(const Key('profile_seller_dashboard_button')), findsOneWidget);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  group('ProfileScreen - Premium User', () {
    testWidgets('shows premium badge and active status', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: AsyncValue.data(premiumUserModel),
          currentUser: mockUser,
          isPremium: true,
        ),
      );
      await pumpLayout(tester);

      // Premium active badge in subscription section
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Manage subscription'), findsOneWidget);

      // Premium users see notifications button
      expect(find.byKey(const Key('profile_notifications_button')), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('hides completion bar when profile is 100% complete', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: AsyncValue.data(premiumUserModel),
          currentUser: mockUser,
          isPremium: true,
        ),
      );
      await pumpLayout(tester);

      // 4/4 steps: name, address, notifications, premium
      expect(find.text('Profile Completion'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('shows premium icon on avatar', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: AsyncValue.data(premiumUserModel),
          currentUser: mockUser,
          isPremium: true,
        ),
      );
      await pumpLayout(tester);

      expect(find.byIcon(Icons.workspace_premium), findsAtLeast(1));

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  group('ProfileScreen - Theme Toggle', () {
    testWidgets('shows theme toggle with 3 mode icons', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: AsyncValue.data(buyerUserModel),
          currentUser: mockUser,
          themeMode: ThemeMode.light,
        ),
      );
      await pumpLayout(tester);

      expect(find.byKey(const Key('profile_theme_button')), findsOneWidget);
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('Change app appearance'), findsOneWidget);
      expect(find.byIcon(Icons.light_mode_rounded), findsAtLeast(1));
      expect(find.byIcon(Icons.brightness_auto_rounded), findsAtLeast(1));
      expect(find.byIcon(Icons.dark_mode_rounded), findsAtLeast(1));

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('calls onThemeChange when dark pill is tapped', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      ThemeMode? selectedTheme;
      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: AsyncValue.data(buyerUserModel),
          currentUser: mockUser,
          themeMode: ThemeMode.light,
          onThemeChange: (mode) => selectedTheme = mode,
        ),
      );
      await pumpLayout(tester);

      await tester.tap(find.byIcon(Icons.dark_mode_rounded).last);
      await tester.pump();

      expect(selectedTheme, equals(ThemeMode.dark));

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('calls onThemeChange for system mode', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      ThemeMode? selectedTheme;
      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: AsyncValue.data(buyerUserModel),
          currentUser: mockUser,
          themeMode: ThemeMode.dark,
          onThemeChange: (mode) => selectedTheme = mode,
        ),
      );
      await pumpLayout(tester);

      await tester.tap(find.byIcon(Icons.brightness_auto_rounded).last);
      await tester.pump();

      expect(selectedTheme, equals(ThemeMode.system));

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  group('ProfileScreen - User Interactions', () {
    testWidgets('sign-out button calls onSignOut callback', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      var signOutCalled = false;
      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: AsyncValue.data(buyerUserModel),
          currentUser: mockUser,
          onSignOut: () => signOutCalled = true,
        ),
      );
      await pumpLayout(tester);

      await tester.tap(find.byKey(const Key('profile_sign_out_button')));
      await tester.pump();

      expect(signOutCalled, isTrue);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('delete account button calls onDeleteAccountRequested', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      var deleteCalled = false;
      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: AsyncValue.data(buyerUserModel),
          currentUser: mockUser,
          onDeleteAccountRequested: () => deleteCalled = true,
        ),
      );
      await pumpLayout(tester);

      await tester.ensureVisible(find.byKey(const Key('profile_delete_account_button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('profile_delete_account_button')));
      await tester.pump();

      expect(deleteCalled, isTrue);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('export data button calls onExportData', (tester) async {
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1.0;

      var exportCalled = false;
      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: AsyncValue.data(buyerUserModel),
          currentUser: mockUser,
          onExportData: () => exportCalled = true,
        ),
      );
      await pumpLayout(tester);

      await tester.ensureVisible(find.byKey(const Key('profile_export_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap the GestureDetector descendant inside the export menu item
      final gestureDetector = find.descendant(
        of: find.byKey(const Key('profile_export_button')),
        matching: find.byType(GestureDetector),
      );
      await tester.tap(gestureDetector.first);
      await tester.pump();

      expect(exportCalled, isTrue);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('export button shows loading indicator when exporting', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: AsyncValue.data(buyerUserModel),
          currentUser: mockUser,
          isExportLoading: true,
        ),
      );
      await pumpLayout(tester);

      final exportButton = find.byKey(const Key('profile_export_button'));
      expect(exportButton, findsOneWidget);
      expect(
        find.descendant(of: exportButton, matching: find.byType(ModernLoadingIndicator)),
        findsOneWidget,
      );

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('language button calls onLanguageChange', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      String? selectedLang;
      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: AsyncValue.data(buyerUserModel),
          currentUser: mockUser,
          onLanguageChange: (lang) => selectedLang = lang,
        ),
      );
      await pumpLayout(tester);

      await tester.tap(find.byKey(const Key('profile_language_button')));
      await tester.pump();

      // English locale by default, tapping should switch to 'fr'
      expect(selectedLang, equals('fr'));

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  group('ProfileScreen - Navigation', () {
    testWidgets('my orders button navigates to orders', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      String? navigatedRoute;
      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: AsyncValue.data(buyerUserModel),
          currentUser: mockUser,
          onGenerateRoute: (settings) {
            navigatedRoute = settings.name;
            return MaterialPageRoute(builder: (_) => const Scaffold());
          },
        ),
      );
      await pumpLayout(tester);

      await tester.tap(find.byKey(const Key('profile_my_orders_button')));
      await tester.pump();
      await tester.pump();

      expect(navigatedRoute, equals(AppRoutes.orders));

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('become seller button navigates to seller registration', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      String? navigatedRoute;
      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: AsyncValue.data(buyerUserModel),
          currentUser: mockUser,
          onGenerateRoute: (settings) {
            navigatedRoute = settings.name;
            return MaterialPageRoute(builder: (_) => const Scaffold());
          },
        ),
      );
      await pumpLayout(tester);

      await tester.tap(find.byKey(const Key('profile_become_seller_button')));
      await tester.pump();
      await tester.pump();

      expect(navigatedRoute, equals(AppRoutes.sellerRegistration));

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('seller orders button navigates correctly', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      String? navigatedRoute;
      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: AsyncValue.data(sellerUserModel),
          currentUser: mockUser,
          onGenerateRoute: (settings) {
            navigatedRoute = settings.name;
            return MaterialPageRoute(builder: (_) => const Scaffold());
          },
        ),
      );
      await pumpLayout(tester);

      await tester.tap(find.byKey(const Key('profile_seller_orders_button')));
      await tester.pump();
      await tester.pump();

      expect(navigatedRoute, equals(AppRoutes.sellerOrders));

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('seller dashboard button navigates correctly', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      String? navigatedRoute;
      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: AsyncValue.data(sellerUserModel),
          currentUser: mockUser,
          onGenerateRoute: (settings) {
            navigatedRoute = settings.name;
            return MaterialPageRoute(builder: (_) => const Scaffold());
          },
        ),
      );
      await pumpLayout(tester);

      await tester.tap(find.byKey(const Key('profile_seller_dashboard_button')));
      await tester.pump();
      await tester.pump();

      expect(navigatedRoute, equals(AppRoutes.sellerProducts));

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('admin panel button navigates correctly', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      String? navigatedRoute;
      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: AsyncValue.data(adminUserModel),
          currentUser: mockUser,
          onGenerateRoute: (settings) {
            navigatedRoute = settings.name;
            return MaterialPageRoute(builder: (_) => const Scaffold());
          },
        ),
      );
      await pumpLayout(tester);

      await tester.tap(find.byKey(const Key('profile_admin_panel_button')));
      await tester.pump();
      await tester.pump();

      expect(navigatedRoute, equals(AppRoutes.adminPanel));

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('address button navigates correctly', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      String? navigatedRoute;
      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: AsyncValue.data(buyerUserModel),
          currentUser: mockUser,
          onGenerateRoute: (settings) {
            navigatedRoute = settings.name;
            return MaterialPageRoute(builder: (_) => const Scaffold());
          },
        ),
      );
      await pumpLayout(tester);

      await tester.tap(find.byKey(const Key('profile_address_button')));
      await tester.pump();
      await tester.pump();

      expect(navigatedRoute, equals(AppRoutes.addressManagement));

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('favorites button navigates correctly', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      String? navigatedRoute;
      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: AsyncValue.data(buyerUserModel),
          currentUser: mockUser,
          onGenerateRoute: (settings) {
            navigatedRoute = settings.name;
            return MaterialPageRoute(builder: (_) => const Scaffold());
          },
        ),
      );
      await pumpLayout(tester);

      await tester.tap(find.byKey(const Key('profile_favorites_button')));
      await tester.pump();
      await tester.pump();

      expect(navigatedRoute, equals(AppRoutes.favorites));

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('premium section navigates to subscription', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      String? navigatedRoute;
      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: AsyncValue.data(buyerUserModel),
          currentUser: mockUser,
          onGenerateRoute: (settings) {
            navigatedRoute = settings.name;
            return MaterialPageRoute(builder: (_) => const Scaffold());
          },
        ),
      );
      await pumpLayout(tester);

      await tester.tap(find.text('Premium'));
      await tester.pump();
      await tester.pump();

      expect(navigatedRoute, equals(AppRoutes.subscription));

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('messages button navigates to chat inbox', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      String? navigatedRoute;
      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: AsyncValue.data(buyerUserModel),
          currentUser: mockUser,
          onGenerateRoute: (settings) {
            navigatedRoute = settings.name;
            return MaterialPageRoute(builder: (_) => const Scaffold());
          },
        ),
      );
      await pumpLayout(tester);

      await tester.tap(find.byKey(const Key('profile_messages_button')));
      await tester.pump();
      await tester.pump();

      expect(navigatedRoute, equals(AppRoutes.chatInbox));

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('notifications button navigates correctly for premium', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      String? navigatedRoute;
      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: AsyncValue.data(premiumUserModel),
          currentUser: mockUser,
          isPremium: true,
          onGenerateRoute: (settings) {
            navigatedRoute = settings.name;
            return MaterialPageRoute(builder: (_) => const Scaffold());
          },
        ),
      );
      await pumpLayout(tester);

      await tester.tap(find.byKey(const Key('profile_notifications_button')));
      await tester.pump();
      await tester.pump();

      expect(navigatedRoute, equals(AppRoutes.notifications));

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  group('ProfileScreen - Profile Completion Bar', () {
    testWidgets('shows 50% when name and address are set', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      final userWithAddress = UserModel(
        uid: 'test_user_123',
        name: 'Test User',
        email: 'test@example.com',
        roles: const ['buyer'],
        isPremium: false,
        createdAt: DateTime(2026, 1, 1),
        address: Address(
          street: '123 Main St',
          city: 'Toronto',
          state: 'ON',
          postalCode: 'M5V 1A1',
          country: 'Canada',
        ),
      );

      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: AsyncValue.data(userWithAddress),
          currentUser: mockUser,
        ),
      );
      await pumpLayout(tester);

      expect(find.text('50%'), findsOneWidget);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('shows 75% when name, address, and notifications are set', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      final userWith3Steps = UserModel(
        uid: 'test_user_123',
        name: 'Test User',
        email: 'test@example.com',
        roles: const ['buyer'],
        isPremium: false,
        notifyNewProducts: true,
        createdAt: DateTime(2026, 1, 1),
        address: Address(
          street: '123 Main St',
          city: 'Toronto',
          state: 'ON',
          postalCode: 'M5V 1A1',
          country: 'Canada',
        ),
      );

      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: AsyncValue.data(userWith3Steps),
          currentUser: mockUser,
        ),
      );
      await pumpLayout(tester);

      expect(find.text('75%'), findsOneWidget);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  group('ProfileScreen - Email Verification', () {
    testWidgets('shows email verification view for unverified non-google user', (tester) async {
      final unverifiedUser = MockUser();
      when(unverifiedUser.uid).thenReturn('test_user_123');
      when(unverifiedUser.email).thenReturn('unverified@example.com');
      when(unverifiedUser.emailVerified).thenReturn(false);
      when(unverifiedUser.providerData).thenReturn([]);

      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: const AsyncValue.data(null),
          currentUser: unverifiedUser,
        ),
      );
      await pumpLayout(tester);

      expect(find.text('Verify Your Email'), findsOneWidget);
      expect(find.text('unverified@example.com'), findsOneWidget);
      expect(find.text('Check your inbox'), findsOneWidget);
      expect(find.text('Click the link'), findsOneWidget);
      expect(find.text('Come back here'), findsOneWidget);
    });

    testWidgets('shows verification action buttons', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;

      final unverifiedUser = MockUser();
      when(unverifiedUser.uid).thenReturn('test_user_123');
      when(unverifiedUser.email).thenReturn('unverified@example.com');
      when(unverifiedUser.emailVerified).thenReturn(false);
      when(unverifiedUser.providerData).thenReturn([]);

      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: const AsyncValue.data(null),
          currentUser: unverifiedUser,
        ),
      );
      await pumpLayout(tester);

      expect(find.text("I've Verified My Email"), findsOneWidget);
      expect(find.text('Resend Verification Email'), findsOneWidget);
      expect(find.text('Sign in with a different account'), findsOneWidget);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('does NOT show email verification for google user', (tester) async {
      final googleUser = MockUser();
      when(googleUser.uid).thenReturn('test_user_123');
      when(googleUser.email).thenReturn('google@example.com');
      when(googleUser.emailVerified).thenReturn(false);

      final googleProviderData = MockUserInfo();
      when(googleProviderData.providerId).thenReturn('google.com');
      when(googleUser.providerData).thenReturn([googleProviderData]);

      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: const AsyncValue.data(null),
          currentUser: googleUser,
        ),
      );
      // Use pump with duration instead of pumpAndSettle (ModernLoadingIndicator is infinite)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Google users skip email verification — should see "Setting up..." instead
      expect(find.text('Verify Your Email'), findsNothing);
      expect(find.text('Setting up...'), findsOneWidget);
    });
  });

  group('ProfileScreen - Profile Header', () {
    testWidgets('shows user initials in avatar', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: AsyncValue.data(buyerUserModel),
          currentUser: mockUser,
        ),
      );
      await pumpLayout(tester);

      expect(find.text('T'), findsOneWidget); // First letter of "Test User"

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('shows user name and email in header', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: AsyncValue.data(sellerUserModel),
          currentUser: mockUser,
        ),
      );
      await pumpLayout(tester);

      expect(find.text('Seller User'), findsOneWidget);
      expect(find.text('seller@example.com'), findsOneWidget);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('shows no role badge for regular buyer', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        buildLayout(
          userProfileAsync: AsyncValue.data(buyerUserModel),
          currentUser: mockUser,
        ),
      );
      await pumpLayout(tester);

      expect(find.text('Seller'), findsNothing);
      expect(find.text('Admin'), findsNothing);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  group('ProfileScreen - Delete Account Dialog (via ConsumerWidget)', () {
    testWidgets('opens delete account dialog via ProfileScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        TestWrapper(
          overrides: [
            currentUserProvider.overrideWithValue(mockUser),
            userProfileProvider.overrideWith((ref) => Stream.value(buyerUserModel)),
            subscriptionStreamProvider.overrideWith((ref) => Stream.value(null)),
            themeModeProvider.overrideWith((ref) => ThemeMode.light),
          ],
          child: const ProfileScreen(),
        ),
      );
      await pumpLayout(tester);

      // Scroll to and tap delete account
      await tester.ensureVisible(find.byKey(const Key('profile_delete_account_button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('profile_delete_account_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Dialog should appear
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Delete Account'), findsAtLeast(2)); // Title + button
      expect(find.text('This action is irreversible.'), findsOneWidget);
      expect(find.text('Type DELETE to confirm'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  group('ProfileScreen - ConsumerWidget Integration', () {
    testWidgets('renders full ProfileScreen for authenticated buyer', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        TestWrapper(
          overrides: [
            currentUserProvider.overrideWithValue(mockUser),
            userProfileProvider.overrideWith((ref) => Stream.value(buyerUserModel)),
            subscriptionStreamProvider.overrideWith((ref) => Stream.value(null)),
            themeModeProvider.overrideWith((ref) => ThemeMode.light),
          ],
          child: const ProfileScreen(),
        ),
      );
      await pumpLayout(tester);

      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('test@example.com'), findsOneWidget);
      expect(find.byKey(const Key('profile_my_orders_button')), findsOneWidget);
      expect(find.byKey(const Key('profile_sign_out_button')), findsOneWidget);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('renders profile with premium subscription info', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      final premiumSub = SubscriptionInfo(
        status: 'active',
        isPremium: true,
      );

      await tester.pumpWidget(
        TestWrapper(
          overrides: [
            currentUserProvider.overrideWithValue(mockUser),
            userProfileProvider.overrideWith((ref) => Stream.value(premiumUserModel)),
            subscriptionStreamProvider.overrideWith((ref) => Stream.value(premiumSub)),
            themeModeProvider.overrideWith((ref) => ThemeMode.light),
          ],
          child: const ProfileScreen(),
        ),
      );
      await pumpLayout(tester);

      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Manage subscription'), findsOneWidget);
      expect(find.byKey(const Key('profile_notifications_button')), findsOneWidget);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('renders sign-in view via ConsumerWidget when logged out', (tester) async {
      await tester.pumpWidget(
        TestWrapper(
          overrides: [
            currentUserProvider.overrideWithValue(null),
            userProfileProvider.overrideWith((ref) => Stream.value(null)),
            subscriptionStreamProvider.overrideWith((ref) => Stream.value(null)),
          ],
          child: const ProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign in to see profile'), findsOneWidget);
      expect(find.byKey(const Key('profile_sign_in_button')), findsOneWidget);
    });
  });
}
