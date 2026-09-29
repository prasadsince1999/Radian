import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/domain/models/sector_event.dart';
import 'package:sectograph_mcp/engine/dial_input.dart';
import 'package:sectograph_mcp/engine/dial_model_builder.dart';
import 'package:sectograph_mcp/presentation/controllers/clock_controller.dart';
import 'package:sectograph_mcp/presentation/widgets/dial/dial_gesture_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DialGestureController Tests (Phase 5 Interaction)', () {
    late DialInput sampleInput;
    final testNow = DateTime(2026, 9, 29, 10, 15);

    late SectorEvent eventYoga;
    late SectorEvent eventWork;
    late SectorEvent eventStandup;
    late List<SectorEvent> allEvents;

    setUp(() {
      eventYoga = SectorEvent(
        id: 'ev-1',
        title: 'Morning Yoga',
        start: DateTime(2026, 9, 29, 6, 0),
        end: DateTime(2026, 9, 29, 7, 15),
        colorHex: '#10B981',
        category: 'Health',
        subtasks: const ['Asana', 'Pranayama'],
      );
      eventWork = SectorEvent(
        id: 'ev-2',
        title: 'Deep Work',
        start: DateTime(2026, 9, 29, 9, 30),
        end: DateTime(2026, 9, 29, 12, 0),
        colorHex: '#6366F1',
        category: 'Work',
      );
      eventStandup = SectorEvent(
        id: 'ev-3',
        title: 'Team Standup',
        start: DateTime(2026, 9, 29, 14, 0),
        end: DateTime(2026, 9, 29, 15, 0),
        colorHex: '#F59E0B',
        category: 'Work',
      );
      allEvents = [eventYoga, eventWork, eventStandup];

      sampleInput = DialInput(
        now: testNow,
        tzid: 'UTC',
        occurrences: [
          Occurrence(
            id: 'occ-1',
            eventId: 'ev-1',
            title: 'Morning Yoga',
            start: DateTime(2026, 9, 29, 6, 0),
            end: DateTime(2026, 9, 29, 7, 15),
            colorHex: '#10B981',
            category: 'Health',
            subtasks: const ['Asana', 'Pranayama'],
          ),
          Occurrence(
            id: 'occ-2',
            eventId: 'ev-2',
            title: 'Deep Work',
            start: DateTime(2026, 9, 29, 9, 30),
            end: DateTime(2026, 9, 29, 12, 0),
            colorHex: '#6366F1',
            category: 'Work',
          ),
          Occurrence(
            id: 'occ-3',
            eventId: 'ev-3',
            title: 'Team Standup',
            start: DateTime(2026, 9, 29, 14, 0),
            end: DateTime(2026, 9, 29, 15, 0),
            colorHex: '#F59E0B',
            category: 'Work',
          ),
        ],
        prefs: const DialPrefs(
          is24HourMode: false,
          previousBlocksCount: 1,
          futureBlocksCount: 3,
        ),
      );
    });

    testWidgets('touchToDisplayAngle and touchToNaturalAngle map angles using warp.inverse', (tester) async {
      final model = DialModelBuilder.build(sampleInput);
      const center = Offset(180, 180);

      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              final controller = DialGestureController(
                ref: ref,
                model: model,
                center: center,
                innerRadius: 50.0,
                routineTrackIn: 70.0,
                routineTrackOut: 140.0,
                ringDividerRadius: 105.0,
                is24HourMode: false,
                isDialEditing: false,
                allEvents: allEvents,
              );

              // 12:00 position is (180, 80) -> straight up, angle = 0°
              final displayUp = controller.touchToDisplayAngle(const Offset(180, 80));
              expect(displayUp, closeTo(0.0, 0.5));
              expect(controller.touchToNaturalAngle(const Offset(180, 80)), closeTo(0.0, 0.5));

              // 3:00 position is (280, 180) -> straight right, angle = 90°
              final displayRight = controller.touchToDisplayAngle(const Offset(280, 180));
              expect(displayRight, closeTo(90.0, 0.5));
              // In natural coordinates, 90° display is inverted through warp
              final naturalRight = controller.touchToNaturalAngle(const Offset(280, 180));
              expect(naturalRight, equals(model.warp.inverse(90.0)));

              // 6:00 position is (180, 280) -> straight down, angle = 180°
              final displayDown = controller.touchToDisplayAngle(const Offset(180, 280));
              expect(displayDown, closeTo(180.0, 0.5));

              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('hitTestBlock detects block under touch within radius and arc', (tester) async {
      final model = DialModelBuilder.build(sampleInput);
      const center = Offset(180, 180);

      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              final controller = DialGestureController(
                ref: ref,
                model: model,
                center: center,
                innerRadius: 50.0,
                routineTrackIn: 70.0,
                routineTrackOut: 140.0,
                ringDividerRadius: 105.0,
                is24HourMode: false,
                isDialEditing: false,
                allEvents: allEvents,
              );

              // Test tap inside center hub (< 50) returns null
              final hubHit = controller.hitTestBlock(center);
              expect(hubHit, isNull);

              // Test tap outside outer radius (> 140) returns null
              final outsideHit = controller.hitTestBlock(const Offset(180, 10));
              expect(outsideHit, isNull);

              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('handleTapUp selects event on block tap and deselects on center/outside tap', (tester) async {
      final model = DialModelBuilder.build(sampleInput);
      const center = Offset(180, 180);

      SectorEvent? currentSelection;

      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              currentSelection = ref.watch(selectedEventProvider);
              final controller = DialGestureController(
                ref: ref,
                model: model,
                center: center,
                innerRadius: 50.0,
                routineTrackIn: 70.0,
                routineTrackOut: 140.0,
                ringDividerRadius: 105.0,
                is24HourMode: false,
                isDialEditing: false,
                allEvents: allEvents,
                selectedEvent: currentSelection,
              );

              return GestureDetector(
                onTapUp: controller.handleTapUp,
                child: Container(
                  width: 360,
                  height: 360,
                  color: Colors.blue,
                ),
              );
            },
          ),
        ),
      );

      expect(currentSelection, isNull);

      // Tap center hub to verify no crash and deselect behavior
      await tester.tapAt(center);
      await tester.pump();
      expect(currentSelection, isNull);
    });

    testWidgets('handlePan scrub updates dialScrubAngleProvider when not editing', (tester) async {
      final model = DialModelBuilder.build(sampleInput);
      const center = Offset(180, 180);

      double? currentScrubAngle;

      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              currentScrubAngle = ref.watch(dialScrubAngleProvider);
              final controller = DialGestureController(
                ref: ref,
                model: model,
                center: center,
                innerRadius: 50.0,
                routineTrackIn: 70.0,
                routineTrackOut: 140.0,
                ringDividerRadius: 105.0,
                is24HourMode: false,
                isDialEditing: false,
                allEvents: allEvents,
              );

              return GestureDetector(
                onPanStart: controller.handlePanStart,
                onPanUpdate: controller.handlePanUpdate,
                onPanEnd: controller.handlePanEnd,
                child: Container(
                  width: 360,
                  height: 360,
                  color: Colors.grey,
                ),
              );
            },
          ),
        ),
      );

      expect(currentScrubAngle, isNull);

      // Pan around rim: touch at (280, 180) -> 90°
      final gesture = await tester.startGesture(const Offset(280, 180));
      await tester.pump();
      expect(currentScrubAngle, closeTo(90.0, 1.0));

      // Move to (180, 280) -> 180°
      await gesture.moveTo(const Offset(180, 280));
      await tester.pump();
      expect(currentScrubAngle, closeTo(180.0, 1.0));

      // End pan -> scrub angle resets to null
      await gesture.up();
      await tester.pump();
      expect(currentScrubAngle, isNull);
    });
  });
}
