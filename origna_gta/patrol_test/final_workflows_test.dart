import 'package:flutter/material.dart';

import 'common.dart';

void main() {
  patrol('WF91: Admin — ban a user', ($) async {
    await createApp($);
    await ensureLoggedInAsAdmin($);
    await navigateToAdminPanel($);
    await $('Users').first.tap();
    await $.pump(const Duration(seconds: 3));

    final user = $('test@example.com');
    if (user.exists) {
      await user.first.tap();
      await $.pump(const Duration(seconds: 2));
      await $('Ban User').first.tap();
      await $.pump(const Duration(seconds: 2));
      await $('Confirm Ban').first.tap();
      await $.pump(const Duration(seconds: 2));
      expect($('Banned'), findsWidgets);
    }
    debugPrint('✅ WF91 completed');
  });

  patrol('WF92: Admin — view rate limit logs', ($) async {
    await createApp($);
    await ensureLoggedInAsAdmin($);
    await navigateToAdminPanel($);
    await $('Security').first.tap();
    await $.pump(const Duration(seconds: 3));
    await $('Rate Limits').first.tap();
    await $.pump(const Duration(seconds: 3));
    expect($('Rate Limit Events'), findsWidgets);
    debugPrint('✅ WF92 completed');
  });

  patrol('WF93: Admin — update platform config', ($) async {
    await createApp($);
    await ensureLoggedInAsAdmin($);
    await navigateToAdminPanel($);
    await $(Icons.settings_outlined).first.tap();
    await $.pump(const Duration(seconds: 3));

    await $('Maintenance Mode').first.tap();
    await $.pump(const Duration(seconds: 2));
    await $('Save Changes').first.tap();
    debugPrint('✅ WF93 completed');
  });

  patrol('WF94: Buyer — use multiple addresses', ($) async {
    await createApp($);
    await ensureLoggedInAsBuyer($);
    await navigateToProfile($);
    await $('Addresses').first.tap();
    await $.pump(const Duration(seconds: 3));

    // Already has one from WF70, add another
    await $('Add New Address').first.tap();
    await $.pump(const Duration(seconds: 2));
    await $(const Key('address_street_field')).enterText('456 Multi St');
    await $(const Key('address_city_field')).enterText('Montreal');
    await $('Save Address').first.tap();
    await $.pump(const Duration(seconds: 2));
    expect($('456 Multi St'), findsWidgets);
    debugPrint('✅ WF94 completed');
  });

  patrol('WF95: Buyer — delete an address', ($) async {
    await createApp($);
    await ensureLoggedInAsBuyer($);
    await navigateToProfile($);
    await $('Addresses').first.tap();
    await $.pump(const Duration(seconds: 3));

    final deleteIcon = $(Icons.delete_outline);
    if (deleteIcon.exists) {
      await deleteIcon.first.tap();
      await $.pump(const Duration(seconds: 2));
      await $('Confirm Delete').first.tap();
      await $.pump(const Duration(seconds: 2));
    }
    debugPrint('✅ WF95 completed');
  });

  patrol('WF96: Seller — configure shipping rates', ($) async {
    await createApp($);
    await ensureLoggedInAsSeller($);
    await navigateToProfile($);
    await $('Shipping Settings').first.tap();
    await $.pump(const Duration(seconds: 3));

    await $('Flat Rate').first.tap();
    await $(TextField).enterText('15.00');
    await $('Save').first.tap();
    await $.pump(const Duration(seconds: 2));
    debugPrint('✅ WF96 completed');
  });

  patrol('WF97: Seller — view inventory alerts', ($) async {
    await createApp($);
    await ensureLoggedInAsSeller($);
    await navigateToProfile($);
    await $('Inventory').first.tap();
    await $.pump(const Duration(seconds: 3));

    expect($('Low Stock'), findsWidgets);
    debugPrint('✅ WF97 completed');
  });

  patrol('WF98: Buyer — sort products by price', ($) async {
    await createApp($);
    await $('Sort').first.tap();
    await $.pump(const Duration(seconds: 2));
    await $('Price: High to Low').first.tap();
    await $.pump(const Duration(seconds: 3));
    debugPrint('✅ WF98 completed');
  });

  patrol('WF99: Buyer — filter products by category and price', ($) async {
    await createApp($);
    await $('Filter').first.tap();
    await $.pump(const Duration(seconds: 2));
    await $('Electronics').first.tap();
    await $.tester.drag($(RangeSlider).first, const Offset(100, 0));
    await $('Apply Filters').first.tap();
    await $.pump(const Duration(seconds: 3));
    debugPrint('✅ WF99 completed');
  });

  patrol('WF100: Admin — view active checkout sessions', ($) async {
    await createApp($);
    await ensureLoggedInAsAdmin($);
    await navigateToAdminPanel($);
    await $('Payments').first.tap();
    await $.pump(const Duration(seconds: 3));
    await $('Active Sessions').first.tap();
    await $.pump(const Duration(seconds: 3));
    expect($('Checkout Sessions'), findsWidgets);
    debugPrint('✅ WF100 completed');
  });
}
