import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/presentation/controllers/clock_controller.dart';
import 'package:sectograph_mcp/presentation/controllers/mcp_server_controller.dart';
import 'package:sectograph_mcp/presentation/screens/home_screen.dart';
import 'package:sectograph_mcp/presentation/widgets/dial/sectograph_dial.dart';
import 'package:sectograph_mcp/presentation/widgets/timeline/expressive_timeline.dart';

import '../mocks/fake_event_repository.dart';

void main() {
  group('Responsive Layout Tests', () {
    late FakeEventRepository fakeRepo;
    final fixedTime = DateTime(2026, 9, 7, 10, 30);

    setUp(() {
      fakeRepo = FakeEventRepository();
    });

    testWidgets(
      'renders Compact (< 600dp) mobile vertical stacked Column layout',
      (tester) async {
        // Set mobile portrait dimensions (Compact: < 600dp)
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              eventRepositoryProvider.overrideWithValue(fakeRepo),
              currentTimeProvider.overrideWith(
                (ref) => Stream.value(fixedTime),
              ),
              mcpServerControllerProvider.overrideWith(
                (ref) => McpServerController(ref, autoStart: false),
              ),
            ],
            child: const MaterialApp(home: HomeScreen()),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(SectographDial), findsOneWidget);
        expect(find.byType(ExpressiveTimeline), findsOneWidget);

        // In mobile stacked layout, no VerticalDivider is present
        expect(find.byType(VerticalDivider), findsNothing);
      },
    );

    testWidgets(
      'renders Medium (600dp - 840dp) 2-pane split Row layout',
      (tester) async {
        // Set foldables unfolded / small tablet dimensions (Medium: 720dp)
        tester.view.physicalSize = const Size(720, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              eventRepositoryProvider.overrideWithValue(fakeRepo),
              currentTimeProvider.overrideWith(
                (ref) => Stream.value(fixedTime),
              ),
              mcpServerControllerProvider.overrideWith(
                (ref) => McpServerController(ref, autoStart: false),
              ),
            ],
            child: const MaterialApp(home: HomeScreen()),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(SectographDial), findsOneWidget);
        expect(find.byType(ExpressiveTimeline), findsOneWidget);

        // In 2-pane layout, 1 VerticalDivider separates Dial and Timeline
        expect(find.byType(VerticalDivider), findsOneWidget);
      },
    );

    testWidgets(
      'renders Expanded (>= 840dp) 3-pane adaptive Row layout with Supporting Insights',
      (tester) async {
        // Set large tablet / desktop dimensions (Expanded: 1200dp)
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              eventRepositoryProvider.overrideWithValue(fakeRepo),
              currentTimeProvider.overrideWith(
                (ref) => Stream.value(fixedTime),
              ),
              mcpServerControllerProvider.overrideWith(
                (ref) => McpServerController(ref, autoStart: false),
              ),
            ],
            child: const MaterialApp(home: HomeScreen()),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(SectographDial), findsOneWidget);
        expect(find.byType(ExpressiveTimeline), findsOneWidget);

        // In 3-pane layout, 2 VerticalDividers separate Dial, Timeline, and Supporting Pane
        expect(find.byType(VerticalDivider), findsNWidgets(2));
        // Supporting pane renders the habit/routine insights header
        expect(find.text('Habit & Routine Insights'), findsOneWidget);
      },
    );
  });
}
