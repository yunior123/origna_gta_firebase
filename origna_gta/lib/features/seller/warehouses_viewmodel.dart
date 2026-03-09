// coverage:ignore-file
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/models/generated/base_models.dart';
import 'package:origna_gta/models/generated/product_models.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Documentation for WarehousesState
class WarehousesState {
  final List<SellerWarehouse> warehouses;
  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;

  const WarehousesState({
    this.warehouses = const [],
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
  });

  WarehousesState copyWith({
    List<SellerWarehouse>? warehouses,
    bool? isLoading,
    Object? errorMessage = _sentinel,
    bool? isSuccess,
  }) {
    return WarehousesState(
      warehouses: warehouses ?? this.warehouses,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage == _sentinel ? this.errorMessage : errorMessage as String?,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

const _sentinel = Object();

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Real-time stream of the seller's warehouses (ordered: default first, then by creation)
final sellerWarehousesStreamProvider = StreamProvider.autoDispose<List<SellerWarehouse>>((ref) {
  final uid = ref.watch(userIdProvider);
  if (uid == null) return const Stream.empty();

  return ref
      .read(firestoreProvider)
      .collection(Collections.users)
      .doc(uid)
      .collection(Collections.warehouses)
      .orderBy(Fields.isDefault, descending: true)
      .orderBy(Fields.createdAt, descending: false)
      .snapshots()
      .map((snap) => snap.docs.map((doc) => SellerWarehouse.fromFirestore(doc)).toList());
});

final warehousesViewModelProvider =
    StateNotifierProvider.autoDispose<WarehousesViewModel, WarehousesState>(
  (ref) => WarehousesViewModel(ref),
);

// ---------------------------------------------------------------------------
// ViewModel
// ---------------------------------------------------------------------------

/// Documentation for WarehousesViewModel
class WarehousesViewModel extends StateNotifier<WarehousesState> {
  final Ref _ref;

  WarehousesViewModel(this._ref) : super(const WarehousesState());

  Future<void> createWarehouse({
    required String label,
    required String type,
    required Address address,
    bool isDefault = false,
  }) async {
    if (state.isLoading) return;

    final trimmedLabel = label.trim();
    if (trimmedLabel.isEmpty || trimmedLabel.length > 100) {
      state = state.copyWith(isLoading: false, errorMessage: 'Warehouse label must be 1–100 characters');
      return;
    }
    if (address.city.trim().isEmpty) {
      state = state.copyWith(isLoading: false, errorMessage: 'City is required for a warehouse address');
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null, isSuccess: false);

    try {
      final functions = _ref.read(firebaseFunctionsProvider);
      final callable = functions.httpsCallable(CloudFunctionEndpoints.createWarehouse);
      await callable.call({
        'label': label.trim(),
        'type': type,
        'address': _addressToMap(address),
        'isDefault': isDefault,
      });
      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _parseError(e));
    }
  }

  Future<void> updateWarehouse({
    required String warehouseId,
    String? label,
    String? type,
    Address? address,
    bool? isDefault,
  }) async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, errorMessage: null, isSuccess: false);

    try {
      final functions = _ref.read(firebaseFunctionsProvider);
      final callable = functions.httpsCallable(CloudFunctionEndpoints.updateWarehouse);
      final payload = <String, dynamic>{'warehouseId': warehouseId};
      if (label != null) payload['label'] = label.trim();
      if (type != null) payload['type'] = type;
      if (address != null) payload['address'] = _addressToMap(address);
      if (isDefault != null) payload['isDefault'] = isDefault;
      await callable.call(payload);
      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _parseError(e));
    }
  }

  Future<void> deleteWarehouse(String warehouseId) async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, errorMessage: null, isSuccess: false);

    try {
      final functions = _ref.read(firebaseFunctionsProvider);
      final callable = functions.httpsCallable(CloudFunctionEndpoints.deleteWarehouse);
      await callable.call({'warehouseId': warehouseId});
      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _parseError(e));
    }
  }

  void clearStatus() {
    state = state.copyWith(errorMessage: null, isSuccess: false);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _addressToMap(Address address) => {
    Fields.street: address.street,
    if (address.apartment.isNotEmpty) Fields.apartment: address.apartment,
    Fields.city: address.city,
    Fields.state: address.state,
    Fields.postalCode: address.postalCode,
    Fields.country: address.country,
    if (address.phoneNumber != null) Fields.phoneNumber: address.phoneNumber,
    if (address.latitude != null) Fields.latitude: address.latitude,
    if (address.longitude != null) Fields.longitude: address.longitude,
    if (address.label != null) Fields.label: address.label,
  };

  String _parseError(Object e) {
    final msg = e.toString();
    if (msg.contains('unauthenticated')) return 'Please log in to manage warehouses.';
    if (msg.contains('not-found')) return 'Warehouse not found.';
    if (msg.contains('invalid-argument')) {
      final start = msg.indexOf('] ');
      return start >= 0 ? msg.substring(start + 2) : 'Invalid input. Please check the form.';
    }
    return 'Something went wrong. Please try again.';
  }
}
