/// A single mapping point between linear clock time angle and stretched dial display angle.
class WarpBreakpoint {
  final double naturalDeg;
  final double displayDeg;

  const WarpBreakpoint(this.naturalDeg, this.displayDeg);

  Map<String, dynamic> toJson() => {
        'naturalDeg': naturalDeg,
        'displayDeg': displayDeg,
      };

  factory WarpBreakpoint.fromJson(Map<String, dynamic> json) {
    return WarpBreakpoint(
      (json['naturalDeg'] as num).toDouble(),
      (json['displayDeg'] as num).toDouble(),
    );
  }

  @override
  String toString() =>
      'WarpBreakpoint(${naturalDeg.toStringAsFixed(1)}° -> ${displayDeg.toStringAsFixed(1)}°)';
}

/// Piecewise-linear monotonic coordinate transformation between natural time angles
/// and warped dial display angles (§4.4, I6, I7, RC4).
class WarpMap {
  final List<WarpBreakpoint> breakpoints;

  const WarpMap(this.breakpoints);

  /// Identity map (uniform 1:1 circular clock).
  const WarpMap.identity()
      : breakpoints = const [
          WarpBreakpoint(0.0, 0.0),
          WarpBreakpoint(360.0, 360.0),
        ];

  /// Transforms a natural linear clock angle in degrees [0, 360) into the stretched
  /// dial display angle in degrees [0, 360).
  double forward(double naturalDeg) {
    if ((naturalDeg - 360.0).abs() < 1e-9) {
      return breakpoints.isNotEmpty ? breakpoints.last.displayDeg : 360.0;
    }
    final norm = (naturalDeg % 360.0 + 360.0) % 360.0;
    if (breakpoints.length < 2) return norm;

    // Handle exact 0.0 anchor
    if (norm == 0.0) return breakpoints.first.displayDeg;

    for (int i = 0; i < breakpoints.length - 1; i++) {
      final p0 = breakpoints[i];
      final p1 = breakpoints[i + 1];

      if (norm >= p0.naturalDeg && norm <= p1.naturalDeg) {
        final natSpan = p1.naturalDeg - p0.naturalDeg;
        if (natSpan <= 1e-9) return p0.displayDeg;

        final t = (norm - p0.naturalDeg) / natSpan;
        final dispSpan = p1.displayDeg - p0.displayDeg;
        final res = p0.displayDeg + t * dispSpan;
        if ((res - 360.0).abs() < 1e-9) return 360.0;
        return (res % 360.0 + 360.0) % 360.0;
      }
    }

    return norm;
  }

  /// Transforms a display angle in degrees [0, 360) back into the corresponding
  /// natural linear clock angle [0, 360) (used for touch scrubbing & drag handles).
  double inverse(double displayDeg) {
    if ((displayDeg - 360.0).abs() < 1e-9) {
      return breakpoints.isNotEmpty ? breakpoints.last.naturalDeg : 360.0;
    }
    final norm = (displayDeg % 360.0 + 360.0) % 360.0;
    if (breakpoints.length < 2) return norm;

    if (norm == 0.0) return breakpoints.first.naturalDeg;

    for (int i = 0; i < breakpoints.length - 1; i++) {
      final p0 = breakpoints[i];
      final p1 = breakpoints[i + 1];

      if (norm >= p0.displayDeg && norm <= p1.displayDeg) {
        final dispSpan = p1.displayDeg - p0.displayDeg;
        if (dispSpan <= 1e-9) return p0.naturalDeg;

        final t = (norm - p0.displayDeg) / dispSpan;
        final natSpan = p1.naturalDeg - p0.naturalDeg;
        final res = p0.naturalDeg + t * natSpan;
        if ((res - 360.0).abs() < 1e-9) return 360.0;
        return (res % 360.0 + 360.0) % 360.0;
      }
    }

    return norm;
  }

  /// Verifies whether the mapping preserves monotonicity across all breakpoints.
  bool get isMonotonic {
    for (int i = 0; i < breakpoints.length - 1; i++) {
      if (breakpoints[i + 1].naturalDeg < breakpoints[i].naturalDeg) {
        return false;
      }
      if (breakpoints[i + 1].displayDeg < breakpoints[i].displayDeg) {
        return false;
      }
    }
    return true;
  }

  /// Verifies that 12 o'clock (0°) natural maps to 12 o'clock display.
  bool get anchorHolds {
    final val = forward(0.0);
    return val < 1e-4 || (360.0 - val) < 1e-4;
  }

  Map<String, dynamic> toJson() => {
        'breakpoints': breakpoints.map((b) => b.toJson()).toList(),
      };

  factory WarpMap.fromJson(Map<String, dynamic> json) {
    final list = json['breakpoints'] as List<dynamic>?;
    if (list == null || list.isEmpty) {
      return const WarpMap.identity();
    }
    return WarpMap(
      list
          .map((b) => WarpBreakpoint.fromJson(b as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  String toString() => 'WarpMap(points: ${breakpoints.length})';
}
