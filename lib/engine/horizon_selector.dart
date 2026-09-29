import 'package:timezone/timezone.dart' as tz;

import 'angular_occupancy.dart';
import 'dial_input.dart';

enum BlockTier {
  /// Tier A: Highest visual priority (Active event, Next 1 upcoming).
  /// Receives full expanded sweep, river pebbles, and content ideal sizing.
  A,

  /// Tier B: Secondary priority (Previous 1, Next 2 upcoming).
  B,

  /// Tier C: Peripheral context (Previous 2/3, Next 3).
  C,
}

enum BlockRole { selected, active, next, prev }

/// A contiguous segment of an event occurrence on the dial face.
///
/// Midnight-crossing blocks are divided into 2 segments (segmentIndex 0 and 1).
class OccurrenceSegment {
  final Occurrence occurrence;
  final int segmentIndex;
  final DateTime segmentStart;
  final DateTime segmentEnd;
  final double naturalStartDeg;
  final double naturalSweepDeg;
  final BlockTier tier;
  final BlockRole role;
  final int rank; // 0 = active/selected, 1 = prev1/next1, 2 = prev2/next2, etc.

  const OccurrenceSegment({
    required this.occurrence,
    required this.segmentIndex,
    required this.segmentStart,
    required this.segmentEnd,
    required this.naturalStartDeg,
    required this.naturalSweepDeg,
    required this.tier,
    required this.role,
    required this.rank,
  });

  String get eventId => occurrence.eventId;
  String get title => occurrence.title;
  Duration get duration => segmentEnd.difference(segmentStart);

  Map<String, dynamic> toJson() => {
    'id': '${occurrence.id}#$segmentIndex',
    'eventId': occurrence.eventId,
    'segmentIndex': segmentIndex,
    'title': occurrence.title,
    'start': segmentStart.toIso8601String(),
    'end': segmentEnd.toIso8601String(),
    'naturalStartDeg': naturalStartDeg,
    'naturalSweepDeg': naturalSweepDeg,
    'tier': tier.name,
    'role': role.name,
    'rank': rank,
  };

  @override
  String toString() =>
      'OccurrenceSegment(${occurrence.title}#$segmentIndex, ${tier.name}, ${naturalStartDeg.toStringAsFixed(1)}°+${naturalSweepDeg.toStringAsFixed(1)}°)';
}

class HiddenEventInfo {
  final String eventId;
  final String title;
  final String reason;

  const HiddenEventInfo({
    required this.eventId,
    required this.title,
    required this.reason,
  });

  Map<String, dynamic> toJson() => {
    'eventId': eventId,
    'title': title,
    'reason': reason,
  };

  @override
  String toString() => 'HiddenEventInfo($eventId "$title": $reason)';
}

class HiddenSummary {
  final int hiddenCount;
  final List<HiddenEventInfo> hiddenEvents;

  const HiddenSummary({this.hiddenCount = 0, this.hiddenEvents = const []});

  const HiddenSummary.empty() : hiddenCount = 0, hiddenEvents = const [];

  Map<String, dynamic> toJson() => {
    'hiddenCount': hiddenCount,
    'hiddenEvents': hiddenEvents.map((e) => e.toJson()).toList(),
  };

  @override
  String toString() => 'HiddenSummary(count: $hiddenCount)';
}

class HorizonResult {
  final List<OccurrenceSegment> visibleSegments;
  final HiddenSummary hidden;
  final Occurrence? activeEvent;
  final Occurrence? focusEvent;

  const HorizonResult({
    required this.visibleSegments,
    required this.hidden,
    this.activeEvent,
    this.focusEvent,
  });

  /// Convenience getter returning distinct visible occurrences admitted by horizon selection.
  List<Occurrence> get visible =>
      visibleSegments.map((s) => s.occurrence).toList();

  @override
  String toString() =>
      'HorizonResult(visible: ${visibleSegments.length}, hidden: ${hidden.hiddenCount}, active: ${activeEvent?.title})';
}

