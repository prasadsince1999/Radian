import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Reusable component for rendering the single continuous red hour indicator needle.
///
/// Features:
/// - Single Continuous Needle: Solid 3.0dp crimson needle hand across the single ring track.
/// - Outer Rim Beacon: Day/night celestial icon badge (Sun during daytime, Moon at night).
class HourNeedleRenderer {
  const HourNeedleRenderer._();

  /// Draws the single continuous hour needle and outer rim celestial beacon.
  static void drawNeedle({
    required Canvas canvas,
    required Offset center,
    required double angleRad,
    required double hubRadius,
    required double outerROut,
    required bool isDaytime,
    double? outerRIn,
    Color needleColor = const Color(0xFFEF4444), // Crimson
  }) {
    final cosAngle = math.cos(angleRad);
    final sinAngle = math.sin(angleRad);

    final hubPt = Offset(
      center.dx + hubRadius * cosAngle,
      center.dy + hubRadius * sinAngle,
    );
    final rimPt = Offset(
      center.dx + outerROut * cosAngle,
      center.dy + outerROut * sinAngle,
    );

    // 1. Single solid, continuous crimson needle hand
    final needlePaint = Paint()
      ..color = needleColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(hubPt, rimPt, needlePaint);

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
