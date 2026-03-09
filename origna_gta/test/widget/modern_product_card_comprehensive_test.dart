import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/widgets/modern_product_card.dart';
import '../test_utils.dart';

void main() {
  setUpAll(() {
    initTestMocks();
  });

  group('ModernProductCard Comprehensive Tests', () {
    testWidgets('renders regular product with all fields', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(TestWrapper(
        child: ModernProductCard(
          productName: 'Test Product',
          price: 99.99,
          imageUrl: '', // Use empty to avoid network image issues in tests
          sellerName: 'Best Seller',
          rating: 4.5,
          reviewCount: 10,
          onTap: () => tapped = true,
          shipFromCity: 'Toronto',
          shipFromProvince: 'ON',
          shipFromCountry: 'Canada',
        ),
      ));
      await tester.pump();
      
      expect(find.text('Test Product'), findsOneWidget);
      expect(find.text('Best Seller'), findsOneWidget);
      expect(find.textContaining('Toronto'), findsOneWidget);
      
      await tester.tap(find.byType(ModernProductCard));
      expect(tapped, isTrue);
    });

    testWidgets('renders on-sale product', (tester) async {
      await tester.pumpWidget(TestWrapper(
        child: ModernProductCard(
          productName: 'Sale Item',
          price: 50.0,
          compareAtPrice: 100.0,
          imageUrl: '',
          sellerName: 'S1',
          onTap: () {},
        ),
      ));
      await tester.pump();
      
      expect(find.textContaining('50.00'), findsOneWidget);
      expect(find.textContaining('100.00'), findsOneWidget);
    });

    testWidgets('renders out of stock state', (tester) async {
      await tester.pumpWidget(TestWrapper(
        child: ModernProductCard(
          productName: 'Out Item',
          price: 10.0,
          imageUrl: '',
          sellerName: 'S1',
          isOutOfStock: true,
          onTap: () {},
        ),
      ));
      await tester.pump();
      
      expect(find.textContaining('STOCK'), findsOneWidget);
    });

    testWidgets('renders trending HOT badge', (tester) async {
      await tester.pumpWidget(TestWrapper(
        child: ModernProductCard(
          productName: 'Hot Item',
          price: 10.0,
          imageUrl: '',
          sellerName: 'S1',
          isTrending: true,
          trendingScore: 80,
          onTap: () {},
        ),
      ));
      await tester.pump();
      
      expect(find.text('HOT'), findsOneWidget);
    });

    testWidgets('renders trending RISING badge', (tester) async {
      await tester.pumpWidget(TestWrapper(
        child: ModernProductCard(
          productName: 'Rising Item',
          price: 10.0,
          imageUrl: '',
          sellerName: 'S1',
          isTrending: true,
          trendingScore: 30,
          onTap: () {},
        ),
      ));
      await tester.pump();
      
      expect(find.text('RISING'), findsOneWidget);
    });

    testWidgets('handles different shipping location counts', (tester) async {
      // 2 locations
      await tester.pumpWidget(TestWrapper(
        child: ModernProductCard(
          productName: 'P1', price: 10, imageUrl: '', sellerName: 'S1', onTap: () {},
          shipFromCountries: ['Canada', 'USA'],
        ),
      ));
      await tester.pump();
      expect(find.textContaining('Canada · USA'), findsOneWidget);

      // 4 locations
      await tester.pumpWidget(TestWrapper(
        child: ModernProductCard(
          productName: 'P2', price: 10, imageUrl: '', sellerName: 'S1', onTap: () {},
          shipFromCountries: ['A', 'B', 'C', 'D'],
        ),
      ));
      await tester.pump();
      expect(find.textContaining('Ships from 4 locations'), findsOneWidget);
    });

    testWidgets('handles hover animation', (tester) async {
      await tester.pumpWidget(TestWrapper(
        child: ModernProductCard(
          productName: 'P1', price: 10, imageUrl: '', sellerName: 'S1', onTap: () {},
        ),
      ));
      await tester.pump();
      
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await tester.pump();
      
      await gesture.moveTo(tester.getCenter(find.byType(ModernProductCard)));
      await tester.pump(const Duration(milliseconds: 100));
      
      await gesture.moveTo(const Offset(1000, 1000)); // Move out
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
