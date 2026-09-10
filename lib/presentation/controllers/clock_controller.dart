import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/local_event_repository.dart';
import '../../domain/models/dial_settings.dart';
import '../../domain/models/sector_event.dart';
import '../../domain/repositories/event_repository.dart';
import '../../domain/use_cases/quick_schedule_block_use_case.dart';
import '../../domain/use_cases/sync_dial_widget_use_case.dart';
import '../../domain/use_cases/sync_health_sessions_use_case.dart';

/// Provider for SharedPreferences instance.
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) {
  return null; // overridden in main() with actual instance
});

/// Provider for EventRepository.
final eventRepositoryProvider = Provider<EventRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocalEventRepository(prefs: prefs);
});

/// Explicit user-selected custom day (null when following live today).
final customSelectedDayProvider = StateProvider<DateTime?>((ref) => null);

/// Currently selected day for the dial and timeline.
/// If user hasn't explicitly navigated to another day, this automatically tracks today.
final selectedDayProvider = Provider<DateTime>((ref) {
  final custom = ref.watch(customSelectedDayProvider);
  if (custom != null) {
    return DateTime(custom.year, custom.month, custom.day);
  }
  final now = ref.watch(currentTimeProvider).value ?? DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Live stream of events for the selected day with computed concentric levels.
final dayEventsProvider = StreamProvider<List<SectorEvent>>((ref) {
  final repo = ref.watch(eventRepositoryProvider);
  final day = ref.watch(selectedDayProvider);
  return repo.watchEventsForDay(day);
});

/// Live stream of all events across days for seamless rolling widget horizons.
final allEventsProvider = StreamProvider<List<SectorEvent>>((ref) {
  final repo = ref.watch(eventRepositoryProvider);
  return repo.watchAllEvents();
});

/// Currently selected / focused event (tapped on dial or timeline).
final selectedEventProvider = StateProvider<SectorEvent?>((ref) => null);

/// Manual scrub angle in degrees (null when dial shows live real-time).
final dialScrubAngleProvider = StateProvider<double?>((ref) => null);

/// In 12H mode, which half of the day is visible: true = PM (12:00-24:00), false = AM (00:00-12:00), null = auto.
final viewing12HourHalfProvider = StateProvider<bool?>((ref) => null);

/// Live real-time clock ticker updating every second.
final currentTimeProvider = StreamProvider<DateTime>((ref) {
  return Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});

/// Active event taking place right now.
final currentActiveEventProvider = Provider<SectorEvent?>((ref) {
  final eventsAsync = ref.watch(allEventsProvider);
  final now = ref.watch(currentTimeProvider).value ?? DateTime.now();

  return eventsAsync.when(
    data: (events) {
      for (final event in events) {
        if (event.isCurrentlyActive(now)) {
          return event;
        }
      }
      return null;
    },
    loading: () => null,
    error: (_, _) => null,
  );
});

/// StateNotifier for DialSettings with persistent disk storage.
class DialSettingsNotifier extends StateNotifier<DialSettings> {
  final SharedPreferences? _prefs;

  DialSettingsNotifier(this._prefs) : super(const DialSettings()) {
    _loadFromDisk();
  }

  void _loadFromDisk() {
    final prefs = _prefs;
    if (prefs != null) {
      final is24 = prefs.getBool('setting_is24h');
      final themeStr = prefs.getString('setting_theme');
      final seedHex = prefs.getString('setting_seed_color');
      final faceStr = prefs.getString('setting_face_style');
      final sectorStr = prefs.getString('setting_sector_style');
      final handStr = prefs.getString('setting_hand_style');
      final clockDisplayStr = prefs.getString('setting_clock_display');
      final dialShapeStr = prefs.getString('setting_dial_shape');
      final pastHoursStr = prefs.getString('setting_past_hours_style');

      state = state.copyWith(
        is24HourMode: is24,
        themeMode: themeStr != null
            ? ThemeMode.values.firstWhere(
                (e) => e.name == themeStr,
                orElse: () => state.themeMode,
              )
            : null,
        seedColorHex: seedHex,
        faceStyle: faceStr != null
            ? DialFaceStyle.values.firstWhere(
                (e) => e.name == faceStr,
                orElse: () => state.faceStyle,
              )
            : null,
        sectorStyle: sectorStr != null
            ? SectorVisualTheme.values.firstWhere(
                (e) => e.name == sectorStr,
                orElse: () => state.sectorStyle,
              )
            : null,
        handStyle: handStr != null
            ? HandStyle.values.firstWhere(
                (e) => e.name == handStr,
                orElse: () => state.handStyle,
              )
            : null,
        centerClockDisplay: clockDisplayStr != null
            ? CenterClockDisplay.values.firstWhere(
                (e) => e.name == clockDisplayStr,
                orElse: () => state.centerClockDisplay,
              )
            : null,
        dialShape: dialShapeStr != null
            ? DialShape.values.firstWhere(
                (e) => e.name == dialShapeStr,
                orElse: () => state.dialShape,
              )
            : null,
        pastHoursStyle: pastHoursStr != null
            ? PastHoursStyle.values.firstWhere(
                (e) => e.name == pastHoursStr,
                orElse: () => state.pastHoursStyle,
              )
            : null,
      );
    }
  }

  Future<void> updateSettings(DialSettings newSettings) async {
    state = newSettings;
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.setBool('setting_is24h', newSettings.is24HourMode);
      await prefs.setString('setting_theme', newSettings.themeMode.name);
      await prefs.setString('setting_seed_color', newSettings.seedColorHex);
      await prefs.setString('setting_face_style', newSettings.faceStyle.name);
      await prefs.setString(
        'setting_sector_style',
        newSettings.sectorStyle.name,
      );
      await prefs.setString('setting_hand_style', newSettings.handStyle.name);
      await prefs.setString(
        'setting_clock_display',
        newSettings.centerClockDisplay.name,
      );
      await prefs.setString('setting_dial_shape', newSettings.dialShape.name);
      await prefs.setString(
        'setting_past_hours_style',
        newSettings.pastHoursStyle.name,
      );
    }
  }

  void setPastHoursStyle(PastHoursStyle style) {
    updateSettings(state.copyWith(pastHoursStyle: style));
  }

  void setDialShape(DialShape shape) {
    updateSettings(state.copyWith(dialShape: shape));
  }

  void toggle24HourMode() {
    updateSettings(state.copyWith(is24HourMode: !state.is24HourMode));
  }

  void setThemeMode(ThemeMode mode) {
    updateSettings(state.copyWith(themeMode: mode));
  }

  void setSeedColorHex(String hex) {
    updateSettings(state.copyWith(seedColorHex: hex));
  }

  void setFaceStyle(DialFaceStyle style) {
    updateSettings(state.copyWith(faceStyle: style));
  }

  void setSectorStyle(SectorVisualTheme style) {
    updateSettings(state.copyWith(sectorStyle: style));
  }

  void setHandStyle(HandStyle style) {
    updateSettings(state.copyWith(handStyle: style));
  }

  void setCenterClockDisplay(CenterClockDisplay display) {
    updateSettings(state.copyWith(centerClockDisplay: display));
  }

  void cycleCenterClockDisplay() {
    final current = state.centerClockDisplay;
    final next = switch (current) {
      CenterClockDisplay.both => CenterClockDisplay.digital,
      CenterClockDisplay.digital => CenterClockDisplay.analog,
      CenterClockDisplay.analog => CenterClockDisplay.both,
    };
    setCenterClockDisplay(next);
  }
}

final dialSettingsProvider =
    StateNotifierProvider<DialSettingsNotifier, DialSettings>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return DialSettingsNotifier(prefs);
    });

/// Domain Use Case Providers
final quickScheduleBlockUseCaseProvider = Provider<QuickScheduleBlockUseCase>((
  ref,
) {
  final repo = ref.watch(eventRepositoryProvider);
  return QuickScheduleBlockUseCase(
    eventRepository: repo,
    nowProvider: () => ref.read(currentTimeProvider).value ?? DateTime.now(),
  );
});

final syncHealthSessionsUseCaseProvider = Provider<SyncHealthSessionsUseCase>((
  ref,
) {
  final repo = ref.watch(eventRepositoryProvider);
  return SyncHealthSessionsUseCase(eventRepository: repo);
});

final syncDialWidgetUseCaseProvider = Provider<SyncDialWidgetUseCase>((ref) {
  return SyncDialWidgetUseCase();
});
