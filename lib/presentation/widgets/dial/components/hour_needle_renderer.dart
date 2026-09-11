import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Reusable component for rendering the single continuous red hour indicator needle.
///
/// Features:
/// - Single Continuous Needle: Solid 3.0dp crimson needle hand across the single ring track.
/// - Outer Rim Beacon: Day/night celestial icon badge (Sun during daytime, Moon at night).
class HourNeedleRenderer {
  const HourNeedleRenderer._();

  /// Draws the single continuous hour needle and celestial beacon,
  /// strictly contained within the circular dial area.
  static void drawNeedle({
    required Canvas canvas,
    required Offset center,
    required double angleRad,
    required double hubRadius,
    required double outerROut,
    required bool isDaytime,
    double? baseRadius,
    double? outerRIn,
    Color needleColor = const Color(0xFFEF4444), // Crimson
  }) {
    final cosAngle = math.cos(angleRad);
    final sinAngle = math.sin(angleRad);

    final hubPt = Offset(
      center.dx + hubRadius * cosAngle,
      center.dy + hubRadius * sinAngle,
    );

    // Position beacon safely inside the outer circle rim (baseRadius)
    const beaconRadius = 6.5;
    final effectiveBaseRadius = baseRadius ?? (outerROut + 3.5);
    final beaconCenterDist = effectiveBaseRadius - beaconRadius - 4.5;
    final beaconCenter = Offset(
      center.dx + beaconCenterDist * cosAngle,
      center.dy + beaconCenterDist * sinAngle,
    );

    // 1. Single solid, continuous crimson needle hand running cleanly to the beacon center
    final needlePaint = Paint()
      ..color = needleColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(hubPt, beaconCenter, needlePaint);

    // 2. Celestial Beacon (Sun or Moon) strictly contained within the circle area
    final beaconBgPaint = Paint()
      ..color = needleColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(beaconCenter, beaconRadius, beaconBgPaint);

    final beaconBorderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(beaconCenter, beaconRadius, beaconBorderPaint);

    // Celestial Icon
    final beaconIcon = isDaytime
        ? Icons.wb_sunny_rounded
        : Icons.nightlight_round;
    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(beaconIcon.codePoint),
        style: TextStyle(
          fontSize: 7.5,
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
