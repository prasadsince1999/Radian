import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/geometry/fisheye_time_lens.dart';
import '../../../../core/geometry/sector_math.dart';
import '../../../../domain/models/dial_settings.dart';

/// Reusable component for rendering the 3D-numbered dial bezel, tick marks,
/// concentric ring dividers, and track backgrounds.
class DialBezelRenderer {
  const DialBezelRenderer._();

  /// Draws the background gradient and concentric track dividers.
  static void drawBackgroundAndDividers({
    required Canvas canvas,
    required Offset center,
    required double routineTrackIn,
    required double routineTrackOut,
    required double ringDividerRadius,
    required ColorScheme colorScheme,
    required bool isDark,
  }) {
    // 1. Subtle background track fill
    final trackPaint = Paint()
      ..color = (isDark ? Colors.black : Colors.white).withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, routineTrackOut, trackPaint);

    // 2. Concentric ring divider line between outer and inner tracks
    final dividerPaint = Paint()
      ..color = (isDark ? const Color(0xFF6B7280) : colorScheme.outlineVariant)
          .withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, ringDividerRadius, dividerPaint);

    // 3. Inner hub boundary
    final innerHubPaint = Paint()
      ..color = (isDark ? Colors.black : Colors.white).withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, routineTrackIn, innerHubPaint);
  }

  /// Draws the dial face with 3D hour numbers positioned half over the block and half outside,
  /// replacing the major tick marks, with subtle minor interval ticks.
  static void drawTicks({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required bool is24HourMode,
    required DialFaceStyle faceStyle,
    required ColorScheme colorScheme,
    FisheyeTimeLens? lens,
    double? trackOuterRadius,
  }) {
    final isDark = colorScheme.brightness == Brightness.dark;
    final tickColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF374151);

    final minorTickPaint = Paint()
      ..color = tickColor.withValues(alpha: 0.40)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    final numRadius = trackOuterRadius ?? (radius - 2.5);

    // 1. Draw subtle minor ticks between hours (if not minimal style)
    if (faceStyle != DialFaceStyle.minimal) {
      final totalIntervals = is24HourMode ? 48 : 48; // 30m in 24h, 15m in 12h
      final intervalsPerHour = is24HourMode ? 2 : 4;

      for (int i = 0; i < totalIntervals; i++) {
        // Skip positions where an hour number sits!
        if (i % intervalsPerHour == 0) continue;

        final rawDeg = (i / totalIntervals) * 360.0;
        final visualDeg = lens?.warpAngle(rawDeg) ?? rawDeg;
        final rad = SectorMath.dialAngleToCanvasRadians(visualDeg);

        final isHalfHour = (!is24HourMode && i % 2 == 0);
        final tickLength = isHalfHour ? 3.5 : 2.0;

        final pOuter = Offset(
          center.dx + radius * math.cos(rad),
          center.dy + radius * math.sin(rad),
        );
        final pInner = Offset(
          center.dx + (radius - tickLength) * math.cos(rad),
          center.dy + (radius - tickLength) * math.sin(rad),
        );

        canvas.drawLine(pInner, pOuter, minorTickPaint);
      }
    }

    // 2. Draw 3D Hour Numbers (e.g. 12, 1, 2, ..., 11) centered on trackOuterRadius
    // Half over the block, half outside the block!
    final totalHours = is24HourMode ? 24 : 12;
    final fontSize = is24HourMode ? 8.5 : 11.5;

    for (int h = 0; h < totalHours; h++) {
      final rawDeg = (h / totalHours) * 360.0;
      final visualDeg = lens?.warpAngle(rawDeg) ?? rawDeg;
      final rad = SectorMath.dialAngleToCanvasRadians(visualDeg);

      final String numStr;
      if (is24HourMode) {
        numStr = '$h';
      } else {
        final hourVal = h == 0 ? 12 : h;
        numStr = '$hourVal';
      }

      final textCenter = Offset(
        center.dx + numRadius * math.cos(rad),
        center.dy + numRadius * math.sin(rad),
      );

      _draw3dHourNumber(
        canvas: canvas,
        center: textCenter,
        text: numStr,
        fontSize: fontSize,
        isDark: isDark,
      );
    }
  }

  /// Renders a 3D hour number with ambient drop shadow, dark contrast halo,
  /// and crisp face fill so it pops with depth over any block color and background.
  static void _draw3dHourNumber({
    required Canvas canvas,
    required Offset center,
    required String text,
    required double fontSize,
    required bool isDark,
  }) {
    final fontStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.3,
    );

    // 1. Ambient 3D drop shadow (creates depth behind the number)
    final shadowSpan = TextSpan(
      text: text,
      style: fontStyle.copyWith(
        color: Colors.transparent,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: isDark ? 0.95 : 0.45),
            offset: const Offset(0.0, 1.8),
            blurRadius: 3.5,
          ),
          Shadow(
            color: Colors.black.withValues(alpha: isDark ? 0.85 : 0.35),
            offset: const Offset(0.0, 0.8),
            blurRadius: 1.5,
          ),
        ],
      ),
    );
    final shadowPainter = TextPainter(
      text: shadowSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    // 2. 3D Dark Bezel Outline / Halo (guarantees 100% legibility over ANY sector color)
    final outlineSpan = TextSpan(
      text: text,
      style: fontStyle.copyWith(
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = isDark
              ? const Color(0xFF0F172A).withValues(alpha: 0.92)
              : Colors.white.withValues(alpha: 0.95),
      ),
    );
    final outlinePainter = TextPainter(
      text: outlineSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    // 3. Crisp Foreground Face
    final fillSpan = TextSpan(
      text: text,
      style: fontStyle.copyWith(
        color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
      ),
    );
    final fillPainter = TextPainter(
      text: fillSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final textPos = Offset(
      center.dx - fillPainter.width / 2.0,
      center.dy - fillPainter.height / 2.0,
    );

    shadowPainter.paint(canvas, textPos);
    outlinePainter.paint(canvas, textPos);
    fillPainter.paint(canvas, textPos);
  }
}
