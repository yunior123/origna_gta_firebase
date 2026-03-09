// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/widgets/promotions/standalone_promo_widget.dart';

@Preview(name: 'PromoBanner - Dark', group: 'Promotions')
Widget previewPromoBannerDark() => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData.dark(),
  home: const Scaffold(
    backgroundColor: Colors.black,
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: StandalonePromoWidget(
          title: 'Spring Clearance Event',
          subtitle: 'Save up to 50% on select items this weekend only.',
          discountText: '50% OFF',
          isDark: true,
        ),
      ),
    ),
  ),
);

@Preview(name: 'PromoBanner - Light', group: 'Promotions')
Widget previewPromoBannerLight() => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData.light(),
  home: const Scaffold(
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: StandalonePromoWidget(
          title: 'Spring Clearance Event',
          subtitle: 'Save up to 50% on select items this weekend only.',
          discountText: '50% OFF',
          isDark: false,
        ),
      ),
    ),
  ),
);
