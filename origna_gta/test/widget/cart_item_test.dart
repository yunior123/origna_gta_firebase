import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:origna_gta/screens/cartitem_screen.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/features/cart/cart_provider.dart';
import '../test_utils.dart';

@GenerateNiceMocks([
  MockSpec<CartController>(),
])
import 'cart_item_test.mocks.dart';

void main() {
  late MockCartController mockCart;

  setUp(() {
    mockCart = MockCartController();
    initTestMocks();
  });

  final testItem = {
    Fields.productId: 'prod_123',
    Fields.name: 'Test Product',
    Fields.price: 99.99,
    Fields.imageUrls: ['https://example.com/image.jpg'],
    Fields.isDigital: false,
    Fields.buyerNote: 'Test note',
  };

  Widget createTestWidget({
    required Map<String, dynamic> item,
    int quantity = 1,
    VoidCallback? onRemove,
  }) {
    return TestWrapper(
      overrides: [
        cartControllerProvider.overrideWithValue(mockCart),
        cartItemQuantityProvider('cart_123').overrideWith((ref) => AsyncValue.data(quantity)),
      ],
      child: Scaffold(
        body: CartItemScreen(
          productId: item[Fields.productId] as String,
          cartItemId: 'cart_123',
          item: item,
          onRemove: onRemove ?? () {},
        ),
      ),
    );
  }

  group('CartItemScreen Widget Tests', () {
    testWidgets('renders item info correctly', (tester) async {
      await tester.pumpWidget(createTestWidget(item: testItem, quantity: 1));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Test Product'), findsOneWidget);
      expect(find.text('\$99.99'), findsOneWidget);
      expect(find.text('Test note'), findsOneWidget);
    });

    testWidgets('shows digital delivery label for digital items', (tester) async {
      final digitalItem = Map<String, dynamic>.from(testItem)..[Fields.isDigital] = true;
      await tester.pumpWidget(createTestWidget(item: digitalItem));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('cart.digital_instant_delivery'.tr()), findsOneWidget);
    });

    testWidgets('calculates total price correctly for multiple quantity', (tester) async {
      await tester.pumpWidget(createTestWidget(item: testItem, quantity: 2));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('\$199.98'), findsOneWidget);
      expect(find.text('\$99.99 ${'cart.each_suffix'.tr()}'), findsOneWidget);
    });

    testWidgets('can increase quantity', (tester) async {
      when(mockCart.updateQuantity(any, any)).thenAnswer((_) async => true);
      
      await tester.pumpWidget(createTestWidget(item: testItem, quantity: 1));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final plusBtn = find.bySemanticsLabel('btn-cart-qty-plus');
      await tester.tap(plusBtn);
      
      verify(mockCart.updateQuantity('cart_123', 2)).called(1);
    });

    testWidgets('can decrease quantity', (tester) async {
      when(mockCart.updateQuantity(any, any)).thenAnswer((_) async => true);
      
      await tester.pumpWidget(createTestWidget(item: testItem, quantity: 2));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final minusBtn = find.bySemanticsLabel('btn-cart-qty-minus');
      await tester.tap(minusBtn);
      
      verify(mockCart.updateQuantity('cart_123', 1)).called(1);
    });

    testWidgets('shows error when stock limit reached', (tester) async {
      when(mockCart.updateQuantity(any, any)).thenAnswer((_) async => false);
      
      await tester.pumpWidget(createTestWidget(item: testItem, quantity: 1));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final plusBtn = find.bySemanticsLabel('btn-cart-qty-plus');
      await tester.tap(plusBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('cart.stock_limit_reached'.tr()), findsOneWidget);
    });

    testWidgets('can save for later', (tester) async {
      when(mockCart.saveForLater(any, any)).thenAnswer((_) async => true);
      
      await tester.pumpWidget(createTestWidget(item: testItem));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byTooltip('cart.save_for_later'.tr()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      verify(mockCart.saveForLater('prod_123', 'cart_123')).called(1);
      expect(find.text('cart.saved_for_later'.tr()), findsOneWidget);
    });

    testWidgets('can add/edit note', (tester) async {
      await tester.pumpWidget(createTestWidget(item: testItem));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Tap on existing note to edit
      await tester.tap(find.text('Test note'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('cart.item_note_edit'.tr()), findsOneWidget);
      
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'New note');
      
      await tester.tap(find.text('cart.item_note_save'.tr()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      verify(mockCart.updateBuyerNote('cart_123', 'New note')).called(1);
    });

    testWidgets('can remove item via button', (tester) async {
      bool removed = false;
      await tester.pumpWidget(createTestWidget(item: testItem, onRemove: () => removed = true));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byTooltip('cart.remove_from_cart'.tr()));
      expect(removed, isTrue);
    });

    testWidgets('can remove item via swipe', (tester) async {
      bool removed = false;
      // Use no images to avoid shimmer
      final noImageItem = Map<String, dynamic>.from(testItem)..[Fields.imageUrls] = [];
      await tester.pumpWidget(createTestWidget(item: noImageItem, onRemove: () => removed = true));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
      // Dismissible takes time to complete
      await tester.pumpAndSettle();

      expect(removed, isTrue);
    });
   group('CartItemScreen Image Rendering', () {
    testWidgets('renders placeholder when no images', (tester) async {
      final noImageItem = Map<String, dynamic>.from(testItem)..[Fields.imageUrls] = [];
      await tester.pumpWidget(createTestWidget(item: noImageItem));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
    });

    testWidgets('renders single image', (tester) async {
      final singleImageItem = Map<String, dynamic>.from(testItem)..[Fields.imageUrls] = ['https://example.com/img1.jpg'];
      await tester.pumpWidget(createTestWidget(item: singleImageItem));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(ClipRRect), findsWidgets);
    });

    testWidgets('renders multiple images with counter', (tester) async {
      final multiImageItem = Map<String, dynamic>.from(testItem)..[Fields.imageUrls] = ['img1.jpg', 'img2.jpg'];
      await tester.pumpWidget(createTestWidget(item: multiImageItem));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('2'), findsOneWidget);
      expect(find.byIcon(Icons.collections), findsOneWidget);
    });
  });
  });
}
