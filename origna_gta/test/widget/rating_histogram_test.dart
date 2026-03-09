import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/widgets/rating_histogram.dart';
import '../test_utils.dart';

void main() {
  setUp(() {
    initTestMocks();
  });

  group('RatingHistogram Widget Tests', () {
    testWidgets('renders correct counts and stars', (tester) async {
      // Use counts that don't collide with 1-5 star labels
      final counts = [100, 80, 60, 40, 20]; // 5, 4, 3, 2, 1 star counts
      final total = 300;

      await tester.pumpWidget(TestWrapper(
        child: RatingHistogram(counts: counts, total: total),
      ));
      await tester.pump();

      // Check star numbers
      expect(find.text('5'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      // Check counts
      expect(find.text('100'), findsOneWidget);
      expect(find.text('80'), findsOneWidget);
      expect(find.text('60'), findsOneWidget);
      expect(find.text('40'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);

      // Check LinearProgressIndicator presence
      expect(find.byType(LinearProgressIndicator), findsNWidgets(5));
    });

    testWidgets('handles zero total correctly', (tester) async {
      final counts = [0, 0, 0, 0, 0];
      final total = 0;

      await tester.pumpWidget(TestWrapper(
        child: RatingHistogram(counts: counts, total: total),
      ));
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsNWidgets(5));
      final indicators = tester.widgetList<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      for (final indicator in indicators) {
        expect(indicator.value, 0.0);
      }
    });
  });
}
