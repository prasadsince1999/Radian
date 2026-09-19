import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models/sector_event.dart';
import 'sector_math.dart';

/// Type of boundary cap or sector drag on the circular dial.
enum DraggedCapType { startCap, endCap, entireBlock }

/// Represents the active cap or block rotation drag state.
@immutable
class CapHitResult {
  final SectorEvent event;
  final DraggedCapType capType;
  final DateTime originalTime;
  final double initialAngle;
  final Duration originalDuration;
  final double angleOffsetFromStart;

  CapHitResult({
    required this.event,
    required this.capType,
    required this.originalTime,
    required this.initialAngle,
    Duration? originalDuration,
    this.angleOffsetFromStart = 0.0,
  }) : originalDuration = originalDuration ?? event.end.difference(event.start);

  bool get isStartCap => capType == DraggedCapType.startCap;
  bool get isEndCap => capType == DraggedCapType.endCap;
  bool get isEntireBlock => capType == DraggedCapType.entireBlock;
}

/// Result of a live drag adjustment on a sector cap or rotating block.
@immutable
class LiveCapAdjustmentResult {
  final SectorEvent updatedEvent;
  final DateTime updatedTime;
  final bool didClamp;
  final Map<String, SectorEvent> allUpdatedEvents;

  const LiveCapAdjustmentResult({
    required this.updatedEvent,
    required this.updatedTime,
    required this.didClamp,
    this.allUpdatedEvents = const {},
  });
}

/// Precision controller for detecting and live-adjusting dark time area boundary caps and rotating blocks.
class DialTimeCapDragHandler {
  DialTimeCapDragHandler._();

  /// Angular tolerance in degrees for grabbing a time badge cap.
  static const double capHitToleranceDeg = 14.0;

  /// Minimum duration enforced so events cannot be inverted or zeroed out.
  static const Duration minBlockDuration = Duration(minutes: 15);

  /// Angular distance helper handling circular wraparound [0, 360).
  static double angularDistance(double a, double b) {
    var diff = (a - b).abs() % 360.0;
    if (diff > 180.0) diff = 360.0 - diff;
    return diff;
  }

  /// Shortest signed angular delta from angle [from] to angle [to] in range [-180, 180].
  static double shortestAngleDelta(double from, double to) {
    var diff = (to - from) % 360.0;
    if (diff > 180.0) diff -= 360.0;
    if (diff < -180.0) diff += 360.0;
    return diff;
  }

  /// Detects if [localOffset] hits a dark boundary time cap on any visible sector.
  static CapHitResult? findHitCap({
    required Offset localOffset,
    required Offset center,
    required double rIn,
    required double rOut,
    required List<SectorEvent> events,
    required bool is24HourMode,
    SectorEvent? selectedEvent,
  }) {
    final dist = (localOffset - center).distance;
    // Cap hit zone: within radial track plus a generous finger padding
    if (dist < (rIn - 28.0) || dist > (rOut + 28.0)) {
      return null;
    }

    final touchAngle = SectorMath.touchDeltaToDialAngle(
      localOffset.dx - center.dx,
      localOffset.dy - center.dy,
    );

    // Prioritize selectedEvent if present
    final sortedEvents = [
      ?selectedEvent,
      ...events.where((e) => e.id != selectedEvent?.id),
    ];

    CapHitResult? bestHit;
    double minDistance = double.infinity;

    for (final event in sortedEvents) {
      if (event.isAllDay) continue;

      final startAngle = (event.sweepAngle > 0)
          ? event.startAngle
          : SectorMath.timeToDialAngle(event.start, is24HourMode: is24HourMode);
      final duration = event.end.difference(event.start);
      final sweepAngle = (event.sweepAngle > 0)
          ? event.sweepAngle
          : SectorMath.durationToSweepAngle(
              duration,
              is24HourMode: is24HourMode,
              clampMinAngle: false,
            );
      final endAngle = SectorMath.normalizeDegrees(startAngle + sweepAngle);

      // Generous boundary cap tolerance (up to 22 degrees or 32% of sector)
      final effectiveCapTol = math.min(22.0, math.max(8.0, sweepAngle * 0.32));

      // Check End Cap (crisp boundary badge at the end of the block)
      final endDist = angularDistance(touchAngle, endAngle);
      if (endDist <= effectiveCapTol && endDist < minDistance) {
        minDistance = endDist;
        bestHit = CapHitResult(
          event: event,
          capType: DraggedCapType.endCap,
          originalTime: event.end,
          initialAngle: endAngle,
          originalDuration: duration,
        );
      }

      // Check Start Cap (crisp boundary badge at the start of the block)
      final startDist = angularDistance(touchAngle, startAngle);
      if (startDist <= effectiveCapTol && startDist < minDistance) {
        minDistance = startDist;
        bestHit = CapHitResult(
          event: event,
          capType: DraggedCapType.startCap,
          originalTime: event.start,
          initialAngle: startAngle,
          originalDuration: duration,
        );
      }
    }

    return bestHit;
  }

