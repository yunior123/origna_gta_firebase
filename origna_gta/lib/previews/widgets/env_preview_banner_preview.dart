// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/previews/_preview_theme.dart';
import 'package:origna_gta/utils/design_tokens.dart';

@Preview(name: 'Env Banners', group: 'EnvPreviewBanner')
Widget previewEnvBanners() =>
    previewGrid(children: [_bannerCard('BETA', DesignTokens.info), _bannerCard('DEV', DesignTokens.warning), _bannerCard('STAGING', DesignTokens.secondary)]);

@Preview(name: 'Env Banners Light', group: 'EnvPreviewBanner')
Widget previewEnvBannersLight() =>
    previewGrid(theme: previewLightTheme, children: [_bannerCard('BETA', DesignTokens.info), _bannerCard('DEV', DesignTokens.warning), _bannerCard('STAGING', DesignTokens.secondary)]);

Widget _bannerCard(String label, Color color) => Container(
  height: 100,
  decoration: BoxDecoration(border: Border.all(color: DesignTokens.darkOutline)),
  child: Banner(
    message: label,
    location: BannerLocation.topEnd,
    color: color,
    child: Center(
      child: Text('App Content', style: TextStyle(color: DesignTokens.textOnDark, fontSize: 16)),
    ),
  ),
);
