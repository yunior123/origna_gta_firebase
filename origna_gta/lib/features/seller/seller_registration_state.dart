// seller_registration_state.dart
import 'package:origna_gta/core/schema/schema_constants.dart';

/// Documentation for SellerRegistrationState
class SellerRegistrationState {
  final bool isLoading;
  final String? error;
  final String? successMessage;
  final String paymentProvider;

  const SellerRegistrationState({this.isLoading = false, this.error, this.successMessage, this.paymentProvider = PaymentProviderValues.stripe});

  SellerRegistrationState copyWith({
    bool? isLoading,
    Object? error = _sentinel,
    Object? successMessage = _sentinel,
    String? paymentProvider,
  }) {
    return SellerRegistrationState(
      isLoading: isLoading ?? this.isLoading,
      error: error == _sentinel ? this.error : error as String?,
      successMessage: successMessage == _sentinel ? this.successMessage : successMessage as String?,
      paymentProvider: paymentProvider ?? this.paymentProvider,
    );
  }
}

const Object _sentinel = Object();
