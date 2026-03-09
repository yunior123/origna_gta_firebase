import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/features/auth/auth_provider.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/repositories/auth_repository.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/models/models.dart';

@GenerateNiceMocks([
  MockSpec<AuthRepository>(),
])
import 'auth_provider_test.mocks.dart';

void main() {
  late MockAuthRepository mockRepo;

  setUp(() {
    mockRepo = MockAuthRepository();
  });

  ProviderContainer createContainer({
    String? userId,
    Stream<UserModel?>? profileStream,
  }) {
    return ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockRepo),
        userIdProvider.overrideWithValue(userId),
        if (profileStream != null)
          userProfileProvider.overrideWith((ref) => profileStream),
      ],
    );
  }

  group('userProfileProvider', () {
    test('returns null if no userId', () async {
      final container = createContainer(userId: null);
      final profile = await container.read(userProfileProvider.future);
      expect(profile, isNull);
    });

    test('returns profile from repository', () async {
      final testUser = UserModel(
        uid: 'user_123',
        email: 'test@example.com',
        name: 'Test',
        roles: ['buyer'],
        createdAt: DateTime.now(),
      );
      
      when(mockRepo.watchProfile('user_123')).thenAnswer((_) => Stream.value(testUser));
      
      final container = createContainer(userId: 'user_123');
      final profile = await container.read(userProfileProvider.future);
      expect(profile, testUser);
    });
  });

  group('needsTermsUpdateProvider', () {
    test('returns false when loading', () {
      final container = createContainer(
        profileStream: const Stream.empty(),
      );
      
      final needsUpdate = container.read(needsTermsUpdateProvider);
      expect(needsUpdate, isFalse);
    });

    test('returns false when profile is null', () async {
      final container = createContainer(
        profileStream: Stream.value(null),
      );
      
      // Wait for stream
      await container.read(userProfileProvider.future);
      
      final needsUpdate = container.read(needsTermsUpdateProvider);
      expect(needsUpdate, isFalse);
    });

    test('returns false when termsVersion is null (pre-versioning)', () async {
      final testUser = UserModel(
        uid: 'u1', email: 'e', name: 'n', roles: [], createdAt: DateTime.now(),
        termsVersion: null,
      );
      final container = createContainer(
        profileStream: Stream.value(testUser),
      );
      
      await container.read(userProfileProvider.future);
      
      final needsUpdate = container.read(needsTermsUpdateProvider);
      expect(needsUpdate, isFalse);
    });

    test('returns false when termsVersion matches current', () async {
      final testUser = UserModel(
        uid: 'u1', email: 'e', name: 'n', roles: [], createdAt: DateTime.now(),
        termsVersion: PolicyVersionValues.defaultVersion,
      );
      final container = createContainer(
        profileStream: Stream.value(testUser),
      );
      
      await container.read(userProfileProvider.future);
      
      final needsUpdate = container.read(needsTermsUpdateProvider);
      expect(needsUpdate, isFalse);
    });

    test('returns true when termsVersion is outdated', () async {
      final testUser = UserModel(
        uid: 'u1', email: 'e', name: 'n', roles: [], createdAt: DateTime.now(),
        termsVersion: '0.1',
      );
      final container = createContainer(
        profileStream: Stream.value(testUser),
      );
      
      await container.read(userProfileProvider.future);
      
      final needsUpdate = container.read(needsTermsUpdateProvider);
      expect(needsUpdate, isTrue);
    });
  });
}
