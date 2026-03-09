import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:origna_gta/widgets/legal_screen_body.dart';

/// Documentation for TermsOfServiceScreen
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LegalScreenBody(
        rawContent: 'legal.terms_of_service_content'.tr(),
        heroTitle: 'legal.terms_of_service_hero'.tr(),
        heroBadge: 'legal.legal_agreement'.tr(),
        heroBadgeIcon: Icons.verified_outlined,
      ),
    );
  }
}

// ─── Flutter Previews ────────────────────────────────────────────────────────

