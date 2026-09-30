import 'dart:collection';

import 'package:flutter/material.dart';

import '../../engine/text_measurer.dart';
import '../theme/app_typography.dart';

/// Flutter TextPainter-backed text measurement service with an LRU cache (§4.5).
///
/// Implements [TextMeasurer] using actual Flutter typography layout.
/// Used during in-app rendering and widget frame precomputation.
class TextMeasurementService extends TextMeasurer {
  static final TextMeasurementService instance = TextMeasurementService._();
  TextMeasurementService._();

  static const int maxCacheEntries = 1000;
  final LinkedHashMap<String, TextDimensions> _cache =
      LinkedHashMap<String, TextDimensions>();

  @override
  TextDimensions measure(
    String text, {
    double fontSize = 12.0,
    String? fontFamily,
    String? locale,
  }) {
    if (text.isEmpty) return TextDimensions.zero;

    final key = '$text|$fontSize|$fontFamily|$locale';
    final cached = _cache[key];
    if (cached != null) {
      // Re-insert to refresh LRU order
      _cache.remove(key);
      _cache[key] = cached;
      return cached;
    }

    final isRtl = locale != null && (locale.startsWith('ar') || locale.startsWith('he') || locale.startsWith('fa') || locale.startsWith('ur'));
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontFamily: fontFamily,
          fontFamilyFallback: AppTypography.fontFamilyFallback,
        ),
      ),
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      locale: locale != null ? Locale(locale) : null,
    )..layout();

    final result = TextDimensions(width: tp.width, height: tp.height);

    if (_cache.length >= maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = result;

    return result;
  }

  /// Clears the LRU cache.
  void clearCache() {
    _cache.clear();
  }

  /// Current number of cached measurements.
  int get cacheSize => _cache.length;
}
