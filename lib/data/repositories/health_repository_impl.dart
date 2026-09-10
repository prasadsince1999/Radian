import '../../core/services/health_service.dart';
import '../../domain/models/health_models.dart';
import '../../domain/repositories/health_repository.dart';

/// Implementation of [HealthRepository] consuming low-level [IHealthService].
class HealthRepositoryImpl implements HealthRepository {
  final IHealthService service;

  HealthRepositoryImpl({required this.service});

  @override
  Future<bool> isAvailable() => service.isAvailable();

  @override
  Future<bool> requestPermissions() => service.requestPermissions();

  @override
  Future<DailyHealthSummary> getDailySummary(DateTime date) =>
      service.fetchDailySummary(date);

  @override
  Future<List<HealthExerciseSession>> getExerciseSessions(DateTime date) =>
      service.fetchExerciseSessions(date);
}
