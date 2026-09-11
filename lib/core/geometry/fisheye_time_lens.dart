import 'dart:math' as math;

import 'sector_math.dart';

/// Pure mathematical transformation for Focus + Context ("Fisheye Lens") on circular dials.
///
/// Warps dial angles such that the active / focused time block receives an expanded
/// angular span (e.g. 1.7x–2.0x magnification), while the remaining non-active hours
/// smoothly and gently compress (squeeze) towards the opposite side of the dial.
///
/// Mathematical properties:
/// 1. Closed-form rational lens: f(x) = M*x / (1 + (M - 1)*|x|) for x in [-1, 1].
/// 2. Strictly monotonic: df/dx > 0 everywhere in [-1, 1], guaranteeing that events
///    never swap positions or overlap chronologically.
/// 3. Exact endpoints: f(-1) = -1, f(0) = 0, f(1) = 1, ensuring the total circle remains
///    strictly 360 degrees.
/// 4. Bounded derivative: Local slope at focus is exactly M (finite magnification),
///    and at the opposite point is 1/M (finite compression).
/// 5. Analytical inverse: Exact O(1) inverse mapping for pixel/touch hit-testing.
class FisheyeTimeLens {
  /// Magnification factor at the focus point (typically 1.5 to 2.2).
  /// A value of 1.0 represents a standard linear dial (zero distortion).
  final double magnification;

  /// The center angle in degrees [0, 360) where maximum magnification occurs.
  final double focusAngle;

  const FisheyeTimeLens({this.magnification = 1.75, required this.focusAngle});

  /// Identity lens with no distortion.
  const FisheyeTimeLens.linear() : magnification = 1.0, focusAngle = 0.0;

  /// Returns true if this lens performs active distortion.
  bool get isDistorted => (magnification - 1.0).abs() > 0.001;

  /// Warps a linear dial angle [angleDeg] into its distorted position.
  /// Both input and output are in degrees in the range [0.0, 360.0).
  double warpAngle(double angleDeg) {
    if (!isDistorted) return SectorMath.normalizeDegrees(angleDeg);

    final normalized = SectorMath.normalizeDegrees(angleDeg);
    // Angular difference relative to focus angle, wrapped to [-180, 180]
    final diff = _normalizeDelta(normalized - focusAngle);
    final x = diff / 180.0; // [-1.0, 1.0]

    // Rational lens transformation
    final m = magnification;
    final absX = x.abs();
    final warpedX = (m * x) / (1.0 + (m - 1.0) * absX);

    final warpedDiff = warpedX * 180.0;
    return SectorMath.normalizeDegrees(focusAngle + warpedDiff);
  }

  /// Inverse warp: converts a distorted visual angle back to the true linear dial angle.
  /// Essential for polar hit-testing (touch to event mapping).
  double unwarpAngle(double visualAngleDeg) {
    if (!isDistorted) return SectorMath.normalizeDegrees(visualAngleDeg);

    final normalized = SectorMath.normalizeDegrees(visualAngleDeg);
    final diff = _normalizeDelta(normalized - focusAngle);
    final y = diff / 180.0; // [-1.0, 1.0]

    // Analytical inverse of y = M*x / (1 + (M - 1)*|x|)
    // |y| = M*|x| / (1 + (M - 1)*|x|) => |x| = |y| / (M - (M - 1)*|y|)
    final m = magnification;
    final absY = y.abs();
    final denom = m - (m - 1.0) * absY;
    if (denom <= 0.0) return normalized;

    final x = y / denom;
    final unwarpedDiff = x * 180.0;
    return SectorMath.normalizeDegrees(focusAngle + unwarpedDiff);
  }

  /// Warps an angular sector defined by [startDeg] and [sweepDeg].
  ///
  /// Returns a record with the warped start angle and the resulting warped sweep angle.
  ({double startDeg, double sweepDeg}) warpSector({
    required double startDeg,
    required double sweepDeg,
  }) {
    if (!isDistorted || sweepDeg <= 0.0) {
      return (
        startDeg: SectorMath.normalizeDegrees(startDeg),
        sweepDeg: sweepDeg,
      );
    }

    if (sweepDeg >= 360.0) {
      return (startDeg: startDeg, sweepDeg: 360.0);
    }

    final endDeg = startDeg + sweepDeg;
    final warpedStart = warpAngle(startDeg);
    final warpedEnd = warpAngle(endDeg);

    var warpedSweep = warpedEnd - warpedStart;
    if (warpedSweep < 0) {
      warpedSweep += 360.0;
    }

    // Guard against floating point micro-collapses
    warpedSweep = math.max(warpedSweep, 1.0);

    return (startDeg: warpedStart, sweepDeg: warpedSweep);
  }

  static double _normalizeDelta(double delta) {
    var d = delta % 360.0;
    if (d > 180.0) d -= 360.0;
    if (d < -180.0) d += 360.0;
    return d;
  }
}
