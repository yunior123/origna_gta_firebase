// coverage:ignore-file
import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/routes.dart';
import 'package:origna_gta/features/orders/orders_provider.dart';
import 'package:origna_gta/screens/common_screens.dart';
import 'package:origna_gta/screens/ordersuccess_screen.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/widgets/animations.dart';
import 'package:origna_gta/widgets/custom_app_bar.dart';
import 'package:origna_gta/widgets/mascot/shop_mascot.dart';
import 'package:origna_gta/widgets/modern_button.dart';
import 'package:origna_gta/widgets/modern_loading_indicator.dart';

// ─── Flutter Previews ────────────────────────────────────────────────────────

/// Gate that waits for order to be confirmed after Stripe payment.
/// Includes a timeout to prevent infinite spinner if webhook is delayed/failed.
class OrderSuccessGate extends ConsumerStatefulWidget {
  final String sessionId;

  const OrderSuccessGate({super.key, required this.sessionId});

  @override
  ConsumerState<OrderSuccessGate> createState() => _OrderSuccessGateState();
}

/// Screen shown when user cancels payment
class PaymentCanceledScreen extends StatelessWidget {
  const PaymentCanceledScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(gradient: DesignTokens.backgroundGradient(isDark: isDark)),
      child: Scaffold(
        appBar: AppBarFactory.simple(title: 'payment.canceled'.tr()),
        backgroundColor: Colors.transparent,
        body: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Padding(
                padding: const EdgeInsets.all(DesignTokens.spacing24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FadeSlideIn(
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [DesignTokens.error.withValues(alpha: 0.15), DesignTokens.error.withValues(alpha: 0.08)]),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: DesignTokens.error.withValues(alpha: 0.15), blurRadius: 30, spreadRadius: 5)],
                        ),
                        child: Icon(Icons.cancel_rounded, size: 72, color: DesignTokens.error),
                      ),
                    ),
                    const SizedBox(height: 32),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 100),
                      child: Text(
                        'payment.canceled'.tr(),
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: isDark ? Colors.white : DesignTokens.textPrimary),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 150),
                      child: Text(
                        'payment.canceled_body'.tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, color: DesignTokens.textSecondary, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 40),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 200),
                      child: Semantics(
                        button: true,
                        label: 'btn-back-to-shopping',
                        child: ModernButton(
                          label: 'payment.back_to_shopping'.tr(),
                          icon: Icons.shopping_bag_outlined,
                          onPressed: () {
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            } else {
                              Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reusable confirming payment view to avoid duplication
class _ConfirmingPaymentView extends StatefulWidget {
  final String message;
  final bool isDark;

  const _ConfirmingPaymentView({required this.message, required this.isDark});

  @override
  State<_ConfirmingPaymentView> createState() => _ConfirmingPaymentViewState();
}

class _ConfirmingPaymentViewState extends State<_ConfirmingPaymentView> {
  late final MascotController _mascotController;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: DesignTokens.backgroundGradient(isDark: widget.isDark)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Mascot waiting animation
                  ShopMascot(controller: _mascotController, size: 88, showSpeechBubble: false),
                  const SizedBox(height: 16),
                  // Spinner ring
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [DesignTokens.primary.withValues(alpha: 0.15), DesignTokens.secondary.withValues(alpha: 0.15)]),
                    ),
                    child: Center(
                      child: ShaderMask(
                        shaderCallback: (bounds) => DesignTokens.primaryGradient.createShader(bounds),
                        child: const SizedBox(
                          width: 28,
                          height: 28,
                          child: ModernLoadingIndicator(size: 28, strokeWidth: 2.5, color: Colors.white, centered: false),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.message,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: widget.isDark ? Colors.white : DesignTokens.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text('payment.may_take_moments'.tr(), style: TextStyle(color: DesignTokens.textSecondary, fontSize: 14)),
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
    _mascotController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _mascotController = MascotController();
    _mascotController.setExcitement(0.5);
  }
}

class _OrderSuccessGateState extends ConsumerState<OrderSuccessGate> {
  static const _timeoutDuration = Duration(seconds: 90);
  Timer? _timeoutTimer;
  bool _timedOut = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(paidOrderBySessionProvider(widget.sessionId), (previous, next) {
      if (next.valueOrNull != null) {
        _timeoutTimer?.cancel();
      }
    });

    final orderAsync = ref.watch(paidOrderBySessionProvider(widget.sessionId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return orderAsync.when(
      loading: () => _timedOut ? _buildTimeoutFallback(isDark) : _ConfirmingPaymentView(message: 'payment.confirming'.tr(), isDark: isDark),
      error: (error, _) => ErrorScreen(message: 'payment.error_loading_order'.tr(namedArgs: {'error': error.toString()})),
      data: (order) {
        if (order == null) {
          return _timedOut ? _buildTimeoutFallback(isDark) : _ConfirmingPaymentView(message: 'payment.processing'.tr(), isDark: isDark);
        }
        final isLocalDelivery = order.items.isNotEmpty && order.items.every((i) => i.isLocalDeliveryOnly);
        final maxShipDays = (order.items.isEmpty || isLocalDelivery) ? null : order.items.map((i) => i.estimatedShipDays).reduce(math.max);
        return OrderSuccessScreen(
          orderId: order.orderId,
          valueCad: order.pendingTotal,
          itemCount: order.items.length,
          estimatedShipDays: maxShipDays,
          isLocalDelivery: isLocalDelivery,
        );
      },
    );
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _timeoutTimer = Timer(_timeoutDuration, () {
      if (mounted) setState(() => _timedOut = true);
    });
  }

  Widget _buildTimeoutFallback(bool isDark) {
    return Container(
      decoration: BoxDecoration(gradient: DesignTokens.backgroundGradient(isDark: isDark)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.all(DesignTokens.spacing24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FadeSlideIn(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [DesignTokens.warning.withValues(alpha: 0.15), DesignTokens.warning.withValues(alpha: 0.08)]),
                        ),
                        child: Icon(Icons.hourglass_top_rounded, size: 40, color: DesignTokens.warning),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'payment.verification_delayed'.tr(),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : DesignTokens.textPrimary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'payment.check_orders_later'.tr(),
                      style: TextStyle(color: DesignTokens.textSecondary, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ModernButton(
                      label: 'orders.view_my_orders'.tr(),
                      icon: Icons.receipt_long_outlined,
                      onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.orders, (route) => route.isFirst),
                    ),
                    const SizedBox(height: 12),
                    ModernButton(
                      label: 'payment.back_to_shopping'.tr(),
                      icon: Icons.home_outlined,
                      isPrimary: false,
                      isOutlined: true,
                      onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
