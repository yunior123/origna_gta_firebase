import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/features/auth/auth_provider.dart';
import 'package:origna_gta/features/cart/cart_provider.dart';
import 'package:origna_gta/features/products/products_provider.dart';
import 'package:origna_gta/features/qa/qa_provider.dart';
import 'package:origna_gta/features/subscription/subscription_provider.dart';
import 'package:origna_gta/models/generated/models.dart';
import 'package:origna_gta/models/models.dart' as models;
import 'package:origna_gta/screens/productdetails_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_utils.dart';
@GenerateNiceMocks([
  MockSpec<auth.User>(),
  MockSpec<auth.FirebaseAuth>(),
  MockSpec<FirebaseFirestore>(),
  MockSpec<CollectionReference<Map<String, dynamic>>>(as: #MockCollectionReferenceMap),
  MockSpec<DocumentReference<Map<String, dynamic>>>(as: #MockDocumentReferenceMap),
  MockSpec<DocumentSnapshot<Map<String, dynamic>>>(as: #MockDocumentSnapshotMap),
  MockSpec<Query<Map<String, dynamic>>>(as: #MockQueryMap),
  MockSpec<QuerySnapshot<Map<String, dynamic>>>(as: #MockQuerySnapshotMap),
  MockSpec<QueryDocumentSnapshot<Map<String, dynamic>>>(as: #MockQueryDocumentSnapshotMap),
  MockSpec<FirebaseFunctions>(),
  MockSpec<HttpsCallable>(),
  MockSpec<HttpsCallableResult>(),
  MockSpec<CartController>(),
])
import 'product_details_screen_test.mocks.dart';

void main() {
  late MockUser mockUser;
  late MockFirebaseAuth mockAuth;
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReferenceMap mockCollection;
  late MockDocumentReferenceMap mockDoc;
  late MockDocumentSnapshotMap mockSnapshot;
  late MockQueryMap mockQuery;
  late MockQuerySnapshotMap mockQuerySnapshot;
  late MockFirebaseFunctions mockFunctions;
  late MockHttpsCallable mockCallable;
  late MockHttpsCallableResult mockResult;
  late MockCartController mockCartController;

  setUp(() {
    mockUser = MockUser();
    mockAuth = MockFirebaseAuth();
    mockFirestore = MockFirebaseFirestore();
    mockCollection = MockCollectionReferenceMap();
    mockDoc = MockDocumentReferenceMap();
    mockSnapshot = MockDocumentSnapshotMap();
    mockQuery = MockQueryMap();
    mockQuerySnapshot = MockQuerySnapshotMap();
    mockFunctions = MockFirebaseFunctions();
    mockCallable = MockHttpsCallable();
    mockResult = MockHttpsCallableResult();
    mockCartController = MockCartController();

    when(mockUser.uid).thenReturn('u1');
    when(mockUser.email).thenReturn('test@example.com');
    when(mockUser.emailVerified).thenReturn(true);
    when(mockUser.providerData).thenReturn([]);

    when(mockAuth.authStateChanges()).thenAnswer((_) => Stream.value(mockUser));
    when(mockAuth.currentUser).thenReturn(mockUser);

    SharedPreferences.setMockInitialValues({});
    initTestMocks();

    when(mockFirestore.collection(any)).thenReturn(mockCollection);
    when(mockCollection.doc(any)).thenReturn(mockDoc);
    when(mockDoc.get()).thenAnswer((_) async => mockSnapshot);
    when(mockSnapshot.exists).thenReturn(false);

    when(mockCollection.where(any, isEqualTo: anyNamed('isEqualTo'))).thenReturn(mockQuery);
    when(mockQuery.where(any, isEqualTo: anyNamed('isEqualTo'))).thenReturn(mockQuery);
    when(mockQuery.limit(any)).thenReturn(mockQuery);
    when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
    when(mockQuerySnapshot.docs).thenReturn([]);

    when(mockFunctions.httpsCallable(any)).thenReturn(mockCallable);
    when(mockCallable.call(any)).thenAnswer((_) async => mockResult);
  });

  final testProduct = Product(
    productId: 'p1',
    name: 'Honey',
    price: 10.0,
    imageUrls: const ['https://example.com/img.jpg'],
    description: 'Sweet honey from Canada.',
    sellerId: 's1',
    stockQuantity: 10,
    categoryId: 1,
    createdAt: DateTime.now(),
    isDigital: false,
    rating: 4.5,
    ratingCount: 10,
    isLocalDeliveryOnly: false,
    sellerAddress: const Address(street: 'S', city: 'C', state: 'ON', postalCode: 'M1M 1M1', country: 'CA'),
  );

  Widget createTestApp({required Widget child, List<Override> overrides = const []}) {
    return TestWrapper(overrides: overrides, child: child);
  }

  group('ProductDetailScreen Comprehensive Tests', () {
    testWidgets('renders all product sections', (tester) async {
      tester.view.physicalSize = const Size(2000, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestApp(
          overrides: [
            productByIdProvider('p1').overrideWith((ref) => testProduct),
            userProfileProvider.overrideWith(
              (ref) => Stream.value(models.UserModel(uid: 'u1', name: 'User', email: 'e', roles: const ['buyer'], createdAt: DateTime.now())),
            ),
            authStateProvider.overrideWith((ref) => Stream.value(mockUser)),
            currentUserProvider.overrideWithValue(mockUser),
            firebaseAuthProvider.overrideWithValue(mockAuth),
            subscriptionStreamProvider.overrideWith((ref) => const Stream.empty()),
            qaListProvider('p1').overrideWith((ref) => const Stream.empty()),
            firestoreProvider.overrideWithValue(mockFirestore),
            cartControllerProvider.overrideWithValue(mockCartController),
          ],
          child: const ProductDetailScreen(productId: 'p1'),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Honey'), findsWidgets);
      expect(find.textContaining('Sweet honey'), findsOneWidget);
    });

    testWidgets('handles variant selection', (tester) async {
      tester.view.physicalSize = const Size(2000, 4000);
      final variantProduct = testProduct.copyWith(
        hasVariants: true,
        variantOptions: const [
          VariantOption(name: 'Size', values: ['Small', 'Large']),
        ],
        variants: [
          const ProductVariant(variantId: 'v1', optionValues: {'Size': 'Small'}, priceCents: 1000, stockQuantity: 5, sku: 'S1'),
          const ProductVariant(variantId: 'v2', optionValues: {'Size': 'Large'}, priceCents: 1500, stockQuantity: 2, sku: 'L1'),
        ],
      );

      await tester.pumpWidget(
        createTestApp(
          overrides: [
            productByIdProvider('p1').overrideWith((ref) => variantProduct),
            userProfileProvider.overrideWith(
              (ref) => Stream.value(models.UserModel(uid: 'u1', name: 'User', email: 'e', roles: const ['buyer'], createdAt: DateTime.now())),
            ),
            authStateProvider.overrideWith((ref) => Stream.value(mockUser)),
            currentUserProvider.overrideWithValue(mockUser),
            firebaseAuthProvider.overrideWithValue(mockAuth),
            subscriptionStreamProvider.overrideWith((ref) => const Stream.empty()),
            qaListProvider('p1').overrideWith((ref) => const Stream.empty()),
            firestoreProvider.overrideWithValue(mockFirestore),
            cartControllerProvider.overrideWithValue(mockCartController),
          ],
          child: const ProductDetailScreen(productId: 'p1'),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      final largeOption = find.text('Large');
      await tester.ensureVisible(largeOption);
      await tester.tap(largeOption);
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('15.00'), findsAtLeast(1));
    });

    testWidgets('add to cart interaction', (tester) async {
      tester.view.physicalSize = const Size(2000, 4000);
      when(mockCartController.addToCart(any, any, variantId: anyNamed('variantId'))).thenAnswer((_) async => true);

      await tester.pumpWidget(
        createTestApp(
          overrides: [
            productByIdProvider('p1').overrideWith((ref) => testProduct),
            userProfileProvider.overrideWith(
              (ref) => Stream.value(models.UserModel(uid: 'u1', name: 'User', email: 'e', roles: const ['buyer'], createdAt: DateTime.now())),
            ),
            authStateProvider.overrideWith((ref) => Stream.value(mockUser)),
            currentUserProvider.overrideWithValue(mockUser),
            firebaseAuthProvider.overrideWithValue(mockAuth),
            subscriptionStreamProvider.overrideWith((ref) => const Stream.empty()),
            qaListProvider('p1').overrideWith((ref) => const Stream.empty()),
            firestoreProvider.overrideWithValue(mockFirestore),
            cartControllerProvider.overrideWithValue(mockCartController),
          ],
          child: const ProductDetailScreen(productId: 'p1'),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      final cartBtn = find.byKey(const Key('product_add_to_cart_button'));
      await tester.ensureVisible(cartBtn);
      await tester.tap(cartBtn);
      await tester.pump(const Duration(seconds: 1));

      verify(mockCartController.addToCart('p1', 1, variantId: null)).called(1);
    });
  });
}
