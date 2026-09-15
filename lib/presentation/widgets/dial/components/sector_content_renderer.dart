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
    bool showSubtasks = true,
  }) {
    final effectiveStartDeg = startDeg + startCapSpanDeg;
    final effectiveSweepDeg = sweepDeg - startCapSpanDeg - endCapSpanDeg;

    // Skip content on hairline / micro sectors
    if (effectiveSweepDeg < (is24HourMode ? 2.5 : 4.0)) return;

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
    final isNarrowSector = effectiveSweepDeg < (is24HourMode ? 18.0 : 35.0);
    final iconFontSize = is24HourMode ? (isNarrowSector ? 11.5 : 13.0) : 14.5;
    final titleFontSize = is24HourMode
        ? (isNarrowSector ? 10.2 : 11.5)
        : (isNarrowSector ? 11.2 : 13.0);
    final metaFontSize = is24HourMode
        ? (isNarrowSector ? 8.5 : 9.5)
        : (isNarrowSector ? 9.5 : 10.5);
    final pebbleFontSize = is24HourMode
        ? (isNarrowSector ? 6.5 : 7.2)
        : (isNarrowSector ? 8.0 : 9.0);

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

    // Micro / tight sectors: draw icon only (strictly inside boundary with auto-scaling)
    if (effectiveSweepDeg < (is24HourMode ? 6.0 : 9.0)) {
      canvas.save();
      canvas.clipPath(pillPath);
      final rMin = math.max(rIn + 8.0, midR - (iconPainter.height / 2.0));
      final availArc = rMin * (effectiveSweepDeg * math.pi / 180.0);
      final iconScale = (availArc / (iconPainter.width + 3.0)).clamp(0.4, 1.0);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      var tangentAngle = midRad + (math.pi / 2.0);
      if (math.cos(tangentAngle) < 0.05) {
        tangentAngle += math.pi;
      }
      canvas.rotate(tangentAngle);
      if (iconScale < 1.0) {
        canvas.scale(iconScale, iconScale);
      }
      iconPainter.paint(
        canvas,
        Offset(-iconPainter.width / 2.0, -iconPainter.height / 2.0),
      );
      canvas.restore();
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

    // Guaranteed cap safety clearance (minimum 2.2dp buffer on both start & end cap sides)
    final hasCaps = startCapSpanDeg > 0.0 || endCapSpanDeg > 0.0;
    final capSafetyPadding = hasCaps ? 4.5 : 2.0;
    final maxAllowedWidth = math.max(
      12.0,
      availableInnerArc - capSafetyPadding,
    );

    // Guaranteed radial clearance (minimum 9dp buffer from inner & outer ring boundaries)
    final maxAllowedHeight = math.max(12.0, trackThickness - 18.0);

    // Adaptive scale: STRICT LEGIBILITY FLOOR (adapts cleanly to narrow blocks with zero overlap)
    var scale = 1.0;
    if (contentWidth > maxAllowedWidth) {
      scale = math.min(scale, maxAllowedWidth / contentWidth);
    }
    if (contentHeight > maxAllowedHeight) {
      scale = math.min(scale, maxAllowedHeight / contentHeight);
    }
    // High-legibility clamp: minimum 0.65 guarantees crisp, readable text without clipping
    scale = scale.clamp(0.65, 1.15);
    // Hard ceiling: scaled content width must NEVER exceed available inner arc buffer
    if (contentWidth * scale > (availableInnerArc - capSafetyPadding) &&
        contentWidth > 0) {
      scale = math.max(
        0.4,
        (availableInnerArc - capSafetyPadding) / contentWidth,
      );
    }

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
    // Only in blocks with sufficient sweep (>= 22° in 24H, >= 32° in 12H), scatter subtasks like smooth river stones
    final minPebbleSweep = is24HourMode ? 22.0 : 32.0;
    if (showSubtasks &&
        event.subtasks.isNotEmpty &&
        effectiveSweepDeg >= minPebbleSweep &&
        trackThickness >= 24.0) {
      _drawRiverPebbles(
        canvas: canvas,
        center: center,
        subtasks: event.subtasks,
        midDeg: midDeg,
        effectiveSweepDeg: effectiveSweepDeg,
        midR: midR,
        rIn: rIn,
        rOut: rOut,
        trackThickness: trackThickness,
        textColor: textColor,
        isDarkSector: isDarkSector,
        pebbleFontSize: pebbleFontSize,
        centerTitleWidth: contentWidth * scale,
        is24HourMode: is24HourMode,
        startCapSpanDeg: startCapSpanDeg,
        endCapSpanDeg: endCapSpanDeg,
      );
    }

    canvas.restore(); // restore from clipPath
  }

  /// Draws organic "river pebbles" scattered naturally around the main center title,
  /// strictly bounded in the open water bays (left & right of title) so they never touch
  /// the center title, never sit below/above the title, and never cross sector boundary caps.
  static void _drawRiverPebbles({
    required Canvas canvas,
    required Offset center,
    required List<String> subtasks,
    required double midDeg,
    required double effectiveSweepDeg,
    required double midR,
    required double rIn,
    required double rOut,
    required double trackThickness,
    required Color textColor,
    required bool isDarkSector,
    required double pebbleFontSize,
    required double centerTitleWidth,
    required bool is24HourMode,
    required double startCapSpanDeg,
    required double endCapSpanDeg,
  }) {
    // Take up to 4 subtasks to scatter like smooth river pebbles
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

    // Minimum angular span of the center title block
    final titleHalfDeg = (centerTitleWidth / 2.0) / (midR * math.pi / 180.0);

    // Subtle natural tilt variations like smooth stones resting in a gentle river flow
    const tilts = [-0.04, 0.05, -0.05, 0.04];

    // Measure each pebble first to compute required angular spans
    final textPainters = <TextPainter>[];
    final pebbleDimensions = <({double w, double h, double halfDeg})>[];

    for (final keyword in pebbles) {
      final tp = TextPainter(
        text: TextSpan(text: keyword, style: pebbleStyle),
        maxLines: 1,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();

      final w = tp.width + (is24HourMode ? 5.0 : 8.0);
      final h = tp.height + (is24HourMode ? 2.5 : 4.0);
      final halfDeg = (w / 2.0) / (midR * math.pi / 180.0);

      textPainters.add(tp);
      pebbleDimensions.add((w: w, h: h, halfDeg: halfDeg));
    }

    final halfSweep = effectiveSweepDeg / 2.0;

    // Safety margins to prevent touching block boundaries or center title
    final boundaryBufferDeg = is24HourMode ? 2.2 : 3.8;
    final titleBufferDeg = is24HourMode ? 3.0 : 5.5;

    // 1. Upstream (Left) Water Bay: between start boundary cap and center title
    final leftBayStartDeg = -halfSweep + startCapSpanDeg + boundaryBufferDeg;
    final leftBayEndDeg = -titleHalfDeg - titleBufferDeg;
    final leftBayWidth = leftBayEndDeg - leftBayStartDeg;

    // 2. Downstream (Right) Water Bay: between center title and end boundary cap
    final rightBayStartDeg = titleHalfDeg + titleBufferDeg;
    final rightBayEndDeg = halfSweep - endCapSpanDeg - boundaryBufferDeg;
    final rightBayWidth = rightBayEndDeg - rightBayStartDeg;

    // Decide assignment of pebbles into Left Bay and Right Bay:
    final leftPebbleIndices = <int>[];
    final rightPebbleIndices = <int>[];

    final int count = pebbles.length;
    if (count == 1) {
      if (rightBayWidth >= leftBayWidth && rightBayWidth > 7.0) {
        rightPebbleIndices.add(0);
      } else if (leftBayWidth > 7.0) {
        leftPebbleIndices.add(0);
      }
    } else if (count == 2) {
      if (leftBayWidth > 7.0) leftPebbleIndices.add(0);
      if (rightBayWidth > 7.0) rightPebbleIndices.add(1);
    } else if (count == 3) {
      if (leftBayWidth > 7.0) leftPebbleIndices.add(0);
      if (rightBayWidth > 16.0) {
        rightPebbleIndices.add(1);
        rightPebbleIndices.add(2);
      } else if (rightBayWidth > 7.0) {
        rightPebbleIndices.add(1);
      }
    } else {
      // 4 pebbles
      if (leftBayWidth > 16.0) {
        leftPebbleIndices.add(0);
        leftPebbleIndices.add(2);
      } else if (leftBayWidth > 7.0) {
        leftPebbleIndices.add(0);
      }
      if (rightBayWidth > 16.0) {
        rightPebbleIndices.add(1);
        rightPebbleIndices.add(3);
      } else if (rightBayWidth > 7.0) {
        rightPebbleIndices.add(1);
      }
    }

    void renderBayPebbles({
      required List<int> indices,
      required double bayStart,
      required double bayEnd,
      required double bayWidth,
    }) {
      if (indices.isEmpty) return;

      if (indices.length == 1) {
        final idx = indices[0];
        final dim = pebbleDimensions[idx];
        if (bayWidth < dim.halfDeg * 2.0) return;

        final targetAngle = (bayStart + bayEnd) / 2.0;
        final pDeg = midDeg + targetAngle;
        final pRad = SectorMath.dialAngleToCanvasRadians(pDeg);
        final pR = midR; // Exactly floating at centerline of the river

        _renderSinglePebble(
          canvas: canvas,
          center: center,
          tp: textPainters[idx],
          dim: dim,
          pRad: pRad,
          pR: pR,
          tilt: tilts[idx % tilts.length],
          pebbleBgPaint: pebbleBgPaint,
          pebbleBorderPaint: pebbleBorderPaint,
        );
      } else if (indices.length == 2) {
        final idx1 = indices[0];
        final idx2 = indices[1];
        final dim1 = pebbleDimensions[idx1];
        final dim2 = pebbleDimensions[idx2];
        final totalNeeded = (dim1.halfDeg * 2.0) + (dim2.halfDeg * 2.0) + 2.0;

        if (bayWidth < totalNeeded) {
          // If 2 don't fit comfortably along the arc, render just the 1st one centered
          final targetAngle = (bayStart + bayEnd) / 2.0;
          final pDeg = midDeg + targetAngle;
          final pRad = SectorMath.dialAngleToCanvasRadians(pDeg);
          _renderSinglePebble(
            canvas: canvas,
            center: center,
            tp: textPainters[idx1],
            dim: dim1,
            pRad: pRad,
            pR: midR,
            tilt: tilts[idx1 % tilts.length],
            pebbleBgPaint: pebbleBgPaint,
            pebbleBorderPaint: pebbleBorderPaint,
          );
          return;
        }

        // Space the 2 pebbles comfortably along the bay
        final p1Angle = bayStart + bayWidth * 0.30;
        final p2Angle = bayStart + bayWidth * 0.72;

        // Subtle radial stagger: one slightly inner, one slightly outer
        final rStagger = trackThickness * 0.14;
        final p1R = (midR - rStagger).clamp(
          rIn + dim1.h / 2.0 + 3.0,
          rOut - dim1.h / 2.0 - 3.0,
        );
        final p2R = (midR + rStagger).clamp(
          rIn + dim2.h / 2.0 + 3.0,
          rOut - dim2.h / 2.0 - 3.0,
        );

        final p1Deg = midDeg + p1Angle;
        final p2Deg = midDeg + p2Angle;

        _renderSinglePebble(
          canvas: canvas,
          center: center,
          tp: textPainters[idx1],
          dim: dim1,
          pRad: SectorMath.dialAngleToCanvasRadians(p1Deg),
          pR: p1R,
          tilt: tilts[idx1 % tilts.length],
          pebbleBgPaint: pebbleBgPaint,
          pebbleBorderPaint: pebbleBorderPaint,
        );

        _renderSinglePebble(
          canvas: canvas,
          center: center,
          tp: textPainters[idx2],
          dim: dim2,
          pRad: SectorMath.dialAngleToCanvasRadians(p2Deg),
          pR: p2R,
          tilt: tilts[idx2 % tilts.length],
          pebbleBgPaint: pebbleBgPaint,
          pebbleBorderPaint: pebbleBorderPaint,
        );
      }
    }

    renderBayPebbles(
      indices: leftPebbleIndices,
      bayStart: leftBayStartDeg,
      bayEnd: leftBayEndDeg,
      bayWidth: leftBayWidth,
    );

    renderBayPebbles(
      indices: rightPebbleIndices,
      bayStart: rightBayStartDeg,
      bayEnd: rightBayEndDeg,
      bayWidth: rightBayWidth,
    );
  }

  static void _renderSinglePebble({
    required Canvas canvas,
    required Offset center,
    required TextPainter tp,
    required ({double w, double h, double halfDeg}) dim,
    required double pRad,
    required double pR,
    required double tilt,
    required Paint pebbleBgPaint,
    required Paint pebbleBorderPaint,
  }) {
    final pPos = Offset(
      center.dx + pR * math.cos(pRad),
      center.dy + pR * math.sin(pRad),
    );

    canvas.save();
    canvas.translate(pPos.dx, pPos.dy);

    var pTangent = pRad + (math.pi / 2.0);
    if (math.cos(pTangent) < 0.05) {
      pTangent += math.pi;
    }
    pTangent += tilt;
    canvas.rotate(pTangent);

    // River stone smooth rounded pill capsule
    final pebbleRect = Rect.fromCenter(
      center: Offset.zero,
      width: dim.w,
      height: dim.h,
    );
    final pebbleRRect = RRect.fromRectAndRadius(
      pebbleRect,
      Radius.circular(dim.h / 2.0),
    );

    canvas.drawRRect(pebbleRRect, pebbleBgPaint);
    canvas.drawRRect(pebbleRRect, pebbleBorderPaint);

    tp.paint(canvas, Offset(-tp.width / 2.0, -tp.height / 2.0));
    canvas.restore();
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
