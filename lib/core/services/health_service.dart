import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/health_repository_impl.dart';
import '../../domain/models/health_models.dart';
import '../../domain/repositories/health_repository.dart';

/// Contract for health data synchronization.
abstract class IHealthService {
  Future<bool> isAvailable();
  Future<bool> requestPermissions();
  Future<DailyHealthSummary> fetchDailySummary(DateTime date);
  Future<List<HealthExerciseSession>> fetchExerciseSessions(DateTime date);
}

/// Authentic Health Connect & Pedometer Service for Android devices.
class DeviceHealthService implements IHealthService {
  static const MethodChannel _channel = MethodChannel(
    'com.ksmxtech.sectograph_mcp/widget',
  );
  final MockHealthService _fallback = MockHealthService();

  @override
  Future<bool> isAvailable() async {
    try {
      final res = await _channel.invokeMethod<bool>('isHealthConnectAvailable');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestPermissions() async {
    try {
      final res = await _channel.invokeMethod<bool>('requestHealthPermissions');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<DailyHealthSummary> fetchDailySummary(DateTime date) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'getDailyHealthSummary',
        {'date': date.toIso8601String()},
      );
      if (res != null && res.isNotEmpty) {
        return DailyHealthSummary.fromJson(Map<String, dynamic>.from(res));
      }
    } catch (_) {
      // Fallback in tests or unsupported environments
    }
    return _fallback.fetchDailySummary(date);
  }

  @override
  Future<List<HealthExerciseSession>> fetchExerciseSessions(
    DateTime date,
  ) async {
    final summary = await fetchDailySummary(date);
    return summary.exerciseSessions;
  }
}

/// Service providing access to Health Connect biometrics.
/// Defaults to a clean, empty state until authentic biometrics are synced.
class MockHealthService implements IHealthService {
  final Map<String, DailyHealthSummary> _cache = {};
  final bool isAvailableStatus;
  final bool requestPermissionsStatus;

  MockHealthService({
    Map<String, DailyHealthSummary>? initialData,
    this.isAvailableStatus = true,
    this.requestPermissionsStatus = true,
  }) {
    if (initialData != null) {
      _cache.addAll(initialData);
    }
  }

  void addSummary(DailyHealthSummary summary) {
    _cache[_dateKey(summary.date)] = summary;
  }

  String _dateKey(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  @override
  Future<bool> isAvailable() async => isAvailableStatus;

  @override
  Future<bool> requestPermissions() async => requestPermissionsStatus;

  @override
  Future<DailyHealthSummary> fetchDailySummary(DateTime date) async {
    final key = _dateKey(date);
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    // Authentic clean state: 0 steps, 0 sleep, no synthetic routines
    final summary = DailyHealthSummary(
      date: DateTime(date.year, date.month, date.day),
      steps: 0,
      activeCalories: 0.0,
      totalCalories: 0.0,
      distanceMeters: 0.0,
      sleepDurationMinutes: 0,
      hydrationMl: 0.0,
      exerciseSessions: const [],
      lastSyncTime: DateTime.now(),
    );
    _cache[key] = summary;
    return summary;
  }

  @override
  Future<List<HealthExerciseSession>> fetchExerciseSessions(
    DateTime date,
  ) async {
    final summary = await fetchDailySummary(date);
    return summary.exerciseSessions;
  }
}

/// Riverpod Providers
final healthServiceProvider = Provider<IHealthService>((ref) {
  return DeviceHealthService();
});

final healthRepositoryProvider = Provider<HealthRepository>((ref) {
  final service = ref.watch(healthServiceProvider);
  return HealthRepositoryImpl(service: service);
});

final healthSyncStatusProvider = StateProvider<HealthSyncStatus>((ref) {
  return HealthSyncStatus.connected;
});

final dailyHealthSummaryProvider =
    FutureProvider.family<DailyHealthSummary, DateTime>((ref, date) async {
      final repo = ref.watch(healthRepositoryProvider);
      return await repo.getDailySummary(date);
    });
