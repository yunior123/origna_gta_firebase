import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'shop_mascot.dart';

/// Global provider for the mascot controller (can be overridden per screen if needed)
final mascotControllerProvider = Provider<MascotController>((ref) {
  final controller = MascotController();
  ref.onDispose(controller.dispose);
  return controller;
});
