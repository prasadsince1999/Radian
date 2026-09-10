import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/data/repositories/local_event_repository.dart';
import 'package:sectograph_mcp/domain/models/dial_settings.dart';
import 'package:sectograph_mcp/domain/models/sector_event.dart';
import 'package:sectograph_mcp/mcp/mcp_tools.dart';

void main() {
  group('McpTools Comprehensive Test Suite (All 13 Tools)', () {
    late LocalEventRepository repository;
    DialSettings settings = const DialSettings();

    setUp(() {
      repository = LocalEventRepository();
      settings = const DialSettings();
    });

    // 1. Tool definitions validation
    test('getToolDefinitions returns all 13 tools with valid schemas', () {
      final tools = McpTools.getToolDefinitions();
      expect(tools.length, 13);

      final names = tools.map((t) => t['name'] as String).toSet();
      expect(names, {
        'get_clock_state',
        'list_sectors',
        'find_free_gaps',
        'bulk_schedule_sectors',
        'replace_day_schedule',
        'smart_auto_plan',
        'schedule_sector',
        'update_sector',
        'delete_sector',
        'clear_sectors',
        'get_dial_settings',
        'update_dial_settings',
        'analyze_day_balance',
      });

      for (final tool in tools) {
        expect(tool['description'], isNotEmpty);
        expect(tool['inputSchema'], isA<Map<String, dynamic>>());
      }
    });

    // 2. schedule_sector
    test(
      'schedule_sector creates a single event with complete metadata',
      () async {
        final today = DateTime.now();
        final start = DateTime(today.year, today.month, today.day, 9, 0);
        final end = DateTime(today.year, today.month, today.day, 10, 30);

        final res = await McpTools.executeTool(
          name: 'schedule_sector',
          arguments: {
            'title': 'Morning Deep Work',
            'start': start.toIso8601String(),
            'end': end.toIso8601String(),
            'category': 'Work',
            'colorHex': '#6366F1',
            'notes': 'Complete quarterly review',
          },
          repository: repository,
          getSettings: () => settings,
          updateSettings: (s) async => settings = s,
        );

        expect(res['success'], isTrue);
        final sector = res['sector'] as Map<String, dynamic>;
        expect(sector['title'], 'Morning Deep Work');
        expect(sector['category'], 'Work');
        expect(sector['colorHex'], '#6366F1');
        expect(sector['notes'], 'Complete quarterly review');

        final saved = await repository.getEventsForDay(today);
        expect(saved.length, 1);
        expect(saved.first.title, 'Morning Deep Work');
      },
    );

    // 3. list_sectors
    test(
      'list_sectors returns scheduled sectors for a specific date',
      () async {
        final today = DateTime.now();
        await repository.addEvent(
          SectorEvent(
            id: 'test-1',
            title: 'Team Standup',
            start: DateTime(today.year, today.month, today.day, 10, 0),
            end: DateTime(today.year, today.month, today.day, 10, 30),
            category: 'Meetings',
          ),
        );

        final res = await McpTools.executeTool(
          name: 'list_sectors',
          arguments: {'date': today.toIso8601String().substring(0, 10)},
          repository: repository,
          getSettings: () => settings,
          updateSettings: (s) async => settings = s,
        );

        expect(res['count'], 1);
        final sectors = res['sectors'] as List<dynamic>;
        expect(sectors.first['title'], 'Team Standup');
      },
    );

    // 4. get_clock_state
    test(
      'get_clock_state detects current active event and upcoming timeline',
      () async {
        final now = DateTime.now();
        // Active event right now
        await repository.addEvent(
          SectorEvent(
            id: 'active-1',
            title: 'Current Active Focus',
            start: now.subtract(const Duration(minutes: 15)),
            end: now.add(const Duration(minutes: 45)),
            category: 'Focus',
          ),
        );
        // Upcoming event later
        await repository.addEvent(
          SectorEvent(
            id: 'upcoming-1',
            title: 'Later Workout',
            start: now.add(const Duration(hours: 2)),
            end: now.add(const Duration(hours: 3)),
            category: 'Fitness',
          ),
        );

        final res = await McpTools.executeTool(
          name: 'get_clock_state',
          arguments: {},
          repository: repository,
          getSettings: () => settings,
          updateSettings: (s) async => settings = s,
        );

        expect(res['is24HourMode'], isFalse);
        expect(res['activeEvent'], isNotNull);
        expect(res['activeEvent']['title'], 'Current Active Focus');
        expect(res['totalEventsToday'], 2);

        final upcoming = res['upcomingEvents'] as List<dynamic>;
        expect(upcoming.isNotEmpty, isTrue);
        expect(upcoming.first['title'], 'Later Workout');
      },
    );

    // 5. find_free_gaps
    test(
      'find_free_gaps returns unoccupied intervals with duration filter',
      () async {
        final today = DateTime.now();
        // Add a single 2-hour event in the morning
        await repository.addEvent(
          SectorEvent(
            id: 'event-midday',
            title: 'Midday Block',
            start: DateTime(today.year, today.month, today.day, 12, 0),
            end: DateTime(today.year, today.month, today.day, 14, 0),
          ),
        );

        final res = await McpTools.executeTool(
          name: 'find_free_gaps',
          arguments: {
            'date': today.toIso8601String().substring(0, 10),
            'minDurationMinutes': 30,
          },
          repository: repository,
          getSettings: () => settings,
          updateSettings: (s) async => settings = s,
        );

        expect(res['freeGapsCount'], isPositive);
        final gaps = res['gaps'] as List<dynamic>;
        for (final g in gaps) {
          final durationMins = g['durationMinutes'] as int;
          expect(durationMins >= 30, isTrue);
        }
      },
    );

    // 6. update_sector
    test('update_sector modifies fields of an existing sector', () async {
      final today = DateTime.now();
      final event = SectorEvent(
        id: 'update-target',
        title: 'Original Title',
        start: DateTime(today.year, today.month, today.day, 15, 0),
        end: DateTime(today.year, today.month, today.day, 16, 0),
        category: 'Work',
      );
      await repository.addEvent(event);

      final res = await McpTools.executeTool(
        name: 'update_sector',
        arguments: {
          'id': 'update-target',
          'title': 'Renamed Strategy Session',
          'category': 'Strategy',
          'colorHex': '#EF4444',
          'notes': 'Updated via MCP',
        },
        repository: repository,
        getSettings: () => settings,
        updateSettings: (s) async => settings = s,
      );

      expect(res['success'], isTrue);
      final sector = res['sector'] as Map<String, dynamic>;
      expect(sector['title'], 'Renamed Strategy Session');
      expect(sector['category'], 'Strategy');
      expect(sector['colorHex'], '#EF4444');
      expect(sector['notes'], 'Updated via MCP');
    });

    // 7. delete_sector
    test('delete_sector removes a sector from the repository', () async {
      final today = DateTime.now();
      final event = SectorEvent(
        id: 'delete-target',
        title: 'To Be Deleted',
        start: DateTime(today.year, today.month, today.day, 17, 0),
        end: DateTime(today.year, today.month, today.day, 18, 0),
      );
      await repository.addEvent(event);

      final res = await McpTools.executeTool(
        name: 'delete_sector',
        arguments: {'id': 'delete-target'},
        repository: repository,
        getSettings: () => settings,
        updateSettings: (s) async => settings = s,
      );

      expect(res['success'], isTrue);
      expect(res['deletedId'], 'delete-target');

      final remaining = await repository.getEventsForDay(today);
      expect(remaining.any((e) => e.id == 'delete-target'), isFalse);
    });

    // 8. clear_sectors
    test('clear_sectors wipes all sectors for target date', () async {
      final today = DateTime.now();
      await repository.addEvent(
        SectorEvent(
          id: 'c1',
          title: 'Block 1',
          start: DateTime(today.year, today.month, today.day, 8, 0),
          end: DateTime(today.year, today.month, today.day, 9, 0),
        ),
      );
      await repository.addEvent(
        SectorEvent(
          id: 'c2',
          title: 'Block 2',
          start: DateTime(today.year, today.month, today.day, 11, 0),
          end: DateTime(today.year, today.month, today.day, 12, 0),
        ),
      );

      final res = await McpTools.executeTool(
        name: 'clear_sectors',
        arguments: {'date': today.toIso8601String().substring(0, 10)},
        repository: repository,
        getSettings: () => settings,
        updateSettings: (s) async => settings = s,
      );

      expect(res['success'], isTrue);
      final remaining = await repository.getEventsForDay(today);
      expect(remaining.isEmpty, isTrue);
    });

    // 9. bulk_schedule_sectors
    test('bulk_schedule_sectors schedules multiple blocks in batch', () async {
      final today = DateTime.now();
      final res = await McpTools.executeTool(
        name: 'bulk_schedule_sectors',
        arguments: {
          'events': [
            {
              'title': 'Morning Yoga',
              'start': DateTime(
                today.year,
                today.month,
                today.day,
                7,
                0,
              ).toIso8601String(),
              'end': DateTime(
                today.year,
                today.month,
                today.day,
                8,
                0,
              ).toIso8601String(),
              'category': 'Fitness',
            },
            {
              'title': 'Client Call',
              'start': DateTime(
                today.year,
                today.month,
                today.day,
                11,
                0,
              ).toIso8601String(),
              'end': DateTime(
                today.year,
                today.month,
                today.day,
                12,
                0,
              ).toIso8601String(),
              'category': 'Meetings',
            },
          ],
        },
        repository: repository,
        getSettings: () => settings,
        updateSettings: (s) async => settings = s,
      );

      expect(res['success'], isTrue);
      expect(res['scheduledCount'], 2);

      final events = await repository.getEventsForDay(today);
      expect(events.length, 2);
    });

    // 10. replace_day_schedule
    test(
      'replace_day_schedule atomically replaces existing schedule',
      () async {
        final today = DateTime.now();
        // Pre-existing event
        await repository.addEvent(
          SectorEvent(
            id: 'old-1',
            title: 'Old Deprecated Event',
            start: DateTime(today.year, today.month, today.day, 9, 0),
            end: DateTime(today.year, today.month, today.day, 10, 0),
          ),
        );

        final res = await McpTools.executeTool(
          name: 'replace_day_schedule',
          arguments: {
            'date': today.toIso8601String().substring(0, 10),
            'events': [
              {
                'title': 'Brand New Day Plan',
                'start': DateTime(
                  today.year,
                  today.month,
                  today.day,
                  10,
                  0,
                ).toIso8601String(),
                'end': DateTime(
                  today.year,
                  today.month,
                  today.day,
                  11,
                  30,
                ).toIso8601String(),
                'category': 'Focus',
              },
            ],
          },
          repository: repository,
          getSettings: () => settings,
          updateSettings: (s) async => settings = s,
        );

        expect(res['success'], isTrue);
        expect(res['newEventsCount'], 1);

        final events = await repository.getEventsForDay(today);
        expect(events.length, 1);
        expect(events.first.title, 'Brand New Day Plan');
        expect(events.any((e) => e.title == 'Old Deprecated Event'), isFalse);
      },
    );

    // 11. smart_auto_plan
    test(
      'smart_auto_plan automatically packs tasks into free dial gaps',
      () async {
        final today = DateTime.now();
        // Empty day has free gaps from 00:00 to 24:00 (or 12h)
        final res = await McpTools.executeTool(
          name: 'smart_auto_plan',
          arguments: {
            'date': today.toIso8601String().substring(0, 10),
            'tasks': [
              {'title': 'Task A', 'durationMinutes': 45, 'category': 'Focus'},
              {'title': 'Task B', 'durationMinutes': 30, 'category': 'Rest'},
            ],
          },
          repository: repository,
          getSettings: () => settings,
          updateSettings: (s) async => settings = s,
        );

        expect(res['success'], isTrue);
        expect(res['autoScheduledCount'], 2);
        final scheduled = res['scheduled'] as List<dynamic>;
        expect(scheduled[0]['title'], 'Task A');
        expect(scheduled[1]['title'], 'Task B');

        // Verify they do not overlap and have valid durations
        final startA = DateTime.parse(scheduled[0]['start'] as String);
        final endA = DateTime.parse(scheduled[0]['end'] as String);
        final startB = DateTime.parse(scheduled[1]['start'] as String);
        expect(startA.isBefore(endA), isTrue);
        expect(startB.isAtSameMomentAs(endA) || startB.isAfter(endA), isTrue);
      },
    );

    // 12. get_dial_settings & update_dial_settings
    test(
      'get_dial_settings and update_dial_settings read and mutate dial config',
      () async {
        final initial = await McpTools.executeTool(
          name: 'get_dial_settings',
          arguments: {},
          repository: repository,
          getSettings: () => settings,
          updateSettings: (s) async => settings = s,
        );
        expect(initial['is24HourMode'], isFalse);

        final updated = await McpTools.executeTool(
          name: 'update_dial_settings',
          arguments: {
            'is24HourMode': true,
            'themeMode': 'dark',
            'seedColorHex': '#10B981',
            'faceStyle': 'numbered',
            'sectorStyle': 'softGradient',
            'handStyle': 'glowingArrow',
          },
          repository: repository,
          getSettings: () => settings,
          updateSettings: (s) async => settings = s,
        );

        expect(updated['success'], isTrue);
        expect(settings.is24HourMode, isTrue);
        expect(settings.themeMode, ThemeMode.dark);
        expect(settings.seedColorHex, '#10B981');
        expect(settings.faceStyle, DialFaceStyle.numbered);
        expect(settings.sectorStyle, SectorVisualTheme.softGradient);
        expect(settings.handStyle, HandStyle.glowingArrow);
      },
    );

    // 13. analyze_day_balance
    test(
      'analyze_day_balance computes category breakdown and total hours',
      () async {
        final today = DateTime.now();
        await repository.addEvent(
          SectorEvent(
            id: 'b1',
            title: 'Deep Coding',
            start: DateTime(today.year, today.month, today.day, 9, 0),
            end: DateTime(
              today.year,
              today.month,
              today.day,
              11,
              0,
            ), // 120 mins
            category: 'Work',
          ),
        );
        await repository.addEvent(
          SectorEvent(
            id: 'b2',
            title: 'Gym Workout',
            start: DateTime(today.year, today.month, today.day, 12, 0),
            end: DateTime(today.year, today.month, today.day, 13, 0), // 60 mins
            category: 'Fitness',
          ),
        );

        final res = await McpTools.executeTool(
          name: 'analyze_day_balance',
          arguments: {'date': today.toIso8601String().substring(0, 10)},
          repository: repository,
          getSettings: () => settings,
          updateSettings: (s) async => settings = s,
        );

        expect(res['totalEvents'], 2);
        expect(res['totalScheduledMinutes'], 180);
        expect(res['totalScheduledHours'], '3.0');

        final breakdown = res['categoryBreakdown'] as Map<String, dynamic>;
        expect(breakdown['Work']['minutes'], 120);
        expect(breakdown['Work']['hours'], '2.0');
        expect(breakdown['Fitness']['minutes'], 60);
        expect(breakdown['Fitness']['hours'], '1.0');
      },
    );

    // Error handling
    test('executeTool throws for unknown tool name', () async {
      expect(
        () => McpTools.executeTool(
          name: 'non_existent_tool',
          arguments: {},
          repository: repository,
          getSettings: () => settings,
          updateSettings: (s) async => settings = s,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
