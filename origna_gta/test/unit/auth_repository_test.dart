import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:origna_gta/core/repositories/auth_repository.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/utils/env_config.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sign_in_with_apple_platform_interface/sign_in_with_apple_platform_interface.dart';

@GenerateNiceMocks([
  MockSpec<auth.FirebaseAuth>(),
  MockSpec<FirebaseFirestore>(),
  MockSpec<FirebaseFunctions>(),
  MockSpec<HttpsCallable>(),
  MockSpec<HttpsCallableResult>(),
  MockSpec<auth.User>(),
  MockSpec<auth.UserCredential>(),
  MockSpec<CollectionReference<Map<String, dynamic>>>(),
  MockSpec<DocumentReference<Map<String, dynamic>>>(),
  MockSpec<DocumentSnapshot<Map<String, dynamic>>>(),
  MockSpec<auth.UserInfo>(),
  MockSpec<EnvConfig>(),
])
import 'auth_repository_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFirebaseAuth mockAuth;
  late MockFirebaseFirestore mockFirestore;
  late MockFirebaseFunctions mockFunctions;
  late MockHttpsCallable mockCallable;
  late MockHttpsCallableResult<Map<String, dynamic>> mockResult;
  late MockUser mockUser;
  late MockEnvConfig mockEnvConfig;
  late MockCollectionReference mockCollection;
  late MockDocumentReference mockDoc;
  late MockDocumentSnapshot mockSnapshot;
  late FirebaseAuthRepository repository;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockFirestore = MockFirebaseFirestore();
    mockFunctions = MockFirebaseFunctions();
    mockCallable = MockHttpsCallable();
    mockResult = MockHttpsCallableResult<Map<String, dynamic>>();
    mockUser = MockUser();
    mockEnvConfig = MockEnvConfig();
    mockCollection = MockCollectionReference();
    mockDoc = MockDocumentReference();
    mockSnapshot = MockDocumentSnapshot();

    // Standard stubs that are safe
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.uid).thenReturn('user_123');
    when(mockUser.email).thenReturn('test@example.com');
    when(mockUser.displayName).thenReturn('Test User');
    when(mockUser.providerData).thenReturn([]);
    when(mockEnvConfig.isEmulator).thenReturn(false);

    repository = FirebaseAuthRepository(mockAuth, mockFirestore, mockFunctions, isWeb: false, envConfig: mockEnvConfig);
    repository.turnstileOverride = () async => 'mock_token';
  });

  void stubHttps() {
    when(mockFunctions.httpsCallable(any)).thenReturn(mockCallable);
    when(mockCallable.call<Map<String, dynamic>>(any)).thenAnswer((_) async => mockResult);
  }

  void stubFirestoreUser(String uid, {bool exists = true, Map<String, dynamic>? data}) {
    when(mockFirestore.collection(Collections.users)).thenReturn(mockCollection);
    when(mockCollection.doc(uid)).thenReturn(mockDoc);
    when(mockDoc.get(any)).thenAnswer((_) async => mockSnapshot);
    when(mockSnapshot.exists).thenReturn(exists);
    if (exists && data != null) {
      when(mockSnapshot.data()).thenReturn(data);
    }
  }

  group('FirebaseAuthRepository Unit Tests', () {
    test('deleteAccount calls backend', () async {
      stubHttps();
      await repository.deleteAccount();
      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.deleteAccount)).called(1);
    });

    test('signInWithEmail calls auth and ensures document', () async {
      final mockCredential = MockUserCredential();
      when(mockAuth.signInWithEmailAndPassword(email: anyNamed('email'), password: anyNamed('password'))).thenAnswer((_) async => mockCredential);
      when(mockCredential.user).thenReturn(mockUser);

      stubFirestoreUser('user_123');

      await repository.signInWithEmail('test@example.com', 'password123');

      verify(mockAuth.signInWithEmailAndPassword(email: 'test@example.com', password: 'password123')).called(1);
    });

    test('isEmailVerified reloads user', () async {
      when(mockUser.emailVerified).thenReturn(true);
      final verified = await repository.isEmailVerified();
      expect(verified, isTrue);
      verify(mockUser.reload()).called(1);
    });

    test('isEmailVerified returns true in emulator mode', () async {
      when(mockEnvConfig.isEmulator).thenReturn(true);
      final result = await repository.isEmailVerified();
      expect(result, true);
    });

    test('registerWithEmail sends verification and creates profile', () async {
      final mockCredential = MockUserCredential();
      when(mockAuth.createUserWithEmailAndPassword(email: 'test@example.com', password: 'password123')).thenAnswer((_) async => mockCredential);
      when(mockCredential.user).thenReturn(mockUser);
      when(mockUser.email).thenReturn('test@example.com');
      when(mockUser.emailVerified).thenReturn(false);
      when(mockUser.updateDisplayName(any)).thenAnswer((_) async {});

      stubFirestoreUser('user_123', exists: false);

      final mockPendingCollection = MockCollectionReference();
      final mockPendingDoc = MockDocumentReference();
      when(mockFirestore.collection(Collections.pendingProfiles)).thenReturn(mockPendingCollection);
      when(mockPendingCollection.doc('user_123')).thenReturn(mockPendingDoc);

      await repository.registerWithEmail('test@example.com', 'password123', 'Test User');

      verify(mockUser.updateDisplayName('Test User')).called(1);
      verify(mockUser.sendEmailVerification()).called(1);
      verify(mockPendingDoc.set(any, any)).called(1);
    });

    test('sendPasswordResetEmail prevents enumeration (Security M-1)', () async {
      when(mockAuth.sendPasswordResetEmail(email: 'notfound@example.com')).thenThrow(auth.FirebaseAuthException(code: 'user-not-found'));

      await repository.sendPasswordResetEmail('notfound@example.com');
      verify(mockAuth.sendPasswordResetEmail(email: 'notfound@example.com')).called(1);
    });

    test('signOut clears FCM and waits for auth state change', () async {
      when(mockAuth.authStateChanges()).thenAnswer((_) => Stream.fromIterable([null]));
      await repository.signOut();
      verify(mockAuth.signOut()).called(1);
    });

    test('validateCurrentUser signs out if profile missing in Firestore', () async {
      when(mockUser.emailVerified).thenReturn(true);
      when(mockAuth.authStateChanges()).thenAnswer((_) => Stream.fromIterable([null]));

      stubFirestoreUser('user_123', exists: false);

      final isValid = await repository.validateCurrentUser();
      expect(isValid, isFalse);
      verify(mockAuth.signOut()).called(1);
    });

    test('signInWithGoogle uses signInWithProvider on mobile', () async {
      final mockCredential = MockUserCredential();
      when(mockAuth.signInWithProvider(any)).thenAnswer((_) async => mockCredential);
      when(mockCredential.user).thenReturn(mockUser);

      stubFirestoreUser('user_123');

      await repository.signInWithGoogle();
      verify(mockAuth.signInWithProvider(any)).called(1);
    });

    test('signInWithGoogle uses signInWithPopup on web', () async {
      final webRepository = FirebaseAuthRepository(mockAuth, mockFirestore, mockFunctions, isWeb: true, envConfig: mockEnvConfig);

      final mockCredential = MockUserCredential();
      when(mockAuth.signInWithPopup(any)).thenAnswer((_) async => mockCredential);
      when(mockCredential.user).thenReturn(mockUser);

      stubFirestoreUser('user_123');

      await webRepository.signInWithGoogle();
      verify(mockAuth.signInWithPopup(any)).called(1);
    });

    test('ensureUserDocumentExists reloads and checks firestore', () async {
      when(mockUser.reload()).thenAnswer((_) async {});

      stubFirestoreUser('user_123');

      await repository.ensureUserDocumentExists();

      verify(mockUser.reload()).called(1);
      verify(mockDoc.get()).called(1);
    });

    test('watchProfile returns UserModel stream', () async {
      final mockCollection = MockCollectionReference();
      final mockDoc = MockDocumentReference();
      final mockSnapshot = MockDocumentSnapshot();

      when(mockFirestore.collection(Collections.users)).thenReturn(mockCollection);
      when(mockCollection.doc('user_123')).thenReturn(mockDoc);
      when(mockDoc.snapshots()).thenAnswer((_) => Stream.fromIterable([mockSnapshot]));
      when(mockSnapshot.exists).thenReturn(true);
      when(mockSnapshot.data()).thenReturn({Fields.uid: 'user_123', Fields.name: 'Test User', Fields.email: 'test@example.com'});
      when(mockSnapshot.id).thenReturn('user_123');

      final stream = repository.watchProfile('user_123');
      final model = await stream.first;

      expect(model?.uid, 'user_123');
      expect(model?.name, 'Test User');
    });

    test('sendEmailVerification sends when not verified', () async {
      when(mockUser.emailVerified).thenReturn(false);
      when(mockUser.sendEmailVerification()).thenAnswer((_) async {
        return;
      });

      await repository.sendEmailVerification();
      verify(mockUser.sendEmailVerification()).called(1);
    });

    test('sendEmailVerification throws if no user', () async {
      when(mockAuth.currentUser).thenReturn(null);
      expect(() => repository.sendEmailVerification(), throwsA(isA<auth.FirebaseAuthException>().having((e) => e.code, 'code', 'no-current-user')));
    });

    test('registerWithEmail handles verification email failure', () async {
      final mockCredential = MockUserCredential();
      when(mockAuth.createUserWithEmailAndPassword(email: anyNamed('email'), password: anyNamed('password'))).thenAnswer((_) async => mockCredential);
      when(mockCredential.user).thenReturn(mockUser);
      when(mockUser.email).thenReturn('test@example.com');
      when(mockUser.uid).thenReturn('user_123');
      when(mockUser.updateDisplayName(any)).thenAnswer((_) async {});
      when(mockUser.sendEmailVerification()).thenThrow(Exception('Mail Error'));

      stubFirestoreUser('user_123');

      await repository.registerWithEmail('test@example.com', 'password', 'Test User');
      verify(mockUser.sendEmailVerification()).called(1);
    });

    test('validateCurrentUser handles user-not-found', () async {
      when(mockUser.reload()).thenThrow(auth.FirebaseAuthException(code: 'user-not-found'));
      when(mockAuth.authStateChanges()).thenAnswer((_) => Stream.fromIterable([null]));

      final isValid = await repository.validateCurrentUser();
      expect(isValid, isFalse);
      verify(mockAuth.signOut()).called(1);
    });

    test('_createUserDocumentIfNeeded recovers name even if provided name is null', () async {
      stubHttps();
      when(mockUser.emailVerified).thenReturn(true);

      stubFirestoreUser('user_123', exists: false);

      final mockPendingCollection = MockCollectionReference();
      final mockPendingDoc = MockDocumentReference();
      final mockPendingSnapshot = MockDocumentSnapshot();
      when(mockFirestore.collection(Collections.pendingProfiles)).thenReturn(mockPendingCollection);
      when(mockPendingCollection.doc('user_123')).thenReturn(mockPendingDoc);
      when(mockPendingDoc.get()).thenAnswer((_) async => mockPendingSnapshot);
      when(mockPendingSnapshot.exists).thenReturn(true);
      when(mockPendingSnapshot.data()).thenReturn({Fields.name: 'Auto Recovered Name', Fields.marketingOptIn: true});

      final mockCredential = MockUserCredential();
      when(mockAuth.signInWithEmailAndPassword(email: anyNamed('email'), password: anyNamed('password'))).thenAnswer((_) async => mockCredential);
      when(mockCredential.user).thenReturn(mockUser);

      await repository.signInWithEmail('test@example.com', 'password');

      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.createUserProfile)).called(1);
      verify(mockPendingDoc.delete()).called(1);
      verify(mockCallable.call(argThat(containsPair(Fields.name, 'Auto Recovered Name')))).called(1);
    });

    test('_createUserDocumentIfNeeded handles exceptions gracefully', () async {
      when(mockUser.emailVerified).thenReturn(true);
      when(mockUser.reload()).thenThrow(Exception('Reload Error'));

      stubFirestoreUser('user_123');

      await repository.ensureUserDocumentExists();
      verify(mockDoc.get()).called(1);
    });

    test('signInWithApple calls auth and creates profile', () async {
      stubHttps();
      final fakeApplePlatform = FakeApplePlatform();
      SignInWithApplePlatform.instance = fakeApplePlatform;

      final mockCredential = MockUserCredential();
      when(mockAuth.signInWithCredential(any)).thenAnswer((_) async => mockCredential);
      when(mockCredential.user).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('apple_user_123');

      final mockUserInfo = MockUserInfo();
      when(mockUserInfo.providerId).thenReturn('apple.com');
      when(mockUser.providerData).thenReturn([mockUserInfo]);
      when(mockUser.emailVerified).thenReturn(false);

      stubFirestoreUser('apple_user_123', exists: false);

      final mockPendingCollection = MockCollectionReference();
      final mockPendingDoc = MockDocumentReference();
      final mockPendingSnapshot = MockDocumentSnapshot();
      when(mockFirestore.collection(Collections.pendingProfiles)).thenReturn(mockPendingCollection);
      when(mockPendingCollection.doc(any)).thenReturn(mockPendingDoc);
      when(mockPendingDoc.set(any, any)).thenAnswer((_) async {});
      when(mockPendingDoc.get()).thenAnswer((_) async => mockPendingSnapshot);
      when(mockPendingSnapshot.exists).thenReturn(false);
      when(mockPendingDoc.delete()).thenAnswer((_) async {});

      await repository.signInWithApple();

      verify(mockAuth.signInWithCredential(any)).called(1);
      verify(mockFunctions.httpsCallable(CloudFunctionEndpoints.createUserProfile)).called(1);
      verify(mockPendingDoc.set(any, any)).called(1);
    });

    test('registerWithEmail validates email format', () async {
      expect(
        () => repository.registerWithEmail('bad-email', 'password', 'Name'),
        throwsA(isA<auth.FirebaseAuthException>().having((e) => e.code, 'code', 'invalid-email')),
      );
    });

    test('signInWithEmail validates email format', () async {
      expect(
        () => repository.signInWithEmail('bad-email', 'password'),
        throwsA(isA<auth.FirebaseAuthException>().having((e) => e.code, 'code', 'invalid-email')),
      );
    });

    test('sendPasswordResetEmail validates email format', () async {
      expect(() => repository.sendPasswordResetEmail('bad-email'), throwsA(isA<auth.FirebaseAuthException>().having((e) => e.code, 'code', 'invalid-email')));
    });

    test('sendEmailVerification returns early if already verified', () async {
      when(mockUser.emailVerified).thenReturn(true);
      await repository.sendEmailVerification();
      verifyNever(mockUser.sendEmailVerification());
    });

    test('validateCurrentUser skips firestore for unverified users', () async {
      when(mockUser.emailVerified).thenReturn(false);
      when(mockEnvConfig.isEmulator).thenReturn(false);

      final result = await repository.validateCurrentUser();
      expect(result, isTrue);
      verifyNever(mockFirestore.collection(any));
    });
  });
}

class FakeApplePlatform extends Fake with MockPlatformInterfaceMixin implements SignInWithApplePlatform {
  @override
  Future<AuthorizationCredentialAppleID> getAppleIDCredential({
    String? nonce,
    required List<AppleIDAuthorizationScopes> scopes,
    String? state,
    WebAuthenticationOptions? webAuthenticationOptions,
  }) async {
    return const AuthorizationCredentialAppleID(
      authorizationCode: 'auth_code',
      identityToken: 'id_token',
      userIdentifier: 'apple_user_123',
      givenName: 'Test',
      familyName: 'User',
      email: 'test@example.com',
      state: 'mock_state',
    );
  }
}
