import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../domain/models/dial_settings.dart';
import '../../domain/models/sector_event.dart';
import '../utils/time_formatters.dart';
import 'dial_image_renderer.dart';

/// Service that coordinates synchronization between Flutter routine data
/// and the native Android Home Screen AppWidget.
class AndroidWidgetService {
  static const MethodChannel _channel = MethodChannel(
    'com.ksmxtech.sectograph_mcp/widget',
  );

  static bool isEnabled = true;

  static bool get isSupported =>
      isEnabled &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      !WidgetsBinding.instance.runtimeType.toString().contains('Test');

  static void Function(String action)? onActionReceived;

  static void initialize({void Function(String action)? onAction}) {
    if (!isSupported) return;
    onActionReceived = onAction;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onWidgetAction') {
        final action = call.arguments as String?;
        if (action != null) {
          onActionReceived?.call(action);
        }
      }
    });
  }

  /// Checks if the app was launched by a widget shortcut action.
  static Future<String?> getInitialAction() async {
    if (!isSupported) return null;
    try {
      return await _channel.invokeMethod<String>('getInitialAction');
    } catch (_) {
      return null;
    }
  }

  /// Requests the Android OS to pin the Sectograph widget to the user's home screen.
  static Future<bool> requestPinWidget() async {
    if (!isSupported) return false;
    try {
      final success = await _channel.invokeMethod<bool>('pinWidget');
      return success ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Synchronizes current schedule, active routine block, and rendered dial image
  /// with the Android home screen widget.
  static Future<void> syncWidget({
    required List<SectorEvent> dayEvents,
    required DateTime currentTime,
    required DialSettings settings,
    required ColorScheme colorScheme,
    SectorEvent? activeEvent,
  }) async {
    if (!isSupported) return;
    try {
      final is24 = settings.is24HourMode;
      String title;
      String time;
      String status;
      final date = DateFormat('EEE, d MMM').format(currentTime);

      if (activeEvent != null) {
        title = activeEvent.title;
        time =
            '${TimeFormatters.formatTime(activeEvent.start, is24Hour: is24)} – ${TimeFormatters.formatTime(activeEvent.end, is24Hour: is24)}';
        final remaining = activeEvent.end.difference(currentTime).inMinutes;
        status = 'REMAINING ${remaining > 0 ? '${remaining}m' : '0m'}';
      } else {
        // Find next upcoming event today
        final upcoming =
            dayEvents
                .where((e) => e.start.isAfter(currentTime) && !e.isAllDay)
                .toList()
              ..sort((a, b) => a.start.compareTo(b.start));

        if (upcoming.isNotEmpty) {
          final next = upcoming.first;
          title = next.title;
          time =
              '${TimeFormatters.formatTime(next.start, is24Hour: is24)} – ${TimeFormatters.formatTime(next.end, is24Hour: is24)}';
          final inMinutes = next.start.difference(currentTime).inMinutes;
          status = 'STARTS IN ${inMinutes > 0 ? '${inMinutes}m' : '1m'}';
        } else {
          title = 'Dial is clear';
          time = 'Plan your day';
          status = 'ALL CLEAR';
        }
      }

      // Render 1:1 circular dial image offscreen
      final dialBytes = await DialImageRenderer.renderDialPng(
        events: dayEvents,
        currentTime: currentTime,
        settings: settings,
        colorScheme: colorScheme,
        activeEvent: activeEvent,
        size: 1024.0,
      );

      await _channel.invokeMethod('updateWidget', {
        'title': title,
        'time': time,
        'status': status,
        'date': date,
        'dialBytes': dialBytes,
      });
    } catch (_) {
      // Ignored if platform channel is unavailable (e.g. running unit tests)
    }
  }
}
