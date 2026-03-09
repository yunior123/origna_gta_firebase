// GENERATED — flutter test --update-goldens test/golden_previews_test.dart
// ignore_for_file: unused_import

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:origna_gta/previews/screens/addproduct_screen_preview.dart';
import 'package:origna_gta/previews/screens/addressmanagement_screen_preview.dart';
import 'package:origna_gta/previews/screens/authwrapper_screen_preview.dart';
import 'package:origna_gta/previews/screens/cart_screen_preview.dart';
import 'package:origna_gta/previews/screens/cartitem_screen_preview.dart';
import 'package:origna_gta/previews/screens/chat_conversations_screen_preview.dart';
import 'package:origna_gta/previews/screens/chat_screen_preview.dart';
import 'package:origna_gta/previews/screens/checkout_screen_preview.dart';
import 'package:origna_gta/previews/screens/common_screens_preview.dart';
import 'package:origna_gta/previews/screens/editaddress_screen_preview.dart';
import 'package:origna_gta/previews/screens/editproduct_screen_preview.dart';
import 'package:origna_gta/previews/screens/favorites_screen_preview.dart';
import 'package:origna_gta/previews/screens/home_screen_preview.dart';
import 'package:origna_gta/previews/screens/login_screen_preview.dart';
import 'package:origna_gta/previews/screens/main_screen_preview.dart';
import 'package:origna_gta/previews/screens/notifications_screen_preview.dart';
import 'package:origna_gta/previews/screens/order_detail_screen_preview.dart';
import 'package:origna_gta/previews/screens/orders_screen_preview.dart';
import 'package:origna_gta/previews/screens/ordersuccess_screen_preview.dart';
import 'package:origna_gta/previews/screens/payment_screens_preview.dart';
import 'package:origna_gta/previews/screens/privacy_policy_screen_preview.dart';
import 'package:origna_gta/previews/screens/product_card_screen_preview.dart';
import 'package:origna_gta/previews/screens/productaddimages_screen_preview.dart';
import 'package:origna_gta/previews/screens/productaddvideo_screen_preview.dart';
import 'package:origna_gta/previews/screens/productdetails_screen_preview.dart';
import 'package:origna_gta/previews/screens/profile_screen_preview.dart';
import 'package:origna_gta/previews/screens/reset_password_screen_preview.dart';
import 'package:origna_gta/previews/screens/seller_integration_screen_preview.dart';
import 'package:origna_gta/previews/screens/seller_orders_screen_preview.dart';
import 'package:origna_gta/previews/screens/seller_products_screen_preview.dart';
import 'package:origna_gta/previews/screens/seller_registration_screen_preview.dart';
import 'package:origna_gta/previews/screens/seller_setup_screen_preview.dart';
import 'package:origna_gta/previews/screens/shipping_approval_screen_preview.dart';
import 'package:origna_gta/previews/screens/subscription_cancel_screen_preview.dart';
import 'package:origna_gta/previews/screens/subscription_screen_preview.dart';
import 'package:origna_gta/previews/screens/subscription_success_screen_preview.dart';
import 'package:origna_gta/previews/screens/terms_of_service_screen_preview.dart';
import 'package:origna_gta/previews/screens/terms_screen_preview.dart';
import 'package:origna_gta/previews/widgets/animations_preview.dart';
import 'package:origna_gta/previews/widgets/app_bar_preview.dart';
import 'package:origna_gta/previews/widgets/buttons_preview.dart';
import 'package:origna_gta/previews/widgets/cards_preview.dart';
import 'package:origna_gta/previews/widgets/custom_app_bar_preview.dart';
import 'package:origna_gta/previews/widgets/design_tokens_preview.dart';
import 'package:origna_gta/previews/widgets/env_preview_banner_preview.dart';
import 'package:origna_gta/previews/widgets/language_selector_preview.dart';
import 'package:origna_gta/previews/widgets/legal_screen_body_preview.dart';
import 'package:origna_gta/previews/widgets/loading_preview.dart';
import 'package:origna_gta/previews/widgets/mascot_preview.dart';
import 'package:origna_gta/previews/widgets/modern_appbar_preview.dart'
    hide previewAppBarVariants;
import 'package:origna_gta/previews/widgets/modern_button_preview.dart';
import 'package:origna_gta/previews/widgets/modern_card_preview.dart';
import 'package:origna_gta/previews/widgets/modern_loading_indicator_preview.dart'
    hide previewLoadingInline;
import 'package:origna_gta/previews/widgets/modern_product_card_preview.dart';
import 'package:origna_gta/previews/widgets/modern_textfield_preview.dart';
import 'package:origna_gta/previews/widgets/order_status_preview.dart';
import 'package:origna_gta/previews/widgets/order_widgets_preview.dart';
import 'package:origna_gta/previews/widgets/premium_paywall_preview.dart';
import 'package:origna_gta/previews/widgets/product_card_preview.dart';
import 'package:origna_gta/previews/widgets/rating_dialog_preview.dart';
import 'package:origna_gta/previews/widgets/rating_histogram_preview.dart';
import 'package:origna_gta/previews/widgets/rating_preview.dart';
import 'package:origna_gta/previews/widgets/standalone_promo_preview.dart';
import 'package:origna_gta/previews/widgets/textfields_preview.dart';

bool _goldensRequested() {
  const requestedByDefine = bool.fromEnvironment('RUN_GOLDENS');
  final envValue = (Platform.environment['RUN_GOLDENS'] ?? '').toLowerCase();
  return requestedByDefine ||
      envValue == '1' ||
      envValue == 'true' ||
      envValue == 'yes';
}

bool _hasGoldenBaselines() {
  final dir = Directory('test/goldens');
  if (!dir.existsSync()) {
    return false;
  }
  return dir.listSync().any((entity) => entity is File);
}

