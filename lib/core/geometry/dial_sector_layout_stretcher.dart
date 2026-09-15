import 'dart:math' as math;

import '../../domain/models/sector_event.dart';
import '../constants/app_layout_constants.dart';
import 'sector_math.dart';

/// Pure geometric layout resolver that naturally stretches tight or compressed
/// dial sectors into adjacent empty time gaps.
///
/// Ensures that boundary time caps, inner icons, titles, and duration labels
/// fit with generous breathing room and zero overlapping collisions, while strictly
/// maintaining chronological order and preserving inter-block gaps.
class DialSectorLayoutStretcher {
  const DialSectorLayoutStretcher._();

  /// Stretches sectors in [events] naturally to satisfy content readability floors.
  ///
  /// Returns a new list of [SectorEvent] instances in the same order as [events]
  /// with adjusted [startAngle] and [sweepAngle].
  static List<SectorEvent> stretch(
    List<SectorEvent> events, {
    required bool is24HourMode,
    double minSweep24H = AppLayoutConstants.minContentSweepDeg24H,
    double minSweep12H = AppLayoutConstants.minContentSweepDeg12H,
    double minInterBlockGap = AppLayoutConstants.minInterBlockGapDeg,
  }) {
    if (events.isEmpty) return const [];
    if (events.length == 1) {
      final e = events.first;
      final requiredSweep = is24HourMode ? minSweep24H : minSweep12H;
      if (e.sweepAngle >= requiredSweep) {
        return events;
      }
      final diff = requiredSweep - e.sweepAngle;
      return [
        e.copyWith(
          startAngle: SectorMath.normalizeDegrees(e.startAngle - diff / 2.0),
          sweepAngle: requiredSweep,
        ),
      ];
    }

    final n = events.length;

    // 1. Sort a working list by startAngle on the circular dial face [0, 360)
    final sorted = List<SectorEvent>.from(events)
      ..sort((a, b) {
        final aStart = SectorMath.normalizeDegrees(a.startAngle);
        final bStart = SectorMath.normalizeDegrees(b.startAngle);
        final cmp = aStart.compareTo(bStart);
        if (cmp != 0) return cmp;
        return a.id.compareTo(b.id);
      });

    // 2. Identify contiguous relationships and compute circular gaps between consecutive sectors
    final isContiguousWithNext = List<bool>.filled(n, false);
    final gaps = List<double>.filled(n, 0.0);

    for (int i = 0; i < n; i++) {
      final nextIdx = (i + 1) % n;
      final endAngle = SectorMath.normalizeDegrees(
        sorted[i].startAngle + sorted[i].sweepAngle,
      );
      final nextStartAngle = SectorMath.normalizeDegrees(
        sorted[nextIdx].startAngle,
      );

      var gap = (nextStartAngle - endAngle) % 360.0;
      if (gap < 0) gap += 360.0;

      // Tolerance for contiguous sectors touching at boundary (within 0.75°)
      if (gap <= 0.75 || gap >= 359.25) {
        isContiguousWithNext[i] = true;
        gaps[i] = 0.0;
      } else {
        isContiguousWithNext[i] = false;
        gaps[i] = gap;
      }
    }

    // 3. Compute target required sweep and deficit for each sector
    final deficits = List<double>.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      final prevIdx = (i - 1 + n) % n;
      final hasStartCap = !isContiguousWithNext[prevIdx];
      final double targetSweep = hasStartCap
          ? (is24HourMode ? minSweep24H : minSweep12H)
          : (is24HourMode ? 18.0 : 26.0);

      final curSweep = sorted[i].sweepAngle;
      if (curSweep < targetSweep) {
        deficits[i] = targetSweep - curSweep;
      }
    }

    // If no sectors need stretching, return original list immediately
    if (!deficits.any((d) => d > 0.001)) {
      return events;
    }

    // 4. Compute usable space in each gap (preserving minInterBlockGap buffer)
    final usableSpace = List<double>.generate(n, (k) {
      if (isContiguousWithNext[k] || gaps[k] <= minInterBlockGap) {
        return 0.0;
      }
      return math.max(0.0, gaps[k] - minInterBlockGap);
    });

    final remainingUsable = List<double>.from(usableSpace);

    // 5. Pass 1: Compute preferred expansion requests (backward into prev gap, forward into next gap)
    final reqBwd = List<double>.filled(n, 0.0);
    final reqFwd = List<double>.filled(n, 0.0);

    for (int i = 0; i < n; i++) {
      final d = deficits[i];
      if (d <= 0.0) continue;

      final prevIdx = (i - 1 + n) % n;
      final canBwd = usableSpace[prevIdx] > 0.0;
      final canFwd = usableSpace[i] > 0.0;

      if (canBwd && canFwd) {
        reqBwd[i] = d / 2.0;
        reqFwd[i] = d / 2.0;
      } else if (canBwd) {
        reqBwd[i] = d;
      } else if (canFwd) {
        reqFwd[i] = d;
      }
    }

    // 6. Allocate from each gap k: event k expands forward, event k+1 expands backward
    final grantedFwd = List<double>.filled(n, 0.0);
    final grantedBwd = List<double>.filled(n, 0.0);

    for (int k = 0; k < n; k++) {
      final nextIdx = (k + 1) % n;
      final demand = reqFwd[k] + reqBwd[nextIdx];
      final avail = remainingUsable[k];

      if (demand <= 0.0 || avail <= 0.0) continue;

      if (demand <= avail) {
        grantedFwd[k] = reqFwd[k];
        grantedBwd[nextIdx] = reqBwd[nextIdx];
        remainingUsable[k] = avail - demand;
      } else {
        final scale = avail / demand;
        grantedFwd[k] = reqFwd[k] * scale;
        grantedBwd[nextIdx] = reqBwd[nextIdx] * scale;
        remainingUsable[k] = 0.0;
      }
    }

    // 7. Pass 2: Scavenge unused gap space for any events still with unsatisfied deficit
    for (int i = 0; i < n; i++) {
      final totalGranted = grantedBwd[i] + grantedFwd[i];
      var remainingDeficit = deficits[i] - totalGranted;
      if (remainingDeficit <= 0.001) continue;

      // Try taking remaining deficit from next gap first
      if (remainingUsable[i] > 0.0) {
        final extraFwd = math.min(remainingDeficit, remainingUsable[i]);
        grantedFwd[i] += extraFwd;
        remainingUsable[i] -= extraFwd;
        remainingDeficit -= extraFwd;
      }

      // Try taking remaining deficit from prev gap
      final prevIdx = (i - 1 + n) % n;
      if (remainingDeficit > 0.001 && remainingUsable[prevIdx] > 0.0) {
        final extraBwd = math.min(remainingDeficit, remainingUsable[prevIdx]);
        grantedBwd[i] += extraBwd;
        remainingUsable[prevIdx] -= extraBwd;
        remainingDeficit -= extraBwd;
      }
    }

    // 8. Construct updated events with stretched start and sweep angles
    final updatedMap = <String, SectorEvent>{};
    for (int i = 0; i < n; i++) {
      final ev = sorted[i];
      final bwd = grantedBwd[i];
      final fwd = grantedFwd[i];

      final newStart = SectorMath.normalizeDegrees(ev.startAngle - bwd);
      final newSweep = ev.sweepAngle + bwd + fwd;

      updatedMap[ev.id] = ev.copyWith(
        startAngle: newStart,
        sweepAngle: newSweep,
      );
    }

    // Return in the identical original ordering of [events]
    return events.map((e) => updatedMap[e.id] ?? e).toList();
  }
}
