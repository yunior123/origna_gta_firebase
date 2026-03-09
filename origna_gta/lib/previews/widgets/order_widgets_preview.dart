// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/previews/_preview_theme.dart';
import 'package:origna_gta/widgets/order_widgets.dart';

@Preview(name: 'Order Banners', group: 'OrderWidgets')
Widget previewOrderBanners() => previewGrid(
  children: [
    const PendingApprovalsBanner(count: 3),
    const Padding(padding: EdgeInsets.all(24), child: SellerPackageTimeline(currentStep: 1)),
  ],
);

@Preview(name: 'Order Timelines', group: 'OrderWidgets')
Widget previewOrderTimelines() => previewGrid(
  children: [
    const Padding(padding: EdgeInsets.all(24), child: OrderStatusTimeline(currentStep: 0)),
    const Padding(padding: EdgeInsets.all(24), child: OrderStatusTimeline(currentStep: 2)),
    const Padding(padding: EdgeInsets.all(24), child: OrderStatusTimeline(currentStep: 4)),
  ],
);

@Preview(name: 'Order Banners Light', group: 'OrderWidgets')
Widget previewOrderBannersLight() => previewGrid(
  theme: previewLightTheme,
  children: [
    const PendingApprovalsBanner(count: 3),
    const Padding(padding: EdgeInsets.all(24), child: SellerPackageTimeline(currentStep: 1)),
  ],
);

@Preview(name: 'Order Timelines Light', group: 'OrderWidgets')
Widget previewOrderTimelinesLight() => previewGrid(
  theme: previewLightTheme,
  children: [
    const Padding(padding: EdgeInsets.all(24), child: OrderStatusTimeline(currentStep: 0)),
    const Padding(padding: EdgeInsets.all(24), child: OrderStatusTimeline(currentStep: 2)),
    const Padding(padding: EdgeInsets.all(24), child: OrderStatusTimeline(currentStep: 4)),
  ],
);
