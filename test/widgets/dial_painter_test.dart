import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/domain/models/dial_settings.dart';
import 'package:sectograph_mcp/engine/dial_input.dart';
import 'package:sectograph_mcp/engine/dial_model_builder.dart';
import 'package:sectograph_mcp/presentation/widgets/dial/dial_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DialPainter Tests (Phase 5 Pure Painter)', () {
    late DialInput sampleInput;
    final testNow = DateTime(2026, 9, 29, 10, 15);

    setUp(() {
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
            subtasks: const ['Asana', 'Pranayama', 'Meditation'],
            subtaskItems: const [
              SubtaskItemOccurrence(
                id: 'st-1',
                title: 'Asana',
                isCompleted: true,
                startMinuteOffset: 0,
                endMinuteOffset: 25,
              ),
              SubtaskItemOccurrence(
                id: 'st-2',
                title: 'Pranayama',
                isCompleted: false,
                startMinuteOffset: 25,
                endMinuteOffset: 50,
              ),
            ],
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

    testWidgets('paints cleanly on canvas at reference size (360x360)', (tester) async {
      final model = DialModelBuilder.build(sampleInput);
      const settings = DialSettings();
      final theme = ThemeData.light();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: 360,
                child: CustomPaint(
                  painter: DialPainter(
                    model: model,
                    settings: settings,
                    theme: theme,
                    colorScheme: theme.colorScheme,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('paints cleanly at scaled size (200x200) and zero size (0x0)', (tester) async {
      final model = DialModelBuilder.build(sampleInput);
      const settings = DialSettings();
      final theme = ThemeData.dark();

      // Scaled size
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: CustomPaint(
                  painter: DialPainter(
                    model: model,
                    settings: settings,
                    theme: theme,
                    colorScheme: theme.colorScheme,
                    showCenterClock: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);

      // Zero size
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 0,
              height: 0,
              child: CustomPaint(
                painter: DialPainter(
                  model: model,
                  settings: settings,
                  theme: theme,
                  colorScheme: theme.colorScheme,
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('paints 24-hour mode dial with 24 ticks without error', (tester) async {
      final input24 = sampleInput.copyWith(
        prefs: sampleInput.prefs.copyWith(is24HourMode: true),
        window: DialWindowMode.fullDay24,
      );
      final model24 = DialModelBuilder.build(input24);
      expect(model24.is24HourMode, isTrue);
      expect(model24.ticks.length, equals(24));

      const settings = DialSettings(is24HourMode: true);
      final theme = ThemeData.light();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: 360,
                child: CustomPaint(
                  painter: DialPainter(
                    model: model24,
                    settings: settings,
                    theme: theme,
                    colorScheme: theme.colorScheme,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    test('shouldRepaint returns false when model signature and theme are identical', () {
      final model = DialModelBuilder.build(sampleInput);
      const settings = DialSettings();
      final theme = ThemeData.light();

      final painter1 = DialPainter(
        model: model,
        settings: settings,
        theme: theme,
        colorScheme: theme.colorScheme,
      );

      final painter2 = DialPainter(
        model: model,
        settings: settings,
        theme: theme,
        colorScheme: theme.colorScheme,
      );

      expect(painter2.shouldRepaint(painter1), isFalse);
    });

    test('shouldRepaint returns true when model signature changes', () {
      final model1 = DialModelBuilder.build(sampleInput);
      final input2 = sampleInput.copyWith(
        occurrences: [
          ...sampleInput.occurrences,
          Occurrence(
            id: 'occ-new',
            eventId: 'ev-new',
            title: 'Quick Call',
            start: DateTime(2026, 9, 29, 16, 0),
            end: DateTime(2026, 9, 29, 16, 30),
            colorHex: '#3B82F6',
            category: 'Work',
          ),
        ],
      );
      final model2 = DialModelBuilder.build(input2);
      expect(model1.signature, isNot(equals(model2.signature)));

      const settings = DialSettings();
      final theme = ThemeData.light();

      final painter1 = DialPainter(
        model: model1,
        settings: settings,
        theme: theme,
        colorScheme: theme.colorScheme,
      );

      final painter2 = DialPainter(
        model: model2,
        settings: settings,
        theme: theme,
        colorScheme: theme.colorScheme,
      );

      expect(painter2.shouldRepaint(painter1), isTrue);
    });

    test('shouldRepaint returns true when theme or scrubAngle changes', () {
      final model = DialModelBuilder.build(sampleInput);
      const settings = DialSettings();
      final themeLight = ThemeData.light();
      final themeDark = ThemeData.dark();

      final painter1 = DialPainter(
        model: model,
        settings: settings,
        theme: themeLight,
        colorScheme: themeLight.colorScheme,
        scrubAngle: null,
      );

      final painterThemeChanged = DialPainter(
        model: model,
        settings: settings,
        theme: themeDark,
        colorScheme: themeDark.colorScheme,
        scrubAngle: null,
      );

      expect(painterThemeChanged.shouldRepaint(painter1), isTrue);

      final painterScrubChanged = DialPainter(
        model: model,
        settings: settings,
        theme: themeLight,
        colorScheme: themeLight.colorScheme,
        scrubAngle: 45.0,
      );

      expect(painterScrubChanged.shouldRepaint(painter1), isTrue);
    });
  });
}
