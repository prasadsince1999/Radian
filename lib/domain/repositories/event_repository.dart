import '../models/free_gap.dart';
import '../models/sector_event.dart';

abstract class EventRepository {
  Stream<List<SectorEvent>> watchEventsForDay(DateTime day);
  Future<List<SectorEvent>> getEventsForDay(DateTime day);
  Stream<List<SectorEvent>> watchAllEvents();
  Future<List<SectorEvent>> getAllEvents();
  Future<void> addEvent(SectorEvent event);
  Future<void> updateEvent(SectorEvent event);
  Future<void> deleteEvent(String id);
  Future<void> bulkAddEvents(List<SectorEvent> events);
  Future<void> replaceDayEvents(DateTime day, List<SectorEvent> events);
  Future<void> clearEventsForDay(DateTime day);
  Future<List<FreeGap>> findFreeGaps({
    required DateTime day,
    required bool is24HourMode,
    Duration minDuration = const Duration(minutes: 15),
  });
}
