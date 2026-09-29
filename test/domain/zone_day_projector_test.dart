import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:sectograph_mcp/core/time/time_spec.dart';
import 'package:sectograph_mcp/core/time/zone_clock.dart';
import 'package:sectograph_mcp/domain/models/sector_event.dart';
import 'package:sectograph_mcp/domain/schedule/zone_day_projector.dart';

void main() {
  setUpAll(() {
    ensureTimeZonesInitialized();
  });

  group('ZoneDayProjector Tests', () {
    test('Round-trip: Store in IST -> Read in New York (Instant vs Floating)', () {
      final nyLoc = tz.getLocation('America/New_York');

      // 1. Instant event: Global Team Sync at 15:00 IST on 2026-06-15 (summer)
      // 15:00 IST = 09:30 UTC = 05:30 EDT in NY (UTC-4)
      final instantUtc = DateTime.utc(2026, 6, 15, 9, 30);
      final instantEvent = SectorEvent(
        id: 'meeting-1',
        title: 'Global Team Sync',
        start: DateTime(2026, 6, 15, 15, 0),
        end: DateTime(2026, 6, 15, 16, 0),
        timeSpec: InstantTime(
          utcMillis: instantUtc.millisecondsSinceEpoch,
          tzid: 'Asia/Kolkata',
        ),
      );

      final occurrenceNY = ZoneDayProjector.project(
        event: instantEvent,
        targetDay: DateTime(2026, 6, 15),
        displayZone: nyLoc,
      );

      expect(occurrenceNY, isNotNull);
      expect(occurrenceNY!.startLocal.hour, 5);
      expect(occurrenceNY.startLocal.minute, 30);
      expect(occurrenceNY.endLocal.hour, 6);
      expect(occurrenceNY.endLocal.minute, 30);

      // 2. Floating routine: Morning Meditation at 07:00 AM (device floating)
      final floatingEvent = SectorEvent(
        id: 'routine-1',
        title: 'Morning Meditation',
        start: DateTime(2026, 6, 15, 7, 0),
        end: DateTime(2026, 6, 15, 7, 45),
        repeatDays: [1, 2, 3, 4, 5],
        timeSpec: FloatingTime.fromTimes(
          startHour: 7,
          startMinute: 0,
          durationMinutes: 45,
          zoneMode: const ZoneMode.device(),
        ),
      );

      // Project routine in NY: should stay at 07:00 AM in NY!
      final occurrenceFloatingNY = ZoneDayProjector.project(
        event: floatingEvent,
        targetDay: DateTime(2026, 6, 15), // Monday = 1
        displayZone: nyLoc,
      );

      expect(occurrenceFloatingNY, isNotNull);
      expect(occurrenceFloatingNY!.startLocal.hour, 7);
      expect(occurrenceFloatingNY.startLocal.minute, 0);
      expect(occurrenceFloatingNY.endLocal.hour, 7);
      expect(occurrenceFloatingNY.endLocal.minute, 45);
    });

    test('Half-hour and 45-min zones: Asia/Kolkata (+5:30) and Asia/Kathmandu (+5:45)', () {
      final kolkata = tz.getLocation('Asia/Kolkata');
      final kathmandu = tz.getLocation('Asia/Kathmandu');

      // 06:00 UTC = 11:30 IST = 11:45 NPT
      final utcMeeting = DateTime.utc(2026, 9, 29, 6, 0);
      final event = SectorEvent(
        id: 'sync-1',
        title: 'Himalayan Regional Sync',
        start: DateTime(2026, 9, 29, 11, 30),
        end: DateTime(2026, 9, 29, 12, 30),
        timeSpec: InstantTime(
          utcMillis: utcMeeting.millisecondsSinceEpoch,
          tzid: 'UTC',
        ),
      );

      final occKolkata = ZoneDayProjector.project(
        event: event,
        targetDay: DateTime(2026, 9, 29),
        displayZone: kolkata,
      );
      expect(occKolkata, isNotNull);
      expect(occKolkata!.startLocal.hour, 11);
      expect(occKolkata.startLocal.minute, 30);

      final occKathmandu = ZoneDayProjector.project(
        event: event,
        targetDay: DateTime(2026, 9, 29),
        displayZone: kathmandu,
      );
      expect(occKathmandu, isNotNull);
      expect(occKathmandu!.startLocal.hour, 11);
      expect(occKathmandu.startLocal.minute, 45);
    });

    test('Australia/Lord_Howe handles 30-min DST without distortion', () {
      final lordHowe = tz.getLocation('Australia/Lord_Howe');

      final event = SectorEvent(
        id: 'lh-routine',
        title: 'Island Walk',
        start: DateTime(2026, 12, 10, 8, 30),
        end: DateTime(2026, 12, 10, 9, 30),
        repeatDays: [1, 2, 3, 4, 5, 6, 7],
        timeSpec: FloatingTime.fromTimes(
          startHour: 8,
          startMinute: 30,
          durationMinutes: 60,
        ),
      );

      final occ = ZoneDayProjector.project(
        event: event,
        targetDay: DateTime(2026, 12, 10),
        displayZone: lordHowe,
      );

      expect(occ, isNotNull);
      expect(occ!.startLocal.hour, 8);
      expect(occ.startLocal.minute, 30);
      expect(occ.endLocal.hour, 9);
      expect(occ.endLocal.minute, 30);
    });

    test('America/New_York DST transition days', () {
      final ny = tz.getLocation('America/New_York');

      // Spring-forward: 2026-03-08
      final springForwardDay = DateTime(2026, 3, 8);
      final event = SectorEvent(
        id: 'daily-gym',
        title: 'Gym',
        start: DateTime(2026, 1, 1, 9, 0),
        end: DateTime(2026, 1, 1, 10, 0),
        repeatDays: [1, 2, 3, 4, 5, 6, 7],
        timeSpec: FloatingTime.fromTimes(
          startHour: 9,
          startMinute: 0,
          durationMinutes: 60,
        ),
      );

      final occ = ZoneDayProjector.project(
        event: event,
        targetDay: springForwardDay,
        displayZone: ny,
      );

      expect(occ, isNotNull);
      expect(occ!.startLocal.hour, 9);
      expect(occ.startLocal.minute, 0);
      expect(occ.endLocal.hour, 10);
      expect(occ.endLocal.minute, 0);
    });

    test('Legacy event backwards compatibility with EventDayProjector wrapping', () {
      final kolkata = tz.getLocation('Asia/Kolkata');

      final legacyEvent = SectorEvent(
        id: 'legacy-1',
        title: 'Legacy Event',
        start: DateTime(2026, 9, 29, 14, 0),
        end: DateTime(2026, 9, 29, 15, 30),
      );

      final occ = ZoneDayProjector.project(
        event: legacyEvent,
        targetDay: DateTime(2026, 9, 29),
        displayZone: kolkata,
      );

      expect(occ, isNotNull);
      expect(occ!.startLocal.hour, 14);
      expect(occ.startLocal.minute, 0);
      expect(occ.endLocal.hour, 15);
      expect(occ.endLocal.minute, 30);
    });
  });
}
