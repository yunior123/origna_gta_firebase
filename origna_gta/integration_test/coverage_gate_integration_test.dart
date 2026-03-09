import "package:flutter_test/flutter_test.dart";
import "package:integration_test/integration_test.dart";
import "package:origna_gta/coverage_gate.dart";

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group("coverage gate integration", () {
    testWidgets("boundedAdd covers clamp branches", (tester) async {
      expect(boundedAdd(-10, 2, min: -5, max: 10), -5);
      expect(boundedAdd(40, 9, min: 0, max: 20), 20);
      expect(boundedAdd(4, 3, min: 0, max: 20), 7);
    });

    testWidgets("normalizeLabel covers empty and normalized branches", (
      tester,
    ) async {
      expect(normalizeLabel("   "), "unknown");
      expect(normalizeLabel("  READY "), "ready");
    });

    testWidgets("shouldProceed rejects when session is missing", (
      tester,
    ) async {
      expect(
        shouldProceed(
          hasSession: false,
          e2eHealthy: true,
          mode: CoverageMode.fast,
        ),
        isFalse,
      );
    });

    testWidgets("shouldProceed safe mode rejects unhealthy e2e", (
      tester,
    ) async {
      expect(
        shouldProceed(
          hasSession: true,
          e2eHealthy: false,
          mode: CoverageMode.safe,
        ),
        isFalse,
      );
    });

    testWidgets("shouldProceed safe mode accepts healthy e2e", (tester) async {
      expect(
        shouldProceed(
          hasSession: true,
          e2eHealthy: true,
          mode: CoverageMode.safe,
        ),
        isTrue,
      );
    });

    testWidgets("shouldProceed fast mode proceeds with a session", (
      tester,
    ) async {
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
