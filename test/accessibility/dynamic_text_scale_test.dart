import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/core/i18n/numeral_system.dart';
import 'package:sectograph_mcp/engine/content_planner.dart';
import 'package:sectograph_mcp/engine/dial_input.dart';
import 'package:sectograph_mcp/engine/dial_model.dart';
import 'package:sectograph_mcp/engine/horizon_selector.dart';

void main() {
  group('Dynamic Text Scaling (100% to 200%) in ContentPlanner', () {
    final start = DateTime(2026, 9, 30, 10, 0);
    final end = DateTime(2026, 9, 30, 11, 30);

    final occurrence = Occurrence(
      id: 'scale-test',
      eventId: 'ev-scale',
      title: 'Design Team Sync',
      start: start,
      end: end,
      colorHex: '#3B82F6',
      category: 'Work',
    );

    final segment = OccurrenceSegment(
      occurrence: occurrence,
      segmentIndex: 0,
      segmentStart: start,
      segmentEnd: end,
      naturalStartDeg: 300.0,
      naturalSweepDeg: 45.0,
      tier: BlockTier.A,
      role: BlockRole.active,
      rank: 0,
    );

    test('ladder degrades gracefully from full to compact as text scale increases', () {
      // At sweep = 42.0 degrees:
      // At 1.0x (100%): threshold for full is 38.0° -> ContentMode.full
      final plan100 = ContentPlanner.planContent(
        segment: segment,
        displayStartDeg: 300.0,
        displaySweepDeg: 42.0,
        is24HourMode: false,
        textScale: 1.0,
      );
      expect(plan100.mode, ContentMode.full);

      // At 1.5x (150%): threshold for full is 38.0 * 1.5 = 57.0° -> ContentMode.compact (threshold 24.0 * 1.5 = 36.0°)
      final plan150 = ContentPlanner.planContent(
        segment: segment,
        displayStartDeg: 300.0,
        displaySweepDeg: 42.0,
        is24HourMode: false,
        textScale: 1.5,
      );
      expect(plan150.mode, ContentMode.compact);

      // At 2.0x (200%): threshold for compact is 24.0 * 2.0 = 48.0° -> ContentMode.iconKeyword (threshold 14.0 * 2.0 = 28.0°)
      final plan200 = ContentPlanner.planContent(
        segment: segment,
        displayStartDeg: 300.0,
        displaySweepDeg: 42.0,
        is24HourMode: false,
        textScale: 2.0,
      );
      expect(plan200.mode, ContentMode.iconKeyword);
    });

    test('cap labels visibility and span adapt to textScale', () {
      // Sweep = 20.0 deg
      // At 1.0x: minSweepForCaps = 14.0°, so visible
      final plan100 = ContentPlanner.planContent(
        segment: segment,
        displayStartDeg: 300.0,
        displaySweepDeg: 20.0,
        is24HourMode: false,
        textScale: 1.0,
      );
      expect(plan100.caps.isVisible, isTrue);

      // At 2.0x: minSweepForCaps = 14.0 * 2.0 = 28.0°, so hidden!
      final plan200 = ContentPlanner.planContent(
        segment: segment,
        displayStartDeg: 300.0,
        displaySweepDeg: 20.0,
        is24HourMode: false,
        textScale: 2.0,
      );
      expect(plan200.caps.isVisible, isFalse);
    });

    test('cap timestamp labels format according to requested numeralSystem', () {
      final devanagariPlan = ContentPlanner.planContent(
        segment: segment,
        displayStartDeg: 300.0,
        displaySweepDeg: 45.0,
        is24HourMode: false,
        numeralSystem: NumeralSystem.devanagari,
      );

      expect(devanagariPlan.caps.startTimeLabel, '१०:००');
      expect(devanagariPlan.caps.endTimeLabel, '११:३०');

      final arabicPlan = ContentPlanner.planContent(
        segment: segment,
        displayStartDeg: 300.0,
        displaySweepDeg: 45.0,
        is24HourMode: false,
        numeralSystem: NumeralSystem.arabicIndic,
      );

      expect(arabicPlan.caps.startTimeLabel, '١٠:٠٠');
      expect(arabicPlan.caps.endTimeLabel, '١١:٣٠');
    });
  });
}
