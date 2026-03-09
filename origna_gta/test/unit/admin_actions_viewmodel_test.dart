import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:origna_gta/features/admin/admin_actions_viewmodel.dart';
import 'package:origna_gta/features/admin/admin_repository.dart';
import 'package:origna_gta/features/admin/admin_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@GenerateNiceMocks([MockSpec<AdminRepository>()])
import 'admin_actions_viewmodel_test.mocks.dart';

void main() {
  late MockAdminRepository mockRepo;
  late ProviderContainer container;

  setUp(() {
    mockRepo = MockAdminRepository();
    container = ProviderContainer(
      overrides: [
        adminRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
  });

  group('AdminActionsViewModel', () {
    test('approveProduct calls repository and succeeds', () async {
      when(mockRepo.approveProduct('p123')).thenAnswer((_) async => true);
      
      final viewModel = container.read(adminActionsViewModelProvider.notifier);
      final result = await viewModel.approveProduct('p123');

      expect(result, isTrue);
      expect(container.read(adminActionsViewModelProvider).isLoading, isFalse);
      verify(mockRepo.approveProduct('p123')).called(1);
    });

    test('rejectProduct calls repository and succeeds', () async {
      when(mockRepo.rejectProduct('p123', 'Poor quality')).thenAnswer((_) async => true);
      
      final viewModel = container.read(adminActionsViewModelProvider.notifier);
      final result = await viewModel.rejectProduct('p123', 'Poor quality');

      expect(result, isTrue);
      verify(mockRepo.rejectProduct('p123', 'Poor quality')).called(1);
    });

    test('setUserSuspended calls repository', () async {
      when(mockRepo.setUserSuspended('u123', true)).thenAnswer((_) async => true);
      
      final viewModel = container.read(adminActionsViewModelProvider.notifier);
      await viewModel.setUserSuspended('u123', true);

      verify(mockRepo.setUserSuspended('u123', true)).called(1);
    });

    test('updateUserRoles calls repository', () async {
      when(mockRepo.updateUserRoles('u123', add: ['admin'], remove: [], reason: anyNamed('reason'))).thenAnswer((_) async => true);
      
      final viewModel = container.read(adminActionsViewModelProvider.notifier);
      await viewModel.updateUserRoles('u123', add: ['admin']);

      verify(mockRepo.updateUserRoles('u123', add: ['admin'], remove: [], reason: argThat(isNull, named: 'reason'))).called(1);
    });
  });
}
