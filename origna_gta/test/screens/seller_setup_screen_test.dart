import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:origna_gta/screens/seller_setup_screen.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import '../test_utils.dart';

@GenerateNiceMocks([MockSpec<User>()])
import 'seller_setup_screen_test.mocks.dart';

void main() {
  setUpAll(() {
    initTestMocks();
  });
  late MockUser mockUser;
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    mockUser = MockUser();
    fakeFirestore = FakeFirebaseFirestore();
    when(mockUser.uid).thenReturn('test_user_123');
  });

  group('SellerSetupScreen Smoke Test', () {
    testWidgets('renders seller setup complete screen correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestWrapper(
          overrides: [
            currentUserProvider.overrideWithValue(mockUser),
            firestoreProvider.overrideWithValue(fakeFirestore),
          ],
          child: const SellerSetupCompleteScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SellerSetupCompleteScreen), findsOneWidget);
    });

    testWidgets('renders seller setup refresh screen correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestWrapper(
          overrides: [
            currentUserProvider.overrideWithValue(mockUser),
            firestoreProvider.overrideWithValue(fakeFirestore),
          ],
          child: const SellerSetupRefreshScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SellerSetupRefreshScreen), findsOneWidget);
    });
  });
}
