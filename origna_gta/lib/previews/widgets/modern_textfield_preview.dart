// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/previews/_preview_theme.dart';
import 'package:origna_gta/widgets/modern_textfield.dart';

@Preview(name: 'Modern TextField — Variants', group: 'ModernTextField')
Widget previewTextFieldVariants() => previewGrid(
  children: [
    const ModernTextField(label: 'Email Address', hint: 'enter@email.com', prefixIcon: Icons.email_outlined),
    const ModernTextField(label: 'Password', hint: '••••••••', isPassword: true, prefixIcon: Icons.lock_outline_rounded),
    const ModernTextField(label: 'Search', hint: 'Search for products...', prefixIcon: Icons.search_rounded),
  ],
);

@Preview(name: 'Modern TextField — States', group: 'ModernTextField')
Widget previewTextFieldStates() => previewGrid(
  children: [
    const ModernTextField(label: 'Bio', hint: 'Tell us about yourself...', isMultiline: true, minLines: 3, maxLines: 5),
    const ModernTextField(label: 'Username', hint: 'yunior123', maxLength: 20, showCounter: true),
    ModernTextField(label: 'Validation Error', hint: 'Wrong input', validator: (v) => 'This field is required'),
  ],
);

@Preview(name: 'Modern TextField Light — Variants', group: 'ModernTextField')
Widget previewTextFieldVariantsLight() => previewGrid(
  theme: previewLightTheme,
  children: [
    const ModernTextField(label: 'Email Address', hint: 'enter@email.com', prefixIcon: Icons.email_outlined),
    const ModernTextField(label: 'Password', hint: '••••••••', isPassword: true, prefixIcon: Icons.lock_outline_rounded),
    const ModernTextField(label: 'Search', hint: 'Search for products...', prefixIcon: Icons.search_rounded),
  ],
);

@Preview(name: 'Modern TextField Light — States', group: 'ModernTextField')
Widget previewTextFieldStatesLight() => previewGrid(
  theme: previewLightTheme,
  children: [
    const ModernTextField(label: 'Bio', hint: 'Tell us about yourself...', isMultiline: true, minLines: 3, maxLines: 5),
    const ModernTextField(label: 'Username', hint: 'yunior123', maxLength: 20, showCounter: true),
    ModernTextField(label: 'Validation Error', hint: 'Wrong input', validator: (v) => 'This field is required'),
  ],
);
