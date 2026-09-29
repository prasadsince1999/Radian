import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sectograph_mcp/core/constants/app_strings.dart';
import 'package:sectograph_mcp/core/time/time_spec.dart';
import 'package:sectograph_mcp/data/repositories/local_event_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 1 Legacy Data Migration Tests', () {
    test('Migrates 200 legacy events, sets assumedZone, backs up to v1_0_24, handles midnight crossing', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // 1. Generate 200 legacy events with offset-less ISO strings
      final legacyEvents = <Map<String, dynamic>>[];

      for (int i = 0; i < 199; i++) {
        final hour = i % 24;
        final minute = (i * 7) % 60;
        final isRoutine = i % 3 == 0;

        legacyEvents.add({
          'id': 'legacy-event-$i',
          'title': 'Legacy Block $i',
          // Deliberately offset-less ISO-8601 string as stored in v1.0.24
          'start': '2026-09-29T${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00.000',
          'end': '2026-09-29T${((hour + 1) % 24).toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00.000',
          'category': 'Work',
          'colorHex': '#3B82F6',
          'notes': 'Legacy block note $i',
          'isAllDay': false,
          'repeatDays': isRoutine ? [1, 2, 3, 4, 5] : null,
          'subtasks': ['Subtask A for $i', 'Subtask B for $i'],
        });
      }

      // Event 200: Midnight crossing event (23:15 to 01:45 next day)
      legacyEvents.add({
        'id': 'midnight-crosser-200',
        'title': 'Nocturnal Deep Flow',
        'start': '2026-09-29T23:15:00.000',
        'end': '2026-09-30T01:45:00.000',
        'category': 'Focus',
        'colorHex': '#8B5CF6',
        'notes': 'Crosses midnight',
        'isAllDay': false,
        'repeatDays': null,
        'subtasks': ['Deep coding', 'Commit & shutdown'],
      });

      expect(legacyEvents.length, 200);

      final legacyJson = jsonEncode(legacyEvents);
      await prefs.setString(AppStrings.eventsStorageKey, legacyJson);
      await prefs.setBool('sectograph_stamped_daily_repeat_v1', true);

      // Verify initial state: schema version not set yet
      expect(prefs.getInt(LocalEventRepository.schemaVersionKey), isNull);
      expect(prefs.getString(LocalEventRepository.migrationBackupKey), isNull);

      // 2. Initialize LocalEventRepository to trigger migration
      final repo = LocalEventRepository(prefs: prefs);

      // 3. Verify migration assertions
      // A: Backup was saved with exact legacy data
      final backup = prefs.getString(LocalEventRepository.migrationBackupKey);
      expect(backup, isNotNull);
      expect(backup, legacyJson);

      // B: Schema version is now 2
      expect(
        prefs.getInt(LocalEventRepository.schemaVersionKey),
        LocalEventRepository.currentSchemaVersion,
      );

      // C: All 200 events loaded
      final loadedEvents = await repo.getAllEvents();
      expect(loadedEvents.length, 200);

      // D: Legacy events without offset have assumedZone = true
      final sample = loadedEvents.first;
      expect(sample.assumedZone, true);

      // E: Midnight crossing event preserved accurately
      final midnightEvent = loadedEvents.firstWhere(
        (e) => e.id == 'midnight-crosser-200',
      );
      expect(midnightEvent.title, 'Nocturnal Deep Flow');
      expect(midnightEvent.start.hour, 23);
      expect(midnightEvent.start.minute, 15);
      expect(midnightEvent.end.hour, 1);
      expect(midnightEvent.end.minute, 45);
      expect(midnightEvent.duration, const Duration(hours: 2, minutes: 30));
      expect(midnightEvent.assumedZone, true);
      expect(midnightEvent.effectiveTimeSpec, isA<InstantTime>());

      // F: Routine events have FloatingTime effectiveTimeSpec
      final routineEvent = loadedEvents.firstWhere(
        (e) => e.repeatDays != null && e.repeatDays!.isNotEmpty,
      );
      expect(routineEvent.effectiveTimeSpec, isA<FloatingTime>());
      final floating = routineEvent.effectiveTimeSpec as FloatingTime;
      expect(floating.assumedZone, true);
    });
  });
}
