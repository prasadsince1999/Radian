import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/constants/app_layout_constants.dart';
import '../../../core/geometry/dial_time_cap_drag_handler.dart';
import '../../../core/geometry/fisheye_time_lens.dart';
import '../../../core/geometry/sector_math.dart';
import '../../../domain/models/dial_settings.dart';
import '../../../domain/models/sector_event.dart';
import 'components/dial_bezel_renderer.dart';
import 'components/hour_needle_renderer.dart';
import 'components/sector_content_renderer.dart';
import 'components/sector_pill_renderer.dart';

/// Master dial painter for Sectograph.
///
/// Cleanly orchestrates specialized, reusable components:
/// - [SectorPillRenderer]: 3D curved pill geometry, vibrant fills (zero dimming), boundary timestamps.
/// - [SectorContentRenderer]: Arc-aligned typography, guaranteed boundary clipping, time range formatting.
/// - [HourNeedleRenderer]: Two-stage hierarchical needle, glow, and celestial beacon.
/// - [DialBezelRenderer]: Numeral-free bezel ring, tick marks, and concentric dividers.
class SectographPainter extends CustomPainter {
  final List<SectorEvent> events;
  final SectorEvent? selectedEvent;
  final SectorEvent? activeEvent;
  final DateTime currentTime;
  final double? scrubAngle;
  final DialSettings settings;
  final ColorScheme colorScheme;
  final bool showCenterClock;
  final bool showNeedle;
  final FisheyeTimeLens? lens;
  final CapHitResult? activeDraggingCap;
  final bool isDialEditing;

  SectographPainter({
    required this.events,
    required this.selectedEvent,
    required this.activeEvent,
    required this.currentTime,
    required this.scrubAngle,
    required this.settings,
    required this.colorScheme,
    this.showCenterClock = false,
    this.showNeedle = true,
    this.lens,
    this.activeDraggingCap,
    this.isDialEditing = false,
  });

  static const int scallopLobes = AppLayoutConstants.scallopLobes;
  static const double referenceCanvasSize = 360.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final scale = math.min(size.width, size.height) / referenceCanvasSize;
    canvas.save();
    final dx = (size.width - referenceCanvasSize * scale) / 2.0;
    final dy = (size.height - referenceCanvasSize * scale) / 2.0;
    canvas.translate(dx, dy);
    canvas.scale(scale, scale);

