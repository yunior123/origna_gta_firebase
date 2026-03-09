import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/features/auth/auth_provider.dart';
import 'package:origna_gta/screens/home_screen.dart';

/// Documentation for MainScreen
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  bool _timedOut = false;
  Timer? _timeoutTimer;

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userProfileProvider);

    // Reset timeout flag once data arrives so future reloads work correctly
    ref.listen(userProfileProvider, (_, next) {
      if ((next.hasValue || next.hasError) && _timedOut) {
        setState(() => _timedOut = false);
      }
    });

    // If profile loading takes too long, show HomeScreen without profile data
    // User remains logged in (Firebase Auth), just without Firestore profile
    if (_timedOut && userProfileAsync.isLoading) {
      return const HomeScreen(userModel: null);
    }

    return userProfileAsync.when(
      // Show HomeScreen immediately - no loading indicator to avoid flash after splash
      loading: () => const HomeScreen(userModel: null),
      error: (error, stack) => const HomeScreen(userModel: null),
      data: (userModel) => HomeScreen(userModel: userModel),
    );
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Safety timeout: if user profile takes more than 3 seconds, show home anyway
    // This prevents infinite loading if Firestore is slow or unresponsive
    _timeoutTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        final userProfileAsync = ref.read(userProfileProvider);
        if (userProfileAsync.isLoading) {
          setState(() => _timedOut = true);
        }
      }
    });
  }
}
