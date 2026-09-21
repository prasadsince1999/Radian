import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/core/geometry/focused_block_layout_resolver.dart';
import 'package:sectograph_mcp/domain/models/sector_event.dart';

void main() {
  group('FocusedBlockLayoutResolver Tests', () {
    final baseDate = DateTime(2026, 9, 11);

    SectorEvent makeEvent(String id, int startHour, int endHour) {
      return SectorEvent(
        id: id,
        title: id,
        start: baseDate.add(Duration(hours: startHour)),
        end: baseDate.add(Duration(hours: endHour)),
        colorHex: '#6366F1',
        category: 'Focus',
      );
    }

    test(
      'extracts exact 3 previous + 1 active + 3 upcoming from 10 events when limits are 3',
      () {
        final events = [
          makeEvent('e0', 0, 2), // Older past (should be excluded)
          makeEvent('e1', 2, 4), // Prev 3 (inner ring)
          makeEvent('e2', 4, 6), // Prev 2 (inner ring)
          makeEvent('e3', 6, 8), // Prev 1 (outer ring)
          makeEvent('e4', 8, 11), // ACTIVE NOW (outer ring)
          makeEvent('e5', 11, 13), // Next 1 (outer ring)
          makeEvent('e6', 13, 15), // Next 2 (inner ring)
          makeEvent('e7', 15, 17), // Next 3 (inner ring)
          makeEvent('e8', 17, 19), // Farther future (should be excluded)
          makeEvent('e9', 19, 21), // Farther future (should be excluded)
        ];

        final effectiveTime = baseDate.add(
          const Duration(hours: 9),
        ); // inside e4 (8-11)
        final result = FocusedBlockLayoutResolver.resolve(
          events: events,
          effectiveTime: effectiveTime,
          is24HourMode: true,
          previousBlocksCount: 3,
          futureBlocksCount: 3,
        );

        expect(result.activeEvent?.id, 'e4');
        expect(result.prev1?.id, 'e3');
        expect(result.prev2?.id, 'e2');
        expect(result.prev3?.id, 'e1');
        expect(result.next1?.id, 'e5');
        expect(result.next2?.id, 'e6');
        expect(result.next3?.id, 'e7');

        // Outer ring: prev1, active, next1
        expect(result.outerEventIds, containsAll(['e3', 'e4', 'e5']));
        expect(result.outerEventIds.length, 3);

        // Inner ring: prev3, prev2, next2, next3
        expect(result.innerEventIds, containsAll(['e1', 'e2', 'e6', 'e7']));
        expect(result.innerEventIds.length, 4);

        // Total visible events: exactly 7
        expect(result.visibleEvents.length, 7);
        expect(result.visibleEvents.map((e) => e.id).toList(), [
          'e1',
          'e2',
          'e3',
          'e4',
          'e5',
          'e6',
          'e7',
        ]);

        // e0, e8, e9 are completely excluded!
        expect(result.visibleEvents.any((e) => e.id == 'e0'), isFalse);
        expect(result.visibleEvents.any((e) => e.id == 'e8'), isFalse);
        expect(result.visibleEvents.any((e) => e.id == 'e9'), isFalse);
      },
    );

    test('extracts default 1 previous + 1 active + 2 upcoming from 10 events', () {
      final events = [
        makeEvent('e0', 0, 2),
        makeEvent('e1', 2, 4),
        makeEvent('e2', 4, 6),
        makeEvent('e3', 6, 8), // Prev 1
        makeEvent('e4', 8, 11), // Active
        makeEvent('e5', 11, 13), // Next 1
        makeEvent('e6', 13, 15), // Next 2
        makeEvent('e7', 15, 17),
        makeEvent('e8', 17, 19),
      ];

      final effectiveTime = baseDate.add(const Duration(hours: 9));
      final result = FocusedBlockLayoutResolver.resolve(
        events: events,
        effectiveTime: effectiveTime,
        is24HourMode: true,
      );

      // Default should have at most 4 blocks: prev1 (e3), active (e4), next1 (e5), next2 (e6)
      expect(result.visibleEvents.length, 4);
      expect(result.visibleEvents.map((e) => e.id).toList(), ['e3', 'e4', 'e5', 'e6']);
    });

    test('respects zero previous and future block counts', () {
      final events = [
        makeEvent('e1', 6, 8),
        makeEvent('e2', 8, 10),
        makeEvent('e3', 10, 12),
      ];

      final effectiveTime = baseDate.add(const Duration(hours: 9));
      final result = FocusedBlockLayoutResolver.resolve(
        events: events,
        effectiveTime: effectiveTime,
        previousBlocksCount: 0,
        futureBlocksCount: 0,
      );

      // Only active block visible!
      expect(result.visibleEvents.length, 1);
      expect(result.visibleEvents.first.id, 'e2');
    });

    test(
      'suppresses angular collisions on 12-hour dial for inner ring blocks',
      () {
        final events = [
          makeEvent(
            'sleep_am',
            1,
            8,
          ), // 1:30 - 8:30 AM (covers angles 30° to 240°)
          makeEvent('work_pm', 15, 17), // 3:00 - 5:00 PM (angles 90° to 150°)
          makeEvent('flex_pm', 17, 20), // 5:00 - 8:00 PM (angles 150° to 240°)
        ];

        final effectiveTime = baseDate.add(
          const Duration(hours: 11),
        ); // 11:00 AM
        final result = FocusedBlockLayoutResolver.resolve(
          events: events,
          effectiveTime: effectiveTime,
          is24HourMode: false,
        );

        // In 12H mode, sleep_am must NOT collide with afternoon blocks work_pm & flex_pm
        // on the inner ring:
        expect(result.innerEventIds.contains('sleep_am'), isFalse);
      },
    );

    test('guarantees zero angular sector overlap in 12H mode between next1 (Bed Time) and past afternoon/evening blocks', () {
      // Exact user scenario: 10:48 PM (22:48)
      // Today:
      //   - 'workout': 15:00 - 17:30 (3:00 PM - 5:30 PM) -> angles 90° - 165°
      //   - 'flex': 17:30 - 20:30 (5:30 PM - 8:30 PM) -> angles 165° - 255°
      //   - 'lunch': 20:30 - 21:30 (8:30 PM - 9:30 PM) -> angles 255° - 285° (prev1)
      //   - 'study': 21:30 - 01:30 (9:30 PM - 1:30 AM) -> angles 285° - 45° (active)
      // Tomorrow:
      //   - 'bed_time': 01:30 - 08:30 (1:30 AM - 8:30 AM) -> angles 45° - 255° (next1)
      final workout = SectorEvent(
        id: 'workout',
        title: 'Workout or Chill Time',
        start: DateTime(2026, 9, 11, 15, 0),
        end: DateTime(2026, 9, 11, 17, 30),
        colorHex: '#6B7280',
      );
      final flex = SectorEvent(
        id: 'flex',
        title: 'Flexible Hours',
        start: DateTime(2026, 9, 11, 17, 30),
        end: DateTime(2026, 9, 11, 20, 30),
        colorHex: '#6B7280',
      );
      final lunch = SectorEvent(
        id: 'lunch',
        title: 'Cooking+Lunch',
        start: DateTime(2026, 9, 11, 20, 30),
        end: DateTime(2026, 9, 11, 21, 30),
        colorHex: '#10B981',
      );
      final study = SectorEvent(
        id: 'study',
        title: 'Study Time',
        start: DateTime(2026, 9, 11, 21, 30),
        end: DateTime(2026, 9, 12, 1, 30),
        colorHex: '#3B82F6',
      );
      final bedTime = SectorEvent(
        id: 'bed_time',
        title: 'Bed Time',
        start: DateTime(2026, 9, 12, 1, 30),
        end: DateTime(2026, 9, 12, 8, 30),
        colorHex: '#8B5CF6',
      );

      final events = [workout, flex, lunch, study, bedTime];
      final effectiveTime = DateTime(2026, 9, 11, 22, 48); // 10:48 PM

      final result = FocusedBlockLayoutResolver.resolve(
        events: events,
        effectiveTime: effectiveTime,
        is24HourMode: false, // 12H dial
      );

      // Active is Study Time
      expect(result.activeEvent?.id, 'study');
      // Prev1 is Cooking+Lunch
      expect(result.prev1?.id, 'lunch');
      // Next1 is Bed Time
      expect(result.next1?.id, 'bed_time');

      // Bed Time covers 45° to 255°
      // workout (90°-165°) and flex (165°-255°) collide directly with Bed Time's angle in 12H!
      // They must NOT be included in visibleEvents to avoid grey wash and text collision:
      expect(result.visibleEvents.any((e) => e.id == 'workout'), isFalse);
      expect(result.visibleEvents.any((e) => e.id == 'flex'), isFalse);

      // Visible events should be exactly lunch (255°-285°), study (285°-45°), bed_time (45°-255°)
      final visibleIds = result.visibleEvents.map((e) => e.id).toSet();
      expect(visibleIds, containsAll(['lunch', 'study', 'bed_time']));
      expect(visibleIds.length, 3);
    });

    test('handles schedule with fewer than 3 previous and upcoming events', () {
      final events = [
        makeEvent('e1', 6, 8), // Prev 1
        makeEvent('e2', 8, 10), // ACTIVE
        makeEvent('e3', 10, 12), // Next 1
      ];

      final effectiveTime = baseDate.add(const Duration(hours: 9));
      final result = FocusedBlockLayoutResolver.resolve(
        events: events,
        effectiveTime: effectiveTime,
      );

      expect(result.activeEvent?.id, 'e2');
      expect(result.prev1?.id, 'e1');
      expect(result.prev2, isNull);
      expect(result.prev3, isNull);
      expect(result.next1?.id, 'e3');
      expect(result.next2, isNull);
      expect(result.next3, isNull);

      expect(result.outerEventIds, containsAll(['e1', 'e2', 'e3']));
      expect(result.innerEventIds, isEmpty);
      expect(result.visibleEvents.length, 3);
    });

    test('handles free time (no current active event) by picking next upcoming as anchor', () {
      final events = [
        makeEvent('e1', 4, 6), // completed
        makeEvent('e2', 6, 8), // completed
        makeEvent('e3', 12, 14), // upcoming
        makeEvent('e4', 14, 16), // upcoming
      ];

      // Time is 10:00 (between e2 and e3)
      final effectiveTime = baseDate.add(const Duration(hours: 10));
      final result = FocusedBlockLayoutResolver.resolve(
        events: events,
        effectiveTime: effectiveTime,
      );

      expect(result.activeEvent?.id, 'e3'); // nearest upcoming is anchor
      expect(result.prev1?.id, 'e2');
      expect(result.prev2?.id, 'e1');
      expect(result.next1?.id, 'e4');
      expect(result.outerEventIds, containsAll(['e2', 'e3', 'e4']));
      expect(result.innerEventIds, contains('e1'));
    });

    test('deconflicts overlapping events in 24H mode (Nap Time vs Bed Time collision)', () {
      final events = [
        SectorEvent(
          id: 'bed_time',
          title: 'Bed Time',
          start: baseDate.add(const Duration(hours: 1, minutes: 30)), // 01:30
          end: baseDate.add(const Duration(hours: 8, minutes: 30)), // 08:30
          colorHex: '#64748B',
          category: 'Rest',
        ),
        SectorEvent(
          id: 'nap_time',
          title: 'Nap Time',
          start: baseDate.add(const Duration(hours: 1, minutes: 30)), // 01:30
          end: baseDate.add(const Duration(hours: 3, minutes: 0)), // 03:00
          colorHex: '#3B82F6',
          category: 'Rest',
        ),
        SectorEvent(
          id: 'study_time',
          title: 'Study Time',
          start: baseDate.add(const Duration(hours: 21, minutes: 30)), // 21:30
          end: baseDate.add(const Duration(hours: 23, minutes: 0)), // 23:00
          colorHex: '#F97316',
          category: 'Deep Focus',
        ),
      ];

      final effectiveTime = baseDate.add(const Duration(hours: 2, minutes: 0));
      final result = FocusedBlockLayoutResolver.resolve(
        events: events,
        effectiveTime: effectiveTime,
        is24HourMode: true,
      );

      // Nap Time and Bed Time collide at 01:30. Only ONE should be visible on the dial, never both!
      final hasBed = result.visibleEvents.any((e) => e.id == 'bed_time');
      final hasNap = result.visibleEvents.any((e) => e.id == 'nap_time');
      expect(
        hasBed && hasNap,
        isFalse,
        reason:
            'Overlapping events must never both be admitted to the single ring',
      );
    });

    test('enforces maxDialVisibleBlocks limit on circular dial', () {
      // Create 15 non-overlapping 1-hour events
      final events = List.generate(15, (i) => makeEvent('e$i', i, i + 1));
      final effectiveTime = baseDate.add(const Duration(hours: 7, minutes: 30));
      final result = FocusedBlockLayoutResolver.resolve(
        events: events,
        effectiveTime: effectiveTime,
        is24HourMode: true,
      );

      expect(result.visibleEvents.length, lessThanOrEqualTo(10));
    });
  });
}
