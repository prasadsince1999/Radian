import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/core/layout/window_size_class.dart';

void main() {
  group('WindowSizeClass Tests', () {
    test('classifies compact width (< 600dp)', () {
      final wsc = WindowSizeClass.calculate(const Size(390, 844));
      expect(wsc.widthClass, WindowWidthSizeClass.compact);
      expect(wsc.isCompactWidth, isTrue);
      expect(wsc.isTwoPane, isFalse);
      expect(wsc.isThreePane, isFalse);
    });

    test('classifies medium width (600dp - 840dp)', () {
      final wsc = WindowSizeClass.calculate(const Size(700, 900));
      expect(wsc.widthClass, WindowWidthSizeClass.medium);
      expect(wsc.isMediumWidth, isTrue);
      expect(wsc.isTwoPane, isTrue);
      expect(wsc.isThreePane, isFalse);
    });

    test('classifies expanded width (>= 840dp)', () {
      final wsc = WindowSizeClass.calculate(const Size(1200, 800));
      expect(wsc.widthClass, WindowWidthSizeClass.expanded);
      expect(wsc.isExpandedWidth, isTrue);
      expect(wsc.isTwoPane, isTrue);
      expect(wsc.isThreePane, isTrue);
    });

    test('classifies compact height (< 480dp)', () {
      final wsc = WindowSizeClass.calculate(const Size(800, 390));
      expect(wsc.heightClass, WindowHeightSizeClass.compact);
      expect(wsc.isCompactHeight, isTrue);
    });

    test('derives from BoxConstraints correctly', () {
      const constraints = BoxConstraints(maxWidth: 500, maxHeight: 950);
      final wsc = WindowSizeClass.fromBoxConstraints(constraints);
      expect(wsc.widthClass, WindowWidthSizeClass.compact);
      expect(wsc.heightClass, WindowHeightSizeClass.expanded);
    });
  });
}