  /// Detects whether [localOffset] hits a cap, an event sector body, or the dial ring.
  /// When [isDialEditing] is false, time blocks and boundary caps are strictly locked
  /// against dragging to prevent accidental shifts while scrubbing or viewing.
  static CapHitResult? findHitTarget({
    required Offset localOffset,
    required Offset center,
    required double rIn,
    required double rOut,
    required List<SectorEvent> events,
    required bool is24HourMode,
    SectorEvent? selectedEvent,
    bool isDialEditing = false,
  }) {
    if (!isDialEditing) {
      return null;
    }

    final dist = (localOffset - center).distance;
    final touchAngle = SectorMath.touchDeltaToDialAngle(
      localOffset.dx - center.dx,
      localOffset.dy - center.dy,
    );

    final isWithinTrack = dist >= (rIn - 24.0) && dist <= (rOut + 24.0);

    // 1. First priority: Check if hitting start or end cap badge within the sector track
    if (isWithinTrack) {
      final capHit = findHitCap(
        localOffset: localOffset,
        center: center,
        rIn: rIn,
        rOut: rOut,
        events: events,
        is24HourMode: is24HourMode,
        selectedEvent: selectedEvent,
      );
      if (capHit != null) {
        return capHit;
      }

      // 2. Second priority: Check if touching inside any visible sector body
      // In single-ring layout, shorter blocks are rendered on top of longer blocks.
      // Sort by duration ascending so topmost rendered blocks are hit-tested first.
      final sortedSectors = List<SectorEvent>.from(events)
        ..sort((a, b) {
          final durA = a.end.difference(a.start).inSeconds;
          final durB = b.end.difference(b.start).inSeconds;
          return durA.compareTo(durB);
        });

      for (final event in sortedSectors) {
        if (event.isAllDay) continue;

        final startAngle = (event.sweepAngle > 0)
            ? event.startAngle
            : SectorMath.timeToDialAngle(
                event.start,
                is24HourMode: is24HourMode,
              );
        final duration = event.end.difference(event.start);
        final sweepAngle = (event.sweepAngle > 0)
            ? event.sweepAngle
            : SectorMath.durationToSweepAngle(
                duration,
                is24HourMode: is24HourMode,
                clampMinAngle: false,
              );
        final endAngle = SectorMath.normalizeDegrees(startAngle + sweepAngle);

        final bool isInsideSector;
        if (sweepAngle >= 360.0) {
          isInsideSector = true;
        } else if (startAngle <= endAngle) {
          isInsideSector = touchAngle >= startAngle && touchAngle <= endAngle;
        } else {
          isInsideSector = touchAngle >= startAngle || touchAngle <= endAngle;
        }

        if (isInsideSector) {
          final angleOffset = SectorMath.normalizeDegrees(
            touchAngle - startAngle,
          );
          return CapHitResult(
            event: event,
            capType: DraggedCapType.entireBlock,
            originalTime: event.start,
            initialAngle: touchAngle,
            originalDuration: duration,
            angleOffsetFromStart: angleOffset,
          );
        }
      }
    }

    // 3. Third priority: In Circle Edit Mode, if user touches/rotates the dial ring or wheel
    if (isDialEditing && (dist >= 30.0 && dist <= (rOut + 60.0))) {
      final targetEvent =
          selectedEvent ??
          (events.where((e) => !e.isAllDay).isNotEmpty
              ? events.firstWhere((e) => !e.isAllDay)
              : null);
      if (targetEvent != null && !targetEvent.isAllDay) {
        final selStartAngle = SectorMath.timeToDialAngle(
          targetEvent.start,
          is24HourMode: is24HourMode,
        );
        final selDuration = targetEvent.end.difference(targetEvent.start);
        final angleOffset = SectorMath.normalizeDegrees(
          touchAngle - selStartAngle,
        );
        return CapHitResult(
          event: targetEvent,
          capType: DraggedCapType.entireBlock,
          originalTime: targetEvent.start,
          initialAngle: touchAngle,
          originalDuration: selDuration,
          angleOffsetFromStart: angleOffset,
        );
      }
    }

    return null;
  }

