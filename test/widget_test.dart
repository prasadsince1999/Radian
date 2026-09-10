import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/core/constants/app_strings.dart';
import 'package:sectograph_mcp/main.dart';
import 'package:sectograph_mcp/presentation/controllers/clock_controller.dart';
import 'package:sectograph_mcp/presentation/controllers/mcp_server_controller.dart';
import 'package:sectograph_mcp/presentation/screens/home_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('SectographApp smoke test renders title and dial', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({'has_completed_onboarding': true});
    final prefs = await SharedPreferences.getInstance();
    final fixedTime = DateTime(2026, 9, 7, 10, 30);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentTimeProvider.overrideWith((ref) => Stream.value(fixedTime)),
          // Prevent real network server bind in widget test
          mcpServerControllerProvider.overrideWith(
            (ref) => McpServerController(ref, autoStart: false),
          ),
        ],
        child: const SectographApp(home: HomeScreen()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(AppStrings.appName), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.byTooltip('Add Block'), findsOneWidget);
    expect(find.byKey(const ValueKey('add_block_fab')), findsOneWidget);
  });
}
