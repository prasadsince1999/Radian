import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/engine/content_planner.dart';
import 'package:sectograph_mcp/engine/dial_input.dart';
import 'package:sectograph_mcp/engine/dial_model.dart';
import 'package:sectograph_mcp/engine/horizon_selector.dart';
import 'package:sectograph_mcp/engine/subtask_placer.dart';
import 'package:sectograph_mcp/engine/warp_map.dart';

void main() {
  OccurrenceSegment createSegment({
    required String title,
    required List<String> subtasks,
    List<SubtaskItemOccurrence>? subtaskItems,
    BlockTier tier = BlockTier.A,
    BlockRole role = BlockRole.active,
    DateTime? start,
    DateTime? end,
    double naturalStartDeg = 60.0,
    double naturalSweepDeg = 120.0,
  }) {
    final int startMinutes = ((naturalStartDeg / 360.0) * 12 * 60).round();
    final int durationMinutes = math.max(
      1,
      ((naturalSweepDeg / 360.0) * 12 * 60).round(),
    );
    final baseDay = DateTime(2026, 9, 29);
    final s = start ?? baseDay.add(Duration(minutes: startMinutes));
    final e = end ?? s.add(Duration(minutes: durationMinutes));

    return OccurrenceSegment(
      occurrence: Occurrence(
        id: 'ev-test',
        eventId: 'test',
        title: title,
        start: s,
        end: e,
        colorHex: '#6366F1',
        category: 'Work',
        subtasks: subtasks,
        subtaskItems: subtaskItems ?? const [],
      ),
      segmentIndex: 0,
      segmentStart: s,
      segmentEnd: e,
      naturalStartDeg: naturalStartDeg,
      naturalSweepDeg: naturalSweepDeg,
      tier: tier,
      role: role,
      rank: 0,
    );
  }

  void assertNonOverlapping({
    required List<CapsulePlacement> capsules,
    required ContentPlan contentPlan,
    required double displayStartDeg,
    required double displaySweepDeg,
  }) {
    final blockStart = displayStartDeg;
    final blockEnd = displayStartDeg + displaySweepDeg;

    // 1. Invariant I4: Verify every capsule stays strictly within block boundaries
    for (final c in capsules) {
      final halfSpan = c.angularWidthDeg / 2.0;

      // Normalize c.centerDeg to block frame
      var normalizedCenter = c.centerDeg;
      while (normalizedCenter < blockStart - 1e-4) {
        normalizedCenter += 360.0;
      }
      while (normalizedCenter > blockEnd + 1e-4) {
        normalizedCenter -= 360.0;
      }

      final candStart = normalizedCenter - halfSpan;
      final candEnd = normalizedCenter + halfSpan;

      expect(
        candStart >= blockStart - 1e-3,
        isTrue,
        reason:
            'Capsule ${c.title} start ($candStart) violates blockStart ($blockStart)',
      );
      expect(
        candEnd <= blockEnd + 1e-3,
        isTrue,
        reason:
            'Capsule ${c.title} end ($candEnd) violates blockEnd ($blockEnd)',
      );

      // 2. Invariant I4: No capsule intersects any reserved zone
      for (final zone in contentPlan.reservedZones) {
        final intersects = zone.intersects(
          candStart % 360.0,
          candEnd - candStart,
          candidateLane: c.lane,
        );
        expect(
          intersects,
          isFalse,
          reason:
              'Capsule ${c.title} (lane ${c.lane}) collides with reserved zone ${zone.name}',
        );
      }
    }

    // 3. Invariant I4: No two capsules in the same lane intersect each other
    for (int i = 0; i < capsules.length; i++) {
      for (int j = i + 1; j < capsules.length; j++) {
        final c1 = capsules[i];
        final c2 = capsules[j];

        if (c1.lane != c2.lane) continue;

        var center1 = c1.centerDeg;
        while (center1 < blockStart - 1e-4) {
          center1 += 360.0;
        }
        var center2 = c2.centerDeg;
        while (center2 < blockStart - 1e-4) {
          center2 += 360.0;
        }

        final span1 = c1.angularWidthDeg;
        final span2 = c2.angularWidthDeg;

        final start1 = center1 - span1 / 2.0;
        final end1 = center1 + span1 / 2.0;
        final start2 = center2 - span2 / 2.0;
        final end2 = center2 + span2 / 2.0;

        final overlaps = !(end1 <= start2 + 1e-4 || start1 >= end2 - 1e-4);
        expect(
          overlaps,
          isFalse,
          reason:
              'Capsules "${c1.title}" and "${c2.title}" in lane ${c1.lane} collide: [$start1, $end1] vs [$start2, $end2]',
        );
      }
    }
  }

  group('SubtaskPlacer Fixture Counts (0, 1, 3, 6, 10)', () {
    test('0 subtasks produces empty capsule list', () {
      final seg = createSegment(title: 'Empty Task', subtasks: const []);
      final plan = ContentPlanner.planContent(
        segment: seg,
        displayStartDeg: 60.0,
        displaySweepDeg: 120.0,
        is24HourMode: false,
      );

      final capsules = SubtaskPlacer.place(
        segment: seg,
        displayStartDeg: 60.0,
        displaySweepDeg: 120.0,
        warp: const WarpMap.identity(),
        is24HourMode: false,
        contentPlan: plan,
      );

      expect(capsules, isEmpty);
    });

    test('1 subtask places single capsule cleanly without collision', () {
      final seg = createSegment(
        title: 'Single Task',
        subtasks: const ['Review PR'],
      );
      final plan = ContentPlanner.planContent(
        segment: seg,
        displayStartDeg: 60.0,
        displaySweepDeg: 120.0,
        is24HourMode: false,
      );

      final capsules = SubtaskPlacer.place(
        segment: seg,
        displayStartDeg: 60.0,
        displaySweepDeg: 120.0,
        warp: const WarpMap.identity(),
        is24HourMode: false,
        contentPlan: plan,
      );

      expect(capsules.length, 1);
      expect(capsules.first.title, 'Review');
      expect(capsules.first.isFolded, isFalse);

      assertNonOverlapping(
        capsules: capsules,
        contentPlan: plan,
        displayStartDeg: 60.0,
        displaySweepDeg: 120.0,
      );
    });

    test('3 subtasks on Tier A place all 3 capsules without folding (I5)', () {
      final seg = createSegment(
        title: 'Morning Yoga & Meditation',
        subtasks: const ['Hydrate', 'Surya Namaskar', 'Meditation'],
        tier: BlockTier.A,
      );
      final plan = ContentPlanner.planContent(
        segment: seg,
        displayStartDeg: 60.0,
        displaySweepDeg: 120.0,
        is24HourMode: false,
      );

      final capsules = SubtaskPlacer.place(
        segment: seg,
        displayStartDeg: 60.0,
        displaySweepDeg: 120.0,
        warp: const WarpMap.identity(),
        is24HourMode: false,
        contentPlan: plan,
      );

      expect(capsules.length, 3);
      expect(capsules.every((c) => !c.isFolded), isTrue);

      assertNonOverlapping(
        capsules: capsules,
        contentPlan: plan,
        displayStartDeg: 60.0,
        displaySweepDeg: 120.0,
      );
    });

    test(
      '6 subtasks on Tier A guarantee no folding into +N (I5 Tier A Guarantee)',
      () {
        final seg = createSegment(
          title: 'Deep Engineering Sprint',
          subtasks: const [
            'Architecture',
            'Warp Solver',
            'Content Planner',
            'Subtask Placer',
            'Dial Painter',
            'Parity Test',
          ],
          tier: BlockTier.A,
          naturalSweepDeg: 130.0,
        );

        final plan = ContentPlanner.planContent(
          segment: seg,
          displayStartDeg: 45.0,
          displaySweepDeg: 130.0,
          is24HourMode: false,
        );

        final capsules = SubtaskPlacer.place(
          segment: seg,
          displayStartDeg: 45.0,
          displaySweepDeg: 130.0,
          warp: const WarpMap.identity(),
          is24HourMode: false,
          contentPlan: plan,
        );

        // Invariant I5: Tier A blocks never fold to +N for <= 6 subtasks
        expect(capsules.length, 6);
        expect(
          capsules.any((c) => c.isFolded),
          isFalse,
          reason:
              'Tier A must never fold to +N for <= 6 subtasks (Invariant I5)',
        );

        assertNonOverlapping(
          capsules: capsules,
          contentPlan: plan,
          displayStartDeg: 45.0,
          displaySweepDeg: 130.0,
        );
      },
    );

    test(
      '10 subtasks on tight Tier B block folds excess into +N capsule cleanly',
      () {
        final seg = createSegment(
          title: 'Backlog Grooming',
          subtasks: List.generate(10, (i) => 'Item ${i + 1}'),
          tier: BlockTier.B,
          naturalSweepDeg: 60.0,
        );

        final plan = ContentPlanner.planContent(
          segment: seg,
          displayStartDeg: 120.0,
          displaySweepDeg: 60.0,
          is24HourMode: false,
        );

        final capsules = SubtaskPlacer.place(
          segment: seg,
          displayStartDeg: 120.0,
          displaySweepDeg: 60.0,
          warp: const WarpMap.identity(),
          is24HourMode: false,
          contentPlan: plan,
        );

        // Should place some and fold remainder
        expect(capsules.isNotEmpty, isTrue);
        expect(capsules.any((c) => c.isFolded), isTrue);

        assertNonOverlapping(
          capsules: capsules,
          contentPlan: plan,
          displayStartDeg: 120.0,
          displaySweepDeg: 60.0,
        );
      },
    );
  });

  group('SubtaskPlacer International Titles', () {
    test(
      'places subtasks with Odia, Hindi, Arabic, and CJK titles correctly',
      () {
        final seg = createSegment(
          title: 'Global International Sync',
          subtasks: const [
            'ଯୋଗ ଏବଂ ଧ୍ୟାନ', // Odia
            'प्राणायाम', // Hindi
            'جلسة عمل', // Arabic
            '設計レビュー', // Japanese
          ],
          tier: BlockTier.A,
          naturalSweepDeg: 125.0,
        );

        final plan = ContentPlanner.planContent(
          segment: seg,
          displayStartDeg: 90.0,
          displaySweepDeg: 125.0,
          is24HourMode: false,
        );

        final capsules = SubtaskPlacer.place(
          segment: seg,
          displayStartDeg: 90.0,
          displaySweepDeg: 125.0,
          warp: const WarpMap.identity(),
          is24HourMode: false,
          contentPlan: plan,
        );

        expect(capsules.length, 4);
        assertNonOverlapping(
          capsules: capsules,
          contentPlan: plan,
          displayStartDeg: 90.0,
          displaySweepDeg: 125.0,
        );
      },
    );
  });

  group('SubtaskPlacer Edge Cases & Invariants', () {
    test('two subtasks with identical start times separate across radial lanes without collision', () {
      final items = [
        const SubtaskItemOccurrence(
          id: 'st-1',
          title: 'Pair Review',
          startMinuteOffset: 30,
        ),
        const SubtaskItemOccurrence(
          id: 'st-2',
          title: 'Unit Test',
          startMinuteOffset: 30, // Identical time!
        ),
      ];

      final seg = createSegment(
        title: 'Coding Session',
        subtasks: const [],
        subtaskItems: items,
        tier: BlockTier.A,
      );

      final plan = ContentPlanner.planContent(
        segment: seg,
        displayStartDeg: 60.0,
        displaySweepDeg: 110.0,
        is24HourMode: false,
      );

      final capsules = SubtaskPlacer.place(
        segment: seg,
        displayStartDeg: 60.0,
        displaySweepDeg: 110.0,
        warp: const WarpMap.identity(),
        is24HourMode: false,
        contentPlan: plan,
      );

      expect(capsules.length, 2);
      // They should either be on different lanes or shifted collision-free
      assertNonOverlapping(
        capsules: capsules,
        contentPlan: plan,
        displayStartDeg: 60.0,
        displaySweepDeg: 110.0,
      );
    });

    test('subtasks at exactly block start and block end clamp inside safe interior', () {
      final items = [
        const SubtaskItemOccurrence(
          id: 'st-start',
          title: 'Kickoff',
          startMinuteOffset: 0, // Exactly at block start
        ),
        const SubtaskItemOccurrence(
          id: 'st-end',
          title: 'Wrapup',
          startMinuteOffset: 120, // Exactly at block end (2 hours)
        ),
      ];

      final seg = createSegment(
        title: 'Project Milestone',
        subtasks: const [],
        subtaskItems: items,
        tier: BlockTier.A,
      );

      final plan = ContentPlanner.planContent(
        segment: seg,
        displayStartDeg: 60.0,
        displaySweepDeg: 110.0,
        is24HourMode: false,
      );

      final capsules = SubtaskPlacer.place(
        segment: seg,
        displayStartDeg: 60.0,
        displaySweepDeg: 110.0,
        warp: const WarpMap.identity(),
        is24HourMode: false,
        contentPlan: plan,
      );

      expect(capsules.length, 2);
      assertNonOverlapping(
        capsules: capsules,
        contentPlan: plan,
        displayStartDeg: 60.0,
        displaySweepDeg: 110.0,
      );
    });

    test('block crossing 360°/0° boundary places capsules with correct angular coordinates', () {
      final items = [
        const SubtaskItemOccurrence(
          id: 'st-night',
          title: 'Night Meditation',
          startMinuteOffset: 30,
        ),
        const SubtaskItemOccurrence(
          id: 'st-dawn',
          title: 'Dawn Prep',
          startMinuteOffset: 150,
        ),
      ];

      final seg = createSegment(
        title: 'Midnight Crossing',
        subtasks: const [],
        subtaskItems: items,
        start: DateTime(2026, 9, 29, 23, 0),
        end: DateTime(2026, 9, 30, 2, 0), // 3 hours, crosses midnight
        naturalStartDeg: 330.0,
        naturalSweepDeg: 90.0,
        tier: BlockTier.A,
      );

      final plan = ContentPlanner.planContent(
        segment: seg,
        displayStartDeg: 330.0,
        displaySweepDeg: 100.0,
        is24HourMode: false,
      );

      final capsules = SubtaskPlacer.place(
        segment: seg,
        displayStartDeg: 330.0,
        displaySweepDeg: 100.0,
        warp: const WarpMap.identity(),
        is24HourMode: false,
        contentPlan: plan,
      );

      expect(capsules.length, 2);
      assertNonOverlapping(
        capsules: capsules,
        contentPlan: plan,
        displayStartDeg: 330.0,
        displaySweepDeg: 100.0,
      );
    });
  });
}
