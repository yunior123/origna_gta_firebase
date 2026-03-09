/// Documentation for SellerOrdersState
class SellerOrdersState {
  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;

  const SellerOrdersState({
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
  });

  SellerOrdersState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? isSuccess,
  }) {
    return SellerOrdersState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}
