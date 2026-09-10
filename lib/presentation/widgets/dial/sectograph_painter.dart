import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/constants/app_layout_constants.dart';
import '../../../core/geometry/sector_math.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/time_formatters.dart';
import '../../../domain/models/dial_settings.dart';
import '../../../domain/models/sector_event.dart';

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
    final maxRadius = (math.min(size.width, size.height) / 2) - 6.0;
    final baseRadius = maxRadius - scallopAmp;
    final innerRadius = baseRadius * AppLayoutConstants.innerRadiusRatio;
    final radialThickness = baseRadius - innerRadius;
    final routineTrackIn =
        innerRadius + AppLayoutConstants.routineTrackInnerOffset;
    final routineTrackOut = baseRadius - 28.0;

    final is24 = settings.is24HourMode;
    final pastStyle = settings.pastHoursStyle;

    FocusedWarp? warp;
    if (pastStyle == PastHoursStyle.focusedBlock) {
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

      SectorEvent? focusEv = activeEvent;
      if (focusEv == null) {
        for (final e in events) {
          if (e.start.isBefore(effectiveTime) && e.end.isAfter(effectiveTime)) {
            focusEv = e;
            break;
          }
        }
      }
      focusEv ??= selectedEvent;
      if (focusEv == null) {
        for (final e in events) {
          if (e.start.isAfter(effectiveTime)) {
            focusEv = e;
            break;
          }
        }
      }

      if (focusEv != null && focusEv.sweepAngle > 1.0) {
        warp = FocusedWarp.fromEvent(
          eventId: focusEv.id,
          startAngle: focusEv.startAngle,
          sweepAngle: focusEv.sweepAngle,
          subtaskCount: focusEv.subtasks.length,
        );
      }
    }

    // 1. Dial chassis with radial spokes & dark slate face (Circle or Wave)
    _drawDialBackground(
      canvas,
      center,
      baseRadius,
      innerRadius,
      isWave: isWave,
      scallopAmp: scallopAmp,
    );

    // 2. Rounded pill arc routine sectors with 3D overlap, drop shadows & icons
    _drawSectors(
      canvas,
      center,
      baseRadius,
      innerRadius,
      radialThickness,
      warp: warp,
    );

    // 3. Subtle dial bezel outline (Circle or Wave)
    _drawDialOutline(
      canvas,
      center,
      baseRadius,
      isWave: isWave,
      scallopAmp: scallopAmp,
    );

    // 4. Outer numerals 1-12 and 60 minute ticks (clean numbers, no major tick lines sticking into them)
    _drawTicksAndNumbers(
      canvas,
      center,
      baseRadius,
      innerRadius,
      isWave: isWave,
      scallopAmp: scallopAmp,
      warp: warp,
    );

    // 5. Day / Night "NOW" sweep needle & moon/sun node (stay ABOVE ALL numbers, ticks, and sectors)
    _drawDayNightSweep(
      canvas,
      center,
      baseRadius,
      innerRadius,
      routineTrackIn,
      routineTrackOut,
      warp: warp,
    );

    // 6. Dual analog clock hands (olive hour hand, lavender minute hand, cream pivot)
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

    // 1. Soft elevation drop shadow
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

    // 3. Radial hour division spokes from inner hub to outer tick ring
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
        center.dx + (innerRadius + 1.0) * math.cos(rad),
        center.dy + (innerRadius + 1.0) * math.sin(rad),
      );
      final p2 = Offset(
        center.dx + (baseRadius - 10.0) * math.cos(rad),
        center.dy + (baseRadius - 10.0) * math.sin(rad),
      );
      canvas.drawLine(p1, p2, spokePaint);
    }

    // 4. Inner core background
    canvas.drawCircle(center, innerRadius, bgPaint);
  }

  void _drawDialOutline(
    Canvas canvas,
    Offset center,
    double baseRadius, {
    required bool isWave,
    required double scallopAmp,
  }) {
    final isDark = colorScheme.brightness == Brightness.dark;
    // Subtle, clean circular or wavy bezel border
    final outlinePaint = Paint()
      ..color = isDark ? const Color(0xFF33373E) : colorScheme.outlineVariant
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    if (isWave) {
      final scallopPath = _buildScallopPath(center, baseRadius, scallopAmp);
      canvas.drawPath(scallopPath, outlinePaint);
    } else {
      canvas.drawCircle(center, baseRadius, outlinePaint);
    }
  }

  void _drawTicksAndNumbers(
    Canvas canvas,
    Offset center,
    double baseRadius,
    double innerRadius, {
    required bool isWave,
    required double scallopAmp,
    FocusedWarp? warp,
  }) {
    final isDark = colorScheme.brightness == Brightness.dark;
    final is24 = settings.is24HourMode;
    final totalHours = is24 ? 24 : 12;
    final stepAngle = 360.0 / totalHours;
    final faceStyle = settings.faceStyle;

    final showNumbers = faceStyle != DialFaceStyle.minimal;
    final showMinorTicks = faceStyle != DialFaceStyle.numbered;
    final isMinimal = faceStyle == DialFaceStyle.minimal;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    // 1. Minute & hour ticks around the rim
    final minorTickPaint = Paint()
      ..color = isDark ? const Color(0xFF4E5460) : colorScheme.outline
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    final majorTickPaint = Paint()
      ..color = isDark ? const Color(0xFF9E968D) : colorScheme.onSurfaceVariant
      ..strokeWidth = isMinimal ? 2.0 : 1.2
      ..strokeCap = StrokeCap.round;

    final cardinalTickPaint = Paint()
      ..color = colorScheme.primary
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    final totalTicks = is24 ? 120 : 60;
    final tickStepDeg = 360.0 / totalTicks;

    for (var i = 0; i < totalTicks; i++) {
      final isMajorHour = (i % (totalTicks ~/ totalHours) == 0);
      final hourIndex = i ~/ (totalTicks ~/ totalHours);
      final isCardinal = is24
          ? (hourIndex % 6 == 0) // 0, 6, 12, 18
          : (hourIndex % 3 == 0); // 12, 3, 6, 9

      final rawTickDeg = i * tickStepDeg;
      final tickDeg = warp != null ? warp.warp(rawTickDeg) : rawTickDeg;
      final tickRad = SectorMath.dialAngleToCanvasRadians(tickDeg);

      if (isMajorHour) {
        // If we are in minimal mode (no numbers), draw prominent hour bars with cardinal accents
        if (isMinimal) {
          final tickLength = isCardinal ? 9.0 : 6.0;
          final currentBaseR = isWave
              ? baseRadius +
                    scallopAmp *
                        math.cos(scallopLobes * (tickDeg * math.pi / 180.0))
              : baseRadius;
          final pOut = Offset(
            center.dx + (currentBaseR - 2.5) * math.cos(tickRad),
            center.dy + (currentBaseR - 2.5) * math.sin(tickRad),
          );
          final pIn = Offset(
            center.dx + (currentBaseR - 2.5 - tickLength) * math.cos(tickRad),
            center.dy + (currentBaseR - 2.5 - tickLength) * math.sin(tickRad),
          );
          canvas.drawLine(
            pIn,
            pOut,
            isCardinal ? cardinalTickPaint : majorTickPaint,
          );
        }
        continue;
      }

      // If minor ticks are disabled (e.g. 'numbered' mode), skip minor ticks
      if (!showMinorTicks) {
        continue;
      }

      const tickLength = 3.5;
      final currentBaseR = isWave
          ? baseRadius +
                scallopAmp *
                    math.cos(scallopLobes * (tickDeg * math.pi / 180.0))
          : baseRadius;
      final pOut = Offset(
        center.dx + (currentBaseR - 2.5) * math.cos(tickRad),
        center.dy + (currentBaseR - 2.5) * math.sin(tickRad),
      );
      final pIn = Offset(
        center.dx + (currentBaseR - 2.5 - tickLength) * math.cos(tickRad),
        center.dy + (currentBaseR - 2.5 - tickLength) * math.sin(tickRad),
      );
      canvas.drawLine(pIn, pOut, minorTickPaint);
    }

    // 2. Hour numerals (Centered in the middle area of the outer bezel ring)
    if (showNumbers) {
      final numeralRadius = baseRadius - (is24 ? 12.0 : 13.5);
      final majorColor = isDark
          ? const Color(0xFFFFFFFF)
          : colorScheme.onSurface;
      final minorColor = isDark
          ? const Color(0xFF8A909D)
          : colorScheme.onSurfaceVariant;

      for (var h = 0; h < totalHours; h++) {
        final rawDeg = h * stepAngle;
        final deg = warp != null ? warp.warp(rawDeg) : rawDeg;
        final rad = SectorMath.dialAngleToCanvasRadians(deg);

        final bool isMajor = !is24 || (h % 2 == 0);
        final textPos = Offset(
          center.dx + numeralRadius * math.cos(rad),
          center.dy + numeralRadius * math.sin(rad),
        );

        final label = is24 ? (h == 0 ? '0' : '$h') : (h == 0 ? '12' : '$h');

        textPainter.text = TextSpan(
          text: label,
          style: TextStyle(
            fontSize: is24 ? (isMajor ? 11.0 : 9.0) : 15.5,
            fontWeight: isMajor ? FontWeight.w800 : FontWeight.w600,
            color: isMajor ? majorColor : minorColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          textPos - Offset(textPainter.width / 2, textPainter.height / 2),
        );
      }
    }
  }

  void _drawSunGlyph(
    Canvas canvas,
    Offset pos, {
    double radius = 2.8,
    Color color = const Color(0xFFF5C242),
  }) {
    final sunPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos, radius, sunPaint);

    final rayPaint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    for (var r = 0; r < 8; r++) {
      final angle = r * (math.pi / 4);
      final p1 = Offset(
        pos.dx + (radius + 1.2) * math.cos(angle),
        pos.dy + (radius + 1.2) * math.sin(angle),
      );
      final p2 = Offset(
        pos.dx + (radius + 2.8) * math.cos(angle),
        pos.dy + (radius + 2.8) * math.sin(angle),
      );
      canvas.drawLine(p1, p2, rayPaint);
    }
  }

  void _drawMoonGlyph(
    Canvas canvas,
    Offset pos, {
    double radius = 4.2,
    Color color = const Color(0xFFFFFFFF),
  }) {
    final moonPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final moonPath = Path()
      ..addOval(Rect.fromCircle(center: pos, radius: radius));
    final cutPath = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(pos.dx + radius * 0.55, pos.dy - radius * 0.28),
          radius: radius * 0.85,
        ),
      );
    final crescent = Path.combine(PathOperation.difference, moonPath, cutPath);
    canvas.drawPath(crescent, moonPaint);
  }

  void _drawDayNightSweep(
    Canvas canvas,
    Offset center,
    double baseRadius,
    double innerRadius,
    double rIn,
    double rOut, {
    FocusedWarp? warp,
  }) {
    final is24 = settings.is24HourMode;
    final rawNowAngle = SectorMath.timeToDialAngle(
      currentTime,
      is24HourMode: is24,
    );
    final nowAngle = warp != null ? warp.warp(rawNowAngle) : rawNowAngle;
    final nowRad = SectorMath.dialAngleToCanvasRadians(nowAngle);

    // 1. "NOW" sweep line (high-contrast Sectograph crimson needle)
    const sweepColor = Color(0xFFEF4444);
    final pIn = Offset(
      center.dx + rIn * math.cos(nowRad),
      center.dy + rIn * math.sin(nowRad),
    );

    // Circular pointer node at tip of hand (Sectograph signature marker with Day/Night glyph inside)
    const double nodeRadius = 8.0;
    final tipPos = Offset(
      center.dx + (baseRadius - nodeRadius - 1.0) * math.cos(nowRad),
      center.dy + (baseRadius - nodeRadius - 1.0) * math.sin(nowRad),
    );

    // Subtle ambient glow
    final glowPaint = Paint()
      ..color = sweepColor.withValues(alpha: 0.35)
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(pIn, tipPos, glowPaint);

    // Core crisp sweep line
    final linePaint = Paint()
      ..color = sweepColor
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(pIn, tipPos, linePaint);

    // Circular pointer node: SOLID RED fill (Sectograph signature) with crisp white rim
    final nodeBgPaint = Paint()
      ..color = sweepColor
      ..style = PaintingStyle.fill;
    final nodeBorderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(tipPos, nodeRadius, nodeBgPaint);
    canvas.drawCircle(tipPos, nodeRadius, nodeBorderPaint);

    // Inner pivot accent ring
    final pivotRingPaint = Paint()
      ..color = sweepColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: rIn),
      nowRad - (math.pi / 24),
      math.pi / 12,
      false,
      pivotRingPaint,
    );

    // 2. Moon or Sun glyph displayed directly INSIDE the solid red pointer node circle
    final isDaytime = currentTime.hour >= 6 && currentTime.hour < 18;
    if (isDaytime) {
      _drawSunGlyph(
        canvas,
        tipPos,
        radius: 3.0,
        color: const Color(0xFFFFF3B0),
      );
    } else {
      _drawMoonGlyph(
        canvas,
        tipPos,
        radius: 4.4,
        color: const Color(0xFFFFFFFF),
      );
    }
  }

  void _drawSectors(
    Canvas canvas,
    Offset center,
    double baseRadius,
    double innerRadius,
    double radialThickness, {
    FocusedWarp? warp,
  }) {
    final routineTrackIn =
        innerRadius + AppLayoutConstants.routineTrackInnerOffset;
    final routineTrackOut = baseRadius - 28.0;
    const double defaultSectorGapDeg = 2.5;
    const double overlapDeg =
        2.5; // 3D overlap extension over contiguous successor

    ({double rIn, double rOut}) getEventRadii(SectorEvent event) {
      final totalTrackThickness = routineTrackOut - routineTrackIn;
      final rawROut =
          routineTrackOut - (event.topLevel / 1000.0) * totalTrackThickness;
      final rawRIn =
          routineTrackOut - (event.bottomLevel / 1000.0) * totalTrackThickness;

      // Concentric separator gap: 1.0dp inset on non-boundary edges (gives 2.0dp between tracks)
      const gapHalf = 1.0;
      final rOut = event.topLevel > 0 ? (rawROut - gapHalf) : rawROut;
      final rIn = event.bottomLevel < 1000 ? (rawRIn + gapHalf) : rawRIn;
      return (rIn: rIn, rOut: rOut);
    }

    final is24 = settings.is24HourMode;
    final pastStyle = settings.pastHoursStyle;

    DateTime effectiveTime = currentTime;
    double effectiveAngle = SectorMath.timeToDialAngle(
      currentTime,
      is24HourMode: is24,
    );
    if (scrubAngle != null) {
      effectiveAngle = scrubAngle!;
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

    bool isEventCompleted(SectorEvent e) {
      return !effectiveTime.isBefore(e.end);
    }

    bool isEventActive(SectorEvent e) {
      return e.start.isBefore(effectiveTime) && e.end.isAfter(effectiveTime);
    }

    // Bird's Eye Dynamic Horizon Analysis
    final completedEvents =
        events.where((e) => !effectiveTime.isBefore(e.end)).toList()
          ..sort((a, b) => a.end.compareTo(b.end));
    final recentCompletedIds = completedEvents.length <= 2
        ? completedEvents.map((e) => e.id).toSet()
        : completedEvents
              .sublist(completedEvents.length - 2)
              .map((e) => e.id)
              .toSet();

    final upcomingEvents =
        events.where((e) => effectiveTime.isBefore(e.start)).toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    final nextUpcomingIds = upcomingEvents.take(2).map((e) => e.id).toSet();

    // Pre-analyze contiguous relationships
    final hasContiguousPredecessor = List<bool>.filled(events.length, false);
    final hasContiguousSuccessor = List<bool>.filled(events.length, false);

    for (int i = 0; i < events.length; i++) {
      final event = events[i];
      if (event.sweepAngle <= 1.0) continue;

      for (int j = 0; j < events.length; j++) {
        if (i == j) continue;
        final other = events[j];
        if (other.sweepAngle <= 1.0) continue;

        // Only events sharing the same concentric tier can be contiguous
        final sameTier =
            event.topLevel == other.topLevel &&
            event.bottomLevel == other.bottomLevel;
        if (!sameTier) continue;

        // Meets at start
        if ((event.start.difference(other.end).inMinutes).abs() <= 2) {
          hasContiguousPredecessor[i] = true;
        }
        // Meets at end
        if ((other.start.difference(event.end).inMinutes).abs() <= 2) {
          hasContiguousSuccessor[i] = true;
        }
      }
    }

    // Pass 1: Draw all base sector bodies (flush cuts at contiguous boundaries)
    for (int i = 0; i < events.length; i++) {
      final event = events[i];
      final isSelected = selectedEvent?.id == event.id;
      if (event.sweepAngle <= 1.0) continue;

      final isCompleted = isEventCompleted(event);
      final isActive = isEventActive(event);

      // In disappear mode: skip completed events completely
      if (pastStyle == PastHoursStyle.disappear && isCompleted) {
        continue;
      }
      // In Bird's Eye mode: older completed blocks disappear completely!
      if (pastStyle == PastHoursStyle.birdsEye &&
          isCompleted &&
          !recentCompletedIds.contains(event.id)) {
        continue;
      }

      double startDeg;
      double sweepDeg;
      bool roundStart = !hasContiguousPredecessor[i];
      final bool roundEnd = !hasContiguousSuccessor[i];

      if (warp != null) {
        final warpedStart = warp.warp(event.startAngle);
        final warpedEnd = warp.warp(event.startAngle + event.sweepAngle);
        var warpedSweep = (warpedEnd - warpedStart) % 360.0;
        if (warpedSweep <= 0) warpedSweep += 360.0;

        final startGap = hasContiguousPredecessor[i]
            ? 0.0
            : (defaultSectorGapDeg / 2.0);
        final endGap = hasContiguousSuccessor[i]
            ? 0.0
            : (defaultSectorGapDeg / 2.0);

        startDeg = warpedStart + startGap;
        sweepDeg = (warpedSweep - startGap - endGap).clamp(4.0, 360.0);
      } else if (pastStyle == PastHoursStyle.disappear && isActive) {
        // Active event shrinks: starts from effectiveAngle to end
        final remainingDuration = event.end.difference(effectiveTime);
        final remainingSweep = SectorMath.durationToSweepAngle(
          remainingDuration,
          is24HourMode: is24,
        );
        if (remainingSweep <= 1.0) continue;

        startDeg = effectiveAngle;
        sweepDeg = remainingSweep.clamp(2.0, 360.0);
        roundStart = false; // flush cut against current time needle
      } else {
        final startGap = hasContiguousPredecessor[i]
            ? 0.0
            : (defaultSectorGapDeg / 2.0);
        final endGap = hasContiguousSuccessor[i]
            ? 0.0
            : (defaultSectorGapDeg / 2.0);

        startDeg = event.startAngle + startGap;
        sweepDeg = (event.sweepAngle - startGap - endGap).clamp(4.0, 360.0);
      }

      final radii = getEventRadii(event);
      final eventRIn = radii.rIn;
      final eventROut = radii.rOut;
      final cornerRadius = math
          .min(10.0, (eventROut - eventRIn) * 0.28)
          .clamp(3.0, 10.0);

      final sectorPath = _buildRoundedSectorPath(
        center: center,
        rIn: eventRIn,
        rOut: eventROut,
        startDeg: startDeg,
        sweepDeg: sweepDeg,
        cornerRadius: cornerRadius,
        roundStart: roundStart,
        roundEnd: roundEnd,
      );

      final double fillAlpha;
      if (warp != null) {
        fillAlpha = (warp.focusEventId == event.id || isSelected) ? 1.0 : 0.28;
      } else if (pastStyle == PastHoursStyle.birdsEye) {
        if (isCompleted) {
          fillAlpha = 0.38;
        } else if (isActive ||
            isSelected ||
            nextUpcomingIds.contains(event.id)) {
          fillAlpha = 1.0;
        } else {
          fillAlpha = 0.48;
        }
      } else if (isSelected) {
        fillAlpha = 1.0;
      } else {
        fillAlpha = 0.95;
      }

      final fillPaint = Paint()
        ..color = event.color.withValues(alpha: fillAlpha)
        ..style = PaintingStyle.fill;
      canvas.drawPath(sectorPath, fillPaint);

      if (isSelected) {
        final selectBorder = Paint()
          ..color = Colors.white.withValues(alpha: 0.90)
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;
        canvas.drawPath(sectorPath, selectBorder);
      }
    }

    // Pass 2: Draw 3D overlapping end caps with drop shadows & single boundary timestamps
    final drawnTimestampAngles = <({int tier, double angle})>[];

    for (int i = 0; i < events.length; i++) {
      final event = events[i];
      if (event.sweepAngle <= 1.0) continue;

      final isCompleted = isEventCompleted(event);
      if (pastStyle == PastHoursStyle.disappear && isCompleted) {
        continue;
      }
      if (pastStyle == PastHoursStyle.birdsEye &&
          isCompleted &&
          !recentCompletedIds.contains(event.id)) {
        continue;
      }

      final double eventStartAngle;
      final double eventSweepAngle;
      if (warp != null) {
        eventStartAngle = warp.warp(event.startAngle);
        final capEnd = warp.warp(event.startAngle + event.sweepAngle);
        var sw = (capEnd - eventStartAngle) % 360.0;
        if (sw <= 0) sw += 360.0;
        eventSweepAngle = sw;
      } else {
        eventStartAngle = event.startAngle;
        eventSweepAngle = event.sweepAngle;
      }

      final minSpan = is24 ? 3.0 : 5.0;
      final maxSpan = eventSweepAngle * 0.28;
      if (maxSpan < minSpan || eventSweepAngle < (is24 ? 10.0 : 16.0)) {
        continue;
      }

      final radii = getEventRadii(event);
      final eventRIn = radii.rIn;
      final eventROut = radii.rOut;
      final cornerRadius = math
          .min(10.0, (eventROut - eventRIn) * 0.28)
          .clamp(3.0, 10.0);
      final isMultiTier = event.topLevel > 0 || event.bottomLevel < 1000;

      final desiredSpan = (20.0 / eventROut) * (180.0 / math.pi);
      final edgeSpanDeg = desiredSpan.clamp(minSpan, maxSpan);
      final isContiguous = hasContiguousSuccessor[i];

      final endBoundaryDeg = eventStartAngle + eventSweepAngle;
      final capEndDeg = endBoundaryDeg + (isContiguous ? overlapDeg : 0.0);
      final capSpanDeg = edgeSpanDeg + (isContiguous ? overlapDeg : 0.0);

      bool angleAlreadyDrawn(double deg) {
        for (final entry in drawnTimestampAngles) {
          if (entry.tier == event.topLevel) {
            final diff = ((deg - entry.angle).abs()) % 360.0;
            final angularDistance = diff > 180.0 ? 360.0 - diff : diff;
            if (angularDistance < 8.0) return true;
          }
        }
        return false;
      }

      if (angleAlreadyDrawn(endBoundaryDeg)) continue;

      // 3D Overlapping end cap path
      final capPath = _buildRoundedSectorPath(
        center: center,
        rIn: eventRIn,
        rOut: eventROut,
        startDeg: capEndDeg - capSpanDeg,
        sweepDeg: capSpanDeg,
        cornerRadius: cornerRadius,
        roundStart: false,
        roundEnd: true,
      );

      final isDim = isCompleted && pastStyle == PastHoursStyle.birdsEye;
      final capAlpha = isDim ? 0.38 : 1.0;
      final shadeAlpha = isDim ? 0.40 : 1.0;
      final textAlpha = isDim ? 0.50 : 1.0;

      // 1. Base sector fill on end cap
      final capFillPaint = Paint()
        ..color = event.color.withValues(alpha: capAlpha)
        ..style = PaintingStyle.fill;
      canvas.drawPath(capPath, capFillPaint);

      // 2. Shaded accent strip on end cap (synced to task block color tokenization)
      final shadeColor = Color.lerp(event.color, Colors.black, 0.28)!;
      final shadePaint = Paint()
        ..color = shadeColor.withValues(alpha: shadeAlpha)
        ..style = PaintingStyle.fill;
      canvas.drawPath(capPath, shadePaint);

      // 4. Boundary timestamp text in bold white
      final endTimeStr = TimeFormatters.formatTime(
        event.end,
        is24Hour: settings.is24HourMode,
      );

      final endPainter = TextPainter(
        text: TextSpan(
          text: endTimeStr,
          style: TextStyle(
            fontSize: isMultiTier ? 8.0 : 9.0,
            fontWeight: FontWeight.w900,
            color: const Color(0xFFFFFFFF).withValues(alpha: textAlpha),
            letterSpacing: 0.2,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();

      final textAngleDeg = endBoundaryDeg - (edgeSpanDeg * 0.45);
      final radAngle = SectorMath.dialAngleToCanvasRadians(textAngleDeg);
      final midR = (eventRIn + eventROut) / 2.0;

      final endTextCenter = Offset(
        center.dx + midR * math.cos(radAngle),
        center.dy + midR * math.sin(radAngle),
      );

      canvas.save();
      canvas.translate(endTextCenter.dx, endTextCenter.dy);

      var endRotation = radAngle;
      if (math.cos(radAngle) < -0.05) {
        endRotation += math.pi;
      }
      canvas.rotate(endRotation);

      endPainter.paint(
        canvas,
        Offset(-endPainter.width / 2, -endPainter.height / 2),
      );
      canvas.restore();

      drawnTimestampAngles.add((tier: event.topLevel, angle: endBoundaryDeg));
    }

    // Pass 3: Draw start timestamps for isolated events that do NOT have a contiguous predecessor
    for (int i = 0; i < events.length; i++) {
      final event = events[i];
      if (event.sweepAngle <= 1.0) continue;
      if (hasContiguousPredecessor[i]) continue;

      final isCompleted = isEventCompleted(event);
      final isActive = isEventActive(event);

      // In disappear mode: skip completed events and active event start cap
      if (pastStyle == PastHoursStyle.disappear && (isCompleted || isActive)) {
        continue;
      }
      if (pastStyle == PastHoursStyle.birdsEye &&
          isCompleted &&
          !recentCompletedIds.contains(event.id)) {
        continue;
      }

      final double startCapAngle;
      final double startCapSweep;
      if (warp != null) {
        startCapAngle = warp.warp(event.startAngle);
        final capEnd = warp.warp(event.startAngle + event.sweepAngle);
        var sw = (capEnd - startCapAngle) % 360.0;
        if (sw <= 0) sw += 360.0;
        startCapSweep = sw;
      } else {
        startCapAngle = event.startAngle;
        startCapSweep = event.sweepAngle;
      }

      final minSpan = is24 ? 3.0 : 5.0;
      final maxSpan = startCapSweep * 0.28;
      if (maxSpan < minSpan || startCapSweep < (is24 ? 10.0 : 16.0)) {
        continue;
      }

      final radii = getEventRadii(event);
      final eventRIn = radii.rIn;
      final eventROut = radii.rOut;
      final cornerRadius = math
          .min(10.0, (eventROut - eventRIn) * 0.28)
          .clamp(3.0, 10.0);
      final isMultiTier = event.topLevel > 0 || event.bottomLevel < 1000;

      final startBoundaryDeg = startCapAngle;

      bool angleAlreadyDrawn(double deg) {
        for (final entry in drawnTimestampAngles) {
          if (entry.tier == event.topLevel) {
            final diff = ((deg - entry.angle).abs()) % 360.0;
            final angularDistance = diff > 180.0 ? 360.0 - diff : diff;
            if (angularDistance < 8.0) return true;
          }
        }
        return false;
      }

      if (angleAlreadyDrawn(startBoundaryDeg)) continue;

      final desiredSpan = (20.0 / eventROut) * (180.0 / math.pi);
      final edgeSpanDeg = desiredSpan.clamp(minSpan, maxSpan);

      final startCapPath = _buildRoundedSectorPath(
        center: center,
        rIn: eventRIn,
        rOut: eventROut,
        startDeg: startBoundaryDeg,
        sweepDeg: edgeSpanDeg,
        cornerRadius: cornerRadius,
        roundStart: true,
        roundEnd: false,
      );

      final isDim = isCompleted && pastStyle == PastHoursStyle.birdsEye;
      final shadeAlpha = isDim ? 0.40 : 1.0;
      final textAlpha = isDim ? 0.50 : 1.0;

      final shadeColor = Color.lerp(event.color, Colors.black, 0.32)!;
      final shadePaint = Paint()
        ..color = shadeColor.withValues(alpha: shadeAlpha)
        ..style = PaintingStyle.fill;
      canvas.drawPath(startCapPath, shadePaint);

      final startTimeStr = TimeFormatters.formatTime(
        event.start,
        is24Hour: settings.is24HourMode,
      );

      final startPainter = TextPainter(
        text: TextSpan(
          text: startTimeStr,
          style: TextStyle(
            fontSize: isMultiTier ? 8.0 : 9.0,
            fontWeight: FontWeight.w900,
            color: const Color(0xFFFFFFFF).withValues(alpha: textAlpha),
            letterSpacing: 0.2,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();

      final textAngleDeg = startBoundaryDeg + (edgeSpanDeg * 0.45);
      final radAngle = SectorMath.dialAngleToCanvasRadians(textAngleDeg);
      final midR = (eventRIn + eventROut) / 2.0;

      final startTextCenter = Offset(
        center.dx + midR * math.cos(radAngle),
        center.dy + midR * math.sin(radAngle),
      );

      canvas.save();
      canvas.translate(startTextCenter.dx, startTextCenter.dy);

      var startRotation = radAngle;
      if (math.cos(radAngle) < -0.05) {
        startRotation += math.pi;
      }
      canvas.rotate(startRotation);

      startPainter.paint(
        canvas,
        Offset(-startPainter.width / 2, -startPainter.height / 2),
      );
      canvas.restore();

      drawnTimestampAngles.add((tier: event.topLevel, angle: startBoundaryDeg));
    }

    // Pass 4: Draw vector icon + Title + Duration upright at sector center
    for (int i = 0; i < events.length; i++) {
      final event = events[i];
      final isSelected = selectedEvent?.id == event.id;
      if (event.sweepAngle <= 1.0) continue;

      final isCompleted = isEventCompleted(event);
      final isActive = isEventActive(event);

      if (pastStyle == PastHoursStyle.disappear && isCompleted) {
        continue;
      }
      if (pastStyle == PastHoursStyle.birdsEye &&
          isCompleted &&
          !recentCompletedIds.contains(event.id)) {
        continue;
      }

      double contentStartDeg = event.startAngle;
      double contentSweepDeg = event.sweepAngle;

      if (warp != null) {
        final warpedStart = warp.warp(event.startAngle);
        final warpedEnd = warp.warp(event.startAngle + event.sweepAngle);
        var warpedSweep = (warpedEnd - warpedStart) % 360.0;
        if (warpedSweep <= 0) warpedSweep += 360.0;

        final startGap = hasContiguousPredecessor[i]
            ? 0.0
            : (defaultSectorGapDeg / 2.0);
        final endGap = hasContiguousSuccessor[i]
            ? 0.0
            : (defaultSectorGapDeg / 2.0);

        contentStartDeg = warpedStart + startGap;
        contentSweepDeg = (warpedSweep - startGap - endGap).clamp(4.0, 360.0);
      } else if (pastStyle == PastHoursStyle.disappear && isActive) {
        final remainingDuration = event.end.difference(effectiveTime);
        final remainingSweep = SectorMath.durationToSweepAngle(
          remainingDuration,
          is24HourMode: is24,
        );
        if (remainingSweep <= 1.0) continue;

        contentStartDeg = effectiveAngle;
        contentSweepDeg = remainingSweep;
      } else {
        final startGap = hasContiguousPredecessor[i]
            ? 0.0
            : (defaultSectorGapDeg / 2.0);
        final endGap = hasContiguousSuccessor[i]
            ? 0.0
            : (defaultSectorGapDeg / 2.0);
        contentStartDeg = event.startAngle + startGap;
        contentSweepDeg = (event.sweepAngle - startGap - endGap).clamp(
          4.0,
          360.0,
        );
      }

      final double contentAlpha;
      if (warp != null) {
        contentAlpha = (warp.focusEventId == event.id || isSelected)
            ? 1.0
            : 0.35;
      } else if (pastStyle == PastHoursStyle.birdsEye) {
        if (isCompleted) {
          contentAlpha = 0.40;
        } else if (isActive ||
            isSelected ||
            nextUpcomingIds.contains(event.id)) {
          contentAlpha = 1.0;
        } else {
          contentAlpha = 0.50;
        }
      } else {
        contentAlpha = 1.0;
      }

      final radii = getEventRadii(event);
      final cornerRadius = math
          .min(10.0, (radii.rOut - radii.rIn) * 0.28)
          .clamp(3.0, 10.0);
      final sectorClipPath = _buildRoundedSectorPath(
        center: center,
        rIn: radii.rIn,
        rOut: radii.rOut,
        startDeg: contentStartDeg,
        sweepDeg: contentSweepDeg,
        cornerRadius: cornerRadius,
        roundStart: true,
        roundEnd: true,
      );

      canvas.save();
      canvas.clipPath(sectorClipPath);
      _drawSectorPillContent(
        canvas,
        center,
        event,
        radii.rIn,
        radii.rOut,
        contentStartDeg,
        contentSweepDeg,
        contentAlpha: contentAlpha,
      );
      canvas.restore();
    }
  }

  Path _buildRoundedSectorPath({
    required Offset center,
    required double rIn,
    required double rOut,
    required double startDeg,
    required double sweepDeg,
    required double cornerRadius,
    bool roundStart = true,
    bool roundEnd = true,
  }) {
    final path = Path();
    if (sweepDeg <= 0) return path;

    final endDeg = startDeg + sweepDeg;

    var dThOut = (cornerRadius / rOut) * (180.0 / math.pi);
    var dThIn = (cornerRadius / rIn) * (180.0 / math.pi);

    final maxDTh = sweepDeg * 0.45;
    if (dThOut > maxDTh) dThOut = maxDTh;
    if (dThIn > maxDTh) dThIn = maxDTh;

    final cRadOut = dThOut * (math.pi / 180.0) * rOut;
    final cRadIn = dThIn * (math.pi / 180.0) * rIn;
    final actualCornerR = math.min(cRadOut, cRadIn);

    Offset pt(double r, double deg) {
      final rad = SectorMath.dialAngleToCanvasRadians(deg);
      return Offset(
        center.dx + r * math.cos(rad),
        center.dy + r * math.sin(rad),
      );
    }

    if (roundStart) {
      // 1. Move to start of outer edge
      final p0 = pt(rOut - actualCornerR, startDeg);
      path.moveTo(p0.dx, p0.dy);

      // 2. Corner 1 (Start-Outer)
      final p1 = pt(rOut, startDeg + dThOut);
      path.arcToPoint(p1, radius: Radius.circular(actualCornerR));
    } else {
      final p0 = pt(rOut, startDeg);
      path.moveTo(p0.dx, p0.dy);
    }

    // Outer arc
    final sweepOutStart = roundStart ? startDeg + dThOut : startDeg;
    final sweepOutEnd = roundEnd ? endDeg - dThOut : endDeg;
    final sweepOut = sweepOutEnd - sweepOutStart;
    if (sweepOut > 0) {
      path.arcTo(
        Rect.fromCircle(center: center, radius: rOut),
        SectorMath.dialAngleToCanvasRadians(sweepOutStart),
        SectorMath.degToRad(sweepOut),
        false,
      );
    }

    if (roundEnd) {
      // Corner 2 (End-Outer)
      final p2 = pt(rOut - actualCornerR, endDeg);
      path.arcToPoint(p2, radius: Radius.circular(actualCornerR));

      // Radial straight edge to inner corner
      final p3 = pt(rIn + actualCornerR, endDeg);
      path.lineTo(p3.dx, p3.dy);

      // Corner 3 (End-Inner)
      final p4 = pt(rIn, endDeg - dThIn);
      path.arcToPoint(p4, radius: Radius.circular(actualCornerR));
    } else {
      final pEndIn = pt(rIn, endDeg);
      path.lineTo(pEndIn.dx, pEndIn.dy);
    }

    // Inner arc
    final sweepInStart = roundEnd ? endDeg - dThIn : endDeg;
    final sweepInEnd = roundStart ? startDeg + dThIn : startDeg;
    final sweepIn = sweepInStart - sweepInEnd;
    if (sweepIn > 0) {
      path.arcTo(
        Rect.fromCircle(center: center, radius: rIn),
        SectorMath.dialAngleToCanvasRadians(sweepInStart),
        -SectorMath.degToRad(sweepIn),
        false,
      );
    }

    if (roundStart) {
      // Corner 4 (Start-Inner)
      final p5 = pt(rIn + actualCornerR, startDeg);
      path.arcToPoint(p5, radius: Radius.circular(actualCornerR));
    }

    path.close();
    return path;
  }

  void _drawSectorPillContent(
    Canvas canvas,
    Offset center,
    SectorEvent event,
    double rIn,
    double rOut,
    double startDeg,
    double sweepDeg, {
    double contentAlpha = 1.0,
  }) {
    final is24 = settings.is24HourMode;
    if (sweepDeg < (is24 ? 6.0 : 10.0)) return;

    final midDeg = startDeg + (sweepDeg / 2.0);
    final midRad = SectorMath.dialAngleToCanvasRadians(midDeg);
    final midR = (rIn + rOut) / 2.0;
    final pos = Offset(
      center.dx + midR * math.cos(midRad),
      center.dy + midR * math.sin(midRad),
    );

    // Adaptive contrast: Dark charcoal on pastel fills, crisp white on dark fills
    final isDarkSector =
        ThemeData.estimateBrightnessForColor(event.color) == Brightness.dark;
    final baseTextColor = isDarkSector
        ? const Color(0xFFF7F3EE)
        : const Color(0xFF1E1A16);
    final textColor = baseTextColor.withValues(alpha: contentAlpha);

    final isMultiTier = event.topLevel > 0 || event.bottomLevel < 1000;
    final iconFontSize = isMultiTier
        ? (is24 ? 11.0 : 12.5)
        : (is24 ? 13.5 : 15.0);
    final titleFontSize = isMultiTier
        ? (is24 ? 8.5 : 9.5)
        : (is24 ? 10.0 : 11.5);
    final durationFontSize = isMultiTier
        ? (is24 ? 7.5 : 8.0)
        : (is24 ? 8.5 : 9.5);

    final iconData = _getEventIcon(event);

    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(iconData.codePoint),
        style: TextStyle(
          fontSize: iconFontSize,
          fontFamily: iconData.fontFamily,
          package: iconData.fontPackage,
          color: textColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    if (sweepDeg < (is24 ? 11.0 : 18.0)) {
      // Very narrow sector: draw icon only
      iconPainter.paint(
        canvas,
        Offset(pos.dx - iconPainter.width / 2, pos.dy - iconPainter.height / 2),
      );
      return;
    }

    final arcWidth = midR * (sweepDeg * math.pi / 180.0) - 10.0;
    final maxTitleWidth = math.max(arcWidth * 0.90, 48.0);
    final titlePainter = TextPainter(
      text: TextSpan(
        text: event.title.trim(),
        style: TextStyle(
          fontSize: titleFontSize,
          fontWeight: FontWeight.w900,
          color: textColor,
          letterSpacing: 0.1,
          height: 1.12,
        ),
      ),
      maxLines: 2,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      ellipsis: '…',
    )..layout(maxWidth: maxTitleWidth);

    final durationStr = TimeFormatters.formatDuration(event.duration);
    final durationPainter = TextPainter(
      text: TextSpan(
        text: durationStr,
        style: TextStyle(
          fontSize: durationFontSize,
          fontWeight: FontWeight.w700,
          color: textColor.withValues(alpha: 0.88),
          letterSpacing: 0.1,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    final trackThickness = rOut - rIn;

    if (isMultiTier && trackThickness < 65.0) {
      final arcLength = midR * (sweepDeg * math.pi / 180.0);
      if (arcLength < 28.0) {
        // Narrow multi-tier arc: Icon only
        iconPainter.paint(
          canvas,
          Offset(
            pos.dx - iconPainter.width / 2,
            pos.dy - iconPainter.height / 2,
          ),
        );
        return;
      }

      // 2-line layout for concentric tiers:
      // Line 1: [Icon] Title (centered horizontally)
      // Line 2: Duration (centered horizontally)
      final line1Width = iconPainter.width + 3.0 + titlePainter.width;
      final totalContentHeight =
          math.max(iconPainter.height, titlePainter.height) +
          2.0 +
          durationPainter.height;
      final startY = pos.dy - (totalContentHeight / 2.0);

      if (line1Width <= arcLength * 0.92) {
        final line1StartX = pos.dx - (line1Width / 2.0);
        iconPainter.paint(
          canvas,
          Offset(
            line1StartX,
            startY + (titlePainter.height - iconPainter.height) / 2.0,
          ),
        );
        titlePainter.paint(
          canvas,
          Offset(line1StartX + iconPainter.width + 3.0, startY),
        );
        durationPainter.paint(
          canvas,
          Offset(
            pos.dx - durationPainter.width / 2.0,
            startY + titlePainter.height + 2.0,
          ),
        );
      } else {
        // Tighter multi-tier arc: Icon on top, Duration underneath
        iconPainter.paint(
          canvas,
          Offset(pos.dx - iconPainter.width / 2.0, pos.dy - iconPainter.height),
        );
        durationPainter.paint(
          canvas,
          Offset(pos.dx - durationPainter.width / 2.0, pos.dy + 2.0),
        );
      }
      return;
    }

    final isNarrow =
        (event.subtasks.isEmpty && sweepDeg < (is24 ? 36.0 : 45.0)) ||
        (sweepDeg < (is24 ? 18.0 : 26.0));

    if (isNarrow) {
      // Narrow sector: dynamically orient straight along the radial spoke
      // so text, icon, and duration fit without horizontal boundary collision
      canvas.save();
      canvas.translate(pos.dx, pos.dy);

      var rotation = midRad;
      if (math.cos(midRad) < -0.05) {
        rotation += math.pi;
      }
      canvas.rotate(rotation);

      final maxRadialLength = (rOut - rIn) - 10.0;
      final inlineWidth =
          iconPainter.width +
          4.0 +
          titlePainter.width +
          4.0 +
          durationPainter.width;

      if (inlineWidth <= maxRadialLength) {
        // Option A: Single straight line along radial spoke: [Icon] Title Duration
        var currX = -inlineWidth / 2.0;

        iconPainter.paint(canvas, Offset(currX, -iconPainter.height / 2.0));
        currX += iconPainter.width + 4.0;

        titlePainter.paint(canvas, Offset(currX, -titlePainter.height / 2.0));
        currX += titlePainter.width + 4.0;

        durationPainter.paint(
          canvas,
          Offset(currX, -durationPainter.height / 2.0),
        );
      } else {
        // Option B: Icon beside stacked Title (top) & Duration (bottom) along radial spoke
        final textBlockWidth = math.max(
          titlePainter.width,
          durationPainter.width,
        );
        var totalWidth = iconPainter.width + 4.0 + textBlockWidth;
        if (totalWidth > maxRadialLength) {
          final scaleFactor = (maxRadialLength / totalWidth).clamp(0.65, 1.0);
          canvas.scale(scaleFactor, scaleFactor);
          totalWidth = totalWidth * scaleFactor;
        }
        final startX = (-totalWidth / 2.0).clamp(-maxRadialLength / 2.0, 0.0);

        iconPainter.paint(canvas, Offset(startX, -iconPainter.height / 2.0));

        final textX = startX + iconPainter.width + 4.0;
        titlePainter.paint(canvas, Offset(textX, -titlePainter.height + 1.0));
        durationPainter.paint(canvas, Offset(textX, 1.5));
      }

      canvas.restore();
    } else {
      final bool showDockedSubtask =
          event.subtasks.isNotEmpty && sweepDeg < (is24 ? 38.0 : 55.0);

      TextPainter? dockedSubtaskPainter;
      double dockedPillW = 0.0;
      double dockedPillH = 0.0;

      if (showDockedSubtask) {
        final firstSub = event.subtasks.first.trim();
        final subText = event.subtasks.length > 1
            ? '$firstSub (+${event.subtasks.length - 1})'
            : firstSub;
        dockedSubtaskPainter = TextPainter(
          text: TextSpan(
            text: subText,
            style: TextStyle(
              fontSize: 7.2,
              fontWeight: FontWeight.w700,
              color: isDarkSector
                  ? const Color(0xFFF7F3EE)
                        .withValues(alpha: 0.92 * contentAlpha)
                  : const Color(0xFF1E1A16)
                        .withValues(alpha: 0.90 * contentAlpha),
              letterSpacing: -0.1,
            ),
          ),
          maxLines: 1,
          ellipsis: '…',
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        )..layout(maxWidth: math.max(arcWidth * 0.85, 36.0));

        dockedPillW = dockedSubtaskPainter.width + 10.0;
        dockedPillH = dockedSubtaskPainter.height + 4.0;
      }

      const gap = 2.0;
      final totalH =
          iconPainter.height +
          gap +
          titlePainter.height +
          gap +
          durationPainter.height +
          (showDockedSubtask ? (gap + 2.0 + dockedPillH) : 0.0);

      var effectiveScale = 1.0;
      final contentW = math.max(
        dockedPillW,
        math.max(
          iconPainter.width,
          math.max(titlePainter.width, durationPainter.width),
        ),
      );
      if (contentW > arcWidth) {
        effectiveScale = (arcWidth / contentW).clamp(0.65, 1.0);
      }
      if (totalH > (trackThickness - 6.0)) {
        final hScale = ((trackThickness - 6.0) / totalH).clamp(0.60, 1.0);
        effectiveScale = math.min(effectiveScale, hScale);
      }

      final startY = -(totalH / 2.0);
      final iconY = startY;
      final titleY = iconY + iconPainter.height + gap;
      final durationY = titleY + titlePainter.height + gap;
      final subtaskY = durationY + durationPainter.height + gap + 2.0;

      // Organic subtask bubbles settling around main title in available space for wide sectors
      if (event.subtasks.isNotEmpty && sweepDeg >= (is24 ? 38.0 : 55.0)) {
        final mainLabelW =
            math.max(
              iconPainter.width,
              math.max(titlePainter.width, durationPainter.width),
            ) *
            effectiveScale;
        final mainLabelH =
            (iconPainter.height +
                gap +
                titlePainter.height +
                gap +
                durationPainter.height) *
            effectiveScale;
        final mainLabelRect = Rect.fromCenter(
          center: pos,
          width: mainLabelW + 18.0,
          height: mainLabelH + 12.0,
        );

        _drawOrganicSubtasks(
          canvas: canvas,
          center: center,
          event: event,
          rIn: rIn,
          rOut: rOut,
          startDeg: startDeg,
          sweepDeg: sweepDeg,
          isDarkSector: isDarkSector,
          contentAlpha: contentAlpha,
          mainLabelRect: mainLabelRect,
        );
      }

      // Main stack: Icon, Title, Duration upright
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      if (effectiveScale < 1.0) {
        canvas.scale(effectiveScale, effectiveScale);
      }

      iconPainter.paint(canvas, Offset(-iconPainter.width / 2.0, iconY));
      titlePainter.paint(canvas, Offset(-titlePainter.width / 2.0, titleY));
      durationPainter.paint(
        canvas,
        Offset(-durationPainter.width / 2.0, durationY),
      );

      if (showDockedSubtask && dockedSubtaskPainter != null) {
        final dockedRect = Rect.fromCenter(
          center: Offset(0, subtaskY + dockedPillH / 2.0),
          width: dockedPillW,
          height: dockedPillH,
        );
        final pillBg = isDarkSector
            ? Colors.white.withValues(alpha: 0.16 * contentAlpha)
            : Colors.black.withValues(alpha: 0.10 * contentAlpha);
        final pillBorder = isDarkSector
            ? Colors.white.withValues(alpha: 0.32 * contentAlpha)
            : Colors.black.withValues(alpha: 0.22 * contentAlpha);

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            dockedRect.shift(const Offset(0, 1.0)),
            Radius.circular(dockedPillH / 2.0),
          ),
          Paint()
            ..color = Colors.black.withValues(alpha: 0.12 * contentAlpha)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            dockedRect,
            Radius.circular(dockedPillH / 2.0),
          ),
          Paint()
            ..color = pillBg
            ..style = PaintingStyle.fill,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            dockedRect,
            Radius.circular(dockedPillH / 2.0),
          ),
          Paint()
            ..color = pillBorder
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8,
        );
        dockedSubtaskPainter.paint(
          canvas,
          Offset(-dockedSubtaskPainter.width / 2.0, subtaskY + 2.0),
        );
      }

      canvas.restore();
    }
  }

  void _drawOrganicSubtasks({
    required Canvas canvas,
    required Offset center,
    required SectorEvent event,
    required double rIn,
    required double rOut,
    required double startDeg,
    required double sweepDeg,
    required bool isDarkSector,
    required double contentAlpha,
    required Rect mainLabelRect,
  }) {
    if (event.subtasks.isEmpty) return;

    final subtasks = event.subtasks;
    final count = math.min(subtasks.length, 6);
    final trackThickness = rOut - rIn;
    final midR = (rIn + rOut) / 2.0;

    // Anchor candidates distributed around the wide sector:
    // Left wing, right wing, top wing, bottom wing
    final candidateSlots = const [
      (angleFrac: -0.62, radialFrac: 0.52),
      (angleFrac: 0.60, radialFrac: -0.48),
      (angleFrac: 0.65, radialFrac: 0.50),
      (angleFrac: -0.58, radialFrac: -0.50),
      (angleFrac: -0.78, radialFrac: 0.05),
      (angleFrac: 0.78, radialFrac: -0.05),
      (angleFrac: -0.38, radialFrac: 0.68),
      (angleFrac: 0.38, radialFrac: -0.68),
      (angleFrac: -0.40, radialFrac: -0.68),
      (angleFrac: 0.40, radialFrac: 0.68),
    ];

    final basePillBg = isDarkSector
        ? Colors.white.withValues(alpha: 0.15 * contentAlpha)
        : Colors.black.withValues(alpha: 0.10 * contentAlpha);
    final baseBorderColor = isDarkSector
        ? Colors.white.withValues(alpha: 0.30 * contentAlpha)
        : Colors.black.withValues(alpha: 0.20 * contentAlpha);
    final baseTextColor = isDarkSector
        ? const Color(0xFFF7F3EE).withValues(alpha: 0.90 * contentAlpha)
        : const Color(0xFF1E1A16).withValues(alpha: 0.88 * contentAlpha);

    final List<Rect> placedPills = [];

    for (int i = 0; i < count; i++) {
      final subtask = subtasks[i].trim();
      final hash = (subtask.hashCode ^ (i * 37)).abs();
      final fontSize = 6.8 + (hash % 4) * 0.9;

      String text = subtask;
      if (text.length > 13) {
        text = '${text.substring(0, 12)}…';
      }

      final textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: baseTextColor,
            letterSpacing: -0.1,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();

      final pillPadH = 5.0 + (hash % 3);
      final pillPadV = 2.0 + (hash % 2) * 0.5;
      final pillW = textPainter.width + pillPadH * 2;
      final pillH = textPainter.height + pillPadV * 2;

      // Try candidate slots until one does not collide with mainLabelRect or existing pills
      Rect? selectedPillRect;
      Offset? selectedPos;

      for (int slotIdx = 0; slotIdx < candidateSlots.length; slotIdx++) {
        final slot = candidateSlots[(i + slotIdx) % candidateSlots.length];
        final jitterAngle = ((hash % 11) - 5) * 0.02;
        final jitterR = (((hash ~/ 11) % 9) - 4) * 0.03;

        final targetAngleFrac = (slot.angleFrac + jitterAngle).clamp(
          -0.85,
          0.85,
        );
        final targetRadialFrac = (slot.radialFrac + jitterR).clamp(-0.76, 0.76);

        final bubbleAngleDeg =
            (startDeg + sweepDeg / 2.0) + targetAngleFrac * (sweepDeg * 0.44);
        final bubbleR = midR + targetRadialFrac * (trackThickness * 0.40);

        final bubbleRad = SectorMath.dialAngleToCanvasRadians(bubbleAngleDeg);
        final bubblePos = Offset(
          center.dx + bubbleR * math.cos(bubbleRad),
          center.dy + bubbleR * math.sin(bubbleRad),
        );

        final testRect = Rect.fromCenter(
          center: bubblePos,
          width: pillW,
          height: pillH,
        );

        // Strict collision check against mainLabelRect (with 6px buffer) and other pills (with 3px buffer)
        final collidesWithMain = testRect.overlaps(mainLabelRect.inflate(6.0));
        final collidesWithPlaced = placedPills.any(
          (p) => testRect.overlaps(p.inflate(3.0)),
        );

        if (!collidesWithMain && !collidesWithPlaced) {
          selectedPillRect = testRect;
          selectedPos = bubblePos;
          break;
        }
      }

      if (selectedPillRect == null || selectedPos == null) {
        continue; // Could not place without overlapping - discard safely!
      }

      placedPills.add(selectedPillRect);

      // Subtle drop shadow for organic depth
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          selectedPillRect.shift(const Offset(0, 1.0)),
          Radius.circular(pillH / 2.0),
        ),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.14 * contentAlpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );

      // Pill capsule background
      canvas.drawRRect(
        RRect.fromRectAndRadius(selectedPillRect, Radius.circular(pillH / 2.0)),
        Paint()
          ..color = basePillBg
          ..style = PaintingStyle.fill,
      );

      // Pill capsule border
      canvas.drawRRect(
        RRect.fromRectAndRadius(selectedPillRect, Radius.circular(pillH / 2.0)),
        Paint()
          ..color = baseBorderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );

      // Pill text
      textPainter.paint(
        canvas,
        Offset(
          selectedPos.dx - textPainter.width / 2.0,
          selectedPos.dy - textPainter.height / 2.0,
        ),
      );
    }
  }

  IconData _getEventIcon(SectorEvent event) => event.resolvedIcon;

  void _drawAnalogHands(Canvas canvas, Offset center, double innerRadius) {
    // 1. Hour hand angle (12-hour or 24-hour coordinate)
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

    // 2. Hour Hand: Olive green rounded capsule bar
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

    // 3. Minute Hand: Soft lavender rounded capsule bar
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

    // 4. Center Pivot Cap: Warm cream/gold circle with inner core
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

    // 1. Sleek circular core (surface container matching seed palette)
    final corePaint = Paint()
      ..color = isDark
          ? colorScheme.surfaceContainerLow
          : colorScheme.surfaceContainerHigh
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, innerRadius, corePaint);

    final coreBorder = Paint()
      ..color = colorScheme.outlineVariant
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, innerRadius - 0.5, coreBorder);

    // 2. Subtle center horizon progress arc (TMRW indicator)
    if (!is24) {
      final arcPaint = Paint()
        ..color = colorScheme.primary.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: innerRadius - 3.0),
        -math.pi / 2,
        math.pi / 2,
        false,
        arcPaint,
      );
    }

    // 3. Measure elements for balanced vertical centering inside the circular boundary
    canvas.save();
    canvas.clipPath(
      Path()
        ..addOval(Rect.fromCircle(center: center, radius: innerRadius - 2.0)),
    );

    final amPmFontSize = (innerRadius * 0.16).clamp(9.0, 11.0);
    final timeFontSize = (innerRadius * 0.44).clamp(22.0, 30.0);
    final dateFontSize = (innerRadius * 0.17).clamp(8.5, 11.0);
    final statusFontSize = (innerRadius * 0.14).clamp(8.0, 9.5);
    final pillH = (innerRadius * 0.20).clamp(12.0, 15.0);

    TextPainter? amPmPainter;
    if (!is24) {
      amPmPainter = TextPainter(
        text: TextSpan(
          text: amPmStr,
          style: TextStyle(
            fontSize: amPmFontSize,
            fontWeight: FontWeight.w800,
            color: colorScheme.primary,
            letterSpacing: 0.8,
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
    }

    final timePainter = TextPainter(
      text: TextSpan(
        text: timeStr,
        style: TextStyle(
          fontSize: timeFontSize,
          fontWeight: FontWeight.w900,
          color: isDark ? const Color(0xFFF7F3EE) : colorScheme.onSurface,
          letterSpacing: -0.5,
          height: 1.0,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    final datePainter = TextPainter(
      text: TextSpan(
        text: dateStr,
        style: TextStyle(
          fontSize: dateFontSize,
          fontWeight: FontWeight.w600,
          color: isDark
              ? const Color(0xFFA89F91)
              : colorScheme.onSurfaceVariant,
          letterSpacing: 0.1,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    final statusText = activeEvent?.title ?? 'Radian';
    final statusColor = activeEvent?.color ?? colorScheme.primary;

    // Constrain pill and text to circular chord width so it never overflows
    final maxPillW = innerRadius * 1.35;
    final maxTextW = maxPillW - 14.0;

    var effectiveStatusFontSize = statusFontSize;
    var statusPainter = TextPainter(
      text: TextSpan(
        text: statusText,
        style: TextStyle(
          fontSize: effectiveStatusFontSize,
          fontWeight: FontWeight.w800,
          color: statusColor,
          letterSpacing: 0.1,
          height: 1.0,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    // Dynamically scale down font size so the title fits without hiding words in ellipsis
    if (statusPainter.width > maxTextW) {
      final scaleFactor = (maxTextW / statusPainter.width).clamp(0.68, 1.0);
      effectiveStatusFontSize = statusFontSize * scaleFactor;
      statusPainter = TextPainter(
        text: TextSpan(
          text: statusText,
          style: TextStyle(
            fontSize: effectiveStatusFontSize,
            fontWeight: FontWeight.w800,
            color: statusColor,
            letterSpacing: 0.1,
            height: 1.0,
          ),
        ),
        maxLines: 1,
        ellipsis: '...',
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: maxTextW);
    }

    // Vertical layout - perfectly balanced around center.dy
    final totalHeight =
        (amPmPainter != null ? amPmPainter.height + 1.0 : 0.0) +
        timePainter.height +
        2.0 +
        datePainter.height +
        3.0 +
        pillH;

    var currY = center.dy - (totalHeight / 2.0);

    if (amPmPainter != null) {
      amPmPainter.paint(
        canvas,
        Offset(center.dx - amPmPainter.width / 2, currY),
      );
      currY += amPmPainter.height + 1.0;
    }

    timePainter.paint(canvas, Offset(center.dx - timePainter.width / 2, currY));
    currY += timePainter.height + 2.0;

    datePainter.paint(canvas, Offset(center.dx - datePainter.width / 2, currY));
    currY += datePainter.height + 3.0;

    // Compact status pill with guaranteed chord fit
    final pillW = math.min(statusPainter.width + 14.0, maxPillW);
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, currY + pillH / 2),
        width: pillW,
        height: pillH,
      ),
      Radius.circular(pillH / 2),
    );

    final pillBg = Paint()
      ..color = statusColor.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(pillRect, pillBg);

    final pillBorder = Paint()
      ..color = statusColor.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawRRect(pillRect, pillBorder);

    statusPainter.paint(
      canvas,
      Offset(
        center.dx - statusPainter.width / 2,
        currY + (pillH - statusPainter.height) / 2,
      ),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SectographPainter oldDelegate) {
    return oldDelegate.events != events ||
        oldDelegate.selectedEvent != selectedEvent ||
        oldDelegate.activeEvent != activeEvent ||
        oldDelegate.currentTime.second != currentTime.second ||
        oldDelegate.scrubAngle != scrubAngle ||
        oldDelegate.showCenterClock != showCenterClock ||
        oldDelegate.settings != settings ||
        oldDelegate.colorScheme != colorScheme;
  }
}
