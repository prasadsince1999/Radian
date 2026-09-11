import '../../domain/models/sector_event.dart';

/// Represents the resolved 7-block horizon for Focused Block concentric dial mode.
class FocusedHorizonResult {
  /// The active event (occurring now, or focus center / selected event).
  final SectorEvent? activeEvent;

  /// Immediate preceding event (1st previous) -> Outer Ring.
  final SectorEvent? prev1;

  /// 2nd preceding event -> Inner Ring.
  final SectorEvent? prev2;

  /// 3rd preceding event -> Inner Ring.
  final SectorEvent? prev3;

  /// Immediate upcoming event (1st next) -> Outer Ring.
  final SectorEvent? next1;

  /// 2nd upcoming event -> Inner Ring.
  final SectorEvent? next2;

  /// 3rd upcoming event -> Inner Ring.
  final SectorEvent? next3;

  /// Set of event IDs allocated to the outer ring track.
  final Set<String> outerEventIds;

  /// Set of event IDs allocated to the inner ring track.
  final Set<String> innerEventIds;

  /// The filtered list of up to 7 visible events to render on the dial canvas.
  /// Any event older than [prev3] or farther than [next3] is excluded.
  final List<SectorEvent> visibleEvents;

  const FocusedHorizonResult({
    required this.activeEvent,
    required this.prev1,
    required this.prev2,
    required this.prev3,
    required this.next1,
    required this.next2,
    required this.next3,
    required this.outerEventIds,
    required this.innerEventIds,
    required this.visibleEvents,
  });

  /// Returns true if [eventId] is in the outer ring.
  bool isOuter(String eventId) => outerEventIds.contains(eventId);

  /// Returns true if [eventId] is in the inner ring.
  bool isInner(String eventId) => innerEventIds.contains(eventId);
}

/// Pure mathematical layout resolver for Focused Block mode.
///
/// Implements the Smart 7-Block Focus Horizon:
/// - Outer Ring (Tier 1 Focus): Prev 1, Active Block, Next 1
/// - Inner Ring (Tier 2 Context): Prev 3, Prev 2, Next 2, Next 3
/// - Excluded: Events older than Prev 3 and events farther than Next 3.
class FocusedBlockLayoutResolver {
  const FocusedBlockLayoutResolver._();

