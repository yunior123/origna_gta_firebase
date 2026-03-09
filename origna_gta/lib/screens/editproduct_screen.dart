// coverage:ignore-file
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/models/generated/models.dart';
import 'package:origna_gta/screens/productaddimages_screen.dart';
import 'package:origna_gta/screens/productaddvideo_screen.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/utils/responsive_layout.dart';
import 'package:origna_gta/utils/utils.dart';
import 'package:origna_gta/widgets/custom_app_bar.dart';
import 'package:origna_gta/widgets/modern_loading_indicator.dart';

import '../../features/products/edit_product_state.dart';
import '../../features/products/edit_product_viewmodel.dart';

/// Documentation for EditProductScreen
class EditProductScreen extends ConsumerStatefulWidget {
  final Product product;

  const EditProductScreen({super.key, required this.product});

  @override
  ConsumerState<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditDigitalTypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _EditDigitalTypeChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? DesignTokens.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? DesignTokens.primary
                : DesignTokens.textSecondary.withValues(alpha: 0.3),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? DesignTokens.primary : null),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? DesignTokens.primary : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditProductScreenState extends ConsumerState<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _compareAtPriceController;
  late final TextEditingController _categoryController;
  late final TextEditingController _streetController;
  late final TextEditingController _apartmentController;
  late final TextEditingController _cityController;
  late final TextEditingController _postalCodeController;
  late final TextEditingController _stockController;
  late final TextEditingController _weightController;
  late final TextEditingController _lengthController;
  late final TextEditingController _widthController;
  late final TextEditingController _heightController;
  late final TextEditingController _shipDaysController;
  late final TextEditingController _minOrderController;
  late final TextEditingController _taxCodeController;

  // Inventory config
  bool _lowStockAlertEnabled = false;
  late final TextEditingController _lowStockThresholdController;

  // Bill 96: French translation controllers
  late final TextEditingController _nameFController;
  late final TextEditingController _descriptionFController;

  // Digital product controllers
  late final TextEditingController _macosUrlController;
  late final TextEditingController _windowsUrlController;
  late final TextEditingController _linuxUrlController;
  late final TextEditingController _bookUrlController;
  late final TextEditingController _deviceLimitController;

  // Delivery controllers
  late final TextEditingController _standardDaysController;
  late final TextEditingController _standardPriceController;
  late final TextEditingController _expressDaysController;
  late final TextEditingController _expressPriceController;
  late final TextEditingController _sameDayPriceController;

  static const Map<String, String> _provinceNames = ProvinceCodeValues.names;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editProductViewModelProvider(widget.product));
    final viewModel = ref.read(
      editProductViewModelProvider(widget.product).notifier,
    );

    // Listen for success or error
    ref.listen(editProductViewModelProvider(widget.product), (previous, next) {
      if (next.isSuccess) {
        _onUpdateSuccess();
      } else if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: DesignTokens.error,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBarFactory.simple(title: 'product.edit_product'.tr()),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildApprovalStatusBanner(),
                  _buildSectionTitle('product.basic_information'.tr()),
                  TextFormField(
                    key: const Key('product_edit_name_field'),
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'product.product_name'.tr(),
                      prefixIcon: const Icon(Icons.shopping_bag_outlined),
                    ),
                    validator: (value) => value?.isEmpty ?? true
                        ? 'product.please_enter_name'.tr()
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('product_edit_description_field'),
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'product.description'.tr(),
                      prefixIcon: const Icon(Icons.description_outlined),
                    ),
                    validator: (value) => value?.isEmpty ?? true
                        ? 'product.please_enter_description'.tr()
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _buildSectionTitle('product.french_section_title'.tr()),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: DesignTokens.canadaRed.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: DesignTokens.canadaRed.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: DesignTokens.canadaRed,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'product.french_section_subtitle'.tr(),
                            style: TextStyle(
                              fontSize: 12,
                              color: DesignTokens.canadaRed,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('product_edit_name_f_field'),
                    controller: _nameFController,
                    decoration: InputDecoration(
                      labelText: 'product.name_french'.tr(),
                      hintText: 'product.name_french_hint'.tr(),
                      prefixIcon: const Icon(Icons.sell_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('product_edit_description_f_field'),
                    controller: _descriptionFController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'product.description_french'.tr(),
                      hintText: 'product.description_french_hint'.tr(),
                      prefixIcon: const Icon(Icons.notes_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: const Key('product_edit_price_field'),
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'product.price'.tr(),
                            prefixIcon: const Icon(Icons.attach_money_outlined),
                          ),
                          validator: (value) => value?.isEmpty ?? true
                              ? 'product.please_enter_price'.tr()
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          key: const Key('product_edit_stock_field'),
                          controller: _stockController,
                          keyboardType: TextInputType.number,
                          enabled: !state.isSoldOut,
                          decoration: InputDecoration(
                            labelText: 'product.stock'.tr(),
                            prefixIcon: const Icon(Icons.inventory_2_outlined),
                            suffixText: state.isSoldOut
                                ? 'product.sold_out'.tr()
                                : null,
                          ),
                          validator: (value) =>
                              !state.isSoldOut &&
                                  (value == null || value.isEmpty)
                              ? 'product.enter_quantity'.tr()
                              : null,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  TextFormField(
                    key: const Key('product_edit_compare_at_price_field'),
                    controller: _compareAtPriceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'product.compare_at_price'.tr(),
                      prefixIcon: const Icon(Icons.local_offer_outlined),
                      hintText: 'product.compare_at_price_hint'.tr(),
                      helperText: 'product.compare_at_price_info_body'.tr(),
                      helperMaxLines: 3,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return null; // optional
                      final cap = double.tryParse(v);
                      if (cap == null) return 'product.invalid_price'.tr();
                      final currentPrice =
                          double.tryParse(_priceController.text.trim()) ?? 0;
                      if (cap <= currentPrice) {
                        return 'product.compare_at_price_must_be_higher'.tr();
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('product_edit_tax_code_field'),
                    controller: _taxCodeController,
                    decoration: InputDecoration(
                      labelText: 'product.tax_code_label'.tr(),
                      prefixIcon: const Icon(Icons.receipt_long_rounded),
                      hintText: 'product.tax_code_hint'.tr(),
                      helperText: 'product.stripe_tax_codes_body'.tr(),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty || isValidTaxCode(v)
                        ? null
                        : 'product.invalid_tax_code'.tr(),
                  ),
                  _buildTappableInfoHint(
                    'product.tax_code_learn_more'.tr(),
                    'product.stripe_tax_codes'.tr(),
                    'product.stripe_tax_codes_body'.tr(),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: Text('product.mark_sold_out'.tr()),
                    value: state.isSoldOut,
                    activeTrackColor: DesignTokens.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) {
                      viewModel.toggleSoldOut(v);
                      if (v) _stockController.text = '0';
                    },
                  ),
                  SwitchListTile(
                    key: const Key('editproduct_low_stock_alert_toggle'),
                    title: Text('product.low_stock_alert'.tr()),
                    subtitle: Text('product.low_stock_alert_subtitle'.tr()),
                    secondary: const Icon(Icons.notifications_active_rounded),
                    value: _lowStockAlertEnabled,
                    activeTrackColor: DesignTokens.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setState(() => _lowStockAlertEnabled = v),
                  ),
                  if (_lowStockAlertEnabled) ...[
                    const SizedBox(height: 4),
                    TextFormField(
                      key: const Key('editproduct_low_stock_threshold_field'),
                      controller: _lowStockThresholdController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'product.low_stock_threshold'.tr(),
                        prefixIcon: const Icon(Icons.warning_amber_rounded),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  SwitchListTile(
                    title: Text('product.digital_product'.tr()),
                    subtitle: Text('product.digital_subtitle'.tr()),
                    value: state.isDigital,
                    activeTrackColor: DesignTokens.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: viewModel.toggleDigital,
                  ),
                  if (state.isDigital) ...[
                    const SizedBox(height: 12),
                    _buildEditDigitalSection(state, viewModel),
                  ],
                  DropdownButtonFormField<String>(
                    key: const Key('product_edit_category_dropdown'),
                    menuMaxHeight: ResponsiveBreakpoints.dropdownMaxHeight(context),
                    initialValue: _categoryController.text.isNotEmpty
                        ? _categoryController.text
                        : null,
                    decoration: InputDecoration(
                      labelText: 'product.category'.tr(),
                      prefixIcon: const Icon(Icons.category_outlined),
                    ),
                    items: productCategories
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.categoryId.toString(),
                            child: Text(c.name.tr()),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _categoryController.text = v ?? ''),
                    validator: (v) =>
                        v == null ? 'product.select_category'.tr() : null,
                  ),
                  const SizedBox(height: 24),

                  if (!state.isDigital) ...[
                    _buildSectionTitle('product.shipping_delivery'.tr()),
                    SwitchListTile(
                      title: Text('product.local_delivery_only'.tr()),
                      subtitle: Text('product.restrict_50km'.tr()),
                      value: state.isLocalDeliveryOnly,
                      activeTrackColor: DesignTokens.primary,
                      contentPadding: EdgeInsets.zero,
                      onChanged: viewModel.toggleLocalDelivery,
                    ),
                    SwitchListTile(
                      title: Text('product.perishable_item'.tr()),
                      subtitle: Text('product.perishable_subtitle'.tr()),
                      value: state.isPerishable,
                      activeTrackColor: DesignTokens.primary,
                      contentPadding: EdgeInsets.zero,
                      onChanged: viewModel.togglePerishable,
                    ),
                    SwitchListTile(
                      key: const Key('editproduct_age_restricted_toggle'),
                      title: Text('product.age_restricted_item'.tr()),
                      value: state.isAgeRestricted,
                      activeTrackColor: DesignTokens.primary,
                      contentPadding: EdgeInsets.zero,
                      onChanged: viewModel.toggleAgeRestricted,
                    ),
                    if (!state.isLocalDeliveryOnly) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _weightController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: 'product.weight'.tr(),
                                prefixIcon: const Icon(Icons.scale_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _shipDaysController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'product.ship_days'.tr(),
                                prefixIcon: const Icon(Icons.schedule_outlined),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _lengthController,
                              decoration: InputDecoration(
                                labelText: 'product.length_cm'.tr(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _widthController,
                              decoration: InputDecoration(
                                labelText: 'product.width_cm'.tr(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _heightController,
                              decoration: InputDecoration(
                                labelText: 'product.height_cm'.tr(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _minOrderController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'product.min_order_qty'.tr(),
                                prefixIcon: const Icon(
                                  Icons.format_list_numbered,
                                ),
                              ),
                              validator: (value) => value?.isEmpty ?? true
                                  ? 'common.required'.tr()
                                  : null,
                              onChanged: (v) =>
                                  viewModel.setMinimumOrderQuantity(
                                    int.tryParse(v) ?? 1,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text('product.free_shipping'.tr()),
                              value: state.freeShipping,
                              activeTrackColor: DesignTokens.primary,
                              onChanged: viewModel.toggleFreeShipping,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    _buildDeliveryOptions(state, viewModel),
                    const SizedBox(height: 24),
                  ],

                  _buildSectionTitle('product.product_location'.tr()),
                  TextFormField(
                    controller: _streetController,
                    decoration: InputDecoration(
                      labelText: 'product.street_address'.tr(),
                      prefixIcon: const Icon(Icons.location_on_outlined),
                    ),
                    onChanged: viewModel.onStreetChanged,
                    validator: (v) =>
                        v?.isEmpty ?? true ? 'common.required'.tr() : null,
                  ),
                  if (state.showSuggestions &&
                      state.addressSuggestions.isNotEmpty)
                    _buildAddressSuggestions(state, viewModel),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _cityController,
                          decoration: InputDecoration(
                            labelText: 'product.city'.tr(),
                            prefixIcon: const Icon(
                              Icons.location_city_outlined,
                            ),
                          ),
                          validator: (v) => v?.isEmpty ?? true
                              ? 'common.required'.tr()
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          menuMaxHeight: ResponsiveBreakpoints.dropdownMaxHeight(context),
                          initialValue: state.selectedProvince,
                          decoration: InputDecoration(
                            labelText: 'product.province'.tr(),
                          ),
                          items: _provinceNames.entries
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(e.key),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => viewModel.setProvince(v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _postalCodeController,
                    decoration: InputDecoration(
                      labelText: 'product.postal_code'.tr(),
                      prefixIcon: const Icon(Icons.pin_outlined),
                    ),
                    validator: _validatePostalCode,
                  ),
                  const SizedBox(height: 24),

                  _buildSectionTitle('product.images'.tr()),
                  _buildImageGrid(state, viewModel),
                  const SizedBox(height: 12),
                  ProductAddImages(imageModels: state.newImages),
                  const SizedBox(height: 24),
                  _buildSectionTitle('product.product_video'.tr()),
                  ProductAddVideo(
                    videoFile: state.videoFile,
                    existingVideoUrl: state.existingVideoUrl,
                    onVideoAdded: (file, duration) =>
                        viewModel.setVideo(file, duration),
                    onVideoRemoved: () => viewModel.removeVideo(),
                  ),
                  const SizedBox(height: 32),
                  const SizedBox(height: 32),

                  Semantics(
                    button: true,
                    label: 'btn-save-product',
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        key: const Key('product_edit_save_button'),
                        onPressed: state.isLoading
                            ? null
                            : () => _handleSave(viewModel),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DesignTokens.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: state.isLoading
                            ? const ModernLoadingIndicator(
                                color: Colors.white,
                                centered: false,
                              )
                            : Text(
                                'product.save_changes'.tr(),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFController.dispose();
    _descriptionController.dispose();
    _descriptionFController.dispose();
    _priceController.dispose();
    _compareAtPriceController.dispose();
    _categoryController.dispose();
    _streetController.dispose();
    _apartmentController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _stockController.dispose();
    _weightController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _shipDaysController.dispose();
    _minOrderController.dispose();
    _taxCodeController.dispose();
    _lowStockThresholdController.dispose();
    _macosUrlController.dispose();
    _windowsUrlController.dispose();
    _linuxUrlController.dispose();
    _bookUrlController.dispose();
    _deviceLimitController.dispose();
    _standardDaysController.dispose();
    _standardPriceController.dispose();
    _expressDaysController.dispose();
    _expressPriceController.dispose();
    _sameDayPriceController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p.name);
    _nameFController = TextEditingController(text: p.nameF ?? '');
    _descriptionController = TextEditingController(text: p.description);
    _descriptionFController = TextEditingController(text: p.descriptionF ?? '');
    _priceController = TextEditingController(text: p.price.toString());
    _compareAtPriceController = TextEditingController(
      text: p.compareAtPrice?.toString() ?? '',
    );
    _categoryController = TextEditingController(text: p.categoryId.toString());
    _streetController = TextEditingController(
      text: p.sellerAddress?.street ?? '',
    );
    _apartmentController = TextEditingController(
      text: p.sellerAddress?.apartment ?? '',
    );
    _cityController = TextEditingController(
      text: p.sellerAddress?.city ?? p.shipFromCity ?? '',
    );
    _postalCodeController = TextEditingController(
      text: p.sellerAddress?.postalCode ?? '',
    );
    _stockController = TextEditingController(text: p.stockQuantity.toString());
    _weightController = TextEditingController(
      text: p.weightKg?.toString() ?? '',
    );
    _lengthController = TextEditingController(
      text: p.lengthCm?.toString() ?? '',
    );
    _widthController = TextEditingController(text: p.widthCm?.toString() ?? '');
    _heightController = TextEditingController(
      text: p.heightCm?.toString() ?? '',
    );
    _shipDaysController = TextEditingController(
      text: p.estimatedShipDays.toString(),
    );
    _minOrderController = TextEditingController(
      text: p.minimumOrderQuantity.toString(),
    );
    _taxCodeController = TextEditingController(text: p.taxCode ?? '');
    final existingThreshold = p.inventory?.lowStockThreshold ?? 0;
    _lowStockAlertEnabled = existingThreshold > 0;
    _lowStockThresholdController = TextEditingController(
      text: existingThreshold > 0 ? existingThreshold.toString() : '5',
    );
    _macosUrlController = TextEditingController(
      text: p.digitalBuilds?[DigitalPlatformValues.macos] ?? '',
    );
    _windowsUrlController = TextEditingController(
      text: p.digitalBuilds?[DigitalPlatformValues.windows] ?? '',
    );
    _linuxUrlController = TextEditingController(
      text: p.digitalBuilds?[DigitalPlatformValues.linux] ?? '',
    );
    _bookUrlController = TextEditingController(); // empty — server-side only
    _deviceLimitController = TextEditingController(
      text: p.deviceLimit?.toString() ?? '',
    );

    // Initialize delivery options
    final standardOpt = _findOption(
      p.deliveryOptions,
      'standard',
      SellerDeliveryOption(
        type: 'standard',
        description: 'product.standard_delivery'.tr(),
        costCents: 0,
        estimatedDays: 5,
      ),
    );
    final expressOpt = _findOption(
      p.deliveryOptions,
      'express',
      SellerDeliveryOption(
        type: 'express',
        description: 'product.express_delivery'.tr(),
        costCents: 999,
        estimatedDays: 2,
      ),
    );
    final sameDayOpt = _findOption(
      p.deliveryOptions,
      'same_day',
      SellerDeliveryOption(
        type: 'same_day',
        description: 'product.same_day_delivery'.tr(),
        costCents: 1499,
        estimatedDays: 0,
      ),
    );

    _standardDaysController = TextEditingController(
      text: standardOpt.estimatedDays.toString(),
    );
    _standardPriceController = TextEditingController(
      text: (standardOpt.costCents / 100.0).toStringAsFixed(2),
    );
    _expressDaysController = TextEditingController(
      text: expressOpt.estimatedDays.toString(),
    );
    _expressPriceController = TextEditingController(
      text: (expressOpt.costCents / 100.0).toStringAsFixed(2),
    );
    _sameDayPriceController = TextEditingController(
      text: (sameDayOpt.costCents / 100.0).toStringAsFixed(2),
    );
  }

  Widget _buildAddressSuggestions(
    EditProductState state,
    EditProductViewModel viewModel,
  ) {
    return Card(
      child: Column(
        children: state.addressSuggestions.map((s) {
          final props = s['properties'] ?? {};
          return ListTile(
            title: Text(props['formatted'] ?? ''),
            onTap: () {
              viewModel.selectAddress(s);
              _streetController.text =
                  props['street'] ?? props['formatted'] ?? '';
              _cityController.text = props['city'] ?? '';
              _postalCodeController.text = props['postcode'] ?? '';
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildApprovalStatusBanner() {
    final status = widget.product.lifecycleStatus;
    final reason = widget.product.approvalRejectionReason;
    if (status == ProductLifecycleStatusValues.active ||
        status == ProductLifecycleStatusValues.approved) {
      return const SizedBox.shrink();
    }

    Color bgColor;
    Color textColor;
    IconData icon;
    String title;
    String subtitle = '';

    if (status == ProductLifecycleStatusValues.rejected) {
      bgColor = DesignTokens.error.withValues(alpha: 0.10);
      textColor = DesignTokens.error;
      icon = Icons.cancel_rounded;
      title = 'product.approval_rejected_title'.tr();
      subtitle = reason ?? 'product.approval_rejected_generic'.tr();
    } else {
      bgColor = DesignTokens.warning.withValues(alpha: 0.12);
      textColor = DesignTokens.warningText;
      icon = Icons.hourglass_top_rounded;
      title = 'product.under_review_title'.tr();
      subtitle = 'product.under_review_edit_note'.tr();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(DesignTokens.radius12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    fontSize: 13,
                  ),
                ),
                ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: textColor, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryOptions(
    EditProductState state,
    EditProductViewModel viewModel,
  ) {
    return Card(
      elevation: 0,
      color: DesignTokens.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _buildDeliveryTile(
              'product.standard_delivery'.tr(),
              state.standardEnabled,
              (v) => viewModel.setStandardEnabled(v),
              _standardDaysController,
              _standardPriceController,
              'product.days_label'.tr(),
            ),
            _buildDeliveryTile(
              'product.express_delivery'.tr(),
              state.expressEnabled,
              (v) => viewModel.setExpressEnabled(v),
              _expressDaysController,
              _expressPriceController,
              'product.days_label'.tr(),
            ),
            _buildDeliveryTile(
              'product.same_day_delivery'.tr(),
              state.sameDayEnabled,
              (v) => viewModel.setSameDayEnabled(v),
              null,
              _sameDayPriceController,
              'product.price_dollar'.tr(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryTile(
    String title,
    bool enabled,
    Function(bool) onToggle,
    TextEditingController? daysController,
    TextEditingController priceController,
    String unitLabel, {
    TextEditingController? extraController,
  }) {
    return Column(
      children: [
        SwitchListTile(
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          value: enabled,
          onChanged: onToggle,
          activeThumbColor: DesignTokens.primary,
        ),
        if (enabled)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                if (daysController != null)
                  Expanded(
                    child: TextFormField(
                      controller: daysController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: unitLabel,
                        isDense: true,
                      ),
                    ),
                  ),
                if (extraController != null)
                  Expanded(
                    child: TextFormField(
                      controller: extraController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: unitLabel,
                        isDense: true,
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'product.price_dollar'.tr(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildEditDigitalSection(
    EditProductState state,
    EditProductViewModel viewModel,
  ) {
    return Column(
      key: const Key('editproduct_digital_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _EditDigitalTypeChip(
                key: const Key('editproduct_digital_type_software'),
                label: 'product.digital_type_software'.tr(),
                icon: Icons.computer_outlined,
                selected: state.digitalType == DigitalTypeValues.software,
                onTap: () =>
                    viewModel.setDigitalType(DigitalTypeValues.software),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _EditDigitalTypeChip(
                key: const Key('editproduct_digital_type_book'),
                label: 'product.digital_type_book'.tr(),
                icon: Icons.menu_book_outlined,
                selected: state.digitalType == DigitalTypeValues.book,
                onTap: () => viewModel.setDigitalType(DigitalTypeValues.book),
              ),
            ),
          ],
        ),
        if (state.digitalType == DigitalTypeValues.software) ...[
          const SizedBox(height: 16),
          Text(
            'product.download_links'.tr(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : DesignTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          _editUrlField(
            key: const Key('editproduct_macos_url'),
            label: 'product.mac_os_label'.tr(),
            controller: _macosUrlController,
            onChanged: (v) =>
                viewModel.setMacosDownloadUrl(v.isEmpty ? null : v),
          ),
          _editUrlField(
            key: const Key('editproduct_windows_url'),
            label: 'product.windows_label'.tr(),
            controller: _windowsUrlController,
            onChanged: (v) =>
                viewModel.setWindowsDownloadUrl(v.isEmpty ? null : v),
          ),
          _editUrlField(
            key: const Key('editproduct_linux_url'),
            label: 'product.linux_label'.tr(),
            controller: _linuxUrlController,
            onChanged: (v) =>
                viewModel.setLinuxDownloadUrl(v.isEmpty ? null : v),
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: const Key('editproduct_device_limit'),
            controller: _deviceLimitController,
            decoration: InputDecoration(
              labelText: 'product.device_limit_label'.tr(),
              hintText: 'product.device_limit_hint'.tr(),
            ),
            keyboardType: TextInputType.number,
            onChanged: (v) => viewModel.setDeviceLimit(int.tryParse(v)),
          ),
        ],
        if (state.digitalType == DigitalTypeValues.book) ...[
          const SizedBox(height: 16),
          Text(
            'product.reenter_download_url_update'.tr(),
            style: const TextStyle(fontSize: 12, color: Colors.orange),
          ),
          const SizedBox(height: 6),
          _editUrlField(
            key: const Key('editproduct_book_url'),
            label: 'product.book_download_url'.tr(),
            controller: _bookUrlController,
            onChanged: (v) => viewModel.setBookSourceUrl(v.isEmpty ? null : v),
          ),
        ],
      ],
    );
  }

  Widget _buildImageGrid(
    EditProductState state,
    EditProductViewModel viewModel,
  ) {
    if (state.existingImageUrls.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: state.existingImageUrls.length,
        itemBuilder: (context, index) => Stack(
          children: [
            Container(
              margin: const EdgeInsets.only(right: 8),
              width: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                  image: NetworkImage(state.existingImageUrls[index]),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 8,
              child: IconButton(
                icon: const Icon(
                  Icons.remove_circle,
                  color: DesignTokens.error,
                ),
                tooltip: 'product.remove_image'.tr(),
                onPressed: () => viewModel.removeExistingImage(index),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: DesignTokens.primary,
        ),
      ),
    );
  }

  Widget _buildTappableInfoHint(String shortText, String title, String body) {
    return GestureDetector(
      onTap: () => _showInfoSheet(title, body),
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 14,
              color: DesignTokens.info.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                shortText,
                style: TextStyle(
                  fontSize: 11,
                  color: DesignTokens.textSecondary,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 14,
              color: DesignTokens.textDisabled,
            ),
          ],
        ),
      ),
    );
  }

  Widget _editUrlField({
    Key? key,
    required String label,
    required TextEditingController controller,
    required void Function(String) onChanged,
  }) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        keyboardType: TextInputType.url,
        onChanged: onChanged,
      ),
    );
  }

  SellerDeliveryOption _findOption(
    List<SellerDeliveryOption> options,
    String type,
    SellerDeliveryOption fallback,
  ) {
    return options.firstWhere((o) => o.type == type, orElse: () => fallback);
  }

  void _handleSave(EditProductViewModel viewModel) {
    if (!_formKey.currentState!.validate()) return;

    final state = ref.read(editProductViewModelProvider(widget.product));

    // Bug #6: Preserve existing quantityDiscounts/additionalItemCost/maxItemsPerShipment from product
    final existingStandard = widget.product.deliveryOptions
        .where((o) => o.type == 'standard')
        .firstOrNull;
    final existingExpress = widget.product.deliveryOptions
        .where((o) => o.type == 'express')
        .firstOrNull;
    final existingQuantityDiscounts =
        existingStandard?.quantityDiscounts ??
        existingExpress?.quantityDiscounts ??
        const <ShippingQuantityDiscount>[];
    final existingAdditionalItemCostCents =
        existingStandard?.additionalItemCostCents ??
        existingExpress?.additionalItemCostCents ??
        0;
    final existingMaxItems =
        existingStandard?.maxItemsPerShipment ??
        existingExpress?.maxItemsPerShipment ??
        0;

    List<SellerDeliveryOption> deliveryOptions;
    if (state.isDigital) {
      deliveryOptions = <SellerDeliveryOption>[];
    } else if (state.isLocalDeliveryOnly) {
      // Bug #2: Inject pickup option for local-only products
      deliveryOptions = [
        SellerDeliveryOption(
          type: 'pickup',
          description: 'product.local_pickup_only'.tr(),
          estimatedDays: 0,
          costCents: 0,
        ),
      ];
    } else {
      deliveryOptions = <SellerDeliveryOption>[
        if (state.standardEnabled)
          SellerDeliveryOption(
            type: 'standard',
            description: 'product.standard_delivery'.tr(),
            estimatedDays: int.tryParse(_standardDaysController.text) ?? 5,
            costCents:
                ((double.tryParse(_standardPriceController.text) ?? 0.0) * 100)
                    .round(),
            quantityDiscounts: existingQuantityDiscounts,
            additionalItemCostCents: existingAdditionalItemCostCents,
            maxItemsPerShipment: existingMaxItems,
          ),
        if (state.expressEnabled)
          SellerDeliveryOption(
            type: 'express',
            description: 'product.express_delivery'.tr(),
            estimatedDays: int.tryParse(_expressDaysController.text) ?? 2,
            costCents:
                ((double.tryParse(_expressPriceController.text) ?? 9.99) * 100)
                    .round(),
            quantityDiscounts: existingQuantityDiscounts,
            additionalItemCostCents: existingAdditionalItemCostCents,
            maxItemsPerShipment: existingMaxItems,
          ),
        if (state.sameDayEnabled)
          SellerDeliveryOption(
            type: 'same_day',
            description: 'product.same_day_delivery'.tr(),
            estimatedDays: 0,
            costCents:
                ((double.tryParse(_sameDayPriceController.text) ?? 14.99) * 100)
                    .round(),
          ),
      ];
    }

    final existingInventory =
        widget.product.inventory ?? const InventoryConfig();
    final updatedInventory = existingInventory.copyWith(
      lowStockThreshold: _lowStockAlertEnabled
          ? (int.tryParse(_lowStockThresholdController.text) ?? 5)
          : 0,
    );

    viewModel.updateProduct(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      nameF: _nameFController.text.trim().isEmpty
          ? null
          : _nameFController.text.trim(),
      descriptionF: _descriptionFController.text.trim().isEmpty
          ? null
          : _descriptionFController.text.trim(),
      price: double.tryParse(_priceController.text.trim()) ?? 0,
      stock: int.tryParse(_stockController.text.trim()) ?? 0,
      categoryId: int.tryParse(_categoryController.text.trim()) ?? 0,
      street: _streetController.text.trim(),
      apartment: _apartmentController.text.trim(),
      city: _cityController.text.trim(),
      postalCode: _postalCodeController.text.trim(),
      weight: double.tryParse(_weightController.text),
      length: double.tryParse(_lengthController.text),
      width: double.tryParse(_widthController.text),
      height: double.tryParse(_heightController.text),
      shipDays: state.isDigital
          ? 0
          : int.tryParse(_shipDaysController.text) ?? 3,
      taxCode: _taxCodeController.text.trim(),
      deliveryOptions: deliveryOptions,
      inventory: updatedInventory,
      compareAtPrice: _compareAtPriceController.text.trim().isEmpty
          ? null
          : double.tryParse(_compareAtPriceController.text.trim()),
    );
  }

  void _onUpdateSuccess() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('product.updated_success'.tr()),
        backgroundColor: DesignTokens.success,
      ),
    );
    Navigator.pop(context, true);
  }

  void _showInfoSheet(String title, String body) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: DesignTokens.textOnPrimary,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: DesignTokens.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.lightbulb_rounded,
                    color: DesignTokens.info,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: DesignTokens.darkSurface,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: DesignTokens.surfaceVariant,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: DesignTokens.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              body,
              style: TextStyle(
                fontSize: 14,
                color: DesignTokens.darkSurface.withValues(alpha: 0.8),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DesignTokens.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'common.got_it'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _validatePostalCode(String? v) {
    if (v == null || v.isEmpty) return 'common.required'.tr();
    final reg = RegExp(r'^[A-Z]\d[A-Z] \d[A-Z]\d$');
    if (!reg.hasMatch(v.toUpperCase().trim())) {
      return 'product.invalid_postal'.tr();
    }
    return null;
  }
}
