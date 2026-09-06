import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  /// Format bytes to human readable string (e.g. "18.2 MB")
  static String formatBytes(int? bytes, [int decimals = 1]) {
    if (bytes == null || bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double count = bytes.toDouble();
    while (count >= 1024 && i < suffixes.length - 1) {
      count /= 1024;
      i++;
    }
    return '${count.toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  /// Format duration seconds to "mm:ss" or "hh:mm:ss"
  static String formatDuration(int seconds) {
    if (seconds <= 0) return '00:00';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  /// Format date for display (e.g. "Today", "Yesterday", "Oct 12")
  static String formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final aDate = DateTime(date.year, date.month, date.day);
    final difference = today.difference(aDate).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return DateFormat('EEEE').format(date); // e.g. "Monday"
    } else if (date.year == now.year) {
      return DateFormat('MMM d').format(date); // e.g. "Oct 12"
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }
}
