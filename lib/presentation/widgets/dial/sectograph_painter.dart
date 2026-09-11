import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/constants/app_layout_constants.dart';
import '../../../core/geometry/sector_math.dart';
import '../../../core/theme/app_colors.dart';
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

  SectographPainter({
    required this.events,
    required this.selectedEvent,
    required this.activeEvent,
    required this.currentTime,
    required this.scrubAngle,
    required this.settings,
    required this.colorScheme,
    this.showCenterClock = false,
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

    // 4. Numeral-free outer rim tick marks
    DialBezelRenderer.drawTicks(
      canvas: canvas,
      center: center,
      radius: baseRadius - 1.0,
      is24HourMode: settings.is24HourMode,
      faceStyle: settings.faceStyle,
      colorScheme: colorScheme,
    );

    // 5. Two-stage hierarchical "NOW" hour needle & celestial beacon
    _drawDayNightSweep(
      canvas,
      center,
      baseRadius,
      innerRadius,
      routineTrackIn,
      routineTrackOut,
    );

    // 6. Dual analog clock hands
    if (settings.centerClockDisplay != CenterClockDisplay.digital) {
      _drawAnalogHands(canvas, center, innerRadius);
    }

    // 7. Rich center clock face for offscreen / widget rendering
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
    final effectiveAngle = scrubAngle ?? nowAngle;
    final nowRad = SectorMath.dialAngleToCanvasRadians(effectiveAngle);
    final isDaytime = currentTime.hour >= 6 && currentTime.hour < 18;

    HourNeedleRenderer.drawNeedle(
      canvas: canvas,
      center: center,
      angleRad: nowRad,
      hubRadius: innerRadius,
      outerROut: routineTrackOut,
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

    // Pre-analyze contiguous relationships on the single uniform ring
    final hasContiguousPredecessor = List<bool>.filled(events.length, false);
    final hasContiguousSuccessor = List<bool>.filled(events.length, false);

    for (int i = 0; i < events.length; i++) {
      final event = events[i];
      for (int j = 0; j < events.length; j++) {
        if (i == j) continue;
        final other = events[j];
        if ((event.start.difference(other.end).inMinutes).abs() <= 2) {
          hasContiguousPredecessor[i] = true;
        }
        if ((other.start.difference(event.end).inMinutes).abs() <= 2) {
          hasContiguousSuccessor[i] = true;
        }
      }
    }

    final drawnTimestampAngles = <double>[];
    bool angleAlreadyDrawn(double deg) {
      for (final angle in drawnTimestampAngles) {
        final diff = ((deg - angle).abs()) % 360.0;
        final angularDistance = diff > 180.0 ? 360.0 - diff : diff;
        if (angularDistance < 8.0) return true;
      }
      return false;
    }

    const double overlapDeg = 2.5; // 3D overlap extension over contiguous successor
    final cornerRadius = math
        .min(8.0, (routineTrackOut - routineTrackIn) * 0.22)
        .clamp(3.0, 8.0);

    // Prepare layout data for each event on the single uniform track
    final pillLayouts = <({
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
    })>[];

    for (int i = 0; i < events.length; i++) {
      final event = events[i];
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

      final eventRIn = routineTrackIn;
      final eventROut = routineTrackOut;

      final isContiguous = hasContiguousSuccessor[i];
      // Compact, completely consistent time badge span across all blocks
      final baseCapSpanDeg = is24 ? 5.5 : 7.5;

      final canShowStartCap = !hasContiguousPredecessor[i] &&
          sweepDeg >= (is24 ? 16.0 : 20.0) &&
          !angleAlreadyDrawn(startDeg);
      final canShowEndCap = sweepDeg >= (is24 ? 10.0 : 14.0) &&
          !angleAlreadyDrawn(startDeg + sweepDeg);

      final startCapSpan = canShowStartCap ? baseCapSpanDeg : 0.0;
      final endCapSpan = canShowEndCap ? baseCapSpanDeg : 0.0;
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
        );
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
      }
    }

    // Pass 4: Draw Sector Content (icon, title, duration hours only!)
    for (final l in pillLayouts) {
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
        startCapSpanDeg: l.startCapSpan,
        endCapSpanDeg: l.endCapSpan,
      );
    }
  }

  void _drawAnalogHands(Canvas canvas, Offset center, double innerRadius) {
    final is24 = settings.is24HourMode;
    double hourAngle;
    double minuteAngle;

    if (scrubAngle != null) {
      hourAngle = scrubAngle!;
      final step = is24 ? 15.0 : 30.0;
      minuteAngle = ((scrubAngle! % step) / step) * 360.0;
    } else {
      hourAngle = SectorMath.timeToDialAngle(currentTime, is24HourMode: is24);
      minuteAngle =
          (currentTime.minute / 60.0 + currentTime.second / 3600.0) * 360.0;
    }

    final hourRad = SectorMath.dialAngleToCanvasRadians(hourAngle);
    final minuteRad = SectorMath.dialAngleToCanvasRadians(minuteAngle);

    // Hour Hand: Olive green rounded capsule bar
    const hourHandColor = AppColors.hourHand;
    final hourLength = innerRadius * 0.58;
    final pHourEnd = Offset(
      center.dx + hourLength * math.cos(hourRad),
      center.dy + hourLength * math.sin(hourRad),
    );
    final hourPaint = Paint()
      ..color = hourHandColor
      ..strokeWidth = 9.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, pHourEnd, hourPaint);

    // Minute Hand: Soft lavender rounded capsule bar
    const minuteHandColor = AppColors.minuteHand;
    final minuteLength = innerRadius * 0.90;
    final pMinEnd = Offset(
      center.dx + minuteLength * math.cos(minuteRad),
      center.dy + minuteLength * math.sin(minuteRad),
    );
    final minutePaint = Paint()
      ..color = minuteHandColor
      ..strokeWidth = 7.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, pMinEnd, minutePaint);

    // Center Pivot Cap: Warm cream/gold circle with inner core
    final pivotPaint = Paint()
      ..color = AppColors.pivotCap
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 7.5, pivotPaint);

    final pivotDot = Paint()
      ..color = AppColors.pivotDot
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 2.2, pivotDot);
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

    // Draw AM/PM
    if (!is24) {
      final amPmPainter = TextPainter(
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

      amPmPainter.paint(
        canvas,
        Offset(
          center.dx - amPmPainter.width / 2,
          center.dy - innerRadius * 0.55,
        ),
      );
    }

    // Draw Digital Time
    final timePainter = TextPainter(
      text: TextSpan(
        text: timeStr,
        style: baseStyle.copyWith(fontSize: timeFontSize),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    timePainter.paint(
      canvas,
      Offset(
        center.dx - timePainter.width / 2,
        center.dy - timePainter.height / 2 - (is24 ? 0 : innerRadius * 0.08),
      ),
    );

    // Draw Date
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

    datePainter.paint(
      canvas,
      Offset(
        center.dx - datePainter.width / 2,
        center.dy + (is24 ? innerRadius * 0.28 : innerRadius * 0.22),
      ),
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
        oldDelegate.colorScheme != colorScheme;
  }
}
