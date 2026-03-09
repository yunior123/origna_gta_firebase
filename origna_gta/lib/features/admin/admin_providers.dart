import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/features/admin/admin_repository.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/utils/utils.dart';

final adminOrdersProvider = StreamProvider.autoDispose.family<List<OrderModel>, String>((ref, status) {
  return ref.watch(adminRepositoryProvider).watchOrders(status: status);
});

final adminProductsProvider = StreamProvider.autoDispose.family<List<ProductModel>, String?>((ref, sellerId) {
  return ref.watch(adminRepositoryProvider).watchProducts(sellerId: sellerId);
});

final adminPendingReviewProductsProvider = StreamProvider.autoDispose<List<ProductModel>>((ref) {
  return ref.watch(adminRepositoryProvider).watchPendingReviewProducts();
});

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return FirebaseAdminRepository(ref.watch(firestoreProvider), ref.watch(firebaseFunctionsProvider));
});

final adminReviewsProvider = StreamProvider.autoDispose.family<List<Map<String, dynamic>>, ({bool flaggedOnly, bool hasPhotosOnly})>((ref, filters) {
  return ref.watch(adminRepositoryProvider).watchReviews(
    flaggedOnly: filters.flaggedOnly,
    hasPhotosOnly: filters.hasPhotosOnly,
  );
});

final adminSellersProvider = StreamProvider.autoDispose<List<UserModel>>((ref) {
  return ref.watch(adminRepositoryProvider).watchSellers();
});

final adminUsersProvider = StreamProvider.autoDispose<List<UserModel>>((ref) {
  return ref.watch(adminRepositoryProvider).watchUsers();
});
