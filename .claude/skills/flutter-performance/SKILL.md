---
name: flutter-performance
description: Use when diagnosing frame drops, scroll jank, animation stutter, or slow screen transitions in OrignaGTA — covers overlay, DevTools, benchmarking, and OrignaGTA-specific hotspots.
---

# Flutter Performance Testing Guide

## Target
- **60 FPS** (120 FPS on ProMotion devices) = 16.6 ms per frame budget
- Always test in **Profile mode** on real hardware (debug mode has assertions that skew results)
- **8GB RAM constraint**: run one tool at a time; never profile + build simultaneously

---

## 1. Quick Check: Performance Overlay

```bash
flutter run --profile --dart-define=ENVIRONMENT=dev
# Then press 'P' in terminal to toggle overlay
```

What you see:
- **Top graph** = Raster thread (GPU)
- **Bottom graph** = UI thread (Dart)
- White line = 16 ms budget
- **Red bars** = Jank (dropped frames)

Red UI thread → optimize Dart code (reduce rebuilds, use `const`, memoize).
Red Raster thread → simplify rendering (`saveLayer`, clips, shadows, image decoding).

---

## 2. Flutter DevTools Performance View

```bash
flutter run --profile --dart-define=ENVIRONMENT=dev
# Click the DevTools link in terminal → Performance tab
```

Key workflow:
1. Enable: "Track widget builds", "Track layouts", "Track paints", "Enhance tracing"
2. Perform the slow action (scroll home feed, open checkout, animate bottom sheet)
3. Pause → click a red frame → **Frame Analysis** shows exactly what took too long
4. Use "Disable rendering layers" (clip, opacity, physical shape) to isolate root cause

---

## 3. Automated Benchmarking (Integration Tests + Timeline)

Add to `pubspec.yaml` dev_dependencies (already present — `integration_test: sdk: flutter`).

**Test template** (`integration_test/perf_<screen>_test.dart`):
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:origna_gta/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home feed scroll performance', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    final listFinder = find.byType(Scrollable).first;

    await binding.traceAction(() async {
      await tester.fling(listFinder, const Offset(0, -3000), 3000);
      await tester.pumpAndSettle();
    }, reportKey: 'home_scroll_timeline');
  });
}
```

**Driver** (`test_driver/perf_driver.dart`):
```dart
import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data != null) {
      final timeline = driver.Timeline.fromJson(
        data['home_scroll_timeline'] as Map<String, dynamic>,
      );
      final summary = driver.TimelineSummary.summarize(timeline);
      await summary.writeTimelineToFile('home_scroll', pretty: true, includeSummary: true);
    }
  },
);
```

**Run**:
```bash
cd origna_gta
flutter drive \
  --driver=test_driver/perf_driver.dart \
  --target=integration_test/perf_home_test.dart \
  --profile \
  --dart-define=ENVIRONMENT=dev
```

Results in `build/`:
- `home_scroll.timeline_summary.json` → avg/worst frame times, missed frames %

---

## 4. Custom Tracing (Pinpoint Specific Code)

```dart
import 'dart:developer' as developer;

developer.Timeline.startSync('checkout_total_calculation');
// expensive code here
developer.Timeline.finishSync();
```

Appears as a named block in DevTools Timeline → easy to spot expensive operations.

---

## 5. OrignaGTA-Specific Hot Spots to Check

| Screen | Likely bottleneck | Fix strategy |
|--------|------------------|--------------|
| Home feed | Product card list rebuilds | `const` constructors, `RepaintBoundary` around cards |
| Checkout | `ref.watch` on heavy providers | `select()` to narrow watched fields |
| Mascots (ShopMascot, CanadianMoose) | Every frame repaints via AnimatedBuilder | `shouldRepaint` returning `true` always — add field comparison |
| Order timeline | Shadow + gradient on every card | Cache gradient, use `RepaintBoundary` |
| Animations (FadeSlideIn) | Nested AnimatedBuilders | Already uses `AnimationController` — verify `const` child |

### MoosePainter / MascotPainter
Both mascot painters return `shouldRepaint: true` on every call. This causes full GPU repaints 60x/sec. Fix if jank occurs:
```dart
@override
bool shouldRepaint(covariant MoosePainter old) =>
    old.idleValue != idleValue ||
    old.jumpValue != jumpValue ||
    old.blinkValue != blinkValue ||
    old.earWiggle != earWiggle ||
    old.breathingValue != breathingValue ||
    old.lookTarget != lookTarget ||
    old.excitement != excitement;
```

---

## 6. Firebase Performance Monitoring (Production)

Already integrated via `firebase_performance` package. Key auto-captured metrics:
- HTTP traces (Dio requests to Cloud Functions)
- Screen render time

Add custom traces for slow operations:
```dart
import 'package:firebase_performance/firebase_performance.dart';

final trace = FirebasePerformance.instance.newTrace('checkout_payment_init');
await trace.start();
// ... Stripe PaymentSheet.init() ...
await trace.stop();
```

---

## Workflow for a Performance Audit Session

```
1. flutter build web --profile --dart-define=ENVIRONMENT=dev
2. firebase deploy --only hosting --project orignagta-dev
3. flutter run --profile --dart-define=ENVIRONMENT=dev (on physical device)
4. Press 'P' → check overlay (any red?)
5. Open DevTools → Performance → trace the 3 slowest screens
6. Fix bottlenecks → re-run overlay
7. For regressions: write integration_test/perf_*.dart, run with flutter drive --profile
```

---

## Common Fixes

| Symptom | Root cause | Fix |
|---------|-----------|-----|
| Scroll jank on product list | Widgets rebuilding on scroll | `const` constructors, `RepaintBoundary` |
| Animation stutter on checkout | Heavy provider rebuild | Use `select()` to narrow watch scope |
| Image loading jank | Images decoded on main thread | `precacheImage()`, use `cached_network_image` |
| `saveLayer` in raster thread | Opacity/blur widgets | Replace `Opacity` widget with `.withValues(alpha:)` |
| Font shader compilation | First render | `--cache-sksl` flag for warm-up |
