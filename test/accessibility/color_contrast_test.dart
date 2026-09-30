import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/core/constants/app_presets.dart';
import 'package:sectograph_mcp/core/utils/color_contrast.dart';

void main() {
  group('ColorContrast Luminance and Ratio Calculations', () {
    test('pure black and pure white extremes', () {
      expect(ColorContrast.computeLuminance(const Color(0xFF000000)), 0.0);
      expect(ColorContrast.computeLuminance(const Color(0xFFFFFFFF)), 1.0);

      final ratio = ColorContrast.contrastRatio(
        const Color(0xFF000000),
        const Color(0xFFFFFFFF),
      );
      expect(ratio, closeTo(21.0, 0.01));
    });

    test('identical colors yield 1.0 contrast ratio', () {
      const red = Color(0xFFFF0000);
      expect(ColorContrast.contrastRatio(red, red), closeTo(1.0, 0.01));
    });

    test('isWcagAaCompliant evaluates normal and large text thresholds', () {
      // Black vs White (21:1) is compliant for both
      expect(
        ColorContrast.isWcagAaCompliant(
          const Color(0xFF000000),
          const Color(0xFFFFFFFF),
          isLargeText: false,
        ),
        isTrue,
      );

      // 4.5:1 is required for normal text, 3.0:1 for large text
      // Test intermediate gray
      const gray = Color(0xFF767676); // ~4.54:1 against white
      expect(
        ColorContrast.isWcagAaCompliant(
          gray,
          const Color(0xFFFFFFFF),
          isLargeText: false,
        ),
        isTrue,
      );

      const lightGray = Color(0xFF949494); // ~3.0:1 against white
      expect(
        ColorContrast.isWcagAaCompliant(
          lightGray,
          const Color(0xFFFFFFFF),
          isLargeText: false,
        ),
        isFalse,
      );
      expect(
        ColorContrast.isWcagAaCompliant(
          lightGray,
          const Color(0xFFFFFFFF),
          isLargeText: true,
        ),
        isTrue,
      );
    });
  });

  group('ColorContrast getHighContrastTextColor', () {
    test('selects dark text for light or bright colors', () {
      // Pure white background
      expect(
        ColorContrast.getHighContrastTextColor(const Color(0xFFFFFFFF)),
        ColorContrast.darkText,
      );

      // Bright yellow background
      expect(
        ColorContrast.getHighContrastTextColor(const Color(0xFFFFEB3B)),
        ColorContrast.darkText,
      );

      // Light amber background
      expect(
        ColorContrast.getHighContrastTextColor(const Color(0xFFFDE68A)),
        ColorContrast.darkText,
      );
    });

    test('selects light text for dark backgrounds', () {
      // Pure black background
      expect(
        ColorContrast.getHighContrastTextColor(const Color(0xFF000000)),
        ColorContrast.lightText,
      );

      // Deep navy background
      expect(
        ColorContrast.getHighContrastTextColor(const Color(0xFF0F172A)),
        ColorContrast.lightText,
      );

      // Dark purple background
      expect(
        ColorContrast.getHighContrastTextColor(const Color(0xFF3B0764)),
        ColorContrast.lightText,
      );
    });

    test('maximizes contrast across all default palette colors', () {
      for (final hex in AppPresets.defaultColorPalette) {
        final cleanHex = hex.replaceFirst('#', '');
        final color = Color(int.parse('FF$cleanHex', radix: 16));

        final textColor = ColorContrast.getHighContrastTextColor(color);
        final ratio = ColorContrast.contrastRatio(textColor, color);

        // Every default preset color must provide strong contrast (> 3.0:1) with selected text
        expect(
          ratio,
          greaterThanOrEqualTo(3.0),
          reason: 'Color $hex with text $textColor yielded poor contrast $ratio',
        );
      }
    });
  });

  group('ColorContrast evaluateSectorColor', () {
    test('evaluates compliant high-contrast color', () {
      const darkBlue = Color(0xFF1E3A8A);
      final eval = ColorContrast.evaluateSectorColor(darkBlue);

      expect(eval.recommendedTextColor, ColorContrast.lightText);
      expect(eval.textContrastRatio, greaterThan(4.5));
      expect(eval.isCompliant, isTrue);
      expect(eval.warningMessage, isNull);
    });

    test('generates warning message for poor contrast against surface', () {
      // Nearly black color against dark dial background
      const nearBlack = Color(0xFF141414);
      final eval = ColorContrast.evaluateSectorColor(
        nearBlack,
        surfaceColor: const Color(0xFF121212),
      );

      expect(eval.isCompliant, isFalse);
      expect(eval.warningMessage, contains('blends with the dial background'));
    });
  });
}
