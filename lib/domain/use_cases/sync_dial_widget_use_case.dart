import 'package:flutter/material.dart';

import '../../core/services/android_widget_service.dart';
import '../models/dial_settings.dart';
import '../models/sector_event.dart';

/// Pure domain Use Case responsible for coordinating synchronization between
/// Flutter routine data, dial styling, and the Android Home Screen AppWidget.
class SyncDialWidgetUseCase {
  final Future<void> Function({
    required List<SectorEvent> dayEvents,
    required DateTime currentTime,
    required DialSettings settings,
    required ColorScheme colorScheme,
    SectorEvent? activeEvent,
  })
  _syncWidget;

  SyncDialWidgetUseCase({
    Future<void> Function({
      required List<SectorEvent> dayEvents,
      required DateTime currentTime,
      required DialSettings settings,
      required ColorScheme colorScheme,
      SectorEvent? activeEvent,
    })?
    syncWidget,
  }) : _syncWidget = syncWidget ?? AndroidWidgetService.syncWidget;

  Future<void> execute({
    required List<SectorEvent> events,
    SectorEvent? activeEvent,
    required DateTime currentTime,
    required DialSettings settings,
    required ThemeData theme,
  }) async {
    await _syncWidget(
      dayEvents: events,
      currentTime: currentTime,
      settings: settings,
      colorScheme: theme.colorScheme,
      activeEvent: activeEvent,
    );
  }
}