void main() {
  final runGoldens = _goldensRequested();
  final hasBaselines = _hasGoldenBaselines();
  if (!runGoldens && !hasBaselines) {
    testWidgets('skip goldens when baselines are unavailable', (tester) async {
      expect(
        hasBaselines,
        isFalse,
        reason:
            'Set RUN_GOLDENS=true (or --dart-define=RUN_GOLDENS=true) and run '
            'flutter test --update-goldens test/golden_previews_test.dart to '
            'generate baselines.',
      );
    });
    return;
  }

  group('Widget Golden Previews', () {
    testWidgets('previewAddEditAddressScreenDesktop', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewAddEditAddressScreenDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/add_edit_address_screen_desktop.png'),
      );
    });
    testWidgets('previewAddEditAddressScreenMobile', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewAddEditAddressScreenMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/add_edit_address_screen_mobile.png'),
      );
    });
    testWidgets('previewAddEditAddressScreenTablet', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewAddEditAddressScreenTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/add_edit_address_screen_tablet.png'),
      );
    });
    testWidgets('previewAddEditAddressScreenWeb', (WidgetTester tester) async {
      await tester.pumpWidget(previewAddEditAddressScreenWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/add_edit_address_screen_web.png'),
      );
    });
    testWidgets('previewAddProductScreenDesktop', (WidgetTester tester) async {
      await tester.pumpWidget(previewAddProductScreenDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/add_product_screen_desktop.png'),
      );
    });
    testWidgets('previewAddProductScreenMobile', (WidgetTester tester) async {
      await tester.pumpWidget(previewAddProductScreenMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/add_product_screen_mobile.png'),
      );
    });
    testWidgets('previewAddProductScreenTablet', (WidgetTester tester) async {
      await tester.pumpWidget(previewAddProductScreenTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/add_product_screen_tablet.png'),
      );
    });
    testWidgets('previewAddProductScreenWeb', (WidgetTester tester) async {
      await tester.pumpWidget(previewAddProductScreenWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/add_product_screen_web.png'),
      );
    });
    testWidgets('previewAddressManagementScreenDesktop', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewAddressManagementScreenDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/address_management_screen_desktop.png'),
      );
    });
    testWidgets('previewAddressManagementScreenMobile', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewAddressManagementScreenMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/address_management_screen_mobile.png'),
      );
    });
    testWidgets('previewAddressManagementScreenTablet', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewAddressManagementScreenTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/address_management_screen_tablet.png'),
      );
    });
    testWidgets('previewAddressManagementScreenWeb', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewAddressManagementScreenWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/address_management_screen_web.png'),
      );
    });
    testWidgets('previewAllStatusBadges', (WidgetTester tester) async {
      await tester.pumpWidget(previewAllStatusBadges());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/all_status_badges.png'),
      );
    });
    testWidgets('previewAllStatusBadgesLight', (WidgetTester tester) async {
      await tester.pumpWidget(previewAllStatusBadgesLight());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/all_status_badges_light.png'),
      );
    });
    testWidgets('previewAllTextFields', (WidgetTester tester) async {
      await tester.pumpWidget(previewAllTextFields());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/all_text_fields.png'),
      );
    });
    testWidgets('previewAnimations', (WidgetTester tester) async {
      await tester.pumpWidget(previewAnimations());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/animations.png'),
      );
    });
    testWidgets('previewAppBarAllVariants', (WidgetTester tester) async {
      await tester.pumpWidget(previewAppBarAllVariants());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/app_bar_all_variants.png'),
      );
    });
    testWidgets('previewAppBarCart', (WidgetTester tester) async {
      await tester.pumpWidget(previewAppBarCart());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/app_bar_cart.png'),
      );
    });
    testWidgets('previewAppBarLight', (WidgetTester tester) async {
      await tester.pumpWidget(previewAppBarLight());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/app_bar_light.png'),
      );
    });
    testWidgets('previewAppBarMain', (WidgetTester tester) async {
      await tester.pumpWidget(previewAppBarMain());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/app_bar_main.png'),
      );
    });
    testWidgets('previewAppBarStandard', (WidgetTester tester) async {
      await tester.pumpWidget(previewAppBarStandard());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/app_bar_standard.png'),
      );
    });
    testWidgets('previewAppBarVariants', (WidgetTester tester) async {
      await tester.pumpWidget(previewAppBarVariants());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/app_bar_variants.png'),
      );
    });
    testWidgets('previewAppBarWithActions', (WidgetTester tester) async {
      await tester.pumpWidget(previewAppBarWithActions());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/app_bar_with_actions.png'),
      );
    });
    testWidgets('previewAppBarWithSubtitle', (WidgetTester tester) async {
      await tester.pumpWidget(previewAppBarWithSubtitle());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/app_bar_with_subtitle.png'),
      );
    });
    testWidgets('previewAuthWrapperScreenDesktop', (WidgetTester tester) async {
      await tester.pumpWidget(previewAuthWrapperScreenDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/auth_wrapper_screen_desktop.png'),
      );
    });
    testWidgets('previewAuthWrapperScreenMobile', (WidgetTester tester) async {
      await tester.pumpWidget(previewAuthWrapperScreenMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/auth_wrapper_screen_mobile.png'),
      );
    });
    testWidgets('previewAuthWrapperScreenTablet', (WidgetTester tester) async {
      await tester.pumpWidget(previewAuthWrapperScreenTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/auth_wrapper_screen_tablet.png'),
      );
    });
    testWidgets('previewAuthWrapperScreenWeb', (WidgetTester tester) async {
      await tester.pumpWidget(previewAuthWrapperScreenWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/auth_wrapper_screen_web.png'),
      );
    });
    testWidgets('previewBottomNavVariants', (WidgetTester tester) async {
      await tester.pumpWidget(previewBottomNavVariants());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/bottom_nav_variants.png'),
      );
    });
    testWidgets('previewButtonAllStates', (WidgetTester tester) async {
      await tester.pumpWidget(previewButtonAllStates());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/button_all_states.png'),
      );
    });
    testWidgets('previewButtonDisabled', (WidgetTester tester) async {
      await tester.pumpWidget(previewButtonDisabled());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/button_disabled.png'),
      );
    });
    testWidgets('previewButtonLoading', (WidgetTester tester) async {
      await tester.pumpWidget(previewButtonLoading());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/button_loading.png'),
      );
    });
    testWidgets('previewButtonOutlined', (WidgetTester tester) async {
      await tester.pumpWidget(previewButtonOutlined());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/button_outlined.png'),
      );
    });
    testWidgets('previewButtonSecondary', (WidgetTester tester) async {
      await tester.pumpWidget(previewButtonSecondary());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/button_secondary.png'),
      );
    });
    testWidgets('previewButtonStates', (WidgetTester tester) async {
      await tester.pumpWidget(previewButtonStates());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/button_states.png'),
      );
    });
    testWidgets('previewButtonTypes', (WidgetTester tester) async {
      await tester.pumpWidget(previewButtonTypes());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/button_types.png'),
      );
    });
    testWidgets('previewButtonWithIcon', (WidgetTester tester) async {
      await tester.pumpWidget(previewButtonWithIcon());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/button_with_icon.png'),
      );
    });
    testWidgets('previewCanadianMooseDefault', (WidgetTester tester) async {
      await tester.pumpWidget(previewCanadianMooseDefault());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/canadian_moose_default.png'),
      );
    });
    testWidgets('previewCanadianMooseLarge', (WidgetTester tester) async {
      await tester.pumpWidget(previewCanadianMooseLarge());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/canadian_moose_large.png'),
      );
    });
    testWidgets('previewCardBasic', (WidgetTester tester) async {
      await tester.pumpWidget(previewCardBasic());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/card_basic.png'),
      );
    });
    testWidgets('previewCardComplex', (WidgetTester tester) async {
      await tester.pumpWidget(previewCardComplex());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/card_complex.png'),
      );
    });
    testWidgets('previewCardEmpty', (WidgetTester tester) async {
      await tester.pumpWidget(previewCardEmpty());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/card_empty.png'),
      );
    });
    testWidgets('previewCardLight', (WidgetTester tester) async {
      await tester.pumpWidget(previewCardLight());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/card_light.png'),
      );
    });
    testWidgets('previewCardStats', (WidgetTester tester) async {
      await tester.pumpWidget(previewCardStats());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/card_stats.png'),
      );
    });
    testWidgets('previewCardSuccess', (WidgetTester tester) async {
      await tester.pumpWidget(previewCardSuccess());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/card_success.png'),
      );
    });
    testWidgets('previewCardVariants', (WidgetTester tester) async {
      await tester.pumpWidget(previewCardVariants());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/card_variants.png'),
      );
    });
    testWidgets('previewCardWarning', (WidgetTester tester) async {
      await tester.pumpWidget(previewCardWarning());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/card_warning.png'),
      );
    });
    testWidgets('previewCartItemScreenDesktop', (WidgetTester tester) async {
      await tester.pumpWidget(previewCartItemScreenDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/cart_item_screen_desktop.png'),
      );
    });
    testWidgets('previewCartItemScreenMobile', (WidgetTester tester) async {
      await tester.pumpWidget(previewCartItemScreenMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/cart_item_screen_mobile.png'),
      );
    });
    testWidgets('previewCartItemScreenTablet', (WidgetTester tester) async {
      await tester.pumpWidget(previewCartItemScreenTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/cart_item_screen_tablet.png'),
      );
    });
    testWidgets('previewCartItemScreenWeb', (WidgetTester tester) async {
      await tester.pumpWidget(previewCartItemScreenWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/cart_item_screen_web.png'),
      );
    });
    testWidgets('previewCartScreenDesktop', (WidgetTester tester) async {
      await tester.pumpWidget(previewCartScreenDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/cart_screen_desktop.png'),
      );
    });
    testWidgets('previewCartScreenMobile', (WidgetTester tester) async {
      await tester.pumpWidget(previewCartScreenMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/cart_screen_mobile.png'),
      );
    });
    testWidgets('previewCartScreenTablet', (WidgetTester tester) async {
      await tester.pumpWidget(previewCartScreenTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/cart_screen_tablet.png'),
      );
    });
    testWidgets('previewCartScreenWeb', (WidgetTester tester) async {
      await tester.pumpWidget(previewCartScreenWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/cart_screen_web.png'),
      );
    });
    testWidgets('previewChatConversationsScreenDesktop', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewChatConversationsScreenDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/chat_conversations_screen_desktop.png'),
      );
    });
    testWidgets('previewChatConversationsScreenMobile', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewChatConversationsScreenMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/chat_conversations_screen_mobile.png'),
      );
    });
    testWidgets('previewChatConversationsScreenTablet', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewChatConversationsScreenTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/chat_conversations_screen_tablet.png'),
      );
    });
    testWidgets('previewChatConversationsScreenWeb', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewChatConversationsScreenWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/chat_conversations_screen_web.png'),
      );
    });
    testWidgets('previewChatScreenDesktop', (WidgetTester tester) async {
      await tester.pumpWidget(previewChatScreenDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/chat_screen_desktop.png'),
      );
    });
    testWidgets('previewChatScreenMobile', (WidgetTester tester) async {
      await tester.pumpWidget(previewChatScreenMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/chat_screen_mobile.png'),
      );
    });
    testWidgets('previewChatScreenTablet', (WidgetTester tester) async {
      await tester.pumpWidget(previewChatScreenTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/chat_screen_tablet.png'),
      );
    });
    testWidgets('previewChatScreenWeb', (WidgetTester tester) async {
      await tester.pumpWidget(previewChatScreenWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/chat_screen_web.png'),
      );
    });
    testWidgets('previewCheckoutScreenDesktop', (WidgetTester tester) async {
      await tester.pumpWidget(previewCheckoutScreenDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/checkout_screen_desktop.png'),
      );
    });
    testWidgets('previewCheckoutScreenMobile', (WidgetTester tester) async {
      await tester.pumpWidget(previewCheckoutScreenMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/checkout_screen_mobile.png'),
      );
    });
    testWidgets('previewCheckoutScreenTablet', (WidgetTester tester) async {
      await tester.pumpWidget(previewCheckoutScreenTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/checkout_screen_tablet.png'),
      );
    });
    testWidgets('previewCheckoutScreenWeb', (WidgetTester tester) async {
      await tester.pumpWidget(previewCheckoutScreenWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/checkout_screen_web.png'),
      );
    });
    testWidgets('previewColorPalette', (WidgetTester tester) async {
      await tester.pumpWidget(previewColorPalette());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/color_palette.png'),
      );
    });
    testWidgets('previewEdgeCaseCards', (WidgetTester tester) async {
      await tester.pumpWidget(previewEdgeCaseCards());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/edge_case_cards.png'),
      );
    });
    testWidgets('previewEditProductScreenDesktop', (WidgetTester tester) async {
      await tester.pumpWidget(previewEditProductScreenDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/edit_product_screen_desktop.png'),
      );
    });
    testWidgets('previewEditProductScreenMobile', (WidgetTester tester) async {
      await tester.pumpWidget(previewEditProductScreenMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/edit_product_screen_mobile.png'),
      );
    });
    testWidgets('previewEditProductScreenTablet', (WidgetTester tester) async {
      await tester.pumpWidget(previewEditProductScreenTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/edit_product_screen_tablet.png'),
      );
    });
    testWidgets('previewEditProductScreenWeb', (WidgetTester tester) async {
      await tester.pumpWidget(previewEditProductScreenWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/edit_product_screen_web.png'),
      );
    });
    testWidgets('previewEmailField', (WidgetTester tester) async {
      await tester.pumpWidget(previewEmailField());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/email_field.png'),
      );
    });
    testWidgets('previewEmailVerificationRequiredScreenDesktop', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewEmailVerificationRequiredScreenDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile(
          'goldens/email_verification_required_screen_desktop.png',
        ),
      );
    });
    testWidgets('previewEmailVerificationRequiredScreenMobile', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewEmailVerificationRequiredScreenMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile(
          'goldens/email_verification_required_screen_mobile.png',
        ),
      );
    });
    testWidgets('previewEmailVerificationRequiredScreenTablet', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewEmailVerificationRequiredScreenTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile(
          'goldens/email_verification_required_screen_tablet.png',
        ),
      );
    });
    testWidgets('previewEmailVerificationRequiredScreenWeb', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewEmailVerificationRequiredScreenWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/email_verification_required_screen_web.png'),
      );
    });
    testWidgets('previewEmptyOrders', (WidgetTester tester) async {
      await tester.pumpWidget(previewEmptyOrders());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/empty_orders.png'),
      );
    });
    testWidgets('previewEmptyOrdersFiltered', (WidgetTester tester) async {
      await tester.pumpWidget(previewEmptyOrdersFiltered());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/empty_orders_filtered.png'),
      );
    });
    testWidgets('previewEmptyStates', (WidgetTester tester) async {
      await tester.pumpWidget(previewEmptyStates());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/empty_states.png'),
      );
    });
    testWidgets('previewEnvBanners', (WidgetTester tester) async {
      await tester.pumpWidget(previewEnvBanners());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/env_banners.png'),
      );
    });
    testWidgets('previewFavoritesScreenDesktop', (WidgetTester tester) async {
      await tester.pumpWidget(previewFavoritesScreenDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/favorites_screen_desktop.png'),
      );
    });
    testWidgets('previewFavoritesScreenMobile', (WidgetTester tester) async {
      await tester.pumpWidget(previewFavoritesScreenMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/favorites_screen_mobile.png'),
      );
    });
    testWidgets('previewFavoritesScreenTablet', (WidgetTester tester) async {
      await tester.pumpWidget(previewFavoritesScreenTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/favorites_screen_tablet.png'),
      );
    });
    testWidgets('previewFavoritesScreenWeb', (WidgetTester tester) async {
      await tester.pumpWidget(previewFavoritesScreenWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/favorites_screen_web.png'),
      );
    });
    testWidgets('previewGradient', (WidgetTester tester) async {
      await tester.pumpWidget(previewGradient());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/gradient.png'),
      );
    });
    testWidgets('previewHistogramVariants', (WidgetTester tester) async {
      await tester.pumpWidget(previewHistogramVariants());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/histogram_variants.png'),
      );
    });
    testWidgets('previewHomeScreenDesktop', (WidgetTester tester) async {
      await tester.pumpWidget(previewHomeScreenDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/home_screen_desktop.png'),
      );
    });
    testWidgets('previewHomeScreenMobile', (WidgetTester tester) async {
      await tester.pumpWidget(previewHomeScreenMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/home_screen_mobile.png'),
      );
    });
    testWidgets('previewHomeScreenTablet', (WidgetTester tester) async {
      await tester.pumpWidget(previewHomeScreenTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/home_screen_tablet.png'),
      );
    });
    testWidgets('previewHomeScreenWeb', (WidgetTester tester) async {
      await tester.pumpWidget(previewHomeScreenWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/home_screen_web.png'),
      );
    });
    testWidgets('previewLanguageVariants', (WidgetTester tester) async {
      await tester.pumpWidget(previewLanguageVariants());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/language_variants.png'),
      );
    });
    testWidgets('previewLegalResponsive', (WidgetTester tester) async {
      await tester.pumpWidget(previewLegalResponsive());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/legal_responsive.png'),
      );
    });
    testWidgets('previewLegalVariants', (WidgetTester tester) async {
      await tester.pumpWidget(previewLegalVariants());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/legal_variants.png'),
      );
    });
    testWidgets('previewLoadingAllSizes', (WidgetTester tester) async {
      await tester.pumpWidget(previewLoadingAllSizes());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/loading_all_sizes.png'),
      );
    });
    testWidgets('previewLoadingDefault', (WidgetTester tester) async {
      await tester.pumpWidget(previewLoadingDefault());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/loading_default.png'),
      );
    });
    testWidgets('previewLoadingFullScreen', (WidgetTester tester) async {
      await tester.pumpWidget(previewLoadingFullScreen());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/loading_full_screen.png'),
      );
    });
    testWidgets('previewLoadingInline', (WidgetTester tester) async {
      await tester.pumpWidget(previewLoadingInline());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/loading_inline.png'),
      );
    });
    testWidgets('previewLoadingSmall', (WidgetTester tester) async {
      await tester.pumpWidget(previewLoadingSmall());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/loading_small.png'),
      );
    });
    testWidgets('previewLoadingVariants', (WidgetTester tester) async {
      await tester.pumpWidget(previewLoadingVariants());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/loading_variants.png'),
      );
    });
    testWidgets('previewLoginScreenDesktop', (WidgetTester tester) async {
      await tester.pumpWidget(previewLoginScreenDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/login_screen_desktop.png'),
      );
    });
    testWidgets('previewLoginScreenMobile', (WidgetTester tester) async {
      await tester.pumpWidget(previewLoginScreenMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/login_screen_mobile.png'),
      );
    });
    testWidgets('previewLoginScreenTablet', (WidgetTester tester) async {
      await tester.pumpWidget(previewLoginScreenTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/login_screen_tablet.png'),
      );
    });
    testWidgets('previewLoginScreenWeb', (WidgetTester tester) async {
      await tester.pumpWidget(previewLoginScreenWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/login_screen_web.png'),
      );
    });
    testWidgets('previewMainScreenDesktop', (WidgetTester tester) async {
      await tester.pumpWidget(previewMainScreenDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/main_screen_desktop.png'),
      );
    });
    testWidgets('previewMainScreenMobile', (WidgetTester tester) async {
      await tester.pumpWidget(previewMainScreenMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/main_screen_mobile.png'),
      );
    });
    testWidgets('previewMainScreenTablet', (WidgetTester tester) async {
      await tester.pumpWidget(previewMainScreenTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/main_screen_tablet.png'),
      );
    });
    testWidgets('previewMainScreenWeb', (WidgetTester tester) async {
      await tester.pumpWidget(previewMainScreenWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/main_screen_web.png'),
      );
    });
    testWidgets('previewMultilineField', (WidgetTester tester) async {
      await tester.pumpWidget(previewMultilineField());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/multiline_field.png'),
      );
    });
    testWidgets('previewNotificationsScreenDesktop', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewNotificationsScreenDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/notifications_screen_desktop.png'),
      );
    });
    testWidgets('previewNotificationsScreenEmptyDesktop', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewNotificationsScreenEmptyDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/notifications_screen_empty_desktop.png'),
      );
    });
    testWidgets('previewNotificationsScreenEmptyMobile', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewNotificationsScreenEmptyMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/notifications_screen_empty_mobile.png'),
      );
    });
    testWidgets('previewNotificationsScreenEmptyTablet', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewNotificationsScreenEmptyTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/notifications_screen_empty_tablet.png'),
      );
    });
    testWidgets('previewNotificationsScreenEmptyWeb', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewNotificationsScreenEmptyWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/notifications_screen_empty_web.png'),
      );
    });
    testWidgets('previewNotificationsScreenMobile', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewNotificationsScreenMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/notifications_screen_mobile.png'),
      );
    });
    testWidgets('previewNotificationsScreenTablet', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewNotificationsScreenTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/notifications_screen_tablet.png'),
      );
    });
    testWidgets('previewNotificationsScreenWeb', (WidgetTester tester) async {
      await tester.pumpWidget(previewNotificationsScreenWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/notifications_screen_web.png'),
      );
    });
    testWidgets('previewOrderBanners', (WidgetTester tester) async {
      await tester.pumpWidget(previewOrderBanners());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/order_banners.png'),
      );
    });
    testWidgets('previewOrderDetailScreenDesktop', (WidgetTester tester) async {
      await tester.pumpWidget(previewOrderDetailScreenDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/order_detail_screen_desktop.png'),
      );
    });
    testWidgets('previewOrderDetailScreenMobile', (WidgetTester tester) async {
      await tester.pumpWidget(previewOrderDetailScreenMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/order_detail_screen_mobile.png'),
      );
    });
    testWidgets('previewOrderDetailScreenTablet', (WidgetTester tester) async {
      await tester.pumpWidget(previewOrderDetailScreenTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/order_detail_screen_tablet.png'),
      );
    });
    testWidgets('previewOrderDetailScreenWeb', (WidgetTester tester) async {
      await tester.pumpWidget(previewOrderDetailScreenWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/order_detail_screen_web.png'),
      );
    });
    testWidgets('previewOrderSuccessScreenDesktop', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewOrderSuccessScreenDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/order_success_screen_desktop.png'),
      );
    });
    testWidgets('previewOrderSuccessScreenMobile', (WidgetTester tester) async {
      await tester.pumpWidget(previewOrderSuccessScreenMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/order_success_screen_mobile.png'),
      );
    });
    testWidgets('previewOrderSuccessScreenTablet', (WidgetTester tester) async {
      await tester.pumpWidget(previewOrderSuccessScreenTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/order_success_screen_tablet.png'),
      );
    });
    testWidgets('previewOrderSuccessScreenWeb', (WidgetTester tester) async {
      await tester.pumpWidget(previewOrderSuccessScreenWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/order_success_screen_web.png'),
      );
    });
    testWidgets('previewOrderSummaryCards', (WidgetTester tester) async {
      await tester.pumpWidget(previewOrderSummaryCards());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/order_summary_cards.png'),
      );
    });
    testWidgets('previewOrderTimeline', (WidgetTester tester) async {
      await tester.pumpWidget(previewOrderTimeline());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/order_timeline.png'),
      );
    });
    testWidgets('previewOrderTimelineComplete', (WidgetTester tester) async {
      await tester.pumpWidget(previewOrderTimelineComplete());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/order_timeline_complete.png'),
      );
    });
    testWidgets('previewOrderTimelines', (WidgetTester tester) async {
      await tester.pumpWidget(previewOrderTimelines());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/order_timelines.png'),
      );
    });
    testWidgets('previewOrdersScreenDesktop', (WidgetTester tester) async {
      await tester.pumpWidget(previewOrdersScreenDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/orders_screen_desktop.png'),
      );
    });
    testWidgets('previewOrdersScreenMobile', (WidgetTester tester) async {
      await tester.pumpWidget(previewOrdersScreenMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/orders_screen_mobile.png'),
      );
    });
    testWidgets('previewOrdersScreenTablet', (WidgetTester tester) async {
      await tester.pumpWidget(previewOrdersScreenTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/orders_screen_tablet.png'),
      );
    });
    testWidgets('previewOrdersScreenWeb', (WidgetTester tester) async {
      await tester.pumpWidget(previewOrdersScreenWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/orders_screen_web.png'),
      );
    });
    testWidgets('previewPasswordField', (WidgetTester tester) async {
      await tester.pumpWidget(previewPasswordField());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/password_field.png'),
      );
    });
    testWidgets('previewPaymentCanceledScreenDesktop', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewPaymentCanceledScreenDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/payment_canceled_screen_desktop.png'),
      );
    });
    testWidgets('previewPaymentCanceledScreenMobile', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewPaymentCanceledScreenMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/payment_canceled_screen_mobile.png'),
      );
    });
    testWidgets('previewPaymentCanceledScreenTablet', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewPaymentCanceledScreenTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/payment_canceled_screen_tablet.png'),
      );
    });
    testWidgets('previewPaymentCanceledScreenWeb', (WidgetTester tester) async {
      await tester.pumpWidget(previewPaymentCanceledScreenWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/payment_canceled_screen_web.png'),
      );
    });
    testWidgets('previewPaywallResponsive', (WidgetTester tester) async {
      await tester.pumpWidget(previewPaywallResponsive());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/paywall_responsive.png'),
      );
    });
    testWidgets('previewPaywallVariants', (WidgetTester tester) async {
      await tester.pumpWidget(previewPaywallVariants());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/paywall_variants.png'),
      );
    });
    testWidgets('previewPriceField', (WidgetTester tester) async {
      await tester.pumpWidget(previewPriceField());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/price_field.png'),
      );
    });
    testWidgets('previewPrimaryButtonDark', (WidgetTester tester) async {
      await tester.pumpWidget(previewPrimaryButtonDark());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/primary_button_dark.png'),
      );
    });
    testWidgets('previewPrimaryButtonLight', (WidgetTester tester) async {
      await tester.pumpWidget(previewPrimaryButtonLight());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/primary_button_light.png'),
      );
    });
    testWidgets('previewPrivacyPolicyScreenDesktop', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewPrivacyPolicyScreenDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/privacy_policy_screen_desktop.png'),
      );
    });
    testWidgets('previewPrivacyPolicyScreenMobile', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewPrivacyPolicyScreenMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/privacy_policy_screen_mobile.png'),
      );
    });
    testWidgets('previewPrivacyPolicyScreenTablet', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewPrivacyPolicyScreenTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/privacy_policy_screen_tablet.png'),
      );
    });
    testWidgets('previewPrivacyPolicyScreenWeb', (WidgetTester tester) async {
      await tester.pumpWidget(previewPrivacyPolicyScreenWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/privacy_policy_screen_web.png'),
      );
    });
    testWidgets('previewProductAddImagesDesktop', (WidgetTester tester) async {
      await tester.pumpWidget(previewProductAddImagesDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/product_add_images_desktop.png'),
      );
    });
    testWidgets('previewProductAddImagesMobile', (WidgetTester tester) async {
      await tester.pumpWidget(previewProductAddImagesMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/product_add_images_mobile.png'),
      );
    });
    testWidgets('previewProductAddImagesTablet', (WidgetTester tester) async {
      await tester.pumpWidget(previewProductAddImagesTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/product_add_images_tablet.png'),
      );
    });
    testWidgets('previewProductAddImagesWeb', (WidgetTester tester) async {
      await tester.pumpWidget(previewProductAddImagesWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/product_add_images_web.png'),
      );
    });
    testWidgets('previewProductAddVideoDesktop', (WidgetTester tester) async {
      await tester.pumpWidget(previewProductAddVideoDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/product_add_video_desktop.png'),
      );
    });
    testWidgets('previewProductAddVideoMobile', (WidgetTester tester) async {
      await tester.pumpWidget(previewProductAddVideoMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/product_add_video_mobile.png'),
      );
    });
    testWidgets('previewProductAddVideoTablet', (WidgetTester tester) async {
      await tester.pumpWidget(previewProductAddVideoTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/product_add_video_tablet.png'),
      );
    });
    testWidgets('previewProductAddVideoWeb', (WidgetTester tester) async {
      await tester.pumpWidget(previewProductAddVideoWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/product_add_video_web.png'),
      );
    });
    testWidgets('previewProductCardAllVariants', (WidgetTester tester) async {
      await tester.pumpWidget(previewProductCardAllVariants());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/product_card_all_variants.png'),
      );
    });
    testWidgets('previewProductCardMultiCountry', (WidgetTester tester) async {
      await tester.pumpWidget(previewProductCardMultiCountry());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/product_card_multi_country.png'),
      );
    });
    testWidgets('previewProductCardNoReviews', (WidgetTester tester) async {
      await tester.pumpWidget(previewProductCardNoReviews());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/product_card_no_reviews.png'),
      );
    });
    testWidgets('previewProductCardOnSale', (WidgetTester tester) async {
      await tester.pumpWidget(previewProductCardOnSale());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/product_card_on_sale.png'),
      );
    });
    testWidgets('previewProductCardOutOfStock', (WidgetTester tester) async {
      await tester.pumpWidget(previewProductCardOutOfStock());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/product_card_out_of_stock.png'),
      );
    });
    testWidgets('previewProductCardScreenDesktop', (WidgetTester tester) async {
      await tester.pumpWidget(previewProductCardScreenDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/product_card_screen_desktop.png'),
      );
    });
    testWidgets('previewProductCardScreenMobile', (WidgetTester tester) async {
      await tester.pumpWidget(previewProductCardScreenMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/product_card_screen_mobile.png'),
      );
    });
    testWidgets('previewProductCardScreenTablet', (WidgetTester tester) async {
      await tester.pumpWidget(previewProductCardScreenTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/product_card_screen_tablet.png'),
      );
    });
    testWidgets('previewProductCardScreenWeb', (WidgetTester tester) async {
      await tester.pumpWidget(previewProductCardScreenWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/product_card_screen_web.png'),
      );
    });
    testWidgets('previewProductCardStandard', (WidgetTester tester) async {
      await tester.pumpWidget(previewProductCardStandard());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/product_card_standard.png'),
      );
    });
    testWidgets('previewProductCardStandardLight', (WidgetTester tester) async {
      await tester.pumpWidget(previewProductCardStandardLight());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/product_card_standard_light.png'),
      );
    });
    testWidgets('previewProductCardStates', (WidgetTester tester) async {
      await tester.pumpWidget(previewProductCardStates());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/product_card_states.png'),
      );
    });
    testWidgets('previewProductCardTrendingHot', (WidgetTester tester) async {
      await tester.pumpWidget(previewProductCardTrendingHot());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/product_card_trending_hot.png'),
      );
    });
    testWidgets('previewProductCardTrendingRising', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewProductCardTrendingRising());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/product_card_trending_rising.png'),
      );
    });
    testWidgets('previewProductCardVariants', (WidgetTester tester) async {
      await tester.pumpWidget(previewProductCardVariants());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/product_card_variants.png'),
      );
    });
    testWidgets('previewProductDetailScreenDesktop', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewProductDetailScreenDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/product_detail_screen_desktop.png'),
      );
    });
    testWidgets('previewProductDetailScreenMobile', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewProductDetailScreenMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/product_detail_screen_mobile.png'),
      );
    });
    testWidgets('previewProductDetailScreenTablet', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewProductDetailScreenTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/product_detail_screen_tablet.png'),
      );
    });
    testWidgets('previewProductDetailScreenWeb', (WidgetTester tester) async {
      await tester.pumpWidget(previewProductDetailScreenWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/product_detail_screen_web.png'),
      );
    });
    testWidgets('previewProfileScreenDarkDesktop', (WidgetTester tester) async {
      await tester.pumpWidget(previewProfileScreenDarkDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/profile_screen_dark_desktop.png'),
      );
    });
    testWidgets('previewProfileScreenDarkMobile', (WidgetTester tester) async {
      await tester.pumpWidget(previewProfileScreenDarkMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/profile_screen_dark_mobile.png'),
      );
    });
    testWidgets('previewProfileScreenDarkTablet', (WidgetTester tester) async {
      await tester.pumpWidget(previewProfileScreenDarkTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/profile_screen_dark_tablet.png'),
      );
    });
    testWidgets('previewProfileScreenDarkWeb', (WidgetTester tester) async {
      await tester.pumpWidget(previewProfileScreenDarkWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/profile_screen_dark_web.png'),
      );
    });
    testWidgets('previewProfileScreenLightDesktop', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewProfileScreenLightDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/profile_screen_light_desktop.png'),
      );
    });
    testWidgets('previewProfileScreenLightMobile', (WidgetTester tester) async {
      await tester.pumpWidget(previewProfileScreenLightMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/profile_screen_light_mobile.png'),
      );
    });
    testWidgets('previewProfileScreenLightTablet', (WidgetTester tester) async {
      await tester.pumpWidget(previewProfileScreenLightTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/profile_screen_light_tablet.png'),
      );
    });
    testWidgets('previewProfileScreenLightWeb', (WidgetTester tester) async {
      await tester.pumpWidget(previewProfileScreenLightWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/profile_screen_light_web.png'),
      );
    });
    testWidgets('previewPromoBannerDark', (WidgetTester tester) async {
      await tester.pumpWidget(previewPromoBannerDark());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/promo_banner_dark.png'),
      );
    });
    testWidgets('previewPromoBannerLight', (WidgetTester tester) async {
      await tester.pumpWidget(previewPromoBannerLight());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/promo_banner_light.png'),
      );
    });
    testWidgets('previewRatingAllVariants', (WidgetTester tester) async {
      await tester.pumpWidget(previewRatingAllVariants());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/rating_all_variants.png'),
      );
    });
    testWidgets('previewRatingDialogPremium', (WidgetTester tester) async {
      await tester.pumpWidget(previewRatingDialogPremium());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/rating_dialog_premium.png'),
      );
    });
    testWidgets('previewRatingDialogVariants', (WidgetTester tester) async {
      await tester.pumpWidget(previewRatingDialogVariants());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/rating_dialog_variants.png'),
      );
    });
    testWidgets('previewRatingEmpty', (WidgetTester tester) async {
      await tester.pumpWidget(previewRatingEmpty());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/rating_empty.png'),
      );
    });
    testWidgets('previewRatingLow', (WidgetTester tester) async {
      await tester.pumpWidget(previewRatingLow());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/rating_low.png'),
      );
    });
    testWidgets('previewRatingMixed', (WidgetTester tester) async {
      await tester.pumpWidget(previewRatingMixed());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/rating_mixed.png'),
      );
    });
    testWidgets('previewRatingMixedLight', (WidgetTester tester) async {
      await tester.pumpWidget(previewRatingMixedLight());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/rating_mixed_light.png'),
      );
    });
    testWidgets('previewRatingPerfect', (WidgetTester tester) async {
      await tester.pumpWidget(previewRatingPerfect());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/rating_perfect.png'),
      );
    });
    testWidgets('previewRegisterScreenDesktop', (WidgetTester tester) async {
      await tester.pumpWidget(previewRegisterScreenDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/register_screen_desktop.png'),
      );
    });
    testWidgets('previewRegisterScreenMobile', (WidgetTester tester) async {
      await tester.pumpWidget(previewRegisterScreenMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/register_screen_mobile.png'),
      );
    });
    testWidgets('previewRegisterScreenTablet', (WidgetTester tester) async {
      await tester.pumpWidget(previewRegisterScreenTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/register_screen_tablet.png'),
      );
    });
    testWidgets('previewRegisterScreenWeb', (WidgetTester tester) async {
      await tester.pumpWidget(previewRegisterScreenWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/register_screen_web.png'),
      );
    });
    testWidgets('previewResetPasswordScreenDesktop', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewResetPasswordScreenDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/reset_password_screen_desktop.png'),
      );
    });
    testWidgets('previewResetPasswordScreenMobile', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewResetPasswordScreenMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/reset_password_screen_mobile.png'),
      );
    });
    testWidgets('previewResetPasswordScreenTablet', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewResetPasswordScreenTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/reset_password_screen_tablet.png'),
      );
    });
    testWidgets('previewResetPasswordScreenWeb', (WidgetTester tester) async {
      await tester.pumpWidget(previewResetPasswordScreenWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/reset_password_screen_web.png'),
      );
    });
    testWidgets('previewSearchField', (WidgetTester tester) async {
      await tester.pumpWidget(previewSearchField());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/search_field.png'),
      );
    });
    testWidgets('previewSellerIntegrationDarkDesktop', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewSellerIntegrationDarkDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/seller_integration_dark_desktop.png'),
      );
    });
    testWidgets('previewSellerIntegrationDarkMobile', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewSellerIntegrationDarkMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/seller_integration_dark_mobile.png'),
      );
    });
    testWidgets('previewSellerIntegrationDarkTablet', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewSellerIntegrationDarkTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/seller_integration_dark_tablet.png'),
      );
    });
    testWidgets('previewSellerIntegrationDarkWeb', (WidgetTester tester) async {
      await tester.pumpWidget(previewSellerIntegrationDarkWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/seller_integration_dark_web.png'),
      );
    });
    testWidgets('previewSellerIntegrationLightDesktop', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewSellerIntegrationLightDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/seller_integration_light_desktop.png'),
      );
    });
    testWidgets('previewSellerIntegrationLightMobile', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewSellerIntegrationLightMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/seller_integration_light_mobile.png'),
      );
    });
    testWidgets('previewSellerIntegrationLightTablet', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewSellerIntegrationLightTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/seller_integration_light_tablet.png'),
      );
    });
    testWidgets('previewSellerIntegrationLightWeb', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewSellerIntegrationLightWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/seller_integration_light_web.png'),
      );
    });
    testWidgets('previewSellerOrdersScreenDesktop', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewSellerOrdersScreenDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/seller_orders_screen_desktop.png'),
      );
    });
    testWidgets('previewSellerOrdersScreenMobile', (WidgetTester tester) async {
      await tester.pumpWidget(previewSellerOrdersScreenMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/seller_orders_screen_mobile.png'),
      );
    });
    testWidgets('previewSellerOrdersScreenTablet', (WidgetTester tester) async {
      await tester.pumpWidget(previewSellerOrdersScreenTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/seller_orders_screen_tablet.png'),
      );
    });
    testWidgets('previewSellerOrdersScreenWeb', (WidgetTester tester) async {
      await tester.pumpWidget(previewSellerOrdersScreenWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/seller_orders_screen_web.png'),
      );
    });
    testWidgets('previewSellerProductsScreenDesktop', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewSellerProductsScreenDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/seller_products_screen_desktop.png'),
      );
    });
    testWidgets('previewSellerProductsScreenMobile', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewSellerProductsScreenMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/seller_products_screen_mobile.png'),
      );
    });
    testWidgets('previewSellerProductsScreenTablet', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewSellerProductsScreenTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/seller_products_screen_tablet.png'),
      );
    });
    testWidgets('previewSellerProductsScreenWeb', (WidgetTester tester) async {
      await tester.pumpWidget(previewSellerProductsScreenWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/seller_products_screen_web.png'),
      );
    });
    testWidgets('previewSellerRegistrationScreenDesktop', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewSellerRegistrationScreenDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/seller_registration_screen_desktop.png'),
      );
    });
    testWidgets('previewSellerRegistrationScreenMobile', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewSellerRegistrationScreenMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/seller_registration_screen_mobile.png'),
      );
    });
    testWidgets('previewSellerRegistrationScreenTablet', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewSellerRegistrationScreenTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/seller_registration_screen_tablet.png'),
      );
    });
    testWidgets('previewSellerRegistrationScreenWeb', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewSellerRegistrationScreenWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/seller_registration_screen_web.png'),
      );
    });
    testWidgets('previewSellerSetupCompleteScreenDesktop', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewSellerSetupCompleteScreenDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/seller_setup_complete_screen_desktop.png'),
      );
    });
    testWidgets('previewSellerSetupCompleteScreenMobile', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewSellerSetupCompleteScreenMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/seller_setup_complete_screen_mobile.png'),
      );
    });
    testWidgets('previewSellerSetupCompleteScreenTablet', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewSellerSetupCompleteScreenTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/seller_setup_complete_screen_tablet.png'),
      );
    });
    testWidgets('previewSellerSetupCompleteScreenWeb', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewSellerSetupCompleteScreenWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/seller_setup_complete_screen_web.png'),
      );
    });
    testWidgets('previewSellerSetupRefreshScreenDesktop', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewSellerSetupRefreshScreenDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/seller_setup_refresh_screen_desktop.png'),
      );
    });
    testWidgets('previewSellerSetupRefreshScreenMobile', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewSellerSetupRefreshScreenMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/seller_setup_refresh_screen_mobile.png'),
      );
    });
    testWidgets('previewSellerSetupRefreshScreenTablet', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewSellerSetupRefreshScreenTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/seller_setup_refresh_screen_tablet.png'),
      );
    });
    testWidgets('previewSellerSetupRefreshScreenWeb', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewSellerSetupRefreshScreenWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/seller_setup_refresh_screen_web.png'),
      );
    });
    testWidgets('previewShippingApprovalScreenDesktop', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewShippingApprovalScreenDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/shipping_approval_screen_desktop.png'),
      );
    });
    testWidgets('previewShippingApprovalScreenMobile', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewShippingApprovalScreenMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/shipping_approval_screen_mobile.png'),
      );
    });
    testWidgets('previewShippingApprovalScreenTablet', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewShippingApprovalScreenTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/shipping_approval_screen_tablet.png'),
      );
    });
    testWidgets('previewShippingApprovalScreenWeb', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewShippingApprovalScreenWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/shipping_approval_screen_web.png'),
      );
    });
    testWidgets('previewShopMascotDefault', (WidgetTester tester) async {
      await tester.pumpWidget(previewShopMascotDefault());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/shop_mascot_default.png'),
      );
    });
    testWidgets('previewShopMascotLarge', (WidgetTester tester) async {
      await tester.pumpWidget(previewShopMascotLarge());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/shop_mascot_large.png'),
      );
    });
    testWidgets('previewSpacingRadius', (WidgetTester tester) async {
      await tester.pumpWidget(previewSpacingRadius());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/spacing_radius.png'),
      );
    });
    testWidgets('previewStatusColorReference', (WidgetTester tester) async {
      await tester.pumpWidget(previewStatusColorReference());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/status_color_reference.png'),
      );
    });
    testWidgets('previewSubscriptionCancelScreenDesktop', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewSubscriptionCancelScreenDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/subscription_cancel_screen_desktop.png'),
      );
    });
    testWidgets('previewSubscriptionCancelScreenMobile', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewSubscriptionCancelScreenMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/subscription_cancel_screen_mobile.png'),
      );
    });
    testWidgets('previewSubscriptionCancelScreenTablet', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewSubscriptionCancelScreenTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/subscription_cancel_screen_tablet.png'),
      );
    });
    testWidgets('previewSubscriptionCancelScreenWeb', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewSubscriptionCancelScreenWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/subscription_cancel_screen_web.png'),
      );
    });
    testWidgets('previewSubscriptionScreenDesktop', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewSubscriptionScreenDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/subscription_screen_desktop.png'),
      );
    });
    testWidgets('previewSubscriptionScreenMobile', (WidgetTester tester) async {
      await tester.pumpWidget(previewSubscriptionScreenMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/subscription_screen_mobile.png'),
      );
    });
    testWidgets('previewSubscriptionScreenTablet', (WidgetTester tester) async {
      await tester.pumpWidget(previewSubscriptionScreenTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/subscription_screen_tablet.png'),
      );
    });
    testWidgets('previewSubscriptionScreenWeb', (WidgetTester tester) async {
      await tester.pumpWidget(previewSubscriptionScreenWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/subscription_screen_web.png'),
      );
    });
    testWidgets('previewSubscriptionSuccessScreenDesktop', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewSubscriptionSuccessScreenDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/subscription_success_screen_desktop.png'),
      );
    });
    testWidgets('previewSubscriptionSuccessScreenMobile', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewSubscriptionSuccessScreenMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/subscription_success_screen_mobile.png'),
      );
    });
    testWidgets('previewSubscriptionSuccessScreenTablet', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewSubscriptionSuccessScreenTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/subscription_success_screen_tablet.png'),
      );
    });
    testWidgets('previewSubscriptionSuccessScreenWeb', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewSubscriptionSuccessScreenWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/subscription_success_screen_web.png'),
      );
    });
    testWidgets('previewTermsOfServiceScreenDesktop', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewTermsOfServiceScreenDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/terms_of_service_screen_desktop.png'),
      );
    });
    testWidgets('previewTermsOfServiceScreenMobile', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewTermsOfServiceScreenMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/terms_of_service_screen_mobile.png'),
      );
    });
    testWidgets('previewTermsOfServiceScreenTablet', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(previewTermsOfServiceScreenTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/terms_of_service_screen_tablet.png'),
      );
    });
    testWidgets('previewTermsOfServiceScreenWeb', (WidgetTester tester) async {
      await tester.pumpWidget(previewTermsOfServiceScreenWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/terms_of_service_screen_web.png'),
      );
    });
    testWidgets('previewTermsScreenDesktop', (WidgetTester tester) async {
      await tester.pumpWidget(previewTermsScreenDesktop());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/terms_screen_desktop.png'),
      );
    });
    testWidgets('previewTermsScreenMobile', (WidgetTester tester) async {
      await tester.pumpWidget(previewTermsScreenMobile());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/terms_screen_mobile.png'),
      );
    });
    testWidgets('previewTermsScreenTablet', (WidgetTester tester) async {
      await tester.pumpWidget(previewTermsScreenTablet());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/terms_screen_tablet.png'),
      );
    });
    testWidgets('previewTermsScreenWeb', (WidgetTester tester) async {
      await tester.pumpWidget(previewTermsScreenWeb());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/terms_screen_web.png'),
      );
    });
    testWidgets('previewTextFieldLight', (WidgetTester tester) async {
      await tester.pumpWidget(previewTextFieldLight());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/text_field_light.png'),
      );
    });
    testWidgets('previewTextFieldStates', (WidgetTester tester) async {
      await tester.pumpWidget(previewTextFieldStates());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/text_field_states.png'),
      );
    });
    testWidgets('previewTextFieldVariants', (WidgetTester tester) async {
      await tester.pumpWidget(previewTextFieldVariants());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/text_field_variants.png'),
      );
    });
    testWidgets('previewTypography', (WidgetTester tester) async {
      await tester.pumpWidget(previewTypography());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp).first,
        matchesGoldenFile('goldens/typography.png'),
      );
    });
  });
}
