import 'package:flutter/material.dart';

/// Centralized typographic tokens and international font fallbacks (§5.4).
class AppTypography {
  const AppTypography._();

  /// Comprehensive Noto font family fallbacks covering Indian scripts (Devanagari, Bengali, Odia, Tamil, Telugu),
  /// Arabic/Hebrew, and CJK (Simplified Chinese, Japanese).
  ///
  /// Used for Canvas text rendering ([TextPainter]) in both the in-app dial and widget frame generation.
  static const List<String> fontFamilyFallback = [
    'Noto Sans',
    'Noto Sans Devanagari',
    'Noto Sans Bengali',
    'Noto Sans Oriya',
    'Noto Sans Tamil',
    'Noto Sans Telugu',
    'Noto Sans Arabic',
    'Noto Sans CJK SC',
    'Noto Sans JP',
    'sans-serif',
  ];

  /// Creates a [TextStyle] with international Noto fallbacks and optional tabular figures.
  static TextStyle dialTextStyle({
    double fontSize = 11.0,
    FontWeight fontWeight = FontWeight.w600,
    Color color = Colors.white,
    bool tabularFigures = false,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      fontFamilyFallback: fontFamilyFallback,
      fontFeatures: tabularFigures ? const [FontFeature.tabularFigures()] : null,
    );
  }
}
