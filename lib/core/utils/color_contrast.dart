import 'dart:math' as math;
import 'package:flutter/material.dart';

/// WCAG 2.2 contrast compliance evaluation and high-contrast color solver (§5.4, §7 Phase 7).
class ColorContrast {
  const ColorContrast._();

  /// Standard dark charcoal text color for light backgrounds.
  static const Color darkText = Color(0xFF1E1A16);

  /// Standard warm off-white text color for dark backgrounds.
  static const Color lightText = Color(0xFFF7F3EE);

  /// Pure black.
  static const Color pureBlack = Color(0xFF000000);

  /// Pure white.
  static const Color pureWhite = Color(0xFFFFFFFF);

  /// Calculates the WCAG relative luminance of a [Color] on a scale of 0.0 (darkest black) to 1.0 (lightest white).
  ///
  /// Formula: L = 0.2126 * R_lin + 0.7152 * G_lin + 0.0722 * B_lin.
  static double computeLuminance(Color color) {
    // Flutter's color.computeLuminance() natively implements the IEC 61966-2-1 standard
    return color.computeLuminance();
  }

  /// Calculates the WCAG 2.2 contrast ratio between two colors.
  ///
  /// Returns a value between 1.0 (identical) and 21.0 (black vs white).
  /// Formula: (L1 + 0.05) / (L2 + 0.05) where L1 is the lighter luminance.
  static double contrastRatio(Color foreground, Color background) {
    final double l1 = computeLuminance(foreground);
    final double l2 = computeLuminance(background);
    final double lighter = math.max(l1, l2);
    final double darker = math.min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Determines whether [foreground] and [background] meet WCAG 2.2 Level AA requirements.
  ///
  /// - Normal text (< 18pt or < 14pt bold): minimum 4.5:1.
  /// - Large text (≥ 18pt or ≥ 14pt bold): minimum 3.0:1.
  static bool isWcagAaCompliant(
    Color foreground,
    Color background, {
    bool isLargeText = false,
  }) {
    final double ratio = contrastRatio(foreground, background);
    return isLargeText ? ratio >= 3.0 : ratio >= 4.5;
  }

  /// Selects the optimal text color ([lightText] or [darkText]) that maximizes
  /// contrast ratio on [background], guaranteeing the best possible legibility.
  static Color getHighContrastTextColor(Color background) {
    final double lightRatio = contrastRatio(lightText, background);
    final double darkRatio = contrastRatio(darkText, background);

    if (lightRatio >= darkRatio) {
      // If lightText doesn't even hit 4.5:1, test pureWhite as fallback
      if (lightRatio < 4.5 && contrastRatio(pureWhite, background) >= 4.5) {
        return pureWhite;
      }
      return lightText;
    } else {
      if (darkRatio < 4.5 && contrastRatio(pureBlack, background) >= 4.5) {
        return pureBlack;
      }
      return darkText;
    }
  }

  /// Evaluates an event sector color against dial background and reports whether
  /// it satisfies WCAG 2.2 readability thresholds.
  static ContrastEvaluation evaluateSectorColor(
    Color sectorColor, {
    Color surfaceColor = const Color(0xFF121212),
  }) {
    final textColor = getHighContrastTextColor(sectorColor);
    final textRatio = contrastRatio(textColor, sectorColor);
    final sectorToSurfaceRatio = contrastRatio(sectorColor, surfaceColor);

    final bool isTextCompliant = textRatio >= 4.5;
    final bool isSectorDistinct = sectorToSurfaceRatio >= 1.5;

    return ContrastEvaluation(
      sectorColor: sectorColor,
      recommendedTextColor: textColor,
      textContrastRatio: textRatio,
      sectorToSurfaceRatio: sectorToSurfaceRatio,
      isCompliant: isTextCompliant && isSectorDistinct,
      warningMessage: !isTextCompliant
          ? 'Text on this color has low contrast (${textRatio.toStringAsFixed(1)}:1 < 4.5:1).'
          : (!isSectorDistinct
              ? 'This color blends with the dial background (${sectorToSurfaceRatio.toStringAsFixed(1)}:1).'
              : null),
    );
  }
}

/// Result of evaluating a color for WCAG accessibility.
class ContrastEvaluation {
  final Color sectorColor;
  final Color recommendedTextColor;
  final double textContrastRatio;
  final double sectorToSurfaceRatio;
  final bool isCompliant;
  final String? warningMessage;

  const ContrastEvaluation({
    required this.sectorColor,
    required this.recommendedTextColor,
    required this.textContrastRatio,
    required this.sectorToSurfaceRatio,
    required this.isCompliant,
    this.warningMessage,
  });
}
