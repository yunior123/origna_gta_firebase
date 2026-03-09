// coverage:ignore-file
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/features/auth/auth_provider.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/utils/utils.dart'; // For UserModel
import 'package:origna_gta/widgets/custom_app_bar.dart'; // Assuming this exists based on your code
import 'package:origna_gta/widgets/modern_button.dart';
import 'package:origna_gta/widgets/modern_loading_indicator.dart';

import '../features/seller/seller_account_status_viewmodel.dart';
import '../features/seller/seller_registration_state.dart';
import '../features/seller/seller_registration_view_model.dart';

/// Available payment providers - add new providers here.
const List<PaymentProviderConfig> availablePaymentProviders = [
  PaymentProviderConfig(
    id: PaymentProviderValues.stripe,
    name: 'Stripe',
    icon: Icons.flash_on,
    primaryColor: DesignTokens.stripeViolet,
    secondaryColor: DesignTokens.stripeCyan,
    payoutTiming: '7 days after delivery confirmation',
    features: ['Automatic payouts after 7-day hold period', 'Best for Canada-based sellers', 'Stripe Express instant setup', '2.9% + \$0.30 per transaction'],
    recommendedFor: 'Recommended for local Canadian sellers.',
  ),
  PaymentProviderConfig(
    id: 'paypal', // Not in PaymentProviderValues — future provider
    name: 'PayPal',
    icon: Icons.account_balance_wallet,
    primaryColor: DesignTokens.paypalNavy,
    secondaryColor: DesignTokens.paypalBlue,
    payoutTiming: '3-5 days after delivery',
    features: ['Instant PayPal balance transfers', 'Buyer/Seller protection included', 'Wide international acceptance', '2.9% + \$0.30 per transaction'],
    recommendedFor: 'Great for sellers with existing PayPal business accounts.',
    comingSoon: true,
  ),
  PaymentProviderConfig(
    id: 'wise', // Not in PaymentProviderValues — future provider
    name: 'Wise (TransferWise)',
    icon: Icons.swap_horiz,
    primaryColor: DesignTokens.wiseGreen,
    secondaryColor: DesignTokens.wiseSky,
    payoutTiming: '1-3 days international transfer',
    features: ['Low-cost international transfers', 'Real mid-market exchange rates', 'Multi-currency accounts', '0.35% - 1% transfer fees'],
    recommendedFor: 'Perfect for international sellers needing fast, cheap transfers.',
    comingSoon: true,
  ),
];

/// Payment provider configuration for seller registration
class PaymentProviderConfig {
  final String id;
  final String name;
  final IconData icon;
  final Color primaryColor;
  final Color secondaryColor;
  final String payoutTiming;
  final List<String> features;
  final String recommendedFor;
  final bool comingSoon;

  const PaymentProviderConfig({
    required this.id,
    required this.name,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
    required this.payoutTiming,
    required this.features,
    required this.recommendedFor,
    this.comingSoon = false,
  });
}

// ============================================================================
// PAYMENT PROVIDER CONFIGURATION - Extensible for future providers
// ============================================================================

/// Documentation for SellerRegistrationScreen
class SellerRegistrationScreen extends ConsumerStatefulWidget {
  const SellerRegistrationScreen({super.key});

  @override
  ConsumerState<SellerRegistrationScreen> createState() => _SellerRegistrationScreenState();
}

class _SellerRegistrationScreenState extends ConsumerState<SellerRegistrationScreen> with WidgetsBindingObserver {
  bool _termsAccepted = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Watch User Data
    final userProfileAsync = ref.watch(userProfileProvider);
    // Watch ViewModel State (Loading/Error)
    final viewState = ref.watch(sellerRegistrationViewModelProvider);
    final viewModel = ref.read(sellerRegistrationViewModelProvider.notifier);

