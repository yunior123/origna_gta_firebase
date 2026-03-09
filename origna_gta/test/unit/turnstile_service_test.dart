import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/services/turnstile_service.dart';

void main() {
  group('TurnstileService VM Coverage', () {
    test('getToken returns null on VM', () async {
      final token = await TurnstileService.getToken();
      expect(token, isNull);
    });

    test('reset does not crash on VM', () {
      TurnstileService.reset();
    });
  });
}
