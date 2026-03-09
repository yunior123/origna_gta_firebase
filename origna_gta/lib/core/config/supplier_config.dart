// ============================================================================
// SUPPLIER CONFIGURATION - Dynamic & Extensible Supplier Platform Registry
// ============================================================================
// This configuration is the SINGLE SOURCE OF TRUTH for all supplier platforms.
// To add a new supplier: simply add an entry to [supplierPlatforms] map.
// No other code changes required - the system is fully dynamic.
//
// IMPORTANT: CAD-ONLY PRICING — BUYERS ARE IN CANADA, SELLERS CAN BE WORLDWIDE
// - All SELLING prices are in CAD (Canadian Dollars) only
// - The currencies here are for SUPPLIER COST TRACKING only (what seller pays supplier)
// - Sellers can be from any country — no geographic restriction on sellers
// - Products are always priced and sold in CAD to Canadian buyers

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:origna_gta/utils/design_tokens.dart';

/// The ONLY currency allowed for selling products on the platform
const String kSellingCurrency = 'CAD';

/// Central registry of all supported supplier platforms
/// ADD NEW SUPPLIERS HERE - No other code changes needed!
/// Note: supportedCurrencies is for SUPPLIER COST tracking, not selling price
final Map<String, SupplierPlatformConfig> supplierPlatforms = {
  // ============== CHINA ==============
  'aliexpress': const SupplierPlatformConfig(
    id: 'aliexpress',
    displayName: 'AliExpress',
    region: 'Asia',
    country: 'China',
    minDeliveryDays: 15,
    maxDeliveryDays: 30,
    hasTracking: true,
    supportedCurrencies: ['USD', 'CAD', 'CNY', 'EUR'],
    defaultCurrency: 'USD',
    icon: Icons.shopping_bag,
    color: Color(0xFFE62E04),
    websiteUrl: 'https://aliexpress.com',
    description: 'Global retail marketplace',
  ),
  'alibaba': const SupplierPlatformConfig(
    id: 'alibaba',
    displayName: 'Alibaba',
    region: 'Asia',
    country: 'China',
    minDeliveryDays: 25,
    maxDeliveryDays: 45,
    hasTracking: true,
    supportedCurrencies: ['USD', 'CNY'],
    defaultCurrency: 'USD',
    icon: Icons.business,
    color: Color(0xFFFF6A00),
    websiteUrl: 'https://alibaba.com',
    description: 'B2B wholesale marketplace',
  ),
  '1688': const SupplierPlatformConfig(
    id: '1688',
    displayName: '1688',
    region: 'Asia',
    country: 'China',
    minDeliveryDays: 25,
    maxDeliveryDays: 45,
    hasTracking: false,
    supportedCurrencies: ['CNY', 'USD'],
    defaultCurrency: 'CNY',
    icon: Icons.inventory_2,
    color: Color(0xFFFF4400),
    websiteUrl: 'https://1688.com',
    description: 'Chinese domestic B2B platform',
  ),
  'dhgate': const SupplierPlatformConfig(
    id: 'dhgate',
    displayName: 'DHgate',
    region: 'Asia',
    country: 'China',
    minDeliveryDays: 20,
    maxDeliveryDays: 40,
    hasTracking: true,
    supportedCurrencies: ['USD', 'CAD', 'EUR'],
    defaultCurrency: 'USD',
    icon: Icons.local_shipping,
    color: Color(0xFF1E88E5),
    websiteUrl: 'https://dhgate.com',
    description: 'Cross-border e-commerce platform',
  ),
  'temu': const SupplierPlatformConfig(
    id: 'temu',
    displayName: 'Temu',
    region: 'Asia',
    country: 'China',
    minDeliveryDays: 7,
    maxDeliveryDays: 15,
    hasTracking: true,
    supportedCurrencies: ['USD', 'CAD'],
    defaultCurrency: 'USD',
    icon: Icons.storefront,
    color: Color(0xFFFB7701),
    websiteUrl: 'https://temu.com',
    description: 'Fast shipping marketplace',
  ),
  'made_in_china': const SupplierPlatformConfig(
    id: 'made_in_china',
    displayName: 'Made-in-China',
    region: 'Asia',
    country: 'China',
    minDeliveryDays: 20,
    maxDeliveryDays: 40,
    hasTracking: true,
    supportedCurrencies: ['USD', 'CNY'],
    defaultCurrency: 'USD',
    icon: Icons.factory,
    color: Color(0xFF2196F3),
    websiteUrl: 'https://made-in-china.com',
    description: 'B2B sourcing platform',
  ),
  'global_sources': const SupplierPlatformConfig(
    id: 'global_sources',
    displayName: 'Global Sources',
    region: 'Asia',
    country: 'China/Hong Kong',
    minDeliveryDays: 20,
    maxDeliveryDays: 35,
    hasTracking: true,
    supportedCurrencies: ['USD', 'HKD'],
    defaultCurrency: 'USD',
    icon: Icons.public,
    color: Color(0xFF00ACC1),
    websiteUrl: 'https://globalsources.com',
    description: 'Asia-based B2B platform',
  ),

  // ============== DROPSHIPPING SERVICES ==============
  'cjdropshipping': const SupplierPlatformConfig(
    id: 'cjdropshipping',
    displayName: 'CJ Dropshipping',
    region: 'Global',
    country: 'China (warehouses worldwide)',
    minDeliveryDays: 10,
    maxDeliveryDays: 20,
    hasTracking: true,
    supportedCurrencies: ['USD', 'CAD', 'EUR'],
    defaultCurrency: 'USD',
    icon: Icons.rocket_launch,
    color: Color(0xFF4CAF50),
    websiteUrl: 'https://cjdropshipping.com',
    description: 'Dropshipping & fulfillment service',
  ),
  'spocket': const SupplierPlatformConfig(
    id: 'spocket',
    displayName: 'Spocket',
    region: 'US/EU',
    country: 'USA/Europe',
    minDeliveryDays: 5,
    maxDeliveryDays: 14,
    hasTracking: true,
    supportedCurrencies: ['USD', 'CAD', 'EUR', 'GBP'],
    defaultCurrency: 'USD',
    icon: Icons.speed,
    color: Color(0xFF9C27B0),
    websiteUrl: 'https://spocket.co',
    description: 'US/EU dropshipping suppliers',
    isInternational: false,
  ),
  'printful': const SupplierPlatformConfig(
    id: 'printful',
    displayName: 'Printful',
    region: 'Global',
    country: 'USA/EU/Mexico',
    minDeliveryDays: 5,
    maxDeliveryDays: 12,
    hasTracking: true,
    supportedCurrencies: ['USD', 'CAD', 'EUR', 'GBP'],
    defaultCurrency: 'USD',
    icon: Icons.print,
    color: Color(0xFFE91E63),
    websiteUrl: 'https://printful.com',
    description: 'Print-on-demand fulfillment',
    isInternational: false,
  ),
  'printify': const SupplierPlatformConfig(
    id: 'printify',
    displayName: 'Printify',
    region: 'Global',
    country: 'Various',
    minDeliveryDays: 5,
    maxDeliveryDays: 14,
    hasTracking: true,
    supportedCurrencies: ['USD', 'CAD', 'EUR', 'GBP'],
    defaultCurrency: 'USD',
    icon: Icons.palette,
    color: Color(0xFF00BCD4),
    websiteUrl: 'https://printify.com',
    description: 'Print-on-demand platform',
    isInternational: false,
  ),

  // ============== SOUTH KOREA ==============
  'gmarket': const SupplierPlatformConfig(
    id: 'gmarket',
    displayName: 'Gmarket',
    region: 'Asia',
    country: 'South Korea',
    minDeliveryDays: 10,
    maxDeliveryDays: 20,
    hasTracking: true,
    supportedCurrencies: ['KRW', 'USD'],
    defaultCurrency: 'KRW',
    icon: Icons.shopping_bag_outlined,
    color: Color(0xFFE53935),
    websiteUrl: 'https://gmarket.co.kr',
    description: 'Korean e-commerce platform',
  ),
  'coupang': const SupplierPlatformConfig(
    id: 'coupang',
    displayName: 'Coupang',
    region: 'Asia',
    country: 'South Korea',
    minDeliveryDays: 7,
    maxDeliveryDays: 15,
    hasTracking: true,
    supportedCurrencies: ['KRW', 'USD'],
    defaultCurrency: 'KRW',
    icon: Icons.flash_on,
    color: Color(0xFF6A1B9A),
    websiteUrl: 'https://coupang.com',
    description: 'Korean rocket delivery',
  ),

  // ============== JAPAN ==============
  'rakuten': const SupplierPlatformConfig(
    id: 'rakuten',
    displayName: 'Rakuten',
    region: 'Asia',
    country: 'Japan',
    minDeliveryDays: 10,
    maxDeliveryDays: 20,
    hasTracking: true,
    supportedCurrencies: ['JPY', 'USD'],
    defaultCurrency: 'JPY',
    icon: Icons.castle,
    color: Color(0xFFBF0000),
    websiteUrl: 'https://rakuten.co.jp',
    description: 'Japanese e-commerce giant',
  ),
  'amazon_japan': const SupplierPlatformConfig(
    id: 'amazon_japan',
    displayName: 'Amazon Japan',
    region: 'Asia',
    country: 'Japan',
    minDeliveryDays: 7,
    maxDeliveryDays: 14,
    hasTracking: true,
    supportedCurrencies: ['JPY', 'USD'],
    defaultCurrency: 'JPY',
    icon: Icons.local_mall,
    color: Color(0xFFFF9900),
    websiteUrl: 'https://amazon.co.jp',
    description: 'Amazon Japan marketplace',
  ),

  // ============== INDIA ==============
  'indiamart': const SupplierPlatformConfig(
    id: 'indiamart',
    displayName: 'IndiaMart',
    region: 'Asia',
    country: 'India',
    minDeliveryDays: 15,
    maxDeliveryDays: 30,
    hasTracking: true,
    supportedCurrencies: ['INR', 'USD'],
    defaultCurrency: 'INR',
    icon: Icons.handshake,
    color: Color(0xFF1565C0),
    websiteUrl: 'https://indiamart.com',
    description: 'Indian B2B marketplace',
  ),
  'tradeindia': const SupplierPlatformConfig(
    id: 'tradeindia',
    displayName: 'TradeIndia',
    region: 'Asia',
    country: 'India',
    minDeliveryDays: 15,
    maxDeliveryDays: 35,
    hasTracking: true,
    supportedCurrencies: ['INR', 'USD'],
    defaultCurrency: 'INR',
    icon: Icons.swap_horiz,
    color: Color(0xFFFF5722),
    websiteUrl: 'https://tradeindia.com',
    description: 'Indian B2B platform',
  ),

  // ============== EUROPE ==============
  'faire': const SupplierPlatformConfig(
    id: 'faire',
    displayName: 'Faire',
    region: 'US/EU',
    country: 'USA/Europe',
    minDeliveryDays: 5,
    maxDeliveryDays: 12,
    hasTracking: true,
    supportedCurrencies: ['USD', 'EUR', 'GBP', 'CAD'],
    defaultCurrency: 'USD',
    icon: Icons.store_mall_directory,
    color: Color(0xFF000000),
    websiteUrl: 'https://faire.com',
    description: 'Wholesale marketplace',
    isInternational: false,
  ),
  'amazon_europe': const SupplierPlatformConfig(
    id: 'amazon_europe',
    displayName: 'Amazon Europe',
    region: 'Europe',
    country: 'Germany/UK/France',
    minDeliveryDays: 7,
    maxDeliveryDays: 14,
    hasTracking: true,
    supportedCurrencies: ['EUR', 'GBP', 'USD'],
    defaultCurrency: 'EUR',
    icon: Icons.local_mall,
    color: Color(0xFFFF9900),
    websiteUrl: 'https://amazon.de',
    description: 'Amazon European marketplaces',
    isInternational: false,
  ),

  // ============== NORTH AMERICA ==============
  'amazon_usa': const SupplierPlatformConfig(
    id: 'amazon_usa',
    displayName: 'Amazon USA',
    region: 'North America',
    country: 'USA',
    minDeliveryDays: 3,
    maxDeliveryDays: 7,
    hasTracking: true,
    supportedCurrencies: ['USD', 'CAD'],
    defaultCurrency: 'USD',
    icon: Icons.local_mall,
    color: Color(0xFFFF9900),
    websiteUrl: 'https://amazon.com',
    description: 'Amazon US marketplace',
    isInternational: false,
  ),
  'walmart': const SupplierPlatformConfig(
    id: 'walmart',
    displayName: 'Walmart',
    region: 'North America',
    country: 'USA',
    minDeliveryDays: 3,
    maxDeliveryDays: 7,
    hasTracking: true,
    supportedCurrencies: ['USD', 'CAD'],
    defaultCurrency: 'USD',
    icon: Icons.shopping_cart_checkout,
    color: Color(0xFF0071DC),
    websiteUrl: 'https://walmart.com',
    description: 'US retail giant',
    isInternational: false,
  ),
  'costco': const SupplierPlatformConfig(
    id: 'costco',
    displayName: 'Costco Business',
    region: 'North America',
    country: 'USA/Canada',
    minDeliveryDays: 3,
    maxDeliveryDays: 7,
    hasTracking: true,
    supportedCurrencies: ['USD', 'CAD'],
    defaultCurrency: 'CAD',
    icon: Icons.warehouse,
    color: Color(0xFFE31837),
    websiteUrl: 'https://costco.com',
    description: 'Wholesale club',
    isInternational: false,
  ),

  // ============== CANADA LOCAL ==============
  'local': const SupplierPlatformConfig(
    id: 'local',
    displayName: 'Local Canadian Supplier',
    region: 'Canada',
    country: 'Canada',
    minDeliveryDays: 1,
    maxDeliveryDays: 5,
    hasTracking: true,
    supportedCurrencies: ['CAD'],
    defaultCurrency: 'CAD',
    icon: Icons.home_work,
    color: Color(0xFFD32F2F),
    description: 'Canadian-based supplier',
    isInternational: false,
  ),

  // ============== HANDMADE / ARTISAN ==============
  'etsy_wholesale': const SupplierPlatformConfig(
    id: 'etsy_wholesale',
    displayName: 'Etsy Wholesale',
    region: 'Global',
    country: 'Various',
    minDeliveryDays: 7,
    maxDeliveryDays: 21,
    hasTracking: true,
    supportedCurrencies: ['USD', 'CAD', 'EUR', 'GBP'],
    defaultCurrency: 'USD',
    icon: Icons.handyman,
    color: Color(0xFFEB6D20),
    websiteUrl: 'https://etsy.com',
    description: 'Handmade & vintage items',
  ),

  // ============== CUSTOM / OTHER ==============
  'custom': const SupplierPlatformConfig(
    id: 'custom',
    displayName: 'Custom Supplier',
    region: 'Custom',
    country: 'Specify',
    minDeliveryDays: 7,
    maxDeliveryDays: 30,
    hasTracking: false,
    supportedCurrencies: ['USD', 'CAD', 'EUR', 'GBP', 'CNY', 'JPY', 'KRW', 'INR', 'AUD', 'MXN', 'BRL'],
    defaultCurrency: 'USD',
    icon: Icons.add_business,
    color: Color(0xFF607D8B),
    description: 'Add your own supplier details',
  ),
  'other': const SupplierPlatformConfig(
    id: 'other',
    displayName: 'Other',
    region: 'Various',
    country: 'Various',
    minDeliveryDays: 7,
    maxDeliveryDays: 30,
    hasTracking: false,
    supportedCurrencies: ['USD', 'CAD', 'EUR', 'GBP', 'CNY'],
    defaultCurrency: 'USD',
    icon: Icons.more_horiz,
    color: Color(0xFF9E9E9E),
    description: 'Other supplier not listed',
  ),
};

