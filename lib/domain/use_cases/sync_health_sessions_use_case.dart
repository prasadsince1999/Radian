import '../models/health_models.dart';
import '../models/sector_event.dart';
import '../repositories/event_repository.dart';

/// Pure domain Use Case for syncing actual logged workouts and sleep sessions
/// from Health Connect directly onto the Sectograph dial.
class SyncHealthSessionsUseCase {
  final EventRepository eventRepository;

  SyncHealthSessionsUseCase({required this.eventRepository});

  Future<List<SectorEvent>> execute({
    required DailyHealthSummary health,
    required List<SectorEvent> existingEvents,
  }) async {
    final newEvents = <SectorEvent>[];

    // 1. Sync actual sleep session if logged
    if (health.sleepStart != null && health.sleepEnd != null) {
      final sleepId =
          'health-sleep-${health.date.toIso8601String().substring(0, 10)}';
      final alreadyExists = existingEvents.any((e) => e.id == sleepId);
      if (!alreadyExists) {
        newEvents.add(
          SectorEvent(
            id: sleepId,
            title: 'Sleep',
            start: health.sleepStart!,
            end: health.sleepEnd!,
            colorHex: '#4A3B69',
            iconName: 'bedtime',
            notes: 'Logged from Health Connect (${health.sleepHoursFormatted})',
          ),
        );
      }
    }

    // 2. Sync actual exercise sessions
    for (final session in health.exerciseSessions) {
      final workoutId = 'health-workout-${session.id}';
      final alreadyExists = existingEvents.any((e) => e.id == workoutId);
      if (!alreadyExists) {
        newEvents.add(
          SectorEvent(
            id: workoutId,
            title: session.title,
            start: session.start,
            end: session.end,
            colorHex: '#D97706',
            iconName: 'fitness_center',
            notes:
                'Workout: ${session.caloriesBurned.toInt()} kcal via ${session.sourceApp}',
          ),
        );
      }
    }

    for (final event in newEvents) {
      await eventRepository.addEvent(event);
    }

    return newEvents;
  }
}
