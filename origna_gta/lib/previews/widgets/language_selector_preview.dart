// coverage:ignore-file
import 'package:flutter/widget_previews.dart';
import 'package:flutter/material.dart';
import 'package:origna_gta/previews/_preview_theme.dart';
import 'package:origna_gta/widgets/language_selector.dart';

@Preview(name: 'Language Selector — Variants', group: 'LanguageSelector')
Widget previewLanguageVariants() => previewScope(
  child: previewGrid(
    children: const [
      Padding(padding: EdgeInsets.all(16), child: LanguageSelector()),
      Padding(padding: EdgeInsets.all(16), child: LanguageSelector(compact: true)),
    ],
  ),
);

@Preview(name: 'Language Selector Light — Variants', group: 'LanguageSelector')
Widget previewLanguageVariantsLight() => previewScope(
  child: previewGrid(
    theme: previewLightTheme,
    children: const [
      Padding(padding: EdgeInsets.all(16), child: LanguageSelector()),
      Padding(padding: EdgeInsets.all(16), child: LanguageSelector(compact: true)),
    ],
  ),
);
