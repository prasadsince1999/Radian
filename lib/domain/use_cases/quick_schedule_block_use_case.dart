import '../models/sector_event.dart';
import '../repositories/event_repository.dart';

/// Pure domain Use Case for scheduling quick time blocks (Focus, Nap, Workout, Event).
class QuickScheduleBlockUseCase {
  final EventRepository eventRepository;
  final DateTime Function() _nowProvider;

  QuickScheduleBlockUseCase({
    required this.eventRepository,
    DateTime Function()? nowProvider,
  }) : _nowProvider = nowProvider ?? DateTime.now;

  Future<SectorEvent> execute({
    required String title,
    required Duration duration,
    required String colorHex,
    String notes = '',
    String? iconName,
  }) async {
    final now = _nowProvider();
    final event = SectorEvent(
      id: 'quick_${now.millisecondsSinceEpoch}',
      title: title,
      start: now,
      end: now.add(duration),
      colorHex: colorHex,
      notes: notes,
      iconName: iconName,
    );

    await eventRepository.addEvent(event);
    return event;
  }
}
