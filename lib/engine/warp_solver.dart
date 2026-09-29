import 'dart:math' as math;

import 'dial_input.dart';
import 'horizon_selector.dart';
import 'warp_map.dart';

/// Segment of the dial face partitioned for warp solving (either a block or an empty gap).
class _DialPartition {
  final OccurrenceSegment? block;
  final double naturalStart;
  final double naturalSweep;
  final double minSweep;
  final double wantSweep;

  const _DialPartition({
    this.block,
    required this.naturalStart,
    required this.naturalSweep,
    required this.minSweep,
    required this.wantSweep,
  });

  bool get isBlock => block != null;
  bool get isTierA => block?.tier == BlockTier.A;
  bool get isTierB => block?.tier == BlockTier.B;
  bool get isTierC => block?.tier == BlockTier.C;

  _DialPartition copyWith({double? minSweep, double? wantSweep}) {
    return _DialPartition(
      block: block,
      naturalStart: naturalStart,
      naturalSweep: naturalSweep,
      minSweep: minSweep ?? this.minSweep,
      wantSweep: wantSweep ?? this.wantSweep,
    );
  }

  @override
  String toString() => isBlock
      ? 'Block(${block!.title}, nat: ${naturalSweep.toStringAsFixed(1)}°, want: ${wantSweep.toStringAsFixed(1)}°, min: ${minSweep.toStringAsFixed(1)}°)'
      : 'Gap(nat: ${naturalSweep.toStringAsFixed(1)}°, min: ${minSweep.toStringAsFixed(1)}°)';
}

/// Unified, monotonic, piecewise-linear warp solver (§4.4, I6, I7, RC4).
///
/// Replaces the disparate FisheyeTimeLens, DialSectorLayoutStretcher, and FocusedWarp
/// with a single closed-loop water-filling solver.
class WarpSolver {
  const WarpSolver._();

  /// Computes target sweep for Tier A active/upcoming blocks with subtasks.
  static double _contentIdeal12H(int subtaskCount, double naturalSweep) {
    double ideal;
    if (subtaskCount <= 1) {
      ideal = 70.0;
    } else if (subtaskCount == 2) {
      ideal = 88.0;
    } else if (subtaskCount == 3) {
      ideal = 110.0;
    } else {
      ideal = (110.0 + (subtaskCount - 3) * 10.0).clamp(70.0, 130.0);
    }
    return math.max(ideal, naturalSweep);
  }

  static double _contentIdeal24H(int subtaskCount, double naturalSweep) {
    double ideal;
    if (subtaskCount <= 1) {
      ideal = 40.0;
    } else if (subtaskCount == 2) {
      ideal = 50.0;
    } else if (subtaskCount == 3) {
      ideal = 62.0;
    } else {
      ideal = (62.0 + (subtaskCount - 3) * 6.0).clamp(40.0, 80.0);
    }
    return math.max(ideal, naturalSweep);
  }

