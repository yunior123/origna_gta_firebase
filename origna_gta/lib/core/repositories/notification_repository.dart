import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
/// Documentation for NotificationRepository
class NotificationRepository {
  NotificationRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Future<void> markAllRead(String uid) async {
    final snap = await _firestore
        .collection(Collections.users)
        .doc(uid)
        .collection(Collections.notifications)
        .where(Fields.isRead, isEqualTo: false)
        .get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {Fields.isRead: true});
    }
    await batch.commit();
  }

  Future<void> markRead(String uid, String notificationId) async {
    await _firestore
        .collection(Collections.users)
        .doc(uid)
        .collection(Collections.notifications)
        .doc(notificationId)
        .update({Fields.isRead: true});
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(firestoreProvider));
});
