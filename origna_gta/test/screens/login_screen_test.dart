import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:origna_gta/screens/login_screen.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/repositories/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../test_utils.dart';

@GenerateNiceMocks([MockSpec<AuthRepository>(), MockSpec<FirebaseAuth>()])
import 'login_screen_test.mocks.dart';

void main() {
  setUpAll(() {
    initTestMocks();
  });
  late MockAuthRepository mockAuthRepo;
  late MockFirebaseAuth mockAuth;

  setUp(() {
    mockAuthRepo = MockAuthRepository();
    mockAuth = MockFirebaseAuth();
  });

  group('LoginScreen Smoke Test', () {
    testWidgets('renders login screen correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestWrapper(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepo),
            firebaseAuthProvider.overrideWithValue(mockAuth),
          ],
          child: const LoginScreen(),
        ),
      );

      // Advance animations
      await tester.pumpAndSettle();

      expect(find.text('OrignaGta'), findsOneWidget);
      expect(find.byType(LoginScreenLayout), findsOneWidget);
      expect(find.byKey(const Key('login_email_field')), findsOneWidget);
      expect(find.byKey(const Key('login_password_field')), findsOneWidget);
      expect(find.byKey(const Key('login_submit_button')), findsOneWidget);
    });

    testWidgets('toggles between login and register mode', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        TestWrapper(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepo),
            firebaseAuthProvider.overrideWithValue(mockAuth),
          ],
          child: const LoginScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Initial mode is login
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.byKey(const Key('login_name_field')), findsNothing);

      // Scroll to toggle button
      final toggleButton = find.byKey(const Key('login_toggle_mode_button'));
      await tester.ensureVisible(toggleButton);
      await tester.pumpAndSettle();

      // Tap toggle button
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      // Should be in register mode
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.byKey(const Key('login_name_field')), findsOneWidget);

      // Reset physical size
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
