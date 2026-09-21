import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_strings.dart';
import '../../core/geometry/concentric_solver.dart';
import '../../core/geometry/sector_math.dart';
import '../../core/services/reminder_notification_service.dart';
import '../../domain/models/free_gap.dart';
import '../../domain/models/sector_event.dart';
import '../../domain/repositories/event_repository.dart';
import '../datasources/sample_events_data.dart';

class LocalEventRepository implements EventRepository {
  static const _storageKey = AppStrings.eventsStorageKey;
  final SharedPreferences? prefs;
  final List<SectorEvent> _events = [];
  final _controller = StreamController<List<SectorEvent>>.broadcast();
  final _mutationController = StreamController<EventMutation>.broadcast();

  @override
  Stream<EventMutation> get mutations => _mutationController.stream;

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

      var hasEnriched = false;

      final now = DateTime.now();
      String? urlPreset;
      String? urlMode;
      if (kIsWeb) {
        try {
          final queryParams = Uri.base.queryParameters;
          urlPreset = queryParams['preset']?.toLowerCase();
          urlMode = queryParams['mode']?.toLowerCase();
        } catch (_) {}
      }

      final is24 =
          urlPreset == 'international' ||
          urlPreset == 'intl' ||
          urlMode == '24h' ||
          (prefs?.getBool('setting_is24h') ?? false);

      // Only seed default/demo schedule if repository is completely empty on true first install.
      // NEVER re-seed if the user previously deleted events.
      final hasSeeded =
          prefs?.getBool('sectograph_initial_schedule_seeded_v1') ?? false;
      if (_events.isEmpty && !hasSeeded) {
        prefs?.setBool('sectograph_initial_schedule_seeded_v1', true);
        if (kIsWeb) {
          if (is24) {
            _events.addAll(
              SampleEventsData.generateInternational24hSchedule(now),
            );
          } else {
            _events.addAll(SampleEventsData.generateIndian12hSchedule(now));
          }
        } else {
          _events.addAll(SampleEventsData.generateDefaultSchedule(now));
        }
        hasEnriched = true;
      }

      // Purge obsolete/leftover test events that cause collision or duplicate caps on device
      final initialCount = _events.length;
      _events.removeWhere(
        (e) =>
            e.id == '859ca18a-e5ff-40d6-9d94-026e309a7637' ||
            e.title.contains('Focus Coding Build UI') ||
            (e.title == 'New Block' &&
                e.notes.isEmpty &&
                e.subtasks.isEmpty &&
                e.subtaskItems.isEmpty),
      );
      if (_events.length != initialCount) {
        hasEnriched = true;
      }
      for (int i = 0; i < _events.length; i++) {
        final ev = _events[i];
        final lower = ev.title.toLowerCase();
        if (lower.contains('flexible') && ev.subtasks.isEmpty) {
          _events[i] = ev.copyWith(
            subtasks: const ['LeetCode', 'Mock Prep', 'PyTorch'],
          );
          hasEnriched = true;
        } else if (lower.contains('study') && ev.subtasks.isEmpty) {
          _events[i] = ev.copyWith(
            subtasks: const ['LinAlg', 'PyTorch', 'Transformers'],
          );
          hasEnriched = true;
        } else if (lower.contains('lunch') && ev.subtasks.isEmpty) {
          _events[i] = ev.copyWith(
            subtasks: const ['Meal Prep', 'Quick Lunch'],
          );
          hasEnriched = true;
        } else if (lower.contains('workout') && ev.subtasks.isEmpty) {
          _events[i] = ev.copyWith(
            subtasks: const ['Gym', 'Cardio', 'Stretch'],
          );
          hasEnriched = true;
        }
      }

