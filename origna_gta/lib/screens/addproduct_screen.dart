// coverage:ignore-file
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/config/supplier_config.dart';
import 'package:origna_gta/core/routes.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/models/generated/models.dart';
import 'package:origna_gta/models/generated/product_models.dart';
import 'package:origna_gta/screens/productaddimages_screen.dart';
import 'package:origna_gta/screens/productaddvideo_screen.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/utils/responsive_layout.dart';
import 'package:origna_gta/utils/utils.dart';
import 'package:origna_gta/widgets/modern_loading_indicator.dart';

import '../../features/products/add_product_state.dart';
import '../../features/products/add_product_viewmodel.dart';
import '../../features/seller/warehouses_viewmodel.dart';

/// Documentation for AddProductScreen
class AddProductScreen extends ConsumerStatefulWidget {
  const AddProductScreen({super.key});

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _compareAtPriceController = TextEditingController();
  final _categoryController = TextEditingController();
  final _streetController = TextEditingController();
  final _apartmentController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _stockController = TextEditingController(text: '1');
  final _minOrderController = TextEditingController(text: '1');
  final _weightController = TextEditingController();
  final _lengthController = TextEditingController();
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();
  final _taxCodeController = TextEditingController();

  // Bill 96: French translation controllers
  final _nameFController = TextEditingController();
  final _descriptionFController = TextEditingController();

  // Supplier Info Controllers
  final _costController = TextEditingController();
  final _supplierSkuController = TextEditingController();
  final _sellerSkuController = TextEditingController();
  final _supplierUrlController = TextEditingController();
  final _supplierShippingDaysController = TextEditingController(text: '7-15');
  final _supplierNotesController = TextEditingController();
  final _customSupplierNameController = TextEditingController();

  // Inventory Config
  final _lowStockThresholdController = TextEditingController(text: '5');

  final _standardDaysController = TextEditingController(text: '5');
  final _standardPriceController = TextEditingController(text: '0.00');
  final _expressDaysController = TextEditingController(text: '2');
  final _expressPriceController = TextEditingController(text: '9.99');
  final _sameDayPriceController = TextEditingController(text: '14.99');