/// Core Horizon Selector implementing Invariants I2, I3, I5 and §4.3.
///
/// Features:
/// 1. True P=0 behavior (when previousBlocksCount == 0, NO previous blocks are admitted).
/// 2. Deterministic priority ordering: selected -> active -> next1 -> prev1 -> next2 -> prev2 -> next3 -> prev3.
/// 3. Invariant: visible.length <= 1 + P + N.
/// 4. 12H Angular Occupancy test: rejects candidates that alias with earlier admitted arcs.
/// 5. Order-independent: sorting occurrences chronologically before selection ensures
///    the output is completely independent of input list permutation.
class HorizonSelector {
  const HorizonSelector._();

  /// Calculates natural dial angle in degrees [0, 360) from a wall-clock DateTime.
  static double naturalAngleDeg(DateTime time, {required bool is24HourMode}) {
    final double minutesOfDay =
        time.hour * 60.0 + time.minute + time.second / 60.0;
    if (is24HourMode) {
      // 24 hours = 1440 minutes -> 0.25 deg/min
      return (minutesOfDay * 0.25) % 360.0;
    } else {
      // 12 hours = 720 minutes -> 0.5 deg/min
      return (minutesOfDay % 720.0) * 0.5;
    }
  }

  /// Calculates natural sweep in degrees [0, 360] from duration.
  static double naturalSweepDeg(
    Duration duration, {
    required bool is24HourMode,
  }) {
    final double minutes = duration.inSeconds / 60.0;
    final double degPerMin = is24HourMode ? 0.25 : 0.5;
    final double rawSweep = minutes * degPerMin;
    return rawSweep.clamp(0.0, 360.0);
  }

