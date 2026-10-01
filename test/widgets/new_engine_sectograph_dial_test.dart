import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/core/clock.dart';
import 'package:sectograph_mcp/core/dial_engine_flags.dart';
import 'package:sectograph_mcp/domain/models/sector_event.dart';
import 'package:sectograph_mcp/presentation/controllers/clock_controller.dart';
import 'package:sectograph_mcp/presentation/widgets/dial/dial_painter.dart';
import 'package:sectograph_mcp/presentation/widgets/dial/sectograph_dial.dart';

import '../mocks/fake_event_repository.dart';

void main() {
  group('New Engine SectographDial Tests (Phase 5 Integration)', () {
    late FakeEventRepository fakeRepo;
    final fixedTime = DateTime(2026, 9, 29, 14, 30); // 2:30 PM

    setUp(() {
      DialEngineFlags.newEngine = true;
      fakeRepo = FakeEventRepository([
        SectorEvent(
          id: 'test-event-1',
          title: 'Design Review',
          start: DateTime(2026, 9, 29, 14, 0),
          end: DateTime(2026, 9, 29, 15, 30),
          colorHex: '#3B82F6',
          category: 'Work',
        ),
        SectorEvent(
          id: 'test-event-2',
          title: 'Team Standup',
          start: DateTime(2026, 9, 29, 16, 0),
          end: DateTime(2026, 9, 29, 17, 0),
          colorHex: '#10B981',
          category: 'Work',
        ),
      ]);
    });

    tearDown(() {
      // New engine is permanent in Phase 9
    });

    testWidgets('renders new engine dial stack with DialPainter and Semantics label', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clockProvider.overrideWithValue(FixedClock(fixedTime)),
            currentTimeProvider.overrideWith((ref) => Stream.value(fixedTime)),
            selectedDayProvider.overrideWith((ref) => DateTime(2026, 9, 29)),
            eventRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 500,
                child: SectographDial(),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SectographDial), findsOneWidget);

      // Verify that CustomPaint with DialPainter is rendered
      final customPaintFinder = find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is DialPainter,
      );
      expect(customPaintFinder, findsOneWidget);

      // Verify Semantics contains "Now: Design Review" and "Next: Team Standup"
      final semanticsFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label != null &&
            widget.properties.label!.contains('Now: Design Review') &&
            widget.properties.label!.contains('Next: Team Standup'),
      );
      expect(semanticsFinder, findsOneWidget);
    });

    testWidgets('scrubbing on new engine dial updates dialScrubAngleProvider', (tester) async {
      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(FixedClock(fixedTime)),
          currentTimeProvider.overrideWith((ref) => Stream.value(fixedTime)),
          selectedDayProvider.overrideWith((ref) => DateTime(2026, 9, 29)),
          eventRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 500,
                child: SectographDial(),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(container.read(dialScrubAngleProvider), isNull);

      // Dial center is roughly at (200, 200) inside 400x500 box
      // Start drag at right edge (350, 200) -> 90° angle
      final gesture = await tester.startGesture(const Offset(350, 200));
      try {
        await gesture.moveBy(const Offset(0, 30));
        await tester.pump();

        expect(container.read(dialScrubAngleProvider), isNotNull);
      } finally {
        // Release drag
        await gesture.up();
        await tester.pump();
      }

      expect(container.read(dialScrubAngleProvider), isNull);
    });

    testWidgets('unconditionally renders new engine DialPainter across rebuilds', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clockProvider.overrideWithValue(FixedClock(fixedTime)),
            currentTimeProvider.overrideWith((ref) => Stream.value(fixedTime)),
            selectedDayProvider.overrideWith((ref) => DateTime(2026, 9, 29)),
            eventRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 500,
                child: SectographDial(),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert new engine dial is rendered unconditionally
      final newCustomPaintFinder = find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is DialPainter,
      );
      expect(newCustomPaintFinder, findsOneWidget);
    });
  });
}
