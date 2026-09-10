import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'sector_math.dart';

/// Hit test target interface for circular sectors.
abstract class HitTestableSector {
  double get startAngle;
  double get sweepAngle;
  int get topLevel;
  int get bottomLevel;
}

/// Hit-testing algorithm for circular clock sectors.
///
/// Ported from Sectograph (`y3/n.java:279-360`).
class PolarHitTest {
  PolarHitTest._();

  /// Checks which [HitTestableSector] in [sectors] was tapped by [localOffset]
  /// relative to the dial [center].
  ///
  /// [innerRadius] is the inner hole radius.
  /// [outerRadius] is the outer rim radius.
  /// [touchSlopDegrees] is the angular tolerance buffer (default 4.0°).
  static T? findTappedSector<T extends HitTestableSector>({
    required Offset localOffset,
    required Offset center,
    required double innerRadius,
    required double outerRadius,
    required List<T> sectors,
    double touchSlopDegrees = 4.0,
    double? angleOverride,
    ({double rIn, double rOut}) Function(T sector)? getRadii,
  }) {
    final dx = localOffset.dx - center.dx;
    final dy = localOffset.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    // Out of bounds check
    if (distance < innerRadius - 10 || distance > outerRadius + 10) {
      return null;
    }

    final touchAngle =
        angleOverride ?? SectorMath.touchDeltaToDialAngle(dx, dy);
    final radialThickness = outerRadius - innerRadius;
    if (radialThickness <= 0) return null;

    // Normalized radial depth: 0 = outer boundary, 1000 = inner boundary
    final touchLevel = (((outerRadius - distance) / radialThickness) * 1000)
        .round()
        .clamp(0, 1000);

    for (final sector in sectors) {
      final start = sector.startAngle;
      final effectiveSweep = math.max(
        sector.sweepAngle,
        SectorMath.minSweepAngle,
      );
      final end = SectorMath.normalizeDegrees(start + effectiveSweep);

      final bool isAngleMatch;
      if (effectiveSweep >= 360.0) {
        isAngleMatch = true;
      } else if (start <= end) {
        isAngleMatch =
            touchAngle >= (start - touchSlopDegrees) &&
            touchAngle <= (end + touchSlopDegrees);
      } else {
        // Sector wraps around 12 o'clock (0 degrees)
        isAngleMatch =
            touchAngle >= (start - touchSlopDegrees) ||
            touchAngle <= (end + touchSlopDegrees);
      }

      if (isAngleMatch) {
        if (getRadii != null) {
          final radii = getRadii(sector);
          const radialSlop = 6.0;
          if (distance >= (radii.rIn - radialSlop) &&
              distance <= (radii.rOut + radialSlop)) {
            return sector;
          }
        } else {
          // Radial check (with small slop for easy finger tapping)
          const levelSlop = 40;
          final minLevel = (sector.topLevel - levelSlop).clamp(0, 1000);
          final maxLevel = (sector.bottomLevel + levelSlop).clamp(0, 1000);

          if (touchLevel >= minLevel && touchLevel <= maxLevel) {
            return sector;
          }
        }
      }
    }

    return null;
  }
}
