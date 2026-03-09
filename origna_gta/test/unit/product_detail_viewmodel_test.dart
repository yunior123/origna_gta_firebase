import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/features/products/product_detail_viewmodel.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late ProviderContainer container;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    container = ProviderContainer(
      overrides: [
        firestoreProvider.overrideWithValue(fakeFirestore),
      ],
    );
  });

  group('ProductDetailViewModel Tests', () {
    test('initial state', () {
      final state = container.read(productDetailViewModelProvider);
      expect(state.quantity, 1);
      expect(state.currentImageIndex, 0);
    });

    test('increment/decrement quantity', () {
      final notifier = container.read(productDetailViewModelProvider.notifier);
      
      notifier.incrementQuantity();
      expect(container.read(productDetailViewModelProvider).quantity, 2);
      
      notifier.decrementQuantity();
      expect(container.read(productDetailViewModelProvider).quantity, 1);
      
      notifier.decrementQuantity(); // Should not go below 1
      expect(container.read(productDetailViewModelProvider).quantity, 1);
    });

    test('setImageIndex', () {
      final notifier = container.read(productDetailViewModelProvider.notifier);
      notifier.setImageIndex(2);
      expect(container.read(productDetailViewModelProvider).currentImageIndex, 2);
    });

    test('fetchSellerMetrics', () async {
      await fakeFirestore.collection(Collections.sellerMetrics).doc('s1').set({
        Fields.avgResponseTimeHours: 2.5,
        Fields.avgShipDays: 1.0,
        Fields.positiveRatePct: 98.0,
        Fields.totalReviews: 50,
      });
      
      final notifier = container.read(productDetailViewModelProvider.notifier);
      await notifier.fetchSellerMetrics('s1');
      
      final state = container.read(productDetailViewModelProvider);
      expect(state.sellerMetrics!.avgResponseHours, 2.5);
      expect(state.sellerMetrics!.totalReviews, 50);
    });
  });
}
