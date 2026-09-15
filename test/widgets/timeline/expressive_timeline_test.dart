import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/domain/models/sector_event.dart';
import 'package:sectograph_mcp/presentation/controllers/clock_controller.dart';
import 'package:sectograph_mcp/presentation/widgets/timeline/expressive_timeline.dart';

import '../../mocks/fake_event_repository.dart';

void main() {
  group('ExpressiveTimeline Swipe Threshold Tests', () {
    late FakeEventRepository fakeRepo;
    final fixedTime = DateTime(2026, 9, 11, 10, 0);
    final testEvent = SectorEvent(
      id: 'ev-study',
      title: 'Study Time',
      start: DateTime(2026, 9, 11, 10, 0),
      end: DateTime(2026, 9, 11, 14, 0),
      colorHex: '#F97316',
      category: 'Deep Focus',
    );

    setUp(() {
      fakeRepo = FakeEventRepository([testEvent]);
    });

    testWidgets(
      'Dismissible configures 0.70 threshold for both left and right directions',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              eventRepositoryProvider.overrideWithValue(fakeRepo),
              dayEventsProvider.overrideWith(
                (ref) => Stream.value([testEvent]),
              ),
              currentTimeProvider.overrideWith(
                (ref) => Stream.value(fixedTime),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(body: ExpressiveTimeline()),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final dismissibleFinder = find.byType(Dismissible);
        expect(dismissibleFinder, findsOneWidget);

        final dismissible = tester.widget<Dismissible>(dismissibleFinder);
        expect(
          dismissible.dismissThresholds[DismissDirection.startToEnd],
          0.70,
        );
        expect(
          dismissible.dismissThresholds[DismissDirection.endToStart],
          0.70,
        );
      },
    );

    testWidgets(
      'Small horizontal swipe (30% width) does NOT delete the block',
      (tester) async {
        tester.view.physicalSize = const Size(500, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              eventRepositoryProvider.overrideWithValue(fakeRepo),
              dayEventsProvider.overrideWith(
                (ref) => Stream.value([testEvent]),
              ),
              currentTimeProvider.overrideWith(
                (ref) => Stream.value(fixedTime),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(body: ExpressiveTimeline()),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Study Time'), findsOneWidget);

        // Drag slightly left by 80px (< 20% of card width)
        await tester.drag(find.text('Study Time'), const Offset(-80, 0));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Must still exist in widget tree
        expect(find.text('Study Time'), findsOneWidget);
      },
    );
  });
}
