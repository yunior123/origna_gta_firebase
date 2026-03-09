import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:origna_gta/screens/orders_screen.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/features/orders/orders_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import '../test_utils.dart';

@GenerateNiceMocks([MockSpec<User>()])
import 'orders_screen_test.mocks.dart';

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

  group('OrdersScreen Smoke Test', () {
    testWidgets('renders orders screen correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestWrapper(
          overrides: [
            currentUserProvider.overrideWithValue(mockUser),
            firestoreProvider.overrideWithValue(fakeFirestore),
            buyerOrdersProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const OrdersScreen(),
        ),
      );

      // Use pump() because of infinite animations
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('My Orders'), findsOneWidget);
    });
  });
}
