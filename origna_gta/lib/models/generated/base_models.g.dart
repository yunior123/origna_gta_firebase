// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'base_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Address _$AddressFromJson(Map<String, dynamic> json) => _Address(
  street: json['street'] as String,
  apartment: json['apartment'] as String? ?? '',
  city: json['city'] as String,
  state: json['state'] as String,
  postalCode: json['postalCode'] as String,
  country: json['country'] as String? ?? 'Canada',
  phoneNumber: json['phoneNumber'] as String?,
  isDefault: json['isDefault'] as bool? ?? false,
  addressId: json['addressId'] as String?,
  label: json['label'] as String?,
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
);

Map<String, dynamic> _$AddressToJson(_Address instance) => <String, dynamic>{
  'street': instance.street,
  'apartment': instance.apartment,
  'city': instance.city,
  'state': instance.state,
  'postalCode': instance.postalCode,
  'country': instance.country,
  'phoneNumber': instance.phoneNumber,
  'isDefault': instance.isDefault,
  'addressId': instance.addressId,
  'label': instance.label,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
};

_AddressDetails _$AddressDetailsFromJson(Map<String, dynamic> json) =>
    _AddressDetails(
      street: json['street'] as String,
      city: json['city'] as String,
      state: json['state'] as String,
      postalCode: json['postalCode'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );

Map<String, dynamic> _$AddressDetailsToJson(_AddressDetails instance) =>
    <String, dynamic>{
      'street': instance.street,
      'city': instance.city,
      'state': instance.state,
      'postalCode': instance.postalCode,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
    };
