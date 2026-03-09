import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:origna_gta/features/profile/profile_viewmodel.dart';
import 'package:origna_gta/core/repositories/auth_repository.dart';
import 'package:origna_gta/core/repositories/user_repository.dart';
import 'package:origna_gta/core/providers.dart';

@GenerateNiceMocks([
  MockSpec<AuthRepository>(),
  MockSpec<UserRepository>(),
])
import 'profile_viewmodel_test.mocks.dart';

void main() {
  late MockAuthRepository mockAuthRepo;
  late MockUserRepository mockUserRepo;
  late ProviderContainer container;

  setUp(() {
    mockAuthRepo = MockAuthRepository();
    mockUserRepo = MockUserRepository();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepo),
        userRepositoryProvider.overrideWithValue(mockUserRepo),
        userIdProvider.overrideWith((ref) => 'user_123'),
      ],
    );
  });

  group('ProfileViewModel Tests', () {
    test('signOut calls repository', () async {
      await container.read(profileViewModelProvider.notifier).signOut();
      verify(mockAuthRepo.signOut()).called(1);
    });

    test('updateLanguage calls repository', () async {
      await container.read(profileViewModelProvider.notifier).updateLanguage('fr');
      verify(mockUserRepo.updatePreferredLanguage('user_123', 'fr')).called(1);
    });

    test('deleteAccount requires confirmation', () async {
      await container.read(profileViewModelProvider.notifier).deleteAccount('WRONG');
      final state = container.read(profileViewModelProvider);
      expect(state.errorMessage, contains('DELETE'));
      verifyNever(mockAuthRepo.deleteAccount());
    });

    test('deleteAccount calls repository on correct confirmation', () async {
      await container.read(profileViewModelProvider.notifier).deleteAccount('DELETE');
      verify(mockAuthRepo.deleteAccount()).called(1);
    });
  });
}
