import 'package:flutter_test/flutter_test.dart';
import 'package:able_app/core/utils/formatters.dart';

void main() {
  group('Formatters Unit Tests', () {
    test('formatBytes formats bytes properly', () {
      expect(Formatters.formatBytes(0), '0 B');
      expect(Formatters.formatBytes(500), '500.0 B');
      expect(Formatters.formatBytes(1024), '1.0 KB');
      expect(Formatters.formatBytes(1024 * 1024 * 24), '24.0 MB');
      expect(Formatters.formatBytes(1024 * 1024 * 1024 * 2), '2.0 GB');
    });

    test('formatDuration formats seconds to MM:SS and HH:MM:SS', () {
      expect(Formatters.formatDuration(0), '00:00');
      expect(Formatters.formatDuration(45), '00:45');
      expect(Formatters.formatDuration(260), '04:20');
      expect(Formatters.formatDuration(3665), '01:01:05');
    });

    test('formatRelativeDate handles today and dates', () {
      final now = DateTime.now();
      expect(Formatters.formatRelativeDate(now), 'Today');
      final yesterday = now.subtract(const Duration(days: 1));
      expect(Formatters.formatRelativeDate(yesterday), 'Yesterday');
    });
  });
}