    _paintReference(
      canvas,
      const Size(referenceCanvasSize, referenceCanvasSize),
    );
    canvas.restore();
  }

  void _paintReference(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final isWave = settings.dialShape == DialShape.waveRounded;
    final scallopAmp = isWave ? 5.0 : 0.0;
    final maxRadius = (math.min(size.width, size.height) / 2) - 4.0;
    final baseRadius = maxRadius - scallopAmp;
    final innerRadius = baseRadius * AppLayoutConstants.innerRadiusRatio;
    final radialThickness = baseRadius - innerRadius;
    final routineTrackIn =
        innerRadius + AppLayoutConstants.routineTrackInnerOffset;
    final routineTrackOut =
        baseRadius - AppLayoutConstants.routineTrackOuterMargin;

    // 1. Dial chassis with radial spokes & dark slate face
    _drawDialBackground(
      canvas,
      center,
      baseRadius,
      innerRadius,
      isWave: isWave,
      scallopAmp: scallopAmp,
    );

    // 2. Rounded pill arc routine sectors with full vibrancy, arc typography & boundary timestamps
    _drawSectors(canvas, center, baseRadius, innerRadius, radialThickness);

    // 3. Subtle dial bezel outline
    _drawDialOutline(
      canvas,
      center,
      baseRadius,
      isWave: isWave,
      scallopAmp: scallopAmp,
    );

    // 4. 3D hour numbers positioned half over the block and half outside
    DialBezelRenderer.drawTicks(
      canvas: canvas,
      center: center,
      radius: baseRadius - 1.0,
      trackOuterRadius: routineTrackOut,
      is24HourMode: settings.is24HourMode,
      faceStyle: settings.faceStyle,
      colorScheme: colorScheme,
      lens: lens,
    );

    // 5. Two-stage hierarchical "NOW" hour needle & celestial beacon
    if (showNeedle) {
      _drawDayNightSweep(
        canvas,
        center,
        baseRadius,
        innerRadius,
        routineTrackIn,
        routineTrackOut,
      );
    }

    // 6. Rich center clock face for offscreen / widget rendering
    if (showCenterClock &&
        settings.centerClockDisplay != CenterClockDisplay.analog) {
      _drawCenterClockFace(canvas, center, innerRadius);
    }
  }

  Path _buildScallopPath(Offset center, double baseRadius, double scallopAmp) {
    final path = Path();
    const steps = 360;
    for (int i = 0; i <= steps; i++) {
      final angle = (i * 2 * math.pi) / steps;
      final r = baseRadius + scallopAmp * math.cos(scallopLobes * angle);
      final x = center.dx + r * math.cos(angle - math.pi / 2);
      final y = center.dy + r * math.sin(angle - math.pi / 2);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  void _drawDialBackground(
    Canvas canvas,
    Offset center,
    double baseRadius,
    double innerRadius, {
    required bool isWave,
    required double scallopAmp,
  }) {
    final isDark = colorScheme.brightness == Brightness.dark;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: isDark ? 0.65 : 0.12)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, isDark ? 5.0 : 6.0);

    final dialBgColor = colorScheme.surfaceContainerLowest;
    final bgPaint = Paint()
      ..color = dialBgColor
      ..style = PaintingStyle.fill;

    if (isWave) {
      final scallopPath = _buildScallopPath(center, baseRadius, scallopAmp);
      canvas.drawPath(scallopPath, shadowPaint);
      canvas.drawPath(scallopPath, bgPaint);
    } else {
      canvas.drawCircle(center, baseRadius, shadowPaint);
      canvas.drawCircle(center, baseRadius, bgPaint);
    }

    // Radial hour division spokes
    final spokePaint = Paint()
      ..color = colorScheme.outlineVariant.withValues(
        alpha: isDark ? 0.35 : 0.45,
      )
      ..strokeWidth = 1.0;
    final totalHours = settings.is24HourMode ? 24 : 12;
    final stepAngle = 360.0 / totalHours;
    for (var h = 0; h < totalHours; h++) {
      final deg = h * stepAngle;
      final rad = SectorMath.dialAngleToCanvasRadians(deg);
      final p1 = Offset(
        center.dx + innerRadius * math.cos(rad),
        center.dy + innerRadius * math.sin(rad),
      );
      final p2 = Offset(
        center.dx + (baseRadius - 8.0) * math.cos(rad),
        center.dy + (baseRadius - 8.0) * math.sin(rad),
      );
      canvas.drawLine(p1, p2, spokePaint);
    }
  }

  void _drawDialOutline(
    Canvas canvas,
    Offset center,
    double baseRadius, {
    required bool isWave,
    required double scallopAmp,
  }) {
    final outlinePaint = Paint()
      ..color = colorScheme.outlineVariant.withValues(alpha: 0.60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    if (isWave) {
      final scallopPath = _buildScallopPath(center, baseRadius, scallopAmp);
      canvas.drawPath(scallopPath, outlinePaint);
    } else {
      canvas.drawCircle(center, baseRadius, outlinePaint);
    }
  }

  void _drawDayNightSweep(
    Canvas canvas,
    Offset center,
    double baseRadius,
    double innerRadius,
    double routineTrackIn,
    double routineTrackOut,
  ) {
    final is24 = settings.is24HourMode;
    final nowAngle = SectorMath.timeToDialAngle(
      currentTime,
      is24HourMode: is24,
    );
    final rawAngle = scrubAngle ?? nowAngle;
    final effectiveAngle = lens?.warpAngle(rawAngle) ?? rawAngle;
    final nowRad = SectorMath.dialAngleToCanvasRadians(effectiveAngle);
    final isDaytime = currentTime.hour >= 6 && currentTime.hour < 18;

    HourNeedleRenderer.drawNeedle(
      canvas: canvas,
      center: center,
      angleRad: nowRad,
      hubRadius: innerRadius,
      outerROut: routineTrackOut,
      baseRadius: baseRadius,
      isDaytime: isDaytime,
    );
  }

  void _drawSectors(
    Canvas canvas,
    Offset center,
    double baseRadius,
    double innerRadius,
    double radialThickness,
  ) {
    final routineTrackIn =
        innerRadius + AppLayoutConstants.routineTrackInnerOffset;
    final routineTrackOut =
        baseRadius - AppLayoutConstants.routineTrackOuterMargin;
    const double defaultSectorGapDeg = 2.0;

    final is24 = settings.is24HourMode;
    DateTime effectiveTime = currentTime;
    if (scrubAngle != null) {
      final currentAngle = SectorMath.timeToDialAngle(
        currentTime,
        is24HourMode: is24,
      );
      final degPerMin = is24
          ? SectorMath.degreesPerMinute24H
          : SectorMath.degreesPerMinute12H;
      var diff = scrubAngle! - currentAngle;
      if (diff > 180.0) diff -= 360.0;
      if (diff < -180.0) diff += 360.0;
      final deltaMinutes = (diff / degPerMin).round();
      effectiveTime = currentTime.add(Duration(minutes: deltaMinutes));
    }

    bool isEventActive(SectorEvent e) {
      return !effectiveTime.isBefore(e.start) && effectiveTime.isBefore(e.end);
    }

    // Pre-analyze contiguous relationships on the dial face (checking both DateTime and dial angles)
    bool areContiguous(SectorEvent a, SectorEvent b) {
      if ((a.end.difference(b.start).inMinutes).abs() <= 2) return true;
      // Also check cyclic wrap on the dial face (e.g. crossing midnight / next-day wrap)
      final aEndAngle = (a.startAngle + a.sweepAngle) % 360.0;
      final bStartAngle = b.startAngle % 360.0;
      final diff = (aEndAngle - bStartAngle).abs();
      final angularDist = diff > 180.0 ? 360.0 - diff : diff;
      return angularDist <= 0.8;
    }

    // In a strict single-ring system, all blocks span the uniform track (routineTrackIn to routineTrackOut).
    // Sort events so longer blocks are drawn first and shorter / selected blocks are drawn on top,
    // ensuring no block is hidden on the single ring.
    final renderEvents = List<SectorEvent>.from(events)
      ..sort((a, b) {
        if (selectedEvent != null) {
          if (a.id == selectedEvent!.id) return 1;
          if (b.id == selectedEvent!.id) return -1;
        }
        return b.duration.compareTo(a.duration);
      });

    final hasContiguousPredecessor = List<bool>.filled(
      renderEvents.length,
      false,
    );
    final hasContiguousSuccessor = List<bool>.filled(
      renderEvents.length,
      false,
    );

    for (int i = 0; i < renderEvents.length; i++) {
      final event = renderEvents[i];
      for (int j = 0; j < renderEvents.length; j++) {
        if (i == j) continue;
        final other = renderEvents[j];
        if (areContiguous(other, event)) {
          hasContiguousPredecessor[i] = true;
        }
        if (areContiguous(event, other)) {
          hasContiguousSuccessor[i] = true;
        }
      }
    }

    final drawnTimestampAngles = <double>[];
    bool angleAlreadyDrawn(double deg) {
      const threshold = 1.0;
      for (final angle in drawnTimestampAngles) {
        final diff = ((deg - angle).abs()) % 360.0;
        final angularDistance = diff > 180.0 ? 360.0 - diff : diff;
        if (angularDistance < threshold) return true;
      }
      return false;
    }

    final double overlapDeg = is24 ? 0.8 : 1.2; // Squeezed 3D overlap extension

    // Prepare layout data for each event on the single uniform track
    final pillLayouts =
        <
          ({
            SectorEvent event,
            bool isActive,
            bool isSelected,
            double rIn,
            double rOut,
            double startDeg,
            double sweepDeg,
            double cornerRadius,
            Path pillPath,
            bool showStartCap,
            double startCapSpan,
            bool showEndCap,
            double endCapStartDeg,
            double endCapSpan,
            bool isContiguous,
          })
        >[];

    for (int i = 0; i < renderEvents.length; i++) {
      final event = renderEvents[i];
      if (event.sweepAngle <= 1.0) continue;

      final isActive = isEventActive(event);
      final isSelected = selectedEvent?.id == event.id;

      final startGap = hasContiguousPredecessor[i]
          ? 0.0
          : (defaultSectorGapDeg / 2.0);
      final endGap = hasContiguousSuccessor[i]
          ? 0.0
          : (defaultSectorGapDeg / 2.0);
      final startDeg = event.startAngle + startGap;
      final sweepDeg = (event.sweepAngle - startGap - endGap).clamp(3.0, 360.0);

      // Strictly single ring: full uniform track thickness for every block
      final eventRIn = routineTrackIn;
      final eventROut = routineTrackOut;
      final cornerRadius = math
          .min(8.0, (routineTrackOut - routineTrackIn) * 0.22)
          .clamp(3.0, 8.0);

      final isContiguous = hasContiguousSuccessor[i];
      // Standardized time badge cap span matching Image 3 (08:30)
      final standardCapSpan = is24
          ? AppLayoutConstants.standardCapSpanDeg24H
          : AppLayoutConstants.standardCapSpanDeg12H;
      final baseCapSpanDeg = math.min(standardCapSpan, sweepDeg * 0.35);

      final isActivelyDraggingThis =
          activeDraggingCap != null && activeDraggingCap!.event.id == event.id;

      final minSweepForCaps = is24
          ? AppLayoutConstants.minSweepForCaps24H
          : AppLayoutConstants.minSweepForCaps12H;
      final canShowStartCap =
          (isActivelyDraggingThis &&
              (activeDraggingCap!.isStartCap ||
                  activeDraggingCap!.isEntireBlock)) ||
          (!hasContiguousPredecessor[i] &&
              sweepDeg >= minSweepForCaps &&
              !angleAlreadyDrawn(startDeg));
      final canShowEndCap =
          (isActivelyDraggingThis &&
              (activeDraggingCap!.isEndCap ||
                  activeDraggingCap!.isEntireBlock)) ||
          (sweepDeg >= minSweepForCaps &&
              !angleAlreadyDrawn(startDeg + sweepDeg));

      final startCapSpan = canShowStartCap ? baseCapSpanDeg : 0.0;
      final endCapSpan = canShowEndCap
          ? baseCapSpanDeg + (isContiguous ? overlapDeg : 0.0)
          : 0.0;
      final endBoundaryDeg = startDeg + sweepDeg;
      final capEndDeg = endBoundaryDeg + (isContiguous ? overlapDeg : 0.0);
      final endCapStartDeg = capEndDeg - endCapSpan;

      final pillPath = SectorPillRenderer.buildPillPath(
        center: center,
        rIn: eventRIn,
        rOut: eventROut,
        startDeg: startDeg,
        sweepDeg: sweepDeg,
        cornerRadius: cornerRadius,
        roundStart: !hasContiguousPredecessor[i],
        roundEnd: !hasContiguousSuccessor[i],
      );

      pillLayouts.add((
        event: event,
        isActive: isActive,
        isSelected: isSelected,
        rIn: eventRIn,
        rOut: eventROut,
        startDeg: startDeg,
        sweepDeg: sweepDeg,
        cornerRadius: cornerRadius,
        pillPath: pillPath,
        showStartCap: canShowStartCap,
        startCapSpan: startCapSpan,
        showEndCap: canShowEndCap,
        endCapStartDeg: endCapStartDeg,
        endCapSpan: endCapSpan,
        isContiguous: isContiguous,
      ));

      if (canShowStartCap) {
        drawnTimestampAngles.add(startDeg);
      }
      if (canShowEndCap) {
        drawnTimestampAngles.add(endBoundaryDeg);
      }
    }

    // Pass 1: Draw ALL pill bodies first (pure solid vibrant fills, zero borders, zero shadows)
    for (final l in pillLayouts) {
      SectorPillRenderer.drawPillBody(
        canvas: canvas,
        pillPath: l.pillPath,
        event: l.event,
        isActive: l.isActive,
        isSelected: l.isSelected,
      );

      if (l.event.subtasks.length > 1) {
        SectorPillRenderer.drawSubtaskNotches(
          canvas: canvas,
          center: center,
          rIn: l.rIn,
          startDeg: l.startDeg,
          sweepDeg: l.sweepDeg,
          subtaskCount: l.event.subtasks.length,
          eventColor: l.event.color,
        );
      }
    }

    // Pass 2: Draw 3D Overlapping End Caps with drop shadows ON TOP of successor blocks!
    for (final l in pillLayouts) {
      if (l.showEndCap) {
        SectorPillRenderer.drawIntegratedCap(
          canvas: canvas,
          center: center,
          rIn: l.rIn,
          rOut: l.rOut,
          startDeg: l.endCapStartDeg,
          sweepDeg: l.endCapSpan,
          time: l.event.end,
          eventColor: l.event.color,
          isStartCap: false,
          is24HourMode: is24,
          cornerRadius: l.cornerRadius,
          roundStart: false,
          roundEnd: true,
          isContiguous: l.isContiguous,
          overlapDeg: l.isContiguous ? overlapDeg : 0.0,
        );

        if (activeDraggingCap != null &&
            l.event.id == activeDraggingCap!.event.id &&
            (!activeDraggingCap!.isStartCap ||
                activeDraggingCap!.isEntireBlock)) {
          final highlightPath = SectorPillRenderer.buildPillPath(
            center: center,
            rIn: l.rIn - 2.0,
            rOut: l.rOut + 2.0,
            startDeg: l.endCapStartDeg,
            sweepDeg: l.endCapSpan,
            cornerRadius: l.cornerRadius,
            roundStart: false,
            roundEnd: true,
          );
          canvas.drawPath(
            highlightPath,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.0,
          );
        }
      }
    }

    // Pass 3: Draw Start Caps for isolated events
    for (final l in pillLayouts) {
      if (l.showStartCap) {
        SectorPillRenderer.drawIntegratedCap(
          canvas: canvas,
          center: center,
          rIn: l.rIn,
          rOut: l.rOut,
          startDeg: l.startDeg,
          sweepDeg: l.startCapSpan,
          time: l.event.start,
          eventColor: l.event.color,
          isStartCap: true,
          is24HourMode: is24,
          cornerRadius: l.cornerRadius,
          roundStart: true,
          roundEnd: false,
        );

        if (activeDraggingCap != null &&
            l.event.id == activeDraggingCap!.event.id &&
            (activeDraggingCap!.isStartCap ||
                activeDraggingCap!.isEntireBlock)) {
          final highlightPath = SectorPillRenderer.buildPillPath(
            center: center,
            rIn: l.rIn - 2.0,
            rOut: l.rOut + 2.0,
            startDeg: l.startDeg,
            sweepDeg: l.startCapSpan,
            cornerRadius: l.cornerRadius,
            roundStart: true,
            roundEnd: false,
          );
          canvas.drawPath(
            highlightPath,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.0,
          );
        }
      }
    }

    // Pass 4: Visual Schedule Edit Mode Boundary Outlines & Grab Handles
    if (isDialEditing) {
      for (final l in pillLayouts) {
        // Outline the block: bright white for selected, luminous stroke for others
        final outlinePaint = Paint()
          ..color = l.isSelected
              ? Colors.white
              : Colors.white.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = l.isSelected ? 2.4 : 1.2;
        canvas.drawPath(l.pillPath, outlinePaint);

        // Tactile grab handles at outer boundary corners (never overlaps internal time badges!)
        final handleR = l.rOut;

        // 1. Start grab handle
        final startAngle = l.startDeg;
        final startRad = SectorMath.dialAngleToCanvasRadians(startAngle);
        final startPos = Offset(
          center.dx + handleR * math.cos(startRad),
          center.dy + handleR * math.sin(startRad),
        );
        final isDraggingStart =
            activeDraggingCap != null &&
            l.event.id == activeDraggingCap!.event.id &&
            (activeDraggingCap!.isStartCap || activeDraggingCap!.isEntireBlock);
        _drawGrabHandle(
          canvas: canvas,
          position: startPos,
          isDragging: isDraggingStart,
          baseColor: l.event.color,
        );

        // 2. End grab handle
        final endAngle = l.startDeg + l.sweepDeg;
        final endRad = SectorMath.dialAngleToCanvasRadians(endAngle);
        final endPos = Offset(
          center.dx + handleR * math.cos(endRad),
          center.dy + handleR * math.sin(endRad),
        );
        final isDraggingEnd =
            activeDraggingCap != null &&
            l.event.id == activeDraggingCap!.event.id &&
            (activeDraggingCap!.isEndCap || activeDraggingCap!.isEntireBlock);
        _drawGrabHandle(
          canvas: canvas,
          position: endPos,
          isDragging: isDraggingEnd,
          baseColor: l.event.color,
        );
      }
    }

    // Determine which events display subtasks on the dial:
    // User rule: only show previous one, current one, and upcoming one (plus selectedEvent).
    final subtaskAllowedEventIds = <String>{};
    if (events.isNotEmpty) {
      SectorEvent? current = activeEvent;
      if (current == null) {
        for (final e in events) {
          if (!currentTime.isBefore(e.start) && currentTime.isBefore(e.end)) {
            current = e;
            break;
          }
        }
      }
      current ??= selectedEvent;
      if (current == null) {
        for (final e in events) {
          if (e.start.isAfter(currentTime)) {
            if (current == null || e.start.isBefore(current.start)) {
              current = e;
            }
          }
        }
      }

      if (current != null) {
        subtaskAllowedEventIds.add(current.id);

        // Find immediate previous event (prev1) ending closest to current.start
        SectorEvent? prev1;
        Duration minPrevDiff = const Duration(days: 999);
        for (final e in events) {
          if (e.id == current.id) continue;
          if (e.end.isBefore(current.start) ||
              e.end.isAtSameMomentAs(current.start)) {
            final diff = current.start.difference(e.end);
            if (diff < minPrevDiff) {
              minPrevDiff = diff;
              prev1 = e;
            }
          }
        }
        if (prev1 != null) {
          subtaskAllowedEventIds.add(prev1.id);
        }

        // Find immediate upcoming event (next1) starting closest after current.end
        SectorEvent? next1;
        Duration minNextDiff = const Duration(days: 999);
        for (final e in events) {
          if (e.id == current.id) continue;
          if (e.start.isAfter(current.end) ||
              e.start.isAtSameMomentAs(current.end)) {
            final diff = e.start.difference(current.end);
            if (diff < minNextDiff) {
              minNextDiff = diff;
              next1 = e;
            }
          }
        }
        if (next1 != null) {
          subtaskAllowedEventIds.add(next1.id);
        }
      }

      if (selectedEvent != null) {
        subtaskAllowedEventIds.add(selectedEvent!.id);
      }
    }

    // Pass 4: Draw Sector Content (icon, title, duration hours only!)
    final drawnContentAngles = <double>[];
    for (int i = 0; i < pillLayouts.length; i++) {
      final l = pillLayouts[i];
      final effectiveStartCap = l.showStartCap
          ? l.startCapSpan
          : (hasContiguousPredecessor[i] ? overlapDeg : 0.0);

      final midDeg = (l.startDeg + (l.sweepDeg / 2.0)) % 360.0;
      final collidesWithDrawn = drawnContentAngles.any((a) {
        final diff = ((midDeg - a).abs()) % 360.0;
        final angularDist = diff > 180.0 ? 360.0 - diff : diff;
        return angularDist < 12.0;
      });

      if (!collidesWithDrawn || l.isSelected || l.isActive) {
        drawnContentAngles.add(midDeg);
        SectorContentRenderer.drawContent(
          canvas: canvas,
          center: center,
          event: l.event,
          pillPath: l.pillPath,
          rIn: l.rIn,
          rOut: l.rOut,
          startDeg: l.startDeg,
          sweepDeg: l.sweepDeg,
          is24HourMode: is24,
          startCapSpanDeg: effectiveStartCap,
          endCapSpanDeg: l.endCapSpan,
          showSubtasks: subtaskAllowedEventIds.contains(l.event.id),
        );
      }
    }
  }

  void _drawCenterClockFace(Canvas canvas, Offset center, double innerRadius) {
    final is24 = settings.is24HourMode;
    final amPmStr = currentTime.hour < 12 ? 'AM' : 'PM';
    final timeStr = DateFormat(is24 ? 'HH:mm' : 'h:mm').format(currentTime);
    final dateStr = DateFormat('EEE, d MMM').format(currentTime);

    final isDark = colorScheme.brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF6B7280);

    final timeFontSize = innerRadius * 0.38;
    final dateFontSize = innerRadius * 0.16;
    final amPmFontSize = innerRadius * 0.18;

    final baseStyle = TextStyle(
      color: primaryTextColor,
      letterSpacing: -0.5,
      fontWeight: FontWeight.w900,
    );

    // Measure AM/PM
    TextPainter? amPmPainter;
    if (!is24) {
      amPmPainter = TextPainter(
        text: TextSpan(
          text: amPmStr,
          style: TextStyle(
            color: secondaryTextColor,
            fontSize: amPmFontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
    }

    // Measure Digital Time
    final timePainter = TextPainter(
      text: TextSpan(
        text: timeStr,
        style: baseStyle.copyWith(fontSize: timeFontSize),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    // Measure Date
    final datePainter = TextPainter(
      text: TextSpan(
        text: dateStr,
        style: TextStyle(
          color: secondaryTextColor,
          fontSize: dateFontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    // Measure Active Event Chip (1:1 parity with CenterSummary)
    TextPainter? chipPainter;
    TextPainter? iconPainter;
    double chipWidth = 0.0;
    double chipHeight = 0.0;
    if (activeEvent != null) {
      final chipTitle = activeEvent!.title
          .replaceAll('+', ' + ')
          .replaceAll('-', ' - ');

      final titlePainter = TextPainter(
        text: TextSpan(
          text: chipTitle,
          style: TextStyle(
            fontFamily: 'Kalam',
            fontFamilyFallback: const ['Patrick Hand', 'Caveat', 'sans-serif'],
            fontWeight: FontWeight.w700,
            color: colorScheme.onSecondaryContainer,
            fontSize: innerRadius * 0.125,
            letterSpacing: 0.1,
            height: 1.10,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 2,
      )..layout(maxWidth: innerRadius * 1.15);

      final iconSpan = TextSpan(
        text: String.fromCharCode(activeEvent!.resolvedIcon.codePoint),
        style: TextStyle(
          inherit: false,
          fontFamily: activeEvent!.resolvedIcon.fontFamily,
          package: activeEvent!.resolvedIcon.fontPackage,
          fontSize: innerRadius * 0.13,
          color: colorScheme.onSecondaryContainer,
        ),
      );
      final iPainter = TextPainter(
        text: iconSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      iconPainter = iPainter;
      chipPainter = titlePainter;

      chipWidth = (iconPainter.width + 4.0 + titlePainter.width + 14.0).clamp(
        0.0,
        innerRadius * 1.35,
      );
      chipHeight = math.max(iconPainter.height, titlePainter.height) + 5.0;
    }

    // Vertical sequential layout calculation:
    // Centered around center.dy with guaranteed positive gaps between all elements
    final hasAmPm = amPmPainter != null;
    final hasChip = chipPainter != null;

    final amPmH = hasAmPm ? amPmPainter.height : 0.0;
    final timeH = timePainter.height;
    final dateH = datePainter.height;
    final chipH = hasChip ? chipHeight : 0.0;

    final gapAmPm = hasAmPm ? 2.0 : 0.0;
    const gapDate = 3.5;
    final gapChip = hasChip ? 5.5 : 0.0;

    final totalHeight =
        amPmH + gapAmPm + timeH + gapDate + dateH + gapChip + chipH;
    var curY = center.dy - totalHeight / 2.0;

    // Paint AM/PM
    if (hasAmPm) {
      amPmPainter.paint(
        canvas,
        Offset(center.dx - amPmPainter.width / 2.0, curY),
      );
      curY += amPmH + gapAmPm;
    }

    // Paint Digital Time
    timePainter.paint(
      canvas,
      Offset(center.dx - timePainter.width / 2.0, curY),
    );
    curY += timeH + gapDate;

    // Paint Date
    datePainter.paint(
      canvas,
      Offset(center.dx - datePainter.width / 2.0, curY),
    );
    curY += dateH + gapChip;

    // Paint Active Event Chip
    if (hasChip) {
      final chipRect = Rect.fromCenter(
        center: Offset(center.dx, curY + chipH / 2.0),
        width: chipWidth,
        height: chipHeight,
      );
      final chipRRect = RRect.fromRectAndRadius(
        chipRect,
        const Radius.circular(12.0),
      );

      final chipBg = Paint()
        ..color = colorScheme.secondaryContainer
        ..style = PaintingStyle.fill;
      final chipBorder = Paint()
        ..color = colorScheme.secondary.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      canvas.drawRRect(chipRRect, chipBg);
      canvas.drawRRect(chipRRect, chipBorder);

      final contentTotalW =
          (iconPainter?.width ?? 0.0) +
          (iconPainter != null ? 4.0 : 0.0) +
          chipPainter.width;
      final startX = center.dx - contentTotalW / 2.0;

      if (iconPainter != null) {
        iconPainter.paint(
          canvas,
          Offset(startX, curY + (chipH - iconPainter.height) / 2.0),
        );
      }

      chipPainter.paint(
        canvas,
        Offset(
          startX + (iconPainter != null ? iconPainter.width + 4.0 : 0.0),
          curY + (chipH - chipPainter.height) / 2.0,
        ),
      );
    }
  }

  void _drawGrabHandle({
    required Canvas canvas,
    required Offset position,
    required bool isDragging,
    required Color baseColor,
  }) {
    final handleRadius = isDragging ? 5.8 : 4.4;
    // Outer shadow / glow
    canvas.drawCircle(
      position,
      handleRadius + 1.6,
      Paint()
        ..color = isDragging
            ? colorScheme.primary.withValues(alpha: 0.65)
            : Colors.black.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
    );
    // Fill
    canvas.drawCircle(
      position,
      handleRadius,
      Paint()
        ..color = isDragging
            ? Colors.white
            : Color.lerp(baseColor, Colors.white, 0.25)!
        ..style = PaintingStyle.fill,
    );
    // Border ring
    canvas.drawCircle(
      position,
      handleRadius,
      Paint()
        ..color = isDragging ? colorScheme.primary : Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = isDragging ? 2.2 : 1.5,
    );
    // Center grip dot
    canvas.drawCircle(
      position,
      1.4,
      Paint()
        ..color = isDragging ? colorScheme.primary : Colors.black87
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant SectographPainter oldDelegate) {
    return oldDelegate.currentTime != currentTime ||
        oldDelegate.scrubAngle != scrubAngle ||
        oldDelegate.selectedEvent != selectedEvent ||
        oldDelegate.activeEvent != activeEvent ||
        oldDelegate.events != events ||
        oldDelegate.settings != settings ||
        oldDelegate.colorScheme != colorScheme ||
        oldDelegate.showNeedle != showNeedle ||
        oldDelegate.showCenterClock != showCenterClock ||
        oldDelegate.lens != lens ||
        oldDelegate.activeDraggingCap != activeDraggingCap ||
        oldDelegate.isDialEditing != isDialEditing;
  }
}
