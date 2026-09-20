import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_layout_constants.dart';
import '../../../../core/geometry/sector_math.dart';
import '../../../../core/utils/time_formatters.dart';
import '../../../../domain/models/sector_event.dart';
import 'sector_pill_renderer.dart';

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

  /// Distills a verbose task or title string into a punchy, single keyword (1 word, max 10 chars)
  /// so it fits cleanly in circular dial sectors without overflow or touching boundaries.
  static String distillShortKeyword(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return '';

    final lower = clean.toLowerCase();
    if (lower.contains('linear algebra') || lower.contains('linalg')) {
      return 'LinAlg';
    }
    if (lower.contains('transformer')) return 'Transformers';
    if (lower.contains('flexible')) return 'Flex';
    if (lower.contains('lunch')) return 'Lunch';
    if (lower.contains('nap')) return 'Nap';

    // Universal clean single-word extraction for arbitrary user titles
    final sanitized = clean.replaceAll(RegExp(r'[\+\-\:\|\(\)]+'), ' ').trim();
    final words = sanitized
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return clean;

    return words[0].length > 10 ? words[0].substring(0, 9) : words[0];
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

    // --- TRUE POLAR BOUNDING BOX & NEVER-TOUCH AUDIT ---
    final hasCaps = startCapSpanDeg > 0.0 || endCapSpanDeg > 0.0;
    final capSafetyPadding = hasCaps ? 4.5 : 2.0;
    final rMinEstimate = math.max(rIn + 8.0, midR - (trackThickness * 0.45));
    final availableInnerArc =
        rMinEstimate * (effectiveSweepDeg * math.pi / 180.0);
    final maxAllowedWidth = math.max(
      12.0,
      availableInnerArc - capSafetyPadding,
    );
    final maxAllowedHeight = math.max(12.0, trackThickness - 16.0);

    // FLUID ARC-BASED TYPOGRAPHY SIZING:
    // Size type from available arc length. When subtasks are present, keep title font size
    // harmoniously proportioned so open water bays have ample space for river pebble chips.
    final hasSubtasks = showSubtasks && event.subtasks.isNotEmpty;
    final dynamicTypeSize = hasSubtasks
        ? (availableInnerArc * 0.17).clamp(8.0, 11.5)
        : (availableInnerArc * 0.22).clamp(8.0, 13.5);
    final iconFontSize = (dynamicTypeSize * 1.15).clamp(10.0, 15.0);
    final titleFontSize = dynamicTypeSize;
    final metaFontSize = (dynamicTypeSize * 0.85).clamp(8.0, 11.0);
    final pebbleFontSize = hasSubtasks
        ? (dynamicTypeSize * 0.92).clamp(9.5, 12.5)
        : (dynamicTypeSize * 0.85).clamp(8.5, 11.0);

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

    final fullTitlePainters = wordLines.map((line) {
      return TextPainter(
        text: TextSpan(text: line, style: titleStyle),
        maxLines: 1,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
    }).toList();

    // Distilled keyword painter (1 punchy word or 2 short words, bold and clear)
    final keyword = distillShortKeyword(event.title);
    final keywordPainter = TextPainter(
      text: TextSpan(text: keyword, style: titleStyle),
      maxLines: 1,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    // Duration badge
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

    const iconGap = 1.2;
    const lineGap = 0.8;
    const durGap = 1.2;

    // --- PROGRESSIVE CONTENT ADAPTATION TIERS ---
    // Option A: Full Content (Icon + Title Lines + Duration)
    double widthA = iconPainter.width;
    for (final tp in fullTitlePainters) {
      if (tp.width > widthA) widthA = tp.width;
    }
    if (metaPainter.width > widthA) widthA = metaPainter.width;

    double heightA = iconPainter.height + iconGap;
    for (int i = 0; i < fullTitlePainters.length; i++) {
      heightA += fullTitlePainters[i].height;
      if (i < fullTitlePainters.length - 1) heightA += lineGap;
    }
    heightA += durGap + metaPainter.height;

    final scaleA = math.min(
      maxAllowedWidth / widthA,
      maxAllowedHeight / heightA,
    );

    // Option B: Compact Keyword (Icon + 1 Short Keyword Line, NO duration)
    // This allows the title to remain clean and legible without being squashed!
    final widthB = math.max(iconPainter.width, keywordPainter.width);
    final heightB = iconPainter.height + iconGap + keywordPainter.height;
    final scaleB = math.min(
      maxAllowedWidth / widthB,
      maxAllowedHeight / heightB,
    );

    // 3 Content Tiers:
    // Small sweep (< 14° in 24H, < 20° in 12H) or tight fit -> Tier 1: Icon only
    // Medium sweep (< 30° in 24H, < 45° in 12H) or moderate fit -> Tier 2: Icon + One Word
    // Large sweep (>= 30° in 24H, >= 45° in 12H) with comfortable scale -> Tier 3: Full Title + Duration
    final isLargeSector = effectiveSweepDeg >= (is24HourMode ? 28.0 : 42.0);
    final isMediumSector = effectiveSweepDeg >= (is24HourMode ? 14.0 : 20.0);

    final bool showFull = isLargeSector && scaleA >= 0.85;
    final bool showKeyword = !showFull && isMediumSector && scaleB >= 0.80;
    final bool showIconOnly = !showFull && !showKeyword;

    // Select which painters to draw based on adaptive tier
    List<TextPainter> titlePaintersToDraw;
    bool includeMeta;
    double finalContentWidth;
    double finalContentHeight;
    double scale;

    if (showFull) {
      titlePaintersToDraw = fullTitlePainters;
      includeMeta = true;
      finalContentWidth = widthA;
      finalContentHeight = heightA;
      scale = scaleA.clamp(0.85, 1.15);
    } else if (showKeyword) {
      titlePaintersToDraw = [keywordPainter];
      includeMeta = false;
      finalContentWidth = widthB;
      finalContentHeight = heightB;
      scale = scaleB.clamp(0.80, 1.15);
    } else {
      // Icon only
      titlePaintersToDraw = const [];
      includeMeta = false;
      finalContentWidth = iconPainter.width;
      finalContentHeight = iconPainter.height;
      scale = math
          .min(
            1.0,
            math.min(
              maxAllowedWidth / iconPainter.width,
              maxAllowedHeight / iconPainter.height,
            ),
          )
          .clamp(0.65, 1.15);
    }

    // Micro / hairline sectors: draw icon only (strictly inside boundary with auto-scaling)
    if (showIconOnly && effectiveSweepDeg < (is24HourMode ? 6.0 : 9.0)) {
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

    // CRITICAL: Double-lock clipping:
    // 1. pillPath: bounds content to inner/outer radial tracks and sector corner radii.
    // 2. contentClipPath: strictly limits content between start cap and end cap, ensuring
    //    zero bleed into timestamp caps under any circumstances!
    final contentClipPath = SectorPillRenderer.buildPillPath(
      center: center,
      rIn: rIn,
      rOut: rOut,
      startDeg: effectiveStartDeg,
      sweepDeg: effectiveSweepDeg,
      cornerRadius: 0.0,
      roundStart: false,
      roundEnd: false,
    );

    canvas.save();
    canvas.clipPath(pillPath);
    if (hasCaps) {
      canvas.clipPath(contentClipPath);
    }

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

    var curY = -finalContentHeight / 2.0;

    // Icon (top, centered)
    iconPainter.paint(canvas, Offset(-iconPainter.width / 2.0, curY));
    curY += iconPainter.height + iconGap;

    // Title lines
    for (int i = 0; i < titlePaintersToDraw.length; i++) {
      final tp = titlePaintersToDraw[i];
      tp.paint(canvas, Offset(-tp.width / 2.0, curY));
      curY +=
          tp.height + (i < titlePaintersToDraw.length - 1 ? lineGap : durGap);
    }

    // Duration badge (centered, only if includeMeta is true)
    if (includeMeta) {
      metaPainter.paint(canvas, Offset(-metaPainter.width / 2.0, curY));
    }

    canvas.restore(); // restore from center translate/rotate

    // 2. DRAW "RIVER PEBBLE" SUBTASKS ORGANICALLY AROUND CENTER TITLE
    // In blocks with sufficient sweep (>= minSubtaskPebbleSweep), scatter subtasks like smooth river stones
    final double minPebbleSweep = is24HourMode
        ? AppLayoutConstants.minSubtaskPebbleSweepDeg24H
        : AppLayoutConstants.minSubtaskPebbleSweepDeg12H;
    if (showSubtasks &&
        event.subtasks.isNotEmpty &&
        effectiveSweepDeg >= minPebbleSweep &&
        trackThickness >= 20.0) {
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
        centerTitleWidth: finalContentWidth * scale,
        is24HourMode: is24HourMode,
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
      fontWeight: FontWeight.w800,
      color: textColor,
      letterSpacing: 0.2,
    );

    final pebbleBgPaint = Paint()
      ..color = textColor.withValues(alpha: isDarkSector ? 0.30 : 0.22)
      ..style = PaintingStyle.fill;

    final pebbleBorderPaint = Paint()
      ..color = textColor.withValues(alpha: isDarkSector ? 0.65 : 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

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

      final w = tp.width +
          (is24HourMode ? 6.5 : (effectiveSweepDeg < 38.0 ? 8.0 : 10.5));
      final h = tp.height +
          (is24HourMode ? 3.5 : (effectiveSweepDeg < 38.0 ? 4.5 : 6.0));
      final halfDeg = (w / 2.0) / (midR * math.pi / 180.0);

      textPainters.add(tp);
      pebbleDimensions.add((w: w, h: h, halfDeg: halfDeg));
    }

    final halfSweep = effectiveSweepDeg / 2.0;

    // Safety margins to prevent touching block boundaries or center title
    final boundaryBufferDeg =
        is24HourMode ? 1.5 : (effectiveSweepDeg < 38.0 ? 1.8 : 2.5);
    final titleBufferDeg =
        is24HourMode ? 1.8 : (effectiveSweepDeg < 38.0 ? 2.0 : 3.0);

    // 1. Upstream (Left) Water Bay: between start boundary cap and center title.
    // Note: effectiveSweepDeg already subtracts startCapSpanDeg and endCapSpanDeg,
    // so -halfSweep is already at the inner edge of the start cap.
    final leftBayStartDeg = -halfSweep + boundaryBufferDeg;
    final leftBayEndDeg = -titleHalfDeg - titleBufferDeg;
    final leftBayWidth = leftBayEndDeg - leftBayStartDeg;

    // 2. Downstream (Right) Water Bay: between center title and end boundary cap.
    // Similarly, +halfSweep is already at the inner edge of the end cap.
    final rightBayStartDeg = titleHalfDeg + titleBufferDeg;
    final rightBayEndDeg = halfSweep - boundaryBufferDeg;
    final rightBayWidth = rightBayEndDeg - rightBayStartDeg;

    if (leftBayWidth <= 3.5 && rightBayWidth <= 3.5) return;

    // Helper to calculate minimum bay width required to safely fit 2 pebbles
    double requiredForTwo(int i1, int i2) {
      final d1 = pebbleDimensions[i1];
      final d2 = pebbleDimensions[i2];
      final minSep = math.max(3.5, (d1.halfDeg + d2.halfDeg) * 0.40);
      return d1.halfDeg + minSep + d2.halfDeg;
    }

    // Helper to check if a single pebble can fit
    bool canFitSingle(int idx, double bayWidth) {
      return bayWidth >= pebbleDimensions[idx].halfDeg * 1.6;
    }

    // Assign pebbles into Left Bay and Right Bay based on verified geometric capacity:
    final leftPebbleIndices = <int>[];
    final rightPebbleIndices = <int>[];

    final int count = pebbles.length;
    if (count == 1) {
      if (rightBayWidth >= leftBayWidth && canFitSingle(0, rightBayWidth)) {
        rightPebbleIndices.add(0);
      } else if (canFitSingle(0, leftBayWidth)) {
        leftPebbleIndices.add(0);
      }
    } else if (count == 2) {
      if (canFitSingle(0, leftBayWidth) && canFitSingle(1, rightBayWidth)) {
        leftPebbleIndices.add(0);
        rightPebbleIndices.add(1);
      } else if (rightBayWidth >= requiredForTwo(0, 1)) {
        rightPebbleIndices.add(0);
        rightPebbleIndices.add(1);
      } else if (leftBayWidth >= requiredForTwo(0, 1)) {
        leftPebbleIndices.add(0);
        leftPebbleIndices.add(1);
      } else if (canFitSingle(0, rightBayWidth)) {
        rightPebbleIndices.add(0);
      } else if (canFitSingle(0, leftBayWidth)) {
        leftPebbleIndices.add(0);
      }
    } else if (count == 3) {
      // 3 pebbles (e.g. Gym, Cardio, Stretch)
      final canRightFit2 = rightBayWidth >= requiredForTwo(1, 2);
      final canLeftFit1 = canFitSingle(0, leftBayWidth);
      final canLeftFit2 = leftBayWidth >= requiredForTwo(0, 1);
      final canRightFit1 = canFitSingle(2, rightBayWidth);

      if (canRightFit2 && canLeftFit1) {
        leftPebbleIndices.add(0);
        rightPebbleIndices.add(1);
        rightPebbleIndices.add(2);
      } else if (canLeftFit2 && canRightFit1) {
        leftPebbleIndices.add(0);
        leftPebbleIndices.add(1);
        rightPebbleIndices.add(2);
      } else if (canLeftFit1 && canFitSingle(1, rightBayWidth)) {
        // Safe fallback: each bay gets 1 pebble so no bay overflows
        leftPebbleIndices.add(0);
        rightPebbleIndices.add(1);
      } else if (canRightFit2) {
        rightPebbleIndices.add(0);
        rightPebbleIndices.add(1);
      } else if (canLeftFit2) {
        leftPebbleIndices.add(0);
        leftPebbleIndices.add(1);
      } else if (canLeftFit1) {
        leftPebbleIndices.add(0);
      } else if (canFitSingle(0, rightBayWidth)) {
        rightPebbleIndices.add(0);
      }
    } else {
      // 4 pebbles
      final canLeftFit2 = leftBayWidth >= requiredForTwo(0, 1);
      final canRightFit2 = rightBayWidth >= requiredForTwo(2, 3);
      final canLeftFit1 = canFitSingle(0, leftBayWidth);
      final canRightFit1 = canFitSingle(1, rightBayWidth);

      if (canLeftFit2 && canRightFit2) {
        leftPebbleIndices.add(0);
        leftPebbleIndices.add(1);
        rightPebbleIndices.add(2);
        rightPebbleIndices.add(3);
      } else if (canRightFit2 && canLeftFit1) {
        leftPebbleIndices.add(0);
        rightPebbleIndices.add(1);
        rightPebbleIndices.add(2);
      } else if (canLeftFit2 && canRightFit1) {
        leftPebbleIndices.add(0);
        leftPebbleIndices.add(1);
        rightPebbleIndices.add(2);
      } else if (canLeftFit1 && canRightFit1) {
        leftPebbleIndices.add(0);
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
        if (bayWidth < dim.halfDeg * 1.5) {
          final scaleFactor = (bayWidth / (dim.halfDeg * 2.0)).clamp(0.65, 1.0);
          if (scaleFactor < 0.70) return;
        }

        final minA = math.min(bayStart + dim.halfDeg, bayEnd - dim.halfDeg);
        final maxA = math.max(bayStart + dim.halfDeg, bayEnd - dim.halfDeg);
        var targetAngle = ((bayStart + bayEnd) / 2.0).clamp(minA, maxA);

        final pDeg = midDeg + targetAngle;
        final pRad = SectorMath.dialAngleToCanvasRadians(pDeg);
        final pR = midR.clamp(
          rIn + dim.h / 2.0 + 2.0,
          rOut - dim.h / 2.0 - 2.0,
        );

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
      } else if (indices.length >= 2) {
        final idx1 = indices[0];
        final idx2 = indices[1];
        final dim1 = pebbleDimensions[idx1];
        final dim2 = pebbleDimensions[idx2];

        final minSep = math.max(3.5, (dim1.halfDeg + dim2.halfDeg) * 0.40);
        final minRequiredWidth = dim1.halfDeg + minSep + dim2.halfDeg;

        if (bayWidth < minRequiredWidth ||
            (bayStart + dim1.halfDeg >= bayEnd - dim2.halfDeg - minSep)) {
          // Guaranteed safe fallback to 1 pebble centered:
          final minA = math.min(bayStart + dim1.halfDeg, bayEnd - dim1.halfDeg);
          final maxA = math.max(bayStart + dim1.halfDeg, bayEnd - dim1.halfDeg);
          var targetAngle = ((bayStart + bayEnd) / 2.0).clamp(minA, maxA);
          _renderSinglePebble(
            canvas: canvas,
            center: center,
            tp: textPainters[idx1],
            dim: dim1,
            pRad: SectorMath.dialAngleToCanvasRadians(midDeg + targetAngle),
            pR: midR.clamp(
              rIn + dim1.h / 2.0 + 2.0,
              rOut - dim1.h / 2.0 - 2.0,
            ),
            tilt: tilts[idx1 % tilts.length],
            pebbleBgPaint: pebbleBgPaint,
            pebbleBorderPaint: pebbleBorderPaint,
          );
          return;
        }

        // Both pebbles fit without ANY boundary overflow:
        final slack = math.max(0.0, bayWidth - minRequiredWidth);
        final minP1 = math.min(bayStart + dim1.halfDeg, bayEnd - dim2.halfDeg - minSep);
        final maxP1 = math.max(bayStart + dim1.halfDeg, bayEnd - dim2.halfDeg - minSep);
        final p1Angle = (bayStart + dim1.halfDeg + slack * 0.25).clamp(minP1, maxP1);

        final minP2 = math.min(p1Angle + minSep, bayEnd - dim2.halfDeg);
        final maxP2 = math.max(p1Angle + minSep, bayEnd - dim2.halfDeg);
        final p2Angle = (bayEnd - dim2.halfDeg - slack * 0.25).clamp(minP2, maxP2);

        final rStagger = (trackThickness * 0.14).clamp(4.0, 7.5);
        final p1R = (midR - rStagger).clamp(
          rIn + dim1.h / 2.0 + 2.0,
          rOut - dim1.h / 2.0 - 2.0,
        );
        final p2R = (midR + rStagger).clamp(
          rIn + dim2.h / 2.0 + 2.0,
          rOut - dim2.h / 2.0 - 2.0,
        );

        _renderSinglePebble(
          canvas: canvas,
          center: center,
          tp: textPainters[idx1],
          dim: dim1,
          pRad: SectorMath.dialAngleToCanvasRadians(midDeg + p1Angle),
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
          pRad: SectorMath.dialAngleToCanvasRadians(midDeg + p2Angle),
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
