import 'dart:async';
import 'package:easy_localization/easy_localization.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Silence EasyLocalization warnings globally for all tests to avoid console noise.
  // Many tests don't need real translations or use MaterialApp directly.
  EasyLocalization.logger.enableBuildModes = [];
  
  await testMain();
}
