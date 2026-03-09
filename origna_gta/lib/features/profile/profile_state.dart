
/// Documentation for ProfileState
class ProfileState {
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;
  final bool isDeleted;

  ProfileState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
    this.isDeleted = false,
  });

  ProfileState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    bool? isDeleted,
  }) {
    return ProfileState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
