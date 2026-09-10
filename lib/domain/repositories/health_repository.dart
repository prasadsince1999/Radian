import '../models/health_models.dart';

/// Clean domain abstraction for health data operations.
abstract class HealthRepository {
  Future<bool> isAvailable();
  Future<bool> requestPermissions();
  Future<DailyHealthSummary> getDailySummary(DateTime date);
  Future<List<HealthExerciseSession>> getExerciseSessions(DateTime date);
}
