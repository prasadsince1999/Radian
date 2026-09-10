import 'dart:async';

import 'package:sectograph_mcp/core/geometry/sector_math.dart';
import 'package:sectograph_mcp/domain/models/free_gap.dart';
import 'package:sectograph_mcp/domain/models/sector_event.dart';
import 'package:sectograph_mcp/domain/repositories/event_repository.dart';

/// In-memory fake repository for deterministic widget testing without native SQLite.
class FakeEventRepository implements EventRepository {
  final List<SectorEvent> _events;
  final StreamController<List<SectorEvent>> _controller =
      StreamController<List<SectorEvent>>.broadcast();

  FakeEventRepository([List<SectorEvent>? initialEvents])
    : _events = List<SectorEvent>.from(initialEvents ?? []);

  void _notify() {
    _controller.add(List<SectorEvent>.unmodifiable(_events));
  }

  List<SectorEvent> _filterAndProjectForDay(
    List<SectorEvent> events,
    DateTime day,
  ) {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final dayEvents = <SectorEvent>[];
    for (final e in events) {
      if (e.repeatDays != null && e.repeatDays!.isNotEmpty) {
        final startBoundary = DateTime(
          e.start.year,
          e.start.month,
          e.start.day,
        );
        if (day.isBefore(startBoundary)) continue;
        if (e.recurrenceEndDate != null) {
          final endBoundary = DateTime(
            e.recurrenceEndDate!.year,
            e.recurrenceEndDate!.month,
            e.recurrenceEndDate!.day,
            23,
            59,
            59,
          );
          if (day.isAfter(endBoundary)) continue;
        }
        if (e.repeatDays!.contains(day.weekday)) {
          final projStart = DateTime(
            day.year,
            day.month,
            day.day,
            e.start.hour,
            e.start.minute,
          );
          dayEvents.add(
            e.copyWith(start: projStart, end: projStart.add(e.duration)),
          );
        }
      } else {
        if (e.start.isBefore(endOfDay) && e.end.isAfter(startOfDay)) {
          dayEvents.add(e);
        }
      }
    }
    return dayEvents;
  }

  @override
  Stream<List<SectorEvent>> watchEventsForDay(DateTime day) {
    return _controller.stream.map((list) => _filterAndProjectForDay(list, day));
  }

  @override
  Future<List<SectorEvent>> getEventsForDay(DateTime day) async {
    return _filterAndProjectForDay(_events, day);
  }

  @override
  Stream<List<SectorEvent>> watchAllEvents() {
    return _controller.stream;
  }

  @override
  Future<List<SectorEvent>> getAllEvents() async {
    return List<SectorEvent>.unmodifiable(_events);
  }

  @override
  Future<void> addEvent(SectorEvent event) async {
    _events.add(event);
    _notify();
  }

  @override
  Future<void> updateEvent(SectorEvent event) async {
    final idx = _events.indexWhere((e) => e.id == event.id);
    if (idx != -1) {
      _events[idx] = event;
      _notify();
    }
  }

  @override
  Future<void> deleteEvent(String id) async {
    _events.removeWhere((e) => e.id == id);
    _notify();
  }

  @override
  Future<void> bulkAddEvents(List<SectorEvent> events) async {
    _events.addAll(events);
    _notify();
  }

  @override
  Future<void> replaceDayEvents(DateTime day, List<SectorEvent> events) async {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    _events.removeWhere(
      (e) => e.start.isBefore(endOfDay) && e.end.isAfter(startOfDay),
    );
    _events.addAll(events);
    _notify();
  }

  @override
  Future<void> clearEventsForDay(DateTime day) async {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    _events.removeWhere(
      (e) => e.start.isBefore(endOfDay) && e.end.isAfter(startOfDay),
    );
    _notify();
  }

  @override
  Future<List<FreeGap>> findFreeGaps({
    required DateTime day,
    required bool is24HourMode,
    Duration minDuration = const Duration(minutes: 15),
  }) async {
    final dayEvents = await getEventsForDay(day);
    final spanHours = is24HourMode ? 24 : 12;
    final dialStart = DateTime(day.year, day.month, day.day, 0, 0);
    final dialEnd = dialStart.add(Duration(hours: spanHours));

    var cursor = dialStart;
    final sorted = List<SectorEvent>.from(dayEvents)
      ..sort((a, b) => a.start.compareTo(b.start));
    final gaps = <FreeGap>[];

    for (final ev in sorted) {
      if (ev.start.isAfter(cursor)) {
        final gapDuration = ev.start.difference(cursor);
        if (gapDuration >= minDuration) {
          final startAngle = SectorMath.timeToDialAngle(
            cursor,
            is24HourMode: is24HourMode,
          );
          final sweep = SectorMath.durationToSweepAngle(
            gapDuration,
            is24HourMode: is24HourMode,
          );
          gaps.add(
            FreeGap(
              start: cursor,
              end: ev.start,
              duration: gapDuration,
              startAngle: startAngle,
              sweepAngle: sweep,
            ),
          );
        }
      }
      if (ev.end.isAfter(cursor)) {
        cursor = ev.end;
      }
    }

    if (cursor.isBefore(dialEnd)) {
      final gapDuration = dialEnd.difference(cursor);
      if (gapDuration >= minDuration) {
        final startAngle = SectorMath.timeToDialAngle(
          cursor,
          is24HourMode: is24HourMode,
        );
        final sweep = SectorMath.durationToSweepAngle(
          gapDuration,
          is24HourMode: is24HourMode,
        );
        gaps.add(
          FreeGap(
            start: cursor,
            end: dialEnd,
            duration: gapDuration,
            startAngle: startAngle,
            sweepAngle: sweep,
          ),
        );
      }
    }

    return gaps;
  }
}
