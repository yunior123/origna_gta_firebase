import 'package:flutter/foundation.dart';

@immutable
/// A single product variant combination (e.g. Size=M + Color=Red).
class ProductVariantEntry {
  static const _sentinel = Object();

  final String variantId;
  final Map<String, String> optionValues;
  final int? priceCents;
  final int stockQuantity;
  final String? sku;
  final bool isActive;

  const ProductVariantEntry({this.variantId = '', required this.optionValues, this.priceCents, this.stockQuantity = 0, this.sku, this.isActive = true});

  factory ProductVariantEntry.fromMap(Map<String, dynamic> map) {
    // Support both old 'price' (float) and new 'priceCents' (int)
    int? priceCents;
    if (map['priceCents'] != null) {
      priceCents = (map['priceCents'] as num).toInt();
    } else if (map['price'] != null) {
      priceCents = ((map['price'] as num).toDouble() * 100).round();
    }
    return ProductVariantEntry(
      variantId: map['variantId'] as String? ?? '',
      optionValues: (map['optionValues'] as Map).cast<String, String>(),
      priceCents: priceCents,
      stockQuantity: (map['stockQuantity'] as int?) ?? 0,
      sku: map['sku'] as String?,
      isActive: (map['isActive'] as bool?) ?? true,
    );
  }

  @override
  int get hashCode => Object.hash(variantId, Object.hashAll(optionValues.entries.map((e) => '${e.key}=${e.value}')), priceCents, stockQuantity, sku, isActive);

  /// Price in dollars for display purposes.
  double? get priceDollars => priceCents != null ? priceCents! / 100.0 : null;

  @override
  bool operator ==(Object other) =>
      other is ProductVariantEntry &&
      other.variantId == variantId &&
      mapEquals(other.optionValues, optionValues) &&
      other.priceCents == priceCents &&
      other.stockQuantity == stockQuantity &&
      other.sku == sku &&
      other.isActive == isActive;

  ProductVariantEntry copyWith({
    String? variantId,
    Map<String, String>? optionValues,
    Object? priceCents = _sentinel,
    int? stockQuantity,
    Object? sku = _sentinel,
    bool? isActive,
  }) {
    return ProductVariantEntry(
      variantId: variantId ?? this.variantId,
      optionValues: optionValues ?? this.optionValues,
      priceCents: identical(priceCents, _sentinel) ? this.priceCents : priceCents as int?,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      sku: identical(sku, _sentinel) ? this.sku : sku as String?,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() => {
    'variantId': variantId,
    'optionValues': optionValues,
    'priceCents': priceCents,
    'stockQuantity': stockQuantity,
    'sku': sku,
    'isActive': isActive,
  };
}

@immutable
/// A single product variant option (e.g. Size with values [S, M, L]).
class VariantOption {
  final String name;
  final List<String> values;

  const VariantOption({required this.name, required this.values});

  factory VariantOption.fromMap(Map<String, dynamic> map) {
    return VariantOption(name: map['name'] as String, values: (map['values'] as List).cast<String>());
  }

  @override
  int get hashCode => Object.hash(name, Object.hashAll(values));

  @override
  bool operator ==(Object other) => other is VariantOption && other.name == name && listEquals(other.values, values);

  VariantOption copyWith({String? name, List<String>? values}) {
    return VariantOption(name: name ?? this.name, values: values ?? this.values);
  }

  Map<String, dynamic> toMap() => {'name': name, 'values': values};
}
