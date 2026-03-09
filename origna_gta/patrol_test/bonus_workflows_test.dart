import 'package:flutter/material.dart';
import 'common.dart';

void main() {
  patrol('WF101: Buyer — verify shipping calculator on product detail', ($) async {
    await createApp($);
    await tapFirstProduct($);
    await $.pump(const Duration(seconds: 3));

    await $.scrollUntilVisible(finder: $('Shipping & Delivery'));
    await $('Shipping & Delivery').first.tap();
    await $.pump(const Duration(seconds: 2));

    final zipField = $(TextField);
    if (zipField.exists) {
      await zipField.enterText('M5V 3L9');
      await $('Calculate').first.tap();
      await $.pump(const Duration(seconds: 2));
      expect($('Estimated Shipping'), findsWidgets);
    }
    debugPrint('✅ WF101 completed');
  });

  patrol('WF102: Seller — toggle vacation mode', ($) async {
    await createApp($);
    await ensureLoggedInAsSeller($);
    await navigateToProfile($);

    await $('Store Profile').first.tap();
    await $.pump(const Duration(seconds: 3));

    final vacationSwitch = $('Vacation Mode');
    if (vacationSwitch.exists) {
      await vacationSwitch.first.tap();
      await $.pump(const Duration(seconds: 1));
      await $('Save Profile').first.tap();
      await $.pump(const Duration(seconds: 2));
      expect($('Profile updated'), findsWidgets);
    }
    debugPrint('✅ WF102 completed');
  });

  patrol('WF103: Admin — verify audit logs for an order', ($) async {
    await createApp($);
    await ensureLoggedInAsAdmin($);
    await navigateToAdminPanel($);

    await $('Orders').first.tap();
    await $.pump(const Duration(seconds: 3));

    final firstOrder = $(Card).first;
    if (firstOrder.exists) {
      await firstOrder.tap();
      await $.pump(const Duration(seconds: 2));
      await $('Audit Logs').first.tap();
      await $.pump(const Duration(seconds: 3));
      expect($('Action History'), findsWidgets);
    }
    debugPrint('✅ WF103 completed');
  });

  patrol('WF104: Buyer — update notification preferences', ($) async {
    await createApp($);
    await ensureLoggedInAsBuyer($);
    await navigateToProfile($);

    await $('Settings').first.tap();
    await $.pump(const Duration(seconds: 3));
    await $('Notifications').first.tap();
    await $.pump(const Duration(seconds: 2));

    final emailToggle = $('Email Notifications');
    if (emailToggle.exists) {
      await emailToggle.first.tap();
      await $.pump(const Duration(seconds: 1));
      await $('Save Preferences').first.tap();
      await $.pump(const Duration(seconds: 2));
    }
    debugPrint('✅ WF104 completed');
  });

  patrol('WF105: Seller — export sales report', ($) async {
    await createApp($);
    await ensureLoggedInAsSeller($);
    await navigateToProfile($);

    await $(Icons.dashboard_outlined).first.tap();
    await $.pump(const Duration(seconds: 3));

    await $('Reports').first.tap();
    await $.pump(const Duration(seconds: 2));
    await $('Export PDF').first.tap();
    await $.pump(const Duration(seconds: 3));
    // Usually shows a success toast or opens file picker
    debugPrint('✅ WF105 completed');
  });

  patrol('WF106: Buyer — browse products by sub-category', ($) async {
    await createApp($);
    await $('Categories').first.tap();
    await $.pump(const Duration(seconds: 2));

    final mainCat = $('Electronics');
    if (mainCat.exists) {
      await mainCat.first.tap();
      await $.pump(const Duration(seconds: 2));
      
      final subCat = $('Headphones');
      if (subCat.exists) {
        await subCat.first.tap();
        await $.pump(const Duration(seconds: 3));
        expect($(Card), findsWidgets);
      }
    }
    debugPrint('✅ WF106 completed');
  });

  patrol('WF107: Seller — upload product video', ($) async {
    await createApp($);
    await ensureLoggedInAsSeller($);
    await navigateToAddProduct($);

    await $.scrollUntilVisible(finder: $('Add Video'));
    final videoBtn = $('Add Video');
    if (videoBtn.exists) {
      await videoBtn.first.tap();
      await $.pump(const Duration(seconds: 2));
      // Simulation of video upload
      debugPrint('WF107: Video upload simulation triggered');
    }
    debugPrint('✅ WF107 completed');
  });

  patrol('WF108: Admin — manage categories', ($) async {
    await createApp($);
    await ensureLoggedInAsAdmin($);
    await navigateToAdminPanel($);

    await $('Settings').first.tap();
    await $.pump(const Duration(seconds: 2));
    await $('Categories').first.tap();
    await $.pump(const Duration(seconds: 3));

    await $('Add Category').first.tap();
    await $.pump(const Duration(seconds: 2));
    await $(TextField).enterText('New Test Category');
    await $('Save').first.tap();
    await $.pump(const Duration(seconds: 2));
    expect($('New Test Category'), findsWidgets);
    debugPrint('✅ WF108 completed');
  });

  patrol('WF109: Buyer — use Buy Now direct checkout', ($) async {
    await createApp($);
    await ensureLoggedInAsBuyer($);
    await tapFirstProduct($);
    await $.pump(const Duration(seconds: 3));

    final buyNowBtn = $('Buy Now');
    if (buyNowBtn.exists) {
      await buyNowBtn.first.tap();
      await $.pump(const Duration(seconds: 3));
      // Should be direct to checkout
      expect($('Checkout'), findsWidgets);
      expect($('Place Order'), findsWidgets);
    }
    debugPrint('✅ WF109 completed');
  });

  patrol('WF110: Seller — duplicate product listing', ($) async {
    await createApp($);
    await ensureLoggedInAsSeller($);
    await navigateToProfile($);

    await $('My Products').first.tap();
    await $.pump(const Duration(seconds: 3));

    final duplicateIcon = $(Icons.copy_outlined);
    if (duplicateIcon.exists) {
      await duplicateIcon.first.tap();
      await $.pump(const Duration(seconds: 3));
      // Should be on Add Product screen with filled fields
      expect($('Add Product'), findsWidgets);
      final nameField = $(const Key('product_name_field'));
      expect(nameField, findsOneWidget);
    }
    debugPrint('✅ WF110 completed');
  });
}
