import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/presentation/controllers/clock_controller.dart';
import 'package:sectograph_mcp/presentation/controllers/mcp_server_controller.dart';
import 'package:sectograph_mcp/presentation/screens/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('OnboardingScreen Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('renders Page 1 and navigates through 3 slides to completion', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      final fixedTime = DateTime(2026, 9, 7, 10, 30);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            currentTimeProvider.overrideWith((ref) => Stream.value(fixedTime)),
            mcpServerControllerProvider.overrideWith(
              (ref) => McpServerController(ref, autoStart: false),
            ),
          ],
          child: const MaterialApp(home: OnboardingScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Page 1: 360° Circular Time Blocking
      expect(find.text('360° Circular Time Blocking'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);

      // Tap Next to move to Page 2
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Page 2: Living Themes & Health Balance
      expect(find.text('Living Themes & Health Balance'), findsOneWidget);

      // Tap Next to move to Page 3
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Page 3: AI-Native Agent Scheduling
      expect(find.text('AI-Native Agent Scheduling'), findsOneWidget);
      expect(find.text('Battery Optimization'), findsOneWidget);
      expect(find.text('Routine Notifications'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);

      // Tap Get Started
      await tester.tap(find.text('Get Started'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(prefs.getBool('has_completed_onboarding'), isTrue);
    });
  });
}
