import 'dart:math' as math;

import 'dial_model.dart';
import 'horizon_selector.dart';
import 'text_measurer.dart';

/// A circular angular interval reserved on the dial face where subtask capsules
/// or overlapping text elements may not be placed (§4.5, I4, RC8).
class ReservedZone {
  final String name;
  final double startDeg;
  final double sweepDeg;
  final int? lane; // null indicates reserved across all radial lanes

  const ReservedZone({
    required this.name,
    required this.startDeg,
    required this.sweepDeg,
    this.lane,
  });

  double get endDeg => (startDeg + sweepDeg) % 360.0;

  /// Tests whether a candidate angular interval [candidateStart, candidateStart + candidateSweep]
  /// intersects this reserved zone on the circular dial face.
  bool intersects(
    double candidateStartDeg,
    double candidateSweepDeg, {
    int? candidateLane,
  }) {
    if (lane != null && candidateLane != null && lane != candidateLane) {
      return false;
    }

    final double a0 = (startDeg % 360.0 + 360.0) % 360.0;
    final double b0 = (candidateStartDeg % 360.0 + 360.0) % 360.0;

    // Fast check: if either sweep spans >= 360°, they intersect
    if (sweepDeg >= 360.0 || candidateSweepDeg >= 360.0) return true;

    // Sample across candidate interval [b0, b0 + candidateSweepDeg]
    const numSamples = 10;
    for (int i = 0; i <= numSamples; i++) {
      final double sample = (b0 + candidateSweepDeg * (i / numSamples)) % 360.0;
      if (_containsAngle(a0, sweepDeg, sample)) return true;
    }

    // Also check if zone start point or zone end point falls within candidate
    if (_containsAngle(b0, candidateSweepDeg, a0)) return true;
    final double aEnd = (a0 + sweepDeg) % 360.0;
    if (_containsAngle(b0, candidateSweepDeg, aEnd)) return true;

    return false;
  }

  static bool _containsAngle(
    double intervalStart,
    double intervalSweep,
    double angle,
  ) {
    final double s = (intervalStart % 360.0 + 360.0) % 360.0;
    final double a = (angle % 360.0 + 360.0) % 360.0;
    final double end = s + intervalSweep;
    if (end < 360.0) {
      return a >= s - 1e-4 && a <= end + 1e-4;
    } else {
      // Wraps around 360°/0°
      final double wrappedEnd = end % 360.0;
      return (a >= s - 1e-4) || (a <= wrappedEnd + 1e-4);
    }
  }

  @override
  String toString() =>
      'ReservedZone($name, ${startDeg.toStringAsFixed(1)}°+${sweepDeg.toStringAsFixed(1)}°, lane: $lane)';
}

/// The layout plan for a single dial block's content (§4.5).
class ContentPlan {
  final ContentMode mode;
  final CapLabels caps;
  final List<ReservedZone> reservedZones;
  final String titleKeyword;
  final double titleWidthPx;
  final double centerMidDeg;

  const ContentPlan({
    required this.mode,
    required this.caps,
    required this.reservedZones,
    required this.titleKeyword,
    required this.titleWidthPx,
    required this.centerMidDeg,
  });
}

/// Core Content Planner establishing the ContentMode ladder and reserved zones (§4.5).
class ContentPlanner {
  const ContentPlanner._();

  /// Distills a concise 1-2 word keyword from any user title (supporting international scripts).
  static String distillKeyword(String title, {bool isSubtask = false}) {
    final clean = title.trim();
    if (clean.isEmpty) return 'Task';

    final words = clean
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return clean;

    if (isSubtask) {
      // Subtask capsules must fit compactly along dial arcs
      final primary = words.length > 1 && words[0].length <= 2
          ? words[1]
          : words[0];
      return primary.length > 10 ? primary.substring(0, 10) : primary;
    }

    if (words.length == 1) {
      return words.first.length > 14
          ? words.first.substring(0, 14)
          : words.first;
    }
    // Take first 2 words if short, else first word
    if (words[0].length + words[1].length <= 14) {
      return '${words[0]} ${words[1]}';
    }
    return words[0].length > 14 ? words[0].substring(0, 14) : words[0];
  }

