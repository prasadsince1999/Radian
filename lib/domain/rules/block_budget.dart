import 'package:flutter/foundation.dart';

import '../models/sector_event.dart';

/// Result of checking whether a candidate event fits within the dial's block budget.
@immutable
class BudgetCheckResult {
  final bool allowed;
  final int currentCount;
  final int maxAllowed;
  final String? reason;

  const BudgetCheckResult({
    required this.allowed,
    required this.currentCount,
    required this.maxAllowed,
    this.reason,
  });

  const BudgetCheckResult.ok({
    required this.currentCount,
    required this.maxAllowed,
  })  : allowed = true,
        reason = null;

  const BudgetCheckResult.exceeded({
    required this.currentCount,
    required this.maxAllowed,
    required this.reason,
  }) : allowed = false;

  @override
  String toString() =>
      allowed ? 'BudgetCheckResult.ok($currentCount/$maxAllowed)' : 'BudgetCheckResult.exceeded($currentCount/$maxAllowed: $reason)';
}

/// Unified capacity budget authority for the circular dial engine.
///
/// Replaces all disparate, hardcoded block limits (`maxDialVisibleBlocks`,
/// `maxBlocks12H`, `maxBlocks24H`) across the codebase (RC3, I1).
class BlockBudget {
  const BlockBudget._();

  /// Maximum blocks allowed per 12-Hour dial face window (AM or PM half).
  static const int maxPerWindow12H = 12;

  /// Maximum blocks allowed in a 24-Hour full-day dial face window.
  static const int maxPerWindow24H = 18;

  /// Calculates the maximum visible blocks dynamically as a function of
  /// user preferences: 1 (active) + P (previous) + N (future), bounded to [1, 7].
  static int maxVisible(int previousBlocks, int futureBlocks) {
    return (1 + previousBlocks + futureBlocks).clamp(1, 7);
  }

  /// Checks whether [candidate] can be scheduled alongside [existingEvents]
  /// without exceeding the window block budget.
  static BudgetCheckResult check({
    required List<SectorEvent> existingEvents,
    required SectorEvent candidate,
    required bool is24HourMode,
  }) {
    final candidateDay = DateTime(
      candidate.start.year,
      candidate.start.month,
      candidate.start.day,
    );

    final maxAllowed = is24HourMode ? maxPerWindow24H : maxPerWindow12H;
    final isCandidateAm = candidate.start.hour < 12;

    int count = 0;

    for (final ev in existingEvents) {
      if (ev.id == candidate.id) continue; // Exclude self if editing an existing event

      final evDay = DateTime(ev.start.year, ev.start.month, ev.start.day);
      if (evDay != candidateDay) continue;

      if (is24HourMode) {
        count++;
      } else {
        // In 12H mode, events are budgeted per AM/PM window based on start time
        final isEvAm = ev.start.hour < 12;
        if (isEvAm == isCandidateAm) {
          count++;
        }
      }
    }

    if (count >= maxAllowed) {
      final windowName = is24HourMode ? '24h day' : (isCandidateAm ? '12h AM window' : '12h PM window');
      return BudgetCheckResult.exceeded(
        currentCount: count,
        maxAllowed: maxAllowed,
        reason: 'Dial $windowName is full ($count/$maxAllowed blocks). Delete or reschedule an existing block first.',
      );
    }

    return BudgetCheckResult.ok(
      currentCount: count + 1,
      maxAllowed: maxAllowed,
    );
  }
}
