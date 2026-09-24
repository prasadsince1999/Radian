import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../core/services/health_service.dart';
import '../data/repositories/health_repository_impl.dart';
import '../domain/models/dial_settings.dart';
import '../domain/models/sector_event.dart';
import '../domain/models/subtask_item.dart';
import '../domain/repositories/event_repository.dart';
import '../domain/repositories/health_repository.dart';
import '../domain/use_cases/sync_health_sessions_use_case.dart';

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
                  'subtasks': {
                    'type': 'array',
                    'items': {'type': 'string'},
                    'description': 'List of subtask titles or checklist items',
                  },
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
                  'subtasks': {
                    'type': 'array',
                    'items': {'type': 'string'},
                    'description': 'List of subtasks for this block',
                  },
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
                  'subtasks': {
                    'type': 'array',
                    'items': {'type': 'string'},
                    'description': 'List of subtasks for this task',
                  },
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
            'subtasks': {
              'type': 'array',
              'items': {'type': 'string'},
              'description': 'List of subtask titles or checklist items',
            },
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
            'subtasks': {
              'type': 'array',
              'items': {'type': 'string'},
              'description':
                  'Updated list of subtasks (or empty list to clear)',
            },
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
        'description': 'Remotely customize dial appearance and operation (12h/24h mode, theme, seed accent color, tick style, hand style, center circle display mode, date of birth).',
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
            'centerClockDisplay': {
              'type': 'string',
              'enum': [
                'digital',
                'analog',
                'dateTime',
                'countdown',
                'dobAge',
                'currentSubtask',
              ],
              'description': 'Center circle customization mode: digital (digital clock), analog (classic ticking hands), dateTime (current date + time), countdown (time remaining or countdown to next block), dobAge (Life Clock based on date of birth), or currentSubtask (currently active micro-task).',
            },
            'dateOfBirth': {
              'type': 'string',
              'description': 'Date of birth in YYYY-MM-DD format (used by dobAge Life Clock), or empty string/null to clear.',
            },
          },
        },
      },
      {
        'name': 'manage_subtask',
        'description': 'Add, update, toggle completion, or delete micro-subtasks within a parent macro time block on the circular dial.',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'action': {
              'type': 'string',
              'enum': ['add', 'update', 'toggle_complete', 'delete'],
              'description': 'Subtask operation to execute.',
            },
            'parentEventId': {
              'type': 'string',
              'description': 'ID of the parent macro block (event).',
            },
            'subtaskId': {
              'type': 'string',
              'description': 'ID of the subtask (required for update, toggle_complete, delete).',
            },
            'title': {
              'type': 'string',
              'description': 'Title or description of the subtask.',
            },
            'startTime': {
              'type': 'string',
              'description': 'Start time within day in HH:mm 24h format (e.g. "09:30" or "14:15").',
            },
            'endTime': {
              'type': 'string',
              'description': 'End time within day in HH:mm 24h format (e.g. "10:00" or "15:00").',
            },
            'date': {
              'type': 'string',
              'description': 'Target date in YYYY-MM-DD format (defaults to parent event start date).',
            },
            'endDate': {
              'type': 'string',
              'description': 'Optional end date for multi-day subtasks.',
            },
            'isCompleted': {
              'type': 'boolean',
              'description': 'Completion status of the subtask.',
            },
            'isUnlimited': {
              'type': 'boolean',
              'description': 'Whether the subtask applies to all days (unlimited recurrence).',
            },
            'reminderMinutes': {
              'type': 'integer',
              'description': 'Optional reminder notification minutes.',
            },
          },
          'required': ['action', 'parentEventId'],
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
      {
        'name': 'get_health_summary',
        'description': 'Inspect authentic daily health biometrics (steps, active/total calories, distance, sleep duration, sleep debt, hydration, resting heart rate, and detected workout sessions) from Health Connect.',
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
        'name': 'sync_health_to_dial',
        'description': 'Sync and project recorded sleep and workout/exercise sessions from Health Connect directly onto the circular dial schedule as non-destructive event sectors.',
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
        'name': 'get_health_status',
        'description': 'Check Health Connect availability, integration status, and whether health permissions (steps, sleep, exercise) are currently granted on the device.',
        'inputSchema': {'type': 'object', 'properties': {}},
      },
    ];
  }

  static TimeOfDay? _parseTimeOfDay(dynamic t) {
    if (t is String && t.contains(':')) {
      final parts = t.split(':');
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0].trim());
        final m = int.tryParse(parts[1].trim());
        if (h != null && m != null && h >= 0 && h < 24 && m >= 0 && m < 60) {
          return TimeOfDay(hour: h, minute: m);
        }
      }
    }
    return null;
  }

  static List<SubtaskItem> _parseSubtaskItems(dynamic raw, String parentId) {
    if (raw is! List) return const [];
    final items = <SubtaskItem>[];
    for (final item in raw) {
      if (item is Map<String, dynamic>) {
        TimeOfDay? start;
        if (item['startTime'] != null) {
          start = _parseTimeOfDay(item['startTime']);
        }
        TimeOfDay? end;
        if (item['endTime'] != null) {
          end = _parseTimeOfDay(item['endTime']);
        }
        items.add(
          SubtaskItem(
            id: item['id'] as String? ?? const Uuid().v4(),
            parentEventId: parentId,
            title: item['title'] as String? ?? '',
            isCompleted: item['isCompleted'] as bool? ?? false,
            startTime:
                start ??
                (item['startHour'] != null && item['startMinute'] != null
                    ? TimeOfDay(
                        hour: item['startHour'] as int,
                        minute: item['startMinute'] as int,
                      )
                    : null),
            endTime:
                end ??
                (item['endHour'] != null && item['endMinute'] != null
                    ? TimeOfDay(
                        hour: item['endHour'] as int,
                        minute: item['endMinute'] as int,
                      )
                    : null),
            date: item['date'] != null
                ? DateTime.tryParse(item['date'].toString())
                : null,
            endDate: item['endDate'] != null
                ? DateTime.tryParse(item['endDate'].toString())
                : null,
            isUnlimited: item['isUnlimited'] as bool? ?? false,
            reminderMinutes: item['reminderMinutes'] as int?,
          ),
        );
      } else if (item != null) {
        final title = item.toString().trim();
        if (title.isNotEmpty) {
          items.add(SubtaskItem.fromString(title, parentEventId: parentId));
        }
      }
    }
    return items;
  }

  static DateTime? _tryParseIsoDate(dynamic d) {
    if (d is String && d.isNotEmpty) {
      try {
        return DateTime.parse(d);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static Future<Map<String, dynamic>> executeTool({
    required String name,
    required Map<String, dynamic> arguments,
    required EventRepository repository,
    required DialSettings Function() getSettings,
    required Future<void> Function(DialSettings) updateSettings,
    HealthRepository? healthRepository,
    SyncHealthSessionsUseCase? syncHealthSessionsUseCase,
  }) async {
    final now = arguments['currentTime'] != null
        ? (DateTime.tryParse(arguments['currentTime'].toString()) ??
              DateTime.now())
        : DateTime.now();

    DateTime parseDate(dynamic d) {
      if (d is String && d.isNotEmpty) {
        try {
          return DateTime.parse(d);
        } catch (_) {}
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
        if (active == null) {
          final allEvents = await repository.getAllEvents();
          for (final e in allEvents) {
            if (e.isCurrentlyActive(now)) {
              active = e;
              break;
            }
          }
        }

        SubtaskItem? activeSubtask;
        if (active != null && active.subtaskItems.isNotEmpty) {
          final curMinutes = now.hour * 60 + now.minute;
          for (final s in active.subtaskItems) {
            if (s.startTime != null && s.endTime != null) {
              final sStart = s.startTime!.hour * 60 + s.startTime!.minute;
              final sEnd = s.endTime!.hour * 60 + s.endTime!.minute;
              final isMatch = (sStart <= sEnd)
                  ? (curMinutes >= sStart && curMinutes < sEnd)
                  : (curMinutes >= sStart || curMinutes < sEnd);
              if (isMatch) {
                activeSubtask = s;
                break;
              }
            }
          }
          activeSubtask ??= active.subtaskItems
              .where((s) => !s.isCompleted)
              .firstOrNull;
        }

        if (activeSubtask == null) {
          final curMinutes = now.hour * 60 + now.minute;
          for (final e in events) {
            for (final s in e.subtaskItems) {
              if (s.isScheduledForDate(targetDate) &&
                  s.startTime != null &&
                  s.endTime != null) {
                final sStart = s.startTime!.hour * 60 + s.startTime!.minute;
                final sEnd = s.endTime!.hour * 60 + s.endTime!.minute;
                final isMatch = (sStart <= sEnd)
                    ? (curMinutes >= sStart && curMinutes < sEnd)
                    : (curMinutes >= sStart || curMinutes < sEnd);
                if (isMatch) {
                  activeSubtask = s;
                  break;
                }
              }
            }
            if (activeSubtask != null) break;
          }
        }

        final upcoming = events.where((e) => e.start.isAfter(now)).toList()
          ..sort((a, b) => a.start.compareTo(b.start));

        return {
          'currentTime': now.toIso8601String(),
          'date': targetDate.toIso8601String().substring(0, 10),
          'is24HourMode': settings.is24HourMode,
          'centerClockDisplay': settings.centerClockDisplay.name,
          'dateOfBirth': settings.dateOfBirth?.toIso8601String().substring(
            0,
            10,
          ),
          'activeEvent': active?.toJson(),
          'activeEventRemainingMinutes': active != null
              ? active.end.difference(now).inMinutes
              : 0,
          'activeSubtask': activeSubtask?.toJson(),
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
        final minMinsRaw = arguments['minDurationMinutes'];
        final minMins = (minMinsRaw is int && minMinsRaw > 0) ? minMinsRaw : 15;
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
          if (item is! Map<String, dynamic>) continue;
          final start = _tryParseIsoDate(item['start']);
          final end = _tryParseIsoDate(item['end']);
          if (start == null || end == null || !end.isAfter(start)) continue;

          final id = const Uuid().v4();
          final rawSubtasks = item['subtaskItems'] ?? item['subtasks'];
          final event = SectorEvent(
            id: id,
            title: item['title'] as String? ?? 'Untitled',
            start: start,
            end: end,
            category: item['category'] as String? ?? 'General',
            colorHex: item['colorHex'] as String? ?? '#6366F1',
            notes: item['notes'] as String? ?? '',
            subtaskItems: _parseSubtaskItems(rawSubtasks, id),
          );
          created.add(event);
        }

        if (created.isNotEmpty) {
          await repository.bulkAddEvents(created);
        }
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
          if (item is! Map<String, dynamic>) continue;
          final start = _tryParseIsoDate(item['start']);
          final end = _tryParseIsoDate(item['end']);
          if (start == null || end == null || !end.isAfter(start)) continue;

          final id = const Uuid().v4();
          final rawSubtasks = item['subtaskItems'] ?? item['subtasks'];
          final event = SectorEvent(
            id: id,
            title: item['title'] as String? ?? 'Untitled',
            start: start,
            end: end,
            category: item['category'] as String? ?? 'General',
            colorHex: item['colorHex'] as String? ?? '#6366F1',
            notes: item['notes'] as String? ?? '',
            subtaskItems: _parseSubtaskItems(rawSubtasks, id),
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
          if (t is! Map<String, dynamic>) continue;
          final durationMins = t['durationMinutes'] as int? ?? 30;
          final duration = Duration(minutes: durationMins);

          // Find a gap that can accommodate duration
          while (gapIdx < gaps.length) {
            final gapRemaining = currentGapEnd!.difference(currentGapStart!);
            if (gapRemaining >= duration) {
              final taskStart = currentGapStart;
              final taskEnd = taskStart.add(duration);

              final id = const Uuid().v4();
              final rawSubtasks = t['subtaskItems'] ?? t['subtasks'];
              final event = SectorEvent(
                id: id,
                title: t['title'] as String? ?? 'Focus Task',
                start: taskStart,
                end: taskEnd,
                category: t['category'] as String? ?? 'Focus',
                colorHex: t['colorHex'] as String? ?? '#10B981',
                subtaskItems: _parseSubtaskItems(rawSubtasks, id),
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
        final title = arguments['title'] as String? ?? '';
        final start = _tryParseIsoDate(arguments['start']);
        final end = _tryParseIsoDate(arguments['end']);
        if (start == null || end == null) {
          return {
            'success': false,
            'error': 'Invalid ISO 8601 start or end date format',
          };
        }
        if (!end.isAfter(start)) {
          return {
            'success': false,
            'error': 'End time must be strictly after start time',
          };
        }
        final id = const Uuid().v4();
        final rawSubtasks = arguments['subtaskItems'] ?? arguments['subtasks'];
        final event = SectorEvent(
          id: id,
          title: title,
          start: start,
          end: end,
          category: arguments['category'] as String? ?? 'General',
          colorHex: arguments['colorHex'] as String? ?? '#6366F1',
          notes: arguments['notes'] as String? ?? '',
          subtaskItems: _parseSubtaskItems(rawSubtasks, id),
        );
        await repository.addEvent(event);
        return {'success': true, 'sector': event.toJson()};

      case 'update_sector':
        final id = arguments['id'] as String? ?? '';
        final allEvents = await repository.getAllEvents();
        SectorEvent? existing;
        for (final e in allEvents) {
          if (e.id == id) {
            existing = e;
            break;
          }
        }
        if (existing == null) {
          return {'success': false, 'error': 'Sector not found with id: $id'};
        }

        DateTime? newStart;
        if (arguments['start'] != null) {
          newStart = _tryParseIsoDate(arguments['start']);
          if (newStart == null) {
            return {'success': false, 'error': 'Invalid start date format'};
          }
        }
        DateTime? newEnd;
        if (arguments['end'] != null) {
          newEnd = _tryParseIsoDate(arguments['end']);
          if (newEnd == null) {
            return {'success': false, 'error': 'Invalid end date format'};
          }
        }

        final effectiveStart = newStart ?? existing.start;
        final effectiveEnd = newEnd ?? existing.end;
        if (!effectiveEnd.isAfter(effectiveStart)) {
          return {
            'success': false,
            'error': 'End time must be strictly after start time',
          };
        }

        List<SubtaskItem>? updatedSubtaskItems;
        if (arguments.containsKey('subtaskItems') ||
            arguments.containsKey('subtasks')) {
          final rawSubtasks =
              arguments['subtaskItems'] ?? arguments['subtasks'];
          updatedSubtaskItems = _parseSubtaskItems(rawSubtasks, existing.id);
        }

        final updated = existing.copyWith(
          title: arguments['title'] as String?,
          start: effectiveStart,
          end: effectiveEnd,
          category: arguments['category'] as String?,
          colorHex: arguments['colorHex'] as String?,
          notes: arguments['notes'] as String?,
          subtaskItems: updatedSubtaskItems ?? existing.subtaskItems,
        );
        await repository.updateEvent(updated);
        return {'success': true, 'sector': updated.toJson()};

      case 'delete_sector':
        final id = arguments['id'] as String? ?? '';
        final allEvents = await repository.getAllEvents();
        final exists = allEvents.any((e) => e.id == id);
        if (!exists) {
          return {'success': false, 'error': 'Sector not found with id: $id'};
        }
        await repository.deleteEvent(id);
        return {'success': true, 'deletedId': id};

      case 'clear_sectors':
        final targetDate = parseDate(arguments['date']);
        await repository.clearEventsForDay(targetDate);
        return {
          'success': true,
          'date': targetDate.toIso8601String().substring(0, 10),
        };

      case 'manage_subtask':
        final action = arguments['action'] as String?;
        final parentEventId = arguments['parentEventId'] as String?;

        if (action == null || parentEventId == null || parentEventId.isEmpty) {
          return {
            'success': false,
            'error': 'Both "action" and "parentEventId" are required',
          };
        }

        final allEvents = await repository.getAllEvents();
        SectorEvent? parent;
        for (final e in allEvents) {
          if (e.id == parentEventId) {
            parent = e;
            break;
          }
        }
        if (parent == null) {
          return {
            'success': false,
            'error': 'Parent event not found with id: $parentEventId',
          };
        }

        switch (action) {
          case 'add':
            final title = arguments['title'] as String? ?? 'Subtask';
            if (title.trim().isEmpty) {
              return {
                'success': false,
                'error': 'Subtask title cannot be empty',
              };
            }
            final startTime = _parseTimeOfDay(arguments['startTime']);
            final endTime = _parseTimeOfDay(arguments['endTime']);
            final date = arguments['date'] != null
                ? DateTime.tryParse(arguments['date'].toString())
                : null;
            final endDate = arguments['endDate'] != null
                ? DateTime.tryParse(arguments['endDate'].toString())
                : null;
            final isCompleted = arguments['isCompleted'] as bool? ?? false;
            final isUnlimited = arguments['isUnlimited'] as bool? ?? false;
            final reminderMinutes = arguments['reminderMinutes'] as int?;

            final newSubtask = SubtaskItem.create(
              parentEventId: parentEventId,
              title: title,
              isCompleted: isCompleted,
              startTime: startTime,
              endTime: endTime,
              date:
                  date ??
                  DateTime(
                    parent.start.year,
                    parent.start.month,
                    parent.start.day,
                  ),
              endDate: endDate,
              isUnlimited: isUnlimited,
              reminderMinutes: reminderMinutes,
            );

            final updated = parent.copyWith(
              subtaskItems: [...parent.subtaskItems, newSubtask],
            );
            await repository.updateEvent(updated);
            return {
              'success': true,
              'action': 'add',
              'parentEventId': parentEventId,
              'subtask': newSubtask.toJson(),
            };

          case 'update':
            final subtaskId = arguments['subtaskId'] as String?;
            if (subtaskId == null || subtaskId.isEmpty) {
              return {
                'success': false,
                'error': 'subtaskId is required for update',
              };
            }
            final index = parent.subtaskItems.indexWhere(
              (s) => s.id == subtaskId,
            );
            if (index == -1) {
              return {
                'success': false,
                'error':
                    'Subtask not found with id: $subtaskId in event: $parentEventId',
              };
            }
            final existingSub = parent.subtaskItems[index];
            final updatedSub = existingSub.copyWith(
              title: arguments['title'] as String?,
              startTime: arguments.containsKey('startTime')
                  ? _parseTimeOfDay(arguments['startTime'])
                  : existingSub.startTime,
              endTime: arguments.containsKey('endTime')
                  ? _parseTimeOfDay(arguments['endTime'])
                  : existingSub.endTime,
              date: arguments.containsKey('date')
                  ? DateTime.tryParse(arguments['date'].toString())
                  : existingSub.date,
              endDate: arguments.containsKey('endDate')
                  ? DateTime.tryParse(arguments['endDate'].toString())
                  : existingSub.endDate,
              isCompleted: arguments['isCompleted'] as bool?,
              isUnlimited: arguments['isUnlimited'] as bool?,
              reminderMinutes: arguments['reminderMinutes'] as int?,
            );

            final updatedList = List<SubtaskItem>.from(parent.subtaskItems);
            updatedList[index] = updatedSub;
            await repository.updateEvent(
              parent.copyWith(subtaskItems: updatedList),
            );
            return {
              'success': true,
              'action': 'update',
              'parentEventId': parentEventId,
              'subtask': updatedSub.toJson(),
            };

          case 'toggle_complete':
            final subtaskId = arguments['subtaskId'] as String?;
            if (subtaskId == null || subtaskId.isEmpty) {
              return {
                'success': false,
                'error': 'subtaskId is required for toggle_complete',
              };
            }
            final index = parent.subtaskItems.indexWhere(
              (s) => s.id == subtaskId,
            );
            if (index == -1) {
              return {
                'success': false,
                'error':
                    'Subtask not found with id: $subtaskId in event: $parentEventId',
              };
            }
            final existingSub = parent.subtaskItems[index];
            final newCompleted = arguments.containsKey('isCompleted')
                ? (arguments['isCompleted'] as bool? ??
                      !existingSub.isCompleted)
                : !existingSub.isCompleted;
            final updatedSub = existingSub.copyWith(isCompleted: newCompleted);

            final updatedList = List<SubtaskItem>.from(parent.subtaskItems);
            updatedList[index] = updatedSub;
            await repository.updateEvent(
              parent.copyWith(subtaskItems: updatedList),
            );
            return {
              'success': true,
              'action': 'toggle_complete',
              'parentEventId': parentEventId,
              'isCompleted': newCompleted,
              'subtask': updatedSub.toJson(),
            };

          case 'delete':
            final subtaskId = arguments['subtaskId'] as String?;
            if (subtaskId == null || subtaskId.isEmpty) {
              return {
                'success': false,
                'error': 'subtaskId is required for delete',
              };
            }
            final exists = parent.subtaskItems.any((s) => s.id == subtaskId);
            if (!exists) {
              return {
                'success': false,
                'error':
                    'Subtask not found with id: $subtaskId in event: $parentEventId',
              };
            }
            final updatedList = parent.subtaskItems
                .where((s) => s.id != subtaskId)
                .toList();
            await repository.updateEvent(
              parent.copyWith(subtaskItems: updatedList),
            );
            return {
              'success': true,
              'action': 'delete',
              'parentEventId': parentEventId,
              'deletedSubtaskId': subtaskId,
            };

          default:
            return {
              'success': false,
              'error':
                  'Invalid action: $action. Supported actions: add, update, toggle_complete, delete',
            };
        }

      case 'get_dial_settings':
        return getSettings().toJson();

      case 'update_dial_settings':
        final current = getSettings();
        var updated = current.copyWith(
          is24HourMode: arguments['is24HourMode'] as bool?,
          seedColorHex: arguments['seedColorHex'] as String?,
        );
        if (arguments['themeMode'] != null) {
          final val = arguments['themeMode'].toString();
          for (final e in ThemeMode.values) {
            if (e.name == val) {
              updated = updated.copyWith(themeMode: e);
              break;
            }
          }
        }
        if (arguments['faceStyle'] != null) {
          final val = arguments['faceStyle'].toString();
          for (final e in DialFaceStyle.values) {
            if (e.name == val) {
              updated = updated.copyWith(faceStyle: e);
              break;
            }
          }
        }
        if (arguments['sectorStyle'] != null) {
          final val = arguments['sectorStyle'].toString();
          for (final e in SectorVisualTheme.values) {
            if (e.name == val) {
              updated = updated.copyWith(sectorStyle: e);
              break;
            }
          }
        }
        if (arguments['handStyle'] != null) {
          final val = arguments['handStyle'].toString();
          for (final e in HandStyle.values) {
            if (e.name == val) {
              updated = updated.copyWith(handStyle: e);
              break;
            }
          }
        }
        if (arguments['centerClockDisplay'] != null) {
          final val = arguments['centerClockDisplay'].toString();
          for (final e in CenterClockDisplay.values) {
            if (e.name == val) {
              updated = updated.copyWith(centerClockDisplay: e);
              break;
            }
          }
        }
        if (arguments.containsKey('dateOfBirth')) {
          final dobRaw = arguments['dateOfBirth'];
          if (dobRaw == null || dobRaw.toString().trim().isEmpty) {
            updated = updated.copyWith(clearDateOfBirth: true);
          } else {
            final parsedDob = DateTime.tryParse(dobRaw.toString());
            if (parsedDob != null) {
              updated = updated.copyWith(dateOfBirth: parsedDob);
            }
          }
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

      case 'get_health_summary':
        final targetDate = parseDate(arguments['date']);
        final healthRepo =
            healthRepository ??
            HealthRepositoryImpl(service: DeviceHealthService());
        final summary = await healthRepo.getDailySummary(targetDate);
        final res = summary.toJson();
        res['sleepHoursFormatted'] = summary.sleepHoursFormatted;
        res['sleepDebtMinutes'] = summary.sleepDebtMinutes();
        res['hasSignificantSleepDebt'] = summary.hasSignificantSleepDebt;
        return res;

      case 'sync_health_to_dial':
        final targetDate = parseDate(arguments['date']);
        final healthRepo =
            healthRepository ??
            HealthRepositoryImpl(service: DeviceHealthService());
        final summary = await healthRepo.getDailySummary(targetDate);
        final existing = await repository.getEventsForDay(targetDate);
        final syncUseCase =
            syncHealthSessionsUseCase ??
            SyncHealthSessionsUseCase(eventRepository: repository);
        final synced = await syncUseCase.execute(
          health: summary,
          existingEvents: existing,
        );
        return {
          'success': true,
          'date': targetDate.toIso8601String().substring(0, 10),
          'syncedSessionsCount': synced.length,
          'syncedEvents': synced.map((e) => e.toJson()).toList(),
        };

      case 'get_health_status':
        final healthRepo =
            healthRepository ??
            HealthRepositoryImpl(service: DeviceHealthService());
        final isAvailable = await healthRepo.isAvailable();
        final hasPermissions = await healthRepo.hasPermissions();
        return {
          'isAvailable': isAvailable,
          'hasPermissions': hasPermissions,
          'status': !isAvailable
              ? 'unavailable'
              : (!hasPermissions ? 'permissionRequired' : 'connected'),
          'supportedMetrics': [
            'steps',
            'activeCalories',
            'totalCalories',
            'distanceMeters',
            'sleepDuration',
            'sleepStages',
            'hydrationMl',
            'restingHeartRate',
            'exerciseSessions',
          ],
        };

      default:
        throw Exception('Unknown tool: $name');
    }
  }
}
