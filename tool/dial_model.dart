import 'dart:convert';
import 'dart:io';

import 'package:sectograph_mcp/core/time/zone_clock.dart';
import 'package:sectograph_mcp/engine/dial_input.dart';
import 'package:sectograph_mcp/engine/dial_model_builder.dart';

void main(List<String> args) {
  ensureTimeZonesInitialized();
  final clock = ZoneClock.fixedZone(tzid: 'Asia/Kolkata');
  final snapshot = clock.snapshot();
  final now = snapshot.localNow;

  List<Occurrence> occurrences;

  if (args.isNotEmpty && File(args.first).existsSync()) {
    final content = File(args.first).readAsStringSync();
    final jsonList = jsonDecode(content) as List<dynamic>;
    occurrences = jsonList.map((j) {
      final map = j as Map<String, dynamic>;
      return Occurrence(
        id: map['id'] as String? ?? 'ev-1',
        eventId: map['eventId'] as String? ?? (map['id'] as String? ?? 'ev-1'),
        title: map['title'] as String? ?? 'Untitled',
        start: DateTime.parse(map['start'] as String),
        end: DateTime.parse(map['end'] as String),
        colorHex: map['colorHex'] as String? ?? '#6366F1',
        category: map['category'] as String? ?? 'General',
        subtasks: (map['subtasks'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );
    }).toList();
  } else {
    // Generate canonical default day fixture around now
    final today = DateTime(now.year, now.month, now.day);
    occurrences = [
      Occurrence(
        id: 'ev-sleep',
        eventId: 'sleep',
        title: 'Sleep & Recovery',
        start: today.add(const Duration(hours: 0)),
        end: today.add(const Duration(hours: 7)),
        colorHex: '#6366F1',
        category: 'Health',
      ),
      Occurrence(
        id: 'ev-morning',
        eventId: 'morning',
        title: 'Morning Routine & Yoga',
        start: today.add(const Duration(hours: 7, minutes: 15)),
        end: today.add(const Duration(hours: 8, minutes: 30)),
        colorHex: '#10B981',
        category: 'Fitness',
        subtasks: const ['Hydrate', 'Sun Salutation', 'Meditation'],
      ),
      Occurrence(
        id: 'ev-deepwork',
        eventId: 'deepwork',
        title: 'Deep Focus Coding',
        start: today.add(const Duration(hours: 9, minutes: 30)),
        end: today.add(const Duration(hours: 12, minutes: 30)),
        colorHex: '#3B82F6',
        category: 'Work',
        subtasks: const ['Dial Engine Core', 'Warp Solver', 'Parity Tests'],
      ),
      Occurrence(
        id: 'ev-lunch',
        eventId: 'lunch',
        title: 'Healthy Lunch & Walk',
        start: today.add(const Duration(hours: 13, minutes: 0)),
        end: today.add(const Duration(hours: 14, minutes: 0)),
        colorHex: '#F59E0B',
        category: 'Health',
      ),
      Occurrence(
        id: 'ev-meeting',
        eventId: 'meeting',
        title: 'Sprint Demo & Architecture',
        start: today.add(const Duration(hours: 15, minutes: 0)),
        end: today.add(const Duration(hours: 16, minutes: 30)),
        colorHex: '#EC4899',
        category: 'Meetings',
      ),
      Occurrence(
        id: 'ev-dinner',
        eventId: 'dinner',
        title: 'Family Dinner',
        start: today.add(const Duration(hours: 19, minutes: 0)),
        end: today.add(const Duration(hours: 20, minutes: 30)),
        colorHex: '#8B5CF6',
        category: 'Personal',
      ),
    ];
  }

  final input = DialInput(
    clock: snapshot,
    occurrences: occurrences,
    prefs: const DialPrefs(
      is24HourMode: false,
      previousBlocksCount: 1,
      futureBlocksCount: 3,
      isFocusLensEnabled: true,
      lensMagnification: 1.8,
    ),
    window: DialWindowMode.rolling,
    focus: const DialFocus.none(),
    surface: const DialSurface(type: DialSurfaceType.app, size: 360.0),
  );

  final model = DialModelBuilder.build(input);
  final encoder = const JsonEncoder.withIndent('  ');
  stdout.writeln(encoder.convert(model.toJson()));
}
