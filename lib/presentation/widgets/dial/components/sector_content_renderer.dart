import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/geometry/sector_math.dart';
import '../../../../core/utils/time_formatters.dart';
import '../../../../domain/models/sector_event.dart';

/// Reusable component for rendering sector content (icon, title words stacked vertically,
/// duration, and short-keyword subtask chips) with casual handwritten Kalam typography,
/// strict polar boundary containment, and auto-alignment so text NEVER touches edges or caps.
class SectorContentRenderer {
  const SectorContentRenderer._();

  static const String fontKalam = 'Kalam';
  static const List<String> fontFallbacks = [
    'Patrick Hand',
    'Caveat',
    'sans-serif',
  ];

  /// Distills a verbose task or title string into a punchy, short keyword (1-2 words, max 11 chars)
  /// so it fits cleanly in circular dial sectors without overflow or touching boundaries.
  static String distillShortKeyword(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return '';

    final lower = clean.toLowerCase();
    if (lower.contains('linear algebra') || lower.contains('linalg')) {
      return 'LinAlg';
    }
    if (lower.contains('pytorch')) return 'PyTorch';
    if (lower.contains('transformer')) return 'Transformers';
    if (lower.contains('backprop')) return 'Backprop';
    if (lower.contains('data pipeline') || lower.contains('data prep')) {
      return 'Data Prep';
    }
    if (lower.contains('lora') || lower.contains('fine-tune')) {
      return 'LoRA Tune';
    }
    if (lower.contains('eval') || lower.contains('loss')) return 'Loss & Eval';
    if (lower.contains('leetcode')) return 'LeetCode';
    if (lower.contains('cooking') || lower.contains('lunch')) return 'Lunch';
    if (lower.contains('workout')) return 'Workout';
    if (lower.contains('flexible')) return 'Flex';
    if (lower.contains('study')) return 'Study';
    if (lower.contains('chill')) return 'Chill';

    // General fallback: take first word or up to 10 chars
    final words = clean
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return clean;
    if (words.length == 1) {
      return words[0].length > 11 ? words[0].substring(0, 10) : words[0];
    }
    if (words[0].length + words[1].length < 11) {
      return '${words[0]} ${words[1]}';
    }
    return words[0];
  }

  /// Draws the sector content strictly clipped inside [pillPath] with full auto-alignment.
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
    if (effectiveSweepDeg < (is24HourMode ? 5.0 : 7.0)) return;

    final midDeg = effectiveStartDeg + (effectiveSweepDeg / 2.0);
    final midRad = SectorMath.dialAngleToCanvasRadians(midDeg);
    final midR = (rIn + rOut) / 2.0;
    final pos = Offset(
      center.dx + midR * math.cos(midRad),
      center.dy + midR * math.sin(midRad),
    );

    final trackThickness = rOut - rIn;

    // Adaptive contrast: high-contrast white on dark sectors, dark charcoal on light sectors
    final isDarkSector =
        ThemeData.estimateBrightnessForColor(event.color) == Brightness.dark;
    final textColor = isDarkSector
        ? const Color(0xFFF7F3EE)
        : const Color(0xFF1E1A16);

    final iconData = _getEventIcon(event);
    final iconFontSize = is24HourMode ? 11.5 : 12.5;
    final titleFontSize = is24HourMode ? 10.0 : 11.0;
    final metaFontSize = is24HourMode ? 8.0 : 9.0;

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

