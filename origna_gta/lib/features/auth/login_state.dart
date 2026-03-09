// Sentinel object: distinguishes "not provided" from explicit null in copyWith calls.
const _omit = Object();

/// Documentation for LoginState
class LoginState {
  final bool isLoading;
  final bool isLogin;
  final bool obscurePassword;
  final bool acceptedTerms;
  final bool marketingOptIn; // CASL/Loi 25: separate marketing consent
  final String? errorMessage;
  final String? successMessage;
  final bool isSuccess;

  LoginState({
    this.isLoading = false,
    this.isLogin = true,
    this.obscurePassword = true,
    this.acceptedTerms = false,
    this.marketingOptIn = false,
    this.errorMessage,
    this.successMessage,
    this.isSuccess = false,
  });

  LoginState copyWith({
    bool? isLoading,
    bool? isLogin,
    bool? obscurePassword,
    bool? acceptedTerms,
    bool? marketingOptIn,
    Object? errorMessage = _omit,
    Object? successMessage = _omit,
    bool? isSuccess,
  }) {
    return LoginState(
      isLoading: isLoading ?? this.isLoading,
      isLogin: isLogin ?? this.isLogin,
      obscurePassword: obscurePassword ?? this.obscurePassword,
      acceptedTerms: acceptedTerms ?? this.acceptedTerms,
      marketingOptIn: marketingOptIn ?? this.marketingOptIn,
      errorMessage: identical(errorMessage, _omit) ? this.errorMessage : errorMessage as String?,
      successMessage: identical(successMessage, _omit) ? this.successMessage : successMessage as String?,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}
