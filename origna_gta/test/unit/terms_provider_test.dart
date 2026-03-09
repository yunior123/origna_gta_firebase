import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/features/terms/terms_provider.dart';

void main() {
  group('TermsProvider Tests', () {
    test('returns default terms when Firebase is not available', () async {
      final container = ProviderContainer();
      final terms = await container.read(termsProvider.future);
      expect(terms, contains('Welcome to OrignaGTA'));
    });
  });
}
