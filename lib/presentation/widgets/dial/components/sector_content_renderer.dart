import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/geometry/sector_math.dart';
import '../../../../core/utils/time_formatters.dart';
import '../../../../domain/models/sector_event.dart';

/// Reusable component for rendering sector content (icon, title words stacked vertically,
/// and duration) with casual handwritten Kalam typography, strict geometric boundary
/// containment, and tangential arc alignment.
class SectorContentRenderer {
  const SectorContentRenderer._();

  static const String fontKalam = 'Kalam';
  static const List<String> fontFallbacks = [
    'Patrick Hand',
    'Caveat',
    'sans-serif',
  ];

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
        : (is24HourMode ? 9.5 : 11.0);
    final titleFontSize = isOuterRing
        ? (is24HourMode ? 10.5 : 12.0)
        : (is24HourMode ? 8.5 : 10.0);
    final metaFontSize = isOuterRing
        ? (is24HourMode ? 8.5 : 9.5)
        : (is24HourMode ? 7.5 : 8.5);

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

    // Split title into words stacked vertically ("words one below one")
    final wordLines = _splitTitleWords(event.title);

    final maxTextWidth = math.max(arcLength - 12.0, 32.0);
    final titleStyle = TextStyle(
      fontFamily: fontKalam,
      fontFamilyFallback: fontFallbacks,
      fontSize: titleFontSize,
      fontWeight: FontWeight.w700,
      color: textColor,
      letterSpacing: 0.1,
      height: 1.05,
    );

    final titlePainters = wordLines.map((line) {
      return TextPainter(
        text: TextSpan(text: line, style: titleStyle),
        maxLines: 1,
        ellipsis: '…',
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: maxTextWidth);
    }).toList();

    // Duration only (hours/minutes e.g. "3h", "1h 30m"), no redundant time range
    final durationStr = TimeFormatters.formatDuration(event.duration);
    final metaPainter = TextPainter(
      text: TextSpan(
        text: durationStr,
        style: TextStyle(
          fontFamily: fontKalam,
          fontFamilyFallback: fontFallbacks,
          fontSize: metaFontSize,
          fontWeight: FontWeight.w700,
          color: textColor.withValues(alpha: 0.88),
          letterSpacing: 0.1,
          height: 1.05,
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

    final iconGap = isOuterRing ? 2.0 : 1.2;
    final lineGap = isOuterRing ? 1.0 : 0.8;
    final durGap = isOuterRing ? 2.0 : 1.2;

    if (titlePainters.isEmpty) {
      final totalH = iconPainter.height + durGap + metaPainter.height;
      final maxW = math.max(iconPainter.width, metaPainter.width);
      var s = 1.0;
      if (maxW > arcLength - 10.0) s = math.min(s, (arcLength - 10.0) / maxW);
      if (totalH > trackThickness - 4.0) {
        s = math.min(s, (trackThickness - 4.0) / totalH);
      }
      s = s.clamp(0.55, 1.0);
      if (s < 1.0) canvas.scale(s, s);

      final startY = -totalH / 2.0;
      iconPainter.paint(canvas, Offset(-iconPainter.width / 2.0, startY));
      metaPainter.paint(
        canvas,
        Offset(-metaPainter.width / 2.0, startY + iconPainter.height + durGap),
      );
      canvas.restore();
      return;
    }

    double contentWidth = iconPainter.width;
    for (final tp in titlePainters) {
      if (tp.width > contentWidth) contentWidth = tp.width;
    }
    if (metaPainter.width > contentWidth) {
      contentWidth = metaPainter.width;
    }

    double contentHeight = iconPainter.height + iconGap;
    for (int i = 0; i < titlePainters.length; i++) {
      contentHeight += titlePainters[i].height;
      if (i < titlePainters.length - 1) {
        contentHeight += lineGap;
      }
    }
    contentHeight += durGap + metaPainter.height;

    // Adaptive scale to guarantee snug fit within arc & thickness
    final maxAllowedWidth = arcLength - 10.0;
    final maxAllowedHeight = trackThickness - 4.0;

    var scale = 1.0;
    if (contentWidth > maxAllowedWidth) {
      scale = math.min(scale, maxAllowedWidth / contentWidth);
    }
    if (contentHeight > maxAllowedHeight) {
      scale = math.min(scale, maxAllowedHeight / contentHeight);
    }
    scale = scale.clamp(0.55, 1.0);

    if (scale < 1.0) {
      canvas.scale(scale, scale);
    }

    var curY = -contentHeight / 2.0;

    // 1. Icon (top, centered)
    iconPainter.paint(canvas, Offset(-iconPainter.width / 2.0, curY));
    curY += iconPainter.height + iconGap;

    // 2. Title lines (words one below one, each centered)
    for (int i = 0; i < titlePainters.length; i++) {
      final tp = titlePainters[i];
      tp.paint(canvas, Offset(-tp.width / 2.0, curY));
      curY += tp.height + (i < titlePainters.length - 1 ? lineGap : durGap);
    }

    // 3. Duration badge (bottom, centered)
    metaPainter.paint(canvas, Offset(-metaPainter.width / 2.0, curY));

    canvas.restore();
  }

  /// Splits event title into stacked lines ("words one below one").
  static List<String> _splitTitleWords(String title) {
    final clean = title.trim();
    if (clean.isEmpty) return const [];
    if (clean.contains('\n')) {
      return clean
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }

    // Split on whitespace or common symbols (+, /) to keep each word on its own line
    final normalized = clean.replaceAll('+', ' ').replaceAll('/', ' ');
    final rawWords = normalized
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    if (rawWords.length <= 3) {
      return rawWords;
    }

    // For longer titles (4+ words, e.g. "Workout or Chill Time"), pack into 2 balanced lines
    if (rawWords.length == 4) {
      return ['${rawWords[0]} ${rawWords[1]}', '${rawWords[2]} ${rawWords[3]}'];
    }

    final half = (rawWords.length / 2).ceil();
    return [rawWords.take(half).join(' '), rawWords.skip(half).join(' ')];
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
