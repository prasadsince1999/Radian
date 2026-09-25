import '../models/sector_event.dart';

/// Projects stored blocks onto one calendar day.
///
/// - [SectorEvent.repeatDays] set: routine, shown on those weekdays
///   after the stored start date (and before [SectorEvent.recurrenceEndDate]).
/// - [SectorEvent.recurrenceEndDate] only: shown each day in that window.
/// - Otherwise: once, shown only on the stored calendar day.
class EventDayProjector {
  const EventDayProjector._();

  static const dailyWeekdays = [1, 2, 3, 4, 5, 6, 7];

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static SectorEvent? project(SectorEvent event, DateTime day) {
    final target = DateTime(day.year, day.month, day.day);

    if (event.repeatDays != null && event.repeatDays!.isNotEmpty) {
      final startBoundary = DateTime(
        event.start.year,
        event.start.month,
        event.start.day,
      );
      if (target.isBefore(startBoundary)) return null;
      if (event.recurrenceEndDate != null) {
        final endBoundary = DateTime(
          event.recurrenceEndDate!.year,
          event.recurrenceEndDate!.month,
          event.recurrenceEndDate!.day,
          23,
          59,
          59,
        );
        if (target.isAfter(endBoundary)) return null;
      }
      if (!event.repeatDays!.contains(target.weekday)) return null;
      final projStart = DateTime(
        target.year,
        target.month,
        target.day,
        event.start.hour,
        event.start.minute,
      );
      return event.copyWith(
        start: projStart,
        end: projStart.add(event.duration),
      );
    }

    if (event.recurrenceEndDate != null) {
      final startBoundary = DateTime(
        event.start.year,
        event.start.month,
        event.start.day,
      );
      final endBoundary = DateTime(
        event.recurrenceEndDate!.year,
        event.recurrenceEndDate!.month,
        event.recurrenceEndDate!.day,
        23,
        59,
        59,
      );
      if (target.isBefore(startBoundary) || target.isAfter(endBoundary)) {
        return null;
      }
      final projStart = DateTime(
        target.year,
        target.month,
        target.day,
        event.start.hour,
        event.start.minute,
      );
      return event.copyWith(
        start: projStart,
        end: projStart.add(event.duration),
      );
    }

    if (!isSameDay(event.start, target)) return null;
    return event;
  }

  static List<SectorEvent> projectAll(List<SectorEvent> events, DateTime day) {
    final projected = <SectorEvent>[];
    for (final event in events) {
      final item = project(event, day);
      if (item != null) projected.add(item);
    }

    final unique = <SectorEvent>[];
    final seen = <String>{};
    for (final ev in projected) {
      final slotKey =
          '${ev.title.trim().toLowerCase()}_${ev.start.hour}:${ev.start.minute}_${ev.end.hour}:${ev.end.minute}';
      if (seen.add(slotKey)) unique.add(ev);
    }
    return unique;
  }
}
