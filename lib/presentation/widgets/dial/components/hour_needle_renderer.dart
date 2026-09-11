import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Reusable component for rendering the two-stage hierarchical red hour indicator needle.
///
/// Features:
/// - Inner Segment: Subtle 1.5dp hairline at 50% opacity across the inner ring (preserving legibility).
/// - Outer Segment: Bold 3.2dp crimson needle with ambient glow across the active outer ring.
/// - Junction Micro-dot at the ring transition boundary.
/// - Outer Rim Beacon: Day/night celestial icon badge (Sun during daytime, Moon at night).
class HourNeedleRenderer {
  const HourNeedleRenderer._();

  /// Draws the complete two-stage hour needle with glow, junction dot, and rim beacon.
  static void drawNeedle({
    required Canvas canvas,
    required Offset center,
    required double angleRad,
    required double hubRadius,
    required double outerRIn,
    required double outerROut,
    required bool isDaytime,
    Color needleColor = const Color(0xFFEF4444), // Crimson
  }) {
    final cosAngle = math.cos(angleRad);
    final sinAngle = math.sin(angleRad);

    final hubPt = Offset(
      center.dx + hubRadius * cosAngle,
      center.dy + hubRadius * sinAngle,
    );
    final junctionPt = Offset(
      center.dx + outerRIn * cosAngle,
      center.dy + outerRIn * sinAngle,
    );
    final rimPt = Offset(
      center.dx + outerROut * cosAngle,
      center.dy + outerROut * sinAngle,
    );

    // 1. Stage 1 (Inner Segment): Subtle hairline across inner ring
    final hairlinePaint = Paint()
      ..color = needleColor.withValues(alpha: 0.50)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(hubPt, junctionPt, hairlinePaint);

    // 2. Stage 2 (Outer Segment): Bold Crimson Needle
    final boldPaint = Paint()
      ..color = needleColor
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(junctionPt, rimPt, boldPaint);

    // 4. Junction Micro-dot
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(junctionPt, 2.0, dotPaint);

    // 5. Outer Rim Celestial Beacon (Sun or Moon)
    final beaconCenter = Offset(
      center.dx + (outerROut + 8.0) * cosAngle,
      center.dy + (outerROut + 8.0) * sinAngle,
    );

    // Beacon disc background
    final beaconBgPaint = Paint()
      ..color = needleColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(beaconCenter, 7.5, beaconBgPaint);

    final beaconBorderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(beaconCenter, 7.5, beaconBorderPaint);

    // Celestial Icon
    final beaconIcon = isDaytime
        ? Icons.wb_sunny_rounded
        : Icons.nightlight_round;
    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(beaconIcon.codePoint),
        style: TextStyle(
          fontSize: 8.5,
          fontFamily: beaconIcon.fontFamily,
          package: beaconIcon.fontPackage,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    iconPainter.paint(
      canvas,
      Offset(
        beaconCenter.dx - iconPainter.width / 2.0,
        beaconCenter.dy - iconPainter.height / 2.0,
      ),
    );
  }
}
