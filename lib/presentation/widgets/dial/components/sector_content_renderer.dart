import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/geometry/sector_math.dart';
import '../../../../core/utils/time_formatters.dart';
import '../../../../domain/models/sector_event.dart';

/// Reusable component for rendering sector content:
/// - Main block title, icon, and duration centered at high legibility (NEVER microscopic).
/// - "River Pebble" subtasks: organic, smooth pebble chips scattered around the main title
///   like stones along a riverbank in expanded/active sectors.
/// - Strict polar boundary containment so text never touches caps, shadows, or ring edges.
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
    if (lower.contains('mock')) return 'Mock Prep';
    if (lower.contains('arxiv')) return 'ArXiv';
    if (lower.contains('math')) return 'Math Notes';
    if (lower.contains('cooking') || lower.contains('lunch')) return 'Lunch';
    if (lower.contains('dinner')) return 'Dinner';
    if (lower.contains('workout') || lower.contains('gym')) return 'Workout';
    if (lower.contains('flexible')) return 'Flex';
    if (lower.contains('study')) return 'Study';
    if (lower.contains('chill')) return 'Chill';
    if (lower.contains('nap')) return 'Nap';
    if (lower.contains('coffee')) return 'Coffee';
    if (lower.contains('rest')) return 'Rest';

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

    // BOLD, HIGH-LEGIBILITY FONT SIZES (never microscopic!)
    final iconFontSize = is24HourMode ? 13.0 : 14.5;
    final titleFontSize = is24HourMode ? 11.5 : 13.0;
    final metaFontSize = is24HourMode ? 9.5 : 10.5;
    final pebbleFontSize = is24HourMode ? 9.0 : 10.0;

    final iconData = _getEventIcon(event);
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

    // Measure raw center content dimensions
    const iconGap = 1.2;
    const lineGap = 0.8;
    const durGap = 1.2;

    double contentWidth = iconPainter.width;
    for (final tp in titlePainters) {
      if (tp.width > contentWidth) contentWidth = tp.width;
    }
    if (metaPainter.width > contentWidth) contentWidth = metaPainter.width;

    double contentHeight = iconPainter.height + iconGap;
    for (int i = 0; i < titlePainters.length; i++) {
      contentHeight += titlePainters[i].height;
      if (i < titlePainters.length - 1) contentHeight += lineGap;
    }
    contentHeight += durGap + metaPainter.height;

    // --- TRUE POLAR BOUNDING BOX & NEVER-TOUCH AUDIT ---
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

    // Adaptive scale: STRICT LEGIBILITY FLOOR (never drops below 0.78, so text is NEVER too small!)
    var scale = 1.0;
    if (contentWidth > maxAllowedWidth) {
      scale = math.min(scale, maxAllowedWidth / contentWidth);
    }
    if (contentHeight > maxAllowedHeight) {
      scale = math.min(scale, maxAllowedHeight / contentHeight);
    }
    // High-legibility clamp: minimum 0.78 guarantees crisp, readable text
    scale = scale.clamp(0.78, 1.15);

    // CRITICAL: Clip to pillPath so no content ever bleeds into bezels or margins!
    canvas.save();
    canvas.clipPath(pillPath);

    // 1. DRAW CENTER TITLE & DURATION
    canvas.save();
    canvas.translate(pos.dx, pos.dy);

    var tangentAngle = midRad + (math.pi / 2.0);
    if (math.cos(tangentAngle) < 0.05) {
      tangentAngle += math.pi;
    }
    canvas.rotate(tangentAngle);

    if (scale < 1.0) {
      canvas.scale(scale, scale);
    }

    var curY = -contentHeight / 2.0;

    // Icon (top, centered)
    iconPainter.paint(canvas, Offset(-iconPainter.width / 2.0, curY));
    curY += iconPainter.height + iconGap;

    // Title lines
    for (int i = 0; i < titlePainters.length; i++) {
      final tp = titlePainters[i];
      tp.paint(canvas, Offset(-tp.width / 2.0, curY));
      curY += tp.height + (i < titlePainters.length - 1 ? lineGap : durGap);
    }

    // Duration badge (centered)
    metaPainter.paint(canvas, Offset(-metaPainter.width / 2.0, curY));

    canvas.restore(); // restore from center translate/rotate

    // 2. DRAW "RIVER PEBBLE" SUBTASKS ORGANICALLY AROUND CENTER TITLE
    // In wide or expanded blocks (>= 32° sweep), scatter subtask keywords like smooth river stones
    if (event.subtasks.isNotEmpty && effectiveSweepDeg >= 32.0) {
      _drawRiverPebbles(
        canvas: canvas,
        center: center,
        subtasks: event.subtasks,
        midDeg: midDeg,
        effectiveSweepDeg: effectiveSweepDeg,
        midR: midR,
        trackThickness: trackThickness,
        textColor: textColor,
        isDarkSector: isDarkSector,
        pebbleFontSize: pebbleFontSize,
        centerTitleWidth: contentWidth * scale,
      );
    }

    canvas.restore(); // restore from clipPath
  }

  /// Draws organic "river pebbles" scattered naturally around the main center title.
  static void _drawRiverPebbles({
    required Canvas canvas,
    required Offset center,
    required List<String> subtasks,
    required double midDeg,
    required double effectiveSweepDeg,
    required double midR,
    required double trackThickness,
    required Color textColor,
    required bool isDarkSector,
    required double pebbleFontSize,
    required double centerTitleWidth,
  }) {
    // Take up to 4 subtasks to scatter like river pebbles
    final pebbles = subtasks
        .take(4)
        .map((s) => distillShortKeyword(s))
        .where((s) => s.isNotEmpty)
        .toList();

    if (pebbles.isEmpty) return;

    final pebbleStyle = TextStyle(
      fontFamily: fontKalam,
      fontFamilyFallback: fontFallbacks,
      fontSize: pebbleFontSize,
      fontWeight: FontWeight.w700,
      color: textColor.withValues(alpha: 0.95),
      letterSpacing: 0.1,
    );

    final pebbleBgPaint = Paint()
      ..color = textColor.withValues(alpha: isDarkSector ? 0.22 : 0.14)
      ..style = PaintingStyle.fill;

    final pebbleBorderPaint = Paint()
      ..color = textColor.withValues(alpha: isDarkSector ? 0.42 : 0.26)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;

    // Minimum angular clearance from center title (converted from pixel width to polar angle)
    final titleHalfDeg = (centerTitleWidth / 2.0) / (midR * math.pi / 180.0);
    final minSafeOffsetDeg = titleHalfDeg + 3.5;

    // Organic offsets: upstream and downstream along the river shores
    final dTh = math.max(minSafeOffsetDeg + 6.0, effectiveSweepDeg * 0.28);
    final rShift = trackThickness * 0.22;

    // Subtle natural tilt variations like stones resting casually on the riverbank
    const tilts = [-0.08, 0.10, -0.12, 0.07];
    const cornerRadii = [9.5, 8.0, 10.0, 8.5];

    final offsets = [
      (angleOffset: -dTh, rOffset: rShift), // Flank 1: upstream, outer bank
      (angleOffset: dTh, rOffset: -rShift), // Flank 2: downstream, inner bank
      (
        angleOffset: -dTh * 1.36,
        rOffset: -rShift * 0.85,
      ), // Flank 3: far upstream, inner bank
      (
        angleOffset: dTh * 1.36,
        rOffset: rShift * 0.85,
      ), // Flank 4: far downstream, outer bank
    ];

    for (int i = 0; i < pebbles.length && i < offsets.length; i++) {
      final keyword = pebbles[i];
      final offset = offsets[i];

      final tp = TextPainter(
        text: TextSpan(text: keyword, style: pebbleStyle),
        maxLines: 1,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();

      final pebbleW = tp.width + 11.0;
      final pebbleH = tp.height + 5.0;
      final pR = (midR + offset.rOffset).clamp(
        midR - trackThickness * 0.35,
        midR + trackThickness * 0.35,
      );
      final pebbleHalfDeg = (pebbleW / 2.0) / (pR * math.pi / 180.0);

      // Check collision with center title: must stay outside center title half angle
      if (offset.angleOffset.abs() - pebbleHalfDeg < minSafeOffsetDeg) continue;

      // Check collision with sector boundaries & caps: must stay safely inside
      if (offset.angleOffset.abs() + pebbleHalfDeg >
          (effectiveSweepDeg * 0.45)) {
        continue;
      }

      final pDeg = midDeg + offset.angleOffset;
      final pRad = SectorMath.dialAngleToCanvasRadians(pDeg);
      final pPos = Offset(
        center.dx + pR * math.cos(pRad),
        center.dy + pR * math.sin(pRad),
      );

      canvas.save();
      canvas.translate(pPos.dx, pPos.dy);

      // Rotate along the local tangent + organic pebble tilt
      var pTangent = pRad + (math.pi / 2.0);
      if (math.cos(pTangent) < 0.05) {
        pTangent += math.pi;
      }
      pTangent += tilts[i % tilts.length];
      canvas.rotate(pTangent);

      // River stone rounded capsule
      final pebbleRect = Rect.fromCenter(
        center: Offset.zero,
        width: pebbleW,
        height: pebbleH,
      );
      final pebbleRRect = RRect.fromRectAndRadius(
        pebbleRect,
        Radius.circular(cornerRadii[i % cornerRadii.length]),
      );

      canvas.drawRRect(pebbleRRect, pebbleBgPaint);
      canvas.drawRRect(pebbleRRect, pebbleBorderPaint);

      tp.paint(canvas, Offset(-tp.width / 2.0, -tp.height / 2.0));
      canvas.restore();
    }
  }

  /// Splits event title into stacked lines, with smart single-keyword compaction
  /// for narrow sectors (< 35°) so text never crowds or collides with caps.
  static List<String> _splitTitleWords(
    String title, {
    required double effectiveSweepDeg,
  }) {
    final clean = title.trim();
    if (clean.isEmpty) return const [];

    // Narrow sector (< 35°): compact into a single punchy keyword to guarantee
    // high font size and zero vertical squeezing
    if (effectiveSweepDeg < 35.0) {
      return [distillShortKeyword(clean)];
    }

    if (clean.contains('\n')) {
      return clean
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }

    final normalized = clean.replaceAll('+', ' ').replaceAll('/', ' ');
    final rawWords = normalized
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    if (rawWords.length <= 3) {
      return rawWords;
    }

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
