import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/features/admin/admin_repository.dart';
import 'package:origna_gta/utils/constants.dart';

@GenerateNiceMocks([MockSpec<FirebaseFunctions>(), MockSpec<HttpsCallable>(), MockSpec<HttpsCallableResult>()])
import 'admin_repository_test.mocks.dart';

void main() {
  late FirebaseAdminRepository repository;
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseFunctions mockFunctions;
  late MockHttpsCallable mockCallable;
  late MockHttpsCallableResult mockResult;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockFunctions = MockFirebaseFunctions();
    mockCallable = MockHttpsCallable();
    mockResult = MockHttpsCallableResult();

    repository = FirebaseAdminRepository(fakeFirestore, mockFunctions);

    when(mockFunctions.httpsCallable(any)).thenReturn(mockCallable);
    when(mockCallable.call(any)).thenAnswer((_) async => mockResult);
  });

  group('FirebaseAdminRepository', () {
    test('approveProduct calls correct cloud function', () async {
      await repository.approveProduct('p1');
      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.adminApproveProduct)).called(1);
      verify(mockCallable.call({Fields.productId: 'p1'})).called(1);
    });

    test('deleteProduct calls correct cloud function', () async {
      await repository.deleteProduct('p1');
      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.deleteProduct)).called(1);
      verify(mockCallable.call({Fields.productId: 'p1'})).called(1);
    });

    test('disableAdminMfa calls correct cloud function', () async {
      await repository.disableAdminMfa('123456');
      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.adminMfaDisable)).called(1);
      verify(mockCallable.call({ApiKeys.code: '123456'})).called(1);
    });

    test('enableAdminMfa calls correct cloud function', () async {
      when(mockResult.data).thenReturn({'secret': 'secret123'});
      final result = await repository.enableAdminMfa();
      expect(result['secret'], 'secret123');
      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.adminMfaEnroll)).called(1);
    });

    test('fetchUserById returns user if exists', () async {
      await fakeFirestore.collection(Collections.users).doc('u1').set({
        Fields.email: 'test@ex.com',
        Fields.name: 'Test',
        Fields.roles: ['admin'],
        Fields.createdAt: Timestamp.now(),
      });

      final user = await repository.fetchUserById('u1');
      expect(user?.uid, 'u1');
      expect(user?.email, 'test@ex.com');
    });

    test('fetchUserById returns null if not exists', () async {
      final user = await repository.fetchUserById('non-existent');
      expect(user, isNull);
    });

    test('getPaymentProviders calls correct cloud function', () async {
      when(mockResult.data).thenReturn({'stripe': true});
      final result = await repository.getPaymentProviders();
      expect(result['stripe'], true);
      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.getPaymentProviders)).called(1);
    });

    test('setUserSuspended calls suspendSeller', () async {
      await repository.setUserSuspended('u1', true);
      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.suspendSeller)).called(1);
    });

    test('setUserSuspended calls unsuspendSeller', () async {
      await repository.setUserSuspended('u1', false);
      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.unsuspendSeller)).called(1);
    });

    test('updatePaymentProvider calls correct cloud function', () async {
      await repository.updatePaymentProvider('stripe', true, reason: 'test');
      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.updatePaymentProvider)).called(1);
      verify(mockCallable.call({ApiKeys.provider: 'stripe', ApiKeys.enabled: true, ApiKeys.reason: 'test'})).called(1);
    });

    test('updateProductStock calls correct cloud function', () async {
      await repository.updateProductStock('p1', 10);
      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.adminUpdateProductStock)).called(1);
      verify(mockCallable.call({Fields.productId: 'p1', Fields.stockQuantity: 10})).called(1);
    });

    test('rejectProduct calls correct cloud function', () async {
      await repository.rejectProduct('p1', 'bad photos');
      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.adminRejectProduct)).called(1);
      verify(mockCallable.call({Fields.productId: 'p1', Fields.reason: 'bad photos'})).called(1);
    });

    test('updateUserRoles calls correct cloud function', () async {
      await repository.updateUserRoles('u1', add: ['admin'], remove: ['buyer'], reason: 'promotion');
      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.updateUserRoles)).called(1);
      verify(
        mockCallable.call({
          Fields.targetUserId: 'u1',
          ApiKeys.add: ['admin'],
          ApiKeys.remove: ['buyer'],
          ApiKeys.reason: 'promotion',
        }),
      ).called(1);
    });

    test('verifyAdminMfa calls correct cloud function', () async {
      when(mockResult.data).thenReturn({'success': true});
      final result = await repository.verifyAdminMfa('123456');
      expect(result['success'], true);
      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.adminMfaVerify)).called(1);
      verify(mockCallable.call({ApiKeys.code: '123456'})).called(1);
    });

    test('watchUsers returns stream of users', () async {
      await fakeFirestore.collection(Collections.users).add({
        Fields.email: 'u1@ex.com',
        Fields.name: 'U1',
        Fields.roles: ['buyer'],
        Fields.createdAt: Timestamp.now(),
      });

      final stream = repository.watchUsers();
      final users = await stream.first;
      expect(users.length, 1);
      expect(users.first.name, 'U1');
    });

    test('watchOrders with status filter', () async {
      await fakeFirestore.collection(Collections.orders).add({
        Fields.orderStatus: OrderStatusValues.pending,
        Fields.createdAt: Timestamp.now(),
        Fields.userId: 'u1',
        Fields.customerId: 'c1',
        Fields.customerEmail: 'e1',
        Fields.items: [],
        Fields.totalAmountCents: 1000,
        Fields.subtotalCents: 1000,
        Fields.shippingAddress: {},
        Fields.taxes: <String, double>{},
        Fields.currency: 'cad',
        Fields.sellerIds: <String>[],
        Fields.stripeSessionId: 's1',
      });

      final stream = repository.watchOrders(status: OrderStatusValues.pending);
      final orders = await stream.first;
      expect(orders.length, 1);
      expect(orders.first.orderStatus, OrderStatusValues.pending);
    });

    test('watchProducts returns stream', () async {
      await fakeFirestore.collection(Collections.products).add({
        Fields.name: 'P1',
        Fields.sellerId: 's1',
        Fields.lifecycleStatus: ProductLifecycleStatusValues.active,
        Fields.price: 10.0,
        Fields.description: 'D',
        Fields.imageUrls: <String>[],
        Fields.categoryId: 1,
        Fields.stockQuantity: 5,
        Fields.createdAt: Timestamp.now(),
      });

      final stream = repository.watchProducts(sellerId: 's1');
      final products = await stream.first;
      expect(products.length, 1);
      expect(products.first.sellerId, 's1');
    });

    test('watchPendingReviewProducts returns stream', () async {
      await fakeFirestore.collection(Collections.products).add({
        Fields.name: 'P1',
        Fields.lifecycleStatus: ProductLifecycleStatusValues.underReview,
        Fields.price: 10.0,
        Fields.description: 'D',
        Fields.imageUrls: <String>[],
        Fields.sellerId: 's1',
        Fields.categoryId: 1,
        Fields.stockQuantity: 5,
        Fields.createdAt: Timestamp.now(),
      });

      final stream = repository.watchPendingReviewProducts();
      final products = await stream.first;
      expect(products.length, 1);
      expect(products.first.lifecycleStatus, ProductLifecycleStatusValues.underReview);
    });

    test('watchSellers returns stream of sellers', () async {
      await fakeFirestore.collection(Collections.users).add({
        Fields.email: 's1@ex.com',
        Fields.name: 'S1',
        Fields.roles: [UserRoles.seller],
        Fields.createdAt: Timestamp.now(),
      });

      final stream = repository.watchSellers();
      final sellers = await stream.first;
      expect(sellers.length, 1);
      expect(sellers.first.roles, contains(UserRoles.seller));
    });

    test('watchReviews returns stream', () async {
      await fakeFirestore.collection(Collections.productRatings).add({
        Fields.rating: 5,
        Fields.reviewText: 'Great',
        Fields.isFlagged: true,
        Fields.createdAt: Timestamp.now(),
      });

      final stream = repository.watchReviews(flaggedOnly: true);
      final reviews = await stream.first;
      expect(reviews.length, 1);
      expect(reviews.first['isFlagged'], true);
    });

    test('deleteReview calls adminDeleteReview', () async {
      await repository.deleteReview('r1');
      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.adminDeleteReview)).called(1);
    });

    test('flagReview calls adminFlagReview', () async {
      await repository.flagReview('r1', flagged: true);
      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.adminFlagReview)).called(1);
      verify(mockCallable.call({Fields.reviewId: 'r1', Fields.flagged: true})).called(1);
    });

    test('refundOrder calls adminRefundOrder', () async {
      await repository.refundOrder('o1', reason: 'Customer changed mind');
      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.adminRefundOrder)).called(1);
      verify(mockCallable.call({Fields.orderId: 'o1', Fields.reason: 'Customer changed mind'})).called(1);
    });
  });
}
