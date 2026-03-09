import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origna_gta/features/notifications/notification_provider.dart';

void main() {
  group('NotificationPermissionNotifier Tests', () {
    test('initial state is false', () {
      final container = ProviderContainer();
      expect(container.read(notificationPermissionProvider), isFalse);
    });

    test('setGranted updates state', () {
      final container = ProviderContainer();
      container.read(notificationPermissionProvider.notifier).setGranted(true);
      expect(container.read(notificationPermissionProvider), isTrue);
      
      container.read(notificationPermissionProvider.notifier).setGranted(false);
      expect(container.read(notificationPermissionProvider), isFalse);
    });
  });
}
