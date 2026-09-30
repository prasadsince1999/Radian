import 'package:flutter/material.dart';

import '../i18n/date_labels.dart';

class TimeFormatters {
  TimeFormatters._();

  static String formatTime(DateTime time, {required bool is24Hour}) {
    return DateLabels.formatTime(time, is24Hour: is24Hour);
  }

  static String formatTimeOfDay(TimeOfDay tod, {bool is24Hour = false}) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, tod.hour, tod.minute);
    return formatTime(dt, is24Hour: is24Hour);
  }

  static String formatTimeRange(
    DateTime start,
    DateTime end, {
    required bool is24Hour,
  }) {
    return DateLabels.formatTimeRange(start, end, is24Hour: is24Hour);
  }

  static String formatDuration(Duration duration) {
    return DateLabels.formatRemainingDuration(duration);
  }

  static String formatDateHeading(DateTime date) {
    return DateLabels.formatDateHeading(date, DateTime.now());
  }
}
