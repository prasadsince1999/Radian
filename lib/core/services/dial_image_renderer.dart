import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/models/dial_settings.dart';
import '../../domain/models/sector_event.dart';
import '../../presentation/widgets/dial/sectograph_painter.dart';
import '../geometry/sector_math.dart';

/// Service that renders a high-resolution offscreen image of the Sectograph dial
/// for use in native home screen widgets, notifications, or wear tiles.
abstract final class DialImageRenderer {
  /// Renders the Sectograph dial canvas to a PNG byte array.
  static Future<Uint8List?> renderDialPng({
    required List<SectorEvent> events,
    required DateTime currentTime,
    required DialSettings settings,
    required ColorScheme colorScheme,
    SectorEvent? activeEvent,
    SectorEvent? selectedEvent,
    double size = 1024.0,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paintSize = Size(size, size);

    // Filter events to the active horizon:
    // In 24-hour mode, show events within the 24-hour calendar day of currentTime.
    // In 12-hour mode, show events within the active 12-hour half (AM: 00:00-12:00 or PM: 12:00-24:00)
    // matching the in-app dial display so AM and PM events never overlap.
    final List<SectorEvent> positionedEvents;
    if (settings.is24HourMode) {
      final todayStart = DateTime(
        currentTime.year,
        currentTime.month,
        currentTime.day,
      );
      final todayEnd = DateTime(
        todayStart.year,
        todayStart.month,
        todayStart.day + 1,
      );
      final dayEvents = events.where((e) {
        return e.start.isBefore(todayEnd) && e.end.isAfter(todayStart);
      }).toList();
      positionedEvents = dayEvents
          .map((e) => e.withComputedAngles(is24HourMode: true))
          .toList();
    } else {
      final isPm = currentTime.hour >= 12;
      final halfStart = DateTime(
        currentTime.year,
        currentTime.month,
        currentTime.day,
        isPm ? 12 : 0,
      );
      final halfEnd = halfStart.add(const Duration(hours: 12));
      final halfEvents = events.where((e) {
        return e.start.isBefore(halfEnd) && e.end.isAfter(halfStart);
      }).toList();

      positionedEvents = [];
      for (final e in halfEvents) {
        final visibleStart = e.start.isBefore(halfStart) ? halfStart : e.start;
        final visibleEnd = e.end.isAfter(halfEnd) ? halfEnd : e.end;
        final visibleDuration = visibleEnd.difference(visibleStart);
        if (visibleDuration.inMinutes > 0) {
          final startAngle = SectorMath.timeToDialAngle(
            visibleStart,
            is24HourMode: false,
          );
          final sweepAngle = SectorMath.durationToSweepAngle(
            visibleDuration,
            is24HourMode: false,
          );
          positionedEvents.add(
            e.copyWith(
              topLevel: 0,
              bottomLevel: 1000,
              startAngle: startAngle,
              sweepAngle: sweepAngle,
            ),
          );
        }
      }
    }

    final painter = SectographPainter(
      events: positionedEvents,
      selectedEvent: selectedEvent,
      activeEvent: activeEvent,
      currentTime: currentTime,
      scrubAngle: null,
      settings: settings,
      colorScheme: colorScheme,
      showCenterClock: true,
    );

    painter.paint(canvas, paintSize);

    final picture = recorder.endRecording();
    final image = picture.toImageSync(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData?.buffer.asUint8List();
  }
}
