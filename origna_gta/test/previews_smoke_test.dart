import 'package:flutter_test/flutter_test.dart';
import 'test_utils.dart';
import 'package:origna_gta/previews/screens/home_screen_preview.dart' as p0;
import 'package:origna_gta/previews/screens/editaddress_screen_preview.dart' as p1;
import 'package:origna_gta/previews/screens/subscription_success_screen_preview.dart' as p2;
import 'package:origna_gta/previews/screens/main_screen_preview.dart' as p3;
import 'package:origna_gta/previews/screens/subscription_cancel_screen_preview.dart' as p4;
import 'package:origna_gta/previews/screens/terms_screen_preview.dart' as p5;
import 'package:origna_gta/previews/screens/productaddvideo_screen_preview.dart' as p6;
import 'package:origna_gta/previews/screens/order_detail_screen_preview.dart' as p7;
import 'package:origna_gta/previews/screens/checkout_screen_preview.dart' as p8;
import 'package:origna_gta/previews/screens/seller_orders_screen_preview.dart' as p9;
import 'package:origna_gta/previews/screens/favorites_screen_preview.dart' as p10;
import 'package:origna_gta/previews/screens/privacy_policy_screen_preview.dart' as p11;
import 'package:origna_gta/previews/screens/authwrapper_screen_preview.dart' as p12;
import 'package:origna_gta/previews/screens/common_screens_preview.dart' as p13;
import 'package:origna_gta/previews/screens/shipping_approval_screen_preview.dart' as p14;
import 'package:origna_gta/previews/screens/cart_screen_preview.dart' as p15;
import 'package:origna_gta/previews/screens/chat_screen_preview.dart' as p16;
import 'package:origna_gta/previews/screens/addressmanagement_screen_preview.dart' as p17;
import 'package:origna_gta/previews/screens/chat_conversations_screen_preview.dart' as p18;
import 'package:origna_gta/previews/screens/seller_warehouses_screen_preview.dart' as p19;
import 'package:origna_gta/previews/screens/productaddimages_screen_preview.dart' as p20;
import 'package:origna_gta/previews/screens/subscription_screen_preview.dart' as p21;
import 'package:origna_gta/previews/screens/cartitem_screen_preview.dart' as p22;
import 'package:origna_gta/previews/screens/addproduct_screen_preview.dart' as p23;
import 'package:origna_gta/previews/screens/notifications_screen_preview.dart' as p24;
import 'package:origna_gta/previews/screens/seller_integration_screen_preview.dart' as p25;
import 'package:origna_gta/previews/screens/reset_password_screen_preview.dart' as p26;
import 'package:origna_gta/previews/screens/payment_screens_preview.dart' as p27;
import 'package:origna_gta/previews/screens/login_screen_preview.dart' as p28;
import 'package:origna_gta/previews/screens/editproduct_screen_preview.dart' as p29;
import 'package:origna_gta/previews/screens/profile_screen_preview.dart' as p30;
import 'package:origna_gta/previews/screens/seller_products_screen_preview.dart' as p31;
import 'package:origna_gta/previews/screens/product_card_screen_preview.dart' as p32;
import 'package:origna_gta/previews/screens/productdetails_screen_preview.dart' as p33;
import 'package:origna_gta/previews/screens/orders_screen_preview.dart' as p34;
import 'package:origna_gta/previews/screens/terms_of_service_screen_preview.dart' as p35;
import 'package:origna_gta/previews/screens/seller_registration_screen_preview.dart' as p36;
import 'package:origna_gta/previews/screens/ordersuccess_screen_preview.dart' as p37;
import 'package:origna_gta/previews/screens/seller_setup_screen_preview.dart' as p38;
import 'package:origna_gta/previews/widgets/rating_dialog_preview.dart' as p39;
import 'package:origna_gta/previews/widgets/rating_histogram_preview.dart' as p40;
import 'package:origna_gta/previews/widgets/design_tokens_preview.dart' as p41;
import 'package:origna_gta/previews/widgets/modern_textfield_preview.dart' as p42;
import 'package:origna_gta/previews/widgets/modern_appbar_preview.dart' as p43;
import 'package:origna_gta/previews/widgets/modern_card_preview.dart' as p44;
import 'package:origna_gta/previews/widgets/language_selector_preview.dart' as p45;
import 'package:origna_gta/previews/widgets/custom_app_bar_preview.dart' as p46;
import 'package:origna_gta/previews/widgets/modern_loading_indicator_preview.dart' as p47;
import 'package:origna_gta/previews/widgets/loading_preview.dart' as p48;
import 'package:origna_gta/previews/widgets/mascot_preview.dart' as p49;
import 'package:origna_gta/previews/widgets/modern_product_card_preview.dart' as p50;
import 'package:origna_gta/previews/widgets/order_status_preview.dart' as p51;
import 'package:origna_gta/previews/widgets/premium_paywall_preview.dart' as p52;
import 'package:origna_gta/previews/widgets/buttons_preview.dart' as p53;
import 'package:origna_gta/previews/widgets/app_bar_preview.dart' as p54;
import 'package:origna_gta/previews/widgets/modern_button_preview.dart' as p55;
import 'package:origna_gta/previews/widgets/rating_preview.dart' as p56;
import 'package:origna_gta/previews/widgets/animations_preview.dart' as p57;
import 'package:origna_gta/previews/widgets/standalone_promo_preview.dart' as p58;
import 'package:origna_gta/previews/widgets/cards_preview.dart' as p59;
import 'package:origna_gta/previews/widgets/order_widgets_preview.dart' as p60;
import 'package:origna_gta/previews/widgets/textfields_preview.dart' as p61;
import 'package:origna_gta/previews/widgets/product_card_preview.dart' as p62;
import 'package:origna_gta/previews/widgets/legal_screen_body_preview.dart' as p63;
import 'package:origna_gta/previews/widgets/env_preview_banner_preview.dart' as p64;

