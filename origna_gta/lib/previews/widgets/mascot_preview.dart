// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/widgets/mascot/canadian_moose.dart';
import 'package:origna_gta/widgets/mascot/shop_mascot.dart';

// ─── Canadian Moose Previews ──────────────────────────────────────────────────

@Preview(name: 'Moose — Default (90px)', group: 'CanadianMoose')
Widget previewCanadianMooseDefault() => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData.dark(),
  home: Scaffold(
    backgroundColor: DesignTokens.darkBackground,
    body: Center(child: CanadianMoose(controller: MooseController(), size: 90, showSpeechBubble: false)),
  ),
);

@Preview(name: 'Moose — Large (150px)', group: 'CanadianMoose')
Widget previewCanadianMooseLarge() => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData.dark(),
  home: Scaffold(
    backgroundColor: DesignTokens.darkBackground,
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(80),
        child: CanadianMoose(controller: MooseController(), size: 150, showSpeechBubble: false),
      ),
    ),
  ),
);

// ─── Shop Mascot (Sparky) Previews ────────────────────────────────────────────

@Preview(name: 'Sparky — Default (80px)', group: 'ShopMascot')
Widget previewShopMascotDefault() => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData.dark(),
  home: Scaffold(
    backgroundColor: DesignTokens.darkBackground,
    body: Center(child: ShopMascot(controller: MascotController(), size: 80, showSpeechBubble: false)),
  ),
);

@Preview(name: 'Sparky — Large (140px)', group: 'ShopMascot')
Widget previewShopMascotLarge() => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData.dark(),
  home: Scaffold(
    backgroundColor: DesignTokens.darkBackground,
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(80),
        child: ShopMascot(controller: MascotController(), size: 140, showSpeechBubble: false),
      ),
    ),
  ),
);