  /// Calculates the live-adjusted event when dragging a time cap or rotating an entire block.
  ///
  /// Snaps to 5-minute increments and dynamically clamps against adjacent blocks.
  static LiveCapAdjustmentResult calculateLiveAdjustment({
    required CapHitResult hit,
    required double currentTouchAngle,
    required List<SectorEvent> allDayEvents,
    required bool is24HourMode,
  }) {
    final event = hit.event;
    final refDay = hit.originalTime;
    final dayStart = DateTime(refDay.year, refDay.month, refDay.day, 0, 0);
    final dayEnd = DateTime(refDay.year, refDay.month, refDay.day + 1, 0, 0);

    final noon = DateTime(refDay.year, refDay.month, refDay.day, 12, 0);
    final isPm = !is24HourMode && event.start.hour >= 12;
    final segStart = is24HourMode ? dayStart : (isPm ? noon : dayStart);
    final segEnd = is24HourMode ? dayEnd : (isPm ? dayEnd : noon);

    // Active non-all-day events on this day sorted by start time
    final activeEvents = allDayEvents.where((e) => !e.isAllDay).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final myIndex = activeEvents.indexWhere((e) => e.id == event.id);

    if (hit.isEntireBlock) {
      // Rotating ENTIRE BLOCK around the dial wheel:
      // Preserves duration strictly! Shifts both start and end synchronously.
      // Cleanly clamps against adjacent blocks so events do not collide.
      final deltaAngle = shortestAngleDelta(
        hit.initialAngle,
        currentTouchAngle,
      );
      final minutesPerDegree = is24HourMode
          ? (1440.0 / 360.0)
          : (720.0 / 360.0);
      final rawMinuteShift = deltaAngle * minutesPerDegree;
      final snappedMinuteShift = (rawMinuteShift / 5.0).round() * 5;

      var candidateStart = hit.originalTime.add(
        Duration(minutes: snappedMinuteShift),
      );
      var candidateEnd = candidateStart.add(hit.originalDuration);
      var didClamp = false;

      // 1. Dynamic Clamping against preceding block
      SectorEvent? predecessor;
      for (final e in activeEvents) {
        if (e.id != event.id &&
            (e.end.isBefore(hit.originalTime) || e.end == hit.originalTime)) {
          if (predecessor == null || e.end.isAfter(predecessor.end)) {
            predecessor = e;
          }
        }
      }

      if (predecessor != null) {
        if (candidateStart.isBefore(predecessor.end)) {
          candidateStart = predecessor.end;
          candidateEnd = candidateStart.add(hit.originalDuration);
          didClamp = true;
        }
      }

      // 2. Dynamic Clamping against succeeding block
      SectorEvent? successor;
      final origEnd = hit.originalTime.add(hit.originalDuration);
      for (final e in activeEvents) {
        if (e.id != event.id &&
            (e.start.isAfter(origEnd) || e.start == origEnd)) {
          if (successor == null || e.start.isBefore(successor.start)) {
            successor = e;
          }
        }
      }

      if (successor != null) {
        if (candidateEnd.isAfter(successor.start)) {
          candidateEnd = successor.start;
          candidateStart = candidateEnd.subtract(hit.originalDuration);
          didClamp = true;
        }
      }

      // 3. Segment boundaries (segStart, segEnd)
      if (candidateStart.isBefore(segStart)) {
        candidateStart = segStart;
        candidateEnd = candidateStart.add(hit.originalDuration);
        didClamp = true;
      }
      if (candidateEnd.isAfter(segEnd)) {
        candidateEnd = segEnd;
        candidateStart = candidateEnd.subtract(hit.originalDuration);
        didClamp = true;
      }

      final updatedEvent = event.copyWith(
        start: candidateStart,
        end: candidateEnd,
      );

      return LiveCapAdjustmentResult(
        updatedEvent: updatedEvent,
        updatedTime: candidateStart,
        didClamp: didClamp,
        allUpdatedEvents: {updatedEvent.id: updatedEvent},
      );
    }

    // Angular delta from the initial drag angle of this cap to the current touch angle
    final deltaAngle = shortestAngleDelta(hit.initialAngle, currentTouchAngle);
    final minutesPerDegree = is24HourMode ? (1440.0 / 360.0) : (720.0 / 360.0);
    final rawMinuteShift = deltaAngle * minutesPerDegree;
    final snappedMinuteShift = (rawMinuteShift / 5.0).round() * 5;

    // Shift candidate time continuously from hit.originalTime in 5-minute increments
    var candidateTime = hit.originalTime.add(
      Duration(minutes: snappedMinuteShift),
    );

    var didClamp = false;

    if (hit.isStartCap) {
      // Dragging START cap: adjust start time
      // 1. Must be before end time by at least minBlockDuration
      final maxBlockDuration = is24HourMode
          ? const Duration(hours: 24)
          : const Duration(hours: 12);
      final maxAllowedStart = event.end.subtract(minBlockDuration);
      final minAllowedStart = event.end.subtract(maxBlockDuration);
      final earliestStart = minAllowedStart.isAfter(segStart)
          ? minAllowedStart
          : segStart;
      if (candidateTime.isAfter(maxAllowedStart)) {
        candidateTime = maxAllowedStart;
        didClamp = true;
      }
      if (candidateTime.isBefore(earliestStart)) {
        candidateTime = earliestStart;
        didClamp = true;
      }

      var updatedEvent = event.copyWith(start: candidateTime);
      final Map<String, SectorEvent> allUpdated = {
        updatedEvent.id: updatedEvent,
      };

      // 2. Naturally push preceding blocks backward if overlapping!
      if (myIndex != -1) {
        activeEvents[myIndex] = updatedEvent;
        for (int i = myIndex - 1; i >= 0; i--) {
          final succ = activeEvents[i + 1];
          final curr = activeEvents[i];
          if (curr.end.isAfter(succ.start)) {
            final dur = curr.end.difference(curr.start);
            var newEnd = succ.start;
            var newStart = newEnd.subtract(dur);
            if (newStart.isBefore(segStart)) {
              newStart = segStart;
              newEnd = newStart.add(dur);
              didClamp = true;

              // Propagate forward clamp: blocks cannot be pushed before segStart
              var clampBoundary = newEnd;
              for (int k = i + 1; k <= myIndex; k++) {
                if (activeEvents[k].start.isBefore(clampBoundary)) {
                  final kDur = activeEvents[k].end.difference(
                    activeEvents[k].start,
                  );
                  final kNewStart = clampBoundary;
                  final kNewEnd = (k == myIndex)
                      ? activeEvents[k].end
                      : kNewStart.add(kDur);
                  final clampedEvent = activeEvents[k].copyWith(
                    start: kNewStart,
                    end: kNewEnd,
                  );
                  activeEvents[k] = clampedEvent;
                  allUpdated[clampedEvent.id] = clampedEvent;
                  if (k == myIndex) {
                    candidateTime = kNewStart;
                    updatedEvent = clampedEvent;
                  }
                  clampBoundary = kNewEnd;
                }
              }
            }
            final pushed = curr.copyWith(start: newStart, end: newEnd);
            activeEvents[i] = pushed;
            allUpdated[pushed.id] = pushed;
          } else {
            break;
          }
        }
      }

      return LiveCapAdjustmentResult(
        updatedEvent: updatedEvent,
        updatedTime: candidateTime,
        didClamp: didClamp,
        allUpdatedEvents: allUpdated,
      );
    } else {
      // Dragging END cap: adjust end time
      // 1. Must be after start time by at least minBlockDuration
      final minAllowedEnd = event.start.add(minBlockDuration);
      if (candidateTime.isBefore(minAllowedEnd)) {
        candidateTime = minAllowedEnd;
        didClamp = true;
      }
      final maxBlockDuration = is24HourMode
          ? const Duration(hours: 24)
          : const Duration(hours: 12);
      final maxAllowedEnd = event.start.add(maxBlockDuration);
      final latestEnd = maxAllowedEnd.isBefore(segEnd) ? maxAllowedEnd : segEnd;
      if (candidateTime.isAfter(latestEnd)) {
        candidateTime = latestEnd;
        didClamp = true;
      }

      var updatedEvent = event.copyWith(end: candidateTime);
      final Map<String, SectorEvent> allUpdated = {
        updatedEvent.id: updatedEvent,
      };

      // 2. Naturally push succeeding blocks forward if overlapping!
      if (myIndex != -1) {
        activeEvents[myIndex] = updatedEvent;
        for (int i = myIndex + 1; i < activeEvents.length; i++) {
          final pred = activeEvents[i - 1];
          final curr = activeEvents[i];
          if (curr.start.isBefore(pred.end)) {
            final dur = curr.end.difference(curr.start);
            var newStart = pred.end;
            var newEnd = newStart.add(dur);
            if (newEnd.isAfter(latestEnd)) {
              newEnd = latestEnd;
              newStart = newEnd.subtract(dur);
              didClamp = true;

              // Propagate backward clamp: blocks cannot be pushed past latestEnd
              var clampBoundary = newStart;
              for (int k = i - 1; k >= myIndex; k--) {
                if (activeEvents[k].end.isAfter(clampBoundary)) {
                  final kDur = activeEvents[k].end.difference(
                    activeEvents[k].start,
                  );
                  final kNewEnd = clampBoundary;
                  final kNewStart = (k == myIndex)
                      ? activeEvents[k].start
                      : kNewEnd.subtract(kDur);
                  final clampedEvent = activeEvents[k].copyWith(
                    start: kNewStart,
                    end: kNewEnd,
                  );
                  activeEvents[k] = clampedEvent;
                  allUpdated[clampedEvent.id] = clampedEvent;
                  if (k == myIndex) {
                    candidateTime = kNewEnd;
                    updatedEvent = clampedEvent;
                  }
                  clampBoundary = kNewStart;
                }
              }
            }
            final pushed = curr.copyWith(start: newStart, end: newEnd);
            activeEvents[i] = pushed;
            allUpdated[pushed.id] = pushed;
          } else {
            break;
          }
        }
      }

      return LiveCapAdjustmentResult(
        updatedEvent: updatedEvent,
        updatedTime: candidateTime,
        didClamp: didClamp,
        allUpdatedEvents: allUpdated,
      );
    }
  }

