// coverage:ignore-file
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/routes.dart';
import 'package:origna_gta/features/auth/auth_provider.dart';
import 'package:origna_gta/features/checkout/checkout_provider.dart';
import 'package:origna_gta/features/subscription/subscription_provider.dart';
import 'package:origna_gta/utils/constants.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/utils/responsive_layout.dart';
import 'package:origna_gta/utils/utils.dart';
import 'package:origna_gta/widgets/custom_app_bar.dart';
import 'package:origna_gta/widgets/modern_button.dart';
import 'package:origna_gta/widgets/modern_loading_indicator.dart';
import 'package:url_launcher/url_launcher.dart';

/// Compact 3-step progress indicator for the checkout flow.
/// Steps: Cart (0) → Details (1) → Confirm (2)
class _CheckoutStepper extends StatelessWidget {
  final int currentStep; // 0 = cart, 1 = address, 2 = payment/confirm

  const _CheckoutStepper({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final steps = [
      'checkout.step_cart'.tr(),
      'checkout.step_details'.tr(),
      'checkout.step_confirm'.tr(),
    ];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: isDark ? DesignTokens.darkSurface : Colors.white,
        boxShadow: [
          BoxShadow(
            color: DesignTokens.primary.withValues(alpha: isDark ? 0.08 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            // Connector line
            final stepIndex = (i + 1) ~/ 2;
            final isCompleted = stepIndex <= currentStep;
            return Expanded(
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: isCompleted
                      ? const LinearGradient(
                          colors: [DesignTokens.primary, DesignTokens.secondary],
                        )
                      : null,
                  color: isCompleted ? null : DesignTokens.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            );
          }
          final stepIndex = i ~/ 2;
          final isCompleted = stepIndex < currentStep;
          final isCurrent = stepIndex == currentStep;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? DesignTokens.success
                      : isCurrent
                          ? DesignTokens.primary
                          : DesignTokens.primary.withValues(alpha: 0.12),
                  border: isCurrent
                      ? Border.all(color: DesignTokens.primary, width: 2)
                      : null,
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                      : Text(
                          '${stepIndex + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isCurrent ? Colors.white : DesignTokens.primary.withValues(alpha: 0.5),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                steps[stepIndex],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  color: isCurrent ? DesignTokens.primary : DesignTokens.textSecondary,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// Provider for terms acceptance state — shared between _TermsText and _CheckoutButton
final _termsAcceptedProvider = StateProvider.autoDispose<bool>((ref) => false);

/// Tracks whether the user has interacted with the terms checkbox — gates error state
final _termsInteractedProvider = StateProvider.autoDispose<bool>((ref) => false);

/// Provider for digital product EULA acceptance — required when cart contains digital items
final _eulaAcceptedProvider = StateProvider.autoDispose<bool>((ref) => false);

/// Tracks whether user has interacted with the EULA checkbox — gates error display
final _eulaInteractedProvider = StateProvider.autoDispose<bool>((ref) => false);

/// Provider for age verification acceptance — required when cart contains age-restricted items
final _ageVerifAcceptedProvider = StateProvider.autoDispose<bool>((ref) => false);

/// Tracks whether user has interacted with the age gate checkbox — gates error display
final _ageVerifInteractedProvider = StateProvider.autoDispose<bool>((ref) => false);

/// Documentation for CheckoutScreen
class CheckoutScreen extends ConsumerStatefulWidget {
  final List<CartItemDetailModel> items;
  final double total;

  const CheckoutScreen({super.key, required this.items, required this.total});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _AddressSection extends StatelessWidget {
  final Address address;
  final VoidCallback onRefreshShipping;

  const _AddressSection({required this.address, required this.onRefreshShipping});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      key: const Key('checkout_address_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [DesignTokens.primary, DesignTokens.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: Text(
                  'checkout.delivery_address_title'.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ),
            ),
            Semantics(
              button: true,
              label: 'btn-edit-address',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const Key('checkout_edit_address_button'),
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.addressManagement).then((_) => onRefreshShipping());
                  },
                  borderRadius: BorderRadius.circular(8),
                  splashColor: DesignTokens.primary.withValues(alpha: 0.3),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_outlined, size: 18, color: DesignTokens.primary),
                        const SizedBox(width: 6),
                        Text(
                          'checkout.edit_action'.tr(),
                          style: TextStyle(color: DesignTokens.primary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GlassContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (address.label != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [DesignTokens.primary.withValues(alpha: 0.2), DesignTokens.secondary.withValues(alpha: 0.2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    address.label!,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: DesignTokens.primary),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(address.formattedAddress, style: TextStyle(fontSize: 15, height: 1.6, color: isDark ? DesignTokens.outline : DesignTokens.textPrimary)),
              if (address.phoneNumber != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.phone_outlined, size: 16, color: DesignTokens.primary),
                    const SizedBox(width: 10),
                    Text(address.phoneNumber!, style: TextStyle(color: isDark ? DesignTokens.outline : DesignTokens.textPrimary)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CheckoutButton extends ConsumerWidget {
  final List<CartItemDetailModel> items;
  final UserModel userModel;
  final double subtotal;
  final double total;

  const _CheckoutButton({required this.items, required this.userModel, required this.subtotal, required this.total});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isProcessing = ref.watch(checkoutStateProvider.select((state) => state.isProcessing));
    final isCalculating = ref.watch(checkoutStateProvider.select((state) => state.isCalculatingShipping));
    final shippingError = ref.watch(checkoutStateProvider.select((state) => state.shippingError));
    final termsAccepted = ref.watch(_termsAcceptedProvider);
    final eulaAccepted = ref.watch(_eulaAcceptedProvider);
    final ageVerifAccepted = ref.watch(_ageVerifAcceptedProvider);
    final hasDigitalItems = items.any((item) => item.isDigital);
    final hasAgeRestrictedItems = items.any((item) => item.isAgeRestricted);
    final isDisabled = isProcessing || isCalculating || shippingError != null || !termsAccepted || (hasDigitalItems && !eulaAccepted) || (hasAgeRestrictedItems && !ageVerifAccepted);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.fromLTRB(
        ResponsiveBreakpoints.getSpacing(context, SpacingSize.md),
        12,
        ResponsiveBreakpoints.getSpacing(context, SpacingSize.md),
        ResponsiveBreakpoints.getSpacing(context, SpacingSize.md),
      ),
      decoration: BoxDecoration(
        color: isDark ? DesignTokens.darkSurface : DesignTokens.surface,
        border: Border(top: BorderSide(color: DesignTokens.primary.withValues(alpha: 0.15))),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, -8))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            label: 'btn-place-order',
            child: ModernButton(
              key: const Key('checkout_place_order_button'),
              label: isProcessing ? 'common.processing'.tr() : 'checkout.place_order'.tr(),
              onPressed: isDisabled ? null : () => _showOrderReview(context, ref),
              isLoading: isProcessing,
              icon: Icons.payment,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outlined, size: 12, color: DesignTokens.success.withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              Text(
                'checkout.secure_stripe'.tr(),
                style: TextStyle(fontSize: 11, color: DesignTokens.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showOrderReview(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderReviewSheet(
        items: items,
        subtotal: subtotal,
        onConfirm: () {
          Navigator.of(context).pop();
          _startCheckout(context, ref);
        },
      ),
    );
  }

  Future<void> _redirectToStripe(String url, BuildContext context) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('checkout.stripe_redirect_failed'.tr()),
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: 'common.copy_link'.tr(),
            onPressed: () => Clipboard.setData(ClipboardData(text: url)),
          ),
        ),
      );
    }
  }

  Future<void> _startCheckout(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(checkoutStateProvider.notifier);

    final eulaAccepted = ref.read(_eulaAcceptedProvider);
    final ageVerificationAccepted = ref.read(_ageVerifAcceptedProvider);
    final result = await notifier.startCheckout(items: items, user: userModel, subtotal: subtotal, eulaAccepted: eulaAccepted, ageVerificationAccepted: ageVerificationAccepted);
    if (!context.mounted) return;

    switch (result) {
      case CheckoutSuccess(:final checkoutUrl):
        // Persist terms acceptance server-side (fire-and-forget — never blocks checkout redirect)
        // Failures are reported to Sentry so compliance gaps are visible (PIPEDA / CASL audit trail).
        ref.read(userRepositoryProvider).recordTermsAcceptance().catchError((Object e, StackTrace st) {
          Sentry.captureException(e, stackTrace: st, hint: Hint.withMap({'context': 'recordTermsAcceptance at checkout'}));
        });
        await _redirectToStripe(checkoutUrl, context);
      case CheckoutError(:final message):
        messenger.showSnackBar(
          SnackBar(
            content: Text('checkout.checkout_error'.tr(namedArgs: {'message': message})),
            backgroundColor: DesignTokens.error,
            duration: const Duration(seconds: 5),
          ),
        );
      case CheckoutAlreadyProcessed(:final existingOrderId):
        messenger.showSnackBar(
          SnackBar(
            content: Text('checkout.order_already_exists'.tr(namedArgs: {'id': existingOrderId})),
            backgroundColor: DesignTokens.primary,
          ),
        );
    }
  }
}

class _CheckoutContent extends ConsumerWidget {
  final List<CartItemDetailModel> items;
  final double subtotal;
  final UserModel userModel;
  final VoidCallback onRefreshShipping;

  const _CheckoutContent({required this.items, required this.subtotal, required this.userModel, required this.onRefreshShipping});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final address = ref.watch(checkoutStateProvider.select((state) => state.address));
    final shippingCost = ref.watch(checkoutStateProvider.select((state) => state.shippingCost));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasPhysicalItems = items.any((item) => !item.isDigital);
    final paymentProvider = ref.watch(checkoutStateProvider.select((state) => state.paymentProvider));
    final notifier = ref.read(checkoutStateProvider.notifier);

    if (address == null) {
      if (!hasPhysicalItems) {
        // Digital-only: use profile address province for tax, fallback to Ontario
        final rawState = userModel.address?.state;
        final digitalProvince = (rawState != null && rawState.trim().isNotEmpty) ? rawState.trim() : ProvinceCodeValues.ontario;
        final digitalTaxRate = getTaxRate(digitalProvince);
        final digitalCouponDiscountCents = ref.watch(checkoutStateProvider.select((s) => s.couponDiscountCents));
        final digitalEffective = (subtotal - digitalCouponDiscountCents / 100.0).clamp(0.0, double.infinity);
        // Platform fee is deducted from the seller's payout — NOT added to the buyer's charge.
        // Stripe PaymentIntent = discounted_subtotal + tax only. The fee row is informational only.
        final digitalTax = digitalEffective * digitalTaxRate;
        final digitalTotal = digitalEffective + digitalTax;
        return Container(
          decoration: BoxDecoration(
            gradient: DesignTokens.backgroundGradient(isDark: isDark),
          ),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GlassContainer(
                        child: Row(
                          children: [
                            Icon(Icons.download_done, color: DesignTokens.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'checkout.digital_delivery_no_address'.tr(),
                                style: TextStyle(color: isDark ? DesignTokens.outline : DesignTokens.textPrimary, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      _PaymentProviderSection(selectedProvider: paymentProvider, onChanged: notifier.setPaymentProvider),
                      const SizedBox(height: 28),
                      _CouponSection(subtotalCents: (subtotal * 100).round(), sellerIds: items.map((i) => i.sellerId).where((id) => id.isNotEmpty).toSet().toList()),
                      const SizedBox(height: 28),
                      _OrderSummary(items: items, subtotal: subtotal, state: digitalProvince),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
              const _BuyerProtectionBanner(),
              _CheckoutButton(items: items, userModel: userModel, subtotal: subtotal, total: digitalTotal),
              const _DigitalEulaText(),
              if (items.any((item) => item.isAgeRestricted)) const _AgeGateText(),
              _TermsText(),
              const SizedBox(height: 16),
              _SecurityInfo(),
            ],
          ),
        );
      }
      return _NoAddressView(onRefreshShipping: onRefreshShipping);
    }

    final couponDiscountCents = ref.watch(checkoutStateProvider.select((s) => s.couponDiscountCents));
    final discount = couponDiscountCents / 100.0;
    final effectiveSubtotal = (subtotal - discount).clamp(0.0, double.infinity);
    final taxRate = getTaxRate(address.state);
    // Platform fee is deducted from the seller's payout — NOT added to the buyer's charge.
    // Stripe PaymentIntent = discounted_subtotal + shipping + tax only. Fee row is informational.
    final taxableAmount = effectiveSubtotal + shippingCost; // GST/HST applies to shipping in Canada
    final tax = taxableAmount * taxRate;
    final totalWithTax = effectiveSubtotal + tax + shippingCost;

    final isDesktop = ResponsiveBreakpoints.isDesktop(context);
    final hPad = ResponsiveBreakpoints.getSpacing(context, SpacingSize.lg);
    final bgDecoration = BoxDecoration(
      gradient: DesignTokens.backgroundGradient(isDark: isDark),
    );

    // Form sections (shared between both layouts)
    final formSections = <Widget>[
      _AddressSection(address: address, onRefreshShipping: onRefreshShipping),
      SizedBox(height: ResponsiveBreakpoints.getSpacing(context, SpacingSize.xl)),
      if (hasPhysicalItems) ...[
        _FreeShippingBanner(subtotal: subtotal),
        const SizedBox(height: 12),
        const _DeliveryOptionsSection(),
        const SizedBox(height: 28),
      ] else ...[
        GlassContainer(
          child: Row(
            children: [
              Icon(Icons.download_done, color: DesignTokens.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'checkout.digital_delivery_no_shipping'.tr(),
                  style: TextStyle(color: isDark ? DesignTokens.outline : DesignTokens.textPrimary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
      ],
      _PaymentProviderSection(selectedProvider: paymentProvider, onChanged: notifier.setPaymentProvider),
      const SizedBox(height: 28),
      _CouponSection(subtotalCents: (subtotal * 100).round(), sellerIds: items.map((i) => i.sellerId).where((id) => id.isNotEmpty).toSet().toList()),
    ];

    // Sticky bottom actions (same in both layouts)
    final bottomActions = <Widget>[
      const _BuyerProtectionBanner(),
      _CheckoutButton(items: items, userModel: userModel, subtotal: subtotal, total: totalWithTax),
      if (items.any((item) => item.isDigital)) const _DigitalEulaText(),
      if (items.any((item) => item.isAgeRestricted)) const _AgeGateText(),
      _TermsText(),
      const SizedBox(height: 16),
      _SecurityInfo(),
    ];

    final orderSummary = _OrderSummary(items: items, subtotal: subtotal, state: address.state);

    // Desktop: 2-column — form left (60%), sticky order summary right (40%)
    if (isDesktop) {
      return Container(
        decoration: bgDecoration,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(hPad, hPad, hPad / 2, hPad),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: formSections),
                    ),
                  ),
                  ...bottomActions,
                ],
              ),
            ),
            // Order summary sidebar
            SizedBox(
              width: 360,
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad / 2, hPad, hPad, hPad),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? DesignTokens.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(DesignTokens.radius16),
                    border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : DesignTokens.outline.withValues(alpha: 0.3)),
                    boxShadow: [BoxShadow(color: DesignTokens.primary.withValues(alpha: isDark ? 0.1 : 0.06), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: orderSummary,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Mobile/tablet: single-column stacked layout
    return Container(
      decoration: bgDecoration,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(hPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...formSections,
                  const SizedBox(height: 28),
                  orderSummary,
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          ...bottomActions,
        ],
      ),
    );
  }
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userProfileProvider);

    final address = ref.watch(checkoutStateProvider.select((s) => s.address));
    // Step 0: Cart ✓ — Step 1: Address — Step 2: Payment/Confirm
    final stepIndex = address != null ? 2 : 1;

    return Scaffold(
      key: const Key('checkout_screen_root'),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(140),
        child: Column(
          children: [
            AppBarFactory.simple(title: 'checkout.checkout'.tr()),
            _CheckoutStepper(currentStep: stepIndex),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: ResponsiveBreakpoints.isDesktop(context) ? ResponsiveBreakpoints.contentMaxWidth : 800,
          ),
          child: userProfileAsync.when(
            loading: () => const ModernLoadingIndicator.fullScreen(),
            error: (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 48, color: DesignTokens.error),
                    const SizedBox(height: 16),
                    Text(AppError.getMessage(error), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ModernButton(
                      label: 'common.retry'.tr(),
                      icon: Icons.refresh,
                      isPrimary: false,
                      onPressed: () => ref.invalidate(userProfileProvider),
                    ),
                  ],
                ),
              ),
            ),
            data: (userProfile) {
              if (userProfile == null) {
                return Center(child: Text('checkout.please_login'.tr()));
              }
              return _CheckoutContent(items: widget.items, subtotal: widget.total, userModel: userProfile, onRefreshShipping: _refreshShipping);
            },
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCheckout();
    });
  }

  Future<void> _initializeCheckout() async {
    final notifier = ref.read(checkoutStateProvider.notifier);
    await notifier.initialize();
    if (!mounted) return; // Guard: widget may be disposed during async gap

    final state = ref.read(checkoutStateProvider);
    if (state.address != null) {
      await notifier.calculateShipping(widget.items);
      if (!mounted) return; // Guard: widget may be disposed during async gap
      final shipping = ref.read(checkoutStateProvider).shippingCost;
      notifier.calculateTaxes(widget.total, shippingCost: shipping);
    }
  }

  Future<void> _refreshShipping() async {
    final notifier = ref.read(checkoutStateProvider.notifier);
    // Re-initialize to fetch the newly selected default address
    await notifier.initialize();
    if (!mounted) return; // Guard: widget may be disposed during async gap

    final state = ref.read(checkoutStateProvider);
    if (state.address != null) {
      await notifier.calculateShipping(widget.items);
      if (!mounted) return; // Guard: widget may be disposed during async gap
      final shipping = ref.read(checkoutStateProvider).shippingCost;
      notifier.calculateTaxes(widget.total, shippingCost: shipping);
    }
  }
}

/// Delivery speed options selection
class _DeliveryOptionsSection extends ConsumerWidget {
  const _DeliveryOptionsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availableSpeeds = ref.watch(checkoutStateProvider.select((state) => state.availableDeliverySpeeds));
    final selectedSpeed = ref.watch(checkoutStateProvider.select((state) => state.deliverySpeed));
    final isCalculating = ref.watch(checkoutStateProvider.select((state) => state.isCalculatingShipping));
    final baseShippingCost = ref.watch(checkoutStateProvider.select((state) => state.baseShippingCost));

    if (isCalculating) {
      final isDarkCalc = Theme.of(context).brightness == Brightness.dark;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text('checkout.delivery_speed_title'.tr(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
              const SizedBox(
                width: 20,
                height: 20,
                child: ModernLoadingIndicator(strokeWidth: 2.5, color: DesignTokens.primary, centered: false),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ── AUDIT FIX [HIGH]: Skeleton cards replace blank space while calculating ──
          for (int i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                height: 72,
                decoration: BoxDecoration(
                  color: isDarkCalc
                      ? DesignTokens.darkCard.withValues(alpha: 0.7)
                      : DesignTokens.outlineVariant.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: Text('checkout.delivery_speed_title'.tr(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
            IconButton(
              onPressed: () => _showDeliveryInfo(context),
              icon: const Icon(Icons.info_outline, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'checkout.delivery_options_tooltip'.tr(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...DeliverySpeed.values.map((speed) {
          final isAvailable = availableSpeeds.contains(speed);
          final isSelected = selectedSpeed == speed;
          // Show total shipping cost (base + surcharge), not just surcharge
          final totalCost = speed == DeliverySpeed.standard ? baseShippingCost : baseShippingCost + speed.baseSurcharge;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Semantics(
              button: true,
              label: 'btn-delivery-speed-${speed.name}',
              child: GestureDetector(
                key: Key('checkout_delivery_speed_${speed.name}'),
                onTap: isAvailable ? () => ref.read(checkoutStateProvider.notifier).setDeliverySpeed(speed) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    // ── AUDIT FIX [HIGH]: was Colors.white — not dark-mode safe ──
                    color: isSelected
                        ? DesignTokens.primary.withValues(alpha: 0.08)
                        : (Theme.of(context).brightness == Brightness.dark
                            ? DesignTokens.darkCard
                            : Colors.white),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSelected ? DesignTokens.primary : DesignTokens.outlineVariant, width: isSelected ? 1.5 : 1),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 1))],
                  ),
                  child: Opacity(
                    opacity: isAvailable ? 1.0 : 0.5,
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: isSelected ? DesignTokens.primary : DesignTokens.outline, width: 2),
                          ),
                          child: isSelected
                              ? Center(
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: const BoxDecoration(shape: BoxShape.circle, color: DesignTokens.primary),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      speed.translatedName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                        color: isAvailable ? DesignTokens.textPrimary : DesignTokens.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (speed == DeliverySpeed.sameDay) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: DesignTokens.success, borderRadius: BorderRadius.circular(4)),
                                      child: Text(
                                        'checkout.local'.tr(),
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(speed.translatedTime, style: TextStyle(fontSize: 13, color: DesignTokens.textSecondary)),
                              if (!isAvailable && speed == DeliverySpeed.sameDay)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'checkout.local_only_50km'.tr(),
                                    style: TextStyle(fontSize: 11, color: DesignTokens.tertiary, fontStyle: FontStyle.italic),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          totalCost > 0 ? '\$${totalCost.toStringAsFixed(2)}' : 'checkout.free'.tr(),
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: totalCost > 0 ? DesignTokens.textPrimary : DesignTokens.success),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  static void _showDeliveryInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('checkout.delivery_options'.tr()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: DeliverySpeed.values.map((speed) {
              final surcharge = speed == DeliverySpeed.standard ? 0.0 : speed.baseSurcharge;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(speed.translatedName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        if (speed == DeliverySpeed.sameDay) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: DesignTokens.success, borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              'checkout.local'.tr(),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(speed.translatedTime, style: TextStyle(fontSize: 13, color: DesignTokens.textSecondary)),
                    if (speed == DeliverySpeed.sameDay)
                      Text(
                        'checkout.available_local_50km'.tr(),
                        style: TextStyle(fontSize: 12, color: DesignTokens.textSecondary, fontStyle: FontStyle.italic),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      surcharge > 0 ? 'checkout.additional_cost'.tr(namedArgs: {'amount': surcharge.toStringAsFixed(2)}) : 'checkout.no_additional_cost'.tr(),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: surcharge > 0 ? DesignTokens.textPrimary : DesignTokens.success),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('common.close'.tr()))],
      ),
    );
  }
}

class _NoAddressView extends StatelessWidget {
  final VoidCallback onRefreshShipping;

  const _NoAddressView({required this.onRefreshShipping});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 80, color: DesignTokens.textDisabled),
            const SizedBox(height: 24),
            Text('checkout.no_address_title'.tr(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              'checkout.no_address_desc'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(color: DesignTokens.textSecondary),
            ),
            const SizedBox(height: 32),
            Semantics(
              button: true,
              label: 'btn-add-address',
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.addressManagement).then((_) => onRefreshShipping());
                },
                icon: const Icon(Icons.add_location),
                label: Text('checkout.add_address'.tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DesignTokens.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderSummary extends ConsumerWidget {
  final List<CartItemDetailModel> items;
  final double subtotal;
  final String state;

  const _OrderSummary({required this.items, required this.subtotal, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shippingCost = ref.watch(checkoutStateProvider.select((state) => state.shippingCost));
    final isCalculating = ref.watch(checkoutStateProvider.select((state) => state.isCalculatingShipping));
    final shippingError = ref.watch(checkoutStateProvider.select((state) => state.shippingError));
    final isPremium = ref.watch(subscriptionStreamProvider).whenOrNull(data: (s) => s?.isPremium) ?? false;
    final couponDiscountCentsForTax = ref.watch(checkoutStateProvider.select((s) => s.couponDiscountCents));
    final effectiveSubtotalForTax = (subtotal - couponDiscountCentsForTax / 100.0).clamp(0.0, double.infinity);

    return Column(
      key: const Key('checkout_summary_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('checkout.order_summary_title'.tr(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? DesignTokens.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            children: [
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text('${item.name} x${item.quantity}', style: const TextStyle(fontSize: 14))),
                      Text('\$${(item.price * item.quantity).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(child: Text('cart.subtotal'.tr(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16))),
                  const SizedBox(width: 8),
                  Text('\$${subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16)),
                ],
              ),
              const SizedBox(height: 8),
              _buildCouponDiscountRow(ref),
              _buildPlatformFeeRow(ref, isPremium),
              ..._buildTaxBreakdown(state, effectiveSubtotalForTax + shippingCost),
              const SizedBox(height: 8),
              Row(
                key: const Key('checkout_shipping_section'),
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(child: Text('checkout.estimated_shipping'.tr(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: DesignTokens.textSecondary))),
                  const SizedBox(width: 8),
                  if (isCalculating)
                    const ModernLoadingIndicator.small()
                  else if (shippingError != null)
                    Text(shippingError, style: const TextStyle(color: DesignTokens.error, fontSize: 12))
                  else
                    Text('\$${shippingCost.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              if (!isCalculating && shippingError == null && shippingCost > 0) ...[
                const SizedBox(height: 4),
                // Per-seller shipping breakdown (FEAT-3)
                Builder(builder: (context) {
                  final sellerCosts = ref.watch(checkoutStateProvider.select((s) => s.sellerShippingCosts));
                  final sellerNames = ref.watch(checkoutStateProvider.select((s) => s.sellerNames));
                  if (sellerCosts.length <= 1) return const SizedBox.shrink();

                  return Column(
                    children: sellerCosts.entries.map((entry) {
                      final name = sellerNames[entry.key] ?? entry.key;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2, left: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              ' • $name',
                              style: TextStyle(fontSize: 11, color: DesignTokens.textTertiary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '\$${entry.value.toStringAsFixed(2)}',
                              style: TextStyle(fontSize: 11, color: DesignTokens.textTertiary),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                }),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'checkout.shipping_confirmed_by_seller'.tr(),
                    style: TextStyle(fontSize: 11, color: DesignTokens.textSecondary, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(child: Text('checkout.estimated_total'.tr(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 8),
                  Builder(builder: (context) {
                    final discountCents = ref.watch(checkoutStateProvider.select((s) => s.couponDiscountCents));
                    final discount = discountCents / 100.0;
                    final effective = (subtotal - discount).clamp(0.0, double.infinity);
                    // Platform fee is deducted from seller's payout — NOT added to buyer charge.
                    // Stripe PaymentIntent = discounted_subtotal + shipping + tax only.
                    final total = effective + (getTaxRate(state) * (effective + shippingCost)) + shippingCost;
                    return Text(
                      '\$${total.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: DesignTokens.primary),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'checkout.tax_confirm_notice'.tr(),
                style: TextStyle(fontSize: 12, color: DesignTokens.textSecondary, fontStyle: FontStyle.italic),
              ),
              Builder(builder: (context) {
                final hasIntl = ref.watch(checkoutStateProvider.select((s) => s.hasInternationalItems));
                if (!hasIntl) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: DesignTokens.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: DesignTokens.warning.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 16, color: DesignTokens.warning),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'checkout.brokerage_fee_warning'.tr(),
                            style: TextStyle(fontSize: 11, color: DesignTokens.textSecondary, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCouponDiscountRow(WidgetRef ref) {
    final discountCents = ref.watch(checkoutStateProvider.select((s) => s.couponDiscountCents));
    final couponCode = ref.watch(checkoutStateProvider.select((s) => s.couponCode));
    if (discountCents <= 0 || couponCode == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              children: [
                const Icon(Icons.local_offer_rounded, size: 14, color: DesignTokens.success),
                const SizedBox(width: 4),
                Flexible(child: Text('checkout.coupon_applied_label'.tr(namedArgs: {'code': couponCode}), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: DesignTokens.success))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('-\$${(discountCents / 100.0).toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, color: DesignTokens.success, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildPlatformFeeRow(WidgetRef ref, bool isPremium) {
    final discountCents = ref.watch(checkoutStateProvider.select((s) => s.couponDiscountCents));
    final discount = discountCents / 100.0;
    final effective = (subtotal - discount).clamp(0.0, double.infinity);
    final feeAmount = effective * (BusinessRules.platformFeePercent / 100.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              children: [
                Icon(
                  isPremium ? Icons.star_rounded : Icons.info_outline_rounded,
                  size: 14,
                  color: isPremium ? DesignTokens.secondary : DesignTokens.textSecondary,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'checkout.service_fee_label'.tr(namedArgs: {'rate': BusinessRules.platformFeePercent.toStringAsFixed(1)}),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: isPremium ? DesignTokens.textSecondary : DesignTokens.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isPremium)
            Row(
              children: [
                Text(
                  '\$${feeAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: DesignTokens.textDisabled,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: DesignTokens.textDisabled,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [DesignTokens.gradientStart, DesignTokens.gradientEnd]),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'checkout.service_fee_free'.tr(),
                    style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            )
          else
            Text('\$${feeAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, color: DesignTokens.textSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  List<Widget> _buildTaxBreakdown(String province, double total) {
    final taxes = taxConfig[province] ?? {'HST': 0.13};
    List<Widget> widgets = [];

    taxes.forEach((taxName, rate) {
      final taxAmount = total * rate;
      widgets.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'checkout.tax_estimate_label'.tr(namedArgs: {'name': taxName, 'rate': (rate * 100).toStringAsFixed(2)}),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: DesignTokens.textSecondary),
              ),
            ),
            const SizedBox(width: 8),
            Text('\$${taxAmount.toStringAsFixed(2)}', style: TextStyle(fontSize: 14, color: DesignTokens.textSecondary)),
          ],
        ),
      );
      widgets.add(const SizedBox(height: 4));
    });

    // Excise Tax Act s.223: GST/HST registration number must appear on sales receipts
    widgets.add(
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          'GST/HST Reg: ${EmailConfig.gstHstNumber}',
          style: TextStyle(fontSize: 11, color: DesignTokens.textSecondary),
        ),
      ),
    );

    return widgets;
  }
}

// ============================================================================
// COUPON SECTION (N-07)
// ============================================================================

class _CouponSection extends ConsumerStatefulWidget {
  final int subtotalCents;
  // AUDIT FIX (HIGH-C4): Pass seller IDs so seller-scoped coupon validation works
  final List<String> sellerIds;

  const _CouponSection({required this.subtotalCents, this.sellerIds = const []});

  @override
  ConsumerState<_CouponSection> createState() => _CouponSectionState();
}

class _CouponSectionState extends ConsumerState<_CouponSection> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final couponCode = ref.watch(checkoutStateProvider.select((s) => s.couponCode));
    final isLoading = ref.watch(checkoutStateProvider.select((s) => s.isCouponLoading));
    final isProcessing = ref.watch(checkoutStateProvider.select((s) => s.isProcessing));
    final couponError = ref.watch(checkoutStateProvider.select((s) => s.couponError));
    final notifier = ref.read(checkoutStateProvider.notifier);
    final applied = couponCode != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('checkout.coupon_title'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('checkout_coupon_field'),
                controller: _controller,
                enabled: !applied && !isLoading && !isProcessing,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'checkout.coupon_hint'.tr(),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark ? DesignTokens.darkCard : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: DesignTokens.outline.withValues(alpha: 0.3))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: DesignTokens.outline.withValues(alpha: 0.3))),
                  errorText: couponError,
                  prefixIcon: const Icon(Icons.local_offer_outlined, size: 20),
                  suffixIcon: applied
                      ? Icon(Icons.check_circle, color: DesignTokens.success, size: 20)
                      : null,
                ),
                onSubmitted: (_) => _apply(notifier),
              ),
            ),
            const SizedBox(width: 10),
            applied
                ? TextButton(
                    onPressed: () {
                      _controller.clear();
                      notifier.removeCoupon();
                    },
                    child: Text('common.remove'.tr(), style: TextStyle(color: DesignTokens.error)),
                  )
                : ElevatedButton(
                    key: const Key('checkout_apply_coupon_button'),
                    onPressed: (isLoading || isProcessing) ? null : () => _apply(notifier),
                    style: ElevatedButton.styleFrom(backgroundColor: DesignTokens.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: isLoading ? const SizedBox(width: 18, height: 18, child: ModernLoadingIndicator(strokeWidth: 2)) : Text('common.apply'.tr()),
                  ),
          ],
        ),
      ],
    );
  }

  void _apply(CheckoutNotifier notifier) {
    final code = _controller.text.trim();
    if (code.isEmpty) return;
    // AUDIT FIX (HIGH-C4): Pass sellerIds for server-side seller-scoped validation
    notifier.applyCoupon(code, widget.subtotalCents, sellerIds: widget.sellerIds);
  }
}

class _PaymentProviderSection extends StatelessWidget {
  final String selectedProvider;
  final ValueChanged<String> onChanged;

  const _PaymentProviderSection({required this.selectedProvider, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // Stripe is the only integrated payment provider
    return Column(
      key: const Key('checkout_payment_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('checkout.payment_method_title'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [ChoiceChip(label: Text('payment.stripe'.tr()), selected: true, onSelected: (_) {})],
        ),
        const SizedBox(height: 8),
        Text('checkout.stripe_secure_notice'.tr(), style: TextStyle(color: DesignTokens.textSecondary, fontSize: 12)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: ['VISA', 'MC', 'AMEX', 'Apple Pay', 'Google Pay'].map((label) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                border: Border.all(color: DesignTokens.outline),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: DesignTokens.textSecondary)),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _BuyerProtectionBanner extends StatelessWidget {
  const _BuyerProtectionBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('checkout_buyer_protection_banner'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DesignTokens.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DesignTokens.success.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, color: DesignTokens.success, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'checkout.buyer_protection_title'.tr(),
                  style: TextStyle(color: DesignTokens.success, fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'checkout.buyer_protection_message'.tr(),
                  style: TextStyle(color: DesignTokens.success.withValues(alpha: 0.85), fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 6),
                Semantics(
                  link: true,
                  label: 'link-buyer-protection',
                  child: GestureDetector(
                    onTap: () => launchUrl(Uri.parse('https://www.orignagta.ca/buyer-protection'), mode: LaunchMode.externalApplication),
                    child: Text(
                      'checkout.buyer_protection_link'.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        color: DesignTokens.success,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: DesignTokens.success,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SecurityInfo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('checkout_secure_badge'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DesignTokens.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DesignTokens.info.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, color: DesignTokens.info, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'checkout.secure_payment'.tr(),
                  style: TextStyle(color: DesignTokens.info, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text('checkout.stripe_secure'.tr(), style: TextStyle(color: DesignTokens.info.withValues(alpha: 0.8), fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// FREE SHIPPING THRESHOLD BANNER
// ============================================================================

/// Shows "Spend $X.XX more for free shipping!" when subtotal is below the threshold.
/// Disappears when shipping is already free or the threshold is reached.
class _FreeShippingBanner extends ConsumerWidget {
  final double subtotal;

  const _FreeShippingBanner({required this.subtotal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shippingCost = ref.watch(checkoutStateProvider.select((s) => s.shippingCost));
    final isCalculating = ref.watch(checkoutStateProvider.select((s) => s.isCalculatingShipping));

    if (isCalculating || shippingCost == 0) return const SizedBox.shrink();

    const thresholdCents = BusinessRules.freeShippingThresholdCents;
    final subtotalCents = (subtotal * 100).round();
    final remainingCents = thresholdCents - subtotalCents;
    if (remainingCents <= 0) return const SizedBox.shrink();

    final remaining = remainingCents / 100.0;
    final progress = (subtotalCents / thresholdCents).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [DesignTokens.tertiary.withValues(alpha: 0.12), DesignTokens.success.withValues(alpha: 0.10)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DesignTokens.tertiary.withValues(alpha: 0.35), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping_outlined, size: 17, color: DesignTokens.tertiary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'checkout.free_shipping_banner'.tr(namedArgs: {'amount': '\$${remaining.toStringAsFixed(2)}'}),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: DesignTokens.tertiary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: DesignTokens.outlineVariant,
              valueColor: AlwaysStoppedAnimation<Color>(DesignTokens.tertiary),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ORDER REVIEW SHEET
// ============================================================================

/// Bottom sheet shown before Stripe redirect — lets the user review the full order.
class _OrderReviewSheet extends ConsumerWidget {
  final List<CartItemDetailModel> items;
  final double subtotal;
  final VoidCallback onConfirm;

  const _OrderReviewSheet({required this.items, required this.subtotal, required this.onConfirm});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use targeted selects so this sheet only rebuilds when the fields it
    // actually reads change — not on every checkoutStateProvider mutation.
    final couponDiscountCents = ref.watch(checkoutStateProvider.select((s) => s.couponDiscountCents));
    final addressState = ref.watch(checkoutStateProvider.select((s) => s.address?.state));
    final formattedAddress = ref.watch(checkoutStateProvider.select((s) => s.address?.formattedAddress));
    final couponCode = ref.watch(checkoutStateProvider.select((s) => s.couponCode));
    final shippingCost = ref.watch(checkoutStateProvider.select((s) => s.shippingCost));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final couponDiscount = couponDiscountCents / 100.0;
    final effectiveSubtotal = (subtotal - couponDiscount).clamp(0.0, double.infinity);
    final province = addressState ?? ProvinceCodeValues.ontario;
    final taxRate = getTaxRate(province);
    // Platform fee is deducted from the seller's payout — NOT added to the buyer's charge.
    // Stripe PaymentIntent = discounted_subtotal + shipping + tax only. Fee row is informational.
    final tax = (effectiveSubtotal + shippingCost) * taxRate;
    final total = effectiveSubtotal + shippingCost + tax;

    final bgColor = isDark ? DesignTokens.darkCard : Colors.white;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, -4))],
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: DesignTokens.outline.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(2)),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  Flexible(
                    child: ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [DesignTokens.primary, DesignTokens.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: Text(
                        'checkout.order_review_title'.tr(),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text('checkout.order_review_subtitle'.tr(), style: TextStyle(fontSize: 13, color: DesignTokens.textSecondary)),
            ),
            const Divider(height: 1),
            // Scrollable content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  // Items
                  Text(
                    'checkout.order_review_items'.tr(namedArgs: {'count': '${items.length}'}),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: item.imageUrls.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: item.imageUrls.first,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => _ItemImagePlaceholder(),
                                    errorWidget: (context, url, error) => _ItemImagePlaceholder(),
                                  )
                                : _ItemImagePlaceholder(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Text('×${item.quantity}', style: TextStyle(fontSize: 13, color: DesignTokens.textSecondary)),
                              ],
                            ),
                          ),
                          Text('\$${(item.price * item.quantity).toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  // Shipping address
                  if (formattedAddress != null) ...[
                    const Divider(height: 24),
                    Text('checkout.order_review_shipping_to'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    GlassContainer(
                      child: Text(
                        formattedAddress,
                        style: TextStyle(fontSize: 14, height: 1.5, color: isDark ? DesignTokens.outline : DesignTokens.textPrimary),
                      ),
                    ),
                  ],
                  // Price breakdown
                  const Divider(height: 24),
                  _buildPriceLine('cart.subtotal'.tr(), subtotal),
                  if (couponDiscount > 0)
                    _buildCouponLine(couponCode, couponDiscount),
                  _buildPriceLine('checkout.estimated_shipping'.tr(), shippingCost),
                  _buildPriceLine(
                    'checkout.tax_estimate_label'.tr(namedArgs: {'name': 'checkout.tax_label'.tr(), 'rate': (taxRate * 100).toStringAsFixed(2)}),
                    tax,
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(child: Text('checkout.estimated_total'.tr(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                      const SizedBox(width: 8),
                      Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: DesignTokens.primary)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('checkout.tax_confirm_notice'.tr(), style: TextStyle(fontSize: 11, color: DesignTokens.textSecondary, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            // Confirm & Pay button
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).padding.bottom + 16),
              child: Semantics(
                button: true,
                label: 'btn-confirm-pay',
                child: ModernButton(
                  key: const Key('checkout_confirm_pay_button'),
                  label: 'checkout.order_review_confirm'.tr(),
                  onPressed: onConfirm,
                  icon: Icons.payment,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceLine(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: DesignTokens.textSecondary))),
          Text('\$${amount.toStringAsFixed(2)}', style: TextStyle(fontSize: 14, color: DesignTokens.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildCouponLine(String? code, double discount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              children: [
                const Icon(Icons.local_offer_rounded, size: 14, color: DesignTokens.success),
                const SizedBox(width: 4),
                Flexible(child: Text(code != null ? 'checkout.coupon_applied_label'.tr(namedArgs: {'code': code}) : 'checkout.coupon_applied_generic'.tr(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: DesignTokens.success))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('-\$${discount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, color: DesignTokens.success, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Small placeholder shown when a product image fails to load or is unavailable.
class _ItemImagePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          colors: [DesignTokens.primary.withValues(alpha: 0.1), DesignTokens.secondary.withValues(alpha: 0.07)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: DesignTokens.primary.withValues(alpha: 0.12), width: 1),
      ),
      child: Icon(Icons.camera_alt_outlined, size: 22, color: DesignTokens.primary.withValues(alpha: 0.5)),
    );
  }
}

class _TermsText extends ConsumerWidget {
  const _TermsText();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final termsAccepted = ref.watch(_termsAcceptedProvider);
    final hasInteracted = ref.watch(_termsInteractedProvider);
    final showError = hasInteracted && !termsAccepted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: DesignTokens.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: showError ? DesignTokens.error : DesignTokens.outlineVariant, width: 1),
        ),
        child: Row(
          key: const Key('checkout_terms_link'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 20,
              width: 20,
              child: Semantics(
                label: 'chk-terms-accepted',
                checked: termsAccepted,
                child: Checkbox(
                  key: const Key('checkout_terms_checkbox'),
                  value: termsAccepted,
                  onChanged: (value) {
                    ref.read(_termsInteractedProvider.notifier).state = true;
                    ref.read(_termsAcceptedProvider.notifier).state = value ?? false;
                  },
                  side: BorderSide(color: showError ? DesignTokens.error : DesignTokens.textDisabled),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 13, color: DesignTokens.textPrimary, height: 1.4),
                  children: [
                    TextSpan(text: 'checkout.terms_agree'.tr()),
                    WidgetSpan(
                      child: Semantics(
                        link: true,
                        label: 'link-terms-conditions',
                        child: GestureDetector(
                          onTap: () => openTermsOfService(context),
                          child: Text(
                            'checkout.terms_link'.tr(),
                            style: TextStyle(
                              fontSize: 13,
                              color: DesignTokens.primary,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                              decorationColor: DesignTokens.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    TextSpan(text: ' ${'checkout.and_label'.tr()} '),
                    WidgetSpan(
                      child: Semantics(
                        link: true,
                        label: 'link-privacy-policy',
                        child: GestureDetector(
                          onTap: () => openPrivacyPolicy(context),
                          child: Text(
                            'checkout.privacy_link'.tr(),
                            style: TextStyle(
                              fontSize: 13,
                              color: DesignTokens.primary,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                              decorationColor: DesignTokens.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// EULA checkbox shown when digital products (software, ebooks, etc.) are in the cart.
/// Canadian consumer law requires explicit license acceptance before digital delivery.
class _DigitalEulaText extends ConsumerWidget {
  const _DigitalEulaText();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eulaAccepted = ref.watch(_eulaAcceptedProvider);
    final hasInteracted = ref.watch(_eulaInteractedProvider);
    final showError = hasInteracted && !eulaAccepted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: DesignTokens.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: showError ? DesignTokens.error : DesignTokens.outlineVariant, width: 1),
        ),
        child: Row(
          key: const Key('checkout_digital_eula'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 20,
              width: 20,
              child: Semantics(
                label: 'chk-eula-accepted',
                checked: eulaAccepted,
                child: Checkbox(
                  key: const Key('checkout_eula_checkbox'),
                  value: eulaAccepted,
                  onChanged: (value) {
                    ref.read(_eulaInteractedProvider.notifier).state = true;
                    ref.read(_eulaAcceptedProvider.notifier).state = value ?? false;
                  },
                  side: BorderSide(color: showError ? DesignTokens.error : DesignTokens.textDisabled),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'checkout.digital_eula_agree'.tr(),
                style: TextStyle(fontSize: 13, color: DesignTokens.textPrimary, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Age gate widget — shown when cart contains age-restricted items.
/// Canadian law (CRTC / provincial liquor/tobacco acts) requires age confirmation before purchase.
class _AgeGateText extends ConsumerWidget {
  const _AgeGateText();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ageVerifAccepted = ref.watch(_ageVerifAcceptedProvider);
    final hasInteracted = ref.watch(_ageVerifInteractedProvider);
    final showError = hasInteracted && !ageVerifAccepted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: DesignTokens.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: showError ? DesignTokens.error : DesignTokens.outlineVariant, width: 1),
        ),
        child: Row(
          key: const Key('checkout_age_gate'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 20,
              width: 20,
              child: Semantics(
                label: 'chk-age-gate-accepted',
                checked: ageVerifAccepted,
                child: Checkbox(
                  key: const Key('checkout_age_gate_checkbox'),
                  value: ageVerifAccepted,
                  onChanged: (value) {
                    ref.read(_ageVerifInteractedProvider.notifier).state = true;
                    ref.read(_ageVerifAcceptedProvider.notifier).state = value ?? false;
                  },
                  side: BorderSide(color: showError ? DesignTokens.error : DesignTokens.textDisabled),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'checkout.age_gate_agree'.tr(),
                style: TextStyle(fontSize: 13, color: DesignTokens.textPrimary, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// @Preview skipped — requires live auth/navigation context
// CheckoutScreen requires List<CartItemDetailModel> which depends on live Firestore/Timestamp.
