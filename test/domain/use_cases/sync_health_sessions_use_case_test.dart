import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/domain/models/health_models.dart';
import 'package:sectograph_mcp/domain/use_cases/sync_health_sessions_use_case.dart';

import '../../mocks/fake_event_repository.dart';

void main() {
  group('SyncHealthSessionsUseCase Tests', () {
    late FakeEventRepository repository;
    final testDate = DateTime(2026, 9, 9);

    setUp(() {
      repository = FakeEventRepository();
    });

    test('syncs authentic sleep and exercise sessions onto dial', () async {
      final useCase = SyncHealthSessionsUseCase(eventRepository: repository);

      final health = DailyHealthSummary(
        date: testDate,
        steps: 6200,
        sleepDurationMinutes: 450,
        sleepStart: DateTime(2026, 9, 8, 23, 0),
        sleepEnd: DateTime(2026, 9, 9, 6, 30),
        lastSyncTime: DateTime(2026, 9, 9, 8, 0),
        exerciseSessions: [
          HealthExerciseSession(
            id: 'run-101',
            title: 'Morning 5K',
            type: 'running',
            start: DateTime(2026, 9, 9, 7, 0),
            end: DateTime(2026, 9, 9, 7, 35),
            caloriesBurned: 320.0,
            distanceMeters: 5000.0,
            sourceApp: 'Health Connect',
          ),
        ],
      );

      final synced = await useCase.execute(
        health: health,
        existingEvents: const [],
      );

      expect(synced.length, equals(2)); // 1 sleep + 1 workout
      expect(synced.any((e) => e.title == 'Sleep'), isTrue);
      expect(synced.any((e) => e.title == 'Morning 5K'), isTrue);

      final persisted = await repository.getAllEvents();
      expect(persisted.length, equals(2));
    });

    test('does not duplicate already synced health sessions', () async {
      final useCase = SyncHealthSessionsUseCase(eventRepository: repository);

      final health = DailyHealthSummary(
        date: testDate,
        sleepDurationMinutes: 420,
        sleepStart: DateTime(2026, 9, 8, 23, 30),
        sleepEnd: DateTime(2026, 9, 9, 6, 30),
        lastSyncTime: DateTime(2026, 9, 9, 8, 0),
        exerciseSessions: const [],
      );

      final firstSync = await useCase.execute(
        health: health,
        existingEvents: const [],
      );
      expect(firstSync.length, equals(1));

      final secondSync = await useCase.execute(
        health: health,
        existingEvents: firstSync,
      );
      expect(secondSync, isEmpty);

      final persisted = await repository.getAllEvents();
      expect(persisted.length, equals(1));
    });
  });
}
