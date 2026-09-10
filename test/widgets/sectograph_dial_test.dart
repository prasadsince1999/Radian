import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/domain/models/dial_settings.dart';
import 'package:sectograph_mcp/domain/models/sector_event.dart';
import 'package:sectograph_mcp/presentation/controllers/clock_controller.dart';
import 'package:sectograph_mcp/presentation/widgets/dial/sectograph_dial.dart';

import '../mocks/fake_event_repository.dart';

void main() {
  group('SectographDial Widget Tests', () {
    late FakeEventRepository fakeRepo;
    final fixedTime = DateTime(2026, 9, 7, 14, 30); // 2:30 PM

    setUp(() {
      fakeRepo = FakeEventRepository([
        SectorEvent(
          id: 'test-event-1',
          title: 'Design Review',
          start: DateTime(2026, 9, 7, 14, 0),
          end: DateTime(2026, 9, 7, 15, 30),
          colorHex: '#3B82F6',
          category: 'Work',
        ),
      ]);
    });

    testWidgets('renders dial CustomPaint and center summary successfully', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            eventRepositoryProvider.overrideWithValue(fakeRepo),
            currentTimeProvider.overrideWith((ref) => Stream.value(fixedTime)),
            selectedDayProvider.overrideWith((ref) => DateTime(2026, 9, 7)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(width: 400, height: 500, child: SectographDial()),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SectographDial), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      // Footer bar renders date
      expect(find.textContaining('Sep 7'), findsOneWidget);
    });

    testWidgets('resilient to unbounded vertical height without throwing', (
      tester,
    ) async {
      // Placing SectographDial inside an unconstrained column / scrollable
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            eventRepositoryProvider.overrideWithValue(fakeRepo),
            currentTimeProvider.overrideWith((ref) => Stream.value(fixedTime)),
            selectedDayProvider.overrideWith((ref) => DateTime(2026, 9, 7)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: SectographDial()),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // No RenderFlex or flex unbounded height exceptions thrown
      expect(tester.takeException(), isNull);
      expect(find.byType(SectographDial), findsOneWidget);
    });

    testWidgets('navigates day via chevron buttons in footer bar', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            eventRepositoryProvider.overrideWithValue(fakeRepo),
            currentTimeProvider.overrideWith((ref) => Stream.value(fixedTime)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(width: 400, height: 500, child: SectographDial()),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Find chevron right icon and tap
      final chevronRight = find.byIcon(Icons.chevron_right_rounded);
      expect(chevronRight, findsOneWidget);

      await tester.tap(chevronRight);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Relative badge should appear for tomorrow / future date
      expect(find.byType(SectographDial), findsOneWidget);
    });

    testWidgets(
      'renders correctly under classic, numbered, and minimal dial face styles',
      (tester) async {
        for (final style in [
          DialFaceStyle.classicTicks,
          DialFaceStyle.numbered,
          DialFaceStyle.minimal,
        ]) {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                eventRepositoryProvider.overrideWithValue(fakeRepo),
                currentTimeProvider.overrideWith(
                  (ref) => Stream.value(fixedTime),
                ),
                dialSettingsProvider.overrideWith(
                  (ref) =>
                      _TestDialSettingsNotifier(DialSettings(faceStyle: style)),
                ),
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
          expect(tester.takeException(), isNull);
          expect(find.byType(SectographDial), findsOneWidget);
        }
      },
    );

    testWidgets('renders cleanly in both light and dark theme mode', (
      tester,
    ) async {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              eventRepositoryProvider.overrideWithValue(fakeRepo),
              currentTimeProvider.overrideWith(
                (ref) => Stream.value(fixedTime),
              ),
            ],
            child: MaterialApp(
              themeMode: mode,
              theme: ThemeData(
                brightness: Brightness.light,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.deepPurple,
                  brightness: Brightness.light,
                ),
              ),
              darkTheme: ThemeData(
                brightness: Brightness.dark,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.deepPurple,
                  brightness: Brightness.dark,
                ),
              ),
              home: const Scaffold(
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
        expect(tester.takeException(), isNull);
        expect(find.byType(SectographDial), findsOneWidget);
      }
    });

    testWidgets(
      'renders overlapping events as concentric tracks without errors',
      (tester) async {
        final overlappingRepo = FakeEventRepository([
          SectorEvent(
            id: 'overlap-1',
            title: 'Deep Focus Block',
            start: DateTime(2026, 9, 7, 15, 53),
            end: DateTime(2026, 9, 7, 17, 23),
            colorHex: '#3B82F6',
            category: 'Work',
          ),
          SectorEvent(
            id: 'overlap-2',
            title: 'Strength & Cardio',
            start: DateTime(2026, 9, 7, 16, 0),
            end: DateTime(2026, 9, 7, 17, 15),
            colorHex: '#10B981',
            category: 'Fitness',
          ),
        ]);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              eventRepositoryProvider.overrideWithValue(overlappingRepo),
              currentTimeProvider.overrideWith(
                (ref) => Stream.value(DateTime(2026, 9, 7, 16, 30)),
              ),
              selectedDayProvider.overrideWith((ref) => DateTime(2026, 9, 7)),
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

        expect(tester.takeException(), isNull);
        expect(find.byType(SectographDial), findsOneWidget);
      },
    );
  });
}

class _TestDialSettingsNotifier extends DialSettingsNotifier {
  _TestDialSettingsNotifier(DialSettings initial) : super(null) {
    state = initial;
  }
}