  /// Plans the content mode, cap label placements, and reserved zones for a block segment.
  static ContentPlan planContent({
    required OccurrenceSegment segment,
    required double displayStartDeg,
    required double displaySweepDeg,
    required bool is24HourMode,
    TextMeasurer textMeasurer = const FastTextMeasurer(),
    double dialRadius = 140.0,
    double ringThickness = 36.0,
  }) {
    // 1. ContentMode ladder per §4.5 (full -> compact -> iconKeyword -> iconOnly)
    final ContentMode mode;
    final double fullThreshold = is24HourMode ? 24.0 : 38.0;
    final double compactThreshold = is24HourMode ? 16.0 : 24.0;
    final double keywordThreshold = is24HourMode ? 10.0 : 14.0;

    if (displaySweepDeg >= fullThreshold) {
      mode = ContentMode.full;
    } else if (displaySweepDeg >= compactThreshold) {
      mode = ContentMode.compact;
    } else if (displaySweepDeg >= keywordThreshold) {
      mode = ContentMode.iconKeyword;
    } else {
      mode = ContentMode.iconOnly;
    }

    // 2. Cap Labels Geometry
    final double minSweepForCaps = is24HourMode ? 10.0 : 14.0;
    final bool capsVisible = displaySweepDeg >= minSweepForCaps;
    final double capSpan = is24HourMode ? 7.2 : 9.2;

    final startAngle = displayStartDeg % 360.0;
    final endAngle = (displayStartDeg + displaySweepDeg) % 360.0;

    final startLabel = _formatTime(segment.segmentStart);
    final endLabel = _formatTime(segment.segmentEnd);

    final caps = CapLabels(
      startTimeLabel: startLabel,
      endTimeLabel: endLabel,
      startAngleDeg: startAngle,
      endAngleDeg: endAngle,
      startCapSpanDeg: capsVisible ? capSpan : 0.0,
      endCapSpanDeg: capsVisible ? capSpan : 0.0,
      isVisible: capsVisible,
    );

    // 3. Reserved Zones
    final reservedZones = <ReservedZone>[];
    const double capGap = 1.5; // Safety gap beyond cap text

    if (capsVisible) {
      // Start Cap zone: [startAngle, startAngle + capSpan + capGap]
      reservedZones.add(
        ReservedZone(
          name: 'startCap',
          startDeg: startAngle,
          sweepDeg: capSpan + capGap,
        ),
      );

      // End Cap zone: [endAngle - (capSpan + capGap), endAngle]
      final endCapStart =
          (startAngle + displaySweepDeg - (capSpan + capGap)) % 360.0;
      reservedZones.add(
        ReservedZone(
          name: 'endCap',
          startDeg: endCapStart,
          sweepDeg: capSpan + capGap,
        ),
      );
    }

    // 4. Center Title / Icon Box Reserved Zone
    final hasSubtasks =
        segment.occurrence.subtasks.isNotEmpty ||
        segment.occurrence.subtaskItems.isNotEmpty;
    final rawKeyword = distillKeyword(segment.title);
    final titleKeyword = hasSubtasks
        ? rawKeyword.split(RegExp(r'\s+')).first
        : rawKeyword;
    final String measuredText = hasSubtasks
        ? titleKeyword
        : (mode == ContentMode.full ? segment.title : titleKeyword);
    final textDims = textMeasurer.measure(
      measuredText,
      fontSize: hasSubtasks ? 9.5 : (mode == ContentMode.full ? 12.0 : 10.0),
    );

    // Add icon width + margins
    final totalTitleWidthPx =
        textDims.width +
        (mode != ContentMode.iconOnly ? (hasSubtasks ? 14.0 : 20.0) : 12.0);
    final double midR = dialRadius - (ringThickness / 2.0);
    final double circumferenceAtMid = 2.0 * math.pi * midR;
    final maxFraction = hasSubtasks ? 0.22 : 0.65;
    final maxSpan = math.max(2.0, displaySweepDeg * maxFraction);
    final minSpan = math.min(6.0, maxSpan);
    final double titleAngularSpan =
        ((totalTitleWidthPx / circumferenceAtMid) * 360.0 + 3.0).clamp(
          minSpan,
          maxSpan,
        );

    final double midDeg = (startAngle + displaySweepDeg / 2.0) % 360.0;
    final double titleStartDeg = (midDeg - titleAngularSpan / 2.0) % 360.0;

    if (displaySweepDeg >= 18.0) {
      reservedZones.add(
        ReservedZone(
          name: 'titleBox',
          startDeg: titleStartDeg,
          sweepDeg: titleAngularSpan,
        ),
      );
    }

    return ContentPlan(
      mode: mode,
      caps: caps,
      reservedZones: reservedZones,
      titleKeyword: titleKeyword,
      titleWidthPx: totalTitleWidthPx,
      centerMidDeg: midDeg,
    );
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
