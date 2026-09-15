import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// Immutable domain model representing a micro-subtask within a macro time block.
@immutable
class SubtaskItem {
  final String id;
  final String parentEventId;
  final String title;
  final bool isCompleted;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final DateTime? date;
  final int? reminderMinutes;

  const SubtaskItem({
    required this.id,
    required this.parentEventId,
    required this.title,
    this.isCompleted = false,
    this.startTime,
    this.endTime,
    this.date,
    this.reminderMinutes,
  });

  factory SubtaskItem.create({
    required String parentEventId,
    required String title,
    bool isCompleted = false,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    DateTime? date,
    int? reminderMinutes,
  }) {
    return SubtaskItem(
      id: const Uuid().v4(),
      parentEventId: parentEventId,
      title: title.trim(),
      isCompleted: isCompleted,
      startTime: startTime,
      endTime: endTime,
      date: date,
      reminderMinutes: reminderMinutes,
    );
  }

  SubtaskItem copyWith({
    String? id,
    String? parentEventId,
    String? title,
    bool? isCompleted,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    DateTime? date,
    int? reminderMinutes,
    bool clearReminder = false,
    bool clearTiming = false,
  }) {
    return SubtaskItem(
      id: id ?? this.id,
      parentEventId: parentEventId ?? this.parentEventId,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      startTime: clearTiming ? null : (startTime ?? this.startTime),
      endTime: clearTiming ? null : (endTime ?? this.endTime),
      date: date ?? this.date,
      reminderMinutes: clearReminder
          ? null
          : (reminderMinutes ?? this.reminderMinutes),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'parentEventId': parentEventId,
      'title': title,
      'isCompleted': isCompleted,
      'startHour': startTime?.hour,
      'startMinute': startTime?.minute,
      'endHour': endTime?.hour,
      'endMinute': endTime?.minute,
      'date': date?.toIso8601String(),
      'reminderMinutes': reminderMinutes,
    };
  }

  factory SubtaskItem.fromJson(
    Map<String, dynamic> json, [
    String defaultParentId = '',
  ]) {
    TimeOfDay? start;
    if (json['startHour'] != null && json['startMinute'] != null) {
      start = TimeOfDay(
        hour: json['startHour'] as int,
        minute: json['startMinute'] as int,
      );
    }
    TimeOfDay? end;
    if (json['endHour'] != null && json['endMinute'] != null) {
      end = TimeOfDay(
        hour: json['endHour'] as int,
        minute: json['endMinute'] as int,
      );
    }

    return SubtaskItem(
      id: json['id'] as String? ?? const Uuid().v4(),
      parentEventId: json['parentEventId'] as String? ?? defaultParentId,
      title: json['title'] as String? ?? '',
      isCompleted: json['isCompleted'] as bool? ?? false,
      startTime: start,
      endTime: end,
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : null,
      reminderMinutes: json['reminderMinutes'] as int?,
    );
  }

  /// Converts a legacy plain string into a basic SubtaskItem.
  factory SubtaskItem.fromString(String text, {String parentEventId = ''}) {
    return SubtaskItem(
      id: const Uuid().v4(),
      parentEventId: parentEventId,
      title: text.trim(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubtaskItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          parentEventId == other.parentEventId &&
          title == other.title &&
          isCompleted == other.isCompleted &&
          startTime == other.startTime &&
          endTime == other.endTime &&
          date == other.date &&
          reminderMinutes == other.reminderMinutes;

  @override
  int get hashCode =>
      id.hashCode ^
      parentEventId.hashCode ^
      title.hashCode ^
      isCompleted.hashCode ^
      startTime.hashCode ^
      endTime.hashCode ^
      date.hashCode ^
      reminderMinutes.hashCode;
}
