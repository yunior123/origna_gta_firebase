// coverage:ignore-file
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/features/admin/admin_providers.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/utils/utils.dart';
import 'package:origna_gta/widgets/modern_loading_indicator.dart';

/// Admin tab for managing payment providers
class AdminPaymentProvidersTab extends ConsumerStatefulWidget {
  const AdminPaymentProvidersTab({super.key});

  @override
  ConsumerState<AdminPaymentProvidersTab> createState() => _AdminPaymentProvidersTabState();
}

class _AdminPaymentProvidersTabState extends ConsumerState<AdminPaymentProvidersTab> {
  Map<String, dynamic>? _providersData;
  bool _isLoading = true;
  String? _error;
  final TextEditingController _reasonController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadProviders,
      child: _isLoading
          ? const ModernLoadingIndicator.fullScreen()
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: DesignTokens.error.withValues(alpha: 0.1), shape: BoxShape.circle),
                        child: Icon(Icons.error_outline_rounded, size: 36, color: DesignTokens.error),
                      ),
                      const SizedBox(height: 16),
                      Text(_error!, style: TextStyle(color: DesignTokens.error)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadProviders,
                        icon: const Icon(Icons.refresh),
                        label: Text('common.retry'.tr()),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Header card
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radius16)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: DesignTokens.primaryGradient,
                                    borderRadius: BorderRadius.circular(DesignTokens.radius12),
                                  ),
                                  child: const Icon(Icons.payment_rounded, color: Colors.white, size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('admin.payments.title'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 2),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'admin.payments.description'.tr(),
                              style: TextStyle(color: DesignTokens.textSecondary, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: DesignTokens.warning.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(DesignTokens.radius12),
                                border: Border.all(color: DesignTokens.warning.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: DesignTokens.warning, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'admin.payments.warning_at_least_one'.tr(),
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Provider cards
                    if (_providersData != null) ...[
                      _buildProviderCard(
                        provider: PaymentProviderValues.stripe,
                        name: 'admin.payments.stripe_name'.tr(),
                        icon: Icons.credit_card,
                        description: 'admin.payments.stripe_desc'.tr(),
                        features: [
                          'admin.payments.stripe_feature_1'.tr(),
                          'admin.payments.stripe_feature_2'.tr(),
                          'admin.payments.stripe_feature_3'.tr(),
                          'admin.payments.stripe_feature_4'.tr(),
                        ],
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Enabled providers summary
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radius16)),
                      color: DesignTokens.success.withValues(alpha: 0.06),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: DesignTokens.success.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.check_circle_rounded, color: DesignTokens.success, size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('admin.payments.enabled_providers'.tr(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: DesignTokens.success)),
                                  const SizedBox(height: 4),
                                  Text(_getEnabledProvidersList(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: DesignTokens.success)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Widget _buildProviderCard({
    required String provider,
    required String name,
    required IconData icon,
    required String description,
    required List<String> features,
  }) {
    final providers = _providersData?[ApiKeys.providers] as Map<String, dynamic>? ?? {};
    final providerData = providers[provider] as Map<String, dynamic>? ?? {};
    final isEnabled = providerData[ApiKeys.enabled] as bool? ?? false;
    final isConfigured = providerData[ApiKeys.configured] as bool? ?? false;
    final missingKeys = (providerData[ApiKeys.missingKeys] as List<dynamic>?)?.cast<String>() ?? [];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.radius16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isEnabled ? DesignTokens.primary.withValues(alpha: 0.1) : DesignTokens.surface,
                    borderRadius: BorderRadius.circular(DesignTokens.radius12),
                  ),
                  child: Icon(icon, size: 28, color: isEnabled ? DesignTokens.primary : DesignTokens.textSecondary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!isConfigured)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: DesignTokens.warning.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'admin.payments.not_configured'.tr(),
                                style: const TextStyle(fontSize: 10, color: DesignTokens.warning, fontWeight: FontWeight.w600),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: DesignTokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isEnabled,
                  onChanged: isConfigured || isEnabled
                      ? (value) => _toggleProvider(provider, name, value, isConfigured)
                      : null,
                  activeTrackColor: DesignTokens.primary,
                ),
              ],
            ),
            
            // Warning if not configured
            if (!isConfigured) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DesignTokens.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: DesignTokens.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: DesignTokens.warning, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        missingKeys.isNotEmpty 
                            ? 'admin.payments.missing_keys'.tr(namedArgs: {'keys': missingKeys.join(", ")}) 
                            : 'admin.payments.not_configured_desc'.tr(namedArgs: {'name': name}),
                        style: TextStyle(fontSize: 12, color: DesignTokens.warning),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: features
                  .map(
                    (feature) => Chip(
                      label: Text(
                        feature,
                        style: TextStyle(fontSize: 12, color: isEnabled ? DesignTokens.primary : DesignTokens.textSecondary),
                      ),
                      backgroundColor: isEnabled ? DesignTokens.primary.withValues(alpha: 0.08) : DesignTokens.surface,
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  isEnabled ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: 18,
                  color: isEnabled ? DesignTokens.success : DesignTokens.error,
                ),
                const SizedBox(width: 8),
                Text(
                  isEnabled ? 'admin.payments.accepting'.tr() : 'admin.payments.not_accepting'.tr(),
                  style: TextStyle(
                    fontSize: 13,
                    color: isEnabled ? DesignTokens.success : DesignTokens.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getEnabledProvidersList() {
    final enabledProviders = _providersData?[ApiKeys.enabledProviders] as List<dynamic>? ?? [];
    if (enabledProviders.isEmpty) {
      return 'common.none'.tr();
    }
    return enabledProviders.map((p) => p.toString().toUpperCase()).join(', ');
  }

  Future<void> _loadProviders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final adminRepo = ref.read(adminRepositoryProvider);
      final data = await adminRepo.getPaymentProviders();
      
      if (mounted) {
        setState(() {
          _providersData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'admin.payments.error_loading'.tr();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleProvider(String provider, String name, bool enable, bool isConfigured) async {
    // If trying to enable but not configured, show info dialog
    if (enable && !isConfigured) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: DesignTokens.warning),
              const SizedBox(width: 12),
              Text('admin.payments.not_configured_title'.tr(namedArgs: {'name': name})),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'admin.payments.not_configured_dialog_desc'.tr(namedArgs: {'name': name}),
                style: TextStyle(color: DesignTokens.textPrimary),
              ),
              const SizedBox(height: 16),
              Text(
                'admin.payments.steps_title'.tr(namedArgs: {'name': name}),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '${'admin.payments.step_1'.tr(namedArgs: {'name': name})}\n'
                '${'admin.payments.step_2'.tr(namedArgs: {'name': name})}\n'
                '${'admin.payments.step_3'.tr()}\n'
                '${'admin.payments.step_4'.tr()}',
                style: TextStyle(color: DesignTokens.textSecondary, fontSize: 13),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignTokens.primary,
                foregroundColor: Colors.white,
              ),
              child: Text('common.got_it'.tr()),
            ),
          ],
        ),
      );
      return;
    }

    // Show confirmation dialog
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(enable ? 'admin.payments.enable_title'.tr(namedArgs: {'name': name}) : 'admin.payments.disable_title'.tr(namedArgs: {'name': name})),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              enable
                  ? 'admin.payments.enable_desc'.tr(namedArgs: {'name': name})
                  : 'admin.payments.disable_desc'.tr(namedArgs: {'name': name}),
              style: TextStyle(color: DesignTokens.textPrimary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(
                labelText: 'admin.payments.reason_label'.tr(),
                hintText: 'admin.payments.reason_hint'.tr(),
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _reasonController.clear();
              Navigator.pop(context);
            },
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = _reasonController.text;
              _reasonController.clear();
              Navigator.pop(context, reason);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: enable ? DesignTokens.primary : DesignTokens.error,
              foregroundColor: Colors.white,
            ),
            child: Text(enable ? 'admin.payments.enable_action'.tr() : 'admin.payments.disable_action'.tr()),
          ),
        ],
      ),
    );

    // If dialog was dismissed without confirmation
    if (reason == null) return;

    // Show loading
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ModernLoadingIndicator.fullScreen(),
    );

    try {
      final adminRepo = ref.read(adminRepositoryProvider);
      await adminRepo.updatePaymentProvider(provider, enable, reason: reason);
      
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      
      // Reload data
      await _loadProviders();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(enable ? 'admin.payments.success_enabled'.tr(namedArgs: {'name': name}) : 'admin.payments.success_disabled'.tr(namedArgs: {'name': name})),
          backgroundColor: DesignTokens.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      
      // Extract meaningful error message
      String errorMessage = AppError.getMessage(e, 'admin.payments.error_failed_update'.tr(namedArgs: {'name': name}));
      if (errorMessage.contains('not configured')) {
        errorMessage = 'admin.payments.error_not_configured'.tr(namedArgs: {'name': name});
      } else if (errorMessage.contains('Missing API keys')) {
        errorMessage = 'admin.payments.error_keys_missing'.tr(namedArgs: {'name': name});
      } else if (errorMessage.contains('Cannot disable all')) {
        errorMessage = 'admin.payments.error_cannot_disable_all'.tr();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: DesignTokens.error,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}
