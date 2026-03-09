import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/widgets/modern_product_card.dart';
import '../test_utils.dart';

void main() {
  setUpAll(() {
    initTestMocks();
  });

  group('ModernProductCard Widget Tests', () {
    testWidgets('renders basic product information correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestWrapper(
          child: ModernProductCard(
            productName: 'Modern Chair',
            price: 199.99,
            imageUrl: '', // Empty to test fallback
            sellerName: 'Design Studio',
            onTap: () {},
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Modern Chair'), findsOneWidget);
      expect(find.text('Design Studio'), findsOneWidget);
      expect(find.text('\$199.99'), findsOneWidget);
      // Fallback icon since image is empty
      expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
    });

    testWidgets('triggers onTap when card is pressed', (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        TestWrapper(
          child: ModernProductCard(
            productName: 'Tap Test',
            price: 10.0,
            imageUrl: '',
            sellerName: 'Seller',
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.pump();

      await tester.tap(find.byType(ModernProductCard));
      expect(tapped, isTrue);
    });

    testWidgets('shows out of stock overlay and disables add to cart', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestWrapper(
          child: ModernProductCard(
            productName: 'Out of Stock Item',
            price: 50.0,
            imageUrl: '',
            sellerName: 'Seller',
            onTap: () {},
            isOutOfStock: true,
            onAddToCart: () {},
          ),
        ),
      );

      await tester.pump();

      // Verify "Out of Stock" label
      expect(find.text('OUT OF STOCK'), findsOneWidget);
      
      // Add to cart button should NOT be rendered
      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets('renders sale price and compare at price', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestWrapper(
          child: ModernProductCard(
            productName: 'Sale Item',
            price: 80.0,
            compareAtPrice: 100.0,
            imageUrl: '',
            sellerName: 'Seller',
            onTap: () {},
          ),
        ),
      );

      await tester.pump();

      expect(find.text('\$80.00'), findsOneWidget);
      expect(find.text('\$100.00'), findsOneWidget);
    });

    testWidgets('renders trending badges (HOT and RISING)', (WidgetTester tester) async {
      // Test HOT
      await tester.pumpWidget(
        TestWrapper(
          child: ModernProductCard(
            productName: 'Hot Item',
            price: 10.0,
            imageUrl: '',
            sellerName: 'Seller',
            onTap: () {},
            isTrending: true,
            trendingScore: 60,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('HOT'), findsOneWidget);

      // Test RISING
      await tester.pumpWidget(
        TestWrapper(
          child: ModernProductCard(
            productName: 'Rising Item',
            price: 10.0,
            imageUrl: '',
            sellerName: 'Seller',
            onTap: () {},
            isTrending: true,
            trendingScore: 30,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('RISING'), findsOneWidget);
    });

    testWidgets('calculates ship from label correctly for multiple locations', (WidgetTester tester) async {
      // 2 locations
      await tester.pumpWidget(
        TestWrapper(
          child: ModernProductCard(
            productName: 'Multi Ship',
            price: 10.0,
            imageUrl: '',
            sellerName: 'Seller',
            onTap: () {},
            shipFromCountries: ['Canada', 'USA'],
          ),
        ),
      );
      await tester.pump();
      // "Ships from Canada, USA" (calculated in widget)
      expect(find.textContaining('Ships from'), findsOneWidget);

      // 5 locations (worldwide)
      await tester.pumpWidget(
        TestWrapper(
          child: ModernProductCard(
            productName: 'Global Ship',
            price: 10.0,
            imageUrl: '',
            sellerName: 'Seller',
            onTap: () {},
            shipFromCountries: ['Canada', 'USA', 'UK', 'France', 'Japan'],
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Ships from 5 locations'), findsOneWidget);
    });

    testWidgets('triggers add to cart callback', (WidgetTester tester) async {
      bool added = false;
      await tester.pumpWidget(
        TestWrapper(
          child: ModernProductCard(
            productName: 'Cart Item',
            price: 10.0,
            imageUrl: '',
            sellerName: 'Seller',
            onTap: () {},
            onAddToCart: () => added = true,
          ),
        ),
      );

      await tester.pump();

      final addBtn = find.byIcon(Icons.add);
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      expect(added, isTrue);
    });
  });
}
