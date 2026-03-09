import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Controls the app-wide theme mode (light / dark / system).
/// Defaults to [ThemeMode.system] so the OS preference is respected on first launch.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
