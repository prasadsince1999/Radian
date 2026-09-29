import 'dart:math' as math;

import 'content_planner.dart';
import 'dial_input.dart';
import 'dial_model.dart';
import 'horizon_selector.dart';
import 'text_measurer.dart';
import 'warp_map.dart';

/// Geometry-based subtask placer with reserved zone avoidance and greedy lane packing (§4.5, I4, I5, RC8).
class SubtaskPlacer {
  const SubtaskPlacer._();

  static const double interCapsuleGapDeg = 2.0;

  /// Places subtask capsules inside a block segment without collisions.
  static List<CapsulePlacement> place({
    required OccurrenceSegment segment,
    required double displayStartDeg,
    required double displaySweepDeg,
    required WarpMap warp,
    required bool is24HourMode,
    required ContentPlan contentPlan,
    TextMeasurer textMeasurer = const FastTextMeasurer(),
    double dialRadius = 140.0,
    double ringThickness = 36.0,
  }) {
    // 1. Extract subtasks
    final subtasks = <SubtaskItemOccurrence>[];
    if (segment.occurrence.subtaskItems.isNotEmpty) {
      subtasks.addAll(segment.occurrence.subtaskItems);
    } else if (segment.occurrence.subtasks.isNotEmpty) {
      for (int i = 0; i < segment.occurrence.subtasks.length; i++) {
        subtasks.add(
          SubtaskItemOccurrence(
            id: 'st-$i',
            title: segment.occurrence.subtasks[i],
          ),
        );
      }
    }

    if (subtasks.isEmpty) return const [];

    // If block is in iconOnly mode, no space for subtasks
    if (contentPlan.mode == ContentMode.iconOnly || displaySweepDeg < 16.0) {
      return const [];
    }

    // 2. Compute desired display angle for each subtask
    final candidates = <_SubtaskCandidate>[];

    for (int i = 0; i < subtasks.length; i++) {
      final item = subtasks[i];
      final double dispDeg;

      if (item.startMinuteOffset != null) {
        final atTime = segment.segmentStart.add(
          Duration(minutes: item.startMinuteOffset!),
        );
        final clampedTime = atTime.isBefore(segment.segmentStart)
            ? segment.segmentStart
            : (atTime.isAfter(segment.segmentEnd)
                  ? segment.segmentEnd
                  : atTime);
        final natDeg = HorizonSelector.naturalAngleDeg(
          clampedTime,
          is24HourMode: is24HourMode,
        );
        final rawDispDeg = warp.forward(natDeg);
        var normalized = rawDispDeg;
        while (normalized < displayStartDeg - 1e-4) {
          normalized += 360.0;
        }
        while (normalized > displayStartDeg + displaySweepDeg + 1e-4) {
          normalized -= 360.0;
        }
        dispDeg = normalized.clamp(
          displayStartDeg,
          displayStartDeg + displaySweepDeg,
        );
      } else {
        // Evenly distribute across block display arc (§4.5)
        final fraction = (i + 1.0) / (subtasks.length + 1.0);
        dispDeg = displayStartDeg + (displaySweepDeg * fraction);
      }

      candidates.add(
        _SubtaskCandidate(item: item, desiredDisplayDeg: dispDeg, index: i),
      );
    }

    // Sort chronologically by desired display angle
    candidates.sort(
      (a, b) => a.desiredDisplayDeg.compareTo(b.desiredDisplayDeg),
    );

    // 3. Radial Lane Radii
    // Lane 0: outer lane (closer to bezel)
    // Lane 1: inner lane (closer to inner track)
    final r0 = dialRadius - (ringThickness * 0.25);
    final r1 = dialRadius - (ringThickness * 0.75);
    final laneRadii = [r0, r1];

    final placedCapsules = <CapsulePlacement>[];
    final lanePlacedIntervals = <int, List<_AngleInterval>>{0: [], 1: []};

    // 4. Place each candidate using greedy lane packing & font stepping
    int unplacedStartIndex = -1;

    for (int idx = 0; idx < candidates.length; idx++) {
      final cand = candidates[idx];
      final displayTitle = ContentPlanner.distillKeyword(
        cand.item.title,
        isSubtask: true,
      );

      bool placed = false;

      // Font size ladder: 10.0 -> 9.0 -> 8.0 (2 steps max reduction per §4.5)
      const fontSteps = [10.0, 9.0, 8.0];

      for (final fontSize in fontSteps) {
        final textDims = textMeasurer.measure(displayTitle, fontSize: fontSize);

        final widthPx = textDims.width + (fontSize <= 8.5 ? 6.0 : 8.0);
        const heightPx = 14.0;

        // Try Lane 0 then Lane 1
        for (int lane = 0; lane < 2; lane++) {
          final radius = laneRadii[lane];
          final circumference = 2.0 * math.pi * radius;
          final angularWidthDeg = (widthPx / circumference) * 360.0;
          final halfSpan = angularWidthDeg / 2.0;

          // Attempt placement at desired angle, or locally shift
          final fittedAngle = _findFit(
            centerDeg: cand.desiredDisplayDeg,
            halfSpanDeg: halfSpan,
            displayStartDeg: displayStartDeg,
            displaySweepDeg: displaySweepDeg,
            lane: lane,
            contentPlan: contentPlan,
            existingIntervals: lanePlacedIntervals[lane]!,
          );

          if (fittedAngle != null) {
            final placement = CapsulePlacement(
              subtaskId: cand.item.id,
              title: displayTitle,
              centerDeg: (fittedAngle % 360.0 + 360.0) % 360.0,
              angularWidthDeg: angularWidthDeg,
              radiusRatio: lane == 0 ? 0.75 : 0.25,
              lane: lane,
              widthPx: widthPx,
              heightPx: heightPx,
              isCompleted: cand.item.isCompleted,
            );

            placedCapsules.add(placement);
            lanePlacedIntervals[lane]!.add(
              _AngleInterval(
                start: fittedAngle - halfSpan - interCapsuleGapDeg / 2.0,
                end: fittedAngle + halfSpan + interCapsuleGapDeg / 2.0,
              ),
            );
            placed = true;
            break;
          }
        }

        if (placed) break;
      }

      if (!placed) {
        // Could not fit this candidate individually
        unplacedStartIndex = idx;
        break;
      }
    }

    // 5. If unplaced subtasks remain (Tier B/C or > 6 subtasks), fold into a +N capsule
    if (unplacedStartIndex != -1) {
      final foldedCount = candidates.length - unplacedStartIndex;
      final foldTitle = '+$foldedCount';

      final textDims = textMeasurer.measure(foldTitle, fontSize: 9.0);
      final widthPx = textDims.width + 10.0;
      const heightPx = 14.0;

      // Find any slot in either lane for the fold indicator
      for (int lane = 0; lane < 2; lane++) {
        final radius = laneRadii[lane];
        final angularWidthDeg = (widthPx / (2.0 * math.pi * radius)) * 360.0;
        final halfSpan = angularWidthDeg / 2.0;

        final foldTargetAngle =
            candidates[unplacedStartIndex].desiredDisplayDeg;
        final fittedAngle = _findFit(
          centerDeg: foldTargetAngle,
          halfSpanDeg: halfSpan,
          displayStartDeg: displayStartDeg,
          displaySweepDeg: displaySweepDeg,
          lane: lane,
          contentPlan: contentPlan,
          existingIntervals: lanePlacedIntervals[lane]!,
        );

        if (fittedAngle != null) {
          placedCapsules.add(
            CapsulePlacement(
              subtaskId: 'folded-$foldedCount',
              title: foldTitle,
              centerDeg: (fittedAngle % 360.0 + 360.0) % 360.0,
              angularWidthDeg: angularWidthDeg,
              radiusRatio: lane == 0 ? 0.75 : 0.25,
              lane: lane,
              widthPx: widthPx,
              heightPx: heightPx,
              isFolded: true,
              foldedCount: foldedCount,
            ),
          );
          break;
        }
      }
    }

    return placedCapsules;
  }

