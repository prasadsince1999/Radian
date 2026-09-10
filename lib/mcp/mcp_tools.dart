import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../domain/models/dial_settings.dart';
import '../domain/models/sector_event.dart';
import '../domain/repositories/event_repository.dart';

/// Catalog and executor for all MCP tools supported by Sectograph.
class McpTools {
  McpTools._();

  static List<Map<String, dynamic>> getToolDefinitions() {
    return [
      {
        'name': 'get_clock_state',
        'description': 'Inspect current dial state, current time, active event taking place right now, and next upcoming events.',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'date': {
              'type': 'string',
              'description': 'Optional ISO date (YYYY-MM-DD) to inspect. Defaults to today.',
            },
          },
        },
      },
      {
        'name': 'list_sectors',
        'description': 'List all scheduled circular sectors (events) for a specific date, including angles and radial tracks.',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'date': {
              'type': 'string',
              'description':
                  'Target date in YYYY-MM-DD format. Defaults to today.',
            },
          },
        },
      },
      {
        'name': 'find_free_gaps',
        'description': 'Find all unoccupied intervals on the circular dial where new tasks can be scheduled without overlap.',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'date': {
              'type': 'string',
              'description':
                  'Target date in YYYY-MM-DD format. Defaults to today.',
            },
            'minDurationMinutes': {
              'type': 'integer',
              'description': 'Minimum gap duration in minutes. Defaults to 15.',
            },
          },
        },
      },
      {
        'name': 'bulk_schedule_sectors',
        'description': 'Schedule multiple time blocks on the circular dial in a single call. Use this to plan an entire morning, afternoon, or full day with one prompt.',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'events': {
              'type': 'array',
              'description': 'List of events to schedule.',
              'items': {
                'type': 'object',
                'properties': {
                  'title': {'type': 'string'},
                  'start': {
                    'type': 'string',
                    'description': 'ISO 8601 start time',
                  },
                  'end': {'type': 'string', 'description': 'ISO 8601 end time'},
                  'category': {
                    'type': 'string',
                    'description':
                        'Category e.g. Work, Fitness, Rest, Learning',
                  },
                  'colorHex': {
                    'type': 'string',
                    'description': 'Hex color code e.g. #6366F1',
                  },
                  'notes': {'type': 'string'},
                },
                'required': ['title', 'start', 'end'],
              },
            },
          },
          'required': ['events'],
        },
      },
      {
        'name': 'replace_day_schedule',
        'description': 'Atomically wipe and replace an entire day\'s schedule with a freshly planned set of time blocks.',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'date': {
              'type': 'string',
              'description': 'Target date in YYYY-MM-DD',
            },
            'events': {
              'type': 'array',
              'description':
                  'Complete replacement list of events for this day.',
              'items': {
                'type': 'object',
                'properties': {
                  'title': {'type': 'string'},
                  'start': {'type': 'string'},
                  'end': {'type': 'string'},
                  'category': {'type': 'string'},
                  'colorHex': {'type': 'string'},
                  'notes': {'type': 'string'},
                },
                'required': ['title', 'start', 'end'],
              },
            },
          },
          'required': ['date', 'events'],
        },
      },
      {
        'name': 'smart_auto_plan',
        'description': 'Automatically fits a list of requested tasks into available free gaps on the circular dial without overlaps.',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'date': {
              'type': 'string',
              'description': 'Target date (YYYY-MM-DD)',
            },
            'tasks': {
              'type': 'array',
              'items': {
                'type': 'object',
                'properties': {
                  'title': {'type': 'string'},
                  'durationMinutes': {'type': 'integer'},
                  'category': {'type': 'string'},
                  'colorHex': {'type': 'string'},
                },
                'required': ['title', 'durationMinutes'],
              },
            },
          },
          'required': ['tasks'],
        },
      },
      {
        'name': 'schedule_sector',
        'description': 'Schedule a single time block sector on the dial.',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'title': {'type': 'string'},
            'start': {'type': 'string', 'description': 'ISO 8601 start time'},
            'end': {'type': 'string', 'description': 'ISO 8601 end time'},
            'category': {'type': 'string'},
            'colorHex': {'type': 'string'},
            'notes': {'type': 'string'},
          },
          'required': ['title', 'start', 'end'],
        },
      },
      {
        'name': 'update_sector',
        'description': 'Update an existing sector by ID.',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'id': {'type': 'string'},
            'title': {'type': 'string'},
            'start': {'type': 'string'},
            'end': {'type': 'string'},
            'category': {'type': 'string'},
            'colorHex': {'type': 'string'},
            'notes': {'type': 'string'},
          },
          'required': ['id'],
        },
      },
      {
        'name': 'delete_sector',
        'description': 'Delete a sector from the dial by ID.',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'id': {'type': 'string'},
          },
          'required': ['id'],
        },
      },
      {
        'name': 'clear_sectors',
        'description': 'Clear all sectors for a date or clear by category.',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'date': {'type': 'string', 'description': 'YYYY-MM-DD'},
          },
          'required': ['date'],
        },
      },
      {
        'name': 'get_dial_settings',
        'description': 'Inspect current visual customization settings (12h/24h mode, theme, accent color, styles).',
        'inputSchema': {'type': 'object', 'properties': {}},
      },
      {
        'name': 'update_dial_settings',
        'description': 'Remotely customize dial appearance and operation (12h/24h mode, theme, seed accent color, tick style, hand style).',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'is24HourMode': {'type': 'boolean'},
            'themeMode': {
              'type': 'string',
              'enum': ['system', 'light', 'dark'],
            },
            'seedColorHex': {
              'type': 'string',
              'description': 'Hex color code e.g. #10B981',
            },
            'faceStyle': {
              'type': 'string',
              'enum': ['classicTicks', 'minimal', 'numbered', 'radialSegments'],
            },
            'sectorStyle': {
              'type': 'string',
              'enum': ['solid', 'outline', 'softGradient', 'roundedCaps'],
            },
            'handStyle': {
              'type': 'string',
              'enum': ['sleekNeedle', 'glowingArrow', 'minimalDot'],
            },
          },
        },
      },
      {
        'name': 'analyze_day_balance',
        'description': 'Analyze time distribution across categories, total scheduled hours, and free time percentage.',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'date': {'type': 'string', 'description': 'YYYY-MM-DD'},
          },
        },
      },
    ];
  }

  static Future<Map<String, dynamic>> executeTool({
    required String name,
    required Map<String, dynamic> arguments,
    required EventRepository repository,
    required DialSettings Function() getSettings,
    required Future<void> Function(DialSettings) updateSettings,
  }) async {
    final now = DateTime.now();

    DateTime parseDate(dynamic d) {
      if (d is String && d.isNotEmpty) {
        return DateTime.parse(d);
      }
      return DateTime(now.year, now.month, now.day);
    }

    switch (name) {
      case 'get_clock_state':
        final targetDate = parseDate(arguments['date']);
        final events = await repository.getEventsForDay(targetDate);
        final settings = getSettings();

        SectorEvent? active;
        for (final e in events) {
          if (e.isCurrentlyActive(now)) {
            active = e;
            break;
          }
        }

        final upcoming = events.where((e) => e.start.isAfter(now)).toList()
          ..sort((a, b) => a.start.compareTo(b.start));

        return {
          'currentTime': now.toIso8601String(),
          'date': targetDate.toIso8601String().substring(0, 10),
          'is24HourMode': settings.is24HourMode,
          'activeEvent': active?.toJson(),
          'activeEventRemainingMinutes': active != null
              ? active.end.difference(now).inMinutes
              : 0,
          'totalEventsToday': events.length,
          'upcomingEvents': upcoming.take(3).map((e) => e.toJson()).toList(),
        };

      case 'list_sectors':
        final targetDate = parseDate(arguments['date']);
        final events = await repository.getEventsForDay(targetDate);
        return {
          'date': targetDate.toIso8601String().substring(0, 10),
          'count': events.length,
          'sectors': events.map((e) => e.toJson()).toList(),
        };

      case 'find_free_gaps':
        final targetDate = parseDate(arguments['date']);
        final minMins = arguments['minDurationMinutes'] as int? ?? 15;
        final gaps = await repository.findFreeGaps(
          day: targetDate,
          is24HourMode: getSettings().is24HourMode,
          minDuration: Duration(minutes: minMins),
        );
        return {
          'date': targetDate.toIso8601String().substring(0, 10),
          'freeGapsCount': gaps.length,
          'gaps': gaps.map((g) => g.toJson()).toList(),
        };

      case 'bulk_schedule_sectors':
        final rawEvents = arguments['events'] as List<dynamic>? ?? [];
        final created = <SectorEvent>[];

        for (final item in rawEvents) {
          final m = item as Map<String, dynamic>;
          final event = SectorEvent(
            id: const Uuid().v4(),
            title: m['title'] as String,
            start: DateTime.parse(m['start'] as String),
            end: DateTime.parse(m['end'] as String),
            category: m['category'] as String? ?? 'General',
            colorHex: m['colorHex'] as String? ?? '#6366F1',
            notes: m['notes'] as String? ?? '',
          );
          created.add(event);
        }

        await repository.bulkAddEvents(created);
        return {
          'success': true,
          'scheduledCount': created.length,
          'sectors': created.map((e) => e.toJson()).toList(),
        };

      case 'replace_day_schedule':
        final targetDate = parseDate(arguments['date']);
        final rawEvents = arguments['events'] as List<dynamic>? ?? [];
        final replacement = <SectorEvent>[];

        for (final item in rawEvents) {
          final m = item as Map<String, dynamic>;
          final event = SectorEvent(
            id: const Uuid().v4(),
            title: m['title'] as String,
            start: DateTime.parse(m['start'] as String),
            end: DateTime.parse(m['end'] as String),
            category: m['category'] as String? ?? 'General',
            colorHex: m['colorHex'] as String? ?? '#6366F1',
            notes: m['notes'] as String? ?? '',
          );
          replacement.add(event);
        }

        await repository.replaceDayEvents(targetDate, replacement);
        return {
          'success': true,
          'date': targetDate.toIso8601String().substring(0, 10),
          'newEventsCount': replacement.length,
          'sectors': replacement.map((e) => e.toJson()).toList(),
        };

      case 'smart_auto_plan':
        final targetDate = parseDate(arguments['date']);
        final rawTasks = arguments['tasks'] as List<dynamic>? ?? [];
        final gaps = await repository.findFreeGaps(
          day: targetDate,
          is24HourMode: getSettings().is24HourMode,
          minDuration: const Duration(minutes: 15),
        );

        final scheduled = <SectorEvent>[];
        var gapIdx = 0;
        var currentGapStart = gaps.isNotEmpty ? gaps[0].start : null;
        var currentGapEnd = gaps.isNotEmpty ? gaps[0].end : null;

        for (final t in rawTasks) {
          final tm = t as Map<String, dynamic>;
          final durationMins = tm['durationMinutes'] as int? ?? 30;
          final duration = Duration(minutes: durationMins);

          // Find a gap that can accommodate duration
          while (gapIdx < gaps.length) {
            final gapRemaining = currentGapEnd!.difference(currentGapStart!);
            if (gapRemaining >= duration) {
              final taskStart = currentGapStart;
              final taskEnd = taskStart.add(duration);

              final event = SectorEvent(
                id: const Uuid().v4(),
                title: tm['title'] as String,
                start: taskStart,
                end: taskEnd,
                category: tm['category'] as String? ?? 'Focus',
                colorHex: tm['colorHex'] as String? ?? '#10B981',
              );
              scheduled.add(event);
              currentGapStart = taskEnd;
              break;
            } else {
              gapIdx++;
              if (gapIdx < gaps.length) {
                currentGapStart = gaps[gapIdx].start;
                currentGapEnd = gaps[gapIdx].end;
              }
            }
          }
        }

        if (scheduled.isNotEmpty) {
          await repository.bulkAddEvents(scheduled);
        }

        return {
          'success': true,
          'autoScheduledCount': scheduled.length,
          'scheduled': scheduled.map((e) => e.toJson()).toList(),
        };

      case 'schedule_sector':
        final event = SectorEvent(
          id: const Uuid().v4(),
          title: arguments['title'] as String,
          start: DateTime.parse(arguments['start'] as String),
          end: DateTime.parse(arguments['end'] as String),
          category: arguments['category'] as String? ?? 'General',
          colorHex: arguments['colorHex'] as String? ?? '#6366F1',
          notes: arguments['notes'] as String? ?? '',
        );
        await repository.addEvent(event);
        return {'success': true, 'sector': event.toJson()};

      case 'update_sector':
        final id = arguments['id'] as String;
        final events = await repository.getEventsForDay(now);
        final existing = events.firstWhere(
          (e) => e.id == id,
          orElse: () => throw Exception('Sector not found with id: $id'),
        );

        final updated = existing.copyWith(
          title: arguments['title'] as String?,
          start: arguments['start'] != null
              ? DateTime.parse(arguments['start'] as String)
              : null,
          end: arguments['end'] != null
              ? DateTime.parse(arguments['end'] as String)
              : null,
          category: arguments['category'] as String?,
          colorHex: arguments['colorHex'] as String?,
          notes: arguments['notes'] as String?,
        );
        await repository.updateEvent(updated);
        return {'success': true, 'sector': updated.toJson()};

      case 'delete_sector':
        final id = arguments['id'] as String;
        await repository.deleteEvent(id);
        return {'success': true, 'deletedId': id};

      case 'clear_sectors':
        final targetDate = parseDate(arguments['date']);
        await repository.clearEventsForDay(targetDate);
        return {
          'success': true,
          'date': targetDate.toIso8601String().substring(0, 10),
        };

      case 'get_dial_settings':
        return getSettings().toJson();

      case 'update_dial_settings':
        final current = getSettings();
        var updated = current.copyWith(
          is24HourMode: arguments['is24HourMode'] as bool?,
          seedColorHex: arguments['seedColorHex'] as String?,
        );
        if (arguments['themeMode'] != null) {
          updated = updated.copyWith(
            themeMode: ThemeMode.values.firstWhere(
              (e) => e.name == arguments['themeMode'],
              orElse: () => updated.themeMode,
            ),
          );
        }
        if (arguments['faceStyle'] != null) {
          updated = updated.copyWith(
            faceStyle: DialFaceStyle.values.firstWhere(
              (e) => e.name == arguments['faceStyle'],
              orElse: () => updated.faceStyle,
            ),
          );
        }
        if (arguments['sectorStyle'] != null) {
          updated = updated.copyWith(
            sectorStyle: SectorVisualTheme.values.firstWhere(
              (e) => e.name == arguments['sectorStyle'],
              orElse: () => updated.sectorStyle,
            ),
          );
        }
        if (arguments['handStyle'] != null) {
          updated = updated.copyWith(
            handStyle: HandStyle.values.firstWhere(
              (e) => e.name == arguments['handStyle'],
              orElse: () => updated.handStyle,
            ),
          );
        }
        await updateSettings(updated);
        return {'success': true, 'settings': updated.toJson()};

      case 'analyze_day_balance':
        final targetDate = parseDate(arguments['date']);
        final events = await repository.getEventsForDay(targetDate);
        final categoryMinutes = <String, int>{};
        var totalScheduledMinutes = 0;

        for (final e in events) {
          final mins = e.duration.inMinutes;
          totalScheduledMinutes += mins;
          categoryMinutes[e.category] =
              (categoryMinutes[e.category] ?? 0) + mins;
        }

        return {
          'date': targetDate.toIso8601String().substring(0, 10),
          'totalEvents': events.length,
          'totalScheduledMinutes': totalScheduledMinutes,
          'totalScheduledHours': (totalScheduledMinutes / 60.0).toStringAsFixed(
            1,
          ),
          'categoryBreakdown': categoryMinutes.map(
            (k, v) => MapEntry(k, {
              'minutes': v,
              'hours': (v / 60.0).toStringAsFixed(1),
            }),
          ),
        };

      default:
        throw Exception('Unknown tool: $name');
    }
  }
}
