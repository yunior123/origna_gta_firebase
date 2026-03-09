import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:origna_gta/screens/main_screen.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import '../test_utils.dart';

import 'package:origna_gta/core/repositories/product_repository.dart';

@GenerateNiceMocks([MockSpec<User>(), MockSpec<ProductRepository>()])
import 'main_screen_test.mocks.dart';

void main() {
  late MockUser mockUser;
  late FakeFirebaseFirestore fakeFirestore;
  late MockProductRepository mockProductRepo;

  setUpAll(() {
    initTestMocks();
  });

  setUp(() {
    mockUser = MockUser();
    fakeFirestore = FakeFirebaseFirestore();
    mockProductRepo = MockProductRepository();
    when(mockUser.uid).thenReturn('test_user_123');
  });

  group('MainScreen Smoke Test', () {
    testWidgets('renders main screen correctly', (WidgetTester tester) async {
      when(mockProductRepo.fetchProducts(
        searchQuery: anyNamed('searchQuery'),
        categoryId: anyNamed('categoryId'),
        subcategory: anyNamed('subcategory'),
        lastDocument: anyNamed('lastDocument'),
        pageSize: anyNamed('pageSize'),
        sortOption: anyNamed('sortOption'),
        minPriceCents: anyNamed('minPriceCents'),
        maxPriceCents: anyNamed('maxPriceCents'),
      )).thenAnswer((_) async => ProductQueryResult(products: [], lastDocument: null, hasMore: false));

      await tester.pumpWidget(
        TestWrapper(
          overrides: [
            currentUserProvider.overrideWithValue(mockUser),
            firestoreProvider.overrideWithValue(fakeFirestore),
            productRepositoryProvider.overrideWithValue(mockProductRepo),
          ],
          child: const MainScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 5)); // Wait for 3s timer in initState

      expect(find.byType(MainScreen), findsOneWidget);
    });
  });
}
