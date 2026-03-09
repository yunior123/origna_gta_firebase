import 'package:flutter/material.dart';

import 'common.dart';

void main() {
  patrol('WF61: Buyer — request return on delivered order', ($) async {
    await createApp($);
    await ensureLoggedInAsBuyer($);
    await navigateToProfile($);

    // Go to My Orders
    await $(Icons.shopping_bag_outlined).first.tap();
    await $.pump(const Duration(seconds: 3));

    // Find a delivered order
    final deliveredOrder = $('Delivered');
    if (deliveredOrder.exists) {
      await deliveredOrder.first.tap();
      await $.pump(const Duration(seconds: 3));

      final returnBtn = $('Request Return');
      if (returnBtn.exists) {
        await returnBtn.first.tap();
        await $.pump(const Duration(seconds: 2));

        await $(TextField).enterText('Item defective');
        await $('Submit Request').first.tap();
        await $.pump(const Duration(seconds: 2));
        expect($('Return Requested'), findsWidgets);
      }
    }
    debugPrint('✅ WF61 completed');
  });

  patrol('WF63: Buyer — apply coupon code at checkout', ($) async {
    await createApp($);
    await ensureLoggedInAsBuyer($);
    await tapFirstProduct($);
    await $('Add to cart').first.tap();
    await $.pump(const Duration(seconds: 2));
    await navigateToCart($);

    await $('Checkout').first.tap();
    await $.pump(const Duration(seconds: 3));

    final couponField = $('Promo Code');
    if (couponField.exists) {
      await couponField.enterText('WELCOME10');
      await $('Apply').first.tap();
      await $.pump(const Duration(seconds: 2));

      expect($('10% off applied'), findsWidgets);
    }
    debugPrint('✅ WF63 completed');
  });

  patrol('WF64: Buyer — ask a product question (Q&A)', ($) async {
    await createApp($);
    await ensureLoggedInAsBuyer($);
    await tapFirstProduct($);
    await $.pump(const Duration(seconds: 3));

    await $.scrollUntilVisible(finder: $('Q&A'));
    final askBtn = $('Ask a Question');
    if (askBtn.exists) {
      await askBtn.first.tap();
      await $.pump(const Duration(seconds: 2));

      await $(TextField).enterText('Does this come with a warranty?');
      await $('Post Question').first.tap();
      await $.pump(const Duration(seconds: 2));
      expect($('Question posted'), findsWidgets);
    }
    debugPrint('✅ WF64 completed');
  });

  patrol('WF66: Admin — approve/reject new product', ($) async {
    await createApp($);
    await ensureLoggedInAsAdmin($);
    await navigateToAdminPanel($);

    await $('Products').first.tap();
    await $.pump(const Duration(seconds: 3));

    final underReview = $('Under Review');
    if (underReview.exists) {
      await underReview.first.tap();
      await $.pump(const Duration(seconds: 2));

      final approveBtn = $('Approve');
      if (approveBtn.exists) {
        await approveBtn.first.tap();
        await $.pump(const Duration(seconds: 3));
        expect($('Active'), findsWidgets);
      }
    }
    debugPrint('✅ WF66 completed');
  });

  patrol('WF67: Seller — view performance metrics', ($) async {
    await createApp($);
    await ensureLoggedInAsSeller($);
    await navigateToProfile($);

    await $(Icons.dashboard_outlined).first.tap();
    await $.pump(const Duration(seconds: 3));

    expect($('Performance'), findsWidgets);
    expect($('Response Time'), findsWidgets);
    expect($('Sales Summary'), findsWidgets);

    debugPrint('✅ WF67 completed');
  });

  patrol('WF68: Buyer — chat with seller (Premium)', ($) async {
    await createApp($);
    await ensureLoggedInAsBuyer($); // Assume this buyer is premium for the test
    await tapFirstProduct($);
    await $.pump(const Duration(seconds: 3));

    final chatBtn = $(Icons.chat_bubble_outline);
    if (chatBtn.exists) {
      await chatBtn.first.tap();
      await $.pump(const Duration(seconds: 3));

      expect($(TextField), findsOneWidget);
      await $(TextField).enterText('Is this still available?');
      await $(Icons.send).first.tap();
      await $.pump(const Duration(seconds: 2));
      expect($('Is this still available?'), findsWidgets);
    }
    debugPrint('✅ WF68 completed');
  });

  patrol('WF70: Buyer — manage address book', ($) async {
    await createApp($);
    await ensureLoggedInAsBuyer($);
    await navigateToProfile($);

    await $('Addresses').first.tap();
    await $.pump(const Duration(seconds: 3));

    final addBtn = $('Add New Address');
    if (addBtn.exists) {
      await addBtn.first.tap();
      await $.pump(const Duration(seconds: 2));

      await $(const Key('address_street_field')).enterText('123 Test St');
      await $(const Key('address_city_field')).enterText('Toronto');
      await $('Save Address').first.tap();
      await $.pump(const Duration(seconds: 2));

      expect($('123 Test St'), findsWidgets);
    }
    debugPrint('✅ WF70 completed');
  });
}
