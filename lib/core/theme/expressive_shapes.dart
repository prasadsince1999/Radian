import 'package:flutter/material.dart';

/// Material 3 Expressive shape tokens.
class ExpressiveShapes {
  ExpressiveShapes._();

  static const double cornerXs = 4.0;
  static const double cornerSm = 8.0;
  static const double cornerMd = 12.0;
  static const double cornerLg = 16.0;
  static const double cornerXl = 24.0;
  static const double cornerXxl = 28.0;
  static const double cornerFull = 999.0;

  static final RoundedRectangleBorder xs = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(cornerXs),
  );

  static final RoundedRectangleBorder sm = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(cornerSm),
  );

  static final RoundedRectangleBorder md = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(cornerMd),
  );

  static final RoundedRectangleBorder lg = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(cornerLg),
  );

  static final RoundedRectangleBorder xl = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(cornerXl),
  );

  static final RoundedRectangleBorder xxl = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(cornerXxl),
  );

  static final RoundedRectangleBorder full = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(cornerFull),
  );

  /// Expressive asymmetric corner geometry for event cards and badges.
  static final RoundedRectangleBorder asymmetricCard = RoundedRectangleBorder(
    borderRadius: const BorderRadius.only(
      topLeft: Radius.circular(cornerXl),
      bottomRight: Radius.circular(cornerXl),
      topRight: Radius.circular(cornerMd),
      bottomLeft: Radius.circular(cornerMd),
    ),
  );

  /// Continuous-curvature squircle border for modal bottom sheets (G2 continuity).
  static const ContinuousRectangleBorder modalSheet = ContinuousRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(44)),
  );

  /// Continuous-curvature squircle border for dialogs and floating cards.
  static const ContinuousRectangleBorder squircleCard =
      ContinuousRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(28)),
      );

  /// Asymmetric squircle border for expressive event cards.
  static const ContinuousRectangleBorder asymmetricSquircleCard =
      ContinuousRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
          topRight: Radius.circular(24),
          bottomLeft: Radius.circular(24),
        ),
      );

  /// Continuous-curvature squircle border helper with optional border side.
  static ContinuousRectangleBorder squircle(
    double radius, {
    BorderSide side = BorderSide.none,
  }) => ContinuousRectangleBorder(
    side: side,
    borderRadius: BorderRadius.circular(radius * 1.5),
  );
}
