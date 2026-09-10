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
      'renders mobile vertical stacked Column layout when width < 700',
      (tester) async {
        // Set mobile portrait dimensions
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
      'renders tablet/desktop side-by-side Row layout when width >= 700',
      (tester) async {
        // Set tablet landscape dimensions
        tester.view.physicalSize = const Size(1024, 768);
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

        // In wide split-pane layout, VerticalDivider is rendered
        expect(find.byType(VerticalDivider), findsOneWidget);
      },
    );
  });
}
