import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/core/geometry/dial_sector_layout_stretcher.dart';
import 'package:sectograph_mcp/core/geometry/sector_math.dart';
import 'package:sectograph_mcp/domain/models/sector_event.dart';

void main() {
  group('DialSectorLayoutStretcher Tests', () {
    test('empty and single event handling', () {
      expect(
        DialSectorLayoutStretcher.stretch(const [], is24HourMode: true),
        isEmpty,
      );

      final single = SectorEvent(
        id: '1',
        title: 'Single Task',
        start: DateTime(2026, 9, 15, 10, 0),
        end: DateTime(2026, 9, 15, 10, 30),
        startAngle: 150.0,
        sweepAngle: 7.5,
      );

      final stretched = DialSectorLayoutStretcher.stretch([
        single,
      ], is24HourMode: true);
      expect(stretched.length, 1);
      expect(stretched.first.sweepAngle, 24.0);
    });

    test('stretches compressed isolated Study blocks naturally into surrounding gaps', () {
      // Study 1 (21:30 - 23:00) warped to 13.2°
      // Study 2 (00:00 - 01:30) warped to 12.3°
      // Sits in 24H dial with Flex ending at ~307° and Bed Time starting at ~45°
      final events = [
        SectorEvent(
          id: 'flex',
          title: 'Flex',
          start: DateTime(2026, 9, 15, 17, 30),
          end: DateTime(2026, 9, 15, 20, 30),
          startAngle: 262.5,
          sweepAngle: 45.0, // Ends at 307.5°
        ),
        SectorEvent(
          id: 'study1',
          title: 'Study Time 1',
          start: DateTime(2026, 9, 15, 21, 30),
          end: DateTime(2026, 9, 15, 23, 00),
          startAngle: 328.0,
          sweepAngle: 13.2, // Compressed by lens from 22.5° to 13.2°
        ),
        SectorEvent(
          id: 'study2',
          title: 'Study Time 2',
          start: DateTime(2026, 9, 15, 0, 0),
          end: DateTime(2026, 9, 15, 1, 30),
          startAngle: 355.0,
          sweepAngle: 12.3, // Compressed by lens across midnight
        ),
        SectorEvent(
          id: 'bed',
          title: 'Bed Time',
          start: DateTime(2026, 9, 15, 4, 0),
          end: DateTime(2026, 9, 15, 11, 0),
          startAngle: 60.0,
          sweepAngle: 105.0,
        ),
      ];

      final result = DialSectorLayoutStretcher.stretch(
        events,
        is24HourMode: true,
      );

      final stretchedStudy1 = result.firstWhere((e) => e.id == 'study1');
      final stretchedStudy2 = result.firstWhere((e) => e.id == 'study2');

      // Both Study blocks must reach the full 24.0° readability floor
      expect(stretchedStudy1.sweepAngle, greaterThanOrEqualTo(24.0));
      expect(stretchedStudy2.sweepAngle, greaterThanOrEqualTo(24.0));

      // Gap between Study 1 and Study 2 must remain positive and >= minInterBlockGap (2.0°)
      final study1End = SectorMath.normalizeDegrees(
        stretchedStudy1.startAngle + stretchedStudy1.sweepAngle,
      );
      var gapBetween =
          (SectorMath.normalizeDegrees(stretchedStudy2.startAngle) -
              study1End) %
          360.0;
      if (gapBetween < 0) gapBetween += 360.0;

      expect(gapBetween, greaterThanOrEqualTo(2.0));
    });

    test(
      'preserves already comfortable sectors without unnecessary growth',
      () {
        final events = [
          SectorEvent(
            id: '1',
            title: 'Comfortable Block',
            start: DateTime(2026, 9, 15, 10, 0),
            end: DateTime(2026, 9, 15, 13, 0),
            startAngle: 150.0,
            sweepAngle: 45.0, // 3 hours = 45°
          ),
        ];

        final result = DialSectorLayoutStretcher.stretch(
          events,
          is24HourMode: true,
        );
        expect(result.first.sweepAngle, 45.0);
        expect(result.first.startAngle, 150.0);
      },
    );

    test('preserves contiguity without creating unwanted gaps between touching blocks', () {
      final events = [
        SectorEvent(
          id: '1',
          title: 'Block A',
          start: DateTime(2026, 9, 15, 10, 0),
          end: DateTime(2026, 9, 15, 11, 0),
          startAngle: 150.0,
          sweepAngle: 15.0, // ends at 165.0
        ),
        SectorEvent(
          id: '2',
          title: 'Block B',
          start: DateTime(2026, 9, 15, 11, 0),
          end: DateTime(2026, 9, 15, 12, 0),
          startAngle: 165.0,
          sweepAngle: 15.0, // contiguous with Block A
        ),
      ];

      final result = DialSectorLayoutStretcher.stretch(
        events,
        is24HourMode: true,
      );

      final rA = result.firstWhere((e) => e.id == '1');
      final rB = result.firstWhere((e) => e.id == '2');

      // Both blocks stretch to 18.0° (single-cap target)
      expect(rA.sweepAngle, greaterThanOrEqualTo(18.0));
      expect(rB.sweepAngle, greaterThanOrEqualTo(18.0));
    });

    test('active block with subtasks preserves startAngle at true clock time and expands forward', () {
      // Workout: 15:30 - 16:30 (1 hour = 30° in 12H mode).
      // Angle: 15:30 is 105.0°, 16:30 is 135.0°.
      // Preceded by empty gap (Lunch ended at 13:00 = 30.0°, gap of 75°).
      // Followed by 15-min gap before Read (16:45 = 142.5°, gap of 7.5°).
      final workout = SectorEvent(
        id: 'workout',
        title: 'Workout',
        start: DateTime(2026, 9, 20, 15, 30),
        end: DateTime(2026, 9, 20, 16, 30),
        startAngle: 105.0,
        sweepAngle: 30.0,
        subtasks: const ['Gym', 'Cardio', 'Stretch'],
      );

      final read = SectorEvent(
        id: 'read',
        title: 'Read 2h',
        start: DateTime(2026, 9, 20, 16, 45),
        end: DateTime(2026, 9, 20, 18, 45),
        startAngle: 142.5,
        sweepAngle: 60.0,
        subtasks: const ['Math', 'ArXiv'],
      );

      final lunch = SectorEvent(
        id: 'lunch',
        title: 'Lunch',
        start: DateTime(2026, 9, 20, 12, 0),
        end: DateTime(2026, 9, 20, 13, 0),
        startAngle: 0.0,
        sweepAngle: 30.0,
      );

      final result = DialSectorLayoutStretcher.stretch(
        [lunch, workout, read],
        is24HourMode: false,
        activeEventId: 'workout',
        currentTime: DateTime(2026, 9, 20, 15, 45),
      );

      final stretchedWorkout = result.firstWhere((e) => e.id == 'workout');
      final stretchedRead = result.firstWhere((e) => e.id == 'read');

      // CRITICAL: Workout's startAngle must strictly remain anchored at 105.0° (3:30 PM).
      // It must never borrow backward into preceding gaps, ensuring 3:30 PM is never drawn before 3 o'clock!
      expect(stretchedWorkout.startAngle, 105.0);

      // Buffer between Workout and Read must remain >= minInterBlockGap (3.5°)
      final workoutEnd = SectorMath.normalizeDegrees(
        stretchedWorkout.startAngle + stretchedWorkout.sweepAngle,
      );
      var gapToRead = (stretchedRead.startAngle - workoutEnd) % 360.0;
      if (gapToRead < 0) gapToRead += 360.0;
      expect(gapToRead, greaterThanOrEqualTo(3.5));
    });

    test('single event with subtasks scales sweep based on subtask count in 12H mode', () {
      final single1 = SectorEvent(
        id: 'solo1',
        title: 'Solo Gym',
        start: DateTime(2026, 9, 20, 15, 30),
        end: DateTime(2026, 9, 20, 16, 30),
        startAngle: 105.0,
        sweepAngle: 30.0,
        subtasks: const ['Gym'],
      );

      final stretched1 = DialSectorLayoutStretcher.stretch(
        [single1],
        is24HourMode: false,
        activeEventId: 'solo1',
      );
      expect(stretched1.first.startAngle, 105.0);
      expect(stretched1.first.sweepAngle, 52.0);

      final single3 = SectorEvent(
        id: 'solo3',
        title: 'Solo Gym',
        start: DateTime(2026, 9, 20, 15, 30),
        end: DateTime(2026, 9, 20, 16, 30),
        startAngle: 105.0,
        sweepAngle: 30.0,
        subtasks: const ['Gym', 'Cardio', 'Stretch'],
      );

      final stretched3 = DialSectorLayoutStretcher.stretch(
        [single3],
        is24HourMode: false,
        activeEventId: 'solo3',
      );
      expect(stretched3.first.startAngle, 105.0);
      expect(stretched3.first.sweepAngle, 64.0);
    });
  });
}