    // Micro / tight sectors: draw icon only (strictly inside boundary)
    if (effectiveSweepDeg < (is24HourMode ? 8.0 : 11.0)) {
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

    // Split or compact title words based on available sweep space
    final wordLines = _splitTitleWords(
      event.title,
      effectiveSweepDeg: effectiveSweepDeg,
    );

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
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
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
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    // Subtask short keyword chips (for wide blocks or active focus)
    final subtaskPainters = <TextPainter>[];
    if (event.subtasks.isNotEmpty && effectiveSweepDeg >= 26.0) {
      final subStyle = TextStyle(
        fontFamily: fontKalam,
        fontFamilyFallback: fontFallbacks,
        fontSize: metaFontSize * 0.88,
        fontWeight: FontWeight.w700,
        color: textColor.withValues(alpha: 0.92),
        letterSpacing: 0.1,
      );

      final displaySubtasks = event.subtasks
          .take(2)
          .map((s) => distillShortKeyword(s))
          .toList();

      for (final s in displaySubtasks) {
        subtaskPainters.add(
          TextPainter(
            text: TextSpan(text: s, style: subStyle),
            maxLines: 1,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
          )..layout(),
        );
      }
    }

    // Measure raw content dimensions
    const iconGap = 1.2;
    const lineGap = 0.8;
    const durGap = 1.2;
    const subtaskGap = 1.0;

    double contentWidth = iconPainter.width;
    for (final tp in titlePainters) {
      if (tp.width > contentWidth) contentWidth = tp.width;
    }
    if (metaPainter.width > contentWidth) contentWidth = metaPainter.width;
    for (final sp in subtaskPainters) {
      if (sp.width > contentWidth) contentWidth = sp.width;
    }

    double contentHeight = iconPainter.height + iconGap;
    for (int i = 0; i < titlePainters.length; i++) {
      contentHeight += titlePainters[i].height;
      if (i < titlePainters.length - 1) contentHeight += lineGap;
    }
    contentHeight += durGap + metaPainter.height;

    for (final sp in subtaskPainters) {
      contentHeight += subtaskGap + sp.height;
    }

    // --- TRUE POLAR BOUNDING BOX & NEVER-TOUCH AUDIT ---
    // In polar coordinates, circumference is strictly smaller at inner radius.
    // We compute available arc width at the innermost radial reach of the content box.
    final rMinContent = math.max(rIn + 8.0, midR - (contentHeight / 2.0));
    final availableInnerArc =
        rMinContent * (effectiveSweepDeg * math.pi / 180.0);

    // Guaranteed cap safety clearance (minimum 8dp buffer on both start & end cap sides)
    final hasCaps = startCapSpanDeg > 0.0 || endCapSpanDeg > 0.0;
    final capSafetyPadding = hasCaps ? 16.0 : 10.0;
    final maxAllowedWidth = math.max(
      12.0,
      availableInnerArc - capSafetyPadding,
    );

    // Guaranteed radial clearance (minimum 9dp buffer from inner & outer ring boundaries)
    final maxAllowedHeight = math.max(12.0, trackThickness - 18.0);

    // Adaptive scale to strictly fit inside both radial and angular bounds
    var scale = 1.0;
    if (contentWidth > maxAllowedWidth) {
      scale = math.min(scale, maxAllowedWidth / contentWidth);
    }
    if (contentHeight > maxAllowedHeight) {
      scale = math.min(scale, maxAllowedHeight / contentHeight);
    }
    // Safety clamp: ensure text scales down smoothly without vanishing
    scale = scale.clamp(0.35, 1.0);

    // CRITICAL: Clip to pillPath so no text can ever bleed into bezels or margins!
    canvas.save();
    canvas.clipPath(pillPath);
    canvas.translate(pos.dx, pos.dy);

    // Tangential arc alignment: rotates content along the curvature of the ring
    // Auto-flipped so text consistently faces inward toward the center hub
    var tangentAngle = midRad + (math.pi / 2.0);
    if (math.cos(tangentAngle) < 0.05) {
      tangentAngle += math.pi;
    }
    canvas.rotate(tangentAngle);

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

    // 3. Duration badge (centered)
    metaPainter.paint(canvas, Offset(-metaPainter.width / 2.0, curY));
    curY += metaPainter.height;

    // 4. Subtask short-keyword chips (if present)
    for (final sp in subtaskPainters) {
      curY += subtaskGap;
      sp.paint(canvas, Offset(-sp.width / 2.0, curY));
      curY += sp.height;
    }

    canvas.restore();
  }

  /// Splits event title into stacked lines, with smart single-keyword compaction
  /// for narrow sectors (< 22°) so text never crowds or collides with caps.
  static List<String> _splitTitleWords(
    String title, {
    required double effectiveSweepDeg,
  }) {
    final clean = title.trim();
    if (clean.isEmpty) return const [];

    // Narrow sector: compact into a single punchy keyword
    if (effectiveSweepDeg < 22.0) {
      return [distillShortKeyword(clean)];
    }

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
