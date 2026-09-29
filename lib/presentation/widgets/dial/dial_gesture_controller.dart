import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/geometry/dial_time_cap_drag_handler.dart';
import '../../../core/geometry/sector_math.dart';
import '../../../domain/models/sector_event.dart';
import '../../../engine/dial_model.dart';
import '../../../engine/ring_assigner.dart';
import '../../controllers/clock_controller.dart';
import '../../controllers/cloud_sync_controller.dart';

/// Interaction and gesture controller for the dial using [DialModel.warp.inverse].
///
/// Features:
/// 1. Uses `warp.inverse(displayAngle)` to map touches strictly to natural time,
///    fixing drag and scrub imprecision on warped / stretched sectors (I7, §4.4).
/// 2. Hit-testing directly against pre-computed [DialBlock]s and [CapsulePlacement]s.
/// 3. Cap-dragging and block-dragging in visual schedule editing mode.
/// 4. Time scrubbing around the dial rim.
class DialGestureController {
  final WidgetRef ref;
  final DialModel model;
  final Offset center;
  final double innerRadius;
  final double routineTrackIn;
  final double routineTrackOut;
  final double ringDividerRadius;
  final bool is24HourMode;
  final bool isDialEditing;
  final List<SectorEvent> allEvents;
  final SectorEvent? selectedEvent;

  DialGestureController({
    required this.ref,
    required this.model,
    required this.center,
    required this.innerRadius,
    required this.routineTrackIn,
    required this.routineTrackOut,
    required this.ringDividerRadius,
    required this.is24HourMode,
    required this.isDialEditing,
    required this.allEvents,
    this.selectedEvent,
  });

  /// Converts touch coordinates to warped display angle on the screen [0, 360).
  double touchToDisplayAngle(Offset localPosition) {
    return SectorMath.touchDeltaToDialAngle(
      localPosition.dx - center.dx,
      localPosition.dy - center.dy,
    );
  }

  /// Converts touch coordinates to natural clock angle [0, 360) via [model.warp.inverse].
  double touchToNaturalAngle(Offset localPosition) {
    final displayAngle = touchToDisplayAngle(localPosition);
    return model.warp.inverse(displayAngle);
  }

  /// Hit tests whether a touch falls on a specific [DialBlock] on the dial face.
  DialBlock? hitTestBlock(Offset localPosition) {
    final dist = (localPosition - center).distance;
    if (dist < innerRadius - 8.0 || dist > routineTrackOut + 14.0) {
      return null;
    }

    final displayAngle = touchToDisplayAngle(localPosition);
    final hasInnerBlocks = model.blocks.any((b) => b.ring == RingLevel.inner);

    // Sort by sweep ascending so topmost / smaller blocks get hit priority
    final candidateBlocks = List<DialBlock>.from(model.blocks)
      ..sort((a, b) => a.sweepDeg.compareTo(b.sweepDeg));

    for (final block in candidateBlocks) {
      if (!_isAngleInArc(displayAngle, block.startDeg, block.sweepDeg)) {
        continue;
      }

      final double rIn;
      final double rOut;
      if (hasInnerBlocks) {
        if (block.ring == RingLevel.inner) {
          rIn = routineTrackIn;
          rOut = ringDividerRadius - 1.0;
        } else {
          rIn = ringDividerRadius + 1.0;
          rOut = routineTrackOut;
        }
      } else {
        rIn = routineTrackIn;
        rOut = routineTrackOut;
      }

      const radialSlop = 8.0;
      if (dist >= rIn - radialSlop && dist <= rOut + radialSlop) {
        return block;
      }
    }

    return null;
  }

  /// Hit tests whether a touch falls on a subtask capsule inside [block].
  CapsulePlacement? hitTestCapsule(Offset localPosition, DialBlock block) {
    if (block.capsules.isEmpty) return null;
    final displayAngle = touchToDisplayAngle(localPosition);

    for (final cap in block.capsules) {
      var diff = (cap.centerDeg - displayAngle).abs() % 360.0;
      if (diff > 180.0) diff = 360.0 - diff;
      if (diff <= (cap.angularWidthDeg / 2.0) + 2.0) {
        return cap;
      }
    }
    return null;
  }

  void handleTapUp(TapUpDetails details) {
    final dist = (details.localPosition - center).distance;

    // 1. Center hub tap: deselect or cycle clock display
    if (dist <= innerRadius) {
      if (isDialEditing) return;
      if (selectedEvent != null) {
        ref.read(selectedEventProvider.notifier).state = null;
      } else {
        ref.read(dialSettingsProvider.notifier).cycleCenterClockDisplay();
      }
      return;
    }

    // 2. Block tap
    final hit = hitTestBlock(details.localPosition);
    if (hit != null) {
      // Find matching domain event
      SectorEvent? matchingEvent;
      for (final ev in allEvents) {
        if (ev.id == hit.eventId) {
          matchingEvent = ev;
          break;
        }
      }

      if (matchingEvent != null) {
        ref.read(selectedEventProvider.notifier).state = matchingEvent;
        HapticFeedback.selectionClick();
      }
    } else {
      // Tapped outside blocks: clear selection
      if (selectedEvent != null) {
        ref.read(selectedEventProvider.notifier).state = null;
      }
    }
  }

