import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/time/zone_clock.dart';
import '../../domain/models/dial_settings.dart';
import '../../domain/models/sector_event.dart';
import '../../domain/schedule/occurrence_adapter.dart';
import '../../engine/dial_input.dart';
import '../../engine/dial_model_builder.dart';
import '../../presentation/widgets/dial/dial_painter.dart';
import '../geometry/sector_math.dart';

/// Service that renders a high-resolution offscreen image of the dial canvas
/// driven strictly by [DialModel] and [DialPainter] (§3.3, §4, §6).
abstract final class DialImageRenderer {
  /// Renders the Dial canvas to a PNG byte array using the canonical DialModel engine.
  static Future<Uint8List?> renderDialPng({
    required List<SectorEvent> events,
    required DateTime currentTime,
    required DialSettings settings,
    required ColorScheme colorScheme,
    SectorEvent? activeEvent,
    SectorEvent? selectedEvent,
    double size = 1080.0,
    bool showNeedle = true,
    bool showCenterClock = true,
  }) async {
    final occurrences = OccurrenceAdapter.fromSectorEvents(events);
    final clockSnapshot = ZoneClockSnapshot.fromDateTime(currentTime);

    final input = DialInput(
      clock: clockSnapshot,
      occurrences: occurrences,
      prefs: DialPrefs(
        is24HourMode: settings.is24HourMode,
        previousBlocksCount: settings.previousBlocksCount,
        futureBlocksCount: settings.futureBlocksCount,
        lensMagnification: settings.lensMagnification,
        isFocusLensEnabled: settings.isFocusLensEnabled,
        numeralSystem: settings.numeralSystem,
        secondaryTimeZone: settings.secondaryTimeZone,
        showTrueTimeRing: settings.showTrueTimeRing,
        showSubtaskPaceRing: settings.showSubtaskPaceRing,
        showHiddenBlocksIndicator: settings.showHiddenBlocksIndicator,
      ),
      surface: DialSurface(
        size: size,
        type: DialSurfaceType.widget,
      ),
    );

    final model = DialModelBuilder.build(input);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paintSize = Size(size, size);

    final theme = ThemeData(
      colorScheme: colorScheme,
      brightness: colorScheme.brightness,
    );

    final painter = DialPainter(
      model: model,
      settings: settings,
      theme: theme,
      colorScheme: colorScheme,
      showCenterClock: showCenterClock,
      showNeedle: showNeedle,
      selectedEventId: selectedEvent?.id,
    );

    painter.paint(canvas, paintSize);

    final picture = recorder.endRecording();
    final image = picture.toImageSync(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData?.buffer.asUint8List();
  }

  /// Calculates angular focus parameters for legacy widgets or diagnostics.
  static ({double focusAngle, double magnification, bool isFocusLensEnabled})
  computeLensParameters({
    required List<SectorEvent> events,
    required DateTime currentTime,
    required DialSettings settings,
    SectorEvent? activeEvent,
    SectorEvent? selectedEvent,
  }) {
    SectorEvent? resolvedActive = activeEvent;
    if (resolvedActive == null) {
      for (final e in events) {
        if (!currentTime.isBefore(e.start) && currentTime.isBefore(e.end)) {
          resolvedActive = e;
          break;
        }
      }
    }

    final focusEvent = selectedEvent ?? resolvedActive;
    final double focusAngle;
    if (focusEvent != null) {
      final halfDuration = Duration(
        minutes: focusEvent.duration.inMinutes ~/ 2,
      );
      focusAngle = SectorMath.timeToDialAngle(
        focusEvent.start.add(halfDuration),
        is24HourMode: settings.is24HourMode,
      );
    } else {
      focusAngle = SectorMath.timeToDialAngle(
        currentTime,
        is24HourMode: settings.is24HourMode,
      );
    }

    final activeMagnification =
        (focusEvent != null && focusEvent.subtasks.isNotEmpty)
        ? math.max(settings.lensMagnification, 2.05)
        : (selectedEvent != null
              ? math.max(settings.lensMagnification, 1.85)
              : settings.lensMagnification);

    return (
      focusAngle: focusAngle,
      magnification: activeMagnification,
      isFocusLensEnabled: settings.isFocusLensEnabled,
    );
  }
}
