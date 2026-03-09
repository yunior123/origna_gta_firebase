import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:origna_gta/screens/common_screens.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/features/auth/auth_provider.dart';
import 'package:origna_gta/models/models.dart' as models;
import 'package:firebase_auth/firebase_auth.dart';
import '../test_utils.dart';

@GenerateNiceMocks([
  MockSpec<User>(),
  MockSpec<FirebaseAuth>(),
])
import 'common_screens_test.mocks.dart';

void main() {
  late MockUser mockUser;
  late MockFirebaseAuth mockAuth;

  setUpAll(() {
    initTestMocks();
  });

  setUp(() {
    mockUser = MockUser();
    mockAuth = MockFirebaseAuth();
    
    when(mockAuth.authStateChanges()).thenAnswer((_) => Stream.value(mockUser));
    when(mockUser.uid).thenReturn('test_user_123');
    when(mockUser.email).thenReturn('test@example.com');
    when(mockUser.emailVerified).thenReturn(true);
    when(mockUser.providerData).thenReturn([]);
  });

  group('Common Screens Smoke Tests', () {
    testWidgets('pumps AdminRequiredGate (Admin)', (tester) async {
      final adminUser = models.UserModel(
        uid: 'admin_123',
        name: 'Admin',
        email: 'admin@example.com',
        roles: ['admin'],
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(TestWrapper(
        overrides: [
          userProfileProvider.overrideWith((ref) => Stream.value(adminUser)),
        ],
        child: const AdminRequiredGate(child: Text('Admin Content')),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Admin Content'), findsOneWidget);
    });

    testWidgets('pumps AdminRequiredGate (Non-Admin)', (tester) async {
      final normalUser = models.UserModel(
        uid: 'user_123',
        name: 'User',
        email: 'user@example.com',
        roles: ['buyer'],
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(TestWrapper(
        overrides: [
          userProfileProvider.overrideWith((ref) => Stream.value(normalUser)),
        ],
        child: const AdminRequiredGate(child: Text('Admin Content')),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Admin Content'), findsNothing);
      expect(find.text('Access Denied'), findsOneWidget);
    });

    testWidgets('pumps AuthRequiredGate (Authenticated)', (tester) async {
      await tester.pumpWidget(TestWrapper(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(mockUser)),
          userProfileProvider.overrideWith((ref) => Stream.value(models.UserModel(
            uid: 'u1', name: 'N', email: 'e', roles: [], createdAt: DateTime.now()
          ))),
        ],
        child: const AuthRequiredGate(child: Text('Auth Content')),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Auth Content'), findsOneWidget);
    });

    testWidgets('pumps AuthRequiredGate (Unauthenticated)', (tester) async {
      await tester.pumpWidget(TestWrapper(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const AuthRequiredGate(child: Text('Auth Content')),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Auth Content'), findsNothing);
      expect(find.text('Please sign in'), findsOneWidget);
    });

    testWidgets('pumps ErrorScreen', (tester) async {
      await tester.pumpWidget(const TestWrapper(
        child: ErrorScreen(message: 'Something went wrong'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Something went wrong'), findsOneWidget);
    });

    testWidgets('pumps EmailVerificationRequiredScreen', (tester) async {
      await tester.pumpWidget(TestWrapper(
        overrides: [
          currentUserProvider.overrideWithValue(mockUser),
        ],
        child: const EmailVerificationRequiredScreen(),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(EmailVerificationRequiredScreen), findsOneWidget);
    });
  });
}
