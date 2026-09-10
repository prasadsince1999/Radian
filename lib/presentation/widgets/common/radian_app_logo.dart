import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Pure vector representation of the official Radian APK launcher icon.
///
/// Faithfully reproduces the vector geometry from `ic_launcher_foreground.xml`:
/// - Slate obsidian circular base (`#0B0F19`)
/// - Outer dial track ring (`#1E293B`)
/// - Cardinal hour ticks (`#475569`)
/// - Indigo sector: 12:00 to 4:00 (`#6366F1`)
/// - Sky cyan sector: 4:00 to 6:30 (`#38BDF8`)
/// - Inner core knockout (`#0B0F19`) with rim border (`#334155`)
/// - Active coral needle (`#F43F5E`) pointing at 4:00
/// - Center pivot hub (white ring `#FFFFFF` with coral dot `#F43F5E`)
///
/// Rendered flat with NO shadow or gradient backdrop per user specification.
class RadianAppLogo extends StatelessWidget {
  const RadianAppLogo({super.key, this.size = 72.0});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: const _RadianAppLogoPainter(),
      ),
    );
  }
}

class _RadianAppLogoPainter extends CustomPainter {
  const _RadianAppLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Standard viewport is 108 x 108 from ic_launcher_foreground.xml
    const referenceSize = 108.0;
    final scale = size.width / referenceSize;

    canvas.save();
    canvas.scale(scale, scale);

    const center = Offset(54.0, 54.0);

    // 1. Dark Slate Obsidian Circular Base (#0B0F19)
    final bgPaint = Paint()
      ..color = const Color(0xFF0B0F19)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 52.0, bgPaint);

    // Subtle outline rim for crisp contrast on dark sheets
    final bgRimPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, 51.4, bgRimPaint);

    // 2. Outer Dial Track Ring (Radius 30, strokeWidth 3)
    final trackPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawCircle(center, 30.0, trackPaint);

    // 3. Primary Time Block Sector (Indigo: 12:00 to 4:00 = -90° to 30°, sweep 120°)
    final indigoPaint = Paint()
      ..color = const Color(0xFF6366F1)
      ..style = PaintingStyle.fill;
    final sectorRect = Rect.fromCircle(center: center, radius: 30.0);
    final indigoPath = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(sectorRect, -math.pi / 2, (2 * math.pi / 3), false)
      ..close();
    canvas.drawPath(indigoPath, indigoPaint);

    // 4. Secondary Time Block Sector (Sky Cyan: 4:00 to 6:30 = 30° to 105°, sweep 75°)
    final cyanPaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..style = PaintingStyle.fill;
    final cyanPath = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(sectorRect, math.pi / 6, (75.0 * math.pi / 180.0), false)
      ..close();
    canvas.drawPath(cyanPath, cyanPaint);

    // 5. Cardinal Hour Tick Marks (12, 3, 6, 9)
    final tickPaint = Paint()
      ..color = const Color(0xFF475569)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    // 12 o'clock: (54, 24) to (54, 28)
    canvas.drawLine(const Offset(54, 24), const Offset(54, 28), tickPaint);
    // 3 o'clock: (84, 54) to (80, 54)
    canvas.drawLine(const Offset(84, 54), const Offset(80, 54), tickPaint);
    // 6 o'clock: (54, 84) to (54, 80)
    canvas.drawLine(const Offset(54, 84), const Offset(54, 80), tickPaint);
    // 9 o'clock: (24, 54) to (28, 54)
    canvas.drawLine(const Offset(24, 54), const Offset(28, 54), tickPaint);

    // 6. Center Core Knockout (#0B0F19, radius 16)
    final corePaint = Paint()
      ..color = const Color(0xFF0B0F19)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 16.0, corePaint);

    // 7. Inner Core Rim Guide (#334155, strokeWidth 1.2)
    final coreRimPaint = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, 16.0, coreRimPaint);

    // 8. Active Time Needle (Coral / Rose #F43F5E from center 54,54 to 80.8, 69.5)
    final needlePaint = Paint()
      ..color = const Color(0xFFF43F5E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, const Offset(80.8, 69.5), needlePaint);

    // 9. Center Pivot Hub (white ring radius 5.5, coral dot radius 2.5)
    final pivotRingPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, 5.5, corePaint); // Fill inner hub with #0B0F19
    canvas.drawCircle(center, 5.5, pivotRingPaint);

    final pivotDotPaint = Paint()
      ..color = const Color(0xFFF43F5E)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 2.5, pivotDotPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
