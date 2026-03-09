import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/utils/utils.dart';

void main() {
  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
  });

  group('Regression Fixes Unit Tests', () {
    test('AppError.getMessage sanitizes backend errors', () {
      final fakeFirebaseException = FirebaseException(
        plugin: 'firestore',
        message: 'The query requires an index. You can create it here: https://console.firebase.google.com/...',
      );
      final msg1 = AppError.getMessage(fakeFirebaseException, 'fallback error');
      expect(msg1, isNot(contains('requires an index')));
      expect(msg1, isNot(contains('console.firebase.google.com')));

      final fakeFunctionsException = FirebaseFunctionsException(code: 'failed-precondition', message: 'FailedPrecondition: The query requires an index.');
      final msg2 = AppError.getMessage(fakeFunctionsException, 'fallback error');
      expect(msg2, isNot(contains('FailedPrecondition')));
      expect(msg2, isNot(contains('requires an index')));
    });

    test('Subcategories cover all 21 categories', () {
      for (int i = 1; i <= 21; i++) {
        final subcategories = SubcategoryConstants.forCategoryId(i);
        expect(subcategories, isNotEmpty, reason: 'Category ID $i should have subcategories defined');
      }
    });
  });
}
