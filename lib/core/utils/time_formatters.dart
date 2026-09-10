import 'package:intl/intl.dart';

class TimeFormatters {
  TimeFormatters._();

  static String formatTime(DateTime time, {required bool is24Hour}) {
    if (is24Hour) {
      return DateFormat('HH:mm').format(time);
    } else {
      return DateFormat('h:mm a').format(time);
    }
  }

  static String formatTimeRange(
    DateTime start,
    DateTime end, {
    required bool is24Hour,
  }) {
    final s = formatTime(start, is24Hour: is24Hour);
    final e = formatTime(end, is24Hour: is24Hour);
    return '$s – $e';
  }

  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${minutes}m';
    }
  }

  static String formatDateHeading(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    if (target == today) {
      return 'Today, ${DateFormat('EEEE, MMM d').format(date)}';
    } else if (target == today.add(const Duration(days: 1))) {
      return 'Tomorrow, ${DateFormat('EEEE, MMM d').format(date)}';
    } else if (target == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, ${DateFormat('EEEE, MMM d').format(date)}';
    } else {
      return DateFormat('EEEE, MMM d, yyyy').format(date);
    }
  }
}
