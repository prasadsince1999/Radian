import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/core/clock.dart';
import 'package:sectograph_mcp/core/time/zone_clock.dart';

void main() {
  group('ZoneClock Matrix Tests', () {
    test('Asia/Kolkata handles +05:30 offset without hour*60 assumption', () {
      final utc = DateTime.utc(2026, 9, 29, 6, 0, 0); // 06:00 UTC = 11:30 IST
      final baseClock = FixedClock(utc);
      final zoneClock = ZoneClock.fixedZone(
        tzid: 'Asia/Kolkata',
        baseClock: baseClock,
      );

      final snapshot = zoneClock.snapshot();
      expect(snapshot.tzid, 'Asia/Kolkata');
      expect(snapshot.formattedOffset, '+05:30');
      expect(snapshot.offsetMillis, 5.5 * 3600 * 1000);
      expect(snapshot.localNow.hour, 11);
      expect(snapshot.localNow.minute, 30);
      expect(snapshot.minuteOfDay, (11 * 60) + 30);
    });

    test('Asia/Kathmandu handles +05:45 45-minute offset', () {
      final utc = DateTime.utc(2026, 9, 29, 6, 0, 0); // 06:00 UTC = 11:45 NPT
      final baseClock = FixedClock(utc);
      final zoneClock = ZoneClock.fixedZone(
        tzid: 'Asia/Kathmandu',
        baseClock: baseClock,
      );

      final snapshot = zoneClock.snapshot();
      expect(snapshot.tzid, 'Asia/Kathmandu');
      expect(snapshot.formattedOffset, '+05:45');
      expect(snapshot.localNow.hour, 11);
      expect(snapshot.localNow.minute, 45);
      expect(snapshot.minuteOfDay, (11 * 60) + 45);
    });

    test('Australia/Lord_Howe handles 30-minute DST (+10:30 to +11:00)', () {
      // Winter in Lord Howe (July): standard time is +10:30
      final winterUtc = DateTime.utc(2026, 7, 15, 0, 0, 0);
      final winterClock = ZoneClock.fixedZone(
        tzid: 'Australia/Lord_Howe',
        baseClock: FixedClock(winterUtc),
      );
      final winterSnap = winterClock.snapshot();
      expect(winterSnap.formattedOffset, '+10:30');
      expect(winterSnap.localNow.hour, 10);
      expect(winterSnap.localNow.minute, 30);

      // Summer in Lord Howe (December): DST is +11:00 (only 30 min DST shift!)
      final summerUtc = DateTime.utc(2026, 12, 15, 0, 0, 0);
      final summerClock = ZoneClock.fixedZone(
        tzid: 'Australia/Lord_Howe',
        baseClock: FixedClock(summerUtc),
      );
      final summerSnap = summerClock.snapshot();
      expect(summerSnap.formattedOffset, '+11:00');
      expect(summerSnap.localNow.hour, 11);
      expect(summerSnap.localNow.minute, 0);
      expect(summerSnap.isDst, true);
    });

    test('America/New_York spring-forward and fall-back DST transitions', () {
      // 2026 Spring Forward in US: Sunday, March 8, 2026 (02:00 -> 03:00)
      // 06:00 UTC on March 8 is 01:00 EST (-05:00)
      final beforeUtc = DateTime.utc(2026, 3, 8, 6, 0, 0);
      final clockBefore = ZoneClock.fixedZone(
        tzid: 'America/New_York',
        baseClock: FixedClock(beforeUtc),
      );
      expect(clockBefore.snapshot().formattedOffset, '-05:00');
      expect(clockBefore.snapshot().isDst, false);

      // 08:00 UTC on March 8 is 04:00 EDT (-04:00)
      final afterUtc = DateTime.utc(2026, 3, 8, 8, 0, 0);
      final clockAfter = ZoneClock.fixedZone(
        tzid: 'America/New_York',
        baseClock: FixedClock(afterUtc),
      );
      expect(clockAfter.snapshot().formattedOffset, '-04:00');
      expect(clockAfter.snapshot().isDst, true);
    });

    test('Europe/London GMT vs BST transitions', () {
      // Winter (January): GMT (+00:00)
      final winter = ZoneClock.fixedZone(
        tzid: 'Europe/London',
        baseClock: FixedClock(DateTime.utc(2026, 1, 15, 12, 0, 0)),
      );
      expect(winter.snapshot().formattedOffset, '+00:00');
      expect(winter.snapshot().isDst, false);

      // Summer (July): BST (+01:00)
      final summer = ZoneClock.fixedZone(
        tzid: 'Europe/London',
        baseClock: FixedClock(DateTime.utc(2026, 7, 15, 12, 0, 0)),
      );
      expect(summer.snapshot().formattedOffset, '+01:00');
      expect(summer.snapshot().isDst, true);
    });

    test('Pacific/Auckland (+12:00 / +13:00 NZDT)', () {
      final clock = ZoneClock.fixedZone(
        tzid: 'Pacific/Auckland',
        baseClock: FixedClock(DateTime.utc(2026, 1, 15, 0, 0, 0)),
      );
      final snap = clock.snapshot();
      expect(snap.formattedOffset, '+13:00'); // NZDT in Jan
      expect(snap.localNow.hour, 13);
    });

    test('UTC baseline', () {
      final clock = ZoneClock.fixedZone(
        tzid: 'UTC',
        baseClock: FixedClock(DateTime.utc(2026, 9, 29, 14, 25, 30)),
      );
      final snap = clock.snapshot();
      expect(snap.formattedOffset, '+00:00');
      expect(snap.localNow.hour, 14);
      expect(snap.localNow.minute, 25);
    });
  });
}
