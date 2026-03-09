// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:origna_gta/features/seller/warehouses_viewmodel.dart';
import 'package:origna_gta/models/generated/base_models.dart';
import 'package:origna_gta/models/generated/product_models.dart';
import 'package:origna_gta/screens/addproduct_screen.dart';

import '../_preview_theme.dart';

Widget _addProduct() => previewScope(
  extraOverrides: [
    sellerWarehousesStreamProvider.overrideWith(
      (ref) => Stream.value([
        SellerWarehouse(
          warehouseId: 'wh-preview',
          label: 'Toronto Warehouse',
          address: const Address(
            street: '123 King St W',
            city: 'Toronto',
            state: 'ON',
            postalCode: 'M5H 1A1',
          ),
          isDefault: true,
        ),
      ]),
    ),
  ],
  child: AddProductScreen(),
);

// ── Dark (default) ──────────────────────────────────────────────────────────
@Preview(name: 'Add Product — Mobile', group: 'Product Screens', size: Size(390, 844))
Widget previewAddProductScreenMobile() => previewMobile(child: _addProduct());

@Preview(name: 'Add Product — Tablet', group: 'Product Screens', size: Size(768, 1024))
Widget previewAddProductScreenTablet() => previewTablet(child: _addProduct());

@Preview(name: 'Add Product — Desktop', group: 'Product Screens', size: Size(1280, 800))
Widget previewAddProductScreenDesktop() => previewDesktop(child: _addProduct());

@Preview(name: 'Add Product — Web', group: 'Product Screens', size: Size(1440, 900))
Widget previewAddProductScreenWeb() => previewWeb(child: _addProduct());

// ── Light ────────────────────────────────────────────────────────────────────
@Preview(name: 'Add Product Light — Mobile', group: 'Product Screens', size: Size(390, 844))
Widget previewAddProductLightMobile() => previewMobile(theme: previewLightTheme, child: _addProduct());

@Preview(name: 'Add Product Light — Tablet', group: 'Product Screens', size: Size(768, 1024))
Widget previewAddProductLightTablet() => previewTablet(theme: previewLightTheme, child: _addProduct());

@Preview(name: 'Add Product Light — Desktop', group: 'Product Screens', size: Size(1280, 800))
Widget previewAddProductLightDesktop() => previewDesktop(theme: previewLightTheme, child: _addProduct());

@Preview(name: 'Add Product Light — Web', group: 'Product Screens', size: Size(1440, 900))
Widget previewAddProductLightWeb() => previewWeb(theme: previewLightTheme, child: _addProduct());
