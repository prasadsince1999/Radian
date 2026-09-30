import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sectograph_mcp/core/i18n/date_labels.dart';
import 'package:sectograph_mcp/core/i18n/numeral_system.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  group('NumeralConverter', () {
    test('converts Latin digits to Devanagari correctly', () {
      expect(NumeralConverter.convert('0123456789', NumeralSystem.devanagari), '०१२३४५६७८९');
      expect(NumeralConverter.convert('14:30', NumeralSystem.devanagari), '१४:३०');
      expect(NumeralConverter.formatInt(42, NumeralSystem.devanagari), '४२');
    });

    test('converts Latin digits to Bengali correctly', () {
      expect(NumeralConverter.convert('0123456789', NumeralSystem.bengali), '০১২৩৪৫৬৭৮৯');
      expect(NumeralConverter.convert('09:15', NumeralSystem.bengali), '০৯:১৫');
      expect(NumeralConverter.formatInt(108, NumeralSystem.bengali), '১০৮');
    });

    test('converts Latin digits to Odia correctly', () {
      expect(NumeralConverter.convert('0123456789', NumeralSystem.odia), '୦୧୨୩୪୫୬୭୮୯');
      expect(NumeralConverter.convert('12:00 PM', NumeralSystem.odia), '୧୨:୦୦ PM');
      expect(NumeralConverter.formatInt(7, NumeralSystem.odia), '୭');
    });

    test('converts Latin digits to Arabic-Indic correctly', () {
      expect(NumeralConverter.convert('0123456789', NumeralSystem.arabicIndic), '٠١٢٣٤٥٦٧٨٩');
      expect(NumeralConverter.convert('18:45', NumeralSystem.arabicIndic), '١٨:٤٥');
      expect(NumeralConverter.formatInt(2026, NumeralSystem.arabicIndic), '٢٠٢٦');
    });

    test('preserves Latin digits when latin system is selected', () {
      expect(NumeralConverter.convert('12:34 PM', NumeralSystem.latin), '12:34 PM');
      expect(NumeralConverter.formatInt(99, NumeralSystem.latin), '99');
    });

    test('preserves non-digit characters and punctuation across all systems', () {
      const text = 'Meeting @ 10:30 AM (Room 404 - 5th Floor)';
      final dev = NumeralConverter.convert(text, NumeralSystem.devanagari);
      expect(dev, 'Meeting @ १०:३० AM (Room ४०४ - ५th Floor)');

      final ar = NumeralConverter.convert(text, NumeralSystem.arabicIndic);
      expect(ar, 'Meeting @ ١٠:٣٠ AM (Room ٤٠٤ - ٥th Floor)');
    });
  });

  group('DateLabels English Normalization ("Sept" -> "Sep")', () {
    test('normalizes Sept to Sep in September strings', () {
      expect(DateLabels.normalizeEnglishAbbreviation('Wed, 30 Sept', 9), 'Wed, 30 Sep');
      expect(DateLabels.normalizeEnglishAbbreviation('Wednesday, Sept 30', 9), 'Wednesday, Sep 30');
    });

    test('does not modify strings for other months', () {
      expect(DateLabels.normalizeEnglishAbbreviation('Wed, 28 Oct', 10), 'Wed, 28 Oct');
      expect(DateLabels.normalizeEnglishAbbreviation('Wed, 15 Jan', 1), 'Wed, 15 Jan');
    });

    test('formatDialDate guarantees "Sep" for September in English', () {
      final sepDate = DateTime(2026, 9, 30, 14, 0);
      final formatted = DateLabels.formatDialDate(sepDate, locale: 'en_US');
      expect(formatted, contains('Sep'));
      expect(formatted, isNot(contains('Sept')));
      expect(formatted, 'Wed, 30 Sep');
    });
  });

  group('DateLabels formatTime and formatTimeRange', () {
    final t1 = DateTime(2026, 9, 30, 9, 15);
    final t2 = DateTime(2026, 9, 30, 14, 45);

    test('formats 24H and 12H time correctly in Latin', () {
      expect(DateLabels.formatTime(t1, is24Hour: true), '09:15');
      expect(DateLabels.formatTime(t1, is24Hour: false, showAmPm: false), '9:15');
      expect(DateLabels.formatTime(t2, is24Hour: true), '14:45');
      expect(DateLabels.formatTime(t2, is24Hour: false, showAmPm: true), contains('2:45'));
    });

    test('formats time range with en-dash', () {
      final range24 = DateLabels.formatTimeRange(t1, t2, is24Hour: true);
      expect(range24, '09:15 – 14:45');

      final rangeDevanagari = DateLabels.formatTimeRange(
        t1,
        t2,
        is24Hour: true,
        numeralSystem: NumeralSystem.devanagari,
      );
      expect(rangeDevanagari, '०९:१५ – १४:४५');
    });
  });

  group('DateLabels formatDateHeading', () {
    final now = DateTime(2026, 9, 30, 12, 0);
    final today = DateTime(2026, 9, 30, 15, 0);
    final tomorrow = DateTime(2026, 10, 1, 9, 0);
    final yesterday = DateTime(2026, 9, 29, 18, 0);
    final nextWeek = DateTime(2026, 10, 7, 10, 0);

    test('prefixes relative dates correctly in English', () {
      expect(DateLabels.formatDateHeading(today, now, locale: 'en'), startsWith('Today, '));
      expect(DateLabels.formatDateHeading(tomorrow, now, locale: 'en'), startsWith('Tomorrow, '));
      expect(DateLabels.formatDateHeading(yesterday, now, locale: 'en'), startsWith('Yesterday, '));
      expect(DateLabels.formatDateHeading(nextWeek, now, locale: 'en'), isNot(startsWith('Today')));
    });

    test('respects numeral system in date heading', () {
      final headingDev = DateLabels.formatDateHeading(
        today,
        now,
        locale: 'en',
        numeralSystem: NumeralSystem.devanagari,
      );
      expect(headingDev, contains('३०'));
    });
  });

  group('DateLabels formatRemainingDuration', () {
    test('formats hours and minutes', () {
      expect(DateLabels.formatRemainingDuration(const Duration(hours: 1, minutes: 24)), '1h 24m');
      expect(DateLabels.formatRemainingDuration(const Duration(hours: 2)), '2h');
      expect(DateLabels.formatRemainingDuration(const Duration(minutes: 45)), '45m');
      expect(DateLabels.formatRemainingDuration(Duration.zero), '0m');
      expect(DateLabels.formatRemainingDuration(const Duration(minutes: -5)), '0m');
    });

    test('formats remaining duration with native numerals', () {
      final dur = const Duration(hours: 3, minutes: 15);
      expect(
        DateLabels.formatRemainingDuration(dur, numeralSystem: NumeralSystem.devanagari),
        '३h १५m',
      );
      expect(
        DateLabels.formatRemainingDuration(dur, numeralSystem: NumeralSystem.bengali),
        '৩h ১৫m',
      );
      expect(
        DateLabels.formatRemainingDuration(dur, numeralSystem: NumeralSystem.odia),
        '୩h ୧୫m',
      );
      expect(
        DateLabels.formatRemainingDuration(dur, numeralSystem: NumeralSystem.arabicIndic),
        '٣h ١٥m',
      );
    });
  });

  group('DateLabels formatTickHour', () {
    test('formats 12H dial ticks (0 -> 12, 12 -> 12)', () {
      expect(DateLabels.formatTickHour(0, is24Hour: false), '12');
      expect(DateLabels.formatTickHour(12, is24Hour: false), '12');
      expect(DateLabels.formatTickHour(6, is24Hour: false), '6');
      expect(DateLabels.formatTickHour(11, is24Hour: false), '11');
      expect(DateLabels.formatTickHour(15, is24Hour: false), '3');
    });

    test('formats 24H dial ticks (0..23)', () {
      expect(DateLabels.formatTickHour(0, is24Hour: true), '0');
      expect(DateLabels.formatTickHour(12, is24Hour: true), '12');
      expect(DateLabels.formatTickHour(23, is24Hour: true), '23');
    });

    test('formats ticks with native numerals', () {
      expect(
        DateLabels.formatTickHour(12, is24Hour: false, numeralSystem: NumeralSystem.devanagari),
        '१२',
      );
      expect(
        DateLabels.formatTickHour(6, is24Hour: false, numeralSystem: NumeralSystem.odia),
        '୬',
      );
      expect(
        DateLabels.formatTickHour(18, is24Hour: true, numeralSystem: NumeralSystem.arabicIndic),
        '١٨',
      );
    });
  });

  group('DateLabels Multi-Locale Integration', () {
    final testDate = DateTime(2026, 9, 30, 10, 0);

    test('formats dial date across diverse locales without throwing', () {
      final locales = ['en', 'hi', 'bn', 'or', 'ta', 'ar', 'ja'];
      for (final loc in locales) {
        final res = DateLabels.formatDialDate(testDate, locale: loc);
        expect(res, isNotEmpty, reason: 'Failed for locale: $loc');
      }
    });
  });
}
