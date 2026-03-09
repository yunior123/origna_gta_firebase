/// F-74: Centralised validation constants — single source of truth.
/// All email validation across the app MUST use [ValidationConstants.emailRegex].
abstract final class ValidationConstants {
  /// RFC 5322 simplified email regex — same pattern used in auth_repository and login_viewmodel.
  static final RegExp emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

  /// F-84: Strong password policy — single source of truth.
  /// Requires: 8+ chars, 1 upper, 1 lower, 1 digit, 1 special.
  static final RegExp passwordRegex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*(),.?":{}|<>])[A-Za-z\d!@#$%^&*(),.?":{}|<>]{8,}$');

  static const int minPasswordLength = 8;
  static const int maxEmailLength = 254;
  static const int minEmailLength = 6;
  static const int minNameLength = 2;
  static const int maxNameLength = 60;

  /// Common weak passwords to reject
  static const List<String> commonPasswords = ['password', '12345678', 'qwerty123', 'abc123456', 'password1'];
}
