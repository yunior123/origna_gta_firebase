import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/widgets/modern_loading_indicator.dart';

/// Helper widget for Flutter Web code splitting via deferred imports.
///
/// Usage:
/// ```dart
/// import 'package:origna_gta/screens/heavy_screen.dart' deferred as heavy;
///
/// DeferredWidget(
///   loader: heavy.loadLibrary,
///   builder: () => const heavy.HeavyScreen(),
/// )
/// ```
///
/// On Flutter Web (dart2js), deferred imports create separate JavaScript
/// chunks that are loaded on demand, reducing initial bundle size.
/// On mobile, deferred loading completes synchronously.
class DeferredWidget extends StatefulWidget {
  final Future<dynamic> Function() loader;
  final Widget Function() builder;

  const DeferredWidget({
    super.key,
    required this.loader,
    required this.builder,
  });

  /// Preload a deferred library (e.g., on hover or prefetch)
  static final _loaded = <Future<dynamic> Function(), Future<void>>{};

  static Future<void> preload(Future<dynamic> Function() loader) {
    return _loaded.putIfAbsent(loader, () => loader());
  }

  @override
  State<DeferredWidget> createState() => _DeferredWidgetState();
}

class _DeferredWidgetState extends State<DeferredWidget> {
  late Future<void> _libraryFuture;

  @override
  void initState() {
    super.initState();
    _libraryFuture = DeferredWidget.preload(widget.loader);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _libraryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: DesignTokens.error),
                    const SizedBox(height: 16),
                    Text('common.failed_to_load_page'.tr()),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          DeferredWidget._loaded.remove(widget.loader);
                          _libraryFuture = DeferredWidget.preload(widget.loader);
                        });
                      },
                      child: Text('common.retry'.tr()),
                    ),
                  ],
                ),
              ),
            );
          }
          return widget.builder();
        }
        return const Scaffold(
          body: Center(child: ModernLoadingIndicator()),
        );
      },
    );
  }
}
