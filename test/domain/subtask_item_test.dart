import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/domain/models/sector_event.dart';
import 'package:sectograph_mcp/domain/models/subtask_item.dart';

void main() {
  group('SubtaskItem Domain Tests', () {
    test('creates with full parameters', () {
      final sub = SubtaskItem.create(
        parentEventId: 'event-123',
        title: 'Complete Math Quiz',
        startTime: const TimeOfDay(hour: 10, minute: 30),
        endTime: const TimeOfDay(hour: 11, minute: 15),
        date: DateTime(2026, 9, 12),
        reminderMinutes: 10,
      );

      expect(sub.parentEventId, 'event-123');
      expect(sub.title, 'Complete Math Quiz');
      expect(sub.startTime, const TimeOfDay(hour: 10, minute: 30));
      expect(sub.endTime, const TimeOfDay(hour: 11, minute: 15));
      expect(sub.date, DateTime(2026, 9, 12));
      expect(sub.reminderMinutes, 10);
      expect(sub.isCompleted, false);
    });

    test('serializes and deserializes cleanly via toJson and fromJson', () {
      final sub = SubtaskItem(
        id: 'sub-456',
        parentEventId: 'event-123',
        title: 'Review PR',
        isCompleted: true,
        startTime: const TimeOfDay(hour: 14, minute: 0),
        endTime: const TimeOfDay(hour: 14, minute: 45),
        date: DateTime(2026, 9, 12),
        reminderMinutes: 5,
      );

      final json = sub.toJson();
      final restored = SubtaskItem.fromJson(json);

      expect(restored.id, 'sub-456');
      expect(restored.parentEventId, 'event-123');
      expect(restored.title, 'Review PR');
      expect(restored.isCompleted, true);
      expect(restored.startTime, const TimeOfDay(hour: 14, minute: 0));
      expect(restored.endTime, const TimeOfDay(hour: 14, minute: 45));
      expect(restored.reminderMinutes, 5);
    });

    test(
      'SectorEvent maintains 100% backward compatibility with string subtasks',
      () {
        final event = SectorEvent(
          id: 'ev-1',
          title: 'Study Session',
          start: DateTime(2026, 9, 12, 10, 0),
          end: DateTime(2026, 9, 12, 12, 0),
          subtasks: const ['LinAlg', 'PyTorch'],
        );

        // Both accessors work seamlessly
        expect(event.subtasks, ['LinAlg', 'PyTorch']);
        expect(event.subtaskItems.length, 2);
        expect(event.subtaskItems[0].title, 'LinAlg');
        expect(event.subtaskItems[0].parentEventId, 'ev-1');
        expect(event.subtaskItems[1].title, 'PyTorch');

        // Round-trip through JSON
        final json = event.toJson();
        final restored = SectorEvent.fromJson(json);
        expect(restored.subtasks, ['LinAlg', 'PyTorch']);
        expect(restored.subtaskItems.length, 2);
      },
    );
  });
}
