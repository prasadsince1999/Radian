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

  /// Stretches sectors in [events] naturally to satisfy content readability floors
  /// and ensure subtask river pebbles fit with generous breathing room.
  ///
  /// Returns a new list of [SectorEvent] instances in the same order as [events]
  /// with adjusted [startAngle] and [sweepAngle].
  static List<SectorEvent> stretch(
    List<SectorEvent> events, {
    required bool is24HourMode,
    String? activeEventId,
    String? selectedEventId,
    DateTime? currentTime,
    double minSweep24H = AppLayoutConstants.minContentSweepDeg24H,
    double minSweep12H = AppLayoutConstants.minContentSweepDeg12H,
    double minInterBlockGap = AppLayoutConstants.minInterBlockGapDeg,
  }) {
    if (events.isEmpty) return const [];
    if (events.length == 1) {
      final e = events.first;
      final isTargetActive =
          (activeEventId != null && e.id == activeEventId) ||
          (currentTime != null &&
              !currentTime.isBefore(e.start) &&
              currentTime.isBefore(e.end));
      final isTargetSelected =
          selectedEventId != null && e.id == selectedEventId;
      final isHighPriority = isTargetActive || isTargetSelected;

      double requiredSweep = is24HourMode ? minSweep24H : minSweep12H;
      if (e.subtasks.isNotEmpty) {
        final subtaskTarget = is24HourMode
            ? AppLayoutConstants.targetActiveSubtaskSweepDeg24H(
                e.subtasks.length,
              )
            : AppLayoutConstants.targetActiveSubtaskSweepDeg12H(
                e.subtasks.length,
              );
        requiredSweep = math.max(requiredSweep, subtaskTarget);
      } else if (isHighPriority) {
        final priorityFloor = is24HourMode ? 30.0 : 42.0;
        requiredSweep = math.max(requiredSweep, priorityFloor);
      }

      if (e.sweepAngle >= requiredSweep) {
        return events;
      }
      return [e.copyWith(startAngle: e.startAngle, sweepAngle: requiredSweep)];
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
    final isPriority = List<bool>.filled(n, false);

    for (int i = 0; i < n; i++) {
      final ev = sorted[i];
      final prevIdx = (i - 1 + n) % n;
      final hasStartCap = !isContiguousWithNext[prevIdx];

      final isTargetActive =
          (activeEventId != null && ev.id == activeEventId) ||
          (currentTime != null &&
              !currentTime.isBefore(ev.start) &&
              currentTime.isBefore(ev.end));
      final isTargetSelected =
          selectedEventId != null && ev.id == selectedEventId;
      final isHighPriority = isTargetActive || isTargetSelected;
      isPriority[i] = isHighPriority;

      double baseTargetSweep = hasStartCap
          ? (is24HourMode ? minSweep24H : minSweep12H)
          : (is24HourMode ? 18.0 : 26.0);

      // Subtask-aware breathing room:
      if (ev.subtasks.isNotEmpty) {
        final subtaskTarget = is24HourMode
            ? AppLayoutConstants.targetActiveSubtaskSweepDeg24H(
                ev.subtasks.length,
              )
            : AppLayoutConstants.targetActiveSubtaskSweepDeg12H(
                ev.subtasks.length,
              );
        // Any block with subtasks targets the full subtask capacity so it has natural breathing room
        baseTargetSweep = math.max(baseTargetSweep, subtaskTarget);
      } else if (isHighPriority) {
        final priorityFloor = is24HourMode ? 28.0 : 40.0;
        baseTargetSweep = math.max(baseTargetSweep, priorityFloor);
      }

      final curSweep = ev.sweepAngle;
      if (curSweep < baseTargetSweep) {
        deficits[i] = baseTargetSweep - curSweep;
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

    final grantedFwd = List<double>.filled(n, 0.0);
    final grantedBwd = List<double>.filled(n, 0.0);
    final shiftFwd = List<double>.filled(n, 0.0);

    // 4.5. Contiguous Monolithic Rebalancing:
    // If an event with subtasks has a deficit, first borrow space directly from
    // contiguous monolithic neighbors (e.g. Sleep with large sweep and no subtasks).
    // This allows subtask pebble chips to breathe without pushing downstream events!
    final minMonolithicSweep = is24HourMode ? 28.0 : 45.0;
    for (int i = 0; i < n; i++) {
      final ev = sorted[i];
      if (ev.subtasks.isEmpty) continue;
      var remDeficit = deficits[i] - (grantedBwd[i] + grantedFwd[i]);
      if (remDeficit <= 0.001) continue;

      // 1. Borrow backward from contiguous predecessor if monolithic
      final prevIdx = (i - 1 + n) % n;
      if (isContiguousWithNext[prevIdx] && sorted[prevIdx].subtasks.isEmpty) {
        final prevEv = sorted[prevIdx];
        var minDonorSweep = minMonolithicSweep;
        if (currentTime != null &&
            !currentTime.isBefore(prevEv.start) &&
            currentTime.isBefore(prevEv.end)) {
          final elapsedMin =
              currentTime.difference(prevEv.start).inSeconds / 60.0;
          final rate = is24HourMode ? 0.25 : 0.5;
          final needleOffsetDeg = elapsedMin * rate;
          minDonorSweep = math.max(minDonorSweep, needleOffsetDeg + 12.0);
        }

        final currentPrevSweep = prevEv.sweepAngle +
            grantedFwd[prevIdx] -
            grantedBwd[prevIdx];
        final prevAvail = math.max(0.0, currentPrevSweep - minDonorSweep);
        if (prevAvail > 0.0) {
          final take = math.min(remDeficit, prevAvail);
          grantedBwd[i] += take;
          grantedFwd[prevIdx] -= take;
          remDeficit -= take;
        }
      }

      // 2. Borrow forward from contiguous successor if monolithic
      if (remDeficit > 0.001) {
        final nextIdx = (i + 1) % n;
        if (isContiguousWithNext[i] && sorted[nextIdx].subtasks.isEmpty) {
          final nextEv = sorted[nextIdx];
          var minDonorSweep = minMonolithicSweep;
          if (currentTime != null &&
              !currentTime.isBefore(nextEv.start) &&
              currentTime.isBefore(nextEv.end)) {
            final remainingMin =
                nextEv.end.difference(currentTime).inSeconds / 60.0;
            final rate = is24HourMode ? 0.25 : 0.5;
            final needleFromEndDeg = remainingMin * rate;
            minDonorSweep = math.max(minDonorSweep, needleFromEndDeg + 12.0);
          }

          final currentNextSweep = nextEv.sweepAngle +
              grantedFwd[nextIdx] -
              grantedBwd[nextIdx];
          final nextAvail = math.max(0.0, currentNextSweep - minDonorSweep);
          if (nextAvail > 0.0) {
            final takeFwd = math.min(remDeficit, nextAvail);
            grantedFwd[i] += takeFwd;
            shiftFwd[nextIdx] += takeFwd;
            grantedFwd[nextIdx] -= takeFwd;
            remDeficit -= takeFwd;
          }
        }
      }
    }

    // 5. Pass 1: Compute preferred expansion requests (backward into prev gap, forward into next gap)
    // CRITICAL: Active and selected blocks (isPriority) must NEVER borrow backward across clock time
    // so their start caps (e.g. 3:30 PM) remain strictly anchored to their clock hour mark!
    final reqBwd = List<double>.filled(n, 0.0);
    final reqFwd = List<double>.filled(n, 0.0);

    for (int i = 0; i < n; i++) {
      if (deficits[i] <= 0.001) continue;
      final d = deficits[i] - (grantedBwd[i] + grantedFwd[i]);
      if (d <= 0.001) continue;

      final prevIdx = (i - 1 + n) % n;
      final prevAvail = usableSpace[prevIdx];
      final fwdAvail = usableSpace[i];
      final canBwd = prevAvail > 0.0 && !isPriority[i];
      final canFwd = fwdAvail > 0.0;

      if (canBwd && canFwd) {
        final totalAvail = prevAvail + fwdAvail;
        if (totalAvail > 0.0) {
          reqBwd[i] = math.min(d * (prevAvail / totalAvail), prevAvail);
          reqFwd[i] = math.min(d - reqBwd[i], fwdAvail);
          final rem = d - (reqBwd[i] + reqFwd[i]);
          if (rem > 0.0) {
            final addBwd = math.min(rem, prevAvail - reqBwd[i]);
            reqBwd[i] += addBwd;
            final rem2 = rem - addBwd;
            if (rem2 > 0.0) {
              reqFwd[i] += math.min(rem2, fwdAvail - reqFwd[i]);
            }
          }
        } else {
          reqBwd[i] = d / 2.0;
          reqFwd[i] = d / 2.0;
        }
      } else if (canBwd) {
        reqBwd[i] = math.min(d, prevAvail);
      } else if (canFwd) {
        reqFwd[i] = math.min(d, fwdAvail);
      }
    }

    // 6. Allocate from each gap k: event k expands forward, event k+1 expands backward
    for (int k = 0; k < n; k++) {
      final nextIdx = (k + 1) % n;
      final demand = reqFwd[k] + reqBwd[nextIdx];
      final avail = remainingUsable[k];

      if (demand <= 0.0 || avail <= 0.0) continue;

      if (demand <= avail) {
        grantedFwd[k] += reqFwd[k];
        grantedBwd[nextIdx] += reqBwd[nextIdx];
        remainingUsable[k] = avail - demand;
      } else {
        // Prioritize active or selected events if there's contention for the same gap
        final kPrio = isPriority[k] ? 4.0 : 1.0;
        final nextPrio = isPriority[nextIdx] ? 4.0 : 1.0;
        final totalWeight = (reqFwd[k] * kPrio) + (reqBwd[nextIdx] * nextPrio);
        if (totalWeight > 0.0) {
          final fwdShare = (reqFwd[k] * kPrio) / totalWeight;
          final fwdAlloc = math.min(reqFwd[k], avail * fwdShare);
          final bwdAlloc = math.min(reqBwd[nextIdx], avail - fwdAlloc);
          grantedFwd[k] += fwdAlloc;
          grantedBwd[nextIdx] += bwdAlloc;
          remainingUsable[k] = math.max(0.0, avail - (fwdAlloc + bwdAlloc));
        } else {
          final scale = avail / demand;
          grantedFwd[k] += reqFwd[k] * scale;
          grantedBwd[nextIdx] += reqBwd[nextIdx] * scale;
          remainingUsable[k] = 0.0;
        }
      }
    }

    // 7. Pass 2: Scavenge unused forward gap space for any events still with unsatisfied deficit
    void scavenge(int i) {
      if (deficits[i] <= 0.001) return;
      final totalGranted = grantedBwd[i] + grantedFwd[i];
      var remainingDeficit = deficits[i] - totalGranted;
      if (remainingDeficit <= 0.001) return;

      // Try taking remaining deficit from next gap first
      if (remainingUsable[i] > 0.0) {
        final extraFwd = math.min(remainingDeficit, remainingUsable[i]);
        grantedFwd[i] += extraFwd;
        remainingUsable[i] -= extraFwd;
        remainingDeficit -= extraFwd;
      }

      // If still unsatisfied, borrow from downstream gaps and propagate forward shift
      if (remainingDeficit > 0.001) {
        for (int step = 1; step < n && remainingDeficit > 0.001; step++) {
          final targetGapIdx = (i + step - 1) % n;
          if (remainingUsable[targetGapIdx] > 0.0) {
            final take = math.min(
              remainingDeficit,
              remainingUsable[targetGapIdx],
            );
            grantedFwd[i] += take;
            remainingUsable[targetGapIdx] -= take;
            remainingDeficit -= take;
            for (int s = 1; s < step; s++) {
              final shiftIdx = (i + s) % n;
              shiftFwd[shiftIdx] += take;
            }
          }
        }
      }

      // Try taking remaining deficit from prev gap (only for non-priority events)
      final prevIdx = (i - 1 + n) % n;
      if (!isPriority[i] &&
          remainingDeficit > 0.001 &&
          remainingUsable[prevIdx] > 0.0) {
        final extraBwd = math.min(remainingDeficit, remainingUsable[prevIdx]);
        grantedBwd[i] += extraBwd;
        remainingUsable[prevIdx] -= extraBwd;
        remainingDeficit -= extraBwd;
      }
    }

    // Scavenge priority sectors first
    for (int i = 0; i < n; i++) {
      if (isPriority[i]) scavenge(i);
    }
    // Then scavenge standard sectors
    for (int i = 0; i < n; i++) {
      if (!isPriority[i]) scavenge(i);
    }

    // 8. Construct updated events with stretched start and sweep angles
    final updatedMap = <String, SectorEvent>{};
    for (int i = 0; i < n; i++) {
      final ev = sorted[i];
      final bwd = grantedBwd[i];
      final fwd = grantedFwd[i];

      final newStart = SectorMath.normalizeDegrees(
        ev.startAngle - bwd + shiftFwd[i],
      );
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
