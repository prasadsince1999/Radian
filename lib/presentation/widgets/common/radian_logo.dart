import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/clock_controller.dart';
import 'bouncy_pressable.dart';

/// A signature creative logo for Radian.
///
/// Features:
/// 1. A bespoke mathematical emblem: An orbital circle with a glowing arc
///    sweeping exactly 1 radian (~57.3°), tipped with an active focus node.
/// 2. Modern typographic wordmark with an accented dot over the 'i'
///    signifying the central clock needle / current moment.
/// 3. Interactive BouncyPressable tap that resets scrubbing back to current time.
class RadianLogo extends ConsumerWidget {
  final double emblemSize;
  final double fontSize;

  const RadianLogo({super.key, this.emblemSize = 28, this.fontSize = 22});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BouncyPressable.standard(
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(dialScrubAngleProvider.notifier).state = null;
        ref.read(selectedEventProvider.notifier).state = null;
        ref.read(customSelectedDayProvider.notifier).state = null;
      },
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Creative Radian Arc Emblem
            SizedBox(
              width: emblemSize,
              height: emblemSize,
              child: CustomPaint(
                painter: _RadianEmblemPainter(
                  primaryColor: colorScheme.primary,
                  secondaryColor: colorScheme.tertiary,
                  trackColor: colorScheme.outlineVariant.withValues(
                    alpha: 0.35,
                  ),
                  hubColor: colorScheme.onSurface.withValues(alpha: 0.25),
                ),
              ),
            ),
            const SizedBox(width: 8.5),

            // 2. Stylized Wordmark with accent indicator
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'Radian',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: fontSize,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(width: 3.5),
                Container(
                  width: 4.5,
                  height: 4.5,
                  margin: const EdgeInsets.only(bottom: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.primary,
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.65),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for the 1-radian dynamic arc emblem.
class _RadianEmblemPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;
  final Color trackColor;
  final Color hubColor;

  _RadianEmblemPainter({
    required this.primaryColor,
    required this.secondaryColor,
    required this.trackColor,
    required this.hubColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 2.5;

    // 1. Faint full orbit background circle
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius, trackPaint);

    // 2. Glowing Radian Arc (exactly 1 radian = 57.2958° ≈ 1.0 rad)
    // Starting at 12 o'clock (-pi/2) sweeping clockwise by 1 radian
    const startAngle = -math.pi / 2;
    const sweepAngle = 1.0; // exactly 1 radian!

    final arcRect = Rect.fromCircle(center: center, radius: radius);
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.2
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle + 0.5,
        colors: [primaryColor, secondaryColor],
      ).createShader(arcRect);

    canvas.drawArc(arcRect, startAngle, sweepAngle, false, arcPaint);

    // 3. Leading Node (the "now" pip / jewel at the head of the radian arc)
    final endAngle = startAngle + sweepAngle;
    final nodeX = center.dx + radius * math.cos(endAngle);
    final nodeY = center.dy + radius * math.sin(endAngle);
    final nodeOffset = Offset(nodeX, nodeY);

    // Node outer glow
    final glowPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(nodeOffset, 3.8, glowPaint);

    // Node core
    final nodeCorePaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(nodeOffset, 2.2, nodeCorePaint);

    // 4. Center tiny pivot/hub dot
    final centerDotPaint = Paint()
      ..color = hubColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 1.6, centerDotPaint);
  }

  @override
  bool shouldRepaint(covariant _RadianEmblemPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.hubColor != hubColor;
  }
}
