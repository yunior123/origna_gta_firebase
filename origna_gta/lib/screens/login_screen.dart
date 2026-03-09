// coverage:ignore-file
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/constants/validation_constants.dart';
import 'package:origna_gta/core/routes.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/utils/utils.dart';
import 'package:origna_gta/widgets/modern_button.dart';
import 'package:origna_gta/widgets/modern_loading_indicator.dart';
import 'package:origna_gta/widgets/modern_textfield.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../features/auth/login_viewmodel.dart';

/// Documentation for LoginScreen
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

/// Documentation for LoginScreenLayout
class LoginScreenLayout extends StatelessWidget {
  final bool isLogin;
  final bool isLoading;
  final bool obscurePassword;
  final bool acceptedTerms;
  final bool marketingOptIn;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final GlobalKey<FormState> formKey;
  final Animation<double>? fadeAnimation;
  final Animation<Offset>? slideAnimation;
  final VoidCallback onAuthToggle;
  final VoidCallback onAuthSubmit;
  final VoidCallback onGoogleSignIn;
  final VoidCallback onAppleSignIn;
  final VoidCallback onForgotPassword;
  final VoidCallback onToggleObscurePassword;
  final ValueChanged<bool?> onTermsChanged;
  final ValueChanged<bool?> onMarketingOptInChanged;

