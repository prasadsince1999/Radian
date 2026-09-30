import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/core/time/zone_clock.dart';
import 'package:sectograph_mcp/engine/dial_input.dart';
import 'package:sectograph_mcp/engine/widget_frame_planner.dart';

void main() {
  group('WidgetFramePlanner Unit & Boundary Tests (Phase 6)', () {
    final testDate = DateTime(2026, 9, 29, 8, 0); // 8:00 AM UTC
    late ZoneClockSnapshot clock;

    setUp(() {
      clock = ZoneClockSnapshot.fromDateTime(testDate, tzid: 'UTC');
    });

    test('Empty day produces compact frames covering entire 36h planning horizon', () {
      final plan = WidgetFramePlanner.plan(
        clock: clock,
        occurrences: const [],
        prefs: const DialPrefs(is24HourMode: false),
      );

      expect(plan.tzid, equals(clock.tzid));
      expect(plan.dataVersion, isNotEmpty);
      expect(plan.themeVariants, equals(['light', 'dark']));
      expect(plan.frames, isNotEmpty);

      // Total planning coverage spans from 00:00 today to 12:00 tomorrow (36 hours)
      final firstFrame = plan.frames.first;
      final lastFrame = plan.frames.last;

      expect(firstFrame.start.hour, equals(0));
      expect(firstFrame.start.day, equals(29));
      expect(lastFrame.end.hour, equals(12));
      expect(lastFrame.end.day, equals(30));

      expect(plan.validUntilMs, equals(lastFrame.toMs));

      // frameFor returns a valid frame for any time in the 36-hour window
      final frameAt8am = plan.frameFor(DateTime.utc(2026, 9, 29, 8, 0));
      expect(frameAt8am, isNotNull);
      expect(frameAt8am!.model.center.activeTitle, equals('Free Time'));
    });

    test('Schedule with multiple events generates distinct frames and deduplicates identical layouts', () {
      final occs = [
        Occurrence(
          id: 'occ-1',
          eventId: 'ev-1',
          title: 'Morning Yoga',
          start: DateTime.utc(2026, 9, 29, 6, 0),
          end: DateTime.utc(2026, 9, 29, 7, 15),
          colorHex: '#10B981',
          category: 'Health',
        ),
        Occurrence(
          id: 'occ-2',
          eventId: 'ev-2',
          title: 'Deep Work',
          start: DateTime.utc(2026, 9, 29, 9, 30),
          end: DateTime.utc(2026, 9, 29, 12, 0),
          colorHex: '#6366F1',
          category: 'Work',
        ),
        Occurrence(
          id: 'occ-3',
          eventId: 'ev-3',
          title: 'Team Standup',
          start: DateTime.utc(2026, 9, 29, 14, 0),
          end: DateTime.utc(2026, 9, 29, 15, 0),
          colorHex: '#F59E0B',
          category: 'Work',
        ),
      ];

      final plan = WidgetFramePlanner.plan(
        clock: clock,
        occurrences: occs,
        prefs: const DialPrefs(is24HourMode: false),
      );

      // Verify frameFor at 06:30 returns Yoga as active block
      final frameAtYoga = plan.frameFor(DateTime.utc(2026, 9, 29, 6, 30));
      expect(frameAtYoga, isNotNull);
      expect(frameAtYoga!.model.center.activeTitle, equals('Morning Yoga'));
      expect(frameAtYoga.model.needle.activeEventId, equals('ev-1'));

      // Verify frameFor at 10:15 returns Deep Work as active block
      final frameAtWork = plan.frameFor(DateTime.utc(2026, 9, 29, 10, 15));
      expect(frameAtWork, isNotNull);
      expect(frameAtWork!.model.center.activeTitle, equals('Deep Work'));
      expect(frameAtWork.model.needle.activeEventId, equals('ev-2'));

      // Verify frameFor at 14:30 returns Team Standup as active block
      final frameAtStandup = plan.frameFor(DateTime.utc(2026, 9, 29, 14, 30));
      expect(frameAtStandup, isNotNull);
      expect(frameAtStandup!.model.center.activeTitle, equals('Team Standup'));

      // Frame files are named sequentially 0.png, 1.png, ...
      for (int i = 0; i < plan.frames.length; i++) {
        expect(plan.frames[i].fileName, equals('$i.png'));
      }
    });

    test('JSON serialization strictly conforms to Section 6.1 spec', () {
      final occs = [
        Occurrence(
          id: 'occ-1',
          eventId: 'ev-1',
          title: 'Deep Work',
          start: DateTime.utc(2026, 9, 29, 9, 30),
          end: DateTime.utc(2026, 9, 29, 12, 0),
          colorHex: '#6366F1',
          category: 'Work',
        ),
      ];

      final plan = WidgetFramePlanner.plan(
        clock: clock,
        occurrences: occs,
        prefs: const DialPrefs(is24HourMode: false),
      );

      final json = plan.toJson();
      expect(json['dataVersion'], isA<String>());
      expect(json['tzid'], equals(clock.tzid));
      expect(json['validUntilMs'], isA<int>());
      expect(json['themeVariants'], equals(['light', 'dark']));
      expect(json['frames'], isA<List>());

      final frameJson = (json['frames'] as List).first as Map<String, dynamic>;
      expect(frameJson['fromMs'], isA<int>());
      expect(frameJson['toMs'], isA<int>());
      expect(frameJson['file'], matches(r'^\d+\.png$'));
      expect(frameJson['signature'], isA<String>());
      expect(frameJson['layoutSignature'], isA<String>());
      expect(frameJson['warp'], isA<List>());
      expect(frameJson['center'], isA<Map<String, dynamic>>());
      expect(frameJson['center']['mode'], equals('digital'));
    });

    test('Midnight-crossing block creates valid frames across midnight boundary', () {
      final occs = [
        Occurrence(
          id: 'occ-night',
          eventId: 'ev-night',
          title: 'Night Shift',
          start: DateTime.utc(2026, 9, 29, 23, 0),
          end: DateTime.utc(2026, 9, 30, 2, 0),
          colorHex: '#8B5CF6',
          category: 'Work',
        ),
      ];

      final plan = WidgetFramePlanner.plan(
        clock: clock,
        occurrences: occs,
        prefs: const DialPrefs(is24HourMode: false),
      );

      // Frame at 23:30 (before midnight)
      final frameBeforeMidnight = plan.frameFor(DateTime.utc(2026, 9, 29, 23, 30));
      expect(frameBeforeMidnight, isNotNull);
      expect(frameBeforeMidnight!.model.center.activeTitle, equals('Night Shift'));

      // Frame at 00:30 (after midnight)
      final frameAfterMidnight = plan.frameFor(DateTime.utc(2026, 9, 30, 0, 30));
      expect(frameAfterMidnight, isNotNull);
      expect(frameAfterMidnight!.model.center.activeTitle, equals('Night Shift'));
    });

    test('24-hour mode plans fullDay24 window with 24-hour ticks', () {
      final plan24 = WidgetFramePlanner.plan(
        clock: clock,
        occurrences: const [],
        prefs: const DialPrefs(is24HourMode: true),
      );

      expect(plan24.frames.first.model.is24HourMode, isTrue);
      expect(plan24.frames.first.model.ticks.length, equals(24));
    });
  });
}
