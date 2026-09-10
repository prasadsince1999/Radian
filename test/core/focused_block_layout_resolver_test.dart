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
      'extracts exact 3 previous + 1 active + 3 upcoming from 10 events',
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
  });
}