  /// Resolves the 7-block focus horizon from [events] relative to [effectiveTime].
  ///
  /// In 12-hour mode ([is24HourMode] = false), suppresses candidate blocks that
  /// would collide in angular sector position with higher-priority blocks on the
  /// inner ring, or that fall outside the active 12-hour window.
  static FocusedHorizonResult resolve({
    required List<SectorEvent> events,
    required DateTime effectiveTime,
    SectorEvent? selectedEvent,
    bool is24HourMode = false,
  }) {
    if (events.isEmpty) {
      return const FocusedHorizonResult(
        activeEvent: null,
        prev1: null,
        prev2: null,
        prev3: null,
        next1: null,
        next2: null,
        next3: null,
        outerEventIds: {},
        innerEventIds: {},
        visibleEvents: [],
      );
    }

    // 1. Identify active event
    SectorEvent? active;
    for (final e in events) {
      if (!effectiveTime.isBefore(e.start) && effectiveTime.isBefore(e.end)) {
        active = e;
        break;
      }
    }
    active ??= selectedEvent;
    if (active == null) {
      for (final e in events) {
        if (e.start.isAfter(effectiveTime)) {
          if (active == null || e.start.isBefore(active.start)) {
            active = e;
          }
        }
      }
    }

    final refStart = active?.start ?? effectiveTime;
    final refEnd = active?.end ?? effectiveTime;

    // 2. Identify candidate previous events (completed before refStart)
    // In 12-hour mode, only events completed within the last 12 hours are considered.
    final pastCandidates = events.where((e) {
      if (active != null && e.id == active.id) return false;
      if (e.end.isAfter(refStart)) return false;
      if (!is24HourMode) {
        if (effectiveTime.difference(e.end).inMinutes >= 720) return false;
      }
      return true;
    }).toList()..sort((a, b) => b.end.compareTo(a.end));

    // Immediate previous event -> Outer Ring
    final SectorEvent? prev1 = pastCandidates.isNotEmpty
        ? pastCandidates[0]
        : null;

    // 3. Identify candidate upcoming events (starting after refEnd)
    // In 12-hour mode, only events starting within the next 12 hours are considered.
    final futureCandidates = events.where((e) {
      if (active != null && e.id == active.id) return false;
      if (prev1 != null && e.id == prev1.id) return false;
      if (e.start.isBefore(refEnd)) return false;
      if (!is24HourMode) {
        if (e.start.difference(effectiveTime).inMinutes >= 720) return false;
      }
      return true;
    }).toList()..sort((a, b) => a.start.compareTo(b.start));

    // Immediate upcoming event -> Outer Ring
    final SectorEvent? next1 = futureCandidates.isNotEmpty
        ? futureCandidates[0]
        : null;

    // 4. Allocate Inner Ring Upcoming Events (Next 2, Next 3)
    final SectorEvent? next2;
    final SectorEvent? next3;
    if (futureCandidates.length > 1) {
      next2 = futureCandidates[1];
      if (futureCandidates.length > 2) {
        final c3 = futureCandidates[2];
        if (!is24HourMode && _arcsOverlap12H(next2, c3)) {
          next3 = null;
        } else {
          next3 = c3;
        }
      } else {
        next3 = null;
      }
    } else {
      next2 = null;
      next3 = null;
    }

    // 5. Allocate Inner Ring Previous Events (Prev 2, Prev 3)
    // In 12H mode, ensure past candidates do NOT collide with upcoming inner events
    // or with each other, avoiding confusing double-rendered angular arcs.
    SectorEvent? prev2;
    SectorEvent? prev3;

    final remainingPast = pastCandidates.skip(prev1 != null ? 1 : 0).toList();
    for (final candidate in remainingPast) {
      if (!is24HourMode) {
        // Skip ancient blocks (> 6 hours ago if we already have upcoming events)
        if (futureCandidates.isNotEmpty &&
            effectiveTime.difference(candidate.end).inMinutes > 360) {
          continue;
        }
        // Collision check against inner upcoming events
        if (next2 != null && _arcsOverlap12H(candidate, next2)) continue;
        if (next3 != null && _arcsOverlap12H(candidate, next3)) continue;
      }

      if (prev2 == null) {
        prev2 = candidate;
      } else if (prev3 == null) {
        if (!is24HourMode && _arcsOverlap12H(candidate, prev2)) continue;
        prev3 = candidate;
        break;
      }
    }

    // 6. Allocate ring IDs
    final outerEventIds = <String>{};
    final innerEventIds = <String>{};

    if (is24HourMode) {
      if (prev1 != null) outerEventIds.add(prev1.id);
      if (active != null) outerEventIds.add(active.id);
      if (next1 != null) outerEventIds.add(next1.id);
      if (selectedEvent != null) outerEventIds.add(selectedEvent.id);

      if (prev3 != null) innerEventIds.add(prev3.id);
      if (prev2 != null) innerEventIds.add(prev2.id);
      if (next2 != null) innerEventIds.add(next2.id);
      if (next3 != null) innerEventIds.add(next3.id);
    } else {
      // In 12H mode: Upcoming blocks take over outer ring if space allows,
      // preventing large empty gaps on the dial face.
      if (active != null) outerEventIds.add(active.id);
      if (prev1 != null) outerEventIds.add(prev1.id);
      if (next1 != null) outerEventIds.add(next1.id);
      if (selectedEvent != null) outerEventIds.add(selectedEvent.id);

      final outerEvents = <SectorEvent>[];
      if (active != null) outerEvents.add(active);
      if (prev1 != null) outerEvents.add(prev1);
      if (next1 != null) outerEvents.add(next1);
      if (selectedEvent != null && selectedEvent.id != active?.id) {
        outerEvents.add(selectedEvent);
      }

      // Next 2: take outer ring if no collision with existing outer events
      final n2 = next2;
      if (n2 != null) {
        if (!outerEvents.any((e) => _arcsOverlap12H(n2, e))) {
          outerEventIds.add(n2.id);
          outerEvents.add(n2);
        } else {
          innerEventIds.add(n2.id);
        }
      }

      // Next 3: take outer ring if no collision with existing outer events
      final n3 = next3;
      if (n3 != null) {
        if (!outerEvents.any((e) => _arcsOverlap12H(n3, e))) {
          outerEventIds.add(n3.id);
          outerEvents.add(n3);
        } else {
          innerEventIds.add(n3.id);
        }
      }

      // Past secondary blocks (prev2, prev3) stay in inner ring
      if (prev2 != null) innerEventIds.add(prev2.id);
      if (prev3 != null) innerEventIds.add(prev3.id);
    }

    // 7. Build visible events list
    final visibleEvents = <SectorEvent>[];
    if (prev3 != null) visibleEvents.add(prev3);
    if (prev2 != null) visibleEvents.add(prev2);
    if (prev1 != null) visibleEvents.add(prev1);
    if (active != null) visibleEvents.add(active);
    if (next1 != null) visibleEvents.add(next1);
    if (next2 != null) visibleEvents.add(next2);
    if (next3 != null) visibleEvents.add(next3);

    if (selectedEvent != null &&
        !visibleEvents.any((e) => e.id == selectedEvent.id)) {
      visibleEvents.add(selectedEvent);
    }

    return FocusedHorizonResult(
      activeEvent: active,
      prev1: prev1,
      prev2: prev2,
      prev3: prev3,
      next1: next1,
      next2: next2,
      next3: next3,
      outerEventIds: outerEventIds,
      innerEventIds: innerEventIds,
      visibleEvents: visibleEvents,
    );
  }

