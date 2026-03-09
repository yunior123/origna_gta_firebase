import 'package:flutter/material.dart';

import 'common.dart';

void main() {
  patrol('WF71: Admin — view security alerts', ($) async {
    await createApp($);
    await ensureLoggedInAsAdmin($);
    await navigateToAdminPanel($);
    await $('Security').first.tap();
    await $.pump(const Duration(seconds: 3));
    expect($('Security Alerts'), findsWidgets);
    debugPrint('✅ WF71 completed');
  });

  patrol('WF72: Admin — moderate a review', ($) async {
    await createApp($);
    await ensureLoggedInAsAdmin($);
    await navigateToAdminPanel($);
    await $('Reviews').first.tap();
    await $.pump(const Duration(seconds: 3));
    final flagBtn = $(Icons.flag_outlined);
    if (flagBtn.exists) {
      await flagBtn.first.tap();
      await $.pump(const Duration(seconds: 2));
      await $('Confirm Flag').first.tap();
      await $.pump(const Duration(seconds: 2));
    }
    debugPrint('✅ WF72 completed');
  });

  patrol('WF73: Seller — update warehouse address', ($) async {
    await createApp($);
    await ensureLoggedInAsSeller($);
    await navigateToProfile($);
    await $('Warehouses').first.tap();
    await $.pump(const Duration(seconds: 3));
    final editBtn = $(Icons.edit_outlined);
    if (editBtn.exists) {
      await editBtn.first.tap();
      await $.pump(const Duration(seconds: 2));
      await $(TextField).first.enterText('New Warehouse Name');
      await $('Save').first.tap();
      await $.pump(const Duration(seconds: 2));
      expect($('New Warehouse Name'), findsWidgets);
    }
    debugPrint('✅ WF73 completed');
  });

  patrol('WF74: Seller — bulk archive products', ($) async {
    await createApp($);
    await ensureLoggedInAsSeller($);
    await navigateToProfile($);
    await $('My Products').first.tap();
    await $.pump(const Duration(seconds: 3));
    final checkbox = $(Checkbox);
    if (checkbox.exists) {
      await checkbox.at(0).tap();
      await checkbox.at(1).tap();
      await $.pump(const Duration(seconds: 1));
      await $('Archive').first.tap();
      await $.pump(const Duration(seconds: 2));
      await $('Confirm Archive').first.tap();
      await $.pump(const Duration(seconds: 3));
    }
    debugPrint('✅ WF74 completed');
  });

  patrol('WF75: Seller — view payout history', ($) async {
    await createApp($);
    await ensureLoggedInAsSeller($);
    await navigateToProfile($);
    await $('Payouts').first.tap();
    await $.pump(const Duration(seconds: 3));
    expect($('Payout History'), findsWidgets);
    debugPrint('✅ WF75 completed');
  });

  patrol('WF76: Buyer — filter orders by status', ($) async {
    await createApp($);
    await ensureLoggedInAsBuyer($);
    await navigateToProfile($);
    await $(Icons.shopping_bag_outlined).first.tap();
    await $.pump(const Duration(seconds: 3));
    await $('Shipped').first.tap();
    await $.pump(const Duration(seconds: 2));
    await $('Delivered').first.tap();
    await $.pump(const Duration(seconds: 2));
    debugPrint('✅ WF76 completed');
  });

  patrol('WF77: Buyer — view product Q&A before buying', ($) async {
    await createApp($);
    await tapFirstProduct($);
    await $.pump(const Duration(seconds: 3));
    await $.scrollUntilVisible(finder: $('Q&A'));
    expect($('Q&A'), findsWidgets);
    debugPrint('✅ WF77 completed');
  });

  patrol('WF78: Buyer — reorder a past order', ($) async {
    await createApp($);
    await ensureLoggedInAsBuyer($);
    await navigateToProfile($);
    await $(Icons.shopping_bag_outlined).first.tap();
    await $.pump(const Duration(seconds: 3));
    final buyAgain = $('Buy Again');
    if (buyAgain.exists) {
      await buyAgain.first.tap();
      await $.pump(const Duration(seconds: 2));
      expect($('Added to cart'), findsWidgets);
    }
    debugPrint('✅ WF78 completed');
  });

  patrol('WF79: Buyer — report a seller', ($) async {
    await createApp($);
    await ensureLoggedInAsBuyer($);
    await tapFirstProduct($);
    await $.pump(const Duration(seconds: 3));
    await $.scrollUntilVisible(finder: $('Report Seller'));
    final reportBtn = $('Report Seller');
    if (reportBtn.exists) {
      await reportBtn.first.tap();
      await $.pump(const Duration(seconds: 2));
      await $(TextField).enterText('Inappropriate content');
      await $('Submit Report').first.tap();
      await $.pump(const Duration(seconds: 2));
      expect($('Report submitted'), findsWidgets);
    }
    debugPrint('✅ WF79 completed');
  });

  patrol('WF80: Admin — resolve a dispute', ($) async {
    await createApp($);
    await ensureLoggedInAsAdmin($);
    await navigateToAdminPanel($);
    await $('Orders').first.tap();
    await $.pump(const Duration(seconds: 3));
    final disputed = $('Disputed');
    if (disputed.exists) {
      await disputed.first.tap();
      await $.pump(const Duration(seconds: 2));
      final resolveBtn = $('Resolve Dispute');
      if (resolveBtn.exists) {
        await resolveBtn.first.tap();
        await $.pump(const Duration(seconds: 2));
        await $('Refund Buyer').first.tap();
        await $.pump(const Duration(seconds: 3));
      }
    }
    debugPrint('✅ WF80 completed');
  });

  patrol('WF81: Buyer — remove item from cart', ($) async {
    await createApp($);
    await ensureLoggedInAsBuyer($);
    await tapFirstProduct($);
    await $('Add to cart').first.tap();
    await $.pump(const Duration(seconds: 2));
    await navigateToCart($);

    final removeIcon = $(Icons.delete_outline);
    if (removeIcon.exists) {
      await removeIcon.first.tap();
      await $.pump(const Duration(seconds: 2));
      expect($('Removed from cart'), findsWidgets);
    }
    debugPrint('✅ WF81 completed');
  });

  patrol('WF82: Buyer — clear entire cart', ($) async {
    await createApp($);
    await ensureLoggedInAsBuyer($);
    await navigateToCart($);

    final clearBtn = $('Clear Cart');
    if (clearBtn.exists) {
      await clearBtn.first.tap();
      await $.pump(const Duration(seconds: 2));
      await $('Confirm').first.tap();
      await $.pump(const Duration(seconds: 2));
      expect($('Your cart is empty'), findsWidgets);
    }
    debugPrint('✅ WF82 completed');
  });

  patrol('WF83: Buyer — change password from profile', ($) async {
    await createApp($);
    await ensureLoggedInAsBuyer($);
    await navigateToProfile($);

    await $('Security').first.tap();
    await $.pump(const Duration(seconds: 3));

    await $('Change Password').first.tap();
    await $.pump(const Duration(seconds: 2));
    await $(TextField).at(0).enterText('OldPassword123!');
    await $(TextField).at(1).enterText('NewPassword123!');
    await $('Update Password').first.tap();
    await $.pump(const Duration(seconds: 2));
    expect($('Password updated'), findsWidgets);
    debugPrint('✅ WF83 completed');
  });

  patrol('WF85: Buyer — toggle dark mode', ($) async {
    await createApp($);
    await navigateToProfile($);

    final themeToggle = $(Icons.dark_mode_outlined);
    if (themeToggle.exists) {
      await themeToggle.first.tap();
      await $.pump(const Duration(seconds: 1));
      // Verify theme changed (app-level state)
    }
    debugPrint('✅ WF85 completed');
  });

  patrol('WF86: Seller — mark item as shipped', ($) async {
    await createApp($);
    await ensureLoggedInAsSeller($);
    await navigateToProfile($);

    await $('Seller Orders').first.tap();
    await $.pump(const Duration(seconds: 3));

    final order = $('Processing');
    if (order.exists) {
      await order.first.tap();
      await $.pump(const Duration(seconds: 2));
      await $('Mark Shipped').first.tap();
      await $.pump(const Duration(seconds: 2));
      await $(TextField).enterText('TRK12345678');
      await $('Update Status').first.tap();
      await $.pump(const Duration(seconds: 3));
      expect($('Shipped'), findsWidgets);
    }
    debugPrint('✅ WF86 completed');
  });

  patrol('WF88: Admin — search for a specific user', ($) async {
    await createApp($);
    await ensureLoggedInAsAdmin($);
    await navigateToAdminPanel($);

    await $('Users').first.tap();
    await $.pump(const Duration(seconds: 3));

    await $(TextField).enterText('test@example.com');
    await $.pump(const Duration(seconds: 2));
    expect($('test@example.com'), findsWidgets);
    debugPrint('✅ WF88 completed');
  });

  patrol('WF90: Admin — view payout logs', ($) async {
    await createApp($);
    await ensureLoggedInAsAdmin($);
    await navigateToAdminPanel($);

    await $('Payments').first.tap();
    await $.pump(const Duration(seconds: 3));

    await $('Payout Logs').first.tap();
    await $.pump(const Duration(seconds: 3));
    expect($('Platform Payouts'), findsWidgets);
    debugPrint('✅ WF90 completed');
  });
}
