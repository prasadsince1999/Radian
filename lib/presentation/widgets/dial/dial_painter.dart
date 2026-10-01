import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_layout_constants.dart';
import '../../../core/constants/app_presets.dart';
import '../../../core/geometry/dial_time_cap_drag_handler.dart';
import '../../../core/geometry/sector_math.dart';
import '../../../core/i18n/numeral_system.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/color_contrast.dart';
import '../../../domain/models/dial_settings.dart';
import '../../../engine/dial_model.dart';
import '../../../engine/horizon_selector.dart';
import '../../../engine/ring_assigner.dart';
import 'components/hour_needle_renderer.dart';
import 'components/sector_pattern_renderer.dart';
import 'components/sector_pill_renderer.dart';

/// Pure, high-performance dial painter driven strictly by [DialModel] (§3.3, §4).
///
/// Invariant I8: The app dial draws [DialModel]; nothing else.
/// Zero geometry or layout decisions are made inside this painter.
/// All angles, radii, content modes, and capsule placements are pre-computed.
///
/// [shouldRepaint] checks [model.signature] for instant 60/120fps performance.
class DialPainter extends CustomPainter {
  final DialModel model;
  final DialSettings settings;
  final ThemeData theme;
  final ColorScheme colorScheme;
  final CapHitResult? activeDraggingCap;
  final double? scrubAngle;
  final String? selectedEventId;
  final bool showCenterClock;
  final bool showNeedle;

  DialPainter({
    required this.model,
    required this.settings,
    required this.theme,
    required this.colorScheme,
    this.activeDraggingCap,
    this.scrubAngle,
    this.selectedEventId,
    this.showCenterClock = false,
    this.showNeedle = true,
  });

  static const int scallopLobes = AppLayoutConstants.scallopLobes;
  static const double referenceCanvasSize = 360.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final scale = math.min(size.width, size.height) / referenceCanvasSize;
    canvas.save();
    final dx = (size.width - referenceCanvasSize * scale) / 2.0;
    final dy = (size.height - referenceCanvasSize * scale) / 2.0;
    canvas.translate(dx, dy);
    canvas.scale(scale, scale);