/// Get all supported currencies across all platforms
Set<String> getAllSupportedCurrencies() {
  final currencies = <String>{};
  for (final platform in supplierPlatforms.values) {
    currencies.addAll(platform.supportedCurrencies);
  }
  return currencies;
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/// Get supplier config by ID (with fallback to 'other')
SupplierPlatformConfig getSupplierConfig(String? supplierId) {
  if (supplierId == null || supplierId.isEmpty) {
    return supplierPlatforms['other']!;
  }
  return supplierPlatforms[supplierId] ?? supplierPlatforms['other']!;
}

/// Get delivery range for a supplier
({int minDays, int maxDays}) getSupplierDeliveryRange(String? supplierId) {
  final config = getSupplierConfig(supplierId);
  return (minDays: config.minDeliveryDays, maxDays: config.maxDeliveryDays);
}

/// Get all active supplier platforms as dropdown items
List<DropdownMenuItem<String>> getSupplierDropdownItems() {
  return supplierPlatforms.entries
      .map(
        (e) => DropdownMenuItem(
          value: e.key,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(e.value.icon, size: 18, color: e.value.color),
              const SizedBox(width: 8),
              Flexible(child: Text(e.value.translatedDisplayName, overflow: TextOverflow.ellipsis)),
              if (e.value.country.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text('(${e.value.translatedCountry})', style: TextStyle(fontSize: 11, color: DesignTokens.textSecondary)),
              ],
            ],
          ),
        ),
      )
      .toList();
}

