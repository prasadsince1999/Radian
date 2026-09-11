import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/geometry/sector_math.dart';
import '../../../../core/utils/time_formatters.dart';
import '../../../../domain/models/sector_event.dart';

/// Reusable component for rendering 3D curved time block sector pills.
///
/// Handles path geometry, ambient elevation, solid vibrant fills (zero dimming),
/// active focus glow, and boundary junction timestamps with per-ring isolation.
class SectorPillRenderer {
  const SectorPillRenderer._();

  /// Builds a rounded 3D curved sector path with smooth radial corners.
  static Path buildPillPath({
    required Offset center,
    required double rIn,
    required double rOut,
    required double startDeg,
    required double sweepDeg,
    double cornerRadius = 6.0,
    bool roundStart = true,
    bool roundEnd = true,
  }) {
    final path = Path();
    if (sweepDeg <= 0.05) return path;

    final endDeg = startDeg + sweepDeg;
    final radialThickness = rOut - rIn;
    final actualCornerR = cornerRadius
        .clamp(1.5, radialThickness * 0.45)
        .clamp(1.5, 12.0);

    final dThOut = (actualCornerR / rOut) * (180.0 / math.pi);
    final dThIn = (actualCornerR / rIn) * (180.0 / math.pi);

    Offset pt(double r, double deg) {
      final rad = SectorMath.dialAngleToCanvasRadians(deg);
      return Offset(
        center.dx + r * math.cos(rad),
        center.dy + r * math.sin(rad),
      );
    }

    // 1. Start point
    final startOuterDeg = roundStart ? startDeg + dThOut : startDeg;
    final p0 = pt(rOut, startOuterDeg);
    path.moveTo(p0.dx, p0.dy);

    // 2. Outer arc
    final sweepOutEnd = roundEnd ? endDeg - dThOut : endDeg;
    final sweepOut = sweepOutEnd - startOuterDeg;
    if (sweepOut > 0) {
      path.arcTo(
        Rect.fromCircle(center: center, radius: rOut),
        SectorMath.dialAngleToCanvasRadians(startOuterDeg),
        SectorMath.degToRad(sweepOut),
        false,
      );
    }

    // 3. Corner 1 (End-Outer)
    if (roundEnd) {
      final p1 = pt(rOut - actualCornerR, endDeg);
      path.arcToPoint(p1, radius: Radius.circular(actualCornerR));

      // 4. End edge to inner corner
      final p2 = pt(rIn + actualCornerR, endDeg);
      path.lineTo(p2.dx, p2.dy);

      // 5. Corner 2 (End-Inner)
      final p3 = pt(rIn, endDeg - dThIn);
      path.arcToPoint(p3, radius: Radius.circular(actualCornerR));
    } else {
      path.lineTo(pt(rIn, endDeg).dx, pt(rIn, endDeg).dy);
    }

    // 6. Inner arc (drawn counter-clockwise)
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

    // 7. Corner 3 (Start-Inner)
    if (roundStart) {
      final p4 = pt(rIn + actualCornerR, startDeg);
      path.arcToPoint(p4, radius: Radius.circular(actualCornerR));

      // 8. Start edge to outer corner
      final p5 = pt(rOut - actualCornerR, startDeg);
      path.lineTo(p5.dx, p5.dy);

      // 9. Corner 4 (Start-Outer)
      path.arcToPoint(p0, radius: Radius.circular(actualCornerR));
    } else {
      path.close();
    }

    path.close();
    return path;
  }

  /// Draws a time block sector with full vibrant fill, ambient depth, and active glow.
  static void drawPillBody({
    required Canvas canvas,
    required Path pillPath,
    required SectorEvent event,
    required bool isActive,
    required bool isSelected,
    required bool isOuterRing,
    double pulseValue = 0.0,
  }) {
    // 1. Soft ambient drop shadow
    final shadowColor = Colors.black.withValues(
      alpha: isActive ? 0.28 : (isOuterRing ? 0.20 : 0.14),
    );
    canvas.drawPath(
      pillPath,
      Paint()
        ..color = shadowColor
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          isActive ? 4.5 : (isOuterRing ? 3.0 : 2.0),
        ),
    );