  // Quantity-based shipping discount controllers
  final _shippingDiscount3Controller = TextEditingController();
  final _shippingDiscount5Controller = TextEditingController();
  final _additionalItemCostController = TextEditingController(text: '0.00');
  final _maxItemsPerShipmentController = TextEditingController(text: '0');

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addProductViewModelProvider);
    final viewModel = ref.read(addProductViewModelProvider.notifier);

    ref.listen(addProductViewModelProvider, (previous, next) {
      if (previous?.isSuccess == true) return; // prevent double-fire
      if (next.isSuccess) {
        _onSuccess();
      } else if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            key: const Key('addproduct_error_snackbar'),
            content: Text(next.errorMessage!),
            backgroundColor: DesignTokens.error,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    final maxWidth = ResponsiveBreakpoints.getValue<double>(context: context, mobile: double.infinity, mobilePlus: 540, tablet: 640, desktop: 720);

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      body: Stack(
        children: [
          // Gradient header background
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 200,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [DesignTokens.gradientStart, DesignTokens.gradientMiddle, DesignTokens.gradientEnd],
                ),
              ),
              child: Stack(
                children: [
                  // Decorative circles
                  Positioned(
                    top: -30,
                    right: -20,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.06)),
                    ),
                  ),
                  Positioned(
                    top: 40,
                    left: -40,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.04)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Main content
          SafeArea(
            child: Column(
              children: [
                // Custom top bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        key: const Key('addproduct_back_button'),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'product.go_back'.tr(),
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.arrow_back_rounded, color: DesignTokens.textOnPrimary, size: 20),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          key: const Key('addproduct_screen_title'),
                          'product.new_product'.tr(),
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: DesignTokens.textOnPrimary, letterSpacing: 0.3),
                        ),
                      ),
                      // Step indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(5, (i) {
                            final isActive = i <= state.activeStep;
                            return Container(
                              width: isActive ? 18 : 8,
                              height: 8,
                              margin: EdgeInsets.only(left: i > 0 ? 4 : 0),
                              decoration: BoxDecoration(
                                color: isActive ? DesignTokens.textOnPrimary : Colors.white.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
                // Scrollable form
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Center(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxWidth),
                          child: Form(
                            key: _formKey,
                            autovalidateMode: state.hasAttemptedSubmit ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // SECTION 1: Basic Info
                                _buildSectionCard(
                                  key: const Key('addproduct_section_basic'),
                                  index: 0,
                                  icon: Icons.shopping_bag_rounded,
                                  title: 'product.product_details'.tr(),
                                  subtitle: 'product.name_desc_pricing'.tr(),
                                  state: state,
                                  viewModel: viewModel,
                                  children: [
                                    _buildGlassTextField(
                                      key: const Key('product_name_field'),
                                      controller: _nameController,
                                      label: 'product.product_name'.tr(),
                                      icon: Icons.sell_rounded,
                                      hint: 'product.enter_product_name'.tr(),
                                      validator: (v) => v?.isEmpty ?? true ? 'common.required'.tr() : null,
                                    ),
                                    const SizedBox(height: 16),
                                    _buildGlassTextField(
                                      key: const Key('product_description_field'),
                                      controller: _descriptionController,
                                      label: 'product.description'.tr(),
                                      icon: Icons.notes_rounded,
                                      hint: 'product.describe_product'.tr(),
                                      maxLines: 3,
                                      validator: (v) => v?.isEmpty ?? true ? 'common.required'.tr() : null,
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildGlassTextField(
                                            key: const Key('product_price_field'),
                                            controller: _priceController,
                                            label: 'product.price_cad'.tr(),
                                            icon: Icons.attach_money_rounded,
                                            keyboardType: TextInputType.number,
                                            prefixText: '\$ ',
                                            suffixText: 'CAD',
                                            validator: (v) => v?.isEmpty ?? true ? 'common.required'.tr() : null,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildGlassTextField(
                                            key: const Key('product_stock_field'),
                                            controller: _stockController,
                                            label: 'product.stock'.tr(),
                                            icon: Icons.inventory_2_rounded,
                                            keyboardType: TextInputType.number,
                                            validator: (v) => v?.isEmpty ?? true ? 'common.required'.tr() : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    _buildGlassTextField(
                                      key: const Key('product_compare_at_price_field'),
                                      controller: _compareAtPriceController,
                                      label: 'product.compare_at_price'.tr(),
                                      icon: Icons.local_offer_rounded,
                                      hint: 'product.compare_at_price_hint'.tr(),
                                      keyboardType: TextInputType.number,
                                      prefixText: '\$ ',
                                      validator: (v) {
                                        if (v == null || v.isEmpty) return null; // optional field
                                        final cap = double.tryParse(v);
                                        if (cap == null) return 'product.invalid_price'.tr();
                                        final currentPrice = double.tryParse(_priceController.text.trim()) ?? 0;
                                        if (cap - currentPrice < 0.50) return 'product.compare_at_price_must_be_higher'.tr();
                                        return null;
                                      },
                                    ),
                                    _buildTappableInfoHint(
                                      'product.compare_at_price_learn_more'.tr(),
                                      'product.compare_at_price'.tr(),
                                      'product.compare_at_price_info_body'.tr(),
                                    ),
                                    const SizedBox(height: 16),
                                    _buildGlassTextField(
                                      controller: _minOrderController,
                                      label: 'product.min_order_qty'.tr(),
                                      icon: Icons.format_list_numbered_rounded,
                                      keyboardType: TextInputType.number,
                                      validator: (v) => v?.isEmpty ?? true ? 'common.required'.tr() : null,
                                      onChanged: (v) => viewModel.setMinimumOrderQuantity(int.tryParse(v) ?? 1),
                                    ),
                                    if (!state.isDigital) ...[
                                      const SizedBox(height: 12),
                                      _buildGlassToggle(
                                        key: const Key('addproduct_free_shipping_toggle'),
                                        label: 'product.free_shipping'.tr(),
                                        icon: Icons.local_shipping_rounded,
                                        value: state.freeShipping,
                                        onChanged: viewModel.toggleFreeShipping,
                                        infoTitle: 'product.free_shipping'.tr(),
                                        infoBody: 'product.free_shipping_info_body'.tr(),
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    _buildCategorySelector(viewModel, state),
                                    const SizedBox(height: 12),
                                    _buildSubcategorySelector(state, viewModel),
                                    const SizedBox(height: 12),
                                    _buildGlassTextField(
                                      controller: _taxCodeController,
                                      label: 'product.tax_code_label'.tr(),
                                      icon: Icons.receipt_long_rounded,
                                      hint: 'product.tax_code_hint'.tr(),
                                      validator: (v) => isValidTaxCode(v) ? null : 'product.invalid_tax_code'.tr(),
                                    ),
                                    _buildTappableInfoHint(
                                      'product.tax_code_learn_more'.tr(),
                                      'product.stripe_tax_codes'.tr(),
                                      'product.stripe_tax_codes_body'.tr(),
                                    ),
                                    const SizedBox(height: 16),
                                    _buildGlassTextField(
                                      key: const Key('addproduct_seller_sku_field'),
                                      controller: _sellerSkuController,
                                      label: 'product.sku_optional'.tr(),
                                      icon: Icons.qr_code_rounded,
                                      hint: 'product.sku_hint'.tr(),
                                      errorText: state.skuError,
                                      onChanged: (v) {
                                        if (state.skuError != null) viewModel.clearSkuError();
                                        viewModel.setSellerSku(v);
                                      },
                                    ),
                                    _buildTappableInfoHint('product.sku_what_is'.tr(), 'product.sku'.tr(), 'product.sku_info_body'.tr()),
                                    if (!state.isDigital) ...[const SizedBox(height: 16), _buildConditionSelector(state, viewModel)],
                                  ],
                                ),
                                const SizedBox(height: 16),

                                _buildFrenchTranslationSection(),
                                const SizedBox(height: 16),

                                _buildVariantBuilderSection(state, viewModel),
                                if (state.hasVariants) const SizedBox(height: 16),

                                _buildSectionCard(
                                  key: const Key('addproduct_section_media'),
                                  index: 1,
                                  icon: Icons.perm_media_rounded,
                                  title: 'product.product_media'.tr(), // Changed to media
                                  subtitle: 'product.photos_and_video'.tr(),
                                  state: state,
                                  viewModel: viewModel,
                                  children: [
                                    ProductAddImages(imageModels: state.imageModels, onImagesChanged: viewModel.updateImages),
                                    const SizedBox(height: 24),
                                    ProductAddVideo(videoFile: state.videoFile, onVideoAdded: viewModel.setVideo, onVideoRemoved: viewModel.removeVideo),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                _buildSectionCard(
                                  key: const Key('addproduct_section_delivery'),
                                  index: 2,
                                  icon: Icons.local_shipping_rounded,
                                  title: 'product.delivery_shipping'.tr(),
                                  subtitle: 'product.shipping_options'.tr(),
                                  state: state,
                                  viewModel: viewModel,
                                  children: [
                                    _buildGlassToggle(
                                      key: const Key('addproduct_digital_toggle'),
                                      label: 'product.digital_product_label'.tr(),
                                      subtitle: 'product.no_shipping_needed'.tr(),
                                      icon: Icons.cloud_download_rounded,
                                      value: state.isDigital,
                                      onChanged: viewModel.toggleDigital,
                                      infoTitle: 'product.digital_info_title'.tr(),
                                      infoBody: 'product.digital_info_body'.tr(),
                                    ),
                                    if (state.isDigital)
                                      Padding(
                                        key: const Key('addproduct_digital_info_banner'),
                                        padding: const EdgeInsets.only(top: 8),
                                        child: _buildInfoBanner('product.digital_skip_shipping'.tr(), Icons.info_outline_rounded, DesignTokens.info),
                                      ),
                                    if (state.isDigital) _buildDigitalProductSection(context, state, viewModel),
                                    if (!state.isDigital) ...[
                                      const SizedBox(height: 12),
                                      _buildGlassToggle(
                                        key: const Key('addproduct_perishable_toggle'),
                                        label: 'product.perishable_item'.tr(),
                                        icon: Icons.thermostat_rounded,
                                        value: state.isPerishable,
                                        onChanged: viewModel.togglePerishable,
                                        infoTitle: 'product.perishable_info_title'.tr(),
                                        infoBody: 'product.perishable_info_body'.tr(),
                                      ),
                                      const SizedBox(height: 12),
                                      _buildGlassToggle(
                                        key: const Key('addproduct_age_restricted_toggle'),
                                        label: 'product.age_restricted_item'.tr(),
                                        icon: Icons.no_adult_content_rounded,
                                        value: state.isAgeRestricted,
                                        onChanged: viewModel.toggleAgeRestricted,
                                        infoTitle: 'product.age_restricted_info_title'.tr(),
                                        infoBody: 'product.age_restricted_info_body'.tr(),
                                      ),
                                      const SizedBox(height: 16),
                                      _buildDeliveryTierCard(
                                        key: const Key('addproduct_standard_delivery_card'),
                                        title: 'product.standard_delivery'.tr(),
                                        icon: Icons.local_shipping_outlined,
                                        isEnabled: state.standardEnabled,
                                        onChanged: viewModel.setStandardEnabled,
                                        color: DesignTokens.primary,
                                        infoTitle: 'product.standard_delivery'.tr(),
                                        infoBody: 'product.standard_delivery_info_body'.tr(),
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _buildGlassTextField(
                                                  controller: _standardDaysController,
                                                  label: 'product.days_label'.tr(),
                                                  hint: 'product.est_business_days_hint'.tr(),
                                                  keyboardType: TextInputType.number,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: _buildGlassTextField(
                                                  controller: _standardPriceController,
                                                  label: 'product.price_dollar'.tr(),
                                                  keyboardType: TextInputType.number,
                                                  hint: 'product.free_hint'.tr(),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      if (state.freeShipping)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 12),
                                          child: _buildInfoBanner('product.free_shipping_banner'.tr(), Icons.local_shipping_rounded, DesignTokens.success),
                                        ),
                                      if (!state.freeShipping) ...[
                                        const SizedBox(height: 10),
                                        _buildDeliveryTierCard(
                                          key: const Key('addproduct_express_delivery_card'),
                                          title: 'product.express_delivery'.tr(),
                                          icon: Icons.bolt_rounded,
                                          isEnabled: state.expressEnabled,
                                          onChanged: viewModel.setExpressEnabled,
                                          color: DesignTokens.warning,
                                          infoTitle: 'product.express_delivery'.tr(),
                                          infoBody: 'product.express_delivery_info_body'.tr(),
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: _buildGlassTextField(
                                                    controller: _expressDaysController,
                                                    label: 'product.days_label'.tr(),
                                                    hint: 'product.est_business_days_hint'.tr(),
                                                    keyboardType: TextInputType.number,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: _buildGlassTextField(
                                                    controller: _expressPriceController,
                                                    label: 'product.price_dollar'.tr(),
                                                    keyboardType: TextInputType.number,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        _buildDeliveryTierCard(
                                          key: const Key('addproduct_same_day_delivery_card'),
                                          title: 'product.same_day_delivery'.tr(),
                                          icon: Icons.rocket_launch_rounded,
                                          isEnabled: state.sameDayEnabled,
                                          onChanged: viewModel.setSameDayEnabled,
                                          color: DesignTokens.success,
                                          infoTitle: 'product.same_day_delivery'.tr(),
                                          infoBody: 'product.same_day_delivery_info_body'.tr(),
                                          children: [
                                            _buildGlassTextField(
                                              controller: _sameDayPriceController,
                                              label: 'product.price_dollar'.tr(),
                                              keyboardType: TextInputType.number,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        _buildQuantityShippingDiscountsSection(viewModel, state),
                                      ],
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 16),

                                if (!state.isDigital)
                                  _buildSectionCard(
                                    key: const Key('addproduct_section_package'),
                                    index: 3,
                                    icon: Icons.location_on_rounded,
                                    title: 'product.package_location'.tr(),
                                    subtitle: 'product.dimensions_pickup'.tr(),
                                    state: state,
                                    viewModel: viewModel,
                                    children: [
                                      _buildGlassToggle(
                                        key: const Key('addproduct_local_pickup_toggle'),
                                        label: 'product.local_pickup_only'.tr(),
                                        icon: Icons.store_rounded,
                                        value: state.isLocalDeliveryOnly,
                                        onChanged: viewModel.setLocalDeliveryOnly,
                                        infoTitle: 'product.local_pickup_only'.tr(),
                                        infoBody: 'product.local_pickup_info_body'.tr(),
                                      ),
                                      if (!state.isLocalDeliveryOnly) ...[
                                        const SizedBox(height: 16),
                                        _buildGlassTextField(
                                          controller: _weightController,
                                          key: const Key('addproduct_weight_field'),
                                          label: 'product.weight'.tr(),
                                          icon: Icons.scale_rounded,
                                          keyboardType: TextInputType.number,
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildGlassTextField(
                                                controller: _lengthController,
                                                key: const Key('addproduct_length_field'),
                                                label: 'product.length_cm'.tr(),
                                                keyboardType: TextInputType.number,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: _buildGlassTextField(
                                                controller: _widthController,
                                                key: const Key('addproduct_width_field'),
                                                label: 'product.width_cm'.tr(),
                                                keyboardType: TextInputType.number,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: _buildGlassTextField(
                                                controller: _heightController,
                                                key: const Key('addproduct_height_field'),
                                                label: 'product.height_cm'.tr(),
                                                keyboardType: TextInputType.number,
                                              ),
                                            ),
                                          ],
                                        ),
                                        _buildTappableInfoHint(
                                          'product.weight_dimensions_learn_more'.tr(),
                                          'product.weight_dimensions_info_title'.tr(),
                                          'product.weight_dimensions_info_body'.tr(),
                                        ),
                                      ],
                                      const SizedBox(height: 20),
                                      _buildWarehouseSelector(context, state, viewModel),
                                    ],
                                  ),
                                if (!state.isDigital) const SizedBox(height: 16),

                                _buildCollapsibleSection(
                                  key: const Key('addproduct_section_supplier'),
                                  index: 4,
                                  icon: Icons.business_center_rounded,
                                  title: 'product.supplier_inventory'.tr(),
                                  subtitle: 'product.cost_margins_stock'.tr(),
                                  children: [
                                    _buildSubSectionHeader('product.supplier_info'.tr(), Icons.storefront_rounded),
                                    const SizedBox(height: 12),
                                    _buildGlassDropdown(
                                      label: 'product.supplier_platform'.tr(),
                                      value: state.selectedSupplierType,
                                      items: getSupplierDropdownItems(),
                                      onChanged: (v) {
                                        final type = v ?? SupplierTypeValues.other;
                                        viewModel.setSupplierType(type);
                                        final config = getSupplierConfig(type);
                                        if (!config.supportedCurrencies.contains(state.selectedSupplierCurrency)) {
                                          viewModel.setSupplierCurrency(config.defaultCurrency);
                                        }
                                        final range = getSupplierDeliveryRange(type);
                                        _standardDaysController.text = range.minDays.toString();
                                        _expressDaysController.text = (range.minDays ~/ 2).clamp(1, range.minDays).toString();
                                      },
                                    ),
                                    if (state.selectedSupplierType.isNotEmpty) _buildSupplierInfoBadge(state.selectedSupplierType),
                                    if (getSupplierConfig(state.selectedSupplierType).isCustom) ...[
                                      const SizedBox(height: 12),
                                      _buildGlassTextField(
                                        controller: _customSupplierNameController,
                                        label: 'product.custom_supplier_name'.tr(),
                                        icon: Icons.edit_rounded,
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    _buildInfoBanner('product.supplier_cost_banner'.tr(), Icons.info_outline_rounded, DesignTokens.info),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: _buildGlassTextField(
                                            controller: _costController,
                                            label: 'product.supplier_cost'.tr(),
                                            icon: Icons.payments_rounded,
                                            keyboardType: TextInputType.number,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildGlassDropdown(
                                            label: 'product.currency_label'.tr(),
                                            value: state.selectedSupplierCurrency,
                                            items: getSupplierConfig(
                                              state.selectedSupplierType,
                                            ).supportedCurrencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                                            onChanged: (v) => viewModel.setSupplierCurrency(v ?? SupplierCurrencyValues.usd),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_costController.text.isNotEmpty && _priceController.text.isNotEmpty) _buildMarginPreview(state),
                                    const SizedBox(height: 12),
                                    _buildGlassTextField(controller: _supplierSkuController, label: 'product.supplier_sku'.tr(), icon: Icons.qr_code_2_rounded),
                                    const SizedBox(height: 12),
                                    _buildGlassTextField(
                                      controller: _supplierUrlController,
                                      label: 'product.supplier_url'.tr(),
                                      icon: Icons.link_rounded,
                                      keyboardType: TextInputType.url,
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildGlassTextField(
                                            controller: _supplierShippingDaysController,
                                            label: 'product.ship_days'.tr(),
                                            icon: Icons.schedule_rounded,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildGlassToggle(
                                            label: 'product.has_tracking'.tr(),
                                            icon: Icons.gps_fixed_rounded,
                                            value: state.hasTracking,
                                            onChanged: viewModel.setHasTracking,
                                            infoTitle: 'product.supplier_tracking_title'.tr(),
                                            infoBody: 'product.supplier_tracking_body'.tr(),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    _buildGlassTextField(
                                      controller: _supplierNotesController,
                                      label: 'product.internal_notes'.tr(),
                                      icon: Icons.sticky_note_2_rounded,
                                      maxLines: 2,
                                    ),
                                    const SizedBox(height: 24),
                                    _buildSubSectionHeader('product.inventory_settings'.tr(), Icons.warehouse_rounded),
                                    const SizedBox(height: 12),
                                    _buildGlassToggle(
                                      key: const Key('addproduct_inventory_toggle'),
                                      label: 'product.manage_inventory'.tr(),
                                      subtitle: 'product.manage_inventory_subtitle'.tr(),
                                      icon: Icons.inventory_rounded,
                                      value: state.inventoryManaged,
                                      onChanged: viewModel.setInventoryManaged,
                                      infoTitle: 'product.inventory_management_title'.tr(),
                                      infoBody: 'product.inventory_management_body'.tr(),
                                    ),
                                    if (state.inventoryManaged) ...[
                                      const SizedBox(height: 8),
                                      _buildGlassToggle(
                                        label: 'product.stock_quantity'.tr(),
                                        subtitle: 'product.track_quantity_subtitle'.tr(),
                                        icon: Icons.numbers_rounded,
                                        value: state.trackQuantity,
                                        onChanged: viewModel.setTrackQuantity,
                                        infoTitle: 'product.stock_quantity'.tr(),
                                        infoBody: 'product.track_quantity_info_body'.tr(),
                                      ),
                                      const SizedBox(height: 8),
                                      _buildGlassToggle(
                                        label: 'product.allow_backorders'.tr(),
                                        subtitle: 'product.allow_backorders_subtitle'.tr(),
                                        icon: Icons.replay_rounded,
                                        value: state.allowBackorder,
                                        onChanged: viewModel.setAllowBackorder,
                                        infoTitle: 'product.allow_backorders'.tr(),
                                        infoBody: 'product.allow_backorders_info_body'.tr(),
                                      ),
                                      const SizedBox(height: 8),
                                      _buildGlassToggle(
                                        key: const Key('addproduct_low_stock_alert_toggle'),
                                        label: 'product.low_stock_alert'.tr(),
                                        subtitle: 'product.low_stock_alert_subtitle'.tr(),
                                        icon: Icons.notifications_active_rounded,
                                        value: state.lowStockAlertEnabled,
                                        onChanged: viewModel.setLowStockAlertEnabled,
                                      ),
                                      if (state.lowStockAlertEnabled) ...[
                                        const SizedBox(height: 8),
                                        _buildGlassTextField(
                                          controller: _lowStockThresholdController,
                                          label: 'product.low_stock_threshold'.tr(),
                                          icon: Icons.warning_amber_rounded,
                                          keyboardType: TextInputType.number,
                                        ),
                                      ],
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 28),

                                _buildSubmitButton(state, viewModel),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _nameController.dispose();
    _nameFController.dispose();
    _descriptionController.dispose();
    _descriptionFController.dispose();
    _priceController.dispose();
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
    _compareAtPriceController.dispose();
    _taxCodeController.dispose();
    _minOrderController.dispose();
    _standardDaysController.dispose();
    _standardPriceController.dispose();
    _expressDaysController.dispose();
    _expressPriceController.dispose();
    _sameDayPriceController.dispose();
    _costController.dispose();
    _supplierSkuController.dispose();
    _sellerSkuController.dispose();
    _supplierUrlController.dispose();
    _supplierShippingDaysController.dispose();
    _supplierNotesController.dispose();
    _customSupplierNameController.dispose();
    _lowStockThresholdController.dispose();
    _shippingDiscount3Controller.dispose();
    _shippingDiscount5Controller.dispose();
    _additionalItemCostController.dispose();
    _maxItemsPerShipmentController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
    _shippingDiscount3Controller.addListener(_validateDiscountTiers);
    _shippingDiscount5Controller.addListener(_validateDiscountTiers);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // PROD-C1: reset text controllers when re-entering the screen after a previous success.
      final currentState = ref.read(addProductViewModelProvider);
      if (currentState.isSuccess) {
        _resetControllers();
      }
      ref.read(addProductViewModelProvider.notifier).resetIfSuccess();
    });
  }

  Widget _buildAddressSuggestions(AddProductState state, AddProductViewModel viewModel) {
    return Container(
      key: const Key('addproduct_address_suggestions'),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: DesignTokens.textOnPrimary,
        borderRadius: BorderRadius.circular(14),
        boxShadow: DesignTokens.shadowLg,
        border: Border.all(color: DesignTokens.outline.withValues(alpha: 0.2)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: state.addressSuggestions.length,
          separatorBuilder: (_, _) => Divider(height: 1, color: DesignTokens.outlineVariant),
          itemBuilder: (context, i) {
            final s = state.addressSuggestions[i];
            return ListTile(
              dense: true,
              leading: Icon(Icons.location_on_rounded, size: 18, color: DesignTokens.primary),
              title: Text(s['properties']?['formatted'] ?? '', style: const TextStyle(fontSize: 13)),
              onTap: () {
                viewModel.selectAddress(s);
                final props = s['properties'] as Map<String, dynamic>?;
                final street = (props?['street'] as String?)?.trim() ?? '';
                final houseNumber =
                    (props?['housenumber'] as String?)?.trim() ??
                    (props?['house_number'] as String?)?.trim() ??
                    (props?['address_line1'] as String?)?.trim() ??
                    '';
                final formatted = (props?['formatted'] as String?)?.trim() ?? '';

                final fullStreet = (houseNumber.isNotEmpty && street.isNotEmpty) ? '$houseNumber $street' : (street.isNotEmpty ? street : formatted);

                _streetController.text = fullStreet;
                _cityController.text = s['properties']?['city'] ?? '';
                _postalCodeController.text = s['properties']?['postcode'] ?? '';
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategorySelector(AddProductViewModel viewModel, AddProductState state) {
    return DropdownButtonFormField<String>(
      key: const Key('addproduct_category_selector'),
      menuMaxHeight: ResponsiveBreakpoints.dropdownMaxHeight(context),
      initialValue: state.selectedCategoryId,
      decoration: InputDecoration(
        labelText: 'product.category'.tr(),
        prefixIcon: const Icon(Icons.category_rounded, size: 20),
        filled: true,
        fillColor: DesignTokens.surfaceVariant.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: DesignTokens.outline.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: DesignTokens.outline.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: DesignTokens.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: TextStyle(color: DesignTokens.textSecondary, fontSize: 13),
      ),
      items: productCategories
          .map(
            (c) => DropdownMenuItem(
              key: Key('category_item_${c.name}'),
              value: c.categoryId.toString(),
              child: Semantics(
                label: 'category-option-${c.categoryId}',
                child: Row(
                  children: [
                    Icon(c.icon, size: 18, color: DesignTokens.primary),
                    const SizedBox(width: 10),
                    Text(c.name.tr()),
                  ],
                ),
              ),
            ),
          )
          .toList(),
      onChanged: (v) {
        viewModel.setCategoryId(v);
        _categoryController.text = v ?? '';
      },
      validator: (v) => v == null ? 'common.required'.tr() : null,
    );
  }

  Widget _buildCollapsibleSection({
    Key? key,
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return AnimatedContainer(
      key: key,
      duration: DesignTokens.durationNormal,
      decoration: BoxDecoration(
        color: DesignTokens.textOnPrimary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DesignTokens.outlineVariant),
        boxShadow: DesignTokens.shadowSm,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [DesignTokens.secondary, DesignTokens.primary]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: DesignTokens.textOnPrimary, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: DesignTokens.darkSurface, letterSpacing: -0.3),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(subtitle, style: TextStyle(fontSize: 13, color: DesignTokens.textSecondary)),
          ),
          children: children,
        ),
      ),
    );
  }

  Widget _buildConditionSelector(AddProductState state, AddProductViewModel viewModel) {
    const conditions = [
      (ProductConditionValues.newCondition, 'product.condition_new'),
      (ProductConditionValues.likeNew, 'product.condition_like_new'),
      (ProductConditionValues.good, 'product.condition_good'),
      (ProductConditionValues.fair, 'product.condition_fair'),
      (ProductConditionValues.forParts, 'product.condition_for_parts'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.grade_rounded, size: 16, color: DesignTokens.textSecondary),
            const SizedBox(width: 6),
            Text(
              'product.product_condition'.tr(),
              style: TextStyle(color: DesignTokens.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            Text('common.optional'.tr(), style: TextStyle(color: DesignTokens.textDisabled, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: conditions.map(((String, String) entry) {
            final (value, labelKey) = entry;
            final selected = state.condition == value;
            return ChoiceChip(
              label: Text(
                labelKey.tr(),
                style: TextStyle(
                  fontSize: 12,
                  color: selected ? Colors.white : DesignTokens.textPrimary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              selected: selected,
              onSelected: (_) => viewModel.setCondition(selected ? null : value),
              selectedColor: DesignTokens.primary,
              backgroundColor: DesignTokens.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: selected ? DesignTokens.primary : DesignTokens.outline.withValues(alpha: 0.3)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              showCheckmark: false,
            );
          }).toList(),
        ),
      ],
    );
  }

  List<SellerDeliveryOption> _buildDeliveryOptions(AddProductState state) {
    if (state.isDigital) return [];

    if (state.isLocalDeliveryOnly) {
      return [SellerDeliveryOption(type: DeliveryTypeValues.pickup, description: 'product.local_pickup_only'.tr(), estimatedDays: 0, costCents: 0)];
    }

    final quantityDiscounts = <ShippingQuantityDiscount>[];

    final discount3 = double.tryParse(_shippingDiscount3Controller.text);
    if (discount3 != null && discount3 > 0) {
      quantityDiscounts.add(
        ShippingQuantityDiscount(
          minQuantity: 3,
          discountType: DiscountTypeValues.percent,
          discountValue: discount3,
          label: 'product.shipping_discount_label'.tr(namedArgs: {'percent': discount3.toStringAsFixed(0), 'qty': '3'}),
        ),
      );
    }

    final discount5 = double.tryParse(_shippingDiscount5Controller.text);
    if (discount5 != null && discount5 > 0) {
      quantityDiscounts.add(
        ShippingQuantityDiscount(
          minQuantity: 5,
          discountType: DiscountTypeValues.percent,
          discountValue: discount5,
          label: 'product.shipping_discount_label'.tr(namedArgs: {'percent': discount5.toStringAsFixed(0), 'qty': '5'}),
        ),
      );
    }

    final additionalItemCostCents = ((double.tryParse(_additionalItemCostController.text) ?? 0.0) * 100).round();
    final maxItems = int.tryParse(_maxItemsPerShipmentController.text) ?? 0;

    return [
      if (state.standardEnabled)
        SellerDeliveryOption(
          type: DeliveryTypeValues.standard,
          description: 'product.standard_delivery'.tr(),
          estimatedDays: int.tryParse(_standardDaysController.text) ?? 5,
          costCents: ((double.tryParse(_standardPriceController.text) ?? 0.0) * 100).round(),
          quantityDiscounts: quantityDiscounts,
          additionalItemCostCents: additionalItemCostCents,
          maxItemsPerShipment: maxItems,
        ),
      if (state.expressEnabled)
        SellerDeliveryOption(
          type: DeliveryTypeValues.express,
          description: 'product.express_delivery'.tr(),
          estimatedDays: int.tryParse(_expressDaysController.text) ?? 2,
          costCents: ((double.tryParse(_expressPriceController.text) ?? 9.99) * 100).round(),
          quantityDiscounts: quantityDiscounts,
          additionalItemCostCents: additionalItemCostCents,
          maxItemsPerShipment: maxItems,
        ),
      if (state.sameDayEnabled)
        SellerDeliveryOption(
          type: DeliveryTypeValues.sameDay,
          description: 'product.same_day_delivery'.tr(),
          estimatedDays: 0,
          costCents: ((double.tryParse(_sameDayPriceController.text) ?? 14.99) * 100).round(),
          quantityDiscounts: quantityDiscounts,
          additionalItemCostCents: additionalItemCostCents,
          maxItemsPerShipment: maxItems,
        ),
    ];
  }

  Widget _buildDeliveryTierCard({
    Key? key,
    required String title,
    required IconData icon,
    required bool isEnabled,
    required ValueChanged<bool> onChanged,
    required Color color,
    required List<Widget> children,
    String? infoTitle,
    String? infoBody,
  }) {
    return AnimatedContainer(
      key: key,
      duration: DesignTokens.durationNormal,
      decoration: BoxDecoration(
        color: isEnabled ? color.withValues(alpha: 0.04) : DesignTokens.surfaceVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isEnabled ? color.withValues(alpha: 0.3) : DesignTokens.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 0),
            child: Row(
              children: [
                Icon(icon, size: 20, color: isEnabled ? color : DesignTokens.textDisabled),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isEnabled ? color : DesignTokens.textSecondary),
                  ),
                ),
                if (infoTitle != null && infoBody != null)
                  GestureDetector(
                    onTap: () => _showInfoSheet(infoTitle, infoBody),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(Icons.info_outline_rounded, size: 16, color: isEnabled ? color.withValues(alpha: 0.5) : DesignTokens.textDisabled),
                    ),
                  ),
                Switch.adaptive(value: isEnabled, onChanged: onChanged, activeThumbColor: color),
              ],
            ),
          ),
          if (isEnabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(children: children),
            ),
        ],
      ),
    );
  }

  Widget _buildDigitalProductSection(BuildContext context, AddProductState state, AddProductViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _DigitalTypeCard(
                key: const Key('addproduct_digital_type_software'),
                label: 'product.digital_type_software'.tr(),
                icon: Icons.computer_outlined,
                selected: state.digitalType == DigitalTypeValues.software,
                onTap: () => viewModel.setDigitalType(DigitalTypeValues.software),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DigitalTypeCard(
                key: const Key('addproduct_digital_type_book'),
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
          Text('product.download_links'.tr(), style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : DesignTokens.textPrimary)),
          const SizedBox(height: 4),
          _buildUrlField(
            label: 'product.mac_os_label'.tr(),
            placeholder: 'product.macos_hint'.tr(),
            value: state.macosDownloadUrl,
            onChanged: viewModel.setMacosDownloadUrl,
          ),
          _buildUrlField(
            label: 'product.windows_label'.tr(),
            placeholder: 'product.windows_hint'.tr(),
            value: state.windowsDownloadUrl,
            onChanged: viewModel.setWindowsDownloadUrl,
          ),
          _buildUrlField(
            label: 'product.linux_label'.tr(),
            placeholder: 'product.linux_hint'.tr(),
            value: state.linuxDownloadUrl,
            onChanged: viewModel.setLinuxDownloadUrl,
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: state.deviceLimit?.toString(),
            decoration: InputDecoration(labelText: 'product.device_limit_label'.tr(), hintText: 'product.device_limit_hint'.tr()),
            keyboardType: TextInputType.number,
            onChanged: (v) => viewModel.setDeviceLimit(int.tryParse(v.trim())),
          ),
        ],
        if (state.digitalType == DigitalTypeValues.book) ...[
          const SizedBox(height: 16),
          Text('product.book_download_url'.tr(), style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : DesignTokens.textPrimary)),
          const SizedBox(height: 4),
          _buildUrlField(
            label: 'product.download_source_url_label'.tr(),
            placeholder: 'product.book_download_hint'.tr(),
            value: state.bookSourceUrl,
            onChanged: viewModel.setBookSourceUrl,
          ),
        ],
      ],
    );
  }

  Widget _buildFrenchTranslationSection() {
    return AnimatedContainer(
      key: const Key('addproduct_section_french'),
      duration: DesignTokens.durationNormal,
      decoration: BoxDecoration(
        color: DesignTokens.textOnPrimary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DesignTokens.outlineVariant),
        boxShadow: DesignTokens.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [const Color(0xFF003087), const Color(0xFFEF3340)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.translate_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'product.french_section_title'.tr(),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: DesignTokens.darkSurface, letterSpacing: -0.3),
                      ),
                      const SizedBox(height: 2),
                      Text('product.french_section_subtitle'.tr(), style: TextStyle(fontSize: 13, color: DesignTokens.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF3340).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEF3340).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'Loi 96',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFEF3340)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 24, indent: 20, endIndent: 20),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildGlassTextField(
                  key: const Key('product_name_f_field'),
                  controller: _nameFController,
                  label: 'product.name_french'.tr(),
                  icon: Icons.sell_rounded,
                  hint: 'product.name_french_hint'.tr(),
                ),
                const SizedBox(height: 16),
                _buildGlassTextField(
                  key: const Key('product_description_f_field'),
                  controller: _descriptionFController,
                  label: 'product.description_french'.tr(),
                  icon: Icons.notes_rounded,
                  hint: 'product.description_french_hint'.tr(),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassDropdown({
    Key? key,
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?)? onChanged,
  }) {
    return DropdownButtonFormField<String>(
      key: key,
      menuMaxHeight: ResponsiveBreakpoints.dropdownMaxHeight(context),
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: DesignTokens.surfaceVariant.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: DesignTokens.outline.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: DesignTokens.outline.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: DesignTokens.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: TextStyle(color: DesignTokens.textSecondary, fontSize: 13),
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _buildGlassTextField({
    Key? key,
    required TextEditingController controller,
    required String label,
    IconData? icon,
    String? hint,
    String? prefixText,
    String? suffixText,
    int maxLines = 1,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    bool readOnly = false,
    String? errorText,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      validator: validator,
      onChanged: onChanged,
      readOnly: readOnly,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        suffixText: suffixText,
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
        errorText: errorText,
        filled: true,
        fillColor: DesignTokens.surfaceVariant.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: DesignTokens.outline.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: DesignTokens.outline.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: DesignTokens.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: DesignTokens.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: TextStyle(color: DesignTokens.textSecondary, fontSize: 13),
        hintStyle: TextStyle(color: DesignTokens.textDisabled, fontSize: 13),
      ),
    );
  }

  Widget _buildGlassToggle({
    Key? key,
    required String label,
    String? subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    String? infoTitle,
    String? infoBody,
  }) {
    return GestureDetector(
      key: key,
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: DesignTokens.durationFast,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: value ? DesignTokens.primary.withValues(alpha: 0.06) : DesignTokens.surfaceVariant.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: value ? DesignTokens.primary.withValues(alpha: 0.3) : DesignTokens.outline.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: value ? DesignTokens.primary : DesignTokens.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: value ? DesignTokens.primary : DesignTokens.textPrimary),
                  ),
                  if (subtitle != null) Text(subtitle, style: TextStyle(fontSize: 11, color: DesignTokens.textSecondary)),
                ],
              ),
            ),
            if (infoTitle != null && infoBody != null)
              GestureDetector(
                onTap: () => _showInfoSheet(infoTitle, infoBody),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(Icons.info_outline_rounded, size: 16, color: DesignTokens.info.withValues(alpha: 0.5)),
                ),
              ),
            Semantics(
              label: label,
              child: SizedBox(
                height: 28,
                child: Switch.adaptive(
                  value: value,
                  onChanged: onChanged,
                  activeThumbColor: DesignTokens.primary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner(String text, IconData icon, Color color) {
    // FIX [HIGH] WCAG 2.1 AA: amber (#F59E0B) on white is ~2:1 contrast — fails 4.5:1.
    // Use DesignTokens.warningText (#92400E, ~7:1) for text when banner is warning-colored.
    final isWarning = color == DesignTokens.warning;
    final textColor = isWarning ? DesignTokens.warningText : color;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarginPreview(AddProductState state) {
    if (state.selectedSupplierCurrency != 'CAD') {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: DesignTokens.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: DesignTokens.warning.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 16, color: DesignTokens.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'product.margin_warning'.tr(namedArgs: {'currency': state.selectedSupplierCurrency}),
                style: TextStyle(fontSize: 12, color: DesignTokens.warning),
              ),
            ),
          ],
        ),
      );
    }

    final cost = double.tryParse(_costController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0;
    if (cost <= 0 || price <= 0) return const SizedBox.shrink();

    final margin = ((price - cost) / price * 100);
    final profit = price - cost;
    final isGood = margin > 30;
    final isOk = margin > 15;
    final color = isGood ? DesignTokens.success : (isOk ? DesignTokens.warning : DesignTokens.error);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withValues(alpha: 0.08), color.withValues(alpha: 0.03)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.05)]),
                ),
                child: Center(
                  child: Text(
                    '${margin.toStringAsFixed(0)}%',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'product.profit_margin'.tr(),
                      style: TextStyle(fontSize: 12, color: DesignTokens.textSecondary, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'product.per_unit'.tr(namedArgs: {'amount': profit.toStringAsFixed(2)}),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color),
                    ),
                  ],
                ),
              ),
              Icon(isGood ? Icons.trending_up_rounded : (isOk ? Icons.trending_flat_rounded : Icons.trending_down_rounded), color: color, size: 28),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityShippingDiscountsSection(AddProductViewModel viewModel, AddProductState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [DesignTokens.success.withValues(alpha: 0.04), DesignTokens.primary.withValues(alpha: 0.04)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.success.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: DesignTokens.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.local_offer_rounded, color: DesignTokens.success, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('product.bulk_shipping_discounts'.tr(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ),
              GestureDetector(
                onTap: () => _showInfoSheet('product.bulk_shipping_discounts'.tr(), 'product.bulk_discount_info_body'.tr()),
                child: Icon(Icons.info_outline_rounded, size: 18, color: DesignTokens.textDisabled),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('product.encourage_larger_orders'.tr(), style: TextStyle(color: DesignTokens.textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          _buildShippingDiscountTier(label: 'product.three_plus_items'.tr(), controller: _shippingDiscount3Controller, hint: '20'),
          const SizedBox(height: 8),
          _buildShippingDiscountTier(label: 'product.five_plus_items'.tr(), controller: _shippingDiscount5Controller, hint: '50'),
          if (state.discountTierError) ...[
            const SizedBox(height: 6),
            Text('product.discount_validation'.tr(), style: TextStyle(color: DesignTokens.error, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildGlassTextField(
                  controller: _additionalItemCostController,
                  label: 'product.cost_extra_item'.tr(),
                  prefixText: '\$',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGlassTextField(
                  controller: _maxItemsPerShipmentController,
                  label: 'product.max_per_shipment'.tr(),
                  keyboardType: TextInputType.number,
                  hint: 'product.unlimited_hint'.tr(),
                ),
              ),
            ],
          ),
          _buildTappableInfoHint('product.multi_item_learn_more'.tr(), 'product.multi_item_shipping_title'.tr(), 'product.multi_item_shipping_body'.tr()),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    Key? key,
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    required AddProductState state,
    required AddProductViewModel viewModel,
    required List<Widget> children,
  }) {
    return TapRegion(
      key: key,
      onTapInside: (_) {
        if (state.activeStep != index) viewModel.setActiveStep(index);
      },
      child: AnimatedContainer(
        duration: DesignTokens.durationNormal,
        decoration: BoxDecoration(
          color: DesignTokens.textOnPrimary,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: state.activeStep == index ? DesignTokens.primary.withValues(alpha: 0.3) : DesignTokens.outlineVariant,
            width: state.activeStep == index ? 1.5 : 1,
          ),
          boxShadow: state.activeStep == index
              ? [BoxShadow(color: DesignTokens.primary.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 4))]
              : DesignTokens.shadowSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(gradient: DesignTokens.primaryGradient, borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, color: DesignTokens.textOnPrimary, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: DesignTokens.darkSurface, letterSpacing: -0.3),
                        ),
                        const SizedBox(height: 2),
                        Text(subtitle, style: TextStyle(fontSize: 13, color: DesignTokens.textSecondary)),
                      ],
                    ),
                  ),
                  if (state.activeStep == index) Icon(Icons.edit_rounded, size: 18, color: DesignTokens.primary),
                ],
              ),
            ),
            const Divider(height: 24, indent: 20, endIndent: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShippingDiscountTier({required String label, required TextEditingController controller, required String hint}) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(color: DesignTokens.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 13),
            validator: (v) {
              if (v == null || v.isEmpty) return null;
              final val = double.tryParse(v);
              if (val == null || val < 0 || val > 100) return 'product.discount_range'.tr();
              return null;
            },
            decoration: InputDecoration(
              hintText: hint,
              suffixText: 'product.percent_off'.tr(),
              isDense: true,
              filled: true,
              fillColor: DesignTokens.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: DesignTokens.outline.withValues(alpha: 0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: DesignTokens.outline.withValues(alpha: 0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: DesignTokens.success, width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubcategorySelector(AddProductState state, AddProductViewModel viewModel) {
    final catId = int.tryParse(_categoryController.text) ?? 0;
    final subcategories = SubcategoryConstants.forCategoryId(catId);
    if (subcategories.isEmpty) return const SizedBox.shrink();
    return DropdownButtonFormField<String>(
      key: Key('addproduct_subcategory_$catId'),
      menuMaxHeight: ResponsiveBreakpoints.dropdownMaxHeight(context),
      initialValue: state.selectedSubcategory,
      decoration: InputDecoration(
        labelText: 'product.subcategory_optional'.tr(),
        prefixIcon: const Icon(Icons.subdirectory_arrow_right_rounded, size: 20),
        filled: true,
        fillColor: DesignTokens.surfaceVariant.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: DesignTokens.outline.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: DesignTokens.outline.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: DesignTokens.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: TextStyle(color: DesignTokens.textSecondary, fontSize: 13),
      ),
      hint: Text('product.select_subcategory'.tr(), style: TextStyle(color: DesignTokens.textSecondary, fontSize: 13)),
      items: subcategories
          .map(
            (s) => DropdownMenuItem(
              value: s,
              child: Text(s, style: const TextStyle(fontSize: 14)),
            ),
          )
          .toList(),
      onChanged: viewModel.setSubcategory,
    );
  }

  Widget _buildSubmitButton(AddProductState state, AddProductViewModel viewModel) {
    return Semantics(
      button: true,
      label: 'btn-publish-product',
      child: GestureDetector(
        // PROD-C4: also disable during video upload
        onTapDown: (state.isLoading || state.isUploadingVideo) ? null : (_) => HapticFeedback.mediumImpact(),
        child: AnimatedContainer(
          duration: DesignTokens.durationFast,
          height: 56,
          decoration: BoxDecoration(
            gradient: (state.isLoading || state.isUploadingVideo) ? null : DesignTokens.primaryGradient,
            color: (state.isLoading || state.isUploadingVideo) ? DesignTokens.outline : null,
            borderRadius: BorderRadius.circular(16),
            boxShadow: (state.isLoading || state.isUploadingVideo)
                ? []
                : [BoxShadow(color: DesignTokens.primary.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const Key('addproduct_submit_button'),
              borderRadius: BorderRadius.circular(16),
              onTap: (state.isLoading || state.isUploadingVideo)
                  ? null
                  : () {
                      if (!state.hasAttemptedSubmit) {
                        viewModel.setHasAttemptedSubmit(true);
                      }
                      if (state.discountTierError) return;
                      viewModel.clearError();
                      if (!_formKey.currentState!.validate()) {
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            key: const Key('addproduct_error_snackbar'),
                            content: Text('product.fix_errors_before_submit'.tr()),
                            backgroundColor: DesignTokens.error,
                            duration: const Duration(seconds: 5),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      {
                        final taxCode = _taxCodeController.text.trim();
                        final normalizedTaxCode = taxCode.isEmpty ? null : taxCode;

                        SupplierInfo? supplierInfo;
                        final hasCost = _costController.text.trim().isNotEmpty;
                        final hasSku = _supplierSkuController.text.trim().isNotEmpty;
                        final hasUrl = _supplierUrlController.text.trim().isNotEmpty;

                        if (hasCost || hasSku || hasUrl) {
                          supplierInfo = SupplierInfo(
                            type: state.selectedSupplierType,
                            cost: double.tryParse(_costController.text),
                            currency: state.selectedSupplierCurrency,
                            supplierSku: hasSku ? _supplierSkuController.text.trim() : null,
                            supplierUrl: hasUrl ? _supplierUrlController.text.trim() : null,
                            shippingDays: _supplierShippingDaysController.text.trim().isEmpty ? null : _supplierShippingDaysController.text.trim(),
                            hasTracking: state.hasTracking,
                            notes: _supplierNotesController.text.trim().isEmpty ? null : _supplierNotesController.text.trim(),
                          );
                        }

                        final inventoryConfig = InventoryConfig(
                          managed: state.inventoryManaged,
                          trackQuantity: state.trackQuantity,
                          allowBackorder: state.allowBackorder,
                          lowStockThreshold: state.lowStockAlertEnabled ? (int.tryParse(_lowStockThresholdController.text) ?? 5) : 0,
                        );

                        viewModel.addProduct(
                          name: _nameController.text.trim(),
                          description: _descriptionController.text.trim(),
                          nameF: _nameFController.text.trim().isEmpty ? null : _nameFController.text.trim(),
                          descriptionF: _descriptionFController.text.trim().isEmpty ? null : _descriptionFController.text.trim(),
                          price: double.tryParse(_priceController.text.trim()) ?? 0,
                          compareAtPrice: _compareAtPriceController.text.trim().isEmpty ? null : double.tryParse(_compareAtPriceController.text.trim()),
                          stock: state.selectedWarehouseIds.isEmpty ? (int.tryParse(_stockController.text.trim()) ?? 0) : 0,
                          categoryId: int.tryParse(_categoryController.text.trim()) ?? 0,
                          subcategory: state.selectedSubcategory,
                          street: _streetController.text.trim(),
                          apartment: _apartmentController.text.trim(),
                          city: _cityController.text.trim(),
                          postalCode: _postalCodeController.text.trim(),
                          weight: double.tryParse(_weightController.text),
                          length: double.tryParse(_lengthController.text),
                          width: double.tryParse(_widthController.text),
                          height: double.tryParse(_heightController.text),
                          taxCode: normalizedTaxCode,
                          deliveryOptions: _buildDeliveryOptions(state),
                          minimumOrderQuantity: int.tryParse(_minOrderController.text) ?? 1,
                          freeShipping: state.freeShipping,
                          cost: double.tryParse(_costController.text),
                          supplierSku: _supplierSkuController.text.trim().isEmpty ? null : _supplierSkuController.text.trim(),
                          supplierUrl: _supplierUrlController.text.trim().isEmpty ? null : _supplierUrlController.text.trim(),
                          supplier: supplierInfo,
                          inventory: inventoryConfig,
                          // PROD-C2: inform viewmodel whether seller has warehouses registered
                          sellerHasWarehouses: ref.read(sellerWarehousesStreamProvider).valueOrNull?.isNotEmpty == true,
                        );
                      }
                    },
              child: Center(
                // PROD-C4: show spinner for both full loading and video upload phase
                child: (state.isLoading || state.isUploadingVideo)
                    ? const ModernLoadingIndicator(size: 24, strokeWidth: 2.5, color: DesignTokens.textOnPrimary, centered: false)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.rocket_launch_rounded, color: DesignTokens.textOnPrimary, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'product.publish_product'.tr(),
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: DesignTokens.textOnPrimary, letterSpacing: 0.5),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: DesignTokens.secondary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: DesignTokens.darkSurface),
        ),
      ],
    );
  }

  Widget _buildSupplierInfoBadge(String supplierId) {
    final config = getSupplierConfig(supplierId);
    final deliveryRange = getSupplierDeliveryRange(supplierId);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: config.color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: config.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(config.icon, size: 18, color: config.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.translatedDisplayName,
                  style: TextStyle(fontWeight: FontWeight.w700, color: config.color, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  '${config.translatedRegion} · ${deliveryRange.minDays}-${deliveryRange.maxDays} days · ${config.translatedCountry}',
                  style: TextStyle(fontSize: 11, color: DesignTokens.textSecondary),
                ),
              ],
            ),
          ),
          if (config.isInternational)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [DesignTokens.info.withValues(alpha: 0.15), DesignTokens.info.withValues(alpha: 0.05)]),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'product.intl_label'.tr(),
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: DesignTokens.info),
              ),
            ),
        ],
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
            Icon(Icons.info_outline_rounded, size: 14, color: DesignTokens.info.withValues(alpha: 0.6)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(shortText, style: TextStyle(fontSize: 11, color: DesignTokens.textSecondary)),
            ),
            Icon(Icons.chevron_right_rounded, size: 14, color: DesignTokens.textDisabled),
          ],
        ),
      ),
    );
  }

  // FIX [HIGH] Inconsistent styling: was bare default TextFormField, now matches _buildGlassTextField.
  Widget _buildUrlField({required String label, required String placeholder, required String? value, required void Function(String?) onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          hintText: placeholder,
          prefixIcon: const Icon(Icons.link_rounded, size: 20),
          filled: true,
          fillColor: DesignTokens.surfaceVariant.withValues(alpha: 0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: DesignTokens.outline.withValues(alpha: 0.5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: DesignTokens.outline.withValues(alpha: 0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: DesignTokens.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: DesignTokens.error),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          labelStyle: const TextStyle(color: DesignTokens.textSecondary, fontSize: 13),
          hintStyle: const TextStyle(color: DesignTokens.textDisabled, fontSize: 13),
        ),
        keyboardType: TextInputType.url,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        onChanged: (v) => onChanged(v.trim().isEmpty ? null : v.trim()),
      ),
    );
  }

  Widget _buildVariantBuilderSection(AddProductState state, AddProductViewModel viewModel) {
    return _buildCollapsibleSection(
      key: const Key('addproduct_section_variants'),
      index: 5,
      icon: Icons.style_rounded,
      title: 'product.variant_builder'.tr(),
      subtitle: 'product.variant_builder_desc'.tr(),
      children: [
        _buildGlassToggle(
          key: const Key('addproduct_has_variants_toggle'),
          label: 'product.has_variants'.tr(),
          subtitle: 'product.has_variants_desc'.tr(),
          icon: Icons.tune_rounded,
          value: state.hasVariants,
          onChanged: viewModel.toggleHasVariants,
        ),
        if (state.hasVariants) ...[
          const SizedBox(height: 16),
          ...List.generate(state.variantOptions.length, (i) {
            final opt = state.variantOptions[i];
            return _VariantOptionCard(
              key: Key('variant_option_$i'),
              name: opt.name,
              values: opt.values,
              onRemove: () => viewModel.removeVariantOption(i),
              onUpdate: (newName, newValues) => viewModel.updateVariantOption(i, newName, newValues),
            );
          }),
          const SizedBox(height: 8),
          if (state.variantOptions.length < 3)
            _AddVariantOptionButton(existingNames: state.variantOptions.map((o) => o.name).toList(), onAdd: viewModel.addVariantOption),
          if (state.variants.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildSubSectionHeader('product.variant_combinations'.tr(namedArgs: {'count': state.variants.length.toString()}), Icons.grid_view_rounded),
            const SizedBox(height: 8),
            _buildInfoBanner('product.variant_combinations_info'.tr(), Icons.info_outline_rounded, DesignTokens.info),
            const SizedBox(height: 8),
            ...List.generate(state.variants.length, (i) {
              final variant = state.variants[i];
              return _VariantRow(
                key: Key('variant_row_$i'),
                optionValues: variant.optionValues,
                price: variant.priceDollars,
                stockQuantity: variant.stockQuantity,
                sku: variant.sku,
                onPriceChanged: (v) => viewModel.updateVariantPrice(i, v),
                onStockChanged: (v) => viewModel.updateVariantStock(i, v),
                onSkuChanged: (v) => viewModel.updateVariantSku(i, v),
              );
            }),
          ],
        ],
      ],
    );
  }

  Widget _buildWarehouseSelector(BuildContext context, AddProductState state, AddProductViewModel viewModel) {
    final warehousesAsync = ref.watch(sellerWarehousesStreamProvider);

    return warehousesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: ModernLoadingIndicator()),
      ),
      error: (e, _) => _buildInfoBanner('product.warehouse_load_error'.tr(namedArgs: {'error': e.toString()}), Icons.error_outline_rounded, DesignTokens.error),
      data: (warehouses) {
        if (warehouses.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSubSectionHeader('product.ships_from'.tr(), Icons.pin_drop_rounded),
              const SizedBox(height: 8),
              _buildInfoBanner('product.warehouse_no_locations_hint'.tr(), Icons.info_outline_rounded, DesignTokens.info),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('addproduct_manage_warehouses_button'),
                onPressed: () => Navigator.of(context).pushNamed(AppRoutes.sellerWarehouses),
                icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                label: Text('product.warehouse_add_button'.tr()),
                style: OutlinedButton.styleFrom(foregroundColor: DesignTokens.primary),
              ),
              const SizedBox(height: 16),
              _buildSubSectionHeader('product.warehouse_manual_address'.tr(), Icons.edit_location_alt_rounded),
              const SizedBox(height: 8),
              if (state.addressVerified)
                _buildInfoBanner('product.address_verified'.tr(), Icons.verified_rounded, DesignTokens.success)
              else if (_streetController.text.trim().isNotEmpty && !state.addressVerified)
                _buildInfoBanner('product.address_select_from_suggestions'.tr(), Icons.warning_amber_rounded, DesignTokens.warning),
              const SizedBox(height: 12),
              _buildGlassTextField(
                key: const Key('addproduct_street_field'),
                controller: _streetController,
                label: 'product.street_address'.tr(),
                icon: Icons.home_rounded,
                onChanged: viewModel.onStreetChanged,
                validator: _validateStreet,
                hint: 'product.street_hint'.tr(),
              ),
              if (state.showSuggestions && state.addressSuggestions.isNotEmpty) _buildAddressSuggestions(state, viewModel),
              const SizedBox(height: 12),
              _buildGlassTextField(
                controller: _apartmentController,
                label: 'product.apartment_unit'.tr(),
                icon: Icons.apartment_rounded,
                hint: 'product.apartment_hint'.tr(),
              ),
              const SizedBox(height: 12),
              _buildGlassTextField(
                key: const Key('addproduct_city_field'),
                controller: _cityController,
                label: 'product.city'.tr(),
                validator: _validateCity,
                readOnly: state.addressVerified,
                onChanged: state.addressVerified ? null : (_) => viewModel.clearCoordinates(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildGlassDropdown(
                      key: const Key('addproduct_province_dropdown'),
                      label: 'product.province'.tr(),
                      value: state.selectedProvince,
                      items: ProvinceCodeValues.names.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.key))).toList(),
                      onChanged: state.addressVerified ? null : (v) => viewModel.setProvince(v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildGlassTextField(
                      key: const Key('addproduct_postal_code_field'),
                      controller: _postalCodeController,
                      label: 'product.postal_code'.tr(),
                      textCapitalization: TextCapitalization.characters,
                      validator: _validatePostalCode,
                      readOnly: state.addressVerified,
                      onChanged: state.addressVerified ? null : (_) => viewModel.clearCoordinates(),
                    ),
                  ),
                ],
              ),
              if (state.addressVerified) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    key: const Key('addproduct_clear_address_button'),
                    onPressed: () {
                      _streetController.clear();
                      _cityController.clear();
                      _postalCodeController.clear();
                      viewModel.clearCoordinates();
                    },
                    icon: const Icon(Icons.clear_rounded, size: 16),
                    label: Text('product.clear_address'.tr(), style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildSubSectionHeader('product.ships_from'.tr(), Icons.warehouse_rounded),
                const Spacer(),
                TextButton.icon(
                  key: const Key('addproduct_manage_warehouses_button'),
                  onPressed: () => Navigator.of(context).pushNamed(AppRoutes.sellerWarehouses),
                  icon: const Icon(Icons.settings_rounded, size: 14),
                  label: Text('product.warehouse_manage'.tr(), style: const TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: DesignTokens.primary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Tooltip(
                    message: 'product.warehouse_ships_from_tooltip'.tr(),
                    triggerMode: TooltipTriggerMode.tap,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline_rounded, size: 14, color: DesignTokens.textTertiary),
                        const SizedBox(width: 4),
                        Text('product.warehouse_select_hint'.tr(), style: TextStyle(fontSize: 12, color: DesignTokens.textTertiary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ...warehouses.map((warehouse) {
              final isSelected = state.selectedWarehouseIds.contains(warehouse.warehouseId);
              final stockQty = state.warehouseStockMap[warehouse.warehouseId] ?? 0;
              final typeIcon = warehouse.type == WarehouseTypeValues.warehouse ? Icons.warehouse_rounded : Icons.home_work_rounded;
              return Padding(
                key: Key('addproduct_warehouse_${warehouse.warehouseId}'),
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? Color.fromRGBO(102, 126, 234, 0.08) : DesignTokens.surfaceVariant,
                    borderRadius: BorderRadius.circular(DesignTokens.radius12),
                    border: Border.all(color: isSelected ? DesignTokens.primary : DesignTokens.outline, width: isSelected ? 1.5 : 1),
                  ),
                  child: Column(
                    children: [
                      CheckboxListTile(
                        key: Key('addproduct_warehouse_checkbox_${warehouse.warehouseId}'),
                        value: isSelected,
                        onChanged: (_) => viewModel.toggleWarehouseSelection(warehouse.warehouseId),
                        title: Row(
                          children: [
                            Icon(typeIcon, size: 16, color: DesignTokens.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(warehouse.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            ),
                            if (warehouse.isDefault)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Color.fromRGBO(102, 126, 234, 0.15), borderRadius: BorderRadius.circular(6)),
                                child: Text(
                                  'product.warehouse_default_label'.tr(),
                                  style: TextStyle(fontSize: 10, color: DesignTokens.primary, fontWeight: FontWeight.w600),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          '${warehouse.address.city}, ${warehouse.address.state} · ${warehouse.address.postalCode}',
                          style: TextStyle(fontSize: 12, color: DesignTokens.textSecondary),
                        ),
                        controlAffinity: ListTileControlAffinity.trailing,
                        checkColor: Colors.white,
                        fillColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? DesignTokens.primary : null),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radius12)),
                      ),
                      if (isSelected) ...[
                        Divider(height: 1, color: DesignTokens.outline),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                          child: Row(
                            children: [
                              Icon(Icons.inventory_2_rounded, size: 16, color: DesignTokens.textTertiary),
                              const SizedBox(width: 8),
                              Text('product.warehouse_stock_at_location'.tr(), style: TextStyle(fontSize: 13, color: DesignTokens.textSecondary)),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 80,
                                child: TextFormField(
                                  key: Key('addproduct_warehouse_stock_${warehouse.warehouseId}'),
                                  initialValue: stockQty > 0 ? stockQty.toString() : '',
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  decoration: InputDecoration(
                                    hintText: '0',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    isDense: true,
                                  ),
                                  onChanged: (v) => viewModel.setWarehouseStock(warehouse.warehouseId, int.tryParse(v) ?? 0),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('product.warehouse_units'.tr(), style: TextStyle(fontSize: 12, color: DesignTokens.textTertiary)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
            if (state.selectedWarehouseIds.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('product.warehouse_select_required'.tr(), style: TextStyle(fontSize: 12, color: DesignTokens.error)),
              ),
            if (state.selectedWarehouseIds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.inventory_rounded, size: 14, color: DesignTokens.success),
                    const SizedBox(width: 6),
                    Text(
                      state.selectedWarehouseIds.length > 1
                          ? 'product.warehouse_total_stock_plural'.tr(
                              namedArgs: {
                                'total': state.warehouseStockMap.values.fold(0, (a, b) => a + b).toString(),
                                'count': state.selectedWarehouseIds.length.toString(),
                              },
                            )
                          : 'product.warehouse_total_stock'.tr(
                              namedArgs: {
                                'total': state.warehouseStockMap.values.fold(0, (a, b) => a + b).toString(),
                                'count': state.selectedWarehouseIds.length.toString(),
                              },
                            ),
                      style: TextStyle(fontSize: 12, color: DesignTokens.success, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  void _onSuccess() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const Key('addproduct_success_snackbar'),
        content: Row(
          children: [
            Icon(Icons.hourglass_top_rounded, color: DesignTokens.textOnPrimary, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('product.under_review_title'.tr(), style: TextStyle(fontWeight: FontWeight.w700)),
                  Text('product.under_review_subtitle'.tr(), style: TextStyle(fontSize: 12, color: DesignTokens.textOnPrimary.withValues(alpha: 0.7))),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: DesignTokens.warning, // FIX [LOW] Was hardcoded Color(0xFFF59E0B)
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 5),
      ),
    );
    Navigator.pop(context);
  }

  /// PROD-C1: Clears all text controllers so the form is blank when re-entering after a successful submit.
  void _resetControllers() {
    _nameController.clear();
    _nameFController.clear();
    _descriptionController.clear();
    _descriptionFController.clear();
    _priceController.clear();
    _compareAtPriceController.clear();
    _categoryController.clear();
    _streetController.clear();
    _apartmentController.clear();
    _cityController.clear();
    _postalCodeController.clear();
    _stockController.text = '1';
    _minOrderController.text = '1';
    _weightController.clear();
    _lengthController.clear();
    _widthController.clear();
    _heightController.clear();
    _taxCodeController.clear();
    _costController.clear();
    _supplierSkuController.clear();
    _sellerSkuController.clear();
    _supplierUrlController.clear();
    _supplierShippingDaysController.text = '7-15';
    _supplierNotesController.clear();
    _customSupplierNameController.clear();
    _lowStockThresholdController.text = '5';
    _standardDaysController.text = '5';
    _standardPriceController.text = '0.00';
    _expressDaysController.text = '2';
    _expressPriceController.text = '9.99';
    _sameDayPriceController.text = '14.99';
    _shippingDiscount3Controller.clear();
    _shippingDiscount5Controller.clear();
    _additionalItemCostController.text = '0.00';
    _maxItemsPerShipmentController.text = '0';
  }

  // FIX [MEDIUM] Missing SafeArea: bottom sheet content was clipped on notched devices.
  void _showInfoSheet(String title, String body) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        minimum: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: DesignTokens.textOnPrimary,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, -4))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: DesignTokens.info.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.lightbulb_rounded, color: DesignTokens.info, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: DesignTokens.darkSurface),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: DesignTokens.surfaceVariant, shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded, size: 16, color: DesignTokens.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(body, style: TextStyle(fontSize: 14, color: DesignTokens.textPrimary, height: 1.6)),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ), // SafeArea
    );
  }

  String? _validateCity(String? v) {
    if (v == null || v.trim().isEmpty) return 'common.required'.tr();
    if (v.trim().length < 2) return 'product.city_too_short'.tr();
    if (v.trim().length > 50) return 'product.city_too_long'.tr();
    return null;
  }

  void _validateDiscountTiers() {
    final d3 = double.tryParse(_shippingDiscount3Controller.text);
    final d5 = double.tryParse(_shippingDiscount5Controller.text);
    final hasError = d3 != null && d5 != null && d5 < d3;
    final state = ref.read(addProductViewModelProvider);
    if (hasError != state.discountTierError) {
      ref.read(addProductViewModelProvider.notifier).setDiscountTierError(hasError);
    }
  }

  String? _validatePostalCode(String? v) {
    if (v == null || v.isEmpty) return 'common.required'.tr();
    final normalized = v.toUpperCase().replaceAll(' ', '').trim();
    final reg = RegExp(r'^[A-Z]\d[A-Z]\d[A-Z]\d$');
    if (!reg.hasMatch(normalized)) return 'product.invalid_postal'.tr();
    return null;
  }

  String? _validateStreet(String? v) {
    if (v == null || v.trim().isEmpty) return 'common.required'.tr();
    if (v.trim().length < 3) return 'product.street_too_short'.tr();
    if (v.trim().length > 100) return 'product.street_too_long'.tr();
    return null;
  }
}

class _AddVariantOptionButton extends StatelessWidget {
  final List<String> existingNames;
  final void Function(String name, List<String> values) onAdd;

  const _AddVariantOptionButton({required this.existingNames, required this.onAdd});

  Map<String, List<String>> get _presets => {
    'product.preset_size'.tr(): 'product.preset_size_values'.tr().split(', '),
    'product.preset_color'.tr(): 'product.preset_color_values'.tr().split(', '),
    'product.preset_material'.tr(): 'product.preset_material_values'.tr().split(', '),
  };

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: const Key('addproduct_add_variant_option_button'),
      onPressed: () => _showAddDialog(context),
      icon: const Icon(Icons.add_rounded, size: 18),
      label: Text('product.add_variant_option_btn'.tr()),
      style: OutlinedButton.styleFrom(
        foregroundColor: DesignTokens.secondary,
        side: BorderSide(color: DesignTokens.secondary.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final available = _presets.keys.where((k) => !existingNames.contains(k)).toList();
    final nameCtrl = TextEditingController();
    final valuesCtrl = TextEditingController();
    String? selectedPreset;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('product.add_variant_option'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (available.isNotEmpty) ...[
                Text('product.quick_add'.tr(), style: const TextStyle(fontSize: 12, color: DesignTokens.textSecondary)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: available.map((preset) {
                    final isSelected = selectedPreset == preset;
                    return ChoiceChip(
                      label: Text(preset),
                      selected: isSelected,
                      onSelected: (v) {
                        setDialogState(() {
                          selectedPreset = v ? preset : null;
                          if (v) {
                            nameCtrl.text = preset;
                            valuesCtrl.text = _presets[preset]!.join(', ');
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const Divider(height: 20),
              ],
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: 'product.option_name'.tr(), hintText: 'product.eg_size'.tr()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: valuesCtrl,
                decoration: InputDecoration(labelText: 'product.option_values_hint'.tr(), hintText: 'product.eg_size_values'.tr()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('common.cancel'.tr())),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final values = valuesCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                if (name.isNotEmpty && values.isNotEmpty) {
                  onAdd(name, values);
                }
                Navigator.pop(ctx);
              },
              child: Text('common.add'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

class _DigitalTypeCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _DigitalTypeCard({super.key, required this.label, required this.icon, required this.selected, required this.onTap});

  // FIX [HIGH] Design-system violation: replaced Theme.of(context).colorScheme with DesignTokens.
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: DesignTokens.durationFast,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? DesignTokens.primary.withValues(alpha: 0.08) : DesignTokens.surfaceVariant.withValues(alpha: 0.5),
            border: Border.all(color: selected ? DesignTokens.primary : DesignTokens.outline.withValues(alpha: 0.3), width: selected ? 2 : 1),
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected ? [BoxShadow(color: DesignTokens.primary.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 2))] : null,
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? DesignTokens.primary : DesignTokens.textSecondary, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                  color: selected ? DesignTokens.primary : DesignTokens.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VariantOptionCard extends StatelessWidget {
  final String name;
  final List<String> values;
  final VoidCallback onRemove;
  final void Function(String name, List<String> values) onUpdate;

  const _VariantOptionCard({super.key, required this.name, required this.values, required this.onRemove, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceVariant.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DesignTokens.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.label_rounded, size: 16, color: DesignTokens.secondary),
              const SizedBox(width: 6),
              Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const Spacer(),
              GestureDetector(
                onTap: () => _showEditDialog(context),
                child: Icon(Icons.edit_rounded, size: 16, color: DesignTokens.primary),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onRemove,
                child: Icon(Icons.close_rounded, size: 16, color: DesignTokens.error),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: values
                .map(
                  (v) => Chip(
                    label: Text(v, style: const TextStyle(fontSize: 12)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    backgroundColor: DesignTokens.surface,
                    side: BorderSide(color: DesignTokens.outline.withValues(alpha: 0.3)),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: name);
    final valuesCtrl = TextEditingController(text: values.join(', '));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('product.edit_option'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(labelText: 'product.option_name'.tr()),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: valuesCtrl,
              decoration: InputDecoration(labelText: 'product.option_values_hint'.tr()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('common.cancel'.tr())),
          FilledButton(
            onPressed: () {
              final newName = nameCtrl.text.trim();
              final newValues = valuesCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              if (newName.isNotEmpty && newValues.isNotEmpty) {
                onUpdate(newName, newValues);
              }
              Navigator.pop(ctx);
            },
            child: Text('common.save'.tr()),
          ),
        ],
      ),
    ).then((_) {
      nameCtrl.dispose();
      valuesCtrl.dispose();
    });
  }
}

class _VariantRow extends StatelessWidget {
  final Map<String, String> optionValues;
  final double? price;
  final int stockQuantity;
  final String? sku;
  final void Function(double?) onPriceChanged;
  final void Function(int) onStockChanged;
  final void Function(String?) onSkuChanged;

  const _VariantRow({
    super.key,
    required this.optionValues,
    required this.price,
    required this.stockQuantity,
    required this.sku,
    required this.onPriceChanged,
    required this.onStockChanged,
    required this.onSkuChanged,
  });

  @override
  Widget build(BuildContext context) {
    final label = optionValues.values.join(' / ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: DesignTokens.textOnPrimary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DesignTokens.outline.withValues(alpha: 0.15)),
      ),
      // FIX [HIGH] Design inconsistency: _VariantRow fields now match glass styling used everywhere else.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(color: DesignTokens.secondary.withValues(alpha: 0.6), shape: BoxShape.circle),
              ),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: DesignTokens.darkSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: price?.toStringAsFixed(2),
                  decoration: _variantFieldDecoration('product.price_dollar'.tr(), prefixText: '\$ '),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  onChanged: (v) => onPriceChanged(double.tryParse(v)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: stockQuantity.toString(),
                  decoration: _variantFieldDecoration('product.stock'.tr()),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  onChanged: (v) => onStockChanged(int.tryParse(v) ?? 0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: sku,
                  decoration: _variantFieldDecoration('product.sku'.tr()),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  onChanged: (v) => onSkuChanged(v.trim().isEmpty ? null : v.trim()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Shared compact glass decoration for variant fields.
  static InputDecoration _variantFieldDecoration(String label, {String? prefixText}) {
    return InputDecoration(
      labelText: label,
      prefixText: prefixText,
      isDense: true,
      filled: true,
      fillColor: DesignTokens.surfaceVariant.withValues(alpha: 0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: DesignTokens.outline.withValues(alpha: 0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: DesignTokens.outline.withValues(alpha: 0.25)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: DesignTokens.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: DesignTokens.error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      labelStyle: const TextStyle(color: DesignTokens.textSecondary, fontSize: 11),
    );
  }
}