void main() {
  setUpAll(() {
    initTestMocks();
  });

  group('Previews in home_screen_preview.dart', () {
    testWidgets('previewHomeScreenMobile', (tester) async {
      await tester.pumpWidget(p0.previewHomeScreenMobile());
      await tester.pump();
    });
    testWidgets('previewHomeScreenTablet', (tester) async {
      await tester.pumpWidget(p0.previewHomeScreenTablet());
      await tester.pump();
    });
    testWidgets('previewHomeScreenDesktop', (tester) async {
      await tester.pumpWidget(p0.previewHomeScreenDesktop());
      await tester.pump();
    });
    testWidgets('previewHomeScreenWeb', (tester) async {
      await tester.pumpWidget(p0.previewHomeScreenWeb());
      await tester.pump();
    });
    testWidgets('previewHomeScreenLightMobile', (tester) async {
      await tester.pumpWidget(p0.previewHomeScreenLightMobile());
      await tester.pump();
    });
    testWidgets('previewHomeScreenLightTablet', (tester) async {
      await tester.pumpWidget(p0.previewHomeScreenLightTablet());
      await tester.pump();
    });
    testWidgets('previewHomeScreenLightDesktop', (tester) async {
      await tester.pumpWidget(p0.previewHomeScreenLightDesktop());
      await tester.pump();
    });
    testWidgets('previewHomeScreenLightWeb', (tester) async {
      await tester.pumpWidget(p0.previewHomeScreenLightWeb());
      await tester.pump();
    });
    testWidgets('previewHomeScreenLoggedInMobile', (tester) async {
      await tester.pumpWidget(p0.previewHomeScreenLoggedInMobile());
      await tester.pump();
    });
    testWidgets('previewHomeScreenLoggedInTablet', (tester) async {
      await tester.pumpWidget(p0.previewHomeScreenLoggedInTablet());
      await tester.pump();
    });
    testWidgets('previewHomeScreenLoggedInDesktop', (tester) async {
      await tester.pumpWidget(p0.previewHomeScreenLoggedInDesktop());
      await tester.pump();
    });
    testWidgets('previewHomeScreenLoggedInWeb', (tester) async {
      await tester.pumpWidget(p0.previewHomeScreenLoggedInWeb());
      await tester.pump();
    });
    testWidgets('previewHomeScreenLoggedInLightMobile', (tester) async {
      await tester.pumpWidget(p0.previewHomeScreenLoggedInLightMobile());
      await tester.pump();
    });
    testWidgets('previewHomeScreenLoggedInLightTablet', (tester) async {
      await tester.pumpWidget(p0.previewHomeScreenLoggedInLightTablet());
      await tester.pump();
    });
    testWidgets('previewHomeScreenLoggedInLightDesktop', (tester) async {
      await tester.pumpWidget(p0.previewHomeScreenLoggedInLightDesktop());
      await tester.pump();
    });
    testWidgets('previewHomeScreenLoggedInLightWeb', (tester) async {
      await tester.pumpWidget(p0.previewHomeScreenLoggedInLightWeb());
      await tester.pump();
    });
  });

  group('Previews in editaddress_screen_preview.dart', () {
    testWidgets('previewAddEditAddressScreenMobile', (tester) async {
      await tester.pumpWidget(p1.previewAddEditAddressScreenMobile());
      await tester.pump();
    });
    testWidgets('previewAddEditAddressScreenTablet', (tester) async {
      await tester.pumpWidget(p1.previewAddEditAddressScreenTablet());
      await tester.pump();
    });
    testWidgets('previewAddEditAddressScreenDesktop', (tester) async {
      await tester.pumpWidget(p1.previewAddEditAddressScreenDesktop());
      await tester.pump();
    });
    testWidgets('previewAddEditAddressScreenWeb', (tester) async {
      await tester.pumpWidget(p1.previewAddEditAddressScreenWeb());
      await tester.pump();
    });
    testWidgets('previewAddEditAddressLightMobile', (tester) async {
      await tester.pumpWidget(p1.previewAddEditAddressLightMobile());
      await tester.pump();
    });
    testWidgets('previewAddEditAddressLightTablet', (tester) async {
      await tester.pumpWidget(p1.previewAddEditAddressLightTablet());
      await tester.pump();
    });
    testWidgets('previewAddEditAddressLightDesktop', (tester) async {
      await tester.pumpWidget(p1.previewAddEditAddressLightDesktop());
      await tester.pump();
    });
    testWidgets('previewAddEditAddressLightWeb', (tester) async {
      await tester.pumpWidget(p1.previewAddEditAddressLightWeb());
      await tester.pump();
    });
  });

  group('Previews in subscription_success_screen_preview.dart', () {
    testWidgets('previewSubscriptionSuccessScreenMobile', (tester) async {
      await tester.pumpWidget(p2.previewSubscriptionSuccessScreenMobile());
      await tester.pump();
    });
    testWidgets('previewSubscriptionSuccessScreenTablet', (tester) async {
      await tester.pumpWidget(p2.previewSubscriptionSuccessScreenTablet());
      await tester.pump();
    });
    testWidgets('previewSubscriptionSuccessScreenDesktop', (tester) async {
      await tester.pumpWidget(p2.previewSubscriptionSuccessScreenDesktop());
      await tester.pump();
    });
    testWidgets('previewSubscriptionSuccessScreenWeb', (tester) async {
      await tester.pumpWidget(p2.previewSubscriptionSuccessScreenWeb());
      await tester.pump();
    });
    testWidgets('previewSubscriptionSuccessLightMobile', (tester) async {
      await tester.pumpWidget(p2.previewSubscriptionSuccessLightMobile());
      await tester.pump();
    });
    testWidgets('previewSubscriptionSuccessLightTablet', (tester) async {
      await tester.pumpWidget(p2.previewSubscriptionSuccessLightTablet());
      await tester.pump();
    });
    testWidgets('previewSubscriptionSuccessLightDesktop', (tester) async {
      await tester.pumpWidget(p2.previewSubscriptionSuccessLightDesktop());
      await tester.pump();
    });
    testWidgets('previewSubscriptionSuccessLightWeb', (tester) async {
      await tester.pumpWidget(p2.previewSubscriptionSuccessLightWeb());
      await tester.pump();
    });
  });

  group('Previews in main_screen_preview.dart', () {
    testWidgets('previewMainScreenMobile', (tester) async {
      await tester.pumpWidget(p3.previewMainScreenMobile());
      await tester.pump();
    });
    testWidgets('previewMainScreenTablet', (tester) async {
      await tester.pumpWidget(p3.previewMainScreenTablet());
      await tester.pump();
    });
    testWidgets('previewMainScreenDesktop', (tester) async {
      await tester.pumpWidget(p3.previewMainScreenDesktop());
      await tester.pump();
    });
    testWidgets('previewMainScreenWeb', (tester) async {
      await tester.pumpWidget(p3.previewMainScreenWeb());
      await tester.pump();
    });
    testWidgets('previewMainScreenLightMobile', (tester) async {
      await tester.pumpWidget(p3.previewMainScreenLightMobile());
      await tester.pump();
    });
    testWidgets('previewMainScreenLightTablet', (tester) async {
      await tester.pumpWidget(p3.previewMainScreenLightTablet());
      await tester.pump();
    });
    testWidgets('previewMainScreenLightDesktop', (tester) async {
      await tester.pumpWidget(p3.previewMainScreenLightDesktop());
      await tester.pump();
    });
    testWidgets('previewMainScreenLightWeb', (tester) async {
      await tester.pumpWidget(p3.previewMainScreenLightWeb());
      await tester.pump();
    });
  });

  group('Previews in subscription_cancel_screen_preview.dart', () {
    testWidgets('previewSubscriptionCancelScreenMobile', (tester) async {
      await tester.pumpWidget(p4.previewSubscriptionCancelScreenMobile());
      await tester.pump();
    });
    testWidgets('previewSubscriptionCancelScreenTablet', (tester) async {
      await tester.pumpWidget(p4.previewSubscriptionCancelScreenTablet());
      await tester.pump();
    });
    testWidgets('previewSubscriptionCancelScreenDesktop', (tester) async {
      await tester.pumpWidget(p4.previewSubscriptionCancelScreenDesktop());
      await tester.pump();
    });
    testWidgets('previewSubscriptionCancelScreenWeb', (tester) async {
      await tester.pumpWidget(p4.previewSubscriptionCancelScreenWeb());
      await tester.pump();
    });
    testWidgets('previewSubscriptionCancelLightMobile', (tester) async {
      await tester.pumpWidget(p4.previewSubscriptionCancelLightMobile());
      await tester.pump();
    });
    testWidgets('previewSubscriptionCancelLightTablet', (tester) async {
      await tester.pumpWidget(p4.previewSubscriptionCancelLightTablet());
      await tester.pump();
    });
    testWidgets('previewSubscriptionCancelLightDesktop', (tester) async {
      await tester.pumpWidget(p4.previewSubscriptionCancelLightDesktop());
      await tester.pump();
    });
    testWidgets('previewSubscriptionCancelLightWeb', (tester) async {
      await tester.pumpWidget(p4.previewSubscriptionCancelLightWeb());
      await tester.pump();
    });
  });

  group('Previews in terms_screen_preview.dart', () {
    testWidgets('previewTermsScreenMobile', (tester) async {
      await tester.pumpWidget(p5.previewTermsScreenMobile());
      await tester.pump();
    });
    testWidgets('previewTermsScreenTablet', (tester) async {
      await tester.pumpWidget(p5.previewTermsScreenTablet());
      await tester.pump();
    });
    testWidgets('previewTermsScreenDesktop', (tester) async {
      await tester.pumpWidget(p5.previewTermsScreenDesktop());
      await tester.pump();
    });
    testWidgets('previewTermsScreenWeb', (tester) async {
      await tester.pumpWidget(p5.previewTermsScreenWeb());
      await tester.pump();
    });
    testWidgets('previewTermsScreenLightMobile', (tester) async {
      await tester.pumpWidget(p5.previewTermsScreenLightMobile());
      await tester.pump();
    });
    testWidgets('previewTermsScreenLightTablet', (tester) async {
      await tester.pumpWidget(p5.previewTermsScreenLightTablet());
      await tester.pump();
    });
    testWidgets('previewTermsScreenLightDesktop', (tester) async {
      await tester.pumpWidget(p5.previewTermsScreenLightDesktop());
      await tester.pump();
    });
    testWidgets('previewTermsScreenLightWeb', (tester) async {
      await tester.pumpWidget(p5.previewTermsScreenLightWeb());
      await tester.pump();
    });
  });

  group('Previews in productaddvideo_screen_preview.dart', () {
    testWidgets('previewProductAddVideoMobile', (tester) async {
      await tester.pumpWidget(p6.previewProductAddVideoMobile());
      await tester.pump();
    });
    testWidgets('previewProductAddVideoTablet', (tester) async {
      await tester.pumpWidget(p6.previewProductAddVideoTablet());
      await tester.pump();
    });
    testWidgets('previewProductAddVideoDesktop', (tester) async {
      await tester.pumpWidget(p6.previewProductAddVideoDesktop());
      await tester.pump();
    });
    testWidgets('previewProductAddVideoWeb', (tester) async {
      await tester.pumpWidget(p6.previewProductAddVideoWeb());
      await tester.pump();
    });
    testWidgets('previewProductAddVideoLightMobile', (tester) async {
      await tester.pumpWidget(p6.previewProductAddVideoLightMobile());
      await tester.pump();
    });
    testWidgets('previewProductAddVideoLightTablet', (tester) async {
      await tester.pumpWidget(p6.previewProductAddVideoLightTablet());
      await tester.pump();
    });
    testWidgets('previewProductAddVideoLightDesktop', (tester) async {
      await tester.pumpWidget(p6.previewProductAddVideoLightDesktop());
      await tester.pump();
    });
    testWidgets('previewProductAddVideoLightWeb', (tester) async {
      await tester.pumpWidget(p6.previewProductAddVideoLightWeb());
      await tester.pump();
    });
  });

  group('Previews in order_detail_screen_preview.dart', () {
    testWidgets('previewOrderDetailScreenMobile', (tester) async {
      await tester.pumpWidget(p7.previewOrderDetailScreenMobile());
      await tester.pump();
    });
    testWidgets('previewOrderDetailScreenTablet', (tester) async {
      await tester.pumpWidget(p7.previewOrderDetailScreenTablet());
      await tester.pump();
    });
    testWidgets('previewOrderDetailScreenDesktop', (tester) async {
      await tester.pumpWidget(p7.previewOrderDetailScreenDesktop());
      await tester.pump();
    });
    testWidgets('previewOrderDetailScreenWeb', (tester) async {
      await tester.pumpWidget(p7.previewOrderDetailScreenWeb());
      await tester.pump();
    });
    testWidgets('previewOrderDetailScreenLightMobile', (tester) async {
      await tester.pumpWidget(p7.previewOrderDetailScreenLightMobile());
      await tester.pump();
    });
    testWidgets('previewOrderDetailScreenLightTablet', (tester) async {
      await tester.pumpWidget(p7.previewOrderDetailScreenLightTablet());
      await tester.pump();
    });
    testWidgets('previewOrderDetailScreenLightDesktop', (tester) async {
      await tester.pumpWidget(p7.previewOrderDetailScreenLightDesktop());
      await tester.pump();
    });
    testWidgets('previewOrderDetailScreenLightWeb', (tester) async {
      await tester.pumpWidget(p7.previewOrderDetailScreenLightWeb());
      await tester.pump();
    });
  });

  group('Previews in checkout_screen_preview.dart', () {
    testWidgets('previewCheckoutScreenMobile', (tester) async {
      await tester.pumpWidget(p8.previewCheckoutScreenMobile());
      await tester.pump();
    });
    testWidgets('previewCheckoutScreenTablet', (tester) async {
      await tester.pumpWidget(p8.previewCheckoutScreenTablet());
      await tester.pump();
    });
    testWidgets('previewCheckoutScreenDesktop', (tester) async {
      await tester.pumpWidget(p8.previewCheckoutScreenDesktop());
      await tester.pump();
    });
    testWidgets('previewCheckoutScreenWeb', (tester) async {
      await tester.pumpWidget(p8.previewCheckoutScreenWeb());
      await tester.pump();
    });
    testWidgets('previewCheckoutLightMobile', (tester) async {
      await tester.pumpWidget(p8.previewCheckoutLightMobile());
      await tester.pump();
    });
    testWidgets('previewCheckoutLightTablet', (tester) async {
      await tester.pumpWidget(p8.previewCheckoutLightTablet());
      await tester.pump();
    });
    testWidgets('previewCheckoutLightDesktop', (tester) async {
      await tester.pumpWidget(p8.previewCheckoutLightDesktop());
      await tester.pump();
    });
    testWidgets('previewCheckoutLightWeb', (tester) async {
      await tester.pumpWidget(p8.previewCheckoutLightWeb());
      await tester.pump();
    });
    testWidgets('previewCheckoutSingleMobile', (tester) async {
      await tester.pumpWidget(p8.previewCheckoutSingleMobile());
      await tester.pump();
    });
    testWidgets('previewCheckoutSingleTablet', (tester) async {
      await tester.pumpWidget(p8.previewCheckoutSingleTablet());
      await tester.pump();
    });
    testWidgets('previewCheckoutSingleDesktop', (tester) async {
      await tester.pumpWidget(p8.previewCheckoutSingleDesktop());
      await tester.pump();
    });
    testWidgets('previewCheckoutSingleWeb', (tester) async {
      await tester.pumpWidget(p8.previewCheckoutSingleWeb());
      await tester.pump();
    });
    testWidgets('previewCheckoutSingleLightMobile', (tester) async {
      await tester.pumpWidget(p8.previewCheckoutSingleLightMobile());
      await tester.pump();
    });
    testWidgets('previewCheckoutSingleLightDesktop', (tester) async {
      await tester.pumpWidget(p8.previewCheckoutSingleLightDesktop());
      await tester.pump();
    });
  });

  group('Previews in seller_orders_screen_preview.dart', () {
    testWidgets('previewSellerOrdersScreenMobile', (tester) async {
      await tester.pumpWidget(p9.previewSellerOrdersScreenMobile());
      await tester.pump();
    });
    testWidgets('previewSellerOrdersScreenTablet', (tester) async {
      await tester.pumpWidget(p9.previewSellerOrdersScreenTablet());
      await tester.pump();
    });
    testWidgets('previewSellerOrdersScreenDesktop', (tester) async {
      await tester.pumpWidget(p9.previewSellerOrdersScreenDesktop());
      await tester.pump();
    });
    testWidgets('previewSellerOrdersScreenWeb', (tester) async {
      await tester.pumpWidget(p9.previewSellerOrdersScreenWeb());
      await tester.pump();
    });
    testWidgets('previewSellerOrdersLightMobile', (tester) async {
      await tester.pumpWidget(p9.previewSellerOrdersLightMobile());
      await tester.pump();
    });
    testWidgets('previewSellerOrdersLightDesktop', (tester) async {
      await tester.pumpWidget(p9.previewSellerOrdersLightDesktop());
      await tester.pump();
    });
    testWidgets('previewSellerOrdersLightTablet', (tester) async {
      await tester.pumpWidget(p9.previewSellerOrdersLightTablet());
      await tester.pump();
    });
    testWidgets('previewSellerOrdersLightWeb', (tester) async {
      await tester.pumpWidget(p9.previewSellerOrdersLightWeb());
      await tester.pump();
    });
  });

  group('Previews in favorites_screen_preview.dart', () {
    testWidgets('previewFavoritesScreenMobile', (tester) async {
      await tester.pumpWidget(p10.previewFavoritesScreenMobile());
      await tester.pump();
    });
    testWidgets('previewFavoritesScreenTablet', (tester) async {
      await tester.pumpWidget(p10.previewFavoritesScreenTablet());
      await tester.pump();
    });
    testWidgets('previewFavoritesScreenDesktop', (tester) async {
      await tester.pumpWidget(p10.previewFavoritesScreenDesktop());
      await tester.pump();
    });
    testWidgets('previewFavoritesScreenWeb', (tester) async {
      await tester.pumpWidget(p10.previewFavoritesScreenWeb());
      await tester.pump();
    });
    testWidgets('previewFavoritesLightMobile', (tester) async {
      await tester.pumpWidget(p10.previewFavoritesLightMobile());
      await tester.pump();
    });
    testWidgets('previewFavoritesLightTablet', (tester) async {
      await tester.pumpWidget(p10.previewFavoritesLightTablet());
      await tester.pump();
    });
    testWidgets('previewFavoritesLightDesktop', (tester) async {
      await tester.pumpWidget(p10.previewFavoritesLightDesktop());
      await tester.pump();
    });
    testWidgets('previewFavoritesLightWeb', (tester) async {
      await tester.pumpWidget(p10.previewFavoritesLightWeb());
      await tester.pump();
    });
    testWidgets('previewFavoritesEmptyMobile', (tester) async {
      await tester.pumpWidget(p10.previewFavoritesEmptyMobile());
      await tester.pump();
    });
    testWidgets('previewFavoritesEmptyTablet', (tester) async {
      await tester.pumpWidget(p10.previewFavoritesEmptyTablet());
      await tester.pump();
    });
    testWidgets('previewFavoritesEmptyDesktop', (tester) async {
      await tester.pumpWidget(p10.previewFavoritesEmptyDesktop());
      await tester.pump();
    });
    testWidgets('previewFavoritesEmptyWeb', (tester) async {
      await tester.pumpWidget(p10.previewFavoritesEmptyWeb());
      await tester.pump();
    });
    testWidgets('previewFavoritesEmptyLightMobile', (tester) async {
      await tester.pumpWidget(p10.previewFavoritesEmptyLightMobile());
      await tester.pump();
    });
    testWidgets('previewFavoritesEmptyLightTablet', (tester) async {
      await tester.pumpWidget(p10.previewFavoritesEmptyLightTablet());
      await tester.pump();
    });
    testWidgets('previewFavoritesEmptyLightDesktop', (tester) async {
      await tester.pumpWidget(p10.previewFavoritesEmptyLightDesktop());
      await tester.pump();
    });
    testWidgets('previewFavoritesEmptyLightWeb', (tester) async {
      await tester.pumpWidget(p10.previewFavoritesEmptyLightWeb());
      await tester.pump();
    });
  });

  group('Previews in privacy_policy_screen_preview.dart', () {
    testWidgets('previewPrivacyPolicyScreenMobile', (tester) async {
      await tester.pumpWidget(p11.previewPrivacyPolicyScreenMobile());
      await tester.pump();
    });
    testWidgets('previewPrivacyPolicyScreenTablet', (tester) async {
      await tester.pumpWidget(p11.previewPrivacyPolicyScreenTablet());
      await tester.pump();
    });
    testWidgets('previewPrivacyPolicyScreenDesktop', (tester) async {
      await tester.pumpWidget(p11.previewPrivacyPolicyScreenDesktop());
      await tester.pump();
    });
    testWidgets('previewPrivacyPolicyScreenWeb', (tester) async {
      await tester.pumpWidget(p11.previewPrivacyPolicyScreenWeb());
      await tester.pump();
    });
    testWidgets('previewPrivacyPolicyLightMobile', (tester) async {
      await tester.pumpWidget(p11.previewPrivacyPolicyLightMobile());
      await tester.pump();
    });
    testWidgets('previewPrivacyPolicyLightTablet', (tester) async {
      await tester.pumpWidget(p11.previewPrivacyPolicyLightTablet());
      await tester.pump();
    });
    testWidgets('previewPrivacyPolicyLightDesktop', (tester) async {
      await tester.pumpWidget(p11.previewPrivacyPolicyLightDesktop());
      await tester.pump();
    });
    testWidgets('previewPrivacyPolicyLightWeb', (tester) async {
      await tester.pumpWidget(p11.previewPrivacyPolicyLightWeb());
      await tester.pump();
    });
  });

  group('Previews in authwrapper_screen_preview.dart', () {
    testWidgets('previewAuthWrapperScreenMobile', (tester) async {
      await tester.pumpWidget(p12.previewAuthWrapperScreenMobile());
      await tester.pump();
    });
    testWidgets('previewAuthWrapperScreenTablet', (tester) async {
      await tester.pumpWidget(p12.previewAuthWrapperScreenTablet());
      await tester.pump();
    });
    testWidgets('previewAuthWrapperScreenDesktop', (tester) async {
      await tester.pumpWidget(p12.previewAuthWrapperScreenDesktop());
      await tester.pump();
    });
    testWidgets('previewAuthWrapperScreenWeb', (tester) async {
      await tester.pumpWidget(p12.previewAuthWrapperScreenWeb());
      await tester.pump();
    });
    testWidgets('previewAuthWrapperLightMobile', (tester) async {
      await tester.pumpWidget(p12.previewAuthWrapperLightMobile());
      await tester.pump();
    });
    testWidgets('previewAuthWrapperLightTablet', (tester) async {
      await tester.pumpWidget(p12.previewAuthWrapperLightTablet());
      await tester.pump();
    });
    testWidgets('previewAuthWrapperLightDesktop', (tester) async {
      await tester.pumpWidget(p12.previewAuthWrapperLightDesktop());
      await tester.pump();
    });
    testWidgets('previewAuthWrapperLightWeb', (tester) async {
      await tester.pumpWidget(p12.previewAuthWrapperLightWeb());
      await tester.pump();
    });
  });

  group('Previews in common_screens_preview.dart', () {
    testWidgets('previewEmailVerificationRequiredScreenMobile', (tester) async {
      await tester.pumpWidget(p13.previewEmailVerificationRequiredScreenMobile());
      await tester.pump();
    });
    testWidgets('previewEmailVerificationRequiredScreenTablet', (tester) async {
      await tester.pumpWidget(p13.previewEmailVerificationRequiredScreenTablet());
      await tester.pump();
    });
    testWidgets('previewEmailVerificationRequiredScreenDesktop', (tester) async {
      await tester.pumpWidget(p13.previewEmailVerificationRequiredScreenDesktop());
      await tester.pump();
    });
    testWidgets('previewEmailVerificationRequiredScreenWeb', (tester) async {
      await tester.pumpWidget(p13.previewEmailVerificationRequiredScreenWeb());
      await tester.pump();
    });
    testWidgets('previewEmailVerificationLightMobile', (tester) async {
      await tester.pumpWidget(p13.previewEmailVerificationLightMobile());
      await tester.pump();
    });
    testWidgets('previewEmailVerificationLightTablet', (tester) async {
      await tester.pumpWidget(p13.previewEmailVerificationLightTablet());
      await tester.pump();
    });
    testWidgets('previewEmailVerificationLightDesktop', (tester) async {
      await tester.pumpWidget(p13.previewEmailVerificationLightDesktop());
      await tester.pump();
    });
    testWidgets('previewEmailVerificationLightWeb', (tester) async {
      await tester.pumpWidget(p13.previewEmailVerificationLightWeb());
      await tester.pump();
    });
  });

  group('Previews in shipping_approval_screen_preview.dart', () {
    testWidgets('previewShippingApprovalScreenMobile', (tester) async {
      await tester.pumpWidget(p14.previewShippingApprovalScreenMobile());
      await tester.pump();
    });
    testWidgets('previewShippingApprovalScreenTablet', (tester) async {
      await tester.pumpWidget(p14.previewShippingApprovalScreenTablet());
      await tester.pump();
    });
    testWidgets('previewShippingApprovalScreenDesktop', (tester) async {
      await tester.pumpWidget(p14.previewShippingApprovalScreenDesktop());
      await tester.pump();
    });
    testWidgets('previewShippingApprovalScreenWeb', (tester) async {
      await tester.pumpWidget(p14.previewShippingApprovalScreenWeb());
      await tester.pump();
    });
    testWidgets('previewShippingApprovalLightMobile', (tester) async {
      await tester.pumpWidget(p14.previewShippingApprovalLightMobile());
      await tester.pump();
    });
    testWidgets('previewShippingApprovalLightDesktop', (tester) async {
      await tester.pumpWidget(p14.previewShippingApprovalLightDesktop());
      await tester.pump();
    });
    testWidgets('previewShippingApprovalLightTablet', (tester) async {
      await tester.pumpWidget(p14.previewShippingApprovalLightTablet());
      await tester.pump();
    });
    testWidgets('previewShippingApprovalLightWeb', (tester) async {
      await tester.pumpWidget(p14.previewShippingApprovalLightWeb());
      await tester.pump();
    });
  });

  group('Previews in cart_screen_preview.dart', () {
    testWidgets('previewCartScreenMobile', (tester) async {
      await tester.pumpWidget(p15.previewCartScreenMobile());
      await tester.pump();
    });
    testWidgets('previewCartScreenTablet', (tester) async {
      await tester.pumpWidget(p15.previewCartScreenTablet());
      await tester.pump();
    });
    testWidgets('previewCartScreenDesktop', (tester) async {
      await tester.pumpWidget(p15.previewCartScreenDesktop());
      await tester.pump();
    });
    testWidgets('previewCartScreenWeb', (tester) async {
      await tester.pumpWidget(p15.previewCartScreenWeb());
      await tester.pump();
    });
    testWidgets('previewCartScreenLightMobile', (tester) async {
      await tester.pumpWidget(p15.previewCartScreenLightMobile());
      await tester.pump();
    });
    testWidgets('previewCartScreenLightTablet', (tester) async {
      await tester.pumpWidget(p15.previewCartScreenLightTablet());
      await tester.pump();
    });
    testWidgets('previewCartScreenLightDesktop', (tester) async {
      await tester.pumpWidget(p15.previewCartScreenLightDesktop());
      await tester.pump();
    });
    testWidgets('previewCartScreenLightWeb', (tester) async {
      await tester.pumpWidget(p15.previewCartScreenLightWeb());
      await tester.pump();
    });
    testWidgets('previewCartScreenEmptyMobile', (tester) async {
      await tester.pumpWidget(p15.previewCartScreenEmptyMobile());
      await tester.pump();
    });
    testWidgets('previewCartScreenEmptyTablet', (tester) async {
      await tester.pumpWidget(p15.previewCartScreenEmptyTablet());
      await tester.pump();
    });
    testWidgets('previewCartScreenEmptyDesktop', (tester) async {
      await tester.pumpWidget(p15.previewCartScreenEmptyDesktop());
      await tester.pump();
    });
    testWidgets('previewCartScreenEmptyWeb', (tester) async {
      await tester.pumpWidget(p15.previewCartScreenEmptyWeb());
      await tester.pump();
    });
  });

  group('Previews in chat_screen_preview.dart', () {
    testWidgets('previewChatScreenMobile', (tester) async {
      await tester.pumpWidget(p16.previewChatScreenMobile());
      await tester.pump();
    });
    testWidgets('previewChatScreenTablet', (tester) async {
      await tester.pumpWidget(p16.previewChatScreenTablet());
      await tester.pump();
    });
    testWidgets('previewChatScreenDesktop', (tester) async {
      await tester.pumpWidget(p16.previewChatScreenDesktop());
      await tester.pump();
    });
    testWidgets('previewChatScreenWeb', (tester) async {
      await tester.pumpWidget(p16.previewChatScreenWeb());
      await tester.pump();
    });
    testWidgets('previewChatScreenLightMobile', (tester) async {
      await tester.pumpWidget(p16.previewChatScreenLightMobile());
      await tester.pump();
    });
    testWidgets('previewChatScreenLightTablet', (tester) async {
      await tester.pumpWidget(p16.previewChatScreenLightTablet());
      await tester.pump();
    });
    testWidgets('previewChatScreenLightDesktop', (tester) async {
      await tester.pumpWidget(p16.previewChatScreenLightDesktop());
      await tester.pump();
    });
    testWidgets('previewChatScreenLightWeb', (tester) async {
      await tester.pumpWidget(p16.previewChatScreenLightWeb());
      await tester.pump();
    });
    testWidgets('previewChatScreenFrMobile', (tester) async {
      await tester.pumpWidget(p16.previewChatScreenFrMobile());
      await tester.pump();
    });
    testWidgets('previewChatScreenFrDesktop', (tester) async {
      await tester.pumpWidget(p16.previewChatScreenFrDesktop());
      await tester.pump();
    });
  });

  group('Previews in addressmanagement_screen_preview.dart', () {
    testWidgets('previewAddressManagementScreenMobile', (tester) async {
      await tester.pumpWidget(p17.previewAddressManagementScreenMobile());
      await tester.pump();
    });
    testWidgets('previewAddressManagementScreenTablet', (tester) async {
      await tester.pumpWidget(p17.previewAddressManagementScreenTablet());
      await tester.pump();
    });
    testWidgets('previewAddressManagementScreenDesktop', (tester) async {
      await tester.pumpWidget(p17.previewAddressManagementScreenDesktop());
      await tester.pump();
    });
    testWidgets('previewAddressManagementScreenWeb', (tester) async {
      await tester.pumpWidget(p17.previewAddressManagementScreenWeb());
      await tester.pump();
    });
    testWidgets('previewAddressManagementLightMobile', (tester) async {
      await tester.pumpWidget(p17.previewAddressManagementLightMobile());
      await tester.pump();
    });
    testWidgets('previewAddressManagementLightTablet', (tester) async {
      await tester.pumpWidget(p17.previewAddressManagementLightTablet());
      await tester.pump();
    });
    testWidgets('previewAddressManagementLightDesktop', (tester) async {
      await tester.pumpWidget(p17.previewAddressManagementLightDesktop());
      await tester.pump();
    });
    testWidgets('previewAddressManagementLightWeb', (tester) async {
      await tester.pumpWidget(p17.previewAddressManagementLightWeb());
      await tester.pump();
    });
    testWidgets('previewAddressManagementEmptyMobile', (tester) async {
      await tester.pumpWidget(p17.previewAddressManagementEmptyMobile());
      await tester.pump();
    });
    testWidgets('previewAddressManagementEmptyTablet', (tester) async {
      await tester.pumpWidget(p17.previewAddressManagementEmptyTablet());
      await tester.pump();
    });
    testWidgets('previewAddressManagementEmptyDesktop', (tester) async {
      await tester.pumpWidget(p17.previewAddressManagementEmptyDesktop());
      await tester.pump();
    });
    testWidgets('previewAddressManagementEmptyWeb', (tester) async {
      await tester.pumpWidget(p17.previewAddressManagementEmptyWeb());
      await tester.pump();
    });
    testWidgets('previewAddressManagementWithAddrMobile', (tester) async {
      await tester.pumpWidget(p17.previewAddressManagementWithAddrMobile());
      await tester.pump();
    });
    testWidgets('previewAddressManagementWithAddrTablet', (tester) async {
      await tester.pumpWidget(p17.previewAddressManagementWithAddrTablet());
      await tester.pump();
    });
    testWidgets('previewAddressManagementWithAddrDesktop', (tester) async {
      await tester.pumpWidget(p17.previewAddressManagementWithAddrDesktop());
      await tester.pump();
    });
    testWidgets('previewAddressManagementWithAddrWeb', (tester) async {
      await tester.pumpWidget(p17.previewAddressManagementWithAddrWeb());
      await tester.pump();
    });
    testWidgets('previewAddressManagementWithAddrLightMobile', (tester) async {
      await tester.pumpWidget(p17.previewAddressManagementWithAddrLightMobile());
      await tester.pump();
    });
    testWidgets('previewAddressManagementWithAddrLightDesktop', (tester) async {
      await tester.pumpWidget(p17.previewAddressManagementWithAddrLightDesktop());
      await tester.pump();
    });
  });

  group('Previews in chat_conversations_screen_preview.dart', () {
    testWidgets('previewChatConversationsScreenMobile', (tester) async {
      await tester.pumpWidget(p18.previewChatConversationsScreenMobile());
      await tester.pump();
    });
    testWidgets('previewChatConversationsScreenTablet', (tester) async {
      await tester.pumpWidget(p18.previewChatConversationsScreenTablet());
      await tester.pump();
    });
    testWidgets('previewChatConversationsScreenDesktop', (tester) async {
      await tester.pumpWidget(p18.previewChatConversationsScreenDesktop());
      await tester.pump();
    });
    testWidgets('previewChatConversationsScreenWeb', (tester) async {
      await tester.pumpWidget(p18.previewChatConversationsScreenWeb());
      await tester.pump();
    });
    testWidgets('previewChatConversationsLightMobile', (tester) async {
      await tester.pumpWidget(p18.previewChatConversationsLightMobile());
      await tester.pump();
    });
    testWidgets('previewChatConversationsLightDesktop', (tester) async {
      await tester.pumpWidget(p18.previewChatConversationsLightDesktop());
      await tester.pump();
    });
    testWidgets('previewChatConversationsLightTablet', (tester) async {
      await tester.pumpWidget(p18.previewChatConversationsLightTablet());
      await tester.pump();
    });
    testWidgets('previewChatConversationsLightWeb', (tester) async {
      await tester.pumpWidget(p18.previewChatConversationsLightWeb());
      await tester.pump();
    });
  });

  group('Previews in seller_warehouses_screen_preview.dart', () {
    testWidgets('previewSellerWarehousesScreenMobile', (tester) async {
      await tester.pumpWidget(p19.previewSellerWarehousesScreenMobile());
      await tester.pump();
    });
    testWidgets('previewSellerWarehousesScreenTablet', (tester) async {
      await tester.pumpWidget(p19.previewSellerWarehousesScreenTablet());
      await tester.pump();
    });
    testWidgets('previewSellerWarehousesScreenDesktop', (tester) async {
      await tester.pumpWidget(p19.previewSellerWarehousesScreenDesktop());
      await tester.pump();
    });
    testWidgets('previewSellerWarehousesScreenWeb', (tester) async {
      await tester.pumpWidget(p19.previewSellerWarehousesScreenWeb());
      await tester.pump();
    });
    testWidgets('previewSellerWarehousesLightMobile', (tester) async {
      await tester.pumpWidget(p19.previewSellerWarehousesLightMobile());
      await tester.pump();
    });
    testWidgets('previewSellerWarehousesLightTablet', (tester) async {
      await tester.pumpWidget(p19.previewSellerWarehousesLightTablet());
      await tester.pump();
    });
    testWidgets('previewSellerWarehousesLightDesktop', (tester) async {
      await tester.pumpWidget(p19.previewSellerWarehousesLightDesktop());
      await tester.pump();
    });
    testWidgets('previewSellerWarehousesLightWeb', (tester) async {
      await tester.pumpWidget(p19.previewSellerWarehousesLightWeb());
      await tester.pump();
    });
  });

  group('Previews in productaddimages_screen_preview.dart', () {
    testWidgets('previewProductAddImagesMobile', (tester) async {
      await tester.pumpWidget(p20.previewProductAddImagesMobile());
      await tester.pump();
    });
    testWidgets('previewProductAddImagesTablet', (tester) async {
      await tester.pumpWidget(p20.previewProductAddImagesTablet());
      await tester.pump();
    });
    testWidgets('previewProductAddImagesDesktop', (tester) async {
      await tester.pumpWidget(p20.previewProductAddImagesDesktop());
      await tester.pump();
    });
    testWidgets('previewProductAddImagesWeb', (tester) async {
      await tester.pumpWidget(p20.previewProductAddImagesWeb());
      await tester.pump();
    });
    testWidgets('previewProductAddImagesLightMobile', (tester) async {
      await tester.pumpWidget(p20.previewProductAddImagesLightMobile());
      await tester.pump();
    });
    testWidgets('previewProductAddImagesLightTablet', (tester) async {
      await tester.pumpWidget(p20.previewProductAddImagesLightTablet());
      await tester.pump();
    });
    testWidgets('previewProductAddImagesLightDesktop', (tester) async {
      await tester.pumpWidget(p20.previewProductAddImagesLightDesktop());
      await tester.pump();
    });
    testWidgets('previewProductAddImagesLightWeb', (tester) async {
      await tester.pumpWidget(p20.previewProductAddImagesLightWeb());
      await tester.pump();
    });
  });

  group('Previews in subscription_screen_preview.dart', () {
    testWidgets('previewSubscriptionScreenMobile', (tester) async {
      await tester.pumpWidget(p21.previewSubscriptionScreenMobile());
      await tester.pump();
    });
    testWidgets('previewSubscriptionScreenTablet', (tester) async {
      await tester.pumpWidget(p21.previewSubscriptionScreenTablet());
      await tester.pump();
    });
    testWidgets('previewSubscriptionScreenDesktop', (tester) async {
      await tester.pumpWidget(p21.previewSubscriptionScreenDesktop());
      await tester.pump();
    });
    testWidgets('previewSubscriptionScreenWeb', (tester) async {
      await tester.pumpWidget(p21.previewSubscriptionScreenWeb());
      await tester.pump();
    });
    testWidgets('previewSubscriptionLightMobile', (tester) async {
      await tester.pumpWidget(p21.previewSubscriptionLightMobile());
      await tester.pump();
    });
    testWidgets('previewSubscriptionLightDesktop', (tester) async {
      await tester.pumpWidget(p21.previewSubscriptionLightDesktop());
      await tester.pump();
    });
    testWidgets('previewSubscriptionLightTablet', (tester) async {
      await tester.pumpWidget(p21.previewSubscriptionLightTablet());
      await tester.pump();
    });
    testWidgets('previewSubscriptionLightWeb', (tester) async {
      await tester.pumpWidget(p21.previewSubscriptionLightWeb());
      await tester.pump();
    });
    testWidgets('previewSubscriptionPremiumMobile', (tester) async {
      await tester.pumpWidget(p21.previewSubscriptionPremiumMobile());
      await tester.pump();
    });
    testWidgets('previewSubscriptionPremiumTablet', (tester) async {
      await tester.pumpWidget(p21.previewSubscriptionPremiumTablet());
      await tester.pump();
    });
    testWidgets('previewSubscriptionPremiumDesktop', (tester) async {
      await tester.pumpWidget(p21.previewSubscriptionPremiumDesktop());
      await tester.pump();
    });
    testWidgets('previewSubscriptionPremiumWeb', (tester) async {
      await tester.pumpWidget(p21.previewSubscriptionPremiumWeb());
      await tester.pump();
    });
    testWidgets('previewSubscriptionPremiumLightMobile', (tester) async {
      await tester.pumpWidget(p21.previewSubscriptionPremiumLightMobile());
      await tester.pump();
    });
    testWidgets('previewSubscriptionPremiumLightDesktop', (tester) async {
      await tester.pumpWidget(p21.previewSubscriptionPremiumLightDesktop());
      await tester.pump();
    });
  });

  group('Previews in cartitem_screen_preview.dart', () {
    testWidgets('previewCartItemScreenMobile', (tester) async {
      await tester.pumpWidget(p22.previewCartItemScreenMobile());
      await tester.pump();
    });
    testWidgets('previewCartItemScreenTablet', (tester) async {
      await tester.pumpWidget(p22.previewCartItemScreenTablet());
      await tester.pump();
    });
    testWidgets('previewCartItemScreenDesktop', (tester) async {
      await tester.pumpWidget(p22.previewCartItemScreenDesktop());
      await tester.pump();
    });
    testWidgets('previewCartItemScreenWeb', (tester) async {
      await tester.pumpWidget(p22.previewCartItemScreenWeb());
      await tester.pump();
    });
    testWidgets('previewCartItemScreenLightMobile', (tester) async {
      await tester.pumpWidget(p22.previewCartItemScreenLightMobile());
      await tester.pump();
    });
    testWidgets('previewCartItemScreenLightTablet', (tester) async {
      await tester.pumpWidget(p22.previewCartItemScreenLightTablet());
      await tester.pump();
    });
    testWidgets('previewCartItemScreenLightDesktop', (tester) async {
      await tester.pumpWidget(p22.previewCartItemScreenLightDesktop());
      await tester.pump();
    });
    testWidgets('previewCartItemScreenLightWeb', (tester) async {
      await tester.pumpWidget(p22.previewCartItemScreenLightWeb());
      await tester.pump();
    });
  });

  group('Previews in addproduct_screen_preview.dart', () {
    testWidgets('previewAddProductScreenMobile', (tester) async {
      await tester.pumpWidget(p23.previewAddProductScreenMobile());
      await tester.pump();
    });
    testWidgets('previewAddProductScreenTablet', (tester) async {
      await tester.pumpWidget(p23.previewAddProductScreenTablet());
      await tester.pump();
    });
    testWidgets('previewAddProductScreenDesktop', (tester) async {
      await tester.pumpWidget(p23.previewAddProductScreenDesktop());
      await tester.pump();
    });
    testWidgets('previewAddProductScreenWeb', (tester) async {
      await tester.pumpWidget(p23.previewAddProductScreenWeb());
      await tester.pump();
    });
    testWidgets('previewAddProductLightMobile', (tester) async {
      await tester.pumpWidget(p23.previewAddProductLightMobile());
      await tester.pump();
    });
    testWidgets('previewAddProductLightTablet', (tester) async {
      await tester.pumpWidget(p23.previewAddProductLightTablet());
      await tester.pump();
    });
    testWidgets('previewAddProductLightDesktop', (tester) async {
      await tester.pumpWidget(p23.previewAddProductLightDesktop());
      await tester.pump();
    });
    testWidgets('previewAddProductLightWeb', (tester) async {
      await tester.pumpWidget(p23.previewAddProductLightWeb());
      await tester.pump();
    });
  });

  group('Previews in notifications_screen_preview.dart', () {
    testWidgets('previewNotificationsScreenMobile', (tester) async {
      await tester.pumpWidget(p24.previewNotificationsScreenMobile());
      await tester.pump();
    });
    testWidgets('previewNotificationsScreenTablet', (tester) async {
      await tester.pumpWidget(p24.previewNotificationsScreenTablet());
      await tester.pump();
    });
    testWidgets('previewNotificationsScreenDesktop', (tester) async {
      await tester.pumpWidget(p24.previewNotificationsScreenDesktop());
      await tester.pump();
    });
    testWidgets('previewNotificationsScreenWeb', (tester) async {
      await tester.pumpWidget(p24.previewNotificationsScreenWeb());
      await tester.pump();
    });
    testWidgets('previewNotificationsScreenEmptyMobile', (tester) async {
      await tester.pumpWidget(p24.previewNotificationsScreenEmptyMobile());
      await tester.pump();
    });
    testWidgets('previewNotificationsScreenEmptyTablet', (tester) async {
      await tester.pumpWidget(p24.previewNotificationsScreenEmptyTablet());
      await tester.pump();
    });
    testWidgets('previewNotificationsScreenEmptyDesktop', (tester) async {
      await tester.pumpWidget(p24.previewNotificationsScreenEmptyDesktop());
      await tester.pump();
    });
    testWidgets('previewNotificationsScreenEmptyWeb', (tester) async {
      await tester.pumpWidget(p24.previewNotificationsScreenEmptyWeb());
      await tester.pump();
    });
    testWidgets('previewNotificationsLightMobile', (tester) async {
      await tester.pumpWidget(p24.previewNotificationsLightMobile());
      await tester.pump();
    });
    testWidgets('previewNotificationsLightTablet', (tester) async {
      await tester.pumpWidget(p24.previewNotificationsLightTablet());
      await tester.pump();
    });
    testWidgets('previewNotificationsLightDesktop', (tester) async {
      await tester.pumpWidget(p24.previewNotificationsLightDesktop());
      await tester.pump();
    });
    testWidgets('previewNotificationsLightWeb', (tester) async {
      await tester.pumpWidget(p24.previewNotificationsLightWeb());
      await tester.pump();
    });
    testWidgets('previewNotificationsEmptyLightMobile', (tester) async {
      await tester.pumpWidget(p24.previewNotificationsEmptyLightMobile());
      await tester.pump();
    });
    testWidgets('previewNotificationsEmptyLightTablet', (tester) async {
      await tester.pumpWidget(p24.previewNotificationsEmptyLightTablet());
      await tester.pump();
    });
    testWidgets('previewNotificationsEmptyLightDesktop', (tester) async {
      await tester.pumpWidget(p24.previewNotificationsEmptyLightDesktop());
      await tester.pump();
    });
    testWidgets('previewNotificationsEmptyLightWeb', (tester) async {
      await tester.pumpWidget(p24.previewNotificationsEmptyLightWeb());
      await tester.pump();
    });
  });

  group('Previews in seller_integration_screen_preview.dart', () {
    testWidgets('previewSellerIntegrationDarkMobile', (tester) async {
      await tester.pumpWidget(p25.previewSellerIntegrationDarkMobile());
      await tester.pump();
    });
    testWidgets('previewSellerIntegrationDarkTablet', (tester) async {
      await tester.pumpWidget(p25.previewSellerIntegrationDarkTablet());
      await tester.pump();
    });
    testWidgets('previewSellerIntegrationDarkDesktop', (tester) async {
      await tester.pumpWidget(p25.previewSellerIntegrationDarkDesktop());
      await tester.pump();
    });
    testWidgets('previewSellerIntegrationDarkWeb', (tester) async {
      await tester.pumpWidget(p25.previewSellerIntegrationDarkWeb());
      await tester.pump();
    });
    testWidgets('previewSellerIntegrationLightMobile', (tester) async {
      await tester.pumpWidget(p25.previewSellerIntegrationLightMobile());
      await tester.pump();
    });
    testWidgets('previewSellerIntegrationLightTablet', (tester) async {
      await tester.pumpWidget(p25.previewSellerIntegrationLightTablet());
      await tester.pump();
    });
    testWidgets('previewSellerIntegrationLightDesktop', (tester) async {
      await tester.pumpWidget(p25.previewSellerIntegrationLightDesktop());
      await tester.pump();
    });
    testWidgets('previewSellerIntegrationLightWeb', (tester) async {
      await tester.pumpWidget(p25.previewSellerIntegrationLightWeb());
      await tester.pump();
    });
  });

  group('Previews in reset_password_screen_preview.dart', () {
    testWidgets('previewResetPasswordScreenMobile', (tester) async {
      await tester.pumpWidget(p26.previewResetPasswordScreenMobile());
      await tester.pump();
    });
    testWidgets('previewResetPasswordScreenTablet', (tester) async {
      await tester.pumpWidget(p26.previewResetPasswordScreenTablet());
      await tester.pump();
    });
    testWidgets('previewResetPasswordScreenDesktop', (tester) async {
      await tester.pumpWidget(p26.previewResetPasswordScreenDesktop());
      await tester.pump();
    });
    testWidgets('previewResetPasswordScreenWeb', (tester) async {
      await tester.pumpWidget(p26.previewResetPasswordScreenWeb());
      await tester.pump();
    });
    testWidgets('previewResetPasswordScreenLightMobile', (tester) async {
      await tester.pumpWidget(p26.previewResetPasswordScreenLightMobile());
      await tester.pump();
    });
    testWidgets('previewResetPasswordScreenLightTablet', (tester) async {
      await tester.pumpWidget(p26.previewResetPasswordScreenLightTablet());
      await tester.pump();
    });
    testWidgets('previewResetPasswordScreenLightDesktop', (tester) async {
      await tester.pumpWidget(p26.previewResetPasswordScreenLightDesktop());
      await tester.pump();
    });
    testWidgets('previewResetPasswordScreenLightWeb', (tester) async {
      await tester.pumpWidget(p26.previewResetPasswordScreenLightWeb());
      await tester.pump();
    });
  });

  group('Previews in payment_screens_preview.dart', () {
    testWidgets('previewPaymentCanceledScreenMobile', (tester) async {
      await tester.pumpWidget(p27.previewPaymentCanceledScreenMobile());
      await tester.pump();
    });
    testWidgets('previewPaymentCanceledScreenTablet', (tester) async {
      await tester.pumpWidget(p27.previewPaymentCanceledScreenTablet());
      await tester.pump();
    });
    testWidgets('previewPaymentCanceledScreenDesktop', (tester) async {
      await tester.pumpWidget(p27.previewPaymentCanceledScreenDesktop());
      await tester.pump();
    });
    testWidgets('previewPaymentCanceledScreenWeb', (tester) async {
      await tester.pumpWidget(p27.previewPaymentCanceledScreenWeb());
      await tester.pump();
    });
    testWidgets('previewPaymentCanceledLightMobile', (tester) async {
      await tester.pumpWidget(p27.previewPaymentCanceledLightMobile());
      await tester.pump();
    });
    testWidgets('previewPaymentCanceledLightTablet', (tester) async {
      await tester.pumpWidget(p27.previewPaymentCanceledLightTablet());
      await tester.pump();
    });
    testWidgets('previewPaymentCanceledLightDesktop', (tester) async {
      await tester.pumpWidget(p27.previewPaymentCanceledLightDesktop());
      await tester.pump();
    });
    testWidgets('previewPaymentCanceledLightWeb', (tester) async {
      await tester.pumpWidget(p27.previewPaymentCanceledLightWeb());
      await tester.pump();
    });
  });

  group('Previews in login_screen_preview.dart', () {
    testWidgets('previewLoginScreenMobile', (tester) async {
      await tester.pumpWidget(p28.previewLoginScreenMobile());
      await tester.pump();
    });
    testWidgets('previewLoginScreenTablet', (tester) async {
      await tester.pumpWidget(p28.previewLoginScreenTablet());
      await tester.pump();
    });
    testWidgets('previewLoginScreenDesktop', (tester) async {
      await tester.pumpWidget(p28.previewLoginScreenDesktop());
      await tester.pump();
    });
    testWidgets('previewLoginScreenWeb', (tester) async {
      await tester.pumpWidget(p28.previewLoginScreenWeb());
      await tester.pump();
    });
    testWidgets('previewLoginLightMobile', (tester) async {
      await tester.pumpWidget(p28.previewLoginLightMobile());
      await tester.pump();
    });
    testWidgets('previewLoginLightTablet', (tester) async {
      await tester.pumpWidget(p28.previewLoginLightTablet());
      await tester.pump();
    });
    testWidgets('previewLoginLightDesktop', (tester) async {
      await tester.pumpWidget(p28.previewLoginLightDesktop());
      await tester.pump();
    });
    testWidgets('previewLoginLightWeb', (tester) async {
      await tester.pumpWidget(p28.previewLoginLightWeb());
      await tester.pump();
    });
    testWidgets('previewRegisterScreenMobile', (tester) async {
      await tester.pumpWidget(p28.previewRegisterScreenMobile());
      await tester.pump();
    });
    testWidgets('previewRegisterScreenTablet', (tester) async {
      await tester.pumpWidget(p28.previewRegisterScreenTablet());
      await tester.pump();
    });
    testWidgets('previewRegisterScreenDesktop', (tester) async {
      await tester.pumpWidget(p28.previewRegisterScreenDesktop());
      await tester.pump();
    });
    testWidgets('previewRegisterScreenWeb', (tester) async {
      await tester.pumpWidget(p28.previewRegisterScreenWeb());
      await tester.pump();
    });
    testWidgets('previewRegisterLightMobile', (tester) async {
      await tester.pumpWidget(p28.previewRegisterLightMobile());
      await tester.pump();
    });
    testWidgets('previewRegisterLightTablet', (tester) async {
      await tester.pumpWidget(p28.previewRegisterLightTablet());
      await tester.pump();
    });
    testWidgets('previewRegisterLightDesktop', (tester) async {
      await tester.pumpWidget(p28.previewRegisterLightDesktop());
      await tester.pump();
    });
    testWidgets('previewRegisterLightWeb', (tester) async {
      await tester.pumpWidget(p28.previewRegisterLightWeb());
      await tester.pump();
    });
  });

  group('Previews in editproduct_screen_preview.dart', () {
    testWidgets('previewEditProductScreenMobile', (tester) async {
      await tester.pumpWidget(p29.previewEditProductScreenMobile());
      await tester.pump();
    });
    testWidgets('previewEditProductScreenTablet', (tester) async {
      await tester.pumpWidget(p29.previewEditProductScreenTablet());
      await tester.pump();
    });
    testWidgets('previewEditProductScreenDesktop', (tester) async {
      await tester.pumpWidget(p29.previewEditProductScreenDesktop());
      await tester.pump();
    });
    testWidgets('previewEditProductScreenWeb', (tester) async {
      await tester.pumpWidget(p29.previewEditProductScreenWeb());
      await tester.pump();
    });
    testWidgets('previewEditProductScreenLightMobile', (tester) async {
      await tester.pumpWidget(p29.previewEditProductScreenLightMobile());
      await tester.pump();
    });
    testWidgets('previewEditProductScreenLightTablet', (tester) async {
      await tester.pumpWidget(p29.previewEditProductScreenLightTablet());
      await tester.pump();
    });
    testWidgets('previewEditProductScreenLightDesktop', (tester) async {
      await tester.pumpWidget(p29.previewEditProductScreenLightDesktop());
      await tester.pump();
    });
    testWidgets('previewEditProductScreenLightWeb', (tester) async {
      await tester.pumpWidget(p29.previewEditProductScreenLightWeb());
      await tester.pump();
    });
  });

  group('Previews in profile_screen_preview.dart', () {
    testWidgets('previewProfileScreenDarkMobile', (tester) async {
      await tester.pumpWidget(p30.previewProfileScreenDarkMobile());
      await tester.pump();
    });
    testWidgets('previewProfileScreenDarkTablet', (tester) async {
      await tester.pumpWidget(p30.previewProfileScreenDarkTablet());
      await tester.pump();
    });
    testWidgets('previewProfileScreenDarkDesktop', (tester) async {
      await tester.pumpWidget(p30.previewProfileScreenDarkDesktop());
      await tester.pump();
    });
    testWidgets('previewProfileScreenDarkWeb', (tester) async {
      await tester.pumpWidget(p30.previewProfileScreenDarkWeb());
      await tester.pump();
    });
    testWidgets('previewProfileScreenLightMobile', (tester) async {
      await tester.pumpWidget(p30.previewProfileScreenLightMobile());
      await tester.pump();
    });
    testWidgets('previewProfileScreenLightTablet', (tester) async {
      await tester.pumpWidget(p30.previewProfileScreenLightTablet());
      await tester.pump();
    });
    testWidgets('previewProfileScreenLightDesktop', (tester) async {
      await tester.pumpWidget(p30.previewProfileScreenLightDesktop());
      await tester.pump();
    });
    testWidgets('previewProfileScreenLightWeb', (tester) async {
      await tester.pumpWidget(p30.previewProfileScreenLightWeb());
      await tester.pump();
    });
    testWidgets('previewProfileLoggedOutMobile', (tester) async {
      await tester.pumpWidget(p30.previewProfileLoggedOutMobile());
      await tester.pump();
    });
    testWidgets('previewProfileLoggedOutTablet', (tester) async {
      await tester.pumpWidget(p30.previewProfileLoggedOutTablet());
      await tester.pump();
    });
    testWidgets('previewProfileLoggedOutDesktop', (tester) async {
      await tester.pumpWidget(p30.previewProfileLoggedOutDesktop());
      await tester.pump();
    });
    testWidgets('previewProfileLoggedOutWeb', (tester) async {
      await tester.pumpWidget(p30.previewProfileLoggedOutWeb());
      await tester.pump();
    });
    testWidgets('previewProfileLoggedOutLightMobile', (tester) async {
      await tester.pumpWidget(p30.previewProfileLoggedOutLightMobile());
      await tester.pump();
    });
    testWidgets('previewProfileLoggedOutLightDesktop', (tester) async {
      await tester.pumpWidget(p30.previewProfileLoggedOutLightDesktop());
      await tester.pump();
    });
    testWidgets('previewProfileLoadingMobile', (tester) async {
      await tester.pumpWidget(p30.previewProfileLoadingMobile());
      await tester.pump();
    });
    testWidgets('previewProfileLoadingDesktop', (tester) async {
      await tester.pumpWidget(p30.previewProfileLoadingDesktop());
      await tester.pump();
    });
  });

  group('Previews in seller_products_screen_preview.dart', () {
    testWidgets('previewSellerProductsScreenMobile', (tester) async {
      await tester.pumpWidget(p31.previewSellerProductsScreenMobile());
      await tester.pump();
    });
    testWidgets('previewSellerProductsScreenTablet', (tester) async {
      await tester.pumpWidget(p31.previewSellerProductsScreenTablet());
      await tester.pump();
    });
    testWidgets('previewSellerProductsScreenDesktop', (tester) async {
      await tester.pumpWidget(p31.previewSellerProductsScreenDesktop());
      await tester.pump();
    });
    testWidgets('previewSellerProductsScreenWeb', (tester) async {
      await tester.pumpWidget(p31.previewSellerProductsScreenWeb());
      await tester.pump();
    });
    testWidgets('previewSellerProductsLightMobile', (tester) async {
      await tester.pumpWidget(p31.previewSellerProductsLightMobile());
      await tester.pump();
    });
    testWidgets('previewSellerProductsLightTablet', (tester) async {
      await tester.pumpWidget(p31.previewSellerProductsLightTablet());
      await tester.pump();
    });
    testWidgets('previewSellerProductsLightDesktop', (tester) async {
      await tester.pumpWidget(p31.previewSellerProductsLightDesktop());
      await tester.pump();
    });
    testWidgets('previewSellerProductsLightWeb', (tester) async {
      await tester.pumpWidget(p31.previewSellerProductsLightWeb());
      await tester.pump();
    });
  });

  group('Previews in product_card_screen_preview.dart', () {
    testWidgets('previewProductCardScreenMobile', (tester) async {
      await tester.pumpWidget(p32.previewProductCardScreenMobile());
      await tester.pump();
    });
    testWidgets('previewProductCardScreenTablet', (tester) async {
      await tester.pumpWidget(p32.previewProductCardScreenTablet());
      await tester.pump();
    });
    testWidgets('previewProductCardScreenDesktop', (tester) async {
      await tester.pumpWidget(p32.previewProductCardScreenDesktop());
      await tester.pump();
    });
    testWidgets('previewProductCardScreenWeb', (tester) async {
      await tester.pumpWidget(p32.previewProductCardScreenWeb());
      await tester.pump();
    });
    testWidgets('previewProductCardScreenLightMobile', (tester) async {
      await tester.pumpWidget(p32.previewProductCardScreenLightMobile());
      await tester.pump();
    });
    testWidgets('previewProductCardScreenLightTablet', (tester) async {
      await tester.pumpWidget(p32.previewProductCardScreenLightTablet());
      await tester.pump();
    });
    testWidgets('previewProductCardScreenLightDesktop', (tester) async {
      await tester.pumpWidget(p32.previewProductCardScreenLightDesktop());
      await tester.pump();
    });
    testWidgets('previewProductCardScreenLightWeb', (tester) async {
      await tester.pumpWidget(p32.previewProductCardScreenLightWeb());
      await tester.pump();
    });
  });

  group('Previews in productdetails_screen_preview.dart', () {
    testWidgets('previewProductDetailScreenMobile', (tester) async {
      await tester.pumpWidget(p33.previewProductDetailScreenMobile());
      await tester.pump();
    });
    testWidgets('previewProductDetailScreenTablet', (tester) async {
      await tester.pumpWidget(p33.previewProductDetailScreenTablet());
      await tester.pump();
    });
    testWidgets('previewProductDetailScreenDesktop', (tester) async {
      await tester.pumpWidget(p33.previewProductDetailScreenDesktop());
      await tester.pump();
    });
    testWidgets('previewProductDetailScreenWeb', (tester) async {
      await tester.pumpWidget(p33.previewProductDetailScreenWeb());
      await tester.pump();
    });
    testWidgets('previewProductDetailLightMobile', (tester) async {
      await tester.pumpWidget(p33.previewProductDetailLightMobile());
      await tester.pump();
    });
    testWidgets('previewProductDetailLightTablet', (tester) async {
      await tester.pumpWidget(p33.previewProductDetailLightTablet());
      await tester.pump();
    });
    testWidgets('previewProductDetailLightDesktop', (tester) async {
      await tester.pumpWidget(p33.previewProductDetailLightDesktop());
      await tester.pump();
    });
    testWidgets('previewProductDetailLightWeb', (tester) async {
      await tester.pumpWidget(p33.previewProductDetailLightWeb());
      await tester.pump();
    });
    testWidgets('previewProductDetailOosMobile', (tester) async {
      await tester.pumpWidget(p33.previewProductDetailOosMobile());
      await tester.pump();
    });
    testWidgets('previewProductDetailOosTablet', (tester) async {
      await tester.pumpWidget(p33.previewProductDetailOosTablet());
      await tester.pump();
    });
    testWidgets('previewProductDetailOosDesktop', (tester) async {
      await tester.pumpWidget(p33.previewProductDetailOosDesktop());
      await tester.pump();
    });
    testWidgets('previewProductDetailOosWeb', (tester) async {
      await tester.pumpWidget(p33.previewProductDetailOosWeb());
      await tester.pump();
    });
    testWidgets('previewProductDetailOosLightMobile', (tester) async {
      await tester.pumpWidget(p33.previewProductDetailOosLightMobile());
      await tester.pump();
    });
    testWidgets('previewProductDetailOosLightDesktop', (tester) async {
      await tester.pumpWidget(p33.previewProductDetailOosLightDesktop());
      await tester.pump();
    });
  });

  group('Previews in orders_screen_preview.dart', () {
    testWidgets('previewOrdersScreenMobile', (tester) async {
      await tester.pumpWidget(p34.previewOrdersScreenMobile());
      await tester.pump();
    });
    testWidgets('previewOrdersScreenTablet', (tester) async {
      await tester.pumpWidget(p34.previewOrdersScreenTablet());
      await tester.pump();
    });
    testWidgets('previewOrdersScreenDesktop', (tester) async {
      await tester.pumpWidget(p34.previewOrdersScreenDesktop());
      await tester.pump();
    });
    testWidgets('previewOrdersScreenWeb', (tester) async {
      await tester.pumpWidget(p34.previewOrdersScreenWeb());
      await tester.pump();
    });
    testWidgets('previewOrdersScreenLightMobile', (tester) async {
      await tester.pumpWidget(p34.previewOrdersScreenLightMobile());
      await tester.pump();
    });
    testWidgets('previewOrdersScreenLightTablet', (tester) async {
      await tester.pumpWidget(p34.previewOrdersScreenLightTablet());
      await tester.pump();
    });
    testWidgets('previewOrdersScreenLightDesktop', (tester) async {
      await tester.pumpWidget(p34.previewOrdersScreenLightDesktop());
      await tester.pump();
    });
    testWidgets('previewOrdersScreenLightWeb', (tester) async {
      await tester.pumpWidget(p34.previewOrdersScreenLightWeb());
      await tester.pump();
    });
    testWidgets('previewOrdersEmptyMobile', (tester) async {
      await tester.pumpWidget(p34.previewOrdersEmptyMobile());
      await tester.pump();
    });
    testWidgets('previewOrdersEmptyTablet', (tester) async {
      await tester.pumpWidget(p34.previewOrdersEmptyTablet());
      await tester.pump();
    });
    testWidgets('previewOrdersEmptyDesktop', (tester) async {
      await tester.pumpWidget(p34.previewOrdersEmptyDesktop());
      await tester.pump();
    });
    testWidgets('previewOrdersEmptyWeb', (tester) async {
      await tester.pumpWidget(p34.previewOrdersEmptyWeb());
      await tester.pump();
    });
    testWidgets('previewOrdersEmptyLightMobile', (tester) async {
      await tester.pumpWidget(p34.previewOrdersEmptyLightMobile());
      await tester.pump();
    });
    testWidgets('previewOrdersEmptyLightTablet', (tester) async {
      await tester.pumpWidget(p34.previewOrdersEmptyLightTablet());
      await tester.pump();
    });
    testWidgets('previewOrdersEmptyLightDesktop', (tester) async {
      await tester.pumpWidget(p34.previewOrdersEmptyLightDesktop());
      await tester.pump();
    });
    testWidgets('previewOrdersEmptyLightWeb', (tester) async {
      await tester.pumpWidget(p34.previewOrdersEmptyLightWeb());
      await tester.pump();
    });
    testWidgets('previewOrdersLoadingMobile', (tester) async {
      await tester.pumpWidget(p34.previewOrdersLoadingMobile());
      await tester.pump();
    });
    testWidgets('previewOrdersLoadingDesktop', (tester) async {
      await tester.pumpWidget(p34.previewOrdersLoadingDesktop());
      await tester.pump();
    });
  });

  group('Previews in terms_of_service_screen_preview.dart', () {
    testWidgets('previewTermsOfServiceScreenMobile', (tester) async {
      await tester.pumpWidget(p35.previewTermsOfServiceScreenMobile());
      await tester.pump();
    });
    testWidgets('previewTermsOfServiceScreenTablet', (tester) async {
      await tester.pumpWidget(p35.previewTermsOfServiceScreenTablet());
      await tester.pump();
    });
    testWidgets('previewTermsOfServiceScreenDesktop', (tester) async {
      await tester.pumpWidget(p35.previewTermsOfServiceScreenDesktop());
      await tester.pump();
    });
    testWidgets('previewTermsOfServiceScreenWeb', (tester) async {
      await tester.pumpWidget(p35.previewTermsOfServiceScreenWeb());
      await tester.pump();
    });
    testWidgets('previewTermsOfServiceLightMobile', (tester) async {
      await tester.pumpWidget(p35.previewTermsOfServiceLightMobile());
      await tester.pump();
    });
    testWidgets('previewTermsOfServiceLightTablet', (tester) async {
      await tester.pumpWidget(p35.previewTermsOfServiceLightTablet());
      await tester.pump();
    });
    testWidgets('previewTermsOfServiceLightDesktop', (tester) async {
      await tester.pumpWidget(p35.previewTermsOfServiceLightDesktop());
      await tester.pump();
    });
    testWidgets('previewTermsOfServiceLightWeb', (tester) async {
      await tester.pumpWidget(p35.previewTermsOfServiceLightWeb());
      await tester.pump();
    });
  });

  group('Previews in seller_registration_screen_preview.dart', () {
    testWidgets('previewSellerRegistrationScreenMobile', (tester) async {
      await tester.pumpWidget(p36.previewSellerRegistrationScreenMobile());
      await tester.pump();
    });
    testWidgets('previewSellerRegistrationScreenTablet', (tester) async {
      await tester.pumpWidget(p36.previewSellerRegistrationScreenTablet());
      await tester.pump();
    });
    testWidgets('previewSellerRegistrationScreenDesktop', (tester) async {
      await tester.pumpWidget(p36.previewSellerRegistrationScreenDesktop());
      await tester.pump();
    });
    testWidgets('previewSellerRegistrationScreenWeb', (tester) async {
      await tester.pumpWidget(p36.previewSellerRegistrationScreenWeb());
      await tester.pump();
    });
    testWidgets('previewSellerRegistrationLightMobile', (tester) async {
      await tester.pumpWidget(p36.previewSellerRegistrationLightMobile());
      await tester.pump();
    });
    testWidgets('previewSellerRegistrationLightTablet', (tester) async {
      await tester.pumpWidget(p36.previewSellerRegistrationLightTablet());
      await tester.pump();
    });
    testWidgets('previewSellerRegistrationLightDesktop', (tester) async {
      await tester.pumpWidget(p36.previewSellerRegistrationLightDesktop());
      await tester.pump();
    });
    testWidgets('previewSellerRegistrationLightWeb', (tester) async {
      await tester.pumpWidget(p36.previewSellerRegistrationLightWeb());
      await tester.pump();
    });
  });

  group('Previews in ordersuccess_screen_preview.dart', () {
    testWidgets('previewOrderSuccessScreenMobile', (tester) async {
      await tester.pumpWidget(p37.previewOrderSuccessScreenMobile());
      await tester.pump();
    });
    testWidgets('previewOrderSuccessScreenTablet', (tester) async {
      await tester.pumpWidget(p37.previewOrderSuccessScreenTablet());
      await tester.pump();
    });
    testWidgets('previewOrderSuccessScreenDesktop', (tester) async {
      await tester.pumpWidget(p37.previewOrderSuccessScreenDesktop());
      await tester.pump();
    });
    testWidgets('previewOrderSuccessScreenWeb', (tester) async {
      await tester.pumpWidget(p37.previewOrderSuccessScreenWeb());
      await tester.pump();
    });
    testWidgets('previewOrderSuccessScreenLightMobile', (tester) async {
      await tester.pumpWidget(p37.previewOrderSuccessScreenLightMobile());
      await tester.pump();
    });
    testWidgets('previewOrderSuccessScreenLightTablet', (tester) async {
      await tester.pumpWidget(p37.previewOrderSuccessScreenLightTablet());
      await tester.pump();
    });
    testWidgets('previewOrderSuccessScreenLightDesktop', (tester) async {
      await tester.pumpWidget(p37.previewOrderSuccessScreenLightDesktop());
      await tester.pump();
    });
    testWidgets('previewOrderSuccessScreenLightWeb', (tester) async {
      await tester.pumpWidget(p37.previewOrderSuccessScreenLightWeb());
      await tester.pump();
    });
  });

  group('Previews in seller_setup_screen_preview.dart', () {
    testWidgets('previewSellerSetupCompleteScreenMobile', (tester) async {
      await tester.pumpWidget(p38.previewSellerSetupCompleteScreenMobile());
      await tester.pump();
    });
    testWidgets('previewSellerSetupCompleteScreenTablet', (tester) async {
      await tester.pumpWidget(p38.previewSellerSetupCompleteScreenTablet());
      await tester.pump();
    });
    testWidgets('previewSellerSetupCompleteScreenDesktop', (tester) async {
      await tester.pumpWidget(p38.previewSellerSetupCompleteScreenDesktop());
      await tester.pump();
    });
    testWidgets('previewSellerSetupCompleteScreenWeb', (tester) async {
      await tester.pumpWidget(p38.previewSellerSetupCompleteScreenWeb());
      await tester.pump();
    });
    testWidgets('previewSellerSetupRefreshScreenMobile', (tester) async {
      await tester.pumpWidget(p38.previewSellerSetupRefreshScreenMobile());
      await tester.pump();
    });
    testWidgets('previewSellerSetupRefreshScreenTablet', (tester) async {
      await tester.pumpWidget(p38.previewSellerSetupRefreshScreenTablet());
      await tester.pump();
    });
    testWidgets('previewSellerSetupRefreshScreenDesktop', (tester) async {
      await tester.pumpWidget(p38.previewSellerSetupRefreshScreenDesktop());
      await tester.pump();
    });
    testWidgets('previewSellerSetupRefreshScreenWeb', (tester) async {
      await tester.pumpWidget(p38.previewSellerSetupRefreshScreenWeb());
      await tester.pump();
    });
  });

  group('Previews in rating_dialog_preview.dart', () {
    testWidgets('previewRatingDialogPremium', (tester) async {
      await tester.pumpWidget(p39.previewRatingDialogPremium());
      await tester.pump();
    });
    testWidgets('previewRatingDialogVariants', (tester) async {
      await tester.pumpWidget(p39.previewRatingDialogVariants());
      await tester.pump();
    });
    testWidgets('previewRatingDialogPremiumLight', (tester) async {
      await tester.pumpWidget(p39.previewRatingDialogPremiumLight());
      await tester.pump();
    });
    testWidgets('previewRatingDialogVariantsLight', (tester) async {
      await tester.pumpWidget(p39.previewRatingDialogVariantsLight());
      await tester.pump();
    });
  });

  group('Previews in rating_histogram_preview.dart', () {
    testWidgets('previewHistogramVariants', (tester) async {
      await tester.pumpWidget(p40.previewHistogramVariants());
      await tester.pump();
    });
    testWidgets('previewHistogramVariantsLight', (tester) async {
      await tester.pumpWidget(p40.previewHistogramVariantsLight());
      await tester.pump();
    });
  });

  group('Previews in design_tokens_preview.dart', () {
    testWidgets('previewColorPalette', (tester) async {
      await tester.pumpWidget(p41.previewColorPalette());
      await tester.pump();
    });
    testWidgets('previewGradient', (tester) async {
      await tester.pumpWidget(p41.previewGradient());
      await tester.pump();
    });
    testWidgets('previewTypography', (tester) async {
      await tester.pumpWidget(p41.previewTypography());
      await tester.pump();
    });
    testWidgets('previewSpacingRadius', (tester) async {
      await tester.pumpWidget(p41.previewSpacingRadius());
      await tester.pump();
    });
  });

  group('Previews in modern_textfield_preview.dart', () {
    testWidgets('previewTextFieldVariants', (tester) async {
      await tester.pumpWidget(p42.previewTextFieldVariants());
      await tester.pump();
    });
    testWidgets('previewTextFieldStates', (tester) async {
      await tester.pumpWidget(p42.previewTextFieldStates());
      await tester.pump();
    });
    testWidgets('previewTextFieldVariantsLight', (tester) async {
      await tester.pumpWidget(p42.previewTextFieldVariantsLight());
      await tester.pump();
    });
    testWidgets('previewTextFieldStatesLight', (tester) async {
      await tester.pumpWidget(p42.previewTextFieldStatesLight());
      await tester.pump();
    });
  });

  group('Previews in modern_appbar_preview.dart', () {
    testWidgets('previewAppBarVariants', (tester) async {
      await tester.pumpWidget(p43.previewAppBarVariants());
      await tester.pump();
    });
    testWidgets('previewBottomNavVariants', (tester) async {
      await tester.pumpWidget(p43.previewBottomNavVariants());
      await tester.pump();
    });
    testWidgets('previewAppBarVariantsLight', (tester) async {
      await tester.pumpWidget(p43.previewAppBarVariantsLight());
      await tester.pump();
    });
    testWidgets('previewBottomNavVariantsLight', (tester) async {
      await tester.pumpWidget(p43.previewBottomNavVariantsLight());
      await tester.pump();
    });
  });

  group('Previews in modern_card_preview.dart', () {
    testWidgets('previewCardComplex', (tester) async {
      await tester.pumpWidget(p44.previewCardComplex());
      await tester.pump();
    });
    testWidgets('previewCardVariants', (tester) async {
      await tester.pumpWidget(p44.previewCardVariants());
      await tester.pump();
    });
    testWidgets('previewCardComplexLight', (tester) async {
      await tester.pumpWidget(p44.previewCardComplexLight());
      await tester.pump();
    });
    testWidgets('previewCardVariantsLight', (tester) async {
      await tester.pumpWidget(p44.previewCardVariantsLight());
      await tester.pump();
    });
  });

  group('Previews in language_selector_preview.dart', () {
    testWidgets('previewLanguageVariants', (tester) async {
      await tester.pumpWidget(p45.previewLanguageVariants());
      await tester.pump();
    });
    testWidgets('previewLanguageVariantsLight', (tester) async {
      await tester.pumpWidget(p45.previewLanguageVariantsLight());
      await tester.pump();
    });
  });

  group('Previews in custom_app_bar_preview.dart', () {
    testWidgets('previewAppBarCart', (tester) async {
      await tester.pumpWidget(p46.previewAppBarCart());
      await tester.pump();
    });
    testWidgets('previewAppBarVariants', (tester) async {
      await tester.pumpWidget(p46.previewAppBarVariants());
      await tester.pump();
    });
    testWidgets('previewAppBarCartLight', (tester) async {
      await tester.pumpWidget(p46.previewAppBarCartLight());
      await tester.pump();
    });
    testWidgets('previewAppBarVariantsLight', (tester) async {
      await tester.pumpWidget(p46.previewAppBarVariantsLight());
      await tester.pump();
    });
  });

  group('Previews in modern_loading_indicator_preview.dart', () {
    testWidgets('previewLoadingInline', (tester) async {
      await tester.pumpWidget(p47.previewLoadingInline());
      await tester.pump();
    });
    testWidgets('previewLoadingVariants', (tester) async {
      await tester.pumpWidget(p47.previewLoadingVariants());
      await tester.pump();
    });
    testWidgets('previewLoadingInlineLight', (tester) async {
      await tester.pumpWidget(p47.previewLoadingInlineLight());
      await tester.pump();
    });
    testWidgets('previewLoadingVariantsLight', (tester) async {
      await tester.pumpWidget(p47.previewLoadingVariantsLight());
      await tester.pump();
    });
  });

  group('Previews in loading_preview.dart', () {
    testWidgets('previewLoadingDefault', (tester) async {
      await tester.pumpWidget(p48.previewLoadingDefault());
      await tester.pump();
    });
    testWidgets('previewLoadingSmall', (tester) async {
      await tester.pumpWidget(p48.previewLoadingSmall());
      await tester.pump();
    });
    testWidgets('previewLoadingFullScreen', (tester) async {
      await tester.pumpWidget(p48.previewLoadingFullScreen());
      await tester.pump();
    });
    testWidgets('previewLoadingInline', (tester) async {
      await tester.pumpWidget(p48.previewLoadingInline());
      await tester.pump();
    });
    testWidgets('previewLoadingAllSizes', (tester) async {
      await tester.pumpWidget(p48.previewLoadingAllSizes());
      await tester.pump();
    });
  });

  group('Previews in mascot_preview.dart', () {
    testWidgets('previewCanadianMooseDefault', (tester) async {
      await tester.pumpWidget(p49.previewCanadianMooseDefault());
      await tester.pump();
    });
    testWidgets('previewCanadianMooseLarge', (tester) async {
      await tester.pumpWidget(p49.previewCanadianMooseLarge());
      await tester.pump();
    });
    testWidgets('previewShopMascotDefault', (tester) async {
      await tester.pumpWidget(p49.previewShopMascotDefault());
      await tester.pump();
    });
    testWidgets('previewShopMascotLarge', (tester) async {
      await tester.pumpWidget(p49.previewShopMascotLarge());
      await tester.pump();
    });
  });

  group('Previews in modern_product_card_preview.dart', () {
    testWidgets('previewProductCardStates', (tester) async {
      await tester.pumpWidget(p50.previewProductCardStates());
      await tester.pump();
    });
    testWidgets('previewProductCardVariants', (tester) async {
      await tester.pumpWidget(p50.previewProductCardVariants());
      await tester.pump();
    });
    testWidgets('previewProductCardStatesLight', (tester) async {
      await tester.pumpWidget(p50.previewProductCardStatesLight());
      await tester.pump();
    });
    testWidgets('previewProductCardVariantsLight', (tester) async {
      await tester.pumpWidget(p50.previewProductCardVariantsLight());
      await tester.pump();
    });
  });

  group('Previews in order_status_preview.dart', () {
    testWidgets('previewAllStatusBadges', (tester) async {
      await tester.pumpWidget(p51.previewAllStatusBadges());
      await tester.pump();
    });
    testWidgets('previewAllStatusBadgesLight', (tester) async {
      await tester.pumpWidget(p51.previewAllStatusBadgesLight());
      await tester.pump();
    });
    testWidgets('previewEdgeCaseCards', (tester) async {
      await tester.pumpWidget(p51.previewEdgeCaseCards());
      await tester.pump();
    });
    testWidgets('previewEmptyOrders', (tester) async {
      await tester.pumpWidget(p51.previewEmptyOrders());
      await tester.pump();
    });
    testWidgets('previewEmptyOrdersFiltered', (tester) async {
      await tester.pumpWidget(p51.previewEmptyOrdersFiltered());
      await tester.pump();
    });
    testWidgets('previewOrderSummaryCards', (tester) async {
      await tester.pumpWidget(p51.previewOrderSummaryCards());
      await tester.pump();
    });
    testWidgets('previewOrderTimeline', (tester) async {
      await tester.pumpWidget(p51.previewOrderTimeline());
      await tester.pump();
    });
    testWidgets('previewOrderTimelineComplete', (tester) async {
      await tester.pumpWidget(p51.previewOrderTimelineComplete());
      await tester.pump();
    });
    testWidgets('previewStatusColorReference', (tester) async {
      await tester.pumpWidget(p51.previewStatusColorReference());
      await tester.pump();
    });
  });

  group('Previews in premium_paywall_preview.dart', () {
    testWidgets('previewPaywallResponsive', (tester) async {
      await tester.pumpWidget(p52.previewPaywallResponsive());
      await tester.pump();
    });
    testWidgets('previewPaywallVariants', (tester) async {
      await tester.pumpWidget(p52.previewPaywallVariants());
      await tester.pump();
    });
    testWidgets('previewPaywallResponsiveLight', (tester) async {
      await tester.pumpWidget(p52.previewPaywallResponsiveLight());
      await tester.pump();
    });
    testWidgets('previewPaywallVariantsLight', (tester) async {
      await tester.pumpWidget(p52.previewPaywallVariantsLight());
      await tester.pump();
    });
  });

  group('Previews in buttons_preview.dart', () {
    testWidgets('previewPrimaryButtonDark', (tester) async {
      await tester.pumpWidget(p53.previewPrimaryButtonDark());
      await tester.pump();
    });
    testWidgets('previewPrimaryButtonLight', (tester) async {
      await tester.pumpWidget(p53.previewPrimaryButtonLight());
      await tester.pump();
    });
    testWidgets('previewButtonLoading', (tester) async {
      await tester.pumpWidget(p53.previewButtonLoading());
      await tester.pump();
    });
    testWidgets('previewButtonDisabled', (tester) async {
      await tester.pumpWidget(p53.previewButtonDisabled());
      await tester.pump();
    });
    testWidgets('previewButtonOutlined', (tester) async {
      await tester.pumpWidget(p53.previewButtonOutlined());
      await tester.pump();
    });
    testWidgets('previewButtonWithIcon', (tester) async {
      await tester.pumpWidget(p53.previewButtonWithIcon());
      await tester.pump();
    });
    testWidgets('previewButtonSecondary', (tester) async {
      await tester.pumpWidget(p53.previewButtonSecondary());
      await tester.pump();
    });
    testWidgets('previewButtonAllStates', (tester) async {
      await tester.pumpWidget(p53.previewButtonAllStates());
      await tester.pump();
    });
  });

  group('Previews in app_bar_preview.dart', () {
    testWidgets('previewAppBarStandard', (tester) async {
      await tester.pumpWidget(p54.previewAppBarStandard());
      await tester.pump();
    });
    testWidgets('previewAppBarWithSubtitle', (tester) async {
      await tester.pumpWidget(p54.previewAppBarWithSubtitle());
      await tester.pump();
    });
    testWidgets('previewAppBarWithActions', (tester) async {
      await tester.pumpWidget(p54.previewAppBarWithActions());
      await tester.pump();
    });
    testWidgets('previewAppBarMain', (tester) async {
      await tester.pumpWidget(p54.previewAppBarMain());
      await tester.pump();
    });
    testWidgets('previewAppBarLight', (tester) async {
      await tester.pumpWidget(p54.previewAppBarLight());
      await tester.pump();
    });
    testWidgets('previewAppBarAllVariants', (tester) async {
      await tester.pumpWidget(p54.previewAppBarAllVariants());
      await tester.pump();
    });
  });

  group('Previews in modern_button_preview.dart', () {
    testWidgets('previewButtonStates', (tester) async {
      await tester.pumpWidget(p55.previewButtonStates());
      await tester.pump();
    });
    testWidgets('previewButtonTypes', (tester) async {
      await tester.pumpWidget(p55.previewButtonTypes());
      await tester.pump();
    });
    testWidgets('previewButtonStatesLight', (tester) async {
      await tester.pumpWidget(p55.previewButtonStatesLight());
      await tester.pump();
    });
    testWidgets('previewButtonTypesLight', (tester) async {
      await tester.pumpWidget(p55.previewButtonTypesLight());
      await tester.pump();
    });
  });

  group('Previews in rating_preview.dart', () {
    testWidgets('previewRatingPerfect', (tester) async {
      await tester.pumpWidget(p56.previewRatingPerfect());
      await tester.pump();
    });
    testWidgets('previewRatingMixed', (tester) async {
      await tester.pumpWidget(p56.previewRatingMixed());
      await tester.pump();
    });
    testWidgets('previewRatingLow', (tester) async {
      await tester.pumpWidget(p56.previewRatingLow());
      await tester.pump();
    });
    testWidgets('previewRatingEmpty', (tester) async {
      await tester.pumpWidget(p56.previewRatingEmpty());
      await tester.pump();
    });
    testWidgets('previewRatingMixedLight', (tester) async {
      await tester.pumpWidget(p56.previewRatingMixedLight());
      await tester.pump();
    });
    testWidgets('previewRatingAllVariants', (tester) async {
      await tester.pumpWidget(p56.previewRatingAllVariants());
      await tester.pump();
    });
  });

  group('Previews in animations_preview.dart', () {
    testWidgets('previewAnimations', (tester) async {
      await tester.pumpWidget(p57.previewAnimations());
      await tester.pump();
    });
    testWidgets('previewEmptyStates', (tester) async {
      await tester.pumpWidget(p57.previewEmptyStates());
      await tester.pump();
    });
    testWidgets('previewAnimationsLight', (tester) async {
      await tester.pumpWidget(p57.previewAnimationsLight());
      await tester.pump();
    });
    testWidgets('previewEmptyStatesLight', (tester) async {
      await tester.pumpWidget(p57.previewEmptyStatesLight());
      await tester.pump();
    });
  });

  group('Previews in standalone_promo_preview.dart', () {
    testWidgets('previewPromoBannerDark', (tester) async {
      await tester.pumpWidget(p58.previewPromoBannerDark());
      await tester.pump();
    });
    testWidgets('previewPromoBannerLight', (tester) async {
      await tester.pumpWidget(p58.previewPromoBannerLight());
      await tester.pump();
    });
  });

  group('Previews in cards_preview.dart', () {
    testWidgets('previewCardBasic', (tester) async {
      await tester.pumpWidget(p59.previewCardBasic());
      await tester.pump();
    });
    testWidgets('previewCardStats', (tester) async {
      await tester.pumpWidget(p59.previewCardStats());
      await tester.pump();
    });
    testWidgets('previewCardWarning', (tester) async {
      await tester.pumpWidget(p59.previewCardWarning());
      await tester.pump();
    });
    testWidgets('previewCardSuccess', (tester) async {
      await tester.pumpWidget(p59.previewCardSuccess());
      await tester.pump();
    });
    testWidgets('previewCardEmpty', (tester) async {
      await tester.pumpWidget(p59.previewCardEmpty());
      await tester.pump();
    });
    testWidgets('previewCardLight', (tester) async {
      await tester.pumpWidget(p59.previewCardLight());
      await tester.pump();
    });
  });

  group('Previews in order_widgets_preview.dart', () {
    testWidgets('previewOrderBanners', (tester) async {
      await tester.pumpWidget(p60.previewOrderBanners());
      await tester.pump();
    });
    testWidgets('previewOrderTimelines', (tester) async {
      await tester.pumpWidget(p60.previewOrderTimelines());
      await tester.pump();
    });
    testWidgets('previewOrderBannersLight', (tester) async {
      await tester.pumpWidget(p60.previewOrderBannersLight());
      await tester.pump();
    });
    testWidgets('previewOrderTimelinesLight', (tester) async {
      await tester.pumpWidget(p60.previewOrderTimelinesLight());
      await tester.pump();
    });
  });

  group('Previews in textfields_preview.dart', () {
    testWidgets('previewEmailField', (tester) async {
      await tester.pumpWidget(p61.previewEmailField());
      await tester.pump();
    });
    testWidgets('previewPasswordField', (tester) async {
      await tester.pumpWidget(p61.previewPasswordField());
      await tester.pump();
    });
    testWidgets('previewSearchField', (tester) async {
      await tester.pumpWidget(p61.previewSearchField());
      await tester.pump();
    });
    testWidgets('previewMultilineField', (tester) async {
      await tester.pumpWidget(p61.previewMultilineField());
      await tester.pump();
    });
    testWidgets('previewPriceField', (tester) async {
      await tester.pumpWidget(p61.previewPriceField());
      await tester.pump();
    });
    testWidgets('previewAllTextFields', (tester) async {
      await tester.pumpWidget(p61.previewAllTextFields());
      await tester.pump();
    });
    testWidgets('previewTextFieldLight', (tester) async {
      await tester.pumpWidget(p61.previewTextFieldLight());
      await tester.pump();
    });
  });

  group('Previews in product_card_preview.dart', () {
    testWidgets('previewProductCardStandard', (tester) async {
      await tester.pumpWidget(p62.previewProductCardStandard());
      await tester.pump();
    });
    testWidgets('previewProductCardStandardLight', (tester) async {
      await tester.pumpWidget(p62.previewProductCardStandardLight());
      await tester.pump();
    });
    testWidgets('previewProductCardTrendingHot', (tester) async {
      await tester.pumpWidget(p62.previewProductCardTrendingHot());
      await tester.pump();
    });
    testWidgets('previewProductCardTrendingRising', (tester) async {
      await tester.pumpWidget(p62.previewProductCardTrendingRising());
      await tester.pump();
    });
    testWidgets('previewProductCardOnSale', (tester) async {
      await tester.pumpWidget(p62.previewProductCardOnSale());
      await tester.pump();
    });
    testWidgets('previewProductCardOutOfStock', (tester) async {
      await tester.pumpWidget(p62.previewProductCardOutOfStock());
      await tester.pump();
    });
    testWidgets('previewProductCardNoReviews', (tester) async {
      await tester.pumpWidget(p62.previewProductCardNoReviews());
      await tester.pump();
    });
    testWidgets('previewProductCardMultiCountry', (tester) async {
      await tester.pumpWidget(p62.previewProductCardMultiCountry());
      await tester.pump();
    });
    testWidgets('previewProductCardAllVariants', (tester) async {
      await tester.pumpWidget(p62.previewProductCardAllVariants());
      await tester.pump();
    });
  });

  group('Previews in legal_screen_body_preview.dart', () {
    testWidgets('previewLegalResponsive', (tester) async {
      await tester.pumpWidget(p63.previewLegalResponsive());
      await tester.pump();
    });
    testWidgets('previewLegalVariants', (tester) async {
      await tester.pumpWidget(p63.previewLegalVariants());
      await tester.pump();
    });
    testWidgets('previewLegalResponsiveLight', (tester) async {
      await tester.pumpWidget(p63.previewLegalResponsiveLight());
      await tester.pump();
    });
    testWidgets('previewLegalVariantsLight', (tester) async {
      await tester.pumpWidget(p63.previewLegalVariantsLight());
      await tester.pump();
    });
  });

  group('Previews in env_preview_banner_preview.dart', () {
    testWidgets('previewEnvBanners', (tester) async {
      await tester.pumpWidget(p64.previewEnvBanners());
      await tester.pump();
    });
    testWidgets('previewEnvBannersLight', (tester) async {
      await tester.pumpWidget(p64.previewEnvBannersLight());
      await tester.pump();
    });
  });

}