    _paintReference(
      canvas,
      const Size(referenceCanvasSize, referenceCanvasSize),
    );
    canvas.restore();
  }

  void _paintReference(Canvas canvas, Size size) {
    final center = Offset(size.width / 2.0, size.height / 2.0);
    final isWave = settings.dialShape == DialShape.waveRounded;
    final scallopAmp = isWave ? 5.0 : 0.0;
    final maxRadius = (math.min(size.width, size.height) / 2.0) - 4.0;
    final baseRadius = maxRadius - scallopAmp;
    final innerRadius = baseRadius * AppLayoutConstants.innerRadiusRatio;
    final routineTrackIn =
        innerRadius + AppLayoutConstants.routineTrackInnerOffset;
    final routineTrackOut =
        baseRadius - AppLayoutConstants.routineTrackOuterMargin;
    final ringDividerRadius = (routineTrackIn + routineTrackOut) / 2.0;

    // 1. Dial background chassis & radial spokes
    _drawDialBackground(
      canvas,
      center,
      baseRadius,
      innerRadius,
      isWave: isWave,
      scallopAmp: scallopAmp,
    );

    // 1b. True-time reference ring (Phase 8, §9 Feature 2)
    if (settings.isFocusLensEnabled && settings.showTrueTimeRing) {
      _drawTrueTimeRing(canvas, center, baseRadius);
    }

    // 2. Render all visible DialBlocks (single-ring or dual concentric tracks)
    _drawDialBlocks(
      canvas,
      center,
      routineTrackIn,
      routineTrackOut,
      ringDividerRadius,
    );

    // 2b. Subtask pace ring for active block (Phase 8, §9 Feature 6, I11)
    if (settings.showSubtaskPaceRing) {
      _drawSubtaskPaceRing(
        canvas,
        center,
        routineTrackIn,
        ringDividerRadius,
        routineTrackOut,
      );
    }

    // 2c. Hidden blocks bezel notches (Phase 8, I10)
    if (model.hidden.hiddenCount > 0 && settings.showHiddenBlocksIndicator) {
      _drawHiddenBlocksIndicator(canvas, center, baseRadius);
    }

    // 3. Dial outline ring
    _drawDialOutline(
      canvas,
      center,
      baseRadius,
      isWave: isWave,
      scallopAmp: scallopAmp,
    );

    // 4. Pre-computed hour ticks & 3D numbers from model.ticks
    _drawDialTicks(canvas, center, baseRadius, routineTrackOut);

    // 5. Hour needle & celestial beacon strictly from model.needle
    if (showNeedle) {
      _drawNeedle(canvas, center, innerRadius, routineTrackOut, baseRadius);
    }

    // 5b. Secondary time zone needle (Phase 8, §9 Feature 3)
    if (showNeedle && model.secondaryNeedle != null) {
      _drawSecondaryNeedle(
        canvas,
        center,
        innerRadius,
        routineTrackOut,
        baseRadius,
      );
    }

    // 6. Center hub clock face if enabled
    if (showCenterClock &&
        settings.centerClockDisplay != CenterClockDisplay.analog) {
      _drawCenterHub(canvas, center, innerRadius);
    }
  }

  Path _buildScallopPath(Offset center, double baseRadius, double scallopAmp) {
    final path = Path();
    const steps = 360;
    for (int i = 0; i <= steps; i++) {
      final angle = (i * 2 * math.pi) / steps;
      final r = baseRadius + scallopAmp * math.cos(scallopLobes * angle);
      final x = center.dx + r * math.cos(angle - math.pi / 2);
      final y = center.dy + r * math.sin(angle - math.pi / 2);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  void _drawDialBackground(
    Canvas canvas,
    Offset center,
    double baseRadius,
    double innerRadius, {
    required bool isWave,
    required double scallopAmp,
  }) {
    final isDark = colorScheme.brightness == Brightness.dark;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: isDark ? 0.65 : 0.12)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, isDark ? 5.0 : 6.0);

    final dialBgColor = colorScheme.surfaceContainerLowest;
    final bgPaint = Paint()
      ..color = dialBgColor
      ..style = PaintingStyle.fill;

    if (isWave) {
      final scallopPath = _buildScallopPath(center, baseRadius, scallopAmp);
      canvas.drawPath(scallopPath, shadowPaint);
      canvas.drawPath(scallopPath, bgPaint);
    } else {
      canvas.drawCircle(center, baseRadius, shadowPaint);
      canvas.drawCircle(center, baseRadius, bgPaint);
    }

    // Radial hour division spokes (using model.ticks)
    final spokePaint = Paint()
      ..color = colorScheme.outlineVariant.withValues(
        alpha: isDark ? 0.35 : 0.45,
      )
      ..strokeWidth = 1.0;

    for (final tick in model.ticks) {
      final rad = SectorMath.dialAngleToCanvasRadians(tick.displayDeg);
      final p1 = Offset(
        center.dx + innerRadius * math.cos(rad),
        center.dy + innerRadius * math.sin(rad),
      );
      final p2 = Offset(
        center.dx + (baseRadius - 8.0) * math.cos(rad),
        center.dy + (baseRadius - 8.0) * math.sin(rad),
      );
      canvas.drawLine(p1, p2, spokePaint);
    }
  }

  void _drawDialOutline(
    Canvas canvas,
    Offset center,
    double baseRadius, {
    required bool isWave,
    required double scallopAmp,
  }) {
    final outlinePaint = Paint()
      ..color = colorScheme.outlineVariant.withValues(alpha: 0.60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    if (isWave) {
      final scallopPath = _buildScallopPath(center, baseRadius, scallopAmp);
      canvas.drawPath(scallopPath, outlinePaint);
    } else {
      canvas.drawCircle(center, baseRadius, outlinePaint);
    }
  }

  void _drawDialBlocks(
    Canvas canvas,
    Offset center,
    double routineTrackIn,
    double routineTrackOut,
    double ringDividerRadius,
  ) {
    if (model.blocks.isEmpty) return;

    final hasInnerBlocks = model.blocks.any((b) => b.ring == RingLevel.inner);

    // Sort blocks so larger blocks render first and selected / shorter blocks are on top
    final sortedBlocks = List<DialBlock>.from(model.blocks)
      ..sort((a, b) {
        if (selectedEventId != null) {
          if (a.eventId == selectedEventId) return 1;
          if (b.eventId == selectedEventId) return -1;
        }
        return b.sweepDeg.compareTo(a.sweepDeg);
      });

    for (final block in sortedBlocks) {
      if (block.sweepDeg <= 0.5) continue;

      final double rIn;
      final double rOut;

      if (hasInnerBlocks) {
        if (block.ring == RingLevel.inner) {
          rIn = routineTrackIn;
          rOut = ringDividerRadius - 1.0;
        } else {
          rIn = ringDividerRadius + 1.0;
          rOut = routineTrackOut;
        }
      } else {
        rIn = routineTrackIn;
        rOut = routineTrackOut;
      }

      final color = _parseColor(block.colorHex);
      final isSelected = block.eventId == selectedEventId;
      final cornerRadius = math
          .min(8.0, (rOut - rIn) * 0.22)
          .clamp(3.0, 8.0);

      // 1. Build and fill pill path
      final pillPath = SectorPillRenderer.buildPillPath(
        center: center,
        rIn: rIn,
        rOut: rOut,
        startDeg: block.startDeg,
        sweepDeg: block.sweepDeg,
        cornerRadius: cornerRadius,
      );

      final fillPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawPath(pillPath, fillPaint);

      // Color-blind-safe geometric pattern overlay (§7 Phase 7)
      if (settings.enableColorBlindPatterns) {
        SectorPatternRenderer.drawPattern(
          canvas: canvas,
          pillPath: pillPath,
          bounds: pillPath.getBounds(),
          category: block.category,
          sectorColor: color,
        );
      }

      // Selection outline
      if (isSelected) {
        final highlightPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.95)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4;
        canvas.drawPath(pillPath, highlightPaint);
      }

      // 2. Draw Start & End Caps
      if (block.caps.isVisible) {
        _drawBlockCaps(
          canvas: canvas,
          center: center,
          rIn: rIn,
          rOut: rOut,
          block: block,
          eventColor: color,
          cornerRadius: cornerRadius,
        );
      }

      // 3. Draw Block Content (Title & Icon)
      _drawBlockContent(
        canvas: canvas,
        center: center,
        pillPath: pillPath,
        rIn: rIn,
        rOut: rOut,
        block: block,
        eventColor: color,
      );

      // 4. Draw Subtask Capsules
      if (block.capsules.isNotEmpty) {
        _drawSubtaskCapsules(
          canvas: canvas,
          center: center,
          pillPath: pillPath,
          rIn: rIn,
          rOut: rOut,
          block: block,
          eventColor: color,
        );
      }
    }
  }

  void _drawBlockCaps({
    required Canvas canvas,
    required Offset center,
    required double rIn,
    required double rOut,
    required DialBlock block,
    required Color eventColor,
    required double cornerRadius,
  }) {
    final caps = block.caps;
    final isDraggingThis = activeDraggingCap != null &&
        activeDraggingCap!.event.id == block.eventId;

    // Start Cap
    if (caps.startCapSpanDeg > 0.5 && caps.startTimeLabel.isNotEmpty) {
      final isDraggingStart = isDraggingThis &&
          (activeDraggingCap!.isStartCap || activeDraggingCap!.isEntireBlock);
      _drawCapBadge(
        canvas: canvas,
        center: center,
        rIn: rIn,
        rOut: rOut,
        startDeg: caps.startAngleDeg,
        sweepDeg: caps.startCapSpanDeg,
        label: caps.startTimeLabel,
        eventColor: eventColor,
        cornerRadius: cornerRadius,
        roundStart: true,
        roundEnd: false,
        isDragging: isDraggingStart,
      );
    }

    // End Cap
    if (caps.endCapSpanDeg > 0.5 && caps.endTimeLabel.isNotEmpty) {
      final isDraggingEnd = isDraggingThis &&
          (activeDraggingCap!.isEndCap || activeDraggingCap!.isEntireBlock);
      final capStartDeg = caps.endAngleDeg - caps.endCapSpanDeg;
      _drawCapBadge(
        canvas: canvas,
        center: center,
        rIn: rIn,
        rOut: rOut,
        startDeg: capStartDeg,
        sweepDeg: caps.endCapSpanDeg,
        label: caps.endTimeLabel,
        eventColor: eventColor,
        cornerRadius: cornerRadius,
        roundStart: false,
        roundEnd: true,
        isDragging: isDraggingEnd,
      );
    }
  }

  void _drawCapBadge({
    required Canvas canvas,
    required Offset center,
    required double rIn,
    required double rOut,
    required double startDeg,
    required double sweepDeg,
    required String label,
    required Color eventColor,
    required double cornerRadius,
    required bool roundStart,
    required bool roundEnd,
    required bool isDragging,
  }) {
    final capPath = SectorPillRenderer.buildPillPath(
      center: center,
      rIn: rIn,
      rOut: rOut,
      startDeg: startDeg,
      sweepDeg: sweepDeg,
      cornerRadius: cornerRadius,
      roundStart: roundStart,
      roundEnd: roundEnd,
    );

    final badgeColor = isDragging
        ? Color.lerp(eventColor, Colors.white, 0.25)!
        : Color.lerp(eventColor, Colors.black, 0.36)!;

    canvas.drawPath(
      capPath,
      Paint()
        ..color = badgeColor
        ..style = PaintingStyle.fill,
    );

    if (isDragging) {
      canvas.drawPath(
        capPath,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }

    // Cap timestamp text
    final midAngleDeg = startDeg + (sweepDeg / 2.0);
    final midRad = SectorMath.dialAngleToCanvasRadians(midAngleDeg);
    final midR = (rIn + rOut) / 2.0;
    final textCenter = Offset(
      center.dx + midR * math.cos(midRad),
      center.dy + midR * math.sin(midRad),
    );

    final fontSize = isDragging ? 12.0 : (model.is24HourMode ? 8.6 : 9.5);
    final displayLabel = NumeralConverter.convert(label, settings.numeralSystem);
    final textPainter = TextPainter(
      text: TextSpan(
        text: displayLabel,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: isDragging ? Colors.black87 : Colors.white,
          letterSpacing: -0.1,
          fontFamilyFallback: AppTypography.fontFamilyFallback,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    final availableArcAtMidR = midR * (sweepDeg * math.pi / 180.0);
    final availableRadial = (rOut - rIn) - 4.0;
    var scale = 1.0;
    if (textPainter.height > availableArcAtMidR * 0.94) {
      scale = math.min(scale, (availableArcAtMidR * 0.94) / textPainter.height);
    }
    if (textPainter.width > availableRadial) {
      scale = math.min(scale, availableRadial / textPainter.width);
    }
    scale = scale.clamp(0.70, 1.0);

    canvas.save();
    canvas.clipPath(capPath);
    canvas.translate(textCenter.dx, textCenter.dy);

    var rotation = midRad;
    if (math.cos(midRad) < -0.05) {
      rotation += math.pi;
    }
    canvas.rotate(rotation);

    if (scale < 1.0) {
      canvas.scale(scale, scale);
    }

    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2.0, -textPainter.height / 2.0),
    );
    canvas.restore();
  }

  void _drawBlockContent({
    required Canvas canvas,
    required Offset center,
    required Path pillPath,
    required double rIn,
    required double rOut,
    required DialBlock block,
    required Color eventColor,
  }) {
    if (block.content == ContentMode.iconOnly) {
      _drawIconOnly(
        canvas: canvas,
        center: center,
        rIn: rIn,
        rOut: rOut,
        block: block,
        eventColor: eventColor,
      );
      return;
    }

    final startCapSpan =
        block.caps.isVisible ? block.caps.startCapSpanDeg : 0.0;
    final endCapSpan = block.caps.isVisible ? block.caps.endCapSpanDeg : 0.0;
    final effectiveStartDeg = block.startDeg + startCapSpan;
    final effectiveSweepDeg = block.sweepDeg - startCapSpan - endCapSpan;

    if (effectiveSweepDeg < (model.is24HourMode ? 2.5 : 4.0)) return;

    final midDeg = effectiveStartDeg + (effectiveSweepDeg / 2.0);
    final midRad = SectorMath.dialAngleToCanvasRadians(midDeg);
    final midR = (rIn + rOut) / 2.0;
    final pos = Offset(
      center.dx + midR * math.cos(midRad),
      center.dy + midR * math.sin(midRad),
    );

    final textColor = ColorContrast.getHighContrastTextColor(eventColor);

    final iconData = _resolveIcon(block);
    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(iconData.codePoint),
        style: TextStyle(
          fontSize: 11.0,
          fontFamily: iconData.fontFamily,
          package: iconData.fontPackage,
          color: textColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final titlePainter = TextPainter(
      text: TextSpan(
        text: block.title,
        style: TextStyle(
          fontSize: 10.0,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: -0.2,
          fontFamilyFallback: AppTypography.fontFamilyFallback,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout();

    // Clip to pill body
    canvas.save();
    canvas.clipPath(pillPath);
    canvas.translate(pos.dx, pos.dy);

    var tangentAngle = midRad + (math.pi / 2.0);
    if (math.cos(tangentAngle) < 0.05) {
      tangentAngle += math.pi;
    }
    canvas.rotate(tangentAngle);

    final totalHeight = iconPainter.height + 2.0 + titlePainter.height;
    var curY = -totalHeight / 2.0;

    iconPainter.paint(canvas, Offset(-iconPainter.width / 2.0, curY));
    curY += iconPainter.height + 2.0;

    titlePainter.paint(canvas, Offset(-titlePainter.width / 2.0, curY));

    canvas.restore();
  }

  void _drawIconOnly({
    required Canvas canvas,
    required Offset center,
    required double rIn,
    required double rOut,
    required DialBlock block,
    required Color eventColor,
  }) {
    final midDeg = block.startDeg + (block.sweepDeg / 2.0);
    final midRad = SectorMath.dialAngleToCanvasRadians(midDeg);
    final midR = (rIn + rOut) / 2.0;
    final pos = Offset(
      center.dx + midR * math.cos(midRad),
      center.dy + midR * math.sin(midRad),
    );

    final isDarkSector =
        ThemeData.estimateBrightnessForColor(eventColor) == Brightness.dark;
    final textColor =
        isDarkSector ? const Color(0xFFF7F3EE) : const Color(0xFF1E1A16);

    final iconData = _resolveIcon(block);
    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(iconData.codePoint),
        style: TextStyle(
          fontSize: 11.0,
          fontFamily: iconData.fontFamily,
          package: iconData.fontPackage,
          color: textColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    iconPainter.paint(
      canvas,
      Offset(-iconPainter.width / 2.0, -iconPainter.height / 2.0),
    );
    canvas.restore();
  }

  void _drawSubtaskCapsules({
    required Canvas canvas,
    required Offset center,
    required Path pillPath,
    required double rIn,
    required double rOut,
    required DialBlock block,
    required Color eventColor,
  }) {
    final isDarkSector =
        ThemeData.estimateBrightnessForColor(eventColor) == Brightness.dark;
    final chipBgColor = isDarkSector
        ? Colors.black.withValues(alpha: 0.38)
        : Colors.white.withValues(alpha: 0.85);
    final chipTextColor = ColorContrast.getHighContrastTextColor(chipBgColor);

    for (final capsule in block.capsules) {
      final rad = SectorMath.dialAngleToCanvasRadians(capsule.centerDeg);
      final rMid = rIn + (rOut - rIn) * capsule.radiusRatio;
      final pos = Offset(
        center.dx + rMid * math.cos(rad),
        center.dy + rMid * math.sin(rad),
      );

      final label = capsule.isFolded
          ? '+${NumeralConverter.formatInt(capsule.foldedCount, settings.numeralSystem)}'
          : capsule.title;
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.w600,
            color: chipTextColor,
            letterSpacing: -0.1,
            fontFamilyFallback: AppTypography.fontFamilyFallback,
            decoration: capsule.isCompleted
                ? TextDecoration.lineThrough
                : TextDecoration.none,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final chipWidth = math.max(capsule.widthPx, textPainter.width + 8.0);
      final chipHeight = math.max(capsule.heightPx, 13.0);

      canvas.save();
      canvas.clipPath(pillPath);
      canvas.translate(pos.dx, pos.dy);

      var tangentAngle = rad + (math.pi / 2.0);
      if (math.cos(tangentAngle) < 0.05) {
        tangentAngle += math.pi;
      }
      canvas.rotate(tangentAngle);

      final chipRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: chipWidth,
          height: chipHeight,
        ),
        const Radius.circular(6.0),
      );

      // Chip background & subtle border
      canvas.drawRRect(
        chipRect,
        Paint()
          ..color = chipBgColor
          ..style = PaintingStyle.fill,
      );

      canvas.drawRRect(
        chipRect,
        Paint()
          ..color = isDarkSector
              ? Colors.white.withValues(alpha: 0.20)
              : Colors.black.withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );

      // Draw check dot if completed
      if (capsule.isCompleted) {
        final dotPaint = Paint()
          ..color = const Color(0xFF10B981) // Green
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset(-chipWidth / 2.0 + 4.5, 0),
          2.0,
          dotPaint,
        );
      }

      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2.0, -textPainter.height / 2.0),
      );

      canvas.restore();
    }
  }

  void _drawDialTicks(
    Canvas canvas,
    Offset center,
    double baseRadius,
    double routineTrackOut,
  ) {
    final isDark = colorScheme.brightness == Brightness.dark;
    final tickColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF374151);

    // 1. Minor intervals
    if (settings.faceStyle != DialFaceStyle.minimal) {
      final minorPaint = Paint()
        ..color = tickColor.withValues(alpha: 0.35)
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round;

      final totalIntervals = model.is24HourMode ? 48 : 48;
      for (int i = 0; i < totalIntervals; i++) {
        if (i % (model.is24HourMode ? 2 : 4) == 0) continue;
        final rawDeg = (i / totalIntervals) * 360.0;
        final visualDeg = model.warp.forward(rawDeg);
        final rad = SectorMath.dialAngleToCanvasRadians(visualDeg);

        final pOuter = Offset(
          center.dx + baseRadius * math.cos(rad),
          center.dy + baseRadius * math.sin(rad),
        );
        final pInner = Offset(
          center.dx + (baseRadius - 2.5) * math.cos(rad),
          center.dy + (baseRadius - 2.5) * math.sin(rad),
        );
        canvas.drawLine(pInner, pOuter, minorPaint);
      }
    }

    // 2. Pre-computed hour tick numbers from model.ticks
    for (final tick in model.ticks) {
      final rad = SectorMath.dialAngleToCanvasRadians(tick.displayDeg);
      final numRadius = routineTrackOut;
      final pos = Offset(
        center.dx + numRadius * math.cos(rad),
        center.dy + numRadius * math.sin(rad),
      );

      final fontSize = tick.isMajor ? 11.0 : 9.5;
      final fontWeight = tick.isMajor ? FontWeight.w900 : FontWeight.w600;
      final displayLabel =
          NumeralConverter.convert(tick.label, settings.numeralSystem);

      final textPainter = TextPainter(
        text: TextSpan(
          text: displayLabel,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: tickColor,
            fontFamilyFallback: AppTypography.fontFamilyFallback,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(pos.dx - textPainter.width / 2.0, pos.dy - textPainter.height / 2.0),
      );
    }
  }

  void _drawNeedle(
    Canvas canvas,
    Offset center,
    double innerRadius,
    double routineTrackOut,
    double baseRadius,
  ) {
    final effectiveAngle = scrubAngle ?? model.needle.displayDeg;
    final nowRad = SectorMath.dialAngleToCanvasRadians(effectiveAngle);
    final nowHour = DateTime.now().hour;
    final isDaytime = nowHour >= 6 && nowHour < 18;

    HourNeedleRenderer.drawNeedle(
      canvas: canvas,
      center: center,
      angleRad: nowRad,
      hubRadius: innerRadius,
      outerROut: routineTrackOut,
      baseRadius: baseRadius,
      isDaytime: isDaytime,
    );
  }

  void _drawCenterHub(Canvas canvas, Offset center, double innerRadius) {
    final isDark = colorScheme.brightness == Brightness.dark;
    final title = model.center.activeTitle;
    final remaining = model.center.remainingDurationFormatted;
    final displayRemaining =
        NumeralConverter.convert(remaining, settings.numeralSystem);

    final titlePainter = TextPainter(
      text: TextSpan(
        text: title.isNotEmpty ? title : 'Free Time',
        style: TextStyle(
          fontSize: 12.0,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : Colors.black87,
          fontFamilyFallback: AppTypography.fontFamilyFallback,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout();

    final remainingPainter = displayRemaining.isNotEmpty
        ? (TextPainter(
            text: TextSpan(
              text: displayRemaining,
              style: TextStyle(
                fontSize: 10.0,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : Colors.black54,
                fontFamilyFallback: AppTypography.fontFamilyFallback,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout())
        : null;

    final totalH = titlePainter.height + (remainingPainter?.height ?? 0.0);
    var y = center.dy - totalH / 2.0;

    titlePainter.paint(
      canvas,
      Offset(center.dx - titlePainter.width / 2.0, y),
    );

    if (remainingPainter != null) {
      y += titlePainter.height + 2.0;
      remainingPainter.paint(
        canvas,
        Offset(center.dx - remainingPainter.width / 2.0, y),
      );
    }
  }

  void _drawTrueTimeRing(Canvas canvas, Offset center, double baseRadius) {
    final isDark = colorScheme.brightness == Brightness.dark;
    final ringPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75;

    final tickPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = colorScheme.primary.withValues(alpha: 0.40)
      ..style = PaintingStyle.fill;

    final ringR = baseRadius - 1.5;
    canvas.drawCircle(center, ringR, ringPaint);

    final totalTicks = model.is24HourMode ? 24 : 12;
    for (int h = 0; h < totalTicks; h++) {
      final naturalDeg = h * (model.is24HourMode ? 15.0 : 30.0);
      final rad = SectorMath.dialAngleToCanvasRadians(naturalDeg);
      final isMajor = model.is24HourMode ? (h % 6 == 0) : (h % 3 == 0);

      final pOuter = Offset(
        center.dx + ringR * math.cos(rad),
        center.dy + ringR * math.sin(rad),
      );
      final tickLength = isMajor ? 3.5 : 2.0;
      final pInner = Offset(
        center.dx + (ringR - tickLength) * math.cos(rad),
        center.dy + (ringR - tickLength) * math.sin(rad),
      );
      canvas.drawLine(pInner, pOuter, tickPaint);

      if (isMajor) {
        canvas.drawCircle(
          Offset(
            center.dx + (ringR - 5.5) * math.cos(rad),
            center.dy + (ringR - 5.5) * math.sin(rad),
          ),
          1.0,
          dotPaint,
        );
      }
    }
  }

  void _drawSecondaryNeedle(
    Canvas canvas,
    Offset center,
    double innerRadius,
    double routineTrackOut,
    double baseRadius,
  ) {
    final secNeedle = model.secondaryNeedle;
    if (secNeedle == null) return;

    final rad = SectorMath.dialAngleToCanvasRadians(secNeedle.displayDeg);
    final isDark = colorScheme.brightness == Brightness.dark;

    // Slender dual-line / accent secondary needle
    final needleColor = colorScheme.tertiary;
    final needlePaint = Paint()
      ..color = needleColor.withValues(alpha: 0.85)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final pStart = Offset(
      center.dx + (innerRadius + 4.0) * math.cos(rad),
      center.dy + (innerRadius + 4.0) * math.sin(rad),
    );
    final pEnd = Offset(
      center.dx + (routineTrackOut - 2.0) * math.cos(rad),
      center.dy + (routineTrackOut - 2.0) * math.sin(rad),
    );
    canvas.drawLine(pStart, pEnd, needlePaint);

    // Tip pip
    final pipPaint = Paint()
      ..color = needleColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pEnd, 2.5, pipPaint);

    // Bezel badge label (e.g. "NYC 18:30")
    final badgeRad = rad;
    final badgeR = baseRadius + 1.0;
    final badgePos = Offset(
      center.dx + badgeR * math.cos(badgeRad),
      center.dy + badgeR * math.sin(badgeRad),
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: secNeedle.label,
        style: TextStyle(
          fontSize: 8.0,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : Colors.black87,
          fontFamilyFallback: AppTypography.fontFamilyFallback,
          letterSpacing: 0.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(badgePos.dx, badgePos.dy);
    var tangent = badgeRad + math.pi / 2.0;
    if (math.cos(tangent) < 0.05) tangent += math.pi;
    canvas.rotate(tangent);

    final badgeRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset.zero,
        width: textPainter.width + 6.0,
        height: textPainter.height + 3.0,
      ),
      const Radius.circular(4.0),
    );

    canvas.drawRRect(
      badgeRRect,
      Paint()
        ..color = (isDark
            ? const Color(0xFF1E293B)
            : const Color(0xFFF1F5F9)),
    );
    canvas.drawRRect(
      badgeRRect,
      Paint()
        ..color = needleColor.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2.0, -textPainter.height / 2.0),
    );
    canvas.restore();
  }

  void _drawSubtaskPaceRing(
    Canvas canvas,
    Offset center,
    double routineTrackIn,
    double ringDividerRadius,
    double routineTrackOut,
  ) {
    // Find active block with subtasks
    final activeBlock = model.blocks
        .where((b) => b.role == BlockRole.active && b.subtasks.isNotEmpty)
        .firstOrNull;
    if (activeBlock == null) return;

    final totalSubtasks = activeBlock.subtasks.length;
    final completedCount =
        activeBlock.capsules.where((c) => c.isCompleted).length;
    if (totalSubtasks == 0) return;

    final isSingleRing = model.blocks.every((b) => b.ring == RingLevel.outer);
    final rIn = (isSingleRing || activeBlock.ring == RingLevel.inner)
        ? routineTrackIn
        : ringDividerRadius;

    final paceR = rIn + 2.5;
    final startRad =
        SectorMath.dialAngleToCanvasRadians(activeBlock.startDeg);
    final sweepRad = activeBlock.sweepDeg * math.pi / 180.0;

    // Track arc
    final trackPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: paceR);
    canvas.drawArc(rect, startRad, sweepRad, false, trackPaint);

    // Completed subtasks ratio (Invariant I11: calm neutral tone)
    final subtaskRatio = (completedCount / totalSubtasks).clamp(0.0, 1.0);
    if (subtaskRatio > 0) {
      final paceFillPaint = Paint()
        ..color = const Color(0xFFE2D9CC)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        rect,
        startRad,
        sweepRad * subtaskRatio,
        false,
        paceFillPaint,
      );
    }
  }

  void _drawHiddenBlocksIndicator(
    Canvas canvas,
    Offset center,
    double baseRadius,
  ) {
    if (model.hidden.hiddenCount == 0) return;

    final notchPaint = Paint()
      ..color = const Color(0xFFF59E0B) // Amber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final pipPaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.fill;

    // Draw bezel notch for each hidden block
    for (final hidden in model.hidden.hiddenEvents) {
      final displayAngle = model.warp.forward(hidden.naturalAngleDeg);
      final rad = SectorMath.dialAngleToCanvasRadians(displayAngle);

      final p1 = Offset(
        center.dx + (baseRadius - 1.0) * math.cos(rad),
        center.dy + (baseRadius - 1.0) * math.sin(rad),
      );
      final p2 = Offset(
        center.dx + (baseRadius + 3.5) * math.cos(rad),
        center.dy + (baseRadius + 3.5) * math.sin(rad),
      );
      canvas.drawLine(p1, p2, notchPaint);
      canvas.drawCircle(p2, 1.5, pipPaint);
    }
  }

  IconData _resolveIcon(DialBlock block) {
    if (block.occurrence.iconName != null &&
        block.occurrence.iconName!.isNotEmpty) {
      return AppPresets.getIconById(block.occurrence.iconName);
    }
    final title = block.title.toLowerCase();
    if (title.contains('work') ||
        title.contains('code') ||
        title.contains('study')) {
      return Icons.laptop_mac_rounded;
    }
    if (title.contains('sleep') ||
        title.contains('bed') ||
        title.contains('rest')) {
      return Icons.bedtime_rounded;
    }
    if (title.contains('yoga') ||
        title.contains('gym') ||
        title.contains('run')) {
      return Icons.fitness_center_rounded;
    }
    if (title.contains('eat') ||
        title.contains('lunch') ||
        title.contains('dinner')) {
      return Icons.restaurant_rounded;
    }
    return Icons.schedule_rounded;
  }

  Color _parseColor(String hex) {
    final clean = hex.replaceFirst('#', '');
    final val = int.tryParse(clean, radix: 16) ?? 0xFF6366F1;
    return Color(val.bitLength <= 24 ? val | 0xFF000000 : val);
  }

  @override
  bool shouldRepaint(covariant DialPainter oldDelegate) {
    return oldDelegate.model.signature != model.signature ||
        oldDelegate.theme != theme ||
        oldDelegate.colorScheme != colorScheme ||
        oldDelegate.settings != settings ||
        oldDelegate.activeDraggingCap != activeDraggingCap ||
        oldDelegate.scrubAngle != scrubAngle ||
        oldDelegate.selectedEventId != selectedEventId ||
        oldDelegate.showCenterClock != showCenterClock ||
        oldDelegate.showNeedle != showNeedle;
  }
}
