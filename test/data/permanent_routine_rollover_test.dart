import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/data/datasources/sample_events_data.dart';
import 'package:sectograph_mcp/data/repositories/local_event_repository.dart';
import 'package:sectograph_mcp/domain/models/sector_event.dart';
import 'package:sectograph_mcp/domain/schedule/event_day_projector.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Permanent Main Routine Blocks & Day Rollover Tests', () {
    test('main routine blocks project onto any future viewing day without expiring', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = LocalEventRepository(prefs: prefs);
      await repo.clearAllEvents();

      // Create a permanent routine block on Monday, Sep 21
      final monday = DateTime(2026, 9, 21);
      final sleepBlock = SectorEvent(
        id: 'in-sleep',
        title: 'Sleep',
        start: DateTime(monday.year, monday.month, monday.day, 0, 0),
        end: DateTime(monday.year, monday.month, monday.day, 6, 0),
        colorHex: '#98A8C8',
        category: 'Rest',
        repeatDays: EventDayProjector.dailyWeekdays,
      );
      final studyBlock = SectorEvent(
        id: 'in-study',
        title: 'Study Time',
        start: DateTime(monday.year, monday.month, monday.day, 9, 0),
        end: DateTime(monday.year, monday.month, monday.day, 12, 0),
        colorHex: '#F7C752',
        category: 'Focus',
        repeatDays: EventDayProjector.dailyWeekdays,
      );

      await repo.addEvent(sleepBlock);
      await repo.addEvent(studyBlock);

      // Verify on Monday, Sep 21
      final mondayEvents = await repo.getEventsForDay(monday);
      expect(mondayEvents.length, 2);
      expect(mondayEvents[0].title, 'Sleep');
      expect(mondayEvents[0].start, DateTime(2026, 9, 21, 0, 0));
      expect(mondayEvents[0].end, DateTime(2026, 9, 21, 6, 0));

      // Verify on Wednesday, Sep 23 (Day rollover test)
      final wednesday = DateTime(2026, 9, 23);
      final wednesdayEvents = await repo.getEventsForDay(wednesday);
      expect(wednesdayEvents.length, 2);
      expect(wednesdayEvents[0].title, 'Sleep');
      expect(wednesdayEvents[0].start, DateTime(2026, 9, 23, 0, 0));
      expect(wednesdayEvents[0].end, DateTime(2026, 9, 23, 6, 0));
      expect(wednesdayEvents[1].title, 'Study Time');
      expect(wednesdayEvents[1].start, DateTime(2026, 9, 23, 9, 0));
      expect(wednesdayEvents[1].end, DateTime(2026, 9, 23, 12, 0));

      // Verify on a day 30 days into the future
      final futureDay = monday.add(const Duration(days: 30));
      final futureEvents = await repo.getEventsForDay(futureDay);
      expect(futureEvents.length, 2);
      expect(
        futureEvents[0].start,
        DateTime(futureDay.year, futureDay.month, futureDay.day, 0, 0),
      );
    });

    test(
      'blocks with repeatDays project only on their specified days of week',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final repo = LocalEventRepository(prefs: prefs);

        // Create block repeating on Weekdays only (1 = Mon ... 5 = Fri)
        final monday = DateTime(2026, 9, 21); // Mon (weekday 1)
        final weekdayBlock = SectorEvent(
          id: 'team-standup',
          title: 'Team Standup',
          start: DateTime(monday.year, monday.month, monday.day, 10, 0),
          end: DateTime(monday.year, monday.month, monday.day, 10, 30),
          repeatDays: [1, 2, 3, 4, 5],
        );

        await repo.addEvent(weekdayBlock);

        // Wednesday, Sep 23 (weekday 3) -> should appear
        final wednesdayEvents = await repo.getEventsForDay(
          DateTime(2026, 9, 23),
        );
        expect(wednesdayEvents.any((e) => e.title == 'Team Standup'), isTrue);

        // Sunday, Sep 27 (weekday 7) -> should NOT appear
        final sundayEvents = await repo.getEventsForDay(DateTime(2026, 9, 27));
        expect(sundayEvents.any((e) => e.title == 'Team Standup'), isFalse);
      },
    );

    test(
      'blocks with recurrenceEndDate project only up to the end date',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final repo = LocalEventRepository(prefs: prefs);

        final monday = DateTime(2026, 9, 21);
        final limitedBlock = SectorEvent(
          id: 'sprint-review',
          title: 'Sprint Review',
          start: DateTime(monday.year, monday.month, monday.day, 14, 0),
          end: DateTime(monday.year, monday.month, monday.day, 15, 0),
          recurrenceEndDate: DateTime(2026, 9, 24),
        );

        await repo.addEvent(limitedBlock);

        // Sep 23 -> within boundary -> should appear
        final dayBefore = await repo.getEventsForDay(DateTime(2026, 9, 23));
        expect(dayBefore.any((e) => e.title == 'Sprint Review'), isTrue);

        // Sep 25 -> after boundary -> should NOT appear
        final dayAfter = await repo.getEventsForDay(DateTime(2026, 9, 25));
        expect(dayAfter.any((e) => e.title == 'Sprint Review'), isFalse);
      },
    );

    test('SampleEventsData produces canonical permanent routines', () {
      final now = DateTime(2026, 9, 23);
      final schedule = SampleEventsData.generateIndian12hSchedule(now);

      // Should have 10 standard routine blocks
      expect(schedule.length, 10);
      expect(
        schedule.map((e) => e.id),
        containsAll([
          'in-sleep',
          'in-yoga',
          'in-chai',
          'in-study',
          'in-projects',
          'in-break',
          'in-workout',
          'in-read',
          'in-dinner',
          'in-code',
        ]),
      );

      // None should have day prefixes
      for (final ev in schedule) {
        expect(RegExp(r'^\d{8}-').hasMatch(ev.id), isFalse);
      }
    });

    test(
      'deduplicates legacy duplicate routine blocks on initialization',
      () async {
        // Simulate stored SharedPreferences with 3 legacy copies of Sleep from old multi-day seeding
        SharedPreferences.setMockInitialValues({
          'radian_events_v1': '''[
          {"id":"20260920-in-sleep","title":"Sleep","start":"2026-09-20T00:00:00.000","end":"2026-09-20T06:00:00.000","colorHex":"#98A8C8"},
          {"id":"20260921-in-sleep","title":"Sleep","start":"2026-09-21T00:00:00.000","end":"2026-09-21T06:00:00.000","colorHex":"#98A8C8"},
          {"id":"20260922-in-sleep","title":"Sleep","start":"2026-09-22T00:00:00.000","end":"2026-09-22T06:00:00.000","colorHex":"#98A8C8"}
        ]''',
        });

        final prefs = await SharedPreferences.getInstance();
        final repo = LocalEventRepository(prefs: prefs);

        // All 3 should be collapsed to 1 canonical routine block
        final allEvents = await repo.getAllEvents();
        final sleepEvents = allEvents.where((e) => e.title == 'Sleep').toList();
        expect(sleepEvents.length, 1);
        expect(sleepEvents.first.id, 'in-sleep');

        // Projected day events should also have exactly 1 Sleep block
        final dayEvents = await repo.getEventsForDay(DateTime(2026, 9, 23));
        final daySleep = dayEvents.where((e) => e.title == 'Sleep').toList();
        expect(daySleep.length, 1);
      },
    );
  });
}
