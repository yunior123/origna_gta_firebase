import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/core/repositories/notification_repository.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late NotificationRepository repository;
  const String userId = 'user_123';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = NotificationRepository(fakeFirestore);
  });

  group('NotificationRepository Tests', () {
    test('markRead updates a single notification', () async {
      final notifRef = fakeFirestore
          .collection(Collections.users)
          .doc(userId)
          .collection(Collections.notifications)
          .doc('n1');
          
      await notifRef.set({Fields.isRead: false});
      
      await repository.markRead(userId, 'n1');
      
      final doc = await notifRef.get();
      expect(doc.data()![Fields.isRead], isTrue);
    });

    test('markAllRead updates all unread notifications', () async {
      final colRef = fakeFirestore
          .collection(Collections.users)
          .doc(userId)
          .collection(Collections.notifications);
          
      await colRef.doc('n1').set({Fields.isRead: false});
      await colRef.doc('n2').set({Fields.isRead: false});
      await colRef.doc('n3').set({Fields.isRead: true});
      
      await repository.markAllRead(userId);
      
      final n1 = await colRef.doc('n1').get();
      final n2 = await colRef.doc('n2').get();
      final n3 = await colRef.doc('n3').get();
      
      expect(n1.data()![Fields.isRead], isTrue);
      expect(n2.data()![Fields.isRead], isTrue);
      expect(n3.data()![Fields.isRead], isTrue);
    });
  });
}
