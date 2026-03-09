// coverage:ignore-file
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/utils/responsive_layout.dart';
import 'package:origna_gta/utils/utils.dart';
import 'package:origna_gta/widgets/custom_app_bar.dart';
import 'package:origna_gta/widgets/modern_button.dart';

import '../features/profile/address_viewmodel.dart';

// ─── Flutter Previews ────────────────────────────────────────────────────────

/// Documentation for AddEditAddressScreen
class AddEditAddressScreen extends ConsumerStatefulWidget {
  final Address? address;
  const AddEditAddressScreen({super.key, this.address});

  @override
  ConsumerState<AddEditAddressScreen> createState() => _AddEditAddressScreenState();
}

class _AddEditAddressScreenState extends ConsumerState<AddEditAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _streetController = TextEditingController();
  final _apartmentController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addressViewModelProvider);
    final viewModel = ref.read(addressViewModelProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen(addressViewModelProvider, (previous, next) {
      if (next.isSuccess) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text('address.saved_success'.tr()),
            backgroundColor: DesignTokens.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radius12)),
          ),
        );
      } else if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: DesignTokens.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radius12)),
          ),
        );
      }
    });

    return Container(
      decoration: BoxDecoration(gradient: DesignTokens.backgroundGradient(isDark: isDark)),
      child: Scaffold(
        appBar: AppBarFactory.simple(title: widget.address == null ? 'address.add_address'.tr() : 'address.edit_address'.tr()),
        backgroundColor: Colors.transparent,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(DesignTokens.spacing20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Address Label Section
                    _buildSectionTitle('address.label'.tr(), Icons.label_outlined),
                    const SizedBox(height: DesignTokens.spacing12),
                    Wrap(
                      spacing: 10,
                      children: [AddressLabelValues.home, AddressLabelValues.work, AddressLabelValues.other].map((label) {
                        final isSelected = state.selectedLabel == label;
                        final displayLabel = label == AddressLabelValues.home
                            ? 'address.home'.tr()
                            : label == AddressLabelValues.work
                            ? 'address.work'.tr()
                            : 'address.other'.tr();
                        return Semantics(
                          button: true,
                          label: 'chip-address-label-${label.toLowerCase()}',
                          selected: isSelected,
                          child: ChoiceChip(
                            label: Text(displayLabel),
                            selected: isSelected,
                            onSelected: (selected) => viewModel.setLabel(label),
                            selectedColor: DesignTokens.primary,
                            backgroundColor: isDark ? DesignTokens.darkSurface : Colors.white,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : (isDark ? Colors.white : DesignTokens.textPrimary),
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(DesignTokens.radius12),
                              side: BorderSide(color: isSelected ? DesignTokens.primary : (isDark ? DesignTokens.textPrimary : DesignTokens.outlineVariant)),
                            ),
                            elevation: isSelected ? 2 : 0,
                            shadowColor: DesignTokens.primary.withValues(alpha: 0.3),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: DesignTokens.spacing24),

                    // Address Details Section
                    _buildSectionTitle('address.details'.tr(), Icons.location_on_outlined),
                    const SizedBox(height: DesignTokens.spacing12),

                    GlassContainer(
                      child: Column(
                        children: [
                          _buildTextField(
                            key: const Key('address_street_field'),
                            controller: _streetController,
                            label: 'address.street'.tr(),
                            icon: Icons.location_on_outlined,
                            onChanged: viewModel.onStreetChanged,
                            validator: (v) => v?.isEmpty ?? true ? 'common.required'.tr() : null,
                          ),
                          if (state.showSuggestions && state.addressSuggestions.isNotEmpty)
                            Container(
                              key: const Key('address_suggestions'),
                              margin: const EdgeInsets.only(top: 8, bottom: 8),
                              decoration: BoxDecoration(
                                color: isDark ? DesignTokens.darkSurface : Colors.white,
                                borderRadius: BorderRadius.circular(DesignTokens.radius12),
                                boxShadow: DesignTokens.shadowMd,
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: state.addressSuggestions.length,
                                itemBuilder: (context, i) {
                                  final s = state.addressSuggestions[i];
                                  return ListTile(
                                    leading: Icon(Icons.location_on, color: DesignTokens.primary, size: 20),
                                    title: Text(
                                      s['properties']?['formatted'] ?? '',
                                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : DesignTokens.textPrimary),
                                    ),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radius8)),
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

                                      final fullStreet = (houseNumber.isNotEmpty && street.isNotEmpty)
                                          ? '$houseNumber $street'
                                          : (street.isNotEmpty ? street : formatted);

                                      _streetController.text = fullStreet;
                                      _cityController.text = s['properties']?['city'] ?? '';
                                      _postalCodeController.text = s['properties']?['postcode'] ?? '';
                                    },
                                  );
                                },
                              ),
                            ),
                          const SizedBox(height: DesignTokens.spacing16),
                          _buildTextField(
                            key: const Key('address_apartment_field'),
                            controller: _apartmentController,
                            label: 'address.apartment_optional'.tr(),
                            icon: Icons.apartment_outlined,
                          ),
                          const SizedBox(height: DesignTokens.spacing16),
                          _buildTextField(
                            key: const Key('address_city_field'),
                            controller: _cityController,
                            label: 'address.city'.tr(),
                            icon: Icons.location_city_outlined,
                            validator: (v) => v?.isEmpty ?? true ? 'common.required'.tr() : null,
                          ),
                          const SizedBox(height: DesignTokens.spacing16),
                          DropdownButtonFormField<String>(
                            key: ValueKey(state.selectedProvince),
                            isExpanded: true,
                            menuMaxHeight: ResponsiveBreakpoints.dropdownMaxHeight(context),
                            initialValue: state.selectedProvince,
                            decoration: InputDecoration(
                              labelText: 'address.province'.tr(),
                              prefixIcon: Icon(Icons.map_outlined, color: DesignTokens.primary.withValues(alpha: 0.7)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(DesignTokens.radius12),
                                borderSide: BorderSide(color: isDark ? DesignTokens.textPrimary : DesignTokens.outlineVariant),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(DesignTokens.radius12),
                                borderSide: BorderSide(color: isDark ? DesignTokens.textPrimary : DesignTokens.outlineVariant),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(DesignTokens.radius12),
                                borderSide: const BorderSide(color: DesignTokens.primary, width: 2),
                              ),
                              filled: true,
                              fillColor: isDark ? DesignTokens.darkSurface : Colors.white,
                            ),
                            items: ProvinceCodeValues.all
                                .map((code) => DropdownMenuItem(value: code, child: Text('${ProvinceCodeValues.names[code]} ($code)')))
                                .toList(),
                            onChanged: (v) => viewModel.setProvince(v!),
                          ),
                          const SizedBox(height: DesignTokens.spacing16),
                          _buildTextField(
                            key: const Key('address_postal_code_field'),
                            controller: _postalCodeController,
                            label: 'address.postal_code'.tr(),
                            icon: Icons.markunread_mailbox_outlined,
                            textCapitalization: TextCapitalization.characters,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'common.required'.tr();
                              final cleaned = v.replaceAll(' ', '').toUpperCase();
                              if (!RegExp(r'^[A-Z]\d[A-Z]\d[A-Z]\d$').hasMatch(cleaned)) {
                                return 'address.valid_postal'.tr();
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: DesignTokens.spacing16),
                          _buildTextField(
                            key: const Key('address_phone_field'),
                            controller: _phoneController,
                            label: 'address.phone'.tr(),
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'common.required'.tr();
                              final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                              if (digits.length < 10 || digits.length > 15) {
                                return 'address.valid_phone'.tr();
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: DesignTokens.spacing16),

                    // Set as default toggle
                    SwitchListTile(
                      value: state.isDefault,
                      onChanged: (v) => viewModel.setDefault(v),
                      title: Text(
                        'address.set_as_default'.tr(),
                        style: TextStyle(color: isDark ? Colors.white : DesignTokens.textPrimary, fontWeight: FontWeight.w600),
                      ),
                      activeThumbColor: DesignTokens.primary,
                      activeTrackColor: DesignTokens.primary.withValues(alpha: 0.5),
                      contentPadding: EdgeInsets.zero,
                      tileColor: Colors.transparent,
                    ),

                    const SizedBox(height: DesignTokens.spacing24),

                    Semantics(
                      button: true,
                      label: 'btn-save-address',
                      child: ModernButton(
                        key: const Key('btn_save_address'),
                        label: state.isLoading ? 'address.saving'.tr() : 'address.save_address'.tr(),
                        imageIcon: 'assets/icons/save_icon.png',
                        isLoading: state.isLoading,
                        onPressed: state.isLoading
                            ? null
                            : () {
                                if (_formKey.currentState!.validate()) {
                                  viewModel.saveAddress(
                                    street: _streetController.text,
                                    apartment: _apartmentController.text,
                                    city: _cityController.text,
                                    postalCode: _postalCodeController.text,
                                    phoneNumber: _phoneController.text,
                                  );
                                }
                              },
                      ),
                    ),

                    const SizedBox(height: DesignTokens.spacing32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _streetController.dispose();
    _apartmentController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.address != null) {
      _streetController.text = widget.address!.street;
      _cityController.text = widget.address!.city;
      _postalCodeController.text = widget.address!.postalCode;
      _apartmentController.text = widget.address!.apartment;
      _phoneController.text = widget.address!.phoneNumber ?? '';
    }
    Future.microtask(() => ref.read(addressViewModelProvider.notifier).setInitialData(widget.address));
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [DesignTokens.primary.withValues(alpha: 0.15), DesignTokens.secondary.withValues(alpha: 0.15)]),
            borderRadius: BorderRadius.circular(DesignTokens.radius8),
          ),
          child: Icon(icon, size: 18, color: DesignTokens.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : DesignTokens.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    Key? key,
    required TextEditingController controller,
    required String label,
    IconData? icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      key: key,
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
      validator: validator,
      style: TextStyle(color: isDark ? Colors.white : DesignTokens.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, color: DesignTokens.primary.withValues(alpha: 0.7)) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius12),
          borderSide: BorderSide(color: isDark ? DesignTokens.textPrimary : DesignTokens.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius12),
          borderSide: BorderSide(color: isDark ? DesignTokens.textPrimary : DesignTokens.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius12),
          borderSide: const BorderSide(color: DesignTokens.primary, width: 2),
        ),
        filled: true,
        fillColor: isDark ? DesignTokens.darkSurface : Colors.white,
      ),
    );
  }
}