  /// Detects whether [localOffset] hits the central text title & icon area of [event]
  /// rather than the generic outer sector surface.
  static bool isTitleTextHit({
    required Offset localOffset,
    required Offset center,
    required double rIn,
    required double rOut,
    required SectorEvent event,
    required bool is24HourMode,
  }) {
    final dist = (localOffset - center).distance;
    if (dist < (rIn - 8.0) || dist > (rOut + 8.0)) {
      return false;
    }

    final touchAngle = SectorMath.touchDeltaToDialAngle(
      localOffset.dx - center.dx,
      localOffset.dy - center.dy,
    );

    final startAngle = SectorMath.timeToDialAngle(
      event.start,
      is24HourMode: is24HourMode,
    );
    final sweepAngle = SectorMath.durationToSweepAngle(
      event.end.difference(event.start),
      is24HourMode: is24HourMode,
      clampMinAngle: false,
    );

    final midAngle = SectorMath.normalizeDegrees(
      startAngle + (sweepAngle / 2.0),
    );
    final angDist = angularDistance(touchAngle, midAngle);

    final maxTitleTolDeg = math.max(6.5, sweepAngle * 0.22);
    return angDist <= maxTitleTolDeg;
  }

  /// Discovers free, non-overlapping intervals on the given calendar [day]
  /// between existing non-all-day events.
  static List<(DateTime, DateTime)> findFreeGaps({
    required List<SectorEvent> events,
    required DateTime day,
  }) {
    final startOfDay = DateTime(day.year, day.month, day.day, 0, 0);
    final endOfDay = DateTime(day.year, day.month, day.day + 1, 0, 0);

    final activeEvents =
        events
            .where(
              (e) =>
                  !e.isAllDay &&
                  e.end.isAfter(startOfDay) &&
                  e.start.isBefore(endOfDay),
            )
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));

    final gaps = <(DateTime, DateTime)>[];
    var cursor = startOfDay;

    for (final ev in activeEvents) {
      if (ev.start.isAfter(cursor)) {
        final gapMinutes = ev.start.difference(cursor).inMinutes;
        if (gapMinutes >= 15) {
          gaps.add((cursor, ev.start));
        }
      }
      if (ev.end.isAfter(cursor)) {
        cursor = ev.end;
      }
    }

    if (endOfDay.isAfter(cursor)) {
      final gapMinutes = endOfDay.difference(cursor).inMinutes;
      if (gapMinutes >= 15) {
        gaps.add((cursor, endOfDay));
      }
    }

    return gaps;
  }
}
