import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:origna_gta/screens/productdetails_screen.dart';
import 'package:origna_gta/features/products/products_provider.dart';
import 'package:origna_gta/models/generated/product_models.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import '../test_utils.dart';

@GenerateNiceMocks([MockSpec<User>()])
import 'product_details_screen_test.mocks.dart';

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

  group('ProductDetailScreen Smoke Test', () {
    testWidgets('renders product details correctly', (WidgetTester tester) async {
      // Use a very large size to avoid overflows in this complex screen
      tester.view.physicalSize = const Size(2000, 3000);
      tester.view.devicePixelRatio = 1.0;

      // Create a dummy product
      final testProduct = Product(
        productId: 'prod_123',
        name: 'Test Product',
        description: 'This is a test product description.',
        price: 99.99,
        sellerId: 'seller_123',
        categoryId: 1,
        imageUrls: ['https://example.com/image.jpg'],
        stockQuantity: 10,
        rating: 4.5,
        ratingCount: 10,
        createdAt: DateTime.now(),
        isDigital: false,
        freeShipping: true,
      );

      await tester.pumpWidget(
        TestWrapper(
          overrides: [
            currentUserProvider.overrideWithValue(mockUser),
            firestoreProvider.overrideWithValue(fakeFirestore),
            productByIdProvider('prod_123').overrideWith((ref) => Future.value(testProduct)),
          ],
          child: const ProductDetailScreen(productId: 'prod_123'),
        ),
      );

      // Use pump() instead of pumpAndSettle() due to infinite animations
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Test Product'), findsOneWidget);
      expect(find.text('\$99.99'), findsOneWidget);
      
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
