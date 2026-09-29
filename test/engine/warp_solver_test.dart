import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/engine/dial_input.dart';
import 'package:sectograph_mcp/engine/dial_model_builder.dart';
import 'package:sectograph_mcp/engine/horizon_selector.dart';
import 'package:sectograph_mcp/engine/warp_solver.dart';

void main() {
  group('WarpSolver & WarpMap Unit & Invariant Tests', () {
    test('Empty day produces linear identity warp map', () {
      final now = DateTime(2026, 9, 29, 10, 0);
      final input = DialInput(
        now: now,
        occurrences: const [],
        prefs: const DialPrefs(lensEnabled: true),
      );
      final horizon = HorizonSelector.select(input);
      final map = WarpSolver.solve(horizon: horizon, input: input);

      expect(map.forward(0.0), closeTo(0.0, 1e-4));
      expect(map.forward(90.0), closeTo(90.0, 1e-4));
      expect(map.forward(180.0), closeTo(180.0, 1e-4));
      expect(map.forward(270.0), closeTo(270.0, 1e-4));
      expect(map.forward(360.0), closeTo(360.0, 1e-4));
    });

    test('Anchor holds strictly at 0° and 360°', () {
      final now = DateTime(2026, 9, 29, 9, 30);
      final occurrences = [
        Occurrence(
          id: 'ev-1',
          eventId: 'ev-1',
          title: 'Active Focus',
          start: DateTime(2026, 9, 29, 9, 0),
          end: DateTime(2026, 9, 29, 11, 0),
          subtasks: ['Sub 1', 'Sub 2', 'Sub 3'],
        ),
      ];

      final input = DialInput(
        now: now,
        occurrences: occurrences,
        prefs: const DialPrefs(lensEnabled: true, lensMagnification: 2.0),
      );
      final horizon = HorizonSelector.select(input);
      final map = WarpSolver.solve(horizon: horizon, input: input);

      expect(
        map.forward(0.0),
        closeTo(0.0, 1e-5),
        reason: 'Natural 0° must map to 0°',
      );
      expect(
        map.forward(360.0),
        closeTo(360.0, 1e-5),
        reason: 'Natural 360° must map to 360°',
      );
      expect(
        map.inverse(0.0),
        closeTo(0.0, 1e-5),
        reason: 'Inverse 0° must map to 0°',
      );
      expect(
        map.inverse(360.0),
        closeTo(360.0, 1e-5),
        reason: 'Inverse 360° must map to 360°',
      );
    });

    test('Piecewise-linear monotonicity across all breakpoints', () {
      final now = DateTime(2026, 9, 29, 9, 30);
      final occurrences = [
        Occurrence(
          id: 'ev-1',
          eventId: 'ev-1',
          title: 'Morning Yoga',
          start: DateTime(2026, 9, 29, 7, 0),
          end: DateTime(2026, 9, 29, 8, 30),
        ),
        Occurrence(
          id: 'ev-2',
          eventId: 'ev-2',
          title: 'Deep Coding',
          start: DateTime(2026, 9, 29, 9, 0),
          end: DateTime(2026, 9, 29, 11, 30),
          subtasks: ['Engine', 'Warp', 'Solver'],
        ),
        Occurrence(
          id: 'ev-3',
          eventId: 'ev-3',
          title: 'Lunch',
          start: DateTime(2026, 9, 29, 12, 30),
          end: DateTime(2026, 9, 29, 13, 30),
        ),
      ];

      final input = DialInput(
        now: now,
        occurrences: occurrences,
        prefs: const DialPrefs(lensEnabled: true, lensMagnification: 1.8),
      );
      final horizon = HorizonSelector.select(input);
      final map = WarpSolver.solve(horizon: horizon, input: input);

      final bps = map.breakpoints;
      for (int i = 0; i < bps.length - 1; i++) {
        expect(
          bps[i + 1].naturalDeg,
          greaterThan(bps[i].naturalDeg),
          reason: 'Natural breakpoints must strictly increase',
        );
        expect(
          bps[i + 1].displayDeg,
          greaterThan(bps[i].displayDeg),
          reason: 'Display breakpoints must strictly increase (monotonicity)',
        );
      }
    });

    test(
      'Roundtrip identity: inverse(forward(x)) ≈ x for all angles in [0, 360)',
      () {
        final now = DateTime(2026, 9, 29, 10, 15);
        final occurrences = [
          Occurrence(
            id: 'ev-1',
            eventId: 'ev-1',
            title: 'Deep Coding',
            start: DateTime(2026, 9, 29, 9, 0),
            end: DateTime(2026, 9, 29, 12, 0),
            subtasks: ['Task A', 'Task B'],
          ),
          Occurrence(
            id: 'ev-2',
            eventId: 'ev-2',
            title: 'Lunch',
            start: DateTime(2026, 9, 29, 12, 30),
            end: DateTime(2026, 9, 29, 13, 30),
          ),
        ];

        final input = DialInput(
          now: now,
          occurrences: occurrences,
          prefs: const DialPrefs(lensEnabled: true, lensMagnification: 2.0),
        );
        final horizon = HorizonSelector.select(input);
        final map = WarpSolver.solve(horizon: horizon, input: input);

        for (double deg = 0.0; deg <= 360.0; deg += 0.5) {
          final warped = map.forward(deg);
          final unwarped = map.inverse(warped);
          expect(
            unwarped,
            closeTo(deg, 1e-4),
            reason: 'Inverse must roundtrip accurately for angle $deg',
          );
        }
      },
    );

    test('Needle inside active arc iff now in [start, end) (Invariant I7)', () {
      final start = DateTime(2026, 9, 29, 9, 0);
      final end = DateTime(2026, 9, 29, 11, 0);
      final occurrences = [
        Occurrence(
          id: 'active-1',
          eventId: 'active-1',
          title: 'Active Event',
          start: start,
          end: end,
          subtasks: ['Subtask 1'],
        ),
      ];

      // Test 1: now is INSIDE active event (10:00 AM)
      final insideNow = DateTime(2026, 9, 29, 10, 0);
      final insideInput = DialInput(
        now: insideNow,
        occurrences: occurrences,
        prefs: const DialPrefs(lensEnabled: true),
      );
      final insideModel = DialModelBuilder.build(insideInput);

      final activeBlock = insideModel.blocks.firstWhere(
        (b) => b.eventId == 'active-1',
      );
      final activeStartDeg = activeBlock.startDeg;
      final activeEndDeg = (activeStartDeg + activeBlock.sweepDeg) % 360.0;
      final displayNeedleDeg = insideModel.needle.displayDeg;

      final isInside = (activeEndDeg >= activeStartDeg)
          ? (displayNeedleDeg >= activeStartDeg &&
                displayNeedleDeg <= activeEndDeg)
          : (displayNeedleDeg >= activeStartDeg ||
                displayNeedleDeg <= activeEndDeg);

      expect(
        isInside,
        isTrue,
        reason: 'Needle must be strictly inside active arc when now is between start and end',
      );
      expect(insideModel.needle.isInsideActiveBlock, isTrue);

      // Test 2: now is OUTSIDE active event (e.g. 11:30 AM in a gap)
      final outsideNow = DateTime(2026, 9, 29, 11, 30);
      final outsideInput = DialInput(
        now: outsideNow,
        occurrences: occurrences,
        prefs: const DialPrefs(lensEnabled: true),
      );
      final outsideModel = DialModelBuilder.build(outsideInput);

      final outsideBlock = outsideModel.blocks.firstWhere(
        (b) => b.eventId == 'active-1',
      );
      final outStart = outsideBlock.startDeg;
      final outEnd = (outStart + outsideBlock.sweepDeg) % 360.0;
      final outDisplayNeedle = outsideModel.needle.displayDeg;

      final isOutside = (outEnd >= outStart)
          ? (outDisplayNeedle < outStart || outDisplayNeedle > outEnd)
          : (outDisplayNeedle < outStart && outDisplayNeedle > outEnd);

      expect(
        isOutside,
        isTrue,
        reason: 'Needle must NOT be inside block when now is after block end',
      );
      expect(outsideModel.needle.isInsideActiveBlock, isFalse);
    });

    test('Tier A blocks scale sweep for subtask counts', () {
      final now = DateTime(2026, 9, 29, 10, 0);

      // Compare 0 subtasks vs 3 subtasks
      Occurrence createOcc(List<String> subtasks) => Occurrence(
        id: 'ev-coding',
        eventId: 'ev-coding',
        title: 'Deep Coding',
        start: DateTime(2026, 9, 29, 9, 30),
        end: DateTime(2026, 9, 29, 10, 30), // natural sweep = 30°
        subtasks: subtasks,
      );

      final input0 = DialInput(
        now: now,
        occurrences: [createOcc([])],
        prefs: const DialPrefs(lensEnabled: true, lensMagnification: 1.8),
      );
      final model0 = DialModelBuilder.build(input0);

      final input3 = DialInput(
        now: now,
        occurrences: [
          createOcc(['Sub 1', 'Sub 2', 'Sub 3']),
        ],
        prefs: const DialPrefs(lensEnabled: true, lensMagnification: 1.8),
      );
      final model3 = DialModelBuilder.build(input3);

      final sweep0 = model0.blocks.first.sweepDeg;
      final sweep3 = model3.blocks.first.sweepDeg;

      expect(
        sweep3,
        greaterThan(sweep0),
        reason: 'Tier A block with 3 subtasks should receive greater sweep than with 0 subtasks',
      );
      expect(
        sweep3,
        greaterThanOrEqualTo(50.0),
        reason:
            'Tier A block with 3 subtasks must satisfy content ideal minimum',
      );
    });

    test('Degrade ladder handles heavily crowded days gracefully', () {
      final now = DateTime(2026, 9, 29, 12, 0);
      // Create 8 contiguous 1-hour blocks spanning 8:00 to 16:00
      final occurrences = List.generate(8, (i) {
        final startHour = 8 + i;
        return Occurrence(
          id: 'ev-$i',
          eventId: 'ev-$i',
          title: 'Event $i',
          start: DateTime(2026, 9, 29, startHour, 0),
          end: DateTime(2026, 9, 29, startHour + 1, 0),
          subtasks: ['Subtask $i-A', 'Subtask $i-B'],
        );
      });

      final input = DialInput(
        now: now,
        occurrences: occurrences,
        prefs: const DialPrefs(
          previousBlocks: 3,
          nextBlocks: 3,
          lensEnabled: true,
        ),
      );

      final model = DialModelBuilder.build(input);

      // Verify sum of sweeps <= 360°
      final totalSweep = model.blocks.fold<double>(
        0.0,
        (acc, b) => acc + b.sweepDeg,
      );
      expect(totalSweep, lessThanOrEqualTo(360.0 + 1e-4));

      // Verify that no block collapsed to negative or zero sweep
      for (final block in model.blocks) {
        expect(block.sweepDeg, greaterThan(0.0));
      }
    });
  });

  group('WarpSolver Property-Based Tests (>= 1,000 Seeded Iterations)', () {
    test(
      '1,000 seeded random days: monotonicity, anchor, sum=360°, roundtrip',
      () {
        final rng = math.Random(93821);

        for (int iter = 0; iter < 1000; iter++) {
          final startHour = rng.nextInt(24);
          final startMinute = rng.nextInt(60);
          final now = DateTime(2026, 9, 29, startHour, startMinute);

          final is24 = rng.nextBool();
          final lensEnabled = rng.nextBool();
          final mag = 1.0 + rng.nextDouble() * 1.5; // 1.0 .. 2.5

          final numEvents = rng.nextInt(8) + 1; // 1..8 events
          final events = <Occurrence>[];

          var cursor = now.subtract(Duration(hours: rng.nextInt(6) + 1));
          for (int i = 0; i < numEvents; i++) {
            final gapMinutes = rng.nextInt(45) + 5;
            final durationMinutes = rng.nextInt(90) + 15;
            final evStart = cursor.add(Duration(minutes: gapMinutes));
            final evEnd = evStart.add(Duration(minutes: durationMinutes));
            cursor = evEnd;

            final subtaskCount = rng.nextInt(4);
            events.add(
              Occurrence(
                id: 'ev-$iter-$i',
                eventId: 'ev-$iter-$i',
                title: 'Block $i',
                start: evStart,
                end: evEnd,
                subtasks: List.generate(subtaskCount, (s) => 'Sub $s'),
              ),
            );
          }

          final input = DialInput(
            now: now,
            occurrences: events,
            prefs: DialPrefs(
              previousBlocks: rng.nextInt(4),
              nextBlocks: rng.nextInt(4),
              is24HourMode: is24,
              lensEnabled: lensEnabled,
              lensMagnification: mag,
            ),
          );

          final horizon = HorizonSelector.select(input);
          final map = WarpSolver.solve(horizon: horizon, input: input);

          // Invariant 1: Anchor holds at 0° and 360°
          expect(
            map.forward(0.0),
            closeTo(0.0, 1e-4),
            reason: 'Iteration $iter: 0° anchor failed',
          );
          expect(
            map.forward(360.0),
            closeTo(360.0, 1e-4),
            reason: 'Iteration $iter: 360° anchor failed',
          );

          // Invariant 2: Monotonicity
          final bps = map.breakpoints;
          for (int b = 0; b < bps.length - 1; b++) {
            expect(
              bps[b + 1].naturalDeg,
              greaterThan(bps[b].naturalDeg),
              reason: 'Iteration $iter: natural breakpoints not increasing',
            );
            expect(
              bps[b + 1].displayDeg,
              greaterThan(bps[b].displayDeg),
              reason: 'Iteration $iter: display breakpoints not monotonic',
            );
          }

          // Invariant 3: Roundtrip inverse(forward(x)) ≈ x
          final testAngles = [
            15.0,
            45.0,
            90.0,
            135.0,
            180.0,
            225.0,
            270.0,
            315.0,
          ];
          for (final angle in testAngles) {
            final fwd = map.forward(angle);
            final inv = map.inverse(fwd);
            expect(
              inv,
              closeTo(angle, 1e-3),
              reason: 'Iteration $iter: Roundtrip failed for angle $angle',
            );
          }
        }
      },
    );
  });
}
