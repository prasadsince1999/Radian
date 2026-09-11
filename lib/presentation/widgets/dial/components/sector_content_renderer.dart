import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/geometry/sector_math.dart';
import '../../../../core/utils/time_formatters.dart';
import '../../../../domain/models/sector_event.dart';

/// Reusable component for rendering sector content (icon, title, duration, time range)
/// with strict geometric boundary containment, tangential arc alignment, and zero dimming.
class SectorContentRenderer {
  const SectorContentRenderer._();

  /// Draws the sector content strictly clipped inside [pillPath].
  static void drawContent({
    required Canvas canvas,
    required Offset center,
    required SectorEvent event,
    required Path pillPath,
    required double rIn,
    required double rOut,
    required double startDeg,
    required double sweepDeg,
    required bool is24HourMode,
    bool isOuterRing = true,
    double startCapSpanDeg = 0.0,
    double endCapSpanDeg = 0.0,
  }) {
    final effectiveStartDeg = startDeg + startCapSpanDeg;
    final effectiveSweepDeg = sweepDeg - startCapSpanDeg - endCapSpanDeg;

    // Skip content on hairline / micro sectors
    if (effectiveSweepDeg < (is24HourMode ? 5.0 : 8.0)) return;

    final midDeg = effectiveStartDeg + (effectiveSweepDeg / 2.0);
    final midRad = SectorMath.dialAngleToCanvasRadians(midDeg);
    final midR = (rIn + rOut) / 2.0;
    final pos = Offset(
      center.dx + midR * math.cos(midRad),
      center.dy + midR * math.sin(midRad),
    );

    final trackThickness = rOut - rIn;
    final arcLength = midR * (effectiveSweepDeg * math.pi / 180.0);

    // Adaptive contrast: high-contrast white on dark sectors, dark charcoal on light sectors
    final isDarkSector =
        ThemeData.estimateBrightnessForColor(event.color) == Brightness.dark;
    final textColor = isDarkSector
        ? const Color(0xFFF7F3EE)
        : const Color(0xFF1E1A16);

    final iconData = _getEventIcon(event);
    final iconFontSize = isOuterRing
        ? (is24HourMode ? 12.0 : 13.5)
        : (is24HourMode ? 10.5 : 11.5);
    final titleFontSize = isOuterRing
        ? (is24HourMode ? 9.5 : 10.5)
        : (is24HourMode ? 8.5 : 9.5);
    final metaFontSize = isOuterRing
        ? (is24HourMode ? 7.5 : 8.5)
        : (is24HourMode ? 7.0 : 7.5);

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

    // Narrow sectors: draw icon only (strictly inside boundary)
    if (arcLength < 32.0 || sweepDeg < (is24HourMode ? 9.0 : 14.0)) {
      canvas.save();
      canvas.clipPath(pillPath);
      iconPainter.paint(
        canvas,
        Offset(
          pos.dx - iconPainter.width / 2.0,
          pos.dy - iconPainter.height / 2.0,
        ),
      );
      canvas.restore();
      return;
    }

    // Build subtitle / meta text: show duration ONLY (hours/minutes), no redundant time range
    final durationStr = TimeFormatters.formatDuration(event.duration);
    final metaStr = durationStr;

    final maxTextWidth = math.max(arcLength - 16.0, 36.0);
    final titlePainter = TextPainter(
      text: TextSpan(
        text: event.title.trim(),
        style: TextStyle(
          fontSize: titleFontSize,
          fontWeight: FontWeight.w900,
          color: textColor,
          letterSpacing: 0.1,
          height: 1.1,
        ),
      ),
      maxLines: 1,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: maxTextWidth);

    final metaPainter = TextPainter(
      text: TextSpan(
        text: metaStr,
        style: TextStyle(
          fontSize: metaFontSize,
          fontWeight: FontWeight.w700,
          color: textColor.withValues(alpha: 0.90),
          letterSpacing: 0.1,
        ),
      ),
      maxLines: 1,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: maxTextWidth);

    // CRITICAL: Clip to pillPath so no text can ever bleed into bezels or margins!
    canvas.save();
    canvas.clipPath(pillPath);
    canvas.translate(pos.dx, pos.dy);

    // Tangential arc alignment: rotates content along the curvature of the ring
    // Auto-flipped so text is always right-side up for the user
    var tangentAngle = midRad + (math.pi / 2.0);
    // If text would be upside down (pointing leftwards), flip by 180°
    if (math.cos(tangentAngle) < -0.1) {
      tangentAngle += math.pi;
    }
    canvas.rotate(tangentAngle);

    final contentWidth = math.max(
      iconPainter.width + 4.0 + titlePainter.width,
      metaPainter.width,
    );
    const gap = 1.5;
    final contentHeight =
        math.max(iconPainter.height, titlePainter.height) +
        gap +
        metaPainter.height;

    // Adaptive scale to guarantee snug fit within arc & thickness
    final maxAllowedWidth = arcLength - 12.0;
    final maxAllowedHeight = trackThickness - 6.0;

    var scale = 1.0;
    if (contentWidth > maxAllowedWidth) {
      scale = math.min(scale, maxAllowedWidth / contentWidth);
    }
    if (contentHeight > maxAllowedHeight) {
      scale = math.min(scale, maxAllowedHeight / contentHeight);
    }
    scale = scale.clamp(0.65, 1.0);

    if (scale < 1.0) {
      canvas.scale(scale, scale);
    }

    final topRowW = iconPainter.width + 4.0 + titlePainter.width;
    final topRowStartX = -topRowW / 2.0;
    final topRowY = -contentHeight / 2.0;

    // Line 1: [Icon] Title
    iconPainter.paint(
      canvas,
      Offset(
        topRowStartX,
        topRowY + (titlePainter.height - iconPainter.height) / 2.0,
      ),
    );
    titlePainter.paint(
      canvas,
      Offset(topRowStartX + iconPainter.width + 4.0, topRowY),
    );

    // Line 2: Duration • Range
    final metaY =
        topRowY + math.max(iconPainter.height, titlePainter.height) + gap;
    metaPainter.paint(canvas, Offset(-metaPainter.width / 2.0, metaY));

    canvas.restore();
  }

  static IconData _getEventIcon(SectorEvent event) {
    if (event.iconName != null) return event.iconData;
    final title = event.title.toLowerCase();
    if (title.contains('cook') ||
        title.contains('dinner') ||
        title.contains('lunch') ||
        title.contains('eat') ||
        title.contains('meal')) {
      return Icons.restaurant_rounded;
    }
    if (title.contains('code') ||
        title.contains('work') ||
        title.contains('study') ||
        title.contains('focus') ||
        title.contains('dev')) {
      return Icons.laptop_mac_rounded;
    }
    if (title.contains('sleep') ||
        title.contains('bed') ||
        title.contains('nap') ||
        title.contains('rest')) {
      return Icons.bedtime_rounded;
    }
    if (title.contains('gym') ||
        title.contains('workout') ||
        title.contains('fitness') ||
        title.contains('run') ||
        title.contains('walk')) {
      return Icons.fitness_center_rounded;
    }
    return Icons.schedule_rounded;
  }
}