  void handlePanDown(DragDownDetails details) {
    if (!isDialEditing) return;

    final hitTarget = DialTimeCapDragHandler.findHitTarget(
      localOffset: details.localPosition,
      center: center,
      rIn: routineTrackIn,
      rOut: routineTrackOut,
      events: allEvents,
      is24HourMode: is24HourMode,
      selectedEvent: selectedEvent,
      isDialEditing: isDialEditing,
    );

    if (hitTarget != null) {
      ref.read(activeDraggingCapProvider.notifier).state = hitTarget;
      ref.read(liveAdjustedEventProvider.notifier).state = hitTarget.event;
      ref.read(selectedEventProvider.notifier).state = hitTarget.event;
      HapticFeedback.selectionClick();
    }
  }

  void handlePanStart(DragStartDetails details) {
    var activeCap = ref.read(activeDraggingCapProvider);
    if (isDialEditing && activeCap == null) {
      final hitTarget = DialTimeCapDragHandler.findHitTarget(
        localOffset: details.localPosition,
        center: center,
        rIn: routineTrackIn,
        rOut: routineTrackOut,
        events: allEvents,
        is24HourMode: is24HourMode,
        selectedEvent: selectedEvent,
        isDialEditing: isDialEditing,
      );
      if (hitTarget != null) {
        ref.read(activeDraggingCapProvider.notifier).state = hitTarget;
        ref.read(liveAdjustedEventProvider.notifier).state = hitTarget.event;
        ref.read(selectedEventProvider.notifier).state = hitTarget.event;
        HapticFeedback.selectionClick();
        activeCap = hitTarget;
      }
    }

    if (activeCap == null && !isDialEditing) {
      final screenAngle = touchToDisplayAngle(details.localPosition);
      ref.read(dialScrubAngleProvider.notifier).state = screenAngle;
    }
  }

  void handlePanUpdate(DragUpdateDetails details) {
    final activeCap = ref.read(activeDraggingCapProvider);
    if (isDialEditing && activeCap != null) {
      // CRITICAL (Phase 5): Use warp.inverse() so dragging maps linearly to natural minutes!
      final naturalAngle = touchToNaturalAngle(details.localPosition);
      final prevAdjusted = ref.read(liveAdjustedEventProvider);

      final adjResult = DialTimeCapDragHandler.calculateLiveAdjustment(
        hit: activeCap,
        currentTouchAngle: naturalAngle,
        allDayEvents: allEvents,
        is24HourMode: is24HourMode,
      );

      if (prevAdjusted == null ||
          prevAdjusted.start != adjResult.updatedEvent.start ||
          prevAdjusted.end != adjResult.updatedEvent.end) {
        HapticFeedback.selectionClick();
      }

      ref.read(liveAdjustedEventProvider.notifier).state =
          adjResult.updatedEvent;
      ref.read(liveAdjustedEventsMapProvider.notifier).state =
          adjResult.allUpdatedEvents;
    } else if (!isDialEditing) {
      final screenAngle = touchToDisplayAngle(details.localPosition);
      ref.read(dialScrubAngleProvider.notifier).state = screenAngle;
    }
  }

  void handlePanEnd(DragEndDetails details) {
    final activeCap = ref.read(activeDraggingCapProvider);
    final liveAdjusted = ref.read(liveAdjustedEventProvider);
    final liveMap = ref.read(liveAdjustedEventsMapProvider);

    if (isDialEditing && liveMap.isNotEmpty) {
      for (final updated in liveMap.values) {
        ref.read(eventRepositoryProvider).updateEvent(updated);
        ref.read(cloudSyncServiceProvider).queueUpsert(updated);
      }
      if (liveAdjusted != null) {
        ref.read(selectedEventProvider.notifier).state = liveAdjusted;
      }
      ref.read(cloudSyncControllerProvider.notifier).syncNow();
      ref.read(hasModifiedDialPositionsProvider.notifier).state = true;
      HapticFeedback.mediumImpact();
    } else if (isDialEditing && activeCap != null && liveAdjusted != null) {
      ref.read(eventRepositoryProvider).updateEvent(liveAdjusted);
      ref.read(selectedEventProvider.notifier).state = liveAdjusted;
      ref.read(cloudSyncServiceProvider).queueUpsert(liveAdjusted);
      ref.read(cloudSyncControllerProvider.notifier).syncNow();
      ref.read(hasModifiedDialPositionsProvider.notifier).state = true;
      HapticFeedback.mediumImpact();
    }

    ref.read(activeDraggingCapProvider.notifier).state = null;
    ref.read(liveAdjustedEventProvider.notifier).state = null;
    ref.read(liveAdjustedEventsMapProvider.notifier).state = const {};
    ref.read(dialScrubAngleProvider.notifier).state = null;
  }

  void handlePanCancel() {
    ref.read(activeDraggingCapProvider.notifier).state = null;
    ref.read(liveAdjustedEventProvider.notifier).state = null;
    ref.read(liveAdjustedEventsMapProvider.notifier).state = const {};
    ref.read(dialScrubAngleProvider.notifier).state = null;
  }

  static bool _isAngleInArc(
    double angleDeg,
    double startDeg,
    double sweepDeg, {
    double toleranceDeg = 2.0,
  }) {
    final normAngle = angleDeg % 360.0;
    final normStart = (startDeg - toleranceDeg) % 360.0;
    final effectiveSweep = sweepDeg + (toleranceDeg * 2.0);

    if (effectiveSweep >= 360.0) return true;

    final normEnd = (normStart + effectiveSweep) % 360.0;

    if (normStart <= normEnd) {
      return normAngle >= normStart && normAngle <= normEnd;
    } else {
      return normAngle >= normStart || normAngle <= normEnd;
    }
  }
}
