import 'dart:math';

import 'package:flutter/material.dart';

/// A compact circular 12-hour clock preview showing the event's sector arc
/// and the hours / duration in the center, matching Sectograph's design.
class MiniSectorDial extends StatelessWidget {
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final Color color;
  final String centerText;
  final bool isAllDay;
  final double size;

  const MiniSectorDial({
    super.key,
    required this.startTime,
    required this.endTime,
    required this.color,
    required this.centerText,
    this.isAllDay = false,
    this.size = 76.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MiniSectorDialPainter(
          startTime: startTime,
          endTime: endTime,
          color: color,
          centerText: centerText,
          isAllDay: isAllDay,
        ),
      ),
    );
  }
}

class _MiniSectorDialPainter extends CustomPainter {
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final Color color;
  final String centerText;
  final bool isAllDay;

  _MiniSectorDialPainter({
    required this.startTime,
    required this.endTime,
    required this.color,
    required this.centerText,
    required this.isAllDay,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final scale = size.width / 76.0;
    final strokeWidth = (8.0 * scale).clamp(4.0, 10.0);
    final arcRadius = radius - strokeWidth / 2 - (2.0 * scale);

    // 1. Dark circular dial background
    final bgPaint = Paint()
      ..color = const Color(0xFF1C1A18)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // 2. Track background ring
    final trackPaint = Paint()
      ..color = const Color(0xFF2A2724)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, arcRadius, trackPaint);

    // 3. Colored event sector arc
    if (isAllDay) {
      final allDayPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, arcRadius, allDayPaint);
    } else {
      final startMin = (startTime.hour % 12) * 60 + startTime.minute;
      var endMin = (endTime.hour % 12) * 60 + endTime.minute;
      if (endMin <= startMin) {
        endMin += 12 * 60;
      }
      var durationMin = endMin - startMin;
      if (durationMin > 12 * 60) durationMin = 12 * 60;

      // 12 o'clock is -pi/2
      final startAngle = (startMin / (12 * 60.0)) * 2 * pi - pi / 2;
      final sweepAngle = (durationMin / (12 * 60.0)) * 2 * pi;

      if (sweepAngle > 0.01) {
        final arcPaint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = strokeWidth;

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: arcRadius),
          startAngle,
          sweepAngle,
          false,
          arcPaint,
        );
      }
    }

    // 4. Hours / duration in center (e.g. 1h, 1.5h, 2h, 45m, 24h)
    final baseFontSize = centerText.length <= 2
        ? 20.0
        : centerText.length <= 4
        ? 14.5
        : 11.5;
    final fontSize = baseFontSize * scale;

    final textSpan = TextSpan(
      text: centerText,
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.3,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final textOffset = Offset(
      center.dx - textPainter.width / 2,
      center.dy - textPainter.height / 2,
    );
    textPainter.paint(canvas, textOffset);
  }

  @override
  bool shouldRepaint(covariant _MiniSectorDialPainter oldDelegate) {
    return oldDelegate.startTime != startTime ||
        oldDelegate.endTime != endTime ||
        oldDelegate.color != color ||
        oldDelegate.centerText != centerText ||
        oldDelegate.isAllDay != isAllDay;
  }
}
