// coverage:ignore-file
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/widgets/custom_app_bar.dart';
import 'package:origna_gta/widgets/modern_button.dart';
import 'package:origna_gta/widgets/modern_loading_indicator.dart';
import 'package:origna_gta/widgets/modern_textfield.dart';

import '../features/auth/reset_password_view_model.dart';

/// Documentation for ResetPasswordScreen
class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String oobCode;

  const ResetPasswordScreen({super.key, required this.oobCode});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(resetPasswordViewModelProvider(widget.oobCode));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (state.isVerifying) {
      return const Scaffold(body: Center(child: ModernLoadingIndicator()));
    }

    if (state.isSuccess) {
      return Container(
        decoration: BoxDecoration(gradient: DesignTokens.backgroundGradient(isDark: isDark)),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBarFactory.simple(title: 'auth.reset_password_title'.tr()),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(DesignTokens.spacing24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, color: DesignTokens.success, size: 80),
                  const SizedBox(height: DesignTokens.spacing24),
                  Text(
                    'auth.reset_success_title'.tr(),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: isDark ? Colors.white : DesignTokens.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: DesignTokens.spacing16),
                  Text(
                    'auth.reset_success_desc'.tr(),
                    style: TextStyle(color: DesignTokens.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: DesignTokens.spacing32),
                  Semantics(
                    button: true,
                    label: 'reset_password_go_to_login_button',
                    child: ModernButton(label: 'auth.go_to_login'.tr(), onPressed: () => Navigator.of(context).pushReplacementNamed('/')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(gradient: DesignTokens.backgroundGradient(isDark: isDark)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBarFactory.simple(title: 'auth.reset_password_title'.tr()),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(DesignTokens.spacing24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'auth.create_new_password'.tr(),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : DesignTokens.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (state.userEmail != null) ...[
                    const SizedBox(height: DesignTokens.spacing8),
                    Text(
                      '${'auth.resetting_for'.tr()}: ${state.userEmail}',
                      style: TextStyle(color: DesignTokens.textSecondary, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: DesignTokens.spacing32),
                  if (state.errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(DesignTokens.spacing12),
                      margin: const EdgeInsets.only(bottom: DesignTokens.spacing24),
                      decoration: BoxDecoration(
                        color: DesignTokens.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(DesignTokens.radius8),
                        border: Border.all(color: DesignTokens.error.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        state.errorMessage!,
                        style: const TextStyle(color: DesignTokens.error),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (state.userEmail != null) ...[
                    ModernTextField(
                      key: const Key('reset_password_new_password_field'),
                      semanticsLabel: 'reset_password_new_password_field',
                      label: 'auth.new_password'.tr(),
                      hint: '••••••••',
                      controller: _passwordController,
                      isPassword: _obscurePassword,
                      prefixIcon: Icons.lock_outline,
                      suffixIcon: _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      onSuffixTap: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    const SizedBox(height: DesignTokens.spacing16),
                    ModernTextField(
                      key: const Key('reset_password_confirm_password_field'),
                      semanticsLabel: 'reset_password_confirm_password_field',
                      label: 'auth.confirm_new_password'.tr(),
                      hint: '••••••••',
                      controller: _confirmController,
                      isPassword: _obscureConfirm,
                      prefixIcon: Icons.lock_outline,
                      suffixIcon: _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      onSuffixTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    const SizedBox(height: DesignTokens.spacing32),
                    Semantics(
                      button: true,
                      label: 'reset_password_submit_button',
                      child: ModernButton(
                        label: 'auth.reset_password_button'.tr(),
                        isLoading: state.isLoading,
                        onPressed: () => ref
                            .read(resetPasswordViewModelProvider(widget.oobCode).notifier)
                            .resetPassword(_passwordController.text.trim(), _confirmController.text.trim()),
                      ),
                    ),
                  ] else ...[
                    Semantics(
                      button: true,
                      label: 'reset_password_go_to_login_button',
                      child: ModernButton(label: 'auth.go_to_login'.tr(), onPressed: () => Navigator.of(context).pushReplacementNamed('/')),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }
}
