import 'package:intl/intl.dart';

import 'numeral_system.dart';

/// Unified locale-aware date and time label formatter for app and widget surfaces (§5.4).
///
/// Features:
/// 1. Canonical 3-letter month abbreviation normalization ("Sept" -> "Sep" resolution).
/// 2. Locale-aware formatting via [intl.DateFormat].
/// 3. Pluggable [NumeralSystem] conversion (Latin, Devanagari, Bengali, Odia, Arabic-Indic).
/// 4. Shared contract for in-app dial, center summary, and home screen widget.
class DateLabels {
  DateLabels._();

  /// Canonical 3-letter month abbreviation override mapping for English.
  static const Map<int, String> _canonicalEnMonths = {
    1: 'Jan',
    2: 'Feb',
    3: 'Mar',
    4: 'Apr',
    5: 'May',
    6: 'Jun',
    7: 'Jul',
    8: 'Aug',
    9: 'Sep',
    10: 'Oct',
    11: 'Nov',
    12: 'Dec',
  };

  /// Normalizes month abbreviation in English strings so September is always 'Sep', never 'Sept'.
  static String normalizeEnglishAbbreviation(String formatted, int month) {
    if (month == 9 && formatted.contains('Sept')) {
      return formatted.replaceAll('Sept', 'Sep');
    }
    return formatted;
  }

  /// Formats time as 'HH:mm' (24H) or 'h:mm a' / 'h:mm' (12H).
  static String formatTime(
    DateTime time, {
    required bool is24Hour,
    bool showAmPm = true,
    String? locale,
    NumeralSystem numeralSystem = NumeralSystem.latin,
  }) {
    final pattern = is24Hour
        ? 'HH:mm'
        : (showAmPm ? 'h:mm a' : 'h:mm');
    final raw = DateFormat(pattern, locale).format(time);
    return NumeralConverter.convert(raw, numeralSystem);
  }

  /// Formats a time range e.g. "14:00 – 15:30" or "2:00 PM – 3:30 PM".
  static String formatTimeRange(
    DateTime start,
    DateTime end, {
    required bool is24Hour,
    bool showAmPm = false,
    String? locale,
    NumeralSystem numeralSystem = NumeralSystem.latin,
  }) {
    final s = formatTime(
      start,
      is24Hour: is24Hour,
      showAmPm: showAmPm,
      locale: locale,
      numeralSystem: numeralSystem,
    );
    final e = formatTime(
      end,
      is24Hour: is24Hour,
      showAmPm: showAmPm,
      locale: locale,
      numeralSystem: numeralSystem,
    );
    return '$s – $e';
  }

  /// Formats date for dial center / widget e.g. "Wed, 30 Sep".
  static String formatDialDate(
    DateTime date, {
    String? locale,
    NumeralSystem numeralSystem = NumeralSystem.latin,
  }) {
    final isEn = locale == null || locale.startsWith('en');
    String raw;
    if (isEn) {
      // Direct canonical format preventing 'Sept'
      final weekday = DateFormat('EEE', locale).format(date);
      final month = _canonicalEnMonths[date.month] ?? 'Sep';
      raw = '$weekday, ${date.day} $month';
    } else {
      raw = DateFormat('EEE, d MMM', locale).format(date);
    }

    return NumeralConverter.convert(raw, numeralSystem);
  }

  /// Formats full date heading e.g. "Today, Wednesday, Sep 30".
  static String formatDateHeading(
    DateTime date,
    DateTime now, {
    String? locale,
    NumeralSystem numeralSystem = NumeralSystem.latin,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    String prefix = '';
    if (target == today) {
      prefix = 'Today, ';
    } else if (target == today.add(const Duration(days: 1))) {
      prefix = 'Tomorrow, ';
    } else if (target == today.subtract(const Duration(days: 1))) {
      prefix = 'Yesterday, ';
    }

    var body = DateFormat('EEEE, MMM d', locale).format(date);
    body = normalizeEnglishAbbreviation(body, date.month);

    final result = '$prefix$body';
    return NumeralConverter.convert(result, numeralSystem);
  }

  /// Formats remaining duration e.g. "1h 24m" or "45m".
  static String formatRemainingDuration(
    Duration duration, {
    NumeralSystem numeralSystem = NumeralSystem.latin,
  }) {
    final totalMinutes = duration.inMinutes;
    if (totalMinutes <= 0) {
      return NumeralConverter.convert('0m', numeralSystem);
    }

    final hours = duration.inHours;
    final minutes = totalMinutes % 60;

    final String raw;
    if (hours > 0 && minutes > 0) {
      raw = '${hours}h ${minutes}m';
    } else if (hours > 0) {
      raw = '${hours}h';
    } else {
      raw = '${minutes}m';
    }

    return NumeralConverter.convert(raw, numeralSystem);
  }

  /// Formats a single hour tick label on the dial face (0..23 or 1..12).
  static String formatTickHour(
    int hour, {
    required bool is24Hour,
    NumeralSystem numeralSystem = NumeralSystem.latin,
  }) {
    final int displayHour;
    if (is24Hour) {
      displayHour = hour % 24;
    } else {
      displayHour = (hour == 0 || hour == 12) ? 12 : (hour % 12);
    }

    return NumeralConverter.convert(displayHour.toString(), numeralSystem);
  }
}
