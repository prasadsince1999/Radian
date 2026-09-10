import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/core/services/health_service.dart';
import 'package:sectograph_mcp/domain/models/health_models.dart';

void main() {
  group('Health Service & Domain Models Tests', () {
    test(
      'DailyHealthSummary computes sleep debt and formatted hours correctly',
      () {
        final summaryWithDebt = DailyHealthSummary(
          date: DateTime(2026, 9, 9),
          steps: 7500,
          sleepDurationMinutes: 360, // 6h (debt = 120m)
          lastSyncTime: DateTime(2026, 9, 9, 8, 0),
        );

        expect(summaryWithDebt.sleepHours, equals(6.0));
        expect(summaryWithDebt.sleepHoursFormatted, equals('6h 0m'));
        expect(summaryWithDebt.sleepDebtMinutes(), equals(120));
        expect(summaryWithDebt.hasSignificantSleepDebt, isTrue);

        final summaryAdequate = DailyHealthSummary(
          date: DateTime(2026, 9, 9),
          steps: 10500,
          sleepDurationMinutes: 495, // 8h 15m
          lastSyncTime: DateTime(2026, 9, 9, 8, 0),
        );

        expect(summaryAdequate.sleepHoursFormatted, equals('8h 15m'));
        expect(summaryAdequate.sleepDebtMinutes(), equals(0));
        expect(summaryAdequate.hasSignificantSleepDebt, isFalse);
      },
    );

    test('HealthExerciseSession JSON roundtrip preserves metrics', () {
      final session = HealthExerciseSession(
        id: 'workout-101',
        title: 'Trail Run',
        type: 'running',
        start: DateTime(2026, 9, 9, 7, 0),
        end: DateTime(2026, 9, 9, 7, 45),
        caloriesBurned: 350.0,
        distanceMeters: 6200.0,
        sourceApp: 'Strava / Health Connect',
      );

      final json = session.toJson();
      final restored = HealthExerciseSession.fromJson(json);

      expect(restored.id, equals(session.id));
      expect(restored.title, equals(session.title));
      expect(restored.durationMinutes, equals(45));
      expect(restored.caloriesBurned, equals(350.0));
      expect(restored.distanceMeters, equals(6200.0));
      expect(restored.sourceApp, equals(session.sourceApp));
    });

    test(
      'MockHealthService starts clean and returns seeded biometrics when added',
      () async {
        final service = MockHealthService();
        expect(await service.isAvailable(), isTrue);
        expect(await service.requestPermissions(), isTrue);

        // Clean default state
        final emptySummary = await service.fetchDailySummary(DateTime.now());
        expect(emptySummary.steps, equals(0));
        expect(emptySummary.exerciseSessions, isEmpty);

        // Populating authentic data
        final today = DateTime.now();
        service.addSummary(
          DailyHealthSummary(
            date: DateTime(today.year, today.month, today.day),
            steps: 8500,
            activeCalories: 450.0,
            sleepDurationMinutes: 480,
            sleepStart: DateTime(today.year, today.month, today.day - 1, 23, 0),
            sleepEnd: DateTime(today.year, today.month, today.day, 7, 0),
            exerciseSessions: [
              HealthExerciseSession(
                id: 'sess-1',
                title: 'Morning Run',
                type: 'running',
                start: DateTime(today.year, today.month, today.day, 7, 30),
                end: DateTime(today.year, today.month, today.day, 8, 15),
                caloriesBurned: 350.0,
              ),
            ],
            lastSyncTime: today,
          ),
        );

        final summary = await service.fetchDailySummary(today);
        expect(summary.steps, equals(8500));
        expect(summary.exerciseSessions.length, equals(1));
        expect(summary.exerciseSessions.first.title, equals('Morning Run'));
      },
    );
  });
}
