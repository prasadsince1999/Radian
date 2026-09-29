/// A single linear angle segment on [0, 360).
class _AngleInterval {
  final double start;
  final double end;
  final String eventId;

  const _AngleInterval(this.start, this.end, this.eventId);

  bool overlapsWith(_AngleInterval other) {
    return start < other.end && end > other.start;
  }

  @override
  String toString() => '_AngleInterval($start - $end, $eventId)';
}

/// Angular occupancy authority on a 360° circular dial face.
///
/// Implements §4.3 of Dial Engine Architecture: detects circular angle collisions
/// on 12-hour faces (where AM and PM intervals occupy the same angular space)
/// and identifies aliasing event IDs with guard gap buffering.
class AngularOccupancy {
  final double guardGapDeg;
  final List<_AngleInterval> _intervals = [];

  AngularOccupancy({this.guardGapDeg = 1.5});

  /// Decomposes a circular arc [startDeg, startDeg + sweepDeg] into 1 or 2
  /// non-wrapping linear intervals on [0, 360).
  List<_AngleInterval> _decomposeArc(
    double startDeg,
    double sweepDeg,
    String eventId,
    double extraPadding,
  ) {
    var s = (startDeg - extraPadding) % 360.0;
    if (s < 0) s += 360.0;
    final totalSpan = sweepDeg + (extraPadding * 2);

    if (totalSpan >= 360.0) {
      return [_AngleInterval(0.0, 360.0, eventId)];
    }

    final rawEnd = s + totalSpan;
    if (rawEnd > 360.0) {
      return [
        _AngleInterval(s, 360.0, eventId),
        _AngleInterval(0.0, rawEnd - 360.0, eventId),
      ];
    } else {
      return [_AngleInterval(s, rawEnd, eventId)];
    }
  }

  /// Checks whether a candidate arc [startDeg, startDeg + sweepDeg] can be admitted
  /// without colliding with already admitted arcs.
  bool canAdmit(double startDeg, double sweepDeg) {
    return conflictingEventId(startDeg, sweepDeg) == null;
  }

  /// Finds the ID of the existing event whose occupied arc collides with the candidate arc,
  /// or null if free.
  String? conflictingEventId(double startDeg, double sweepDeg) {
    final candidateIntervals = _decomposeArc(
      startDeg,
      sweepDeg,
      '',
      guardGapDeg / 2.0,
    );

    for (final candidate in candidateIntervals) {
      for (final existing in _intervals) {
        if (candidate.overlapsWith(existing)) {
          return existing.eventId;
        }
      }
    }
    return null;
  }

  /// Admits a candidate arc into the occupancy set.
  void admit(double startDeg, double sweepDeg, String eventId) {
    final newIntervals = _decomposeArc(
      startDeg,
      sweepDeg,
      eventId,
      guardGapDeg / 2.0,
    );
    _intervals.addAll(newIntervals);
  }

  /// Clears all admitted intervals.
  void clear() {
    _intervals.clear();
  }

  /// Current number of admitted linear segments.
  int get segmentCount => _intervals.length;
}
