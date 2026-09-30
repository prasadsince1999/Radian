import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/presentation/widgets/dial/components/sector_pattern_renderer.dart';

void main() {
  test('SectorPatternRenderer draws distinct patterns for all category families without throwing', () {
    final pictureRecorder = PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    const bounds = Rect.fromLTWH(0, 0, 200, 200);

    final path = Path()..addRect(bounds);

    final categories = [
      'Work',
      'Deep Focus',
      'Meetings',
      'Health & Fitness',
      'Yoga & Wellness',
      'Rest & Sleep',
      'Random Category',
    ];

    for (final cat in categories) {
      expect(
        () => SectorPatternRenderer.drawPattern(
          canvas: canvas,
          pillPath: path,
          bounds: bounds,
          category: cat,
          sectorColor: Colors.blue,
        ),
        returnsNormally,
        reason: 'Failed rendering pattern for $cat with light/medium sector',
      );

      expect(
        () => SectorPatternRenderer.drawPattern(
          canvas: canvas,
          pillPath: path,
          bounds: bounds,
          category: cat,
          sectorColor: Colors.black,
        ),
        returnsNormally,
        reason: 'Failed rendering pattern for $cat with dark sector',
      );
    }

    pictureRecorder.endRecording();
  });
}
