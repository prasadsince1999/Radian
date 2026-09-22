import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/models/dial_settings.dart';
import '../../domain/models/sector_event.dart';
import '../../presentation/widgets/dial/sectograph_painter.dart';
import '../geometry/concentric_solver.dart';
import '../geometry/dial_sector_layout_stretcher.dart';
import '../geometry/fisheye_time_lens.dart';
import '../geometry/focused_block_layout_resolver.dart';
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
    double size = 1080.0,
    bool showNeedle = true,
    bool showCenterClock = true,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paintSize = Size(size, size);

    // Filter events to the active horizon:
    // In 24-hour mode, show events within the 24-hour calendar day of currentTime.
    // In 12-hour mode, show events within the rolling 12-hour window around currentTime,
    // matching the in-app dial display so AM and PM events never collide.
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
      final withAngles = dayEvents
          .map((e) => e.withComputedAngles(is24HourMode: true))
          .toList();
      final solved = ConcentricSolver.solve(withAngles);
      positionedEvents = withAngles.map((e) {
        final levels = solved[e];
        if (levels != null) {
          return e.copyWith(
            topLevel: levels.topLevel,
            bottomLevel: levels.bottomLevel,
          );
        }
        return e;
      }).toList();
    } else {
      // Dynamic rolling 12-hour horizon around currentTime:
      // In 12H mode, only events within 12 hours of currentTime are displayed.
      final rawEvents = <SectorEvent>[];
      for (final e in events) {
        // Skip events that are more than 12 hours ahead in 12H mode
        if (e.start.difference(currentTime).inMinutes >= 720) {
          continue;
        }
        final isFocusedBlock =
            settings.pastHoursStyle == PastHoursStyle.focusedBlock;
        if (isFocusedBlock) {
          // In focused block mode, allow past events within 12 hours so FocusedBlockLayoutResolver
          // can select the configured previousBlocksCount (0..3).
          if (currentTime.difference(e.end).inMinutes >= 720) {
            continue;
          }
        } else {
          // Skip events that completed more than 15 minutes before currentTime (unless active)
          if (e.end.isBefore(
                currentTime.subtract(const Duration(minutes: 15)),
              ) &&
              !(!currentTime.isBefore(e.start) &&
                  currentTime.isBefore(e.end))) {
            continue;
          }
        }

        final duration = e.end.difference(e.start);
        if (duration.inMinutes > 0) {
          final startAngle = SectorMath.timeToDialAngle(
            e.start,
            is24HourMode: false,
          );
          final sweepAngle = SectorMath.durationToSweepAngle(
            duration,
            is24HourMode: false,
          );

          rawEvents.add(
            e.copyWith(
              topLevel: 0,
              bottomLevel: 1000,
              startAngle: startAngle,
              sweepAngle: sweepAngle,
            ),
          );
        }
      }
      final solved = ConcentricSolver.solve(rawEvents);
      positionedEvents = rawEvents.map((e) {
        final levels = solved[e];
        if (levels != null) {
          return e.copyWith(
            topLevel: levels.topLevel,
            bottomLevel: levels.bottomLevel,
          );
        }
        return e;
      }).toList();
    }

    final isFocusedBlockMode =
        settings.pastHoursStyle == PastHoursStyle.focusedBlock;
    final FocusedHorizonResult? horizonResult = isFocusedBlockMode
        ? FocusedBlockLayoutResolver.resolve(
            events: positionedEvents,
            effectiveTime: currentTime,
            selectedEvent: selectedEvent,
            is24HourMode: settings.is24HourMode,
            previousBlocksCount: settings.previousBlocksCount,
            futureBlocksCount: settings.futureBlocksCount,
          )
        : null;

    final baseDisplayEvents = horizonResult != null
        ? horizonResult.visibleEvents
        : positionedEvents;

    SectorEvent? resolvedActive = activeEvent;
    if (horizonResult?.activeEvent != null) {
      resolvedActive = horizonResult!.activeEvent;
    }
    if (resolvedActive == null) {
      for (final e in positionedEvents) {
        if (!currentTime.isBefore(e.start) && currentTime.isBefore(e.end)) {
          resolvedActive = e;
          break;
        }
      }
    }

    final lensParams = computeLensParameters(
      events: positionedEvents,
      currentTime: currentTime,
      settings: settings,
      activeEvent: resolvedActive,
      selectedEvent: selectedEvent,
    );

    final lens = lensParams.isFocusLensEnabled
        ? FisheyeTimeLens(
            focusAngle: lensParams.focusAngle,
            magnification: lensParams.magnification,
          )
        : const FisheyeTimeLens.linear();

    final warpedEvents = baseDisplayEvents.map((e) {
      final warped = lens.warpSector(
        startDeg: e.startAngle,
        sweepDeg: e.sweepAngle,
      );
      return e.copyWith(
        startAngle: warped.startDeg,
        sweepAngle: warped.sweepDeg,
      );
    }).toList();

    final finalDisplayEvents = DialSectorLayoutStretcher.stretch(
      warpedEvents,
      is24HourMode: settings.is24HourMode,
      activeEventId: resolvedActive?.id,
      selectedEventId: selectedEvent?.id,
      currentTime: currentTime,
    );

    final painter = SectographPainter(
      events: finalDisplayEvents,
      selectedEvent: selectedEvent,
      activeEvent: resolvedActive,
      currentTime: currentTime,
      scrubAngle: null,
      settings: settings,
      colorScheme: colorScheme,
      showCenterClock: showCenterClock,
      showNeedle: showNeedle,
      lens: lens,
    );

    painter.paint(canvas, paintSize);

    final picture = recorder.endRecording();
    final image = picture.toImageSync(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData?.buffer.asUint8List();
  }

  /// Computes lens parameters (focusAngle, magnification, isFocusLensEnabled) for widget needle sync.
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