  /// Searches for a valid collision-free angle around [centerDeg] within block bounds.
  static double? _findFit({
    required double centerDeg,
    required double halfSpanDeg,
    required double displayStartDeg,
    required double displaySweepDeg,
    required int lane,
    required ContentPlan contentPlan,
    required List<_AngleInterval> existingIntervals,
  }) {
    final blockStart = displayStartDeg;
    final blockEnd = displayStartDeg + displaySweepDeg;

    // Search outwards from centerDeg across the block sweep
    final maxOffsetDeg = math.max(45.0, displaySweepDeg / 2.0);
    const stepDeg = 0.5;
    for (double offset = 0.0; offset <= maxOffsetDeg; offset += stepDeg) {
      // Try +offset then -offset
      for (final sign in [1.0, -1.0]) {
        final candidate = centerDeg + sign * offset;
        final candStart = candidate - halfSpanDeg;
        final candEnd = candidate + halfSpanDeg;

        // Ensure strictly bounded inside block
        if (candStart < blockStart + 0.5 || candEnd > blockEnd - 0.5) {
          if (offset == 0.0) break;
          continue;
        }

        // Check reserved zones
        bool collidesWithZone = false;
        for (final zone in contentPlan.reservedZones) {
          if (zone.intersects(
            candStart,
            candEnd - candStart,
            candidateLane: lane,
          )) {
            collidesWithZone = true;
            break;
          }
        }
        if (collidesWithZone) {
          if (offset == 0.0) break;
          continue;
        }

        // Check already placed capsules in this lane
        bool collidesWithCapsule = false;
        for (final interval in existingIntervals) {
          if (interval.intersects(candStart, candEnd)) {
            collidesWithCapsule = true;
            break;
          }
        }
        if (collidesWithCapsule) {
          if (offset == 0.0) break;
          continue;
        }

        return candidate;
      }
    }

    return null;
  }
}

class _SubtaskCandidate {
  final SubtaskItemOccurrence item;
  final double desiredDisplayDeg;
  final int index;

  _SubtaskCandidate({
    required this.item,
    required this.desiredDisplayDeg,
    required this.index,
  });
}

class _AngleInterval {
  final double start;
  final double end;

  _AngleInterval({required this.start, required this.end});

  bool intersects(double otherStart, double otherEnd) {
    return !(end <= otherStart || start >= otherEnd);
  }
}
