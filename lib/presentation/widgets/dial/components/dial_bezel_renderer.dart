import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/geometry/fisheye_time_lens.dart';
import '../../../../core/geometry/sector_math.dart';
import '../../../../domain/models/dial_settings.dart';

/// Reusable component for rendering the numeral-free dial bezel, tick marks,
/// concentric ring dividers, and day/night background sweep.
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

  /// Draws the numeral-free dial face with tick marks.
  static void drawTicks({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required bool is24HourMode,
    required DialFaceStyle faceStyle,
    required ColorScheme colorScheme,
    FisheyeTimeLens? lens,
  }) {
    final isDark = colorScheme.brightness == Brightness.dark;
    final tickColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF374151);

    final majorTickPaint = Paint()
      ..color = tickColor.withValues(alpha: 0.90)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final minorTickPaint = Paint()
      ..color = tickColor.withValues(alpha: 0.45)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    final totalTicks = is24HourMode ? 96 : 60; // 15-min or 12-min intervals
    final majorInterval = is24HourMode ? 4 : 5; // Every 1 hour

    for (int i = 0; i < totalTicks; i++) {
      final isMajor = i % majorInterval == 0;
      final rawDeg = (i / totalTicks) * 360.0;
      final visualDeg = lens?.warpAngle(rawDeg) ?? rawDeg;
      final rad = SectorMath.dialAngleToCanvasRadians(visualDeg);

      final tickLength = isMajor ? 6.5 : 3.5;
      final pOuter = Offset(
        center.dx + radius * math.cos(rad),
        center.dy + radius * math.sin(rad),
      );
      final pInner = Offset(
        center.dx + (radius - tickLength) * math.cos(rad),
        center.dy + (radius - tickLength) * math.sin(rad),
      );

      canvas.drawLine(
        pInner,
        pOuter,
        isMajor ? majorTickPaint : minorTickPaint,
      );
    }
  }
}
