import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/data/repositories/local_event_repository.dart';
import 'package:sectograph_mcp/domain/models/sector_event.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalEventRepository Deconfliction Tests', () {
    test('auto-deconflicts overlapping events on initialization', () async {
      SharedPreferences.setMockInitialValues({
        'radian_events_v1':
            '[{"id":"ev-1","title":"Block 1","start":"2026-09-13T04:15:00.000","end":"2026-09-13T07:20:00.000","colorHex":"#6366F1"},'
            '{"id":"ev-2","title":"Block 2","start":"2026-09-13T06:00:00.000","end":"2026-09-13T07:30:00.000","colorHex":"#6366F1"},'
            '{"id":"ev-3","title":"Block 3","start":"2026-09-13T08:50:00.000","end":"2026-09-13T11:40:00.000","colorHex":"#6366F1"}]',
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = LocalEventRepository(prefs: prefs);

      final events = await repo.getEventsForDay(DateTime(2026, 9, 13));
      expect(events.length, 3);

      final ev1 = events.firstWhere((e) => e.id == 'ev-1');
      final ev2 = events.firstWhere((e) => e.id == 'ev-2');
      final ev3 = events.firstWhere((e) => e.id == 'ev-3');

      // ev-1 should be clamped to end at 6:00 AM (ev-2's start)
      expect(ev1.start, DateTime(2026, 9, 13, 4, 15));
      expect(ev1.end, DateTime(2026, 9, 13, 6, 0));
      expect(ev1.duration, const Duration(hours: 1, minutes: 45));

      // ev-2 runs 6:00 AM to 7:30 AM
      expect(ev2.start, DateTime(2026, 9, 13, 6, 0));
      expect(ev2.end, DateTime(2026, 9, 13, 7, 30));

      // ev-3 runs 8:50 AM to 11:40 AM
      expect(ev3.start, DateTime(2026, 9, 13, 8, 50));
      expect(ev3.end, DateTime(2026, 9, 13, 11, 40));
    });

    test('addEvent maintains non-overlapping invariant', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = LocalEventRepository(prefs: prefs);

      await repo.addEvent(
        SectorEvent(
          id: 'ev-1',
          title: 'Morning Work',
          start: DateTime(2026, 9, 13, 9, 0),
          end: DateTime(2026, 9, 13, 12, 0),
        ),
      );

      // Add overlapping event starting at 10:30 AM
      await repo.addEvent(
        SectorEvent(
          id: 'ev-2',
          title: 'Lunch Meeting',
          start: DateTime(2026, 9, 13, 10, 30),
          end: DateTime(2026, 9, 13, 11, 30),
        ),
      );

      final events = await repo.getEventsForDay(DateTime(2026, 9, 13));
      final ev1 = events.firstWhere((e) => e.id == 'ev-1');
      final ev2 = events.firstWhere((e) => e.id == 'ev-2');

      // ev-1 end should be clamped to 10:30
      expect(ev1.end, DateTime(2026, 9, 13, 10, 30));
      expect(ev2.start, DateTime(2026, 9, 13, 10, 30));
    });
  });
}