  /// Checks if two events overlap in angular sector space on a 12-hour dial.
  static bool _arcsOverlap12H(SectorEvent a, SectorEvent b) {
    final aDurMin = a.end.difference(a.start).inMinutes;
    final bDurMin = b.end.difference(b.start).inMinutes;
    if (aDurMin >= 720 || bDurMin >= 720) return true;

    final aStartDeg = ((a.start.hour % 12) * 60 + a.start.minute) * 0.5;
    final aSweepDeg = (aDurMin * 0.5).clamp(0.0, 360.0);

    final bStartDeg = ((b.start.hour % 12) * 60 + b.start.minute) * 0.5;
    final bSweepDeg = (bDurMin * 0.5).clamp(0.0, 360.0);

    return _intervalsOverlapOnCircle(
      aStartDeg,
      aSweepDeg,
      bStartDeg,
      bSweepDeg,
    );
  }

  /// Determines if two angular intervals [start, start + sweep] on a 360° circle overlap.
  static bool _intervalsOverlapOnCircle(
    double s1,
    double sw1,
    double s2,
    double sw2,
  ) {
    if (sw1 <= 0.5 || sw2 <= 0.5) return false;
    if (sw1 >= 360.0 || sw2 >= 360.0) return true;

    final normS1 = (s1 % 360.0 + 360.0) % 360.0;
    final normS2 = (s2 % 360.0 + 360.0) % 360.0;

    // Small threshold (e.g. 1.0°) so contiguous boundaries that touch don't trigger overlap
    const eps = 1.0;
    if (sw1 <= eps * 2 || sw2 <= eps * 2) return false;

    // Sample points along arc 1 and test if inside arc 2
    final steps = (sw1 / 5.0).ceil().clamp(3, 36);
    for (int i = 1; i < steps; i++) {
      final angle = (normS1 + (sw1 * i / steps)) % 360.0;
      if (_isAngleInsideArc(angle, normS2, sw2)) return true;
    }
    // Also test midpoint of arc 2 inside arc 1
    final mid2 = (normS2 + sw2 * 0.5) % 360.0;
    return _isAngleInsideArc(mid2, normS1, sw1);
  }

  static bool _isAngleInsideArc(double angle, double start, double sweep) {
    final diff = (angle - start) % 360.0;
    final normDiff = diff < 0 ? diff + 360.0 : diff;
    return normDiff > 0.5 && normDiff < (sweep - 0.5);
  }
}
