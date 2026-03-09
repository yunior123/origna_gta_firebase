import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/repositories/algolia_product_repository.dart';
import 'package:origna_gta/core/repositories/auth_repository.dart';
import 'package:origna_gta/core/repositories/cart_repository.dart';
import 'package:origna_gta/core/repositories/location_repository.dart';
import 'package:origna_gta/core/repositories/order_repository.dart';
import 'package:origna_gta/core/repositories/product_repository.dart';
import 'package:origna_gta/core/repositories/user_repository.dart';
import 'package:origna_gta/models/models.dart';
import 'package:origna_gta/services/algolia_service.dart';
import 'package:origna_gta/services/conf_services.dart';
import 'package:origna_gta/utils/env_config.dart';
import 'package:origna_gta/utils/utils.dart';

// Algolia-based product repository (hybrid mode with Firestore fallback)
final algoliaProductRepositoryProvider = Provider<ProductRepository>((ref) {
  return AlgoliaProductRepository(ref.watch(algoliaServiceProvider), ref.watch(firestoreProvider), ref.watch(firebaseFunctionsProvider));
});

// Algolia service for fast product search
final algoliaServiceProvider = Provider<AlgoliaService>((ref) {
  final config = ConfigService();
  return AlgoliaService.create(appId: config.algoliaAppId, searchApiKey: config.algoliaSearchApiKey);
});

// ============================================================================
// REPOSITORY PROVIDERS
// ============================================================================

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository(ref.watch(firebaseAuthProvider), ref.watch(firestoreProvider), ref.watch(firebaseFunctionsProvider));
});

// ============================================================================
// AUTH STATE PROVIDER
// ============================================================================

final authStateProvider = StreamProvider<User?>((ref) => ref.watch(firebaseAuthProvider).authStateChanges());

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return FirebaseCartRepository(ref.watch(firestoreProvider));
});

final currentUserProvider = Provider<User?>((ref) => ref.watch(authStateProvider).valueOrNull);

// ============================================================================
// CORE PROVIDERS - Firebase instances
// ============================================================================

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final firebaseFunctionsProvider = Provider<FirebaseFunctions>((ref) {
  return FirebaseFunctions.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final envConfigProvider = Provider<EnvConfig>((ref) => EnvConfig());

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return GeoapifyLocationRepository();
});

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return FirebaseOrderRepository(ref.watch(firestoreProvider), ref.watch(firebaseFunctionsProvider));
});

// Default product repository — Algolia with automatic Firestore fallback.
// AlgoliaService.isAvailable handles empty credentials gracefully,
// so AlgoliaProductRepository always works (routes to Firestore when needed).
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ref.watch(algoliaProductRepositoryProvider);
});

final userAddressesProvider = StreamProvider.autoDispose<List<Address>>((ref) {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return Stream.value([]);
  return ref.watch(userRepositoryProvider).watchAddresses(userId);
});

final userIdProvider = Provider<String?>((ref) => ref.watch(currentUserProvider)?.uid);

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return FirebaseUserRepository(ref.watch(firestoreProvider), ref.watch(firebaseFunctionsProvider));
});
