import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_strings.dart';
import '../../core/geometry/concentric_solver.dart';
import '../../core/geometry/sector_math.dart';
import '../../core/services/reminder_notification_service.dart';
import '../../domain/models/free_gap.dart';
import '../../domain/models/sector_event.dart';
import '../../domain/repositories/event_repository.dart';

class LocalEventRepository implements EventRepository {
  static const _storageKey = AppStrings.eventsStorageKey;
  final SharedPreferences? prefs;
  final List<SectorEvent> _events = [];
  final _controller = StreamController<List<SectorEvent>>.broadcast();

  LocalEventRepository({this.prefs}) {
    _init();
  }

  void _init() {
    if (prefs != null) {
      prefs!.remove('sectograph_events_v1');
      prefs!.remove('sectograph_events_v2');
      prefs!.remove('sectograph_events_v3');
      prefs!.remove('sectograph_events_v4');
      final raw = prefs!.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        try {
          final List<dynamic> decoded = jsonDecode(raw);
          _events.addAll(
            decoded.map((e) => SectorEvent.fromJson(e as Map<String, dynamic>)),
          );
        } catch (_) {
          // fallback to sample
        }
      }
    }

    _notify();
    if (_events.isNotEmpty) {
      unawaited(ReminderNotificationService.syncAllReminders(_events));
    }
  }

  Future<void> _saveToDisk() async {
    if (prefs != null) {
      final encoded = jsonEncode(_events.map((e) => e.toJson()).toList());
      await prefs!.setString(_storageKey, encoded);
    }
  }

  void _notify() {
    _controller.add(List.unmodifiable(_events));
  }

  List<SectorEvent> _filterAndProjectForDay(
    List<SectorEvent> events,
    DateTime day,
  ) {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = DateTime(day.year, day.month, day.day + 1);

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

    final levels = ConcentricSolver.solve(dayEvents);
    return dayEvents.map((e) {
      final solved = levels[e];
      if (solved != null) {
        return e.copyWith(
          topLevel: solved.topLevel,
          bottomLevel: solved.bottomLevel,
        );
      }
      return e;
    }).toList();
  }

  @override
  Stream<List<SectorEvent>> watchEventsForDay(DateTime day) async* {
    yield await getEventsForDay(day);
    yield* _controller.stream.map((list) => _filterAndProjectForDay(list, day));
  }

  @override
  Future<List<SectorEvent>> getEventsForDay(DateTime day) async {
    return _filterAndProjectForDay(_events, day);
  }

  @override
  Stream<List<SectorEvent>> watchAllEvents() async* {
    yield List.unmodifiable(_events);
    yield* _controller.stream.map((list) => List.unmodifiable(list));
  }

  @override
  Future<List<SectorEvent>> getAllEvents() async {
    return List.unmodifiable(_events);
  }

  @override
  Future<void> addEvent(SectorEvent event) async {
    _events.add(event);
    await _saveToDisk();
    _notify();
    if (event.reminderMinutes != null) {
      unawaited(ReminderNotificationService.scheduleReminder(event));
    }
  }

  @override
  Future<void> updateEvent(SectorEvent event) async {
    final idx = _events.indexWhere((e) => e.id == event.id);
    if (idx != -1) {
      _events[idx] = event;
      await _saveToDisk();
      _notify();
      if (event.reminderMinutes != null) {
        unawaited(ReminderNotificationService.scheduleReminder(event));
      } else {
        unawaited(ReminderNotificationService.cancelReminder(event.id));
      }
    }
  }

  @override
  Future<void> deleteEvent(String id) async {
    _events.removeWhere((e) => e.id == id);
    await _saveToDisk();
    _notify();
    unawaited(ReminderNotificationService.cancelReminder(id));
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Future<void> bulkAddEvents(List<SectorEvent> events) async {
    for (final event in events) {
      final idx = _events.indexWhere((e) => e.id == event.id);
      if (idx != -1) {
        _events[idx] = event;
      } else {
        _events.add(event);
      }
    }
    await _saveToDisk();
    _notify();
    unawaited(ReminderNotificationService.syncAllReminders(_events));
  }

  @override
  Future<void> replaceDayEvents(DateTime day, List<SectorEvent> events) async {
    _events.removeWhere((e) => _isSameDay(e.start, day));
    _events.addAll(events);
    await _saveToDisk();
    _notify();
    unawaited(ReminderNotificationService.syncAllReminders(_events));
  }

  @override
  Future<void> clearEventsForDay(DateTime day) async {
    final removed = _events.where((e) => _isSameDay(e.start, day)).toList();
    _events.removeWhere((e) => _isSameDay(e.start, day));
    await _saveToDisk();
    _notify();
    for (final e in removed) {
      unawaited(ReminderNotificationService.cancelReminder(e.id));
    }
  }

  @override
  Future<List<FreeGap>> findFreeGaps({
    required DateTime day,
    required bool is24HourMode,
    Duration minDuration = const Duration(minutes: 15),
  }) async {
    final dayEvents = await getEventsForDay(day);
    final regularEvents = dayEvents.where((e) => !e.isAllDay).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    final dayStart = DateTime(day.year, day.month, day.day, 0, 0);
    final dayEnd = dayStart.add(const Duration(hours: 24));

    final gaps = <FreeGap>[];
    var cursor = dayStart;

    for (final event in regularEvents) {
      if (event.start.isAfter(cursor)) {
        final gapDuration = event.start.difference(cursor);
        if (gapDuration >= minDuration) {
          gaps.add(
            FreeGap(
              start: cursor,
              end: event.start,
              duration: gapDuration,
              startAngle: SectorMath.timeToDialAngle(
                cursor,
                is24HourMode: is24HourMode,
              ),
              sweepAngle: SectorMath.durationToSweepAngle(
                gapDuration,
                is24HourMode: is24HourMode,
                clampMinAngle: false,
              ),
            ),
          );
        }
      }
      if (event.end.isAfter(cursor)) {
        cursor = event.end;
      }
    }

    if (dayEnd.isAfter(cursor)) {
      final gapDuration = dayEnd.difference(cursor);
      if (gapDuration >= minDuration) {
        gaps.add(
          FreeGap(
            start: cursor,
            end: dayEnd,
            duration: gapDuration,
            startAngle: SectorMath.timeToDialAngle(
              cursor,
              is24HourMode: is24HourMode,
            ),
            sweepAngle: SectorMath.durationToSweepAngle(
              gapDuration,
              is24HourMode: is24HourMode,
              clampMinAngle: false,
            ),
          ),
        );
      }
    }

    return gaps;
  }
}
