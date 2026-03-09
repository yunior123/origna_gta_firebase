// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/features/subscription/subscription_provider.dart';
import 'package:origna_gta/features/subscription/subscription_state.dart';
import 'package:origna_gta/previews/_preview_theme.dart';
import 'package:origna_gta/widgets/rating_dialog.dart';

@Preview(name: 'Rating Dialog — Premium', group: 'RatingDialog')
Widget previewRatingDialogPremium() => previewScope(
  extraOverrides: [subscriptionStreamProvider.overrideWith((_) => Stream.value(const SubscriptionInfo(status: 'active', isPremium: true)))],
  child: previewGrid(
    children: [RatingDialog(orderId: 'preview-order-456', productId: 'preview-product-789', productName: 'Artisan Quebec Cheese Board')],
  ),
);

@Preview(name: 'Rating Dialog — Variants', group: 'RatingDialog')
Widget previewRatingDialogVariants() => previewScope(
  extraOverrides: [subscriptionStreamProvider.overrideWith((_) => Stream.value(const SubscriptionInfo(status: 'inactive', isPremium: false)))],
  child: previewGrid(
    children: [RatingDialog(orderId: 'preview-order-123', productId: 'preview-product-456', productName: 'Handmade Canadian Maple Syrup')],
  ),
);

@Preview(name: 'Rating Dialog Light — Premium', group: 'RatingDialog')
Widget previewRatingDialogPremiumLight() => previewScope(
  extraOverrides: [subscriptionStreamProvider.overrideWith((_) => Stream.value(const SubscriptionInfo(status: 'active', isPremium: true)))],
  child: previewGrid(
    theme: previewLightTheme,
    children: [RatingDialog(orderId: 'preview-order-456', productId: 'preview-product-789', productName: 'Artisan Quebec Cheese Board')],
  ),
);

@Preview(name: 'Rating Dialog Light — Variants', group: 'RatingDialog')
Widget previewRatingDialogVariantsLight() => previewScope(
  extraOverrides: [subscriptionStreamProvider.overrideWith((_) => Stream.value(const SubscriptionInfo(status: 'inactive', isPremium: false)))],
  child: previewGrid(
    theme: previewLightTheme,
    children: [RatingDialog(orderId: 'preview-order-123', productId: 'preview-product-456', productName: 'Handmade Canadian Maple Syrup')],
  ),
);
