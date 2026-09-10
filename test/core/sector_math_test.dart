import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/core/geometry/sector_math.dart';

void main() {
  group('SectorMath 12-Hour Angle Tests', () {
    test('12:00 (midnight or noon) maps to 0 degrees', () {
      final time = DateTime(2026, 9, 7, 12, 0);
      expect(SectorMath.timeToDialAngle(time, is24HourMode: false), 0.0);
    });

    test('03:00 maps to 90 degrees', () {
      final time = DateTime(2026, 9, 7, 3, 0);
      expect(SectorMath.timeToDialAngle(time, is24HourMode: false), 90.0);
    });

    test('06:00 maps to 180 degrees', () {
      final time = DateTime(2026, 9, 7, 6, 0);
      expect(SectorMath.timeToDialAngle(time, is24HourMode: false), 180.0);
    });

    test('09:00 maps to 270 degrees', () {
      final time = DateTime(2026, 9, 7, 9, 0);
      expect(SectorMath.timeToDialAngle(time, is24HourMode: false), 270.0);
    });

    test(
      '15:30 (3:30 PM) in 12h mode maps to (3 * 60 + 30) * 0.5 = 105 degrees',
      () {
        final time = DateTime(2026, 9, 7, 15, 30);
        expect(SectorMath.timeToDialAngle(time, is24HourMode: false), 105.0);
      },
    );
  });

  group('SectorMath 24-Hour Angle Tests', () {
    test('00:00 maps to 0 degrees', () {
      final time = DateTime(2026, 9, 7, 0, 0);
      expect(SectorMath.timeToDialAngle(time, is24HourMode: true), 0.0);
    });

    test('06:00 maps to 90 degrees in 24h mode', () {
      final time = DateTime(2026, 9, 7, 6, 0);
      expect(SectorMath.timeToDialAngle(time, is24HourMode: true), 90.0);
    });

    test('12:00 maps to 180 degrees in 24h mode', () {
      final time = DateTime(2026, 9, 7, 12, 0);
      expect(SectorMath.timeToDialAngle(time, is24HourMode: true), 180.0);
    });

    test('18:00 maps to 270 degrees in 24h mode', () {
      final time = DateTime(2026, 9, 7, 18, 0);
      expect(SectorMath.timeToDialAngle(time, is24HourMode: true), 270.0);
    });
  });

  group('SectorMath Sweep & Clamping Tests', () {
    test('1 hour event in 12h mode has 30 degree sweep', () {
      expect(
        SectorMath.durationToSweepAngle(
          const Duration(hours: 1),
          is24HourMode: false,
        ),
        30.0,
      );
    });

    test('2 minute event clamps to minimum 5.0 degrees', () {
      expect(
        SectorMath.durationToSweepAngle(
          const Duration(minutes: 2),
          is24HourMode: false,
        ),
        5.0,
      );
    });
  });

  group('Touch Delta to Dial Angle Tests', () {
    test('Touch directly above center (0, -100) is 12 o\'clock (0°)', () {
      expect(SectorMath.touchDeltaToDialAngle(0, -100), closeTo(0.0, 0.001));
    });

    test('Touch directly right of center (100, 0) is 3 o\'clock (90°)', () {
      expect(SectorMath.touchDeltaToDialAngle(100, 0), closeTo(90.0, 0.001));
    });

    test('Touch directly below center (0, 100) is 6 o\'clock (180°)', () {
      expect(SectorMath.touchDeltaToDialAngle(0, 100), closeTo(180.0, 0.001));
    });

    test('Touch directly left of center (-100, 0) is 9 o\'clock (270°)', () {
      expect(SectorMath.touchDeltaToDialAngle(-100, 0), closeTo(270.0, 0.001));
    });
  });

  group('Midnight Crossing Tests', () {
    test('identifies cross-midnight intervals', () {
      final start = DateTime(2026, 9, 7, 23, 0);
      final end = DateTime(2026, 9, 8, 1, 30);
      expect(SectorMath.spansAcrossMidnight(start, end), isTrue);

      final sameDayEnd = DateTime(2026, 9, 7, 23, 45);
      expect(SectorMath.spansAcrossMidnight(start, sameDayEnd), isFalse);
    });

    test('splits midnight boundary cleanly', () {
      final start = DateTime(2026, 9, 7, 23, 0);
      final end = DateTime(2026, 9, 8, 1, 30);
      final split = SectorMath.splitMidnightBoundary(start, end);

      expect(split.day1End.day, 7);
      expect(split.day1End.hour, 23);
      expect(split.day1End.minute, 59);
      expect(split.day2Start.day, 8);
      expect(split.day2Start.hour, 0);
      expect(split.day2Start.minute, 0);
    });
  });

  group('FocusedWarp Tests', () {
    test(
      'scales active sector based on subtask count and clamps correctly',
      () {
        final warp0 = FocusedWarp.fromEvent(
          eventId: 'ev1',
          startAngle: 30.0,
          sweepAngle: 30.0,
          subtaskCount: 0,
        );
        expect(warp0.targetSweep, 140.0);

        final warp2 = FocusedWarp.fromEvent(
          eventId: 'ev1',
          startAngle: 30.0,
          sweepAngle: 30.0,
          subtaskCount: 2,
        );
        expect(warp2.targetSweep, 190.0); // 140 + 2 * 25 = 190

        final warp10 = FocusedWarp.fromEvent(
          eventId: 'ev1',
          startAngle: 30.0,
          sweepAngle: 30.0,
          subtaskCount: 10,
        );
        expect(warp10.targetSweep, 270.0); // clamped to 270
      },
    );

    test(
      'is strictly bijective: unwarp(warp(deg)) == deg across full circle',
      () {
        final warp = FocusedWarp.fromEvent(
          eventId: 'ev1',
          startAngle: 45.0,
          sweepAngle: 60.0,
          subtaskCount: 3,
        );

        for (var deg = 0.0; deg < 360.0; deg += 7.5) {
          final warped = warp.warp(deg);
          final unwarped = warp.unwarp(warped);
          expect(unwarped, closeTo(deg, 0.001));
        }
      },
    );

    test('centers warped focus sector around original event midpoint', () {
      final warp = FocusedWarp.fromEvent(
        eventId: 'ev1',
        startAngle: 60.0,
        sweepAngle: 30.0,
        subtaskCount: 1,
      );
      // Event center is 75°
      // Midpoint warped should be 75°
      expect(warp.warp(75.0), closeTo(75.0, 0.001));
      expect(warp.unwarp(75.0), closeTo(75.0, 0.001));
    });
  });
}
