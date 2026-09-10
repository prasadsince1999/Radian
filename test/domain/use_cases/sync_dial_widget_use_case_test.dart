import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/domain/models/dial_settings.dart';
import 'package:sectograph_mcp/domain/models/sector_event.dart';
import 'package:sectograph_mcp/domain/use_cases/sync_dial_widget_use_case.dart';

void main() {
  group('SyncDialWidgetUseCase Tests', () {
    test('delegates sync invocation with correct parameters', () async {
      List<SectorEvent>? capturedEvents;
      DateTime? capturedCurrentTime;
      DialSettings? capturedSettings;
      ColorScheme? capturedColorScheme;
      SectorEvent? capturedActiveEvent;

      final useCase = SyncDialWidgetUseCase(
        syncWidget:
            ({
              required List<SectorEvent> dayEvents,
              required DateTime currentTime,
              required DialSettings settings,
              required ColorScheme colorScheme,
              SectorEvent? activeEvent,
            }) async {
              capturedEvents = dayEvents;
              capturedCurrentTime = currentTime;
              capturedSettings = settings;
              capturedColorScheme = colorScheme;
              capturedActiveEvent = activeEvent;
            },
      );

      final events = [
        SectorEvent(
          id: 'evt-1',
          title: 'Design Review',
          start: DateTime(2026, 9, 9, 10, 0),
          end: DateTime(2026, 9, 9, 11, 0),
          colorHex: '#FF9800',
        ),
      ];
      final activeEvent = events.first;
      final now = DateTime(2026, 9, 9, 10, 15);
      const settings = DialSettings(is24HourMode: true);
      final theme = ThemeData.dark();

      await useCase.execute(
        events: events,
        activeEvent: activeEvent,
        currentTime: now,
        settings: settings,
        theme: theme,
      );

      expect(capturedEvents, equals(events));
      expect(capturedActiveEvent, equals(activeEvent));
      expect(capturedCurrentTime, equals(now));
      expect(capturedSettings, equals(settings));
      expect(capturedColorScheme, equals(theme.colorScheme));
    });
  });
}
