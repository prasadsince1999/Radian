import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/core/services/health_service.dart';
import 'package:sectograph_mcp/data/repositories/health_repository_impl.dart';
import 'package:sectograph_mcp/data/repositories/local_event_repository.dart';
import 'package:sectograph_mcp/domain/models/dial_settings.dart';
import 'package:sectograph_mcp/domain/models/health_models.dart';
import 'package:sectograph_mcp/domain/models/sector_event.dart';
import 'package:sectograph_mcp/domain/models/subtask_item.dart';
import 'package:sectograph_mcp/mcp/mcp_tools.dart';

void main() {
  group('McpTools Comprehensive Test Suite (All 17 Tools)', () {
    late LocalEventRepository repository;
    DialSettings settings = const DialSettings();

    setUp(() {
      repository = LocalEventRepository();
      settings = const DialSettings();
    });

    // 1. Tool definitions validation
    test('getToolDefinitions returns all 17 tools with valid schemas', () {
      final tools = McpTools.getToolDefinitions();
      expect(tools.length, 17);

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
        'manage_subtask',
        'get_dial_settings',
        'update_dial_settings',
        'analyze_day_balance',
        'get_health_summary',
        'sync_health_to_dial',
        'get_health_status',
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
        final endOfDay = DateTime(now.year, now.month, now.day, 23, 59);
        final remainingMinutes = endOfDay.difference(now).inMinutes;
        final activeEndMins = remainingMinutes > 10 ? 5 : 1;
        final upcomingStartMins = remainingMinutes > 10 ? 6 : 2;
        final upcomingEndMins = remainingMinutes > 10 ? 8 : 3;

        // Active event right now
        await repository.addEvent(
          SectorEvent(
            id: 'active-1',
            title: 'Current Active Focus',
            start: now.subtract(const Duration(minutes: 5)),
            end: now.add(Duration(minutes: activeEndMins)),
            category: 'Focus',
          ),
        );
        // Upcoming event later today
        await repository.addEvent(
          SectorEvent(
            id: 'upcoming-1',
            title: 'Later Workout',
            start: now.add(Duration(minutes: upcomingStartMins)),
            end: now.add(Duration(minutes: upcomingEndMins)),
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

    // Subtasks Functionality Tests
    test('schedule_sector saves and retrieves subtasks', () async {
      final today = DateTime.now();
      final start = DateTime(today.year, today.month, today.day, 14, 0);
      final end = DateTime(today.year, today.month, today.day, 16, 0);

      final res = await McpTools.executeTool(
        name: 'schedule_sector',
        arguments: {
          'title': 'AI Prep Sprint',
          'start': start.toIso8601String(),
          'end': end.toIso8601String(),
          'subtasks': ['LeetCode', 'Mock Prep', 'PyTorch'],
        },
        repository: repository,
        getSettings: () => settings,
        updateSettings: (s) async => settings = s,
      );

      expect(res['success'], isTrue);
      final sector = res['sector'] as Map<String, dynamic>;
      expect(sector['subtasks'], ['LeetCode', 'Mock Prep', 'PyTorch']);

      final saved = await repository.getEventsForDay(today);
      expect(saved.first.subtasks, ['LeetCode', 'Mock Prep', 'PyTorch']);
    });

    test(
      'bulk_schedule_sectors and replace_day_schedule handle subtasks',
      () async {
        final today = DateTime.now();
        final start = DateTime(today.year, today.month, today.day, 16, 0);
        final end = DateTime(today.year, today.month, today.day, 17, 0);

        final bulkRes = await McpTools.executeTool(
          name: 'bulk_schedule_sectors',
          arguments: {
            'events': [
              {
                'title': 'Cooking Session',
                'start': start.toIso8601String(),
                'end': end.toIso8601String(),
                'subtasks': ['Meal Prep', 'Quick Lunch'],
              },
            ],
          },
          repository: repository,
          getSettings: () => settings,
          updateSettings: (s) async => settings = s,
        );

        expect(bulkRes['success'], isTrue);
        final sectors = bulkRes['sectors'] as List<dynamic>;
        expect(sectors.first['subtasks'], ['Meal Prep', 'Quick Lunch']);

        // Now test replace_day_schedule
        final replaceRes = await McpTools.executeTool(
          name: 'replace_day_schedule',
          arguments: {
            'date': today.toIso8601String().substring(0, 10),
            'events': [
              {
                'title': 'Replaced Deep Work',
                'start': start.toIso8601String(),
                'end': end.toIso8601String(),
                'subtasks': ['Backprop', 'Transformers'],
              },
            ],
          },
          repository: repository,
          getSettings: () => settings,
          updateSettings: (s) async => settings = s,
        );

        expect(replaceRes['success'], isTrue);
        final repSectors = replaceRes['sectors'] as List<dynamic>;
        expect(repSectors.first['subtasks'], ['Backprop', 'Transformers']);
      },
    );

    test('update_sector modifies, clears, and preserves subtasks', () async {
      final today = DateTime.now();
      final start = DateTime(today.year, today.month, today.day, 10, 0);
      final end = DateTime(today.year, today.month, today.day, 11, 0);

      final initial = await McpTools.executeTool(
        name: 'schedule_sector',
        arguments: {
          'title': 'Original Task',
          'start': start.toIso8601String(),
          'end': end.toIso8601String(),
          'subtasks': ['Sub 1', 'Sub 2'],
        },
        repository: repository,
        getSettings: () => settings,
        updateSettings: (s) async => settings = s,
      );
      final id = (initial['sector'] as Map<String, dynamic>)['id'] as String;

      // 1. Preserve subtasks when omitted
      final resPreserve = await McpTools.executeTool(
        name: 'update_sector',
        arguments: {'id': id, 'title': 'Updated Title'},
        repository: repository,
        getSettings: () => settings,
        updateSettings: (s) async => settings = s,
      );
      expect(resPreserve['success'], isTrue);
      expect(resPreserve['sector']['subtasks'], ['Sub 1', 'Sub 2']);

      // 2. Modify subtasks
      final resModify = await McpTools.executeTool(
        name: 'update_sector',
        arguments: {
          'id': id,
          'subtasks': ['Sub 3', 'Sub 4'],
        },
        repository: repository,
        getSettings: () => settings,
        updateSettings: (s) async => settings = s,
      );
      expect(resModify['success'], isTrue);
      expect(resModify['sector']['subtasks'], ['Sub 3', 'Sub 4']);

      // 3. Clear subtasks with empty list
      final resClear = await McpTools.executeTool(
        name: 'update_sector',
        arguments: {'id': id, 'subtasks': []},
        repository: repository,
        getSettings: () => settings,
        updateSettings: (s) async => settings = s,
      );
      expect(resClear['success'], isTrue);
      expect(resClear['sector']['subtasks'], isEmpty);
    });

    // MCP Edge Cases Tests
    test('schedule_sector rejects inverted start and end times', () async {
      final today = DateTime.now();
      final start = DateTime(today.year, today.month, today.day, 14, 0);
      final end = DateTime(
        today.year,
        today.month,
        today.day,
        13,
        0,
      ); // before start!

      final res = await McpTools.executeTool(
        name: 'schedule_sector',
        arguments: {
          'title': 'Impossible Time',
          'start': start.toIso8601String(),
          'end': end.toIso8601String(),
        },
        repository: repository,
        getSettings: () => settings,
        updateSettings: (s) async => settings = s,
      );

      expect(res['success'], isFalse);
      expect(res['error'], contains('End time must be strictly after'));
    });

    test(
      'schedule_sector handles invalid ISO date strings gracefully',
      () async {
        final res = await McpTools.executeTool(
          name: 'schedule_sector',
          arguments: {
            'title': 'Bad Date',
            'start': 'invalid-date-string',
            'end': 'another-bad-date',
          },
          repository: repository,
          getSettings: () => settings,
          updateSettings: (s) async => settings = s,
        );

        expect(res['success'], isFalse);
        expect(res['error'], contains('Invalid ISO 8601'));
      },
    );

    test('update_sector returns clean error for non-existent ID', () async {
      final res = await McpTools.executeTool(
        name: 'update_sector',
        arguments: {'id': 'non-existent-id-999', 'title': 'Ghost'},
        repository: repository,
        getSettings: () => settings,
        updateSettings: (s) async => settings = s,
      );

      expect(res['success'], isFalse);
      expect(res['error'], contains('Sector not found'));
    });

    test('delete_sector returns clean error for non-existent ID', () async {
      final res = await McpTools.executeTool(
        name: 'delete_sector',
        arguments: {'id': 'non-existent-id-999'},
        repository: repository,
        getSettings: () => settings,
        updateSettings: (s) async => settings = s,
      );

      expect(res['success'], isFalse);
      expect(res['error'], contains('Sector not found'));
    });

    test(
      'subtasks sanitization handles whitespace and non-string types',
      () async {
        final today = DateTime.now();
        final start = DateTime(today.year, today.month, today.day, 10, 0);
        final end = DateTime(today.year, today.month, today.day, 11, 0);

        final res = await McpTools.executeTool(
          name: 'schedule_sector',
          arguments: {
            'title': 'Sanitization Test',
            'start': start.toIso8601String(),
            'end': end.toIso8601String(),
            'subtasks': ['  Trimmed Item  ', '', '   ', 123, true],
          },
          repository: repository,
          getSettings: () => settings,
          updateSettings: (s) async => settings = s,
        );

        expect(res['success'], isTrue);
        final sector = res['sector'] as Map<String, dynamic>;
        expect(sector['subtasks'], ['Trimmed Item', '123', 'true']);
      },
    );

    test(
      'update_dial_settings ignores invalid enum values without throwing',
      () async {
        final res = await McpTools.executeTool(
          name: 'update_dial_settings',
          arguments: {
            'themeMode': 'alien_theme_mode',
            'faceStyle': 'unknown_style',
            'sectorStyle': 'non_existent_sector',
            'handStyle': 'laser_pointer',
          },
          repository: repository,
          getSettings: () => settings,
          updateSettings: (s) async => settings = s,
        );

        expect(res['success'], isTrue);
        expect(res['settings'], isA<Map<String, dynamic>>());
      },
    );

    test('get_clock_state functions safely on completely empty day', () async {
      final futureDate = DateTime(2030, 1, 1);
      final res = await McpTools.executeTool(
        name: 'get_clock_state',
        arguments: {'date': futureDate.toIso8601String().substring(0, 10)},
        repository: repository,
        getSettings: () => settings,
        updateSettings: (s) async => settings = s,
      );

      expect(res['totalEventsToday'], 0);
      expect(res['activeEvent'], isNull);
      expect(res['upcomingEvents'], isEmpty);
      expect(res['activeEventRemainingMinutes'], 0);
    });

    // Health MCP Tools Tests
    test(
      'get_health_summary returns authentic biometrics and metrics',
      () async {
        final mockService = MockHealthService();
        final today = DateTime.now();
        mockService.addSummary(
          DailyHealthSummary(
            date: DateTime(today.year, today.month, today.day),
            steps: 8520,
            activeCalories: 350.0,
            totalCalories: 350.0,
            distanceMeters: 6200.0,
            sleepDurationMinutes: 440,
            sleepStart: DateTime(today.year, today.month, today.day - 1, 23, 0),
            sleepEnd: DateTime(today.year, today.month, today.day, 6, 20),
            exerciseSessions: [
              HealthExerciseSession(
                id: 'sess-run-1',
                title: 'Morning Jog',
                type: 'running',
                start: DateTime(today.year, today.month, today.day, 7, 0),
                end: DateTime(today.year, today.month, today.day, 7, 30),
                caloriesBurned: 220.0,
              ),
            ],
            lastSyncTime: today,
          ),
        );
        final healthRepo = HealthRepositoryImpl(service: mockService);

        final res = await McpTools.executeTool(
          name: 'get_health_summary',
          arguments: {'date': today.toIso8601String().substring(0, 10)},
          repository: repository,
          getSettings: () => settings,
          updateSettings: (s) async => settings = s,
          healthRepository: healthRepo,
        );

        expect(res['steps'], 8520);
        expect(res['activeCalories'], 350.0);
        expect(res['sleepDurationMinutes'], 440);
        expect(res['sleepHoursFormatted'], '7h 20m');
        expect(res['exerciseSessions'], isNotEmpty);
        expect(res['exerciseSessions'][0]['title'], 'Morning Jog');
      },
    );

    test(
      'sync_health_to_dial adds sleep and workouts to dial schedule',
      () async {
        final mockService = MockHealthService();
        final today = DateTime.now();
        mockService.addSummary(
          DailyHealthSummary(
            date: DateTime(today.year, today.month, today.day),
            steps: 7000,
            sleepDurationMinutes: 420,
            sleepStart: DateTime(
              today.year,
              today.month,
              today.day - 1,
              23,
              30,
            ),
            sleepEnd: DateTime(today.year, today.month, today.day, 6, 30),
            exerciseSessions: [
              HealthExerciseSession(
                id: 'workout-101',
                title: 'HIIT Session',
                type: 'workout',
                start: DateTime(today.year, today.month, today.day, 8, 0),
                end: DateTime(today.year, today.month, today.day, 8, 45),
                caloriesBurned: 300.0,
              ),
            ],
            lastSyncTime: today,
          ),
        );
        final healthRepo = HealthRepositoryImpl(service: mockService);

        final res = await McpTools.executeTool(
          name: 'sync_health_to_dial',
          arguments: {'date': today.toIso8601String().substring(0, 10)},
          repository: repository,
          getSettings: () => settings,
          updateSettings: (s) async => settings = s,
          healthRepository: healthRepo,
        );

        expect(res['success'], isTrue);
        expect(res['syncedSessionsCount'], 2); // 1 sleep + 1 workout

        final events = await repository.getEventsForDay(today);
        expect(events.any((e) => e.title == 'Sleep'), isTrue);
        expect(events.any((e) => e.title == 'HIIT Session'), isTrue);
      },
    );

    test('get_health_status returns availability and permissions', () async {
      final mockService = MockHealthService(
        isAvailableStatus: true,
        hasPermissionsStatus: true,
      );
      final healthRepo = HealthRepositoryImpl(service: mockService);

      final res = await McpTools.executeTool(
        name: 'get_health_status',
        arguments: {},
        repository: repository,
        getSettings: () => settings,
        updateSettings: (s) async => settings = s,
        healthRepository: healthRepo,
      );

      expect(res['isAvailable'], isTrue);
      expect(res['hasPermissions'], isTrue);
      expect(res['status'], 'connected');
      expect(res['supportedMetrics'], contains('steps'));
      expect(res['supportedMetrics'], contains('sleepDuration'));
    });

    // -------------------------------------------------------------
    // Center Circle Customization via MCP
    // -------------------------------------------------------------
    group('Center Circle Customization via update_dial_settings', () {
      test('supports all 6 centerClockDisplay modes and dateOfBirth', () async {
        final modes = [
          'digital',
          'analog',
          'dateTime',
          'countdown',
          'dobAge',
          'currentSubtask',
        ];

        for (final mode in modes) {
          final res = await McpTools.executeTool(
            name: 'update_dial_settings',
            arguments: {'centerClockDisplay': mode},
            repository: repository,
            getSettings: () => settings,
            updateSettings: (s) async => settings = s,
          );
          expect(res['success'], isTrue);
          expect(settings.centerClockDisplay.name, mode);
        }

        // Test dateOfBirth setting
        final dobRes = await McpTools.executeTool(
          name: 'update_dial_settings',
          arguments: {
            'centerClockDisplay': 'dobAge',
            'dateOfBirth': '1998-05-14',
          },
          repository: repository,
          getSettings: () => settings,
          updateSettings: (s) async => settings = s,
        );
        expect(dobRes['success'], isTrue);
        expect(settings.dateOfBirth, DateTime(1998, 5, 14));

        // Test clearing dateOfBirth
        final clearDobRes = await McpTools.executeTool(
          name: 'update_dial_settings',
          arguments: {'dateOfBirth': ''},
          repository: repository,
          getSettings: () => settings,
          updateSettings: (s) async => settings = s,
        );
        expect(clearDobRes['success'], isTrue);
        expect(settings.dateOfBirth, isNull);
      });

      test(
        'get_dial_settings returns current center circle configuration',
        () async {
          settings = settings.copyWith(
            centerClockDisplay: CenterClockDisplay.countdown,
            dateOfBirth: DateTime(1995, 10, 25),
          );

          final res = await McpTools.executeTool(
            name: 'get_dial_settings',
            arguments: {},
            repository: repository,
            getSettings: () => settings,
            updateSettings: (s) async => settings = s,
          );

          expect(res['centerClockDisplay'], 'countdown');
          expect(res['dateOfBirth'], '1995-10-25T00:00:00.000');
        },
      );
    });

    // -------------------------------------------------------------
    // get_clock_state with Center Circle and Active Subtask
    // -------------------------------------------------------------
    group('get_clock_state with Active Subtask & Center Modes', () {
      test(
        'returns center circle mode and resolves timed active subtask',
        () async {
          final now = DateTime.now();
          settings = settings.copyWith(
            centerClockDisplay: CenterClockDisplay.currentSubtask,
          );

          final parentEvent = SectorEvent(
            id: 'macro-1',
            title: 'Deep Focus Morning',
            start: now.subtract(const Duration(minutes: 30)),
            end: now.add(const Duration(minutes: 60)),
            subtaskItems: [
              SubtaskItem.create(
                parentEventId: 'macro-1',
                title: 'Past Completed Subtask',
                isCompleted: true,
                startTime: TimeOfDay(
                  hour: now.subtract(const Duration(minutes: 25)).hour,
                  minute: now.subtract(const Duration(minutes: 25)).minute,
                ),
                endTime: TimeOfDay(
                  hour: now.subtract(const Duration(minutes: 5)).hour,
                  minute: now.subtract(const Duration(minutes: 5)).minute,
                ),
              ),
              SubtaskItem.create(
                parentEventId: 'macro-1',
                title: 'Currently Running Subtask',
                startTime: TimeOfDay(
                  hour: now.subtract(const Duration(minutes: 5)).hour,
                  minute: now.subtract(const Duration(minutes: 5)).minute,
                ),
                endTime: TimeOfDay(
                  hour: now.add(const Duration(minutes: 20)).hour,
                  minute: now.add(const Duration(minutes: 20)).minute,
                ),
              ),
              SubtaskItem.create(
                parentEventId: 'macro-1',
                title: 'Upcoming Subtask',
                startTime: TimeOfDay(
                  hour: now.add(const Duration(minutes: 25)).hour,
                  minute: now.add(const Duration(minutes: 25)).minute,
                ),
                endTime: TimeOfDay(
                  hour: now.add(const Duration(minutes: 50)).hour,
                  minute: now.add(const Duration(minutes: 50)).minute,
                ),
              ),
            ],
          );
          await repository.addEvent(parentEvent);

          final res = await McpTools.executeTool(
            name: 'get_clock_state',
            arguments: {},
            repository: repository,
            getSettings: () => settings,
            updateSettings: (s) async => settings = s,
          );

          expect(res['centerClockDisplay'], 'currentSubtask');
          expect(res['activeEvent'], isNotNull);
          expect(res['activeEvent']['id'], 'macro-1');
          expect(res['activeSubtask'], isNotNull);
          expect(res['activeSubtask']['title'], 'Currently Running Subtask');
        },
      );

      test(
        'falls back to first uncompleted subtask when no timed subtasks match',
        () async {
          final now = DateTime.now();
          final parentEvent = SectorEvent(
            id: 'macro-fallback',
            title: 'Macro Coding',
            start: now.subtract(const Duration(minutes: 10)),
            end: now.add(const Duration(minutes: 50)),
            subtaskItems: [
              SubtaskItem.create(
                parentEventId: 'macro-fallback',
                title: 'Subtask 1 Done',
                isCompleted: true,
              ),
              SubtaskItem.create(
                parentEventId: 'macro-fallback',
                title: 'Subtask 2 Next Pending',
                isCompleted: false,
              ),
            ],
          );
          await repository.addEvent(parentEvent);

          final res = await McpTools.executeTool(
            name: 'get_clock_state',
            arguments: {},
            repository: repository,
            getSettings: () => settings,
            updateSettings: (s) async => settings = s,
          );

          expect(res['activeSubtask'], isNotNull);
          expect(res['activeSubtask']['title'], 'Subtask 2 Next Pending');
        },
      );

      test('returns null activeSubtask when all subtasks in active event are completed', () async {
        final now = DateTime.now();
        final parentEvent = SectorEvent(
          id: 'macro-all-done',
          title: 'Macro Review',
          start: now.subtract(const Duration(minutes: 10)),
          end: now.add(const Duration(minutes: 50)),
          subtaskItems: [
            SubtaskItem.create(
              parentEventId: 'macro-all-done',
              title: 'Step 1',
              isCompleted: true,
            ),
            SubtaskItem.create(
              parentEventId: 'macro-all-done',
              title: 'Step 2',
              isCompleted: true,
            ),
          ],
        );
        await repository.addEvent(parentEvent);

        final res = await McpTools.executeTool(
          name: 'get_clock_state',
          arguments: {},
          repository: repository,
          getSettings: () => settings,
          updateSettings: (s) async => settings = s,
        );

        expect(res['activeSubtask'], isNull);
      });
    });

    // -------------------------------------------------------------
    // manage_subtask CRUD & Edge Cases
    // -------------------------------------------------------------
    group('manage_subtask CRUD and Edge Cases', () {
      late SectorEvent testParent;

      setUp(() async {
        final today = DateTime.now();
        testParent = SectorEvent(
          id: 'parent-event-42',
          title: 'Main Sprint Block',
          start: DateTime(today.year, today.month, today.day, 10, 0),
          end: DateTime(today.year, today.month, today.day, 12, 0),
        );
        await repository.addEvent(testParent);
      });

      test(
        'action "add" creates a subtask with full time bounds and reminder',
        () async {
          final res = await McpTools.executeTool(
            name: 'manage_subtask',
            arguments: {
              'action': 'add',
              'parentEventId': 'parent-event-42',
              'title': 'API Client Implementation',
              'startTime': '10:15',
              'endTime': '11:00',
              'reminderMinutes': 10,
              'isUnlimited': false,
            },
            repository: repository,
            getSettings: () => settings,
            updateSettings: (s) async => settings = s,
          );

          expect(res['success'], isTrue);
          expect(res['action'], 'add');
          final subtask = res['subtask'] as Map<String, dynamic>;
          expect(subtask['title'], 'API Client Implementation');
          expect(subtask['startHour'], 10);
          expect(subtask['startMinute'], 15);
          expect(subtask['endHour'], 11);
          expect(subtask['endMinute'], 0);
          expect(subtask['reminderMinutes'], 10);

          // Verify repository state
          final all = await repository.getAllEvents();
          final updatedParent = all.firstWhere(
            (e) => e.id == 'parent-event-42',
          );
          expect(updatedParent.subtaskItems.length, 1);
          expect(
            updatedParent.subtaskItems.first.title,
            'API Client Implementation',
          );
        },
      );

      test('action "add" rejects empty title or non-existent parent', () async {
        // Empty title
        final emptyRes = await McpTools.executeTool(
          name: 'manage_subtask',
          arguments: {
            'action': 'add',
            'parentEventId': 'parent-event-42',
            'title': '   ',
          },
          repository: repository,
          getSettings: () => settings,
          updateSettings: (s) async => settings = s,
        );
        expect(emptyRes['success'], isFalse);
        expect(emptyRes['error'], contains('title cannot be empty'));

        // Non-existent parent
        final nonExistentRes = await McpTools.executeTool(
          name: 'manage_subtask',
          arguments: {
            'action': 'add',
            'parentEventId': 'does-not-exist',
            'title': 'Valid Title',
          },
          repository: repository,
          getSettings: () => settings,
          updateSettings: (s) async => settings = s,
        );
        expect(nonExistentRes['success'], isFalse);
        expect(nonExistentRes['error'], contains('Parent event not found'));
      });

      test('action "update" updates existing subtask fields', () async {
        // First add subtask
        final addRes = await McpTools.executeTool(
          name: 'manage_subtask',
          arguments: {
            'action': 'add',
            'parentEventId': 'parent-event-42',
            'title': 'Original Subtask',
          },
          repository: repository,
          getSettings: () => settings,
          updateSettings: (s) async => settings = s,
        );
        final subId = addRes['subtask']['id'] as String;

        // Now update
        final updateRes = await McpTools.executeTool(
          name: 'manage_subtask',
          arguments: {
            'action': 'update',
            'parentEventId': 'parent-event-42',
            'subtaskId': subId,
            'title': 'Renamed Subtask',
            'startTime': '10:30',
            'endTime': '11:15',
            'isUnlimited': true,
          },
          repository: repository,
          getSettings: () => settings,
          updateSettings: (s) async => settings = s,
        );

        expect(updateRes['success'], isTrue);
        expect(updateRes['subtask']['title'], 'Renamed Subtask');
        expect(updateRes['subtask']['startHour'], 10);
        expect(updateRes['subtask']['startMinute'], 30);
        expect(updateRes['subtask']['isUnlimited'], isTrue);

        final all = await repository.getAllEvents();
        final updatedParent = all.firstWhere((e) => e.id == 'parent-event-42');
        expect(updatedParent.subtaskItems.first.title, 'Renamed Subtask');
      });

      test('action "update" fails if subtaskId not found', () async {
        final res = await McpTools.executeTool(
          name: 'manage_subtask',
          arguments: {
            'action': 'update',
            'parentEventId': 'parent-event-42',
            'subtaskId': 'non-existent-subtask',
            'title': 'Ghost',
          },
          repository: repository,
          getSettings: () => settings,
          updateSettings: (s) async => settings = s,
        );
        expect(res['success'], isFalse);
        expect(res['error'], contains('Subtask not found with id'));
      });

      test(
        'action "toggle_complete" flips or explicitly sets isCompleted',
        () async {
          final addRes = await McpTools.executeTool(
            name: 'manage_subtask',
            arguments: {
              'action': 'add',
              'parentEventId': 'parent-event-42',
              'title': 'Toggleable Item',
            },
            repository: repository,
            getSettings: () => settings,
            updateSettings: (s) async => settings = s,
          );
          final subId = addRes['subtask']['id'] as String;

          // Toggle to true
          final tog1 = await McpTools.executeTool(
            name: 'manage_subtask',
            arguments: {
              'action': 'toggle_complete',
              'parentEventId': 'parent-event-42',
              'subtaskId': subId,
            },
            repository: repository,
            getSettings: () => settings,
            updateSettings: (s) async => settings = s,
          );
          expect(tog1['success'], isTrue);
          expect(tog1['isCompleted'], isTrue);

          // Toggle back to false
          final tog2 = await McpTools.executeTool(
            name: 'manage_subtask',
            arguments: {
              'action': 'toggle_complete',
              'parentEventId': 'parent-event-42',
              'subtaskId': subId,
            },
            repository: repository,
            getSettings: () => settings,
            updateSettings: (s) async => settings = s,
          );
          expect(tog2['success'], isTrue);
          expect(tog2['isCompleted'], isFalse);

          // Explicitly set true
          final tog3 = await McpTools.executeTool(
            name: 'manage_subtask',
            arguments: {
              'action': 'toggle_complete',
              'parentEventId': 'parent-event-42',
              'subtaskId': subId,
              'isCompleted': true,
            },
            repository: repository,
            getSettings: () => settings,
            updateSettings: (s) async => settings = s,
          );
          expect(tog3['isCompleted'], isTrue);
        },
      );

      test('action "delete" removes the subtask from parent event', () async {
        final addRes = await McpTools.executeTool(
          name: 'manage_subtask',
          arguments: {
            'action': 'add',
            'parentEventId': 'parent-event-42',
            'title': 'Subtask to Delete',
          },
          repository: repository,
          getSettings: () => settings,
          updateSettings: (s) async => settings = s,
        );
        final subId = addRes['subtask']['id'] as String;

        final delRes = await McpTools.executeTool(
          name: 'manage_subtask',
          arguments: {
            'action': 'delete',
            'parentEventId': 'parent-event-42',
            'subtaskId': subId,
          },
          repository: repository,
          getSettings: () => settings,
          updateSettings: (s) async => settings = s,
        );
        expect(delRes['success'], isTrue);
        expect(delRes['deletedSubtaskId'], subId);

        final all = await repository.getAllEvents();
        final updatedParent = all.firstWhere((e) => e.id == 'parent-event-42');
        expect(updatedParent.subtaskItems, isEmpty);
      });

      test(
        'returns error for invalid action or missing required arguments',
        () async {
          // Missing parentEventId
          final missingParent = await McpTools.executeTool(
            name: 'manage_subtask',
            arguments: {'action': 'add'},
            repository: repository,
            getSettings: () => settings,
            updateSettings: (s) async => settings = s,
          );
          expect(missingParent['success'], isFalse);

          // Invalid action
          final invalidAction = await McpTools.executeTool(
            name: 'manage_subtask',
            arguments: {
              'action': 'invalid_unknown_action',
              'parentEventId': 'parent-event-42',
            },
            repository: repository,
            getSettings: () => settings,
            updateSettings: (s) async => settings = s,
          );
          expect(invalidAction['success'], isFalse);
          expect(invalidAction['error'], contains('Invalid action'));
        },
      );
    });

    // -------------------------------------------------------------
    // Main Blocks & Rich Subtasks Across Schedulers
    // -------------------------------------------------------------
    group('Main Blocks & Rich Subtasks Edge Cases', () {
      test('schedule_sector accepts rich subtask objects with specific time windows', () async {
        final today = DateTime.now();
        final res = await McpTools.executeTool(
          name: 'schedule_sector',
          arguments: {
            'title': 'Macro Workshop',
            'start': DateTime(
              today.year,
              today.month,
              today.day,
              14,
              0,
            ).toIso8601String(),
            'end': DateTime(
              today.year,
              today.month,
              today.day,
              16,
              0,
            ).toIso8601String(),
            'subtaskItems': [
              {
                'title': 'Keynote Presentation',
                'startHour': 14,
                'startMinute': 0,
                'endHour': 14,
                'endMinute': 45,
              },
              {
                'title': 'Q&A Discussion',
                'startHour': 14,
                'startMinute': 45,
                'endHour': 15,
                'endMinute': 30,
              },
            ],
          },
          repository: repository,
          getSettings: () => settings,
          updateSettings: (s) async => settings = s,
        );

        expect(res['success'], isTrue);
        final sector = res['sector'] as Map<String, dynamic>;
        final subtaskItems = sector['subtaskItems'] as List<dynamic>;
        expect(subtaskItems.length, 2);
        expect(subtaskItems[0]['title'], 'Keynote Presentation');
        expect(subtaskItems[0]['startHour'], 14);
        expect(subtaskItems[1]['title'], 'Q&A Discussion');
      });

      test('update_sector on an event scheduled for a different date works (cross-date lookup)', () async {
        // Event scheduled for tomorrow
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        final futureEvent = SectorEvent(
          id: 'future-event-99',
          title: 'Future Milestone',
          start: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10, 0),
          end: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 11, 0),
        );
        await repository.addEvent(futureEvent);

        final updateRes = await McpTools.executeTool(
          name: 'update_sector',
          arguments: {
            'id': 'future-event-99',
            'title': 'Updated Future Milestone',
          },
          repository: repository,
          getSettings: () => settings,
          updateSettings: (s) async => settings = s,
        );

        expect(updateRes['success'], isTrue);
        final updated = updateRes['sector'] as Map<String, dynamic>;
        expect(updated['title'], 'Updated Future Milestone');
      });

      test('delete_sector on an event scheduled for a different date removes it cleanly', () async {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final pastEvent = SectorEvent(
          id: 'past-event-77',
          title: 'Old History Block',
          start: DateTime(yesterday.year, yesterday.month, yesterday.day, 9, 0),
          end: DateTime(yesterday.year, yesterday.month, yesterday.day, 10, 0),
        );
        await repository.addEvent(pastEvent);

        final delRes = await McpTools.executeTool(
          name: 'delete_sector',
          arguments: {'id': 'past-event-77'},
          repository: repository,
          getSettings: () => settings,
          updateSettings: (s) async => settings = s,
        );

        expect(delRes['success'], isTrue);
        expect(delRes['deletedId'], 'past-event-77');
        final all = await repository.getAllEvents();
        expect(all.any((e) => e.id == 'past-event-77'), isFalse);
      });

      test('schedule_sector validates chronological end after start', () async {
        final today = DateTime.now();
        final res = await McpTools.executeTool(
          name: 'schedule_sector',
          arguments: {
            'title': 'Invalid Time Order',
            'start': DateTime(
              today.year,
              today.month,
              today.day,
              15,
              0,
            ).toIso8601String(),
            'end': DateTime(
              today.year,
              today.month,
              today.day,
              14,
              0,
            ).toIso8601String(),
          },
          repository: repository,
          getSettings: () => settings,
          updateSettings: (s) async => settings = s,
        );

        expect(res['success'], isFalse);
        expect(
          res['error'],
          contains('End time must be strictly after start time'),
        );
      });
    });

    // -------------------------------------------------------------
    // Date & Time Edge Cases (Midnight Crossing & Leap Day)
    // -------------------------------------------------------------
    group('Date & Time Edge Cases', () {
      test('handles event crossing midnight cleanly', () async {
        final today = DateTime.now();
        final start = DateTime(today.year, today.month, today.day, 23, 30);
        final end = DateTime(today.year, today.month, today.day + 1, 1, 30);

        final res = await McpTools.executeTool(
          name: 'schedule_sector',
          arguments: {
            'title': 'Late Night Session',
            'start': start.toIso8601String(),
            'end': end.toIso8601String(),
            'category': 'Rest',
          },
          repository: repository,
          getSettings: () => settings,
          updateSettings: (s) async => settings = s,
        );

        expect(res['success'], isTrue);
        final sector = res['sector'] as Map<String, dynamic>;
        expect(sector['title'], 'Late Night Session');
      });

      test(
        'handles leap day (2028-02-29) schedule and query without crash',
        () async {
          final res = await McpTools.executeTool(
            name: 'schedule_sector',
            arguments: {
              'title': 'Leap Day Event',
              'start': DateTime(2028, 2, 29, 10, 0).toIso8601String(),
              'end': DateTime(2028, 2, 29, 12, 0).toIso8601String(),
            },
            repository: repository,
            getSettings: () => settings,
            updateSettings: (s) async => settings = s,
          );

          expect(res['success'], isTrue);
          final listRes = await McpTools.executeTool(
            name: 'list_sectors',
            arguments: {'date': '2028-02-29'},
            repository: repository,
            getSettings: () => settings,
            updateSettings: (s) async => settings = s,
          );
          expect(listRes['count'], 1);
        },
      );
    });

    // -------------------------------------------------------------
    // Health Data Edge Cases
    // -------------------------------------------------------------
    group('Health Data Edge Cases', () {
      test('get_health_summary handles zero activity and zero sleep debt without division errors', () async {
        final mockService = MockHealthService();
        final today = DateTime.now();
        mockService.addSummary(
          DailyHealthSummary(
            date: DateTime(today.year, today.month, today.day),
            steps: 0,
            activeCalories: 0.0,
            totalCalories: 0.0,
            distanceMeters: 0.0,
            sleepDurationMinutes: 0,
            exerciseSessions: const [],
            lastSyncTime: today,
          ),
        );
        final healthRepo = HealthRepositoryImpl(service: mockService);

        final res = await McpTools.executeTool(
          name: 'get_health_summary',
          arguments: {'date': today.toIso8601String().substring(0, 10)},
          repository: repository,
          getSettings: () => settings,
          updateSettings: (s) async => settings = s,
          healthRepository: healthRepo,
        );

        expect(res['steps'], 0);
        expect(res['sleepHoursFormatted'], '0h 0m');
        expect(res['sleepDebtMinutes'], 0); // 0 when no sleep session recorded
        expect(res['hasSignificantSleepDebt'], isFalse);

        // Test with 6h sleep (360m), expecting 120m sleep debt
        final debtSummary = DailyHealthSummary(
          date: DateTime(today.year, today.month, today.day),
          steps: 4000,
          sleepDurationMinutes: 360,
          lastSyncTime: today,
        );
        mockService.addSummary(debtSummary);
        final debtRes = await McpTools.executeTool(
          name: 'get_health_summary',
          arguments: {'date': today.toIso8601String().substring(0, 10)},
          repository: repository,
          getSettings: () => settings,
          updateSettings: (s) async => settings = s,
          healthRepository: healthRepo,
        );
        expect(debtRes['sleepDebtMinutes'], 120);
        expect(debtRes['hasSignificantSleepDebt'], isTrue);
      });

      test(
        'sync_health_to_dial is idempotent when synced multiple times',
        () async {
          final mockService = MockHealthService();
          final today = DateTime.now();
          mockService.addSummary(
            DailyHealthSummary(
              date: DateTime(today.year, today.month, today.day),
              steps: 5000,
              sleepDurationMinutes: 450,
              sleepStart: DateTime(
                today.year,
                today.month,
                today.day - 1,
                23,
                0,
              ),
              sleepEnd: DateTime(today.year, today.month, today.day, 6, 30),
              exerciseSessions: [
                HealthExerciseSession(
                  id: 'idempotent-workout-1',
                  title: 'Cycling',
                  type: 'biking',
                  start: DateTime(today.year, today.month, today.day, 17, 0),
                  end: DateTime(today.year, today.month, today.day, 18, 0),
                  caloriesBurned: 350.0,
                ),
              ],
              lastSyncTime: today,
            ),
          );
          final healthRepo = HealthRepositoryImpl(service: mockService);

          // 1st sync: 2 sessions added
          final firstSync = await McpTools.executeTool(
            name: 'sync_health_to_dial',
            arguments: {'date': today.toIso8601String().substring(0, 10)},
            repository: repository,
            getSettings: () => settings,
            updateSettings: (s) async => settings = s,
            healthRepository: healthRepo,
          );
          expect(firstSync['syncedSessionsCount'], 2);

          // 2nd sync immediately after: 0 duplicate sessions added
          final secondSync = await McpTools.executeTool(
            name: 'sync_health_to_dial',
            arguments: {'date': today.toIso8601String().substring(0, 10)},
            repository: repository,
            getSettings: () => settings,
            updateSettings: (s) async => settings = s,
            healthRepository: healthRepo,
          );
          expect(secondSync['syncedSessionsCount'], 0);
        },
      );
    });

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
