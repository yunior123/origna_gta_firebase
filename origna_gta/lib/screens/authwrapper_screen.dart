import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/features/auth/auth_provider.dart';
import 'package:origna_gta/features/terms/terms_provider.dart';
import 'package:origna_gta/screens/common_screens.dart';
import 'package:origna_gta/screens/main_screen.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/utils/env_config.dart';
import 'package:origna_gta/utils/utils.dart';
import 'package:origna_gta/widgets/modern_button.dart';
import 'package:origna_gta/widgets/modern_loading_indicator.dart';

// Splash removal is handled entirely by index.html JS (flutter-first-frame + 5s fallback).

/// Documentation for AuthWrapper
class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    return authState.when(
      data: (user) {
        // Require email verification except in emulator (emulator doesn't persist emailVerified reliably)
        if (user != null && !user.emailVerified && !EnvConfig().isEmulator) {
          return const EmailVerificationRequiredScreen();
        }
        // CASL/PIPEDA: gate on updated Terms version before allowing app access
        if (user != null) {
          final needsTermsUpdate = ref.watch(needsTermsUpdateProvider);
          if (needsTermsUpdate) {
            return const _TermsUpdateGate();
          }
        }
        return const MainScreen();
      },
      loading: () => const MainScreen(), // HTML splash covers the gap
      error: (e, st) {
        // Log for Sentry observability — don't block the user
        AppError.log(e, stackTrace: st, context: 'auth_wrapper');
        return const MainScreen();
      },
    );
  }
}

/// Un-bypassable full-screen gate shown when the user's accepted terms version
/// differs from the current required version. User must read and accept before
/// proceeding. No back button or skip action.
class _TermsUpdateGate extends ConsumerStatefulWidget {
  const _TermsUpdateGate();

  @override
  ConsumerState<_TermsUpdateGate> createState() => _TermsUpdateGateState();
}

class _TermsUpdateGateState extends ConsumerState<_TermsUpdateGate> {
  bool _accepting = false;
  bool _hasScrolledToBottom = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_hasScrolledToBottom) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 80) {
      setState(() => _hasScrolledToBottom = true);
    }
  }

  Future<void> _acceptTerms() async {
    if (_accepting) return;
    setState(() => _accepting = true);
    try {
      await ref.read(userRepositoryProvider).recordTermsAcceptance();
      // Provider will auto-update via Firestore stream — no manual navigation needed.
    } catch (e, st) {
      AppError.log(e, stackTrace: st, context: 'terms_update_gate');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('legal.terms_accept_error'.tr()), backgroundColor: DesignTokens.error),
        );
      }
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final termsAsync = ref.watch(termsProvider);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: DesignTokens.backgroundGradient(isDark: true)),
        child: SafeArea(
          child: Column(
            children: [
              // Header — no close/back action
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  children: [
                    const Icon(Icons.policy_outlined, size: 36, color: DesignTokens.primary),
                    const SizedBox(height: 8),
                    Text(
                      'legal.terms_updated_title'.tr(),
                      style: const TextStyle(
                        color: DesignTokens.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'legal.terms_updated_subtitle'.tr(),
                      style: const TextStyle(color: DesignTokens.textSecondary, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              Divider(color: DesignTokens.textSecondary.withValues(alpha: 0.3), height: 1),
              // Scrollable terms body
              Expanded(
                child: termsAsync.when(
                  data: (content) => ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    children: [
                      Text(
                        content,
                        style: const TextStyle(color: DesignTokens.textSecondary, fontSize: 13, height: 1.55),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                  loading: () => const Center(child: ModernLoadingIndicator()),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'legal.terms_load_error'.tr(),
                      style: const TextStyle(color: DesignTokens.textSecondary),
                    ),
                  ),
                ),
              ),
              Divider(color: DesignTokens.textSecondary.withValues(alpha: 0.3), height: 1),
              // Accept button — enabled only after scrolling to bottom
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_hasScrolledToBottom)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'legal.terms_scroll_to_accept'.tr(),
                          style: const TextStyle(color: DesignTokens.textSecondary, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ModernButton(
                      key: const Key('btn-terms-accept'),
                      label: _accepting ? 'common.loading'.tr() : 'legal.terms_accept_button'.tr(),
                      onPressed: (_accepting || !_hasScrolledToBottom) ? null : _acceptTerms,
                      isPrimary: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
