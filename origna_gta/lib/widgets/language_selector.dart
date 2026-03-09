// coverage:ignore-file
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/utils/design_tokens.dart';

/// Language selector widget for Quebec Bill 96 compliance.
/// Allows users to switch between English and French.
/// Can be placed in profile/settings or app bar.
class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key, this.compact = false});

  /// If true, shows only a flag/icon button instead of full dropdown
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _CompactLanguageButton();
    }
    return _LanguageDropdown();
  }
}

class _CompactLanguageButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = context.locale;
    final isEn = currentLocale.languageCode == LanguageValues.english;

    return Semantics(
      label: 'language.select_language'.tr(),
      button: true,
      child: Tooltip(
        message: 'language.select_language'.tr(),
        child: IconButton(
          tooltip: 'language.select_language'.tr(),
          onPressed: () {
            final newLocale = isEn
                ? const Locale(LanguageValues.french)
                : const Locale(LanguageValues.english);
            context.setLocale(newLocale);
            _persistLang(ref, newLocale.languageCode);
          },
          icon: Text(
            isEn ? 'FR' : 'EN',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: DesignTokens.primary,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageDropdown extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = context.locale;

    return Semantics(
      label: 'language.select_language'.tr(),
      child: DropdownButton<Locale>(
        value: currentLocale,
        underline: const SizedBox.shrink(),
        icon: const Icon(Icons.language, color: DesignTokens.primary),
        items: const [
          DropdownMenuItem(
            value: Locale(LanguageValues.english),
            child: Text('English'),
          ),
          DropdownMenuItem(
            value: Locale(LanguageValues.french),
            child: Text('Français'),
          ),
        ],
        onChanged: (locale) {
          if (locale != null) {
            context.setLocale(locale);
            _persistLang(ref, locale.languageCode);
          }
        },
      ),
    );
  }
}

void _persistLang(WidgetRef ref, String langCode) {
  final userId = ref.read(userIdProvider);
  if (userId == null) return;
  final lang = langCode == LanguageValues.french
      ? LanguageValues.french
      : LanguageValues.english;
  ref
      .read(userRepositoryProvider)
      .updatePreferredLanguage(userId, lang)
      .catchError((_) {
        // Fire-and-forget — UI locale is already set; Firestore failure is non-critical
      });
}
