import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/time/zone_clock.dart';
import '../../engine/dial_input.dart';
import '../models/sector_event.dart';
import '../models/subtask_item.dart';
import 'zone_day_projector.dart' as zone;

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

  static Occurrence fromZoneOccurrence(
    zone.Occurrence occ, {
    String? occurrenceId,
  }) {
    return Occurrence(
      id: occurrenceId ??
          '${occ.event.id}_${occ.startLocal.millisecondsSinceEpoch}',
      eventId: occ.event.id,
      title: occ.event.title,
      start: occ.startLocal,
      end: occ.endLocal,
      colorHex: occ.event.colorHex,
      category: occ.event.category,
      notes: occ.event.notes,
      iconName: occ.event.iconName,
      reminderMinutes: occ.event.reminderMinutes,
      isAllDay: occ.event.isAllDay,
      subtasks: List.unmodifiable(occ.event.subtasks),
      subtaskItems: occ.event.subtaskItems
          .map((s) => fromSubtaskItem(s, occ.startLocal))
          .toList(),
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

  static SectorEvent toSectorEvent(
    Occurrence occ, {
    required bool is24HourMode,
  }) {
    return SectorEvent(
      id: occ.eventId,
      title: occ.title,
      start: occ.start,
      end: occ.end,
      colorHex: occ.colorHex,
      category: occ.category,
      notes: occ.notes,
      iconName: occ.iconName,
      reminderMinutes: occ.reminderMinutes,
      isAllDay: occ.isAllDay,
      subtasks: occ.subtasks,
      subtaskItems: occ.subtaskItems.map((s) {
        final subStart = s.startMinuteOffset != null
            ? occ.start.add(Duration(minutes: s.startMinuteOffset!))
            : null;
        final subEnd = s.endMinuteOffset != null
            ? occ.start.add(Duration(minutes: s.endMinuteOffset!))
            : null;
        return SubtaskItem(
          id: s.id,
          parentEventId: occ.eventId,
          title: s.title,
          isCompleted: s.isCompleted,
          startTime: subStart != null
              ? TimeOfDay(hour: subStart.hour, minute: subStart.minute)
              : null,
          endTime: subEnd != null
              ? TimeOfDay(hour: subEnd.hour, minute: subEnd.minute)
              : null,
        );
      }).toList(),
    ).withComputedAngles(is24HourMode: is24HourMode);
  }

  /// Projects occurrences across a rolling horizon window (e.g. 36h) for widget frame planning.
  static List<Occurrence> projectOccurrencesForHorizon({
    required List<SectorEvent> events,
    required ZoneClockSnapshot clock,
    required bool is24HourMode,
    Duration horizon = const Duration(hours: 36),
  }) {
    final now = clock.localNow;
    final dayStart = DateTime(now.year, now.month, now.day);
    final displayLocation = now.location;

    final daysToProject = (horizon.inHours / 24).ceil() + 1;
    final uniqueOccurrences = <String, Occurrence>{};

    for (int i = 0; i <= daysToProject; i++) {
      final day = dayStart.add(Duration(days: i));
      final occs = zone.ZoneDayProjector.projectAllOccurrences(
        events: events,
        targetDay: day,
        displayZone: displayLocation,
        is24HourMode: is24HourMode,
      );
      for (final occ in occs) {
        final occurrenceId =
            '${occ.event.id}_${occ.startLocal.millisecondsSinceEpoch}';
        final engineOcc = fromZoneOccurrence(
          occ,
          occurrenceId: occurrenceId,
        );
        uniqueOccurrences[occurrenceId] = engineOcc;
      }
    }
    return uniqueOccurrences.values.toList();
  }
}
