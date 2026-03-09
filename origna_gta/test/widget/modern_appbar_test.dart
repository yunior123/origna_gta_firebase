import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/widgets/modern_appbar.dart';
import '../test_utils.dart';

void main() {
  setUp(() {
    initTestMocks();
  });

  group('ModernAppBar Widget Tests', () {
    testWidgets('renders title and back button by default', (tester) async {
      await tester.pumpWidget(const TestWrapper(
        child: Scaffold(
          appBar: ModernAppBar(title: 'Test Title'),
        ),
      ));
      await tester.pump();

      expect(find.text('Test Title'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    });

    testWidgets('can hide back button and show leading icon', (tester) async {
      await tester.pumpWidget(const TestWrapper(
        child: Scaffold(
          appBar: ModernAppBar(
            title: 'No Back',
            showBackButton: false,
            leadingIcon: Icon(Icons.menu),
          ),
        ),
      ));
      await tester.pump();

      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
      expect(find.byIcon(Icons.menu), findsOneWidget);
    });

    testWidgets('renders actions', (tester) async {
      await tester.pumpWidget(const TestWrapper(
        child: Scaffold(
          appBar: ModernAppBar(
            title: 'Actions',
            actions: [
              Icon(Icons.search, key: Key('search_icon')),
            ],
          ),
        ),
      ));
      await tester.pump();

      expect(find.byKey(const Key('search_icon')), findsOneWidget);
    });

    testWidgets('calls onBackPressed when provided', (tester) async {
      bool pressed = false;
      await tester.pumpWidget(TestWrapper(
        child: Scaffold(
          appBar: ModernAppBar(
            title: 'Callback',
            onBackPressed: () => pressed = true,
          ),
        ),
      ));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      expect(pressed, isTrue);
    });
  });

  group('ModernBottomNavBar Widget Tests', () {
    final items = [
      BottomNavItem(icon: Icons.home, label: 'Home'),
      BottomNavItem(icon: Icons.search, label: 'Search'),
    ];

    testWidgets('renders all items', (tester) async {
      await tester.pumpWidget(TestWrapper(
        child: Scaffold(
          bottomNavigationBar: ModernBottomNavBar(
            currentIndex: 0,
            onIndexChanged: (_) {},
            items: items,
          ),
        ),
      ));
      await tester.pump();

      expect(find.byIcon(Icons.home), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Search'), findsNothing); // Label only shown for active item
    });

    testWidgets('calls onIndexChanged on tap', (tester) async {
      int? changedIndex;
      await tester.pumpWidget(TestWrapper(
        child: Scaffold(
          bottomNavigationBar: ModernBottomNavBar(
            currentIndex: 0,
            onIndexChanged: (index) => changedIndex = index,
            items: items,
          ),
        ),
      ));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.search));
      expect(changedIndex, 1);
    });

    testWidgets('shows label only for active item', (tester) async {
      await tester.pumpWidget(TestWrapper(
        child: Scaffold(
          bottomNavigationBar: ModernBottomNavBar(
            currentIndex: 1,
            onIndexChanged: (_) {},
            items: items,
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('Home'), findsNothing);
      expect(find.text('Search'), findsOneWidget);
    });
  });
}
