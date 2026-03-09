import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/core/repositories/cart_repository.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late FirebaseCartRepository repository;
  const String userId = 'user_123';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = FirebaseCartRepository(fakeFirestore);
  });

  group('FirebaseCartRepository Tests', () {
    test('addToCart adds new item', () async {
      await repository.addToCart(userId, 'p1', 2);
      
      final cartItems = await fakeFirestore
          .collection(Collections.users)
          .doc(userId)
          .collection(Collections.cart)
          .get();
          
      expect(cartItems.docs.length, 1);
      expect(cartItems.docs.first.id, 'p1');
      expect(cartItems.docs.first.data()[Fields.quantity], 2);
    });

    test('addToCart updates existing item quantity', () async {
      await repository.addToCart(userId, 'p1', 2);
      await repository.addToCart(userId, 'p1', 3);
      
      final doc = await fakeFirestore
          .collection(Collections.users)
          .doc(userId)
          .collection(Collections.cart)
          .doc('p1')
          .get();
          
      expect(doc.data()![Fields.quantity], 5);
    });

    test('updateQuantity updates item', () async {
      await repository.addToCart(userId, 'p1', 2);
      await repository.updateQuantity(userId, 'p1', 10);
      
      final doc = await fakeFirestore
          .collection(Collections.users)
          .doc(userId)
          .collection(Collections.cart)
          .doc('p1')
          .get();
          
      expect(doc.data()![Fields.quantity], 10);
    });

    test('removeFromCart removes item', () async {
      await repository.addToCart(userId, 'p1', 2);
      await repository.removeFromCart(userId, 'p1');
      
      final doc = await fakeFirestore
          .collection(Collections.users)
          .doc(userId)
          .collection(Collections.cart)
          .doc('p1')
          .get();
          
      expect(doc.exists, isFalse);
    });

    test('clearCart removes all items', () async {
      await repository.addToCart(userId, 'p1', 2);
      await repository.addToCart(userId, 'p2', 1);
      await repository.clearCart(userId);
      
      final cartItems = await fakeFirestore
          .collection(Collections.users)
          .doc(userId)
          .collection(Collections.cart)
          .get();
          
      expect(cartItems.docs.isEmpty, isTrue);
    });

    test('getProductSellerId returns sellerId', () async {
      await fakeFirestore.collection(Collections.products).doc('p1').set({
        Fields.sellerId: 's1',
      });
      
      final sellerId = await repository.getProductSellerId('p1');
      expect(sellerId, 's1');
    });

    test('isVariantValid verifies variant', () async {
      await fakeFirestore.collection(Collections.products).doc('p1').set({
        Fields.variants: [
          {Fields.variantId: 'v1', 'isActive': true},
          {Fields.variantId: 'v2', 'isActive': false},
        ],
      });
      
      expect(await repository.isVariantValid('p1', 'v1'), isTrue);
      expect(await repository.isVariantValid('p1', 'v2'), isFalse);
      expect(await repository.isVariantValid('p1', 'v3'), isFalse);
    });
  });
}
