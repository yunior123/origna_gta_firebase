import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:origna_gta/utils/deferred_widget.dart';
import 'package:origna_gta/widgets/modern_loading_indicator.dart';
import '../test_utils.dart';

void main() {
  setUp(() {
    initTestMocks();
  });

  group('DeferredWidget Widget Tests', () {
    testWidgets('renders loading state initially', (tester) async {
      final completer = Completer<void>();
      
      await tester.pumpWidget(TestWrapper(
        child: DeferredWidget(
          loader: () => completer.future,
          builder: () => const Text('Loaded!'),
        ),
      ));
      await tester.pump();

      // debugDumpApp(); // Uncomment if still failing
      expect(find.byType(ModernLoadingIndicator), findsOneWidget);
    });

    testWidgets('renders builder content after loader completes', (tester) async {
      await tester.pumpWidget(TestWrapper(
        child: DeferredWidget(
          loader: () async => Future.value(),
          builder: () => const Text('Loaded!'),
        ),
      ));
      
      // FutureBuilder needs a frame to start, then another when future completes
      await tester.pump(); 
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Loaded!'), findsOneWidget);
    });

    testWidgets('renders error state if loader fails', (tester) async {
      await tester.pumpWidget(TestWrapper(
        child: DeferredWidget(
          loader: () async => throw Exception('Failed'),
          builder: () => const Text('Loaded!'),
        ),
      ));
      
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('common.failed_to_load_page'.tr()), findsOneWidget);
    });

    testWidgets('can retry after failure', (tester) async {
      int callCount = 0;
      
      await tester.pumpWidget(TestWrapper(
        child: DeferredWidget(
          loader: () async {
            callCount++;
            if (callCount == 1) throw Exception('Failed');
            return Future.value();
          },
          builder: () => const Text('Loaded!'),
        ),
      ));
      
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('common.retry'.tr()), findsOneWidget);
      expect(callCount, 1);

      await tester.tap(find.text('common.retry'.tr()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(callCount, 2);
      expect(find.text('Loaded!'), findsOneWidget);
    });
  });
}
