import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'canadian_moose.dart';

final mooseControllerProvider = Provider<MooseController>((ref) {
  final controller = MooseController();
  ref.onDispose(controller.dispose);
  return controller;
});