    return Container(
      decoration: BoxDecoration(gradient: DesignTokens.backgroundGradient(isDark: isDark)),
      child: Scaffold(
        appBar: AppBarFactory.simple(title: 'seller.become_seller'.tr()),
        backgroundColor: Colors.transparent,
        body: userProfileAsync.when(
          loading: () => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(colors: [DesignTokens.primary, DesignTokens.secondary]).createShader(bounds),
                  child: SizedBox(
                    width: 50,
                    height: 50,
                    child: ModernLoadingIndicator(size: 50, strokeWidth: 3, color: Colors.white.withValues(alpha: 0.8), centered: false),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'seller.loading'.tr(),
                  style: TextStyle(color: DesignTokens.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          error: (error, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('seller.error_loading_profile'.tr(namedArgs: {'error': error.toString()})),
            ),
          ),
          data: (userModel) {
            if (userModel == null) {
              return Center(child: Text('seller.please_login'.tr()));
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // --- Header Card ---
                      _buildHeaderCard(),

                      const SizedBox(height: 20),

                      _buildProviderSelector(userModel, viewState, viewModel),

                      const SizedBox(height: 20),

                      // --- Status Card (commented out - function needs refactoring) ---
                      // _buildStatusCard(userModel),
                      const SizedBox(height: 20),

                      // --- Benefits Card ---
                      _buildBenefitsCard(),

                      const SizedBox(height: 20),

                      // --- Error Display ---
                      if (viewState.error != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [DesignTokens.error.withValues(alpha: 0.2), DesignTokens.error.withValues(alpha: 0.1)]),
                            borderRadius: BorderRadius.circular(DesignTokens.radius12),
                            border: Border.all(color: DesignTokens.error.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: DesignTokens.error, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  viewState.error!,
                                  style: TextStyle(color: DesignTokens.error, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // --- Terms and Conditions ---
                      Semantics(
                        label: 'chk-seller-terms',
                        checked: _termsAccepted,
                        child: CheckboxListTile(
                          key: const Key('seller_terms_checkbox'),
                          value: _termsAccepted,
                          onChanged: (value) => setState(() => _termsAccepted = value ?? false),
                          title: Text('seller.accept_terms'.tr()),
                          subtitle: !_termsAccepted
                              ? Text('seller.accept_terms_required'.tr(), style: TextStyle(color: DesignTokens.warning, fontSize: 12))
                              : null,
                          controlAffinity: ListTileControlAffinity.leading,
                          fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
                            if (states.contains(WidgetState.selected)) {
                              return DesignTokens.primary;
                            }
                            return null;
                          }),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // --- Verification Status Card ---
                      _buildVerificationStatusCard(userModel),

                      // --- Action Button ---
                      _buildActionButton(userModel, viewState, viewModel),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When user returns from the browser (Stripe onboarding), refresh their status
    if (state == AppLifecycleState.resumed) {
      ref.read(sellerRegistrationViewModelProvider.notifier).refreshAccountStatus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  Widget _buildActionButton(UserModel user, SellerRegistrationState viewState, SellerRegistrationViewModel viewModel) {
    final isLoading = viewState.isLoading;

    final statusAsync = ref.watch(sellerAccountStatusProvider);
    final status = statusAsync.valueOrNull;

    // C-5: Read from sellerAccountStatusProvider instead of UserModel
    final hasAccount = status != null && status.isSeller; // isSeller implies a seller profile exists
    final canReceivePayouts = status?.chargesEnabled ?? false; // In SellerAccountStatus, chargesEnabled implies payoutsEnabled
    final onboardingCompleted = status?.detailsSubmitted ?? false;
    final hasPendingRequirements = status?.hasPendingRequirements ?? false;
    final hasError = viewState.error != null && viewState.error!.isNotEmpty;

    String buttonText;
    VoidCallback? onPressed;

    if (canReceivePayouts) {
      // Already set up - can manage without accepting terms again
      buttonText = 'seller.manage_stripe'.tr();
      onPressed = viewModel.openStripeDashboard;
    } else if (hasAccount && onboardingCompleted && hasPendingRequirements && !hasError) {
      // Has account, submitted details, but still has requirements to complete
      buttonText = 'seller.complete_documents'.tr();
      onPressed = viewModel.continueOnboarding;
    } else if (hasAccount && onboardingCompleted && !hasError) {
      // Has account, submitted all details, waiting for Stripe verification
      buttonText = 'seller.check_verification'.tr();
      onPressed = viewModel.openStripeDashboard;
    } else if (hasAccount && !onboardingCompleted && !hasError) {
      // Has account but hasn't finished providing info to Stripe
      buttonText = 'seller.complete_stripe_setup'.tr();
      onPressed = viewModel.continueOnboarding;
    } else if (hasAccount && hasError) {
      // Has account but onboarding link failed - allow retry
      buttonText = 'seller.retry_stripe_setup'.tr();
      onPressed = viewModel.continueOnboarding;
    } else {
      // New registration - MUST accept terms
      buttonText = 'seller.start_registration'.tr();
      onPressed = _termsAccepted ? viewModel.startRegistration : null;
    }

    return Semantics(
      button: true,
      label: 'btn-seller-action',
      child: ModernButton(
        key: const Key('seller_action_button'),
        onPressed: isLoading ? null : onPressed,
        label: buttonText,
        isLoading: isLoading,
        icon: canReceivePayouts
            ? Icons.dashboard
            : hasAccount
            ? Icons.check_circle
            : Icons.store,
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [DesignTokens.primary.withValues(alpha: 0.2), DesignTokens.secondary.withValues(alpha: 0.1)]),
            borderRadius: BorderRadius.circular(DesignTokens.radius8),
          ),
          child: Icon(icon, color: DesignTokens.primary, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.4)),
        ),
      ],
    );
  }

  Widget _buildBenefitsCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isDark ? DesignTokens.textPrimary.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.8),
            isDark ? DesignTokens.textPrimary.withValues(alpha: 0.4) : DesignTokens.surface.withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DesignTokens.radius16),
        border: Border.all(color: DesignTokens.primary.withValues(alpha: 0.2), width: 1),
        boxShadow: [BoxShadow(color: DesignTokens.primary.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(colors: [DesignTokens.primary, DesignTokens.secondary]).createShader(bounds),
            child: Text(
              'seller.why_sell_with_us'.tr(),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(height: 20),
          _buildBenefitItem(Icons.people, 'seller.access_customers'.tr()),
          const SizedBox(height: 12),
          _buildBenefitItem(Icons.credit_card, 'seller.secure_processing'.tr()),
          const SizedBox(height: 12),
          _buildBenefitItem(Icons.speed, 'seller.fast_payouts'.tr()),
          const SizedBox(height: 12),
          _buildBenefitItem(Icons.analytics, 'seller.track_sales'.tr()),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [DesignTokens.primary.withValues(alpha: 0.95), DesignTokens.secondary.withValues(alpha: 0.95)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DesignTokens.radius20),
        boxShadow: [BoxShadow(color: DesignTokens.primary.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: Icon(Icons.store, size: 50, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Text(
            'seller.sell_on_origna'.tr(),
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'seller.reach_customers'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderInfoCard(PaymentProviderConfig config) {
    // Check backend configuration status
    final backendStatus = ref.watch(paymentProviderStatusProvider);
    final isConfiguredInBackend = backendStatus.when(
      data: (statusMap) {
        final providerStatus = statusMap[config.id];
        if (providerStatus == null) return true;
        return providerStatus[ApiKeys.configured] == true;
      },
      loading: () => true,
      error: (_, _) => true,
    );
    final isDisabled = config.comingSoon || !isConfiguredInBackend;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [config.primaryColor.withValues(alpha: 0.1), config.secondaryColor.withValues(alpha: 0.05)]),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: config.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(config.icon, size: 18, color: config.primaryColor),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'seller.payout_timing'.tr(namedArgs: {'timing': config.payoutTiming}),
                  style: TextStyle(fontWeight: FontWeight.w600, color: config.primaryColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(config.features.map((f) => '• $f').join('\n'), style: TextStyle(color: DesignTokens.textPrimary, fontSize: 12, height: 1.5)),
          if (isDisabled) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: DesignTokens.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: DesignTokens.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule, size: 14, color: DesignTokens.warning),
                  const SizedBox(width: 4),
                  Text(
                    'seller.coming_soon'.tr(),
                    style: TextStyle(fontSize: 11, color: DesignTokens.warning, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProviderSelector(UserModel user, SellerRegistrationState state, SellerRegistrationViewModel viewModel) {
    final provider = user.paymentProvider.isNotEmpty ? user.paymentProvider : state.paymentProvider;
    final selectedConfig = availablePaymentProviders.firstWhere((p) => p.id == provider, orElse: () => availablePaymentProviders.first);

    // Watch backend provider status once — pass resolved value into the map to avoid double-watch
    final backendStatus = ref.watch(paymentProviderStatusProvider);
    final backendStatusMap = backendStatus.valueOrNull ?? {};

    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'seller.payment_provider'.tr(),
            style: TextStyle(fontWeight: FontWeight.w700, color: DesignTokens.primary),
          ),
          const SizedBox(height: 12),
          // Dynamic provider chips from configuration
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availablePaymentProviders.map((config) {
              final isSelected = provider == config.id;

              // Check if provider is configured in backend (defaults to true if unknown)
              final providerStatus = backendStatusMap[config.id];
              final isConfiguredInBackend = providerStatus == null ? true : providerStatus[ApiKeys.configured] == true;

              // Provider is disabled if it's marked "comingSoon" OR not configured in backend
              final isDisabled = config.comingSoon || !isConfiguredInBackend;

              return Stack(
                children: [
                  ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(config.icon, size: 16, color: isSelected ? Colors.white : (isDisabled ? DesignTokens.textSecondary : config.primaryColor)),
                        const SizedBox(width: 6),
                        Text(config.name),
                        if (isDisabled) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(color: DesignTokens.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              'seller.soon_badge'.tr(),
                              style: TextStyle(fontSize: 9, color: DesignTokens.warning, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ],
                    ),
                    selected: isSelected && !isDisabled,
                    onSelected: isDisabled
                        ? null
                        : (selected) {
                            if (selected) viewModel.setPaymentProvider(config.id);
                          },
                    selectedColor: config.primaryColor,
                    backgroundColor: isDisabled ? DesignTokens.outlineVariant : null,
                    labelStyle: TextStyle(color: isSelected && !isDisabled ? Colors.white : (isDisabled ? DesignTokens.textSecondary : null)),
                  ),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          // Dynamic payment timing info card based on selected provider
          _buildProviderInfoCard(selectedConfig),
          const SizedBox(height: 8),
          Text(selectedConfig.recommendedFor, style: TextStyle(color: DesignTokens.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  /// Build verification status info card — reads Stripe status from seller_profiles/{uid}
  /// via sellerAccountStatusProvider (not UserModel, which only reads users/{uid}).
  Widget _buildVerificationStatusCard(UserModel user) {
    // Stripe status fields live in seller_profiles/{uid}, not users/{uid}.
    // Use sellerAccountStatusProvider which correctly combines both collections.
    final statusAsync = ref.watch(sellerAccountStatusProvider);
    final status = statusAsync.valueOrNull;

    final hasAccount = user.stripeAccountId != null && user.stripeAccountId!.isNotEmpty;
    final onboardingCompleted = status?.detailsSubmitted ?? false;
    final chargesEnabled = status?.chargesEnabled ?? false;
    final payoutsEnabled = status?.chargesEnabled ?? false; // chargesEnabled combines both in SellerAccountStatus

    // Only show if user has account but verification is pending
    if (!hasAccount || (chargesEnabled && payoutsEnabled)) return const SizedBox.shrink();

    String title;
    String message;
    IconData icon;
    Color color;

    if (!onboardingCompleted) {
      title = 'seller.complete_your_setup'.tr();
      message = 'seller.complete_setup_card_body'.tr();
      icon = Icons.assignment_outlined;
      color = DesignTokens.primary;
    } else if (!chargesEnabled || !payoutsEnabled) {
      title = 'seller.identity_pending'.tr();
      message = 'seller.identity_pending_card_body'.tr();
      icon = Icons.hourglass_empty;
      color = DesignTokens.warning;
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(DesignTokens.radius12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(message, style: TextStyle(color: DesignTokens.textPrimary, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Status row builder - reserved for future use if needed
}
