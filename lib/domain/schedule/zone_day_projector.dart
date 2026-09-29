import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/geometry/sector_math.dart';
import '../../core/time/time_spec.dart';
import '../../core/time/zone_clock.dart';
import '../models/sector_event.dart';
import 'event_day_projector.dart';

/// An occurrence of a time block on a specific calendar day in a specific timezone.
@immutable
class Occurrence {
  final SectorEvent event;
  final tz.TZDateTime startLocal;
  final tz.TZDateTime endLocal;
  final DateTime startInstant; // UTC
  final DateTime endInstant; // UTC
  final double startAngle;
  final double sweepAngle;

  const Occurrence({
    required this.event,
    required this.startLocal,
    required this.endLocal,
    required this.startInstant,
    required this.endInstant,
    required this.startAngle,
    required this.sweepAngle,
  });

  Duration get wallClockDuration => endLocal.difference(startLocal);

  /// Converts this occurrence into a projected [SectorEvent] suitable for
  /// consumption by existing dial painters and UI widgets.
  SectorEvent toSectorEvent({required bool is24HourMode}) {
    return event.copyWith(
      start: DateTime(
        startLocal.year,
        startLocal.month,
        startLocal.day,
        startLocal.hour,
        startLocal.minute,
        startLocal.second,
      ),
      end: DateTime(
        endLocal.year,
        endLocal.month,
        endLocal.day,
        endLocal.hour,
        endLocal.minute,
        endLocal.second,
      ),
      startAngle: startAngle,
      sweepAngle: sweepAngle,
    );
  }

  @override
  String toString() =>
      'Occurrence(${event.title}, local: $startLocal -> $endLocal, angle: $startAngle + $sweepAngle)';
}

/// Timezone-aware day projector wrapping and extending [EventDayProjector] (refinement R4).
///
/// Projects stored events (whether [InstantTime], [FloatingTime], or legacy)
/// onto a target calendar day in a specific display [tz.Location].
class ZoneDayProjector {
  const ZoneDayProjector._();

  /// Projects a single [SectorEvent] onto [targetDay] in [displayZone].
  static Occurrence? project({
    required SectorEvent event,
    required DateTime targetDay,
    required tz.Location displayZone,
    bool is24HourMode = false,
  }) {
    ensureTimeZonesInitialized();

    final timeSpec = event.timeSpec;

    if (timeSpec is InstantTime) {
      return _projectInstant(
        event: event,
        instant: timeSpec,
        targetDay: targetDay,
        displayZone: displayZone,
        is24HourMode: is24HourMode,
      );
    } else if (timeSpec is FloatingTime) {
      return _projectFloating(
        event: event,
        floating: timeSpec,
        targetDay: targetDay,
        displayZone: displayZone,
        is24HourMode: is24HourMode,
      );
    }

    // Fallback: Legacy event without explicit TimeSpec
    // Wrap existing EventDayProjector logic (Refinement R4)
    final legacyProjected = EventDayProjector.project(event, targetDay);
    if (legacyProjected == null) return null;

    final startLocal = tz.TZDateTime(
      displayZone,
      legacyProjected.start.year,
      legacyProjected.start.month,
      legacyProjected.start.day,
      legacyProjected.start.hour,
      legacyProjected.start.minute,
      legacyProjected.start.second,
    );
    final endLocal = tz.TZDateTime(
      displayZone,
      legacyProjected.end.year,
      legacyProjected.end.month,
      legacyProjected.end.day,
      legacyProjected.end.hour,
      legacyProjected.end.minute,
      legacyProjected.end.second,
    );

    final startAngle = SectorMath.timeToDialAngle(
      startLocal,
      is24HourMode: is24HourMode,
    );
    final sweepAngle = SectorMath.durationToSweepAngle(
      endLocal.difference(startLocal),
      is24HourMode: is24HourMode,
    );

    return Occurrence(
      event: legacyProjected,
      startLocal: startLocal,
      endLocal: endLocal,
      startInstant: startLocal.toUtc(),
      endInstant: endLocal.toUtc(),
      startAngle: startAngle,
      sweepAngle: sweepAngle,
    );
  }

  /// Projects an [InstantTime] event (fixed point in UTC time).
  static Occurrence? _projectInstant({
    required SectorEvent event,
    required InstantTime instant,
    required DateTime targetDay,
    required tz.Location displayZone,
    required bool is24HourMode,
  }) {
    final utcStart = instant.utcDateTime;
    final utcEnd = utcStart.add(event.duration);

    final localStart = tz.TZDateTime.from(utcStart, displayZone);
    final localEnd = tz.TZDateTime.from(utcEnd, displayZone);

    final dayStart = tz.TZDateTime(
      displayZone,
      targetDay.year,
      targetDay.month,
      targetDay.day,
      0,
      0,
      0,
    );
    final dayEnd = tz.TZDateTime(
      displayZone,
      targetDay.year,
      targetDay.month,
      targetDay.day,
      23,
      59,
      59,
      999,
    );

    // Check if the event overlaps with this target day
    if (localEnd.isBefore(dayStart) || localStart.isAfter(dayEnd)) {
      return null;
    }

    final startAngle = SectorMath.timeToDialAngle(
      localStart,
      is24HourMode: is24HourMode,
    );
    final sweepAngle = SectorMath.durationToSweepAngle(
      localEnd.difference(localStart),
      is24HourMode: is24HourMode,
    );

    return Occurrence(
      event: event,
      startLocal: localStart,
      endLocal: localEnd,
      startInstant: utcStart,
      endInstant: utcEnd,
      startAngle: startAngle,
      sweepAngle: sweepAngle,
    );
  }

