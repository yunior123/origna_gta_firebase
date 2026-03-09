import "package:flutter_test/flutter_test.dart";
import "package:origna_gta/coverage_gate.dart";

void main() {
  group("boundedAdd", () {
    test("returns clamped minimum when below range", () {
      expect(boundedAdd(-10, 2, min: -5, max: 10), -5);
    });

    test("returns clamped maximum when above range", () {
      expect(boundedAdd(40, 9, min: 0, max: 20), 20);
    });

    test("returns exact sum when inside range", () {
      expect(boundedAdd(4, 3, min: 0, max: 20), 7);
    });
  });

  group("normalizeLabel", () {
    test("returns unknown for blank values", () {
      expect(normalizeLabel("   "), "unknown");
    });

    test("trims and lowercases values", () {
      expect(normalizeLabel("  READY "), "ready");
    });
  });

  group("shouldProceed", () {
    test("rejects when session is missing", () {
      expect(
        shouldProceed(
          hasSession: false,
          e2eHealthy: true,
          mode: CoverageMode.fast,
        ),
        isFalse,
      );
    });

    test("safe mode rejects unhealthy e2e", () {
      expect(
        shouldProceed(
          hasSession: true,
          e2eHealthy: false,
          mode: CoverageMode.safe,
        ),
        isFalse,
      );
    });

    test("safe mode accepts healthy e2e", () {
      expect(
        shouldProceed(
          hasSession: true,
          e2eHealthy: true,
          mode: CoverageMode.safe,
        ),
        isTrue,
      );
    });

    test("fast mode proceeds with a session even when e2e is unhealthy", () {
      expect(
        shouldProceed(
          hasSession: true,
          e2eHealthy: false,
          mode: CoverageMode.fast,
        ),
        isTrue,
      );
    });
  });
}
