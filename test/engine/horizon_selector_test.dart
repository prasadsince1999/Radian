import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/engine/dial_input.dart';
import 'package:sectograph_mcp/engine/horizon_selector.dart';

void main() {
  group('HorizonSelector Unit & Invariant Tests', () {
    final baseDate = DateTime(2026, 9, 29, 10, 0); // 10:00 AM

    test('P = 0 admits ZERO previous blocks (Invariants I2, RC1)', () {
      final occurrences = [
        Occurrence(
          id: 'prev-1',
          eventId: 'prev-1',
          title: 'Morning Yoga',
          start: DateTime(2026, 9, 29, 7, 0),
          end: DateTime(2026, 9, 29, 8, 30),
        ),
        Occurrence(
          id: 'active',
          eventId: 'active',
          title: 'Deep Work',
          start: DateTime(2026, 9, 29, 9, 30),
          end: DateTime(2026, 9, 29, 11, 30),
        ),
        Occurrence(
          id: 'next-1',
          eventId: 'next-1',
          title: 'Lunch',
          start: DateTime(2026, 9, 29, 12, 0),
          end: DateTime(2026, 9, 29, 13, 0),
        ),
      ];

      final input = DialInput(
        now: baseDate,
        occurrences: occurrences,
        prefs: const DialPrefs(previousBlocks: 0, nextBlocks: 3),
      );

      final result = HorizonSelector.select(input);

      expect(result.visible.any((o) => o.end.isBefore(baseDate)), isFalse,
          reason: 'No blocks ending before now should be admitted when P=0');
      expect(result.visible.map((o) => o.id), containsAll(['active', 'next-1']));
      expect(result.visible.map((o) => o.id), isNot(contains('prev-1')));
    });

    test('Strict Priority Order: selected -> active -> next1 -> prev1 -> next2 -> prev2', () {
      // 10:00 AM now
      final occurrences = [
        Occurrence(
          id: 'prev-2',
          eventId: 'prev-2',
          title: 'Dawn Meditation',
          start: DateTime(2026, 9, 29, 5, 0),
          end: DateTime(2026, 9, 29, 6, 0),
        ),
        Occurrence(
          id: 'prev-1',
          eventId: 'prev-1',
          title: 'Breakfast',
          start: DateTime(2026, 9, 29, 7, 30),
          end: DateTime(2026, 9, 29, 8, 30),
        ),
        Occurrence(
          id: 'active',
          eventId: 'active',
          title: 'Core Architecture',
          start: DateTime(2026, 9, 29, 9, 30),
          end: DateTime(2026, 9, 29, 11, 30),
        ),
        Occurrence(
          id: 'next-1',
          eventId: 'next-1',
          title: 'Sync',
          start: DateTime(2026, 9, 29, 12, 0),
          end: DateTime(2026, 9, 29, 12, 45),
        ),
        Occurrence(
          id: 'next-2',
          eventId: 'next-2',
          title: 'Review',
          start: DateTime(2026, 9, 29, 14, 0),
          end: DateTime(2026, 9, 29, 15, 0),
        ),
      ];

      // Test with P=1, N=1
      final input1 = DialInput(
        now: baseDate,
        occurrences: occurrences,
        prefs: const DialPrefs(previousBlocks: 1, nextBlocks: 1),
      );
      final res1 = HorizonSelector.select(input1);
      final ids1 = res1.visible.map((o) => o.id).toList();

      expect(ids1, contains('active'));
      expect(ids1, contains('next-1'));
      expect(ids1, contains('prev-1'));
      expect(ids1, isNot(contains('prev-2')));
      expect(ids1, isNot(contains('next-2')));

      // Test with explicit selected focus on next-2
      final inputSelected = DialInput(
        now: baseDate,
        occurrences: occurrences,
        focus: const DialFocusSelected('next-2'),
        prefs: const DialPrefs(previousBlocks: 1, nextBlocks: 1),
      );
      final resSelected = HorizonSelector.select(inputSelected);
      final idsSelected = resSelected.visible.map((o) => o.id).toList();

      expect(idsSelected.first, equals('next-2'),
          reason: 'Selected focus must take absolute highest priority');
    });

    test('12H Aliasing Deconfliction (RC1 & I2): 11 PM with tomorrow 6 AM and yesterday 6 PM', () {
      // Current time: 11:00 PM (23:00) on Sep 29
      final nightNow = DateTime(2026, 9, 29, 23, 0);

      final occurrences = [
        // Today 6:00 PM - 7:00 PM (18:00 - 19:00 on Sep 29) -> angles 180° - 210°
        Occurrence(
          id: 'today-dinner',
          eventId: 'today-dinner',
          title: 'Today Dinner',
          start: DateTime(2026, 9, 29, 18, 0),
          end: DateTime(2026, 9, 29, 19, 0),
        ),
        // Active: 10:30 PM - 11:30 PM (22:30 - 23:30 on Sep 29) -> angles 315° - 345°
        Occurrence(
          id: 'night-reading',
          eventId: 'night-reading',
          title: 'Night Reading',
          start: DateTime(2026, 9, 29, 22, 30),
          end: DateTime(2026, 9, 29, 23, 30),
        ),
        // Tomorrow 6:00 AM - 7:00 AM (06:00 - 07:00 on Sep 30) -> angles 180° - 210°
        Occurrence(
          id: 'tomorrow-yoga',
          eventId: 'tomorrow-yoga',
          title: 'Tomorrow Yoga',
          start: DateTime(2026, 9, 30, 6, 0),
          end: DateTime(2026, 9, 30, 7, 0),
        ),
      ];

      final input = DialInput(
        now: nightNow,
        occurrences: occurrences,
        prefs: const DialPrefs(previousBlocks: 2, nextBlocks: 2, is24HourMode: false),
      );

      final result = HorizonSelector.select(input);
      final visibleIds = result.visible.map((o) => o.id).toList();

      expect(visibleIds, contains('night-reading'), reason: 'Active block must be visible');
      // Due to priority order (active -> next1 -> prev1):
      // tomorrow-yoga is next1 (rank 1 next). It is admitted at angles 180°-210°.
      // today-dinner is prev1. Its angle interval (180°-210°) conflicts with tomorrow-yoga!
      // Therefore, tomorrow-yoga must be visible and today-dinner must be hidden with aliasesWith:tomorrow-yoga!
      expect(visibleIds, contains('tomorrow-yoga'));
      expect(visibleIds, isNot(contains('today-dinner')));

      expect(result.hidden.hiddenCount, greaterThanOrEqualTo(1));
      final hiddenReason = result.hidden.hiddenEvents
          .firstWhere((h) => h.eventId == 'today-dinner')
          .reason;
      expect(hiddenReason, contains('aliasesWith:tomorrow-yoga'));
    });

    test('Midnight-Crossing Block is split into contiguous segments', () {
      final now = DateTime(2026, 9, 29, 23, 45); // 11:45 PM
      final occurrences = [
        Occurrence(
          id: 'night-shift',
          eventId: 'night-shift',
          title: 'Midnight Shift',
          start: DateTime(2026, 9, 29, 23, 0),
          end: DateTime(2026, 9, 30, 1, 0), // 2 hour block crossing midnight
        ),
      ];

      final input = DialInput(
        now: now,
        occurrences: occurrences,
        prefs: const DialPrefs(previousBlocks: 1, nextBlocks: 1),
      );

      final result = HorizonSelector.select(input);
      expect(result.visibleSegments.length, equals(2),
          reason: 'A midnight-crossing block should be split into 2 segments: #0 and #1');
      expect(result.visibleSegments[0].segmentIndex, equals(0));
      expect(result.visibleSegments[1].segmentIndex, equals(1));
      expect(result.visibleSegments[0].segmentEnd.hour, equals(0));
      expect(result.visibleSegments[1].segmentStart.hour, equals(0));
    });

    test('Admitted visible blocks never exceed 1 + P + N limit', () {
      final now = DateTime(2026, 9, 29, 12, 0);
      final occurrences = List.generate(20, (i) {
        final startHour = 6 + i;
        return Occurrence(
          id: 'ev-$i',
          eventId: 'ev-$i',
          title: 'Block $i',
          start: DateTime(2026, 9, 29, startHour, 0),
          end: DateTime(2026, 9, 29, startHour, 45),
        );
      });

      for (int p = 0; p <= 3; p++) {
        for (int n = 0; n <= 3; n++) {
          final input = DialInput(
            now: now,
            occurrences: occurrences,
            prefs: DialPrefs(previousBlocks: p, nextBlocks: n),
          );
          final res = HorizonSelector.select(input);
          // Count distinct logical events
          final distinctIds = res.visible.map((o) => o.eventId).toSet();
          expect(distinctIds.length, lessThanOrEqualTo(1 + p + n),
              reason: 'Distinct admitted events must be <= 1 + P + N (P=$p, N=$n)');
        }
      }
    });

    test('Input permutation invariance: order of occurrences array does not change result', () {
      final now = DateTime(2026, 9, 29, 11, 0);
      final raw = [
        Occurrence(
          id: 'ev-1',
          eventId: 'ev-1',
          title: 'Event 1',
          start: DateTime(2026, 9, 29, 8, 0),
          end: DateTime(2026, 9, 29, 9, 0),
        ),
        Occurrence(
          id: 'ev-2',
          eventId: 'ev-2',
          title: 'Event 2',
          start: DateTime(2026, 9, 29, 9, 30),
          end: DateTime(2026, 9, 29, 10, 30),
        ),
        Occurrence(
          id: 'ev-3',
          eventId: 'ev-3',
          title: 'Event 3',
          start: DateTime(2026, 9, 29, 10, 45),
          end: DateTime(2026, 9, 29, 11, 45),
        ),
        Occurrence(
          id: 'ev-4',
          eventId: 'ev-4',
          title: 'Event 4',
          start: DateTime(2026, 9, 29, 12, 30),
          end: DateTime(2026, 9, 29, 13, 30),
        ),
      ];

      final inputAsc = DialInput(
        now: now,
        occurrences: raw,
        prefs: const DialPrefs(previousBlocks: 2, nextBlocks: 2),
      );
      final resAsc = HorizonSelector.select(inputAsc);

      // Reverse list
      final inputRev = DialInput(
        now: now,
        occurrences: raw.reversed.toList(),
        prefs: const DialPrefs(previousBlocks: 2, nextBlocks: 2),
      );
      final resRev = HorizonSelector.select(inputRev);

      expect(resAsc.visible.map((o) => o.id).toList(),
          equals(resRev.visible.map((o) => o.id).toList()));
    });
  });

  group('HorizonSelector Property-Based Tests (>= 1,000 Seeded Iterations)', () {
    test('1,000 seeded random days invariant verification', () {
      final rng = math.Random(42893); // Deterministic seed

      for (int iter = 0; iter < 1000; iter++) {
        final startHour = rng.nextInt(24);
        final startMinute = rng.nextInt(60);
        final now = DateTime(2026, 9, 29, startHour, startMinute);

        final p = rng.nextInt(4); // 0..3
        final n = rng.nextInt(4); // 0..3
        final is24 = rng.nextBool();

        final numEvents = rng.nextInt(15) + 1; // 1..15 events
        final events = <Occurrence>[];

        // Generate non-overlapping random events throughout a 48-hour span around now
        var cursor = now.subtract(const Duration(hours: 14));
        for (int i = 0; i < numEvents; i++) {
          final gapMinutes = rng.nextInt(60) + 10;
          final durationMinutes = rng.nextInt(120) + 30;
          final evStart = cursor.add(Duration(minutes: gapMinutes));
          final evEnd = evStart.add(Duration(minutes: durationMinutes));
          cursor = evEnd;

          events.add(Occurrence(
            id: 'rand-ev-$iter-$i',
            eventId: 'rand-ev-$iter-$i',
            title: 'Random Block $i',
            start: evStart,
            end: evEnd,
          ));
        }

        final input = DialInput(
          now: now,
          occurrences: events,
          prefs: DialPrefs(previousBlocks: p, nextBlocks: n, is24HourMode: is24),
        );

        final result = HorizonSelector.select(input);

        // Invariant 1: Distinct admitted logical events <= 1 + P + N
        final distinctAdmitted = result.visible.map((o) => o.eventId).toSet();
        expect(distinctAdmitted.length, lessThanOrEqualTo(1 + p + n),
            reason: 'Iteration $iter: Admitted events exceed 1 + P + N');

        // Invariant 2: When P = 0, no admitted block ends strictly before now
        if (p == 0) {
          final anyStrictPrev = result.visible.any((o) => o.end.isBefore(now));
          expect(anyStrictPrev, isFalse,
              reason: 'Iteration $iter: P=0 admitted a previous block');
        }

        // Invariant 3: Permutation invariance
        final shuffledEvents = List<Occurrence>.from(events)..shuffle(rng);
        final permutedResult = HorizonSelector.select(DialInput(
          now: now,
          occurrences: shuffledEvents,
          prefs: DialPrefs(previousBlocks: p, nextBlocks: n, is24HourMode: is24),
        ));
        expect(result.visible.map((o) => o.id).toSet(),
            equals(permutedResult.visible.map((o) => o.id).toSet()),
            reason: 'Iteration $iter: Admitted set differs under permutation');
      }
    });
  });
}
