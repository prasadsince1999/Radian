import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Interactive color picker dialog featuring a circular HSV spectrum wheel,
/// preview swatch, recent color palette, and CANCEL/OK actions.
class ColorWheelDialog extends StatefulWidget {
  final Color initialColor;

  const ColorWheelDialog({super.key, required this.initialColor});

  static Future<Color?> show(BuildContext context, Color initialColor) {
    return showDialog<Color>(
      context: context,
      builder: (ctx) => ColorWheelDialog(initialColor: initialColor),
    );
  }

  @override
  State<ColorWheelDialog> createState() => _ColorWheelDialogState();
}

class _ColorWheelDialogState extends State<ColorWheelDialog> {
  late Color _currentColor;
  late double _hue;
  late double _saturation;

  static const List<Color> _presetColors = [
    Color(0xFFFFEB3B), // Yellow
    Color(0xFFFFCDD2), // Soft Pink
    Color(0xFFFF00E5), // Neon Magenta
    Color(0xFFE0E0E0), // Light Grey
    Color(0xFFB0BEC5), // Silver Grey
    Color(0xFF00E5FF), // Cyan
    Color(0xFF00E676), // Bright Green
    Color(0xFFFF6D00), // Deep Orange
    Color(0xFF7C4DFF), // Purple
    Color(0xFF2979FF), // Sky Blue
  ];

  @override
  void initState() {
    super.initState();
    _currentColor = widget.initialColor;
    final hsv = HSVColor.fromColor(_currentColor);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
  }

  void _updateColorFromWheel(Offset localPosition, double radius) {
    final dx = localPosition.dx - radius;
    final dy = localPosition.dy - radius;
    final distance = math.sqrt(dx * dx + dy * dy);
    final sat = (distance / radius).clamp(0.0, 1.0);

    // Angle in degrees from 0 to 360
    var angle = math.atan2(dy, dx) * 180 / math.pi;
    if (angle < 0) angle += 360;

    setState(() {
      _hue = angle;
      _saturation = sat;
      _currentColor = HSVColor.fromAHSV(1.0, _hue, _saturation, 1.0).toColor();
    });
  }

  void _selectPreset(Color c) {
    final hsv = HSVColor.fromColor(c);
    setState(() {
      _currentColor = c;
      _hue = hsv.hue;
      _saturation = hsv.saturation;
    });
  }

  @override
  Widget build(BuildContext context) {
    const wheelSize = 210.0;
    const wheelRadius = wheelSize / 2;

    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1.2),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose color',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 16),

            // Color Wheel
            Center(
              child: SizedBox(
                width: wheelSize,
                height: wheelSize,
                child: GestureDetector(
                  onPanDown: (details) =>
                      _updateColorFromWheel(details.localPosition, wheelRadius),
                  onPanUpdate: (details) =>
                      _updateColorFromWheel(details.localPosition, wheelRadius),
                  child: CustomPaint(
                    size: const Size(wheelSize, wheelSize),
                    painter: _ColorWheelPainter(
                      hue: _hue,
                      saturation: _saturation,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Selected Color Preview Swatch
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _currentColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 2.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Recent Colors Header
            const Text(
              'Recent Colors',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 10),

            // 2x5 Palette Grid
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _presetColors.take(5).map((color) {
                    final isSelected =
                        color.toARGB32() == _currentColor.toARGB32();
                    return _buildColorTile(color, isSelected);
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _presetColors.skip(5).take(5).map((color) {
                    final isSelected =
                        color.toARGB32() == _currentColor.toARGB32();
                    return _buildColorTile(color, isSelected);
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Action Buttons (CANCEL / OK)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'CANCEL',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(_currentColor),
                  child: Text(
                    'OK',
                    style: TextStyle(
                      color: _currentColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorTile(Color color, bool isSelected) {
    return GestureDetector(
      onTap: () => _selectPreset(color),
      child: Container(
        width: 44,
        height: 38,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? Colors.white : AppColors.cardBorder,
            width: isSelected ? 2.2 : 1.0,
          ),
        ),
      ),
    );
  }
}

class _ColorWheelPainter extends CustomPainter {
  final double hue;
  final double saturation;

  _ColorWheelPainter({required this.hue, required this.saturation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Draw 360-degree Hue sweep gradient
    const sweepColors = [
      Color(0xFFFF0000), // Red 0°
      Color(0xFFFFFF00), // Yellow 60°
      Color(0xFF00FF00), // Green 120°
      Color(0xFF00FFFF), // Cyan 180°
      Color(0xFF0000FF), // Blue 240°
      Color(0xFFFF00FF), // Magenta 300°
      Color(0xFFFF0000), // Red 360°
    ];

    final sweepPaint = Paint()
      ..shader = const SweepGradient(colors: sweepColors)
          .createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, sweepPaint);

    // 2. Overlay radial gradient from white (saturation = 0 at center) to transparent (saturation = 1 at outer edge)
    final radialPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, Colors.white.withValues(alpha: 0.0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, radialPaint);

    // 3. Draw Touch Indicator Handle
    final rad = hue * math.pi / 180;
    final dist = saturation * radius;
    final handlePos = Offset(
      center.dx + dist * math.cos(rad),
      center.dy + dist * math.sin(rad),
    );

    final handleBorderPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    final handleInnerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(handlePos, 9, handleBorderPaint);
    canvas.drawCircle(handlePos, 9, handleInnerPaint);
  }

  @override
  bool shouldRepaint(covariant _ColorWheelPainter oldDelegate) {
    return oldDelegate.hue != hue || oldDelegate.saturation != saturation;
  }
}
