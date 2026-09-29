import 'dart:math' as math;

import '../../engine/dial_input.dart';
import '../models/sector_event.dart';
import '../models/subtask_item.dart';

/// Bridges between Flutter-facing SectorEvent domain models and the pure Dart Dial Engine.
class OccurrenceAdapter {
  const OccurrenceAdapter._();

  static SubtaskItemOccurrence fromSubtaskItem(
    SubtaskItem item,
    DateTime blockStart,
  ) {
    int? startOffset;
    int? endOffset;

    if (item.startTime != null) {
      final subStartMins = item.startTime!.hour * 60 + item.startTime!.minute;
      final blockStartMins = blockStart.hour * 60 + blockStart.minute;
      startOffset = math.max(0, subStartMins - blockStartMins);
    }
    if (item.endTime != null) {
      final subEndMins = item.endTime!.hour * 60 + item.endTime!.minute;
      final blockStartMins = blockStart.hour * 60 + blockStart.minute;
      endOffset = math.max(0, subEndMins - blockStartMins);
    }

    return SubtaskItemOccurrence(
      id: item.id,
      title: item.title,
      isCompleted: item.isCompleted,
      startMinuteOffset: startOffset,
      endMinuteOffset: endOffset,
    );
  }

  static Occurrence fromSectorEvent(
    SectorEvent event, {
    String? occurrenceId,
  }) {
    return Occurrence(
      id: occurrenceId ?? event.id,
      eventId: event.id,
      title: event.title,
      start: event.start,
      end: event.end,
      colorHex: event.colorHex,
      category: event.category,
      notes: event.notes,
      iconName: event.iconName,
      reminderMinutes: event.reminderMinutes,
      isAllDay: event.isAllDay,
      subtasks: List.unmodifiable(event.subtasks),
      subtaskItems: event.subtaskItems
          .map((s) => fromSubtaskItem(s, event.start))
          .toList(),
    );
  }

  static List<Occurrence> fromSectorEvents(List<SectorEvent> events) {
    return events.map((e) => fromSectorEvent(e)).toList();
  }
}
