// coverage:ignore-file
/// Flutter Widget Previewer — ModernTextField variants.
library;

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/widgets/modern_textfield.dart';

import 'package:origna_gta/previews/_preview_theme.dart';

@Preview(name: 'Email field — dark', group: 'Text Fields')
Widget previewEmailField() => previewWrapper(
  child: ModernTextField(
    label: 'Email Address',
    hint: 'you@example.com',
    keyboardType: TextInputType.emailAddress,
    prefixIcon: Icons.email_outlined,
  ),
);

@Preview(name: 'Password field', group: 'Text Fields')
Widget previewPasswordField() => previewWrapper(
  child: ModernTextField(
    label: 'Password',
    hint: '••••••••',
    isPassword: true,
    prefixIcon: Icons.lock_outlined,
  ),
);

@Preview(name: 'Search field', group: 'Text Fields')
Widget previewSearchField() => previewWrapper(
  child: ModernTextField(
    hint: 'Search products…',
    prefixIcon: Icons.search,
    suffixIcon: Icons.tune_outlined,
  ),
);

@Preview(name: 'Multiline — description', group: 'Text Fields')
Widget previewMultilineField() => previewWrapper(
  child: ModernTextField(
    label: 'Product Description',
    hint: 'Describe your product in detail…',
    isMultiline: true,
    maxLines: 5,
    minLines: 3,
    maxLength: 500,
    showCounter: true,
  ),
);

@Preview(name: 'Price field', group: 'Text Fields')
Widget previewPriceField() => previewWrapper(
  child: ModernTextField(
    label: 'Price (CAD)',
    hint: '0.00',
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    prefixIcon: Icons.attach_money,
  ),
);

@Preview(name: 'All variants', group: 'Text Fields')
Widget previewAllTextFields() => previewGrid(
  children: [
    ModernTextField(
      label: 'Email',
      hint: 'you@example.com',
      prefixIcon: Icons.email_outlined,
    ),
    ModernTextField(
      label: 'Password',
      hint: '••••••••',
      isPassword: true,
      prefixIcon: Icons.lock_outlined,
    ),
    ModernTextField(
      label: 'Price (CAD)',
      hint: '0.00',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      prefixIcon: Icons.attach_money,
    ),
    ModernTextField(
      label: 'Description',
      hint: 'Tell us about your product…',
      isMultiline: true,
      maxLines: 3,
      minLines: 2,
    ),
  ],
);

@Preview(name: 'Light mode', group: 'Text Fields', brightness: Brightness.light)
Widget previewTextFieldLight() => previewWrapper(
  theme: previewLightTheme,
  background: DesignTokens.surface,
  child: ModernTextField(
    label: 'Email Address',
    hint: 'you@example.com',
    prefixIcon: Icons.email_outlined,
  ),
);
