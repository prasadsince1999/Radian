import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/engine/content_planner.dart';
import 'package:sectograph_mcp/engine/dial_input.dart';
import 'package:sectograph_mcp/engine/dial_model.dart';
import 'package:sectograph_mcp/engine/horizon_selector.dart';

void main() {
  group('ContentPlanner ContentMode Ladder', () {
    final now = DateTime(2026, 9, 29, 10, 0);
    final occurrence = Occurrence(
      id: 'ev-test',
      eventId: 'test',
      title: 'Sprint Planning Meeting',
      start: now,
      end: now.add(const Duration(hours: 2)),
      colorHex: '#3B82F6',
      category: 'Work',
    );

    final segment = OccurrenceSegment(
      occurrence: occurrence,
      segmentIndex: 0,
      segmentStart: now,
      segmentEnd: now.add(const Duration(hours: 2)),
      naturalStartDeg: 300.0,
      naturalSweepDeg: 60.0,
      tier: BlockTier.A,
      role: BlockRole.active,
      rank: 0,
    );

    test('12H mode selects correct ladder step across sweep variations', () {
      final fullPlan = ContentPlanner.planContent(
        segment: segment,
        displayStartDeg: 300.0,
        displaySweepDeg: 42.0,
        is24HourMode: false,
      );
      expect(fullPlan.mode, ContentMode.full);

      final compactPlan = ContentPlanner.planContent(
        segment: segment,
        displayStartDeg: 300.0,
        displaySweepDeg: 30.0,
        is24HourMode: false,
      );
      expect(compactPlan.mode, ContentMode.compact);

      final keywordPlan = ContentPlanner.planContent(
        segment: segment,
        displayStartDeg: 300.0,
        displaySweepDeg: 20.0,
        is24HourMode: false,
      );
      expect(keywordPlan.mode, ContentMode.iconKeyword);

      final iconOnlyPlan = ContentPlanner.planContent(
        segment: segment,
        displayStartDeg: 300.0,
        displaySweepDeg: 12.0,
        is24HourMode: false,
      );
      expect(iconOnlyPlan.mode, ContentMode.iconOnly);
    });

    test('24H mode adapts lower sweep thresholds for denser face', () {
      final fullPlan = ContentPlanner.planContent(
        segment: segment,
        displayStartDeg: 150.0,
        displaySweepDeg: 26.0,
        is24HourMode: true,
      );
      expect(fullPlan.mode, ContentMode.full);

      final compactPlan = ContentPlanner.planContent(
        segment: segment,
        displayStartDeg: 150.0,
        displaySweepDeg: 18.0,
        is24HourMode: true,
      );
      expect(compactPlan.mode, ContentMode.compact);

      final keywordPlan = ContentPlanner.planContent(
        segment: segment,
        displayStartDeg: 150.0,
        displaySweepDeg: 12.0,
        is24HourMode: true,
      );
      expect(keywordPlan.mode, ContentMode.iconKeyword);

      final iconOnlyPlan = ContentPlanner.planContent(
        segment: segment,
        displayStartDeg: 150.0,
        displaySweepDeg: 8.0,
        is24HourMode: true,
      );
      expect(iconOnlyPlan.mode, ContentMode.iconOnly);
    });
  });

  group('ContentPlanner Cap Labels', () {
    final start = DateTime(2026, 9, 29, 9, 15);
    final end = DateTime(2026, 9, 29, 11, 45);

    final segment = OccurrenceSegment(
      occurrence: Occurrence(
        id: 'ev-caps',
        eventId: 'caps',
        title: 'Work Session',
        start: start,
        end: end,
        colorHex: '#10B981',
        category: 'Work',
      ),
      segmentIndex: 0,
      segmentStart: start,
      segmentEnd: end,
      naturalStartDeg: 277.5,
      naturalSweepDeg: 75.0,
      tier: BlockTier.B,
      role: BlockRole.next,
      rank: 1,
    );

    test(
      'formats time labels cleanly and toggles visibility based on sweep',
      () {
        final visiblePlan = ContentPlanner.planContent(
          segment: segment,
          displayStartDeg: 277.5,
          displaySweepDeg: 75.0,
          is24HourMode: false,
        );

        expect(visiblePlan.caps.isVisible, isTrue);
        expect(visiblePlan.caps.startTimeLabel, '09:15');
        expect(visiblePlan.caps.endTimeLabel, '11:45');
        expect(visiblePlan.caps.startAngleDeg, 277.5);
        expect(visiblePlan.caps.endAngleDeg, (277.5 + 75.0) % 360.0);

        final hiddenPlan = ContentPlanner.planContent(
          segment: segment,
          displayStartDeg: 277.5,
          displaySweepDeg: 10.0,
          is24HourMode: false,
        );
        expect(hiddenPlan.caps.isVisible, isFalse);
      },
    );
  });

  group('ContentPlanner distillKeyword', () {
    test(
      'extracts punchy keywords across English and international scripts',
      () {
        expect(ContentPlanner.distillKeyword('Yoga'), 'Yoga');
        expect(ContentPlanner.distillKeyword('Morning Yoga'), 'Morning Yoga');
        expect(
          ContentPlanner.distillKeyword('Deep Focus Coding Session'),
          'Deep Focus',
        );
        expect(
          ContentPlanner.distillKeyword('Comprehensive Architecture Review'),
          'Comprehensive',
        );

        // Odia
        expect(ContentPlanner.distillKeyword('ଯୋଗ ଏବଂ ଧ୍ୟାନ'), 'ଯୋଗ ଏବଂ');

        // Hindi
        expect(
          ContentPlanner.distillKeyword('प्राणायाम और ध्यान'),
          'प्राणायाम और',
        );

        // Arabic
        expect(ContentPlanner.distillKeyword('جلسة عمل مركزة'), 'جلسة عمل');

        // CJK / Japanese
        expect(ContentPlanner.distillKeyword('デザイン設計レビュー'), 'デザイン設計レビュー');

        // Edge cases
        expect(ContentPlanner.distillKeyword(''), 'Task');
        expect(ContentPlanner.distillKeyword('   '), 'Task');
      },
    );
  });

  group('ReservedZone Circular Collision Detection', () {
    test(
      'standard non-wrapping intervals detect intersections and clearances',
      () {
        const zone = ReservedZone(
          name: 'testZone',
          startDeg: 100.0,
          sweepDeg: 30.0,
        );

        // Overlap at start
        expect(zone.intersects(90.0, 20.0), isTrue);
        // Overlap at end
        expect(zone.intersects(120.0, 20.0), isTrue);
        // Fully contained inside
        expect(zone.intersects(105.0, 10.0), isTrue);
        // Fully enclosing zone
        expect(zone.intersects(80.0, 60.0), isTrue);
        // Disjoint before
        expect(zone.intersects(50.0, 30.0), isFalse);
        // Disjoint after
        expect(zone.intersects(140.0, 30.0), isFalse);
      },
    );

    test('zone crossing 360°/0° boundary correctly intersects both sides', () {
      // Zone spans [350° to 370° (10°)]
      const wrapZone = ReservedZone(
        name: 'midnightZone',
        startDeg: 350.0,
        sweepDeg: 20.0,
      );

      // Candidate on 350°+ side
      expect(wrapZone.intersects(355.0, 4.0), isTrue);
      // Candidate on 0°-10° side
      expect(wrapZone.intersects(2.0, 5.0), isTrue);
      // Candidate crossing 0° exactly
      expect(wrapZone.intersects(358.0, 6.0), isTrue);
      // Disjoint on 340° side
      expect(wrapZone.intersects(330.0, 15.0), isFalse);
      // Disjoint on 20° side
      expect(wrapZone.intersects(15.0, 20.0), isFalse);
    });

    test('candidate crossing 360°/0° boundary detects static zones', () {
      const zoneA = ReservedZone(
        name: 'beforeMidnight',
        startDeg: 350.0,
        sweepDeg: 8.0,
      );
      const zoneB = ReservedZone(
        name: 'afterMidnight',
        startDeg: 2.0,
        sweepDeg: 8.0,
      );
      const zoneC = ReservedZone(
        name: 'farAway',
        startDeg: 100.0,
        sweepDeg: 20.0,
      );

      // Candidate spans [355° to 5°]
      expect(zoneA.intersects(355.0, 10.0), isTrue);
      expect(zoneB.intersects(355.0, 10.0), isTrue);
      expect(zoneC.intersects(355.0, 10.0), isFalse);
    });

    test('lane-specific reserved zones isolate lanes correctly', () {
      const outerZone = ReservedZone(
        name: 'outerOnly',
        startDeg: 50.0,
        sweepDeg: 20.0,
        lane: 0,
      );

      // Same angular interval, different lane
      expect(outerZone.intersects(55.0, 10.0, candidateLane: 1), isFalse);
      // Same angular interval, matching lane
      expect(outerZone.intersects(55.0, 10.0, candidateLane: 0), isTrue);
      // Candidate with unspecified lane
      expect(outerZone.intersects(55.0, 10.0, candidateLane: null), isTrue);
    });
  });
}
