import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/utils/utils.dart';
import 'profile_state.dart';

final profileViewModelProvider = StateNotifierProvider.autoDispose<ProfileViewModel, ProfileState>((ref) {
  return ProfileViewModel(ref);
});

/// Documentation for ProfileViewModel
class ProfileViewModel extends StateNotifier<ProfileState> {
  final Ref _ref;

  ProfileViewModel(this._ref) : super(ProfileState());

  Future<void> signOut() async {
    await _ref.read(authRepositoryProvider).signOut();
  }

  Future<void> updateLanguage(String langCode) async {
    final userId = _ref.read(userIdProvider);
    if (userId == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await _ref.read(userRepositoryProvider).updatePreferredLanguage(userId, langCode);
      state = state.copyWith(isLoading: false, successMessage: 'profile.language_updated'.tr());
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: AppError.getMessage(e, 'Failed to update language'));
    }
  }

  Future<void> exportData() async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      final functions = _ref.read(firebaseFunctionsProvider);
      await functions.httpsCallable(CloudFunctionEndpoints.exportUserData).call();
      state = state.copyWith(isLoading: false, successMessage: 'profile.export_started'.tr());
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: AppError.getMessage(e, 'Failed to export data'));
    }
  }

  Future<void> deleteAccount(String confirmation) async {
    if (confirmation.toUpperCase() != 'DELETE') {
      state = state.copyWith(errorMessage: 'Please type DELETE to confirm');
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await _ref.read(authRepositoryProvider).deleteAccount();
      state = state.copyWith(isLoading: false, isDeleted: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: AppError.getMessage(e, 'Failed to delete account'));
    }
  }
}
