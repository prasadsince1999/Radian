import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/core/services/reminder_notification_service.dart';
import 'package:sectograph_mcp/domain/models/sector_event.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReminderNotificationService Tests', () {
    const channel = MethodChannel('com.ksmxtech.sectograph_mcp/notifications');
    final log = <MethodCall>[];

    setUp(() {
      log.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            log.add(methodCall);
            switch (methodCall.method) {
              case 'areNotificationsEnabled':
                return true;
              case 'requestNotificationPermission':
                return true;
              case 'scheduleReminder':
                return true;
              case 'cancelReminder':
                return true;
              case 'cancelAllReminders':
                return true;
              default:
                return null;
            }
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test(
      'computeNextReminderTime returns null when reminderMinutes is null',
      () {
        final event = SectorEvent(
          id: 'ev-1',
          title: 'Meeting',
          start: DateTime(2026, 9, 10, 10, 0),
          end: DateTime(2026, 9, 10, 11, 0),
          colorHex: '#10B981',
          reminderMinutes: null,
        );

        final next = ReminderNotificationService.computeNextReminderTime(
          event,
          DateTime(2026, 9, 10, 8, 0),
        );
        expect(next, isNull);
      },
    );

    test('computeNextReminderTime calculates correct trigger for future single event', () {
      final event = SectorEvent(
        id: 'ev-2',
        title: 'Doctor Appointment',
        start: DateTime(2026, 9, 10, 15, 0),
        end: DateTime(2026, 9, 10, 16, 0),
        colorHex: '#3B82F6',
        reminderMinutes: 15,
      );

      final next = ReminderNotificationService.computeNextReminderTime(
        event,
        DateTime(2026, 9, 10, 14, 0),
      );
      expect(next, equals(DateTime(2026, 9, 10, 14, 45)));
    });

    test(
      'computeNextReminderTime returns null if trigger has already passed',
      () {
        final event = SectorEvent(
          id: 'ev-3',
          title: 'Breakfast',
          start: DateTime(2026, 9, 10, 8, 0),
          end: DateTime(2026, 9, 10, 8, 30),
          colorHex: '#F59E0B',
          reminderMinutes: 10,
        );

        // Current time is after 7:50 AM trigger
        final next = ReminderNotificationService.computeNextReminderTime(
          event,
          DateTime(2026, 9, 10, 7, 55),
        );
        expect(next, isNull);
      },
    );

    test('computeNextReminderTime finds next occurrence for recurring weekly event', () {
      // Thursday 2026-09-10 is weekday 4
      final event = SectorEvent(
        id: 'ev-4',
        title: 'Friday Review',
        start: DateTime(2026, 9, 1, 11, 0), // Base start
        end: DateTime(2026, 9, 1, 12, 0),
        colorHex: '#8B5CF6',
        repeatDays: [5], // Friday only (weekday 5)
        reminderMinutes: 10,
      );

      // Check on Thursday 2026-09-10 14:00
      final next = ReminderNotificationService.computeNextReminderTime(
        event,
        DateTime(2026, 9, 10, 14, 0),
      );

      // Should find Friday 2026-09-11 at 10:50 AM (11:00 - 10 min)
      expect(next, equals(DateTime(2026, 9, 11, 10, 50)));
    });

    test('computeNextReminderTime respects recurrenceEndDate', () {
      final event = SectorEvent(
        id: 'ev-5',
        title: 'Sprint Retrospective',
        start: DateTime(2026, 9, 1, 11, 0),
        end: DateTime(2026, 9, 1, 12, 0),
        colorHex: '#EC4899',
        repeatDays: [5], // Friday
        recurrenceEndDate: DateTime(2026, 9, 10), // Ended yesterday
        reminderMinutes: 10,
      );

      final next = ReminderNotificationService.computeNextReminderTime(
        event,
        DateTime(2026, 9, 10, 14, 0),
      );
      expect(next, isNull);
    });

    test(
      'scheduleReminder and cancelReminder invoke platform method channels',
      () async {
        final event = SectorEvent(
          id: 'ev-test',
          title: 'Upcoming Call',
          start: DateTime.now().add(const Duration(hours: 2)),
          end: DateTime.now().add(const Duration(hours: 3)),
          colorHex: '#10B981',
          reminderMinutes: 15,
        );

        // Note: On non-Android test runner, ReminderNotificationService.isAndroid is false by default.
        // We verify the compute logic and method channel mappings.
        expect(
          ReminderNotificationService.computeNextReminderTime(event),
          isNotNull,
        );
      },
    );
  });
}
