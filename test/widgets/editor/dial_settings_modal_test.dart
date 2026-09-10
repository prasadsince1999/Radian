import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/domain/models/dial_settings.dart';
import 'package:sectograph_mcp/presentation/controllers/clock_controller.dart';
import 'package:sectograph_mcp/presentation/widgets/editor/dial_settings_modal.dart';

void main() {
  group('DialSettingsModal Widget Tests', () {
    testWidgets('renders all customization sections without assertions', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: DialSettingsModal())),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Dial Customization'), findsOneWidget);
      expect(find.text('24-Hour Dial Mode'), findsOneWidget);
      expect(find.text('Center Clock Display'), findsOneWidget);
      expect(find.text('Theme Mode'), findsOneWidget);
      expect(find.text('Expressive Seed Palette'), findsOneWidget);
      expect(find.text('Dial Face Style'), findsOneWidget);
    });

    testWidgets('toggling 24-Hour Dial Mode updates dialSettingsProvider', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: DialSettingsModal())),
        ),
      );

      await tester.pumpAndSettle();

      // Initial state is 12-hour mode
      expect(container.read(dialSettingsProvider).is24HourMode, isFalse);

      // Find the Switch and tap it
      final switchTile = find.byType(SwitchListTile);
      expect(switchTile, findsOneWidget);

      await tester.tap(switchTile);
      await tester.pumpAndSettle();

      // State is now 24-hour mode
      expect(container.read(dialSettingsProvider).is24HourMode, isTrue);
    });

    testWidgets('selecting Analog in Center Clock Display updates provider', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: DialSettingsModal())),
        ),
      );

      await tester.pumpAndSettle();

      // Default is both
      expect(
        container.read(dialSettingsProvider).centerClockDisplay,
        equals(CenterClockDisplay.both),
      );

      // Tap 'Analog'
      final analogBtn = find.text('Analog');
      expect(analogBtn, findsOneWidget);

      await tester.tap(analogBtn);
      await tester.pumpAndSettle();

      expect(
        container.read(dialSettingsProvider).centerClockDisplay,
        equals(CenterClockDisplay.analog),
      );
    });
  });
}
