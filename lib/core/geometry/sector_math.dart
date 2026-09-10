import 'dart:math' as math;

/// Mathematical utilities for polar conversions and circular dial geometry.
///
/// Ported and refined from Sectograph (`CircleDay.java` and `y3/n.java`).
class SectorMath {
  SectorMath._();

  /// Angular rate for 12-hour dial: 360° / 720 minutes = 0.5 degrees/minute.
  static const double degreesPerMinute12H = 0.5;

  /// Angular rate for 24-hour dial: 360° / 1440 minutes = 0.25 degrees/minute.
  static const double degreesPerMinute24H = 0.25;

  /// Minimum visible sweep angle in degrees to ensure short tasks (e.g. 2 min)
  /// remain visually distinct on the dial.
  static const double minSweepAngle = 5.0;

  /// Sectograph dial reference offset: 12 o'clock is at the top (-90 degrees in Flutter canvas).
  static const double dialTopOffsetDegrees = -90.0;

  /// Converts degrees to radians.
  static double degToRad(double deg) => deg * (math.pi / 180.0);

  /// Converts radians to degrees.
  static double radToDeg(double rad) => rad * (180.0 / math.pi);

  /// Normalizes any angle in degrees to the [0.0, 360.0) range.
  static double normalizeDegrees(double deg) {
    var d = deg % 360.0;
    if (d < 0) d += 360.0;
    return d;
  }

  /// Calculates the dial angle in degrees for a given [time].
  ///
  /// The returned angle is measured clockwise from 12 o'clock (0° at 12:00, 90° at 3:00, etc.).
  static double timeToDialAngle(DateTime time, {required bool is24HourMode}) {
    final rate = is24HourMode ? degreesPerMinute24H : degreesPerMinute12H;
    final minutes = is24HourMode
        ? time.hour * 60 + time.minute + (time.second / 60.0)
        : (time.hour % 12) * 60 + time.minute + (time.second / 60.0);

    return normalizeDegrees(minutes * rate);
  }

  /// Converts dial angle (where 0° is 12 o'clock) to Flutter Canvas angle in radians
  /// (where 0 rad is 3 o'clock / positive X-axis).
  static double dialAngleToCanvasRadians(double dialDegrees) {
    return degToRad(dialDegrees + dialTopOffsetDegrees);
  }

  /// Calculates the visual sweep angle in degrees for an event with [duration].
  /// Clamps to [minSweepAngle] so very short events remain visible.
  static double durationToSweepAngle(
    Duration duration, {
    required bool is24HourMode,
    bool clampMinAngle = true,
  }) {
    final rate = is24HourMode ? degreesPerMinute24H : degreesPerMinute12H;
    final rawDegrees = duration.inSeconds / 60.0 * rate;

    if (clampMinAngle && rawDegrees < minSweepAngle) {
      return minSweepAngle;
    }
    return rawDegrees;
  }

  /// Converts a touch delta (relative to dial center) into a dial angle in degrees
  /// [0, 360), where 0° is 12 o'clock, 90° is 3 o'clock, 180° is 6 o'clock.
  static double touchDeltaToDialAngle(double dx, double dy) {
    // math.atan2 returns angle where positive X is 0, positive Y is 90°
    final rad = math.atan2(dy, dx);
    final deg = radToDeg(rad);
    // Rotate by +90° so that -Y (12 o'clock) maps to 0°
    return normalizeDegrees(deg + 90.0);
  }

  /// Converts a dial angle back to hour and minute components.
  static ({int hour, int minute}) dialAngleToTime(
    double dialDegrees, {
    required bool is24HourMode,
    int baseHour12 = 0,
  }) {
    final normalized = normalizeDegrees(dialDegrees);
    final rate = is24HourMode ? degreesPerMinute24H : degreesPerMinute12H;
    final totalMinutes = (normalized / rate).round();

    if (is24HourMode) {
      final hour = (totalMinutes ~/ 60) % 24;
      final minute = totalMinutes % 60;
      return (hour: hour, minute: minute);
    } else {
      var hour = (totalMinutes ~/ 60) % 12;
      if (baseHour12 >= 12) {
        hour += 12;
      }
      final minute = totalMinutes % 60;
      return (hour: hour, minute: minute);
    }
  }

