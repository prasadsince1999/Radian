import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:sectograph_mcp/core/time/zone_clock.dart';
import 'package:sectograph_mcp/domain/models/dial_settings.dart';
import 'package:sectograph_mcp/engine/dial_input.dart';
import 'package:sectograph_mcp/engine/dial_model.dart';
import 'package:sectograph_mcp/engine/dial_model_builder.dart';

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
  });

  group('Phase 8 Smart Features: Secondary Time Zone Needle', () {
    final nowUtc = DateTime.utc(2026, 10, 2, 12, 0); // 12:00 UTC
    final clock = ZoneClockSnapshot.fromDateTime(nowUtc, tzid: 'UTC');

    test('calculates secondary needle display angle and label correctly in UTC', () {
      final input = DialInput(
        clock: clock,
        occurrences: const [],
        prefs: const DialPrefs(
          is24HourMode: false,
          secondaryTimeZone: 'UTC',
        ),
      );

      final model = DialModelBuilder.build(input);

      expect(model.secondaryNeedle, isNotNull);
      final sec = model.secondaryNeedle!;
      expect(sec.timeZoneId, 'UTC');
      expect(sec.label, contains('12:00'));
      // In 12H mode, 12:00 is at 0 degrees
      expect(sec.naturalDeg, closeTo(0.0, 0.1));
    });

    test('calculates secondary needle for distant time zone (e.g. New York UTC-4)', () {
      // 12:00 UTC = 08:00 AM EDT (America/New_York)
      final input = DialInput(
        clock: clock,
        occurrences: const [],
        prefs: const DialPrefs(
          is24HourMode: false,
          secondaryTimeZone: 'America/New_York',
        ),
      );

      final model = DialModelBuilder.build(input);

      expect(model.secondaryNeedle, isNotNull);
      final sec = model.secondaryNeedle!;
      expect(sec.timeZoneId, 'America/New_York');
      expect(sec.label, contains('08:00'));
      // In 12H mode, 8:00 is at 8 * 30 = 240 degrees
      expect(sec.naturalDeg, closeTo(240.0, 0.5));
    });

    test('omits secondary needle when secondaryTimeZone is null', () {
      final input = DialInput(
        clock: clock,
        occurrences: const [],
        prefs: const DialPrefs(
          is24HourMode: false,
          secondaryTimeZone: null,
        ),
      );

      final model = DialModelBuilder.build(input);
      expect(model.secondaryNeedle, isNull);
    });
  });

  group('Phase 8 Smart Features: Hidden Blocks Tracking (I10)', () {
    final baseTime = DateTime(2026, 10, 2, 10, 0);
    final clock = ZoneClockSnapshot.fromDateTime(baseTime, tzid: 'UTC');

    test('populates HiddenEventInfo with angles and reasons when blocks exceed horizon', () {
      final occurrences = List.generate(6, (i) {
        final start = baseTime.add(Duration(hours: 1 + i));
        final end = start.add(const Duration(minutes: 45));
        return Occurrence(
          id: 'ev-$i',
          eventId: 'event-$i',
          title: 'Event $i',
          start: start,
          end: end,
          colorHex: '#3B82F6',
          category: 'Work',
        );
      });

      // With N = 2, only next1 and next2 are admitted; events 3, 4, 5 are hidden!
      final input = DialInput(
        clock: clock,
        occurrences: occurrences,
        prefs: const DialPrefs(
          is24HourMode: false,
          previousBlocksCount: 1,
          futureBlocksCount: 2,
        ),
      );

      final model = DialModelBuilder.build(input);

      expect(model.hidden.hiddenCount, greaterThanOrEqualTo(1));
      for (final hidden in model.hidden.hiddenEvents) {
        expect(hidden.eventId, isNotEmpty);
        expect(hidden.title, isNotEmpty);
        expect(hidden.reason, contains('exceedsHorizon'));
        expect(hidden.naturalAngleDeg, inInclusiveRange(0.0, 360.0));
      }
    });
  });

  group('Phase 8 Smart Features: DialModel JSON Round-Trip', () {
    final baseTime = DateTime(2026, 10, 2, 10, 0);
    final clock = ZoneClockSnapshot.fromDateTime(baseTime, tzid: 'UTC');

    test('preserves secondary needle and hidden summary through toJson and fromJson', () {
      final input = DialInput(
        clock: clock,
        occurrences: const [],
        prefs: const DialPrefs(
          is24HourMode: false,
          secondaryTimeZone: 'UTC',
        ),
      );

      final model = DialModelBuilder.build(input);
      final jsonMap = model.toJson();
      final restored = DialModel.fromJson(jsonMap);

      expect(restored.signature, model.signature);
      expect(restored.is24HourMode, model.is24HourMode);
      expect(restored.secondaryNeedle, isNotNull);
      expect(restored.secondaryNeedle!.timeZoneId, model.secondaryNeedle!.timeZoneId);
      expect(restored.secondaryNeedle!.displayDeg, model.secondaryNeedle!.displayDeg);
    });
  });

  group('Phase 8 Smart Features: DialSettings and DialPrefs defaults', () {
    test('DialSettings default values match Phase 8 spec', () {
      const settings = DialSettings();
      expect(settings.showTrueTimeRing, isTrue);
      expect(settings.secondaryTimeZone, isNull);
      expect(settings.showSubtaskPaceRing, isTrue);
      expect(settings.showHiddenBlocksIndicator, isTrue);
    });

    test('DialSettings serialization preserves Phase 8 fields', () {
      const settings = DialSettings(
        showTrueTimeRing: false,
        secondaryTimeZone: 'Asia/Tokyo',
        showSubtaskPaceRing: false,
        showHiddenBlocksIndicator: false,
      );

      final json = settings.toJson();
      final restored = DialSettings.fromJson(json);

      expect(restored.showTrueTimeRing, isFalse);
      expect(restored.secondaryTimeZone, 'Asia/Tokyo');
      expect(restored.showSubtaskPaceRing, isFalse);
      expect(restored.showHiddenBlocksIndicator, isFalse);
    });
  });
}
