import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/utils/color_contrast.dart';

/// Renders color-blind-safe tactile patterns over sector arcs (§7 Phase 7).
///
/// Enables users with deuteranopia, protanopia, tritanopia, or monochromacy
/// to reliably differentiate scheduled categories by textural geometry
/// rather than color hue alone.
class SectorPatternRenderer {
  const SectorPatternRenderer._();

  /// Draws an accessible geometric overlay pattern over [pillPath].
  static void drawPattern({
    required Canvas canvas,
    required Path pillPath,
    required Rect bounds,
    required String category,
    required Color sectorColor,
  }) {
    final isDark =
        ColorContrast.computeLuminance(sectorColor) < 0.35;
    final strokeColor = isDark
        ? Colors.white.withValues(alpha: 0.22)
        : Colors.black.withValues(alpha: 0.18);

    final patternPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    canvas.save();
    canvas.clipPath(pillPath);

    final catLower = category.toLowerCase().trim();

    if (catLower.contains('work') || catLower.contains('focus') || catLower.contains('deep')) {
      // Pattern 1: 45° Diagonal Hatching (///)
      _drawDiagonalStripes(canvas, bounds, patternPaint, step: 10.0, angleDeg: 45.0);
    } else if (catLower.contains('meet') || catLower.contains('call') || catLower.contains('sync')) {
      // Pattern 2: Cross-hatching (XXX)
      _drawCrossHatch(canvas, bounds, patternPaint, step: 12.0);
    } else if (catLower.contains('health') || catLower.contains('yoga') || catLower.contains('sport') || catLower.contains('gym')) {
      // Pattern 3: Polka dots / Stippling (:::)
      _drawDots(canvas, bounds, strokeColor, step: 12.0, radius: 1.5);
    } else if (catLower.contains('rest') || catLower.contains('sleep') || catLower.contains('break') || catLower.contains('nap')) {
      // Pattern 4: Horizontal lines (===)
      _drawHorizontalLines(canvas, bounds, patternPaint, step: 8.0);
    } else {
      // Pattern 5: -45° Diagonal Hatching (\\\) for other categories
      _drawDiagonalStripes(canvas, bounds, patternPaint, step: 12.0, angleDeg: -45.0);
    }

    canvas.restore();
  }

  static void _drawDiagonalStripes(
    Canvas canvas,
    Rect bounds,
    Paint paint, {
    required double step,
    required double angleDeg,
  }) {
    final double rad = angleDeg * math.pi / 180.0;
    final double cosA = math.cos(rad);
    final double sinA = math.sin(rad);

    final double diagonal = math.sqrt(bounds.width * bounds.width + bounds.height * bounds.height);
    final int lineCount = (diagonal * 2 / step).ceil();

    final center = bounds.center;

    for (int i = -lineCount; i <= lineCount; i++) {
      final double offset = i * step;
      // Perpendicular line points
      final p1 = Offset(
        center.dx + offset * cosA - diagonal * sinA,
        center.dy + offset * sinA + diagonal * cosA,
      );
      final p2 = Offset(
        center.dx + offset * cosA + diagonal * sinA,
        center.dy + offset * sinA - diagonal * cosA,
      );
      canvas.drawLine(p1, p2, paint);
    }
  }

  static void _drawCrossHatch(Canvas canvas, Rect bounds, Paint paint, {required double step}) {
    _drawDiagonalStripes(canvas, bounds, paint, step: step, angleDeg: 45.0);
    _drawDiagonalStripes(canvas, bounds, paint, step: step, angleDeg: -45.0);
  }

  static void _drawHorizontalLines(Canvas canvas, Rect bounds, Paint paint, {required double step}) {
    for (double y = bounds.top - step; y <= bounds.bottom + step; y += step) {
      canvas.drawLine(Offset(bounds.left - 10, y), Offset(bounds.right + 10, y), paint);
    }
  }

  static void _drawDots(
    Canvas canvas,
    Rect bounds,
    Color color, {
    required double step,
    required double radius,
  }) {
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (double x = bounds.left; x <= bounds.right; x += step) {
      for (double y = bounds.top; y <= bounds.bottom; y += step) {
        canvas.drawCircle(Offset(x, y), radius, dotPaint);
      }
    }
  }
}
