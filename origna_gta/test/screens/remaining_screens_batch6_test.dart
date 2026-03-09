import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:origna_gta/screens/addressmanagement_screen.dart';
import 'package:origna_gta/screens/editaddress_screen.dart';
import 'package:origna_gta/screens/notifications_screen.dart';
import 'package:origna_gta/screens/ordersuccess_screen.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import '../test_utils.dart';

@GenerateNiceMocks([MockSpec<User>()])
import 'remaining_screens_batch6_test.mocks.dart';

void main() {
  late MockUser mockUser;
  late FakeFirebaseFirestore fakeFirestore;

  setUpAll(() {
    initTestMocks();
  });

  setUp(() {
    mockUser = MockUser();
    fakeFirestore = FakeFirebaseFirestore();
    when(mockUser.uid).thenReturn('test_user_123');
  });

  Future<void> pumpResilient(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(
      TestWrapper(
        overrides: [
          currentUserProvider.overrideWithValue(mockUser),
          firestoreProvider.overrideWithValue(fakeFirestore),
        ],
        child: widget,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    try {
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
    } catch (_) {}
  }

  group('Remaining Screens Batch 6 Smoke Tests', () {
    testWidgets('renders AddressManagementScreen', (tester) async {
      await pumpResilient(tester, const AddressManagementScreen());
      expect(find.byType(AddressManagementScreen), findsOneWidget);
    });

    testWidgets('renders AddEditAddressScreen (New)', (tester) async {
      await pumpResilient(tester, const AddEditAddressScreen());
      expect(find.byType(AddEditAddressScreen), findsOneWidget);
    });

    testWidgets('renders NotificationsScreen', (tester) async {
      await pumpResilient(tester, const NotificationsScreen());
      expect(find.byType(NotificationsScreen), findsOneWidget);
    });

    testWidgets('renders OrderSuccessScreen', (tester) async {
      await pumpResilient(tester, const OrderSuccessScreen(orderId: 'o1'));
      expect(find.byType(OrderSuccessScreen), findsOneWidget);
    });
  });
}
