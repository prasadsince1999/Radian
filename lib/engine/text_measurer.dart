/// Pure Dart text measurement contract and fast script-aware estimator (§4.5).
class TextDimensions {
  final double width;
  final double height;

  const TextDimensions({required this.width, required this.height});
  static const TextDimensions zero = TextDimensions(width: 0.0, height: 0.0);

  @override
  String toString() =>
      'TextDimensions(${width.toStringAsFixed(1)}x${height.toStringAsFixed(1)})';
}

/// Abstract text measurer interface.
///
/// In Flutter environments, backed by [TextMeasurementService] via cached [TextPainter].
/// In pure Dart environments (CLI, engine tests), backed by [FastTextMeasurer].
abstract class TextMeasurer {
  const TextMeasurer();

  TextDimensions measure(
    String text, {
    double fontSize = 12.0,
    String? fontFamily,
    String? locale,
  });
}

/// Pure Dart fast text measurer that estimates typographic dimensions based on Unicode scripts.
///
/// Provides deterministic measurements in CLI and pure engine environments without Flutter.
class FastTextMeasurer extends TextMeasurer {
  const FastTextMeasurer();

  @override
  TextDimensions measure(
    String text, {
    double fontSize = 12.0,
    String? fontFamily,
    String? locale,
  }) {
    if (text.isEmpty) return TextDimensions.zero;

    double totalWidth = 0.0;
    for (final rune in text.runes) {
      // CJK Unified Ideographs, Hangul, Katakana, Hiragana
      if ((rune >= 0x4E00 && rune <= 0x9FFF) ||
          (rune >= 0x3400 && rune <= 0x4DBF) ||
          (rune >= 0xAC00 && rune <= 0xD7AF) ||
          (rune >= 0x3040 && rune <= 0x30FF)) {
        totalWidth += fontSize * 1.05;
      }
      // Indic scripts (Devanagari 0900..097F, Bengali 0980..09FF, Odia 0B00..0B7F, Tamil 0B80..0BFF, Telugu 0C00..0C7F)
      else if (rune >= 0x0900 && rune <= 0x0D7F) {
        totalWidth += fontSize * 0.75;
      }
      // Arabic / Hebrew (0590..06FF)
      else if (rune >= 0x0590 && rune <= 0x06FF) {
        totalWidth += fontSize * 0.62;
      }
      // Narrow latin punctuation and numerals (i, l, 1, ., :, etc.)
      else if (rune == 0x20 ||
          rune == 0x2E ||
          rune == 0x3A ||
          rune == 0x69 ||
          rune == 0x6C ||
          rune == 0x31) {
        totalWidth += fontSize * 0.32;
      }
      // Wide latin uppercase (M, W, etc.)
      else if (rune == 0x4D || rune == 0x57) {
        totalWidth += fontSize * 0.85;
      }
      // Standard Latin / Digits
      else {
        totalWidth += fontSize * 0.58;
      }
    }

    return TextDimensions(width: totalWidth, height: fontSize * 1.25);
  }
}