    // 2. Base sector fill - 100% VIBRANT SOLID (Zero Dimming!)
    final fillAlpha = isActive || isSelected
        ? 1.0
        : (isOuterRing ? 0.96 : 0.92);
    final fillPaint = Paint()
      ..color = event.color.withValues(alpha: fillAlpha)
      ..style = PaintingStyle.fill;
    canvas.drawPath(pillPath, fillPaint);

    // 3. Active pulse aura & highlight border
    if (isActive) {
      final pulseAlpha = (0.35 + 0.30 * math.sin(pulseValue * math.pi)).clamp(
        0.0,
        1.0,
      );
      final activeBorderPaint = Paint()
        ..color = Colors.white.withValues(alpha: pulseAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawPath(pillPath, activeBorderPaint);
    } else if (isSelected) {
      final selectBorderPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.90)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2;
      canvas.drawPath(pillPath, selectBorderPaint);
    }
  }

  /// Draws an integrated end-cap or start-cap badge inside the sector pill.
  ///
  /// The badge is rendered as a seamless part of the sector pill with a darker
  /// shaded tone, a subtle separator hairline, and high-contrast bold white
  /// boundary timestamp text.
  static void drawIntegratedCap({
    required Canvas canvas,
    required Offset center,
    required double rIn,
    required double rOut,
    required double startDeg,
    required double sweepDeg,
    required DateTime time,
    required Color eventColor,
    required bool isStartCap,
    required bool is24HourMode,
    double cornerRadius = 6.0,
    bool roundStart = false,
    bool roundEnd = true,
  }) {
    if (sweepDeg <= 0.5) return;

    final capPath = buildPillPath(
      center: center,
      rIn: rIn,
      rOut: rOut,
      startDeg: startDeg,
      sweepDeg: sweepDeg,
      cornerRadius: cornerRadius,
      roundStart: roundStart,
      roundEnd: roundEnd,
    );

    // 1. Sleek shaded overlay for the badge background
    final badgeOverlayColor = Color.lerp(eventColor, Colors.black, 0.35)!;
    canvas.drawPath(
      capPath,
      Paint()
        ..color = badgeOverlayColor
        ..style = PaintingStyle.fill,
    );

    // 2. Subtle separator hairline at the junction with the main pill body
    final sepDeg = isStartCap ? startDeg + sweepDeg : startDeg;
    final sepRad = SectorMath.dialAngleToCanvasRadians(sepDeg);
    canvas.drawLine(
      Offset(
        center.dx + (rIn + 1.0) * math.cos(sepRad),
        center.dy + (rIn + 1.0) * math.sin(sepRad),
      ),
      Offset(
        center.dx + (rOut - 1.0) * math.cos(sepRad),
        center.dy + (rOut - 1.0) * math.sin(sepRad),
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.28)
        ..strokeWidth = 1.0,
    );

    // 3. Boundary timestamp text in crisp bold white
    final timeStr = TimeFormatters.formatTime(time, is24Hour: is24HourMode);
    final midAngleDeg = startDeg + (sweepDeg / 2.0);
    final midRad = SectorMath.dialAngleToCanvasRadians(midAngleDeg);
    final midR = (rIn + rOut) / 2.0;

    final textCenter = Offset(
      center.dx + midR * math.cos(midRad),
      center.dy + midR * math.sin(midRad),
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: timeStr,
        style: const TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          color: Color(0xFFFFFFFF),
          letterSpacing: 0.2,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    canvas.save();
    canvas.clipPath(capPath);
    canvas.translate(textCenter.dx, textCenter.dy);

    var rotation = midRad;
    if (math.cos(midRad) < -0.05) {
      rotation += math.pi;
    }
    canvas.rotate(rotation);

    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2.0, -textPainter.height / 2.0),
    );
    canvas.restore();
  }
}
