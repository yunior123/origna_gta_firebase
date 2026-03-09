import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:origna_gta/widgets/legal_screen_body.dart';

/// Documentation for PrivacyPolicyScreen
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LegalScreenBody(
        rawContent: 'legal.privacy_policy_content'.tr(),
        heroTitle: 'legal.privacy_policy_hero'.tr(),
        heroBadge: 'legal.your_privacy_matters'.tr(),
        heroBadgeIcon: Icons.lock_outlined,
      ),
    );
  }
}

// ─── Flutter Previews ────────────────────────────────────────────────────────

