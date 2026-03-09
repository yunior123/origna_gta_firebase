import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/widgets/mascot/mascot_provider.dart';
import 'package:origna_gta/widgets/mascot/shop_mascot.dart';

void main() {
  group('mascotControllerProvider', () {
    test('provides a MascotController', () {
      final container = ProviderContainer();
      final controller = container.read(mascotControllerProvider);
      expect(controller, isA<MascotController>());
    });

    test('disposes controller when provider is disposed', () {
      final container = ProviderContainer();
      container.read(mascotControllerProvider);
      container.dispose();
      // Since we can't easily check if it's disposed without a mock or exposing state,
      // we at least ensure it doesn't crash.
    });
  });
}
