import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../domain/models/sector_event.dart';

/// Production-grade Android exact alarm and heads-up push notification service
/// for scheduled Sectograph routine and event reminders.
class ReminderNotificationService {
  static const MethodChannel _channel = MethodChannel(
    'com.ksmxtech.sectograph_mcp/notifications',
  );

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Checks if Android notifications are enabled.
  static Future<bool> areNotificationsEnabled() async {
    if (!isAndroid) return true;
    try {
      final enabled = await _channel.invokeMethod<bool>(
        'areNotificationsEnabled',
      );
      return enabled ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Prompts user with Android 13+ runtime POST_NOTIFICATIONS permission dialog.
  static Future<bool> requestNotificationPermission() async {
    if (!isAndroid) return true;
    try {
      final granted = await _channel.invokeMethod<bool>(
        'requestNotificationPermission',
      );
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Calculates the next upcoming reminder trigger for an event (including recurring events).
  static DateTime? computeNextReminderTime(
    SectorEvent event, [
    DateTime? relativeTo,
  ]) {
    final minutes = event.reminderMinutes;
    if (minutes == null) return null;

    final now = relativeTo ?? DateTime.now();

    // 1. Repeating Event
    if (event.repeatDays != null && event.repeatDays!.isNotEmpty) {
      final repeatSet = event.repeatDays!.toSet();
      for (int i = 0; i <= 8; i++) {
        final targetDate = now.add(Duration(days: i));
        final weekday = targetDate.weekday; // 1 (Mon) .. 7 (Sun)
        if (!repeatSet.contains(weekday)) continue;

        // Check boundary if recurrenceEndDate is specified
        if (event.recurrenceEndDate != null) {
          final endBoundary = DateTime(
            event.recurrenceEndDate!.year,
            event.recurrenceEndDate!.month,
            event.recurrenceEndDate!.day,
            23,
            59,
            59,
          );
          if (targetDate.isAfter(endBoundary)) continue;
        }

        final instanceStart = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          event.start.hour,
          event.start.minute,
        );

        final triggerTime = instanceStart.subtract(Duration(minutes: minutes));
        if (triggerTime.isAfter(now)) {
          return triggerTime;
        }
      }
      return null;
    }

    // 2. Single One-Time Event
    final triggerTime = event.start.subtract(Duration(minutes: minutes));
    if (triggerTime.isAfter(now)) {
      return triggerTime;
    }

    return null;
  }

  /// Schedules an exact Android alarm for an event's reminder.
  static Future<bool> scheduleReminder(SectorEvent event) async {
    if (!isAndroid) return false;
    final minutes = event.reminderMinutes;
    if (minutes == null) return false;

    final triggerTime = computeNextReminderTime(event);
    if (triggerTime == null) return false;

    final notifId = (event.id.hashCode & 0x7FFFFFFF) % 1000000;

    final startFmt = DateFormat('h:mm a').format(event.start);
    final endFmt = DateFormat('h:mm a').format(event.end);
    var body = '$startFmt - $endFmt';
    if (event.notes.isNotEmpty) {
      body += ' • ${event.notes}';
    }

    try {
      final ok = await _channel.invokeMethod<bool>('scheduleReminder', {
        'id': notifId,
        'eventId': event.id,
        'title': event.title,
        'body': body,
        'triggerTimeMillis': triggerTime.millisecondsSinceEpoch,
        'colorHex': event.colorHex,
        'minutesBefore': minutes,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Cancels any scheduled alarm and active notification for this event.
  static Future<bool> cancelReminder(String eventId) async {
    if (!isAndroid) return false;
    final notifId = (eventId.hashCode & 0x7FFFFFFF) % 1000000;
    try {
      final ok = await _channel.invokeMethod<bool>('cancelReminder', {
        'id': notifId,
        'eventId': eventId,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Cancels all scheduled reminder alarms and active notifications.
  static Future<bool> cancelAllReminders() async {
    if (!isAndroid) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('cancelAllReminders');
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Re-synchronizes all future alarms for a list of events.
  static Future<void> syncAllReminders(List<SectorEvent> events) async {
    if (!isAndroid) return;
    for (final event in events) {
      if (event.reminderMinutes != null) {
        await scheduleReminder(event);
      } else {
        await cancelReminder(event.id);
      }
    }
  }
}