  /// Evaluates occurrences against the current clock and horizon window.
  static HorizonResult select(DialInput input) {
    final now = input.now;
    final prefs = input.prefs;
    final is24 = prefs.is24HourMode;
    final pLimit = prefs.previousBlocksCount.clamp(0, 3);
    final nLimit = prefs.futureBlocksCount.clamp(0, 3);

    // 1. Establish window interval
    final DateTime windowStart;
    final DateTime windowEnd;

    switch (input.window) {
      case DialWindowMode.rolling:
        windowStart = now.subtract(const Duration(hours: 12));
        windowEnd = now.add(const Duration(hours: 12));
        break;
      case DialWindowMode.segmentAm:
        windowStart = now.isUtc
            ? DateTime.utc(now.year, now.month, now.day, 0, 0)
            : DateTime(now.year, now.month, now.day, 0, 0);
        windowEnd = now.isUtc
            ? DateTime.utc(now.year, now.month, now.day, 12, 0)
            : DateTime(now.year, now.month, now.day, 12, 0);
        break;
      case DialWindowMode.segmentPm:
        windowStart = now.isUtc
            ? DateTime.utc(now.year, now.month, now.day, 12, 0)
            : DateTime(now.year, now.month, now.day, 12, 0);
        windowEnd = now.isUtc
            ? DateTime.utc(now.year, now.month, now.day + 1, 0, 0)
            : DateTime(now.year, now.month, now.day + 1, 0, 0);
        break;
      case DialWindowMode.fullDay24:
        windowStart = now.isUtc
            ? DateTime.utc(now.year, now.month, now.day, 0, 0)
            : DateTime(now.year, now.month, now.day, 0, 0);
        windowEnd = now.isUtc
            ? DateTime.utc(now.year, now.month, now.day + 1, 0, 0)
            : DateTime(now.year, now.month, now.day + 1, 0, 0);
        break;
    }

    // 2. Normalize input occurrences to match now's timezone representation,
    //    filter non-all-day occurrences intersecting the window, and sort chronologically.
    final normalizedOccurrences = input.occurrences.map((o) {
      if (o.start.isUtc == now.isUtc &&
          o.start.timeZoneOffset == now.timeZoneOffset &&
          o.end.isUtc == now.isUtc &&
          o.end.timeZoneOffset == now.timeZoneOffset) {
        return o;
      }
      final s = o.start;
      final e = o.end;
      final DateTime normStart;
      final DateTime normEnd;

      if (now is tz.TZDateTime) {
        normStart = tz.TZDateTime(
          now.location,
          s.year,
          s.month,
          s.day,
          s.hour,
          s.minute,
          s.second,
          s.millisecond,
        );
        normEnd = tz.TZDateTime(
          now.location,
          e.year,
          e.month,
          e.day,
          e.hour,
          e.minute,
          e.second,
          e.millisecond,
        );
      } else if (now.isUtc) {
        normStart = DateTime.utc(
          s.year,
          s.month,
          s.day,
          s.hour,
          s.minute,
          s.second,
          s.millisecond,
        );
        normEnd = DateTime.utc(
          e.year,
          e.month,
          e.day,
          e.hour,
          e.minute,
          e.second,
          e.millisecond,
        );
      } else {
        normStart = DateTime(
          s.year,
          s.month,
          s.day,
          s.hour,
          s.minute,
          s.second,
          s.millisecond,
        );
        normEnd = DateTime(
          e.year,
          e.month,
          e.day,
          e.hour,
          e.minute,
          e.second,
          e.millisecond,
        );
      }
      return o.copyWith(start: normStart, end: normEnd);
    });

    final windowOccurrences = normalizedOccurrences.where((o) {
      if (o.isAllDay) return false;
      return o.end.isAfter(windowStart) && o.start.isBefore(windowEnd);
    }).toList()..sort((a, b) => a.start.compareTo(b.start));

    // 3. Identify Active block (covering now)
    Occurrence? active;
    for (final o in windowOccurrences) {
      if ((o.start.isBefore(now) || o.start == now) && o.end.isAfter(now)) {
        active = o;
        break;
      }
    }

    // 4. Identify Selected block
    Occurrence? selected;
    final selectedId = input.focus.selectedEventId;
    if (selectedId != null) {
      selected = windowOccurrences
          .where((o) => o.eventId == selectedId)
          .firstOrNull;
    }

    // 5. Partition Remaining into Upcoming (next) and Preceding (prev)
    // Upcoming: starts at or after now (or active's end if active exists)
    final anchorTime = active != null ? active.end : now;
    final prevAnchorTime = active != null ? active.start : now;

    final upcomingCandidates = windowOccurrences.where((o) {
      if (o.id == active?.id || o.id == selected?.id) return false;
      return o.start.isAfter(anchorTime) || o.start == anchorTime;
    }).toList()..sort((a, b) => a.start.compareTo(b.start)); // Ascending

    final previousCandidates =
        windowOccurrences.where((o) {
          if (o.id == active?.id || o.id == selected?.id) return false;
          return o.end.isBefore(prevAnchorTime) || o.end == prevAnchorTime;
        }).toList()..sort(
          (a, b) => b.end.compareTo(a.end),
        ); // Descending (most recent first)

    // 6. Build prioritized candidate list:
    // Priority order: selected -> active -> next1 -> prev1 -> next2 -> prev2 -> next3 -> prev3
    final orderedCandidates = <_RankedCandidate>[];

    if (selected != null) {
      orderedCandidates.add(
        _RankedCandidate(
          occurrence: selected,
          role: BlockRole.selected,
          tier: BlockTier.A,
          rank: 0,
        ),
      );
    }

    if (active != null && active.id != selected?.id) {
      orderedCandidates.add(
        _RankedCandidate(
          occurrence: active,
          role: BlockRole.active,
          tier: BlockTier.A,
          rank: 0,
        ),
      );
    }

    // Interleave Next and Prev by rank (Next before Prev per §4.3)
    final maxRanks = 3;
    for (int r = 1; r <= maxRanks; r++) {
      // Next at rank r (if within N limit)
      if (r <= nLimit && r <= upcomingCandidates.length) {
        final occ = upcomingCandidates[r - 1];
        if (occ.id != selected?.id) {
          final tier = r == 1
              ? BlockTier.A
              : (r == 2 ? BlockTier.B : BlockTier.C);
          orderedCandidates.add(
            _RankedCandidate(
              occurrence: occ,
              role: BlockRole.next,
              tier: tier,
              rank: r,
            ),
          );
        }
      }

      // Prev at rank r (if within P limit) - true P=0 skips this entirely!
      if (r <= pLimit && r <= previousCandidates.length) {
        final occ = previousCandidates[r - 1];
        if (occ.id != selected?.id) {
          final tier = r == 1 ? BlockTier.B : BlockTier.C;
          orderedCandidates.add(
            _RankedCandidate(
              occurrence: occ,
              role: BlockRole.prev,
              tier: tier,
              rank: r,
            ),
          );
        }
      }
    }

    // 7. Angular Occupancy test (in 12H mode, detect AM/PM aliasing)
    final occupancy = AngularOccupancy(guardGapDeg: 1.5);
    final visibleSegments = <OccurrenceSegment>[];
    final hiddenEvents = <HiddenEventInfo>[];

    for (final candidate in orderedCandidates) {
      final occ = candidate.occurrence;
      final startAngle = naturalAngleDeg(occ.start, is24HourMode: is24);
      final sweepAngle = naturalSweepDeg(occ.duration, is24HourMode: is24);

      if (!is24) {
        // 12-Hour Angular Occupancy Test
        final conflictingId = occupancy.conflictingEventId(
          startAngle,
          sweepAngle,
        );
        if (conflictingId != null) {
          hiddenEvents.add(
            HiddenEventInfo(
              eventId: occ.eventId,
              title: occ.title,
              reason: 'aliasesWith:$conflictingId',
            ),
          );
          continue;
        }
      }

      // Check if block crosses midnight
      if (occ.start.day != occ.end.day &&
          occ.end.difference(occ.start) < const Duration(hours: 24)) {
        final midnight = occ.start.isUtc
            ? DateTime.utc(
                occ.start.year,
                occ.start.month,
                occ.start.day + 1,
                0,
                0,
              )
            : DateTime(
                occ.start.year,
                occ.start.month,
                occ.start.day + 1,
                0,
                0,
              );
        final seg0Duration = midnight.difference(occ.start);
        final seg1Duration = occ.end.difference(midnight);

        final seg0Sweep = naturalSweepDeg(seg0Duration, is24HourMode: is24);
        final seg1Sweep = naturalSweepDeg(seg1Duration, is24HourMode: is24);

        visibleSegments.add(
          OccurrenceSegment(
            occurrence: occ,
            segmentIndex: 0,
            segmentStart: occ.start,
            segmentEnd: midnight,
            naturalStartDeg: startAngle,
            naturalSweepDeg: seg0Sweep,
            tier: candidate.tier,
            role: candidate.role,
            rank: candidate.rank,
          ),
        );

        visibleSegments.add(
          OccurrenceSegment(
            occurrence: occ,
            segmentIndex: 1,
            segmentStart: midnight,
            segmentEnd: occ.end,
            naturalStartDeg: 0.0,
            naturalSweepDeg: seg1Sweep,
            tier: candidate.tier,
            role: candidate.role,
            rank: candidate.rank,
          ),
        );
      } else {
        visibleSegments.add(
          OccurrenceSegment(
            occurrence: occ,
            segmentIndex: 0,
            segmentStart: occ.start,
            segmentEnd: occ.end,
            naturalStartDeg: startAngle,
            naturalSweepDeg: sweepAngle,
            tier: candidate.tier,
            role: candidate.role,
            rank: candidate.rank,
          ),
        );
      }

      // Mark occupied on the face
      occupancy.admit(startAngle, sweepAngle, occ.eventId);
    }

    return HorizonResult(
      visibleSegments: visibleSegments,
      hidden: HiddenSummary(
        hiddenCount: hiddenEvents.length,
        hiddenEvents: hiddenEvents,
      ),
      activeEvent: active,
      focusEvent: selected ?? active,
    );
  }
}

class _RankedCandidate {
  final Occurrence occurrence;
  final BlockRole role;
  final BlockTier tier;
  final int rank;

  const _RankedCandidate({
    required this.occurrence,
    required this.role,
    required this.tier,
    required this.rank,
  });
}
