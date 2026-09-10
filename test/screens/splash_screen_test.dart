import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/core/constants/app_strings.dart';
import 'package:sectograph_mcp/presentation/controllers/clock_controller.dart';
import 'package:sectograph_mcp/presentation/controllers/mcp_server_controller.dart';
import 'package:sectograph_mcp/presentation/screens/splash_screen.dart';
import 'package:sectograph_mcp/presentation/widgets/common/radian_app_logo.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SplashScreen Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'has_completed_onboarding': true,
      });
    });

    testWidgets('renders RadianAppLogo, app name, and tagline', (tester) async {
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
          child: const MaterialApp(home: SplashScreen()),
        ),
      );

      // Fast forward animation halfway to verify components render during splash
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(RadianAppLogo), findsOneWidget);
      expect(find.text(AppStrings.appName), findsOneWidget);
      expect(find.text(AppStrings.appTagline), findsOneWidget);

      // Settle delayed navigation timer so test completes cleanly
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();
    });
  });
}