  /// Projects a [FloatingTime] event (routine tied to wall-clock time).
  static Occurrence? _projectFloating({
    required SectorEvent event,
    required FloatingTime floating,
    required DateTime targetDay,
    required tz.Location displayZone,
    required bool is24HourMode,
  }) {
    // 1. Recurrence checks
    if (event.repeatDays != null && event.repeatDays!.isNotEmpty) {
      final startBoundary = DateTime(
        event.start.year,
        event.start.month,
        event.start.day,
      );
      final targetDateOnly =
          DateTime(targetDay.year, targetDay.month, targetDay.day);

      if (targetDateOnly.isBefore(startBoundary)) return null;

      if (event.recurrenceEndDate != null) {
        final endBoundary = DateTime(
          event.recurrenceEndDate!.year,
          event.recurrenceEndDate!.month,
          event.recurrenceEndDate!.day,
          23,
          59,
          59,
        );
        if (targetDateOnly.isAfter(endBoundary)) return null;
      }

      if (!event.repeatDays!.contains(targetDay.weekday)) return null;
    } else if (event.recurrenceEndDate != null) {
      final startBoundary = DateTime(
        event.start.year,
        event.start.month,
        event.start.day,
      );
      final targetDateOnly =
          DateTime(targetDay.year, targetDay.month, targetDay.day);
      final endBoundary = DateTime(
        event.recurrenceEndDate!.year,
        event.recurrenceEndDate!.month,
        event.recurrenceEndDate!.day,
        23,
        59,
        59,
      );
      if (targetDateOnly.isBefore(startBoundary) ||
          targetDateOnly.isAfter(endBoundary)) {
        return null;
      }
    } else {
      // Single-instance floating routine check
      if (event.start.year != targetDay.year ||
          event.start.month != targetDay.month ||
          event.start.day != targetDay.day) {
        return null;
      }
    }

    // 2. Resolve wall-clock start & duration
    tz.TZDateTime localStart;
    tz.TZDateTime localEnd;

    if (floating.zoneMode.isFixed && floating.zoneMode.tzid != null) {
      // Fixed zone: wall clock in fixed zone, then converted to displayZone
      try {
        final fixedLoc = tz.getLocation(floating.zoneMode.tzid!);
        final fixedStart = tz.TZDateTime(
          fixedLoc,
          targetDay.year,
          targetDay.month,
          targetDay.day,
          floating.startHour,
          floating.startMinute,
        );
        final fixedEnd =
            fixedStart.add(Duration(minutes: floating.durationMinutes));

        localStart = tz.TZDateTime.from(fixedStart.toUtc(), displayZone);
        localEnd = tz.TZDateTime.from(fixedEnd.toUtc(), displayZone);
      } catch (_) {
        // Fallback to displayZone if fixed zone is invalid
        localStart = tz.TZDateTime(
          displayZone,
          targetDay.year,
          targetDay.month,
          targetDay.day,
          floating.startHour,
          floating.startMinute,
        );
        localEnd = localStart.add(Duration(minutes: floating.durationMinutes));
      }
    } else {
      // Device mode: floats directly to the target day in displayZone
      localStart = tz.TZDateTime(
        displayZone,
        targetDay.year,
        targetDay.month,
        targetDay.day,
        floating.startHour,
        floating.startMinute,
      );
      localEnd = localStart.add(Duration(minutes: floating.durationMinutes));
    }

    final startAngle = SectorMath.timeToDialAngle(
      localStart,
      is24HourMode: is24HourMode,
    );
    final sweepAngle = SectorMath.durationToSweepAngle(
      localEnd.difference(localStart),
      is24HourMode: is24HourMode,
    );

    return Occurrence(
      event: event,
      startLocal: localStart,
      endLocal: localEnd,
      startInstant: localStart.toUtc(),
      endInstant: localEnd.toUtc(),
      startAngle: startAngle,
      sweepAngle: sweepAngle,
    );
  }

  /// Projects all events onto [targetDay] in [displayZone], de-duplicating
  /// identical slot occurrences.
  static List<Occurrence> projectAllOccurrences({
    required List<SectorEvent> events,
    required DateTime targetDay,
    required tz.Location displayZone,
    bool is24HourMode = false,
  }) {
    final occurrences = <Occurrence>[];
    for (final event in events) {
      final occ = project(
        event: event,
        targetDay: targetDay,
        displayZone: displayZone,
        is24HourMode: is24HourMode,
      );
      if (occ != null) occurrences.add(occ);
    }

    final unique = <Occurrence>[];
    final seen = <String>{};
    for (final occ in occurrences) {
      final slotKey =
          '${occ.event.title.trim().toLowerCase()}_${occ.startLocal.hour}:${occ.startLocal.minute}_${occ.endLocal.hour}:${occ.endLocal.minute}';
      if (seen.add(slotKey)) {
        unique.add(occ);
      }
    }
    return unique;
  }

  /// Convenience projection returning a list of [SectorEvent] objects for
  /// backward compatibility with the existing rendering pipeline.
  static List<SectorEvent> projectAllEvents({
    required List<SectorEvent> events,
    required DateTime targetDay,
    required tz.Location displayZone,
    bool is24HourMode = false,
  }) {
    final occurrences = projectAllOccurrences(
      events: events,
      targetDay: targetDay,
      displayZone: displayZone,
      is24HourMode: is24HourMode,
    );
    return occurrences
        .map((occ) => occ.toSectorEvent(is24HourMode: is24HourMode))
        .toList();
  }
}
