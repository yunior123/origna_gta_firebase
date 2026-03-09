import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:origna_gta/screens/notifications_screen.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/repositories/notification_repository.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import '../test_utils.dart';

@GenerateNiceMocks([
  MockSpec<NotificationRepository>(),
  MockSpec<FirebaseFirestore>(),
  MockSpec<CollectionReference<Map<String, dynamic>>>(),
  MockSpec<DocumentReference<Map<String, dynamic>>>(),
  MockSpec<Query<Map<String, dynamic>>>(),
  MockSpec<QuerySnapshot<Map<String, dynamic>>>(),
  MockSpec<QueryDocumentSnapshot<Map<String, dynamic>>>(),
  MockSpec<auth.User>(),
])
import 'notifications_screen_test.mocks.dart';

void main() {
  late MockNotificationRepository mockRepo;
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockCollection;
  late MockDocumentReference mockDoc;
  late MockQuery mockQuery;
  late MockQuerySnapshot mockQuerySnapshot;
  late MockUser mockUser;

  setUp(() {
    mockRepo = MockNotificationRepository();
    mockFirestore = MockFirebaseFirestore();
    mockCollection = MockCollectionReference();
    mockDoc = MockDocumentReference();
    mockQuery = MockQuery();
    mockQuerySnapshot = MockQuerySnapshot();
    mockUser = MockUser();
    
    initTestMocks();
    
    when(mockUser.uid).thenReturn('user_123');
    
    when(mockFirestore.collection(any)).thenReturn(mockCollection);
    when(mockCollection.doc(any)).thenReturn(mockDoc);
    when(mockDoc.collection(any)).thenReturn(mockCollection);
    when(mockCollection.orderBy(any, descending: anyNamed('descending'))).thenReturn(mockQuery);
    when(mockQuery.limit(any)).thenReturn(mockQuery);
    when(mockQuery.snapshots()).thenAnswer((_) => Stream.value(mockQuerySnapshot));
  });

  Widget createTestWidget({
    bool loggedIn = true,
  }) {
    return TestWrapper(
      overrides: [
        currentUserProvider.overrideWithValue(loggedIn ? mockUser : null),
        notificationRepositoryProvider.overrideWithValue(mockRepo),
        firestoreProvider.overrideWithValue(mockFirestore),
      ],
      child: const NotificationsScreen(),
    );
  }

  group('NotificationsScreen Widget Tests', () {
    testWidgets('renders empty state when no notifications', (tester) async {
      when(mockQuerySnapshot.docs).thenReturn([]);
      
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('notifications.no_notifications'.tr()), findsOneWidget);
    });

    testWidgets('renders list of notifications', (tester) async {
      final mockDoc1 = MockQueryDocumentSnapshot();
      when(mockDoc1.id).thenReturn('n1');
      when(mockDoc1.data()).thenReturn({
        'title': 'Test Title',
        'body': 'Test Body',
        Fields.type: 'order_confirmation',
        Fields.isRead: false,
        Fields.createdAt: Timestamp.now(),
      });
      
      when(mockQuerySnapshot.docs).thenReturn([mockDoc1]);
      
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Test Title'), findsOneWidget);
      expect(find.text('Test Body'), findsOneWidget);
    });

    testWidgets('can mark all read', (tester) async {
      final mockDoc1 = MockQueryDocumentSnapshot();
      when(mockDoc1.id).thenReturn('n1');
      when(mockDoc1.data()).thenReturn({
        'title': 'T1', 'body': 'B1', Fields.type: 't', Fields.isRead: false, Fields.createdAt: Timestamp.now(),
      });
      when(mockQuerySnapshot.docs).thenReturn([mockDoc1]);
      
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final markAllBtn = find.text('notifications.mark_all_read'.tr());
      await tester.tap(markAllBtn);
      await tester.pump();

      verify(mockRepo.markAllRead('user_123')).called(1);
    });

    testWidgets('can mark single read by tapping', (tester) async {
      final mockDoc1 = MockQueryDocumentSnapshot();
      when(mockDoc1.id).thenReturn('n1');
      when(mockDoc1.data()).thenReturn({
        'title': 'T1', 'body': 'B1', Fields.type: 't', Fields.isRead: false, Fields.createdAt: Timestamp.now(),
      });
      when(mockQuerySnapshot.docs).thenReturn([mockDoc1]);
      
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('T1'));
      await tester.pump();

      verify(mockRepo.markRead('user_123', 'n1')).called(1);
    });
  });
}
