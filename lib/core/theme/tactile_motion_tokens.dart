import 'package:flutter/animation.dart';

/// Standardized tactile motion tokens and bouncy spring physics
/// from Google Material 3 Expressive (JustForPixel-ExpressiveLab).
class TactileMotionTokens {
  TactileMotionTokens._();

  /// Pronounced scale reduction factor for Floating Action Buttons (FABs)
  static const double pressScaleFab = 0.88;

  /// Standard scale reduction factor for interactive buttons, chips, and toggles
  static const double pressScaleStandard = 0.92;

  /// Subtle scale reduction factor for cards and list tiles
  static const double pressScaleCard = 0.96;

  /// Playful spring overshoot curve for press release
  static const Curve bouncySpringCurve = Curves.easeOutBack;

  /// Smooth, non-overshooting curve for structural motion
  static const Curve gentleSpringCurve = Curves.easeOutCubic;

  /// Compression curve when the user depresses their finger
  static const Curve pressDownCurve = Curves.easeOutQuad;

  /// Standard press-down duration
  static const Duration pressDownDuration = Duration(milliseconds: 90);

  /// Spring-back release duration
  static const Duration springBackDuration = Duration(milliseconds: 240);
}
