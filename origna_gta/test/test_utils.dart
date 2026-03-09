import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mock_asset_loader.dart';

/// A wrapper to provide necessary context for widget tests
class TestWrapper extends StatelessWidget {
  final Widget child;
  final List<Override> overrides;
  final List<NavigatorObserver> navigatorObservers;
  final Route<dynamic>? Function(RouteSettings)? onGenerateRoute;

  const TestWrapper({
    super.key,
    required this.child,
    this.overrides = const [],
    this.navigatorObservers = const [],
    this.onGenerateRoute,
  });

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: overrides,
      child: EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('fr')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        assetLoader: MockAssetLoader(),
        useOnlyLangCode: true,
        saveLocale: false,
        child: Builder(
          builder: (context) {
            return MaterialApp(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              navigatorObservers: navigatorObservers,
              onGenerateRoute: onGenerateRoute,
              home: Scaffold(body: child),
            );
          },
        ),
      ),
    );
  }
}

/// Helper to initialize necessary mocks for all tests
void initTestMocks() {
  SharedPreferences.setMockInitialValues({});
}