  /// Solves the warp map given the horizon result and user preferences.
  static WarpMap solve({
    required HorizonResult horizon,
    required DialInput input,
  }) {
    final prefs = input.prefs;
    final is24 = prefs.is24HourMode;

    // If lens is disabled or there are no visible segments, return uniform identity map
    if (!prefs.isFocusLensEnabled ||
        prefs.lensMagnification <= 1.0 ||
        horizon.visibleSegments.isEmpty) {
      return const WarpMap.identity();
    }

    // 1. Sort visible segments by natural start angle around the circle [0, 360)
    final sortedSegments = List<OccurrenceSegment>.from(horizon.visibleSegments)
      ..sort((a, b) => a.naturalStartDeg.compareTo(b.naturalStartDeg));

    // 2. Partition the entire 360° circle into alternating blocks and gaps
    var partitions = <_DialPartition>[];
    double cursor = 0.0;

    for (final seg in sortedSegments) {
      final segStart = seg.naturalStartDeg;
      final segSweep = seg.naturalSweepDeg;

      if (segStart > cursor + 1e-4) {
        // Gap between cursor and segment start
        final gapSweep = segStart - cursor;
        partitions.add(
          _DialPartition(
            naturalStart: cursor,
            naturalSweep: gapSweep,
            minSweep: gapSweep > 0.0 ? math.min(gapSweep, 2.0) : 0.0,
            wantSweep: gapSweep,
          ),
        );
      }

      // Determine min and want sweep for this block
      final subtaskCount = math.max(
        seg.occurrence.subtasks.length,
        seg.occurrence.subtaskItems.length,
      );
      final double minSweep;
      final double wantSweep;

      if (seg.tier == BlockTier.A) {
        final ideal = is24
            ? _contentIdeal24H(subtaskCount, segSweep)
            : _contentIdeal12H(subtaskCount, segSweep);
        final magnified = segSweep * prefs.lensMagnification;
        final baseMin = is24 ? 34.0 : 45.0;
        minSweep = math.max(baseMin, math.min(ideal, is24 ? 75.0 : 110.0));
        wantSweep = math
            .max(ideal, magnified)
            .clamp(minSweep, is24 ? 90.0 : 135.0);
      } else if (seg.tier == BlockTier.B) {
        minSweep = is24 ? 20.0 : 28.0;
        wantSweep = math.max(segSweep, minSweep);
      } else {
        // Tier C
        minSweep = is24 ? 12.0 : 16.0;
        wantSweep = segSweep;
      }

      partitions.add(
        _DialPartition(
          block: seg,
          naturalStart: segStart,
          naturalSweep: segSweep,
          minSweep: minSweep,
          wantSweep: wantSweep,
        ),
      );

      cursor = segStart + segSweep;
    }

    // Trailing gap to 360.0
    if (cursor < 360.0 - 1e-4) {
      final trailingSweep = 360.0 - cursor;
      partitions.add(
        _DialPartition(
          naturalStart: cursor,
          naturalSweep: trailingSweep,
          minSweep: trailingSweep > 0.0 ? math.min(trailingSweep, 2.0) : 0.0,
          wantSweep: trailingSweep,
        ),
      );
    }

    // 3. Degrade Ladder if total minimums exceed 360° (§4.4)
    double totalMin = partitions.fold(0.0, (sum, p) => sum + p.minSweep);
    if (totalMin > 360.0) {
      // Step 1: Lower Tier C minimums
      partitions = partitions.map((p) {
        if (p.isTierC) {
          return p.copyWith(minSweep: math.min(p.minSweep, is24 ? 8.0 : 10.0));
        }
        return p;
      }).toList();
      totalMin = partitions.fold(0.0, (sum, p) => sum + p.minSweep);
    }

    if (totalMin > 360.0) {
      // Step 2: Lower Tier B minimums
      partitions = partitions.map((p) {
        if (p.isTierB) {
          return p.copyWith(minSweep: math.min(p.minSweep, is24 ? 14.0 : 18.0));
        }
        return p;
      }).toList();
      totalMin = partitions.fold(0.0, (sum, p) => sum + p.minSweep);
    }

    if (totalMin > 360.0) {
      // Step 3: Reduce Tier A ideal to its minimum
      partitions = partitions.map((p) {
        if (p.isTierA) {
          return p.copyWith(
            minSweep: is24 ? 24.0 : 34.0,
            wantSweep: is24 ? 24.0 : 34.0,
          );
        }
        return p;
      }).toList();
      totalMin = partitions.fold(0.0, (sum, p) => sum + p.minSweep);
    }

    if (totalMin > 360.0) {
      // Safety scale: clamp all minimums proportionally to strictly fit in 360.0
      final scale = 360.0 / totalMin;
      partitions = partitions
          .map(
            (p) => p.copyWith(
              minSweep: p.minSweep * scale,
              wantSweep: p.wantSweep * scale,
            ),
          )
          .toList();
    }

    // 4. Water-filling solver: minimise sum (s_i - want_i)^2 / natural_i subject to sum s_i = 360
    final n = partitions.length;
    final displaySweeps = List<double>.filled(n, 0.0);
    final clamped = List<bool>.filled(n, false);

    // Initial proportional assignment from wantSweep
    final totalWant = partitions.fold(0.0, (sum, p) => sum + p.wantSweep);
    for (int i = 0; i < n; i++) {
      displaySweeps[i] = totalWant > 0
          ? (partitions[i].wantSweep / totalWant) * 360.0
          : partitions[i].naturalSweep;
    }

    // Water-filling relaxation loop (max 10 iterations)
    for (int iter = 0; iter < 10; iter++) {
      bool newlyClamped = false;

      for (int i = 0; i < n; i++) {
        if (!clamped[i] && displaySweeps[i] < partitions[i].minSweep) {
          clamped[i] = true;
          displaySweeps[i] = partitions[i].minSweep;
          newlyClamped = true;
        }
      }

      if (!newlyClamped) break;

      // Redistribute remaining budget among unclamped partitions
      double fixedBudget = 0.0;
      double remainingWant = 0.0;

      for (int i = 0; i < n; i++) {
        if (clamped[i]) {
          fixedBudget += displaySweeps[i];
        } else {
          remainingWant += partitions[i].wantSweep;
        }
      }

      final remBudget = math.max(0.0, 360.0 - fixedBudget);
      if (remainingWant <= 1e-6) {
        // Fallback: distribute evenly among unclamped
        int unclampedCount = clamped.where((c) => !c).length;
        if (unclampedCount > 0) {
          final share = remBudget / unclampedCount;
          for (int i = 0; i < n; i++) {
            if (!clamped[i]) displaySweeps[i] = share;
          }
        }
        break;
      }

      for (int i = 0; i < n; i++) {
        if (!clamped[i]) {
          displaySweeps[i] =
              (partitions[i].wantSweep / remainingWant) * remBudget;
        }
      }
    }

    // 5. Construct Breakpoints [(0.0, 0.0), ..., (360.0, 360.0)]
    final breakpoints = <WarpBreakpoint>[const WarpBreakpoint(0.0, 0.0)];

    double currNatural = 0.0;
    double currDisplay = 0.0;

    for (int i = 0; i < n; i++) {
      currNatural += partitions[i].naturalSweep;
      currDisplay += displaySweeps[i];

      // Avoid redundant identical angle entries
      if ((currNatural - breakpoints.last.naturalDeg).abs() > 1e-4) {
        breakpoints.add(
          WarpBreakpoint(
            currNatural.clamp(0.0, 360.0),
            currDisplay.clamp(0.0, 360.0),
          ),
        );
      }
    }

    // Ensure terminating 360.0 -> 360.0 anchor
    if (breakpoints.last.naturalDeg < 360.0 - 1e-4) {
      breakpoints.add(const WarpBreakpoint(360.0, 360.0));
    } else {
      breakpoints[breakpoints.length - 1] = const WarpBreakpoint(360.0, 360.0);
    }

    return WarpMap(breakpoints);
  }
}
