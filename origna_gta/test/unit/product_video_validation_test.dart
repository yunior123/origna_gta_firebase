import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/utils/utils.dart';

void main() {
  group('Product Video Validation', () {
    test('validateVideoFile returns none for valid video', () {
      final result = validateVideoFile(sizeInBytes: BusinessRules.maxVideoBytes - 100, durationInSeconds: BusinessRules.maxVideoDurationSeconds - 1);
      expect(result, VideoValidationError.none);
    });

    test('validateVideoFile returns tooLarge for oversized video', () {
      final result = validateVideoFile(sizeInBytes: BusinessRules.maxVideoBytes + 1, durationInSeconds: 30);
      expect(result, VideoValidationError.tooLarge);
    });

    test('validateVideoFile returns tooLong for overly long video', () {
      final result = validateVideoFile(sizeInBytes: 10 * 1024 * 1024, durationInSeconds: BusinessRules.maxVideoDurationSeconds + 1);
      expect(result, VideoValidationError.tooLong);
    });

    test('validateVideoFile prioritizes size error over duration error', () {
      final result = validateVideoFile(sizeInBytes: BusinessRules.maxVideoBytes + 1, durationInSeconds: BusinessRules.maxVideoDurationSeconds + 1);
      expect(result, VideoValidationError.tooLarge);
    });
  });
}