/// Get supplier region for display
String? getSupplierRegion(String? supplierId) {
  final config = getSupplierConfig(supplierId);
  return config.isCustom ? null : '${config.translatedCountry} (${config.translatedRegion})';
}

/// Get suppliers grouped by region for organized display
Map<String, List<SupplierPlatformConfig>> getSuppliersByRegion() {
  final grouped = <String, List<SupplierPlatformConfig>>{};
  for (final platform in supplierPlatforms.values) {
    grouped.putIfAbsent(platform.translatedRegion, () => []).add(platform);
  }
  return grouped;
}

/// Check if supplier is international
bool isInternationalSupplier(String? supplierId) {
  return getSupplierConfig(supplierId).isInternational;
}

/// Supplier platform configuration
class SupplierPlatformConfig {
  final String id;
  final String displayName;
  final String region;
  final String country;
  final int minDeliveryDays;
  final int maxDeliveryDays;
  final bool hasTracking;
  final List<String> supportedCurrencies;
  final String defaultCurrency;
  final IconData icon;
  final Color color;
  final String? websiteUrl;
  final String description;
  final bool isInternational;
  const SupplierPlatformConfig({
    required this.id,
    required this.displayName,
    required this.region,
    required this.country,
    required this.minDeliveryDays,
    required this.maxDeliveryDays,
    this.hasTracking = true,
    this.supportedCurrencies = const ['USD', 'CAD'],
    this.defaultCurrency = 'USD',
    this.icon = Icons.store,
    this.color = DesignTokens.primary,
    this.websiteUrl,
    this.description = '',
    this.isInternational = true,
  });

  /// Whether this is a custom/user-defined supplier
  bool get isCustom => id == 'custom' || id == 'other';

  /// Translation helpers
  String get translatedDisplayName => 'supplier.$id.display_name'.tr();
  String get translatedRegion => 'supplier.$id.region'.tr();
  String get translatedCountry => 'supplier.$id.country'.tr();
  String get translatedDescription => 'supplier.$id.description'.tr();
}
