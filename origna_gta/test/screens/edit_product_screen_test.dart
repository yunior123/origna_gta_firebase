import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:origna_gta/screens/editproduct_screen.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:origna_gta/models/generated/product_models.dart';
import '../test_utils.dart';

@GenerateNiceMocks([MockSpec<User>(), MockSpec<FirebaseFunctions>()])
import 'edit_product_screen_test.mocks.dart';

void main() {
  setUpAll(() {
    initTestMocks();
  });
  late MockUser mockUser;
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseFunctions mockFunctions;

  setUp(() {
    mockUser = MockUser();
    fakeFirestore = FakeFirebaseFirestore();
    mockFunctions = MockFirebaseFunctions();
    when(mockUser.uid).thenReturn('test_user_123');
  });

  group('EditProductScreen Smoke Test', () {
    testWidgets('renders edit product screen correctly', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1920);
      tester.view.devicePixelRatio = 1.0;

      final testProduct = Product(
        productId: 'prod_123',
        name: 'Existing Product',
        description: 'Existing description.',
        price: 49.99,
        sellerId: 'test_user_123',
        categoryId: 1,
        imageUrls: [],
        stockQuantity: 5,
        createdAt: DateTime.now(),
        isDigital: false,
      );

      await tester.pumpWidget(
        TestWrapper(
          overrides: [
            currentUserProvider.overrideWithValue(mockUser),
            firestoreProvider.overrideWithValue(fakeFirestore),
            firebaseFunctionsProvider.overrideWithValue(mockFunctions),
          ],
          child: EditProductScreen(product: testProduct),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Existing Product'), findsOneWidget);
      expect(find.text('Basic Information'), findsOneWidget);
      
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
