/// Supported numeral systems for dial labels and time displays (§5.4).
enum NumeralSystem {
  /// Standard Western Arabic numerals (0, 1, 2, 3, 4, 5, 6, 7, 8, 9).
  latin,

  /// Devanagari numerals (०, १, २, ३, ४, ५, ६, ७, ८, ९) used in Hindi, Marathi, Nepali.
  devanagari,

  /// Bengali-Assamese numerals (০, ১, ২, ৩, ৪, ৫, ৬, ৭, ৮, ৯).
  bengali,

  /// Odia numerals (୦, ୧, ୨, ୩, ୪, ୫, ୬, ୭, ୮, ୯).
  odia,

  /// Arabic-Indic numerals (٠, ١, ٢, ٣, ٤, ٥, ٦, ٧, ٨, ٩) used in Arabic.
  arabicIndic,
}

/// Utility for translating digits between Western Arabic (ASCII) and native numeral scripts.
class NumeralConverter {
  const NumeralConverter._();

  static const Map<NumeralSystem, List<String>> _digits = {
    NumeralSystem.latin: ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'],
    NumeralSystem.devanagari: [
      '०',
      '१',
      '२',
      '३',
      '४',
      '५',
      '६',
      '७',
      '८',
      '९',
    ],
    NumeralSystem.bengali: ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'],
    NumeralSystem.odia: ['୦', '୧', '୨', '୩', '୪', '୫', '୬', '୭', '୮', '୯'],
    NumeralSystem.arabicIndic: [
      '٠',
      '١',
      '٢',
      '٣',
      '٤',
      '٥',
      '٦',
      '٧',
      '٨',
      '٩',
    ],
  };

  /// Converts any ASCII digits [0-9] in [input] to the requested [system], preserving all punctuation and non-digit characters.
  static String convert(String input, NumeralSystem system) {
    if (system == NumeralSystem.latin || input.isEmpty) {
      return input;
    }

    final targetDigits = _digits[system];
    if (targetDigits == null) return input;

    final sb = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final codeUnit = input.codeUnitAt(i);
      // '0' is 48, '9' is 57
      if (codeUnit >= 48 && codeUnit <= 57) {
        sb.write(targetDigits[codeUnit - 48]);
      } else {
        sb.write(input[i]);
      }
    }
    return sb.toString();
  }

  /// Converts an integer directly to a string in the requested [system].
  static String formatInt(int value, NumeralSystem system) {
    return convert(value.toString(), system);
  }
}