  /// Checks whether a time interval spans across midnight.
  static bool spansAcrossMidnight(DateTime start, DateTime end) {
    if (!end.isAfter(start)) return false;
    return start.year != end.year ||
        start.month != end.month ||
        start.day != end.day;
  }

  /// Splits an overnight event crossing midnight into two separate day intervals:
  /// (start -> 23:59:59.999 on day 1) and (00:00:00 -> end on day 2).
  static ({DateTime day1End, DateTime day2Start}) splitMidnightBoundary(
    DateTime start,
    DateTime end,
  ) {
    final nextDay = DateTime(start.year, start.month, start.day + 1);
    return (
      day1End: nextDay.subtract(const Duration(milliseconds: 1)),
      day2Start: nextDay,
    );
  }
}

/// Dynamic non-linear angular warping engine for Focused Blocks mode.
///
/// Expands the active block to occupy a prominent fraction of the dial (140°-270°,
/// proportional to subtask count) while smoothly compressing the remaining dial angles.
class FocusedWarp {
  final String focusEventId;
  final double startDeg; // natural start of focus event [0, 360)
  final double naturalSweep; // natural sweep of focus event (e.g. 37.5)
  final double targetSweep; // expanded sweep of focus event (e.g. 165.0)
  final double targetStart; // expanded start of focus event [0, 360)

  const FocusedWarp({
    required this.focusEventId,
    required this.startDeg,
    required this.naturalSweep,
    required this.targetSweep,
    required this.targetStart,
  });

  /// Factory that builds a FocusedWarp from a target focus event and subtask count.
  factory FocusedWarp.fromEvent({
    required String eventId,
    required double startAngle,
    required double sweepAngle,
    required int subtaskCount,
  }) {
    final natStart = SectorMath.normalizeDegrees(startAngle);
    final natSweep = sweepAngle.clamp(4.0, 350.0);
    // Base 140° zoom, + 25° per subtask, clamped to [140°, 270°]
    final tgtSweep = math.max(
      natSweep,
      (140.0 + subtaskCount * 25.0).clamp(140.0, 270.0),
    );
    // Center the target sweep roughly around the original mid angle
    final tgtStart = SectorMath.normalizeDegrees(
      natStart - (tgtSweep - natSweep) / 2.0,
    );
    return FocusedWarp(
      focusEventId: eventId,
      startDeg: natStart,
      naturalSweep: natSweep,
      targetSweep: tgtSweep,
      targetStart: tgtStart,
    );
  }

  /// Transforms any natural dial angle [deg] into its warped position on the focused dial.
  double warp(double deg) {
    var d = (deg - startDeg) % 360.0;
    if (d < 0) d += 360.0;

    if (d <= naturalSweep) {
      final frac = naturalSweep > 0 ? d / naturalSweep : 0.0;
      return SectorMath.normalizeDegrees(targetStart + frac * targetSweep);
    } else {
      final outsideOrig = 360.0 - naturalSweep;
      final outsideTarget = 360.0 - targetSweep;
      final frac = (d - naturalSweep) / outsideOrig;
      return SectorMath.normalizeDegrees(
        targetStart + targetSweep + frac * outsideTarget,
      );
    }
  }

  /// Inverse transform from warped dial angle back to natural dial angle.
  double unwarp(double warpedDeg) {
    var d = (warpedDeg - targetStart) % 360.0;
    if (d < 0) d += 360.0;

    if (d <= targetSweep) {
      final frac = targetSweep > 0 ? d / targetSweep : 0.0;
      return SectorMath.normalizeDegrees(startDeg + frac * naturalSweep);
    } else {
      final outsideOrig = 360.0 - naturalSweep;
      final outsideTarget = 360.0 - targetSweep;
      final frac = (d - targetSweep) / outsideTarget;
      return SectorMath.normalizeDegrees(
        startDeg + naturalSweep + frac * outsideOrig,
      );
    }
  }
}
