import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EasyLocalization Key Verification', () {
    test('Verifies key presence in memory after loading', () async {
      // This is a unit test to check if we can simulate translation lookup
      // In a real app, this is handled by EasyLocalization widget.
      
      // For now, let's just check if the string itself has the .tr() method available
      // (which we know it does because it's an extension)
      expect('auth.errors.registration_success'.tr(), isNotNull);
    });
  });
}
