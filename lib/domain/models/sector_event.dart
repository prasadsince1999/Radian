import 'package:flutter/material.dart';

import '../../core/constants/app_presets.dart';
import '../../core/geometry/concentric_solver.dart';
import '../../core/geometry/polar_hit_test.dart';
import '../../core/geometry/sector_math.dart';

/// Immutable domain model representing a time block sector on the circular dial.
///
/// Ported and modernized from Sectograph's `SEvent.java`.
@immutable
class SectorEvent extends ConcentricItem implements HitTestableSector {
  final String id;
  final String title;
  @override
  final DateTime start;
  @override
  final DateTime end;
  final String colorHex;
  final String category;
  final String notes;
  final bool isAllDay;
  final String? iconName;
  final int? reminderMinutes;
  final List<int>? repeatDays;
  final DateTime? recurrenceEndDate;

  @override
  final int topLevel;
  @override
  final int bottomLevel;

  @override
  final double startAngle;
  @override
  final double sweepAngle;

  SectorEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.colorHex = '#3B82F6',
    this.category = 'General',
    this.notes = '',
    this.isAllDay = false,
    this.iconName,
    this.reminderMinutes,
    this.repeatDays,
    this.recurrenceEndDate,
    this.topLevel = 0,
    this.bottomLevel = 1000,
    this.startAngle = 0.0,
    this.sweepAngle = 0.0,
  });

  IconData get iconData => AppPresets.getIconById(iconName);

  /// Resolved icon for this event, utilizing [iconName] or intelligently inferring
  /// from category & title to ensure consistent iconography across dial & schedule list.
  IconData get resolvedIcon {
    if (iconName != null &&
        iconName!.isNotEmpty &&
        iconName != 'schedule' &&
        iconName != 'routine') {
      return AppPresets.getIconById(iconName);
    }
    final text = '$category $title'.toLowerCase();
    if (text.contains('workout') ||
        text.contains('fitness') ||
        text.contains('gym') ||
        text.contains('run') ||
        text.contains('sport') ||
        text.contains('exercise') ||
        text.contains('cardio')) {
      return Icons.fitness_center_rounded;
    } else if (text.contains('code') ||
        text.contains('dev') ||
        text.contains('terminal') ||
        text.contains('prog') ||
        text.contains('software')) {
      return Icons.terminal_rounded;
    } else if (text.contains('break') ||
        text.contains('coffee') ||
        text.contains('tea') ||
        text.contains('chill')) {
      return Icons.coffee_rounded;
    } else if (text.contains('read') ||
        text.contains('book') ||
        text.contains('study') ||
        text.contains('novel') ||
        text.contains('learn')) {
      return Icons.menu_book_rounded;
    } else if (text.contains('lunch') ||
        text.contains('dinner') ||
        text.contains('food') ||
        text.contains('cook') ||
        text.contains('meal') ||
        text.contains('breakfast')) {
      return Icons.restaurant_rounded;
    } else if (text.contains('sleep') ||
        text.contains('bed') ||
        text.contains('nap') ||
        text.contains('rest')) {
      return Icons.nightlight_round;
    } else if (text.contains('focus') ||
        text.contains('work') ||
        text.contains('laptop') ||
        text.contains('deep')) {
      return Icons.laptop_chromebook;
    } else if (text.contains('meet') ||
        text.contains('chat') ||
        text.contains('forum') ||
        text.contains('call')) {
      return Icons.forum_rounded;
    } else if (text.contains('music') || text.contains('audio')) {
      return Icons.headphones_rounded;
    }
    return AppPresets.getIconById(iconName);
  }

  Duration get duration => end.difference(start);

  bool isCurrentlyActive([DateTime? now]) {
    final t = now ?? DateTime.now();
    return !t.isBefore(start) && t.isBefore(end);
  }

  /// Calculates the fraction [0.0, 1.0] of time elapsed if currently active.
  double progressFraction([DateTime? now]) {
    final t = now ?? DateTime.now();
    if (t.isBefore(start)) return 0.0;
    if (!t.isBefore(end)) return 1.0;
    final totalMs = duration.inMilliseconds;
    if (totalMs <= 0) return 0.0;
    final elapsedMs = t.difference(start).inMilliseconds;
    return (elapsedMs / totalMs).clamp(0.0, 1.0);
  }

  Color get color {
    try {
      var hex = colorHex.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return const Color(0xFF3B82F6);
    }
  }

  /// Returns a new instance with calculated angles based on [is24HourMode].
  SectorEvent withComputedAngles({required bool is24HourMode}) {
    final calculatedStart = SectorMath.timeToDialAngle(
      start,
      is24HourMode: is24HourMode,
    );
    final calculatedSweep = SectorMath.durationToSweepAngle(
      duration,
      is24HourMode: is24HourMode,
    );
    return copyWith(startAngle: calculatedStart, sweepAngle: calculatedSweep);
  }

  SectorEvent copyWith({
    String? id,
    String? title,
    DateTime? start,
    DateTime? end,
    String? colorHex,
    String? category,
    String? notes,
    bool? isAllDay,
    String? iconName,
    int? reminderMinutes,
    bool clearReminder = false,
    List<int>? repeatDays,
    bool clearRepeatDays = false,
    DateTime? recurrenceEndDate,
    bool clearRecurrenceEndDate = false,
    int? topLevel,
    int? bottomLevel,
    double? startAngle,
    double? sweepAngle,
  }) {
    return SectorEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      start: start ?? this.start,
      end: end ?? this.end,
      colorHex: colorHex ?? this.colorHex,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      isAllDay: isAllDay ?? this.isAllDay,
      iconName: iconName ?? this.iconName,
      reminderMinutes: clearReminder
          ? null
          : (reminderMinutes ?? this.reminderMinutes),
      repeatDays: clearRepeatDays ? null : (repeatDays ?? this.repeatDays),
      recurrenceEndDate: clearRecurrenceEndDate
          ? null
          : (recurrenceEndDate ?? this.recurrenceEndDate),
      topLevel: topLevel ?? this.topLevel,
      bottomLevel: bottomLevel ?? this.bottomLevel,
      startAngle: startAngle ?? this.startAngle,
      sweepAngle: sweepAngle ?? this.sweepAngle,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'colorHex': colorHex,
    'category': category,
    'notes': notes,
    'isAllDay': isAllDay,
    'iconName': iconName,
    'reminderMinutes': reminderMinutes,
    'repeatDays': repeatDays,
    'recurrenceEndDate': recurrenceEndDate?.toIso8601String(),
    'topLevel': topLevel,
    'bottomLevel': bottomLevel,
    'startAngle': startAngle,
    'sweepAngle': sweepAngle,
  };

  factory SectorEvent.fromJson(Map<String, dynamic> json) {
    return SectorEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
      colorHex: json['colorHex'] as String? ?? '#3B82F6',
      category: json['category'] as String? ?? 'General',
      notes: json['notes'] as String? ?? '',
      isAllDay: json['isAllDay'] as bool? ?? false,
      iconName: json['iconName'] as String?,
      reminderMinutes: json['reminderMinutes'] as int?,
      repeatDays: (json['repeatDays'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList(),
      recurrenceEndDate: json['recurrenceEndDate'] != null
          ? DateTime.parse(json['recurrenceEndDate'] as String)
          : null,
      topLevel: json['topLevel'] as int? ?? 0,
      bottomLevel: json['bottomLevel'] as int? ?? 1000,
      startAngle: (json['startAngle'] as num?)?.toDouble() ?? 0.0,
      sweepAngle: (json['sweepAngle'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SectorEvent &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          start == other.start &&
          end == other.end &&
          colorHex == other.colorHex &&
          topLevel == other.topLevel &&
          bottomLevel == other.bottomLevel;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      start.hashCode ^
      end.hashCode ^
      topLevel.hashCode ^
      bottomLevel.hashCode;
}
