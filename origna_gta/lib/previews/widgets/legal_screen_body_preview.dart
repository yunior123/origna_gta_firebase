// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/previews/_preview_theme.dart';
import 'package:origna_gta/widgets/legal_screen_body.dart';

const _kPrivacyMock = '''
# Privacy Policy
We value your privacy. Your data is handled securely and not shared with third parties without your consent. 
''';

const _kTermsMock = '''
# Terms of Service
By using our service, you agree to our terms.
''';

@Preview(name: 'Legal Content — Responsive', group: 'LegalScreenBody')
Widget previewLegalResponsive() => previewResponsiveBreakpoints(
  builder: (bp) => const LegalScreenBody(heroTitle: 'Privacy Policy', heroBadge: 'PRIVACY', heroBadgeIcon: Icons.shield_outlined, rawContent: _kPrivacyMock),
);

@Preview(name: 'Legal Content — Variants', group: 'LegalScreenBody')
Widget previewLegalVariants() => previewGrid(
  children: [
    SizedBox(height: 700, child: const LegalScreenBody(heroTitle: 'Privacy Policy', heroBadge: 'PRIVACY', heroBadgeIcon: Icons.shield_outlined, rawContent: _kPrivacyMock)),
    SizedBox(height: 700, child: const LegalScreenBody(heroTitle: 'Terms of Service', heroBadge: 'TERMS', heroBadgeIcon: Icons.gavel_outlined, rawContent: _kTermsMock)),
  ],
);

@Preview(name: 'Legal Content Light — Responsive', group: 'LegalScreenBody')
Widget previewLegalResponsiveLight() => previewResponsiveBreakpoints(
  theme: previewLightTheme,
  builder: (bp) => const LegalScreenBody(heroTitle: 'Privacy Policy', heroBadge: 'PRIVACY', heroBadgeIcon: Icons.shield_outlined, rawContent: _kPrivacyMock),
);

@Preview(name: 'Legal Content Light — Variants', group: 'LegalScreenBody')
Widget previewLegalVariantsLight() => previewGrid(
  theme: previewLightTheme,
  children: [
    SizedBox(height: 700, child: const LegalScreenBody(heroTitle: 'Privacy Policy', heroBadge: 'PRIVACY', heroBadgeIcon: Icons.shield_outlined, rawContent: _kPrivacyMock)),
    SizedBox(height: 700, child: const LegalScreenBody(heroTitle: 'Terms of Service', heroBadge: 'TERMS', heroBadgeIcon: Icons.gavel_outlined, rawContent: _kTermsMock)),
  ],
);
