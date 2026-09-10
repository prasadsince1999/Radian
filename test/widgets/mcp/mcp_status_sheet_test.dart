import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/core/constants/app_strings.dart';
import 'package:sectograph_mcp/presentation/controllers/mcp_server_controller.dart';
import 'package:sectograph_mcp/presentation/widgets/mcp/mcp_status_sheet.dart';

void main() {
  group('McpStatusSheet Widget Tests', () {
    testWidgets(
      'renders Gemini & Connectors tab with Name and Server URL fields',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: Scaffold(body: McpStatusSheet())),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('AI Agent & MCP Hub'), findsOneWidget);
        expect(find.text('Gemini & Connectors'), findsOneWidget);
        expect(find.text('Name'), findsOneWidget);
        expect(find.text(AppStrings.appName), findsOneWidget);
        expect(find.text('Server URL'), findsOneWidget);
        expect(find.text('Public HTTPS (Gemini)'), findsOneWidget);
        expect(find.text('Local Wi-Fi'), findsOneWidget);
        expect(find.text('USB ADB'), findsOneWidget);
      },
    );

    testWidgets('switching mode chips changes connector server URL display', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: McpStatusSheet())),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Local Wi-Fi chip
      await tester.tap(find.text('Local Wi-Fi'));
      await tester.pumpAndSettle();

      expect(find.text('Copy Wi-Fi MCP URL'), findsOneWidget);

      // Tap USB ADB chip
      await tester.tap(find.text('USB ADB'));
      await tester.pumpAndSettle();

      expect(find.text('Copy USB ADB URL'), findsOneWidget);
      expect(find.textContaining('adb reverse'), findsWidgets);
    });
  });
}
