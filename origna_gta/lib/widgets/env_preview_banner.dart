// coverage:ignore-file
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/utils/env_config.dart';

/// A wrapper widget that displays a "DEV", "STAGING", or "BETA" ribbon
/// on the web platform during the early launch period.
class EnvPreviewBanner extends StatelessWidget {
  final Widget child;

  const EnvPreviewBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Only show on the web platform
    if (!kIsWeb) {
      return child;
    }

    String? bannerText;
    Color bannerColor = DesignTokens.primary;

    if (envConfig.isEmulator || envConfig.isDev) {
      bannerText = 'DEV';
      bannerColor = DesignTokens.warning;
    } else if (envConfig.isStaging) {
      bannerText = 'STAGING';
      bannerColor = DesignTokens.secondary;
    } else if (envConfig.isProduction) {
      // Show "BETA" during the first 3 months of launch.
      // Launch target is March 1, 2026. 3 months is June 1, 2026.
      final now = DateTime.now();
      final cutoffDate = DateTime(2026, 6, 1);

      if (now.isBefore(cutoffDate)) {
        bannerText = 'BETA';
        bannerColor = DesignTokens.info;
      }
    }

    // If no banner is needed, return the child as is
    if (bannerText == null) {
      return child;
    }

    return Banner(message: bannerText, location: BannerLocation.topEnd, color: bannerColor, child: child);
  }
}
