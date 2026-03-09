// coverage:ignore-file
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/features/admin/admin_providers.dart';
import 'package:origna_gta/features/admin/admin_repository.dart';
import 'package:origna_gta/utils/utils.dart';

final adminActionsViewModelProvider = StateNotifierProvider.autoDispose<AdminActionsViewModel, AdminActionsState>((ref) {
  return AdminActionsViewModel(ref);
});

/// Documentation for AdminActionsState
class AdminActionsState {
  final bool isLoading;
  final bool isSuccess;
  final String? errorMessage;

  const AdminActionsState({this.isLoading = false, this.isSuccess = false, this.errorMessage});

  AdminActionsState copyWith({bool? isLoading, bool? isSuccess, String? errorMessage}) {
    return AdminActionsState(isLoading: isLoading ?? this.isLoading, isSuccess: isSuccess ?? this.isSuccess, errorMessage: errorMessage);
  }
}

/// Documentation for AdminActionsViewModel
class AdminActionsViewModel extends StateNotifier<AdminActionsState> {
  final Ref _ref;

  AdminActionsViewModel(this._ref) : super(AdminActionsState());

  AdminRepository get _repository => _ref.read(adminRepositoryProvider);

  Future<bool> approveProduct(String productId) async {
    state = state.copyWith(isLoading: true, isSuccess: false, errorMessage: null);
    try {
      await _repository.approveProduct(productId);
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: AppError.getMessage(e, 'Failed to approve product'));
      return false;
    }
  }

  Future<bool> rejectProduct(String productId, String reason) async {
    state = state.copyWith(isLoading: true, isSuccess: false, errorMessage: null);
    try {
      await _repository.rejectProduct(productId, reason);
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: AppError.getMessage(e, 'Failed to reject product'));
      return false;
    }
  }

  Future<bool> deleteProduct(String productId) async {
    state = state.copyWith(isLoading: true, isSuccess: false, errorMessage: null);
    try {
      await _repository.deleteProduct(productId);
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: AppError.getMessage(e, 'admin.errors.delete_product_failed'.tr()));
      return false;
    }
  }

  Future<bool> disableAdminMfa(String code) async {
    state = state.copyWith(isLoading: true, isSuccess: false, errorMessage: null);
    try {
      await _repository.disableAdminMfa(code);
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: AppError.getMessage(e, 'admin.errors.mfa_disable_failed'.tr()));
      return false;
    }
  }

  Future<Map<String, dynamic>?> enableAdminMfa() async {
    state = state.copyWith(isLoading: true, isSuccess: false, errorMessage: null);
    try {
      final result = await _repository.enableAdminMfa();
      state = state.copyWith(isLoading: false, isSuccess: true);
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: AppError.getMessage(e, 'admin.errors.mfa_enable_failed'.tr()));
      return null;
    }
  }

  Future<UserModel?> fetchUserById(String userId) async {
    try {
      return await _repository.fetchUserById(userId);
    } catch (_) {
      return null;
    }
  }

  Future<bool> setUserSuspended(String userId, bool suspended) async {
    state = state.copyWith(isLoading: true, isSuccess: false, errorMessage: null);
    try {
      await _repository.setUserSuspended(userId, suspended);
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: AppError.getMessage(e, 'admin.errors.user_suspension_failed'.tr()));
      return false;
    }
  }

  Future<bool> updateProductStock(String productId, int quantity) async {
    state = state.copyWith(isLoading: true, isSuccess: false, errorMessage: null);
    try {
      await _repository.updateProductStock(productId, quantity);
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: AppError.getMessage(e, 'admin.errors.update_stock_failed'.tr()));
      return false;
    }
  }

  Future<bool> updateUserRoles(String userId, {List<String> add = const [], List<String> remove = const []}) async {
    state = state.copyWith(isLoading: true, isSuccess: false, errorMessage: null);
    try {
      await _repository.updateUserRoles(userId, add: add, remove: remove);
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: AppError.getMessage(e, 'admin.errors.user_roles_failed'.tr()));
      return false;
    }
  }

  Future<bool> verifyAdminMfa(String code) async {
    state = state.copyWith(isLoading: true, isSuccess: false, errorMessage: null);
    try {
      await _repository.verifyAdminMfa(code);
      state = state.copyWith(isLoading: false, isSuccess: true);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: AppError.getMessage(e, 'admin.errors.mfa_verify_failed'.tr()));
      return false;
    }
  }
}