  const LoginScreenLayout({
    super.key,
    required this.isLogin,
    required this.isLoading,
    required this.obscurePassword,
    required this.acceptedTerms,
    required this.marketingOptIn,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.formKey,
    this.fadeAnimation,
    this.slideAnimation,
    required this.onAuthToggle,
    required this.onAuthSubmit,
    required this.onGoogleSignIn,
    required this.onAppleSignIn,
    required this.onForgotPassword,
    required this.onToggleObscurePassword,
    required this.onTermsChanged,
    required this.onMarketingOptInChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget content = Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [DesignTokens.surface, DesignTokens.surface]
                : [DesignTokens.primary.withValues(alpha: 0.05), DesignTokens.secondary.withValues(alpha: 0.05)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (_, constraints) {
              final isDesktop = constraints.maxWidth >= 900;
              final formPanel = SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spacing20, vertical: DesignTokens.spacing24),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Hero(
                        tag: 'app_logo',
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [DesignTokens.gradientStart, DesignTokens.gradientMiddle, DesignTokens.gradientEnd],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(DesignTokens.radius24),
                            boxShadow: [
                              ...DesignTokens.shadowLg,
                              BoxShadow(color: DesignTokens.gradientStart.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8)),
                            ],
                          ),
                          child: const Icon(Icons.shopping_bag_outlined, size: 56, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 32),
                      ShaderMask(
                        shaderCallback: (bounds) => DesignTokens.primaryGradient.createShader(bounds),
                        child: const Text(
                          'OrignaGta',
                          style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.5),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isLogin ? 'auth.welcome_back_subtitle'.tr() : 'auth.start_today'.tr(),
                        style: TextStyle(fontSize: 15, color: DesignTokens.textSecondary, fontWeight: FontWeight.w500, letterSpacing: 0.2),
                      ),
                      const SizedBox(height: 40),
                      GlassContainer(
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: Column(
                            children: [
                              if (!isLogin) ...[
                                ModernTextField(
                                  key: const Key('login_name_field'),
                                  label: 'auth.full_name'.tr(),
                                  hint: 'auth.full_name_hint'.tr(),
                                  controller: nameController,
                                  prefixIcon: Icons.person_outline,
                                  validator: (value) {
                                    if (isLogin) return null;
                                    if (value == null || value.isEmpty) {
                                      return 'auth.name_required'.tr();
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: DesignTokens.spacing16),
                              ],
                              ModernTextField(
                                key: const Key('login_email_field'),
                                semanticsLabel: 'login_email_field',
                                label: 'auth.email_address'.tr(),
                                hint: 'auth.email_hint'.tr(),
                                controller: emailController,
                                keyboardType: TextInputType.emailAddress,
                                prefixIcon: Icons.mail_outline,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'auth.email_required'.tr();
                                  }
                                  if (!ValidationConstants.emailRegex.hasMatch(value)) {
                                    return 'auth.email_invalid'.tr();
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: DesignTokens.spacing16),
                              ModernTextField(
                                key: const Key('login_password_field'),
                                semanticsLabel: 'login_password_field',
                                label: 'auth.password'.tr(),
                                hint: '••••••••',
                                controller: passwordController,
                                isPassword: obscurePassword,
                                prefixIcon: Icons.lock_outline,
                                suffixIcon: obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                onSuffixTap: onToggleObscurePassword,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'auth.password_required'.tr();
                                  }
                                  if (!isLogin) {
                                    if (value.length < ValidationConstants.minPasswordLength) {
                                      return 'auth.validation.password_min_8'.tr();
                                    }
                                    if (!ValidationConstants.passwordRegex.hasMatch(value)) {
                                      return 'auth.validation.password_weak'.tr();
                                    }
                                  }
                                  if (isLogin && value.length < 6) {
                                    return 'auth.password_min_length'.tr();
                                  }
                                  return null;
                                },
                              ),
                              if (!isLogin) ...[
                                const SizedBox(height: DesignTokens.spacing16),
                                Row(
                                  children: [
                                    Semantics(
                                      label: 'checkbox-accept-terms',
                                      child: Checkbox(
                                        key: const Key('login_terms_checkbox'),
                                        value: acceptedTerms,
                                        onChanged: onTermsChanged,
                                        fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
                                          if (states.contains(WidgetState.selected)) {
                                            return DesignTokens.primary;
                                          }
                                          return null;
                                        }),
                                      ),
                                    ),
                                    Expanded(
                                      child: RichText(
                                        text: TextSpan(
                                          style: TextStyle(fontSize: 13, color: DesignTokens.textPrimary, height: 1.4),
                                          children: [
                                            TextSpan(text: 'auth.agree_to_prefix'.tr()),
                                            TextSpan(
                                              text: 'auth.terms_conditions'.tr(),
                                              style: const TextStyle(
                                                color: DesignTokens.primary,
                                                fontWeight: FontWeight.w600,
                                                decoration: TextDecoration.underline,
                                              ),
                                              recognizer: TapGestureRecognizer()..onTap = () => openTermsOfService(context),
                                            ),
                                            TextSpan(text: 'auth.and_conjunction'.tr()),
                                            TextSpan(
                                              text: 'auth.privacy_policy_link'.tr(),
                                              style: const TextStyle(
                                                color: DesignTokens.primary,
                                                fontWeight: FontWeight.w600,
                                                decoration: TextDecoration.underline,
                                              ),
                                              recognizer: TapGestureRecognizer()..onTap = () => openPrivacyPolicy(context),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (!isLogin) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Semantics(
                                      label: 'checkbox-marketing-opt-in',
                                      child: Checkbox(
                                        value: marketingOptIn,
                                        onChanged: onMarketingOptInChanged,
                                        fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
                                          if (states.contains(WidgetState.selected)) {
                                            return DesignTokens.primary;
                                          }
                                          return null;
                                        }),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text('auth.marketing_opt_in'.tr(), style: TextStyle(fontSize: 12, color: DesignTokens.textSecondary, height: 1.4)),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spacing16),
                        child: Column(
                          children: [
                            ModernButton(
                              key: const Key('login_submit_button'),
                              semanticsLabel: 'login_submit_button',
                              label: isLogin ? 'auth.sign_in'.tr() : 'auth.create_account'.tr(),
                              isLoading: isLoading,
                              isPrimary: true,
                              onPressed: onAuthSubmit,
                            ),
                            const SizedBox(height: 16),
                            if (isLogin) ...[
                              Semantics(
                                label: 'btn-forgot-password',
                                button: true,
                                child: TextButton(
                                  key: const Key('login_forgot_password_button'),
                                  onPressed: onForgotPassword,
                                  child: Text(
                                    'auth.forgot_password'.tr(),
                                    style: TextStyle(color: DesignTokens.primary, fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(child: Divider(color: DesignTokens.outlineVariant, thickness: 0.8)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spacing12),
                                  child: Text(
                                    'auth.or_continue_with'.tr(),
                                    style: TextStyle(color: DesignTokens.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                ),
                                Expanded(child: Divider(color: DesignTokens.outlineVariant, thickness: 0.8)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _GoogleSignInButton(
                              key: const Key('login_google_button'),
                              label: isLogin ? 'auth.google_sign_in'.tr() : 'auth.sign_up_with_google'.tr(),
                              isLoading: isLoading,
                              onPressed: isLoading ? null : onGoogleSignIn,
                            ),
                            if (!kIsWeb && (Theme.of(context).platform == TargetPlatform.iOS || Theme.of(context).platform == TargetPlatform.macOS)) ...[
                              const SizedBox(height: 12),
                              Semantics(
                                label: 'login_apple_button',
                                button: true,
                                child: SignInWithAppleButton(
                                  key: const Key('login_apple_button'),
                                  text: isLogin ? 'auth.apple_sign_in'.tr() : 'auth.sign_up_with_apple'.tr(),
                                  style: isDark ? SignInWithAppleButtonStyle.white : SignInWithAppleButtonStyle.black,
                                  height: 52,
                                  borderRadius: const BorderRadius.all(Radius.circular(DesignTokens.radius16)),
                                  onPressed: isLoading ? () {} : onAppleSignIn,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Semantics(
                        label: 'btn-toggle-auth-mode',
                        button: true,
                        child: GestureDetector(
                          key: const Key('login_toggle_mode_button'),
                          onTap: isLoading ? null : onAuthToggle,
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 14, color: DesignTokens.textSecondary, fontWeight: FontWeight.w500),
                              children: [
                                TextSpan(text: isLogin ? "auth.no_account".tr() : 'auth.already_have_account'.tr()),
                                TextSpan(
                                  text: isLogin ? 'auth.sign_up'.tr() : 'auth.sign_in'.tr(),
                                  style: const TextStyle(color: DesignTokens.primary, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
              if (isDesktop) {
                return Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [DesignTokens.primary.withValues(alpha: 0.15), DesignTokens.secondary.withValues(alpha: 0.08)],
                          ),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShaderMask(
                                shaderCallback: (b) => DesignTokens.primaryGradient.createShader(b),
                                child: const Text(
                                  'OrignaGTA',
                                  style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.white),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text('app.tagline'.tr(), style: TextStyle(fontSize: 17, color: DesignTokens.textSecondary, height: 1.5)),
                              const SizedBox(height: 48),
                              ...['auth.feature_1', 'auth.feature_2', 'auth.feature_3'].map(
                                (key) => Padding(
                                  padding: const EdgeInsets.only(bottom: 20),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(gradient: DesignTokens.primaryGradient, shape: BoxShape.circle),
                                        child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(key.tr(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 500, child: formPanel),
                  ],
                );
              }
              return Center(
                child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 500), child: formPanel),
              );
            },
          ),
        ),
      ),
    );

    if (fadeAnimation != null && slideAnimation != null) {
      return FadeTransition(
        opacity: fadeAnimation!,
        child: SlideTransition(position: slideAnimation!, child: content),
      );
    }

    return content;
  }
}

/// Google "G" logo mark rendered with official brand colors.
class _GoogleGLogo extends StatelessWidget {
  const _GoogleGLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 20, height: 20, child: CustomPaint(painter: _GoogleGPainter()));
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final paint = Paint()..style = PaintingStyle.fill;

    // Draw the 4-color Google G
    // Blue: top → right (~270° to ~30°)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), -1.57, 2.09, true, paint);

    // Red: left-top (~150° to ~270°)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), 2.62, 1.83, true, paint);

    // Yellow: bottom-left (~90° to ~150°)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), 1.57, 1.05, true, paint);

    // Green: right-bottom (~30° to ~90°)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), 0.52, 1.05, true, paint);

    // White center circle to create the "G" cutout
    paint.color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), r * 0.58, paint);

    // White horizontal bar for the "G" crossbar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(cx, cy - r * 0.18, r, r * 0.36), barPaint);

    // Re-mask outer arc for the crossbar area (only right half shows blue in crossbar)
    paint.color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), r * 0.58, paint);
    // Redraw the crossbar portion in the cutout
    barPaint.color = const Color(0xFF4285F4);
    canvas.drawRect(Rect.fromLTWH(cx, cy - r * 0.18, r * 0.42, r * 0.36), barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Google Sign-In button following Google's branding guidelines.
/// Uses a white background with the Google "G" logo mark and correct typography.
class _GoogleSignInButton extends StatefulWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _GoogleSignInButton({super.key, required this.label, required this.isLoading, this.onPressed});

  @override
  State<_GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<_GoogleSignInButton> with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scale;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      enabled: !isDisabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: isDisabled ? null : (_) => _scaleController.forward(),
        onTapUp: isDisabled ? null : (_) => _scaleController.reverse(),
        onTapCancel: isDisabled ? null : () => _scaleController.reverse(),
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131314) : Colors.white,
              borderRadius: BorderRadius.circular(DesignTokens.radius16),
              border: Border.all(color: isDark ? const Color(0xFF5F6368) : const Color(0xFFDEDEDE), width: 1),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isDisabled ? null : widget.onPressed,
                borderRadius: BorderRadius.circular(DesignTokens.radius16),
                child: Center(
                  child: widget.isLoading
                      ? const ModernLoadingIndicator(size: 20, color: Color(0xFF4285F4))
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Google G logo mark using official brand colors
                            _GoogleGLogo(),
                            const SizedBox(width: 10),
                            Text(
                              widget.label,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF3C4043),
                                letterSpacing: 0.25,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut));
  }
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginViewModelProvider);
    final viewModel = ref.read(loginViewModelProvider.notifier);

    // Listen for success or error
    ref.listen(loginViewModelProvider, (previous, next) {
      if (next.isSuccess) {
        _onAuthSuccess();
      } else if (next.successMessage != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.successMessage!), backgroundColor: DesignTokens.success, behavior: SnackBarBehavior.floating));
      } else if (next.errorMessage != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.errorMessage!), backgroundColor: DesignTokens.error, behavior: SnackBarBehavior.floating));
      }
    });

    return LoginScreenLayout(
      isLogin: state.isLogin,
      isLoading: state.isLoading,
      obscurePassword: state.obscurePassword,
      acceptedTerms: state.acceptedTerms,
      marketingOptIn: state.marketingOptIn,
      nameController: _nameController,
      emailController: _emailController,
      passwordController: _passwordController,
      formKey: _formKey,
      fadeAnimation: _fadeAnimation,
      slideAnimation: _slideAnimation,
      onAuthToggle: () {
        viewModel.toggleAuthMode();
        _formKey.currentState?.reset();
      },
      onAuthSubmit: () {
        if (!state.isLogin && !state.acceptedTerms) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('auth.accept_terms_required'.tr()), backgroundColor: DesignTokens.error, behavior: SnackBarBehavior.floating));
          return;
        }

        if (_formKey.currentState!.validate()) {
          viewModel.handleAuth(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            name: !state.isLogin ? _nameController.text.trim() : null,
            marketingOptIn: !state.isLogin ? state.marketingOptIn : false,
          );
        }
      },
      onGoogleSignIn: viewModel.handleGoogleSignIn,
      onAppleSignIn: viewModel.handleAppleSignIn,
      onForgotPassword: () => _showForgotPasswordDialog(context),
      onToggleObscurePassword: viewModel.toggleObscurePassword,
      onTermsChanged: (v) => viewModel.setAcceptedTerms(v ?? false),
      onMarketingOptInChanged: (v) => viewModel.setMarketingOptIn(v ?? false),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
    _animationController.forward();
  }

  void _onAuthSuccess() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('auth.welcome_back_msg'.tr()), backgroundColor: DesignTokens.success, behavior: SnackBarBehavior.floating));
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
  }

  void _showForgotPasswordDialog(BuildContext context) {
    final emailController = TextEditingController(text: _emailController.text.trim());
    final formKey = GlobalKey<FormState>();
    bool isSending = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('auth.reset_password'.tr()),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('auth.reset_password_desc'.tr(), style: TextStyle(fontSize: 14, color: DesignTokens.textSecondary)),
                  const SizedBox(height: 20),
                  Form(
                    key: formKey,
                    child: TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(labelText: 'auth.email'.tr(), prefixIcon: Icon(Icons.email_outlined)),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'auth.please_enter_email'.tr();
                        if (!ValidationConstants.emailRegex.hasMatch(value)) return 'auth.enter_valid_email'.tr();
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                Semantics(
                  label: 'btn-forgot-cancel',
                  button: true,
                  child: TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('common.cancel'.tr())),
                ),
                Semantics(
                  label: 'btn-forgot-send',
                  button: true,
                  child: ElevatedButton(
                    onPressed: isSending
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            final messenger = ScaffoldMessenger.of(dialogContext);
                            setState(() => isSending = true);
                            try {
                              await ref.read(loginViewModelProvider.notifier).resetPassword(emailController.text.trim());
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                                messenger.showSnackBar(SnackBar(content: Text('auth.reset_link_sent'.tr()), backgroundColor: DesignTokens.success));
                              }
                            } catch (e) {
                              if (dialogContext.mounted) {
                                messenger.showSnackBar(SnackBar(content: Text('auth.reset_link_failed'.tr()), backgroundColor: DesignTokens.error));
                              }
                            } finally {
                              if (mounted) setState(() => isSending = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(backgroundColor: DesignTokens.primary, foregroundColor: Colors.white),
                    child: isSending ? const ModernLoadingIndicator.small(color: Colors.white) : Text('auth.send'.tr()),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
