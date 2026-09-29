import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/domain/models/sector_event.dart';
import 'package:sectograph_mcp/domain/rules/block_budget.dart';

void main() {
  group('BlockBudget Tests', () {
    test('maxVisible dynamically scales with P and N bounded [1, 7]', () {
      expect(BlockBudget.maxVisible(0, 0), 1);
      expect(BlockBudget.maxVisible(1, 1), 3);
      expect(BlockBudget.maxVisible(1, 3), 5);
      expect(BlockBudget.maxVisible(3, 3), 7);
      expect(BlockBudget.maxVisible(5, 5), 7); // Clamped at 7
    });

    test('12H window allows up to 12 blocks in AM and rejects 13th', () {
      final existing = <SectorEvent>[];
      final day = DateTime(2026, 9, 29);

      // Add 12 events in AM window (00:00 - 12:00)
      for (int i = 0; i < 12; i++) {
        existing.add(
          SectorEvent(
            id: 'am-$i',
            title: 'AM Block $i',
            start: DateTime(day.year, day.month, day.day, i, 0),
            end: DateTime(day.year, day.month, day.day, i, 45),
          ),
        );
      }

      // 13th AM block should be rejected
      final candidate13thAM = SectorEvent(
        id: 'am-overflow',
        title: 'AM 13th',
        start: DateTime(day.year, day.month, day.day, 11, 45),
        end: DateTime(day.year, day.month, day.day, 12, 0),
      );

      final resultAM = BlockBudget.check(
        existingEvents: existing,
        candidate: candidate13thAM,
        is24HourMode: false,
      );

      expect(resultAM.allowed, false);
      expect(resultAM.currentCount, 12);
      expect(resultAM.maxAllowed, 12);
      expect(resultAM.reason, contains('full'));

      // But a PM block should still be allowed!
      final candidatePM = SectorEvent(
        id: 'pm-1',
        title: 'PM Block 1',
        start: DateTime(day.year, day.month, day.day, 14, 0),
        end: DateTime(day.year, day.month, day.day, 15, 0),
      );

      final resultPM = BlockBudget.check(
        existingEvents: existing,
        candidate: candidatePM,
        is24HourMode: false,
      );

      expect(resultPM.allowed, true);
      expect(resultPM.currentCount, 1);
    });

    test('24H mode allows up to 18 blocks across the entire day', () {
      final existing = <SectorEvent>[];
      final day = DateTime(2026, 9, 29);

      // Add 18 events
      for (int i = 0; i < 18; i++) {
        final hour = i % 24;
        existing.add(
          SectorEvent(
            id: '24h-$i',
            title: 'Block $i',
            start: DateTime(day.year, day.month, day.day, hour, 0),
            end: DateTime(day.year, day.month, day.day, hour, 30),
          ),
        );
      }

      final candidate19th = SectorEvent(
        id: 'overflow-24h',
        title: '19th Block',
        start: DateTime(day.year, day.month, day.day, 23, 0),
        end: DateTime(day.year, day.month, day.day, 23, 30),
      );

      final result = BlockBudget.check(
        existingEvents: existing,
        candidate: candidate19th,
        is24HourMode: true,
      );

      expect(result.allowed, false);
      expect(result.currentCount, 18);
      expect(result.maxAllowed, 18);
    });
  });
}
