import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/widgets/orders/order_status_widgets.dart';

void main() {
  group('EmptyOrdersCard', () {
    testWidgets('renders without filter', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: EmptyOrdersCard()),
      ));
      expect(find.text('No orders yet'), findsOneWidget);
    });

    testWidgets('renders with filter label', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: EmptyOrdersCard(filterLabel: 'pending')),
      ));
      expect(find.text('No pending orders'), findsOneWidget);
    });
  });

  group('InfoChip', () {
    testWidgets('renders icon and label', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: InfoChip(icon: Icons.shopping_bag, label: '3 items')),
      ));
      expect(find.text('3 items'), findsOneWidget);
      expect(find.byIcon(Icons.shopping_bag), findsOneWidget);
    });
  });

  group('OrderSummaryCard', () {
    testWidgets('renders all fields', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OrderSummaryCard(
              orderId: 'ABC123',
              status: OrderStatus.confirmed,
              itemCount: 3,
              total: '\$49.99',
              date: 'Jan 1, 2026',
              sellerName: 'Test Shop',
            ),
          ),
        ),
      ));
      expect(find.textContaining('ABC123'), findsOneWidget);
      expect(find.text('\$49.99'), findsOneWidget);
      expect(find.text('Jan 1, 2026'), findsOneWidget);
      expect(find.text('Test Shop'), findsOneWidget);
      expect(find.text('3 items'), findsOneWidget);
    });

    testWidgets('renders without seller name', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OrderSummaryCard(
              orderId: 'XYZ',
              status: OrderStatus.pending,
              itemCount: 1,
              total: '\$9.99',
              date: 'Feb 1, 2026',
            ),
          ),
        ),
      ));
      expect(find.text('1 item'), findsOneWidget);
    });

    testWidgets('all status types render', (tester) async {
      for (final status in OrderStatus.values) {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OrderSummaryCard(
                orderId: 'O1',
                status: status,
                itemCount: 1,
                total: '\$10',
                date: 'Jan 1',
              ),
            ),
          ),
        ));
        await tester.pump();
        expect(find.byType(StatusBadge), findsOneWidget);
      }
    });
  });

  group('StatusBadge', () {
    testWidgets('renders for each status', (tester) async {
      for (final status in OrderStatus.values) {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: StatusBadge(status: status)),
        ));
        await tester.pump();
        expect(find.byType(StatusBadge), findsOneWidget);
      }
    });

    testWidgets('large variant', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: StatusBadge(status: OrderStatus.delivered, large: true)),
      ));
      await tester.pump();
      expect(find.byType(StatusBadge), findsOneWidget);
    });
  });
}
