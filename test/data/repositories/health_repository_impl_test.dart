import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/core/services/health_service.dart';
import 'package:sectograph_mcp/data/repositories/health_repository_impl.dart';
import 'package:sectograph_mcp/domain/models/health_models.dart';

void main() {
  group('HealthRepositoryImpl Tests', () {
    late MockHealthService mockService;
    late HealthRepositoryImpl repository;

    setUp(() {
      mockService = MockHealthService();
      final today = DateTime.now();
      mockService.addSummary(
        DailyHealthSummary(
          date: DateTime(today.year, today.month, today.day),
          steps: 8420,
          sleepDurationMinutes: 440,
          exerciseSessions: [
            HealthExerciseSession(
              id: 'sess-1',
              title: 'Morning Run',
              type: 'running',
              start: DateTime(today.year, today.month, today.day, 7, 0),
              end: DateTime(today.year, today.month, today.day, 7, 45),
              caloriesBurned: 350.0,
            ),
          ],
          lastSyncTime: today,
        ),
      );
      repository = HealthRepositoryImpl(service: mockService);
    });

    test('isAvailable queries underlying service', () async {
      final available = await repository.isAvailable();
      expect(available, isTrue);
    });

    test('requestPermissions queries underlying service', () async {
      final granted = await repository.requestPermissions();
      expect(granted, isTrue);
    });

    test('getDailySummary fetches and returns daily biometrics', () async {
      final today = DateTime.now();
      final summary = await repository.getDailySummary(today);

      expect(summary.steps, greaterThan(0));
      expect(summary.sleepDurationMinutes, greaterThan(0));
      expect(summary.exerciseSessions.length, equals(1));
    });

    test('getExerciseSessions returns logged workouts for the day', () async {
      final today = DateTime.now();
      final sessions = await repository.getExerciseSessions(today);

      expect(sessions.isNotEmpty, isTrue);
      expect(sessions.first.title, contains('Run'));
      expect(sessions.first.caloriesBurned, greaterThan(0));
    });
  });
}
