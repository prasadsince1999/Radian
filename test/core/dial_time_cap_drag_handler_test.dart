import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/core/geometry/dial_time_cap_drag_handler.dart';
import 'package:sectograph_mcp/core/geometry/sector_math.dart';
import 'package:sectograph_mcp/domain/models/sector_event.dart';

void main() {
  group('DialTimeCapDragHandler Tests', () {
    const center = Offset(200, 200);
    const rIn = 100.0;
    const rOut = 180.0;
    const midR = 140.0;

    // Setup two events:
    // Event A: 8:30 PM – 9:30 PM (20:30 – 21:30)
    // Event B: 9:30 PM – 11:30 PM (21:30 – 23:30)
    final eventA = SectorEvent(
      id: 'event-a',
      title: 'Cooking+Lunch',
      start: DateTime(2026, 9, 12, 20, 30),
      end: DateTime(2026, 9, 12, 21, 30),
    );

    final eventB = SectorEvent(
      id: 'event-b',
      title: 'Study Time',
      start: DateTime(2026, 9, 12, 21, 30),
      end: DateTime(2026, 9, 12, 23, 30),
    );

    test('findHitCap detects touch on end cap', () {
      // In 12H mode, 9:30 PM is angle for 9:30 -> (9.5 / 12) * 360 = 285°
      final endAngleA = SectorMath.timeToDialAngle(
        eventA.end,
        is24HourMode: false,
      );
      final rad = SectorMath.dialAngleToCanvasRadians(endAngleA);
      final touchPos = Offset(
        center.dx + midR * math.cos(rad),
        center.dy + midR * math.sin(rad),
      );

      final hit = DialTimeCapDragHandler.findHitCap(
        localOffset: touchPos,
        center: center,
        rIn: rIn,
        rOut: rOut,
        events: [eventA, eventB],
        is24HourMode: false,
      );

      expect(hit, isNotNull);
      expect(hit!.capType, DraggedCapType.endCap);
      expect(hit.event.id, 'event-a');
      expect(hit.originalTime, DateTime(2026, 9, 12, 21, 30));
    });

    test('calculateLiveAdjustment snaps to 5 minutes', () {
      final hit = CapHitResult(
        event: eventA,
        capType: DraggedCapType.endCap,
        originalTime: eventA.end,
        initialAngle: 285.0,
      );

      // Drag to angle corresponding to 9:18 PM (20:30 + 48m)
      final targetAngle = SectorMath.timeToDialAngle(
        DateTime(2026, 9, 12, 21, 18),
        is24HourMode: false,
      );

      final result = DialTimeCapDragHandler.calculateLiveAdjustment(
        hit: hit,
        currentTouchAngle: targetAngle,
        allDayEvents: [eventA, eventB],
        is24HourMode: false,
      );

      // 9:18 PM snaps to 9:20 PM
      expect(result.updatedTime.minute, 20);
      expect(result.updatedTime.hour, 21);
      expect(result.updatedEvent.end, DateTime(2026, 9, 12, 21, 20));
      expect(result.didClamp, false);
    });

    test('calculateLiveAdjustment naturally pushes succeeding blocks when dragging end cap', () {
      final hit = CapHitResult(
        event: eventA,
        capType: DraggedCapType.endCap,
        originalTime: eventA.end,
        initialAngle: 285.0,
      );

      // Attempt to drag end of eventA into 10:00 PM (which overlaps Study Time starting at 9:30 PM)
      final targetAngle = SectorMath.timeToDialAngle(
        DateTime(2026, 9, 12, 22, 0),
        is24HourMode: false,
      );

      final result = DialTimeCapDragHandler.calculateLiveAdjustment(
        hit: hit,
        currentTouchAngle: targetAngle,
        allDayEvents: [eventA, eventB],
        is24HourMode: false,
      );

      // Event A expands to 22:00
      expect(result.updatedTime, DateTime(2026, 9, 12, 22, 0));
      expect(result.updatedEvent.end, DateTime(2026, 9, 12, 22, 0));
      // Event B (originally 21:30 - 23:30, duration 2h) is naturally pushed forward to 22:00 - 24:00!
      expect(
        result.allUpdatedEvents[eventB.id]?.start,
        DateTime(2026, 9, 12, 22, 0),
      );
      expect(
        result.allUpdatedEvents[eventB.id]?.end,
        DateTime(2026, 9, 13, 0, 0),
      );
      expect(
        result.allUpdatedEvents[eventB.id]!.end.difference(
          result.allUpdatedEvents[eventB.id]!.start,
        ),
        const Duration(hours: 2),
      );
    });

    test('calculateLiveAdjustment enforces 15-minute minimum duration', () {
      final hit = CapHitResult(
        event: eventA,
        capType: DraggedCapType.endCap,
        originalTime: eventA.end,
        initialAngle: 285.0,
      );

      // Attempt to drag end of eventA before or at start (e.g. 8:35 PM, duration 5 min)
      final targetAngle = SectorMath.timeToDialAngle(
        DateTime(2026, 9, 12, 20, 35),
        is24HourMode: false,
      );

      final result = DialTimeCapDragHandler.calculateLiveAdjustment(
        hit: hit,
        currentTouchAngle: targetAngle,
        allDayEvents: [eventA, eventB],
        is24HourMode: false,
      );

      // Enforced minimum duration of 15 min: 8:30 + 15m = 8:45 PM
      expect(result.updatedTime, DateTime(2026, 9, 12, 20, 45));
      expect(result.didClamp, true);
    });

    test('findHitTarget locks blocks when isDialEditing is false, and detects entireBlock when isDialEditing is true', () {
      // Midpoint of Event B (9:30 PM to 11:30 PM) is 10:30 PM -> 315°
      final midAngleB = SectorMath.timeToDialAngle(
        DateTime(2026, 9, 12, 22, 30),
        is24HourMode: false,
      );
      final rad = SectorMath.dialAngleToCanvasRadians(midAngleB);
      final touchPos = Offset(
        center.dx + midR * math.cos(rad),
        center.dy + midR * math.sin(rad),
      );

      // When NOT in Edit mode (isDialEditing: false), blocks are strictly locked against dragging
      final lockedHit = DialTimeCapDragHandler.findHitTarget(
        localOffset: touchPos,
        center: center,
        rIn: rIn,
        rOut: rOut,
        events: [eventA, eventB],
        is24HourMode: false,
        isDialEditing: false,
      );
      expect(lockedHit, isNull);

      // When in Edit mode (isDialEditing: true), block dragging is unlocked
      final hit = DialTimeCapDragHandler.findHitTarget(
        localOffset: touchPos,
        center: center,
        rIn: rIn,
        rOut: rOut,
        events: [eventA, eventB],
        is24HourMode: false,
        isDialEditing: true,
      );

      expect(hit, isNotNull);
      expect(hit!.capType, DraggedCapType.entireBlock);
      expect(hit.event.id, 'event-b');
      expect(hit.originalDuration, const Duration(hours: 2));
    });

    test('calculateLiveAdjustment for entireBlock rotates and preserves exact duration', () {
      final initialAngle = SectorMath.timeToDialAngle(
        DateTime(2026, 9, 12, 22, 30),
        is24HourMode: false,
      );
      final hit = CapHitResult(
        event: eventB,
        capType: DraggedCapType.entireBlock,
        originalTime: eventB.start, // 21:30
        initialAngle: initialAngle,
        originalDuration: const Duration(hours: 2),
      );

      // Rotate clockwise by 15° (which is +30 minutes in 12h mode: 360° = 720m => 2m/deg)
      final newTouchAngle = initialAngle + 15.0;

      final result = DialTimeCapDragHandler.calculateLiveAdjustment(
        hit: hit,
        currentTouchAngle: newTouchAngle,
        allDayEvents: [eventA, eventB],
        is24HourMode: false,
      );

      // 21:30 + 30m = 22:00
      expect(result.updatedEvent.start, DateTime(2026, 9, 12, 22, 0));
      expect(result.updatedEvent.end, DateTime(2026, 9, 12, 24, 0));
      // Exact 2-hour duration preserved!
      expect(
        result.updatedEvent.end.difference(result.updatedEvent.start),
        const Duration(hours: 2),
      );
      expect(result.didClamp, false);
    });

    test('calculateLiveAdjustment for entireBlock clamps against predecessor (zero overlap)', () {
      final initialAngle = SectorMath.timeToDialAngle(
        DateTime(2026, 9, 12, 22, 30),
        is24HourMode: false,
      );
      final hit = CapHitResult(
        event: eventB, // 21:30 - 23:30
        capType: DraggedCapType.entireBlock,
        originalTime: eventB.start,
        initialAngle: initialAngle,
        originalDuration: const Duration(hours: 2),
      );

      // Attempt to rotate counter-clockwise by 30° (-60 minutes => 20:30)
      // which would overlap eventA (20:30 - 21:30)
      final newTouchAngle = initialAngle - 30.0;

      final result = DialTimeCapDragHandler.calculateLiveAdjustment(
        hit: hit,
        currentTouchAngle: newTouchAngle,
        allDayEvents: [eventA, eventB],
        is24HourMode: false,
      );

      // Clamped flush against eventA.end (21:30)
      expect(result.updatedEvent.start, DateTime(2026, 9, 12, 21, 30));
      expect(result.updatedEvent.end, DateTime(2026, 9, 12, 23, 30));
      expect(
        result.updatedEvent.end.difference(result.updatedEvent.start),
        const Duration(hours: 2),
      );
      expect(result.didClamp, true);
    });

    test('calculateLiveAdjustment naturally pushes preceding blocks when dragging start cap', () {
      final hit = CapHitResult(
        event: eventB,
        capType: DraggedCapType.startCap,
        originalTime: eventB.start, // 21:30
        initialAngle: 285.0,
      );

      // Drag start of eventB backwards into 21:00 (overlapping eventA ending at 21:30)
      final targetAngle = SectorMath.timeToDialAngle(
        DateTime(2026, 9, 12, 21, 0),
        is24HourMode: false,
      );

      final result = DialTimeCapDragHandler.calculateLiveAdjustment(
        hit: hit,
        currentTouchAngle: targetAngle,
        allDayEvents: [eventA, eventB],
        is24HourMode: false,
      );

      // Event B start expands to 21:00
      expect(result.updatedTime, DateTime(2026, 9, 12, 21, 0));
      expect(result.updatedEvent.start, DateTime(2026, 9, 12, 21, 0));
      // Event A (originally 20:30 - 21:30, 1h) is pushed backward to 20:00 - 21:00!
      expect(
        result.allUpdatedEvents[eventA.id]?.start,
        DateTime(2026, 9, 12, 20, 0),
      );
      expect(
        result.allUpdatedEvents[eventA.id]?.end,
        DateTime(2026, 9, 12, 21, 0),
      );
      expect(
        result.allUpdatedEvents[eventA.id]!.end.difference(
          result.allUpdatedEvents[eventA.id]!.start,
        ),
        const Duration(hours: 1),
      );
    });

    test('calculateLiveAdjustment clamps cascade push at dayEnd', () {
      final hit = CapHitResult(
        event: eventA,
        capType: DraggedCapType.endCap,
        originalTime: eventA.end,
        initialAngle: 285.0,
      );

      // Try to drag eventA so far forward that eventB would be pushed past midnight
      final targetAngle = SectorMath.timeToDialAngle(
        DateTime(2026, 9, 12, 23, 0),
        is24HourMode: false,
      );

      final result = DialTimeCapDragHandler.calculateLiveAdjustment(
        hit: hit,
        currentTouchAngle: targetAngle,
        allDayEvents: [eventA, eventB],
        is24HourMode: false,
      );

      // Event B duration is 2h, dayEnd is midnight (24:00)
      // So Event B can start at most at 22:00, meaning Event A end cannot exceed 22:00!
      expect(result.didClamp, true);
      expect(
        result.allUpdatedEvents[eventB.id]?.end,
        DateTime(2026, 9, 13, 0, 0),
      );
      expect(
        result.allUpdatedEvents[eventB.id]?.start,
        DateTime(2026, 9, 12, 22, 0),
      );
      expect(result.updatedEvent.end, DateTime(2026, 9, 12, 22, 0));
    });
  });
}
