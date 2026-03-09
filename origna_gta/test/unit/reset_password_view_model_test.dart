import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/features/auth/reset_password_view_model.dart';

@GenerateNiceMocks([MockSpec<FirebaseAuth>()])
import 'reset_password_view_model_test.mocks.dart';

void main() {
  late MockFirebaseAuth mockAuth;
  late ProviderContainer container;
  const oobCode = 'test-code';

  setUp(() {
    mockAuth = MockFirebaseAuth();
    container = ProviderContainer(overrides: [firebaseAuthProvider.overrideWithValue(mockAuth)]);
  });

  group('ResetPasswordViewModel', () {
    test('initialization calls verifyPasswordResetCode', () async {
      when(mockAuth.verifyPasswordResetCode(oobCode)).thenAnswer((_) async => 'test@example.com');

      final keepAlive = container.listen(resetPasswordViewModelProvider(oobCode), (_, _) {});
      container.read(resetPasswordViewModelProvider(oobCode).notifier);

      // Wait for async initialization in constructor
      await Future.delayed(Duration.zero);

      final state = container.read(resetPasswordViewModelProvider(oobCode));
      expect(state.userEmail, 'test@example.com');
      expect(state.isVerifying, isFalse);
      verify(mockAuth.verifyPasswordResetCode(oobCode)).called(1);
      keepAlive.close();
    });

    test('initialization handles FirebaseAuthException codes', () async {
      final codes = ['expired-action-code', 'invalid-action-code', 'user-disabled', 'user-not-found', 'weak-password', 'other'];

      for (final code in codes) {
        when(mockAuth.verifyPasswordResetCode(oobCode)).thenThrow(FirebaseAuthException(code: code));

        final keepAlive = container.listen(resetPasswordViewModelProvider(oobCode), (_, _) {});
        container.read(resetPasswordViewModelProvider(oobCode).notifier);
        await Future.delayed(Duration.zero);

        final state = container.read(resetPasswordViewModelProvider(oobCode));
        expect(state.errorMessage, isNotNull, reason: 'Failed for code: $code');
        expect(state.isVerifying, isFalse);
        keepAlive.close();

        // Reset container/state for next iteration
        container = ProviderContainer(overrides: [firebaseAuthProvider.overrideWithValue(mockAuth)]);
      }
    });

    test('initialization handles generic error', () async {
      when(mockAuth.verifyPasswordResetCode(oobCode)).thenThrow(Exception('unknown'));

      final keepAlive = container.listen(resetPasswordViewModelProvider(oobCode), (_, _) {});
      container.read(resetPasswordViewModelProvider(oobCode).notifier);
      await Future.delayed(Duration.zero);

      final state = container.read(resetPasswordViewModelProvider(oobCode));
      expect(state.errorMessage, isNotNull);
      expect(state.isVerifying, isFalse);
      keepAlive.close();
    });

    test('resetPassword validates password requirements', () async {
      when(mockAuth.verifyPasswordResetCode(oobCode)).thenAnswer((_) async => 'test@example.com');
      final viewModel = container.read(resetPasswordViewModelProvider(oobCode).notifier);
      final keepAlive = container.listen(resetPasswordViewModelProvider(oobCode), (_, _) {});
      await Future.delayed(Duration.zero);

      // Empty
      await viewModel.resetPassword('', '');
      expect(container.read(resetPasswordViewModelProvider(oobCode)).errorMessage, isNotNull);

      // Too short
      await viewModel.resetPassword('123', '123');
      expect(container.read(resetPasswordViewModelProvider(oobCode)).errorMessage, isNotNull);

      // Mismatch
      await viewModel.resetPassword('Password123!', 'Password124!');
      expect(container.read(resetPasswordViewModelProvider(oobCode)).errorMessage, isNotNull);
      keepAlive.close();
    });

    test('resetPassword success', () async {
      when(mockAuth.verifyPasswordResetCode(oobCode)).thenAnswer((_) async => 'test@example.com');
      when(mockAuth.confirmPasswordReset(code: oobCode, newPassword: 'Password123!')).thenAnswer((_) async {});

      final viewModel = container.read(resetPasswordViewModelProvider(oobCode).notifier);
      final keepAlive = container.listen(resetPasswordViewModelProvider(oobCode), (_, _) {});
      await Future.delayed(Duration.zero);

      await viewModel.resetPassword('Password123!', 'Password123!');

      final state = container.read(resetPasswordViewModelProvider(oobCode));
      expect(state.isSuccess, isTrue);
      expect(state.isLoading, isFalse);
      verify(mockAuth.confirmPasswordReset(code: oobCode, newPassword: 'Password123!')).called(1);
      keepAlive.close();
    });

    test('resetPassword handles failure', () async {
      when(mockAuth.verifyPasswordResetCode(oobCode)).thenAnswer((_) async => 'test@example.com');
      when(mockAuth.confirmPasswordReset(code: anyNamed('code'), newPassword: anyNamed('newPassword'))).thenThrow(FirebaseAuthException(code: 'weak-password'));

      final viewModel = container.read(resetPasswordViewModelProvider(oobCode).notifier);
      final keepAlive = container.listen(resetPasswordViewModelProvider(oobCode), (_, _) {});
      await Future.delayed(Duration.zero);

      await viewModel.resetPassword('Password123!', 'Password123!');

      final state = container.read(resetPasswordViewModelProvider(oobCode));
      expect(state.errorMessage, isNotNull);
      expect(state.isLoading, isFalse);
      keepAlive.close();
    });

    test('resetPassword handles generic failure', () async {
      when(mockAuth.verifyPasswordResetCode(oobCode)).thenAnswer((_) async => 'test@example.com');
      when(mockAuth.confirmPasswordReset(code: anyNamed('code'), newPassword: anyNamed('newPassword'))).thenThrow(Exception('error'));

      final viewModel = container.read(resetPasswordViewModelProvider(oobCode).notifier);
      final keepAlive = container.listen(resetPasswordViewModelProvider(oobCode), (_, _) {});
      await Future.delayed(Duration.zero);

      await viewModel.resetPassword('Password123!', 'Password123!');

      final state = container.read(resetPasswordViewModelProvider(oobCode));
      expect(state.errorMessage, isNotNull);
      expect(state.isLoading, isFalse);
      keepAlive.close();
    });
  });
}
