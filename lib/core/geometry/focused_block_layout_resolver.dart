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
  static FocusedHorizonResult resolve({
    required List<SectorEvent> events,
    required DateTime effectiveTime,
    SectorEvent? selectedEvent,
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

    // 2. Identify previous events (up to 3 completed before refStart)
    // Sorted by end descending (most recently completed first)
    final pastCandidates = events.where((e) {
      if (active != null && e.id == active.id) return false;
      return !e.end.isAfter(refStart);
    }).toList()..sort((a, b) => b.end.compareTo(a.end));

    final SectorEvent? prev1 = pastCandidates.isNotEmpty
        ? pastCandidates[0]
        : null;
    final SectorEvent? prev2 = pastCandidates.length > 1
        ? pastCandidates[1]
        : null;
    final SectorEvent? prev3 = pastCandidates.length > 2
        ? pastCandidates[2]
        : null;

    // 3. Identify upcoming events (up to 3 starting after refEnd)
    // Sorted by start ascending (earliest upcoming first)
    final futureCandidates = events.where((e) {
      if (active != null && e.id == active.id) return false;
      if (prev1 != null && e.id == prev1.id) return false;
      if (prev2 != null && e.id == prev2.id) return false;
      if (prev3 != null && e.id == prev3.id) return false;
      return !e.start.isBefore(refEnd);
    }).toList()..sort((a, b) => a.start.compareTo(b.start));

    final SectorEvent? next1 = futureCandidates.isNotEmpty
        ? futureCandidates[0]
        : null;
    final SectorEvent? next2 = futureCandidates.length > 1
        ? futureCandidates[1]
        : null;
    final SectorEvent? next3 = futureCandidates.length > 2
        ? futureCandidates[2]
        : null;

    // 4. Allocate ring IDs
    final outerEventIds = <String>{};
    if (prev1 != null) outerEventIds.add(prev1.id);
    if (active != null) outerEventIds.add(active.id);
    if (next1 != null) outerEventIds.add(next1.id);
    if (selectedEvent != null) outerEventIds.add(selectedEvent.id);

    final innerEventIds = <String>{};
    if (prev3 != null) innerEventIds.add(prev3.id);
    if (prev2 != null) innerEventIds.add(prev2.id);
    if (next2 != null) innerEventIds.add(next2.id);
    if (next3 != null) innerEventIds.add(next3.id);

    // 5. Build visible events list (only the 7 horizon events + selected if external)
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
}