      // Cleanup obsolete/corrupted test events and duplicate overlapping schedules:
      // Previously, test schedules from Sep 10-14 were given repeatDays which caused multiple
      // overlapping duplicate blocks (3 copies of Bed Time, duplicate New Blocks, Cooking+Dinner, etc.)
      final didCleanCorrupted =
          prefs!.getBool('sectograph_cleaned_corrupted_v3') ?? false;
      if (!didCleanCorrupted) {
        _events.removeWhere((e) {
          final t = e.title.toLowerCase();
          if (t.contains('workout or chill') ||
              t.contains('cooking+dinner') ||
              t.contains('cooking+lunch') ||
              t.contains('meeting syncx') ||
              t.contains('team standup') ||
              t.contains('deep focus session') ||
              t.contains('evening workout') ||
              e.id == '859ca18a-e5ff-40d6-9d94-026e309a7637' ||
              e.title.contains('Focus Coding Build UI')) {
            return true;
          }
          // Purge colliding throwaway test blocks created during earlier tests
          if (e.id == '041f12b2-8cca-4854-9863-fde6005420c3' ||
              e.id == '00bdd90b-f728-4c11-a13d-fa922c6edca6' ||
              e.id == '8145b44b-f29b-4ab7-a221-9d360d0aaf21' ||
              e.id == 'c4dbdec3-74b9-4f1c-9c34-13d82685a946' ||
              e.id == 'health-sleep-2026-09-15' ||
              e.id == '7c84bcab-901b-42ee-8898-d7d32e3796cd' ||
              e.id == '6e032c79-3d1c-4838-9559-fe25713017b4') {
            return true;
          }
          return false;
        });

        // Deduplicate any remaining blocks with identical title, date, and start time
        final seenSlots = <String>{};
        _events.removeWhere((e) {
          final slotKey =
              '${e.title.trim().toLowerCase()}_${e.start.year}-${e.start.month}-${e.start.day}_${e.start.hour}:${e.start.minute}';
          if (seenSlots.contains(slotKey)) {
            return true;
          }
          seenSlots.add(slotKey);
          return false;
        });

        hasEnriched = true;
        unawaited(prefs!.setBool('sectograph_cleaned_corrupted_v3', true));
      }
      if (hasEnriched) {
        unawaited(_saveToDisk());
      }
    }

    _notify();
    if (_events.isNotEmpty) {
      unawaited(
        ReminderNotificationService.syncAllReminders(
          List<SectorEvent>.from(_events),
        ),
      );
    }
  }

  /// In the concentric polar dial, overlapping events are placed on separate concentric rings
  /// by ConcentricSolver. We preserve exact user start/end times without destructive clipping.
  bool _deconflictEvents() {
    return false;
  }

  List<SectorEvent> _deconflictDayEvents(List<SectorEvent> events) {
    return events;
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
      } else if (e.recurrenceEndDate != null) {
        final startBoundary = DateTime(
          e.start.year,
          e.start.month,
          e.start.day,
        );
        final endBoundary = DateTime(
          e.recurrenceEndDate!.year,
          e.recurrenceEndDate!.month,
          e.recurrenceEndDate!.day,
          23,
          59,
          59,
        );
        if (!day.isBefore(startBoundary) && !day.isAfter(endBoundary)) {
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

    final deconflictedDayEvents = _deconflictDayEvents(dayEvents);
    final levels = ConcentricSolver.solve(deconflictedDayEvents);
    return deconflictedDayEvents.map((e) {
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
    _mutationController.add(EventMutation.upsert(event));
    if (event.reminderMinutes != null) {
      unawaited(ReminderNotificationService.scheduleReminder(event));
    }
  }

  @override
  Future<void> updateEvent(SectorEvent event) async {
    final idx = _events.indexWhere((e) => e.id == event.id);
    if (idx != -1) {
      _events[idx] = event;
    } else {
      _events.add(event);
    }
    await _saveToDisk();
    _notify();
    _mutationController.add(EventMutation.upsert(event));
    if (event.reminderMinutes != null) {
      unawaited(ReminderNotificationService.scheduleReminder(event));
    } else {
      unawaited(ReminderNotificationService.cancelReminder(event.id));
    }
  }

  @override
  Future<void> deleteEvent(String id, {bool notifyMutation = true}) async {
    _events.removeWhere((e) => e.id == id);
    await _saveToDisk();
    _notify();
    if (notifyMutation) {
      _mutationController.add(EventMutation.delete(id));
    }
    unawaited(ReminderNotificationService.cancelReminder(id));
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Future<void> bulkAddEvents(
    List<SectorEvent> events, {
    bool notifyMutations = false,
  }) async {
    for (final event in events) {
      final idx = _events.indexWhere((e) => e.id == event.id);
      if (idx != -1) {
        _events[idx] = event;
      } else {
        _events.add(event);
      }
      if (notifyMutations) {
        _mutationController.add(EventMutation.upsert(event));
      }
    }
    await _saveToDisk();
    _notify();
    unawaited(ReminderNotificationService.syncAllReminders(_events));
  }

  @override
  Future<void> replaceDayEvents(DateTime day, List<SectorEvent> events) async {
    final toDelete = _events
        .where((e) => _isSameDay(e.start, day))
        .map((e) => e.id)
        .toList();
    _events.removeWhere((e) => _isSameDay(e.start, day));
    for (final id in toDelete) {
      _mutationController.add(EventMutation.delete(id));
    }
    _events.addAll(events);
    for (final event in events) {
      _mutationController.add(EventMutation.upsert(event));
    }
    await _saveToDisk();
    _notify();
    unawaited(ReminderNotificationService.syncAllReminders(_events));
  }

  @override
  Future<void> clearEventsForDay(DateTime day) async {
    final removed = _events.where((e) => _isSameDay(e.start, day)).toList();
    _events.removeWhere((e) => _isSameDay(e.start, day));
    for (final e in removed) {
      _mutationController.add(EventMutation.delete(e.id));
      unawaited(ReminderNotificationService.cancelReminder(e.id));
    }
    await _saveToDisk();
    _notify();
  }

  @override
  Future<void> clearAllEvents() async {
    _events.clear();
    await _saveToDisk();
    _notify();
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

  @override
  Future<void> loadPreset(String preset) async {
    final now = DateTime.now();
    final newEvents = preset == 'international_24h'
        ? SampleEventsData.generateInternational24hSchedule(now)
        : SampleEventsData.generateIndian12hSchedule(now);
    _events.clear();
    _events.addAll(newEvents);
    _deconflictEvents();
    await _saveToDisk();
    _notify();
  }
}
